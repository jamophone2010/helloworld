local M = {}

local SUITS = {"hearts", "diamonds", "clubs", "spades"}
local RANKS = {"A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"}

function M.new()
  local deck = {
    cards = {}
  }
  M.reset(deck)
  return deck
end

function M.reset(deck)
  deck.cards = {}
  for _, suit in ipairs(SUITS) do
    for _, rank in ipairs(RANKS) do
      table.insert(deck.cards, {suit = suit, rank = rank})
    end
  end
  M.shuffle(deck)
end

function M.shuffle(deck)
  for i = #deck.cards, 2, -1 do
    local j = math.random(i)
    deck.cards[i], deck.cards[j] = deck.cards[j], deck.cards[i]
  end
end

function M.deal(deck)
  if #deck.cards < 10 then
    M.reset(deck)
  end
  return table.remove(deck.cards)
end

function M.getCardValue(card)
  if card.rank == "A" then
    return 11
  elseif card.rank == "J" or card.rank == "Q" or card.rank == "K" then
    return 10
  else
    return tonumber(card.rank)
  end
end

function M.cardsRemaining(deck)
  return #deck.cards
end

return M
