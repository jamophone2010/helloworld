local M = {}

local machine = require("slotmachine.machine")
local credits = require("slotmachine.credits")
local audio = require("slotmachine.audio")
local ui = require("slotmachine.ui")
local symbols = require("slotmachine.symbols")
local winFx = require("casino_win_fx")

local SCREEN_W = 1366
local SCREEN_H = 768

local gameState = {}

function M.load(startingCredits)
  gameState.machine = machine.new()
  gameState.bank = credits.new(startingCredits or 1000)
  gameState.wins = {}
  gameState.totalWinnings = 0
  gameState.lastTotalBet = 0

  audio.load()
  ui.load()
end

function M.getCredits()
  return gameState.bank.credits
end

function M.update(dt)
  gameState.dt = dt
  machine.update(gameState.machine, dt)
  winFx.update(dt)

  if gameState.machine.state == "checking" then
    local wins, totalWinnings = machine.checkWins(gameState.machine, gameState.bank.currentBet)

    gameState.wins = wins
    gameState.totalWinnings = totalWinnings

    if totalWinnings > 0 then
      -- Start win FX before adding credits so counter animates up
      local creditsBeforeWin = gameState.bank.credits
      credits.addWinnings(gameState.bank, totalWinnings)
      audio.playWin()
      winFx.startWin(totalWinnings, gameState.lastTotalBet, creditsBeforeWin, SCREEN_W / 2, 350)
      gameState.machine.state = "payout"
    else
      gameState.machine.state = "idle"
    end
  end

  -- Extend payout state while win FX is active
  if gameState.machine.state == "payout" and not winFx.isActive() then
    -- Only transition to idle after win FX finishes
  end
end

function M.draw()
  love.graphics.setBackgroundColor(0.02, 0.02, 0.06)

  -- Apply screen shake
  local shakeX, shakeY = winFx.getScreenShake()
  love.graphics.push()
  love.graphics.translate(shakeX, shakeY)

  -- Draw faded Bellagio-style background
  ui.drawBackground(gameState.dt)

  -- Draw glow behind game UI
  winFx.drawGlow()

  ui.drawReels(gameState.machine)
  ui.drawUI(gameState.bank, gameState.machine.state)

  if gameState.machine.state == "payout" then
    ui.drawWins(gameState.wins, gameState.totalWinnings, symbols.PAYLINES)
  end

  -- Win FX particles and text on top
  winFx.drawParticles()
  if winFx.isActive() then
    winFx.drawWinText(SCREEN_W / 2, SCREEN_H / 2 - 60)
  end

  love.graphics.pop()
end

function M.keypressed(key)
  if key == "space" then
    if winFx.isActive() then
      winFx.skip()
      return
    end
    if gameState.machine.state == "idle" or (gameState.machine.state == "payout" and not winFx.isActive()) then
      gameState.machine.state = "idle"
      if credits.canPlaceBet(gameState.bank) then
        gameState.lastTotalBet = credits.getTotalBet(gameState.bank)
        credits.placeBet(gameState.bank)
        machine.spin(gameState.machine)
        gameState.wins = {}
        gameState.totalWinnings = 0
        audio.playSpin()
      end
    end
  elseif key == "left" then
    credits.prevChip(gameState.bank)
  elseif key == "right" then
    credits.nextChip(gameState.bank)
  elseif key == "up" then
    credits.increaseBet(gameState.bank)
  elseif key == "down" then
    credits.decreaseBet(gameState.bank)
  end
end

return M
