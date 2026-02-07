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

function M.drawPokerChip(x, y, value, stackHeight)
  local radius = 14
  local color = bet.getChipColor(value)
  local label = bet.getChipLabel(value)

  stackHeight = stackHeight or 0

  -- Draw chip shadow for depth effect
  love.graphics.setColor(0, 0, 0, 0.3)
  love.graphics.circle("fill", x + 2, y + 2 + stackHeight, radius)

  -- Draw main chip body
  love.graphics.setColor(color[1], color[2], color[3])
  love.graphics.circle("fill", x, y + stackHeight, radius)

  -- Draw chip edge (darker)
  love.graphics.setColor(color[1] * 0.7, color[2] * 0.7, color[3] * 0.7)
  love.graphics.circle("line", x, y + stackHeight, radius)
  love.graphics.setLineWidth(2)
  love.graphics.circle("line", x, y + stackHeight, radius - 2)
  love.graphics.setLineWidth(1)

  -- Draw inner circle for detail
  love.graphics.setColor(1, 1, 1)
  love.graphics.circle("line", x, y + stackHeight, radius - 4)

  -- Draw value text
  love.graphics.setFont(fonts.small)
  if value == 1 or value == 25 or value == 10000 or value == 1000000 then
    love.graphics.setColor(0, 0, 0)
  else
    love.graphics.setColor(1, 1, 1)
  end
  local textWidth = fonts.small:getWidth(label)
  love.graphics.print(label, x - textWidth / 2, y + stackHeight - 7)
end

function M.drawChipStack(x, y, stack)
  local totalHeight = 0

  for i, chip in ipairs(stack) do
    for j = 1, math.min(chip.count, 10) do
      M.drawPokerChip(x, y, chip.value, -totalHeight)
      totalHeight = totalHeight + 3
    end

    if chip.count > 10 then
      love.graphics.setFont(fonts.small)
      love.graphics.setColor(1, 1, 0)
      love.graphics.print("x" .. chip.count, x + 18, y - totalHeight - 5)
    end
  end
end

function M.drawGameUI(gameState, animations)
  love.graphics.setBackgroundColor(0.05, 0.3, 0.05)
  
  -- Draw blackjack table felt (curved top edge)
  love.graphics.setColor(0.1, 0.5, 0.1)
  love.graphics.rectangle("fill", 50, 150, 700, 450, 15)
  
  -- Draw table arc at top for dealer position
  love.graphics.setColor(0.12, 0.55, 0.12)
  love.graphics.arc("fill", 400, 150, 200, math.pi, 2 * math.pi)
  
  -- Draw betting circle for player
  love.graphics.setColor(0.9, 0.8, 0.1)
  love.graphics.setLineWidth(3)
  love.graphics.circle("line", 400, 450, 50)
  love.graphics.setLineWidth(1)
  
  -- Draw "BLACKJACK PAYS 3:2" text on table
  love.graphics.setFont(fonts.small)
  love.graphics.setColor(0.9, 0.8, 0.1)
  love.graphics.printf("BLACKJACK PAYS 3:2", 0, 300, 800, "center")
  
  -- Dealer section at top
  love.graphics.setFont(fonts.normal)
  love.graphics.setColor(1, 1, 1)
  love.graphics.print("DEALER", 50, 10)
  
  -- Draw deck at top center as stacked cards
  local cardsRemaining = gameState.deck and (#gameState.deck.cards) or 52
  local maxStackHeight = 8 -- Maximum visible stacked cards
  local stackCount = math.min(maxStackHeight, math.ceil(cardsRemaining / 6.5))
  
  -- Draw shuffling animation if active
  if gameState.shuffleAnimation and gameState.shuffleAnimation.active then
    local progress = gameState.shuffleAnimation.timer / gameState.shuffleAnimation.duration
    local wobble = math.sin(progress * math.pi * 8) * 5
    love.graphics.push()
    love.graphics.translate(wobble, 0)
  end
  
  -- Draw stacked cards
  for i = 1, stackCount do
    local offsetY = (stackCount - i) * 2
    local offsetX = (stackCount - i) * 1
    love.graphics.setColor(0.2, 0.2, 0.2)
    love.graphics.rectangle("fill", 370 + offsetX, 20 + offsetY, cards.CARD_WIDTH, cards.CARD_HEIGHT, 5)
    love.graphics.setColor(0.8, 0.8, 0.8)
    love.graphics.rectangle("line", 370 + offsetX, 20 + offsetY, cards.CARD_WIDTH, cards.CARD_HEIGHT, 5)
  end
  
  if gameState.shuffleAnimation and gameState.shuffleAnimation.active then
    love.graphics.pop()
    -- Show "SHUFFLING..." text
    love.graphics.setFont(fonts.small)
    love.graphics.setColor(1, 1, 0)
    love.graphics.print("SHUFFLING...", 360, 5)
  end

  -- Draw dealer's hand below deck
  if not gameState.dealer.holeCardRevealed and #gameState.dealer.hand.cards > 0 then
    M.drawHand(gameState.dealer.hand, 320, 140, true)
  else
    M.drawHand(gameState.dealer.hand, 320, 140, false)
  end

  -- Draw player's hand in center-bottom area
  -- Always draw all player hands
  for i, h in ipairs(gameState.player.hands) do
    local xOffset = 0
    if #gameState.player.hands > 1 then
      -- For split hands: left hand 200px left, right hand 200px right
      xOffset = (i == 1) and -200 or 200
    end
    local handX = 320 + xOffset
    
    -- Draw yellow box around active hand during player turn
    if gameState.state == "player_turn" and i == gameState.player.currentHandIndex then
      love.graphics.setColor(1, 1, 0, 1)
      love.graphics.setLineWidth(3)
      local cards = require("blackjack.cards")
      local handWidth = #h.cards * cards.CARD_SPACING + cards.CARD_WIDTH - cards.CARD_SPACING
      love.graphics.rectangle("line", handX - 5, 325, handWidth + 10, cards.CARD_HEIGHT + 10, 5)
      love.graphics.setLineWidth(1)
    end
    
    M.drawHand(h, handX, 330, false)
  end

  -- Draw credits and bet in bottom left
  love.graphics.setFont(fonts.small)
  love.graphics.setColor(0, 0, 0)
  love.graphics.print("Credits: " .. gameState.betting.credits, 60, 520)

  -- Draw current bet as chip stack in betting circle
  if gameState.betting.currentBet > 0 then
    local betStack = bet.getChipStack(gameState.betting.currentBet)
    M.drawChipStack(400, 450, betStack)
    love.graphics.setFont(fonts.small)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("Bet: " .. gameState.betting.currentBet, 350, 470, 100, "center")
  end

  if gameState.betting.insuranceBet > 0 then
    love.graphics.setFont(fonts.normal)
    love.graphics.print("Insurance: " .. gameState.betting.insuranceBet, 20, 550)
  end

  M.buttons = {}

  if gameState.state == "betting" then
    M.buttons.deal = M.drawButton("DEAL", 350, 660, 100, 40, bet.canPlaceBet(gameState.betting))

    M.buttons.betUp = M.drawButton("+BET", 500, 660, 80, 40, true)
    M.buttons.betDown = M.drawButton("-BET", 600, 660, 80, 40, true)

    -- Draw chip selector with visual chips in two rows at bottom right
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Select Chip (UP/DOWN):", 500, 500)
    local chipX = 500
    local chipRow = 1
    for i, value in ipairs(bet.CHIP_VALUES) do
      if bet.canAfford(gameState.betting, value) then
        local chipY = (chipRow == 1) and 540 or 575
        if i == gameState.betting.selectedChipIndex then
          love.graphics.setColor(1, 1, 0, 0.3)
          love.graphics.circle("fill", chipX + 14, chipY, 18)
        end
        M.drawPokerChip(chipX + 14, chipY, value)
        chipX = chipX + 35
        if chipX > 660 and chipRow == 1 then
          chipX = 500
          chipRow = 2
        end
      end
    end

  elseif gameState.state == "player_turn" then
    local canAct = #(animations or {}) == 0 -- Disable buttons during animations
    local currentHand = gameState.player.hands[gameState.player.currentHandIndex]
    local handValue = currentHand and hand.getValue(currentHand) or 0
    local canHit = canAct and handValue < 21
    
    M.buttons.hit = M.drawButton("HIT", 200, 660, 80, 40, canHit)
    M.buttons.stand = M.drawButton("STAND", 300, 660, 80, 40, canAct)

    if gameState.player.canDouble then
      M.buttons.double = M.drawButton("DOUBLE", 400, 660, 80, 40, canAct)
    end

    if gameState.player.canSplit then
      M.buttons.split = M.drawButton("SPLIT", 500, 660, 80, 40, canAct)
    end

    if not gameState.insuranceOffered and gameState.dealer and
       #gameState.dealer.hand.cards > 0 and
       gameState.dealer.hand.cards[1].rank == "A" then
      M.buttons.insurance = M.drawButton("INSURANCE", 580, 660, 120, 40, canAct)
    end
    
  elseif gameState.state == "dealing" then
    -- Cards are being dealt with animations
    -- No status text needed

  elseif gameState.state == "payout" then
    M.buttons.newRound = M.drawButton("NEW ROUND", 300, 660, 120, 40, true)

    if gameState.result then
      love.graphics.setFont(fonts.large)
      love.graphics.setColor(1, 1, 0)
      love.graphics.printf(gameState.result, 0, 490, 800, "center")
      
      -- Display payout amounts
      if gameState.payouts then
        love.graphics.setFont(fonts.normal)
        if #gameState.payouts == 1 then
          local payout = gameState.payouts[1]
          if payout > 0 then
            love.graphics.setColor(0, 1, 0)
            love.graphics.printf("Won: +" .. payout .. " credits", 0, 530, 800, "center")
          end
        else
          -- For split hands, show each payout (only if positive)
          local yOffset = 0
          for i, payout in ipairs(gameState.payouts) do
            if payout > 0 then
              love.graphics.setColor(0, 1, 0)
              love.graphics.printf("Hand " .. i .. ": +" .. payout, 0, 530 + yOffset, 800, "center")
              yOffset = yOffset + 25
            end
          end
        end
      end
    end
  end
  
  -- Draw animated cards on top
  if animations then
    for _, anim in ipairs(animations) do
      M.drawCard(anim.card, anim.currentX, anim.currentY, anim.isHoleCard)
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
