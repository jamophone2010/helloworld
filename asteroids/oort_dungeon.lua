-- asteroids/oort_dungeon.lua
-- Zelda: Link's Awakening-style 4x4 dungeon in the Oort Cloud constellation.
-- The dungeon is entered via a portal tile inside Oort and consists of
-- 16 rooms arranged in a 4x4 grid.  Room (4,4) contains the Ice Cube boss
-- whose defeat drops the Ice Cube ship.
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

-- Boss constants — single phase, massive HP
local BOSS_TOTAL_HP = 600

-- Frost minion constants
local FROST_MINION_HP = 3
local FROST_MINION_SPEED = 100
local FROST_MINION_SHOOT_INTERVAL = 2.0
local FROST_MINION_BULLET_SPEED = 180
local FROST_MINION_BULLET_DAMAGE = 8
local FROST_MINION_SPAWN_INTERVAL = 8
local FROST_MINION_MAX = 4

-- Player freeze constants
local FREEZE_DURATION = 3.0       -- seconds player is frozen
local FREEZE_DPS_PCT = 0.05       -- 5% max HP per second
local FREEZE_COOLDOWN = 8.0       -- boss won't re-freeze within this window

-- Firebird melt constants
local MELT_RANGE_MAX = 300        -- max distance for proximity melt
local MELT_DPS_BASE = 5           -- DPS at point-blank
local BULLET_MELT_MULTIPLIER = 3  -- Firebird bullets do 3x melt damage
local MELT_STACK_MAX = 10         -- max melt stacks
local MELT_STACK_DPS = 2          -- extra DPS per stack

-- ==================== STATE ====================

local active = false
local roomX = 1    -- current room column (1-4)
local roomY = 1    -- current room row    (1-4)
local screenW = 1366
local screenH = 768
local time = 0

-- Room data cache
local roomCache = {}

-- Transition state
local transition = {
  active = false,
  timer = 0,
  dirX = 0,
  dirY = 0,
  fromX = 1,
  fromY = 1,
}

-- Enemy state for current room
local enemies = {}
local enemyBullets = {}

-- Boss state
local boss = {
  active = false,
  health = BOSS_TOTAL_HP,
  maxHealth = BOSS_TOTAL_HP,
  x = 0,
  y = 0,
  angle = 0,
  attackTimer = 0,
  moveTimer = 0,
  moveAngle = 0,
  flashTimer = 0,
  defeated = false,
  -- Freeze attack
  freezeTimer = 0,        -- countdown to next freeze attempt
  freezeChargeTimer = 0,  -- visible charging before freeze
  freezeCharging = false,
  -- Melt stacks (from Firebird)
  meltStacks = 0,
  meltDecayTimer = 0,
  -- Frost minion spawning
  minionSpawnTimer = FROST_MINION_SPAWN_INTERVAL,
  minions = {},
  -- Movement
  driftAngle = 0,
  bobPhase = 0,
  -- Visual
  crackLevel = 0,  -- increases as HP drops, visual cracks on the cube
}

-- Player freeze state (returned to init.lua for application)
local playerFrozen = false
local playerFreezeTimer = 0
local freezeCooldownTimer = 0

-- Reward state (Ice Cube ship drop)
local reward = {
  active = false,
  x = 0,
  y = 0,
  collected = false,
  glow = 0,
}

-- Room map
local roomMap = {}

-- Cleared rooms tracking
local clearedRooms = {}

-- Minimap discovered rooms
local discoveredRooms = {}

-- Key items
local hasKey = false

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
  -- Fixed layout for a Zelda-style icy dungeon with critical path

  -- Row 1 (top): entrance row
  roomMap["1,1"] = {doors = {up = false, down = true, left = false, right = true},
                    enemies = 3, type = "normal", enemyType = "iceslime"}
  roomMap["1,2"] = {doors = {up = false, down = false, left = true, right = true},
                    enemies = 4, type = "normal", enemyType = "frostshooter"}
  roomMap["1,3"] = {doors = {up = false, down = true, left = true, right = true},
                    enemies = 0, type = "treasure"}
  roomMap["1,4"] = {doors = {up = false, down = true, left = true, right = false},
                    enemies = 3, type = "normal", enemyType = "iceslime"}

  -- Row 2
  roomMap["2,1"] = {doors = {up = true, down = true, left = false, right = true},
                    enemies = 5, type = "normal", enemyType = "mixed"}
  roomMap["2,2"] = {doors = {up = false, down = true, left = true, right = false},
                    enemies = 0, type = "key"}
  roomMap["2,3"] = {doors = {up = true, down = true, left = false, right = true},
                    enemies = 4, type = "normal", enemyType = "frostshooter"}
  roomMap["2,4"] = {doors = {up = true, down = true, left = true, right = false},
                    enemies = 3, type = "normal", enemyType = "icecharger"}

  -- Row 3
  roomMap["3,1"] = {doors = {up = true, down = true, left = false, right = true},
                    enemies = 5, type = "normal", enemyType = "frostshooter"}
  roomMap["3,2"] = {doors = {up = true, down = false, left = true, right = true},
                    enemies = 6, type = "normal", enemyType = "mixed"}
  roomMap["3,3"] = {doors = {up = true, down = true, left = true, right = true},
                    enemies = 4, type = "normal", enemyType = "icecharger"}
  roomMap["3,4"] = {doors = {up = true, down = true, left = true, right = false},
                    enemies = 0, type = "treasure"}

  -- Row 4 (bottom): boss row
  roomMap["4,1"] = {doors = {up = true, down = false, left = false, right = true},
                    enemies = 6, type = "normal", enemyType = "mixed"}
  roomMap["4,2"] = {doors = {up = false, down = false, left = true, right = true},
                    enemies = 5, type = "normal", enemyType = "frostshooter"}
  roomMap["4,3"] = {doors = {up = true, down = false, left = true, right = true},
                    enemies = 5, type = "normal", enemyType = "mixed"}
  roomMap["4,4"] = {doors = {up = false, down = false, left = true, right = false},
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
  local etype = room.enemyType or "iceslime"

  seed(rx, ry, 77)

  for i = 1, count do
    local ex = 100 + rand() * (screenW - 200)
    local ey = 100 + rand() * (screenH - 200)
    local t = etype
    if etype == "mixed" then
      local r = rand()
      if r < 0.33 then t = "iceslime"
      elseif r < 0.66 then t = "frostshooter"
      else t = "icecharger" end
    end

    table.insert(result, {
      x = ex, y = ey,
      vx = 0, vy = 0,
      health = t == "icecharger" and 4 or (t == "frostshooter" and 2 or 3),
      maxHealth = t == "icecharger" and 4 or (t == "frostshooter" and 2 or 3),
      type = t,
      size = t == "icecharger" and 16 or 12,
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
      -- Freeze state (for Ice Cube ship effect)
      frozenTimer = 0,
      freezeHits = 0,
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

  -- Interior ice pillars for some rooms
  seed(rx, ry, 99)
  if room.type == "normal" and room.enemies >= 4 then
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

-- ==================== COLLISION HELPERS ====================

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
      x = x + radius
      hit = true
    end
  end
  return x, y, hit
end

-- ==================== FROST MINION HELPERS ====================

local function spawnFrostMinion()
  if not boss or boss.defeated then return end
  local side = math.random(1, 4)
  local mx, my
  if side == 1 then     mx = 60;            my = 60 + math.random() * (screenH - 120)
  elseif side == 2 then mx = screenW - 60;  my = 60 + math.random() * (screenH - 120)
  elseif side == 3 then mx = 60 + math.random() * (screenW - 120); my = 60
  else                  mx = 60 + math.random() * (screenW - 120); my = screenH - 60
  end
  table.insert(boss.minions, {
    x = mx, y = my,
    vx = 0, vy = 0,
    hp = FROST_MINION_HP,
    maxHp = FROST_MINION_HP,
    size = 10,
    angle = math.random() * math.pi * 2,
    shootTimer = 1 + math.random() * FROST_MINION_SHOOT_INTERVAL,
    flashTimer = 0,
    dead = false,
  })
end

-- ==================== PUBLIC API ====================

--- Check if current tile should be the Oort dungeon entrance
function M.isOortDungeonTile(tileX, tileY)
  -- The Oort dungeon entrance is at the center of the Oort Cloud constellation
  -- Oort is at constellation grid (0,1), center tile is (0,7)
  return tileX == 0 and tileY == 7
end

--- Enter the Oort dungeon
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
  playerFrozen = false
  playerFreezeTimer = 0
  freezeCooldownTimer = 0

  -- Generate dungeon layout
  generateRoomMap()

  -- Reset boss
  boss.active = false
  boss.defeated = false
  boss.health = BOSS_TOTAL_HP
  boss.maxHealth = BOSS_TOTAL_HP
  boss.flashTimer = 0
  boss.freezeTimer = 5
  boss.freezeCharging = false
  boss.freezeChargeTimer = 0
  boss.meltStacks = 0
  boss.meltDecayTimer = 0
  boss.minionSpawnTimer = FROST_MINION_SPAWN_INTERVAL
  boss.minions = {}
  boss.driftAngle = 0
  boss.bobPhase = 0
  boss.crackLevel = 0

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
  boss.minions = {}
  playerFrozen = false
  playerFreezeTimer = 0
end

function M.isBossDefeated()
  return boss.defeated
end

function M.isRewardCollected()
  return reward.collected
end

--- Returns whether the player is currently frozen (for init.lua to block movement)
function M.isPlayerFrozen()
  return playerFrozen
end

--- Returns freeze damage per second while frozen (5% max HP)
function M.getFreezeDPS(maxHealth)
  if not playerFrozen then return 0 end
  return maxHealth * FREEZE_DPS_PCT
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
    boss.y = screenH * 0.35
    boss.angle = 0
    boss.attackTimer = 3
    boss.moveTimer = 0
    boss.flashTimer = 0
    boss.health = BOSS_TOTAL_HP
    boss.maxHealth = BOSS_TOTAL_HP
    boss.freezeTimer = 5
    boss.freezeCharging = false
    boss.freezeChargeTimer = 0
    boss.meltStacks = 0
    boss.meltDecayTimer = 0
    boss.minionSpawnTimer = FROST_MINION_SPAWN_INTERVAL
    boss.minions = {}
    boss.driftAngle = 0
    boss.bobPhase = 0
    boss.crackLevel = 0
    playerFrozen = false
    playerFreezeTimer = 0
    freezeCooldownTimer = 0
    enemies = {}
  elseif room.type == "key" and not clearedRooms[key] then
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
    return false
  end

  transition.active = true
  transition.timer = ROOM_TRANSITION_SPEED
  transition.dirX = dx
  transition.dirY = dy
  transition.fromX = roomX
  transition.fromY = roomY
  return true
end

-- ==================== BOSS LOGIC ====================

local function updateBoss(dt, shipX, shipY, shipDef)
  if not boss.active or boss.defeated then return end

  boss.flashTimer = math.max(0, boss.flashTimer - dt)
  time = time + dt

  -- ---- Movement: slow menacing drift ----
  boss.driftAngle = boss.driftAngle + dt * 0.3
  boss.bobPhase = boss.bobPhase + dt * 1.5
  local targetX = screenW / 2 + math.cos(boss.driftAngle) * 150
  local targetY = screenH * 0.35 + math.sin(boss.driftAngle * 0.7) * 80
  boss.x = boss.x + (targetX - boss.x) * dt * 0.8
  boss.y = boss.y + (targetY - boss.y) * dt * 0.8

  -- ---- Crack level based on HP ----
  boss.crackLevel = 1.0 - (boss.health / boss.maxHealth)

  -- ---- Frost minion spawning ----
  boss.minionSpawnTimer = boss.minionSpawnTimer - dt
  if boss.minionSpawnTimer <= 0 and #boss.minions < FROST_MINION_MAX then
    spawnFrostMinion()
    -- Spawn faster as HP drops
    local spawnMult = 1.0 - boss.crackLevel * 0.5
    boss.minionSpawnTimer = FROST_MINION_SPAWN_INTERVAL * math.max(0.3, spawnMult)
  end

  -- ---- Update frost minions ----
  for i = #boss.minions, 1, -1 do
    local m = boss.minions[i]
    if m.dead then
      table.remove(boss.minions, i)
    else
      m.flashTimer = math.max(0, m.flashTimer - dt)

      -- Chase player
      local dx = shipX - m.x
      local dy = shipY - m.y
      local dist = math.sqrt(dx * dx + dy * dy)
      if dist > 30 then
        m.vx = (dx / dist) * FROST_MINION_SPEED
        m.vy = (dy / dist) * FROST_MINION_SPEED
      end
      m.x = m.x + m.vx * dt
      m.y = m.y + m.vy * dt
      m.angle = math.atan2(m.vy, m.vx)

      -- Keep in bounds
      m.x = math.max(30, math.min(screenW - 30, m.x))
      m.y = math.max(30, math.min(screenH - 30, m.y))

      -- Shoot at player
      m.shootTimer = m.shootTimer - dt
      if m.shootTimer <= 0 then
        m.shootTimer = FROST_MINION_SHOOT_INTERVAL + math.random() * 0.5
        local a = math.atan2(shipY - m.y, shipX - m.x)
        table.insert(enemyBullets, {
          x = m.x, y = m.y,
          vx = math.cos(a) * FROST_MINION_BULLET_SPEED,
          vy = math.sin(a) * FROST_MINION_BULLET_SPEED,
          lifetime = 3,
          size = 4,
          damage = FROST_MINION_BULLET_DAMAGE,
          color = {0.3, 0.7, 1.0},
        })
      end
    end
  end

  -- ---- Freeze attack ----
  freezeCooldownTimer = math.max(0, freezeCooldownTimer - dt)

  if not playerFrozen and freezeCooldownTimer <= 0 then
    if not boss.freezeCharging then
      boss.freezeTimer = boss.freezeTimer - dt
      if boss.freezeTimer <= 0 then
        boss.freezeCharging = true
        boss.freezeChargeTimer = 1.5  -- 1.5s visible charge-up
      end
    else
      boss.freezeChargeTimer = boss.freezeChargeTimer - dt
      if boss.freezeChargeTimer <= 0 then
        -- FREEZE the player!
        playerFrozen = true
        playerFreezeTimer = FREEZE_DURATION
        boss.freezeCharging = false
        boss.freezeTimer = FREEZE_COOLDOWN
        freezeCooldownTimer = FREEZE_COOLDOWN
      end
    end
  end

  -- ---- Update player freeze ----
  if playerFrozen then
    playerFreezeTimer = playerFreezeTimer - dt
    if playerFreezeTimer <= 0 then
      playerFrozen = false
      playerFreezeTimer = 0
    end
  end

  -- ---- Firebird proximity melt damage ----
  if shipDef and shipDef.meltsIce then
    local dx = shipX - boss.x
    local dy = shipY - boss.y
    local dist = math.sqrt(dx * dx + dy * dy)
    if dist < MELT_RANGE_MAX then
      local intensity = 1.0 - (dist / MELT_RANGE_MAX)
      local meltDmg = MELT_DPS_BASE * intensity * dt
      -- Add melt stack bonus
      meltDmg = meltDmg + (boss.meltStacks * MELT_STACK_DPS * dt)
      boss.health = boss.health - meltDmg
      if boss.health <= 0 then
        boss.health = 0
        boss.defeated = true
        boss.active = false
        reward.active = true
        reward.x = boss.x
        reward.y = boss.y
        reward.collected = false
        reward.glow = 0
        enemyBullets = {}
        boss.minions = {}
        enemies = {}
      end
    end
  end

  -- ---- Melt stack decay ----
  if boss.meltStacks > 0 then
    boss.meltDecayTimer = boss.meltDecayTimer - dt
    if boss.meltDecayTimer <= 0 then
      boss.meltStacks = math.max(0, boss.meltStacks - 1)
      boss.meltDecayTimer = 3.0
    end
  end

  -- ---- Boss attacks: ice shards ----
  boss.attackTimer = boss.attackTimer - dt
  if boss.attackTimer <= 0 then
    -- Radial ice shard burst + aimed shots
    local shardCount = 8 + math.floor(boss.crackLevel * 8) -- 8-16 shards
    for i = 0, shardCount - 1 do
      local a = (i / shardCount) * math.pi * 2 + time * 0.2
      table.insert(enemyBullets, {
        x = boss.x, y = boss.y,
        vx = math.cos(a) * 160,
        vy = math.sin(a) * 160,
        lifetime = 3,
        size = 5,
        damage = 10,
        color = {0.5, 0.85, 1.0},
      })
    end
    -- Aimed triple shot
    local aimA = math.atan2(shipY - boss.y, shipX - boss.x)
    for i = -1, 1 do
      local a = aimA + i * 0.2
      table.insert(enemyBullets, {
        x = boss.x, y = boss.y,
        vx = math.cos(a) * 220,
        vy = math.sin(a) * 220,
        lifetime = 3.5,
        size = 6,
        damage = 12,
        color = {0.3, 0.6, 1.0},
      })
    end
    -- Faster attacks as HP drops
    boss.attackTimer = 2.5 - boss.crackLevel * 1.2
  end
end

-- ==================== UPDATE ====================

function M.update(dt, shipX, shipY, shipRadius, shipDef)
  if not active then return end
  time = time + dt

  -- Room transition
  if transition.active then
    transition.timer = transition.timer - dt
    if transition.timer <= 0 then
      transition.active = false
      enterRoom(transition.fromX + transition.dirX, transition.fromY + transition.dirY)
    end
    return
  end

  -- Ship edge detection for room transitions (blocked while frozen)
  if not playerFrozen then
    if shipX < WALL_THICKNESS + 5 then
      startTransition(-1, 0)
    elseif shipX > screenW - WALL_THICKNESS - 5 then
      startTransition(1, 0)
    elseif shipY < WALL_THICKNESS + 5 then
      startTransition(0, -1)
    elseif shipY > screenH - WALL_THICKNESS - 5 then
      startTransition(0, 1)
    end
  end

  -- Key room pickup
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

  -- Update regular enemies
  for i = #enemies, 1, -1 do
    local e = enemies[i]
    if e.dead then
      table.remove(enemies, i)
    else
      e.flashTimer = math.max(0, e.flashTimer - dt)
      e.moveTimer = e.moveTimer + dt

      -- Frozen enemies don't move or act
      if e.frozenTimer and e.frozenTimer > 0 then
        e.frozenTimer = e.frozenTimer - dt
        goto continueEnemy
      end

      if e.type == "iceslime" then
        -- Slow slide toward player
        if e.moveTimer > 2 then
          e.moveTimer = 0
          e.angle = math.atan2(shipY - e.y, shipX - e.x) + (math.random() - 0.5) * 1.5
        end
        e.x = e.x + math.cos(e.angle) * 50 * dt
        e.y = e.y + math.sin(e.angle) * 50 * dt

      elseif e.type == "frostshooter" then
        e.x = e.x + math.cos(e.angle) * 25 * dt
        e.y = e.y + math.sin(e.angle) * 25 * dt
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
            vx = math.cos(a) * ENEMY_BULLET_SPEED * 0.7,
            vy = math.sin(a) * ENEMY_BULLET_SPEED * 0.7,
            lifetime = 2.5, size = 4, damage = 5,
            color = {0.4, 0.7, 1.0},
          })
        end

      elseif e.type == "icecharger" then
        e.chargeCooldown = math.max(0, e.chargeCooldown - dt)
        if not e.charging then
          e.x = e.x + math.cos(e.angle) * 35 * dt
          e.y = e.y + math.sin(e.angle) * 35 * dt
          if e.moveTimer > 2.5 then
            e.moveTimer = 0
            e.angle = math.atan2(shipY - e.y, shipX - e.x)
          end
          local dist = math.sqrt((shipX - e.x)^2 + (shipY - e.y)^2)
          if dist < 250 and e.chargeCooldown <= 0 then
            e.charging = true
            e.chargeTimer = 0.6
            local a = math.atan2(shipY - e.y, shipX - e.x)
            e.chargeVX = math.cos(a) * 380
            e.chargeVY = math.sin(a) * 380
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

      ::continueEnemy::
    end
  end

  -- Check if room is cleared
  if room and room.type == "normal" and #enemies == 0 and not clearedRooms[key] then
    clearedRooms[key] = true
  end

  -- Boss update
  updateBoss(dt, shipX, shipY, shipDef)
end

-- ==================== DAMAGE ====================

--- Player bullets hitting dungeon enemies. Returns list of destroyed positions.
--- Also handles melt stacking on boss from Firebird bullets.
function M.checkBulletCollisions(bullets)
  local destroyed = {}
  if not active then return destroyed end

  for bi = #bullets, 1, -1 do
    local b = bullets[bi]
    if b.owner == "player" then
      -- Check vs regular enemies
      for _, e in ipairs(enemies) do
        if not e.dead then
          local dist = math.sqrt((b.x - e.x)^2 + (b.y - e.y)^2)
          if dist < e.size + (b.size or 2) then
            e.health = e.health - 1
            e.flashTimer = 0.15

            -- Ice Cube ship freeze effect: 3 hits freezes enemy
            if b.freezeOnHit then
              e.freezeHits = (e.freezeHits or 0) + 1
              if e.freezeHits >= 3 then
                e.frozenTimer = 999  -- permanently frozen
                e.vx = 0
                e.vy = 0
                e.charging = false
              end
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
      if boss.active and not boss.defeated then
        local dist = math.sqrt((b.x - boss.x)^2 + (b.y - boss.y)^2)
        if dist < 50 then  -- Ice cube boss is big
          local dmg = 1
          -- Firebird melt: 3x damage + melt stack
          if b.meltsIce then
            dmg = dmg * BULLET_MELT_MULTIPLIER
            boss.meltStacks = math.min(MELT_STACK_MAX, boss.meltStacks + 1)
            boss.meltDecayTimer = 3.0
          end
          boss.health = boss.health - dmg
          boss.flashTimer = 0.1

          if boss.health <= 0 then
            boss.health = 0
            boss.defeated = true
            boss.active = false
            reward.active = true
            reward.x = boss.x
            reward.y = boss.y
            reward.collected = false
            reward.glow = 0
            enemyBullets = {}
            boss.minions = {}
            enemies = {}
            playerFrozen = false
            playerFreezeTimer = 0
            table.insert(destroyed, {x = boss.x, y = boss.y, isBoss = true})
          end

          if bi <= #bullets and bullets[bi] == b then
            table.remove(bullets, bi)
          end
        end
      end

      -- Check vs frost minions
      if boss.active and not boss.defeated then
        for _, m in ipairs(boss.minions) do
          if not m.dead then
            local dist = math.sqrt((b.x - m.x)^2 + (b.y - m.y)^2)
            if dist < m.size + (b.size or 2) then
              m.hp = m.hp - 1
              m.flashTimer = 0.12
              if m.hp <= 0 then
                m.dead = true
                table.insert(destroyed, {x = m.x, y = m.y})
              end
              if bi <= #bullets and bullets[bi] == b then
                table.remove(bullets, bi)
              end
              break
            end
          end
        end
      end
    end
  end

  return destroyed
end

--- Get enemy bullets that hit the player. Returns list of {damage, x, y}
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
    if dist < shipRadius + 45 then
      table.insert(hits, {damage = 15, x = boss.x, y = boss.y, isBodySlam = true})
    end
  end

  -- Frost minion body collision
  if boss.active then
    for _, m in ipairs(boss.minions) do
      if not m.dead then
        local dist = math.sqrt((shipX - m.x)^2 + (shipY - m.y)^2)
        if dist < shipRadius + m.size then
          table.insert(hits, {damage = 6, x = m.x, y = m.y})
        end
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

function M.hasTreasure()
  local key = roomY .. "," .. roomX
  local room = roomMap[key]
  return room and room.type == "treasure" and not clearedRooms[key]
end

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

  -- Background — dark icy blue-black
  love.graphics.setColor(0.01, 0.02, 0.05)
  love.graphics.rectangle("fill", 0, 0, screenW, screenH)

  -- Icy grid pattern (dungeon floor tiles)
  love.graphics.setColor(0.04, 0.06, 0.12, 0.4)
  local gridSize = 48
  for gx = 0, screenW, gridSize do
    love.graphics.line(gx, 0, gx, screenH)
  end
  for gy = 0, screenH, gridSize do
    love.graphics.line(0, gy, screenW, gy)
  end

  -- Frost shimmer lines on floor
  local pulsePhase = math.sin(t * 1.2) * 0.5 + 0.5
  love.graphics.setColor(0.2, 0.5, 0.8, 0.03 + pulsePhase * 0.02)
  for i = 0, 5 do
    local ly = screenH * (i / 5) + math.sin(t * 0.8 + i) * 15
    love.graphics.line(0, ly, screenW, ly)
  end

  -- Frost crystal sparkles on floor
  seed(rx, ry, 123)
  for i = 1, 12 do
    local sx = rand() * screenW
    local sy = rand() * screenH
    local sparkle = math.sin(t * 3 + i * 0.7) * 0.5 + 0.5
    love.graphics.setColor(0.5, 0.8, 1.0, 0.1 * sparkle)
    love.graphics.circle("fill", sx, sy, 2 + sparkle * 2)
  end

  -- Walls
  local walls = getRoomWalls(rx, ry)
  for _, w in ipairs(walls) do
    if w.isPillar then
      -- Ice pillar
      love.graphics.setColor(0.15, 0.25, 0.4, 0.9)
      love.graphics.rectangle("fill", w.x, w.y, w.w, w.h, 4, 4)
      love.graphics.setColor(0.3, 0.6, 0.9, 0.6)
      love.graphics.rectangle("line", w.x, w.y, w.w, w.h, 4, 4)
      -- Ice glint
      love.graphics.setColor(0.6, 0.9, 1.0, 0.3)
      love.graphics.rectangle("fill", w.x + 2, w.y + 2, w.w * 0.3, w.h * 0.3, 2, 2)
    else
      -- Regular ice walls
      love.graphics.setColor(0.08, 0.12, 0.22, 0.95)
      love.graphics.rectangle("fill", w.x, w.y, w.w, w.h)
      love.graphics.setColor(0.2, 0.4, 0.7, 0.5)
      love.graphics.setLineWidth(2)
      love.graphics.rectangle("line", w.x, w.y, w.w, w.h)
      love.graphics.setLineWidth(1)
    end
  end

  -- Door indicators
  local doorColor = {0.2, 0.5, 0.9}
  if room.doors.up then
    love.graphics.setColor(doorColor[1], doorColor[2], doorColor[3], 0.3 + math.sin(t * 3) * 0.15)
    love.graphics.rectangle("fill", screenW/2 - DOOR_WIDTH/2, 0, DOOR_WIDTH, WALL_THICKNESS)
  end
  if room.doors.down then
    love.graphics.setColor(doorColor[1], doorColor[2], doorColor[3], 0.3 + math.sin(t * 3) * 0.15)
    love.graphics.rectangle("fill", screenW/2 - DOOR_WIDTH/2, screenH - WALL_THICKNESS, DOOR_WIDTH, WALL_THICKNESS)
  end
  if room.doors.left then
    love.graphics.setColor(doorColor[1], doorColor[2], doorColor[3], 0.3 + math.sin(t * 3) * 0.15)
    love.graphics.rectangle("fill", 0, screenH/2 - DOOR_WIDTH/2, WALL_THICKNESS, DOOR_WIDTH)
  end
  if room.doors.right then
    local dc = {0.2, 0.5, 0.9}
    local targetKey = ry .. "," .. (rx + 1)
    local targetRoom = roomMap[targetKey]
    if targetRoom and targetRoom.type == "boss" and not hasKey and not boss.defeated then
      dc = {0.8, 0.2, 0.2}  -- Locked = red
    end
    love.graphics.setColor(dc[1], dc[2], dc[3], 0.3 + math.sin(t * 3) * 0.15)
    love.graphics.rectangle("fill", screenW - WALL_THICKNESS, screenH/2 - DOOR_WIDTH/2, WALL_THICKNESS, DOOR_WIDTH)
  end

  -- Key item
  if room.type == "key" and not hasKey and not clearedRooms[key] then
    local kx, ky = screenW/2, screenH/2
    local kGlow = math.sin(t * 4) * 0.3 + 0.7
    love.graphics.setColor(0.3, 0.7, 1.0, 0.15 * kGlow)
    love.graphics.circle("fill", kx, ky, 30)
    love.graphics.setColor(0.4, 0.8, 1.0, kGlow)
    love.graphics.circle("fill", kx, ky - 5, 8)
    love.graphics.rectangle("fill", kx - 2, ky + 3, 4, 15)
    love.graphics.rectangle("fill", kx, ky + 12, 6, 3)
    love.graphics.rectangle("fill", kx, ky + 7, 4, 3)
    love.graphics.setColor(0.4, 0.8, 1.0, kGlow)
    love.graphics.printf("BOSS KEY", 0, ky + 25, screenW, "center")
  end

  -- Treasure
  if room.type == "treasure" and not clearedRooms[key] then
    local tx, ty = screenW/2, screenH/2
    local tGlow = math.sin(t * 3) * 0.3 + 0.7
    love.graphics.setColor(0.2, 0.6, 0.9, 0.15 * tGlow)
    love.graphics.circle("fill", tx, ty, 25)
    love.graphics.setColor(0.3, 0.8, 1.0, tGlow)
    love.graphics.printf("+", tx - 6, ty - 10, 12, "center")
    love.graphics.printf("REPAIR", 0, ty + 18, screenW, "center")
  end

  -- Enemies
  for _, e in ipairs(enemies) do
    if not e.dead then
      local flash = e.flashTimer > 0 and 1 or 0
      local frozen = e.frozenTimer and e.frozenTimer > 0

      if frozen then
        -- Draw frozen overlay
        love.graphics.setColor(0.4, 0.7, 1.0, 0.4)
        love.graphics.circle("fill", e.x, e.y, e.size + 4)
      end

      if e.type == "iceslime" then
        love.graphics.setColor(0.2 + flash * 0.5, 0.5, 0.8 + flash * 0.2)
        love.graphics.circle("fill", e.x, e.y, e.size)
        love.graphics.setColor(0.4, 0.7, 1.0, 0.5)
        love.graphics.circle("line", e.x, e.y, e.size)
      elseif e.type == "frostshooter" then
        love.graphics.setColor(0.3 + flash * 0.4, 0.5, 0.9)
        love.graphics.polygon("fill",
          e.x, e.y - e.size,
          e.x + e.size, e.y,
          e.x, e.y + e.size,
          e.x - e.size, e.y)
        love.graphics.setColor(0.5, 0.7, 1.0, 0.6)
        love.graphics.polygon("line",
          e.x, e.y - e.size,
          e.x + e.size, e.y,
          e.x, e.y + e.size,
          e.x - e.size, e.y)
      elseif e.type == "icecharger" then
        love.graphics.setColor(0.4 + flash * 0.3, 0.6, 0.9)
        local a = e.angle
        love.graphics.polygon("fill",
          e.x + math.cos(a) * e.size, e.y + math.sin(a) * e.size,
          e.x + math.cos(a + 2.4) * e.size * 0.7, e.y + math.sin(a + 2.4) * e.size * 0.7,
          e.x + math.cos(a - 2.4) * e.size * 0.7, e.y + math.sin(a - 2.4) * e.size * 0.7)
        if e.charging then
          love.graphics.setColor(0.3, 0.7, 1.0, 0.5)
          love.graphics.circle("fill", e.x, e.y, e.size + 5)
        end
      end

      -- Frozen ice block overlay
      if frozen then
        love.graphics.setColor(0.5, 0.8, 1.0, 0.6)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", e.x - e.size, e.y - e.size, e.size * 2, e.size * 2, 3, 3)
        love.graphics.setLineWidth(1)
        -- "FROZEN" text
        love.graphics.setColor(0.6, 0.9, 1.0, 0.8)
        love.graphics.printf("❄", e.x - 6, e.y - e.size - 14, 12, "center")
      end

      -- Health bar for damaged enemies
      if e.health < e.maxHealth then
        local barW = e.size * 2
        love.graphics.setColor(0.2, 0.2, 0.3, 0.8)
        love.graphics.rectangle("fill", e.x - barW/2, e.y - e.size - 8, barW, 4)
        love.graphics.setColor(0.3, 0.7, 1.0)
        love.graphics.rectangle("fill", e.x - barW/2, e.y - e.size - 8,
          barW * (e.health / e.maxHealth), 4)
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

  -- Player freeze overlay
  if playerFrozen then
    M.drawFreezeOverlay(t)
  end

  -- Freeze charge warning
  if boss.active and boss.freezeCharging then
    M.drawFreezeChargeWarning(t)
  end

  -- Minimap
  M.drawMinimap()

  -- Room label
  love.graphics.setColor(0.3, 0.6, 0.9, 0.5)
  love.graphics.printf("OORT SANCTUM  " .. rx .. "-" .. ry, 0, screenH - 25, screenW, "center")

  -- Key indicator
  if hasKey then
    love.graphics.setColor(0.4, 0.8, 1.0, 0.8)
    love.graphics.printf("🔑 BOSS KEY", screenW - 160, 25, 140, "right")
  end
end

function M.drawBoss(t)
  local flash = boss.flashTimer > 0 and 1 or 0
  local crack = boss.crackLevel

  -- ---- THE ICE CUBE: a massive actual ice cube ----
  local cubeSize = 45
  local bob = math.sin(boss.bobPhase) * 5

  -- Outer cold aura
  local auraSize = 70 + math.sin(t * 1.5) * 10
  love.graphics.setColor(0.2, 0.5, 0.9, 0.06)
  love.graphics.circle("fill", boss.x, boss.y + bob, auraSize)
  love.graphics.setColor(0.3, 0.6, 1.0, 0.04)
  love.graphics.circle("fill", boss.x, boss.y + bob, auraSize + 20)

  -- Cold mist particles
  for i = 1, 6 do
    local angle = t * 0.5 + (i / 6) * math.pi * 2
    local dist = 55 + math.sin(t + i) * 15
    local mx = boss.x + math.cos(angle) * dist
    local my = boss.y + bob + math.sin(angle) * dist * 0.6
    love.graphics.setColor(0.3, 0.6, 1.0, 0.1 + math.sin(t * 2 + i) * 0.05)
    love.graphics.circle("fill", mx, my, 8 + math.sin(t * 3 + i) * 3)
  end

  -- Main cube body — 3D-ish ice cube with isometric look
  local cx, cy = boss.x, boss.y + bob
  local s = cubeSize

  -- Back face (darker)
  love.graphics.setColor(0.15 + flash * 0.4, 0.25 + flash * 0.3, 0.45 + flash * 0.2, 0.9)
  love.graphics.polygon("fill",
    cx - s * 0.6, cy - s * 0.3,
    cx + s * 0.2, cy - s * 0.8,
    cx + s * 0.8, cy - s * 0.3,
    cx, cy + 0.2 * s)

  -- Front face (lighter, translucent ice)
  love.graphics.setColor(0.25 + flash * 0.4, 0.45 + flash * 0.3, 0.75 + flash * 0.15, 0.85)
  love.graphics.polygon("fill",
    cx - s * 0.8, cy - s * 0.1,
    cx - s * 0.6, cy - s * 0.3,
    cx, cy + 0.2 * s,
    cx - s * 0.2, cy + s * 0.4)

  -- Right face
  love.graphics.setColor(0.2 + flash * 0.4, 0.35 + flash * 0.3, 0.6 + flash * 0.15, 0.88)
  love.graphics.polygon("fill",
    cx, cy + 0.2 * s,
    cx + s * 0.8, cy - s * 0.3,
    cx + s * 0.6, cy + s * 0.1,
    cx - s * 0.2, cy + s * 0.4)

  -- Top face (brightest — catches light)
  love.graphics.setColor(0.4 + flash * 0.3, 0.65 + flash * 0.2, 0.95 + flash * 0.05, 0.8)
  love.graphics.polygon("fill",
    cx - s * 0.6, cy - s * 0.3,
    cx + s * 0.2, cy - s * 0.8,
    cx + s * 0.8, cy - s * 0.3,
    cx, cy + s * 0.2)

  -- Ice edge highlights
  love.graphics.setColor(0.6, 0.85, 1.0, 0.5)
  love.graphics.setLineWidth(1.5)
  -- Top edges
  love.graphics.line(cx - s * 0.6, cy - s * 0.3, cx + s * 0.2, cy - s * 0.8)
  love.graphics.line(cx + s * 0.2, cy - s * 0.8, cx + s * 0.8, cy - s * 0.3)
  -- Front edges
  love.graphics.line(cx - s * 0.8, cy - s * 0.1, cx - s * 0.2, cy + s * 0.4)
  love.graphics.line(cx + s * 0.8, cy - s * 0.3, cx + s * 0.6, cy + s * 0.1)
  love.graphics.setLineWidth(1)

  -- Ice glint / specular highlight
  love.graphics.setColor(1, 1, 1, 0.3 + math.sin(t * 2) * 0.15)
  love.graphics.polygon("fill",
    cx - s * 0.1, cy - s * 0.5,
    cx + s * 0.05, cy - s * 0.6,
    cx + s * 0.15, cy - s * 0.45,
    cx, cy - s * 0.35)

  -- Cracks (appear as HP drops)
  if crack > 0.1 then
    love.graphics.setColor(0.15, 0.3, 0.5, crack * 0.7)
    love.graphics.setLineWidth(1.5)
    -- Major crack
    love.graphics.line(cx - s * 0.3, cy - s * 0.4, cx + s * 0.1, cy + s * 0.1)
    if crack > 0.3 then
      love.graphics.line(cx + s * 0.1, cy - s * 0.5, cx - s * 0.1, cy + s * 0.2)
    end
    if crack > 0.5 then
      love.graphics.line(cx - s * 0.4, cy, cx + s * 0.3, cy - s * 0.2)
      love.graphics.line(cx, cy - s * 0.3, cx + s * 0.2, cy + s * 0.3)
    end
    if crack > 0.7 then
      for i = 1, 3 do
        local ca = (i / 3) * math.pi * 2 + 0.5
        love.graphics.line(
          cx + math.cos(ca) * s * 0.1, cy + math.sin(ca) * s * 0.1,
          cx + math.cos(ca) * s * 0.5, cy + math.sin(ca) * s * 0.5)
      end
    end
    love.graphics.setLineWidth(1)
  end

  -- Melt stacks indicator (dripping water effect)
  if boss.meltStacks > 0 then
    for i = 1, boss.meltStacks do
      local dropX = cx - s * 0.4 + (i / (MELT_STACK_MAX + 1)) * s * 0.8
      local dropY = cy + s * 0.4 + math.sin(t * 4 + i) * 5
      love.graphics.setColor(0.3, 0.5, 0.8, 0.6)
      love.graphics.circle("fill", dropX, dropY, 3)
      -- Drip trail
      love.graphics.setColor(0.3, 0.5, 0.8, 0.3)
      love.graphics.line(dropX, cy + s * 0.2, dropX, dropY)
    end
  end

  -- Frost minions
  for _, m in ipairs(boss.minions) do
    if not m.dead then
      local mFlash = m.flashTimer > 0 and 1 or 0
      -- Small ice crystal ship
      love.graphics.setColor(0.3 + mFlash * 0.5, 0.6, 0.9, 0.85)
      local ms = m.size
      love.graphics.polygon("fill",
        m.x, m.y - ms,
        m.x + ms, m.y,
        m.x, m.y + ms * 0.6,
        m.x - ms, m.y)
      love.graphics.setColor(0.5, 0.8, 1.0, 0.6)
      love.graphics.polygon("line",
        m.x, m.y - ms,
        m.x + ms, m.y,
        m.x, m.y + ms * 0.6,
        m.x - ms, m.y)
      -- HP bar
      if m.hp < m.maxHp then
        love.graphics.setColor(0.1, 0.1, 0.2, 0.7)
        love.graphics.rectangle("fill", m.x - 10, m.y - ms - 6, 20, 3)
        love.graphics.setColor(0.3, 0.7, 1.0, 0.9)
        love.graphics.rectangle("fill", m.x - 10, m.y - ms - 6, 20 * (m.hp / m.maxHp), 3)
      end
    end
  end

  -- Boss health bar
  local barW = 400
  local barH = 12
  local barX = screenW / 2 - barW / 2
  local barY = 18
  local hpPct = boss.health / boss.maxHealth

  love.graphics.setColor(0.3, 0.6, 1.0, 0.9)
  love.graphics.printf("THE ICE CUBE", 0, 3, screenW, "center")

  love.graphics.setColor(0.05, 0.05, 0.12, 0.8)
  love.graphics.rectangle("fill", barX, barY, barW, barH, 3, 3)
  love.graphics.setColor(0.2, 0.5, 0.9, 0.9)
  love.graphics.rectangle("fill", barX, barY, barW * hpPct, barH, 3, 3)
  love.graphics.setColor(0.3, 0.6, 1.0, 0.5)
  love.graphics.rectangle("line", barX, barY, barW, barH, 3, 3)

  -- Melt stacks HUD
  if boss.meltStacks > 0 then
    love.graphics.setColor(1, 0.6, 0.2, 0.8)
    love.graphics.printf("MELT x" .. boss.meltStacks, 0, barY + barH + 2, screenW, "center")
  end
end

function M.drawFreezeOverlay(t)
  -- Freeze effect on entire screen
  local freezePct = playerFreezeTimer / FREEZE_DURATION
  local iceAlpha = 0.3 + freezePct * 0.2

  -- Full screen ice tint
  love.graphics.setColor(0.1, 0.3, 0.6, iceAlpha)
  love.graphics.rectangle("fill", 0, 0, screenW, screenH)

  -- Frost crystals on edges
  love.graphics.setColor(0.5, 0.8, 1.0, iceAlpha * 0.8)
  for i = 0, 20 do
    local ix = (i / 20) * screenW
    local iy1 = math.sin(t * 2 + i * 0.5) * 30
    local iy2 = screenH - math.sin(t * 2 + i * 0.3) * 30
    love.graphics.circle("fill", ix, iy1, 8 + math.sin(t + i) * 4)
    love.graphics.circle("fill", ix, iy2, 8 + math.sin(t + i + 1) * 4)
  end
  for i = 0, 12 do
    local iy = (i / 12) * screenH
    local ix1 = math.sin(t * 1.5 + i * 0.4) * 25
    local ix2 = screenW - math.sin(t * 1.5 + i * 0.6) * 25
    love.graphics.circle("fill", ix1, iy, 6 + math.sin(t + i) * 3)
    love.graphics.circle("fill", ix2, iy, 6 + math.sin(t + i + 2) * 3)
  end

  -- FROZEN text
  love.graphics.setColor(0.5, 0.85, 1.0, 0.7 + math.sin(t * 5) * 0.2)
  love.graphics.printf("❄ FROZEN ❄", 0, screenH / 2 - 20, screenW, "center")

  -- Timer bar
  local timerW = 200
  local timerH = 6
  local timerX = screenW / 2 - timerW / 2
  local timerY = screenH / 2 + 15
  love.graphics.setColor(0.1, 0.2, 0.3, 0.7)
  love.graphics.rectangle("fill", timerX, timerY, timerW, timerH, 2, 2)
  love.graphics.setColor(0.4, 0.7, 1.0, 0.9)
  love.graphics.rectangle("fill", timerX, timerY, timerW * freezePct, timerH, 2, 2)
end

function M.drawFreezeChargeWarning(t)
  local chargePct = 1.0 - (boss.freezeChargeTimer / 1.5)
  local pulse = math.sin(t * 10) * 0.3 + 0.7

  -- Warning ring expanding from boss
  love.graphics.setColor(0.3, 0.6, 1.0, 0.3 * chargePct * pulse)
  love.graphics.setLineWidth(3)
  love.graphics.circle("line", boss.x, boss.y, 60 + chargePct * 200)
  love.graphics.setLineWidth(1)

  -- Warning text
  love.graphics.setColor(0.5, 0.8, 1.0, chargePct * pulse)
  love.graphics.printf("⚠ FREEZE INCOMING ⚠", 0, screenH / 2 + 60, screenW, "center")
end

function M.drawReward(t)
  local glow = math.sin(t * 3) * 0.3 + 0.7

  -- Large ice glow
  love.graphics.setColor(0.2, 0.5, 0.9, 0.1 * glow)
  love.graphics.circle("fill", reward.x, reward.y, 60)
  love.graphics.setColor(0.3, 0.6, 1.0, 0.15 * glow)
  love.graphics.circle("fill", reward.x, reward.y, 40)

  -- Ice Cube ship icon (small cube)
  local s = 12
  local cx, cy = reward.x, reward.y
  love.graphics.setColor(0.3, 0.6, 0.95, glow)
  love.graphics.polygon("fill",
    cx - s, cy, cx, cy - s, cx + s, cy, cx, cy + s)
  love.graphics.setColor(0.5, 0.8, 1.0, glow * 0.8)
  love.graphics.polygon("line",
    cx - s, cy, cx, cy - s, cx + s, cy, cx, cy + s)

  -- Label
  love.graphics.setColor(0.4, 0.8, 1.0, glow)
  love.graphics.printf("ICE CUBE", 0, reward.y + 20, screenW, "center")
  love.graphics.setColor(0.3, 0.6, 0.9, glow * 0.7)
  love.graphics.printf("fly into it to claim", 0, reward.y + 38, screenW, "center")
end

function M.drawMinimap()
  local mapX = screenW - 110
  local mapY = 50
  local cellSize = 18
  local padding = 2

  love.graphics.setColor(0, 0, 0.02, 0.6)
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
          love.graphics.setColor(0.3, 0.6, 1.0)
          love.graphics.rectangle("fill", cx, cy, cellSize, cellSize, 2, 2)
        elseif room and room.type == "boss" then
          love.graphics.setColor(0.2, 0.4, 0.8, 0.8)
          love.graphics.rectangle("fill", cx, cy, cellSize, cellSize, 2, 2)
        elseif room and room.type == "key" then
          love.graphics.setColor(0.4, 0.8, 1.0, 0.7)
          love.graphics.rectangle("fill", cx, cy, cellSize, cellSize, 2, 2)
        elseif clearedRooms[key] then
          love.graphics.setColor(0.15, 0.3, 0.2, 0.7)
          love.graphics.rectangle("fill", cx, cy, cellSize, cellSize, 2, 2)
        else
          love.graphics.setColor(0.12, 0.15, 0.25, 0.7)
          love.graphics.rectangle("fill", cx, cy, cellSize, cellSize, 2, 2)
        end

        love.graphics.setColor(0.2, 0.4, 0.7, 0.5)
        if room then
          if room.doors.right and col < 4 then
            love.graphics.rectangle("fill", cx + cellSize, cy + cellSize/2 - 1, padding, 2)
          end
          if room.doors.down and row < 4 then
            love.graphics.rectangle("fill", cx + cellSize/2 - 1, cy + cellSize, 2, padding)
          end
        end
      else
        love.graphics.setColor(0.05, 0.05, 0.1, 0.5)
        love.graphics.rectangle("fill", cx, cy, cellSize, cellSize, 2, 2)
      end
    end
  end
end

return M
