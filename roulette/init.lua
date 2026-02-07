local M = {}

local wheel = require("roulette.wheel")
local ball = require("roulette.ball")
local table = require("roulette.table")
local bets = require("roulette.bets")
local credits = require("roulette.credits")
local audio = require("roulette.audio")
local ui = require("roulette.ui")

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

  audio.load()
  ui.load()
end

function M.getCredits()
  return gameState.bank.balance
end

function M.update(dt)
  wheel.update(gameState.wheel, dt)
  ball.update(gameState.ball, dt)

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
        credits.add(gameState.bank, totalPayout)
        audio.playWin()
      end

      gameState.state = "payout"
      gameState.payoutTimer = 0
    end

  elseif gameState.state == "payout" then
    gameState.payoutTimer = gameState.payoutTimer + dt
    if gameState.payoutTimer >= 3.0 then
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
  love.graphics.setBackgroundColor(0.05, 0.15, 0.05)

  ui.drawWheel(gameState.wheel)
  if gameState.ball.phase ~= "idle" then
    ui.drawBall(gameState.ball, gameState.wheel)
  end

  ui.drawTable(gameState.table)
  ui.drawBets(gameState.bets, gameState.table)
  ui.drawUI(gameState.bank, gameState.state, gameState.result, gameState.history, gameState.table, gameState.payout)

  if gameState.state == "payout" and gameState.payout > 0 then
    love.graphics.setFont(love.graphics.newFont(32))
    love.graphics.setColor(1, 1, 0)
    love.graphics.print("Winner!", 150, 450)
    love.graphics.setFont(love.graphics.newFont(28))
    love.graphics.print(gameState.payout, 150, 490)
  end
end

function M.keypressed(key)
  if key == "space" and gameState.state == "betting" then
    local totalBet = bets.getTotalBetAmount(gameState.bets)
    if totalBet > 0 then
      wheel.spin(gameState.wheel)
      ball.spin(gameState.ball, gameState.wheel.targetPocket, #wheel.POCKETS)
      gameState.state = "spinning"
      audio.playSpin()
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
