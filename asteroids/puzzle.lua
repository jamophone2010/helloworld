-- asteroids/puzzle.lua
-- Metroid/Zelda style puzzle rooms with Torpedo Pod and Shield Cell rewards
-- Each of the 9 constellations (Nebula + 8 Inner Space) gets one Torpedo Pod 
-- puzzle sector and one Shield Cell puzzle sector, assigned deterministically.

local M = {}
local constellation = require("asteroids.constellation")
local asteroid = require("asteroids.asteroid")
local ui = require("asteroids.ui")

-- ===================== PUZZLE TYPES =====================
M.PUZZLE_SPINNING_LOCK  = "spinning_lock"
M.PUZZLE_HIDDEN_PORTAL  = "hidden_portal"
M.PUZZLE_DEEP_SPACE_BOSS = "deep_space_boss"
M.PUZZLE_HEAT_MAZE      = "heat_maze"
M.PUZZLE_GRAVITY_RINGS  = "gravity_rings"
M.PUZZLE_CRYSTAL_ALIGN  = "crystal_align"
M.PUZZLE_COMET_CATCH    = "comet_catch"
M.PUZZLE_PULSAR_TIMING  = "pulsar_timing"
M.PUZZLE_NEBULA_MEMORY  = "nebula_memory"

-- ===================== REWARD TYPES =====================
M.REWARD_TORPEDO_POD  = "torpedo_pod"
M.REWARD_SHIELD_CELL  = "shield_cell"

-- ===================== PUZZLE ASSIGNMENTS =====================
-- Deterministic sector assignments per constellation
-- Each constellation gets 2 puzzle sectors (1 torpedo pod, 1 shield cell)
-- Sectors are chosen by hashing constellation coords to pick local tile offsets

local puzzleAssignments = {}
local puzzleStates = {}

-- Deterministic hash for picking puzzle sectors
local function sectorHash(cx, cy, salt)
  local h = math.abs((cx * 73856093 + cy * 19349663 + salt * 83492791) % 2147483647)
  return h
end

-- Initialize puzzle assignments for all 9 constellations
function M.initAssignments()
  puzzleAssignments = {}
  
  local constellationKeys = {
    {cx = 0, cy = 0,  id = "nebula",    puzzle1 = M.PUZZLE_NEBULA_MEMORY,   puzzle2 = M.PUZZLE_SPINNING_LOCK},
    {cx = 1, cy = 0,  id = "gargantua", puzzle1 = M.PUZZLE_GRAVITY_RINGS,   puzzle2 = M.PUZZLE_DEEP_SPACE_BOSS},
    {cx = -1, cy = 0, id = "pleiades",  puzzle1 = M.PUZZLE_CRYSTAL_ALIGN,   puzzle2 = M.PUZZLE_HIDDEN_PORTAL},
    {cx = 0, cy = 1,  id = "oort",      puzzle1 = M.PUZZLE_COMET_CATCH,     puzzle2 = M.PUZZLE_SPINNING_LOCK},
    {cx = 0, cy = -1, id = "messier",   puzzle1 = M.PUZZLE_HIDDEN_PORTAL,   puzzle2 = M.PUZZLE_DEEP_SPACE_BOSS},
    {cx = 1, cy = 1,  id = "vela",      puzzle1 = M.PUZZLE_PULSAR_TIMING,   puzzle2 = M.PUZZLE_SPINNING_LOCK},
    {cx = -1, cy = 1, id = "pandora",   puzzle1 = M.PUZZLE_HEAT_MAZE,       puzzle2 = M.PUZZLE_DEEP_SPACE_BOSS},
    {cx = -1, cy = -1,id = "orion",     puzzle1 = M.PUZZLE_SPINNING_LOCK,   puzzle2 = M.PUZZLE_HIDDEN_PORTAL},
    {cx = 1, cy = -1, id = "andromeda", puzzle1 = M.PUZZLE_DEEP_SPACE_BOSS, puzzle2 = M.PUZZLE_CRYSTAL_ALIGN},
  }
  
  for _, cDef in ipairs(constellationKeys) do
    -- Pick two non-overlapping sectors within the 7x7 constellation grid
    -- Avoid center tile (often has stations/portals) and edge tiles
    local candidates = {}
    for lx = 1, 5 do
      for ly = 1, 5 do
        -- Convert local coords to absolute tile coords
        local tileX = cDef.cx * 7 + (lx - 3)
        local tileY = cDef.cy * 7 + (ly - 3)
        -- Skip the center tile and any tiles that might have stations/portals
        if not (lx == 3 and ly == 3) then
          table.insert(candidates, {tx = tileX, ty = tileY, lx = lx, ly = ly})
        end
      end
    end
    
    -- Pick torpedo pod sector
    local hash1 = sectorHash(cDef.cx, cDef.cy, 1) % #candidates + 1
    local torpedoSector = candidates[hash1]
    
    -- Pick shield cell sector (different from torpedo)
    table.remove(candidates, hash1)
    local hash2 = sectorHash(cDef.cx, cDef.cy, 2) % #candidates + 1
    local shieldSector = candidates[hash2]
    
    -- Store assignments
    local key1 = torpedoSector.tx .. "," .. torpedoSector.ty
    local key2 = shieldSector.tx .. "," .. shieldSector.ty
    
    puzzleAssignments[key1] = {
      constellation = cDef.id,
      puzzleType = cDef.puzzle1,
      reward = M.REWARD_TORPEDO_POD,
      tileX = torpedoSector.tx,
      tileY = torpedoSector.ty,
    }
    
    puzzleAssignments[key2] = {
      constellation = cDef.id,
      puzzleType = cDef.puzzle2,
      reward = M.REWARD_SHIELD_CELL,
      tileX = shieldSector.tx,
      tileY = shieldSector.ty,
    }
  end
end

-- Check if a tile has a puzzle
function M.getPuzzleAt(tileX, tileY)
  local key = tileX .. "," .. tileY
  return puzzleAssignments[key]
end

-- ===================== PUZZLE STATE MANAGEMENT =====================

function M.getState(tileX, tileY)
  local key = tileX .. "," .. tileY
  if not puzzleStates[key] then
    puzzleStates[key] = {
      active = false,
      completed = false,
      rewardCollected = false,
      phase = "dormant",
      timer = 0,
      data = {},
    }
  end
  return puzzleStates[key]
end

function M.isCompleted(tileX, tileY)
  local state = M.getState(tileX, tileY)
  return state.rewardCollected
end

-- ===================== SCAN POWERUP =====================
M.scanActive = false
M.scanTimer = 0
M.scanRadius = 0
M.scanMaxRadius = 200  -- ~1/3 of screen area coverage
M.scanPulse = 0
M.scanUnlocked = false -- Unlocked at Singularity shop for 100 Notes
M.scanRevealed = {} -- tiles where hidden portals have been revealed

-- Sync scan unlock state from hub shop (call when entering/returning to asteroids)
function M.syncScanUnlock()
  local ok, hub = pcall(require, "hub.init")
  if ok and hub and hub.getShopItems then
    local items = hub.getShopItems()
    if items and items.scan then
      M.scanUnlocked = true
    end
  end
end

function M.updateScan(dt, shipX, shipY, screenW, screenH)
  if not M.scanUnlocked then return end
  
  if M.scanActive then
    M.scanTimer = M.scanTimer + dt
    M.scanPulse = M.scanPulse + dt * 6
    -- Expand scan radius smoothly
    M.scanRadius = math.min(M.scanMaxRadius, M.scanRadius + dt * 300)
  else
    -- Contract scan radius when released
    M.scanRadius = math.max(0, M.scanRadius - dt * 500)
    M.scanTimer = 0
  end
end

function M.drawScan(shipX, shipY)
  if M.scanRadius <= 0 then return end
  
  local time = love.timer.getTime()
  local pulse = math.sin(M.scanPulse) * 0.15
  
  -- Outer scan ring
  love.graphics.setLineWidth(2)
  love.graphics.setColor(0.2, 1.0, 0.4, 0.4 + pulse)
  love.graphics.circle("line", shipX, shipY, M.scanRadius)
  
  -- Inner scanning rings (sweeping)
  for i = 1, 3 do
    local ringRadius = M.scanRadius * (0.3 + i * 0.2)
    local ringAlpha = 0.15 + pulse * 0.5
    local offset = math.sin(time * 4 + i * 1.5) * 0.1
    love.graphics.setColor(0.1, 0.8 + offset, 0.3, ringAlpha)
    love.graphics.circle("line", shipX, shipY, ringRadius)
  end
  
  -- Scan fill (semi-transparent green)
  love.graphics.setColor(0.1, 0.8, 0.3, 0.05 + pulse * 0.03)
  love.graphics.circle("fill", shipX, shipY, M.scanRadius)
  
  -- Rotating scan line (radar sweep)
  local sweepAngle = time * 3
  local endX = shipX + math.cos(sweepAngle) * M.scanRadius
  local endY = shipY + math.sin(sweepAngle) * M.scanRadius
  love.graphics.setColor(0.2, 1.0, 0.4, 0.6)
  love.graphics.setLineWidth(1)
  love.graphics.line(shipX, shipY, endX, endY)
  
  -- Sweep trail
  for j = 1, 8 do
    local trailAngle = sweepAngle - j * 0.08
    local trailEndX = shipX + math.cos(trailAngle) * M.scanRadius
    local trailEndY = shipY + math.sin(trailAngle) * M.scanRadius
    love.graphics.setColor(0.2, 1.0, 0.4, 0.3 - j * 0.035)
    love.graphics.line(shipX, shipY, trailEndX, trailEndY)
  end
  
  -- Grid dots within scan area
  love.graphics.setColor(0.2, 0.9, 0.4, 0.15)
  local gridSize = 30
  for gx = -M.scanRadius, M.scanRadius, gridSize do
    for gy = -M.scanRadius, M.scanRadius, gridSize do
      local dist = math.sqrt(gx * gx + gy * gy)
      if dist < M.scanRadius then
        love.graphics.circle("fill", shipX + gx, shipY + gy, 1)
      end
    end
  end
  
  -- "SCANNING" text
  love.graphics.setFont(ui.getFont("hudSmall"))
  love.graphics.setColor(0.2, 1.0, 0.4, 0.7 + pulse)
  love.graphics.printf("SCANNING", shipX - 50, shipY - M.scanRadius - 18, 100, "center")
  
  love.graphics.setLineWidth(1)
end

-- ===================== SPINNING LOCK PUZZLE =====================
-- Player must shoot targets on spinning concentric rings. 
-- Hit all rings from outside-in to unlock. Miss = reset.

local function initSpinningLock(state, screenW, screenH)
  local cx, cy = screenW / 2, screenH / 2
  state.data = {
    centerX = cx,
    centerY = cy,
    rings = {},
    currentRing = 1,
    totalRings = 4,
    failed = false,
    failTimer = 0,
    successTimer = 0,
    allHit = false,
    hitFlash = 0,
    particles = {},
  }
  -- Create rings from outermost to innermost
  for i = 1, state.data.totalRings do
    local radius = 180 - (i - 1) * 40
    local speed = 1.5 + (i - 1) * 0.8  -- Inner rings spin faster
    local direction = (i % 2 == 0) and -1 or 1  -- Alternate direction
    table.insert(state.data.rings, {
      radius = radius,
      angle = math.random() * math.pi * 2,
      speed = speed * direction,
      targetAngle = 0,  -- Where the target is on the ring
      targetSize = math.max(12, 22 - i * 3),  -- Targets get smaller
      hit = false,
      hitFlash = 0,
      glowPulse = 0,
    })
    -- Randomize target position on ring
    state.data.rings[i].targetAngle = math.random() * math.pi * 2
  end
  state.active = true
  state.phase = "active"
end

local function updateSpinningLock(state, dt, bullets, screenW, screenH)
  local d = state.data
  if not d or d.allHit then
    if d and d.allHit then
      d.successTimer = d.successTimer + dt
    end
    return
  end
  
  -- Update ring rotations
  for i, ring in ipairs(d.rings) do
    if not ring.hit then
      ring.angle = ring.angle + ring.speed * dt
      ring.glowPulse = ring.glowPulse + dt * 4
    end
    if ring.hitFlash > 0 then
      ring.hitFlash = ring.hitFlash - dt * 2
    end
  end
  
  -- Update particles
  for i = #d.particles, 1, -1 do
    local p = d.particles[i]
    p.x = p.x + p.vx * dt
    p.y = p.y + p.vy * dt
    p.life = p.life - dt
    p.vy = p.vy + 30 * dt  -- slight gravity
    if p.life <= 0 then
      table.remove(d.particles, i)
    end
  end
  
  -- Fail reset animation
  if d.failed then
    d.failTimer = d.failTimer + dt
    if d.failTimer >= 1.5 then
      -- Reset all rings
      d.failed = false
      d.failTimer = 0
      d.currentRing = 1
      for _, ring in ipairs(d.rings) do
        ring.hit = false
        ring.targetAngle = math.random() * math.pi * 2
      end
    end
    return
  end
  
  -- Check bullet collisions with current ring target
  local ring = d.rings[d.currentRing]
  if ring and not ring.hit then
    local targetX = d.centerX + math.cos(ring.angle + ring.targetAngle) * ring.radius
    local targetY = d.centerY + math.sin(ring.angle + ring.targetAngle) * ring.radius
    
    for i = #bullets, 1, -1 do
      local b = bullets[i]
      if b.owner == "player" then
        local dist = math.sqrt((b.x - targetX)^2 + (b.y - targetY)^2)
        if dist < ring.targetSize + 5 then
          -- HIT!
          ring.hit = true
          ring.hitFlash = 1.0
          d.hitFlash = 1.0
          table.remove(bullets, i)
          
          -- Spawn hit particles
          for j = 1, 15 do
            local angle = math.random() * math.pi * 2
            local speed = 80 + math.random() * 150
            table.insert(d.particles, {
              x = targetX, y = targetY,
              vx = math.cos(angle) * speed,
              vy = math.sin(angle) * speed,
              life = 0.5 + math.random() * 0.5,
              size = 2 + math.random() * 3,
              r = 0.3, g = 1.0, b = 0.5,
            })
          end
          
          -- Advance to next ring
          d.currentRing = d.currentRing + 1
          if d.currentRing > d.totalRings then
            d.allHit = true
            d.successTimer = 0
          end
          break
        end
        
        -- Check if bullet hit wrong part of current ring (miss)
        local ringDist = math.sqrt((b.x - d.centerX)^2 + (b.y - d.centerY)^2)
        if math.abs(ringDist - ring.radius) < 15 and dist > ring.targetSize + 15 then
          -- MISS! Reset puzzle
          d.failed = true
          d.failTimer = 0
          table.remove(bullets, i)
          
          -- Spawn fail particles (red)
          for j = 1, 20 do
            local angle = math.random() * math.pi * 2
            local speed = 60 + math.random() * 100
            table.insert(d.particles, {
              x = b.x, y = b.y,
              vx = math.cos(angle) * speed,
              vy = math.sin(angle) * speed,
              life = 0.4 + math.random() * 0.3,
              size = 2 + math.random() * 2,
              r = 1.0, g = 0.2, b = 0.1,
            })
          end
          break
        end
      end
    end
  end
end

local function drawSpinningLock(state, screenW, screenH)
  local d = state.data
  if not d then return end
  
  local time = love.timer.getTime()
  
  -- Draw ambient glow at center
  love.graphics.setColor(0.1, 0.3, 0.5, 0.15)
  love.graphics.circle("fill", d.centerX, d.centerY, 200)
  
  -- Draw rings
  for i, ring in ipairs(d.rings) do
    local isCurrent = (i == d.currentRing and not d.allHit and not d.failed)
    local alpha = ring.hit and 0.3 or (isCurrent and 0.8 or 0.4)
    
    -- Ring circle
    love.graphics.setLineWidth(isCurrent and 3 or 2)
    if ring.hit then
      love.graphics.setColor(0.2, 0.8, 0.3, alpha)
    elseif isCurrent then
      local pulse = math.sin(ring.glowPulse) * 0.2
      love.graphics.setColor(0.3 + pulse, 0.6 + pulse, 1.0, alpha)
    else
      love.graphics.setColor(0.3, 0.3, 0.5, alpha)
    end
    love.graphics.circle("line", d.centerX, d.centerY, ring.radius)
    
    -- Target on ring
    local targetX = d.centerX + math.cos(ring.angle + ring.targetAngle) * ring.radius
    local targetY = d.centerY + math.sin(ring.angle + ring.targetAngle) * ring.radius
    
    if ring.hit then
      -- Hit target: green checkmark glow
      love.graphics.setColor(0.2, 1.0, 0.4, 0.5 + ring.hitFlash)
      love.graphics.circle("fill", targetX, targetY, ring.targetSize * 0.8)
      love.graphics.setColor(0.3, 1.0, 0.5, 0.8)
      love.graphics.circle("line", targetX, targetY, ring.targetSize)
    elseif isCurrent then
      -- Active target: pulsing bright
      local glow = math.sin(time * 5) * 0.2 + 0.8
      love.graphics.setColor(1.0, 0.8, 0.2, glow)
      love.graphics.circle("fill", targetX, targetY, ring.targetSize)
      -- Crosshair lines
      love.graphics.setColor(1, 1, 1, 0.6)
      love.graphics.setLineWidth(1)
      love.graphics.line(targetX - ring.targetSize - 5, targetY, targetX + ring.targetSize + 5, targetY)
      love.graphics.line(targetX, targetY - ring.targetSize - 5, targetX, targetY + ring.targetSize + 5)
      -- Target outline
      love.graphics.setColor(1.0, 0.9, 0.3, 1.0)
      love.graphics.setLineWidth(2)
      love.graphics.circle("line", targetX, targetY, ring.targetSize)
    else
      -- Inactive target: dim
      love.graphics.setColor(0.4, 0.4, 0.6, 0.4)
      love.graphics.circle("fill", targetX, targetY, ring.targetSize * 0.6)
    end
  end
  
  -- Draw particles
  for _, p in ipairs(d.particles) do
    local alpha = p.life / 0.8
    love.graphics.setColor(p.r, p.g, p.b, alpha)
    love.graphics.circle("fill", p.x, p.y, p.size * alpha)
  end
  
  -- Hit flash overlay
  if d.hitFlash and d.hitFlash > 0 then
    love.graphics.setColor(0.3, 1.0, 0.5, d.hitFlash * 0.15)
    love.graphics.rectangle("fill", 0, 0, screenW, screenH)
    d.hitFlash = d.hitFlash - love.timer.getDelta() * 3
  end
  
  -- Fail animation
  if d.failed then
    local progress = d.failTimer / 1.5
    love.graphics.setColor(1, 0.1, 0.1, (1 - progress) * 0.3)
    love.graphics.rectangle("fill", 0, 0, screenW, screenH)
    -- "MISS!" text
    love.graphics.setFont(ui.getFont("title"))
    love.graphics.setColor(1, 0.2, 0.1, 1 - progress)
    love.graphics.printf("MISS!", 0, screenH / 2 - 80, screenW, "center")
    love.graphics.setFont(ui.getFont("hud"))
    love.graphics.setColor(0.8, 0.8, 0.8, 1 - progress)
    love.graphics.printf("Puzzle resetting...", 0, screenH / 2 - 40, screenW, "center")
  end
  
  -- Success animation
  if d.allHit then
    local progress = math.min(1, d.successTimer / 2.0)
    -- Expanding golden rings
    for i = 1, 3 do
      local ringR = progress * 300 + i * 30
      local ringAlpha = (1 - progress) * 0.6
      love.graphics.setColor(1, 0.8, 0.2, ringAlpha)
      love.graphics.setLineWidth(3)
      love.graphics.circle("line", d.centerX, d.centerY, ringR)
    end
    love.graphics.setFont(ui.getFont("subtitle"))
    love.graphics.setColor(1, 0.9, 0.3, 1)
    love.graphics.printf("LOCK OPENED!", 0, d.centerY - 120, screenW, "center")
  end
  
  -- Progress indicator
  if not d.allHit and not d.failed then
    love.graphics.setFont(ui.getFont("hudLabel"))
    love.graphics.setColor(0.7, 0.7, 0.9, 0.8)
    love.graphics.printf("Ring " .. d.currentRing .. " of " .. d.totalRings, 
      0, d.centerY + 200, screenW, "center")
    love.graphics.setColor(0.5, 0.5, 0.7, 0.6)
    love.graphics.printf("Shoot the target! Miss the ring = reset", 
      0, d.centerY + 218, screenW, "center")
  end
  
  love.graphics.setLineWidth(1)
end

-- ===================== HIDDEN PORTAL (INDIANA JONES MAZE) =====================
-- A hidden portal revealed by Scan → leads to an obstacle maze sub-level

local function initHiddenPortal(state, screenW, screenH)
  state.data = {
    portalX = screenW / 2 + (math.random() - 0.5) * 400,
    portalY = screenH / 2 + (math.random() - 0.5) * 200,
    portalRadius = 40,
    revealed = false,
    revealProgress = 0,
    entered = false,
    -- Maze sub-level
    inMaze = false,
    mazeComplete = false,
    mazeTimer = 0,
    -- Indiana Jones obstacle maze
    mazeWalls = {},
    mazeBoulders = {},
    mazeTraps = {},
    mazeDarts = {},
    mazePlayerX = 0,
    mazePlayerY = 0,
    mazeGoalX = 0,
    mazeGoalY = 0,
    mazeShake = 0,
    particles = {},
  }
  
  -- Generate maze layout (simple grid-based)
  local mazeW, mazeH = 12, 8
  local cellW = screenW / mazeW
  local cellH = screenH / mazeH
  
  -- Create walls with gaps (maze paths)
  for row = 0, mazeH do
    for col = 0, mazeW do
      -- Horizontal walls
      if row > 0 and row < mazeH then
        local hasGap = sectorHash(col, row, 100 + state.data.portalX) % 3 ~= 0
        if not hasGap then
          table.insert(state.data.mazeWalls, {
            x1 = col * cellW, y1 = row * cellH,
            x2 = (col + 1) * cellW, y2 = row * cellH,
            horizontal = true,
          })
        end
      end
      -- Vertical walls
      if col > 0 and col < mazeW then
        local hasGap = sectorHash(col, row, 200 + state.data.portalY) % 3 ~= 0
        if not hasGap then
          table.insert(state.data.mazeWalls, {
            x1 = col * cellW, y1 = row * cellH,
            x2 = col * cellW, y2 = (row + 1) * cellH,
            horizontal = false,
          })
        end
      end
    end
  end
  
  -- Rolling boulders (Indiana Jones style)
  for i = 1, 3 do
    table.insert(state.data.mazeBoulders, {
      x = screenW * 0.3 + i * screenW * 0.2,
      y = -50 - i * 200,
      radius = 30 + math.random() * 15,
      speed = 80 + math.random() * 60,
      active = false,
      triggerY = screenH * (0.2 + i * 0.2),
      rotation = 0,
      rumble = 0,
    })
  end
  
  -- Dart traps (shoot from walls periodically)
  for i = 1, 5 do
    local side = (i % 2 == 0) and "left" or "right"
    table.insert(state.data.mazeTraps, {
      x = side == "left" and 0 or screenW,
      y = 80 + i * (screenH - 160) / 5,
      side = side,
      timer = math.random() * 3,
      interval = 2 + math.random() * 2,
      dartSpeed = 300 + math.random() * 200,
    })
  end
  
  state.data.mazeGoalX = screenW - 80
  state.data.mazeGoalY = screenH - 80
  
  state.active = true
  state.phase = "scanning"
end

local function updateHiddenPortal(state, dt, shipX, shipY, scanActive, scanRadius, screenW, screenH)
  local d = state.data
  if not d then return end
  
  -- Check if scan reveals the portal
  if not d.revealed and scanActive and scanRadius > 0 then
    local dist = math.sqrt((shipX - d.portalX)^2 + (shipY - d.portalY)^2)
    if dist < scanRadius then
      d.revealProgress = math.min(1, d.revealProgress + dt * 0.5)
      if d.revealProgress >= 1 then
        d.revealed = true
        state.phase = "revealed"
      end
    end
  end
  
  -- Update particles
  for i = #d.particles, 1, -1 do
    local p = d.particles[i]
    p.x = p.x + p.vx * dt
    p.y = p.y + p.vy * dt
    p.life = p.life - dt
    if p.life <= 0 then
      table.remove(d.particles, i)
    end
  end
  
  -- Maze mode
  if d.inMaze then
    d.mazeTimer = d.mazeTimer + dt
    d.mazePlayerX = shipX
    d.mazePlayerY = shipY
    
    -- Update shake
    d.mazeShake = math.max(0, d.mazeShake - dt * 5)
    
    -- Update boulders
    for _, boulder in ipairs(d.mazeBoulders) do
      if not boulder.active and shipY < boulder.triggerY and d.mazeTimer > 2 then
        boulder.active = true
        boulder.y = -boulder.radius
      end
      if boulder.active then
        boulder.y = boulder.y + boulder.speed * dt
        boulder.rotation = boulder.rotation + (boulder.speed / boulder.radius) * dt
        boulder.rumble = math.sin(d.mazeTimer * 20) * 2
        
        -- Check collision with player
        local dist = math.sqrt((shipX - boulder.x)^2 + (shipY - boulder.y)^2)
        if dist < boulder.radius + 15 then
          d.mazeShake = 1.0
          -- Push player away
          return "boulder_hit"
        end
        
        -- Reset when off screen
        if boulder.y > screenH + boulder.radius * 2 then
          boulder.active = false
          boulder.y = -boulder.radius
        end
      end
    end
    
    -- Update dart traps
    for _, trap in ipairs(d.mazeTraps) do
      trap.timer = trap.timer + dt
      if trap.timer >= trap.interval then
        trap.timer = 0
        -- Spawn dart
        local dart = {
          x = trap.x,
          y = trap.y,
          vx = trap.side == "left" and trap.dartSpeed or -trap.dartSpeed,
          vy = 0,
          life = 3,
          size = 4,
        }
        table.insert(d.mazeDarts, dart)
      end
    end
    
    -- Update darts
    for i = #d.mazeDarts, 1, -1 do
      local dart = d.mazeDarts[i]
      dart.x = dart.x + dart.vx * dt
      dart.y = dart.y + dart.vy * dt
      dart.life = dart.life - dt
      
      -- Check collision with player
      local dist = math.sqrt((shipX - dart.x)^2 + (shipY - dart.y)^2)
      if dist < 18 then
        table.remove(d.mazeDarts, i)
        return "dart_hit"
      end
      
      if dart.life <= 0 or dart.x < -20 or dart.x > screenW + 20 then
        table.remove(d.mazeDarts, i)
      end
    end
    
    -- Check goal reached
    local goalDist = math.sqrt((shipX - d.mazeGoalX)^2 + (shipY - d.mazeGoalY)^2)
    if goalDist < 50 then
      d.mazeComplete = true
      d.inMaze = false
      state.phase = "complete"
    end
  end
  
  return nil
end

local function drawHiddenPortal(state, shipX, shipY, screenW, screenH)
  local d = state.data
  if not d then return end
  local time = love.timer.getTime()
  
  if d.inMaze then
    -- === MAZE SUB-LEVEL ===
    -- Dark dungeon background
    love.graphics.setColor(0.05, 0.04, 0.03, 1)
    love.graphics.rectangle("fill", 0, 0, screenW, screenH)
    
    -- Shake offset
    local sx = d.mazeShake > 0 and (math.random() - 0.5) * d.mazeShake * 8 or 0
    local sy = d.mazeShake > 0 and (math.random() - 0.5) * d.mazeShake * 8 or 0
    love.graphics.push()
    love.graphics.translate(sx, sy)
    
    -- Draw maze walls (stone texture look)
    love.graphics.setLineWidth(4)
    for _, wall in ipairs(d.mazeWalls) do
      love.graphics.setColor(0.35, 0.3, 0.2, 0.9)
      love.graphics.line(wall.x1, wall.y1, wall.x2, wall.y2)
      -- Stone texture highlight
      love.graphics.setColor(0.45, 0.4, 0.3, 0.4)
      love.graphics.line(wall.x1, wall.y1 - 1, wall.x2, wall.y2 - 1)
    end
    
    -- Draw dart traps (wall slots)
    for _, trap in ipairs(d.mazeTraps) do
      love.graphics.setColor(0.2, 0.15, 0.1, 0.9)
      local tx = trap.side == "left" and 0 or screenW - 10
      love.graphics.rectangle("fill", tx, trap.y - 6, 10, 12)
      -- Red warning glow near firing
      local timeToFire = trap.interval - trap.timer
      if timeToFire < 0.5 then
        love.graphics.setColor(1, 0.2, 0.1, (0.5 - timeToFire) * 1.5)
        love.graphics.circle("fill", trap.x, trap.y, 8)
      end
    end
    
    -- Draw darts
    for _, dart in ipairs(d.mazeDarts) do
      love.graphics.setColor(0.8, 0.8, 0.2, 1)
      local angle = math.atan2(dart.vy, dart.vx)
      love.graphics.push()
      love.graphics.translate(dart.x, dart.y)
      love.graphics.rotate(angle)
      -- Arrow shape
      love.graphics.polygon("fill", 8, 0, -4, -3, -4, 3)
      love.graphics.setColor(0.6, 0.4, 0.2, 1)
      love.graphics.rectangle("fill", -12, -1, 10, 2)
      love.graphics.pop()
    end
    
    -- Draw boulders (Indiana Jones style)
    for _, boulder in ipairs(d.mazeBoulders) do
      if boulder.active then
        love.graphics.push()
        love.graphics.translate(boulder.x + (boulder.rumble or 0), boulder.y)
        love.graphics.rotate(boulder.rotation)
        -- Rock body
        love.graphics.setColor(0.45, 0.4, 0.35, 1)
        love.graphics.circle("fill", 0, 0, boulder.radius)
        -- Texture cracks
        love.graphics.setColor(0.3, 0.25, 0.2, 0.6)
        love.graphics.line(-boulder.radius * 0.3, -boulder.radius * 0.5, boulder.radius * 0.2, boulder.radius * 0.3)
        love.graphics.line(boulder.radius * 0.4, -boulder.radius * 0.2, -boulder.radius * 0.1, boulder.radius * 0.4)
        -- Highlight
        love.graphics.setColor(0.55, 0.5, 0.4, 0.3)
        love.graphics.arc("fill", 0, 0, boulder.radius * 0.8, -math.pi * 0.7, -math.pi * 0.2)
        love.graphics.pop()
        
        -- Dust trail
        love.graphics.setColor(0.5, 0.45, 0.35, 0.3)
        for j = 1, 5 do
          local dustX = boulder.x + (math.random() - 0.5) * boulder.radius
          local dustY = boulder.y - boulder.radius - math.random() * 20
          love.graphics.circle("fill", dustX, dustY, 3 + math.random() * 4)
        end
      end
    end
    
    -- Draw goal (treasure chest glow)
    local goalPulse = math.sin(time * 3) * 0.2 + 0.8
    love.graphics.setColor(1, 0.8, 0.2, goalPulse * 0.3)
    love.graphics.circle("fill", d.mazeGoalX, d.mazeGoalY, 50)
    love.graphics.setColor(1, 0.9, 0.3, goalPulse)
    love.graphics.circle("fill", d.mazeGoalX, d.mazeGoalY, 20)
    -- Chest icon
    love.graphics.setColor(0.7, 0.5, 0.2, 1)
    love.graphics.rectangle("fill", d.mazeGoalX - 15, d.mazeGoalY - 10, 30, 20, 3, 3)
    love.graphics.setColor(0.9, 0.7, 0.3, 1)
    love.graphics.rectangle("line", d.mazeGoalX - 15, d.mazeGoalY - 10, 30, 20, 3, 3)
    love.graphics.setColor(1, 0.8, 0.2, 1)
    love.graphics.circle("fill", d.mazeGoalX, d.mazeGoalY, 4)
    
    love.graphics.pop()
    
    -- Maze HUD
    love.graphics.setFont(ui.getFont("hudLabel"))
    love.graphics.setColor(0.8, 0.7, 0.5, 0.9)
    love.graphics.printf("ANCIENT PASSAGE", 0, 10, screenW, "center")
    love.graphics.setFont(ui.getFont("hudSmall"))
    love.graphics.setColor(0.6, 0.5, 0.4, 0.7)
    love.graphics.printf("Reach the treasure! Avoid the traps!", 0, 30, screenW, "center")
    
    love.graphics.setLineWidth(1)
    return
  end
  
  -- === OVERWORLD (portal reveal) ===
  -- Draw hidden portal shimmer (visible only when scanning or revealed)
  if d.revealed or d.revealProgress > 0 then
    local alpha = d.revealed and 1.0 or d.revealProgress
    
    -- Portal shimmer
    love.graphics.setColor(0.2, 0.8, 1.0, alpha * 0.3)
    love.graphics.circle("fill", d.portalX, d.portalY, d.portalRadius * 1.5)
    
    -- Swirling rings
    for i = 1, 4 do
      local angle = time * (1 + i * 0.5) + i * math.pi / 2
      local r = d.portalRadius * (0.8 + math.sin(time * 2 + i) * 0.2)
      love.graphics.setColor(0.3, 0.6, 1.0, alpha * (0.6 - i * 0.1))
      love.graphics.setLineWidth(2)
      love.graphics.arc("line", "open", d.portalX, d.portalY, r, angle, angle + math.pi * 0.8)
    end
    
    -- Core glow
    love.graphics.setColor(0.5, 0.9, 1.0, alpha * 0.8)
    love.graphics.circle("fill", d.portalX, d.portalY, d.portalRadius * 0.5)
    love.graphics.setColor(1, 1, 1, alpha * 0.5)
    love.graphics.circle("fill", d.portalX, d.portalY, d.portalRadius * 0.25)
    
    if d.revealed then
      love.graphics.setFont(ui.getFont("hudLabel"))
      love.graphics.setColor(0.5, 0.9, 1.0, 0.7 + math.sin(time * 3) * 0.3)
      love.graphics.printf("HIDDEN PASSAGE", d.portalX - 80, d.portalY - d.portalRadius - 25, 160, "center")
      love.graphics.setFont(ui.getFont("hudSmall"))
      love.graphics.setColor(0.5, 0.7, 0.9, 0.6)
      love.graphics.printf("Fly into the portal", d.portalX - 80, d.portalY + d.portalRadius + 10, 160, "center")
    end
  end
  
  -- Particles
  for _, p in ipairs(d.particles) do
    local alpha = p.life / 1.0
    love.graphics.setColor(0.3, 0.7, 1.0, alpha)
    love.graphics.circle("fill", p.x, p.y, p.size)
  end
  
  love.graphics.setLineWidth(1)
end

-- ===================== DEEP SPACE BOSS =====================
-- Multi-phase boss fight with fancy animations

local function initDeepSpaceBoss(state, screenW, screenH, constellationId)
  -- Boss palette varies by constellation
  local palettes = {
    gargantua = {body = {0.6, 0.3, 0.1}, eye = {1, 0.5, 0}, name = "Abyssal Devourer"},
    messier   = {body = {0.5, 0.4, 0.2}, eye = {1, 0.9, 0.4}, name = "Golden Sentinel"},
    pandora   = {body = {0.3, 0.3, 0.6}, eye = {0.5, 0.3, 1}, name = "Chaos Hydra"},
    andromeda = {body = {0.4, 0.2, 0.5}, eye = {0.8, 0.3, 1}, name = "Spiral Wraith"},
  }
  local palette = palettes[constellationId] or {body = {0.4, 0.4, 0.5}, eye = {1, 0.3, 0.3}, name = "Void Guardian"}
  
  state.data = {
    boss = {
      x = screenW / 2,
      y = 120,
      hp = 300,
      maxHp = 300,
      phase = 1,   -- 3 phases
      name = palette.name,
      bodyColor = palette.body,
      eyeColor = palette.eye,
      size = 60,
      angle = 0,
      moveTimer = 0,
      movePattern = "hover",
      attackTimer = 0,
      attackCooldown = 2.0,
      invuln = false,
      invulnTimer = 0,
      shieldAngle = 0,
      tentacles = {},
      orbs = {},
      phaseTransition = false,
      phaseTransTimer = 0,
      deathTimer = 0,
      dead = false,
    },
    projectiles = {},
    particles = {},
    screenFlash = 0,
    screenShake = 0,
    phaseAnnounce = "",
    phaseAnnounceTimer = 0,
  }
  
  -- Initialize tentacles
  local d = state.data
  for i = 1, 6 do
    table.insert(d.boss.tentacles, {
      baseAngle = (i / 6) * math.pi * 2,
      length = 80 + math.random() * 30,
      segments = 8,
      wave = math.random() * math.pi * 2,
      waveSpeed = 2 + math.random(),
    })
  end
  
  state.active = true
  state.phase = "boss_fight"
  d.phaseAnnounce = "PHASE 1 - " .. string.upper(d.boss.name)
  d.phaseAnnounceTimer = 3.0
end

local function updateDeepSpaceBoss(state, dt, shipX, shipY, bullets, screenW, screenH)
  local d = state.data
  if not d or not d.boss then return end
  local boss = d.boss
  
  -- Update screen effects
  d.screenFlash = math.max(0, d.screenFlash - dt * 3)
  d.screenShake = math.max(0, d.screenShake - dt * 4)
  d.phaseAnnounceTimer = math.max(0, d.phaseAnnounceTimer - dt)
  
  -- Update particles
  for i = #d.particles, 1, -1 do
    local p = d.particles[i]
    p.x = p.x + p.vx * dt
    p.y = p.y + p.vy * dt
    p.life = p.life - dt
    if p.life <= 0 then
      table.remove(d.particles, i)
    end
  end
  
  if boss.dead then
    boss.deathTimer = boss.deathTimer + dt
    -- Death explosion particles
    if boss.deathTimer < 3.0 and math.random() < dt * 30 then
      for j = 1, 3 do
        local angle = math.random() * math.pi * 2
        local speed = 50 + math.random() * 200
        local ox = (math.random() - 0.5) * boss.size
        local oy = (math.random() - 0.5) * boss.size
        table.insert(d.particles, {
          x = boss.x + ox, y = boss.y + oy,
          vx = math.cos(angle) * speed, vy = math.sin(angle) * speed,
          life = 0.5 + math.random() * 1.0,
          size = 3 + math.random() * 6,
          r = boss.eyeColor[1], g = boss.eyeColor[2], b = boss.eyeColor[3],
        })
      end
    end
    if boss.deathTimer >= 4.0 then
      state.phase = "complete"
    end
    return
  end
  
  -- Phase transition animation
  if boss.phaseTransition then
    boss.phaseTransTimer = boss.phaseTransTimer + dt
    boss.invuln = true
    
    -- Dramatic animation during transition
    d.screenShake = 0.3
    if math.random() < dt * 15 then
      local angle = math.random() * math.pi * 2
      local speed = 100 + math.random() * 150
      table.insert(d.particles, {
        x = boss.x + (math.random() - 0.5) * boss.size,
        y = boss.y + (math.random() - 0.5) * boss.size,
        vx = math.cos(angle) * speed, vy = math.sin(angle) * speed,
        life = 0.8, size = 4 + math.random() * 4,
        r = boss.eyeColor[1], g = boss.eyeColor[2], b = boss.eyeColor[3],
      })
    end
    
    if boss.phaseTransTimer >= 3.0 then
      boss.phaseTransition = false
      boss.invuln = false
      boss.phase = boss.phase + 1
      boss.attackCooldown = math.max(0.5, boss.attackCooldown - 0.5)
      d.phaseAnnounce = "PHASE " .. boss.phase
      d.phaseAnnounceTimer = 2.0
      d.screenFlash = 1.0
      
      -- Phase 2: Boss grows larger and faster
      if boss.phase == 2 then
        boss.size = 75
        boss.movePattern = "circle"
      elseif boss.phase == 3 then
        boss.size = 90
        boss.movePattern = "aggressive"
      end
    end
    return
  end
  
  -- Boss movement
  boss.moveTimer = boss.moveTimer + dt
  boss.angle = boss.angle + dt * 0.5
  boss.shieldAngle = boss.shieldAngle + dt * 2
  
  if boss.movePattern == "hover" then
    boss.x = screenW / 2 + math.sin(boss.moveTimer * 0.8) * 200
    boss.y = 120 + math.sin(boss.moveTimer * 0.5) * 40
  elseif boss.movePattern == "circle" then
    boss.x = screenW / 2 + math.cos(boss.moveTimer * 1.2) * 250
    boss.y = 150 + math.sin(boss.moveTimer * 1.2) * 100
  elseif boss.movePattern == "aggressive" then
    -- Periodically dash toward player
    local dashPhase = boss.moveTimer % 5
    if dashPhase < 3 then
      boss.x = screenW / 2 + math.sin(boss.moveTimer * 1.5) * 300
      boss.y = 130 + math.sin(boss.moveTimer * 0.8) * 60
    else
      -- Dash toward player
      local dx = shipX - boss.x
      local dy = shipY - boss.y
      local dist = math.sqrt(dx * dx + dy * dy)
      if dist > 10 then
        boss.x = boss.x + (dx / dist) * 200 * dt
        boss.y = boss.y + (dy / dist) * 200 * dt
      end
    end
  end
  
  -- Update tentacles
  for _, tent in ipairs(boss.tentacles) do
    tent.wave = tent.wave + tent.waveSpeed * dt
  end
  
  -- Boss attacks
  boss.attackTimer = boss.attackTimer + dt
  if boss.attackTimer >= boss.attackCooldown then
    boss.attackTimer = 0
    
    if boss.phase == 1 then
      -- Phase 1: Radial burst
      for i = 1, 8 do
        local angle = (i / 8) * math.pi * 2 + boss.angle
        table.insert(d.projectiles, {
          x = boss.x, y = boss.y,
          vx = math.cos(angle) * 180,
          vy = math.sin(angle) * 180,
          life = 4, size = 5,
          r = boss.eyeColor[1], g = boss.eyeColor[2], b = boss.eyeColor[3],
        })
      end
    elseif boss.phase == 2 then
      -- Phase 2: Aimed triple shot
      local dx = shipX - boss.x
      local dy = shipY - boss.y
      local baseAngle = math.atan2(dy, dx)
      for i = -1, 1 do
        local angle = baseAngle + i * 0.2
        table.insert(d.projectiles, {
          x = boss.x, y = boss.y,
          vx = math.cos(angle) * 250,
          vy = math.sin(angle) * 250,
          life = 3, size = 6,
          r = boss.eyeColor[1], g = boss.eyeColor[2], b = boss.eyeColor[3],
        })
      end
    elseif boss.phase == 3 then
      -- Phase 3: Spiral pattern
      for i = 1, 12 do
        local angle = (i / 12) * math.pi * 2 + boss.angle * 3
        table.insert(d.projectiles, {
          x = boss.x, y = boss.y,
          vx = math.cos(angle) * (150 + i * 15),
          vy = math.sin(angle) * (150 + i * 15),
          life = 3.5, size = 4,
          r = boss.eyeColor[1], g = boss.eyeColor[2], b = boss.eyeColor[3],
        })
      end
    end
  end
  
  -- Update boss projectiles
  for i = #d.projectiles, 1, -1 do
    local p = d.projectiles[i]
    p.x = p.x + p.vx * dt
    p.y = p.y + p.vy * dt
    p.life = p.life - dt
    if p.life <= 0 or p.x < -50 or p.x > screenW + 50 or p.y < -50 or p.y > screenH + 50 then
      table.remove(d.projectiles, i)
    end
  end
  
  -- Check player bullets hitting boss
  if not boss.invuln then
    for i = #bullets, 1, -1 do
      local b = bullets[i]
      if b.owner == "player" then
        local dist = math.sqrt((b.x - boss.x)^2 + (b.y - boss.y)^2)
        if dist < boss.size then
          boss.hp = boss.hp - 10
          table.remove(bullets, i)
          d.screenFlash = 0.2
          
          -- Hit particles
          for j = 1, 5 do
            local angle = math.random() * math.pi * 2
            local speed = 80 + math.random() * 100
            table.insert(d.particles, {
              x = b.x, y = b.y,
              vx = math.cos(angle) * speed, vy = math.sin(angle) * speed,
              life = 0.3 + math.random() * 0.3,
              size = 2 + math.random() * 2,
              r = 1, g = 1, b = 1,
            })
          end
          
          -- Check phase transitions
          if boss.hp <= 0 then
            boss.dead = true
            boss.deathTimer = 0
            d.screenFlash = 1.0
            d.screenShake = 1.0
          elseif boss.phase == 1 and boss.hp <= boss.maxHp * 0.66 then
            boss.phaseTransition = true
            boss.phaseTransTimer = 0
          elseif boss.phase == 2 and boss.hp <= boss.maxHp * 0.33 then
            boss.phaseTransition = true
            boss.phaseTransTimer = 0
          end
          break
        end
      end
    end
  end
  
  -- Return boss projectiles for collision with player (handled externally)
  return d.projectiles
end

local function drawDeepSpaceBoss(state, screenW, screenH)
  local d = state.data
  if not d or not d.boss then return end
  local boss = d.boss
  local time = love.timer.getTime()
  
  -- Screen shake
  if d.screenShake > 0 then
    love.graphics.push()
    love.graphics.translate(
      (math.random() - 0.5) * d.screenShake * 10,
      (math.random() - 0.5) * d.screenShake * 10
    )
  end
  
  if not boss.dead then
    -- Draw tentacles
    for _, tent in ipairs(boss.tentacles) do
      local prevX, prevY = boss.x, boss.y
      for seg = 1, tent.segments do
        local t = seg / tent.segments
        local wave = math.sin(tent.wave + seg * 0.5) * 15 * t
        local angle = tent.baseAngle + boss.angle + wave * 0.02
        local segLen = tent.length / tent.segments
        local nx = prevX + math.cos(angle) * segLen + math.sin(tent.wave + seg) * wave * 0.3
        local ny = prevY + math.sin(angle) * segLen + math.cos(tent.wave + seg) * wave * 0.3
        
        local thickness = (1 - t) * 6 + 1
        local alpha = (1 - t) * 0.7 + 0.2
        love.graphics.setColor(boss.bodyColor[1], boss.bodyColor[2], boss.bodyColor[3], alpha)
        love.graphics.setLineWidth(thickness)
        love.graphics.line(prevX, prevY, nx, ny)
        
        prevX, prevY = nx, ny
      end
    end
    
    -- Draw body
    local pulse = math.sin(time * 3) * 0.1
    
    -- Outer glow
    love.graphics.setColor(boss.eyeColor[1], boss.eyeColor[2], boss.eyeColor[3], 0.15 + pulse)
    love.graphics.circle("fill", boss.x, boss.y, boss.size * 1.4)
    
    -- Main body
    love.graphics.setColor(boss.bodyColor[1] + pulse, boss.bodyColor[2], boss.bodyColor[3], 0.9)
    love.graphics.circle("fill", boss.x, boss.y, boss.size)
    
    -- Armor plating (rotating segments)
    love.graphics.setLineWidth(3)
    local armorSegments = boss.phase >= 2 and 8 or 6
    for i = 1, armorSegments do
      local angle = (i / armorSegments) * math.pi * 2 + boss.shieldAngle
      local arcLen = math.pi * 2 / armorSegments * 0.6
      love.graphics.setColor(boss.bodyColor[1] + 0.2, boss.bodyColor[2] + 0.1, boss.bodyColor[3] + 0.1, 0.7)
      love.graphics.arc("line", "open", boss.x, boss.y, boss.size * 0.85, angle, angle + arcLen)
    end
    
    -- Eye (center)
    local eyeSize = boss.size * 0.3
    love.graphics.setColor(0, 0, 0, 0.9)
    love.graphics.circle("fill", boss.x, boss.y, eyeSize * 1.1)
    love.graphics.setColor(boss.eyeColor[1], boss.eyeColor[2], boss.eyeColor[3], 0.9)
    love.graphics.circle("fill", boss.x, boss.y, eyeSize)
    -- Pupil (tracks player)
    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.circle("fill", boss.x, boss.y, eyeSize * 0.4)
    -- Eye highlight
    love.graphics.setColor(1, 1, 1, 0.6)
    love.graphics.circle("fill", boss.x - eyeSize * 0.2, boss.y - eyeSize * 0.2, eyeSize * 0.15)
    
    -- Phase transition effects
    if boss.phaseTransition then
      local progress = boss.phaseTransTimer / 3.0
      local flashAlpha = math.sin(progress * math.pi * 8) * 0.3
      love.graphics.setColor(boss.eyeColor[1], boss.eyeColor[2], boss.eyeColor[3], flashAlpha)
      love.graphics.circle("fill", boss.x, boss.y, boss.size * (1.5 + progress))
      
      -- Warning text
      love.graphics.setFont(ui.getFont("medium"))
      love.graphics.setColor(1, 0.3, 0.2, 0.5 + math.sin(time * 6) * 0.3)
      love.graphics.printf("POWERING UP!", 0, boss.y + boss.size + 20, screenW, "center")
    end
    
    -- Invulnerability indicator
    if boss.invuln and not boss.phaseTransition then
      love.graphics.setColor(1, 1, 1, 0.3 + math.sin(time * 10) * 0.2)
      love.graphics.circle("line", boss.x, boss.y, boss.size + 5)
    end
  else
    -- Death animation
    local deathProgress = boss.deathTimer / 4.0
    if deathProgress < 0.8 then
      -- Flickering body
      local flicker = math.sin(boss.deathTimer * 30) > 0
      if flicker then
        love.graphics.setColor(boss.bodyColor[1], boss.bodyColor[2], boss.bodyColor[3], 0.5)
        love.graphics.circle("fill", boss.x, boss.y, boss.size * (1 - deathProgress * 0.5))
      end
      love.graphics.setColor(boss.eyeColor[1], boss.eyeColor[2], boss.eyeColor[3], 0.8)
      love.graphics.circle("fill", boss.x, boss.y, boss.size * 0.3 * (1 - deathProgress))
    end
    -- Final explosion flash
    if deathProgress > 0.7 and deathProgress < 0.9 then
      local flashAlpha = (1 - (deathProgress - 0.7) / 0.2)
      love.graphics.setColor(1, 1, 1, flashAlpha)
      love.graphics.rectangle("fill", 0, 0, screenW, screenH)
    end
  end
  
  -- Draw boss projectiles
  for _, p in ipairs(d.projectiles) do
    local alpha = math.min(1, p.life)
    love.graphics.setColor(p.r, p.g, p.b, alpha * 0.3)
    love.graphics.circle("fill", p.x, p.y, p.size * 2)
    love.graphics.setColor(p.r, p.g, p.b, alpha * 0.8)
    love.graphics.circle("fill", p.x, p.y, p.size)
    love.graphics.setColor(1, 1, 1, alpha * 0.5)
    love.graphics.circle("fill", p.x, p.y, p.size * 0.4)
  end
  
  -- Draw particles
  for _, p in ipairs(d.particles) do
    local alpha = p.life / 1.0
    love.graphics.setColor(p.r, p.g, p.b, alpha)
    love.graphics.circle("fill", p.x, p.y, p.size * alpha)
  end
  
  -- Screen flash
  if d.screenFlash > 0 then
    love.graphics.setColor(1, 1, 1, d.screenFlash * 0.4)
    love.graphics.rectangle("fill", 0, 0, screenW, screenH)
  end
  
  if d.screenShake > 0 then
    love.graphics.pop()
  end
  
  -- Boss HP bar
  if not boss.dead then
    local barW = 300
    local barH = 12
    local barX = (screenW - barW) / 2
    local barY = 20
    
    -- Background
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", barX - 2, barY - 2, barW + 4, barH + 4, 3, 3)
    
    -- HP fill
    local hpPct = boss.hp / boss.maxHp
    local r = 1 - hpPct
    local g = hpPct
    love.graphics.setColor(r, g, 0.1, 0.9)
    love.graphics.rectangle("fill", barX, barY, barW * hpPct, barH, 2, 2)
    
    -- Border
    love.graphics.setColor(0.6, 0.6, 0.7, 0.8)
    love.graphics.rectangle("line", barX, barY, barW, barH, 2, 2)
    
    -- Boss name
    love.graphics.setFont(ui.getFont("hudSmall"))
    love.graphics.setColor(1, 1, 1, 0.9)
    love.graphics.printf(boss.name, barX, barY + barH + 3, barW, "center")
  end
  
  -- Phase announcement
  if d.phaseAnnounceTimer > 0 then
    local alpha = math.min(1, d.phaseAnnounceTimer)
    love.graphics.setFont(ui.getFont("subtitle"))
    love.graphics.setColor(boss.eyeColor[1], boss.eyeColor[2], boss.eyeColor[3], alpha)
    love.graphics.printf(d.phaseAnnounce, 0, screenH / 2 - 100, screenW, "center")
  end
  
  love.graphics.setLineWidth(1)
end

-- ===================== HEAT MAZE PUZZLE (Pandora) =====================
-- Navigate invisible "cool" paths through a heat zone

local function initHeatMaze(state, screenW, screenH)
  -- Generate cool path through the hot zone
  local pathWidth = 50
  local path = {}
  local x = 60
  local y = screenH / 2
  
  while x < screenW - 60 do
    table.insert(path, {x = x, y = y})
    x = x + 30 + math.random() * 20
    y = y + (math.random() - 0.5) * 80
    y = math.max(60, math.min(screenH - 60, y))
  end
  -- Final point at goal
  table.insert(path, {x = screenW - 60, y = screenH / 2})
  
  state.data = {
    path = path,
    pathWidth = pathWidth,
    goalX = screenW - 60,
    goalY = screenH / 2,
    startX = 60,
    startY = screenH / 2,
    heatDamageTimer = 0,
    heatPulse = 0,
    playerOnPath = false,
    goalReached = false,
    goalTimer = 0,
    -- Hint particles that drift along the cool path
    hintParticles = {},
    heatDistortion = 0,
    particles = {},
  }
  
  -- Pre-generate hint particles
  for i = 1, 30 do
    local idx = math.random(#path)
    local pt = path[idx]
    table.insert(state.data.hintParticles, {
      x = pt.x + (math.random() - 0.5) * pathWidth * 0.5,
      y = pt.y + (math.random() - 0.5) * pathWidth * 0.5,
      baseX = pt.x,
      baseY = pt.y,
      drift = math.random() * math.pi * 2,
      driftSpeed = 0.5 + math.random(),
      size = 1 + math.random() * 2,
      alpha = 0.1 + math.random() * 0.2,
    })
  end
  
  state.active = true
  state.phase = "active"
end

local function updateHeatMaze(state, dt, shipX, shipY, screenW, screenH)
  local d = state.data
  if not d then return end
  
  if d.goalReached then
    d.goalTimer = d.goalTimer + dt
    if d.goalTimer >= 2.0 then
      state.phase = "complete"
    end
    return
  end
  
  d.heatPulse = d.heatPulse + dt * 3
  d.heatDistortion = d.heatDistortion + dt * 5
  
  -- Check if player is on the cool path
  d.playerOnPath = false
  for i = 1, #d.path - 1 do
    local p1 = d.path[i]
    local p2 = d.path[i + 1]
    -- Distance from ship to line segment
    local dx = p2.x - p1.x
    local dy = p2.y - p1.y
    local lenSq = dx * dx + dy * dy
    local t = math.max(0, math.min(1, ((shipX - p1.x) * dx + (shipY - p1.y) * dy) / lenSq))
    local projX = p1.x + t * dx
    local projY = p1.y + t * dy
    local dist = math.sqrt((shipX - projX)^2 + (shipY - projY)^2)
    if dist < d.pathWidth then
      d.playerOnPath = true
      break
    end
  end
  
  -- Heat damage when off-path
  if not d.playerOnPath then
    d.heatDamageTimer = d.heatDamageTimer + dt
    return "heat_damage"  -- Signal to apply damage
  else
    d.heatDamageTimer = 0
  end
  
  -- Update hint particles
  for _, hp in ipairs(d.hintParticles) do
    hp.drift = hp.drift + hp.driftSpeed * dt
    hp.x = hp.baseX + math.sin(hp.drift) * 10
    hp.y = hp.baseY + math.cos(hp.drift) * 10
  end
  
  -- Check goal
  local goalDist = math.sqrt((shipX - d.goalX)^2 + (shipY - d.goalY)^2)
  if goalDist < 40 then
    d.goalReached = true
    d.goalTimer = 0
  end
end

local function drawHeatMaze(state, shipX, shipY, screenW, screenH)
  local d = state.data
  if not d then return end
  local time = love.timer.getTime()
  
  -- Heat distortion overlay (red/orange waves)
  local heatAlpha = 0.15 + math.sin(d.heatPulse) * 0.05
  love.graphics.setColor(1, 0.3, 0.05, heatAlpha)
  love.graphics.rectangle("fill", 0, 0, screenW, screenH)
  
  -- Heat shimmer lines (horizontal wavy lines)
  love.graphics.setColor(1, 0.5, 0.1, 0.08)
  for y = 0, screenH, 20 do
    local waveOffset = math.sin(d.heatDistortion + y * 0.05) * 15
    love.graphics.line(0, y + waveOffset, screenW, y + waveOffset)
  end
  
  -- Draw cool path (subtle, nearly invisible)
  -- The path is only clearly visible with Scan or very subtly with hint particles
  if M.scanActive and M.scanRadius > 0 then
    -- Show path within scan range
    for i = 1, #d.path - 1 do
      local p1 = d.path[i]
      local p2 = d.path[i + 1]
      local midX = (p1.x + p2.x) / 2
      local midY = (p1.y + p2.y) / 2
      local dist = math.sqrt((shipX - midX)^2 + (shipY - midY)^2)
      if dist < M.scanRadius then
        local scanAlpha = 0.4 * (1 - dist / M.scanRadius)
        love.graphics.setColor(0.2, 0.5, 1.0, scanAlpha)
        love.graphics.setLineWidth(d.pathWidth * 0.6)
        love.graphics.line(p1.x, p1.y, p2.x, p2.y)
      end
    end
    love.graphics.setLineWidth(1)
  end
  
  -- Hint particles (subtle blue dots drifting along the cool path)
  for _, hp in ipairs(d.hintParticles) do
    love.graphics.setColor(0.3, 0.5, 0.9, hp.alpha)
    love.graphics.circle("fill", hp.x, hp.y, hp.size)
  end
  
  -- Start marker
  love.graphics.setColor(0.3, 0.6, 1.0, 0.7 + math.sin(time * 3) * 0.2)
  love.graphics.circle("line", d.startX, d.startY, 25)
  love.graphics.setFont(ui.getFont("hudSmall"))
  love.graphics.printf("START", d.startX - 25, d.startY + 30, 50, "center")
  
  -- Goal marker
  local goalPulse = math.sin(time * 4) * 0.2 + 0.8
  love.graphics.setColor(0.2, 1.0, 0.4, goalPulse * 0.4)
  love.graphics.circle("fill", d.goalX, d.goalY, 35)
  love.graphics.setColor(0.3, 1.0, 0.5, goalPulse)
  love.graphics.circle("line", d.goalX, d.goalY, 25)
  love.graphics.setFont(ui.getFont("hudSmall"))
  love.graphics.setColor(0.3, 1.0, 0.5, 0.8)
  love.graphics.printf("GOAL", d.goalX - 25, d.goalY + 30, 50, "center")
  
  -- Player heat indicator
  if not d.playerOnPath and not d.goalReached then
    local dangerPulse = math.sin(time * 8) * 0.3 + 0.7
    love.graphics.setColor(1, 0.2, 0.05, dangerPulse * 0.3)
    love.graphics.circle("fill", shipX, shipY, 40)
    love.graphics.setFont(ui.getFont("hudLabel"))
    love.graphics.setColor(1, 0.3, 0.1, dangerPulse)
    love.graphics.printf("TOO HOT!", shipX - 40, shipY - 30, 80, "center")
  end
  
  -- Goal reached animation
  if d.goalReached then
    local progress = math.min(1, d.goalTimer / 2.0)
    love.graphics.setColor(0.2, 1.0, 0.4, (1 - progress) * 0.5)
    love.graphics.circle("fill", d.goalX, d.goalY, 30 + progress * 200)
    love.graphics.setFont(ui.getFont("subtitle"))
    love.graphics.setColor(0.2, 1.0, 0.4, 1)
    love.graphics.printf("PATH CLEARED!", 0, screenH / 2 - 60, screenW, "center")
  end
  
  -- HUD
  love.graphics.setFont(ui.getFont("hudLabel"))
  love.graphics.setColor(0.9, 0.6, 0.3, 0.8)
  love.graphics.printf("Navigate the cool path through the heat zone", 0, screenH - 30, screenW, "center")
end

-- ===================== GRAVITY RINGS (Gargantua) =====================
-- Navigate through shifting gravity rings pulled by the black hole

local function initGravityRings(state, screenW, screenH)
  state.data = {
    rings = {},
    currentRing = 0,
    totalRings = 8,
    complete = false,
    completeTimer = 0,
    particles = {},
    blackHoleX = screenW / 2,
    blackHoleY = screenH / 2,
    accretionAngle = 0,
  }
  
  -- Generate gravity ring checkpoints in a spiral pattern
  local d = state.data
  for i = 1, d.totalRings do
    local angle = (i / d.totalRings) * math.pi * 1.5 + math.pi * 0.5
    local dist = 80 + i * 30
    table.insert(d.rings, {
      x = d.blackHoleX + math.cos(angle) * dist,
      y = d.blackHoleY + math.sin(angle) * dist,
      radius = 35 - i * 2,
      passed = false,
      glowTimer = 0,
      orbitAngle = angle,
      orbitDist = dist,
      orbitSpeed = 0.3 + i * 0.05,
    })
  end
  
  state.active = true
  state.phase = "active"
end

local function updateGravityRings(state, dt, shipX, shipY, screenW, screenH)
  local d = state.data
  if not d then return end
  
  if d.complete then
    d.completeTimer = d.completeTimer + dt
    if d.completeTimer >= 2.5 then
      state.phase = "complete"
    end
    return
  end
  
  d.accretionAngle = d.accretionAngle + dt * 0.8
  
  -- Update ring orbits
  for i, ring in ipairs(d.rings) do
    ring.orbitAngle = ring.orbitAngle + ring.orbitSpeed * dt
    ring.x = d.blackHoleX + math.cos(ring.orbitAngle) * ring.orbitDist
    ring.y = d.blackHoleY + math.sin(ring.orbitAngle) * ring.orbitDist
    ring.glowTimer = ring.glowTimer + dt
  end
  
  -- Check if player passes through current ring
  local nextRing = d.currentRing + 1
  if nextRing <= d.totalRings then
    local ring = d.rings[nextRing]
    local dist = math.sqrt((shipX - ring.x)^2 + (shipY - ring.y)^2)
    if dist < ring.radius then
      ring.passed = true
      d.currentRing = nextRing
      
      -- Spawn celebration particles
      for j = 1, 12 do
        local angle = math.random() * math.pi * 2
        local speed = 60 + math.random() * 100
        table.insert(d.particles, {
          x = ring.x, y = ring.y,
          vx = math.cos(angle) * speed, vy = math.sin(angle) * speed,
          life = 0.6 + math.random() * 0.4,
          size = 2 + math.random() * 3,
          r = 0.9, g = 0.7, b = 0.2,
        })
      end
      
      if d.currentRing >= d.totalRings then
        d.complete = true
        d.completeTimer = 0
      end
    end
  end
  
  -- Update particles
  for i = #d.particles, 1, -1 do
    local p = d.particles[i]
    p.x = p.x + p.vx * dt
    p.y = p.y + p.vy * dt
    p.life = p.life - dt
    if p.life <= 0 then
      table.remove(d.particles, i)
    end
  end
end

local function drawGravityRings(state, screenW, screenH)
  local d = state.data
  if not d then return end
  local time = love.timer.getTime()
  
  -- Draw accretion disk effect around center
  for i = 1, 5 do
    local r = 30 + i * 20
    local alpha = 0.15 - i * 0.02
    local angle = d.accretionAngle + i * 0.5
    love.graphics.setColor(0.9, 0.6, 0.15, alpha)
    love.graphics.setLineWidth(3)
    love.graphics.arc("line", "open", d.blackHoleX, d.blackHoleY, r, angle, angle + math.pi * 1.2)
  end
  
  -- Black hole center
  love.graphics.setColor(0, 0, 0, 0.95)
  love.graphics.circle("fill", d.blackHoleX, d.blackHoleY, 25)
  love.graphics.setColor(0.9, 0.6, 0.2, 0.5)
  love.graphics.setLineWidth(2)
  love.graphics.circle("line", d.blackHoleX, d.blackHoleY, 28)
  
  -- Draw rings
  for i, ring in ipairs(d.rings) do
    local isNext = (i == d.currentRing + 1)
    
    if ring.passed then
      -- Passed ring: green
      love.graphics.setColor(0.2, 0.8, 0.3, 0.4)
      love.graphics.circle("line", ring.x, ring.y, ring.radius)
      love.graphics.setColor(0.2, 0.8, 0.3, 0.1)
      love.graphics.circle("fill", ring.x, ring.y, ring.radius)
    elseif isNext then
      -- Next target ring: bright pulsing gold
      local pulse = math.sin(ring.glowTimer * 4) * 0.2 + 0.8
      love.graphics.setColor(1, 0.8, 0.2, pulse)
      love.graphics.setLineWidth(3)
      love.graphics.circle("line", ring.x, ring.y, ring.radius)
      love.graphics.setColor(1, 0.8, 0.2, pulse * 0.15)
      love.graphics.circle("fill", ring.x, ring.y, ring.radius)
      -- Ring number
      love.graphics.setFont(ui.getFont("hudLabel"))
      love.graphics.setColor(1, 0.9, 0.3, pulse)
      love.graphics.printf(tostring(i), ring.x - 10, ring.y - 7, 20, "center")
    else
      -- Future ring: dim
      love.graphics.setColor(0.4, 0.3, 0.2, 0.3)
      love.graphics.setLineWidth(1)
      love.graphics.circle("line", ring.x, ring.y, ring.radius)
    end
  end
  
  -- Draw particles
  for _, p in ipairs(d.particles) do
    local alpha = p.life / 1.0
    love.graphics.setColor(p.r, p.g, p.b, alpha)
    love.graphics.circle("fill", p.x, p.y, p.size)
  end
  
  -- Progress
  love.graphics.setFont(ui.getFont("hudLabel"))
  love.graphics.setColor(0.8, 0.6, 0.2, 0.8)
  love.graphics.printf("Ring " .. d.currentRing .. "/" .. d.totalRings, 0, screenH - 30, screenW, "center")
  
  -- Completion
  if d.complete then
    local alpha = math.min(1, d.completeTimer)
    love.graphics.setFont(ui.getFont("subtitle"))
    love.graphics.setColor(1, 0.8, 0.2, alpha)
    love.graphics.printf("GRAVITY MASTERED!", 0, screenH / 2 - 80, screenW, "center")
  end
  
  love.graphics.setLineWidth(1)
end

-- ===================== CRYSTAL ALIGNMENT (Pleiades) =====================
-- Shoot crystals to rotate them until all beams connect

local function initCrystalAlign(state, screenW, screenH)
  state.data = {
    crystals = {},
    beams = {},
    complete = false,
    completeTimer = 0,
    particles = {},
  }
  
  local d = state.data
  local cx, cy = screenW / 2, screenH / 2
  
  -- Place 5 crystals in a pattern
  local positions = {
    {x = cx, y = cy - 120},
    {x = cx + 130, y = cy - 40},
    {x = cx + 80, y = cy + 100},
    {x = cx - 80, y = cy + 100},
    {x = cx - 130, y = cy - 40},
  }
  
  for i, pos in ipairs(positions) do
    table.insert(d.crystals, {
      x = pos.x, y = pos.y,
      angle = math.random() * math.pi * 2,  -- Random start rotation
      targetAngle = ((i - 1) / 5) * math.pi * 2 + math.pi / 2,  -- Target angle pointing to next crystal
      size = 20,
      aligned = false,
      hitFlash = 0,
      shimmer = math.random() * math.pi * 2,
    })
  end
  
  state.active = true
  state.phase = "active"
end

local function updateCrystalAlign(state, dt, bullets, screenW, screenH)
  local d = state.data
  if not d then return end
  
  if d.complete then
    d.completeTimer = d.completeTimer + dt
    if d.completeTimer >= 2.5 then
      state.phase = "complete"
    end
    return
  end
  
  -- Update particles
  for i = #d.particles, 1, -1 do
    local p = d.particles[i]
    p.x = p.x + p.vx * dt
    p.y = p.y + p.vy * dt
    p.life = p.life - dt
    if p.life <= 0 then
      table.remove(d.particles, i)
    end
  end
  
  -- Check bullet hits on crystals to rotate them
  for _, crystal in ipairs(d.crystals) do
    crystal.shimmer = crystal.shimmer + dt * 3
    crystal.hitFlash = math.max(0, crystal.hitFlash - dt * 3)
    
    for i = #bullets, 1, -1 do
      local b = bullets[i]
      if b.owner == "player" then
        local dist = math.sqrt((b.x - crystal.x)^2 + (b.y - crystal.y)^2)
        if dist < crystal.size + 5 then
          -- Rotate crystal by 45 degrees
          crystal.angle = crystal.angle + math.pi / 4
          crystal.hitFlash = 1.0
          table.remove(bullets, i)
          
          -- Particles
          for j = 1, 8 do
            local angle = math.random() * math.pi * 2
            local speed = 50 + math.random() * 80
            table.insert(d.particles, {
              x = crystal.x, y = crystal.y,
              vx = math.cos(angle) * speed, vy = math.sin(angle) * speed,
              life = 0.4, size = 2 + math.random() * 2,
              r = 0.5, g = 0.8, b = 1.0,
            })
          end
          break
        end
      end
    end
  end
  
  -- Check alignment (each crystal's angle should point roughly toward next crystal)
  local allAligned = true
  for i, crystal in ipairs(d.crystals) do
    local nextIdx = (i % #d.crystals) + 1
    local nextCrystal = d.crystals[nextIdx]
    local targetAngle = math.atan2(nextCrystal.y - crystal.y, nextCrystal.x - crystal.x)
    
    -- Normalize angles for comparison
    local diff = (crystal.angle - targetAngle + math.pi) % (math.pi * 2) - math.pi
    crystal.aligned = math.abs(diff) < math.pi / 6  -- ~30 degree tolerance
    
    if not crystal.aligned then
      allAligned = false
    end
  end
  
  if allAligned then
    d.complete = true
    d.completeTimer = 0
  end
end

local function drawCrystalAlign(state, screenW, screenH)
  local d = state.data
  if not d then return end
  local time = love.timer.getTime()
  
  -- Draw beam connections between aligned crystals
  for i, crystal in ipairs(d.crystals) do
    local nextIdx = (i % #d.crystals) + 1
    local nextCrystal = d.crystals[nextIdx]
    
    if crystal.aligned then
      -- Connected beam
      love.graphics.setColor(0.4, 0.7, 1.0, 0.6)
      love.graphics.setLineWidth(3)
      love.graphics.line(crystal.x, crystal.y, nextCrystal.x, nextCrystal.y)
      -- Beam glow
      love.graphics.setColor(0.5, 0.8, 1.0, 0.15)
      love.graphics.setLineWidth(12)
      love.graphics.line(crystal.x, crystal.y, nextCrystal.x, nextCrystal.y)
    else
      -- Disconnected beam (dim red)
      love.graphics.setColor(0.5, 0.2, 0.2, 0.2)
      love.graphics.setLineWidth(1)
      love.graphics.line(crystal.x, crystal.y, nextCrystal.x, nextCrystal.y)
    end
  end
  
  -- Draw crystals
  for _, crystal in ipairs(d.crystals) do
    -- Crystal glow
    local glowAlpha = 0.2 + math.sin(crystal.shimmer) * 0.1
    love.graphics.setColor(0.4, 0.6, 1.0, glowAlpha + crystal.hitFlash * 0.3)
    love.graphics.circle("fill", crystal.x, crystal.y, crystal.size * 1.5)
    
    -- Crystal body (diamond shape rotated to current angle)
    love.graphics.push()
    love.graphics.translate(crystal.x, crystal.y)
    love.graphics.rotate(crystal.angle)
    
    -- Main crystal shape
    if crystal.aligned then
      love.graphics.setColor(0.3, 0.8, 1.0, 0.9)
    else
      love.graphics.setColor(0.5, 0.6, 0.8, 0.8)
    end
    love.graphics.polygon("fill",
      crystal.size, 0,
      0, -crystal.size * 0.5,
      -crystal.size * 0.6, 0,
      0, crystal.size * 0.5
    )
    
    -- Direction indicator (pointing edge)
    love.graphics.setColor(1, 1, 1, 0.7 + crystal.hitFlash * 0.3)
    love.graphics.polygon("fill",
      crystal.size, 0,
      crystal.size * 0.6, -3,
      crystal.size * 0.6, 3
    )
    
    love.graphics.pop()
    
    -- Alignment indicator
    if crystal.aligned then
      love.graphics.setColor(0.2, 1.0, 0.4, 0.8)
      love.graphics.setFont(ui.getFont("hudSmall"))
      love.graphics.printf("✓", crystal.x - 10, crystal.y - crystal.size - 15, 20, "center")
    end
  end
  
  -- Draw particles
  for _, p in ipairs(d.particles) do
    local alpha = p.life / 0.5
    love.graphics.setColor(p.r, p.g, p.b, alpha)
    love.graphics.circle("fill", p.x, p.y, p.size)
  end
  
  -- Completion
  if d.complete then
    local progress = math.min(1, d.completeTimer / 2.5)
    love.graphics.setFont(ui.getFont("subtitle"))
    love.graphics.setColor(0.4, 0.8, 1.0, 1)
    love.graphics.printf("CRYSTALS ALIGNED!", 0, screenH / 2 - 80, screenW, "center")
    -- Expanding energy ring
    love.graphics.setColor(0.4, 0.7, 1.0, (1 - progress) * 0.6)
    love.graphics.setLineWidth(3)
    love.graphics.circle("line", screenW / 2, screenH / 2, progress * 300)
  end
  
  -- Instructions
  if not d.complete then
    love.graphics.setFont(ui.getFont("hudSmall"))
    love.graphics.setColor(0.5, 0.7, 0.9, 0.7)
    love.graphics.printf("Shoot crystals to rotate them until all beams connect!", 0, screenH - 30, screenW, "center")
  end
  
  love.graphics.setLineWidth(1)
end

-- ===================== COMET CATCH (Oort Cloud) =====================
-- Catch special comets by flying through them in sequence

local function initCometCatch(state, screenW, screenH)
  state.data = {
    comets = {},
    caughtCount = 0,
    targetCount = 6,
    complete = false,
    completeTimer = 0,
    spawnTimer = 0,
    particles = {},
  }
  
  -- Spawn initial comets
  local d = state.data
  for i = 1, 3 do
    local side = math.random(4)
    local x, y, vx, vy
    if side == 1 then x = -30; y = math.random(screenH); vx = 100 + math.random() * 100; vy = (math.random() - 0.5) * 80
    elseif side == 2 then x = screenW + 30; y = math.random(screenH); vx = -(100 + math.random() * 100); vy = (math.random() - 0.5) * 80
    elseif side == 3 then x = math.random(screenW); y = -30; vx = (math.random() - 0.5) * 80; vy = 100 + math.random() * 100
    else x = math.random(screenW); y = screenH + 30; vx = (math.random() - 0.5) * 80; vy = -(100 + math.random() * 100)
    end
    table.insert(d.comets, {
      x = x, y = y, vx = vx, vy = vy,
      size = 15 + math.random() * 10,
      caught = false,
      color = {0.0, 0.6 + math.random() * 0.4, 0.8 + math.random() * 0.2},
      trail = {},
      glow = 0,
    })
  end
  
  state.active = true
  state.phase = "active"
end

local function updateCometCatch(state, dt, shipX, shipY, screenW, screenH)
  local d = state.data
  if not d then return end
  
  if d.complete then
    d.completeTimer = d.completeTimer + dt
    if d.completeTimer >= 2.5 then
      state.phase = "complete"
    end
    return
  end
  
  -- Spawn new comets periodically
  d.spawnTimer = d.spawnTimer + dt
  if d.spawnTimer >= 3 and #d.comets < 4 then
    d.spawnTimer = 0
    local side = math.random(4)
    local x, y, vx, vy
    if side == 1 then x = -30; y = math.random(screenH); vx = 80 + math.random() * 120; vy = (math.random() - 0.5) * 60
    elseif side == 2 then x = screenW + 30; y = math.random(screenH); vx = -(80 + math.random() * 120); vy = (math.random() - 0.5) * 60
    elseif side == 3 then x = math.random(screenW); y = -30; vx = (math.random() - 0.5) * 60; vy = 80 + math.random() * 120
    else x = math.random(screenW); y = screenH + 30; vx = (math.random() - 0.5) * 60; vy = -(80 + math.random() * 120)
    end
    table.insert(d.comets, {
      x = x, y = y, vx = vx, vy = vy,
      size = 15 + math.random() * 10,
      caught = false,
      color = {0.0, 0.6 + math.random() * 0.4, 0.8 + math.random() * 0.2},
      trail = {},
      glow = 0,
    })
  end
  
  -- Update comets
  for i = #d.comets, 1, -1 do
    local c = d.comets[i]
    c.x = c.x + c.vx * dt
    c.y = c.y + c.vy * dt
    c.glow = c.glow + dt * 5
    
    -- Trail
    table.insert(c.trail, 1, {x = c.x, y = c.y, age = 0})
    for j = #c.trail, 1, -1 do
      c.trail[j].age = c.trail[j].age + dt
      if c.trail[j].age > 0.6 then
        table.remove(c.trail, j)
      end
    end
    while #c.trail > 25 do table.remove(c.trail) end
    
    -- Check player catch
    local dist = math.sqrt((shipX - c.x)^2 + (shipY - c.y)^2)
    if dist < c.size + 15 then
      d.caughtCount = d.caughtCount + 1
      -- Catch particles
      for j = 1, 15 do
        local angle = math.random() * math.pi * 2
        local speed = 50 + math.random() * 100
        table.insert(d.particles, {
          x = c.x, y = c.y,
          vx = math.cos(angle) * speed, vy = math.sin(angle) * speed,
          life = 0.5 + math.random() * 0.3,
          size = 2 + math.random() * 3,
          r = c.color[1], g = c.color[2], b = c.color[3],
        })
      end
      table.remove(d.comets, i)
      
      if d.caughtCount >= d.targetCount then
        d.complete = true
        d.completeTimer = 0
      end
    elseif c.x < -100 or c.x > screenW + 100 or c.y < -100 or c.y > screenH + 100 then
      table.remove(d.comets, i)
    end
  end
  
  -- Update particles
  for i = #d.particles, 1, -1 do
    local p = d.particles[i]
    p.x = p.x + p.vx * dt
    p.y = p.y + p.vy * dt
    p.life = p.life - dt
    if p.life <= 0 then
      table.remove(d.particles, i)
    end
  end
end

local function drawCometCatch(state, screenW, screenH)
  local d = state.data
  if not d then return end
  local time = love.timer.getTime()
  
  -- Draw comets
  for _, c in ipairs(d.comets) do
    -- Trail
    for j, t in ipairs(c.trail) do
      local alpha = (1 - t.age / 0.6) * 0.5
      local size = c.size * (1 - t.age / 0.6) * 0.4
      love.graphics.setColor(c.color[1], c.color[2], c.color[3], alpha)
      love.graphics.circle("fill", t.x, t.y, math.max(1, size))
    end
    
    -- Comet body glow
    local glowPulse = math.sin(c.glow) * 0.15 + 0.5
    love.graphics.setColor(c.color[1], c.color[2], c.color[3], glowPulse * 0.3)
    love.graphics.circle("fill", c.x, c.y, c.size * 1.5)
    -- Core
    love.graphics.setColor(1, 1, 1, 0.8)
    love.graphics.circle("fill", c.x, c.y, c.size * 0.4)
    love.graphics.setColor(c.color[1], c.color[2], c.color[3], 0.9)
    love.graphics.circle("fill", c.x, c.y, c.size * 0.7)
    -- Target indicator
    love.graphics.setColor(1, 1, 0.5, 0.6 + math.sin(time * 4) * 0.2)
    love.graphics.setLineWidth(2)
    love.graphics.circle("line", c.x, c.y, c.size + 5)
  end
  
  -- Draw particles
  for _, p in ipairs(d.particles) do
    local alpha = p.life / 0.8
    love.graphics.setColor(p.r, p.g, p.b, alpha)
    love.graphics.circle("fill", p.x, p.y, p.size)
  end
  
  -- Progress
  love.graphics.setFont(ui.getFont("hudLabel"))
  love.graphics.setColor(0.3, 0.8, 1.0, 0.8)
  love.graphics.printf("Comets caught: " .. d.caughtCount .. "/" .. d.targetCount, 0, screenH - 35, screenW, "center")
  love.graphics.setFont(ui.getFont("hudSmall"))
  love.graphics.setColor(0.4, 0.6, 0.8, 0.6)
  love.graphics.printf("Fly through the comets to catch them!", 0, screenH - 18, screenW, "center")
  
  -- Completion
  if d.complete then
    local alpha = math.min(1, d.completeTimer)
    love.graphics.setFont(ui.getFont("subtitle"))
    love.graphics.setColor(0.0, 0.9, 1.0, alpha)
    love.graphics.printf("ALL COMETS CAUGHT!", 0, screenH / 2 - 80, screenW, "center")
  end
  
  love.graphics.setLineWidth(1)
end

-- ===================== PULSAR TIMING (Vela) =====================
-- Timed puzzle: activate switches between pulsar bursts

local function initPulsarTiming(state, screenW, screenH)
  state.data = {
    switches = {},
    activatedCount = 0,
    totalSwitches = 5,
    complete = false,
    completeTimer = 0,
    burstWarning = false,
    burstTimer = 0,
    burstInterval = 8,  -- Shorter than the real pulsar for puzzle pacing
    burstActive = false,
    burstProgress = 0,
    safeZones = {},
    particles = {},
  }
  
  local d = state.data
  -- Place switches around the screen
  for i = 1, d.totalSwitches do
    local angle = ((i - 1) / d.totalSwitches) * math.pi * 2 + math.pi / 2
    local dist = 200 + math.random() * 50
    table.insert(d.switches, {
      x = screenW / 2 + math.cos(angle) * dist,
      y = screenH / 2 + math.sin(angle) * dist,
      activated = false,
      size = 18,
      pulse = math.random() * math.pi * 2,
    })
  end
  
  -- Safe zones (where player can hide from bursts)
  for i = 1, 3 do
    table.insert(d.safeZones, {
      x = screenW * (0.2 + i * 0.2) + (math.random() - 0.5) * 50,
      y = screenH * (0.3 + (math.random() - 0.5) * 0.4),
      radius = 45,
    })
  end
  
  state.active = true
  state.phase = "active"
end

local function updatePulsarTiming(state, dt, shipX, shipY, bullets, screenW, screenH)
  local d = state.data
  if not d then return end
  
  if d.complete then
    d.completeTimer = d.completeTimer + dt
    if d.completeTimer >= 2.5 then
      state.phase = "complete"
    end
    return
  end
  
  -- Update burst cycle
  d.burstTimer = d.burstTimer + dt
  local timeUntilBurst = d.burstInterval - d.burstTimer
  d.burstWarning = timeUntilBurst <= 3.0 and not d.burstActive
  
  if d.burstTimer >= d.burstInterval then
    d.burstActive = true
    d.burstProgress = 0
  end
  
  if d.burstActive then
    d.burstProgress = d.burstProgress + dt
    if d.burstProgress >= 1.5 then
      d.burstActive = false
      d.burstTimer = 0
    end
    
    -- Check if player is NOT in a safe zone during burst
    if d.burstProgress < 0.2 then  -- Damage only at burst start
      local inSafe = false
      for _, zone in ipairs(d.safeZones) do
        local dist = math.sqrt((shipX - zone.x)^2 + (shipY - zone.y)^2)
        if dist < zone.radius then
          inSafe = true
          break
        end
      end
      if not inSafe then
        return "pulsar_hit"
      end
    end
  end
  
  -- Check bullets hitting switches
  for _, sw in ipairs(d.switches) do
    sw.pulse = sw.pulse + dt * 3
    if not sw.activated then
      for i = #bullets, 1, -1 do
        local b = bullets[i]
        if b.owner == "player" then
          local dist = math.sqrt((b.x - sw.x)^2 + (b.y - sw.y)^2)
          if dist < sw.size + 5 then
            sw.activated = true
            d.activatedCount = d.activatedCount + 1
            table.remove(bullets, i)
            
            -- Particles
            for j = 1, 10 do
              local angle = math.random() * math.pi * 2
              local speed = 50 + math.random() * 80
              table.insert(d.particles, {
                x = sw.x, y = sw.y,
                vx = math.cos(angle) * speed, vy = math.sin(angle) * speed,
                life = 0.5, size = 2 + math.random() * 2,
                r = 0.5, g = 0.3, b = 1.0,
              })
            end
            
            if d.activatedCount >= d.totalSwitches then
              d.complete = true
              d.completeTimer = 0
            end
            break
          end
        end
      end
    end
  end
  
  -- Update particles
  for i = #d.particles, 1, -1 do
    local p = d.particles[i]
    p.x = p.x + p.vx * dt
    p.y = p.y + p.vy * dt
    p.life = p.life - dt
    if p.life <= 0 then
      table.remove(d.particles, i)
    end
  end
  
  return nil
end

local function drawPulsarTiming(state, screenW, screenH)
  local d = state.data
  if not d then return end
  local time = love.timer.getTime()
  
  -- Draw safe zones
  for _, zone in ipairs(d.safeZones) do
    -- Warning: safe zones flash more intensely near burst
    local alpha = 0.15
    if d.burstWarning then
      alpha = 0.3 + math.sin(time * 6) * 0.15
    end
    love.graphics.setColor(0.2, 0.3, 0.8, alpha)
    love.graphics.circle("fill", zone.x, zone.y, zone.radius)
    love.graphics.setColor(0.3, 0.4, 0.9, alpha * 2)
    love.graphics.setLineWidth(2)
    love.graphics.circle("line", zone.x, zone.y, zone.radius)
    -- Label
    love.graphics.setFont(ui.getFont("hudSmall"))
    love.graphics.setColor(0.4, 0.5, 1.0, 0.6)
    love.graphics.printf("SAFE", zone.x - 20, zone.y - 5, 40, "center")
  end
  
  -- Draw switches
  for i, sw in ipairs(d.switches) do
    if sw.activated then
      love.graphics.setColor(0.3, 0.8, 1.0, 0.6)
      love.graphics.circle("fill", sw.x, sw.y, sw.size * 0.7)
      love.graphics.setColor(0.3, 0.9, 1.0, 0.8)
      love.graphics.circle("line", sw.x, sw.y, sw.size)
    else
      local pulse = math.sin(sw.pulse) * 0.2 + 0.6
      love.graphics.setColor(0.8, 0.5, 1.0, pulse)
      love.graphics.circle("fill", sw.x, sw.y, sw.size)
      love.graphics.setColor(1, 0.8, 1.0, pulse)
      love.graphics.setLineWidth(2)
      love.graphics.circle("line", sw.x, sw.y, sw.size)
      -- Number
      love.graphics.setFont(ui.getFont("hudLabel"))
      love.graphics.setColor(1, 1, 1, 0.8)
      love.graphics.printf(tostring(i), sw.x - 8, sw.y - 6, 16, "center")
    end
  end
  
  -- Burst warning
  if d.burstWarning then
    local flash = math.sin(time * 8) * 0.3 + 0.5
    love.graphics.setFont(ui.getFont("small"))
    love.graphics.setColor(1, 0.3, 0.5, flash)
    local timeLeft = math.max(0, math.floor(d.burstInterval - d.burstTimer))
    love.graphics.printf("PULSAR BURST IN " .. timeLeft .. "s - GET TO SAFETY!", 0, 50, screenW, "center")
  end
  
  -- Burst active effect
  if d.burstActive then
    local alpha = (1 - d.burstProgress / 1.5) * 0.6
    love.graphics.setColor(0.7, 0.4, 1.0, alpha)
    love.graphics.rectangle("fill", 0, 0, screenW, screenH)
    if d.burstProgress < 0.3 then
      love.graphics.setColor(1, 1, 1, (0.3 - d.burstProgress) / 0.3 * 0.8)
      love.graphics.rectangle("fill", 0, 0, screenW, screenH)
    end
  end
  
  -- Draw particles
  for _, p in ipairs(d.particles) do
    local alpha = p.life / 0.5
    love.graphics.setColor(p.r, p.g, p.b, alpha)
    love.graphics.circle("fill", p.x, p.y, p.size)
  end
  
  -- Progress
  love.graphics.setFont(ui.getFont("hudLabel"))
  love.graphics.setColor(0.7, 0.5, 1.0, 0.8)
  love.graphics.printf("Switches: " .. d.activatedCount .. "/" .. d.totalSwitches, 0, screenH - 30, screenW, "center")
  
  -- Completion
  if d.complete then
    local alpha = math.min(1, d.completeTimer)
    love.graphics.setFont(ui.getFont("subtitle"))
    love.graphics.setColor(0.7, 0.4, 1.0, alpha)
    love.graphics.printf("PULSAR TAMED!", 0, screenH / 2 - 80, screenW, "center")
  end
  
  love.graphics.setLineWidth(1)
end

-- ===================== NEBULA MEMORY (The Nebula) =====================
-- Simon-says style: remember and repeat a sequence of colored nodes

local function initNebulaMemory(state, screenW, screenH)
  local nodeColors = {
    {1, 0.3, 0.3},   -- Red
    {0.3, 0.3, 1},    -- Blue
    {0.3, 1, 0.3},    -- Green
    {1, 1, 0.3},      -- Yellow
    {1, 0.3, 1},      -- Magenta
    {0.3, 1, 1},      -- Cyan
  }
  
  state.data = {
    nodes = {},
    sequence = {},
    playerSequence = {},
    showingSequence = true,
    sequenceIndex = 1,
    sequenceShowTimer = 0,
    sequenceLength = 1,
    maxLength = 6,
    nodeShowDuration = 0.8,
    gapDuration = 0.3,
    failed = false,
    failTimer = 0,
    complete = false,
    completeTimer = 0,
    particles = {},
    flashNode = -1,
    flashTimer = 0,
    roundComplete = false,
    roundCompleteTimer = 0,
  }
  
  local d = state.data
  -- Place 6 nodes in a hexagonal pattern
  local cx, cy = screenW / 2, screenH / 2
  for i = 1, 6 do
    local angle = ((i - 1) / 6) * math.pi * 2 - math.pi / 2
    local dist = 140
    table.insert(d.nodes, {
      x = cx + math.cos(angle) * dist,
      y = cy + math.sin(angle) * dist,
      color = nodeColors[i],
      size = 25,
      glowing = false,
      glowTimer = 0,
      hitFlash = 0,
    })
  end
  
  -- Generate first sequence element
  table.insert(d.sequence, math.random(#d.nodes))
  
  state.active = true
  state.phase = "active"
end

local function updateNebulaMemory(state, dt, bullets, screenW, screenH)
  local d = state.data
  if not d then return end
  
  if d.complete then
    d.completeTimer = d.completeTimer + dt
    if d.completeTimer >= 2.5 then
      state.phase = "complete"
    end
    return
  end
  
  -- Update particles
  for i = #d.particles, 1, -1 do
    local p = d.particles[i]
    p.x = p.x + p.vx * dt
    p.y = p.y + p.vy * dt
    p.life = p.life - dt
    if p.life <= 0 then
      table.remove(d.particles, i)
    end
  end
  
  -- Update node flashes
  for _, node in ipairs(d.nodes) do
    node.hitFlash = math.max(0, node.hitFlash - dt * 3)
  end
  d.flashTimer = math.max(0, d.flashTimer - dt * 3)
  
  -- Fail animation
  if d.failed then
    d.failTimer = d.failTimer + dt
    if d.failTimer >= 2.0 then
      -- Reset
      d.failed = false
      d.failTimer = 0
      d.playerSequence = {}
      d.showingSequence = true
      d.sequenceIndex = 1
      d.sequenceShowTimer = 0
    end
    return
  end
  
  -- Round complete pause
  if d.roundComplete then
    d.roundCompleteTimer = d.roundCompleteTimer + dt
    if d.roundCompleteTimer >= 1.0 then
      d.roundComplete = false
      d.sequenceLength = d.sequenceLength + 1
      
      if d.sequenceLength > d.maxLength then
        d.complete = true
        d.completeTimer = 0
        return
      end
      
      -- Add new element to sequence
      table.insert(d.sequence, math.random(#d.nodes))
      d.playerSequence = {}
      d.showingSequence = true
      d.sequenceIndex = 1
      d.sequenceShowTimer = 0
    end
    return
  end
  
  -- Show sequence phase
  if d.showingSequence then
    d.sequenceShowTimer = d.sequenceShowTimer + dt
    
    local totalPerNode = d.nodeShowDuration + d.gapDuration
    local currentNodeTime = (d.sequenceIndex - 1) * totalPerNode
    local elapsed = d.sequenceShowTimer - currentNodeTime
    
    -- Reset all glowing
    for _, node in ipairs(d.nodes) do
      node.glowing = false
    end
    
    if d.sequenceIndex <= d.sequenceLength then
      if elapsed >= 0 and elapsed < d.nodeShowDuration then
        -- Show this node
        local nodeIdx = d.sequence[d.sequenceIndex]
        d.nodes[nodeIdx].glowing = true
        d.flashNode = nodeIdx
      elseif elapsed >= totalPerNode then
        d.sequenceIndex = d.sequenceIndex + 1
      end
    else
      -- Done showing
      d.showingSequence = false
      d.playerSequence = {}
    end
    return
  end
  
  -- Player input phase: check bullets hitting nodes
  for _, node in ipairs(d.nodes) do
    for i = #bullets, 1, -1 do
      local b = bullets[i]
      if b.owner == "player" then
        local dist = math.sqrt((b.x - node.x)^2 + (b.y - node.y)^2)
        if dist < node.size + 8 then
          -- Find which node was hit
          local hitIdx = 0
          for ni, n in ipairs(d.nodes) do
            if n == node then hitIdx = ni; break end
          end
          
          table.insert(d.playerSequence, hitIdx)
          node.hitFlash = 1.0
          d.flashNode = hitIdx
          d.flashTimer = 1.0
          table.remove(bullets, i)
          
          -- Check if correct
          local seqPos = #d.playerSequence
          if d.sequence[seqPos] ~= hitIdx then
            -- WRONG!
            d.failed = true
            d.failTimer = 0
            -- Red particles
            for j = 1, 12 do
              local angle = math.random() * math.pi * 2
              local speed = 50 + math.random() * 80
              table.insert(d.particles, {
                x = node.x, y = node.y,
                vx = math.cos(angle) * speed, vy = math.sin(angle) * speed,
                life = 0.5, size = 3,
                r = 1, g = 0.2, b = 0.1,
              })
            end
          else
            -- Correct! Green particles
            for j = 1, 8 do
              local angle = math.random() * math.pi * 2
              local speed = 40 + math.random() * 60
              table.insert(d.particles, {
                x = node.x, y = node.y,
                vx = math.cos(angle) * speed, vy = math.sin(angle) * speed,
                life = 0.4, size = 2 + math.random() * 2,
                r = 0.3, g = 1, b = 0.4,
              })
            end
            
            -- Check if round complete
            if seqPos >= d.sequenceLength then
              d.roundComplete = true
              d.roundCompleteTimer = 0
            end
          end
          break
        end
      end
    end
  end
end

local function drawNebulaMemory(state, screenW, screenH)
  local d = state.data
  if not d then return end
  local time = love.timer.getTime()
  
  -- Center decoration
  love.graphics.setColor(0.15, 0.15, 0.3, 0.3)
  love.graphics.circle("fill", screenW / 2, screenH / 2, 160)
  love.graphics.setColor(0.2, 0.2, 0.4, 0.2)
  love.graphics.circle("line", screenW / 2, screenH / 2, 160)
  
  -- Draw connection lines between nodes
  for i = 1, #d.nodes do
    local j = (i % #d.nodes) + 1
    love.graphics.setColor(0.2, 0.2, 0.3, 0.2)
    love.graphics.line(d.nodes[i].x, d.nodes[i].y, d.nodes[j].x, d.nodes[j].y)
  end
  
  -- Draw nodes
  for i, node in ipairs(d.nodes) do
    local isGlowing = node.glowing or node.hitFlash > 0
    local baseAlpha = isGlowing and 1.0 or 0.4
    
    -- Outer glow
    if isGlowing then
      love.graphics.setColor(node.color[1], node.color[2], node.color[3], 0.3 + node.hitFlash * 0.2)
      love.graphics.circle("fill", node.x, node.y, node.size * 2)
    end
    
    -- Main circle
    love.graphics.setColor(node.color[1], node.color[2], node.color[3], baseAlpha)
    love.graphics.circle("fill", node.x, node.y, node.size)
    
    -- Border
    love.graphics.setColor(1, 1, 1, baseAlpha * 0.5)
    love.graphics.setLineWidth(2)
    love.graphics.circle("line", node.x, node.y, node.size)
    
    -- Highlight
    if isGlowing then
      love.graphics.setColor(1, 1, 1, 0.4)
      love.graphics.circle("fill", node.x - 5, node.y - 5, node.size * 0.3)
    end
  end
  
  -- Draw particles
  for _, p in ipairs(d.particles) do
    local alpha = p.life / 0.5
    love.graphics.setColor(p.r, p.g, p.b, alpha)
    love.graphics.circle("fill", p.x, p.y, p.size)
  end
  
  -- Status text
  love.graphics.setFont(ui.getFont("hudLabel"))
  if d.showingSequence then
    love.graphics.setColor(0.7, 0.7, 1.0, 0.8)
    love.graphics.printf("Watch the sequence...", 0, 50, screenW, "center")
  elseif d.failed then
    love.graphics.setColor(1, 0.3, 0.3, 1 - d.failTimer / 2.0)
    love.graphics.printf("Wrong! Try again...", 0, 50, screenW, "center")
  elseif d.roundComplete then
    love.graphics.setColor(0.3, 1, 0.4, 1)
    love.graphics.printf("Correct!", 0, 50, screenW, "center")
  else
    love.graphics.setColor(0.8, 0.8, 1.0, 0.8)
    love.graphics.printf("Repeat the sequence! Shoot the nodes!", 0, 50, screenW, "center")
  end
  
  -- Progress
  love.graphics.setFont(ui.getFont("hudLabel"))
  love.graphics.setColor(0.6, 0.6, 0.8, 0.7)
  love.graphics.printf("Round " .. d.sequenceLength .. "/" .. d.maxLength, 0, screenH - 30, screenW, "center")
  
  -- Completion
  if d.complete then
    local alpha = math.min(1, d.completeTimer)
    love.graphics.setFont(ui.getFont("subtitle"))
    love.graphics.setColor(0.5, 0.5, 1.0, alpha)
    love.graphics.printf("MEMORY UNLOCKED!", 0, screenH / 2 - 80, screenW, "center")
  end
  
  love.graphics.setLineWidth(1)
end

-- ===================== REWARD DROP SYSTEM =====================

M.rewardDrop = nil  -- Active reward floating in the sector

function M.spawnReward(puzzleInfo, screenW, screenH)
  local color, name, description
  if puzzleInfo.reward == M.REWARD_TORPEDO_POD then
    color = {1, 0.4, 0.2}
    name = "TORPEDO POD"
    description = "+1 Torpedo capacity"
  else
    color = {0.3, 0.7, 1.0}
    name = "SHIELD CELL"
    description = "+25 Max shield energy"
  end
  
  M.rewardDrop = {
    x = screenW / 2,
    y = screenH / 2,
    reward = puzzleInfo.reward,
    color = color,
    name = name,
    description = description,
    timer = 0,
    collected = false,
    collectTimer = 0,
    particles = {},
  }
end

function M.updateReward(dt, shipX, shipY)
  if not M.rewardDrop or M.rewardDrop.collected then
    if M.rewardDrop and M.rewardDrop.collected then
      M.rewardDrop.collectTimer = M.rewardDrop.collectTimer + dt
      if M.rewardDrop.collectTimer >= 2.0 then
        local reward = M.rewardDrop.reward
        M.rewardDrop = nil
        return reward  -- Return what was collected
      end
    end
    return nil
  end
  
  M.rewardDrop.timer = M.rewardDrop.timer + dt
  
  -- Update particles
  for i = #M.rewardDrop.particles, 1, -1 do
    local p = M.rewardDrop.particles[i]
    p.x = p.x + p.vx * dt
    p.y = p.y + p.vy * dt
    p.life = p.life - dt
    if p.life <= 0 then
      table.remove(M.rewardDrop.particles, i)
    end
  end
  
  -- Ambient particles
  if math.random() < dt * 5 then
    local angle = math.random() * math.pi * 2
    local dist = 20 + math.random() * 15
    table.insert(M.rewardDrop.particles, {
      x = M.rewardDrop.x + math.cos(angle) * dist,
      y = M.rewardDrop.y + math.sin(angle) * dist,
      vx = (math.random() - 0.5) * 20,
      vy = -10 - math.random() * 20,
      life = 0.5 + math.random() * 0.5,
      size = 1 + math.random() * 2,
    })
  end
  
  -- Check collection
  local dist = math.sqrt((shipX - M.rewardDrop.x)^2 + (shipY - M.rewardDrop.y)^2)
  if dist < 35 then
    M.rewardDrop.collected = true
    M.rewardDrop.collectTimer = 0
    -- Burst of particles
    for i = 1, 30 do
      local angle = math.random() * math.pi * 2
      local speed = 60 + math.random() * 150
      table.insert(M.rewardDrop.particles, {
        x = M.rewardDrop.x, y = M.rewardDrop.y,
        vx = math.cos(angle) * speed, vy = math.sin(angle) * speed,
        life = 0.5 + math.random() * 0.8,
        size = 2 + math.random() * 4,
      })
    end
  end
  
  return nil
end

function M.drawReward(screenW, screenH)
  if not M.rewardDrop then return end
  local r = M.rewardDrop
  local time = love.timer.getTime()
  
  -- Draw particles
  for _, p in ipairs(r.particles) do
    local alpha = p.life / 1.0
    love.graphics.setColor(r.color[1], r.color[2], r.color[3], alpha)
    love.graphics.circle("fill", p.x, p.y, p.size)
  end
  
  if r.collected then
    -- Collection animation
    local progress = r.collectTimer / 2.0
    
    -- Expanding rings
    for i = 1, 3 do
      local ringR = progress * 200 + i * 25
      local ringA = (1 - progress) * 0.6
      love.graphics.setColor(r.color[1], r.color[2], r.color[3], ringA)
      love.graphics.setLineWidth(3)
      love.graphics.circle("line", r.x, r.y, ringR)
    end
    
    -- Reward text rising
    love.graphics.setFont(ui.getFont("medium"))
    love.graphics.setColor(r.color[1], r.color[2], r.color[3], 1 - progress)
    love.graphics.printf(r.name .. " ACQUIRED!", 0, r.y - 40 - progress * 50, screenW, "center")
    love.graphics.setFont(ui.getFont("hudLabel"))
    love.graphics.setColor(1, 1, 1, 0.8 * (1 - progress))
    love.graphics.printf(r.description, 0, r.y - progress * 50, screenW, "center")
  else
    -- Floating reward item
    local bob = math.sin(r.timer * 2) * 8
    local pulse = math.sin(r.timer * 4) * 0.15 + 0.85
    
    -- Outer glow
    love.graphics.setColor(r.color[1], r.color[2], r.color[3], 0.2 * pulse)
    love.graphics.circle("fill", r.x, r.y + bob, 40)
    
    -- Item body
    love.graphics.setColor(r.color[1], r.color[2], r.color[3], 0.9)
    love.graphics.circle("fill", r.x, r.y + bob, 18)
    
    -- Inner highlight
    love.graphics.setColor(1, 1, 1, 0.5)
    love.graphics.circle("fill", r.x - 4, r.y + bob - 4, 6)
    
    -- Rotating star points
    love.graphics.setLineWidth(2)
    love.graphics.setColor(r.color[1], r.color[2], r.color[3], pulse)
    for i = 1, 4 do
      local a = r.timer * 1.5 + (i / 4) * math.pi * 2
      local ex = r.x + math.cos(a) * 28
      local ey = r.y + bob + math.sin(a) * 28
      love.graphics.line(r.x, r.y + bob, ex, ey)
    end
    
    -- Name label
    love.graphics.setFont(ui.getFont("hudLabel"))
    love.graphics.setColor(r.color[1], r.color[2], r.color[3], 0.9)
    love.graphics.printf(r.name, r.x - 60, r.y + bob + 30, 120, "center")
    love.graphics.setFont(ui.getFont("hudSmall"))
    love.graphics.setColor(1, 1, 1, 0.6)
    love.graphics.printf("Fly to collect", r.x - 60, r.y + bob + 46, 120, "center")
  end
  
  love.graphics.setLineWidth(1)
end

-- ===================== MAIN PUZZLE INTERFACE =====================

-- Initialize a puzzle for the current tile
function M.activatePuzzle(tileX, tileY, screenW, screenH)
  local puzzleInfo = M.getPuzzleAt(tileX, tileY)
  if not puzzleInfo then return false end
  
  local state = M.getState(tileX, tileY)
  if state.completed then return false end
  
  -- If already active (player left and returned), don't re-initialize.
  -- This preserves boss HP, puzzle progress, drops, etc.
  if state.active then return true end
  
  local pType = puzzleInfo.puzzleType
  local cId = puzzleInfo.constellation
  
  if pType == M.PUZZLE_SPINNING_LOCK then
    initSpinningLock(state, screenW, screenH)
  elseif pType == M.PUZZLE_HIDDEN_PORTAL then
    initHiddenPortal(state, screenW, screenH)
  elseif pType == M.PUZZLE_DEEP_SPACE_BOSS then
    initDeepSpaceBoss(state, screenW, screenH, cId)
  elseif pType == M.PUZZLE_HEAT_MAZE then
    initHeatMaze(state, screenW, screenH)
  elseif pType == M.PUZZLE_GRAVITY_RINGS then
    initGravityRings(state, screenW, screenH)
  elseif pType == M.PUZZLE_CRYSTAL_ALIGN then
    initCrystalAlign(state, screenW, screenH)
  elseif pType == M.PUZZLE_COMET_CATCH then
    initCometCatch(state, screenW, screenH)
  elseif pType == M.PUZZLE_PULSAR_TIMING then
    initPulsarTiming(state, screenW, screenH)
  elseif pType == M.PUZZLE_NEBULA_MEMORY then
    initNebulaMemory(state, screenW, screenH)
  end
  
  return true
end

-- Update puzzle for the current tile
function M.updatePuzzle(tileX, tileY, dt, shipX, shipY, bullets, screenW, screenH)
  local puzzleInfo = M.getPuzzleAt(tileX, tileY)
  if not puzzleInfo then return nil end
  
  local state = M.getState(tileX, tileY)
  if not state.active then return nil end
  
  -- Update scan
  M.updateScan(dt, shipX, shipY, screenW, screenH)
  
  local pType = puzzleInfo.puzzleType
  local result = nil
  
  if pType == M.PUZZLE_SPINNING_LOCK then
    updateSpinningLock(state, dt, bullets, screenW, screenH)
  elseif pType == M.PUZZLE_HIDDEN_PORTAL then
    result = updateHiddenPortal(state, dt, shipX, shipY, M.scanActive, M.scanRadius, screenW, screenH)
    -- Check if player flies into revealed portal
    if state.data and state.data.revealed and not state.data.inMaze and not state.data.mazeComplete then
      local dist = math.sqrt((shipX - state.data.portalX)^2 + (shipY - state.data.portalY)^2)
      if dist < state.data.portalRadius then
        state.data.inMaze = true
        state.data.mazeTimer = 0
        state.phase = "maze"
      end
    end
  elseif pType == M.PUZZLE_DEEP_SPACE_BOSS then
    result = updateDeepSpaceBoss(state, dt, shipX, shipY, bullets, screenW, screenH)
  elseif pType == M.PUZZLE_HEAT_MAZE then
    result = updateHeatMaze(state, dt, shipX, shipY, screenW, screenH)
  elseif pType == M.PUZZLE_GRAVITY_RINGS then
    updateGravityRings(state, dt, shipX, shipY, screenW, screenH)
  elseif pType == M.PUZZLE_CRYSTAL_ALIGN then
    updateCrystalAlign(state, dt, bullets, screenW, screenH)
  elseif pType == M.PUZZLE_COMET_CATCH then
    updateCometCatch(state, dt, shipX, shipY, screenW, screenH)
  elseif pType == M.PUZZLE_PULSAR_TIMING then
    result = updatePulsarTiming(state, dt, shipX, shipY, bullets, screenW, screenH)
  elseif pType == M.PUZZLE_NEBULA_MEMORY then
    updateNebulaMemory(state, dt, bullets, screenW, screenH)
  end
  
  -- Check for completion → spawn reward
  if state.phase == "complete" and not state.completed then
    state.completed = true
    M.spawnReward(puzzleInfo, screenW, screenH)
  end
  
  -- Update reward drop
  local collected = M.updateReward(dt, shipX, shipY)
  if collected then
    state.rewardCollected = true
    state.active = false
    return collected  -- "torpedo_pod" or "shield_cell"
  end
  
  return result
end

-- Draw puzzle for current tile
function M.drawPuzzle(tileX, tileY, screenW, screenH, shipX, shipY)
  local puzzleInfo = M.getPuzzleAt(tileX, tileY)
  if not puzzleInfo then return end
  
  local state = M.getState(tileX, tileY)
  if not state.active and not M.rewardDrop then return end
  
  local pType = puzzleInfo.puzzleType
  
  if state.active then
    if pType == M.PUZZLE_SPINNING_LOCK then
      drawSpinningLock(state, screenW, screenH)
    elseif pType == M.PUZZLE_HIDDEN_PORTAL then
      drawHiddenPortal(state, shipX, shipY, screenW, screenH)
    elseif pType == M.PUZZLE_DEEP_SPACE_BOSS then
      drawDeepSpaceBoss(state, screenW, screenH)
    elseif pType == M.PUZZLE_HEAT_MAZE then
      drawHeatMaze(state, shipX, shipY, screenW, screenH)
    elseif pType == M.PUZZLE_GRAVITY_RINGS then
      drawGravityRings(state, screenW, screenH)
    elseif pType == M.PUZZLE_CRYSTAL_ALIGN then
      drawCrystalAlign(state, screenW, screenH)
    elseif pType == M.PUZZLE_COMET_CATCH then
      drawCometCatch(state, screenW, screenH)
    elseif pType == M.PUZZLE_PULSAR_TIMING then
      drawPulsarTiming(state, screenW, screenH)
    elseif pType == M.PUZZLE_NEBULA_MEMORY then
      drawNebulaMemory(state, screenW, screenH)
    end
  end
  
  -- Draw scan overlay
  if shipX and shipY then
    M.drawScan(shipX, shipY)
  end
  
  -- Draw reward
  M.drawReward(screenW, screenH)
  
  -- Draw puzzle sector indicator when entering
  if state.active and not state.completed and state.phase ~= "complete" then
    local rewardName = puzzleInfo.reward == M.REWARD_TORPEDO_POD and "Torpedo Pod" or "Shield Cell"
    love.graphics.setFont(ui.getFont("hudSmall"))
    love.graphics.setColor(0.6, 0.6, 0.8, 0.5)
    love.graphics.printf("Puzzle Sector — Reward: " .. rewardName, 0, 3, screenW, "center")
  end
end

-- Check if tile has an uncollected puzzle (for minimap indicator)
function M.hasPuzzle(tileX, tileY)
  local puzzle = M.getPuzzleAt(tileX, tileY)
  if not puzzle then return false end
  return not M.isCompleted(tileX, tileY)
end

-- Get save data for persistence
function M.getSaveData()
  local data = {}
  for key, state in pairs(puzzleStates) do
    if state.rewardCollected then
      data[key] = true
    end
  end
  data.scanUnlocked = M.scanUnlocked
  return data
end

-- Load save data
function M.loadSaveData(data)
  if not data then return end
  for key, collected in pairs(data) do
    if key ~= "scanUnlocked" and collected == true then
      puzzleStates[key] = {
        active = false,
        completed = true,
        rewardCollected = true,
        phase = "complete",
        timer = 0,
        data = {},
      }
    end
  end
  if data.scanUnlocked then
    M.scanUnlocked = true
  end
end

-- Initialize on module load
M.initAssignments()

return M
