local M = {}
local hand = require("blackjack.hand")

M.CHIP_VALUES = {5, 10, 25, 50, 100}

function M.new(startingCredits)
  return {
    credits = startingCredits or 1000,
    currentBet = 10,
    insuranceBet = 0,
    selectedChipIndex = 2
  }
end

function M.getSelectedChipValue(betting)
  return M.CHIP_VALUES[betting.selectedChipIndex]
end

function M.increaseBet(betting)
  local chipValue = M.getSelectedChipValue(betting)
  if betting.credits >= betting.currentBet + chipValue then
    betting.currentBet = betting.currentBet + chipValue
  end
end

function M.decreaseBet(betting)
  local chipValue = M.getSelectedChipValue(betting)
  betting.currentBet = math.max(5, betting.currentBet - chipValue)
end

function M.nextChip(betting)
  betting.selectedChipIndex = betting.selectedChipIndex + 1
  if betting.selectedChipIndex > #M.CHIP_VALUES then
    betting.selectedChipIndex = 1
  end
end

function M.prevChip(betting)
  betting.selectedChipIndex = betting.selectedChipIndex - 1
  if betting.selectedChipIndex < 1 then
    betting.selectedChipIndex = #M.CHIP_VALUES
  end
end

function M.canPlaceBet(betting)
  return betting.credits >= betting.currentBet
end

function M.placeBet(betting)
  if not M.canPlaceBet(betting) then
    return false
  end
  betting.credits = betting.credits - betting.currentBet
  return true
end

function M.placeInsurance(betting)
  local insuranceAmount = math.floor(betting.currentBet / 2)
  if betting.credits >= insuranceAmount then
    betting.credits = betting.credits - insuranceAmount
    betting.insuranceBet = insuranceAmount
    return true
  end
  return false
end

function M.calculatePayout(betting, playerHand, dealerHand, dealerBlackjack)
  local payout = 0
  local result = ""

  if betting.insuranceBet > 0 then
    if dealerBlackjack then
      payout = payout + betting.insuranceBet * 3
      result = "Insurance pays 2:1"
    end
    betting.insuranceBet = 0
  end

  local playerValue = hand.getValue(playerHand)
  local dealerValue = hand.getValue(dealerHand)
  local playerBJ = hand.isBlackjack(playerHand)
  local playerBust = hand.isBust(playerHand)
  local dealerBust = hand.isBust(dealerHand)

  if playerBust then
    result = "Bust - Dealer wins"
  elseif playerBJ and not dealerBlackjack then
    payout = payout + math.floor(betting.currentBet * 2.5)
    result = "Blackjack! Pays 3:2"
  elseif dealerBust then
    payout = payout + betting.currentBet * 2
    result = "Dealer busts - You win!"
  elseif playerValue > dealerValue then
    payout = payout + betting.currentBet * 2
    result = "You win!"
  elseif playerValue == dealerValue then
    payout = payout + betting.currentBet
    result = "Push"
  else
    result = "Dealer wins"
  end

  betting.credits = betting.credits + payout
  return payout, result
end

return M
