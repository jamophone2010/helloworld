-- asteroids/bomb_dungeon.lua
-- Super Bombs dungeon in the southwest outer space sector (5×5 tiles).
-- Dungeon area: tiles (-17,-17) to (-13,-13). Entrance: (-17,-17). Boss tile: (-15,-15).
--
-- Flow:
--   Player enters boss tile → Super Bombs powerup appears
--   Player picks it up → barriers seal tile, boss spawns
--   Beat 3-phase Bomb Broker boss → barriers open, Super Bombs kept permanently
--   Die to boss → lose Super Bombs, respawn at entrance (-17,-17)
--
-- Mechanic: Chain Detonation
--   Normal lasers deal only 1 HP per hit — grinding the boss down is very slow.
--   The boss fires slow "boss bombs" (80 px/s) aimed at the player.
--   When the player detonates their own bomb near a boss bomb AND that boss bomb
--   is within 300 px of the boss → chain explosion: 400 HP damage.
--   Boss refills player bombs (drops a pickup) every 30 s when player has ≤ 1 bomb.

local M = {}

-- ===================== CONSTANTS =====================

local DUNGEON_MIN_X   = -17
local DUNGEON_MIN_Y   = -17
local DUNGEON_MAX_X   = -13
local DUNGEON_MAX_Y   = -13
local ENTRANCE_TILE_X = -17
local ENTRANCE_TILE_Y = -17
local BOSS_TILE_X     = -15
local BOSS_TILE_Y     = -15

-- Combat room tiles
local COMBAT_ROOMS = {
  {x = -16, y = -16, enemyCount = 4},
  {x = -14, y = -14, enemyCount = 5},
}

local LASER_DAMAGE     = 1       -- lasers are nearly useless vs this boss
local CHAIN_DAMAGE     = 400     -- damage from a successful chain detonation
local CHAIN_RADIUS_PAD = 60      -- extra radius added to bomb's max ring radius for chain check
local CHAIN_BOSS_RANGE = 300     -- boss bomb must be this close to boss to chain
local BOMB_REFILL_INTERVAL = 30  -- seconds between refill drops
local BOMB_REFILL_THRESHOLD = 1  -- drop only when player has ≤ this many bombs

local BARRIER_ANIM_DUR  = 1.5
local BARRIER_DEACT_DUR = 1.2

-- Phase HP pools
local PHASE_HP = {1500, 1000, 500}

-- Boss bullet / bomb constants
local BOSS_BULLET_SPEED  = 220
local BOSS_BULLET_DAMAGE = 15
local BOSS_BULLET_SIZE   = 5
local BOSS_BOMB_SPEED    = 80
local BOSS_BOMB_DAMAGE   = 20
local BOSS_BOMB_SIZE     = 14
local BOSS_BOMB_LIFETIME = 8.0

-- Detonator enemy constants
local DETONATOR_HP_MIN = 3
local DETONATOR_HP_MAX = 5
local DETONATOR_SHOOT_INTERVAL = 3.5
local DETONATOR_SPEED  = 60
local DETONATOR_CHASE_RANGE = 320

-- Mini-map cell size
local MAP_CELL = 10
local MAP_PAD  = 8   -- from top-right corner

-- ===================== STATE =====================

local state = "idle"
-- "idle" | "powerup_present" | "boss_fight" | "boss_defeated" | "cleared"

local cleared = false

local boss = nil

local barrierAlpha  = 0
local barrierAnim   = 0
local barrierDeact  = false
local barrierDeactT = 0

local time = 0

-- Per-room state: keyed by "x,y"
-- { type, explored, cleared, enemies={}, barrierActive, keyDropped }
local roomState = {}

local currentTileX = ENTRANCE_TILE_X
local currentTileY = ENTRANCE_TILE_Y

-- Bomb refill pickup (spawned in boss room when applicable)
local bombRefill = nil
local bombRefillTimer = 0

-- Chain flash effect
local chainFlashes = {}   -- {x, y, timer, maxTimer}

-- ===================== ROOM HELPERS =====================

local function roomKey(tx, ty)
  return tx .. "," .. ty
end

local function getRoomType(tx, ty)
  if tx == BOSS_TILE_X and ty == BOSS_TILE_Y then return "boss" end
  if tx == ENTRANCE_TILE_X and ty == ENTRANCE_TILE_Y then return "entrance" end
  for _, cr in ipairs(COMBAT_ROOMS) do
    if tx == cr.x and ty == cr.y then return "combat" end
  end
  return "regular"
end

local function getCombatRoom(tx, ty)
  for _, cr in ipairs(COMBAT_ROOMS) do
    if tx == cr.x and ty == cr.y then return cr end
  end
  return nil
end

local function ensureRoomState(tx, ty)
  local k = roomKey(tx, ty)
  if not roomState[k] then
    local rtype = getRoomType(tx, ty)
    roomState[k] = {
      type         = rtype,
      explored     = false,
      cleared      = rtype == "regular" or rtype == "entrance",
      enemies      = {},
      barrierActive = false,
    }
  end
  return roomState[k]
end

local function spawnDetonators(tx, ty, width, height)
  local k    = roomKey(tx, ty)
  local rs   = roomState[k]
  local cr   = getCombatRoom(tx, ty)
  local count = cr and cr.enemyCount or 4
  rs.enemies = {}
  local cx, cy = width / 2, height / 2
  for i = 1, count do
    local angle = (i / count) * math.pi * 2
    local dist  = 120 + math.random() * 80
    table.insert(rs.enemies, {
      x          = cx + math.cos(angle) * dist,
      y          = cy + math.sin(angle) * dist,
      vx         = 0,
      vy         = 0,
      hp         = DETONATOR_HP_MIN + math.random(0, DETONATOR_HP_MAX - DETONATOR_HP_MIN),
      maxHp      = DETONATOR_HP_MAX,
      size       = 13,
      angle      = math.random() * math.pi * 2,
      shootTimer = 1.5 + math.random() * 2.0,
      flashTimer = 0,
      dead       = false,
      seekerLocked = false,
    })
  end
  rs.barrierActive = true
end

-- ===================== BOSS CREATION =====================

local function spawnBoss(width, height)
  boss = {
    x            = width  / 2,
    y            = height / 2,
    centerX      = width  / 2,
    centerY      = height / 2,
    phase        = 1,
    hp           = PHASE_HP[1],
    maxHp        = PHASE_HP[1],
    -- Visuals
    flashTimer   = 0,
    phaseFlash   = 0,
    pulseAngle   = 0,
    coreAngle    = 0,
    -- Attacks
    bulletTimer  = 3.0,
    bombTimer    = 6.0,
    bombs        = {},    -- active boss bombs on screen
    bullets      = {},    -- fast bullet attacks
    -- Movement
    driftAngle   = 0,
    driftRadius  = 0,
    -- Bomb refill
    refillTimer  = BOMB_REFILL_INTERVAL,
    -- Death
    dead         = false,
    deathTimer   = 2.5,
    deathFlash   = 0,
    time         = 0,
    seekerLocked = false,
  }
end

-- ===================== BOSS BOMBS =====================

local function makeBossBomb(x, y, targetX, targetY)
  local angle = math.atan2(targetY - y, targetX - x)
  -- Jitter aim a bit to give player a chance
  angle = angle + (math.random() - 0.5) * 0.4
  return {
    x         = x,
    y         = y,
    vx        = math.cos(angle) * BOSS_BOMB_SPEED,
    vy        = math.sin(angle) * BOSS_BOMB_SPEED,
    lifetime  = BOSS_BOMB_LIFETIME,
    size      = BOSS_BOMB_SIZE,
    damage    = BOSS_BOMB_DAMAGE,
    pulseAngle = 0,
    owner     = "boss_bomb",
  }
end

local function makeBossBullet(x, y, angle, speed)
  return {
    x        = x,
    y        = y,
    vx       = math.cos(angle) * (speed or BOSS_BULLET_SPEED),
    vy       = math.sin(angle) * (speed or BOSS_BULLET_SPEED),
    lifetime = 3.0,
    size     = BOSS_BULLET_SIZE,
    damage   = BOSS_BULLET_DAMAGE,
    owner    = "boss_bomb_broker",
  }
end

-- ===================== BOSS UPDATE =====================

local function updateBoss(dt, ship)
  if not boss or boss.dead then return {} end

  boss.time       = boss.time + dt
  boss.pulseAngle = boss.pulseAngle + dt * 2.0
  boss.coreAngle  = boss.coreAngle  + dt * (0.5 + (boss.phase - 1) * 0.25)
  boss.phaseFlash = math.max(0, boss.phaseFlash - dt * 2)
  boss.flashTimer = math.max(0, boss.flashTimer - dt)

  -- Phase movement
  if boss.phase == 1 then
    -- Slow side-to-side drift
    boss.driftAngle  = boss.driftAngle + dt * 0.3
    boss.driftRadius = 60
    boss.x = boss.centerX + math.cos(boss.driftAngle) * boss.driftRadius
    boss.y = boss.centerY + math.sin(boss.driftAngle * 0.7) * boss.driftRadius * 0.5
  elseif boss.phase == 2 then
    -- Figure-8
    local t = boss.time * 0.5
    boss.x = boss.centerX + math.sin(t)     * 90
    boss.y = boss.centerY + math.sin(t * 2) * 50
  elseif boss.phase == 3 then
    -- Fast orbit
    boss.driftAngle = boss.driftAngle + dt * 0.8
    local r = 110
    boss.x = boss.centerX + math.cos(boss.driftAngle) * r
    boss.y = boss.centerY + math.sin(boss.driftAngle) * r
  end

  -- Bomb refill drop
  boss.refillTimer = boss.refillTimer - dt
  if boss.refillTimer <= 0 then
    boss.refillTimer = BOMB_REFILL_INTERVAL
    -- Signal to spawn a refill (handled in M.update)
  end

  local newBullets = {}

  -- Bullet attack (faster in higher phases)
  boss.bulletTimer = boss.bulletTimer - dt
  if boss.bulletTimer <= 0 then
    local baseAngle = math.atan2(ship.y - boss.y, ship.x - boss.x)
    if boss.phase == 1 then
      table.insert(newBullets, makeBossBullet(boss.x, boss.y, baseAngle))
      boss.bulletTimer = 3.0
    elseif boss.phase == 2 then
      for i = -1, 1 do
        table.insert(newBullets, makeBossBullet(boss.x, boss.y, baseAngle + i * 0.2))
      end
      boss.bulletTimer = 2.5
    elseif boss.phase == 3 then
      for i = -2, 2 do
        table.insert(newBullets, makeBossBullet(boss.x, boss.y, baseAngle + i * 0.18))
      end
      boss.bulletTimer = 1.8
    end
  end

  -- Boss bomb launch
  boss.bombTimer = boss.bombTimer - dt
  if boss.bombTimer <= 0 then
    if boss.phase == 1 then
      table.insert(boss.bombs, makeBossBomb(boss.x, boss.y, ship.x, ship.y))
      boss.bombTimer = 6.0
    elseif boss.phase == 2 then
      for k = 0, 1 do
        local delay = k * 0.5
        -- Stagger via a simple offset; both aimed at player current pos
        local bx = boss.x + math.cos(boss.coreAngle + k * math.pi) * 20
        local by = boss.y + math.sin(boss.coreAngle + k * math.pi) * 20
        table.insert(boss.bombs, makeBossBomb(bx, by, ship.x, ship.y))
      end
      boss.bombTimer = 4.5
    elseif boss.phase == 3 then
      for k = 0, 2 do
        local off = (k / 2) * math.pi * 2
        table.insert(boss.bombs, makeBossBomb(boss.x, boss.y, ship.x + math.cos(off) * 60, ship.y + math.sin(off) * 60))
      end
      boss.bombTimer = 3.0
    end
  end

  -- Update boss bombs
  for i = #boss.bombs, 1, -1 do
    local bb = boss.bombs[i]
    bb.x = bb.x + bb.vx * dt
    bb.y = bb.y + bb.vy * dt
    bb.lifetime  = bb.lifetime - dt
    bb.pulseAngle = bb.pulseAngle + dt * 4
    if bb.lifetime <= 0 then
      table.remove(boss.bombs, i)
    end
  end

  -- Update boss bullets
  for i = #boss.bullets, 1, -1 do
    local b = boss.bullets[i]
    b.x = b.x + b.vx * dt
    b.y = b.y + b.vy * dt
    b.lifetime = b.lifetime - dt
    if b.lifetime <= 0 then
      table.remove(boss.bullets, i)
    end
  end

  for _, blt in ipairs(newBullets) do
    table.insert(boss.bullets, blt)
  end

  return newBullets
end

-- Called from M.update when refill timer fires
local function trySpawnBombRefill(ship, width, height)
  if not ship then return end
  if (ship.bombs or 0) <= BOMB_REFILL_THRESHOLD then
    -- Drop a bomb pickup near the boss
    local angle = math.random() * math.pi * 2
    bombRefill = {
      x            = boss.x + math.cos(angle) * 80,
      y            = boss.y + math.sin(angle) * 80,
      type         = "bomb",
      lifetime     = 20,
      rotation     = 0,
      size         = 14,
      collected    = false,
      collectTimer = 0,
      collectFlash = 0,
      isBombRefill = true,
    }
  end
end

-- ===================== PHASE ADVANCEMENT =====================

local function advancePhase()
  if not boss then return false end
  boss.phase = boss.phase + 1
  if boss.phase > 3 then
    boss.dead      = true
    boss.deathTimer = 2.5
    return true
  end
  boss.hp       = PHASE_HP[boss.phase]
  boss.maxHp    = PHASE_HP[boss.phase]
  boss.phaseFlash = 1.0
  boss.bombs    = {}
  if boss.phase == 2 then
    boss.bombTimer   = 4.5
    boss.bulletTimer = 2.5
  elseif boss.phase == 3 then
    boss.bombTimer   = 3.0
    boss.bulletTimer = 1.8
  end
  return false
end

-- ===================== PLAYER BULLETS vs BOSS =====================

local function checkPlayerBulletsVsBoss(playerBullets)
  if not boss or boss.dead then return end
  for i = #playerBullets, 1, -1 do
    local b = playerBullets[i]
    if b.owner == "player" then
      local dx   = b.x - boss.x
      local dy   = b.y - boss.y
      local dist = math.sqrt(dx * dx + dy * dy)
      if dist < 40 + (b.size or 2) then
        boss.hp         = boss.hp - LASER_DAMAGE
        boss.flashTimer = 0.06
        table.remove(playerBullets, i)
        if boss.hp <= 0 then
          local died = advancePhase()
          if died then return end
        end
      end
    end
  end
end

-- ===================== BARRIER =====================

local function updateBarriers(dt)
  if barrierDeact then
    barrierDeactT = barrierDeactT + dt
    barrierAlpha  = math.max(0, 1.0 - barrierDeactT / BARRIER_DEACT_DUR)
    if barrierDeactT >= BARRIER_DEACT_DUR then
      barrierDeact = false
      barrierAlpha = 0
    end
    return
  end
  if state == "boss_fight" then
    barrierAnim  = math.min(1, barrierAnim + dt / BARRIER_ANIM_DUR)
    barrierAlpha = barrierAnim
  end
end

-- ===================== CHAIN FLASH HELPERS =====================

local function addChainFlash(x, y)
  table.insert(chainFlashes, {x = x, y = y, timer = 0.6, maxTimer = 0.6})
end

local function updateChainFlashes(dt)
  for i = #chainFlashes, 1, -1 do
    local cf = chainFlashes[i]
    cf.timer = cf.timer - dt
    if cf.timer <= 0 then
      table.remove(chainFlashes, i)
    end
  end
end

-- ===================== DETONATOR UPDATE =====================

local function updateDetonators(dt, tileX, tileY, ship, width, height)
  local k  = roomKey(tileX, tileY)
  local rs = roomState[k]
  if not rs or not rs.barrierActive then return {} end

  local newBullets = {}
  local allDead    = true

  for _, e in ipairs(rs.enemies) do
    if not e.dead then
      allDead = false

      -- Chase player if close
      local dx   = ship.x - e.x
      local dy   = ship.y - e.y
      local dist = math.sqrt(dx * dx + dy * dy)
      if dist < DETONATOR_CHASE_RANGE and dist > 5 then
        e.vx = dx / dist * DETONATOR_SPEED
        e.vy = dy / dist * DETONATOR_SPEED
      else
        -- Patrol slowly
        e.vx = e.vx * 0.95
        e.vy = e.vy * 0.95
      end

      e.x = e.x + e.vx * dt
      e.y = e.y + e.vy * dt
      e.angle = e.angle + dt * 0.8
      e.flashTimer = math.max(0, e.flashTimer - dt)

      -- Clamp to screen
      e.x = math.max(30, math.min(width  - 30, e.x))
      e.y = math.max(30, math.min(height - 30, e.y))

      -- Shoot a slow bomb at player
      e.shootTimer = e.shootTimer - dt
      if e.shootTimer <= 0 then
        e.shootTimer = DETONATOR_SHOOT_INTERVAL
        local angle = math.atan2(ship.y - e.y, ship.x - e.x) + (math.random() - 0.5) * 0.5
        table.insert(newBullets, {
          x        = e.x,
          y        = e.y,
          vx       = math.cos(angle) * 100,
          vy       = math.sin(angle) * 100,
          lifetime = 4.0,
          size     = 5,
          damage   = 10,
          owner    = "boss_bomb_broker",
        })
      end
    end
  end

  if allDead and rs.barrierActive then
    rs.barrierActive = false
    rs.cleared       = true
  end

  return newBullets
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

function M.isLocked()
  return state == "boss_fight" and barrierAlpha > 0.05
end

function M.getState()
  return state
end

function M.setCleared(val)
  cleared = val == true
  if cleared then state = "cleared" end
end

function M.isCleared()
  return cleared
end

function M.isCombatLocked()
  local k  = roomKey(currentTileX, currentTileY)
  local rs = roomState[k]
  return rs and rs.barrierActive == true
end

-- Returns list of {x, y, entity} for seeker lock-on
function M.getTargetList()
  local list = {}
  if boss and not boss.dead then
    table.insert(list, {x = boss.x, y = boss.y, entity = boss})
  end
  local k  = roomKey(currentTileX, currentTileY)
  local rs = roomState[k]
  if rs then
    for _, e in ipairs(rs.enemies) do
      if not e.dead then
        table.insert(list, {x = e.x, y = e.y, entity = e})
      end
    end
  end
  return list
end

-- Returns bomb refill if one is waiting, then clears it (caller inserts into powerups)
function M.takeBombRefill()
  local r = bombRefill
  bombRefill = nil
  return r
end

-- Called when tile is entered. Returns powerup table if boss tile and not cleared.
function M.initTile(tileX, tileY, width, height)
  currentTileX = tileX
  currentTileY = tileY

  local k  = roomKey(tileX, tileY)
  local rs = ensureRoomState(tileX, tileY)
  rs.explored = true

  -- Combat room entry
  if rs.type == "combat" and not rs.cleared and #rs.enemies == 0 then
    spawnDetonators(tileX, tileY, width, height)
  end

  -- Boss tile
  if not M.isBossTile(tileX, tileY) then return nil end
  if cleared then return nil end
  if state == "boss_fight" then return nil end

  state        = "powerup_present"
  barrierAnim  = 0
  barrierAlpha = 0

  return {
    x            = width  / 2,
    y            = height / 2,
    type         = "superbombs",
    lifetime     = 9999,
    rotation     = 0,
    size         = 18,
    collected    = false,
    collectTimer = 0,
    collectFlash = 0,
  }
end

-- Called when player collects the Super Bombs powerup
function M.onSuperBombsCollected()
  if state ~= "powerup_present" then return end
  state        = "boss_fight"
  barrierAnim  = 0
  barrierAlpha = 0
  barrierDeact = false
  local w = love.graphics.getWidth()
  local h = love.graphics.getHeight()
  spawnBoss(w, h)
  bombRefillTimer = BOMB_REFILL_INTERVAL
end

-- Called when player dies during boss fight
function M.onPlayerDied()
  state        = "powerup_present"
  boss         = nil
  barrierAlpha = 0
  barrierAnim  = 0
  barrierDeact = false
  bombRefill   = nil
  chainFlashes = {}
end

function M.deactivateBarriers()
  barrierDeact  = true
  barrierDeactT = 0
end

-- ===================== CHAIN DETONATION =====================
-- Called from triggerSmartBomb in init.lua.
-- bombX, bombY: position of the player bomb's detonation center.
-- effectiveRadius: the largest ring maxRadius (including 1.5x if super bombs active).
-- Returns total chain damage dealt (0 if no chain).
function M.checkBombChain(bombX, bombY, effectiveRadius)
  if not boss or boss.dead then return 0 end
  if state ~= "boss_fight" then return 0 end

  local chainRadius = effectiveRadius + CHAIN_RADIUS_PAD
  local totalDamage = 0

  for i = #boss.bombs, 1, -1 do
    local bb = boss.bombs[i]
    -- Is boss bomb within player bomb's blast radius?
    local dx1 = bb.x - bombX
    local dy1 = bb.y - bombY
    local distToBomb = math.sqrt(dx1 * dx1 + dy1 * dy1)

    if distToBomb <= chainRadius then
      -- Is boss bomb close enough to the boss to chain?
      local dx2 = bb.x - boss.x
      local dy2 = bb.y - boss.y
      local distToBoss = math.sqrt(dx2 * dx2 + dy2 * dy2)

      if distToBoss <= CHAIN_BOSS_RANGE then
        totalDamage = totalDamage + CHAIN_DAMAGE
        addChainFlash(bb.x, bb.y)
        table.remove(boss.bombs, i)
      end
    end
  end

  if totalDamage > 0 then
    boss.hp         = boss.hp - totalDamage
    boss.flashTimer = 0.3
    if boss.hp <= 0 then
      advancePhase()
    end
  end

  return totalDamage
end

-- ===================== MAIN UPDATE =====================

function M.update(dt, ship, playerBullets, width, height)
  updateChainFlashes(dt)

  -- Bomb refill pickup lifetime
  if bombRefill then
    bombRefill.lifetime = bombRefill.lifetime - dt
    bombRefill.rotation = bombRefill.rotation + dt * 2
    if bombRefill.lifetime <= 0 then
      bombRefill = nil
    end
  end

  -- Combat room update (any room, not just boss room)
  local ck = roomKey(currentTileX, currentTileY)
  local crs = roomState[ck]
  local combatBullets = {}
  if crs and crs.type == "combat" and crs.barrierActive then
    combatBullets = updateDetonators(dt, currentTileX, currentTileY, ship, width, height)
    -- Detonator bullets vs player handled in init.lua by owner == "boss_bomb_broker"
    -- Player bullets vs detonators
    for i = #playerBullets, 1, -1 do
      local b = playerBullets[i]
      if b.owner == "player" then
        for _, e in ipairs(crs.enemies) do
          if not e.dead then
            local dx = b.x - e.x
            local dy = b.y - e.y
            if math.sqrt(dx*dx + dy*dy) < e.size + (b.size or 2) then
              e.hp        = e.hp - (b.isHyper and 2 or 1)
              e.flashTimer = 0.1
              table.remove(playerBullets, i)
              if e.hp <= 0 then
                e.dead = true
                e.seekerLocked = false
              end
              break
            end
          end
        end
      end
    end
  end

  if state ~= "boss_fight" then
    return {bossBullets = combatBullets, bossDefeated = false}
  end

  time = time + dt
  updateBarriers(dt)

  -- Boss death animation
  if boss and boss.dead then
    boss.deathTimer = boss.deathTimer - dt
    boss.deathFlash = math.sin(boss.deathTimer * 10) * 0.5 + 0.5
    if boss.deathTimer <= 0 then
      state   = "boss_defeated"
      cleared = true
      boss    = nil
      M.deactivateBarriers()
      return {bossBullets = combatBullets, bossDefeated = true}
    end
    return {bossBullets = combatBullets, bossDefeated = false}
  end

  -- Player bullets vs boss
  checkPlayerBulletsVsBoss(playerBullets)

  -- Boss AI
  local newBullets = updateBoss(dt, ship)

  -- Bomb refill drop check
  if boss and not boss.dead and not bombRefill then
    bombRefillTimer = bombRefillTimer - dt
    if bombRefillTimer <= 0 then
      bombRefillTimer = BOMB_REFILL_INTERVAL
      trySpawnBombRefill(ship, width, height)
    end
  end

  -- Bounce ship off walls
  if M.isLocked() then
    local margin = 30
    if ship.x < margin             then ship.x = margin;              ship.vx =  math.abs(ship.vx) end
    if ship.x > width  - margin    then ship.x = width  - margin;     ship.vx = -math.abs(ship.vx) end
    if ship.y < margin             then ship.y = margin;              ship.vy =  math.abs(ship.vy) end
    if ship.y > height - margin    then ship.y = height - margin;     ship.vy = -math.abs(ship.vy) end
  end

  for _, blt in ipairs(newBullets) do
    table.insert(combatBullets, blt)
  end

  return {bossBullets = combatBullets, bossDefeated = false}
end

-- ===================== DRAW =====================

function M.drawBackground(width, height)
  if state ~= "boss_fight" and state ~= "boss_defeated" then return end
  if not boss then return end
  local pulse = math.sin(boss.pulseAngle) * 0.5 + 0.5
  -- Ominous dark-orange ambient
  love.graphics.setColor(0.8, 0.35, 0.05, 0.05 + pulse * 0.04)
  love.graphics.circle("fill", boss.x, boss.y, 220 + pulse * 30)
  love.graphics.setColor(0.6, 0.2, 0.0, 0.03)
  love.graphics.circle("fill", boss.x, boss.y, 320)
end

function M.drawForeground(width, height)
  -- Combat room barrier
  local k  = roomKey(currentTileX, currentTileY)
  local rs = roomState[k]
  if rs and rs.type == "combat" and rs.barrierActive then
    local margin = 20
    love.graphics.setLineWidth(8)
    love.graphics.setColor(1.0, 0.45, 0.0, 0.25)
    love.graphics.rectangle("line", margin, margin, width - 2 * margin, height - 2 * margin)
    love.graphics.setLineWidth(2)
    love.graphics.setColor(1.0, 0.6, 0.1, 0.85)
    love.graphics.rectangle("line", margin, margin, width - 2 * margin, height - 2 * margin)

    -- Corner sparks
    local corners = { {margin,margin},{width-margin,margin},{margin,height-margin},{width-margin,height-margin} }
    for _, c in ipairs(corners) do
      love.graphics.setColor(1.0, 0.7, 0.2, 0.9)
      love.graphics.polygon("fill", c[1]-5,c[2], c[1],c[2]-5, c[1]+5,c[2], c[1],c[2]+5)
    end
    love.graphics.setLineWidth(1)

    -- Draw detonator enemies
    for _, e in ipairs(rs.enemies) do
      if not e.dead then
        local flash = e.flashTimer > 0 and 1.0 or 0.0
        -- Outer glow
        love.graphics.setColor(1.0, 0.5, 0.1, 0.20)
        love.graphics.circle("fill", e.x, e.y, e.size * 2.2)
        -- Hexagon body
        local pts = {}
        for vi = 1, 6 do
          local a = e.angle + (vi / 6) * math.pi * 2
          table.insert(pts, e.x + math.cos(a) * e.size)
          table.insert(pts, e.y + math.sin(a) * e.size)
        end
        love.graphics.setColor(0.9 + flash * 0.1, 0.4 + flash * 0.3, 0.05, 0.9)
        love.graphics.polygon("fill", pts)
        -- Direction dot
        love.graphics.setColor(1, 0.9, 0.5, 0.9)
        love.graphics.circle("fill", e.x + math.cos(e.angle) * (e.size * 0.6), e.y + math.sin(e.angle) * (e.size * 0.6), 3)
        -- HP bar
        if e.hp < e.maxHp then
          local bw = e.size * 2
          local hpR = math.max(0, e.hp / e.maxHp)
          love.graphics.setColor(0.2, 0.2, 0.2, 0.7)
          love.graphics.rectangle("fill", e.x - bw/2, e.y - e.size - 8, bw, 4)
          love.graphics.setColor(1.0 - hpR, hpR * 0.8, 0, 0.9)
          love.graphics.rectangle("fill", e.x - bw/2, e.y - e.size - 8, bw * hpR, 4)
        end
      end
    end
  end

  -- Boss fight rendering
  if state ~= "boss_fight" and state ~= "boss_defeated" then return end

  -- Barriers
  if barrierAlpha > 0.01 then
    local ba = barrierAlpha
    local margin = 20
    love.graphics.setLineWidth(8)
    love.graphics.setColor(1.0, 0.45, 0.0, ba * 0.3)
    love.graphics.rectangle("line", margin, margin, width - 2*margin, height - 2*margin)
    love.graphics.setLineWidth(2)
    love.graphics.setColor(1.0, 0.65, 0.1, ba * 0.9)
    love.graphics.rectangle("line", margin, margin, width - 2*margin, height - 2*margin)
    -- Corner diamonds
    local corners = { {margin,margin},{width-margin,margin},{margin,height-margin},{width-margin,height-margin} }
    for _, c in ipairs(corners) do
      love.graphics.setColor(1.0, 0.75, 0.3, ba)
      love.graphics.polygon("fill", c[1]-5,c[2], c[1],c[2]-5, c[1]+5,c[2], c[1],c[2]+5)
    end
    love.graphics.setLineWidth(1)
  end

  if not boss then return end

  -- Boss bombs
  for _, bb in ipairs(boss.bombs) do
    local lifeRatio = bb.lifetime / BOSS_BOMB_LIFETIME
    local pulse     = math.sin(bb.pulseAngle) * 0.5 + 0.5
    -- Outer warning glow
    love.graphics.setColor(1.0, 0.3, 0.0, lifeRatio * 0.35 + pulse * 0.15)
    love.graphics.circle("fill", bb.x, bb.y, bb.size * 2.5)
    -- Core
    love.graphics.setColor(1.0, 0.6, 0.1, lifeRatio * 0.95)
    love.graphics.circle("fill", bb.x, bb.y, bb.size)
    -- Inner hot spot
    love.graphics.setColor(1.0, 0.95, 0.5, lifeRatio * 0.7)
    love.graphics.circle("fill", bb.x, bb.y, bb.size * 0.45)
    -- Fuse sparks (3 dots rotating around)
    for j = 1, 3 do
      local fa = bb.pulseAngle + (j / 3) * math.pi * 2
      love.graphics.setColor(1.0, 1.0, 0.3, lifeRatio * 0.8)
      love.graphics.circle("fill", bb.x + math.cos(fa) * (bb.size + 5), bb.y + math.sin(fa) * (bb.size + 5), 2)
    end
  end

  -- Boss fast bullets
  for _, b in ipairs(boss.bullets) do
    local lr = b.lifetime / 3.0
    love.graphics.setColor(1.0, 0.5, 0.1, lr * 0.4)
    love.graphics.circle("fill", b.x, b.y, b.size * 2)
    love.graphics.setColor(1.0, 0.75, 0.3, lr * 0.9)
    love.graphics.circle("fill", b.x, b.y, b.size)
  end

  -- Chain flash effects
  for _, cf in ipairs(chainFlashes) do
    local a = cf.timer / cf.maxTimer
    love.graphics.setColor(1.0, 0.8, 0.2, a * 0.8)
    love.graphics.circle("fill", cf.x, cf.y, 40 * (1 - a) + 10)
    love.graphics.setColor(1.0, 1.0, 0.5, a * 0.6)
    love.graphics.circle("line", cf.x, cf.y, 60 * (1 - a) + 5)
  end

  -- Bomb refill pickup
  if bombRefill then
    local pulse = math.sin(time * 4) * 0.5 + 0.5
    love.graphics.setColor(1.0, 0.5, 0.1, 0.25 + pulse * 0.15)
    love.graphics.circle("fill", bombRefill.x, bombRefill.y, 22 + pulse * 4)
    love.graphics.setColor(1.0, 0.7, 0.2, 0.9)
    love.graphics.circle("fill", bombRefill.x, bombRefill.y, 14)
    love.graphics.setColor(1.0, 0.95, 0.5, 0.95)
    love.graphics.printf("B", bombRefill.x - 10, bombRefill.y - 8, 20, "center")
  end

  -- Boss body
  if boss.dead then
    local df = boss.deathFlash or 0
    love.graphics.setColor(1.0, 0.6, 0.1, df * 0.8)
    love.graphics.circle("fill", boss.x, boss.y, 55 + df * 25)
    love.graphics.setColor(1, 1, 1, df)
    love.graphics.circle("fill", boss.x, boss.y, 22)
    return
  end

  local pulse    = math.sin(boss.pulseAngle) * 0.5 + 0.5
  local flashMod = boss.flashTimer > 0 and 1.0 or 0.0
  local pf       = boss.phaseFlash or 0

  -- Outer glow
  love.graphics.setColor(0.8 + pf * 0.2, 0.3, 0.0, 0.2 + pulse * 0.12)
  love.graphics.circle("fill", boss.x, boss.y, 60 + pulse * 10)

  -- Armour rings (3 concentric)
  love.graphics.setLineWidth(3)
  for ri = 1, 3 do
    local ra    = boss.coreAngle * (ri % 2 == 0 and 1 or -1) + ri * 0.8
    local rr    = 28 + ri * 10
    love.graphics.setColor(0.7 + pf * 0.3, 0.3 - ri * 0.05, 0.0, 0.55)
    love.graphics.circle("line", boss.x, boss.y, rr)
    -- 4 rivets per ring
    for j = 1, 4 do
      local ang = ra + (j / 4) * math.pi * 2
      love.graphics.setColor(1.0, 0.65 + pulse * 0.2, 0.1, 0.8)
      love.graphics.circle("fill", boss.x + math.cos(ang) * rr, boss.y + math.sin(ang) * rr, 3)
    end
  end
  love.graphics.setLineWidth(1)

  -- Core body
  love.graphics.setColor(
    0.75 + flashMod * 0.25 + pf * 0.1,
    0.25 + flashMod * 0.1,
    0.0,
    0.92
  )
  love.graphics.circle("fill", boss.x, boss.y, 26)

  -- Inner bright spot
  love.graphics.setColor(1.0, 0.85, 0.3, 0.55 + pulse * 0.25)
  love.graphics.circle("fill", boss.x - 7, boss.y - 7, 10)
end

function M.drawHUD(width, height)
  local ui = require("asteroids.ui")

  -- Mini-map (top-right)
  local gridW  = DUNGEON_MAX_X - DUNGEON_MIN_X + 1  -- 5
  local gridH  = DUNGEON_MAX_Y - DUNGEON_MIN_Y + 1  -- 5
  local mapW   = gridW * MAP_CELL
  local mapH   = gridH * MAP_CELL
  local mapX   = width  - mapW - MAP_PAD
  local mapY   = MAP_PAD

  for ty = DUNGEON_MIN_Y, DUNGEON_MAX_Y do
    for tx = DUNGEON_MIN_X, DUNGEON_MAX_X do
      local k   = roomKey(tx, ty)
      local rs  = roomState[k]
      local cx  = mapX + (tx - DUNGEON_MIN_X) * MAP_CELL
      local cy  = mapY + (ty - DUNGEON_MIN_Y) * MAP_CELL

      -- Background
      love.graphics.setColor(0.05, 0.05, 0.05, 0.7)
      love.graphics.rectangle("fill", cx, cy, MAP_CELL - 1, MAP_CELL - 1)

      if rs and rs.explored then
        local rtype = rs.type
        if rtype == "boss" then
          if cleared then
            love.graphics.setColor(0.5, 0.4, 0.0, 0.85)
          else
            love.graphics.setColor(0.9, 0.7, 0.1, 0.85)
          end
        elseif rtype == "combat" then
          if rs.cleared then
            love.graphics.setColor(0.1, 0.6, 0.1, 0.7)
          else
            love.graphics.setColor(0.7, 0.15, 0.05, 0.7)
          end
        elseif rtype == "entrance" then
          love.graphics.setColor(0.2, 0.3, 0.5, 0.7)
        else
          love.graphics.setColor(0.25, 0.25, 0.25, 0.6)
        end
        love.graphics.rectangle("fill", cx, cy, MAP_CELL - 1, MAP_CELL - 1)
      end

      -- Current tile highlight
      if tx == currentTileX and ty == currentTileY then
        love.graphics.setColor(1, 1, 1, 0.9)
        love.graphics.setLineWidth(1)
        love.graphics.rectangle("line", cx, cy, MAP_CELL - 1, MAP_CELL - 1)
      end
    end
  end

  -- Boss fight HUD
  if state ~= "boss_fight" then return end
  if not boss or boss.dead then return end

  -- Phase indicator
  love.graphics.setFont(ui.getFont("hud"))
  local pf = boss.phaseFlash or 0
  love.graphics.setColor(1.0, 0.6 + pf * 0.2, 0.1, 0.85 + pf * 0.1)
  love.graphics.printf("PHASE " .. boss.phase .. " / 3", 0, 14, width, "center")

  -- Boss HP bar
  local barW  = 260
  local barH  = 12
  local barX  = (width - barW) / 2
  local barY  = 36
  local hpRat = math.max(0, boss.hp / boss.maxHp)

  love.graphics.setColor(0.12, 0.07, 0.02, 0.85)
  love.graphics.rectangle("fill", barX, barY, barW, barH, 3)
  love.graphics.setColor(0.9 * hpRat + (1 - hpRat), 0.35 * hpRat, 0.0, 0.9)
  love.graphics.rectangle("fill", barX, barY, barW * hpRat, barH, 3)
  love.graphics.setColor(1.0, 0.6, 0.2, 0.7)
  love.graphics.setLineWidth(1)
  love.graphics.rectangle("line", barX, barY, barW, barH, 3)

  -- Chain hint
  if #boss.bombs > 0 then
    love.graphics.setFont(ui.getFont("hudSmall"))
    love.graphics.setColor(1.0, 0.9, 0.3, 0.75 + math.sin(time * 4) * 0.15)
    love.graphics.printf("CHAIN BOMB FOR MASSIVE DAMAGE", 0, barY + barH + 6, width, "center")
  end
end

function M.drawAcquisitionBanner(timer)
  if timer <= 0 then return end
  local ui = require("asteroids.ui")
  love.graphics.setFont(ui.getFont("medium"))
  local alpha = math.min(1, timer) * math.min(1, timer)
  love.graphics.setColor(1.0, 0.6, 0.1, alpha)
  love.graphics.printf("💣 SUPER BOMBS 💣", 0, love.graphics.getHeight() / 2 - 30, love.graphics.getWidth(), "center")
  love.graphics.setFont(ui.getFont("hudSmall"))
  love.graphics.setColor(1.0, 0.85, 0.4, alpha * 0.7)
  love.graphics.printf("DEFEAT THE BOMB BROKER TO KEEP THEM", 0, love.graphics.getHeight() / 2 + 4, love.graphics.getWidth(), "center")
end

return M
