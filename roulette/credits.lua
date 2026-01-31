local M = {}

M.CHIP_VALUES = {1, 5, 10, 25, 100}

function M.new(startingCredits)
  return {
    balance = startingCredits or 1000,
    selectedChipIndex = 1
  }
end

function M.getSelectedChipValue(bank)
  return M.CHIP_VALUES[bank.selectedChipIndex]
end

function M.canAfford(bank, amount)
  return bank.balance >= amount
end

function M.deduct(bank, amount)
  if not M.canAfford(bank, amount) then
    return false
  end
  bank.balance = bank.balance - amount
  return true
end

function M.add(bank, amount)
  bank.balance = bank.balance + amount
end

function M.nextChip(bank)
  bank.selectedChipIndex = bank.selectedChipIndex + 1
  if bank.selectedChipIndex > #M.CHIP_VALUES then
    bank.selectedChipIndex = 1
  end
end

function M.prevChip(bank)
  bank.selectedChipIndex = bank.selectedChipIndex - 1
  if bank.selectedChipIndex < 1 then
    bank.selectedChipIndex = #M.CHIP_VALUES
  end
end

return M
