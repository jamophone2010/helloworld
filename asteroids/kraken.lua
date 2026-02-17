-- asteroids/kraken.lua
-- The Kraken: a legendary boss encounter in Outer Space rings 4 and 5.
-- A massive space octopus with 8 animated tentacles, aliasing shimmer effect,
-- and 3 distinct phases. Defeating it awards The Trident.

local M = {}

local particle = require("asteroids.particle")

-- ===================== KRAKEN CONSTANTS =====================

local BODY_RADIUS = 60
local TENTACLE_COUNT = 8
local TENTACLE_LENGTH = 120       -- max length per tentacle
local TENTACLE_SEGMENTS = 12       -- segments per tentacle
local SEGMENT_LENGTH = TENTACLE_LENGTH / TENTACLE_SEGMENTS

-- Phase thresholds (% of max health)
local PHASE_2_THRESHOLD = 0.66   -- Phase 2 at 66% health
local PHASE_3_THRESHOLD = 0.33   -- Phase 3 at 33% health

-- ===================== KRAKEN STATE =====================

function M.new(screenW, screenH)
  local k = {
    active = false,
    defeated = false,

    -- Position (spawns off-screen, drifts in)
    x = screenW / 2,
    y = -200,
    targetX = screenW / 2,
    targetY = screenH * 0.35,
    entryTimer = 0,
    entryDuration = 3.0,
    entered = false,

    -- Health
    health = 200,
    maxHealth = 200,
    phase = 1,            -- 1, 2, or 3
    phaseTransition = false,
    phaseTransTimer = 0,
    phaseTransDuration = 2.0,

    -- Movement
    driftAngle = 0,
    driftSpeed = 30,
    driftTimer = 0,

    -- Body
    bodyRadius = BODY_RADIUS,
    bodyPulse = 0,
    bodyColor = {0.15, 0.5, 0.45},
    eyeColor = {0.9, 0.1, 0.2},
    eyePupilAngle = 0,

    -- Tentacles (array of tentacle data)
    tentacles = {},

    -- Aliasing shimmer effect
    aliasTimer = 0,
    aliasIntensity = 0.3,    -- grows with phases
    aliasOffsets = {},        -- pixel offsets for shimmer

    -- Combat timers
    attackTimer = 0,
    attackCooldown = 3.0,
    currentAttack = nil,

    -- Phase 1: Ink Spray
    inkClouds = {},

    -- Phase 2: Tentacle Slam
    slamTentacle = nil,
    slamTimer = 0,
    slamPhase = "none",  -- "windup", "slam", "recover"

    -- Phase 3: Vortex
    vortexActive = false,
    vortexAngle = 0,
    vortexStrength = 0,
    vortexParticles = {},

    -- Damage flash
    damageFlash = 0,

    -- Death animation
    deathTimer = 0,
    deathDuration = 4.0,
    dying = false,
    deathParticles = {},
    deathRings = {},

    -- Drops
    droppedTrident = false,
    tridentDrop = nil,

    -- Screen ref
    screenW = screenW,
    screenH = screenH,
  }

  -- Initialize tentacles
  for i = 1, TENTACLE_COUNT do
    local baseAngle = (i / TENTACLE_COUNT) * math.pi * 2
    local tentacle = {
      baseAngle = baseAngle,
      segments = {},
      wavPhase = math.random() * math.pi * 2,
      wavSpeed = 1.5 + math.random() * 1.0,
      wavAmp = 0.3 + math.random() * 0.2,
      thickness = 8 - (0.3 * i),  -- Varies slightly
      tipColor = {0.2, 0.8, 0.6},
      state = "idle",   -- "idle", "reaching", "slam", "flail"
      reachTarget = nil,
      slamProgress = 0,
    }
    -- Initialize segment positions
    for j = 1, TENTACLE_SEGMENTS do
      table.insert(tentacle.segments, {
        x = 0, y = 0,
        angle = baseAngle,
      })
    end
    table.insert(k.tentacles, tentacle)
  end

  -- Initialize alias offsets
  for i = 1, 20 do
    table.insert(k.aliasOffsets, {
      ox = 0, oy = 0,
      targetOx = 0, targetOy = 0,
      timer = math.random() * 2,
    })
  end

  return k
end

-- ===================== SPAWN =====================

function M.spawn(kraken)
  kraken.active = true
  kraken.defeated = false
  kraken.entered = false
  kraken.entryTimer = 0
  kraken.health = kraken.maxHealth
  kraken.phase = 1
  kraken.dying = false
  kraken.deathTimer = 0
  kraken.droppedTrident = false
  kraken.tridentDrop = nil
  kraken.y = -200
end

-- ===================== UPDATE =====================

function M.update(kraken, dt, shipX, shipY)
  if not kraken.active then return end

  -- ===== ENTRY ANIMATION =====
  if not kraken.entered then
    kraken.entryTimer = kraken.entryTimer + dt
    local t = math.min(1, kraken.entryTimer / kraken.entryDuration)
    -- Ease-out cubic
    local ease = 1 - (1 - t) * (1 - t) * (1 - t)
    kraken.y = -200 + (kraken.targetY + 200) * ease

    -- Tentacles flop around during entry
    M.updateTentaclePhysics(kraken, dt, "flail")

    if t >= 1 then
      kraken.entered = true
    end
    M.updateAliasEffect(kraken, dt)
    return
  end

  -- ===== DEATH ANIMATION =====
  if kraken.dying then
    M.updateDeath(kraken, dt)
    return
  end

  -- ===== PHASE TRANSITION =====
  if kraken.phaseTransition then
    kraken.phaseTransTimer = kraken.phaseTransTimer + dt
    M.updateTentaclePhysics(kraken, dt, "flail")
    M.updateAliasEffect(kraken, dt)

    if kraken.phaseTransTimer >= kraken.phaseTransDuration then
      kraken.phaseTransition = false
    end
    return
  end

  -- ===== DAMAGE FLASH =====
  kraken.damageFlash = math.max(0, kraken.damageFlash - dt * 4)

  -- ===== BODY PULSE =====
  kraken.bodyPulse = kraken.bodyPulse + dt * 2
  local pulseSize = math.sin(kraken.bodyPulse) * 4

  -- ===== DRIFT MOVEMENT =====
  kraken.driftTimer = kraken.driftTimer + dt
  if kraken.driftTimer > 4 then
    kraken.driftTimer = 0
    kraken.driftAngle = math.random() * math.pi * 2
  end
  kraken.x = kraken.x + math.cos(kraken.driftAngle) * kraken.driftSpeed * dt
  kraken.y = kraken.y + math.sin(kraken.driftAngle) * kraken.driftSpeed * dt

  -- Keep on screen
  kraken.x = math.max(BODY_RADIUS + 20, math.min(kraken.screenW - BODY_RADIUS - 20, kraken.x))
  kraken.y = math.max(BODY_RADIUS + 20, math.min(kraken.screenH * 0.6, kraken.y))

  -- ===== EYE TRACKING =====
  kraken.eyePupilAngle = math.atan2(shipY - kraken.y, shipX - kraken.x)

  -- ===== ATTACK LOGIC =====
  kraken.attackTimer = kraken.attackTimer + dt
  if kraken.attackTimer >= kraken.attackCooldown then
    kraken.attackTimer = 0
    M.chooseAttack(kraken, shipX, shipY)
  end

  -- Update current attack
  M.updateAttack(kraken, dt, shipX, shipY)

  -- ===== TENTACLE PHYSICS =====
  M.updateTentaclePhysics(kraken, dt, "idle")

  -- ===== ALIAS EFFECT =====
  M.updateAliasEffect(kraken, dt)

  -- ===== INK CLOUDS =====
  M.updateInkClouds(kraken, dt)

  -- ===== VORTEX =====
  if kraken.vortexActive then
    M.updateVortex(kraken, dt)
  end
end

-- ===================== TENTACLE PHYSICS =====================
-- Procedural tentacle animation with physics-based flopping

function M.updateTentaclePhysics(kraken, dt, mode)
  for i, t in ipairs(kraken.tentacles) do
    local baseX = kraken.x + math.cos(t.baseAngle) * (kraken.bodyRadius * 0.8)
    local baseY = kraken.y + math.sin(t.baseAngle) * (kraken.bodyRadius * 0.8)

    t.wavPhase = t.wavPhase + t.wavSpeed * dt

    -- Phase-dependent behavior
    local wavAmpMult = 1.0
    local speedMult = 1.0
    if kraken.phase == 2 then
      wavAmpMult = 1.5
      speedMult = 1.3
    elseif kraken.phase == 3 then
      wavAmpMult = 2.0
      speedMult = 1.8
    end

    if mode == "flail" then
      wavAmpMult = wavAmpMult * 2.5
      speedMult = speedMult * 2.0
    end

    for j = 1, TENTACLE_SEGMENTS do
      local segFrac = j / TENTACLE_SEGMENTS
      local parentX, parentY, parentAngle

      if j == 1 then
        parentX = baseX
        parentY = baseY
        parentAngle = t.baseAngle
      else
        local prev = t.segments[j - 1]
        parentX = prev.x
        parentY = prev.y
        parentAngle = prev.angle
      end

      -- Wave offset (sinusoidal)
      local waveOffset = math.sin(t.wavPhase * speedMult + j * 0.6) * t.wavAmp * wavAmpMult * segFrac

      -- Secondary wave for organic feel
      local wave2 = math.sin(t.wavPhase * speedMult * 0.7 + j * 1.2 + i * 0.5) * t.wavAmp * wavAmpMult * segFrac * 0.5

      local segAngle = parentAngle + waveOffset + wave2

      -- Slam override
      if t.state == "slam" and t.reachTarget then
        local targetAngle = math.atan2(t.reachTarget.y - parentY, t.reachTarget.x - parentX)
        segAngle = segAngle + (targetAngle - segAngle) * t.slamProgress * segFrac
      end

      t.segments[j].x = parentX + math.cos(segAngle) * SEGMENT_LENGTH
      t.segments[j].y = parentY + math.sin(segAngle) * SEGMENT_LENGTH
      t.segments[j].angle = segAngle
    end
  end
end

-- ===================== ALIASING SHIMMER EFFECT =====================
-- Creates a pixel-art aliasing shimmer around the kraken's silhouette

function M.updateAliasEffect(kraken, dt)
  kraken.aliasTimer = kraken.aliasTimer + dt

  -- Intensity increases with phase
  kraken.aliasIntensity = 0.3 + (kraken.phase - 1) * 0.2

  for _, ao in ipairs(kraken.aliasOffsets) do
    ao.timer = ao.timer + dt
    if ao.timer > 0.08 then  -- Refresh every ~80ms for jittery alias feel
      ao.timer = 0
      ao.targetOx = (math.random() - 0.5) * 6 * kraken.aliasIntensity
      ao.targetOy = (math.random() - 0.5) * 6 * kraken.aliasIntensity
    end
    -- Snap to target (pixel-art step feel, not smooth interpolation)
    ao.ox = math.floor(ao.targetOx + 0.5)
    ao.oy = math.floor(ao.targetOy + 0.5)
  end
end

-- ===================== ATTACK SYSTEM =====================

function M.chooseAttack(kraken, shipX, shipY)
  if kraken.phase == 1 then
    -- Phase 1: Ink Spray only
    kraken.currentAttack = "ink_spray"
    kraken.attackCooldown = 2.5
  elseif kraken.phase == 2 then
    -- Phase 2: Ink Spray + Tentacle Slam
    if math.random() < 0.5 then
      kraken.currentAttack = "ink_spray"
    else
      kraken.currentAttack = "tentacle_slam"
      M.initTentacleSlam(kraken, shipX, shipY)
    end
    kraken.attackCooldown = 2.0
  else
    -- Phase 3: All attacks + Vortex
    local roll = math.random()
    if roll < 0.3 then
      kraken.currentAttack = "ink_spray"
    elseif roll < 0.6 then
      kraken.currentAttack = "tentacle_slam"
      M.initTentacleSlam(kraken, shipX, shipY)
    else
      kraken.currentAttack = "vortex"
      M.initVortex(kraken)
    end
    kraken.attackCooldown = 1.5
  end
end

function M.updateAttack(kraken, dt, shipX, shipY)
  if kraken.currentAttack == "ink_spray" then
    M.doInkSpray(kraken, shipX, shipY)
    kraken.currentAttack = nil
  elseif kraken.currentAttack == "tentacle_slam" then
    M.updateTentacleSlam(kraken, dt, shipX, shipY)
  elseif kraken.currentAttack == "vortex" then
    M.updateVortex(kraken, dt)
  end
end

-- ===== PHASE 1 MECHANIC: INK SPRAY =====
-- Fires a burst of ink projectiles that leave lingering damage clouds

function M.doInkSpray(kraken, targetX, targetY)
  local angle = math.atan2(targetY - kraken.y, targetX - kraken.x)
  local spreadCount = 3 + kraken.phase * 2  -- 5/7/9 projectiles by phase

  for i = 1, spreadCount do
    local a = angle + ((i - 1) / (spreadCount - 1) - 0.5) * 1.2
    a = a + (math.random() - 0.5) * 0.2
    local speed = 200 + math.random() * 100

    table.insert(kraken.inkClouds, {
      x = kraken.x + math.cos(a) * kraken.bodyRadius,
      y = kraken.y + math.sin(a) * kraken.bodyRadius,
      vx = math.cos(a) * speed,
      vy = math.sin(a) * speed,
      life = 3.0,
      maxLife = 3.0,
      size = 8 + math.random() * 6,
      expanding = false,
      expandTimer = 0,
      damage = 5,
      isProjectile = true,  -- moves fast first, then becomes cloud
      travelDist = 0,
      maxTravel = 150 + math.random() * 200,
    })
  end
end

function M.updateInkClouds(kraken, dt)
  for i = #kraken.inkClouds, 1, -1 do
    local ink = kraken.inkClouds[i]
    ink.life = ink.life - dt

    if ink.isProjectile then
      ink.x = ink.x + ink.vx * dt
      ink.y = ink.y + ink.vy * dt
      ink.travelDist = ink.travelDist + math.sqrt(ink.vx * ink.vx + ink.vy * ink.vy) * dt

      if ink.travelDist >= ink.maxTravel then
        ink.isProjectile = false
        ink.expanding = true
        ink.vx = 0
        ink.vy = 0
      end
    elseif ink.expanding then
      ink.expandTimer = ink.expandTimer + dt
      ink.size = ink.size + dt * 15  -- grow
      ink.vx = ink.vx * 0.95
      ink.vy = ink.vy * 0.95
    end

    if ink.life <= 0 then
      table.remove(kraken.inkClouds, i)
    end
  end
end

-- ===== PHASE 2 MECHANIC: TENTACLE SLAM =====
-- Winds up a tentacle then slams it at the player's position

function M.initTentacleSlam(kraken, targetX, targetY)
  -- Pick the tentacle closest to the player
  local bestIdx = 1
  local bestDist = math.huge
  for i, t in ipairs(kraken.tentacles) do
    local tipSeg = t.segments[TENTACLE_SEGMENTS]
    local dx = targetX - tipSeg.x
    local dy = targetY - tipSeg.y
    local dist = dx * dx + dy * dy
    if dist < bestDist then
      bestDist = dist
      bestIdx = i
    end
  end

  local t = kraken.tentacles[bestIdx]
  t.state = "slam"
  t.reachTarget = {x = targetX, y = targetY}
  t.slamProgress = 0
  kraken.slamTentacle = bestIdx
  kraken.slamTimer = 0
  kraken.slamPhase = "windup"
end

function M.updateTentacleSlam(kraken, dt, shipX, shipY)
  kraken.slamTimer = kraken.slamTimer + dt

  if kraken.slamPhase == "windup" then
    -- Pull tentacle back (0.5s)
    local t = kraken.tentacles[kraken.slamTentacle]
    t.slamProgress = -math.min(1, kraken.slamTimer / 0.5) * 0.5

    if kraken.slamTimer >= 0.5 then
      kraken.slamPhase = "slam"
      kraken.slamTimer = 0
      -- Update target to current player position (tracking)
      t.reachTarget = {x = shipX, y = shipY}
    end

  elseif kraken.slamPhase == "slam" then
    -- Slam forward (0.3s)
    local t = kraken.tentacles[kraken.slamTentacle]
    t.slamProgress = math.min(1, kraken.slamTimer / 0.3)

    if kraken.slamTimer >= 0.3 then
      kraken.slamPhase = "recover"
      kraken.slamTimer = 0
    end

  elseif kraken.slamPhase == "recover" then
    -- Retract (0.8s)
    local t = kraken.tentacles[kraken.slamTentacle]
    t.slamProgress = math.max(0, 1 - kraken.slamTimer / 0.8)

    if kraken.slamTimer >= 0.8 then
      t.state = "idle"
      t.slamProgress = 0
      t.reachTarget = nil
      kraken.slamPhase = "none"
      kraken.currentAttack = nil
    end
  end
end

-- ===== PHASE 3 MECHANIC: VORTEX =====
-- Creates a swirling vortex that pulls the player in

function M.initVortex(kraken)
  kraken.vortexActive = true
  kraken.vortexAngle = 0
  kraken.vortexStrength = 0
  kraken.vortexParticles = {}
end

function M.updateVortex(kraken, dt)
  kraken.slamTimer = (kraken.slamTimer or 0) + dt
  kraken.vortexAngle = kraken.vortexAngle + dt * 4

  -- Ramp up strength, then fade out
  local duration = 5.0
  local elapsed = kraken.slamTimer
  if elapsed < 1.0 then
    kraken.vortexStrength = elapsed / 1.0  -- ramp up
  elseif elapsed < duration - 1.0 then
    kraken.vortexStrength = 1.0  -- full power
  elseif elapsed < duration then
    kraken.vortexStrength = (duration - elapsed) / 1.0  -- fade out
  else
    kraken.vortexActive = false
    kraken.vortexStrength = 0
    kraken.currentAttack = nil
    return
  end

  -- Spawn vortex particles
  for i = 1, 3 do
    local a = kraken.vortexAngle + math.random() * math.pi * 2
    local dist = 150 + math.random() * 100
    table.insert(kraken.vortexParticles, {
      x = kraken.x + math.cos(a) * dist,
      y = kraken.y + math.sin(a) * dist,
      angle = a,
      dist = dist,
      life = 1.0,
      maxLife = 1.0,
      size = 2 + math.random() * 3,
    })
  end

  -- Update vortex particles (spiral inward)
  for i = #kraken.vortexParticles, 1, -1 do
    local p = kraken.vortexParticles[i]
    p.life = p.life - dt
    p.dist = p.dist - 80 * dt * kraken.vortexStrength
    p.angle = p.angle + 3 * dt
    p.x = kraken.x + math.cos(p.angle) * p.dist
    p.y = kraken.y + math.sin(p.angle) * p.dist

    if p.life <= 0 or p.dist < 20 then
      table.remove(kraken.vortexParticles, i)
    end
  end

  -- Cap particles
  while #kraken.vortexParticles > 80 do
    table.remove(kraken.vortexParticles, 1)
  end
end

-- Get vortex pull force on the player
function M.getVortexPull(kraken, shipX, shipY)
  if not kraken.active or not kraken.vortexActive then return 0, 0 end

  local dx = kraken.x - shipX
  local dy = kraken.y - shipY
  local dist = math.sqrt(dx * dx + dy * dy)
  if dist < 10 then dist = 10 end

  local pullStrength = 180 * kraken.vortexStrength
  return (dx / dist) * pullStrength, (dy / dist) * pullStrength
end

-- ===================== DAMAGE =====================

function M.takeDamage(kraken, damage)
  if not kraken.active or kraken.dying or not kraken.entered then return false end
  if kraken.phaseTransition then return false end

  kraken.health = kraken.health - damage
  kraken.damageFlash = 1.0

  -- Check phase transitions
  local pct = kraken.health / kraken.maxHealth
  if kraken.phase == 1 and pct <= PHASE_2_THRESHOLD then
    kraken.phase = 2
    kraken.phaseTransition = true
    kraken.phaseTransTimer = 0
    kraken.driftSpeed = 45  -- faster drift
    kraken.currentAttack = nil
  elseif kraken.phase == 2 and pct <= PHASE_3_THRESHOLD then
    kraken.phase = 3
    kraken.phaseTransition = true
    kraken.phaseTransTimer = 0
    kraken.driftSpeed = 60
    kraken.currentAttack = nil
  end

  -- Death
  if kraken.health <= 0 then
    kraken.health = 0
    kraken.dying = true
    kraken.deathTimer = 0
    M.initDeathAnimation(kraken)
    return true  -- defeated
  end

  return false
end

-- ===================== COLLISION CHECKS =====================

-- Check if a bullet hits the kraken body or tentacles
function M.checkBulletHit(kraken, bx, by, bRadius)
  if not kraken.active or kraken.dying or not kraken.entered then return false end

  -- Body collision
  local dx = bx - kraken.x
  local dy = by - kraken.y
  local dist = math.sqrt(dx * dx + dy * dy)
  if dist < kraken.bodyRadius + (bRadius or 4) then
    return true
  end

  -- Tentacle collision (check each segment)
  for _, t in ipairs(kraken.tentacles) do
    for _, seg in ipairs(t.segments) do
      local sdx = bx - seg.x
      local sdy = by - seg.y
      if math.sqrt(sdx * sdx + sdy * sdy) < 10 + (bRadius or 4) then
        return true
      end
    end
  end

  return false
end

-- Check if tentacle slam hits the player
function M.checkTentacleDamage(kraken, shipX, shipY, shipSize)
  if not kraken.active or kraken.dying then return 0 end

  local totalDamage = 0

  -- Tentacle tip contact damage
  for _, t in ipairs(kraken.tentacles) do
    local tip = t.segments[TENTACLE_SEGMENTS]
    local dx = shipX - tip.x
    local dy = shipY - tip.y
    local dist = math.sqrt(dx * dx + dy * dy)

    if dist < shipSize + 12 then
      if t.state == "slam" and t.slamProgress > 0.5 then
        totalDamage = totalDamage + 20  -- Slam damage
      else
        totalDamage = totalDamage + 5   -- Contact damage
      end
    end
  end

  -- Body contact damage
  local bdx = shipX - kraken.x
  local bdy = shipY - kraken.y
  if math.sqrt(bdx * bdx + bdy * bdy) < kraken.bodyRadius + shipSize then
    totalDamage = totalDamage + 10
  end

  return totalDamage
end

-- Check ink cloud damage to player
function M.checkInkDamage(kraken, shipX, shipY, shipSize)
  if not kraken.active then return 0 end

  for _, ink in ipairs(kraken.inkClouds) do
    local dx = shipX - ink.x
    local dy = shipY - ink.y
    local dist = math.sqrt(dx * dx + dy * dy)
    local hitRadius = ink.isProjectile and (ink.size * 0.8) or ink.size
    if dist < hitRadius + shipSize then
      return ink.damage
    end
  end
  return 0
end

-- ===================== DEATH ANIMATION =====================

function M.initDeathAnimation(kraken)
  kraken.deathParticles = {}
  kraken.deathRings = {}

  -- Create massive explosion particles
  for i = 1, 80 do
    local angle = math.random() * math.pi * 2
    local speed = 50 + math.random() * 250
    table.insert(kraken.deathParticles, {
      x = kraken.x + (math.random() - 0.5) * kraken.bodyRadius,
      y = kraken.y + (math.random() - 0.5) * kraken.bodyRadius,
      vx = math.cos(angle) * speed,
      vy = math.sin(angle) * speed,
      life = 1.5 + math.random() * 2.5,
      maxLife = 4.0,
      size = 3 + math.random() * 8,
      r = kraken.bodyColor[1] + math.random() * 0.3,
      g = kraken.bodyColor[2] + math.random() * 0.3,
      b = kraken.bodyColor[3] + math.random() * 0.3,
      delay = math.random() * 1.5,  -- staggered explosions
    })
  end

  -- Multiple shockwave rings
  for i = 1, 5 do
    table.insert(kraken.deathRings, {
      radius = 5,
      maxRadius = 100 + i * 50,
      speed = 100 + i * 40,
      alpha = 1.0,
      delay = (i - 1) * 0.4,
      started = false,
      color = {
        kraken.bodyColor[1] + math.random() * 0.3,
        kraken.bodyColor[2] + math.random() * 0.3,
        0.8 + math.random() * 0.2,
      },
    })
  end
end

function M.updateDeath(kraken, dt)
  kraken.deathTimer = kraken.deathTimer + dt

  -- Shake body during death
  kraken.x = kraken.x + (math.random() - 0.5) * 8
  kraken.y = kraken.y + (math.random() - 0.5) * 8

  -- Tentacles go wild
  M.updateTentaclePhysics(kraken, dt, "flail")
  M.updateAliasEffect(kraken, dt)

  -- Update particles
  for i = #kraken.deathParticles, 1, -1 do
    local p = kraken.deathParticles[i]
    if kraken.deathTimer >= p.delay then
      p.x = p.x + p.vx * dt
      p.y = p.y + p.vy * dt
      p.vx = p.vx * 0.97
      p.vy = p.vy * 0.97
      p.life = p.life - dt
      if p.life <= 0 then
        table.remove(kraken.deathParticles, i)
      end
    end
  end

  -- Update rings
  for _, ring in ipairs(kraken.deathRings) do
    if kraken.deathTimer >= ring.delay then
      ring.started = true
    end
    if ring.started then
      ring.radius = ring.radius + ring.speed * dt
      ring.alpha = math.max(0, 1.0 - (ring.radius / ring.maxRadius))
    end
  end

  -- End death sequence → drop Trident
  if kraken.deathTimer >= kraken.deathDuration then
    kraken.active = false
    kraken.defeated = true
    if not kraken.droppedTrident then
      kraken.droppedTrident = true
      kraken.tridentDrop = {
        x = kraken.x,
        y = kraken.y,
        bobTimer = 0,
        glowTimer = 0,
        collected = false,
      }
    end
  end
end

-- ===================== TRIDENT DROP =====================

function M.updateTridentDrop(kraken, dt, shipX, shipY, shipSize)
  if not kraken.tridentDrop or kraken.tridentDrop.collected then return false end

  local td = kraken.tridentDrop
  td.bobTimer = td.bobTimer + dt
  td.glowTimer = td.glowTimer + dt

  -- Check player pickup
  local dx = shipX - td.x
  local dy = shipY - td.y
  local dist = math.sqrt(dx * dx + dy * dy)
  if dist < shipSize + 25 then
    td.collected = true
    return true  -- Player collected the Trident!
  end

  return false
end

-- ===================== DRAWING =====================

function M.draw(kraken)
  if not kraken.active and not kraken.tridentDrop then return end

  -- Draw Trident drop (persists after kraken death)
  if kraken.tridentDrop and not kraken.tridentDrop.collected then
    M.drawTridentDrop(kraken.tridentDrop)
  end

  if not kraken.active then return end

  -- ===== VORTEX PARTICLES =====
  if kraken.vortexActive then
    for _, p in ipairs(kraken.vortexParticles) do
      local alpha = p.life / p.maxLife
      love.graphics.setColor(0.2, 0.8, 0.9, alpha * 0.6)
      love.graphics.circle("fill", p.x, p.y, p.size)
    end
    -- Vortex center glow
    local vAlpha = kraken.vortexStrength * 0.3
    love.graphics.setColor(0.1, 0.6, 0.8, vAlpha)
    love.graphics.circle("fill", kraken.x, kraken.y, 40 + math.sin(kraken.vortexAngle) * 10)
  end

  -- ===== INK CLOUDS =====
  for _, ink in ipairs(kraken.inkClouds) do
    local alpha = ink.life / ink.maxLife
    if ink.isProjectile then
      -- Fast-moving ink blob
      love.graphics.setColor(0.05, 0.05, 0.1, alpha * 0.9)
      love.graphics.circle("fill", ink.x, ink.y, ink.size * 0.7)
      love.graphics.setColor(0.15, 0.4, 0.35, alpha * 0.6)
      love.graphics.circle("fill", ink.x, ink.y, ink.size)
    else
      -- Lingering cloud
      love.graphics.setColor(0.05, 0.15, 0.12, alpha * 0.4)
      love.graphics.circle("fill", ink.x, ink.y, ink.size)
      love.graphics.setColor(0.1, 0.3, 0.25, alpha * 0.2)
      love.graphics.circle("fill", ink.x, ink.y, ink.size * 1.5)
    end
  end

  -- ===== ALIASING SHIMMER (draw offset copies) =====
  for _, ao in ipairs(kraken.aliasOffsets) do
    local shimmerAlpha = 0.08 * kraken.aliasIntensity
    love.graphics.setColor(kraken.bodyColor[1], kraken.bodyColor[2], kraken.bodyColor[3], shimmerAlpha)
    love.graphics.circle("fill", kraken.x + ao.ox, kraken.y + ao.oy, kraken.bodyRadius * 0.9)
  end

  -- ===== TENTACLES =====
  for _, t in ipairs(kraken.tentacles) do
    M.drawTentacle(kraken, t)
  end

  -- ===== BODY =====
  local bodyR = kraken.bodyRadius + math.sin(kraken.bodyPulse) * 4

  -- Outer glow
  local glowAlpha = 0.15 + kraken.aliasIntensity * 0.1
  love.graphics.setColor(kraken.bodyColor[1] * 0.5, kraken.bodyColor[2] * 1.2, kraken.bodyColor[3] * 1.1, glowAlpha)
  love.graphics.circle("fill", kraken.x, kraken.y, bodyR + 15)

  -- Body
  if kraken.damageFlash > 0 then
    love.graphics.setColor(1, 1, 1, 1)
  elseif kraken.dying then
    local flicker = math.sin(kraken.deathTimer * 30) > 0 and 1 or 0
    love.graphics.setColor(1, flicker * 0.5, 0, 0.8)
  else
    love.graphics.setColor(kraken.bodyColor[1], kraken.bodyColor[2], kraken.bodyColor[3], 0.95)
  end
  love.graphics.circle("fill", kraken.x, kraken.y, bodyR)

  -- Body texture (darker patches)
  love.graphics.setColor(kraken.bodyColor[1] * 0.6, kraken.bodyColor[2] * 0.6, kraken.bodyColor[3] * 0.6, 0.3)
  for i = 1, 5 do
    local px = kraken.x + math.cos(i * 1.2 + kraken.bodyPulse * 0.3) * bodyR * 0.4
    local py = kraken.y + math.sin(i * 1.7 + kraken.bodyPulse * 0.3) * bodyR * 0.4
    love.graphics.circle("fill", px, py, bodyR * 0.2)
  end

  -- ===== EYE =====
  local eyeSize = bodyR * 0.35

  -- Eye white (sclera)
  love.graphics.setColor(0.9, 0.85, 0.8, 1)
  love.graphics.circle("fill", kraken.x, kraken.y - bodyR * 0.1, eyeSize)

  -- Iris
  local irisX = kraken.x + math.cos(kraken.eyePupilAngle) * eyeSize * 0.3
  local irisY = kraken.y - bodyR * 0.1 + math.sin(kraken.eyePupilAngle) * eyeSize * 0.3
  love.graphics.setColor(kraken.eyeColor[1], kraken.eyeColor[2], kraken.eyeColor[3], 1)
  love.graphics.circle("fill", irisX, irisY, eyeSize * 0.55)

  -- Pupil (vertical slit)
  love.graphics.setColor(0, 0, 0, 1)
  love.graphics.push()
  love.graphics.translate(irisX, irisY)
  love.graphics.scale(0.25, 1)
  love.graphics.circle("fill", 0, 0, eyeSize * 0.4)
  love.graphics.pop()

  -- Eye glint
  love.graphics.setColor(1, 1, 1, 0.8)
  love.graphics.circle("fill", irisX - eyeSize * 0.15, irisY - eyeSize * 0.15, eyeSize * 0.12)

  -- ===== HEALTH BAR =====
  if kraken.entered and not kraken.dying then
    local barW = 200
    local barH = 8
    local barX = kraken.x - barW / 2
    local barY = kraken.y - kraken.bodyRadius - 30

    -- Phase indicator background color
    local phaseColors = {
      {0.2, 0.6, 0.5},   -- Phase 1: teal
      {0.7, 0.5, 0.2},   -- Phase 2: amber
      {0.8, 0.2, 0.2},   -- Phase 3: red
    }
    local pc = phaseColors[kraken.phase]

    -- Background
    love.graphics.setColor(0.1, 0.1, 0.1, 0.8)
    love.graphics.rectangle("fill", barX - 1, barY - 1, barW + 2, barH + 2)

    -- Fill
    local pct = kraken.health / kraken.maxHealth
    love.graphics.setColor(pc[1], pc[2], pc[3], 0.9)
    love.graphics.rectangle("fill", barX, barY, barW * pct, barH)

    -- Phase markers
    love.graphics.setColor(1, 1, 1, 0.5)
    love.graphics.setLineWidth(1)
    love.graphics.line(barX + barW * PHASE_2_THRESHOLD, barY, barX + barW * PHASE_2_THRESHOLD, barY + barH)
    love.graphics.line(barX + barW * PHASE_3_THRESHOLD, barY, barX + barW * PHASE_3_THRESHOLD, barY + barH)

    -- Name
    love.graphics.setColor(1, 1, 1, 0.9)
    love.graphics.printf("THE KRAKEN", barX, barY - 16, barW, "center")

    -- Phase label
    love.graphics.setColor(pc[1], pc[2], pc[3], 0.7)
    love.graphics.printf("Phase " .. kraken.phase, barX, barY + barH + 2, barW, "center")
  end

  -- ===== DEATH EFFECTS =====
  if kraken.dying then
    -- Death shockwave rings
    for _, ring in ipairs(kraken.deathRings) do
      if ring.started and ring.alpha > 0 then
        love.graphics.setLineWidth(3)
        love.graphics.setColor(ring.color[1], ring.color[2], ring.color[3], ring.alpha * 0.7)
        love.graphics.circle("line", kraken.x, kraken.y, ring.radius)
        love.graphics.setLineWidth(1)
      end
    end

    -- Death particles
    for _, p in ipairs(kraken.deathParticles) do
      if kraken.deathTimer >= p.delay then
        local alpha = p.life / p.maxLife
        love.graphics.setColor(p.r, p.g, p.b, alpha)
        love.graphics.circle("fill", p.x, p.y, p.size * alpha)
      end
    end

    -- Central fireball (pulsing)
    if kraken.deathTimer < 3.0 then
      local t = kraken.deathTimer / 3.0
      local fireSize = kraken.bodyRadius * (1 + t * 0.5)
      local fireAlpha = (1 - t) * 0.7
      -- White core
      love.graphics.setColor(1, 1, 1, fireAlpha)
      love.graphics.circle("fill", kraken.x, kraken.y, fireSize * 0.3)
      -- Color mid
      love.graphics.setColor(0.2, 0.8, 0.7, fireAlpha * 0.6)
      love.graphics.circle("fill", kraken.x, kraken.y, fireSize * 0.6)
      -- Outer glow
      love.graphics.setColor(0.1, 0.4, 0.8, fireAlpha * 0.3)
      love.graphics.circle("fill", kraken.x, kraken.y, fireSize)
    end
  end

  -- ===== PHASE TRANSITION FLASH =====
  if kraken.phaseTransition then
    local t = kraken.phaseTransTimer / kraken.phaseTransDuration
    local flashAlpha = math.sin(t * math.pi) * 0.4
    love.graphics.setColor(1, 1, 1, flashAlpha)
    love.graphics.rectangle("fill", 0, 0, kraken.screenW, kraken.screenH)
  end
end

-- Draw a single tentacle
function M.drawTentacle(kraken, tentacle)
  local segments = tentacle.segments
  if #segments < 2 then return end

  local baseX = kraken.x + math.cos(tentacle.baseAngle) * (kraken.bodyRadius * 0.8)
  local baseY = kraken.y + math.sin(tentacle.baseAngle) * (kraken.bodyRadius * 0.8)

  -- Draw tentacle as connected line segments with decreasing width
  for j = 1, #segments do
    local seg = segments[j]
    local prevX, prevY
    if j == 1 then
      prevX, prevY = baseX, baseY
    else
      prevX, prevY = segments[j - 1].x, segments[j - 1].y
    end

    local segFrac = j / #segments
    local thickness = tentacle.thickness * (1 - segFrac * 0.7)

    -- Gradient color: body color → tip color
    local r = kraken.bodyColor[1] + (tentacle.tipColor[1] - kraken.bodyColor[1]) * segFrac
    local g = kraken.bodyColor[2] + (tentacle.tipColor[2] - kraken.bodyColor[2]) * segFrac
    local b = kraken.bodyColor[3] + (tentacle.tipColor[3] - kraken.bodyColor[3]) * segFrac

    -- Aliasing shimmer on tentacles
    local aliasOff = kraken.aliasOffsets[(j % #kraken.aliasOffsets) + 1]
    local ox = aliasOff.ox * segFrac * 0.5
    local oy = aliasOff.oy * segFrac * 0.5

    if kraken.damageFlash > 0 then
      love.graphics.setColor(1, 1, 1, 1)
    elseif kraken.dying then
      local flicker = math.sin(kraken.deathTimer * 30 + j) > 0 and 0.8 or 0.3
      love.graphics.setColor(1, flicker, 0, 0.7)
    else
      love.graphics.setColor(r, g, b, 0.9)
    end

    love.graphics.setLineWidth(thickness)
    love.graphics.line(prevX + ox, prevY + oy, seg.x + ox, seg.y + oy)

    -- Suction cups on underside (every 3rd segment)
    if j % 3 == 0 and not kraken.dying then
      local cupSize = thickness * 0.4
      love.graphics.setColor(r * 0.7, g * 0.7, b * 0.7, 0.6)
      love.graphics.circle("fill", seg.x + ox, seg.y + oy, cupSize)
      love.graphics.setColor(r * 0.5, g * 0.5, b * 0.5, 0.4)
      love.graphics.circle("fill", seg.x + ox, seg.y + oy, cupSize * 0.5)
    end
  end

  love.graphics.setLineWidth(1)

  -- Tentacle tip glow
  if not kraken.dying then
    local tip = segments[#segments]
    local glowPulse = math.sin(kraken.bodyPulse * 2 + tentacle.wavPhase) * 0.3 + 0.3
    love.graphics.setColor(tentacle.tipColor[1], tentacle.tipColor[2], tentacle.tipColor[3], glowPulse)
    love.graphics.circle("fill", tip.x, tip.y, 5)
  end
end

-- Draw the Trident item drop
function M.drawTridentDrop(td)
  local bob = math.sin(td.bobTimer * 2) * 8
  local glow = math.sin(td.glowTimer * 3) * 0.3 + 0.7
  local x = td.x
  local y = td.y + bob

  -- Outer glow
  love.graphics.setColor(0.2, 0.6, 1.0, glow * 0.3)
  love.graphics.circle("fill", x, y, 35)

  -- Inner glow
  love.graphics.setColor(0.4, 0.8, 1.0, glow * 0.5)
  love.graphics.circle("fill", x, y, 20)

  -- Trident shape (three prongs)
  love.graphics.setColor(0.7, 0.9, 1.0, glow)
  love.graphics.setLineWidth(3)

  -- Handle
  love.graphics.line(x, y + 18, x, y - 8)

  -- Crossbar
  love.graphics.line(x - 12, y - 5, x + 12, y - 5)

  -- Three prongs
  love.graphics.line(x - 12, y - 5, x - 12, y - 18)
  love.graphics.line(x, y - 8, x, y - 22)
  love.graphics.line(x + 12, y - 5, x + 12, y - 18)

  -- Prong tips (small triangles)
  love.graphics.setColor(1, 1, 1, glow)
  love.graphics.polygon("fill",
    x - 14, y - 18, x - 10, y - 18, x - 12, y - 24)
  love.graphics.polygon("fill",
    x - 2, y - 22, x + 2, y - 22, x, y - 28)
  love.graphics.polygon("fill",
    x + 10, y - 18, x + 14, y - 18, x + 12, y - 24)

  love.graphics.setLineWidth(1)

  -- Label
  love.graphics.setColor(0.7, 0.9, 1.0, glow * 0.8)
  love.graphics.printf("THE TRIDENT", x - 60, y + 28, 120, "center")
end

-- ===================== QUERIES =====================

function M.isActive(kraken)
  return kraken.active
end

function M.isDefeated(kraken)
  return kraken.defeated
end

function M.hasTridentDrop(kraken)
  return kraken.tridentDrop ~= nil and not kraken.tridentDrop.collected
end

function M.isTridentCollected(kraken)
  return kraken.tridentDrop ~= nil and kraken.tridentDrop.collected
end

return M
