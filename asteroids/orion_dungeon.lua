-- asteroids/orion_dungeon.lua
-- Spread Beam dungeon in the Orion constellation (4×4 tile area).
-- Boss room: tile (-7,-7). Dungeon area: tiles (-9,-9) to (-6,-6).
-- Entrance tile (respawn destination on death): (-9,-9).
--
-- Flow:
--   Player enters boss tile → Spread Beam powerup appears
--   Player picks it up → barriers seal the tile, boss spawns
--   Beat 3-phase boss → barriers open, Spread Beam kept permanently
--   Die to boss → lose Spread Beam, respawn at entrance tile (-9,-9)

local M = {}

-- ===================== CONSTANTS =====================

local BOSS_TILE_X       = -7
local BOSS_TILE_Y       = -7
local DUNGEON_MIN_X     = -9
local DUNGEON_MIN_Y     = -9
local DUNGEON_MAX_X     = -6
local DUNGEON_MAX_Y     = -6
local ENTRANCE_TILE_X   = -9
local ENTRANCE_TILE_Y   = -9

local NODE_COUNT        = 3
local NODE_RADIUS       = 220        -- px from boss center
local NODE_SIZE         = 28         -- collision radius
local NODE_HP           = {300, 400, 500}   -- per phase
local NODE_REGEN_RATE   = 20         -- HP/sec when not ALL nodes being hit

local BOSS_BULLET_SPEED     = 220
local BOSS_BULLET_DAMAGE    = 15
local BOSS_BULLET_SIZE      = 5

local ORBIT_SPEED = {0, 0.3, 0.8}   -- rad/s per phase (1-indexed)

-- ===================== STATE =====================

local state = "idle"
-- "idle"           – dungeon not relevant (not in dungeon tiles)
-- "powerup_present"– player is on boss tile, powerup waiting
-- "boss_fight"     – barriers sealed, boss active
-- "boss_defeated"  – boss dead, barriers lowering
-- "cleared"        – dungeon completed; powerup permanent

local cleared = false

local boss = nil
local barrierAlpha  = 0
local barrierAnim   = 0        -- 0..1 seal-in progress
local barrierDeact  = false
local barrierDeactT = 0
local BARRIER_ANIM_DUR  = 1.5
local BARRIER_DEACT_DUR = 1.2

local time = 0   -- dungeon time accumulator

-- Pending results returned per frame
local pendingResult = nil

-- ===================== BOSS CREATION =====================

local function makeNode(index)
  local angle = ((index - 1) / NODE_COUNT) * math.pi * 2 -- 0, 2π/3, 4π/3
  return {
    baseAngle  = angle,
    orbitAngle = angle,   -- actual current angle (changes in phase 2/3)
    hp         = NODE_HP[1],
    maxHp      = NODE_HP[1],
    flashTimer = 0,
    beingShot  = false,
  }
end

local function spawnBoss(width, height)
  local nodes = {}
  for i = 1, NODE_COUNT do
    table.insert(nodes, makeNode(i))
  end
  boss = {
    x           = width  / 2,
    y           = height / 2,
    phase       = 1,
    nodes       = nodes,
    attackTimer = 2.5,
    ringTimer   = 4.0,
    bullets     = {},
    dead        = false,
    deathTimer  = 0,
    deathFlash  = 0,
    time        = 0,
    phaseFlash  = 0,  -- flash when phase changes
  }
end

-- ===================== PHASE HELPERS =====================

local function advancePhase()
  if not boss then return false end
  boss.phase = boss.phase + 1
  if boss.phase > 3 then
    -- Boss defeated
    boss.dead = true
    boss.deathTimer = 0
    state = "boss_defeated"
    barrierDeact  = true
    barrierDeactT = 0
    return true
  end
  -- Reset all node HP for new phase
  for _, n in ipairs(boss.nodes) do
    n.hp     = NODE_HP[boss.phase]
    n.maxHp  = NODE_HP[boss.phase]
  end
  boss.attackTimer = 2.5 - (boss.phase - 1) * 0.5
  boss.phaseFlash  = 1.0
  return false
end

-- ===================== PUBLIC: STATE ACCESS =====================

function M.isBossTile(tx, ty)
  return tx == BOSS_TILE_X and ty == BOSS_TILE_Y
end

function M.isDungeonTile(tx, ty)
  return tx >= DUNGEON_MIN_X and tx <= DUNGEON_MAX_X
      and ty >= DUNGEON_MIN_Y and ty <= DUNGEON_MAX_Y
end

function M.getEntranceTile()
  return ENTRANCE_TILE_X, ENTRANCE_TILE_Y
end

function M.getBossTile()
  return BOSS_TILE_X, BOSS_TILE_Y
end

function M.getState()
  return state
end

function M.isLocked()
  return state == "boss_fight" and barrierAlpha > 0.1
end

function M.isCleared()
  return cleared
end

function M.setCleared(val)
  cleared = val or false
  if cleared then
    state = "cleared"
  else
    state = "idle"
    boss  = nil
  end
end

-- ===================== TILE INIT =====================

-- Called by init.lua's spawnTileContent. Returns a powerup table to insert,
-- or nil if nothing should be spawned.
function M.initTile(tileX, tileY, width, height)
  if cleared then
    state = "cleared"
    return nil
  end

  if not M.isBossTile(tileX, tileY) then
    -- Inside the 4×4 dungeon area but not the boss room: just track presence
    if M.isDungeonTile(tileX, tileY) then
      if state == "idle" then state = "idle" end  -- no-op, just navigating
    else
      state = "idle"
    end
    boss = nil
    barrierAlpha = 0
    return nil
  end

  -- Boss tile entered
  state         = "powerup_present"
  boss          = nil
  barrierAlpha  = 0
  barrierAnim   = 0
  barrierDeact  = false

  -- Return a Spread Beam powerup centered on screen
  return {
    x           = width  / 2,
    y           = height / 2,
    type        = "spreadbeam",
    lifetime    = 9999,   -- won't expire
    rotation    = 0,
    size        = 18,
    collected   = false,
    collectTimer= 0,
    collectFlash= 0,
    orionBossRoom = true, -- marker so we know this is the dungeon pickup
  }
end

-- ===================== ON SPREAD BEAM COLLECTED =====================

function M.onSpreadBeamCollected()
  if state ~= "powerup_present" then return end
  state       = "boss_fight"
  barrierAnim = 0
  barrierAlpha= 0
  barrierDeact= false
  time        = 0
end

-- Called by init.lua after boss fight starts (first update frame after collection)
local function ensureBossSpawned(width, height)
  if not boss then
    spawnBoss(width, height)
  end
end

-- ===================== ON PLAYER DIED =====================

-- Called from init.lua when player dies while state == "boss_fight".
-- Resets dungeon to powerup_present so the player can try again.
function M.onPlayerDied()
  state         = "powerup_present"
  boss          = nil
  barrierAlpha  = 0
  barrierAnim   = 0
  barrierDeact  = false
  time          = 0
  pendingResult = nil
end

-- ===================== UPDATE =====================

function M.update(dt, ship, bullets, width, height)
  pendingResult = {bossBullets = {}, bossDefeated = false, playerHit = 0}

  if state == "idle" or state == "cleared" or state == "powerup_present" then
    return pendingResult
  end

  time = time + dt

  -- Spawn boss if not yet spawned
  ensureBossSpawned(width, height)

  -- ---- Barrier animation ----
  if state == "boss_fight" then
    if not barrierDeact then
      barrierAnim  = math.min(1, barrierAnim + dt / BARRIER_ANIM_DUR)
      barrierAlpha = barrierAnim
    end
  end

  if barrierDeact then
    barrierDeactT = barrierDeactT + dt
    local t = math.min(1, barrierDeactT / BARRIER_DEACT_DUR)
    barrierAlpha  = 1 - t
    if t >= 1 then
      barrierAlpha = 0
      if state == "boss_defeated" then
        state   = "cleared"
        cleared = true
        pendingResult.bossDefeated = true
      end
    end
  end

  -- ---- Bounce ship off barrier walls ----
  if M.isLocked() and ship and not ship.dead and not ship.exploding then
    local margin = 8
    if ship.x < margin then
      ship.x  = margin
      ship.vx = math.abs(ship.vx or 0) * 0.5
    end
    if ship.x > width - margin then
      ship.x  = width - margin
      ship.vx = -math.abs(ship.vx or 0) * 0.5
    end
    if ship.y < margin then
      ship.y  = margin
      ship.vy = math.abs(ship.vy or 0) * 0.5
    end
    if ship.y > height - margin then
      ship.y  = height - margin
      ship.vy = -math.abs(ship.vy or 0) * 0.5
    end
  end

  if not boss or boss.dead then
    boss.deathTimer = (boss.deathTimer or 0) + dt
    return pendingResult
  end

  boss.time = boss.time + dt
  if boss.phaseFlash > 0 then boss.phaseFlash = boss.phaseFlash - dt * 2 end

  local phase = boss.phase

  -- ---- Node orbit ----
  local orbitSpd = ORBIT_SPEED[phase] or 0
  for _, n in ipairs(boss.nodes) do
    n.orbitAngle = n.orbitAngle + orbitSpd * dt
    n.flashTimer = math.max(0, n.flashTimer - dt)
    n.beingShot  = false  -- reset each frame
  end

  -- ---- Check player bullets vs nodes ----
  local allThreeHit = false
  for i = #bullets, 1, -1 do
    local b = bullets[i]
    if b.owner == "player" then
      for ni, n in ipairs(boss.nodes) do
        if not (n.hp <= 0) then
          local nx = boss.x + math.cos(n.orbitAngle) * NODE_RADIUS
          local ny = boss.y + math.sin(n.orbitAngle) * NODE_RADIUS
          local dx = b.x - nx
          local dy = b.y - ny
          if math.sqrt(dx*dx + dy*dy) < NODE_SIZE + b.size then
            n.beingShot = true
            n.hp        = n.hp - 1
            n.flashTimer= 0.12
            if n.hp < 0 then n.hp = 0 end
            table.remove(bullets, i)
            break
          end
        end
      end
    end
  end

  -- Count how many nodes are being hit
  local hitCount = 0
  for _, n in ipairs(boss.nodes) do
    if n.beingShot then hitCount = hitCount + 1 end
  end
  allThreeHit = (hitCount == 3)

  -- ---- Node HP regen (only stops if ALL 3 hit this frame) ----
  for _, n in ipairs(boss.nodes) do
    if n.hp > 0 and not allThreeHit and not n.beingShot then
      -- Regen any node that wasn't hit when not all 3 were hit
      n.hp = math.min(n.maxHp, n.hp + NODE_REGEN_RATE * dt)
    end
  end

  -- ---- Check if all nodes dead (phase transition) ----
  local allDead = true
  for _, n in ipairs(boss.nodes) do
    if n.hp > 0 then allDead = false; break end
  end
  if allDead then
    advancePhase()
    return pendingResult
  end

  -- ---- Boss attacks ----
  boss.attackTimer = boss.attackTimer - dt

  if boss.attackTimer <= 0 then
    if phase == 1 then
      -- Radial burst: 8 bullets outward from boss center
      boss.attackTimer = 2.5
      local count = 8
      for i = 0, count - 1 do
        local a = (i / count) * math.pi * 2 + boss.time * 0.2
        table.insert(pendingResult.bossBullets, {
          x        = boss.x,
          y        = boss.y,
          vx       = math.cos(a) * BOSS_BULLET_SPEED,
          vy       = math.sin(a) * BOSS_BULLET_SPEED,
          lifetime = 3,
          owner    = "boss",
          size     = BOSS_BULLET_SIZE,
          damage   = BOSS_BULLET_DAMAGE,
          isMissile= false,
          missileTrail = {},
          angle    = a,
        })
      end

    elseif phase == 2 then
      -- Aimed shot at player
      boss.attackTimer = 1.5
      if ship and not ship.dead then
        local dx = ship.x - boss.x
        local dy = ship.y - boss.y
        local d  = math.sqrt(dx*dx + dy*dy)
        if d > 0 then
          local a = math.atan2(dy, dx)
          table.insert(pendingResult.bossBullets, {
            x        = boss.x,
            y        = boss.y,
            vx       = math.cos(a) * (BOSS_BULLET_SPEED * 1.3),
            vy       = math.sin(a) * (BOSS_BULLET_SPEED * 1.3),
            lifetime = 4,
            owner    = "boss",
            size     = BOSS_BULLET_SIZE,
            damage   = BOSS_BULLET_DAMAGE,
            isMissile= false,
            missileTrail = {},
            angle    = a,
          })
        end
      end

    elseif phase == 3 then
      -- 3-way spread aimed at player
      boss.attackTimer = 1.0
      if ship and not ship.dead then
        local dx = ship.x - boss.x
        local dy = ship.y - boss.y
        local d  = math.sqrt(dx*dx + dy*dy)
        if d > 0 then
          local baseA = math.atan2(dy, dx)
          local spreads = {-0.3, 0, 0.3}
          for _, off in ipairs(spreads) do
            local a = baseA + off
            table.insert(pendingResult.bossBullets, {
              x        = boss.x,
              y        = boss.y,
              vx       = math.cos(a) * (BOSS_BULLET_SPEED * 1.5),
              vy       = math.sin(a) * (BOSS_BULLET_SPEED * 1.5),
              lifetime = 4,
              owner    = "boss",
              size     = BOSS_BULLET_SIZE,
              damage   = BOSS_BULLET_DAMAGE,
              isMissile= false,
              missileTrail = {},
              angle    = a,
            })
          end
        end
      end
    end
  end

  -- Phase 3 ring attack
  if phase == 3 then
    boss.ringTimer = boss.ringTimer - dt
    if boss.ringTimer <= 0 then
      boss.ringTimer = 4.0
      local count = 16
      for i = 0, count - 1 do
        local a = (i / count) * math.pi * 2
        table.insert(pendingResult.bossBullets, {
          x        = boss.x,
          y        = boss.y,
          vx       = math.cos(a) * BOSS_BULLET_SPEED * 0.8,
          vy       = math.sin(a) * BOSS_BULLET_SPEED * 0.8,
          lifetime = 5,
          owner    = "boss",
          size     = BOSS_BULLET_SIZE - 1,
          damage   = BOSS_BULLET_DAMAGE * 0.7,
          isMissile= false,
          missileTrail = {},
          angle    = a,
        })
      end
    end
  end

  -- ---- Check boss bullets vs player ----
  -- Boss bullets live in gameState.bullets (added by init.lua from pendingResult.bossBullets)
  -- Damage is applied in init.lua — here we just return the bullets to add.
  -- (Boss bullet → player collision is handled by init.lua like ufo bullets.)

  return pendingResult
end

-- ===================== DRAW =====================

-- Background: draw boss body / nebula pillar effect
function M.drawBackground(width, height)
  if state ~= "boss_fight" and state ~= "boss_defeated" then return end
  if not boss then return end

  local t = time

  -- Boss core: pulsing pillar of gas
  local pulseR = math.sin(t * 1.4) * 0.1 + 0.5
  local pulseG = math.sin(t * 0.9 + 1) * 0.1 + 0.25
  local pulseB = math.sin(t * 1.1 + 2) * 0.1 + 0.5

  -- Outer glow rings
  for i = 1, 4 do
    local r = 60 + i * 25 + math.sin(t * 0.7 + i) * 10
    local a = (0.12 - i * 0.02) * (boss.dead and math.max(0, 1 - boss.deathTimer) or 1)
    love.graphics.setColor(pulseR, pulseG, pulseB, a)
    love.graphics.circle("fill", boss.x, boss.y, r)
  end

  -- Phase flash overlay
  if boss.phaseFlash and boss.phaseFlash > 0 then
    love.graphics.setColor(1, 1, 1, boss.phaseFlash * 0.3)
    love.graphics.rectangle("fill", 0, 0, width, height)
  end

  -- Node connection lines (faint)
  for i, n in ipairs(boss.nodes) do
    local nx = boss.x + math.cos(n.orbitAngle) * NODE_RADIUS
    local ny = boss.y + math.sin(n.orbitAngle) * NODE_RADIUS
    local a  = math.max(0, (n.hp / n.maxHp)) * 0.15
    love.graphics.setColor(pulseR, pulseG, pulseB, a)
    love.graphics.setLineWidth(1)
    love.graphics.line(boss.x, boss.y, nx, ny)
  end
  love.graphics.setLineWidth(1)
end

-- Foreground: draw boss core, nodes, barriers
function M.drawForeground(width, height)
  if state ~= "boss_fight" and state ~= "boss_defeated" then return end
  if not boss then return end

  local t    = time
  local deathFade = boss.dead and math.max(0, 1 - boss.deathTimer * 0.8) or 1

  -- ---- Draw nodes ----
  for i, n in ipairs(boss.nodes) do
    if n.hp > 0 then
      local nx = boss.x + math.cos(n.orbitAngle) * NODE_RADIUS
      local ny = boss.y + math.sin(n.orbitAngle) * NODE_RADIUS

      local flash   = n.flashTimer > 0
      local hpFrac  = n.hp / n.maxHp

      -- Node body
      if flash then
        love.graphics.setColor(1, 1, 1, deathFade)
      else
        -- Color shifts red→green with hp
        love.graphics.setColor(1 - hpFrac * 0.5, 0.3 + hpFrac * 0.4, 0.8, deathFade * 0.9)
      end
      love.graphics.circle("fill", nx, ny, NODE_SIZE)

      -- Node ring
      love.graphics.setColor(1, 1, 1, deathFade * 0.4)
      love.graphics.setLineWidth(2)
      love.graphics.circle("line", nx, ny, NODE_SIZE + 4 + math.sin(t * 3 + i) * 2)
      love.graphics.setLineWidth(1)

      -- Node number
      love.graphics.setColor(1, 1, 1, deathFade * 0.8)
      love.graphics.printf(tostring(i), nx - 8, ny - 7, 16, "center")
    end
  end

  -- ---- Draw boss core ----
  if not boss.dead then
    local pulse = math.sin(t * 2) * 0.1 + 0.9
    local phase = boss.phase

    -- Core body
    love.graphics.setColor(0.6, 0.2, 0.7, 0.85)
    love.graphics.circle("fill", boss.x, boss.y, 28 * pulse)

    -- Inner core
    love.graphics.setColor(1, 0.5, 1, 0.9)
    love.graphics.circle("fill", boss.x, boss.y, 14 * pulse)

    -- Phase ring
    local ringR = 40 + math.sin(t * 1.5) * 4
    love.graphics.setColor(0.8, 0.3, 0.9, 0.5)
    love.graphics.setLineWidth(2)
    love.graphics.circle("line", boss.x, boss.y, ringR)
    love.graphics.setLineWidth(1)

    -- Phase indicator lines radiating from core
    for p = 1, phase do
      local a = (p / 3) * math.pi * 2 + t * 0.4
      local x2 = boss.x + math.cos(a) * 55
      local y2 = boss.y + math.sin(a) * 55
      love.graphics.setColor(1, 0.6, 1, 0.4)
      love.graphics.line(boss.x, boss.y, x2, y2)
    end
  else
    -- Death explosion
    local dt2 = boss.deathTimer
    if dt2 < 1.5 then
      local alpha = math.max(0, 1 - dt2)
      local r = 30 + dt2 * 120
      love.graphics.setColor(1, 0.6, 0.1, alpha * 0.7)
      love.graphics.circle("fill", boss.x, boss.y, r)
      love.graphics.setColor(1, 1, 1, alpha * 0.5)
      love.graphics.circle("fill", boss.x, boss.y, r * 0.4)
    end
  end

  -- ---- Draw barriers ----
  if barrierAlpha > 0 then
    local w = width
    local h = height
    local a = barrierAlpha
    local pulse = math.sin(love.timer.getTime() * 4) * 0.12

    -- Orion nebula colors: rose/magenta barriers
    local r, g, b = 0.9, 0.3, 0.7

    love.graphics.setLineWidth(3)
    for layer = 1, 3 do
      local off = layer * 2
      local la  = a * (0.55 - layer * 0.12 + pulse)
      love.graphics.setColor(r, g, b, la)
      local prog = math.min(1, barrierAnim)
      love.graphics.line(w * (0.5 - 0.5*prog), off,    w * (0.5 + 0.5*prog), off)
      love.graphics.line(w * (0.5 - 0.5*prog), h-off,  w * (0.5 + 0.5*prog), h-off)
      love.graphics.line(off,   h * (0.5 - 0.5*prog), off,   h * (0.5 + 0.5*prog))
      love.graphics.line(w-off, h * (0.5 - 0.5*prog), w-off, h * (0.5 + 0.5*prog))
    end

    -- Corner nodes
    local cn = 10 * a
    local corners = {{4,4},{w-4,4},{4,h-4},{w-4,h-4}}
    for _, c in ipairs(corners) do
      love.graphics.setColor(1, 0.5, 0.9, a * (0.7 + pulse))
      love.graphics.circle("fill", c[1], c[2], cn)
      love.graphics.setColor(1, 1, 1, a * 0.5)
      love.graphics.circle("fill", c[1], c[2], cn * 0.35)
    end
    love.graphics.setLineWidth(1)
  end
end

-- HUD: node HP bars + phase indicator
function M.drawHUD(width, height)
  if state ~= "boss_fight" and state ~= "boss_defeated" then return end
  if not boss then return end

  local ui = require("asteroids.ui")
  love.graphics.setFont(ui.getFont("hudSmall"))

  -- Phase indicator (top center)
  if not boss.dead then
    local phaseLabel = "PHASE " .. boss.phase .. " / 3"
    love.graphics.setColor(1, 0.5, 1, 0.9)
    love.graphics.printf(phaseLabel, 0, 14, width, "center")

    -- "BARRIER ACTIVE" hint
    if M.isLocked() then
      love.graphics.setColor(0.9, 0.4, 0.8, 0.6)
      love.graphics.printf("▣ AREA SEALED", 0, 28, width, "center")
    end
  else
    love.graphics.setColor(0.2, 1, 0.6, 0.9)
    love.graphics.printf("BOSS DEFEATED — SPREAD BEAM KEPT!", 0, 14, width, "center")
  end

  -- Node HP bars (bottom-right)
  local barW = 100
  local barH = 8
  local startX = width  - barW - 12
  local startY = height - 16 - (NODE_COUNT * (barH + 6))

  for i, n in ipairs(boss.nodes) do
    local bx = startX
    local by = startY + (i - 1) * (barH + 6)
    local frac = math.max(0, n.hp / n.maxHp)

    -- Label
    love.graphics.setColor(0.8, 0.7, 0.9, 0.8)
    love.graphics.print("NODE " .. i, bx - 54, by)

    -- Background
    love.graphics.setColor(0.2, 0.2, 0.25, 0.8)
    love.graphics.rectangle("fill", bx, by, barW, barH)

    -- HP bar (red when low, cyan when full)
    local r = 1 - frac * 0.6
    local g = 0.2 + frac * 0.6
    love.graphics.setColor(r, g, 1, 0.9)
    love.graphics.rectangle("fill", bx, by, barW * frac, barH)

    -- Regen indicator (pulsing if not all three being hit)
    if n.hp > 0 and n.hp < n.maxHp then
      local regen = math.sin(love.timer.getTime() * 6) * 0.5 + 0.5
      love.graphics.setColor(0, 1, 0.5, regen * 0.6)
      love.graphics.rectangle("fill", bx + barW * frac, by, 3, barH)
    end

    -- Border
    love.graphics.setColor(0.5, 0.3, 0.6, 0.6)
    love.graphics.rectangle("line", bx, by, barW, barH)
  end
end

-- ===================== UTILITY =====================

-- Draw the "SPREAD BEAM" announcement banner (called from init.lua)
function M.drawAcquisitionBanner(timer)
  if timer <= 0 then return end
  local ui = require("asteroids.ui")
  love.graphics.setFont(ui.getFont("medium"))
  local alpha = math.min(1, timer) * math.min(1, (timer))
  love.graphics.setColor(0.2, 1, 0.6, alpha)
  love.graphics.printf("✦ SPREAD BEAM ✦", 0, love.graphics.getHeight() / 2 - 30, love.graphics.getWidth(), "center")
  love.graphics.setFont(ui.getFont("hudSmall"))
  love.graphics.setColor(0.8, 1, 0.9, alpha * 0.7)
  love.graphics.printf("DEFEAT THE GUARDIAN TO KEEP IT", 0, love.graphics.getHeight() / 2 + 4, love.graphics.getWidth(), "center")
end

return M
