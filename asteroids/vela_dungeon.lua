-- asteroids/vela_dungeon.lua
-- Zelda: Link's Awakening-style 4x4 dungeon in the Vela constellation.
-- The dungeon is entered via a portal tile inside Vela and consists of
-- 16 rooms arranged in a 4x4 grid.  The player moves between rooms by
-- touching screen edges.  Room (4,4) contains a 3-phase boss whose defeat
-- drops the Firebird ship.
--
-- Room layout (row, col — 1-indexed):
--   [1,1] [1,2] [1,3] [1,4]
--   [2,1] [2,2] [2,3] [2,4]
--   [3,1] [3,2] [3,3] [3,4]
--   [4,1] [4,2] [4,3] [4,4]  ← Boss room
--
-- Entry is at room (1,1).

local M = {}
local constellation = require("asteroids.constellation")

-- ==================== CONSTANTS ====================

local ROOM_TRANSITION_SPEED = 0.4   -- seconds for slide transition
local WALL_THICKNESS = 16
local DOOR_WIDTH = 80
local ENEMY_BULLET_SPEED = 200
local ENEMY_SHOOT_INTERVAL = 2.5

-- Boss phase constants
local BOSS_PHASE_1_HP = 80
local BOSS_PHASE_2_HP = 100
local BOSS_PHASE_3_HP = 120
local BOSS_TOTAL_HP = BOSS_PHASE_1_HP + BOSS_PHASE_2_HP + BOSS_PHASE_3_HP

-- ==================== STATE ====================

local active = false
local roomX = 1    -- current room column (1-4)
local roomY = 1    -- current room row    (1-4)
local screenW = 1366
local screenH = 768
local time = 0

-- Room data cache (generated per-room)
local roomCache = {}

-- Transition state
local transition = {
  active = false,
  timer = 0,
  dirX = 0,  -- -1 left, +1 right
  dirY = 0,  -- -1 up,   +1 down
  fromX = 1,
  fromY = 1,
}

-- Enemy state for current room
local enemies = {}
local enemyBullets = {}

-- Boss state
local boss = {
  active = false,
  phase = 1,           -- 1, 2, or 3
  health = BOSS_PHASE_1_HP,
  maxHealth = BOSS_PHASE_1_HP,
  totalMaxHealth = BOSS_TOTAL_HP,
  totalHealth = BOSS_TOTAL_HP,
  x = 0,
  y = 0,
  angle = 0,
  attackTimer = 0,
  moveTimer = 0,
  moveAngle = 0,
  flashTimer = 0,
  defeated = false,
  phaseTransition = false,
  phaseTransitionTimer = 0,
  shieldAngle = 0,
  chargeTimer = 0,
  charging = false,
  chargeTargetX = 0,
  chargeTargetY = 0,
  spawnTimer = 0,      -- Phase 2: minion spawn
  orbAngle = 0,        -- Phase 3: orbiting projectiles
  orbs = {},           -- Phase 3: orbiting fire orbs
  enraged = false,     -- Phase 3: low HP enrage
}

-- Reward state (Firebird drop)
local reward = {
  active = false,
  x = 0,
  y = 0,
  collected = false,
  glow = 0,
}

-- Room map: which rooms have which content
-- Each room: {doors = {up, down, left, right}, enemies = count, type = "normal"|"key"|"boss"|"treasure"}
local roomMap = {}

-- Cleared rooms tracking
local clearedRooms = {}

-- Minimap discovered rooms
local discoveredRooms = {}

-- Key items
local hasKey = false  -- needed to unlock boss door

-- ==================== DETERMINISTIC RNG ====================

local rng = 0
local function seed(a, b, salt)
  rng = math.abs((a * 73856093 + b * 19349663 + (salt or 0) * 83492791) % 2147483647)
end
local function rand()
  rng = (rng * 1103515245 + 12345) % 2147483648
  return rng / 2147483648
end
local function randInt(a, b)
  return a + math.floor(rand() * (b - a + 1))
end

-- ==================== ROOM MAP GENERATION ====================

local function generateRoomMap()
  roomMap = {}
  -- Fixed layout for a Zelda-style dungeon with critical path
  -- Row 1 (top): entrance row
  roomMap["1,1"] = {doors = {up = false, down = true, left = false, right = true},
                    enemies = 3, type = "normal", enemyType = "walker"}
  roomMap["1,2"] = {doors = {up = false, down = true, left = true, right = true},
                    enemies = 0, type = "treasure"}
  roomMap["1,3"] = {doors = {up = false, down = true, left = true, right = true},
                    enemies = 4, type = "normal", enemyType = "shooter"}
  roomMap["1,4"] = {doors = {up = false, down = true, left = true, right = false},
                    enemies = 2, type = "normal", enemyType = "walker"}

  -- Row 2
  roomMap["2,1"] = {doors = {up = true, down = true, left = false, right = true},
                    enemies = 4, type = "normal", enemyType = "mixed"}
  roomMap["2,2"] = {doors = {up = true, down = false, left = true, right = true},
                    enemies = 5, type = "normal", enemyType = "shooter"}
  roomMap["2,3"] = {doors = {up = true, down = true, left = true, right = false},
                    enemies = 0, type = "key"}
  roomMap["2,4"] = {doors = {up = true, down = true, left = false, right = false},
                    enemies = 3, type = "normal", enemyType = "charger"}

  -- Row 3
  roomMap["3,1"] = {doors = {up = true, down = false, left = false, right = true},
                    enemies = 5, type = "normal", enemyType = "shooter"}
  roomMap["3,2"] = {doors = {up = false, down = true, left = true, right = true},
                    enemies = 6, type = "normal", enemyType = "mixed"}
  roomMap["3,3"] = {doors = {up = true, down = true, left = true, right = true},
                    enemies = 4, type = "normal", enemyType = "charger"}
  roomMap["3,4"] = {doors = {up = true, down = true, left = true, right = false},
                    enemies = 3, type = "normal", enemyType = "walker"}

  -- Row 4 (bottom): boss row
  roomMap["4,1"] = {doors = {up = false, down = false, left = false, right = true},
                    enemies = 6, type = "normal", enemyType = "mixed"}
  roomMap["4,2"] = {doors = {up = true, down = false, left = true, right = true},
                    enemies = 5, type = "normal", enemyType = "shooter"}
  roomMap["4,3"] = {doors = {up = true, down = false, left = true, right = true},
                    enemies = 0, type = "treasure"}
  roomMap["4,4"] = {doors = {up = true, down = false, left = true, right = false},
                    enemies = 0, type = "boss"}
end

-- ==================== ENEMY GENERATION ====================

local function spawnRoomEnemies(rx, ry)
  local key = ry .. "," .. rx
  local room = roomMap[key]
  if not room then return {} end
  if clearedRooms[key] then return {} end

  local result = {}
  local count = room.enemies
  local etype = room.enemyType or "walker"

  seed(rx, ry, 42)

  for i = 1, count do
    local ex = 100 + rand() * (screenW - 200)
    local ey = 100 + rand() * (screenH - 200)
    local t = etype
    if etype == "mixed" then
      local r = rand()
      if r < 0.33 then t = "walker"
      elseif r < 0.66 then t = "shooter"
      else t = "charger" end
    end

    table.insert(result, {
      x = ex, y = ey,
      vx = 0, vy = 0,
      health = t == "charger" and 4 or (t == "shooter" and 2 or 3),
      maxHealth = t == "charger" and 4 or (t == "shooter" and 2 or 3),
      type = t,
      size = t == "charger" and 16 or 12,
      angle = rand() * math.pi * 2,
      moveTimer = rand() * 3,
      shootTimer = 1 + rand() * 2,
      flashTimer = 0,
      dead = false,
      -- Charger state
      charging = false,
      chargeTimer = 0,
      chargeVX = 0,
      chargeVY = 0,
      chargeCooldown = 0,
    })
  end
  return result
end

-- ==================== ROOM WALLS & DOORS ====================

local function getRoomWalls(rx, ry)
  local key = ry .. "," .. rx
  local room = roomMap[key]
  if not room then return {} end

  local walls = {}
  local wt = WALL_THICKNESS
  local dw = DOOR_WIDTH
  local cx = screenW / 2
  local cy = screenH / 2

  -- Top wall
  if not room.doors.up then
    table.insert(walls, {x = 0, y = 0, w = screenW, h = wt})
  else
    table.insert(walls, {x = 0, y = 0, w = cx - dw/2, h = wt})
    table.insert(walls, {x = cx + dw/2, y = 0, w = cx - dw/2, h = wt})
  end

  -- Bottom wall
  if not room.doors.down then
    table.insert(walls, {x = 0, y = screenH - wt, w = screenW, h = wt})
  else
    table.insert(walls, {x = 0, y = screenH - wt, w = cx - dw/2, h = wt})
    table.insert(walls, {x = cx + dw/2, y = screenH - wt, w = cx - dw/2, h = wt})
  end

  -- Left wall
  if not room.doors.left then
    table.insert(walls, {x = 0, y = 0, w = wt, h = screenH})
  else
    table.insert(walls, {x = 0, y = 0, w = wt, h = cy - dw/2})
    table.insert(walls, {x = 0, y = cy + dw/2, w = wt, h = cy - dw/2})
  end

  -- Right wall
  if not room.doors.right then
    table.insert(walls, {x = screenW - wt, y = 0, w = wt, h = screenH})
  else
    table.insert(walls, {x = screenW - wt, y = 0, w = wt, h = cy - dw/2})
    table.insert(walls, {x = screenW - wt, y = cy + dw/2, w = wt, h = cy - dw/2})
  end

  -- Boss room: locked door if no key
  if room.type == "boss" and not hasKey then
    -- Seal the entry doors with a locked barrier
    -- (left door is the main entry to boss room)
  end

  -- Add interior obstacles for some rooms
  seed(rx, ry, 99)
  if room.type == "normal" and room.enemies >= 4 then
    -- Place 1-2 pillar obstacles inside
    local numPillars = randInt(1, 2)
    for p = 1, numPillars do
      local px = 200 + rand() * (screenW - 400)
      local py = 200 + rand() * (screenH - 400)
      local ps = 30 + rand() * 30
      table.insert(walls, {x = px - ps/2, y = py - ps/2, w = ps, h = ps, isPillar = true})
    end
  end

  return walls
end

-- ==================== PUBLIC API ====================

--- Check if current tile should be the Vela dungeon entrance
function M.isVelaDungeonTile(tileX, tileY)
  -- The Vela dungeon entrance is at the center of the Vela constellation
  -- Vela is at constellation grid (1,1), center tile is (7,7)
  return tileX == 7 and tileY == 7
end

--- Enter the Vela dungeon
function M.enter(w, h)
  screenW = w or 1366
  screenH = h or 768
  active = true
  time = 0
  roomX = 1
  roomY = 1
  clearedRooms = {}
  discoveredRooms = {}
  discoveredRooms["1,1"] = true
  hasKey = false
  reward.active = false
  reward.collected = false
  enemyBullets = {}

  -- Generate dungeon layout
  generateRoomMap()

  -- Reset boss
  boss.active = false
  boss.defeated = false
  boss.phase = 1
  boss.health = BOSS_PHASE_1_HP
  boss.maxHealth = BOSS_PHASE_1_HP
  boss.totalHealth = BOSS_TOTAL_HP
  boss.totalMaxHealth = BOSS_TOTAL_HP
  boss.phaseTransition = false
  boss.orbs = {}

  -- Spawn initial room enemies
  enemies = spawnRoomEnemies(roomX, roomY)
end

function M.isActive()
  return active
end

function M.exit()
  active = false
  enemies = {}
  enemyBullets = {}
  boss.active = false
end

function M.isBossDefeated()
  return boss.defeated
end

function M.isRewardCollected()
  return reward.collected
end

-- ==================== ROOM TRANSITIONS ====================

local function enterRoom(newX, newY)
  roomX = newX
  roomY = newY
  local key = roomY .. "," .. roomX
  discoveredRooms[key] = true
  enemyBullets = {}

  local room = roomMap[key]
  if not room then return end

  if room.type == "boss" and not boss.defeated then
    boss.active = true
    boss.x = screenW / 2
    boss.y = screenH * 0.3
    boss.angle = 0
    boss.attackTimer = 2
    boss.moveTimer = 0
    boss.flashTimer = 0
    boss.charging = false
    boss.spawnTimer = 5
    boss.orbAngle = 0
    boss.orbs = {}
    boss.enraged = false
    if boss.phase == 1 then
      boss.health = BOSS_PHASE_1_HP
      boss.maxHealth = BOSS_PHASE_1_HP
    end
    enemies = {}
  elseif room.type == "key" and not clearedRooms[key] then
    -- Key room: key item sits in center until picked up
    enemies = {}
  elseif room.type == "treasure" and not clearedRooms[key] then
    enemies = {}
  else
    enemies = spawnRoomEnemies(roomX, roomY)
  end
end

local function startTransition(dx, dy)
  local newX = roomX + dx
  local newY = roomY + dy
  if newX < 1 or newX > 4 or newY < 1 or newY > 4 then return false end

  -- Check door exists
  local key = roomY .. "," .. roomX
  local room = roomMap[key]
  if not room then return false end

  if dx == 1 and not room.doors.right then return false end
  if dx == -1 and not room.doors.left then return false end
  if dy == 1 and not room.doors.down then return false end
  if dy == -1 and not room.doors.up then return false end

  -- Check if boss room is locked
  local targetKey = (roomY + dy) .. "," .. (roomX + dx)
  local targetRoom = roomMap[targetKey]
  if targetRoom and targetRoom.type == "boss" and not hasKey and not boss.defeated then
    return false  -- Door locked
  end

  transition.active = true
  transition.timer = ROOM_TRANSITION_SPEED
  transition.dirX = dx
  transition.dirY = dy
  transition.fromX = roomX
  transition.fromY = roomY
  return true
end

-- ==================== COLLISION HELPERS ====================

local function pointInRect(px, py, rx, ry, rw, rh)
  return px >= rx and px <= rx + rw and py >= ry and py <= ry + rh
end

local function resolveWallCollision(x, y, radius, walls)
  local hit = false
  for _, w in ipairs(walls) do
    local closestX = math.max(w.x, math.min(x, w.x + w.w))
    local closestY = math.max(w.y, math.min(y, w.y + w.h))
    local dx = x - closestX
    local dy = y - closestY
    local dist = math.sqrt(dx * dx + dy * dy)
    if dist < radius and dist > 0 then
      local push = radius - dist
      x = x + (dx / dist) * push
      y = y + (dy / dist) * push
      hit = true
    elseif dist == 0 then
      -- Inside wall — push out
      x = x + radius
      hit = true
    end
  end
  return x, y, hit
end

-- ==================== BOSS LOGIC ====================

local function updateBossPhase1(dt, shipX, shipY)
  -- Phase 1: "Pulsar Guardian" — dashes and shoots spreads
  boss.moveTimer = boss.moveTimer + dt
  boss.attackTimer = boss.attackTimer - dt

  -- Slow orbit movement
  boss.angle = boss.angle + dt * 0.8
  local orbitRadius = 120
  local targetX = screenW/2 + math.cos(boss.angle) * orbitRadius
  local targetY = screenH * 0.35 + math.sin(boss.angle * 0.7) * 60
  boss.x = boss.x + (targetX - boss.x) * dt * 2
  boss.y = boss.y + (targetY - boss.y) * dt * 2

  -- Periodic charge attack
  boss.chargeTimer = boss.chargeTimer + dt
  if boss.chargeTimer > 4 and not boss.charging then
    boss.charging = true
    boss.chargeTimer = 0
    boss.chargeTargetX = shipX
    boss.chargeTargetY = shipY
  end

  if boss.charging then
    local dx = boss.chargeTargetX - boss.x
    local dy = boss.chargeTargetY - boss.y
    local dist = math.sqrt(dx*dx + dy*dy)
    if dist > 5 then
      boss.x = boss.x + (dx/dist) * 350 * dt
      boss.y = boss.y + (dy/dist) * 350 * dt
    else
      boss.charging = false
      boss.chargeTimer = 0
    end
  end

  -- Shoot spread
  if boss.attackTimer <= 0 then
    boss.attackTimer = 1.5
    local angleToShip = math.atan2(shipY - boss.y, shipX - boss.x)
    for i = -2, 2 do
      local a = angleToShip + i * 0.25
      table.insert(enemyBullets, {
        x = boss.x, y = boss.y,
        vx = math.cos(a) * ENEMY_BULLET_SPEED,
        vy = math.sin(a) * ENEMY_BULLET_SPEED,
        lifetime = 3,
        size = 5,
        damage = 8,
        color = {0.8, 0.4, 1.0},
      })
    end
  end
end

local function updateBossPhase2(dt, shipX, shipY)
  -- Phase 2: "Nebula Weaver" — teleport + minion spawns + aimed shots
  boss.moveTimer = boss.moveTimer + dt
  boss.attackTimer = boss.attackTimer - dt
  boss.spawnTimer = boss.spawnTimer - dt

  -- Teleport periodically
  if boss.moveTimer > 3 then
    boss.moveTimer = 0
    boss.x = 200 + math.random() * (screenW - 400)
    boss.y = 100 + math.random() * (screenH * 0.4)
    boss.flashTimer = 0.3
  end

  -- Rapid aimed shots
  if boss.attackTimer <= 0 then
    boss.attackTimer = 0.8
    local angleToShip = math.atan2(shipY - boss.y, shipX - boss.x)
    table.insert(enemyBullets, {
      x = boss.x, y = boss.y,
      vx = math.cos(angleToShip) * ENEMY_BULLET_SPEED * 1.3,
      vy = math.sin(angleToShip) * ENEMY_BULLET_SPEED * 1.3,
      lifetime = 3,
      size = 6,
      damage = 10,
      color = {1.0, 0.3, 0.5},
    })
    -- Also fire ring burst every 3rd shot
    if math.floor(time * 10) % 3 == 0 then
      for i = 0, 7 do
        local a = (i / 8) * math.pi * 2
        table.insert(enemyBullets, {
          x = boss.x, y = boss.y,
          vx = math.cos(a) * ENEMY_BULLET_SPEED * 0.8,
          vy = math.sin(a) * ENEMY_BULLET_SPEED * 0.8,
          lifetime = 2.5,
          size = 4,
          damage = 6,
          color = {1.0, 0.5, 0.8},
        })
      end
    end
  end

  -- Spawn minions
  if boss.spawnTimer <= 0 then
    boss.spawnTimer = 6
    for i = 1, 2 do
      table.insert(enemies, {
        x = boss.x + (i == 1 and -60 or 60),
        y = boss.y + 30,
        vx = 0, vy = 0,
        health = 2, maxHealth = 2,
        type = "walker",
        size = 10,
        angle = math.random() * math.pi * 2,
        moveTimer = 0,
        shootTimer = 2,
        flashTimer = 0,
        dead = false,
        charging = false, chargeTimer = 0,
        chargeVX = 0, chargeVY = 0, chargeCooldown = 0,
        isMinion = true,
      })
    end
  end

  -- Gentle sway
  boss.angle = boss.angle + dt * 1.2
  boss.y = boss.y + math.sin(boss.angle) * 15 * dt
end

local function updateBossPhase3(dt, shipX, shipY)
  -- Phase 3: "Vela's Wrath" — orbiting fire orbs + rapid charges + desperation
  boss.moveTimer = boss.moveTimer + dt
  boss.attackTimer = boss.attackTimer - dt
  boss.orbAngle = boss.orbAngle + dt * 2.5

  -- Enrage at 30% HP
  if boss.health < boss.maxHealth * 0.3 and not boss.enraged then
    boss.enraged = true
  end
  local speedMult = boss.enraged and 1.6 or 1.0

  -- Aggressive pursuit
  local dx = shipX - boss.x
  local dy = shipY - boss.y
  local dist = math.sqrt(dx*dx + dy*dy)
  if dist > 80 then
    boss.x = boss.x + (dx/dist) * 100 * speedMult * dt
    boss.y = boss.y + (dy/dist) * 100 * speedMult * dt
  end

  -- Orbiting fire orbs (4 orbs)
  boss.orbs = {}
  local orbCount = boss.enraged and 6 or 4
  for i = 1, orbCount do
    local a = boss.orbAngle + (i / orbCount) * math.pi * 2
    local orbRadius = 80 + math.sin(time * 2 + i) * 20
    table.insert(boss.orbs, {
      x = boss.x + math.cos(a) * orbRadius,
      y = boss.y + math.sin(a) * orbRadius,
      size = 8,
    })
  end

  -- Triple aimed burst
  if boss.attackTimer <= 0 then
    boss.attackTimer = boss.enraged and 0.6 or 1.0
    local angleToShip = math.atan2(shipY - boss.y, shipX - boss.x)
    for i = -1, 1 do
      local a = angleToShip + i * 0.15
      table.insert(enemyBullets, {
        x = boss.x, y = boss.y,
        vx = math.cos(a) * ENEMY_BULLET_SPEED * 1.5,
        vy = math.sin(a) * ENEMY_BULLET_SPEED * 1.5,
        lifetime = 3,
        size = 7,
        damage = 12,
        color = {1.0, 0.2, 0.1},
      })
    end
  end

  -- Charge attack every 5s
  boss.chargeTimer = boss.chargeTimer + dt
  if boss.chargeTimer > (boss.enraged and 3 or 5) and not boss.charging then
    boss.charging = true
    boss.chargeTimer = 0
    boss.chargeTargetX = shipX
    boss.chargeTargetY = shipY
  end
  if boss.charging then
    local cdx = boss.chargeTargetX - boss.x
    local cdy = boss.chargeTargetY - boss.y
    local cdist = math.sqrt(cdx*cdx + cdy*cdy)
    if cdist > 5 then
      boss.x = boss.x + (cdx/cdist) * 500 * speedMult * dt
      boss.y = boss.y + (cdy/cdist) * 500 * speedMult * dt
    else
      boss.charging = false
    end
  end
end

local function advanceBossPhase()
  boss.phaseTransition = true
  boss.phaseTransitionTimer = 2.0
  boss.flashTimer = 2.0

  if boss.phase == 1 then
    boss.phase = 2
    boss.health = BOSS_PHASE_2_HP
    boss.maxHealth = BOSS_PHASE_2_HP
  elseif boss.phase == 2 then
    boss.phase = 3
    boss.health = BOSS_PHASE_3_HP
    boss.maxHealth = BOSS_PHASE_3_HP
  elseif boss.phase == 3 then
    -- Boss defeated!
    boss.defeated = true
    boss.active = false
    -- Drop the Firebird reward
    reward.active = true
    reward.x = boss.x
    reward.y = boss.y
    reward.collected = false
    reward.glow = 0
    -- Clear remaining bullets and minions
    enemyBullets = {}
    enemies = {}
  end
  boss.charging = false
  boss.chargeTimer = 0
  boss.attackTimer = 2
  boss.moveTimer = 0
  boss.spawnTimer = 5
  boss.orbs = {}
  boss.orbAngle = 0
  boss.enraged = false
end

-- ==================== UPDATE ====================

function M.update(dt, shipX, shipY, shipRadius)
  if not active then return end
  time = time + dt

  -- Room transition
  if transition.active then
    transition.timer = transition.timer - dt
    if transition.timer <= 0 then
      transition.active = false
      enterRoom(transition.fromX + transition.dirX, transition.fromY + transition.dirY)
    end
    return  -- Freeze gameplay during transition
  end

  -- Update room walls
  local walls = getRoomWalls(roomX, roomY)

  -- Ship wall collision (handled externally but we expose walls)
  -- Ship edge detection for room transitions
  if shipX < WALL_THICKNESS + 5 then
    startTransition(-1, 0)
  elseif shipX > screenW - WALL_THICKNESS - 5 then
    startTransition(1, 0)
  elseif shipY < WALL_THICKNESS + 5 then
    startTransition(0, -1)
  elseif shipY > screenH - WALL_THICKNESS - 5 then
    startTransition(0, 1)
  end

  -- Key room: check if player picks up key
  local key = roomY .. "," .. roomX
  local room = roomMap[key]
  if room and room.type == "key" and not hasKey and not clearedRooms[key] then
    local kx, ky = screenW/2, screenH/2
    local kDist = math.sqrt((shipX - kx)^2 + (shipY - ky)^2)
    if kDist < 40 then
      hasKey = true
      clearedRooms[key] = true
    end
  end

  -- Treasure room: bonus health
  if room and room.type == "treasure" and not clearedRooms[key] then
    local tx, ty = screenW/2, screenH/2
    local tDist = math.sqrt((shipX - tx)^2 + (shipY - ty)^2)
    if tDist < 40 then
      clearedRooms[key] = true
      -- Heal is handled by returning the event to init.lua
    end
  end

  -- Reward pickup
  if reward.active and not reward.collected then
    reward.glow = reward.glow + dt
    local rDist = math.sqrt((shipX - reward.x)^2 + (shipY - reward.y)^2)
    if rDist < 40 then
      reward.collected = true
      reward.active = false
    end
  end

  -- Update enemy bullets
  for i = #enemyBullets, 1, -1 do
    local b = enemyBullets[i]
    b.x = b.x + b.vx * dt
    b.y = b.y + b.vy * dt
    b.lifetime = b.lifetime - dt
    if b.lifetime <= 0 or b.x < -20 or b.x > screenW + 20 or b.y < -20 or b.y > screenH + 20 then
      table.remove(enemyBullets, i)
    end
  end

  -- Update enemies
  for i = #enemies, 1, -1 do
    local e = enemies[i]
    if e.dead then
      table.remove(enemies, i)
    else
      e.flashTimer = math.max(0, e.flashTimer - dt)
      e.moveTimer = e.moveTimer + dt

      if e.type == "walker" then
        -- Random walk toward player
        if e.moveTimer > 2 then
          e.moveTimer = 0
          e.angle = math.atan2(shipY - e.y, shipX - e.x) + (math.random() - 0.5) * 1.5
        end
        e.x = e.x + math.cos(e.angle) * 60 * dt
        e.y = e.y + math.sin(e.angle) * 60 * dt

      elseif e.type == "shooter" then
        -- Slow drift, periodic shots
        e.x = e.x + math.cos(e.angle) * 30 * dt
        e.y = e.y + math.sin(e.angle) * 30 * dt
        if e.moveTimer > 3 then
          e.moveTimer = 0
          e.angle = e.angle + math.pi + (math.random() - 0.5)
        end
        e.shootTimer = e.shootTimer - dt
        if e.shootTimer <= 0 then
          e.shootTimer = 2 + math.random()
          local a = math.atan2(shipY - e.y, shipX - e.x)
          table.insert(enemyBullets, {
            x = e.x, y = e.y,
            vx = math.cos(a) * ENEMY_BULLET_SPEED * 0.8,
            vy = math.sin(a) * ENEMY_BULLET_SPEED * 0.8,
            lifetime = 2.5, size = 4, damage = 5,
            color = {0.6, 0.3, 0.9},
          })
        end

      elseif e.type == "charger" then
        e.chargeCooldown = math.max(0, e.chargeCooldown - dt)
        if not e.charging then
          -- Idle patrol
          e.x = e.x + math.cos(e.angle) * 40 * dt
          e.y = e.y + math.sin(e.angle) * 40 * dt
          if e.moveTimer > 2.5 then
            e.moveTimer = 0
            e.angle = math.atan2(shipY - e.y, shipX - e.x)
          end
          -- Start charge
          local dist = math.sqrt((shipX - e.x)^2 + (shipY - e.y)^2)
          if dist < 250 and e.chargeCooldown <= 0 then
            e.charging = true
            e.chargeTimer = 0.6
            local a = math.atan2(shipY - e.y, shipX - e.x)
            e.chargeVX = math.cos(a) * 400
            e.chargeVY = math.sin(a) * 400
          end
        else
          e.x = e.x + e.chargeVX * dt
          e.y = e.y + e.chargeVY * dt
          e.chargeTimer = e.chargeTimer - dt
          if e.chargeTimer <= 0 then
            e.charging = false
            e.chargeCooldown = 3
          end
        end
      end

      -- Keep enemies in bounds
      e.x = math.max(WALL_THICKNESS + e.size, math.min(screenW - WALL_THICKNESS - e.size, e.x))
      e.y = math.max(WALL_THICKNESS + e.size, math.min(screenH - WALL_THICKNESS - e.size, e.y))

      -- Firebird burn DoT tick
      if e.burnTimer and e.burnTimer > 0 then
        e.burnTimer = e.burnTimer - dt
        e.burnTickTimer = (e.burnTickTimer or 0) + dt
        if e.burnTickTimer >= 1.0 then
          e.burnTickTimer = e.burnTickTimer - 1.0
          e.health = e.health - (e.burnDamage or 1)
          e.flashTimer = 0.1
          if e.health <= 0 then
            e.dead = true
          end
        end
        if e.burnTimer <= 0 then
          e.burnTimer = nil
          e.burnDamage = nil
          e.burnTickTimer = nil
        end
      end
    end
  end

  -- Check if room is cleared
  if room and room.type == "normal" and #enemies == 0 and not clearedRooms[key] then
    clearedRooms[key] = true
  end

  -- Boss update
  if boss.active and not boss.defeated then
    boss.flashTimer = math.max(0, boss.flashTimer - dt)

    if boss.phaseTransition then
      boss.phaseTransitionTimer = boss.phaseTransitionTimer - dt
      if boss.phaseTransitionTimer <= 0 then
        boss.phaseTransition = false
      end
      return
    end

    if boss.phase == 1 then
      updateBossPhase1(dt, shipX, shipY)
    elseif boss.phase == 2 then
      updateBossPhase2(dt, shipX, shipY)
    elseif boss.phase == 3 then
      updateBossPhase3(dt, shipX, shipY)
    end

    -- Keep boss in bounds
    boss.x = math.max(40, math.min(screenW - 40, boss.x))
    boss.y = math.max(40, math.min(screenH - 40, boss.y))

    -- Firebird burn DoT tick on boss
    if boss.burnTimer and boss.burnTimer > 0 then
      boss.burnTimer = boss.burnTimer - dt
      boss.burnTickTimer = (boss.burnTickTimer or 0) + dt
      if boss.burnTickTimer >= 1.0 then
        boss.burnTickTimer = boss.burnTickTimer - 1.0
        boss.health = boss.health - (boss.burnDamage or 1)
        boss.flashTimer = 0.1
        if boss.health <= 0 then
          advanceBossPhase()
        end
      end
      if boss.burnTimer <= 0 then
        boss.burnTimer = nil
        boss.burnDamage = nil
        boss.burnTickTimer = nil
      end
    end
  end
end

-- ==================== DAMAGE ====================

--- Player bullets hitting dungeon enemies. Returns list of destroyed positions.
function M.checkBulletCollisions(bullets)
  local destroyed = {}
  if not active then return destroyed end

  for bi = #bullets, 1, -1 do
    local b = bullets[bi]
    if b.owner == "player" then
      -- Check vs enemies
      for _, e in ipairs(enemies) do
        if not e.dead then
          local dist = math.sqrt((b.x - e.x)^2 + (b.y - e.y)^2)
          if dist < e.size + (b.size or 2) then
            e.health = e.health - 1
            e.flashTimer = 0.15
            -- Apply Firebird burn DoT on hit
            if b.burnDamage and b.burnDuration then
              e.burnDamage = b.burnDamage
              e.burnTimer = b.burnDuration
            end
            if e.health <= 0 then
              e.dead = true
              table.insert(destroyed, {x = e.x, y = e.y})
            end
            table.remove(bullets, bi)
            break
          end
        end
      end

      -- Check vs boss
      if boss.active and not boss.defeated and not boss.phaseTransition then
        local dist = math.sqrt((b.x - boss.x)^2 + (b.y - boss.y)^2)
        if dist < 35 then
          boss.health = boss.health - 1
          boss.flashTimer = 0.1
          -- Apply Firebird burn DoT to boss
          if b.burnDamage and b.burnDuration then
            boss.burnDamage = b.burnDamage
            boss.burnTimer = b.burnDuration
          end
          if boss.health <= 0 then
            advanceBossPhase()
            table.insert(destroyed, {x = boss.x, y = boss.y, isBoss = true})
          end
          -- Remove bullet if it still exists at this index
          if bi <= #bullets and bullets[bi] == b then
            table.remove(bullets, bi)
          end
        end
      end
    end
  end

  return destroyed
end

--- Get enemy bullets that hit the player. Returns list of {damage, index}
function M.getPlayerHits(shipX, shipY, shipRadius)
  local hits = {}
  if not active then return hits end

  for i = #enemyBullets, 1, -1 do
    local b = enemyBullets[i]
    local dist = math.sqrt((b.x - shipX)^2 + (b.y - shipY)^2)
    if dist < shipRadius + b.size then
      table.insert(hits, {damage = b.damage, x = b.x, y = b.y})
      table.remove(enemyBullets, i)
    end
  end

  -- Boss body collision
  if boss.active and not boss.defeated then
    local dist = math.sqrt((shipX - boss.x)^2 + (shipY - boss.y)^2)
    if dist < shipRadius + 30 then
      table.insert(hits, {damage = 15, x = boss.x, y = boss.y, isBodySlam = true})
    end

    -- Orb collision (phase 3)
    for _, orb in ipairs(boss.orbs) do
      local oDist = math.sqrt((shipX - orb.x)^2 + (shipY - orb.y)^2)
      if oDist < shipRadius + orb.size then
        table.insert(hits, {damage = 8, x = orb.x, y = orb.y})
      end
    end
  end

  return hits
end

--- Get room walls for external collision resolution
function M.getWalls()
  if not active then return {} end
  return getRoomWalls(roomX, roomY)
end

function M.resolveShipWallCollision(shipX, shipY, shipRadius)
  if not active then return shipX, shipY, false end
  local walls = getRoomWalls(roomX, roomY)
  return resolveWallCollision(shipX, shipY, shipRadius, walls)
end

--- Is current room the treasure room and uncollected?
function M.hasTreasure()
  local key = roomY .. "," .. roomX
  local room = roomMap[key]
  return room and room.type == "treasure" and not clearedRooms[key]
end

--- Is current room the key room and uncollected?
function M.hasKeyItem()
  local key = roomY .. "," .. roomX
  local room = roomMap[key]
  return room and room.type == "key" and not hasKey and not clearedRooms[key]
end

-- ==================== DRAWING ====================

function M.draw()
  if not active then return end

  local t = love.timer.getTime()

  -- Room transition slide effect
  if transition.active then
    local progress = 1 - (transition.timer / ROOM_TRANSITION_SPEED)
    love.graphics.push()
    love.graphics.translate(
      -transition.dirX * screenW * progress,
      -transition.dirY * screenH * progress
    )
    M.drawRoom(roomX, roomY, t)
    love.graphics.pop()

    -- Draw incoming room
    love.graphics.push()
    love.graphics.translate(
      transition.dirX * screenW * (1 - progress),
      transition.dirY * screenH * (1 - progress)
    )
    M.drawRoom(roomX + transition.dirX, roomY + transition.dirY, t)
    love.graphics.pop()
    return
  end

  M.drawRoom(roomX, roomY, t)
end

function M.drawRoom(rx, ry, t)
  local key = ry .. "," .. rx
  local room = roomMap[key]
  if not room then return end

  -- Background — dark Vela purple
  love.graphics.setColor(0.03, 0.02, 0.06)
  love.graphics.rectangle("fill", 0, 0, screenW, screenH)

  -- Subtle grid pattern (dungeon floor tiles)
  love.graphics.setColor(0.06, 0.04, 0.1, 0.4)
  local gridSize = 48
  for gx = 0, screenW, gridSize do
    love.graphics.line(gx, 0, gx, screenH)
  end
  for gy = 0, screenH, gridSize do
    love.graphics.line(0, gy, screenW, gy)
  end

  -- Subtle pulsar energy lines on floor
  local pulsePhase = math.sin(t * 1.5) * 0.5 + 0.5
  love.graphics.setColor(0.5, 0.3, 0.8, 0.05 + pulsePhase * 0.03)
  for i = 0, 5 do
    local ly = screenH * (i / 5) + math.sin(t + i) * 10
    love.graphics.line(0, ly, screenW, ly)
  end

  -- Walls
  local walls = getRoomWalls(rx, ry)
  for _, w in ipairs(walls) do
    if w.isPillar then
      -- Pillar obstacle
      love.graphics.setColor(0.2, 0.15, 0.3, 0.9)
      love.graphics.rectangle("fill", w.x, w.y, w.w, w.h, 4, 4)
      love.graphics.setColor(0.5, 0.3, 0.8, 0.6)
      love.graphics.rectangle("line", w.x, w.y, w.w, w.h, 4, 4)
    else
      -- Regular walls
      love.graphics.setColor(0.15, 0.1, 0.25, 0.95)
      love.graphics.rectangle("fill", w.x, w.y, w.w, w.h)
      -- Wall highlight
      love.graphics.setColor(0.4, 0.25, 0.6, 0.5)
      love.graphics.setLineWidth(2)
      love.graphics.rectangle("line", w.x, w.y, w.w, w.h)
      love.graphics.setLineWidth(1)
    end
  end

  -- Door indicators
  if room.doors.up then
    love.graphics.setColor(0.5, 0.3, 0.8, 0.3 + math.sin(t * 3) * 0.15)
    love.graphics.rectangle("fill", screenW/2 - DOOR_WIDTH/2, 0, DOOR_WIDTH, WALL_THICKNESS)
  end
  if room.doors.down then
    love.graphics.setColor(0.5, 0.3, 0.8, 0.3 + math.sin(t * 3) * 0.15)
    love.graphics.rectangle("fill", screenW/2 - DOOR_WIDTH/2, screenH - WALL_THICKNESS, DOOR_WIDTH, WALL_THICKNESS)
  end
  if room.doors.left then
    love.graphics.setColor(0.5, 0.3, 0.8, 0.3 + math.sin(t * 3) * 0.15)
    love.graphics.rectangle("fill", 0, screenH/2 - DOOR_WIDTH/2, WALL_THICKNESS, DOOR_WIDTH)
  end
  if room.doors.right then
    local doorColor = {0.5, 0.3, 0.8}
    local targetKey = ry .. "," .. (rx + 1)
    local targetRoom = roomMap[targetKey]
    if targetRoom and targetRoom.type == "boss" and not hasKey and not boss.defeated then
      doorColor = {0.8, 0.2, 0.2}  -- Locked = red
    end
    love.graphics.setColor(doorColor[1], doorColor[2], doorColor[3], 0.3 + math.sin(t * 3) * 0.15)
    love.graphics.rectangle("fill", screenW - WALL_THICKNESS, screenH/2 - DOOR_WIDTH/2, WALL_THICKNESS, DOOR_WIDTH)
  end

  -- Key item
  if room.type == "key" and not hasKey and not clearedRooms[key] then
    local kx, ky = screenW/2, screenH/2
    local kGlow = math.sin(t * 4) * 0.3 + 0.7
    -- Key glow
    love.graphics.setColor(1, 0.85, 0.2, 0.15 * kGlow)
    love.graphics.circle("fill", kx, ky, 30)
    -- Key shape (simple)
    love.graphics.setColor(1, 0.85, 0.2, kGlow)
    love.graphics.circle("fill", kx, ky - 5, 8)
    love.graphics.rectangle("fill", kx - 2, ky + 3, 4, 15)
    love.graphics.rectangle("fill", kx, ky + 12, 6, 3)
    love.graphics.rectangle("fill", kx, ky + 7, 4, 3)
    -- Label
    love.graphics.setColor(1, 0.9, 0.4, kGlow)
    love.graphics.printf("BOSS KEY", 0, ky + 25, screenW, "center")
  end

  -- Treasure
  if room.type == "treasure" and not clearedRooms[key] then
    local tx, ty = screenW/2, screenH/2
    local tGlow = math.sin(t * 3) * 0.3 + 0.7
    love.graphics.setColor(0.2, 0.8, 0.3, 0.15 * tGlow)
    love.graphics.circle("fill", tx, ty, 25)
    love.graphics.setColor(0.2, 0.9, 0.3, tGlow)
    love.graphics.printf("+", tx - 6, ty - 10, 12, "center")
    love.graphics.printf("REPAIR", 0, ty + 18, screenW, "center")
  end

  -- Enemies
  for _, e in ipairs(enemies) do
    if not e.dead then
      local flash = e.flashTimer > 0 and 1 or 0

      if e.type == "walker" then
        love.graphics.setColor(0.3 + flash * 0.7, 0.6, 0.9)
        love.graphics.circle("fill", e.x, e.y, e.size)
        love.graphics.setColor(0.5, 0.8, 1.0, 0.5)
        love.graphics.circle("line", e.x, e.y, e.size)
      elseif e.type == "shooter" then
        love.graphics.setColor(0.6 + flash * 0.4, 0.3, 0.9)
        -- Diamond shape
        love.graphics.polygon("fill",
          e.x, e.y - e.size,
          e.x + e.size, e.y,
          e.x, e.y + e.size,
          e.x - e.size, e.y)
        love.graphics.setColor(0.8, 0.5, 1.0, 0.6)
        love.graphics.polygon("line",
          e.x, e.y - e.size,
          e.x + e.size, e.y,
          e.x, e.y + e.size,
          e.x - e.size, e.y)
      elseif e.type == "charger" then
        love.graphics.setColor(0.9 + flash * 0.1, 0.4, 0.2)
        -- Triangle pointing toward move direction
        local a = e.angle
        love.graphics.polygon("fill",
          e.x + math.cos(a) * e.size, e.y + math.sin(a) * e.size,
          e.x + math.cos(a + 2.4) * e.size * 0.7, e.y + math.sin(a + 2.4) * e.size * 0.7,
          e.x + math.cos(a - 2.4) * e.size * 0.7, e.y + math.sin(a - 2.4) * e.size * 0.7)
        if e.charging then
          love.graphics.setColor(1, 0.6, 0.1, 0.5)
          love.graphics.circle("fill", e.x, e.y, e.size + 5)
        end
      end

      -- Health bar for damaged enemies
      if e.health < e.maxHealth then
        local barW = e.size * 2
        love.graphics.setColor(0.3, 0.3, 0.3, 0.8)
        love.graphics.rectangle("fill", e.x - barW/2, e.y - e.size - 8, barW, 4)
        love.graphics.setColor(0.2, 0.8, 0.3)
        love.graphics.rectangle("fill", e.x - barW/2, e.y - e.size - 8,
          barW * (e.health / e.maxHealth), 4)
      end

      -- Firebird burn aura on burning enemies
      if e.burnTimer and e.burnTimer > 0 then
        local bFlicker = 0.5 + 0.5 * math.sin(t * 10 + e.x)
        love.graphics.setColor(1, 0.4, 0.05, 0.25 * bFlicker)
        love.graphics.circle("fill", e.x, e.y, e.size + 8)
        love.graphics.setColor(1, 0.6, 0.1, 0.15 * bFlicker)
        love.graphics.circle("fill", e.x, e.y, e.size + 14)
      end
    end
  end

  -- Enemy bullets
  for _, b in ipairs(enemyBullets) do
    love.graphics.setColor(b.color[1], b.color[2], b.color[3])
    love.graphics.circle("fill", b.x, b.y, b.size)
    love.graphics.setColor(b.color[1], b.color[2], b.color[3], 0.3)
    love.graphics.circle("fill", b.x, b.y, b.size * 2)
  end

  -- Boss
  if boss.active and not boss.defeated then
    M.drawBoss(t)
  end

  -- Reward drop
  if reward.active and not reward.collected then
    M.drawReward(t)
  end

  -- Minimap
  M.drawMinimap()

  -- Room label
  love.graphics.setColor(0.6, 0.5, 0.8, 0.5)
  love.graphics.printf("VELA SANCTUM  " .. rx .. "-" .. ry, 0, screenH - 25, screenW, "center")

  -- Key indicator
  if hasKey then
    love.graphics.setColor(1, 0.85, 0.2, 0.8)
    love.graphics.printf("🔑 BOSS KEY", screenW - 160, 25, 140, "right")
  end
end

function M.drawBoss(t)
  local flash = boss.flashTimer > 0 and 1 or 0
  local phaseColors = {
    {0.6, 0.3, 0.9},   -- Phase 1: purple
    {0.9, 0.2, 0.5},   -- Phase 2: magenta
    {1.0, 0.15, 0.1},  -- Phase 3: crimson
  }
  local pc = phaseColors[boss.phase] or phaseColors[1]

  -- Phase transition flash
  if boss.phaseTransition then
    local tFlash = math.sin(boss.phaseTransitionTimer * 15) * 0.5 + 0.5
    love.graphics.setColor(1, 1, 1, tFlash * 0.4)
    love.graphics.circle("fill", boss.x, boss.y, 80 + (2 - boss.phaseTransitionTimer) * 40)
    love.graphics.setColor(pc[1], pc[2], pc[3], tFlash * 0.7)
    love.graphics.circle("fill", boss.x, boss.y, 40)
    return
  end

  -- Boss body glow
  love.graphics.setColor(pc[1], pc[2], pc[3], 0.1)
  love.graphics.circle("fill", boss.x, boss.y, 55)
  love.graphics.setColor(pc[1], pc[2], pc[3], 0.06)
  love.graphics.circle("fill", boss.x, boss.y, 80)

  -- Boss body (star/eye shape depending on phase)
  if boss.phase == 1 then
    -- Armored orb with spikes
    love.graphics.setColor(pc[1] + flash * 0.4, pc[2] + flash * 0.4, pc[3] + flash * 0.4)
    love.graphics.circle("fill", boss.x, boss.y, 28)
    -- Spikes
    for i = 0, 5 do
      local a = (i / 6) * math.pi * 2 + t * 0.5
      local sx = boss.x + math.cos(a) * 35
      local sy = boss.y + math.sin(a) * 35
      love.graphics.polygon("fill",
        boss.x + math.cos(a) * 25, boss.y + math.sin(a) * 25,
        sx + math.cos(a + 0.3) * 8, sy + math.sin(a + 0.3) * 8,
        sx - math.cos(a - 0.3) * 8, sy - math.sin(a - 0.3) * 8)
    end
    -- Eye
    love.graphics.setColor(1, 0.8, 0.3)
    love.graphics.circle("fill", boss.x, boss.y, 8)
    love.graphics.setColor(0.1, 0, 0.2)
    love.graphics.circle("fill", boss.x, boss.y, 4)

  elseif boss.phase == 2 then
    -- Wraith form: shifting triangular body
    love.graphics.setColor(pc[1] + flash * 0.4, pc[2] + flash * 0.4, pc[3] + flash * 0.4, 0.9)
    local sway = math.sin(t * 2) * 10
    love.graphics.polygon("fill",
      boss.x + sway, boss.y - 35,
      boss.x - 30, boss.y + 25,
      boss.x + 30, boss.y + 25)
    -- Inner triangle
    love.graphics.setColor(pc[1] * 1.3, pc[2] * 1.3, pc[3] * 1.3, 0.7)
    love.graphics.polygon("fill",
      boss.x + sway * 0.5, boss.y - 18,
      boss.x - 15, boss.y + 12,
      boss.x + 15, boss.y + 12)
    -- Eyes (two)
    love.graphics.setColor(1, 0.3, 0.5)
    love.graphics.circle("fill", boss.x - 8 + sway * 0.3, boss.y + 2, 4)
    love.graphics.circle("fill", boss.x + 8 + sway * 0.3, boss.y + 2, 4)

  elseif boss.phase == 3 then
    -- True form: fiery demon with wings
    love.graphics.setColor(pc[1] + flash * 0.4, pc[2] + flash * 0.4, pc[3] + flash * 0.4)
    -- Core body
    love.graphics.circle("fill", boss.x, boss.y, 30)
    -- Wing shapes
    local wingFlap = math.sin(t * 4) * 15
    love.graphics.polygon("fill",
      boss.x - 20, boss.y,
      boss.x - 65, boss.y - 30 + wingFlap,
      boss.x - 50, boss.y + 10)
    love.graphics.polygon("fill",
      boss.x + 20, boss.y,
      boss.x + 65, boss.y - 30 - wingFlap,
      boss.x + 50, boss.y + 10)
    -- Inner fire
    local fireFlicker = math.sin(t * 8) * 0.3 + 0.7
    love.graphics.setColor(1, 0.5, 0.1, fireFlicker)
    love.graphics.circle("fill", boss.x, boss.y, 18)
    love.graphics.setColor(1, 0.9, 0.3, fireFlicker * 0.8)
    love.graphics.circle("fill", boss.x, boss.y, 10)
    -- Crown horns
    love.graphics.setColor(pc[1] * 0.8, pc[2] * 0.6, pc[3] * 0.6)
    love.graphics.polygon("fill",
      boss.x - 12, boss.y - 25,
      boss.x - 20, boss.y - 50,
      boss.x - 5, boss.y - 28)
    love.graphics.polygon("fill",
      boss.x + 12, boss.y - 25,
      boss.x + 20, boss.y - 50,
      boss.x + 5, boss.y - 28)
  end

  -- Orbiting fire orbs (phase 3)
  for _, orb in ipairs(boss.orbs) do
    love.graphics.setColor(1, 0.4, 0.1, 0.8)
    love.graphics.circle("fill", orb.x, orb.y, orb.size)
    love.graphics.setColor(1, 0.7, 0.2, 0.3)
    love.graphics.circle("fill", orb.x, orb.y, orb.size * 1.5)
  end

  -- Firebird burn aura on boss
  if boss.burnTimer and boss.burnTimer > 0 then
    local bFlicker = 0.5 + 0.5 * math.sin(t * 10)
    love.graphics.setColor(1, 0.4, 0.05, 0.2 * bFlicker)
    love.graphics.circle("fill", boss.x, boss.y, 50)
    love.graphics.setColor(1, 0.6, 0.1, 0.1 * bFlicker)
    love.graphics.circle("fill", boss.x, boss.y, 70)
  end

  -- Boss health bar (top of screen)
  local totalHP = 0
  if boss.phase == 1 then totalHP = boss.health
  elseif boss.phase == 2 then totalHP = BOSS_PHASE_1_HP + boss.health
  elseif boss.phase == 3 then totalHP = BOSS_PHASE_1_HP + BOSS_PHASE_2_HP + boss.health
  end

  local barW = 400
  local barH = 12
  local barX = screenW/2 - barW/2
  local barY = 18

  -- Phase names
  local phaseNames = {"PULSAR GUARDIAN", "NEBULA WEAVER", "VELA'S WRATH"}
  love.graphics.setColor(pc[1], pc[2], pc[3], 0.9)
  love.graphics.printf(phaseNames[boss.phase] or "???", 0, 3, screenW, "center")

  -- HP bar background
  love.graphics.setColor(0.1, 0.1, 0.15, 0.8)
  love.graphics.rectangle("fill", barX, barY, barW, barH, 3, 3)
  -- HP fill
  local hpPct = totalHP / BOSS_TOTAL_HP
  love.graphics.setColor(pc[1], pc[2], pc[3], 0.9)
  love.graphics.rectangle("fill", barX, barY, barW * hpPct, barH, 3, 3)
  -- Phase dividers
  love.graphics.setColor(0.2, 0.2, 0.3, 0.8)
  local p1pct = BOSS_PHASE_1_HP / BOSS_TOTAL_HP
  local p2pct = (BOSS_PHASE_1_HP + BOSS_PHASE_2_HP) / BOSS_TOTAL_HP
  love.graphics.line(barX + barW * p1pct, barY, barX + barW * p1pct, barY + barH)
  love.graphics.line(barX + barW * p2pct, barY, barX + barW * p2pct, barY + barH)
  -- Border
  love.graphics.setColor(pc[1], pc[2], pc[3], 0.5)
  love.graphics.rectangle("line", barX, barY, barW, barH, 3, 3)

  -- Enrage indicator
  if boss.enraged then
    love.graphics.setColor(1, 0.2, 0.1, math.sin(t * 6) * 0.4 + 0.6)
    love.graphics.printf("ENRAGED!", 0, barY + barH + 3, screenW, "center")
  end
end

function M.drawReward(t)
  local glow = math.sin(t * 3) * 0.3 + 0.7

  -- Large fire glow
  love.graphics.setColor(1, 0.3, 0.05, 0.1 * glow)
  love.graphics.circle("fill", reward.x, reward.y, 60)
  love.graphics.setColor(1, 0.5, 0.1, 0.15 * glow)
  love.graphics.circle("fill", reward.x, reward.y, 40)

  -- Firebird silhouette (small ship icon)
  love.graphics.setColor(0.9, 0.2, 0.1, glow)
  love.graphics.polygon("fill",
    reward.x, reward.y - 15,
    reward.x - 12, reward.y + 10,
    reward.x + 12, reward.y + 10)
  -- Fire accent
  love.graphics.setColor(1, 0.6, 0.1, glow * 0.8)
  love.graphics.polygon("fill",
    reward.x, reward.y - 10,
    reward.x - 6, reward.y + 5,
    reward.x + 6, reward.y + 5)

  -- Label
  love.graphics.setColor(1, 0.7, 0.3, glow)
  love.graphics.printf("FIREBIRD", 0, reward.y + 20, screenW, "center")
  love.graphics.setColor(0.8, 0.6, 0.4, glow * 0.7)
  love.graphics.printf("fly into it to claim", 0, reward.y + 38, screenW, "center")
end

function M.drawMinimap()
  local mapX = screenW - 110
  local mapY = 50
  local cellSize = 18
  local padding = 2

  -- Background
  love.graphics.setColor(0, 0, 0, 0.6)
  love.graphics.rectangle("fill", mapX - 5, mapY - 5,
    4 * cellSize + padding * 5 + 10, 4 * cellSize + padding * 5 + 10, 4, 4)

  for row = 1, 4 do
    for col = 1, 4 do
      local key = row .. "," .. col
      local cx = mapX + (col - 1) * (cellSize + padding)
      local cy = mapY + (row - 1) * (cellSize + padding)

      if discoveredRooms[key] then
        local room = roomMap[key]
        if col == roomX and row == roomY then
          -- Current room
          love.graphics.setColor(0.8, 0.6, 1.0)
          love.graphics.rectangle("fill", cx, cy, cellSize, cellSize, 2, 2)
        elseif room and room.type == "boss" then
          love.graphics.setColor(0.8, 0.15, 0.1, 0.8)
          love.graphics.rectangle("fill", cx, cy, cellSize, cellSize, 2, 2)
        elseif room and room.type == "key" then
          love.graphics.setColor(1, 0.85, 0.2, 0.7)
          love.graphics.rectangle("fill", cx, cy, cellSize, cellSize, 2, 2)
        elseif clearedRooms[key] then
          love.graphics.setColor(0.2, 0.4, 0.2, 0.7)
          love.graphics.rectangle("fill", cx, cy, cellSize, cellSize, 2, 2)
        else
          love.graphics.setColor(0.25, 0.2, 0.35, 0.7)
          love.graphics.rectangle("fill", cx, cy, cellSize, cellSize, 2, 2)
        end

        -- Draw door connections
        love.graphics.setColor(0.5, 0.3, 0.8, 0.5)
        if room then
          if room.doors.right and col < 4 then
            love.graphics.rectangle("fill", cx + cellSize, cy + cellSize/2 - 1, padding, 2)
          end
          if room.doors.down and row < 4 then
            love.graphics.rectangle("fill", cx + cellSize/2 - 1, cy + cellSize, 2, padding)
          end
        end
      else
        -- Undiscovered
        love.graphics.setColor(0.1, 0.1, 0.15, 0.5)
        love.graphics.rectangle("fill", cx, cy, cellSize, cellSize, 2, 2)
      end
    end
  end
end

return M
