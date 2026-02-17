local M = {}
local screen = require("starfox.screen")

M.scrollOffset = 0
M.scrollSpeed = 100
M.starSpeedMultiplier = 1.0
M.stars = {}
M.groundSections = {}

-- Aquas fog cloud system
-- Simulates drifting cloud banks like flying through clouds on an airplane
M.fogClouds = {}        -- Array of cloud layer objects
M.fogEnabled = false     -- Whether fog is active (Aquas level)
M.fogDensity = 0         -- Current overall fog density (0-1), cycles through phases
M.fogPhaseTimer = 0      -- Timer for fog density cycling
M.fogWisps = {}          -- Small fast-moving wisp particles

function M.initFog()
  M.fogEnabled = true
  M.fogClouds = {}
  M.fogWisps = {}
  M.fogDensity = 0.5
  M.fogPhaseTimer = 0

  -- Create initial cloud bank layers spread across the screen
  -- Each cloud is an elliptical fog bank that drifts downward and laterally
  for i = 1, 18 do
    M.spawnFogCloud(math.random(0, screen.HEIGHT))
  end

  -- Create initial wisp particles (thin streaky clouds)
  for i = 1, 35 do
    table.insert(M.fogWisps, {
      x = math.random(0, screen.WIDTH),
      y = math.random(0, screen.HEIGHT),
      width = math.random(60, 200),
      height = math.random(4, 12),
      speed = math.random(30, 80),
      drift = (math.random() - 0.5) * 20,
      alpha = math.random() * 0.15 + 0.05,
      phase = math.random() * math.pi * 2,
    })
  end
end

function M.spawnFogCloud(startY)
  local cloud = {
    x = math.random(-100, screen.WIDTH + 100),
    y = startY or -math.random(50, 200),
    -- Cloud dimensions - wide and flat like real cloud banks
    width = math.random(200, 550),
    height = math.random(60, 160),
    -- Movement
    speedY = math.random(15, 45),          -- Downward scroll speed
    drift = (math.random() - 0.5) * 30,    -- Lateral drift
    -- Appearance
    alpha = math.random() * 0.25 + 0.15,   -- Base opacity (0.15 to 0.40)
    layers = math.random(3, 6),             -- Sub-blobs that form the cloud
    seed = math.random(1000),               -- For deterministic sub-cloud positions
    -- Pulsing
    pulseSpeed = 0.3 + math.random() * 0.5,
    pulsePhase = math.random() * math.pi * 2,
  }

  -- Generate sub-cloud blob positions (relative to cloud center)
  cloud.blobs = {}
  math.randomseed(cloud.seed)
  for j = 1, cloud.layers do
    table.insert(cloud.blobs, {
      ox = (math.random() - 0.5) * cloud.width * 0.7,
      oy = (math.random() - 0.5) * cloud.height * 0.5,
      rx = cloud.width * (0.2 + math.random() * 0.3),
      ry = cloud.height * (0.3 + math.random() * 0.4),
      alphaMulti = 0.5 + math.random() * 0.5,
    })
  end
  math.randomseed(os.time())  -- Restore normal randomness

  table.insert(M.fogClouds, cloud)
end

function M.updateFog(dt, levelTime)
  if not M.fogEnabled then return end

  M.fogPhaseTimer = M.fogPhaseTimer + dt

  -- Fog density cycles based on level phase (matches wave data)
  -- Phase 1 (0-20s): Light fog, building up
  -- Phase 2 (20-40s): Thick fog
  -- Phase 3 (40-60s): Dense fog (capital ship ambush)
  -- Phase 4 (60-80s): Fog clears temporarily
  -- Phase 5 (80-100s): Fog returns heavy for boss approach
  if levelTime < 20 then
    M.fogDensity = 0.3 + (levelTime / 20) * 0.3  -- 0.3 -> 0.6
  elseif levelTime < 40 then
    M.fogDensity = 0.6 + ((levelTime - 20) / 20) * 0.2  -- 0.6 -> 0.8
  elseif levelTime < 60 then
    M.fogDensity = 0.8 + math.sin(M.fogPhaseTimer * 0.5) * 0.1  -- Heavy, pulsing
  elseif levelTime < 80 then
    -- Fog clears partially
    local clearT = (levelTime - 60) / 20
    if clearT < 0.3 then
      M.fogDensity = 0.8 - clearT * 2  -- Rapid clear
    elseif clearT < 0.7 then
      M.fogDensity = 0.2 + math.sin(M.fogPhaseTimer * 0.8) * 0.1  -- Light fog
    else
      M.fogDensity = 0.2 + (clearT - 0.7) * 2  -- Building back up
    end
  else
    M.fogDensity = 0.7 + math.sin(M.fogPhaseTimer * 0.4) * 0.15  -- Heavy for boss
  end

  -- Update cloud positions
  for i = #M.fogClouds, 1, -1 do
    local cloud = M.fogClouds[i]
    cloud.y = cloud.y + cloud.speedY * dt
    cloud.x = cloud.x + cloud.drift * dt

    -- Remove clouds that have scrolled off screen
    if cloud.y > screen.HEIGHT + cloud.height then
      table.remove(M.fogClouds, i)
    end
  end

  -- Spawn new clouds at the top
  while #M.fogClouds < 18 do
    M.spawnFogCloud()
  end

  -- Update wisps
  for _, wisp in ipairs(M.fogWisps) do
    wisp.y = wisp.y + wisp.speed * dt
    wisp.x = wisp.x + wisp.drift * dt

    if wisp.y > screen.HEIGHT + 20 then
      wisp.y = -wisp.height
      wisp.x = math.random(0, screen.WIDTH)
      wisp.width = math.random(60, 200)
    end
    if wisp.x < -wisp.width then
      wisp.x = screen.WIDTH + math.random(10, 50)
    elseif wisp.x > screen.WIDTH + wisp.width then
      wisp.x = -wisp.width - math.random(10, 50)
    end
  end
end

-- Calculate fog alpha for an entity at position (ex, ey)
-- Returns 0-1 where 0 = fully hidden in fog, 1 = fully visible
function M.getFogVisibility(ex, ey)
  if not M.fogEnabled then return 1 end

  local visibility = 1.0
  local time = love.timer.getTime()

  for _, cloud in ipairs(M.fogClouds) do
    -- Check if entity is inside or near this cloud bank
    local dx = (ex - cloud.x) / (cloud.width * 0.6)
    local dy = (ey - cloud.y) / (cloud.height * 0.6)
    local distSq = dx * dx + dy * dy

    if distSq < 1.0 then
      -- Entity is inside/near this cloud
      local overlap = 1.0 - distSq  -- 0 at edge, 1 at center
      local pulse = 1.0 + math.sin(time * cloud.pulseSpeed + cloud.pulsePhase) * 0.2
      local cloudFade = overlap * cloud.alpha * pulse * (M.fogDensity + 0.2)
      visibility = visibility - cloudFade
    end
  end

  -- Clamp visibility between a minimum (enemies should never be fully invisible
  -- unlike Sector X - fog obscures but doesn't hide completely)
  return math.max(0.12, math.min(1.0, visibility))
end

function M.reset()
  M.scrollOffset = 0
  M.starSpeedMultiplier = 1.0
  M.stars = {}

  for i = 1, 100 do
    table.insert(M.stars, {
      x = math.random(screen.WIDTH),
      y = math.random(screen.HEIGHT),
      speed = math.random(20, 80),
      size = math.random(1, 2)
    })
  end

  M.groundSections = {}

  -- Reset fog
  M.fogEnabled = false
  M.fogClouds = {}
  M.fogWisps = {}
  M.fogDensity = 0
  M.fogPhaseTimer = 0
end

function M.update(dt)
  M.scrollOffset = M.scrollOffset + M.scrollSpeed * dt

  for _, star in ipairs(M.stars) do
    star.y = star.y + star.speed * M.starSpeedMultiplier * dt

    if star.y > screen.HEIGHT then
      star.y = 0
      star.x = math.random(screen.WIDTH)
    end
  end

  -- Update fog if active
  if M.fogEnabled then
    M.updateFog(dt, M.getLevelTime())
  end
end

function M.getScrollOffset()
  return M.scrollOffset
end

function M.getLevelTime()
  return M.scrollOffset / M.scrollSpeed
end

return M
