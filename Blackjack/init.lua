local M = {}

local deck = require("blackjack.deck")
local hand = require("blackjack.hand")
local dealer = require("blackjack.dealer")
local player = require("blackjack.player")
local bet = require("blackjack.bet")
local audio = require("blackjack.audio")
local ui = require("blackjack.ui")

local gameState = {}

function M.load()
  gameState.deck = deck.new()
  gameState.dealer = dealer.new()
  gameState.player = player.new()
  gameState.betting = bet.new(1000)
  gameState.state = "betting"
  gameState.result = nil
  gameState.insuranceOffered = false

  audio.load()
  ui.load()
end

function M.update(dt)
end

function M.draw()
  ui.drawGameUI(gameState)
end

function M.dealCard()
  return deck.deal(gameState.deck)
end

function M.startRound()
  if not bet.placeBet(gameState.betting) then
    return
  end

  dealer.reset(gameState.dealer)
  player.reset(gameState.player)
  gameState.insuranceOffered = false

  local playerHand = player.getCurrentHand(gameState.player)

  hand.addCard(playerHand, M.dealCard())
  hand.addCard(gameState.dealer.hand, M.dealCard())
  hand.addCard(playerHand, M.dealCard())
  hand.addCard(gameState.dealer.hand, M.dealCard())

  player.updateActions(gameState.player)

  if hand.isBlackjack(playerHand) then
    gameState.state = "dealer_turn"
    M.dealerTurn()
  else
    gameState.state = "player_turn"
  end
end

function M.playerHit()
  local currentHand = player.getCurrentHand(gameState.player)
  hand.addCard(currentHand, M.dealCard())

  player.updateActions(gameState.player)

  if hand.isBust(currentHand) then
    if not player.nextHand(gameState.player) then
      gameState.state = "dealer_turn"
      M.dealerTurn()
    end
  end
end

function M.playerStand()
  if not player.nextHand(gameState.player) then
    gameState.state = "dealer_turn"
    M.dealerTurn()
  end
end

function M.playerDouble()
  if player.doubleDown(gameState.player) then
    if bet.canPlaceBet(gameState.betting) then
      gameState.betting.credits = gameState.betting.credits - gameState.betting.currentBet
      gameState.betting.currentBet = gameState.betting.currentBet * 2

      M.playerHit()

      if gameState.state ~= "dealer_turn" then
        M.playerStand()
      end
    end
  end
end

function M.playerSplit()
  if player.split(gameState.player, M.dealCard) then
    if bet.canPlaceBet(gameState.betting) then
      gameState.betting.credits = gameState.betting.credits - gameState.betting.currentBet
    end
  end
end

function M.playerInsurance()
  if bet.placeInsurance(gameState.betting) then
    gameState.insuranceOffered = true
  end
end

function M.dealerTurn()
  dealer.revealHoleCard(gameState.dealer)

  while dealer.shouldHit(gameState.dealer) do
    hand.addCard(gameState.dealer.hand, M.dealCard())
  end

  gameState.state = "payout"
  M.calculatePayout()
end

function M.calculatePayout()
  local currentHand = player.getCurrentHand(gameState.player)
  local dealerBlackjack = hand.isBlackjack(gameState.dealer.hand)

  local payout, result = bet.calculatePayout(
    gameState.betting,
    currentHand,
    gameState.dealer.hand,
    dealerBlackjack
  )

  gameState.result = result

  if payout > 0 then
    audio.playWin()
  else
    audio.playLose()
  end
end

function M.newRound()
  gameState.state = "betting"
  gameState.result = nil
  gameState.betting.insuranceBet = 0
end

function M.keypressed(key)
  if key == "up" then
    bet.nextChip(gameState.betting)
  elseif key == "down" then
    bet.prevChip(gameState.betting)
  end
end

function M.mousepressed(x, y, button)
  if button == 1 then
    local buttonName = ui.checkButtonClick(x, y)

    if buttonName == "deal" then
      M.startRound()
    elseif buttonName == "hit" then
      M.playerHit()
    elseif buttonName == "stand" then
      M.playerStand()
    elseif buttonName == "double" then
      M.playerDouble()
    elseif buttonName == "split" then
      M.playerSplit()
    elseif buttonName == "insurance" then
      M.playerInsurance()
    elseif buttonName == "betUp" then
      bet.increaseBet(gameState.betting)
    elseif buttonName == "betDown" then
      bet.decreaseBet(gameState.betting)
    elseif buttonName == "newRound" then
      M.newRound()
    end
  end
end

return M
