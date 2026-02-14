local M = {}

local wheel = require("roulette.wheel")
local ball = require("roulette.ball")
local table = require("roulette.table")
local bets = require("roulette.bets")
local credits = require("roulette.credits")
local audio = require("roulette.audio")
local ui = require("roulette.ui")
local winFx = require("casino_win_fx")

local SCREEN_W = 1366
local SCREEN_H = 768

local gameState = {}

function M.load(startingCredits)
  -- Seed random number generator for wheel results
  math.randomseed(os.time())
  math.random(); math.random(); math.random() -- Discard first few values for better randomness
  
  gameState.wheel = wheel.new()
  gameState.ball = ball.new()
  gameState.table = table.new()
  gameState.bets = bets.new()
  gameState.bank = credits.new(startingCredits or 1000)
  gameState.state = "betting"
  gameState.result = nil
  gameState.payout = 0
  gameState.payoutTimer = 0
  gameState.history = {}
  gameState.lastTotalBet = 0

  audio.load()
  ui.load()
end

function M.getCredits()
  return gameState.bank.balance
end

function M.update(dt)
  wheel.update(gameState.wheel, dt)
  ball.update(gameState.ball, dt)
  winFx.update(dt)

  if gameState.state == "spinning" then
    if wheel.isStopped(gameState.wheel) then
      gameState.state = "settling"
    end

  elseif gameState.state == "settling" then
    if ball.isStopped(gameState.ball) then
      gameState.result = wheel.getCurrentPocket(gameState.wheel)

      -- Add to history (keep last 5)
      _G.table.insert(gameState.history, 1, gameState.result)
      if #gameState.history > 5 then
        _G.table.remove(gameState.history)
      end

      local totalPayout, wins = bets.calculatePayout(gameState.bets, gameState.result)

      gameState.payout = totalPayout
      if totalPayout > 0 then
        local creditsBeforeWin = gameState.bank.balance
        credits.add(gameState.bank, totalPayout)
        audio.playWin()
        winFx.startWin(totalPayout, gameState.lastTotalBet, creditsBeforeWin, SCREEN_W / 2, SCREEN_H / 2 - 50)
      end

      gameState.state = "payout"
      gameState.payoutTimer = 0
    end

  elseif gameState.state == "payout" then
    gameState.payoutTimer = gameState.payoutTimer + dt
    local minTime = winFx.isActive() and winFx.getTier() * 1.0 or 3.0
    if gameState.payoutTimer >= minTime and not winFx.isActive() then
      bets.clear(gameState.bets)
      gameState.state = "betting"
      gameState.result = nil
      gameState.payout = 0
      
      -- Fully reset wheel and ball for next spin
      gameState.wheel.phase = "idle"
      gameState.wheel.spinning = false
      gameState.wheel.velocity = 0
      gameState.wheel.timer = 0
      gameState.wheel.targetPocket = nil
      
      gameState.ball.phase = "idle"
      gameState.ball.spinning = false
      gameState.ball.velocity = 0
      gameState.ball.timer = 0
      gameState.ball.finalPocket = nil
    end
  end
end

function M.draw()
  love.graphics.setBackgroundColor(0.02, 0.08, 0.03)

  -- Apply screen shake
  local shakeX, shakeY = winFx.getScreenShake()
  love.graphics.push()
  love.graphics.translate(shakeX, shakeY)

  -- Glow behind game elements
  winFx.drawGlow()

  ui.drawTable(gameState.table)
  ui.drawBets(gameState.bets, gameState.table)
  ui.drawWheel(gameState.wheel)
  if gameState.ball.phase ~= "idle" then
    ui.drawBall(gameState.ball, gameState.wheel)
  end

  ui.drawUI(gameState.bank, gameState.state, gameState.result, gameState.history, gameState.table, gameState.payout)

  -- Win FX particles and text on top
  winFx.drawParticles()
  if winFx.isActive() then
    winFx.drawWinText(SCREEN_W / 2, SCREEN_H / 2 - 80)
  end

  love.graphics.pop()
end

function M.keypressed(key)
  if key == "space" then
    if winFx.isActive() then
      winFx.skip()
      return
    end
    if gameState.state == "payout" and not winFx.isActive() then
      bets.clear(gameState.bets)
      gameState.state = "betting"
      gameState.result = nil
      gameState.payout = 0
      gameState.wheel.phase = "idle"
      gameState.wheel.spinning = false
      gameState.wheel.velocity = 0
      gameState.wheel.timer = 0
      gameState.wheel.targetPocket = nil
      gameState.ball.phase = "idle"
      gameState.ball.spinning = false
      gameState.ball.velocity = 0
      gameState.ball.timer = 0
      gameState.ball.finalPocket = nil
      return
    end
    if gameState.state == "betting" then
      local totalBet = bets.getTotalBetAmount(gameState.bets)
      if totalBet > 0 then
        gameState.lastTotalBet = totalBet
        wheel.spin(gameState.wheel)
        ball.spin(gameState.ball, gameState.wheel.targetPocket, #wheel.POCKETS)
        gameState.state = "spinning"
        audio.playSpin()
      end
    end
  elseif key == "up" then
    credits.nextChip(gameState.bank)
  elseif key == "down" then
    credits.prevChip(gameState.bank)
  end
end

function M.mousepressed(x, y, button)
  if button == 1 and gameState.state == "betting" then
    local betInfo = table.getBetFromClick(gameState.table, x, y)
    if betInfo then
      local chipValue = credits.getSelectedChipValue(gameState.bank)
      if credits.canAfford(gameState.bank, chipValue) then
        credits.deduct(gameState.bank, chipValue)
        bets.placeBet(gameState.bets, betInfo, chipValue)
        audio.playPlace()
      end
    end
  end
end

return M
