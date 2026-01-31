local M = {}
local hand = require("blackjack.hand")

function M.new()
  return {
    hand = hand.new(),
    holeCardRevealed = false
  }
end

function M.shouldHit(dealer)
  local value = hand.getValue(dealer.hand)
  return value < 17
end

function M.revealHoleCard(dealer)
  dealer.holeCardRevealed = true
end

function M.reset(dealer)
  hand.clear(dealer.hand)
  dealer.holeCardRevealed = false
end

function M.showsAce(dealer)
  if #dealer.hand.cards > 0 then
    return dealer.hand.cards[1].rank == "A"
  end
  return false
end

return M
