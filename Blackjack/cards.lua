local M = {}

M.CARD_WIDTH = 60
M.CARD_HEIGHT = 90
M.CARD_SPACING = 70

function M.getSuitSymbol(suit)
  local symbols = {
    hearts = "♥",
    diamonds = "♦",
    clubs = "♣",
    spades = "♠"
  }
  return symbols[suit] or "?"
end

function M.getSuitColor(suit)
  if suit == "hearts" or suit == "diamonds" then
    return {0.9, 0.1, 0.1}
  else
    return {0.1, 0.1, 0.1}
  end
end

return M
