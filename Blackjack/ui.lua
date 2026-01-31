local M = {}
local cards = require("blackjack.cards")
local hand = require("blackjack.hand")
local bet = require("blackjack.bet")

local fonts = {}

M.buttons = {}

function M.load()
  fonts.small = love.graphics.newFont(14)
  fonts.normal = love.graphics.newFont(18)
  fonts.large = love.graphics.newFont(28)
end

function M.drawCard(card, x, y, faceDown)
  love.graphics.setColor(1, 1, 1)
  love.graphics.rectangle("fill", x, y, cards.CARD_WIDTH, cards.CARD_HEIGHT, 5)
  love.graphics.setColor(0, 0, 0)
  love.graphics.rectangle("line", x, y, cards.CARD_WIDTH, cards.CARD_HEIGHT, 5)

  if faceDown then
    love.graphics.setColor(0.2, 0.3, 0.6)
    love.graphics.rectangle("fill", x + 2, y + 2, cards.CARD_WIDTH - 4, cards.CARD_HEIGHT - 4, 5)
  else
    love.graphics.setFont(fonts.large)
    local color = cards.getSuitColor(card.suit)
    love.graphics.setColor(color)
    love.graphics.print(card.rank, x + 8, y + 8)

    love.graphics.setFont(fonts.normal)
    local symbol = cards.getSuitSymbol(card.suit)
    love.graphics.print(symbol, x + 8, y + cards.CARD_HEIGHT - 30)
  end
end

function M.drawHand(h, x, y, hideSecond)
  for i, card in ipairs(h.cards) do
    local cardX = x + (i - 1) * cards.CARD_SPACING
    local faceDown = hideSecond and i == 2
    M.drawCard(card, cardX, y, faceDown)
  end
end

function M.drawButton(text, x, y, width, height, enabled)
  if enabled then
    love.graphics.setColor(0.2, 0.6, 0.2)
  else
    love.graphics.setColor(0.3, 0.3, 0.3)
  end
  love.graphics.rectangle("fill", x, y, width, height, 5)

  love.graphics.setColor(1, 1, 1)
  love.graphics.rectangle("line", x, y, width, height, 5)

  love.graphics.setFont(fonts.normal)
  love.graphics.printf(text, x, y + height / 2 - 9, width, "center")

  return {x = x, y = y, width = width, height = height, enabled = enabled}
end

function M.drawGameUI(gameState)
  love.graphics.setBackgroundColor(0.1, 0.4, 0.1)

  love.graphics.setFont(fonts.normal)
  love.graphics.setColor(1, 1, 1)
  love.graphics.print("Dealer", 300, 20)

  if not gameState.dealer.holeCardRevealed and #gameState.dealer.hand.cards > 0 then
    M.drawHand(gameState.dealer.hand, 250, 50, true)
  else
    M.drawHand(gameState.dealer.hand, 250, 50, false)
    local dealerValue = hand.getValue(gameState.dealer.hand)
    love.graphics.print("Value: " .. dealerValue, 300, 160)
  end

  love.graphics.print("Player", 300, 220)
  local currentHand = gameState.player.hands[gameState.player.currentHandIndex]
  M.drawHand(currentHand, 250, 250, false)

  local playerValue = hand.getValue(currentHand)
  love.graphics.print("Value: " .. playerValue, 300, 360)

  love.graphics.print("Credits: $" .. gameState.betting.credits, 20, 450)
  love.graphics.print("Bet: $" .. gameState.betting.currentBet, 20, 480)

  if gameState.betting.insuranceBet > 0 then
    love.graphics.print("Insurance: $" .. gameState.betting.insuranceBet, 20, 510)
  end

  M.buttons = {}

  if gameState.state == "betting" then
    M.buttons.deal = M.drawButton("DEAL", 300, 450, 100, 40, bet.canPlaceBet(gameState.betting))

    M.buttons.betUp = M.drawButton("+BET", 450, 450, 80, 40, true)
    M.buttons.betDown = M.drawButton("-BET", 550, 450, 80, 40, true)

    local chipValue = bet.getSelectedChipValue(gameState.betting)
    love.graphics.print("Chip: $" .. chipValue, 450, 510)

  elseif gameState.state == "player_turn" then
    M.buttons.hit = M.drawButton("HIT", 200, 450, 80, 40, true)
    M.buttons.stand = M.drawButton("STAND", 300, 450, 80, 40, true)

    if gameState.player.canDouble then
      M.buttons.double = M.drawButton("DOUBLE", 400, 450, 80, 40, true)
    end

    if gameState.player.canSplit then
      M.buttons.split = M.drawButton("SPLIT", 500, 450, 80, 40, true)
    end

    if not gameState.insuranceOffered and gameState.dealer and
       #gameState.dealer.hand.cards > 0 and
       gameState.dealer.hand.cards[1].rank == "A" then
      M.buttons.insurance = M.drawButton("INSURANCE", 600, 450, 100, 40, true)
    end

  elseif gameState.state == "payout" then
    M.buttons.newRound = M.drawButton("NEW ROUND", 300, 450, 120, 40, true)

    if gameState.result then
      love.graphics.setFont(fonts.large)
      love.graphics.setColor(1, 1, 0)
      love.graphics.printf(gameState.result, 0, 400, 800, "center")
    end
  end
end

function M.checkButtonClick(x, y)
  for name, button in pairs(M.buttons) do
    if button.enabled and
       x >= button.x and x <= button.x + button.width and
       y >= button.y and y <= button.y + button.height then
      return name
    end
  end
  return nil
end

return M
