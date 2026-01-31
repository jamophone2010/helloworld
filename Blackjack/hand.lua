local M = {}
local deck = require("blackjack.deck")

function M.new()
  return {
    cards = {}
  }
end

function M.addCard(hand, card)
  table.insert(hand.cards, card)
end

function M.getValue(hand)
  local value = 0
  local aces = 0

  for _, card in ipairs(hand.cards) do
    local cardValue = deck.getCardValue(card)
    if card.rank == "A" then
      aces = aces + 1
    end
    value = value + cardValue
  end

  while value > 21 and aces > 0 do
    value = value - 10
    aces = aces - 1
  end

  return value
end

function M.isBust(hand)
  return M.getValue(hand) > 21
end

function M.isBlackjack(hand)
  if #hand.cards ~= 2 then
    return false
  end

  local value = M.getValue(hand)
  return value == 21
end

function M.isSoft(hand)
  local value = 0
  local hasAce = false

  for _, card in ipairs(hand.cards) do
    local cardValue = deck.getCardValue(card)
    if card.rank == "A" then
      hasAce = true
    end
    value = value + cardValue
  end

  return hasAce and value <= 21
end

function M.canSplit(hand)
  if #hand.cards ~= 2 then
    return false
  end

  return deck.getCardValue(hand.cards[1]) == deck.getCardValue(hand.cards[2])
end

function M.clear(hand)
  hand.cards = {}
end

return M
