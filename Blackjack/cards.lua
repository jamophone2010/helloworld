local M = {}

M.CARD_WIDTH = 70
M.CARD_HEIGHT = 100
M.CARD_SPACING = 75

-- Rank display names (for face cards)
M.RANK_DISPLAY = {
  A = "A", ["2"] = "2", ["3"] = "3", ["4"] = "4", ["5"] = "5",
  ["6"] = "6", ["7"] = "7", ["8"] = "8", ["9"] = "9", ["10"] = "10",
  J = "J", Q = "Q", K = "K"
}

M.FACE_CARDS = { J = true, Q = true, K = true }

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
    return {0.85, 0.08, 0.08}
  else
    return {0.12, 0.12, 0.15}
  end
end

-- Get a lighter tint of suit color for decorative pips
function M.getSuitTint(suit)
  if suit == "hearts" or suit == "diamonds" then
    return {1.0, 0.7, 0.7, 0.15}
  else
    return {0.6, 0.6, 0.7, 0.12}
  end
end

-- ─── GEOMETRIC SUIT SHAPES ──────────────────────────────────
-- Draw a heart shape centered at (cx, cy) with given size
function M.drawHeart(cx, cy, size)
  local s = size
  -- Heart as two circles on top + triangle on bottom
  local r = s * 0.3
  love.graphics.circle("fill", cx - r, cy - r * 0.4, r)
  love.graphics.circle("fill", cx + r, cy - r * 0.4, r)
  love.graphics.polygon("fill",
    cx - s * 0.58, cy - r * 0.15,
    cx + s * 0.58, cy - r * 0.15,
    cx, cy + s * 0.7
  )
end

-- Draw a diamond shape centered at (cx, cy) with given size
function M.drawDiamond(cx, cy, size)
  local w = size * 0.45
  local h = size * 0.7
  love.graphics.polygon("fill",
    cx, cy - h,
    cx + w, cy,
    cx, cy + h,
    cx - w, cy
  )
end

-- Draw a club shape centered at (cx, cy) with given size
function M.drawClub(cx, cy, size)
  local r = size * 0.25
  -- Three circles: top, bottom-left, bottom-right
  love.graphics.circle("fill", cx, cy - r * 0.8, r)
  love.graphics.circle("fill", cx - r * 0.9, cy + r * 0.35, r)
  love.graphics.circle("fill", cx + r * 0.9, cy + r * 0.35, r)
  -- Stem
  love.graphics.polygon("fill",
    cx - size * 0.08, cy + r * 0.2,
    cx + size * 0.08, cy + r * 0.2,
    cx + size * 0.12, cy + size * 0.65,
    cx - size * 0.12, cy + size * 0.65
  )
end

-- Draw a spade shape centered at (cx, cy) with given size
function M.drawSpade(cx, cy, size)
  local s = size
  -- Inverted heart (two circles on bottom + triangle on top)
  local r = s * 0.28
  love.graphics.circle("fill", cx - r, cy + r * 0.15, r)
  love.graphics.circle("fill", cx + r, cy + r * 0.15, r)
  love.graphics.polygon("fill",
    cx - s * 0.54, cy + r * 0.05,
    cx + s * 0.54, cy + r * 0.05,
    cx, cy - s * 0.65
  )
  -- Stem
  love.graphics.polygon("fill",
    cx - s * 0.08, cy + r * 0.3,
    cx + s * 0.08, cy + r * 0.3,
    cx + s * 0.12, cy + s * 0.65,
    cx - s * 0.12, cy + s * 0.65
  )
end

-- Draw any suit at a given position/size
function M.drawSuit(suit, cx, cy, size)
  if suit == "hearts" then
    M.drawHeart(cx, cy, size)
  elseif suit == "diamonds" then
    M.drawDiamond(cx, cy, size)
  elseif suit == "clubs" then
    M.drawClub(cx, cy, size)
  elseif suit == "spades" then
    M.drawSpade(cx, cy, size)
  end
end

return M
