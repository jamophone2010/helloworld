local M = {}
local hand = require("blackjack.hand")

function M.new()
  return {
    hands = {hand.new()},
    currentHandIndex = 1,
    canDouble = false,
    canSplit = false,
    hasDoubled = false,
    hasSplit = false
  }
end

function M.getCurrentHand(player)
  return player.hands[player.currentHandIndex]
end

function M.nextHand(player)
  player.currentHandIndex = player.currentHandIndex + 1
  if player.currentHandIndex > #player.hands then
    return false
  end
  M.updateActions(player)
  return true
end

function M.updateActions(player)
  local currentHand = M.getCurrentHand(player)

  player.canDouble = #currentHand.cards == 2 and not player.hasDoubled
  player.canSplit = hand.canSplit(currentHand) and not player.hasSplit
end

function M.split(player, dealCard)
  if not player.canSplit then
    return false
  end

  local currentHand = M.getCurrentHand(player)
  local card = table.remove(currentHand.cards)

  local newHand = hand.new()
  hand.addCard(newHand, card)
  table.insert(player.hands, newHand)

  if dealCard then
    hand.addCard(currentHand, dealCard())
    hand.addCard(newHand, dealCard())
  end

  player.hasSplit = true
  player.canSplit = false
  M.updateActions(player)

  return true
end

function M.doubleDown(player)
  if not player.canDouble then
    return false
  end

  player.hasDoubled = true
  player.canDouble = false
  return true
end

function M.reset(player)
  player.hands = {hand.new()}
  player.currentHandIndex = 1
  player.canDouble = false
  player.canSplit = false
  player.hasDoubled = false
  player.hasSplit = false
end

return M
