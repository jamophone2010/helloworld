-- asteroids/outer_dungeon.lua
-- Seeker Missiles dungeon in outer space at tiles (11,11)→(17,17).
-- Zelda-inspired: key/lock progression, 3 combat rooms, 1 puzzle room, mini-map HUD.
-- Boss: The Outer Warden — 5-phase boss, teleports frequently; Seeker Missiles are key advantage.
--
-- Room layout:
--   Entrance  (11,11)
--   Combat 1  (13,12) → Key A      Combat 2  (15,14) → Key B      Combat 3  (13,16) no key
--   Puzzle    (12,13) → shortcut    Boss      (14,14)
--   Lock A: east from (13,13)→(14,13)   Lock B: north from (14,13)→(14,14)

local M = {}

-- ===================== CONSTANTS =====================

local DUNGEON_MIN_X = 11
local DUNGEON_MIN_Y = 11
local DUNGEON_MAX_X = 17
local DUNGEON_MAX_Y = 17

local ENTRANCE_TILE_X = 11
local ENTRANCE_TILE_Y = 11
local BOSS_TILE_X     = 14
local BOSS_TILE_Y     = 14

-- Special room definitions
local ROOM_TYPES = {
  ["11,11"] = "entrance",
  ["13,12"] = "combat",    -- Combat 1: Key A
  ["15,14"] = "combat",    -- Combat 2: Key B
  ["13,16"] = "combat",    -- Combat 3: no key
  ["12,13"] = "puzzle",    -- Puzzle room: 3 switches → shortcut
  ["14,14"] = "boss",
}

-- Which combat room drops which key
local COMBAT_KEY_DROPS = {
  ["13,12"] = "A",
  ["15,14"] = "B",
}

-- Sentinel counts per combat room
local COMBAT_SENTINEL_COUNT = {
  ["13,12"] = 5,
  ["15,14"] = 5,
  ["13,16"] = 6,
}

-- Puzzle switch positions (normalized 0-1, multiplied by w/h at runtime)
local PUZZLE_SWITCH_OFFSETS = {
  {0.3, 0.35}, {0.7, 0.35}, {0.5, 0.65},
}

-- Lock definitions: { from tile, to tile (by tile step), required key }
local LOCK_DEFS = {
  {fx=13, fy=13, tx=14, ty=13, key="A"},  -- east from (13,13) to (14,13)
  {fx=14, fy=13, tx=14, ty=14, key="B"},  -- north from (14,13) to (14,14)
}

-- Shortcut unlocked by puzzle: removes lock going west from (13,14) to (12,14)
-- (alternate path: (12,14)→(13,14) opens when puzzle solved)
local SHORTCUT_LOCK = {fx=12, fy=14, tx=13, ty=14}

-- Sentinel constants
local SENTINEL_SPEED       = 90
local SENTINEL_SHOOT_INT   = 2.5
local SENTINEL_BULLET_SPD  = 180
local SENTINEL_BULLET_DMG  = 12
local SENTINEL_BULLET_SIZE = 5
local SENTINEL_CHASE_RANGE = 280

-- Boss constants
local BOSS_TOTAL_HP    = 2500
local BOSS_PHASE_THRESHOLDS = {2000, 1500, 1000, 500}  -- HP at which each phase starts
local TELEPORT_FLASH_DUR = 0.3
local CLONE_COUNT = 2

-- ===================== STATE =====================

local cleared = false

-- Per-room persistent state (keyed by "x,y")
local roomState = {}

-- Player progression
local playerKeys = {A = false, B = false}
local shortcutOpen = false

-- Key objects floating in the world (picked up by ship proximity)
local worldKeys = {}  -- {x, y, keyId, rotation=0, bob=0, bobDir=1}

-- Current tile the player is on
local currentTileX = 0
local currentTileY = 0

-- Combat barrier state for current tile
local barrierAlpha   = 0
local barrierAnim    = 0
local barrierDeact   = false
local barrierDeactT  = 0
local BARRIER_ANIM_DUR   = 1.2
local BARRIER_DEACT_DUR  = 0.9

-- Puzzle state (only active when on puzzle tile)
local puzzleActive = false
local puzzleSwitches = {}  -- {x, y, active, flashTimer}
local puzzleAllDone = false

-- Boss state
local bossState = "idle"
-- "idle" / "boss_fight" / "boss_defeated"
local boss = nil

-- Room entry flash animation
local entryFlashTimer = 0

-- Lock blocked notification
local lockBlockedTimer = 0
local lockBlockedKey   = ""

-- Pending results table
local pendingResult = nil

local time = 0

-- ===================== ROOM STATE HELPERS =====================

local function tileKey(tx, ty) return tx .. "," .. ty end

local function getRoomState(tx, ty)
  local k = tileKey(tx, ty)
  if not roomState[k] then
    local rtype = ROOM_TYPES[k] or "regular"
    roomState[k] = {
      type         = rtype,
      explored     = false,
      cleared      = (rtype == "regular" or rtype == "entrance"),
      sentinels    = {},
      barrierActive = false,
      switchStates = {false, false, false},
      keyDropped   = false,
    }
  end
  return roomState[k]
end

local function countLivingSentinels(room)
  local n = 0
  for _, s in ipairs(room.sentinels) do
    if not s.dead then n = n + 1 end
  end
  return n
end

-- ===================== SENTINEL SPAWNING =====================

local function spawnSentinels(tx, ty, count, width, height)
  local sentinels = {}
  local margin = 80
  for i = 1, count do
    local angle = (i / count) * math.pi * 2
    local r = 150 + math.random() * 80
    local sx = math.max(margin, math.min(width - margin, width / 2 + math.cos(angle) * r))
    local sy = math.max(margin, math.min(height - margin, height / 2 + math.sin(angle) * r))
    local patrol = math.random() * math.pi * 2
    table.insert(sentinels, {
      x = sx, y = sy,
      vx = math.cos(patrol) * SENTINEL_SPEED,
      vy = math.sin(patrol) * SENTINEL_SPEED,
      hp = 3 + math.random(0, 3),
      maxHp = 6,
      size = 13,
      angle = patrol,
      patrolTimer = 2 + math.random() * 2,
      shootTimer = 1 + math.random() * SENTINEL_SHOOT_INT,
      flashTimer = 0,
      dead = false,
      seekerLocked = false,
    })
  end
  return sentinels
end

-- ===================== PUZZLE ROOM SETUP =====================

local function setupPuzzle(width, height)
  puzzleSwitches = {}
  for _, offset in ipairs(PUZZLE_SWITCH_OFFSETS) do
    table.insert(puzzleSwitches, {
      x = width * offset[1],
      y = height * offset[2],
      active = false,
      flashTimer = 0,
    })
  end
  puzzleAllDone = false
end

-- ===================== BOSS CREATION =====================

local function spawnBoss(width, height)
  boss = {
    x = width / 2,
    y = height / 2,
    centerX = width / 2,
    centerY = height / 2,
    hp = BOSS_TOTAL_HP,
    maxHp = BOSS_TOTAL_HP,
    phase = 1,
    -- Combo/targeting
    seekerLocked = false,
    -- Teleport
    teleportTimer = 8.0,
    teleportFlash = 0,
    teleporting = false,
    pendingTeleport = false,
    teleportX = 0, teleportY = 0,
    -- Attacks
    attackTimer = 3.0,
    ringTimer = 4.0,
    -- Clones (phase 4+)
    clones = {},
    -- Death
    dead = false,
    deathTimer = 2.5,
    deathFlash = 0,
    -- Visuals
    pulseAngle = 0,
    flashTimer = 0,
    phaseFlash = 0,
    -- Burst tracking for phase 5
    burstTimer = 0.5,
    time = 0,
    -- Bullets live in outer_dungeon pending result
    bullets = {},
  }
end

-- ===================== PHASE HELPERS =====================

local function getBossPhase()
  if not boss then return 1 end
  local hpRatio = boss.hp / boss.maxHp
  if hpRatio > 0.8 then return 1
  elseif hpRatio > 0.6 then return 2
  elseif hpRatio > 0.4 then return 3
  elseif hpRatio > 0.2 then return 4
  else return 5 end
end

local function makeBossBullet(x, y, angle, speed, dmg, sz)
  return {
    x = x, y = y,
    vx = math.cos(angle) * (speed or 200),
    vy = math.sin(angle) * (speed or 200),
    lifetime = 4.0,
    owner = "boss_outer",
    size  = sz  or SENTINEL_BULLET_SIZE,
    damage = dmg or SENTINEL_BULLET_DMG,
  }
end

local function fireRadial(count, speed, dmg, sz)
  local b = {}
  for i = 1, count do
    table.insert(b, makeBossBullet(boss.x, boss.y, (i/count)*math.pi*2, speed, dmg, sz))
  end
  return b
end

local function fireAimed(ship, count, arc, speed, dmg, sz)
  local b = {}
  local base = math.atan2(ship.y - boss.y, ship.x - boss.x)
  for i = 1, count do
    local off = count == 1 and 0 or (i/(count-1) - 0.5) * (arc or 0)
    table.insert(b, makeBossBullet(boss.x, boss.y, base + off, speed, dmg, sz))
  end
  return b
end

-- ===================== BOSS UPDATE =====================

local function updateBoss(dt, ship, width, height)
  if not boss or boss.dead then return {} end
  local newBullets = {}
  boss.time = boss.time + dt
  boss.pulseAngle = boss.pulseAngle + dt * 2.0
  boss.phaseFlash = math.max(0, boss.phaseFlash - dt * 2)
  boss.flashTimer  = math.max(0, boss.flashTimer  - dt)

  -- Phase update
  local oldPhase = boss.phase
  boss.phase = getBossPhase()
  if boss.phase ~= oldPhase then
    boss.phaseFlash = 1.0
  end

  -- Teleport logic
  boss.teleportTimer = boss.teleportTimer - dt
  if boss.teleporting then
    boss.teleportFlash = boss.teleportFlash - dt
    if boss.teleportFlash <= 0 then
      -- Actual jump
      boss.x = boss.teleportX
      boss.y = boss.teleportY
      boss.teleporting = false
      boss.teleportFlash = 0
    end
  elseif boss.teleportTimer <= 0 then
    -- Choose new position
    local margin = 100
    boss.teleportX = margin + math.random() * (width  - margin * 2)
    boss.teleportY = margin + math.random() * (height - margin * 2)
    boss.teleporting   = true
    boss.teleportFlash = TELEPORT_FLASH_DUR
    -- Reset teleport cooldown based on phase
    local intervals = {8, 5, 3, 2, 1}
    boss.teleportTimer = intervals[math.min(5, boss.phase)]
  end

  -- Phase 4+: manage clones
  if boss.phase >= 4 and #boss.clones < CLONE_COUNT then
    local margin = 80
    for i = #boss.clones + 1, CLONE_COUNT do
      table.insert(boss.clones, {
        x = margin + math.random() * (width  - margin*2),
        y = margin + math.random() * (height - margin*2),
        vx = (math.random()-0.5)*120,
        vy = (math.random()-0.5)*120,
        isClone = true,
        pulseAngle = math.random() * math.pi * 2,
      })
    end
  elseif boss.phase < 4 then
    boss.clones = {}
  end
  -- Update clone drift
  for _, c in ipairs(boss.clones) do
    c.x = c.x + c.vx * dt
    c.y = c.y + c.vy * dt
    c.pulseAngle = c.pulseAngle + dt * 1.5
    if c.x < 80 or c.x > width  - 80 then c.vx = -c.vx end
    if c.y < 80 or c.y > height - 80 then c.vy = -c.vy end
  end

  -- Skip attacks while teleporting (pre-flash)
  if boss.teleporting then
    -- Update existing bullets
    for i = #boss.bullets, 1, -1 do
      local b = boss.bullets[i]
      b.x = b.x + b.vx * dt; b.y = b.y + b.vy * dt
      b.lifetime = b.lifetime - dt
      if b.lifetime <= 0 then table.remove(boss.bullets, i) end
    end
    return {}
  end

  -- Attack patterns
  boss.attackTimer = boss.attackTimer - dt
  if boss.attackTimer <= 0 then
    if boss.phase == 1 then
      local b = fireRadial(8, 170, 12, 5)
      for _, blt in ipairs(b) do table.insert(newBullets, blt) end
      boss.attackTimer = 3.0
    elseif boss.phase == 2 then
      local b = fireAimed(ship, 3, math.pi/5, 210, 12, 5)
      for _, blt in ipairs(b) do table.insert(newBullets, blt) end
      boss.attackTimer = 2.0
    elseif boss.phase == 3 then
      local b = fireAimed(ship, 5, math.pi/4, 240, 14, 5)
      for _, blt in ipairs(b) do table.insert(newBullets, blt) end
      boss.attackTimer = 2.5
    elseif boss.phase == 4 then
      local b = fireAimed(ship, 4, math.pi/4, 250, 15, 6)
      for _, blt in ipairs(b) do table.insert(newBullets, blt) end
      boss.attackTimer = 2.0
    elseif boss.phase == 5 then
      local b = fireAimed(ship, 3, math.pi/6, 280, 16, 6)
      for _, blt in ipairs(b) do table.insert(newBullets, blt) end
      boss.attackTimer = 0.5
    end
  end

  -- Ring attack (phases 2+)
  if boss.phase >= 2 then
    boss.ringTimer = boss.ringTimer - dt
    if boss.ringTimer <= 0 then
      local b = fireRadial(16, 190, 12, 4)
      for _, blt in ipairs(b) do table.insert(newBullets, blt) end
      boss.ringTimer = 4.0
    end
  end

  -- Phase 3+ homing pair (slow bullet aimed directly)
  if boss.phase >= 3 then
    boss.burstTimer = boss.burstTimer - dt
    if boss.burstTimer <= 0 then
      local b = fireAimed(ship, 2, math.pi/8, 140, 18, 6)
      for _, blt in ipairs(b) do table.insert(newBullets, blt) end
      boss.burstTimer = 3.0
    end
  end

  -- Add new bullets
  for _, blt in ipairs(newBullets) do table.insert(boss.bullets, blt) end

  -- Update existing boss bullets
  for i = #boss.bullets, 1, -1 do
    local b = boss.bullets[i]
    b.x = b.x + b.vx * dt; b.y = b.y + b.vy * dt
    b.lifetime = b.lifetime - dt
    if b.lifetime <= 0 then table.remove(boss.bullets, i) end
  end

  return newBullets
end

-- ===================== BULLET COLLISION =====================

local function checkPlayerBulletsVsBoss(playerBullets)
  if not boss or boss.dead then return end
  for i = #playerBullets, 1, -1 do
    local b = playerBullets[i]
    if b.owner == "player" then
      local dx = b.x - boss.x; local dy = b.y - boss.y
      if math.sqrt(dx*dx + dy*dy) < 40 + (b.size or 2) then
        local dmg = b.damage or 1
        boss.hp = boss.hp - dmg
        boss.flashTimer = 0.08
        if b.seekerTarget == boss then
          b.seekerTarget.seekerLocked = false
          b.seekerTarget = nil
        end
        table.remove(playerBullets, i)
        if boss.hp <= 0 then
          boss.dead = true
          boss.hp = 0
          boss.deathTimer = 2.5
        end
      end
    end
  end
end

local function checkPlayerBulletsVsSentinels(playerBullets, sentinels)
  for i = #playerBullets, 1, -1 do
    local b = playerBullets[i]
    if b.owner == "player" then
      for _, s in ipairs(sentinels) do
        if not s.dead then
          local dx = b.x - s.x; local dy = b.y - s.y
          if math.sqrt(dx*dx + dy*dy) < s.size + (b.size or 2) then
            s.hp = s.hp - (b.damage or 1)
            s.flashTimer = 0.12
            if b.seekerTarget == s then
              s.seekerLocked = false
              b.seekerTarget = nil
            end
            if s.hp <= 0 then
              s.dead = true
              s.seekerLocked = false
            end
            table.remove(playerBullets, i)
            break
          end
        end
      end
    end
  end
end

-- ===================== WORLD KEY UPDATE =====================

local function updateWorldKeys(dt, ship)
  for i = #worldKeys, 1, -1 do
    local k = worldKeys[i]
    k.rotation = k.rotation + dt * 1.8
    k.bob = k.bob + dt * k.bobDir * 2
    if math.abs(k.bob) > 8 then k.bobDir = -k.bobDir end
    -- Pickup check
    local dx = ship.x - k.x; local dy = ship.y - k.y
    if math.sqrt(dx*dx + dy*dy) < 30 then
      playerKeys[k.keyId] = true
      table.remove(worldKeys, i)
    end
  end
end

-- ===================== BARRIER HELPERS =====================

local function activateBarrier()
  barrierAlpha = 0
  barrierAnim  = 0
  barrierDeact = false
end

local function deactivateBarrier()
  barrierDeact  = true
  barrierDeactT = 0
end

local function updateBarrier(dt)
  if barrierDeact then
    barrierDeactT = barrierDeactT + dt
    barrierAlpha  = math.max(0, 1.0 - barrierDeactT / BARRIER_DEACT_DUR)
    if barrierDeactT >= BARRIER_DEACT_DUR then
      barrierDeact  = false
      barrierAlpha  = 0
      barrierAnim   = 0
    end
    return
  end
  local room = getRoomState(currentTileX, currentTileY)
  if room.barrierActive then
    barrierAnim  = math.min(1, barrierAnim + dt / BARRIER_ANIM_DUR)
    barrierAlpha = barrierAnim
  end
end

-- ===================== PUBLIC API =====================

function M.isDungeonTile(tx, ty)
  return tx >= DUNGEON_MIN_X and tx <= DUNGEON_MAX_X
     and ty >= DUNGEON_MIN_Y and ty <= DUNGEON_MAX_Y
end

function M.isBossTile(tx, ty)
  return tx == BOSS_TILE_X and ty == BOSS_TILE_Y
end

function M.getEntranceTile()
  return ENTRANCE_TILE_X, ENTRANCE_TILE_Y
end

function M.isCombatLocked()
  local room = getRoomState(currentTileX, currentTileY)
  return room.barrierActive and barrierAlpha > 0.05
end

function M.getBossState()
  return bossState
end

function M.isCleared()
  return cleared
end

function M.setCleared(val)
  cleared = val == true
end

-- Returns list of valid seeker targets {x, y, entity}
function M.getTargetList()
  local list = {}
  local room = getRoomState(currentTileX, currentTileY)
  for _, s in ipairs(room.sentinels) do
    if not s.dead then
      table.insert(list, {x = s.x, y = s.y, entity = s})
    end
  end
  if boss and not boss.dead and bossState == "boss_fight" then
    table.insert(list, {x = boss.x, y = boss.y, entity = boss})
  end
  return list
end

-- Called when entering a tile. Returns powerup table if this is boss tile and seeker not yet given.
function M.initTile(tx, ty, width, height)
  if not M.isDungeonTile(tx, ty) then return nil end

  currentTileX = tx
  currentTileY = ty

  local key = tileKey(tx, ty)
  local room = getRoomState(tx, ty)

  -- Entry flash on first exploration
  if not room.explored then
    room.explored = true
    entryFlashTimer = 0.4
  end

  -- Barrier state reset per tile visit
  barrierAnim  = 0
  barrierAlpha = 0
  barrierDeact = false

  -- Reset puzzle switches when entering puzzle room
  if room.type == "puzzle" then
    setupPuzzle(width, height)
    puzzleActive = true
  else
    puzzleActive = false
    puzzleSwitches = {}
  end

  -- Spawn sentinels if combat room not cleared
  if room.type == "combat" and not room.cleared then
    if #room.sentinels == 0 then
      local count = COMBAT_SENTINEL_COUNT[key] or 4
      room.sentinels = spawnSentinels(tx, ty, count, width, height)
    end
    room.barrierActive = true
    activateBarrier()
  end

  -- Boss tile: place Seeker Missiles powerup if not yet cleared
  if M.isBossTile(tx, ty) and not cleared and bossState == "idle" then
    bossState = "powerup_present"
    return {
      x = width / 2,
      y = height / 2,
      type = "seeker",
      lifetime = 9999,
      rotation = 0,
      size = 18,
      collected = false,
      collectTimer = 0,
      collectFlash = 0,
    }
  end

  return nil
end

-- Called when player picks up the Seeker Missiles
function M.onSeekerMissilesCollected()
  if bossState ~= "powerup_present" then return end
  bossState = "boss_fight"
  local w = love.graphics.getWidth()
  local h = love.graphics.getHeight()
  spawnBoss(w, h)
  activateBarrier()
  barrierAnim = 0
end

-- Called when player dies during boss fight
function M.onPlayerDied()
  if bossState == "boss_fight" then
    bossState = "powerup_present"
    boss = nil
    barrierAlpha = 0
    barrierAnim  = 0
    barrierDeact = false
    -- Re-enable the seeker powerup on the boss tile
    local room = getRoomState(BOSS_TILE_X, BOSS_TILE_Y)
    room.explored = false  -- force re-init on next visit so powerup re-spawns
  end
end

-- Returns true = transition allowed, false = blocked (with reason)
-- Also called for combat lock check implicitly via isCombatLocked
function M.checkTransition(fromX, fromY, toX, toY)
  -- Block if either tile isn't a dungeon tile on both sides when moving out
  -- (allow leaving dungeon freely unless boss fight)
  if bossState == "boss_fight" and barrierAlpha > 0.05 then
    return false  -- boss barrier sealed
  end

  -- Combat barrier blocks all exits from current tile
  if M.isCombatLocked() then return false end

  -- Lock A: east from (13,13) to (14,13), needs Key A
  -- Lock B: north from (14,13) to (14,14), needs Key B
  for _, lock in ipairs(LOCK_DEFS) do
    if fromX == lock.fx and fromY == lock.fy and toX == lock.tx and toY == lock.ty then
      if not playerKeys[lock.key] then
        lockBlockedTimer = 2.5
        lockBlockedKey   = lock.key
        return false
      end
    end
  end

  -- Shortcut lock: west from (12,14) to (13,14), open only if puzzle solved
  if fromX == SHORTCUT_LOCK.fx and fromY == SHORTCUT_LOCK.fy
      and toX == SHORTCUT_LOCK.tx and toY == SHORTCUT_LOCK.ty then
    if not shortcutOpen then
      lockBlockedTimer = 2.0
      lockBlockedKey   = "?"
      return false
    end
  end

  return true
end

-- Main update. Returns { bossBullets={}, bossDefeated=bool, keyPickup={} }
function M.update(dt, ship, bullets, width, height)
  if not M.isDungeonTile(currentTileX, currentTileY) then return nil end

  time = time + dt
  lockBlockedTimer = math.max(0, lockBlockedTimer - dt)
  entryFlashTimer  = math.max(0, entryFlashTimer  - dt)

  updateBarrier(dt)

  local newBossBullets = {}
  local bossDefeated   = false
  local keyPickup      = nil

  -- Update world keys
  updateWorldKeys(dt, ship)

  -- Puzzle room update
  if puzzleActive and #puzzleSwitches > 0 then
    local allActive = true
    for _, sw in ipairs(puzzleSwitches) do
      sw.flashTimer = math.max(0, sw.flashTimer - dt)
      local dx = ship.x - sw.x; local dy = ship.y - sw.y
      if math.sqrt(dx*dx + dy*dy) < 25 and not sw.active then
        sw.active = true
        sw.flashTimer = 0.5
      end
      if not sw.active then allActive = false end
    end
    if allActive and not puzzleAllDone then
      puzzleAllDone = true
      shortcutOpen  = true
    end
  end

  -- Current room sentinel update
  local room = getRoomState(currentTileX, currentTileY)
  local sentinelBullets = {}

  for i = #room.sentinels, 1, -1 do
    local s = room.sentinels[i]
    if not s.dead then
      s.flashTimer = math.max(0, s.flashTimer - dt)

      -- Movement
      local dx = ship.x - s.x; local dy = ship.y - s.y
      local dist = math.sqrt(dx*dx + dy*dy)
      if dist < SENTINEL_CHASE_RANGE then
        s.vx = (dx/dist) * SENTINEL_SPEED * 1.3
        s.vy = (dy/dist) * SENTINEL_SPEED * 1.3
        s.angle = math.atan2(dy, dx)
      else
        -- Patrol
        s.patrolTimer = s.patrolTimer - dt
        if s.patrolTimer <= 0 then
          s.angle = s.angle + (math.random() - 0.5) * math.pi
          s.vx = math.cos(s.angle) * SENTINEL_SPEED
          s.vy = math.sin(s.angle) * SENTINEL_SPEED
          s.patrolTimer = 2 + math.random() * 2
        end
      end

      s.x = s.x + s.vx * dt
      s.y = s.y + s.vy * dt

      -- Bounce off edges
      local margin = 40
      if s.x < margin then s.x = margin; s.vx = math.abs(s.vx) end
      if s.x > width  - margin then s.x = width  - margin; s.vx = -math.abs(s.vx) end
      if s.y < margin then s.y = margin; s.vy = math.abs(s.vy) end
      if s.y > height - margin then s.y = height - margin; s.vy = -math.abs(s.vy) end

      -- Shoot
      s.shootTimer = s.shootTimer - dt
      if s.shootTimer <= 0 and dist < 450 then
        local angle = math.atan2(ship.y - s.y, ship.x - s.x)
        table.insert(sentinelBullets, {
          x = s.x, y = s.y,
          vx = math.cos(angle) * SENTINEL_BULLET_SPD,
          vy = math.sin(angle) * SENTINEL_BULLET_SPD,
          lifetime = 3.0,
          owner = "boss_outer",
          size  = SENTINEL_BULLET_SIZE,
          damage = SENTINEL_BULLET_DMG,
        })
        s.shootTimer = SENTINEL_SHOOT_INT + math.random() * 0.5
      end
    end
  end

  -- Player bullets vs sentinels
  checkPlayerBulletsVsSentinels(bullets, room.sentinels)

  -- Check if combat room is now cleared
  if room.barrierActive and countLivingSentinels(room) == 0 then
    room.cleared      = true
    room.barrierActive = false
    deactivateBarrier()
    -- Drop key if applicable
    local dropKey = COMBAT_KEY_DROPS[tileKey(currentTileX, currentTileY)]
    if dropKey and not room.keyDropped then
      room.keyDropped = true
      table.insert(worldKeys, {
        x = width / 2, y = height / 2,
        keyId    = dropKey,
        rotation = 0,
        bob      = 0,
        bobDir   = 1,
      })
    end
  end

  -- Boss update
  if bossState == "boss_fight" and boss then
    if boss.dead then
      boss.deathTimer = boss.deathTimer - dt
      boss.deathFlash = math.sin(boss.deathTimer * 12) * 0.5 + 0.5
      if boss.deathTimer <= 0 then
        bossState   = "boss_defeated"
        cleared     = true
        boss        = nil
        deactivateBarrier()
        bossDefeated = true
      end
    else
      checkPlayerBulletsVsBoss(bullets)
      newBossBullets = updateBoss(dt, ship, width, height)
    end
  end

  -- Bounce ship off edges when locked
  if M.isCombatLocked() or (bossState == "boss_fight" and barrierAlpha > 0.05) then
    local margin = 30
    if ship.x < margin then ship.x = margin; ship.vx = math.abs(ship.vx) end
    if ship.x > width  - margin then ship.x = width  - margin; ship.vx = -math.abs(ship.vx) end
    if ship.y < margin then ship.y = margin; ship.vy = math.abs(ship.vy) end
    if ship.y > height - margin then ship.y = height - margin; ship.vy = -math.abs(ship.vy) end
  end

  -- Combine all enemy bullets to return
  for _, b in ipairs(sentinelBullets) do table.insert(newBossBullets, b) end

  return {bossBullets = newBossBullets, bossDefeated = bossDefeated}
end

-- ===================== DRAW =====================

function M.drawBackground(width, height)
  if not M.isDungeonTile(currentTileX, currentTileY) then return end

  -- Entry tint flash (first exploration)
  if entryFlashTimer > 0 then
    local a = entryFlashTimer / 0.4 * 0.18
    love.graphics.setColor(0.1, 0.8, 0.7, a)
    love.graphics.rectangle("fill", 0, 0, width, height)
  end

  -- Boss fight ambient
  if bossState == "boss_fight" and boss and not boss.dead then
    local pulse = math.sin(boss.pulseAngle) * 0.5 + 0.5
    love.graphics.setColor(0.4, 0.1, 0.6, 0.04 + pulse * 0.03)
    love.graphics.rectangle("fill", 0, 0, width, height)
  end

  -- Puzzle room: draw floor switch backgrounds
  if puzzleActive then
    for _, sw in ipairs(puzzleSwitches) do
      if sw.active then
        local glow = sw.flashTimer > 0 and (0.5 + sw.flashTimer * 0.4) or 0.5
        love.graphics.setColor(0.1, 0.8, 0.6, 0.35 + glow * 0.2)
        love.graphics.circle("fill", sw.x, sw.y, 22)
        love.graphics.setColor(0.0, 1.0, 0.7, 0.7)
        love.graphics.circle("line", sw.x, sw.y, 22)
      else
        love.graphics.setColor(0.3, 0.35, 0.4, 0.3)
        love.graphics.circle("fill", sw.x, sw.y, 22)
        love.graphics.setColor(0.4, 0.45, 0.5, 0.5)
        love.graphics.circle("line", sw.x, sw.y, 22)
      end
      -- Center icon
      love.graphics.setColor(sw.active and 0.0 or 0.3, sw.active and 1.0 or 0.4, sw.active and 0.7 or 0.5, 0.9)
      love.graphics.rectangle("fill", sw.x - 5, sw.y - 5, 10, 10, 2)
    end
    -- Puzzle solved indicator
    if puzzleAllDone then
      love.graphics.setColor(0.2, 1.0, 0.7, 0.5)
      love.graphics.printf("SHORTCUT OPENED", 0, height / 2 - 80, width, "center")
    end
  end
end

-- Draw world keys, sentinels, boss, barriers, clones
function M.drawForeground(width, height)
  if not M.isDungeonTile(currentTileX, currentTileY) then return end

  -- Draw world key objects
  for _, k in ipairs(worldKeys) do
    local ky = k.y + k.bob
    love.graphics.push()
    love.graphics.translate(k.x, ky)
    love.graphics.rotate(k.rotation)
    -- Glow
    love.graphics.setColor(1.0, 0.85, 0.1, 0.35)
    love.graphics.circle("fill", 0, 0, 18)
    -- Key body
    love.graphics.setColor(1.0, 0.9, 0.2, 1.0)
    love.graphics.circle("fill", 0, -8, 7)
    love.graphics.setColor(0.9, 0.8, 0.1, 0.8)
    love.graphics.circle("line", 0, -8, 7)
    love.graphics.setColor(1.0, 0.9, 0.2, 1.0)
    love.graphics.rectangle("fill", -2, -1, 4, 12, 1)
    love.graphics.rectangle("fill", 0, 6, 5, 2, 1)
    love.graphics.rectangle("fill", 0, 9, 3, 2, 1)
    love.graphics.pop()
    -- Label
    local ui = require("asteroids.ui")
    love.graphics.setFont(ui.getFont("hudSmall"))
    love.graphics.setColor(1, 0.9, 0.3, 0.8)
    love.graphics.print("KEY " .. k.keyId, k.x - 14, k.y + k.bob + 20)
  end

  -- Draw sentinels
  local room = getRoomState(currentTileX, currentTileY)
  for _, s in ipairs(room.sentinels) do
    if not s.dead then
      local flash = s.flashTimer > 0 and 1.0 or 0.0
      local r, g, b = 0.1 + flash, 0.7, 0.8 - flash * 0.3
      -- Outer glow
      love.graphics.setColor(r, g, b, 0.25)
      love.graphics.circle("fill", s.x, s.y, s.size * 2)
      -- Hexagon body
      local pts = {}
      for i = 0, 5 do
        local a = (i / 6) * math.pi * 2 + s.angle
        table.insert(pts, s.x + math.cos(a) * s.size)
        table.insert(pts, s.y + math.sin(a) * s.size)
      end
      love.graphics.setColor(r, g, b, 0.85)
      love.graphics.polygon("fill", pts)
      -- Direction dot
      love.graphics.setColor(1, 1, 1, 0.7)
      love.graphics.circle("fill",
        s.x + math.cos(s.angle) * (s.size * 0.55),
        s.y + math.sin(s.angle) * (s.size * 0.55), 3)
      -- HP bar
      if s.hp < s.maxHp then
        love.graphics.setColor(0.1, 0.1, 0.1, 0.7)
        love.graphics.rectangle("fill", s.x - 14, s.y - s.size - 8, 28, 4)
        love.graphics.setColor(0.2, 0.9, 0.5, 0.9)
        love.graphics.rectangle("fill", s.x - 14, s.y - s.size - 8, 28 * (s.hp/s.maxHp), 4)
      end
    end
  end

  -- Combat barriers
  if barrierAlpha > 0.01 then
    M._drawBarriers(width, height, barrierAlpha, {0.5, 0.15, 0.8})
  end

  -- Boss stuff
  if boss then
    M._drawBoss(width, height)
  end

  -- Lock door indicators (always show in dungeon)
  M._drawLockIcons(width, height)
end

function M._drawBarriers(width, height, alpha, col)
  local margin = 18
  local t = love.timer.getTime()
  local pulse = math.sin(t * 5) * 0.1
  love.graphics.setLineWidth(3)

  local edges = {
    {margin, 0, margin, height},         -- left
    {width-margin, 0, width-margin, height}, -- right
    {0, margin, width, margin},          -- top
    {0, height-margin, width, height-margin}, -- bottom
  }
  for _, e in ipairs(edges) do
    love.graphics.setColor(col[1], col[2], col[3], alpha * (0.3 + pulse))
    love.graphics.setLineWidth(8)
    love.graphics.line(e[1], e[2], e[3], e[4])
    love.graphics.setColor(col[1] + 0.3, col[2] + 0.2, col[3] + 0.1, alpha * 0.9)
    love.graphics.setLineWidth(2)
    love.graphics.line(e[1], e[2], e[3], e[4])
  end

  -- Corner nodes
  local corners = {{margin,margin},{width-margin,margin},{margin,height-margin},{width-margin,height-margin}}
  for _, c in ipairs(corners) do
    love.graphics.setColor(col[1]+0.4, col[2]+0.3, col[3]+0.2, alpha)
    love.graphics.circle("fill", c[1], c[2], 7)
  end
  love.graphics.setLineWidth(1)
end

function M._drawBoss(width, height)
  if not boss then return end

  local pulse = math.sin(boss.pulseAngle) * 0.5 + 0.5

  -- Boss bullets
  for _, b in ipairs(boss.bullets) do
    local lr = math.max(0, b.lifetime / 4.0)
    love.graphics.setColor(0.6, 0.1, 0.8, lr * 0.4)
    love.graphics.circle("fill", b.x, b.y, (b.size or 5) * 2.2)
    love.graphics.setColor(0.8, 0.3, 1.0, lr * 0.9)
    love.graphics.circle("fill", b.x, b.y, b.size or 5)
  end

  -- Clones (phase 4+)
  for _, c in ipairs(boss.clones) do
    local cp = math.sin(c.pulseAngle) * 0.5 + 0.5
    love.graphics.setColor(0.5, 0.15, 0.6, 0.3 + cp * 0.15)
    love.graphics.circle("fill", c.x, c.y, 30 + cp * 5)
    love.graphics.setColor(0.7, 0.3, 0.8, 0.55)
    love.graphics.circle("fill", c.x, c.y, 22)
    love.graphics.setColor(0.9, 0.7, 1.0, 0.2)
    love.graphics.circle("fill", c.x - 5, c.y - 5, 8)
    love.graphics.setFont(require("asteroids.ui").getFont("hudSmall"))
    love.graphics.setColor(0.7, 0.3, 0.9, 0.6)
    love.graphics.print("?", c.x - 4, c.y - 7)
  end

  if boss.dead then
    love.graphics.setColor(1, 0.9, 0.5, (boss.deathFlash or 0) * 0.85)
    love.graphics.circle("fill", boss.x, boss.y, 60 + (boss.deathFlash or 0) * 25)
    love.graphics.setColor(1, 1, 1, (boss.deathFlash or 0))
    love.graphics.circle("fill", boss.x, boss.y, 22)
    return
  end

  -- Teleport pre-flash
  if boss.teleporting then
    local frac = 1.0 - boss.teleportFlash / TELEPORT_FLASH_DUR
    love.graphics.setColor(1, 1, 1, frac * 0.8)
    love.graphics.circle("line", boss.x, boss.y, 30 + frac * 30)
    love.graphics.setColor(0.8, 0.5, 1.0, frac * 0.5)
    love.graphics.circle("fill", boss.x, boss.y, 20)
    return
  end

  local pf = boss.phaseFlash or 0
  local fl = boss.flashTimer > 0 and 1.0 or 0.0

  -- Outer aura
  love.graphics.setColor(0.5 + pf*0.2, 0.1, 0.8 + pf*0.1, 0.2 + pulse * 0.12)
  love.graphics.circle("fill", boss.x, boss.y, 55 + pulse * 10)

  -- Core
  love.graphics.setColor(0.55 + fl*0.3, 0.1 + pf*0.2, 0.85, 0.92)
  love.graphics.circle("fill", boss.x, boss.y, 36)

  -- Inner bright
  love.graphics.setColor(0.9, 0.7, 1.0, 0.5 + pulse * 0.3)
  love.graphics.circle("fill", boss.x - 7, boss.y - 7, 11)

  -- Orbiting ring (3 nodes)
  local ringAngle = boss.time * (0.8 + (boss.phase - 1) * 0.3)
  love.graphics.setLineWidth(2)
  for i = 1, 3 do
    local a = ringAngle + (i/3) * math.pi * 2
    local rx = boss.x + math.cos(a) * 50
    local ry = boss.y + math.sin(a) * 50
    love.graphics.setColor(0.8, 0.4, 1.0, 0.7 + pulse * 0.2)
    love.graphics.circle("fill", rx, ry, 5)
  end
  love.graphics.setLineWidth(1)

  -- Phase number indicator
  love.graphics.setFont(require("asteroids.ui").getFont("hudSmall"))
  love.graphics.setColor(1, 0.8, 1, 0.55)
  love.graphics.print("P" .. boss.phase, boss.x + 38, boss.y - 8)
end

function M._drawLockIcons(width, height)
  -- Draw small lock icons on screen edges where locks exist
  for _, lock in ipairs(LOCK_DEFS) do
    if currentTileX == lock.fx and currentTileY == lock.fy then
      local haveKey = playerKeys[lock.key]
      local a = haveKey and 0.7 or 0.5
      local r, g, b = haveKey and 0.2 or 1.0, haveKey and 0.9 or 0.7, haveKey and 0.3 or 0.1

      -- Direction arrow + lock icon
      local ix, iy
      local dx = lock.tx - lock.fx; local dy = lock.ty - lock.fy
      if dx > 0 then ix = width - 28; iy = height / 2
      elseif dx < 0 then ix = 28; iy = height / 2
      elseif dy > 0 then ix = width / 2; iy = height - 28   -- south
      elseif dy < 0 then ix = width / 2; iy = 28 end  -- north

      if ix then
        love.graphics.setColor(r, g, b, a)
        love.graphics.circle(haveKey and "fill" or "line", ix, iy, 12)
        love.graphics.setFont(require("asteroids.ui").getFont("hudSmall"))
        love.graphics.setColor(r * 1.2, g * 1.1, b * 1.1, a + 0.2)
        love.graphics.print(lock.key, ix - 4, iy - 7)
      end
    end
  end
end

function M.drawHUD(width, height)
  if not M.isDungeonTile(currentTileX, currentTileY) then return end

  local ui = require("asteroids.ui")

  -- Key indicator (top-left under other HUD items, but we show near mini-map)
  -- Lock blocked message
  if lockBlockedTimer > 0 then
    love.graphics.setFont(ui.getFont("hud"))
    local msg = lockBlockedKey == "?" and "SOLVE THE PUZZLE FIRST"
                or ("NEED KEY " .. lockBlockedKey)
    love.graphics.setColor(1, 0.7, 0.2, math.min(1, lockBlockedTimer))
    love.graphics.printf(msg, 0, height / 2 + 40, width, "center")
  end

  -- Player key inventory
  local kx = width - 110
  local ky = 100
  love.graphics.setFont(ui.getFont("hudSmall"))
  love.graphics.setColor(0.5, 0.5, 0.5, 0.5)
  love.graphics.print("KEYS:", kx, ky)
  for i, kid in ipairs({"A", "B"}) do
    local have = playerKeys[kid]
    love.graphics.setColor(have and 1.0 or 0.3, have and 0.85 or 0.3, have and 0.1 or 0.3, have and 1.0 or 0.4)
    love.graphics.print(kid, kx + (i-1)*20, ky + 14)
  end

  -- Mini-map (top-right corner)
  M._drawMiniMap(width, height)

  -- Boss HUD
  if bossState == "boss_fight" and boss and not boss.dead then
    M._drawBossHUD(width, height)
  end
end

function M._drawMiniMap(width, height)
  local cellSize = 10
  local gap = 1
  local mapW = (DUNGEON_MAX_X - DUNGEON_MIN_X + 1) * (cellSize + gap)
  local mapH = (DUNGEON_MAX_Y - DUNGEON_MIN_Y + 1) * (cellSize + gap)
  local ox = width  - mapW - 12
  local oy = 8

  local ui = require("asteroids.ui")

  -- Map background
  love.graphics.setColor(0.05, 0.05, 0.1, 0.75)
  love.graphics.rectangle("fill", ox - 4, oy - 4, mapW + 8, mapH + 8, 3)
  love.graphics.setColor(0.3, 0.3, 0.5, 0.5)
  love.graphics.rectangle("line", ox - 4, oy - 4, mapW + 8, mapH + 8, 3)

  for ty = DUNGEON_MIN_Y, DUNGEON_MAX_Y do
    for tx = DUNGEON_MIN_X, DUNGEON_MAX_X do
      local cx = ox + (tx - DUNGEON_MIN_X) * (cellSize + gap)
      local cy = oy + (ty - DUNGEON_MIN_Y) * (cellSize + gap)

      local k = tileKey(tx, ty)
      local rs = roomState[k]
      local isCurrent = (tx == currentTileX and ty == currentTileY)

      if not rs or not rs.explored then
        -- Unexplored — dark
        love.graphics.setColor(0.08, 0.08, 0.12, 0.9)
        love.graphics.rectangle("fill", cx, cy, cellSize, cellSize, 1)
      else
        local rtype = rs.type
        local r, g, b
        if rtype == "boss" then
          r, g, b = 0.9, 0.6, 0.1
        elseif rtype == "combat" then
          if rs.cleared then r, g, b = 0.1, 0.6, 0.2
          else r, g, b = 0.7, 0.15, 0.15 end
        elseif rtype == "puzzle" then
          r, g, b = 0.4, 0.15, 0.7
        elseif rtype == "entrance" then
          r, g, b = 0.2, 0.5, 0.8
        else
          r, g, b = 0.25, 0.28, 0.32
        end
        love.graphics.setColor(r, g, b, 0.85)
        love.graphics.rectangle("fill", cx, cy, cellSize, cellSize, 1)

        -- Current tile: white border
        if isCurrent then
          love.graphics.setColor(1, 1, 1, 0.9)
          love.graphics.setLineWidth(1.5)
          love.graphics.rectangle("line", cx - 1, cy - 1, cellSize + 2, cellSize + 2, 1)
          love.graphics.setLineWidth(1)
        end
      end
    end
  end

  -- Draw lock icons on mini-map edges
  for _, lock in ipairs(LOCK_DEFS) do
    -- Find edge between from and to tile
    local fx = ox + (lock.fx - DUNGEON_MIN_X) * (cellSize + gap)
    local fy = oy + (lock.fy - DUNGEON_MIN_Y) * (cellSize + gap)
    local haveKey = playerKeys[lock.key]
    love.graphics.setColor(haveKey and 0.2 or 1.0, haveKey and 0.9 or 0.6, haveKey and 0.3 or 0.1, 0.9)
    local dx = lock.tx - lock.fx; local dy = lock.ty - lock.fy
    local ex = fx + dx * (cellSize + gap) - (dx < 0 and 1 or 0)
    local ey = fy + dy * (cellSize + gap) - (dy < 0 and 1 or 0)
    love.graphics.circle("fill", fx + cellSize/2 + dx*(cellSize/2+gap/2), fy + cellSize/2 + dy*(cellSize/2+gap/2), 2.5)
  end
end

function M._drawBossHUD(width, height)
  local ui = require("asteroids.ui")

  -- Phase indicator
  love.graphics.setFont(ui.getFont("hud"))
  local pf = boss.phaseFlash or 0
  love.graphics.setColor(0.8 + pf*0.2, 0.4, 1.0, 0.85 + pf*0.1)
  love.graphics.printf("PHASE " .. boss.phase .. " / 5", 0, 14, width, "center")

  -- HP bar
  local barW = 280; local barH = 12
  local barX = (width - barW) / 2; local barY = 36
  local hpR = math.max(0, boss.hp / boss.maxHp)
  love.graphics.setColor(0.1, 0.08, 0.15, 0.85)
  love.graphics.rectangle("fill", barX, barY, barW, barH, 3)
  love.graphics.setColor(0.6 + (1-hpR)*0.4, 0.1, 0.8 * hpR + 0.1, 0.9)
  love.graphics.rectangle("fill", barX, barY, barW * hpR, barH, 3)
  love.graphics.setColor(0.7, 0.3, 0.9, 0.7)
  love.graphics.setLineWidth(1)
  love.graphics.rectangle("line", barX, barY, barW, barH, 3)

  -- Phase tick marks at 20% intervals
  for i = 1, 4 do
    local tx = barX + barW * (i / 5)
    love.graphics.setColor(0.9, 0.7, 1.0, 0.5)
    love.graphics.line(tx, barY, tx, barY + barH)
  end
end

-- Acquisition banner
function M.drawAcquisitionBanner(timer)
  if timer <= 0 then return end
  local ui = require("asteroids.ui")
  love.graphics.setFont(ui.getFont("medium"))
  local alpha = math.min(1, timer) * math.min(1, timer)
  love.graphics.setColor(0.8, 0.2, 0.2, alpha)
  love.graphics.printf("⟳ SEEKER MISSILES ⟳", 0, love.graphics.getHeight() / 2 - 30, love.graphics.getWidth(), "center")
  love.graphics.setFont(ui.getFont("hudSmall"))
  love.graphics.setColor(1.0, 0.6, 0.6, alpha * 0.7)
  love.graphics.printf("DEFEAT THE WARDEN TO KEEP THEM", 0, love.graphics.getHeight() / 2 + 4, love.graphics.getWidth(), "center")
end

return M
