-- asteroids/encounter.lua
-- Zone-based enemy encounter system (Starfox-style)
-- Enemies scale with distance from Hometown Station:
--   The Nebula (cx,cy=0,0):  no encounters
--   Inner Space (maxC=1):    1/10 easy
--   Deep Space ring 1 (maxC=2): 2/10 easy
--   Deep Space ring 2 (maxC=3): 3/10 easy
--   Outer Space ring 3 (maxC=4): 3/10 easy + 1/10 medium
--   Outer Space ring 4 (maxC=4..5*): 3/10 easy + 2/10 medium  + 1/50 Kraken
--   Outer Space ring 5 (maxC=5):     3/10 easy + 2/10 medium + 1/10 hard + 1/50 Kraken
-- (*) Ring 4 = tiles where maxC=4 AND distance from origin ≥ 28
--     Ring 5 = maxC=5

local M = {}

local constellation = require("asteroids.constellation")
local particle = require("asteroids.particle")

-- ===================== ZONE RING CLASSIFICATION =====================

-- Returns a numeric ring index (0–5) for more granular spawn tables.
-- 0 = The Nebula, 1 = Inner Space, 2 = Deep Space ring 1,
-- 3 = Deep Space ring 2, 4 = Outer Space ring 3/4, 5 = Outer Space ring 5
function M.getSpawnRing(tileX, tileY)
  local cx, cy = constellation.getConstellationCoords(tileX, tileY)
  local maxC = math.max(math.abs(cx), math.abs(cy))

  if maxC == 0 then return 0 end       -- The Nebula
  if maxC == 1 then return 1 end       -- Inner Space
  if maxC == 2 then return 2 end       -- Deep Space ring 1
  if maxC == 3 then return 3 end       -- Deep Space ring 2

  -- Outer Space: split by tile distance from origin for rings 4 and 5
  local dist = math.max(math.abs(tileX), math.abs(tileY))
  if maxC >= 5 or dist >= 35 then
    return 5                            -- Outer Space ring 5
  elseif dist >= 28 then
    return 4                            -- Outer Space ring 4
  end
  return 4                              -- Outer Space ring 3 (default outer)
end

-- More precise ring with sub-ring for Outer Space
function M.getDetailedRing(tileX, tileY)
  local cx, cy = constellation.getConstellationCoords(tileX, tileY)
  local maxC = math.max(math.abs(cx), math.abs(cy))

  if maxC == 0 then return "nebula", 0 end
  if maxC == 1 then return "inner_space", 1 end
  if maxC == 2 then return "deep_1", 2 end
  if maxC == 3 then return "deep_2", 3 end

  local dist = math.max(math.abs(tileX), math.abs(tileY))
  if maxC >= 5 or dist >= 35 then
    return "outer_5", 5
  elseif dist >= 28 then
    return "outer_4", 4
  end
  return "outer_3", 3  -- default outer ring
end

-- ===================== SPAWN TABLE =====================
-- Each entry: { easyChance, mediumChance, hardChance, krakenChance }
-- Chances are out of 1.0  (e.g. 1/10 = 0.1)

local SPAWN_TABLE = {
  [0] = { easy = 0,    medium = 0,   hard = 0,   kraken = 0 },      -- Nebula
  [1] = { easy = 0.1,  medium = 0,   hard = 0,   kraken = 0 },      -- Inner Space
  [2] = { easy = 0.2,  medium = 0,   hard = 0,   kraken = 0 },      -- Deep Space 1
  [3] = { easy = 0.3,  medium = 0,   hard = 0,   kraken = 0 },      -- Deep Space 2
}

-- Outer Space ring 3 (maxC=4, close)
SPAWN_TABLE[4] = function(tileX, tileY)
  local dist = math.max(math.abs(tileX), math.abs(tileY))
  if dist < 28 then
    -- Ring 3: 3/10 easy, 1/10 medium
    return { easy = 0.3, medium = 0.1, hard = 0, kraken = 0 }
  else
    -- Ring 4: 3/10 easy, 2/10 medium, 1/50 Kraken
    return { easy = 0.3, medium = 0.2, hard = 0, kraken = 0.02 }
  end
end

-- Outer Space ring 5
SPAWN_TABLE[5] = { easy = 0.3, medium = 0.2, hard = 0.1, kraken = 0.02 }

function M.getSpawnChances(tileX, tileY)
  local ring = M.getSpawnRing(tileX, tileY)
  local entry = SPAWN_TABLE[ring]
  if type(entry) == "function" then
    return entry(tileX, tileY)
  end
  return entry or SPAWN_TABLE[0]
end

-- ===================== ENEMY DEFINITIONS =====================
-- Starfox-style enemy types with fancy behaviors

M.DIFFICULTY_EASY = "easy"
M.DIFFICULTY_MEDIUM = "medium"
M.DIFFICULTY_HARD = "hard"

-- Easy enemies: small fighters in formation, predictable patterns
local EASY_ENEMY_DEFS = {
  {
    id = "scout",
    name = "Scout Drone",
    size = 14,
    health = 2,
    speed = 120,
    score = 100,
    color = {0.3, 0.8, 0.3},
    accentColor = {0.5, 1.0, 0.5},
    behavior = "zigzag",    -- flies in zigzag pattern
    shootCooldown = 2.5,
    bulletSpeed = 250,
    formationCount = {3, 5},  -- spawn 3–5 in a wing
  },
  {
    id = "interceptor",
    name = "Interceptor",
    size = 16,
    health = 3,
    speed = 160,
    score = 150,
    color = {0.8, 0.6, 0.2},
    accentColor = {1.0, 0.8, 0.3},
    behavior = "strafe",    -- strafing runs across screen
    shootCooldown = 2.0,
    bulletSpeed = 300,
    formationCount = {2, 4},
  },
}

-- Medium enemies: tougher with special attacks
local MEDIUM_ENEMY_DEFS = {
  {
    id = "cruiser",
    name = "Space Cruiser",
    size = 28,
    health = 8,
    speed = 80,
    score = 350,
    color = {0.6, 0.3, 0.8},
    accentColor = {0.8, 0.5, 1.0},
    behavior = "orbit",     -- orbits player at medium range
    shootCooldown = 1.2,
    bulletSpeed = 280,
    bulletSpread = 3,       -- fires 3-bullet spread
    formationCount = {1, 3},
  },
  {
    id = "bomber",
    name = "Void Bomber",
    size = 32,
    health = 10,
    speed = 60,
    score = 400,
    color = {0.8, 0.2, 0.2},
    accentColor = {1.0, 0.4, 0.3},
    behavior = "bombing_run", -- slow passes dropping mines
    shootCooldown = 1.8,
    bulletSpeed = 200,
    dropsMinefield = true,
    formationCount = {1, 2},
  },
}

-- Hard enemies: dangerous elites
local HARD_ENEMY_DEFS = {
  {
    id = "ace",
    name = "Void Ace",
    size = 20,
    health = 15,
    speed = 200,
    score = 800,
    color = {1.0, 0.1, 0.1},
    accentColor = {1.0, 0.5, 0.2},
    behavior = "ace",       -- aggressive dogfighting AI
    shootCooldown = 0.6,
    bulletSpeed = 400,
    dodgeChance = 0.3,      -- can dodge player bullets
    formationCount = {1, 2},
  },
  {
    id = "phantom",
    name = "Phantom Wraith",
    size = 22,
    health = 12,
    speed = 180,
    score = 700,
    color = {0.4, 0.1, 0.6},
    accentColor = {0.7, 0.3, 1.0},
    behavior = "cloak",     -- phases in and out of visibility
    shootCooldown = 1.0,
    bulletSpeed = 350,
    cloakDuration = 2.0,
    visibleDuration = 3.0,
    formationCount = {1, 2},
  },
}

-- ===================== ENEMY INSTANCE CREATION =====================

function M.newEnemy(def, x, y)
  return {
    x = x,
    y = y,
    vx = 0,
    vy = 0,
    defId = def.id,
    name = def.name,
    size = def.size,
    health = def.health,
    maxHealth = def.health,
    speed = def.speed,
    score = def.score,
    color = def.color,
    accentColor = def.accentColor,
    behavior = def.behavior,
    shootCooldown = def.shootCooldown,
    shootTimer = def.shootCooldown * (0.5 + math.random() * 0.5),
    bulletSpeed = def.bulletSpeed,
    bulletSpread = def.bulletSpread or 1,
    dodgeChance = def.dodgeChance or 0,
    cloakDuration = def.cloakDuration,
    visibleDuration = def.visibleDuration,
    dropsMinefield = def.dropsMinefield,
    -- State
    dead = false,
    angle = math.random() * math.pi * 2,
    behaviorTimer = 0,
    behaviorPhase = 0,
    strafeDir = math.random() < 0.5 and 1 or -1,
    warpInTimer = 0,
    warpInDuration = 1.0,
    warpingIn = true,
    -- Visual state
    flashTimer = 0,
    damageFlash = 0,
    trailParticles = {},
    engineGlow = 0,
    -- Cloak state (for phantom type)
    cloaked = false,
    cloakTimer = 0,
    -- Mine state (for bomber type)
    mineTimer = 0,
    mines = {},
    -- Warp-in animation
    warpScale = 0,
    warpRotation = math.random() * math.pi * 2,
    -- Explosion
    explosionTimer = 0,
    explosionParticles = {},
    explosionRings = {},
  }
end

-- ===================== FORMATION SPAWNING =====================
-- Starfox-style: enemies warp in from edges in formation

function M.spawnFormation(difficulty, screenW, screenH, shipX, shipY)
  local defs
  if difficulty == M.DIFFICULTY_EASY then
    defs = EASY_ENEMY_DEFS
  elseif difficulty == M.DIFFICULTY_MEDIUM then
    defs = MEDIUM_ENEMY_DEFS
  else
    defs = HARD_ENEMY_DEFS
  end

  local def = defs[math.random(#defs)]
  local minCount = def.formationCount[1]
  local maxCount = def.formationCount[2]
  local count = minCount + math.random(maxCount - minCount + 1) - 1

  local enemies = {}
  local pattern = M.pickFormationPattern(count)

  -- Choose entry side (away from player)
  local side = math.random(4)
  local baseX, baseY, entryAngle

  if side == 1 then -- Left
    baseX = -60
    baseY = math.random(100, screenH - 100)
    entryAngle = 0
  elseif side == 2 then -- Right
    baseX = screenW + 60
    baseY = math.random(100, screenH - 100)
    entryAngle = math.pi
  elseif side == 3 then -- Top
    baseX = math.random(100, screenW - 100)
    baseY = -60
    entryAngle = math.pi / 2
  else -- Bottom
    baseX = math.random(100, screenW - 100)
    baseY = screenH + 60
    entryAngle = -math.pi / 2
  end

  for i, offset in ipairs(pattern) do
    if i <= count then
      -- Offset perpendicular to entry direction
      local perpX = math.cos(entryAngle + math.pi / 2) * offset.x
      local perpY = math.sin(entryAngle + math.pi / 2) * offset.x
      local depthX = math.cos(entryAngle) * offset.y
      local depthY = math.sin(entryAngle) * offset.y

      local ex = baseX + perpX - depthX
      local ey = baseY + perpY - depthY

      local enemy = M.newEnemy(def, ex, ey)
      enemy.angle = entryAngle
      -- Stagger warp-in timing for dramatic effect
      enemy.warpInTimer = -i * 0.15
      table.insert(enemies, enemy)
    end
  end

  return enemies
end

-- Formation patterns (offsets from leader position)
function M.pickFormationPattern(count)
  local patterns = {
    -- V-formation
    function(n)
      local pts = {{x = 0, y = 0}}
      for i = 1, n - 1 do
        local side = (i % 2 == 1) and 1 or -1
        local row = math.ceil(i / 2)
        table.insert(pts, {x = side * row * 40, y = row * 30})
      end
      return pts
    end,
    -- Line abreast
    function(n)
      local pts = {}
      for i = 1, n do
        table.insert(pts, {x = (i - (n + 1) / 2) * 50, y = 0})
      end
      return pts
    end,
    -- Echelon
    function(n)
      local pts = {}
      for i = 1, n do
        table.insert(pts, {x = (i - 1) * 35, y = (i - 1) * 25})
      end
      return pts
    end,
    -- Diamond
    function(n)
      local pts = {{x = 0, y = -30}, {x = -35, y = 0}, {x = 35, y = 0}, {x = 0, y = 30}}
      for i = 5, n do
        table.insert(pts, {x = (math.random() - 0.5) * 80, y = (math.random() - 0.5) * 80})
      end
      return pts
    end,
  }

  local pattern = patterns[math.random(#patterns)]
  return pattern(count)
end

-- ===================== ENEMY AI UPDATE =====================

function M.updateEnemy(enemy, dt, shipX, shipY, screenW, screenH)
  if enemy.dead then
    enemy.explosionTimer = enemy.explosionTimer + dt
    M.updateExplosionParticles(enemy, dt)
    return
  end

  -- Warp-in animation
  if enemy.warpingIn then
    enemy.warpInTimer = enemy.warpInTimer + dt
    if enemy.warpInTimer < 0 then return end -- Staggered delay

    local progress = math.min(1, enemy.warpInTimer / enemy.warpInDuration)
    enemy.warpScale = progress
    enemy.warpRotation = enemy.warpRotation + dt * 8 * (1 - progress)

    if progress >= 1 then
      enemy.warpingIn = false
      enemy.warpScale = 1
    end
    return
  end

  -- Damage flash decay
  enemy.damageFlash = math.max(0, enemy.damageFlash - dt * 4)
  enemy.flashTimer = enemy.flashTimer + dt
  enemy.engineGlow = 0.5 + math.sin(enemy.flashTimer * 6) * 0.5

  -- Shoot timer
  enemy.shootTimer = enemy.shootTimer - dt

  -- Update engine trail particles
  M.updateTrailParticles(enemy, dt)

  -- Behavior-specific update
  if enemy.behavior == "zigzag" then
    M.updateZigzag(enemy, dt, shipX, shipY, screenW, screenH)
  elseif enemy.behavior == "strafe" then
    M.updateStrafe(enemy, dt, shipX, shipY, screenW, screenH)
  elseif enemy.behavior == "orbit" then
    M.updateOrbit(enemy, dt, shipX, shipY, screenW, screenH)
  elseif enemy.behavior == "bombing_run" then
    M.updateBombingRun(enemy, dt, shipX, shipY, screenW, screenH)
  elseif enemy.behavior == "ace" then
    M.updateAce(enemy, dt, shipX, shipY, screenW, screenH)
  elseif enemy.behavior == "cloak" then
    M.updateCloak(enemy, dt, shipX, shipY, screenW, screenH)
  end

  -- Apply velocity
  enemy.x = enemy.x + enemy.vx * dt
  enemy.y = enemy.y + enemy.vy * dt
end

-- ===== ZIGZAG BEHAVIOR (Easy) =====
function M.updateZigzag(enemy, dt, shipX, shipY, screenW, screenH)
  enemy.behaviorTimer = enemy.behaviorTimer + dt

  -- Move toward player with zigzag offset
  local dx = shipX - enemy.x
  local dy = shipY - enemy.y
  local dist = math.sqrt(dx * dx + dy * dy)
  if dist < 1 then dist = 1 end

  local targetAngle = math.atan2(dy, dx)

  -- Zigzag: add sinusoidal offset perpendicular to heading
  local zigOffset = math.sin(enemy.behaviorTimer * 3) * 80
  local perpAngle = targetAngle + math.pi / 2
  local goalX = shipX + math.cos(perpAngle) * zigOffset
  local goalY = shipY + math.sin(perpAngle) * zigOffset

  local gdx = goalX - enemy.x
  local gdy = goalY - enemy.y
  local gdist = math.sqrt(gdx * gdx + gdy * gdy)
  if gdist < 1 then gdist = 1 end

  enemy.angle = math.atan2(gdy, gdx)
  enemy.vx = (gdx / gdist) * enemy.speed
  enemy.vy = (gdy / gdist) * enemy.speed

  -- Keep distance: don't ram the player
  if dist < 150 then
    enemy.vx = enemy.vx - (dx / dist) * enemy.speed * 0.5
    enemy.vy = enemy.vy - (dy / dist) * enemy.speed * 0.5
  end
end

-- ===== STRAFE BEHAVIOR (Easy) =====
function M.updateStrafe(enemy, dt, shipX, shipY, screenW, screenH)
  enemy.behaviorTimer = enemy.behaviorTimer + dt

  -- Fly perpendicular to player, making strafing passes
  local dx = shipX - enemy.x
  local dy = shipY - enemy.y
  local dist = math.sqrt(dx * dx + dy * dy)
  if dist < 1 then dist = 1 end

  -- Strafe direction flips every ~3 seconds
  if enemy.behaviorTimer > 3 then
    enemy.behaviorTimer = 0
    enemy.strafeDir = -enemy.strafeDir
  end

  local toPlayerAngle = math.atan2(dy, dx)
  local strafeAngle = toPlayerAngle + (math.pi / 2) * enemy.strafeDir

  enemy.angle = toPlayerAngle
  enemy.vx = math.cos(strafeAngle) * enemy.speed

  -- Gently approach player Y level
  enemy.vy = math.sin(strafeAngle) * enemy.speed * 0.6 + (dy / dist) * enemy.speed * 0.4
end

-- ===== ORBIT BEHAVIOR (Medium) =====
function M.updateOrbit(enemy, dt, shipX, shipY, screenW, screenH)
  enemy.behaviorTimer = enemy.behaviorTimer + dt

  local dx = shipX - enemy.x
  local dy = shipY - enemy.y
  local dist = math.sqrt(dx * dx + dy * dy)
  if dist < 1 then dist = 1 end

  local orbitRadius = 200
  local orbitSpeed = 1.5

  if dist > orbitRadius + 50 then
    -- Approach player
    enemy.vx = (dx / dist) * enemy.speed
    enemy.vy = (dy / dist) * enemy.speed
  elseif dist < orbitRadius - 50 then
    -- Back away
    enemy.vx = -(dx / dist) * enemy.speed * 0.5
    enemy.vy = -(dy / dist) * enemy.speed * 0.5
  else
    -- Orbit: move tangentially
    local tangentAngle = math.atan2(dy, dx) + math.pi / 2
    enemy.vx = math.cos(tangentAngle) * enemy.speed
    enemy.vy = math.sin(tangentAngle) * enemy.speed
  end

  enemy.angle = math.atan2(dy, dx)
end

-- ===== BOMBING RUN BEHAVIOR (Medium) =====
function M.updateBombingRun(enemy, dt, shipX, shipY, screenW, screenH)
  enemy.behaviorTimer = enemy.behaviorTimer + dt

  -- Slow horizontal passes, dropping mines
  local dx = shipX - enemy.x
  local dy = shipY - enemy.y
  local dist = math.sqrt(dx * dx + dy * dy)
  if dist < 1 then dist = 1 end

  -- Move in wide passes above the player
  local passY = shipY - 150
  local yDiff = passY - enemy.y

  enemy.vx = enemy.strafeDir * enemy.speed
  enemy.vy = yDiff * 0.5

  -- Reverse direction at screen edges
  if enemy.x < 50 or enemy.x > screenW - 50 then
    enemy.strafeDir = -enemy.strafeDir
  end

  enemy.angle = math.atan2(enemy.vy, enemy.vx)

  -- Drop mines periodically
  enemy.mineTimer = enemy.mineTimer + dt
  if enemy.mineTimer >= 2.0 and enemy.dropsMinefield then
    enemy.mineTimer = 0
    table.insert(enemy.mines, {
      x = enemy.x,
      y = enemy.y,
      timer = 5.0,        -- expires after 5s
      pulseTimer = 0,
      size = 6,
      armed = false,
      armTimer = 1.0,      -- arms after 1s
    })
  end
end

-- ===== ACE BEHAVIOR (Hard) =====
function M.updateAce(enemy, dt, shipX, shipY, screenW, screenH)
  enemy.behaviorTimer = enemy.behaviorTimer + dt

  local dx = shipX - enemy.x
  local dy = shipY - enemy.y
  local dist = math.sqrt(dx * dx + dy * dy)
  if dist < 1 then dist = 1 end

  -- Aggressive pursuit with evasive maneuvers
  local phase = math.floor(enemy.behaviorTimer / 2) % 3

  if phase == 0 then
    -- Direct attack run
    enemy.vx = (dx / dist) * enemy.speed
    enemy.vy = (dy / dist) * enemy.speed
  elseif phase == 1 then
    -- Barrel roll evasion (spiral movement)
    local rollAngle = enemy.behaviorTimer * 6
    local rollRadius = 60
    enemy.vx = (dx / dist) * enemy.speed * 0.7 + math.cos(rollAngle) * rollRadius
    enemy.vy = (dy / dist) * enemy.speed * 0.7 + math.sin(rollAngle) * rollRadius
  else
    -- High-speed flyby
    local perpAngle = math.atan2(dy, dx) + math.pi / 2
    enemy.vx = math.cos(perpAngle) * enemy.speed * 1.5
    enemy.vy = math.sin(perpAngle) * enemy.speed * 1.5
  end

  enemy.angle = math.atan2(dy, dx)
end

-- ===== CLOAK BEHAVIOR (Hard) =====
function M.updateCloak(enemy, dt, shipX, shipY, screenW, screenH)
  enemy.behaviorTimer = enemy.behaviorTimer + dt
  enemy.cloakTimer = enemy.cloakTimer + dt

  if enemy.cloaked then
    if enemy.cloakTimer >= (enemy.cloakDuration or 2.0) then
      enemy.cloaked = false
      enemy.cloakTimer = 0
    end
  else
    if enemy.cloakTimer >= (enemy.visibleDuration or 3.0) then
      enemy.cloaked = true
      enemy.cloakTimer = 0
    end
  end

  -- Stalk player (approach from behind when cloaked)
  local dx = shipX - enemy.x
  local dy = shipY - enemy.y
  local dist = math.sqrt(dx * dx + dy * dy)
  if dist < 1 then dist = 1 end

  if enemy.cloaked then
    -- Sneak closer
    enemy.vx = (dx / dist) * enemy.speed * 0.6
    enemy.vy = (dy / dist) * enemy.speed * 0.6
  else
    -- Visible: strafe and fire
    local perpAngle = math.atan2(dy, dx) + math.pi / 2
    enemy.vx = math.cos(perpAngle) * enemy.speed * 0.8
    enemy.vy = (dy / dist) * enemy.speed * 0.4
    -- Maintain distance
    if dist < 120 then
      enemy.vx = enemy.vx - (dx / dist) * enemy.speed * 0.5
      enemy.vy = enemy.vy - (dy / dist) * enemy.speed * 0.5
    end
  end

  enemy.angle = math.atan2(dy, dx)
end

-- ===================== SHOOTING =====================

function M.canShoot(enemy)
  if enemy.dead or enemy.warpingIn then return false end
  if enemy.cloaked then return false end
  return enemy.shootTimer <= 0
end

function M.getShots(enemy, shipX, shipY)
  if not M.canShoot(enemy) then return {} end
  enemy.shootTimer = enemy.shootCooldown

  local shots = {}
  local angle = math.atan2(shipY - enemy.y, shipX - enemy.x)
  local spread = enemy.bulletSpread or 1

  for i = 1, spread do
    local spreadAngle = angle
    if spread > 1 then
      spreadAngle = angle + ((i - 1) / (spread - 1) - 0.5) * 0.4
    end
    -- Add slight inaccuracy for organic feel
    spreadAngle = spreadAngle + (math.random() - 0.5) * 0.15

    table.insert(shots, {
      x = enemy.x + math.cos(spreadAngle) * enemy.size,
      y = enemy.y + math.sin(spreadAngle) * enemy.size,
      vx = math.cos(spreadAngle) * enemy.bulletSpeed,
      vy = math.sin(spreadAngle) * enemy.bulletSpeed,
      lifetime = 3,
      owner = "enemy",
      enemyBullet = true,
      damage = 8,
      size = 4,
      color = enemy.accentColor,
    })
  end

  return shots
end

-- ===================== DAMAGE & DEATH =====================

function M.takeDamage(enemy, damage)
  if enemy.dead or enemy.warpingIn then return false end
  if enemy.cloaked and math.random() < 0.5 then return false end -- 50% miss when cloaked

  enemy.health = enemy.health - damage
  enemy.damageFlash = 1.0

  if enemy.health <= 0 then
    enemy.dead = true
    M.initExplosion(enemy)
    return true -- killed
  end
  return false
end

function M.initExplosion(enemy)
  enemy.explosionParticles = {}
  enemy.explosionRings = {}

  -- Starfox-style dramatic explosion
  for i = 1, 30 do
    local angle = (i / 30) * math.pi * 2 + (math.random() - 0.5) * 0.4
    local speed = 80 + math.random() * 180
    table.insert(enemy.explosionParticles, {
      x = enemy.x,
      y = enemy.y,
      vx = math.cos(angle) * speed,
      vy = math.sin(angle) * speed,
      life = 0.6 + math.random() * 1.0,
      maxLife = 1.6,
      size = 2 + math.random() * 4,
      r = enemy.color[1],
      g = enemy.color[2],
      b = enemy.color[3],
    })
  end

  -- Shockwave rings
  for i = 1, 2 do
    table.insert(enemy.explosionRings, {
      radius = 5,
      maxRadius = 40 + i * 25,
      speed = 120 + i * 50,
      alpha = 1.0,
      delay = (i - 1) * 0.1,
      started = false,
    })
  end
end

function M.updateExplosionParticles(enemy, dt)
  for i = #enemy.explosionParticles, 1, -1 do
    local p = enemy.explosionParticles[i]
    p.x = p.x + p.vx * dt
    p.y = p.y + p.vy * dt
    p.vx = p.vx * 0.97
    p.vy = p.vy * 0.97
    p.life = p.life - dt
    if p.life <= 0 then
      table.remove(enemy.explosionParticles, i)
    end
  end

  for _, ring in ipairs(enemy.explosionRings) do
    if enemy.explosionTimer >= ring.delay then
      ring.started = true
    end
    if ring.started then
      ring.radius = ring.radius + ring.speed * dt
      ring.alpha = math.max(0, 1.0 - (ring.radius / ring.maxRadius))
    end
  end
end

function M.isExplosionDone(enemy)
  return enemy.dead and enemy.explosionTimer > 2.0
end

-- ===================== TRAIL PARTICLES =====================

function M.updateTrailParticles(enemy, dt)
  -- Spawn engine trail
  if not enemy.dead and not enemy.warpingIn then
    local trailAngle = enemy.angle + math.pi  -- Behind the ship
    table.insert(enemy.trailParticles, {
      x = enemy.x + math.cos(trailAngle) * enemy.size * 0.8,
      y = enemy.y + math.sin(trailAngle) * enemy.size * 0.8,
      vx = math.cos(trailAngle) * 40 + (math.random() - 0.5) * 20,
      vy = math.sin(trailAngle) * 40 + (math.random() - 0.5) * 20,
      life = 0.4,
      maxLife = 0.4,
      size = 2 + math.random() * 2,
    })
  end

  -- Update existing particles
  for i = #enemy.trailParticles, 1, -1 do
    local p = enemy.trailParticles[i]
    p.x = p.x + p.vx * dt
    p.y = p.y + p.vy * dt
    p.life = p.life - dt
    if p.life <= 0 then
      table.remove(enemy.trailParticles, i)
    end
  end

  -- Cap trail length
  while #enemy.trailParticles > 20 do
    table.remove(enemy.trailParticles, 1)
  end
end

-- ===================== MINE UPDATE =====================

function M.updateMines(enemy, dt)
  for i = #enemy.mines, 1, -1 do
    local mine = enemy.mines[i]
    mine.timer = mine.timer - dt
    mine.pulseTimer = mine.pulseTimer + dt

    if not mine.armed then
      mine.armTimer = mine.armTimer - dt
      if mine.armTimer <= 0 then
        mine.armed = true
      end
    end

    if mine.timer <= 0 then
      table.remove(enemy.mines, i)
    end
  end
end

-- Check if ship hits a mine  (returns damage or 0)
function M.checkMineCollision(enemy, shipX, shipY, shipSize)
  for i = #enemy.mines, 1, -1 do
    local mine = enemy.mines[i]
    if mine.armed then
      local dx = shipX - mine.x
      local dy = shipY - mine.y
      local dist = math.sqrt(dx * dx + dy * dy)
      if dist < mine.size + shipSize then
        table.remove(enemy.mines, i)
        return 15 -- mine damage
      end
    end
  end
  return 0
end

-- ===================== OFF-SCREEN CHECK =====================

function M.isOffScreen(enemy, screenW, screenH, margin)
  margin = margin or 200
  return enemy.x < -margin or enemy.x > screenW + margin
      or enemy.y < -margin or enemy.y > screenH + margin
end

-- ===================== DRAWING =====================

function M.drawEnemy(enemy)
  if enemy.dead then
    M.drawExplosion(enemy)
    return
  end

  -- Draw engine trail
  for _, p in ipairs(enemy.trailParticles) do
    local alpha = p.life / p.maxLife
    love.graphics.setColor(enemy.accentColor[1], enemy.accentColor[2], enemy.accentColor[3], alpha * 0.6)
    love.graphics.circle("fill", p.x, p.y, p.size * alpha)
  end

  -- Warp-in effect
  if enemy.warpingIn then
    if enemy.warpInTimer < 0 then return end
    local scale = enemy.warpScale
    local rot = enemy.warpRotation

    -- Warp flash
    love.graphics.setColor(1, 1, 1, (1 - scale) * 0.8)
    love.graphics.circle("fill", enemy.x, enemy.y, enemy.size * 2 * (1 - scale))

    -- Stretchy warp-in
    love.graphics.push()
    love.graphics.translate(enemy.x, enemy.y)
    love.graphics.rotate(rot)
    love.graphics.scale(scale, scale * (0.5 + scale * 0.5))

    love.graphics.setColor(enemy.color[1], enemy.color[2], enemy.color[3], scale)
    M.drawShipShape(0, 0, enemy.size, 0, enemy.accentColor)

    love.graphics.pop()
    return
  end

  -- Cloak effect
  if enemy.cloaked then
    local shimmer = 0.1 + math.sin(enemy.flashTimer * 10) * 0.05
    love.graphics.setColor(enemy.color[1], enemy.color[2], enemy.color[3], shimmer)
    -- Draw ghost outline
    love.graphics.push()
    love.graphics.translate(enemy.x, enemy.y)
    love.graphics.rotate(enemy.angle)
    M.drawShipShape(0, 0, enemy.size, 0, {enemy.accentColor[1], enemy.accentColor[2], enemy.accentColor[3], shimmer})
    love.graphics.pop()
    return
  end

  -- Normal draw
  local flashWhite = enemy.damageFlash > 0

  love.graphics.push()
  love.graphics.translate(enemy.x, enemy.y)
  love.graphics.rotate(enemy.angle)

  -- Engine glow
  local glowAlpha = enemy.engineGlow * 0.4
  love.graphics.setColor(enemy.accentColor[1], enemy.accentColor[2], enemy.accentColor[3], glowAlpha)
  love.graphics.circle("fill", -enemy.size * 0.8, 0, enemy.size * 0.4)

  -- Body
  if flashWhite then
    love.graphics.setColor(1, 1, 1, 1)
  else
    love.graphics.setColor(enemy.color[1], enemy.color[2], enemy.color[3], 1)
  end
  M.drawShipShape(0, 0, enemy.size, 0, flashWhite and {1,1,1} or enemy.accentColor)

  -- Health bar (only if damaged)
  if enemy.health < enemy.maxHealth then
    love.graphics.rotate(-enemy.angle) -- Undo rotation for horizontal bar
    local barW = enemy.size * 2
    local barH = 3
    local barY = -enemy.size - 8
    -- Background
    love.graphics.setColor(0.2, 0.2, 0.2, 0.8)
    love.graphics.rectangle("fill", -barW / 2, barY, barW, barH)
    -- Fill
    local pct = enemy.health / enemy.maxHealth
    local r = 1 - pct
    local g = pct
    love.graphics.setColor(r, g, 0, 0.9)
    love.graphics.rectangle("fill", -barW / 2, barY, barW * pct, barH)
  end

  love.graphics.pop()

  -- Draw mines
  if enemy.mines then
    for _, mine in ipairs(enemy.mines) do
      local pulse = math.sin(mine.pulseTimer * 6) * 0.3
      if mine.armed then
        love.graphics.setColor(1.0, 0.2 + pulse, 0.1, 0.8)
      else
        love.graphics.setColor(0.4, 0.4, 0.4, 0.6)
      end
      love.graphics.circle("fill", mine.x, mine.y, mine.size)
      -- Spikes
      if mine.armed then
        love.graphics.setColor(1, 0.5, 0.1, 0.6)
        for i = 1, 6 do
          local a = (i / 6) * math.pi * 2 + mine.pulseTimer
          love.graphics.line(
            mine.x, mine.y,
            mine.x + math.cos(a) * (mine.size + 4),
            mine.y + math.sin(a) * (mine.size + 4)
          )
        end
      end
    end
  end
end

-- Draw a Starfox-style ship silhouette
function M.drawShipShape(x, y, size, angle, accentColor)
  -- Main body (arrow shape)
  love.graphics.polygon("fill",
    x + size, y,                                  -- Nose
    x - size * 0.6, y - size * 0.5,              -- Left wing
    x - size * 0.3, y,                            -- Rear center
    x - size * 0.6, y + size * 0.5               -- Right wing
  )

  -- Wing accents
  if accentColor then
    local prevR, prevG, prevB, prevA = love.graphics.getColor()
    love.graphics.setColor(accentColor[1] or 1, accentColor[2] or 1, accentColor[3] or 1, accentColor[4] or 0.7)
    love.graphics.setLineWidth(1.5)
    love.graphics.line(x + size * 0.3, y, x - size * 0.5, y - size * 0.45)
    love.graphics.line(x + size * 0.3, y, x - size * 0.5, y + size * 0.45)
    love.graphics.setColor(prevR, prevG, prevB, prevA)
    love.graphics.setLineWidth(1)
  end
end

-- Draw explosion
function M.drawExplosion(enemy)
  -- Shockwave rings
  for _, ring in ipairs(enemy.explosionRings) do
    if ring.started and ring.alpha > 0 then
      love.graphics.setLineWidth(2)
      love.graphics.setColor(enemy.accentColor[1], enemy.accentColor[2], enemy.accentColor[3], ring.alpha * 0.6)
      love.graphics.circle("line", enemy.x, enemy.y, ring.radius)
      love.graphics.setColor(1, 0.8, 0.3, ring.alpha * 0.3)
      love.graphics.circle("line", enemy.x, enemy.y, ring.radius * 0.7)
      love.graphics.setLineWidth(1)
    end
  end

  -- Central fireball
  if enemy.explosionTimer < 0.4 then
    local t = enemy.explosionTimer / 0.4
    love.graphics.setColor(1, 1, 1, (1 - t) * 0.9)
    love.graphics.circle("fill", enemy.x, enemy.y, enemy.size * (1 - t) * 0.5)
    love.graphics.setColor(1, 0.5, 0, (1 - t) * 0.6)
    love.graphics.circle("fill", enemy.x, enemy.y, enemy.size * (1 + t * 0.5))
  end

  -- Particles
  for _, p in ipairs(enemy.explosionParticles) do
    local alpha = p.life / p.maxLife
    love.graphics.setColor(p.r, p.g, p.b, alpha)
    love.graphics.circle("fill", p.x, p.y, p.size * alpha)
  end
end

return M
