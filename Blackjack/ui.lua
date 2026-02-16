local M = {}
local cards = require("blackjack.cards")
local hand = require("blackjack.hand")
local bet = require("blackjack.bet")
local winFx = require("casino_win_fx")

local fonts = {}
local uiTime = 0 -- Accumulated time for animations

M.buttons = {}

function M.load()
  fonts.small = love.graphics.newFont("fonts/Exo2-Regular.ttf", 12)
  fonts.normal = love.graphics.newFont("fonts/Exo2-Regular.ttf", 16)
  fonts.large = love.graphics.newFont("fonts/Exo2-Regular.ttf", 26)
  fonts.tableText = love.graphics.newFont(13)
  fonts.cardRank = love.graphics.newFont(22)
  fonts.title = love.graphics.newFont(11)
end

-- ─── TABLE COLORS ─────────────────────────────────────────────
local TABLE = {
  felt        = {0.04, 0.32, 0.12},      -- Deep casino green felt
  feltLight   = {0.06, 0.38, 0.15},      -- Lighter felt accent
  feltDark    = {0.02, 0.22, 0.08},      -- Darker felt shadow
  border      = {0.35, 0.22, 0.08},      -- Rich mahogany rail
  borderLight = {0.5, 0.35, 0.15},       -- Rail highlight
  borderDark  = {0.2, 0.12, 0.04},       -- Rail shadow
  gold        = {0.85, 0.72, 0.2},       -- Gold text/lines
  goldDim     = {0.65, 0.55, 0.18, 0.6}, -- Dimmed gold for subtle lines
  silver      = {0.75, 0.78, 0.82},      -- Silver accents
  cream       = {0.95, 0.92, 0.85},      -- Cream text
}

-- ─── CARD RENDERING ──────────────────────────────────────────

-- Draw a realistic card back pattern
local function drawCardBack(x, y, w, h)
  -- Outer card shape (cream border)
  love.graphics.setColor(0.92, 0.9, 0.85)
  love.graphics.rectangle("fill", x, y, w, h, 6)

  -- Card back (deep red/blue)
  local margin = 3
  love.graphics.setColor(0.12, 0.18, 0.45)
  love.graphics.rectangle("fill", x + margin, y + margin, w - margin * 2, h - margin * 2, 4)

  -- Diamond pattern overlay
  love.graphics.setColor(0.16, 0.24, 0.55, 0.6)
  local step = 10
  for py = y + margin + 5, y + h - margin - 5, step do
    for px = x + margin + 5, x + w - margin - 5, step do
      love.graphics.polygon("fill",
        px, py - 4,
        px + 4, py,
        px, py + 4,
        px - 4, py
      )
    end
  end

  -- Center ornament
  local cx, cy = x + w / 2, y + h / 2
  love.graphics.setColor(0.85, 0.72, 0.2, 0.8)
  love.graphics.circle("fill", cx, cy, 10)
  love.graphics.setColor(0.12, 0.18, 0.45)
  love.graphics.circle("fill", cx, cy, 7)
  love.graphics.setColor(0.85, 0.72, 0.2, 0.8)
  love.graphics.circle("fill", cx, cy, 4)

  -- Inner border line
  love.graphics.setColor(0.85, 0.72, 0.2, 0.4)
  love.graphics.setLineWidth(1)
  love.graphics.rectangle("line", x + margin + 2, y + margin + 2, w - margin * 2 - 4, h - margin * 2 - 4, 3)

  -- Subtle card edge shadow
  love.graphics.setColor(0, 0, 0, 0.15)
  love.graphics.rectangle("line", x, y, w, h, 6)
end

function M.drawCard(card, x, y, faceDown)
  local w, h = cards.CARD_WIDTH, cards.CARD_HEIGHT

  if faceDown then
    drawCardBack(x, y, w, h)
    return
  end

  -- Card shadow
  love.graphics.setColor(0, 0, 0, 0.25)
  love.graphics.rectangle("fill", x + 2, y + 2, w, h, 6)

  -- White card face
  love.graphics.setColor(0.98, 0.97, 0.95)
  love.graphics.rectangle("fill", x, y, w, h, 6)

  -- Subtle inner border
  love.graphics.setColor(0.85, 0.83, 0.8)
  love.graphics.setLineWidth(1)
  love.graphics.rectangle("line", x + 3, y + 3, w - 6, h - 6, 4)

  local color = cards.getSuitColor(card.suit)

  -- Top-left rank
  love.graphics.setFont(fonts.cardRank)
  love.graphics.setColor(color)
  love.graphics.print(card.rank, x + 5, y + 3)

  -- Top-left suit pip (small, below rank)
  love.graphics.setColor(color)
  cards.drawSuit(card.suit, x + 12, y + 33, 8)

  -- Center suit (large)
  love.graphics.setColor(color[1], color[2], color[3], 0.9)
  cards.drawSuit(card.suit, x + w / 2, y + h / 2 - 4, 18)

  -- Bottom-right rank + suit (rotated 180°)
  love.graphics.push()
  love.graphics.translate(x + w, y + h)
  love.graphics.rotate(math.pi)
  love.graphics.setColor(color)
  love.graphics.setFont(fonts.cardRank)
  love.graphics.print(card.rank, 5, 3)
  love.graphics.setColor(color)
  cards.drawSuit(card.suit, 12, 33, 8)
  love.graphics.pop()

  -- Face card indicator: subtle colored bar at bottom
  if cards.FACE_CARDS and cards.FACE_CARDS[card.rank] then
    love.graphics.setColor(color[1], color[2], color[3], 0.12)
    love.graphics.rectangle("fill", x + 4, y + h - 14, w - 8, 10, 3)
  end

  -- Card edge
  love.graphics.setColor(0.6, 0.58, 0.55, 0.5)
  love.graphics.rectangle("line", x, y, w, h, 6)
end

function M.drawHand(h, x, y, hideSecond)
  for i, card in ipairs(h.cards) do
    local cardX = x + (i - 1) * cards.CARD_SPACING
    local faceDown = hideSecond and i == 2
    M.drawCard(card, cardX, y, faceDown)
  end
end

-- ─── BUTTON RENDERING ────────────────────────────────────────

function M.drawButton(text, x, y, width, height, enabled)
  -- Button shadow
  love.graphics.setColor(0, 0, 0, 0.3)
  love.graphics.rectangle("fill", x + 2, y + 2, width, height, 8)

  if enabled then
    -- Gradient-like fill: darker at bottom
    love.graphics.setColor(0.15, 0.55, 0.2)
    love.graphics.rectangle("fill", x, y, width, height, 8)
    love.graphics.setColor(0.2, 0.65, 0.28)
    love.graphics.rectangle("fill", x + 1, y + 1, width - 2, height / 2, 8)
    -- Border
    love.graphics.setColor(0.3, 0.75, 0.35)
    love.graphics.setLineWidth(1.5)
    love.graphics.rectangle("line", x, y, width, height, 8)
  else
    love.graphics.setColor(0.25, 0.25, 0.25)
    love.graphics.rectangle("fill", x, y, width, height, 8)
    love.graphics.setColor(0.35, 0.35, 0.35)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", x, y, width, height, 8)
  end

  love.graphics.setFont(fonts.normal)
  if enabled then
    love.graphics.setColor(1, 1, 1)
  else
    love.graphics.setColor(0.55, 0.55, 0.55)
  end
  love.graphics.printf(text, x, y + height / 2 - 8, width, "center")
  love.graphics.setLineWidth(1)

  return {x = x, y = y, width = width, height = height, enabled = enabled}
end

-- ─── POKER CHIP RENDERING ────────────────────────────────────

function M.drawPokerChip(x, y, value, stackHeight)
  local radius = 16
  local color = bet.getChipColor(value)
  local label = bet.getChipLabel(value)
  stackHeight = stackHeight or 0
  local cy = y + stackHeight

  -- Drop shadow
  love.graphics.setColor(0, 0, 0, 0.35)
  love.graphics.circle("fill", x + 2, cy + 3, radius)

  -- Outer ring (darker edge)
  love.graphics.setColor(color[1] * 0.5, color[2] * 0.5, color[3] * 0.5)
  love.graphics.circle("fill", x, cy, radius)

  -- Main chip body
  love.graphics.setColor(color[1], color[2], color[3])
  love.graphics.circle("fill", x, cy, radius - 1.5)

  -- Edge notch pattern (8 notches like real casino chips)
  love.graphics.setColor(1, 1, 1, 0.6)
  for angle = 0, 7 do
    local a = angle * math.pi / 4
    local nx = x + math.cos(a) * (radius - 3)
    local ny = cy + math.sin(a) * (radius - 3)
    love.graphics.circle("fill", nx, ny, 2)
  end

  -- Inner circle (white ring)
  love.graphics.setColor(1, 1, 1, 0.5)
  love.graphics.setLineWidth(1.5)
  love.graphics.circle("line", x, cy, radius - 5)
  love.graphics.setLineWidth(1)

  -- Center disc
  love.graphics.setColor(color[1] * 0.85, color[2] * 0.85, color[3] * 0.85)
  love.graphics.circle("fill", x, cy, radius - 6)

  -- Value text
  love.graphics.setFont(fonts.small)
  local textDark = (value == 1 or value == 25 or value == 10000 or value == 1000000)
  if textDark then
    love.graphics.setColor(0.1, 0.1, 0.1)
  else
    love.graphics.setColor(1, 1, 1)
  end
  local textWidth = fonts.small:getWidth(label)
  love.graphics.print(label, x - textWidth / 2, cy - 6)

  -- Shine highlight
  love.graphics.setColor(1, 1, 1, 0.15)
  love.graphics.arc("fill", x, cy, radius - 2, -math.pi * 0.8, -math.pi * 0.2)
end

function M.drawChipStack(x, y, stack)
  local totalHeight = 0
  for _, chip in ipairs(stack) do
    for j = 1, math.min(chip.count, 10) do
      M.drawPokerChip(x, y, chip.value, -totalHeight)
      totalHeight = totalHeight + 4
    end
    if chip.count > 10 then
      love.graphics.setFont(fonts.small)
      love.graphics.setColor(1, 1, 0)
      love.graphics.print("x" .. chip.count, x + 20, y - totalHeight - 5)
    end
  end
end

-- ─── TABLE RENDERING ─────────────────────────────────────────

local function drawTableFelt()
  -- Outer wooden rail (mahogany)
  love.graphics.setColor(TABLE.borderDark)
  love.graphics.rectangle("fill", 30, 40, 740, 570, 30)

  -- Rail highlight (top edge)
  love.graphics.setColor(TABLE.borderLight)
  love.graphics.rectangle("fill", 32, 42, 736, 566, 28)

  -- Main rail body
  love.graphics.setColor(TABLE.border)
  love.graphics.rectangle("fill", 34, 44, 732, 562, 26)

  -- Inner shadow (inset look)
  love.graphics.setColor(TABLE.feltDark)
  love.graphics.rectangle("fill", 50, 58, 700, 536, 20)

  -- Felt surface
  love.graphics.setColor(TABLE.felt)
  love.graphics.rectangle("fill", 52, 60, 696, 532, 18)

  -- Felt texture: subtle noise pattern (static dots)
  love.graphics.setColor(TABLE.feltLight[1], TABLE.feltLight[2], TABLE.feltLight[3], 0.08)
  math.randomseed(42) -- Deterministic texture
  for _ = 1, 300 do
    local fx = 55 + math.random() * 690
    local fy = 63 + math.random() * 526
    love.graphics.circle("fill", fx, fy, 1)
  end
  math.randomseed(os.time())

  -- Dealer arc (semicircle area at top)
  love.graphics.setColor(TABLE.feltLight)
  love.graphics.arc("fill", 400, 95, 220, math.pi, 2 * math.pi)
  -- Arc outline
  love.graphics.setColor(TABLE.gold[1], TABLE.gold[2], TABLE.gold[3], 0.5)
  love.graphics.setLineWidth(2)
  love.graphics.arc("line", "open", 400, 95, 220, math.pi, 2 * math.pi)
  love.graphics.setLineWidth(1)

  -- ─── Table markings ─────────────

  -- "BLACKJACK PAYS 3 TO 2" curved text area
  love.graphics.setFont(fonts.tableText)
  love.graphics.setColor(TABLE.gold)
  love.graphics.printf("BLACKJACK PAYS 3 TO 2", 0, 270, 800, "center")

  -- "DEALER MUST STAND ON 17" text
  love.graphics.setColor(TABLE.goldDim)
  love.graphics.printf("DEALER MUST STAND ON ALL 17s", 0, 290, 800, "center")

  -- "INSURANCE PAYS 2 TO 1" text
  love.graphics.setFont(fonts.title)
  love.graphics.setColor(TABLE.gold[1], TABLE.gold[2], TABLE.gold[3], 0.4)
  love.graphics.printf("INSURANCE PAYS 2 TO 1", 0, 310, 800, "center")

  -- Betting circle (main)
  love.graphics.setColor(TABLE.gold)
  love.graphics.setLineWidth(2.5)
  love.graphics.circle("line", 400, 460, 48)
  -- Inner ring
  love.graphics.setColor(TABLE.gold[1], TABLE.gold[2], TABLE.gold[3], 0.4)
  love.graphics.setLineWidth(1)
  love.graphics.circle("line", 400, 460, 38)

  -- Side betting spots (decorative)
  love.graphics.setColor(TABLE.gold[1], TABLE.gold[2], TABLE.gold[3], 0.2)
  love.graphics.circle("line", 220, 430, 25)
  love.graphics.circle("line", 580, 430, 25)

  -- Decorative divider lines
  love.graphics.setColor(TABLE.gold[1], TABLE.gold[2], TABLE.gold[3], 0.15)
  love.graphics.setLineWidth(1)
  love.graphics.line(100, 330, 700, 330)

  -- "DEALER" nameplate
  love.graphics.setFont(fonts.normal)
  love.graphics.setColor(TABLE.cream)
  love.graphics.printf("DEALER", 0, 68, 800, "center")
end

local function drawDeck(gameState)
  local cardsRemaining = gameState.deck and (#gameState.deck.cards) or 52
  local maxStackHeight = 8
  local stackCount = math.min(maxStackHeight, math.ceil(cardsRemaining / 6.5))

  -- Shuffling animation wobble
  if gameState.shuffleAnimation and gameState.shuffleAnimation.active then
    local progress = gameState.shuffleAnimation.timer / gameState.shuffleAnimation.duration
    local wobble = math.sin(progress * math.pi * 10) * 6
    love.graphics.push()
    love.graphics.translate(wobble, 0)
  end

  -- Draw stacked card backs for the deck
  for i = 1, stackCount do
    local offsetY = (stackCount - i) * 2
    local offsetX = (stackCount - i) * 0.8
    local dx, dy = 370 + offsetX, 20 + offsetY
    drawCardBack(dx, dy, cards.CARD_WIDTH, cards.CARD_HEIGHT)
  end

  if gameState.shuffleAnimation and gameState.shuffleAnimation.active then
    love.graphics.pop()
    love.graphics.setFont(fonts.small)
    love.graphics.setColor(1, 1, 0.4)
    love.graphics.printf("SHUFFLING...", 350, 5, 100, "center")
  end

  -- Cards remaining counter
  love.graphics.setFont(fonts.title)
  love.graphics.setColor(TABLE.cream[1], TABLE.cream[2], TABLE.cream[3], 0.6)
  love.graphics.printf(cardsRemaining .. " left", 360, cards.CARD_HEIGHT + 24, 80, "center")
end

-- ─── HAND VALUE DISPLAY ──────────────────────────────────────

local function drawHandValue(h, x, y, isDealer, hideHole)
  if #h.cards == 0 then return end
  if isDealer and hideHole then
    -- Show only the face-up card value
    local val = h.cards[1] and h.cards[1].value or 0
    local text = tostring(val)
    love.graphics.setFont(fonts.small)
    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.rectangle("fill", x - 2, y - 2, fonts.small:getWidth(text) + 12, 18, 4)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print(text, x + 4, y)
    return
  end

  local val = hand.getValue(h)
  local text = tostring(val)
  if hand.isBust(h) then
    text = text .. " BUST"
  elseif hand.isBlackjack(h) then
    text = "BJ!"
  elseif hand.isSoft(h) and val <= 21 then
    text = text .. " (soft)"
  end

  love.graphics.setFont(fonts.small)
  local tw = fonts.small:getWidth(text) + 12
  love.graphics.setColor(0, 0, 0, 0.55)
  love.graphics.rectangle("fill", x - 2, y - 2, tw, 18, 4)

  if hand.isBust(h) then
    love.graphics.setColor(1, 0.3, 0.3)
  elseif hand.isBlackjack(h) then
    love.graphics.setColor(1, 0.9, 0.2)
  else
    love.graphics.setColor(1, 1, 1)
  end
  love.graphics.print(text, x + 4, y)
end

-- ─── CREDITS DISPLAY ─────────────────────────────────────────

local function drawCreditsPanel(betting)
  -- Background panel
  local px, py, pw, ph = 55, 512, 180, 50

  -- Glowing border during win FX
  winFx.drawCreditCounter(px, py, pw, ph, "CREDITS")

  love.graphics.setColor(0, 0, 0, 0.5)
  love.graphics.rectangle("fill", px, py, pw, ph, 8)
  love.graphics.setColor(TABLE.gold[1], TABLE.gold[2], TABLE.gold[3], 0.4)
  love.graphics.setLineWidth(1)
  love.graphics.rectangle("line", px, py, pw, ph, 8)

  -- Credits label
  love.graphics.setFont(fonts.title)
  love.graphics.setColor(TABLE.goldDim)
  love.graphics.print("CREDITS", 68, 517)

  -- Use animated credit count if win FX is active
  local displayCredits = winFx.getDisplayedCredits() or betting.credits

  -- Credits value
  love.graphics.setFont(fonts.normal)
  love.graphics.setColor(TABLE.cream)
  -- Format with commas
  local formatted = tostring(math.floor(displayCredits)):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
  love.graphics.print(formatted, 68, 536)
end

-- ─── MAIN DRAW ───────────────────────────────────────────────

function M.drawGameUI(gameState, animations)
  uiTime = uiTime + (love.timer.getDelta and love.timer.getDelta() or 0.016)

  love.graphics.setBackgroundColor(0.02, 0.08, 0.03)

  -- Draw the table
  drawTableFelt()
  drawDeck(gameState)

  -- Dealer's hand
  local hideHole = not gameState.dealer.holeCardRevealed and #gameState.dealer.hand.cards > 0
  M.drawHand(gameState.dealer.hand, 320, 140, hideHole)

  -- Dealer hand value
  if #gameState.dealer.hand.cards > 0 then
    local handWidth = #gameState.dealer.hand.cards * cards.CARD_SPACING
    drawHandValue(gameState.dealer.hand, 320 + handWidth + 10, 145, true, hideHole)
  end

  -- Player hands
  for i, h in ipairs(gameState.player.hands) do
    local xOffset = 0
    if #gameState.player.hands > 1 then
      xOffset = (i == 1) and -200 or 200
    end
    local handX = 320 + xOffset

    -- Active hand glow indicator
    if gameState.state == "player_turn" and i == gameState.player.currentHandIndex then
      local pulse = 0.5 + 0.3 * math.sin(uiTime * 4)
      love.graphics.setColor(TABLE.gold[1], TABLE.gold[2], TABLE.gold[3], pulse * 0.4)
      local handWidth = #h.cards * cards.CARD_SPACING + cards.CARD_WIDTH - cards.CARD_SPACING
      love.graphics.rectangle("fill", handX - 8, 342, handWidth + 16, cards.CARD_HEIGHT + 16, 8)
      love.graphics.setColor(TABLE.gold[1], TABLE.gold[2], TABLE.gold[3], pulse)
      love.graphics.setLineWidth(2)
      love.graphics.rectangle("line", handX - 8, 342, handWidth + 16, cards.CARD_HEIGHT + 16, 8)
      love.graphics.setLineWidth(1)
    end

    M.drawHand(h, handX, 350, false)

    -- Player hand value
    if #h.cards > 0 then
      local handWidth = #h.cards * cards.CARD_SPACING
      drawHandValue(h, handX + handWidth + 10, 355, false, false)
    end
  end

  -- Credits panel
  drawCreditsPanel(gameState.betting)

  -- Bet in the betting circle
  if gameState.betting.currentBet > 0 then
    local betStack = bet.getChipStack(gameState.betting.currentBet)
    M.drawChipStack(400, 460, betStack)
    love.graphics.setFont(fonts.small)
    love.graphics.setColor(TABLE.cream)
    local formatted = tostring(gameState.betting.currentBet):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
    love.graphics.printf(formatted, 360, 485, 80, "center")
  end

  if gameState.betting.insuranceBet > 0 then
    -- Insurance bet shown in the insurance line area
    love.graphics.setFont(fonts.small)
    love.graphics.setColor(TABLE.cream)
    love.graphics.printf("Insurance: " .. gameState.betting.insuranceBet, 0, 320, 800, "center")
  end

  -- ─── State-specific UI ──────────
  M.buttons = {}

  if gameState.state == "betting" then
    M.buttons.deal = M.drawButton("DEAL", 350, 660, 100, 40, bet.canPlaceBet(gameState.betting))
    M.buttons.betUp = M.drawButton("+BET", 500, 660, 80, 40, true)
    M.buttons.betDown = M.drawButton("-BET", 600, 660, 80, 40, true)

    -- Chip selector panel
    love.graphics.setColor(0, 0, 0, 0.4)
    love.graphics.rectangle("fill", 488, 495, 210, 95, 8)
    love.graphics.setColor(TABLE.gold[1], TABLE.gold[2], TABLE.gold[3], 0.3)
    love.graphics.rectangle("line", 488, 495, 210, 95, 8)

    love.graphics.setFont(fonts.title)
    love.graphics.setColor(TABLE.cream)
    love.graphics.print("SELECT CHIP", 500, 498)

    local chipX = 504
    local chipRow = 1
    for i, value in ipairs(bet.CHIP_VALUES) do
      if bet.canAfford(gameState.betting, value) then
        local chipY = (chipRow == 1) and 530 or 568
        if i == gameState.betting.selectedChipIndex then
          -- Glowing selection ring
          local pulse = 0.6 + 0.4 * math.sin(uiTime * 5)
          love.graphics.setColor(TABLE.gold[1], TABLE.gold[2], TABLE.gold[3], pulse * 0.5)
          love.graphics.circle("fill", chipX + 14, chipY, 20)
        end
        M.drawPokerChip(chipX + 14, chipY, value)
        chipX = chipX + 38
        if chipX > 670 and chipRow == 1 then
          chipX = 504
          chipRow = 2
        end
      end
    end

  elseif gameState.state == "player_turn" then
    local canAct = #(animations or {}) == 0
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
      M.buttons.insurance = M.drawButton("INSURANCE", 590, 660, 110, 40, canAct)
    end

  elseif gameState.state == "dealing" then
    -- Cards being dealt, no extra UI

  elseif gameState.state == "payout" then
    M.buttons.newRound = M.drawButton("NEW ROUND", 310, 660, 140, 40, true)

    if gameState.result then
      -- Result banner
      love.graphics.setColor(0, 0, 0, 0.6)
      love.graphics.rectangle("fill", 150, 485, 500, 70, 10)
      love.graphics.setColor(TABLE.gold[1], TABLE.gold[2], TABLE.gold[3], 0.6)
      love.graphics.setLineWidth(2)
      love.graphics.rectangle("line", 150, 485, 500, 70, 10)
      love.graphics.setLineWidth(1)

      love.graphics.setFont(fonts.large)
      love.graphics.setColor(1, 1, 0.6)
      love.graphics.printf(gameState.result, 0, 492, 800, "center")

      -- Payout amounts
      if gameState.payouts then
        love.graphics.setFont(fonts.normal)
        if #gameState.payouts == 1 then
          local payout = gameState.payouts[1]
          if payout > 0 then
            love.graphics.setColor(0.3, 1, 0.4)
            love.graphics.printf("Won: +" .. payout .. " credits", 0, 525, 800, "center")
          end
        else
          local yOffset = 0
          for i, payout in ipairs(gameState.payouts) do
            if payout > 0 then
              love.graphics.setColor(0.3, 1, 0.4)
              love.graphics.printf("Hand " .. i .. ": +" .. payout, 0, 525 + yOffset, 800, "center")
              yOffset = yOffset + 22
            end
          end
        end
      end
    end
  end

  -- Animated cards drawn on top of everything
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
