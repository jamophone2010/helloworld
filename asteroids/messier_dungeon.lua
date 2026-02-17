-- asteroids/messier_dungeon.lua
-- Hyper Beam dungeon in the Messier constellation (4×4 tile area).
-- Boss room: tile (0,-8). Dungeon area: tiles (-2,-9) to (1,-6).
-- Entrance tile (respawn destination on death): (-2,-9).
--
-- Flow:
--   Player enters boss tile → Hyper Beam powerup appears
--   Player picks it up → barriers seal the tile, boss spawns
--   Beat 3-phase Resonant Core boss → barriers open, Hyper Beam kept permanently
--   Die to boss → lose Hyper Beam, respawn at entrance tile (-2,-9)
--
-- Mechanic: Combo damage system
--   Each bullet hit resets a 0.5s combo window and increments comboCount.
--   Damage = BASE_DAMAGE * (1.4 ^ comboCount) — exponential growth with sustained fire.
--   When the window expires without a hit, boss begins regenerating HP.
--   Forces the player to maintain a rapid rhythm rather than burst-and-wait.

local M = {}

-- ===================== CONSTANTS =====================

local BOSS_TILE_X       =  0
local BOSS_TILE_Y       = -8
local DUNGEON_MIN_X     = -2
local DUNGEON_MIN_Y     = -9
local DUNGEON_MAX_X     =  1
local DUNGEON_MAX_Y     = -6
local ENTRANCE_TILE_X   = -2
local ENTRANCE_TILE_Y   = -9

local COMBO_WINDOW          = 0.5    -- seconds between hits to keep combo alive
local BASE_DAMAGE_NORMAL    = 5
local BASE_DAMAGE_HYPER     = 8
local DAMAGE_MULT           = 1.4    -- per combo level

local PHASE_HP          = {600, 800, 1000}
local REGEN_RATE        = {30,  45,  60}   -- HP/sec when combo broken

local BOSS_BULLET_SPEED     = 200
local BOSS_BULLET_DAMAGE    = 15
local BOSS_BULLET_SIZE      = 6

-- ===================== STATE =====================

local state = "idle"
-- "idle"            – not relevant
-- "powerup_present" – boss tile entered, powerup waiting
-- "boss_fight"      – barriers up, boss active
-- "boss_defeated"   – boss dead
-- "cleared"         – permanent

local cleared = false

local boss = nil
local barrierAlpha  = 0
local barrierAnim   = 0
local barrierDeact  = false
local barrierDeactT = 0
local BARRIER_ANIM_DUR  = 1.5
local BARRIER_DEACT_DUR = 1.2

local time = 0

-- ===================== BOSS CREATION =====================

local function spawnBoss(width, height)
  boss = {
    x             = width  / 2,
    y             = height / 2,
    centerX       = width  / 2,
    centerY       = height / 2,
    phase         = 1,
    hp            = PHASE_HP[1],
    maxHp         = PHASE_HP[1],
    -- Combo state
    comboCount    = 0,
    comboTimer    = 0,
    regenActive   = false,
    -- Visuals
    flashTimer    = 0,
    phaseFlash    = 0,
    pulseAngle    = 0,  -- for pulsing glow animation
    ringAngle     = 0,  -- orbiting decorative ring
    -- Attack
    attackTimer   = 2.5,
    ringTimer     = 4.0,
    bullets       = {},
    -- Death
    dead          = false,
    deathTimer    = 0,
    deathFlash    = 0,
    -- Phase 2/3 movement
    driftAngle    = 0,
    time          = 0,
  }
end

-- ===================== PHASE HELPERS =====================

local function advancePhase()
  if not boss then return false end
  boss.phase = boss.phase + 1
  if boss.phase > 3 then
    boss.dead = true
    boss.deathTimer = 2.5
    return true  -- signal death
  end
  boss.hp     = PHASE_HP[boss.phase]
  boss.maxHp  = PHASE_HP[boss.phase]
  boss.comboCount  = 0
  boss.comboTimer  = 0
  boss.regenActive = false
  boss.phaseFlash  = 1.0
  -- Reset attack timers per phase
  if boss.phase == 2 then
    boss.attackTimer = 2.0
  elseif boss.phase == 3 then
    boss.attackTimer = 1.5
    boss.ringTimer   = 4.0
  end
  return false
end

-- ===================== BULLET HELPERS =====================

local function makeBossBullet(x, y, angle, speed, dmg, sz)
  return {
    x       = x,
    y       = y,
    vx      = math.cos(angle) * (speed or BOSS_BULLET_SPEED),
    vy      = math.sin(angle) * (speed or BOSS_BULLET_SPEED),
    lifetime = 3.5,
    owner   = "boss_messier",
    size    = sz  or BOSS_BULLET_SIZE,
    damage  = dmg or BOSS_BULLET_DAMAGE,
  }
end

-- Fire a radial burst of `count` bullets
local function fireRadialBurst(count, speed, dmg, sz)
  local bullets = {}
  for i = 1, count do
    local angle = (i / count) * math.pi * 2
    table.insert(bullets, makeBossBullet(boss.x, boss.y, angle, speed, dmg, sz))
  end
  return bullets
end

-- Fire aimed shot(s) at ship, with optional spread
local function fireAimed(ship, count, spreadArc, speed, dmg, sz)
  local bullets = {}
  local baseAngle = math.atan2(ship.y - boss.y, ship.x - boss.x)
  count = count or 1
  spreadArc = spreadArc or 0
  for i = 1, count do
    local offset = (count == 1) and 0 or (i / (count - 1) - 0.5) * spreadArc
    table.insert(bullets, makeBossBullet(boss.x, boss.y, baseAngle + offset, speed, dmg, sz))
  end
  return bullets
end

-- ===================== BOSS UPDATE =====================

local function updateBoss(dt, ship)
  if not boss or boss.dead then return {} end

  boss.time        = boss.time + dt
  boss.pulseAngle  = boss.pulseAngle  + dt * 2.5
  boss.ringAngle   = boss.ringAngle   + dt * (0.8 + (boss.phase - 1) * 0.4)
  boss.phaseFlash  = math.max(0, boss.phaseFlash - dt * 2)
  boss.flashTimer  = math.max(0, boss.flashTimer - dt)

  -- Phase 2: figure-8 drift
  if boss.phase == 2 then
    local t = boss.time * 0.5
    local r = 80
    boss.x = boss.centerX + math.sin(t)       * r
    boss.y = boss.centerY + math.sin(t * 2)   * (r * 0.5)
  -- Phase 3: fast orbit
  elseif boss.phase == 3 then
    boss.driftAngle = boss.driftAngle + 0.9 * dt
    local r = 100
    boss.x = boss.centerX + math.cos(boss.driftAngle) * r
    boss.y = boss.centerY + math.sin(boss.driftAngle) * r
  end

  -- Combo timer decay
  if boss.comboTimer > 0 then
    boss.comboTimer = boss.comboTimer - dt
    if boss.comboTimer <= 0 then
      boss.comboCount  = 0
      boss.regenActive = true
    end
  end

  -- HP regen when combo broken
  if boss.regenActive then
    boss.hp = math.min(boss.maxHp, boss.hp + REGEN_RATE[boss.phase] * dt)
  end

  -- Attack logic
  local newBullets = {}
  boss.attackTimer = boss.attackTimer - dt

  if boss.attackTimer <= 0 then
    if boss.phase == 1 then
      -- 12-way slow radial burst
      local b = fireRadialBurst(12, 160, BOSS_BULLET_DAMAGE, BOSS_BULLET_SIZE)
      for _, blt in ipairs(b) do table.insert(newBullets, blt) end
      boss.attackTimer = 3.0
    elseif boss.phase == 2 then
      -- Aimed shot + 3-way spread
      local b = fireAimed(ship, 3, math.pi / 6, 220, BOSS_BULLET_DAMAGE, BOSS_BULLET_SIZE)
      for _, blt in ipairs(b) do table.insert(newBullets, blt) end
      boss.attackTimer = 2.0
    elseif boss.phase == 3 then
      -- Aimed 5-shot burst
      local b = fireAimed(ship, 5, math.pi / 5, 260, BOSS_BULLET_DAMAGE, BOSS_BULLET_SIZE)
      for _, blt in ipairs(b) do table.insert(newBullets, blt) end
      boss.attackTimer = 1.5
    end
  end

  -- Phase 3 ring attack
  if boss.phase == 3 then
    boss.ringTimer = boss.ringTimer - dt
    if boss.ringTimer <= 0 then
      local b = fireRadialBurst(18, 180, BOSS_BULLET_DAMAGE, 4)
      for _, blt in ipairs(b) do table.insert(newBullets, blt) end
      boss.ringTimer = 4.0
    end
  end

  -- Update existing boss bullets
  for i = #boss.bullets, 1, -1 do
    local b = boss.bullets[i]
    b.x = b.x + b.vx * dt
    b.y = b.y + b.vy * dt
    b.lifetime = b.lifetime - dt
    if b.lifetime <= 0 then
      table.remove(boss.bullets, i)
    end
  end

  -- Add new bullets
  for _, blt in ipairs(newBullets) do
    table.insert(boss.bullets, blt)
  end

  return newBullets
end

-- ===================== BULLET vs BOSS COLLISION =====================

-- Returns total damage dealt this frame, updates combo state
local function checkPlayerBulletsVsBoss(playerBullets)
  if not boss or boss.dead then return end

  for i = #playerBullets, 1, -1 do
    local b = playerBullets[i]
    if b.owner == "player" then
      local dx = b.x - boss.x
      local dy = b.y - boss.y
      local dist = math.sqrt(dx*dx + dy*dy)
      local hitRadius = 38  -- boss collision radius
      if dist < hitRadius + (b.size or 2) then
        -- Compute combo-scaled damage
        local baseDmg = b.isHyper and BASE_DAMAGE_HYPER or BASE_DAMAGE_NORMAL
        local dmg = baseDmg * (DAMAGE_MULT ^ boss.comboCount)

        boss.hp         = boss.hp - dmg
        boss.comboCount = boss.comboCount + 1
        boss.comboTimer = COMBO_WINDOW
        boss.regenActive = false
        boss.flashTimer  = 0.08

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

-- ===================== PUBLIC API =====================

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

-- Called when the player tile transitions onto the boss tile.
-- Returns a powerup table for the Hyper Beam (or nil if already cleared/active).
function M.initTile(tileX, tileY, width, height)
  if not M.isBossTile(tileX, tileY) then return nil end
  if cleared then return nil end
  if state == "boss_fight" then return nil end

  state = "powerup_present"
  barrierAnim  = 0
  barrierAlpha = 0

  -- Return a powerup table for the Hyper Beam at the screen centre
  return {
    x            = width  / 2,
    y            = height / 2,
    type         = "hyperbeam",
    lifetime     = 9999,   -- permanent-style: won't expire
    rotation     = 0,
    size         = 18,
    collected    = false,
    collectTimer = 0,
    collectFlash = 0,
  }
end

-- Called when the player collects the Hyper Beam powerup.
function M.onHyperBeamCollected()
  if state ~= "powerup_present" then return end
  state = "boss_fight"
  barrierAnim  = 0
  barrierAlpha = 0
  barrierDeact = false
  -- Spawn boss (width/height captured from last initTile call — use screen dims)
  -- We stash them during initTile via the boss spawn below, but we need w/h here.
  -- Resolve: use Love2D's graphics dimensions directly.
  local w = love.graphics.getWidth()
  local h = love.graphics.getHeight()
  spawnBoss(w, h)
end

-- Called when player dies during boss fight.
function M.onPlayerDied()
  state = "powerup_present"
  boss  = nil
  barrierAlpha = 0
  barrierAnim  = 0
  barrierDeact = false
end

function M.deactivateBarriers()
  barrierDeact  = true
  barrierDeactT = 0
end

-- Main update. Returns result table: {bossBullets, bossDefeated}.
function M.update(dt, ship, bullets, width, height)
  if state ~= "boss_fight" then return nil end

  time = time + dt
  updateBarriers(dt)

  -- Check if boss finished its death animation
  if boss and boss.dead then
    boss.deathTimer = boss.deathTimer - dt
    boss.deathFlash = math.sin(boss.deathTimer * 10) * 0.5 + 0.5
    if boss.deathTimer <= 0 then
      state   = "boss_defeated"
      cleared = true
      boss    = nil
      M.deactivateBarriers()
      return {bossDefeated = true, bossBullets = {}}
    end
    return {bossBullets = {}}
  end

  -- Player-bullet vs boss collisions (modifies bullets table in-place)
  checkPlayerBulletsVsBoss(bullets)

  -- Boss AI update, get new boss bullets
  local newBullets = updateBoss(dt, ship)

  -- Bounce ship off screen edges when locked
  if M.isLocked() then
    local margin = 30
    if ship.x < margin then ship.x = margin; ship.vx = math.abs(ship.vx) end
    if ship.x > width  - margin then ship.x = width  - margin; ship.vx = -math.abs(ship.vx) end
    if ship.y < margin then ship.y = margin; ship.vy = math.abs(ship.vy) end
    if ship.y > height - margin then ship.y = height - margin; ship.vy = -math.abs(ship.vy) end
  end

  return {bossBullets = newBullets, bossDefeated = false}
end

-- ===================== DRAW =====================

function M.drawBackground(width, height)
  if state ~= "boss_fight" and state ~= "boss_defeated" then return end
  if not boss then return end

  -- Soft golden ambient glow behind boss
  local pulse = math.sin(boss.pulseAngle) * 0.5 + 0.5
  love.graphics.setColor(0.8, 0.6, 0.1, 0.06 + pulse * 0.04)
  love.graphics.circle("fill", boss.x, boss.y, 200 + pulse * 30)
  love.graphics.setColor(0.9, 0.75, 0.2, 0.04)
  love.graphics.circle("fill", boss.x, boss.y, 300)
end

-- Draw boss body, bullets, barriers
function M.drawForeground(width, height)
  if state ~= "boss_fight" and state ~= "boss_defeated" then return end

  -- Barriers
  if barrierAlpha > 0.01 then
    local ba = barrierAlpha
    local margin = 20
    love.graphics.setLineWidth(3)

    -- Four edges
    local edges = {
      {margin, margin, width - margin, margin},
      {width - margin, margin, width - margin, height - margin},
      {margin, height - margin, width - margin, height - margin},
      {margin, margin, margin, height - margin},
    }
    for _, e in ipairs(edges) do
      -- Outer glow
      love.graphics.setColor(0.9, 0.7, 0.2, ba * 0.3)
      love.graphics.setLineWidth(8)
      love.graphics.line(e[1], e[2], e[3], e[4])
      -- Core
      love.graphics.setColor(1.0, 0.85, 0.3, ba * 0.9)
      love.graphics.setLineWidth(2)
      love.graphics.line(e[1], e[2], e[3], e[4])
    end

    -- Corner diamonds
    local corners = {
      {margin, margin}, {width - margin, margin},
      {margin, height - margin}, {width - margin, height - margin},
    }
    for _, c in ipairs(corners) do
      love.graphics.setColor(1.0, 0.9, 0.4, ba)
      love.graphics.polygon("fill", c[1]-5, c[2], c[1], c[2]-5, c[1]+5, c[2], c[1], c[2]+5)
    end

    love.graphics.setLineWidth(1)
  end

  if not boss then return end

  -- Boss bullets
  for _, b in ipairs(boss.bullets) do
    local lifeRatio = b.lifetime / 3.5
    -- Outer glow
    love.graphics.setColor(0.9, 0.7, 0.1, lifeRatio * 0.4)
    love.graphics.circle("fill", b.x, b.y, b.size * 2.2)
    -- Core
    love.graphics.setColor(1.0, 0.9, 0.3, lifeRatio * 0.95)
    love.graphics.circle("fill", b.x, b.y, b.size)
  end

  -- Boss body
  if boss.dead then
    -- Death flash strobe
    local df = boss.deathFlash or 0
    love.graphics.setColor(1, 0.9, 0.5, df * 0.8)
    love.graphics.circle("fill", boss.x, boss.y, 50 + df * 20)
    love.graphics.setColor(1, 1, 1, df)
    love.graphics.circle("fill", boss.x, boss.y, 20)
    return
  end

  local pulse = math.sin(boss.pulseAngle) * 0.5 + 0.5
  local flashMod = boss.flashTimer > 0 and 1.0 or 0.0
  local pf = boss.phaseFlash or 0

  -- Outer glow ring
  love.graphics.setColor(0.8 + pf * 0.2, 0.65 + pf * 0.1, 0.1, 0.25 + pulse * 0.15)
  love.graphics.circle("fill", boss.x, boss.y, 55 + pulse * 8)

  -- Core sphere
  love.graphics.setColor(
    0.95 + flashMod * 0.05,
    0.75 + flashMod * 0.05 + pf * 0.15,
    0.15 + pf * 0.3,
    0.92
  )
  love.graphics.circle("fill", boss.x, boss.y, 36)

  -- Inner bright spot
  love.graphics.setColor(1.0, 0.95, 0.7, 0.6 + pulse * 0.25)
  love.graphics.circle("fill", boss.x - 8, boss.y - 8, 12)

  -- Orbiting decorative ring (3 nodes on a ring)
  love.graphics.setLineWidth(2)
  for i = 1, 3 do
    local a = boss.ringAngle + (i / 3) * math.pi * 2
    local rx = boss.x + math.cos(a) * 52
    local ry = boss.y + math.sin(a) * 52
    love.graphics.setColor(1.0, 0.85, 0.3, 0.7 + pulse * 0.2)
    love.graphics.circle("fill", rx, ry, 5)
    love.graphics.setColor(0.9, 0.7, 0.15, 0.4)
    love.graphics.circle("line", rx, ry, 8)
  end
  love.graphics.setLineWidth(1)
end

-- HUD: combo meter + HP bar + phase indicator
function M.drawHUD(width, height)
  if state ~= "boss_fight" then return end
  if not boss or boss.dead then return end

  local ui = require("asteroids.ui")

  -- Phase indicator top-center
  love.graphics.setFont(ui.getFont("hud"))
  local pf = boss.phaseFlash or 0
  love.graphics.setColor(1.0, 0.85 + pf * 0.1, 0.3, 0.85 + pf * 0.1)
  love.graphics.printf("PHASE " .. boss.phase .. " / 3", 0, 14, width, "center")

  -- Boss HP bar (center-top, below phase)
  local barW = 260
  local barH = 12
  local barX = (width - barW) / 2
  local barY = 36
  local hpRatio = math.max(0, boss.hp / boss.maxHp)

  -- Background
  love.graphics.setColor(0.15, 0.12, 0.05, 0.85)
  love.graphics.rectangle("fill", barX, barY, barW, barH, 3)
  -- HP fill (gold → red as HP drops)
  love.graphics.setColor(0.9 * hpRatio + (1 - hpRatio), 0.7 * hpRatio, 0.1 * hpRatio, 0.9)
  love.graphics.rectangle("fill", barX, barY, barW * hpRatio, barH, 3)
  -- Border
  love.graphics.setColor(0.9, 0.7, 0.25, 0.7)
  love.graphics.setLineWidth(1)
  love.graphics.rectangle("line", barX, barY, barW, barH, 3)

  -- Regen indicator
  if boss.regenActive then
    love.graphics.setFont(ui.getFont("hudSmall"))
    love.graphics.setColor(1.0, 0.6, 0.2, 0.85)
    love.graphics.print("REGEN", barX + barW + 6, barY)
  end

  -- Combo meter (bottom-right)
  local comboX = width - 190
  local comboY = height - 60
  love.graphics.setFont(ui.getFont("hudLabel"))
  love.graphics.setColor(0.8, 0.8, 0.8, 0.7)
  love.graphics.print("COMBO", comboX, comboY - 18)

  local cRatio = boss.comboTimer / COMBO_WINDOW
  local comboW = 160
  local comboH = 10
  -- Background
  love.graphics.setColor(0.1, 0.1, 0.1, 0.8)
  love.graphics.rectangle("fill", comboX, comboY, comboW, comboH, 3)
  -- Fill — cyan when active, dims to grey
  if boss.comboCount > 0 then
    love.graphics.setColor(0.2, 0.9, 1.0, 0.5 + cRatio * 0.4)
  else
    love.graphics.setColor(0.3, 0.35, 0.4, 0.4)
  end
  love.graphics.rectangle("fill", comboX, comboY, comboW * cRatio, comboH, 3)
  -- Border
  love.graphics.setColor(0.5, 0.7, 0.9, 0.5)
  love.graphics.rectangle("line", comboX, comboY, comboW, comboH, 3)

  -- Combo count
  if boss.comboCount > 0 then
    love.graphics.setFont(ui.getFont("hud"))
    love.graphics.setColor(0.3, 1.0, 1.0, 0.9)
    love.graphics.print("x" .. boss.comboCount, comboX + comboW + 8, comboY - 2)
  end
end

-- Acquisition banner (called from init.lua with a countdown timer)
function M.drawAcquisitionBanner(timer)
  if timer <= 0 then return end
  local ui = require("asteroids.ui")
  love.graphics.setFont(ui.getFont("medium"))
  local alpha = math.min(1, timer) * math.min(1, timer)
  love.graphics.setColor(0.3, 0.9, 1.0, alpha)
  love.graphics.printf("◈ HYPER BEAM ◈", 0, love.graphics.getHeight() / 2 - 30, love.graphics.getWidth(), "center")
  love.graphics.setFont(ui.getFont("hudSmall"))
  love.graphics.setColor(0.7, 0.95, 1.0, alpha * 0.7)
  love.graphics.printf("DEFEAT THE GUARDIAN TO KEEP IT", 0, love.graphics.getHeight() / 2 + 4, love.graphics.getWidth(), "center")
end

return M
