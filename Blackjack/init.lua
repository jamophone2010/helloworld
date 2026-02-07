local M = {}

local deck = require("blackjack.deck")
local hand = require("blackjack.hand")
local dealer = require("blackjack.dealer")
local player = require("blackjack.player")
local bet = require("blackjack.bet")
local audio = require("blackjack.audio")
local ui = require("blackjack.ui")

local gameState = {}
local animations = {}
local dealQueue = {}

-- Animation constants
local DEAL_SPEED = 800 -- pixels per second
local DEAL_DELAY = 0.3 -- seconds between each card
local DECK_X, DECK_Y = 370, 20 -- deck position (top center)

function M.load(startingCredits)
  -- Seed random number generator for card shuffling
  math.randomseed(os.time())
  math.random(); math.random(); math.random() -- Discard first few values for better randomness
  
  gameState.deck = deck.new()
  gameState.dealer = dealer.new()
  gameState.player = player.new()
  gameState.betting = bet.new(startingCredits or 1000)
  gameState.state = "betting"
  gameState.result = nil
  gameState.insuranceOffered = false
  gameState.shuffleAnimation = { active = false, timer = 0, duration = 1.5 }
  animations = {}
  dealQueue = {}

  audio.load()
  ui.load()
end

local function createCardAnimation(card, startX, startY, endX, endY, target, isHoleCard)
  local distance = math.sqrt((endX - startX)^2 + (endY - startY)^2)
  local duration = distance / DEAL_SPEED
  
  return {
    card = card,
    startX = startX,
    startY = startY,
    endX = endX,
    endY = endY,
    currentX = startX,
    currentY = startY,
    duration = duration,
    elapsed = 0,
    target = target,
    isHoleCard = isHoleCard or false,
    completed = false
  }
end

local function getCardPosition(target, cardIndex, handIndex)
  local cards = require("blackjack.cards")
  local x, y
  
  if target == "dealer" then
    x = 320 + (cardIndex - 1) * cards.CARD_SPACING
    y = 140
  else -- player
    local baseX = 320
    local xOffset = 0
    
    -- Calculate offset for split hands: left 200px, right 200px
    if handIndex and gameState.player and #gameState.player.hands > 1 then
      xOffset = (handIndex == 1) and -200 or 200
    end
    
    x = baseX + xOffset + (cardIndex - 1) * cards.CARD_SPACING
    y = 330
  end
  
  return x, y
end

local function dealCardAnimated(target, cardIndex, delay, isHoleCard, handIndex)
  table.insert(dealQueue, {
    target = target,
    cardIndex = cardIndex,
    timer = delay or 0,
    isHoleCard = isHoleCard or false,
    handIndex = handIndex or 1
  })
end

function M.getCredits()
  return gameState.betting.credits
end

function M.update(dt)
  -- Handle shuffle animation
  if gameState.shuffleAnimation.active then
    gameState.shuffleAnimation.timer = gameState.shuffleAnimation.timer + dt
    if gameState.shuffleAnimation.timer >= gameState.shuffleAnimation.duration then
      gameState.shuffleAnimation.active = false
      gameState.shuffleAnimation.timer = 0
    end
  end
  
  -- Update card animations
  for i = #animations, 1, -1 do
    local anim = animations[i]
    anim.elapsed = anim.elapsed + dt
    
    if anim.elapsed >= anim.duration then
      -- Animation completed
      anim.currentX = anim.endX
      anim.currentY = anim.endY
      anim.completed = true
      
      -- Add card to the actual hand
      if anim.target == "dealer" then
        hand.addCard(gameState.dealer.hand, anim.card)
      else
        local playerHand = player.getCurrentHand(gameState.player)
        hand.addCard(playerHand, anim.card)
      end
      
      table.remove(animations, i)
      audio.playDeal()
    else
      -- Interpolate position
      local progress = anim.elapsed / anim.duration
      -- Use easing function for smoother animation
      progress = progress * progress * (3 - 2 * progress) -- smoothstep
      
      anim.currentX = anim.startX + (anim.endX - anim.startX) * progress
      anim.currentY = anim.startY + (anim.endY - anim.startY) * progress
    end
  end
  
  -- Process deal queue
  if #dealQueue > 0 and #animations == 0 then
    local nextDeal = table.remove(dealQueue, 1)
    nextDeal.timer = nextDeal.timer - dt
    
    if nextDeal.timer <= 0 then
      local card = M.dealCard()
      if card then
        local endX, endY = getCardPosition(nextDeal.target, nextDeal.cardIndex, nextDeal.handIndex)
        local anim = createCardAnimation(card, DECK_X, DECK_Y, endX, endY, nextDeal.target, nextDeal.isHoleCard)
        table.insert(animations, anim)
      end
    else
      -- Put it back at the front if not ready yet
      table.insert(dealQueue, 1, nextDeal)
    end
  end
  
  -- Handle game state transitions after dealing
  if gameState.dealCompleteTimer then
    gameState.dealCompleteTimer = gameState.dealCompleteTimer - dt
    if gameState.dealCompleteTimer <= 0 and #animations == 0 and #dealQueue == 0 then
      gameState.dealCompleteTimer = nil
      
      player.updateActions(gameState.player)
      local playerHand = player.getCurrentHand(gameState.player)
      
      if hand.isBlackjack(playerHand) then
        gameState.state = "dealer_turn"
        M.dealerTurn()
      else
        gameState.state = "player_turn"
      end
    end
  end
  
  if gameState.hitCompleteTimer then
    gameState.hitCompleteTimer = gameState.hitCompleteTimer - dt
    if gameState.hitCompleteTimer <= 0 and #animations == 0 and #dealQueue == 0 then
      gameState.hitCompleteTimer = nil
      
      local currentHand = player.getCurrentHand(gameState.player)
      player.updateActions(gameState.player)
      
      if hand.isBust(currentHand) then
        if not player.nextHand(gameState.player) then
          -- Check if all hands are busted - if so, skip dealer turn
          local allBusted = true
          for _, h in ipairs(gameState.player.hands) do
            if not hand.isBust(h) then
              allBusted = false
              break
            end
          end
          
          if allBusted then
            -- All hands busted, go straight to payout
            gameState.state = "payout"
            M.calculatePayout()
          else
            -- At least one hand is not busted, dealer plays
            gameState.state = "dealer_turn"
            M.dealerTurn()
          end
        else
          gameState.state = "player_turn"
        end
      else
        gameState.state = "player_turn"
      end
    end
  end
  
  if gameState.dealerHitTimer then
    gameState.dealerHitTimer = gameState.dealerHitTimer - dt
    if gameState.dealerHitTimer <= 0 and #animations == 0 and #dealQueue == 0 then
      gameState.dealerHitTimer = nil
      
      if dealer.shouldHit(gameState.dealer) then
        local cardIndex = #gameState.dealer.hand.cards + 1
        gameState.state = "dealing"
        dealCardAnimated("dealer", cardIndex, 0)
        gameState.dealerHitTimer = 0.8
      else
        gameState.state = "payout"
        M.calculatePayout()
      end
    end
  end
end

function M.draw()
  ui.drawGameUI(gameState, animations)
end

function M.dealCard()
  local card = deck.deal(gameState.deck)
  -- Check if deck was reset (shuffled)
  if deck.cardsRemaining(gameState.deck) == 52 then
    gameState.shuffleAnimation.active = true
    gameState.shuffleAnimation.timer = 0
  end
  return card
end

function M.startRound()
  if not bet.placeBet(gameState.betting) then
    return
  end

  dealer.reset(gameState.dealer)
  player.reset(gameState.player)
  gameState.insuranceOffered = false
  animations = {}
  dealQueue = {}

  gameState.state = "dealing"
  
  -- Queue up the initial deal with timing
  dealCardAnimated("player", 1, 0, false, 1)
  dealCardAnimated("dealer", 1, DEAL_DELAY)
  dealCardAnimated("player", 2, DEAL_DELAY * 2, false, 1)
  dealCardAnimated("dealer", 2, DEAL_DELAY * 3, true)
  
  -- Set a timer to check for game state after dealing
  gameState.dealCompleteTimer = DEAL_DELAY * 4 + 1 -- extra time for animation
end

function M.playerHit()
  if gameState.state ~= "player_turn" or #animations > 0 then
    return -- Don't allow actions during animations
  end
  
  local currentHand = player.getCurrentHand(gameState.player)
  local cardIndex = #currentHand.cards + 1
  
  gameState.state = "dealing"
  dealCardAnimated("player", cardIndex, 0, false, gameState.player.currentHandIndex)
  
  gameState.hitCompleteTimer = 0.8 -- time to wait before checking bust
end

function M.playerStand()
  if gameState.state ~= "player_turn" or #animations > 0 then
    return -- Don't allow actions during animations
  end
  
  if not player.nextHand(gameState.player) then
    gameState.state = "dealer_turn"
    M.dealerTurn()
  end
end

function M.playerDouble()
  if gameState.state ~= "player_turn" or #animations > 0 then
    return -- Don't allow actions during animations
  end
  
  if player.doubleDown(gameState.player) then
    if bet.canPlaceBet(gameState.betting) then
      gameState.betting.credits = gameState.betting.credits - gameState.betting.currentBet
      gameState.betting.currentBet = gameState.betting.currentBet * 2

      M.playerHit()

      if gameState.state ~= "dealer_turn" then
        M.playerStand()
      end
    end
  end
end

function M.playerSplit()
  if player.split(gameState.player, M.dealCard) then
    if bet.canPlaceBet(gameState.betting) then
      gameState.betting.credits = gameState.betting.credits - gameState.betting.currentBet
    end
  end
end

function M.playerInsurance()
  if bet.placeInsurance(gameState.betting) then
    gameState.insuranceOffered = true
  end
end

function M.dealerTurn()
  dealer.revealHoleCard(gameState.dealer)

  local function dealNextCard()
    if dealer.shouldHit(gameState.dealer) then
      local cardIndex = #gameState.dealer.hand.cards + 1
      gameState.state = "dealing"
      dealCardAnimated("dealer", cardIndex, 0)
      gameState.dealerHitTimer = 0.8
    else
      gameState.state = "payout"
      M.calculatePayout()
    end
  end
  
  dealNextCard()
end

function M.calculatePayout()
  local dealerBlackjack = hand.isBlackjack(gameState.dealer.hand)
  local totalPayout = 0
  local results = {}
  local payouts = {}

  for i, playerHand in ipairs(gameState.player.hands) do
    local payout, result = bet.calculatePayout(
      gameState.betting,
      playerHand,
      gameState.dealer.hand,
      dealerBlackjack
    )
    totalPayout = totalPayout + payout
    
    -- Store result and payout for each hand
    if #gameState.player.hands > 1 then
      table.insert(results, "Hand " .. i .. ": " .. result)
    else
      table.insert(results, result)
    end
    table.insert(payouts, payout)
  end

  -- Combine results for display
  gameState.result = table.concat(results, " | ")
  gameState.payouts = payouts
  gameState.player.currentHandIndex = 1

  if totalPayout > 0 then
    audio.playWin()
  else
    audio.playLose()
  end
end

function M.newRound()
  gameState.state = "betting"
  gameState.result = nil
  gameState.betting.currentBet = 0
  gameState.betting.insuranceBet = 0
end

function M.keypressed(key)
  if key == "up" then
    bet.nextChip(gameState.betting)
  elseif key == "down" then
    bet.prevChip(gameState.betting)
  elseif key == "space" then
    -- Spacebar to deal
    if gameState.state == "betting" then
      M.startRound()
    end
  end
end

function M.mousepressed(x, y, button)
  if button == 1 then
    local buttonName = ui.checkButtonClick(x, y)

    if buttonName == "deal" then
      M.startRound()
    elseif buttonName == "hit" then
      M.playerHit()
    elseif buttonName == "stand" then
      M.playerStand()
    elseif buttonName == "double" then
      M.playerDouble()
    elseif buttonName == "split" then
      M.playerSplit()
    elseif buttonName == "insurance" then
      M.playerInsurance()
    elseif buttonName == "betUp" then
      bet.increaseBet(gameState.betting)
    elseif buttonName == "betDown" then
      bet.decreaseBet(gameState.betting)
    elseif buttonName == "newRound" then
      M.newRound()
    end
  end
end

return M
