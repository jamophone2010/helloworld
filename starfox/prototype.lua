-- starfox/prototype.lua
-- The Prototype: An advanced experimental starfighter stolen from Hometown Station
-- Roaming boss encounter inspired by Entei from Pokemon Silver
-- Requires a ship with a special attack to break its shield

local M = {}

local screen = require("starfox.screen")
local particles = require("starfox.particles")
local ships = require("starfox.ships")

-- ═══════════════════════════════════════
-- QUEST STATE (persisted via save data)
-- ═══════════════════════════════════════
M.questStarted = false        -- Has the breach cutscene played?
M.questComplete = false       -- Has the player captured the Prototype?
M.firstLevelBeaten = false    -- Has Newton's Nebula (level 1) been beaten?
M.prototypeOnMap = false      -- Is the Prototype currently on the minimap?
M.prototypeMapX = 0           -- Grid position on minimap (sector-level)
M.prototypeMapY = 0           -- Grid position on minimap (sector-level)
M.defeatedCount = 0           -- Times the player has been defeated by the Prototype

-- ═══════════════════════════════════════
-- COMBAT STATE (runtime only)
-- ═══════════════════════════════════════
M.active = false              -- Is the Prototype currently in a combat encounter?
M.chasing = false             -- Is the Prototype chasing the player across sectors?
M.ship = nil                  -- The Prototype ship object during combat

-- Shield state
M.shieldActive = true         -- Prototype's shield is up
M.shieldHealth = 1            -- Shield breaks after 1 special attack hit
M.stunned = false             -- Is the Prototype stunned?
M.stunTimer = 0               -- Stun duration remaining
M.reflectedHits = 0           -- Number of reflected EMP hits on the Prototype

-- Defeat state
M.defeated = false            -- Has the Prototype been defeated this encounter?
M.defeatAnimTimer = 0         -- Animation timer for defeat sequence
M.escapePodLaunched = false   -- Has the pilot ejected?
M.shipPickupReady = false     -- Can the player fly over to collect?
M.shipPickupRotation = 0      -- Rotation animation for collectible ship
M.dialogueState = "none"      -- "pilot_dialogue", "pickup_ready", "collected"
M.dialogueText = ""
M.dialogueSpeaker = ""
M.dialogueQueue = {}
M.dialogueQueueIndex = 0

-- Warp escape state (when Prototype defeats the player)
M.warping = false
M.warpTimer = 0
M.warpParticles = {}

-- Visual effects
M.shieldPulse = 0
M.empParticles = {}
M.engineGlow = 0

-- ═══════════════════════════════════════
-- PROTOTYPE SHIP DEFINITION
-- ═══════════════════════════════════════
local PROTOTYPE_DEF = {
  name = "Prototype",
  type = "Experimental",
  color = {0.1, 0.1, 0.15},
  accentColor = {0.0, 0.8, 1.0},
  shieldColor = {0.3, 0.6, 1.0},
  empColor = {0.2, 0.5, 1.0},
  width = 50,
  height = 40,
  health = 200,
  maxHealth = 200,
  speed = 280,
  laserDamage = 50,      -- 1/2 of player's base 100 health
  empStunDuration = 3,    -- seconds
  fullStunDuration = 10,  -- seconds after 3 reflected hits
  score = 0,              -- No score, quest reward instead
}

-- ═══════════════════════════════════════
-- MINIMAP TRACKING (Entei-style roaming)
-- ═══════════════════════════════════════

-- Spawn the Prototype on a random map tile
function M.trySpawnOnMap()
  if M.questComplete then return false end
  if not M.questStarted then return false end
  if not M.firstLevelBeaten then return false end
  if M.prototypeOnMap then return false end

  -- 1/5 chance of appearing
  if math.random(1, 5) ~= 1 then return false end

  -- Spawn on a random tile (minimap is roughly 20x20 grid)
  M.prototypeMapX = math.random(1, 20)
  M.prototypeMapY = math.random(1, 20)
  M.prototypeOnMap = true

  -- Map the position to a sector index for level select display
  -- Sectors 2-15 are valid (skip 0=Station, 1=Newton's Nebula which is "home")
  -- Won't appear in Hub sector (0) or Hometown sectors
  M.prototypeMapSector = math.random(2, 15)

  return true
end

-- Move the Prototype one square on the minimap (called when player moves)
function M.moveOnMap()
  if not M.prototypeOnMap then return end
  if M.questComplete then return end
  if M.stunned then
    -- When stunned, move away from where the player is conceptually
    -- (just pick a random direction that isn't toward the player)
    return
  end

  -- Move randomly one square (cardinal directions only, no diagonal)
  local dirs = {{0, -1}, {0, 1}, {-1, 0}, {1, 0}}
  local dir = dirs[math.random(1, 4)]
  M.prototypeMapX = math.max(1, math.min(20, M.prototypeMapX + dir[1]))
  M.prototypeMapY = math.max(1, math.min(20, M.prototypeMapY + dir[2]))

  -- Randomly shift sector (the Prototype roams between sectors)
  if math.random(1, 3) == 1 then
    local sectorShift = math.random(-1, 1)
    M.prototypeMapSector = math.max(2, math.min(15, (M.prototypeMapSector or 2) + sectorShift))
  end
end

-- Reset minimap position (when player teleports, returns to station, etc.)
function M.resetMapPosition()
  if M.questComplete then return end
  M.prototypeOnMap = false
  -- Will need to re-roll for appearance after beating a level
end

-- Check if player is on the same map tile as the Prototype
function M.isPlayerOnPrototype(playerMapX, playerMapY)
  if not M.prototypeOnMap then return false end
  if M.questComplete then return false end
  return M.prototypeMapX == playerMapX and M.prototypeMapY == playerMapY
end

-- ═══════════════════════════════════════
-- COMBAT ENCOUNTER
-- ═══════════════════════════════════════

function M.startEncounter()
  M.active = true
  M.chasing = true
  M.defeated = false
  M.defeatAnimTimer = 0
  M.escapePodLaunched = false
  M.shipPickupReady = false
  M.shipPickupRotation = 0
  M.dialogueState = "none"
  M.warping = false
  M.warpTimer = 0

  -- Reset combat state
  M.shieldActive = true
  M.stunned = false
  M.stunTimer = 0
  M.reflectedHits = 0
  M.shieldPulse = 0
  M.empParticles = {}
  M.engineGlow = 0

  -- Create the Prototype ship
  M.ship = {
    x = screen.WIDTH / 2,
    y = -60,
    vx = 0,
    vy = 0,
    width = PROTOTYPE_DEF.width,
    height = PROTOTYPE_DEF.height,
    health = PROTOTYPE_DEF.maxHealth,
    maxHealth = PROTOTYPE_DEF.maxHealth,
    speed = PROTOTYPE_DEF.speed,
    shootTimer = 0,
    empShootTimer = 0,
    empCooldown = 2.0,
    laserCooldown = 1.5,
    aiState = "entering",
    aiTimer = 0,
    targetX = screen.WIDTH / 2,
    targetY = 150,
    strafeDir = 1,
    active = true,
  }
end

function M.endEncounter()
  M.active = false
  M.ship = nil
  M.empParticles = {}
end

-- Called when the Prototype defeats the player
function M.onPlayerDefeated()
  if not M.active then return end
  M.warping = true
  M.warpTimer = 0
  M.prototypeOnMap = false  -- Disappear from minimap
  M.defeatedCount = M.defeatedCount + 1
end

--- Called when the level ends in victory while Prototype is still active
-- The Prototype flees but stays on the map
function M.flee()
  if not M.active then return end
  M.warping = true
  M.warpTimer = 0
  -- Prototype stays on map — it just escapes this encounter
end

-- ═══════════════════════════════════════
-- AI & UPDATE
-- ═══════════════════════════════════════

function M.update(dt, playerX, playerY, playerStunned)
  if not M.active or not M.ship then return end

  M.shieldPulse = M.shieldPulse + dt * 3
  M.engineGlow = M.engineGlow + dt * 5

  -- Update stun
  if M.stunned then
    M.stunTimer = M.stunTimer - dt
    if M.stunTimer <= 0 then
      M.stunned = false
      M.stunTimer = 0
    end
    -- When stunned, drift slowly
    M.ship.x = M.ship.x + math.sin(M.shieldPulse) * 20 * dt
    M.updateEmpParticles(dt)
    return
  end

  -- Warp escape animation
  if M.warping then
    M.warpTimer = M.warpTimer + dt
    M.ship.y = M.ship.y - 400 * dt
    -- Spawn warp particles
    if math.random() < 0.5 then
      table.insert(M.warpParticles, {
        x = M.ship.x + (math.random() - 0.5) * 60,
        y = M.ship.y + (math.random() - 0.5) * 40,
        vx = (math.random() - 0.5) * 200,
        vy = math.random() * 300 + 200,
        life = 0.5,
        maxLife = 0.5,
        color = {0.0, 0.8, 1.0}
      })
    end
    -- Update warp particles
    for i = #M.warpParticles, 1, -1 do
      local p = M.warpParticles[i]
      p.x = p.x + p.vx * dt
      p.y = p.y + p.vy * dt
      p.life = p.life - dt
      if p.life <= 0 then table.remove(M.warpParticles, i) end
    end
    if M.warpTimer >= 2.0 then
      M.endEncounter()
    end
    return
  end

  -- Defeat sequence
  if M.defeated then
    M.defeatAnimTimer = M.defeatAnimTimer + dt
    if M.dialogueState == "none" and M.defeatAnimTimer >= 1.0 then
      -- Pilot speaks
      M.dialogueState = "pilot_dialogue"
      M.dialogueQueue = {
        "OK, ok, you win. You can take your lousy ship back.",
        "But this galaxy isn't really a place like you think it is."
      }
      M.dialogueQueueIndex = 1
      M.dialogueSpeaker = "???"
      M.dialogueText = M.dialogueQueue[1]
    end
    if M.dialogueState == "escape_pod" then
      -- Escape pod animation
      M.ship.y = M.ship.y  -- Ship stays in place
      M.shipPickupRotation = M.shipPickupRotation + dt * 2
      if M.defeatAnimTimer >= 3.0 and not M.shipPickupReady then
        M.shipPickupReady = true
        M.dialogueState = "pickup_ready"
      end
    end
    M.updateEmpParticles(dt)
    return
  end

  -- AI movement
  local ship = M.ship

  if ship.aiState == "entering" then
    -- Fly in from above
    ship.y = ship.y + 150 * dt
    if ship.y >= ship.targetY then
      ship.y = ship.targetY
      ship.aiState = "combat"
      ship.aiTimer = 0
    end
  elseif ship.aiState == "combat" then
    ship.aiTimer = ship.aiTimer + dt

    -- Strafe toward player X position
    local dx = playerX - ship.x
    if math.abs(dx) > 20 then
      ship.x = ship.x + (dx > 0 and 1 or -1) * ship.speed * 0.5 * dt
    end

    -- Occasional vertical movement
    local targetY = 100 + math.sin(ship.aiTimer * 0.8) * 80
    local dy = targetY - ship.y
    ship.y = ship.y + dy * 2 * dt

    -- Shooting
    ship.shootTimer = ship.shootTimer - dt
    ship.empShootTimer = ship.empShootTimer - dt

    -- Clamp position
    ship.x = math.max(ship.width, math.min(screen.WIDTH - ship.width, ship.x))
    ship.y = math.max(50, math.min(300, ship.y))
  end

  M.updateEmpParticles(dt)
end

function M.updateEmpParticles(dt)
  for i = #M.empParticles, 1, -1 do
    local p = M.empParticles[i]
    p.x = p.x + p.vx * dt
    p.y = p.y + p.vy * dt
    p.life = p.life - dt
    -- Electric arc effect
    p.arcTimer = (p.arcTimer or 0) + dt
    if p.arcTimer > 0.05 then
      p.arcTimer = 0
      p.arcOffsetX = (math.random() - 0.5) * 8
      p.arcOffsetY = (math.random() - 0.5) * 8
    end
    if p.life <= 0 then table.remove(M.empParticles, i) end
  end
end

-- ═══════════════════════════════════════
-- PROJECTILES
-- ═══════════════════════════════════════

-- Get pending projectiles for the weapon system to create
function M.getPendingProjectiles(playerX, playerY)
  local projectiles = {}
  if not M.active or not M.ship or M.stunned or M.defeated or M.warping then
    return projectiles
  end

  local ship = M.ship

  -- EMP stun bullets (blue with electric effects)
  if ship.empShootTimer <= 0 then
    ship.empShootTimer = ship.empCooldown
    local dx = playerX - ship.x
    local dy = playerY - ship.y
    local dist = math.sqrt(dx * dx + dy * dy)
    if dist > 0 then
      dx = dx / dist
      dy = dy / dist
    else
      dy = 1
    end
    table.insert(projectiles, {
      type = "emp",
      x = ship.x,
      y = ship.y + ship.height / 2,
      vx = dx * 350,
      vy = dy * 350,
      damage = 0,  -- EMP doesn't damage, only stuns
      stunDuration = PROTOTYPE_DEF.empStunDuration,
      width = 10,
      height = 10,
      owner = "prototype",
      reflectable = true,  -- Can be reflected back
    })
    -- Spawn electric particles at barrel
    M.spawnEmpBurstAt(ship.x, ship.y + ship.height / 2)
  end

  -- Normal lasers (do 1/2 of player's base health)
  if ship.shootTimer <= 0 then
    ship.shootTimer = ship.laserCooldown
    local dx = playerX - ship.x
    local dy = playerY - ship.y
    local dist = math.sqrt(dx * dx + dy * dy)
    if dist > 0 then
      dx = dx / dist
      dy = dy / dist
    else
      dy = 1
    end
    -- Fire twin lasers
    table.insert(projectiles, {
      type = "laser",
      x = ship.x - 15,
      y = ship.y + ship.height / 2,
      vx = dx * 400,
      vy = dy * 400,
      damage = PROTOTYPE_DEF.laserDamage,
      width = 6,
      height = 6,
      owner = "prototype",
      reflectable = true,
    })
    table.insert(projectiles, {
      type = "laser",
      x = ship.x + 15,
      y = ship.y + ship.height / 2,
      vx = dx * 400,
      vy = dy * 400,
      damage = PROTOTYPE_DEF.laserDamage,
      width = 6,
      height = 6,
      owner = "prototype",
      reflectable = true,
    })
  end

  return projectiles
end

function M.spawnEmpBurstAt(x, y)
  for i = 1, 8 do
    local angle = math.random() * math.pi * 2
    local speed = math.random() * 100 + 50
    table.insert(M.empParticles, {
      x = x,
      y = y,
      vx = math.cos(angle) * speed,
      vy = math.sin(angle) * speed,
      life = 0.4,
      maxLife = 0.4,
      arcOffsetX = 0,
      arcOffsetY = 0,
      arcTimer = 0,
    })
  end
end

-- ═══════════════════════════════════════
-- DAMAGE & SHIELD
-- ═══════════════════════════════════════

-- Called when a player's special attack hits the Prototype
function M.onSpecialAttackHit()
  if not M.active or not M.ship then return false end
  if not M.shieldActive then return false end

  -- Special attack breaks the shield
  M.shieldActive = false
  -- Big shield break effect
  for i = 1, 30 do
    local angle = math.random() * math.pi * 2
    local speed = math.random() * 200 + 100
    table.insert(M.empParticles, {
      x = M.ship.x,
      y = M.ship.y,
      vx = math.cos(angle) * speed,
      vy = math.sin(angle) * speed,
      life = 0.8,
      maxLife = 0.8,
      arcOffsetX = 0,
      arcOffsetY = 0,
      arcTimer = 0,
    })
  end
  return true
end

-- Called when a reflected EMP hits the Prototype
function M.onReflectedEmpHit()
  if not M.active or not M.ship then return end

  M.reflectedHits = M.reflectedHits + 1

  if M.reflectedHits >= 3 then
    -- Full stun for 10 seconds
    M.stunned = true
    M.stunTimer = PROTOTYPE_DEF.fullStunDuration
    M.reflectedHits = 0
    -- Big stun effect
    M.spawnEmpBurstAt(M.ship.x, M.ship.y)
    M.spawnEmpBurstAt(M.ship.x, M.ship.y)
  else
    -- Brief stagger
    M.stunned = true
    M.stunTimer = 1.0
    M.spawnEmpBurstAt(M.ship.x, M.ship.y)
  end
end

-- Called when a normal reflected laser hits the Prototype (shield must be down)
function M.damage(amount)
  if not M.active or not M.ship then return false end

  -- If shield is up, damage bounces off harmlessly
  if M.shieldActive then
    -- Visual bounce effect
    particles.spawn(M.ship.x, M.ship.y, 5, PROTOTYPE_DEF.shieldColor)
    return false
  end

  M.ship.health = M.ship.health - amount
  particles.spawn(M.ship.x, M.ship.y, 8, {1, 0.5, 0})

  if M.ship.health <= 0 then
    M.ship.health = 0
    M.defeated = true
    M.defeatAnimTimer = 0
    M.dialogueState = "none"
    return true
  end
  return false
end

-- ═══════════════════════════════════════
-- DIALOGUE INTERACTION
-- ═══════════════════════════════════════

function M.advanceDialogue()
  if M.dialogueState == "pilot_dialogue" then
    if M.dialogueQueueIndex < #M.dialogueQueue then
      M.dialogueQueueIndex = M.dialogueQueueIndex + 1
      M.dialogueText = M.dialogueQueue[M.dialogueQueueIndex]
      return true
    else
      -- Pilot done talking, launch escape pod
      M.dialogueState = "escape_pod"
      M.dialogueText = ""
      M.defeatAnimTimer = 0
      return true
    end
  elseif M.dialogueState == "pickup_ready" then
    -- Player acknowledged, waiting for flyover
    return false
  end
  return false
end

function M.hasDialogue()
  return M.dialogueState == "pilot_dialogue"
end

-- Check if player ship overlaps the collectible Prototype
function M.checkPickup(playerX, playerY, playerWidth, playerHeight)
  if not M.shipPickupReady or not M.ship then return false end

  local dx = math.abs(playerX - M.ship.x)
  local dy = math.abs(playerY - M.ship.y)
  if dx < (playerWidth + M.ship.width) / 2 and dy < (playerHeight + M.ship.height) / 2 then
    M.dialogueState = "collected"
    return true
  end
  return false
end

function M.completeQuest()
  M.questComplete = true
  M.prototypeOnMap = false
  M.active = false
end

-- ═══════════════════════════════════════
-- DRAWING
-- ═══════════════════════════════════════

function M.draw()
  if not M.active or not M.ship then return end

  local ship = M.ship
  local def = PROTOTYPE_DEF

  love.graphics.push()
  love.graphics.translate(ship.x, ship.y)

  -- Pickup rotation if defeated and collectible
  if M.shipPickupReady then
    love.graphics.rotate(M.shipPickupRotation)
    -- Golden glow
    local glowPulse = 0.5 + 0.3 * math.sin(M.shipPickupRotation * 3)
    love.graphics.setColor(1, 0.9, 0.3, glowPulse * 0.3)
    love.graphics.circle("fill", 0, 0, 60)
    love.graphics.setColor(1, 0.9, 0.3, glowPulse * 0.15)
    love.graphics.circle("fill", 0, 0, 90)
  end

  -- Engine glow
  local pulse = math.sin(M.engineGlow) * 0.15 + 0.85
  if not M.defeated then
    love.graphics.setColor(def.accentColor[1], def.accentColor[2], def.accentColor[3], 0.2 * pulse)
    love.graphics.circle("fill", 0, 25, 35)

    -- Engine flame
    love.graphics.setColor(0.0, 0.7, 1.0, 0.7 * pulse)
    love.graphics.polygon("fill", -6, 20, 0, 40 + math.sin(M.engineGlow * 3) * 6, 6, 20)
    love.graphics.setColor(0.5, 0.9, 1.0, 0.5 * pulse)
    love.graphics.polygon("fill", -3, 20, 0, 32 + math.sin(M.engineGlow * 4) * 4, 3, 20)
  end

  -- Main body - dark angular stealth design
  love.graphics.setColor(def.color[1], def.color[2], def.color[3])
  love.graphics.polygon("fill", 0, -30, -22, 20, 22, 20)

  -- Stealth paneling
  love.graphics.setColor(0.15, 0.15, 0.2)
  love.graphics.polygon("fill", 0, -25, -10, 5, 10, 5)

  -- Angular swept wings
  love.graphics.setColor(0.08, 0.08, 0.12)
  love.graphics.polygon("fill", -18, 5, -55, 18, -55, 24, -18, 20)
  love.graphics.polygon("fill", 18, 5, 55, 18, 55, 24, 18, 20)

  -- Wing edge glow
  love.graphics.setColor(def.accentColor[1], def.accentColor[2], def.accentColor[3], 0.6)
  love.graphics.setLineWidth(1.5)
  love.graphics.line(-18, 5, -55, 18)
  love.graphics.line(18, 5, 55, 18)

  -- Cockpit
  love.graphics.setColor(0.0, 0.6, 1.0, 0.8)
  love.graphics.polygon("fill", 0, -20, -5, -5, 5, -5)

  -- Accent stripe
  love.graphics.setColor(def.accentColor[1], def.accentColor[2], def.accentColor[3], 0.9)
  love.graphics.setLineWidth(2)
  love.graphics.line(0, -28, 0, 18)
  love.graphics.setLineWidth(1)

  -- Outline
  love.graphics.setColor(def.accentColor[1], def.accentColor[2], def.accentColor[3], 0.3)
  love.graphics.setLineWidth(1)
  love.graphics.polygon("line", 0, -30, -22, 20, 22, 20)

  love.graphics.pop()

  -- Shield effect (drawn over the ship)
  if M.shieldActive and not M.defeated then
    local shieldAlpha = 0.15 + 0.1 * math.sin(M.shieldPulse)
    love.graphics.setColor(def.shieldColor[1], def.shieldColor[2], def.shieldColor[3], shieldAlpha)
    love.graphics.circle("fill", ship.x, ship.y, 45)
    -- Shield rings
    love.graphics.setColor(def.shieldColor[1], def.shieldColor[2], def.shieldColor[3], 0.4 + 0.2 * math.sin(M.shieldPulse * 1.5))
    love.graphics.setLineWidth(2)
    love.graphics.circle("line", ship.x, ship.y, 45 + math.sin(M.shieldPulse) * 3)
    love.graphics.setColor(def.shieldColor[1], def.shieldColor[2], def.shieldColor[3], 0.2)
    love.graphics.circle("line", ship.x, ship.y, 50 + math.sin(M.shieldPulse * 0.7) * 5)
    love.graphics.setLineWidth(1)

    -- Hexagonal shield pattern
    local hexRadius = 42
    for i = 0, 5 do
      local a1 = (i / 6) * math.pi * 2 + M.shieldPulse * 0.3
      local a2 = ((i + 1) / 6) * math.pi * 2 + M.shieldPulse * 0.3
      love.graphics.setColor(def.shieldColor[1], def.shieldColor[2], def.shieldColor[3], 0.15 + 0.1 * math.sin(M.shieldPulse + i))
      love.graphics.line(
        ship.x + math.cos(a1) * hexRadius, ship.y + math.sin(a1) * hexRadius,
        ship.x + math.cos(a2) * hexRadius, ship.y + math.sin(a2) * hexRadius
      )
    end
  end

  -- Stun effect
  if M.stunned then
    -- Electric arcs around the ship
    love.graphics.setColor(0.2, 0.5, 1.0, 0.6)
    love.graphics.setLineWidth(2)
    for i = 1, 6 do
      local angle = (i / 6) * math.pi * 2 + M.shieldPulse
      local r = 30 + math.random() * 15
      local x1 = ship.x + math.cos(angle) * r
      local y1 = ship.y + math.sin(angle) * r
      local x2 = ship.x + math.cos(angle + 0.5) * (r + math.random() * 10)
      local y2 = ship.y + math.sin(angle + 0.5) * (r + math.random() * 10)
      love.graphics.line(x1, y1, x2, y2)
    end
    love.graphics.setLineWidth(1)

    -- Stun timer display
    love.graphics.setColor(0.2, 0.5, 1.0, 0.8)
    local font = love.graphics.newFont(12)
    love.graphics.setFont(font)
    love.graphics.printf(string.format("STUNNED %.1fs", M.stunTimer), ship.x - 50, ship.y - 55, 100, "center")
  end

  -- EMP particles
  for _, p in ipairs(M.empParticles) do
    local alpha = p.life / p.maxLife
    love.graphics.setColor(0.2, 0.5, 1.0, alpha * 0.8)
    love.graphics.circle("fill", p.x + (p.arcOffsetX or 0), p.y + (p.arcOffsetY or 0), 3)
    -- Electric arc trail
    love.graphics.setColor(0.4, 0.7, 1.0, alpha * 0.4)
    love.graphics.circle("fill", p.x, p.y, 1.5)
  end

  -- Warp escape particles
  for _, p in ipairs(M.warpParticles) do
    local alpha = p.life / p.maxLife
    love.graphics.setColor(p.color[1], p.color[2], p.color[3], alpha)
    love.graphics.circle("fill", p.x, p.y, 3)
  end

  -- Defeat dialogue box
  if M.dialogueState == "pilot_dialogue" and M.dialogueText ~= "" then
    M.drawDialogue()
  end
end

function M.drawDialogue()
  local screenW = screen.WIDTH
  local screenH = screen.HEIGHT

  local boxX = 80
  local boxY = screenH - 180
  local boxW = screenW - 160
  local boxH = 130

  -- Box background
  love.graphics.setColor(0.02, 0.02, 0.06, 0.95)
  love.graphics.rectangle("fill", boxX, boxY, boxW, boxH, 6)

  -- Neon border
  love.graphics.setColor(0.2, 0.5, 1.0, 0.7)
  love.graphics.setLineWidth(2)
  love.graphics.rectangle("line", boxX, boxY, boxW, boxH, 6)

  -- Speaker name
  local nameFont = love.graphics.newFont(22)
  love.graphics.setFont(nameFont)
  love.graphics.setColor(0.2, 0.7, 1.0)
  love.graphics.print(M.dialogueSpeaker, boxX + 20, boxY + 12)

  -- Text
  local textFont = love.graphics.newFont("fonts/Exo2-Regular.ttf", 16)
  love.graphics.setFont(textFont)
  love.graphics.setColor(0.9, 0.9, 0.95)
  love.graphics.printf(M.dialogueText, boxX + 20, boxY + 45, boxW - 40, "left")

  -- Advance hint
  local pulse = 0.4 + 0.4 * math.sin(love.timer.getTime() * 3)
  local hintFont = love.graphics.newFont(12)
  love.graphics.setFont(hintFont)
  love.graphics.setColor(0.5, 0.5, 0.6, pulse)
  love.graphics.print("Press ENTER to continue", boxX + 20, boxY + boxH - 25)
end

-- Draw minimap beacon
function M.drawMinimapBeacon(mapX, mapY, tileSize, offsetX, offsetY, time)
  if not M.prototypeOnMap or M.questComplete then return end

  local bx = offsetX + (M.prototypeMapX - 1) * tileSize + tileSize / 2
  local by = offsetY + (M.prototypeMapY - 1) * tileSize + tileSize / 2

  -- Yellow beacon glow
  local pulse = 0.6 + 0.3 * math.sin((time or 0) * 4)
  love.graphics.setColor(1, 0.9, 0.2, 0.2 * pulse)
  love.graphics.circle("fill", bx, by, tileSize * 0.8)

  -- Beacon dot
  love.graphics.setColor(1, 0.9, 0.2, pulse)
  love.graphics.circle("fill", bx, by, tileSize * 0.3)

  -- Small ship icon
  love.graphics.setColor(1, 0.9, 0.2, 0.9)
  love.graphics.polygon("fill",
    bx, by - tileSize * 0.25,
    bx - tileSize * 0.15, by + tileSize * 0.15,
    bx + tileSize * 0.15, by + tileSize * 0.15
  )

  -- Beacon ring
  love.graphics.setColor(1, 0.9, 0.2, 0.3 * pulse)
  love.graphics.setLineWidth(1)
  love.graphics.circle("line", bx, by, tileSize * 0.5 + math.sin((time or 0) * 3) * 2)
end

-- Draw EMP laser projectile (blue with electric effects)
function M.drawEmpLaser(laser, time)
  -- Core
  love.graphics.setColor(0.2, 0.5, 1.0, 0.9)
  love.graphics.circle("fill", laser.x, laser.y, 5)

  -- Electric glow
  love.graphics.setColor(0.3, 0.6, 1.0, 0.4)
  love.graphics.circle("fill", laser.x, laser.y, 10)

  -- Arcing electricity
  love.graphics.setColor(0.5, 0.8, 1.0, 0.6)
  love.graphics.setLineWidth(1.5)
  for i = 1, 4 do
    local angle = (i / 4) * math.pi * 2 + (time or 0) * 10
    local r = 6 + math.random() * 4
    local ex = laser.x + math.cos(angle) * r
    local ey = laser.y + math.sin(angle) * r
    love.graphics.line(laser.x, laser.y, ex, ey)
  end
  love.graphics.setLineWidth(1)

  -- Trail
  local trailLen = 3
  local dx = -laser.vx * 0.02
  local dy = -laser.vy * 0.02
  for i = 1, trailLen do
    local alpha = (trailLen - i + 1) / trailLen * 0.3
    love.graphics.setColor(0.2, 0.5, 1.0, alpha)
    love.graphics.circle("fill", laser.x + dx * i, laser.y + dy * i, 3)
  end
end

-- Draw the full-screen Prototype acquisition screen
function M.drawAcquisitionScreen(time)
  local screenW = screen.WIDTH
  local screenH = screen.HEIGHT

  -- Dark background with radial gradient
  love.graphics.setColor(0, 0, 0, 0.95)
  love.graphics.rectangle("fill", 0, 0, screenW, screenH)

  -- Radial glow
  local glowPulse = 0.3 + 0.1 * math.sin((time or 0) * 2)
  love.graphics.setColor(0.0, 0.3, 0.6, glowPulse)
  love.graphics.circle("fill", screenW / 2, screenH * 0.4, 200)
  love.graphics.setColor(0.0, 0.2, 0.4, glowPulse * 0.5)
  love.graphics.circle("fill", screenW / 2, screenH * 0.4, 300)

  -- Draw the Prototype ship (large, centered, rotating)
  love.graphics.push()
  love.graphics.translate(screenW / 2, screenH * 0.4)
  local scale = 4.0
  love.graphics.scale(scale, scale)
  love.graphics.rotate(math.sin((time or 0) * 0.5) * 0.1)

  -- Ship body
  love.graphics.setColor(0.1, 0.1, 0.15)
  love.graphics.polygon("fill", 0, -30, -22, 20, 22, 20)
  love.graphics.setColor(0.15, 0.15, 0.2)
  love.graphics.polygon("fill", 0, -25, -10, 5, 10, 5)
  love.graphics.setColor(0.08, 0.08, 0.12)
  love.graphics.polygon("fill", -18, 5, -55, 18, -55, 24, -18, 20)
  love.graphics.polygon("fill", 18, 5, 55, 18, 55, 24, 18, 20)
  love.graphics.setColor(0.0, 0.8, 1.0, 0.6)
  love.graphics.setLineWidth(1.5 / scale)
  love.graphics.line(-18, 5, -55, 18)
  love.graphics.line(18, 5, 55, 18)
  love.graphics.setColor(0.0, 0.6, 1.0, 0.8)
  love.graphics.polygon("fill", 0, -20, -5, -5, 5, -5)
  love.graphics.setColor(0.0, 0.8, 1.0, 0.9)
  love.graphics.setLineWidth(2 / scale)
  love.graphics.line(0, -28, 0, 18)
  love.graphics.setLineWidth(1)

  love.graphics.pop()

  -- "Huzzah!" text
  local titleFont = love.graphics.newFont(36)
  love.graphics.setFont(titleFont)
  love.graphics.setColor(1, 0.9, 0.3)
  love.graphics.printf("Huzzah!", 0, screenH * 0.65, screenW, "center")

  -- Subtitle
  local subFont = love.graphics.newFont(20)
  love.graphics.setFont(subFont)
  love.graphics.setColor(0.0, 0.8, 1.0)
  love.graphics.printf("The Prototype has been added to your Hangar.", 0, screenH * 0.72, screenW, "center")

  -- Continue prompt
  local pulse = 0.4 + 0.4 * math.sin((time or 0) * 3)
  local hintFont = love.graphics.newFont(14)
  love.graphics.setFont(hintFont)
  love.graphics.setColor(0.5, 0.5, 0.6, pulse)
  love.graphics.printf("Press ENTER to continue", 0, screenH * 0.85, screenW, "center")
end

-- ═══════════════════════════════════════
-- SAVE/LOAD
-- ═══════════════════════════════════════

function M.getSaveData()
  return {
    questStarted = M.questStarted,
    questComplete = M.questComplete,
    firstLevelBeaten = M.firstLevelBeaten,
    prototypeOnMap = M.prototypeOnMap,
    prototypeMapX = M.prototypeMapX,
    prototypeMapY = M.prototypeMapY,
    prototypeMapSector = M.prototypeMapSector,
    defeatedCount = M.defeatedCount,
  }
end

function M.loadSaveData(data)
  if not data then return end
  M.questStarted = data.questStarted or false
  M.questComplete = data.questComplete or false
  M.firstLevelBeaten = data.firstLevelBeaten or false
  M.prototypeOnMap = data.prototypeOnMap or false
  M.prototypeMapX = data.prototypeMapX or 0
  M.prototypeMapY = data.prototypeMapY or 0
  M.prototypeMapSector = data.prototypeMapSector or nil
  M.defeatedCount = data.defeatedCount or 0
end

function M.reset()
  M.active = false
  M.chasing = false
  M.ship = nil
  M.shieldActive = true
  M.stunned = false
  M.stunTimer = 0
  M.reflectedHits = 0
  M.defeated = false
  M.defeatAnimTimer = 0
  M.escapePodLaunched = false
  M.shipPickupReady = false
  M.shipPickupRotation = 0
  M.dialogueState = "none"
  M.dialogueText = ""
  M.dialogueSpeaker = ""
  M.dialogueQueue = {}
  M.dialogueQueueIndex = 0
  M.warping = false
  M.warpTimer = 0
  M.warpParticles = {}
  M.shieldPulse = 0
  M.empParticles = {}
  M.engineGlow = 0
end

function M.isActive()
  return M.active
end

function M.isDefeated()
  return M.defeated
end

function M.getShip()
  return M.ship
end

function M.getDef()
  return PROTOTYPE_DEF
end

return M
