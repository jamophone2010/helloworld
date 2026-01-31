local M = {}

local wheel = require("roulette.wheel")
local ball = require("roulette.ball")
local table = require("roulette.table")
local bets = require("roulette.bets")
local credits = require("roulette.credits")
local audio = require("roulette.audio")
local ui = require("roulette.ui")

local gameState = {}

function M.load()
  gameState.wheel = wheel.new()
  gameState.ball = ball.new()
  gameState.table = table.new()
  gameState.bets = bets.new()
  gameState.bank = credits.new(1000)
  gameState.state = "betting"
  gameState.result = nil
  gameState.payout = 0
  gameState.payoutTimer = 0

  audio.load()
  ui.load()
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
    end
  end
end

function M.draw()
  love.graphics.setBackgroundColor(0.05, 0.15, 0.05)

  ui.drawWheel(gameState.wheel)
  if gameState.ball.spinning or gameState.state == "settling" then
    ui.drawBall(gameState.ball)
  end

  ui.drawTable(gameState.table)
  ui.drawBets(gameState.bets, gameState.table)
  ui.drawUI(gameState.bank, gameState.state, gameState.result)

  if gameState.state == "payout" and gameState.payout > 0 then
    love.graphics.setFont(love.graphics.newFont(24))
    love.graphics.setColor(1, 1, 0)
    love.graphics.printf("WIN: " .. gameState.payout, 0, 530, 800, "center")
  end
end

function M.keypressed(key)
  if key == "space" and gameState.state == "betting" then
    local totalBet = bets.getTotalBetAmount(gameState.bets)
    if totalBet > 0 and totalBet <= gameState.bank.balance then
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
