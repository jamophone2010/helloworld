-- ============================================================
-- CASINO WIN FX - Shared exciting win animation system
-- Scales intensity based on win magnitude (win / bet ratio)
-- ============================================================
local M = {}

-- ─── STATE ───────────────────────────────────────────────────
local winState = {
  active = false,
  timer = 0,
  duration = 0,
  displayedCredits = 0,
  targetCredits = 0,
  startCredits = 0,
  winAmount = 0,
  betAmount = 0,
  intensity = 0,       -- 0-1 based on win/bet ratio
  tier = 0,            -- 1=small, 2=medium, 3=big, 4=mega, 5=jackpot
  particles = {},
  glowPulse = 0,
  screenShake = {x = 0, y = 0, magnitude = 0},
  sparkles = {},
  starBursts = {},
  countSpeed = 0,
  countAccel = 0,
}

-- ─── TIER THRESHOLDS (win / bet ratio) ───────────────────────
-- tier 1: small win (1x-3x bet)  - gentle glow, simple count
-- tier 2: medium win (3x-10x)    - brighter glow, faster count, some particles
-- tier 3: big win (10x-25x)      - intense glow, screen shake, lots of particles
-- tier 4: mega win (25x-100x)    - rainbow glow, strong shake, star bursts
-- tier 5: jackpot (100x+)        - everything maxed, sustained fireworks
local TIER_THRESHOLDS = {1, 3, 10, 25, 100}

local TIER_DURATIONS = {2.5, 3.5, 5.0, 6.5, 8.0}
local TIER_PARTICLE_COUNT = {8, 25, 60, 120, 200}
local TIER_SHAKE_MAG = {0, 1.5, 3.5, 6, 10}
local TIER_GLOW_INTENSITY = {0.3, 0.5, 0.75, 1.0, 1.0}
local TIER_COUNT_SPEED = {0.6, 0.4, 0.3, 0.25, 0.2} -- fraction of duration for count-up

local TIER_COLORS = {
  {{1, 0.9, 0.3}},                                                  -- gold
  {{1, 0.9, 0.3}, {1, 1, 0.6}},                                     -- bright gold
  {{1, 0.8, 0.1}, {0.3, 1, 0.4}, {0.3, 0.8, 1}},                  -- gold + green + blue
  {{1, 0.2, 0.3}, {1, 0.8, 0.1}, {0.3, 1, 0.4}, {0.3, 0.6, 1}},  -- rainbow
  {{1, 0.1, 0.2}, {1, 0.6, 0.1}, {1, 1, 0.2}, {0.2, 1, 0.4}, {0.2, 0.6, 1}, {0.7, 0.3, 1}}, -- full rainbow
}

-- ─── FONTS (lazy-loaded) ─────────────────────────────────────
local fonts = {}
local fontsLoaded = false

local function ensureFonts()
  if fontsLoaded then return end
  fonts.counter = love.graphics.newFont(42)
  fonts.counterLarge = love.graphics.newFont(56)
  fonts.counterHuge = love.graphics.newFont(72)
  fonts.label = love.graphics.newFont(20)
  fonts.labelLarge = love.graphics.newFont(28)
  fonts.tier = love.graphics.newFont(36)
  fontsLoaded = true
end

-- ─── UTILITY ─────────────────────────────────────────────────

local function lerp(a, b, t)
  return a + (b - a) * t
end

local function formatNumber(n)
  n = math.floor(n)
  return tostring(n):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
end

local function getTierLabel(tier)
  if tier == 1 then return "WIN!"
  elseif tier == 2 then return "NICE WIN!"
  elseif tier == 3 then return "BIG WIN!"
  elseif tier == 4 then return "MEGA WIN!!"
  elseif tier == 5 then return "★ JACKPOT ★"
  end
  return "WIN!"
end

local function getTier(ratio)
  local tier = 1
  for i, threshold in ipairs(TIER_THRESHOLDS) do
    if ratio >= threshold then
      tier = i
    end
  end
  return tier
end

local function createParticle(cx, cy, tier)
  local colors = TIER_COLORS[tier] or TIER_COLORS[1]
  local color = colors[math.random(1, #colors)]
  local angle = math.random() * math.pi * 2
  local speed = 80 + math.random() * (150 + tier * 60)
  local size = 2 + math.random() * (2 + tier)
  
  return {
    x = cx + (math.random() - 0.5) * 40,
    y = cy + (math.random() - 0.5) * 40,
    vx = math.cos(angle) * speed,
    vy = math.sin(angle) * speed - 60,  -- slight upward bias
    size = size,
    maxSize = size,
    life = 0.8 + math.random() * 1.2,
    maxLife = 0.8 + math.random() * 1.2,
    color = color,
    gravity = 50 + math.random() * 80,
    spin = (math.random() - 0.5) * 10,
    angle = math.random() * math.pi * 2,
    type = math.random() < 0.3 and "star" or "circle",
    trail = {},
  }
end

local function createSparkle(cx, cy, radius)
  local angle = math.random() * math.pi * 2
  local dist = math.random() * radius
  return {
    x = cx + math.cos(angle) * dist,
    y = cy + math.sin(angle) * dist,
    size = 1 + math.random() * 3,
    life = 0.3 + math.random() * 0.6,
    maxLife = 0.3 + math.random() * 0.6,
    phase = math.random() * math.pi * 2,
  }
end

local function createStarBurst(cx, cy)
  return {
    x = cx + (math.random() - 0.5) * 300,
    y = cy + (math.random() - 0.5) * 200,
    life = 0.6 + math.random() * 0.8,
    maxLife = 0.6 + math.random() * 0.8,
    size = 20 + math.random() * 30,
    rays = 4 + math.random(0, 4),
    rotation = math.random() * math.pi,
    color = TIER_COLORS[5][math.random(1, #TIER_COLORS[5])],
  }
end

-- ─── PUBLIC API ──────────────────────────────────────────────

--- Start a win celebration
--- @param winAmount number Total credits won
--- @param betAmount number The bet that produced this win
--- @param currentCredits number Current credit balance (before adding winAmount)
--- @param centerX number Screen X center for effects
--- @param centerY number Screen Y center for effects
function M.startWin(winAmount, betAmount, currentCredits, centerX, centerY)
  ensureFonts()
  
  if winAmount <= 0 then return end
  
  local ratio = betAmount > 0 and (winAmount / betAmount) or 1
  local tier = getTier(ratio)
  
  winState.active = true
  winState.timer = 0
  winState.winAmount = winAmount
  winState.betAmount = betAmount
  winState.startCredits = currentCredits
  winState.targetCredits = currentCredits + winAmount
  winState.displayedCredits = currentCredits
  winState.intensity = math.min(ratio / 100, 1)
  winState.tier = tier
  winState.duration = TIER_DURATIONS[tier]
  winState.glowPulse = 0
  winState.centerX = centerX or 683  -- default to 1366/2
  winState.centerY = centerY or 400
  winState.screenShake = {x = 0, y = 0, magnitude = TIER_SHAKE_MAG[tier]}
  winState.countSpeed = TIER_COUNT_SPEED[tier]
  
  -- Generate particles
  winState.particles = {}
  local numParticles = TIER_PARTICLE_COUNT[tier]
  for i = 1, numParticles do
    -- Stagger particle creation over time
    local p = createParticle(centerX or 683, centerY or 400, tier)
    p.delay = (i / numParticles) * winState.duration * 0.6
    p.active = false
    table.insert(winState.particles, p)
  end
  
  -- Generate sparkles
  winState.sparkles = {}
  
  -- Star bursts for tier 4+
  winState.starBursts = {}
end

--- Update the win animation
--- @param dt number Delta time
--- @return boolean Whether the animation is still active
function M.update(dt)
  if not winState.active then return false end
  
  winState.timer = winState.timer + dt
  winState.glowPulse = winState.glowPulse + dt
  
  local tier = winState.tier
  local progress = winState.timer / winState.duration
  
  if progress >= 1 then
    winState.active = false
    winState.displayedCredits = winState.targetCredits
    return false
  end
  
  -- Count-up credits with easing
  local countFraction = winState.countSpeed
  local countProgress = math.min(progress / countFraction, 1)
  -- Use ease-out for satisfying deceleration
  local easedCount = 1 - math.pow(1 - countProgress, 3)
  winState.displayedCredits = winState.startCredits + winState.winAmount * easedCount
  
  -- Screen shake (decays over time)
  if winState.screenShake.magnitude > 0 then
    local shakeFade = math.max(0, 1 - progress * 1.5)
    local shakeFreq = 15 + tier * 5
    winState.screenShake.x = math.sin(winState.timer * shakeFreq * 2.3) * winState.screenShake.magnitude * shakeFade
    winState.screenShake.y = math.cos(winState.timer * shakeFreq * 1.7) * winState.screenShake.magnitude * shakeFade * 0.7
  end
  
  -- Activate and update particles
  for _, p in ipairs(winState.particles) do
    if not p.active and winState.timer >= p.delay then
      p.active = true
      p.x = winState.centerX + (math.random() - 0.5) * 40
      p.y = winState.centerY + (math.random() - 0.5) * 40
    end
    
    if p.active and p.life > 0 then
      p.life = p.life - dt
      p.x = p.x + p.vx * dt
      p.y = p.y + p.vy * dt
      p.vy = p.vy + p.gravity * dt
      p.angle = p.angle + p.spin * dt
      p.size = p.maxSize * math.max(0, p.life / p.maxLife)
      
      -- Trail (for tier 3+)
      if tier >= 3 and #p.trail < 6 then
        table.insert(p.trail, 1, {x = p.x, y = p.y, alpha = 0.4})
      end
      -- Fade trail
      for i = #p.trail, 1, -1 do
        p.trail[i].alpha = p.trail[i].alpha - dt * 2
        if p.trail[i].alpha <= 0 then
          table.remove(p.trail, i)
        end
      end
    end
  end
  
  -- Spawn sparkles continuously for tier 2+
  if tier >= 2 and math.random() < (0.3 + tier * 0.15) then
    table.insert(winState.sparkles, createSparkle(
      winState.centerX, winState.centerY, 150 + tier * 30
    ))
  end
  
  -- Update sparkles
  for i = #winState.sparkles, 1, -1 do
    local s = winState.sparkles[i]
    s.life = s.life - dt
    if s.life <= 0 then
      table.remove(winState.sparkles, i)
    end
  end
  
  -- Spawn star bursts for tier 4+
  if tier >= 4 and math.random() < 0.05 * tier then
    table.insert(winState.starBursts, createStarBurst(winState.centerX, winState.centerY))
  end
  
  -- Update star bursts
  for i = #winState.starBursts, 1, -1 do
    local sb = winState.starBursts[i]
    sb.life = sb.life - dt
    if sb.life <= 0 then
      table.remove(winState.starBursts, i)
    end
  end
  
  return true
end

--- Draw the full-screen glow overlay
--- Call this BEFORE drawing other game UI to get background glow
function M.drawGlow()
  if not winState.active then return end
  
  local tier = winState.tier
  local progress = winState.timer / winState.duration
  local fadeIn = math.min(progress * 4, 1)
  local fadeOut = math.max(0, 1 - (progress - 0.7) / 0.3)
  local fade = math.min(fadeIn, fadeOut)
  local glowIntensity = TIER_GLOW_INTENSITY[tier] * fade
  
  local pulse = 0.7 + 0.3 * math.sin(winState.glowPulse * (3 + tier * 1.5))
  local colors = TIER_COLORS[tier] or TIER_COLORS[1]
  local colorIndex = math.floor(winState.glowPulse * 2) % #colors + 1
  local color = colors[colorIndex]
  
  -- Outer radial glow
  local cx, cy = winState.centerX, winState.centerY
  local maxRadius = 250 + tier * 80
  
  for radius = maxRadius, 40, -20 do
    local ringAlpha = (1 - radius / maxRadius) * glowIntensity * pulse * 0.08
    love.graphics.setColor(color[1], color[2], color[3], ringAlpha)
    love.graphics.circle("fill", cx, cy, radius)
  end
  
  -- Edge vignette glow for tier 3+
  if tier >= 3 then
    local screenW, screenH = love.graphics.getDimensions()
    local edgeAlpha = glowIntensity * 0.06 * pulse
    -- Top
    love.graphics.setColor(color[1], color[2], color[3], edgeAlpha)
    love.graphics.rectangle("fill", 0, 0, screenW, 40)
    -- Bottom
    love.graphics.rectangle("fill", 0, screenH - 40, screenW, 40)
    -- Left
    love.graphics.rectangle("fill", 0, 0, 40, screenH)
    -- Right
    love.graphics.rectangle("fill", screenW - 40, 0, 40, screenH)
  end
end

--- Draw particles, sparkles, and star bursts
--- Call this AFTER drawing game UI so effects appear on top
function M.drawParticles()
  if not winState.active then return end
  
  local tier = winState.tier
  
  -- Star bursts (behind particles)
  for _, sb in ipairs(winState.starBursts) do
    local lifeRatio = sb.life / sb.maxLife
    local alpha = lifeRatio * 0.6
    local size = sb.size * (1 + (1 - lifeRatio) * 0.5)
    
    love.graphics.push()
    love.graphics.translate(sb.x, sb.y)
    love.graphics.rotate(sb.rotation + (1 - lifeRatio) * 0.5)
    
    for ray = 0, sb.rays - 1 do
      local angle = ray * (math.pi * 2 / sb.rays)
      love.graphics.setColor(sb.color[1], sb.color[2], sb.color[3], alpha)
      local rx = math.cos(angle) * size
      local ry = math.sin(angle) * size
      local pw = 3 + tier
      love.graphics.polygon("fill",
        0, 0,
        rx - math.sin(angle) * pw, ry + math.cos(angle) * pw,
        rx * 1.2, ry * 1.2,
        rx + math.sin(angle) * pw, ry - math.cos(angle) * pw
      )
    end
    
    -- Center glow
    love.graphics.setColor(1, 1, 1, alpha * 0.8)
    love.graphics.circle("fill", 0, 0, size * 0.15)
    
    love.graphics.pop()
  end
  
  -- Sparkles
  for _, s in ipairs(winState.sparkles) do
    local lifeRatio = s.life / s.maxLife
    local twinkle = 0.5 + 0.5 * math.sin(winState.glowPulse * 20 + s.phase)
    local alpha = lifeRatio * twinkle
    
    love.graphics.setColor(1, 1, 1, alpha)
    love.graphics.circle("fill", s.x, s.y, s.size * lifeRatio)
    
    -- Cross sparkle shape
    if s.size > 2 then
      local sz = s.size * lifeRatio * 2
      love.graphics.setColor(1, 1, 1, alpha * 0.5)
      love.graphics.rectangle("fill", s.x - sz, s.y - 0.5, sz * 2, 1)
      love.graphics.rectangle("fill", s.x - 0.5, s.y - sz, 1, sz * 2)
    end
  end
  
  -- Particles
  for _, p in ipairs(winState.particles) do
    if p.active and p.life > 0 then
      local lifeRatio = p.life / p.maxLife
      
      -- Trail
      for _, t in ipairs(p.trail) do
        love.graphics.setColor(p.color[1], p.color[2], p.color[3], t.alpha * 0.3)
        love.graphics.circle("fill", t.x, t.y, p.size * 0.5)
      end
      
      -- Particle body
      love.graphics.setColor(p.color[1], p.color[2], p.color[3], lifeRatio)
      
      if p.type == "star" then
        -- Draw a small star shape
        love.graphics.push()
        love.graphics.translate(p.x, p.y)
        love.graphics.rotate(p.angle)
        local sz = p.size
        for ray = 0, 3 do
          local a = ray * math.pi / 2
          love.graphics.polygon("fill",
            0, 0,
            math.cos(a - 0.3) * sz, math.sin(a - 0.3) * sz,
            math.cos(a) * sz * 2, math.sin(a) * sz * 2,
            math.cos(a + 0.3) * sz, math.sin(a + 0.3) * sz
          )
        end
        love.graphics.pop()
      else
        love.graphics.circle("fill", p.x, p.y, p.size)
      end
      
      -- Bright center for glow effect
      love.graphics.setColor(1, 1, 1, lifeRatio * 0.5)
      love.graphics.circle("fill", p.x, p.y, p.size * 0.4)
    end
  end
end

--- Draw the credit counter with exciting count-up animation
--- @param x number X position of the counter
--- @param y number Y position of the counter
--- @param width number Width of the counter area
--- @param height number Height of the counter area
--- @param label string Label text (e.g. "CREDITS", "BALANCE")
function M.drawCreditCounter(x, y, width, height, label)
  if not winState.active then return false end
  
  ensureFonts()
  
  local tier = winState.tier
  local progress = winState.timer / winState.duration
  local pulse = 0.7 + 0.3 * math.sin(winState.glowPulse * (4 + tier * 2))
  
  local colors = TIER_COLORS[tier] or TIER_COLORS[1]
  local colorIndex = math.floor(winState.glowPulse * 3) % #colors + 1
  local color = colors[colorIndex]
  
  -- Glowing border around credit counter
  local glowFade = math.min(progress * 3, 1) * math.max(0, 1 - (progress - 0.8) / 0.2)
  local borderGlow = glowFade * TIER_GLOW_INTENSITY[tier] * pulse
  
  -- Multiple glow layers
  for i = 3, 1, -1 do
    local expand = i * 3
    love.graphics.setColor(color[1], color[2], color[3], borderGlow * 0.15 / i)
    love.graphics.rectangle("fill", x - expand, y - expand, width + expand * 2, height + expand * 2, 8 + expand)
  end
  
  -- Bright border
  love.graphics.setColor(color[1], color[2], color[3], borderGlow * 0.8)
  love.graphics.setLineWidth(2 + tier * 0.5)
  love.graphics.rectangle("line", x, y, width, height, 6)
  love.graphics.setLineWidth(1)
  
  return true -- indicates we drew something
end

--- Draw the big win announcement text
--- @param x number Center X
--- @param y number Center Y
function M.drawWinText(x, y)
  if not winState.active then return end
  
  ensureFonts()
  
  local tier = winState.tier
  local progress = winState.timer / winState.duration
  
  -- Entrance animation (scale up + bounce)
  local entrance = math.min(progress * 5, 1)
  local bounce = entrance < 1 and (1 + math.sin(entrance * math.pi) * 0.3) or 1
  local scale = entrance * bounce
  
  -- Exit fade
  local exitFade = math.max(0, 1 - (progress - 0.75) / 0.25)
  local alpha = math.min(entrance, exitFade)
  
  if alpha <= 0 then return end
  
  local colors = TIER_COLORS[tier] or TIER_COLORS[1]
  local colorIndex = math.floor(winState.glowPulse * 2.5) % #colors + 1
  local color = colors[colorIndex]
  
  local tierLabel = getTierLabel(tier)
  local amountText = "+" .. formatNumber(winState.winAmount)
  
  -- Choose font based on tier
  local tierFont = tier >= 4 and fonts.tier or fonts.labelLarge
  local amountFont = tier >= 4 and fonts.counterHuge or (tier >= 3 and fonts.counterLarge or fonts.counter)
  
  love.graphics.push()
  love.graphics.translate(x, y)
  love.graphics.scale(scale, scale)
  
  -- Shadow for tier label
  love.graphics.setFont(tierFont)
  love.graphics.setColor(0, 0, 0, alpha * 0.6)
  love.graphics.printf(tierLabel, -200 + 2, -30 + 2, 400, "center")
  
  -- Tier label with color cycling
  if tier >= 4 then
    -- Rainbow outline for mega/jackpot
    for dx = -2, 2 do
      for dy = -2, 2 do
        if math.abs(dx) + math.abs(dy) >= 2 then
          local outlineColor = colors[(colorIndex + 1) % #colors + 1]
          love.graphics.setColor(outlineColor[1], outlineColor[2], outlineColor[3], alpha * 0.7)
          love.graphics.printf(tierLabel, -200 + dx, -30 + dy, 400, "center")
        end
      end
    end
  end
  
  love.graphics.setColor(color[1], color[2], color[3], alpha)
  love.graphics.printf(tierLabel, -200, -30, 400, "center")
  
  -- White hot center
  love.graphics.setColor(1, 1, 1, alpha * 0.5)
  love.graphics.printf(tierLabel, -200, -31, 400, "center")
  
  -- Amount text
  love.graphics.setFont(amountFont)
  love.graphics.setColor(0, 0, 0, alpha * 0.5)
  love.graphics.printf(amountText, -250 + 2, 10 + 2, 500, "center")
  
  love.graphics.setColor(0.3, 1, 0.4, alpha)
  love.graphics.printf(amountText, -250, 10, 500, "center")
  -- Glow
  love.graphics.setColor(0.5, 1, 0.6, alpha * 0.4)
  love.graphics.printf(amountText, -250, 9, 500, "center")
  
  love.graphics.pop()
end

--- Get the current displayed credit count (for animated counter)
--- @return number|nil displayedCredits or nil if not active
function M.getDisplayedCredits()
  if not winState.active then return nil end
  return math.floor(winState.displayedCredits)
end

--- Get screen shake offset (apply to love.graphics.translate)
--- @return number, number x and y shake offset
function M.getScreenShake()
  if not winState.active then return 0, 0 end
  return winState.screenShake.x, winState.screenShake.y
end

--- Check if the win animation is currently active
--- @return boolean
function M.isActive()
  return winState.active
end

--- Get the current tier (1-5)
--- @return number
function M.getTier()
  return winState.active and winState.tier or 0
end

--- Force-finish the animation (e.g., user presses a key)
function M.skip()
  if winState.active then
    winState.active = false
    winState.displayedCredits = winState.targetCredits
  end
end

return M
