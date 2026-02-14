local M = {}

local NUM_PAYLINES = 5

M.CHIP_VALUES = {1, 5, 10, 25, 100, 1000, 5000, 10000, 100000, 1000000}
M.CHIP_COLORS = {
  [1] = {1, 1, 1},          -- White
  [5] = {1, 0.1, 0.1},      -- Red
  [10] = {0.1, 0.1, 1},     -- Blue
  [25] = {0.1, 0.8, 0.1},   -- Green
  [100] = {0.1, 0.1, 0.1},  -- Black
  [1000] = {0.5, 0.1, 0.5}, -- Purple
  [5000] = {1, 0.5, 0},     -- Orange
  [10000] = {0.8, 0.8, 0.1},-- Yellow
  [100000] = {0.8, 0.4, 0.2},-- Brown
  [1000000] = {0.9, 0.7, 0.2}-- Gold
}
M.CHIP_LABELS = {
  [1] = "1",
  [5] = "5",
  [10] = "10",
  [25] = "25",
  [100] = "100",
  [1000] = "1K",
  [5000] = "5K",
  [10000] = "10K",
  [100000] = "100K",
  [1000000] = "1M"
}

function M.new(startingCredits)
  return {
    credits = startingCredits or 100,
    currentBet = 1,
    selectedChipIndex = 1
  }
end

function M.getSelectedChipValue(bank)
  return M.CHIP_VALUES[bank.selectedChipIndex]
end

function M.getChipColor(value)
  return M.CHIP_COLORS[value] or {0.5, 0.5, 0.5}
end

function M.getChipLabel(value)
  return M.CHIP_LABELS[value] or tostring(value)
end

-- Convert an amount into optimal chip stack
function M.getChipStack(amount)
  local stack = {}
  local remaining = amount
  
  for i = #M.CHIP_VALUES, 1, -1 do
    local chipValue = M.CHIP_VALUES[i]
    local count = math.floor(remaining / chipValue)
    if count > 0 then
      table.insert(stack, {value = chipValue, count = count})
      remaining = remaining - (count * chipValue)
    end
  end
  
  return stack
end

function M.getTotalBet(bank)
  return bank.currentBet * NUM_PAYLINES
end

function M.canPlaceBet(bank)
  return bank.credits >= M.getTotalBet(bank) and bank.currentBet > 0
end

function M.placeBet(bank)
  local totalBet = M.getTotalBet(bank)
  if not M.canPlaceBet(bank) then
    return false
  end
  bank.credits = bank.credits - totalBet
  return true
end

function M.addWinnings(bank, amount)
  bank.credits = bank.credits + amount
end

function M.canAfford(bank, amount)
  return bank.credits >= amount
end

function M.increaseBet(bank)
  local chipValue = M.getSelectedChipValue(bank)
  bank.currentBet = bank.currentBet + chipValue
end

function M.decreaseBet(bank)
  local chipValue = M.getSelectedChipValue(bank)
  bank.currentBet = math.max(0, bank.currentBet - chipValue)
end

function M.nextChip(bank)
  local startIndex = bank.selectedChipIndex
  repeat
    bank.selectedChipIndex = bank.selectedChipIndex + 1
    if bank.selectedChipIndex > #M.CHIP_VALUES then
      bank.selectedChipIndex = 1
    end
  until M.canAfford(bank, M.CHIP_VALUES[bank.selectedChipIndex]) or bank.selectedChipIndex == startIndex
end

function M.prevChip(bank)
  local startIndex = bank.selectedChipIndex
  repeat
    bank.selectedChipIndex = bank.selectedChipIndex - 1
    if bank.selectedChipIndex < 1 then
      bank.selectedChipIndex = #M.CHIP_VALUES
    end
  until M.canAfford(bank, M.CHIP_VALUES[bank.selectedChipIndex]) or bank.selectedChipIndex == startIndex
end

return M
