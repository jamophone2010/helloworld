-- cereus/environment.lua
-- Desert environmental effects for Cereus hub world
-- Wind, dust devils, heat shimmer, clouds, desert flora rendering
-- Mountain rendering with layered depth and volcanic texture

local M = {}
local lighting = require("cereus.lighting")

-- ═══════════════════════════════════════
-- WIND STATE
-- ═══════════════════════════════════════
local wind = {
  baseStrength = 0.3,
  currentStrength = 0.3,
  targetStrength = 0.3,
  gustTimer = 0,
  direction = 1
}

-- ═══════════════════════════════════════
-- CLOUD STATE
-- ═══════════════════════════════════════
local clouds = {}
local cloudsSeed = 0

-- ═══════════════════════════════════════
-- DUST DEVIL STATE (desert-specific)
-- ═══════════════════════════════════════
local dustDevils = {}

-- ═══════════════════════════════════════
-- DESERT WILDLIFE (ambient creatures)
-- ═══════════════════════════════════════
local roadrunners = {}
local lizards = {}
local coatimundis = {}      -- Troop of white-nosed coatimundis (Nasua narica)
local hummingbirds = {}      -- Costa's and Anna's hummingbirds at flowers

-- ═══════════════════════════════════════
-- AMBIENT PARTICLE SYSTEMS
-- ═══════════════════════════════════════
local butterflies = {}       -- Painted ladies, monarchs, swallowtails
local pollenMotes = {}       -- Floating golden pollen / seed fluff
local fallingLeaves = {}     -- Leaves drifting from eucalyptus/palo verde
local fireflies = {}         -- Desert fireflies (active at dusk/night)

-- ═══════════════════════════════════════
-- WILDFLOWER GROUND COVER
-- ═══════════════════════════════════════
local wildflowers = {}       -- Persistent ground-cover blooms (poppies, lupine, brittlebush, globe mallow, penstemons)

-- ═══════════════════════════════════════
-- INITIALIZATION
-- ═══════════════════════════════════════
function M.init()
  M.regenerateClouds()
  M.regenerateWildlife()
  M.regenerateButterflies()
  M.regeneratePollenMotes()
  M.regenerateWildflowers()
  M.regenerateFireflies()
end

function M.regenerateClouds()
  local day = lighting.getDayNumber()
  if cloudsSeed == day then return end
  cloudsSeed = day

  clouds = {}
  math.randomseed(day * 54321)

  -- Arizona has sparse cloud cover — fewer clouds than coastal
  local numClouds = 3 + math.random(0, 5)
  for i = 1, numClouds do
    local cloud = {
      x = math.random(-300, 2400),
      y = math.random(15, 120),
      width = math.random(100, 250),
      height = math.random(25, 50),
      speed = 3 + math.random() * 8,
      puffs = {},
      opacity = 0.4 + math.random() * 0.3  -- Thinner desert clouds
    }
    local numPuffs = 2 + math.random(0, 3)
    for j = 1, numPuffs do
      table.insert(cloud.puffs, {
        offsetX = (j - 1) * (cloud.width / numPuffs) - cloud.width / 2 + math.random(-15, 15),
        offsetY = math.random(-8, 8),
        radius = cloud.height / 2 + math.random(-8, 12)
      })
    end
    table.insert(clouds, cloud)
  end

  math.randomseed(os.time())
end

function M.regenerateWildlife()
  roadrunners = {}
  lizards = {}

  -- Roadrunners (2-4 roaming the trails)
  local numRunners = 2 + math.random(0, 2)
  for i = 1, numRunners do
    table.insert(roadrunners, {
      x = 400 + math.random(0, 1600),
      y = 600 + math.random(0, 800),
      targetX = 0, targetY = 0,
      moving = false,
      moveTimer = math.random() * 5,
      direction = 1,
      animFrame = 0,
      speed = 80 + math.random() * 40,  -- Roadrunners are fast!
      running = false
    })
  end

  -- Lizards (small, skittery, on rocks)
  local numLizards = 5 + math.random(0, 5)
  for i = 1, numLizards do
    table.insert(lizards, {
      x = 100 + math.random(0, 2000),
      y = 300 + math.random(0, 1200),
      basking = true,
      baskTimer = 3 + math.random() * 8,
      direction = 1,
      animFrame = 0,
      speed = 100 + math.random() * 60,
      species = math.random(1, 3)  -- 1=collared, 2=horned, 3=whiptail
    })
  end

  -- ═══ COATIMUNDIS (troop of 4-8, travel together foraging) ═══
  coatimundis = {}
  local troopCenterX = 300 + math.random(0, 1400)
  local troopCenterY = 500 + math.random(0, 800)
  local troopSize = 4 + math.random(0, 4)
  for i = 1, troopSize do
    table.insert(coatimundis, {
      x = troopCenterX + math.random(-60, 60),
      y = troopCenterY + math.random(-40, 40),
      targetX = troopCenterX,
      targetY = troopCenterY,
      troopX = troopCenterX,     -- center of troop
      troopY = troopCenterY,
      moving = false,
      foraging = false,          -- nose-down searching animation
      moveTimer = math.random() * 3,
      foragePauseTimer = 0,
      direction = 1,
      animFrame = 0,
      speed = 30 + math.random() * 20,
      tailPhase = math.random() * math.pi * 2,  -- offset for tail wave
      isBaby = i > troopSize - math.floor(troopSize * 0.3),  -- last ~30% are juveniles
    })
  end

  -- ═══ HUMMINGBIRDS (2-4, hovering at flowering plants) ═══
  hummingbirds = {}
  local numHummers = 2 + math.random(0, 2)
  for i = 1, numHummers do
    table.insert(hummingbirds, {
      x = 200 + math.random(0, 1800),
      y = 400 + math.random(0, 600),
      hoverX = 0, hoverY = 0,
      visiting = false,
      visitTimer = 0,
      flightTimer = math.random() * 5,
      direction = 1,
      wingPhase = math.random() * math.pi * 2,
      speed = 120 + math.random() * 80,
      species = math.random(1, 2),  -- 1=Costa's (violet), 2=Anna's (ruby)
      darting = false,
      dartTimer = 0,
    })
  end
end

-- ═══════════════════════════════════════
-- BUTTERFLY / MOTH SYSTEM
-- ═══════════════════════════════════════
function M.regenerateButterflies()
  butterflies = {}
  local hour = lighting.getHour()
  if hour < 5 or hour > 21 then return end  -- no butterflies at night

  local numButterflies = 12 + math.random(0, 8)
  for i = 1, numButterflies do
    local species = math.random(1, 5)
    -- 1=painted lady, 2=monarch, 3=swallowtail, 4=sulfur, 5=blue morpho (rare!)
    table.insert(butterflies, {
      x = 100 + math.random(0, 2000),
      y = 300 + math.random(0, 1200),
      z = 10 + math.random() * 40,    -- height above ground
      targetX = 0, targetY = 0,
      drifting = true,
      driftTimer = math.random() * 4,
      landTimer = 0,
      landed = false,
      wingPhase = math.random() * math.pi * 2,
      wingSpeed = 3 + math.random() * 3,
      speed = 15 + math.random() * 25,
      species = species,
      size = (species == 2 and 1.3 or species == 5 and 1.1 or 0.8 + math.random() * 0.4),
      glideAngle = math.random() * math.pi * 2,
    })
  end
end

-- ═══════════════════════════════════════
-- POLLEN MOTES / SEED FLUFF (floating particles)
-- ═══════════════════════════════════════
function M.regeneratePollenMotes()
  pollenMotes = {}
  fallingLeaves = {}

  -- Golden pollen drifts (daytime only, concentrated near flowers/trees)
  local numMotes = 40 + math.random(0, 30)
  for i = 1, numMotes do
    table.insert(pollenMotes, {
      x = math.random(0, 2200),
      y = math.random(100, 1600),
      z = 5 + math.random() * 60,
      size = 0.8 + math.random() * 1.5,
      speed = 2 + math.random() * 6,
      phase = math.random() * math.pi * 2,
      drift = math.random() * 0.5,
      type = math.random(1, 3),  -- 1=pollen (gold), 2=cottonwood fluff (white), 3=dust sparkle
      alpha = 0.3 + math.random() * 0.4,
    })
  end

  -- Falling leaves (from eucalyptus & palo verde areas)
  local numLeaves = 8 + math.random(0, 6)
  for i = 1, numLeaves do
    table.insert(fallingLeaves, {
      x = 100 + math.random(0, 1800),
      y = math.random(-100, 400),
      rotation = math.random() * math.pi * 2,
      rotSpeed = 1 + math.random() * 2,
      fallSpeed = 8 + math.random() * 12,
      swayAmp = 15 + math.random() * 25,
      swayPhase = math.random() * math.pi * 2,
      size = 3 + math.random() * 3,
      type = math.random(1, 3),  -- 1=eucalyptus sickle, 2=palo verde tiny, 3=mesquite
      timer = 0,
      lifetime = 6 + math.random() * 8,
    })
  end
end

-- ═══════════════════════════════════════
-- WILDFLOWER GROUND COVER (persistent)
-- ═══════════════════════════════════════
function M.regenerateWildflowers()
  wildflowers = {}
  math.randomseed(lighting.getDayNumber() * 77777)

  -- Arizona superbloom: Mexican gold poppies, lupine, globe mallow, brittlebush, penstemons
  -- Scatter in walkable zones (not mountains/water)
  local numPatches = 35 + math.random(0, 20)
  for i = 1, numPatches do
    local patchX = 3 + math.random(0, 62)
    local patchY = 5 + math.random(0, 45)
    local patchType = math.random(1, 6)
    -- 1=gold poppy, 2=lupine (purple), 3=globe mallow (orange), 4=brittlebush (yellow),
    -- 5=penstemon (red), 6=desert marigold (golden)
    local clusterSize = 4 + math.random(0, 6)

    for j = 1, clusterSize do
      table.insert(wildflowers, {
        x = patchX + math.random(-2, 2),
        y = patchY + math.random(-2, 2),
        species = patchType,
        size = 0.6 + math.random() * 0.6,
        swayOffset = math.random() * math.pi * 2,
        petalOffset = math.random() * math.pi * 2,
      })
    end
  end

  math.randomseed(os.time())
end

-- ═══════════════════════════════════════
-- FIREFLY SYSTEM (dusk & nighttime)
-- ═══════════════════════════════════════
function M.regenerateFireflies()
  fireflies = {}
  local numFireflies = 30 + math.random(0, 20)
  for i = 1, numFireflies do
    table.insert(fireflies, {
      x = 100 + math.random(0, 2000),
      y = 200 + math.random(0, 1400),
      z = 5 + math.random() * 50,
      glowPhase = math.random() * math.pi * 2,
      glowSpeed = 0.8 + math.random() * 1.5,
      glowOn = false,
      glowTimer = math.random() * 6,
      glowDuration = 0.3 + math.random() * 0.8,
      driftSpeed = 3 + math.random() * 8,
      driftPhase = math.random() * math.pi * 2,
      size = 1.5 + math.random() * 1.5,
    })
  end
end

-- ═══════════════════════════════════════
-- UPDATE
-- ═══════════════════════════════════════
function M.update(dt)
  M.updateWind(dt)
  M.updateClouds(dt)
  M.updateDustDevils(dt)
  M.updateRoadrunners(dt)
  M.updateLizards(dt)
  M.updateCoatimundis(dt)
  M.updateHummingbirds(dt)
  M.updateButterflies(dt)
  M.updatePollenMotes(dt)
  M.updateFallingLeaves(dt)
  M.updateFireflies(dt)
end

function M.updateWind(dt)
  local hour = lighting.getHour()
  -- Desert wind: calm mornings, builds through the day, gusts in afternoon
  if hour >= 11 and hour <= 17 then
    wind.baseStrength = 0.4 + math.sin(hour * 0.4) * 0.3
  elseif hour >= 17 and hour <= 20 then
    wind.baseStrength = 0.5  -- Evening winds
  else
    wind.baseStrength = 0.15  -- Calm desert mornings/nights
  end

  wind.gustTimer = wind.gustTimer - dt
  if wind.gustTimer <= 0 then
    wind.targetStrength = wind.baseStrength + math.random() * 0.25
    wind.gustTimer = 4 + math.random() * 10
  end

  wind.currentStrength = wind.currentStrength + (wind.targetStrength - wind.currentStrength) * 0.3 * dt
end

function M.updateClouds(dt)
  for _, cloud in ipairs(clouds) do
    cloud.x = cloud.x + cloud.speed * wind.currentStrength * dt
    if cloud.x > 2400 then
      cloud.x = -cloud.width
    end
  end
end

function M.updateDustDevils(dt)
  -- Spawn dust devils in hot conditions
  local shimmer = lighting.getHeatShimmer()
  if shimmer > 0.3 and #dustDevils < 3 and math.random() < 0.001 then
    table.insert(dustDevils, {
      x = math.random(200, 1800),
      y = math.random(400, 1400),
      radius = 8 + math.random() * 12,
      height = 40 + math.random() * 30,
      speed = 15 + math.random() * 25,
      angle = math.random() * math.pi * 2,
      lifetime = 5 + math.random() * 10,
      timer = 0,
      particles = {}
    })
  end

  for i = #dustDevils, 1, -1 do
    local dd = dustDevils[i]
    dd.timer = dd.timer + dt
    dd.angle = dd.angle + dt * 3
    dd.x = dd.x + wind.currentStrength * 20 * dt
    dd.y = dd.y + math.sin(dd.timer * 0.5) * 5 * dt

    if dd.timer >= dd.lifetime then
      table.remove(dustDevils, i)
    end
  end
end

function M.updateRoadrunners(dt)
  for _, bird in ipairs(roadrunners) do
    bird.animFrame = bird.animFrame + dt * (bird.running and 12 or 4)

    if bird.moving then
      local dx = bird.targetX - bird.x
      local dy = bird.targetY - bird.y
      local dist = math.sqrt(dx * dx + dy * dy)
      if dist < 5 then
        bird.moving = false
        bird.running = false
        bird.moveTimer = 2 + math.random() * 6
      else
        bird.x = bird.x + (dx / dist) * bird.speed * dt
        bird.y = bird.y + (dy / dist) * bird.speed * dt
        bird.direction = dx > 0 and 1 or -1
      end
    else
      bird.moveTimer = bird.moveTimer - dt
      if bird.moveTimer <= 0 then
        bird.targetX = bird.x + math.random(-200, 200)
        bird.targetY = bird.y + math.random(-100, 100)
        bird.targetX = math.max(100, math.min(2100, bird.targetX))
        bird.targetY = math.max(300, math.min(1500, bird.targetY))
        bird.moving = true
        bird.running = math.random() > 0.5
      end
    end
  end
end

function M.updateLizards(dt)
  for _, liz in ipairs(lizards) do
    liz.animFrame = liz.animFrame + dt * 6
    if liz.basking then
      liz.baskTimer = liz.baskTimer - dt
      if liz.baskTimer <= 0 then
        -- Quick dart to new position
        liz.basking = false
        liz.targetX = liz.x + math.random(-80, 80)
        liz.targetY = liz.y + math.random(-40, 40)
      end
    else
      local dx = liz.targetX - liz.x
      local dy = liz.targetY - liz.y
      local dist = math.sqrt(dx * dx + dy * dy)
      if dist < 3 then
        liz.basking = true
        liz.baskTimer = 3 + math.random() * 10
      else
        liz.x = liz.x + (dx / dist) * liz.speed * dt
        liz.y = liz.y + (dy / dist) * liz.speed * dt
        liz.direction = dx > 0 and 1 or -1
      end
    end
  end
end

-- ═══════════════════════════════════════
-- COATIMUNDI UPDATE (troop behavior — foraging, nose-poking, tail-up wandering)
-- ═══════════════════════════════════════
function M.updateCoatimundis(dt)
  -- Move troop center slowly (foraging wander)
  if #coatimundis > 0 then
    local leader = coatimundis[1]
    leader.troopX = leader.troopX + math.sin(love.timer.getTime() * 0.1) * 8 * dt
    leader.troopY = leader.troopY + math.cos(love.timer.getTime() * 0.08) * 5 * dt
    leader.troopX = math.max(100, math.min(2000, leader.troopX))
    leader.troopY = math.max(300, math.min(1500, leader.troopY))
    -- propagate troop center
    for _, c in ipairs(coatimundis) do
      c.troopX = leader.troopX
      c.troopY = leader.troopY
    end
  end

  for _, c in ipairs(coatimundis) do
    c.animFrame = c.animFrame + dt * 4
    c.tailPhase = c.tailPhase + dt * 2.5

    if c.foraging then
      c.foragePauseTimer = c.foragePauseTimer - dt
      c.animFrame = c.animFrame + dt * 2  -- faster nose-wiggle
      if c.foragePauseTimer <= 0 then
        c.foraging = false
        c.moveTimer = 1 + math.random() * 3
      end
    elseif c.moving then
      local dx = c.targetX - c.x
      local dy = c.targetY - c.y
      local dist = math.sqrt(dx * dx + dy * dy)
      if dist < 5 then
        c.moving = false
        -- Start foraging at destination
        if math.random() > 0.4 then
          c.foraging = true
          c.foragePauseTimer = 2 + math.random() * 4
        else
          c.moveTimer = 1 + math.random() * 2
        end
      else
        c.x = c.x + (dx / dist) * c.speed * dt
        c.y = c.y + (dy / dist) * c.speed * dt
        c.direction = dx > 0 and 1 or -1
      end
    else
      c.moveTimer = c.moveTimer - dt
      if c.moveTimer <= 0 then
        -- Move toward troop center with some scatter
        c.targetX = c.troopX + math.random(-80, 80)
        c.targetY = c.troopY + math.random(-60, 60)
        c.targetX = math.max(80, math.min(2100, c.targetX))
        c.targetY = math.max(250, math.min(1550, c.targetY))
        c.moving = true
      end
    end
  end
end

-- ═══════════════════════════════════════
-- HUMMINGBIRD UPDATE (hover, dart, visit flowers)
-- ═══════════════════════════════════════
function M.updateHummingbirds(dt)
  for _, h in ipairs(hummingbirds) do
    h.wingPhase = h.wingPhase + dt * 45  -- extremely fast wingbeat

    if h.darting then
      -- Rapid dart to new position (fast, decisive movement)
      local dx = h.hoverX - h.x
      local dy = h.hoverY - h.y
      local dist = math.sqrt(dx * dx + dy * dy)
      if dist < 4 then
        h.darting = false
        h.visiting = true
        h.visitTimer = 2 + math.random() * 4
        -- Snap to exact hover position (no drift)
        h.x = h.hoverX
        h.y = h.hoverY
      else
        -- Much faster dart speed
        h.x = h.x + (dx / dist) * h.speed * 5.0 * dt
        h.y = h.y + (dy / dist) * h.speed * 5.0 * dt
        h.direction = dx > 0 and 1 or -1
      end
    elseif h.visiting then
      -- Pollinating at a flower — hold perfectly still
      h.x = h.hoverX
      h.y = h.hoverY
      h.visitTimer = h.visitTimer - dt
      if h.visitTimer <= 0 then
        h.visiting = false
        h.flightTimer = 0.5 + math.random() * 2  -- shorter pause before next dart
      end
    else
      -- Brief idle pause (stationary, waiting to move)
      h.flightTimer = h.flightTimer - dt
      if h.flightTimer <= 0 then
        -- Dart to new flower location
        h.hoverX = 150 + math.random(0, 1900)
        h.hoverY = 350 + math.random(0, 900)
        h.darting = true
        h.direction = (h.hoverX > h.x) and 1 or -1
      end
    end
  end
end

-- ═══════════════════════════════════════
-- BUTTERFLY UPDATE
-- ═══════════════════════════════════════
function M.updateButterflies(dt)
  local hour = lighting.getHour()
  -- Butterflies retire at night
  if hour < 5.5 or hour > 20.5 then
    butterflies = {}
    return
  end

  for i = #butterflies, 1, -1 do
    local b = butterflies[i]
    b.wingPhase = b.wingPhase + dt * b.wingSpeed
    b.timer = (b.timer or 0) + dt

    if b.landed then
      b.landTimer = b.landTimer - dt
      -- Occasional wing flutter while landed
      if b.landTimer <= 0 then
        b.landed = false
        b.drifting = true
        b.driftTimer = 3 + math.random() * 6
      end
    elseif b.drifting then
      -- Lazy drifting flight — erratic, looping path
      b.glideAngle = b.glideAngle + (math.sin(b.timer * 0.8) * 1.5 + math.random() * 0.5 - 0.25) * dt
      b.x = b.x + math.cos(b.glideAngle) * b.speed * dt + wind.currentStrength * 5 * dt
      b.y = b.y + math.sin(b.glideAngle) * b.speed * 0.6 * dt
      b.z = b.z + math.sin(b.timer * 1.2) * 8 * dt

      -- Keep in bounds
      b.x = math.max(50, math.min(2200, b.x))
      b.y = math.max(200, math.min(1600, b.y))
      b.z = math.max(5, math.min(55, b.z))

      b.driftTimer = b.driftTimer - dt
      if b.driftTimer <= 0 then
        -- Land on a flower or surface
        if math.random() > 0.4 then
          b.landed = true
          b.landTimer = 3 + math.random() * 8
          b.z = 2  -- rest near ground
        else
          b.driftTimer = 2 + math.random() * 5
          b.glideAngle = math.random() * math.pi * 2
        end
      end
    end
  end

  -- Occasionally spawn a new butterfly if below threshold
  if #butterflies < 10 and math.random() < 0.005 then
    M.regenerateButterflies()
  end
end

-- ═══════════════════════════════════════
-- POLLEN MOTE & FALLING LEAF UPDATE
-- ═══════════════════════════════════════
function M.updatePollenMotes(dt)
  for _, m in ipairs(pollenMotes) do
    m.phase = m.phase + dt * 0.8
    m.x = m.x + wind.currentStrength * m.speed * dt + math.sin(m.phase) * m.drift * dt * 10
    m.y = m.y + math.sin(m.phase * 0.7) * 2 * dt
    m.z = m.z + math.cos(m.phase * 0.5) * 1.5 * dt

    -- Wrap around
    if m.x > 2400 then m.x = -50 end
    if m.x < -100 then m.x = 2300 end
    m.z = math.max(2, math.min(65, m.z))
  end
end

function M.updateFallingLeaves(dt)
  for i = #fallingLeaves, 1, -1 do
    local l = fallingLeaves[i]
    l.timer = l.timer + dt
    l.rotation = l.rotation + l.rotSpeed * dt
    l.swayPhase = l.swayPhase + dt * 1.5

    -- Falling with horizontal sway
    l.y = l.y + l.fallSpeed * dt
    l.x = l.x + math.sin(l.swayPhase) * l.swayAmp * dt + wind.currentStrength * 12 * dt

    if l.timer >= l.lifetime or l.y > 1800 then
      -- Respawn at top
      l.x = 100 + math.random(0, 1800)
      l.y = math.random(-100, 200)
      l.timer = 0
      l.lifetime = 6 + math.random() * 8
    end
  end
end

-- ═══════════════════════════════════════
-- FIREFLY UPDATE
-- ═══════════════════════════════════════
function M.updateFireflies(dt)
  local hour = lighting.getHour()
  -- Only active dusk–dawn (roughly 18:00–5:30)
  local active = (hour >= 18 or hour < 5.5)
  if not active then return end

  for _, f in ipairs(fireflies) do
    f.driftPhase = f.driftPhase + dt * 0.6
    f.x = f.x + math.sin(f.driftPhase) * f.driftSpeed * dt
    f.y = f.y + math.cos(f.driftPhase * 0.7) * f.driftSpeed * 0.6 * dt
    f.z = f.z + math.sin(f.driftPhase * 0.3) * 3 * dt
    f.z = math.max(3, math.min(55, f.z))

    -- Bioluminescent pulse
    if f.glowOn then
      f.glowTimer = f.glowTimer - dt
      if f.glowTimer <= 0 then
        f.glowOn = false
        f.glowTimer = 2 + math.random() * 5  -- off period
      end
    else
      f.glowTimer = f.glowTimer - dt
      if f.glowTimer <= 0 then
        f.glowOn = true
        f.glowTimer = f.glowDuration
      end
    end
  end
end

-- ═══════════════════════════════════════
-- GETTERS
-- ═══════════════════════════════════════
function M.getWindStrength() return wind.currentStrength end

function M.getWindSway(x, time, amplitude)
  amplitude = amplitude or 1
  local phase = x * 0.02 + time * 0.5 * wind.currentStrength
  local sway = math.sin(phase) * wind.currentStrength * amplitude
  sway = sway + math.sin(phase * 0.6 + x * 0.04) * wind.currentStrength * amplitude * 0.3
  return sway
end

-- ═══════════════════════════════════════
-- DRAW: SKY & MOUNTAINS
-- ═══════════════════════════════════════

function M.drawSky(screenW, screenH)
  local horizonColor, zenithColor = lighting.getSkyColors()
  local segments = 25
  for i = 0, segments - 1 do
    local t1 = i / segments
    local t2 = (i + 1) / segments
    local y1 = t1 * screenH * 0.45
    local y2 = t2 * screenH * 0.45

    local r = zenithColor[1] + (horizonColor[1] - zenithColor[1]) * t1
    local g = zenithColor[2] + (horizonColor[2] - zenithColor[2]) * t1
    local b = zenithColor[3] + (horizonColor[3] - zenithColor[3]) * t1

    love.graphics.setColor(r, g, b)
    love.graphics.rectangle("fill", 0, y1, screenW, y2 - y1 + 1)
  end

  -- Stars at night
  if lighting.isNight() then
    local _, intensity = lighting.getAmbientLight()
    local starAlpha = math.max(0, (0.3 - intensity) * 3)
    if starAlpha > 0 then
      math.randomseed(lighting.getDayNumber() * 999)
      for i = 1, 80 do
        local sx = math.random(0, screenW)
        local sy = math.random(0, math.floor(screenH * 0.4))
        local brightness = 0.5 + math.random() * 0.5
        local twinkle = math.sin(love.timer.getTime() * 2 + i * 1.7) * 0.3 + 0.7
        love.graphics.setColor(1, 1, 0.95, starAlpha * brightness * twinkle)
        love.graphics.circle("fill", sx, sy, 1 + math.random() * 1.5)
      end
      math.randomseed(os.time())
    end
  end
end

-- Draw distant mountain silhouettes in the background
function M.drawDistantMountains(screenW, screenH, cameraX, cameraY)
  local ambientColor, ambientIntensity = lighting.getAmbientLight()
  local sunsetGlow = lighting.getSunsetGlow()

  -- Layer 1: Far background mountains (Superstition Mountains)
  local layerY = screenH * 0.2
  love.graphics.setColor(
    (0.45 + sunsetGlow * 0.2) * ambientIntensity,
    (0.35 + sunsetGlow * 0.05) * ambientIntensity,
    (0.42 - sunsetGlow * 0.1) * ambientIntensity,
    0.6
  )
  local farParallax = cameraX * 0.02
  local peaks1 = {}
  for px = -50, screenW + 50, 8 do
    local peakHeight = math.sin((px + farParallax) * 0.008) * 40
      + math.sin((px + farParallax) * 0.015) * 25
      + math.sin((px + farParallax) * 0.003) * 60
    table.insert(peaks1, px)
    table.insert(peaks1, layerY - peakHeight - 20)
  end
  table.insert(peaks1, screenW + 50)
  table.insert(peaks1, screenH)
  table.insert(peaks1, -50)
  table.insert(peaks1, screenH)
  if #peaks1 >= 6 then
    love.graphics.polygon("fill", peaks1)
  end

  -- Layer 2: Mid-distance mesas (Picketpost visible)
  local layer2Y = screenH * 0.28
  love.graphics.setColor(
    (0.52 + sunsetGlow * 0.25) * ambientIntensity,
    (0.40 + sunsetGlow * 0.08) * ambientIntensity,
    (0.35 - sunsetGlow * 0.05) * ambientIntensity,
    0.75
  )
  local midParallax = cameraX * 0.04
  local peaks2 = {}
  for px = -50, screenW + 50, 6 do
    local peakHeight = math.sin((px + midParallax) * 0.012) * 35
      + math.sin((px + midParallax) * 0.025) * 20
      + math.sin((px + midParallax) * 0.005) * 45
    -- Mesa flat tops
    if math.sin((px + midParallax) * 0.009) > 0.7 then
      peakHeight = peakHeight + 15
    end
    table.insert(peaks2, px)
    table.insert(peaks2, layer2Y - peakHeight - 10)
  end
  table.insert(peaks2, screenW + 50)
  table.insert(peaks2, screenH)
  table.insert(peaks2, -50)
  table.insert(peaks2, screenH)
  if #peaks2 >= 6 then
    love.graphics.polygon("fill", peaks2)
  end

  -- Layer 3: Near mountains with volcanic texture
  local layer3Y = screenH * 0.35
  love.graphics.setColor(
    (0.58 + sunsetGlow * 0.15) * ambientIntensity,
    (0.45 + sunsetGlow * 0.05) * ambientIntensity,
    (0.38) * ambientIntensity,
    0.85
  )
  local nearParallax = cameraX * 0.07
  local peaks3 = {}
  for px = -50, screenW + 50, 5 do
    local peakHeight = math.sin((px + nearParallax) * 0.018) * 30
      + math.sin((px + nearParallax) * 0.035) * 18
      + math.sin((px + nearParallax) * 0.007) * 40
    -- Jagged volcanic ridges
    peakHeight = peakHeight + math.sin((px + nearParallax) * 0.08) * 8
    table.insert(peaks3, px)
    table.insert(peaks3, layer3Y - peakHeight)
  end
  table.insert(peaks3, screenW + 50)
  table.insert(peaks3, screenH)
  table.insert(peaks3, -50)
  table.insert(peaks3, screenH)
  if #peaks3 >= 6 then
    love.graphics.polygon("fill", peaks3)
  end
end

-- Draw clouds
function M.drawClouds(cameraX, cameraY, time)
  local sunsetGlow = lighting.getSunsetGlow()

  for _, cloud in ipairs(clouds) do
    local parallaxX = cloud.x - cameraX * 0.08
    local parallaxY = cloud.y

    local r, g, b = 0.95, 0.95, 0.95
    if sunsetGlow > 0 then
      r = 0.95 + sunsetGlow * 0.05
      g = 0.95 - sunsetGlow * 0.3
      b = 0.95 - sunsetGlow * 0.45
    end

    love.graphics.setColor(r, g, b, cloud.opacity)
    for _, puff in ipairs(cloud.puffs) do
      love.graphics.ellipse("fill",
        parallaxX + puff.offsetX,
        parallaxY + puff.offsetY,
        puff.radius * 1.3,
        puff.radius * 0.7
      )
    end

    -- Cloud shadow on desert floor
    if not lighting.isNight() then
      local shadowY = 1000 + parallaxY * 2
      love.graphics.setColor(0, 0, 0, 0.04 * cloud.opacity)
      for _, puff in ipairs(cloud.puffs) do
        love.graphics.ellipse("fill",
          parallaxX + puff.offsetX + 60,
          shadowY,
          puff.radius * 1.8,
          puff.radius * 0.3
        )
      end
    end
  end
end

-- ═══════════════════════════════════════
-- DRAW: DESERT FLORA
-- ═══════════════════════════════════════

-- Draw a saguaro cactus (iconic Sonoran Desert)
function M.drawSaguaro(x, y, gs, time, arms, height)
  arms = arms or 2
  height = height or 3
  local baseX = x * gs + gs / 2
  local baseY = y * gs + gs
  local ambientColor, ambientIntensity = lighting.getAmbientLight()
  local sway = M.getWindSway(x * gs, time, 1)

  local trunkHeight = height * gs
  local trunkWidth = 12

  -- Main trunk (pleated/ribbed)
  local segments = 14
  for i = 0, segments - 1 do
    local t = i / segments
    local segSway = sway * t * 0.3
    local w = trunkWidth - t * 3

    local y1 = baseY - t * trunkHeight
    local y2 = baseY - (t + 1 / segments) * trunkHeight
    local cx = baseX + segSway

    -- Deep green body
    local shade = 0.9 + math.sin(i * 1.8 + x) * 0.1
    love.graphics.setColor(
      0.18 * shade * ambientIntensity,
      0.42 * shade * ambientIntensity,
      0.15 * shade * ambientIntensity
    )
    love.graphics.polygon("fill",
      cx - w / 2, y1,
      cx + w / 2, y1,
      cx + w / 2 - 0.2, y2,
      cx - w / 2 + 0.2, y2
    )

    -- Vertical ribs (pleats)
    love.graphics.setColor(
      0.12 * shade * ambientIntensity,
      0.35 * shade * ambientIntensity,
      0.10 * shade * ambientIntensity,
      0.5
    )
    for rib = -2, 2 do
      local ribX = cx + rib * (w / 5)
      love.graphics.line(ribX, y1, ribX, y2)
    end

    -- Highlight on sun-facing side
    love.graphics.setColor(
      0.30 * shade * ambientIntensity,
      0.55 * shade * ambientIntensity,
      0.25 * shade * ambientIntensity,
      0.2
    )
    love.graphics.polygon("fill",
      cx + w / 4, y1,
      cx + w / 2, y1,
      cx + w / 2 - 0.2, y2,
      cx + w / 4, y2
    )
  end

  -- Saguaro crown (top dome)
  local topX = baseX + sway * 0.3
  local topY = baseY - trunkHeight
  love.graphics.setColor(0.20 * ambientIntensity, 0.45 * ambientIntensity, 0.18 * ambientIntensity)
  love.graphics.ellipse("fill", topX, topY, trunkWidth / 2 - 1, 5)

  -- Arms
  for i = 1, math.min(arms, 4) do
    local armDir = (i % 2 == 0) and 1 or -1
    local armStartY = baseY - trunkHeight * (0.35 + i * 0.12)
    local armLength = gs * (1.2 + math.sin(x + i) * 0.3)
    local armSway = sway * 0.2

    -- Arm going horizontal then curving up
    local armSegs = 8
    local lastAX, lastAY = baseX + armSway * 0.3, armStartY
    for j = 1, armSegs do
      local t = j / armSegs
      -- Horizontal then upward curve
      local ax = lastAX + armDir * (armLength / armSegs) * math.max(0, 1 - t * 0.8)
      local ay = armStartY - t * t * armLength * 0.6 + armSway * t

      local armW = 8 - t * 4
      local shade = 0.9 + math.sin(j * 2.1) * 0.1
      love.graphics.setColor(
        0.18 * shade * ambientIntensity,
        0.42 * shade * ambientIntensity,
        0.15 * shade * ambientIntensity
      )
      love.graphics.polygon("fill",
        lastAX - armW / 2, lastAY,
        lastAX + armW / 2, lastAY,
        ax + armW / 2, ay,
        ax - armW / 2, ay
      )

      lastAX, lastAY = ax, ay
    end

    -- Arm top dome
    love.graphics.setColor(0.22 * ambientIntensity, 0.48 * ambientIntensity, 0.20 * ambientIntensity)
    love.graphics.ellipse("fill", lastAX, lastAY, 4, 3)
  end

  -- Spines (tiny white dots/lines radiating outward)
  love.graphics.setColor(0.85, 0.82, 0.72, 0.3 * ambientIntensity)
  for i = 1, 12 do
    local spineY = baseY - (i / 12) * trunkHeight * 0.9
    local spineX = baseX + sway * (i / 12) * 0.3
    love.graphics.circle("fill", spineX - trunkWidth / 2 - 1, spineY, 0.8)
    love.graphics.circle("fill", spineX + trunkWidth / 2 + 1, spineY, 0.8)
  end

  -- Saguaro flowers at top (spring bloom — white blossoms)
  local hour = lighting.getHour()
  if hour >= 6 and hour <= 18 then
    love.graphics.setColor(0.98 * ambientIntensity, 0.95 * ambientIntensity, 0.85 * ambientIntensity)
    love.graphics.circle("fill", topX - 2, topY - 4, 3)
    love.graphics.circle("fill", topX + 2, topY - 3, 2.5)
    -- Yellow stamen
    love.graphics.setColor(0.95, 0.85, 0.3, ambientIntensity)
    love.graphics.circle("fill", topX, topY - 4, 1.5)
  end
end

-- Draw barrel cactus
function M.drawBarrelCactus(x, y, gs, time)
  local baseX = x * gs + gs / 2
  local baseY = y * gs + gs
  local ambientColor, ambientIntensity = lighting.getAmbientLight()

  -- Round barrel body
  local radius = gs * 0.35
  love.graphics.setColor(0.22 * ambientIntensity, 0.40 * ambientIntensity, 0.18 * ambientIntensity)
  love.graphics.ellipse("fill", baseX, baseY - radius, radius, radius * 1.1)

  -- Ribs
  love.graphics.setColor(0.15 * ambientIntensity, 0.32 * ambientIntensity, 0.12 * ambientIntensity, 0.6)
  for i = 1, 6 do
    local ribAngle = (i / 6) * math.pi
    love.graphics.line(
      baseX + math.cos(ribAngle) * radius * 0.2,
      baseY - radius * 2,
      baseX + math.cos(ribAngle) * radius,
      baseY
    )
  end

  -- Central crown (wool and spines)
  love.graphics.setColor(0.80, 0.75, 0.55, 0.5 * ambientIntensity)
  love.graphics.ellipse("fill", baseX, baseY - radius * 1.8, radius * 0.4, radius * 0.3)

  -- Spines at apex
  love.graphics.setColor(0.85, 0.78, 0.6, 0.4 * ambientIntensity)
  for i = 1, 8 do
    local ang = (i / 8) * math.pi * 2
    love.graphics.line(
      baseX, baseY - radius * 1.8,
      baseX + math.cos(ang) * 6, baseY - radius * 1.8 + math.sin(ang) * 4
    )
  end
end

-- Draw prickly pear cactus (flat paddle segments)
function M.drawPricklyPear(x, y, gs, time, w, h)
  local baseX = x * gs
  local baseY = y * gs + gs
  local ambientColor, ambientIntensity = lighting.getAmbientLight()
  w = w or 1
  local sway = M.getWindSway(x * gs, time, 0.5)

  -- Draw paddle segments
  local paddles = {{0, 0}, {-8 + sway, -18}, {10 + sway, -20}, {-3 + sway * 0.5, -35}, {15 + sway * 0.7, -32}}
  for i, pad in ipairs(paddles) do
    local px = baseX + gs * 0.5 + pad[1]
    local py = baseY + pad[2]
    local pw = 14 - i * 1.5
    local ph = 18 - i * 2

    -- Paddle body
    local shade = 0.9 + math.sin(i * 2.3) * 0.1
    love.graphics.setColor(
      0.28 * shade * ambientIntensity,
      0.52 * shade * ambientIntensity,
      0.22 * shade * ambientIntensity
    )
    love.graphics.ellipse("fill", px, py, pw, ph)

    -- Areole dots (spine clusters)
    love.graphics.setColor(0.75, 0.72, 0.58, 0.4 * ambientIntensity)
    for j = 1, 5 do
      local ax = px + math.cos(j * 1.3 + i) * pw * 0.6
      local ay = py + math.sin(j * 1.8 + i) * ph * 0.6
      love.graphics.circle("fill", ax, ay, 1.5)
    end

    -- Prickly pear fruit (tunas — red/magenta at top paddles)
    if i >= 3 and math.sin(x + i) > 0 then
      love.graphics.setColor(0.8 * ambientIntensity, 0.15 * ambientIntensity, 0.25 * ambientIntensity)
      love.graphics.ellipse("fill", px + pw * 0.5, py - ph * 0.3, 4, 5)
    end
  end
end

-- Draw ocotillo (tall spindly desert shrub)
function M.drawOcotillo(x, y, gs, time)
  local baseX = x * gs + gs / 2
  local baseY = y * gs + gs
  local ambientColor, ambientIntensity = lighting.getAmbientLight()
  local sway = M.getWindSway(x * gs, time, 3)

  -- 5-8 tall thin stems radiating from base
  local numStems = 5 + math.floor(math.sin(x * 3.7 + y * 2.1) * 1.5 + 1.5)
  for i = 1, numStems do
    local stemAngle = (i / numStems) * math.pi - math.pi / 2 + math.sin(x + i) * 0.2
    local stemLength = gs * (2.5 + math.sin(i * 1.7) * 0.5)
    local stemSway = sway * 0.3

    -- Draw stem segments
    local segs = 8
    local lastSX, lastSY = baseX, baseY
    for j = 1, segs do
      local t = j / segs
      local sx = baseX + math.cos(stemAngle) * stemLength * t * 0.3 + stemSway * t * t
      local sy = baseY - stemLength * t + math.sin(t * math.pi * 0.3) * 5

      -- Brown-green stem
      love.graphics.setColor(
        0.38 * ambientIntensity,
        0.30 * ambientIntensity + t * 0.08,
        0.18 * ambientIntensity
      )
      love.graphics.setLineWidth(3 - t * 2)
      love.graphics.line(lastSX, lastSY, sx, sy)

      -- Small leaves during green season
      if t > 0.3 and t < 0.9 then
        love.graphics.setColor(0.25 * ambientIntensity, 0.50 * ambientIntensity, 0.20 * ambientIntensity, 0.7)
        love.graphics.circle("fill", sx + 2, sy, 2)
        love.graphics.circle("fill", sx - 2, sy - 1, 1.8)
      end

      lastSX, lastSY = sx, sy
    end

    -- Red flower tip (blooming season)
    love.graphics.setColor(0.90 * ambientIntensity, 0.15 * ambientIntensity, 0.10 * ambientIntensity)
    love.graphics.ellipse("fill", lastSX, lastSY - 3, 3, 6)
    love.graphics.setColor(0.95 * ambientIntensity, 0.25 * ambientIntensity, 0.12 * ambientIntensity)
    love.graphics.ellipse("fill", lastSX, lastSY - 5, 2, 4)
  end
  love.graphics.setLineWidth(1)
end

-- Draw desert tree (palo verde, ironwood, mesquite)
function M.drawDesertTree(x, y, gs, time, variety)
  variety = variety or "palo_verde"
  local baseX = x * gs + gs / 2
  local baseY = y * gs + gs
  local ambientColor, ambientIntensity = lighting.getAmbientLight()
  local sway = M.getWindSway(x * gs, time, 2)
  local treeSeed = x * 7 + y * 13

  -- Trunk colors by species
  local trunkR, trunkG, trunkB
  local leafR, leafG, leafB
  local canopyR, canopyG, canopyB

  if variety == "palo_verde" then
    -- Green bark (photosynthetic trunk — unique to palo verde!)
    trunkR, trunkG, trunkB = 0.35, 0.50, 0.25
    leafR, leafG, leafB = 0.40, 0.60, 0.25
    canopyR, canopyG, canopyB = 0.35, 0.55, 0.22
  elseif variety == "ironwood" then
    trunkR, trunkG, trunkB = 0.40, 0.32, 0.25
    leafR, leafG, leafB = 0.30, 0.45, 0.22
    canopyR, canopyG, canopyB = 0.28, 0.42, 0.20
  else  -- mesquite
    trunkR, trunkG, trunkB = 0.42, 0.35, 0.22
    leafR, leafG, leafB = 0.32, 0.50, 0.20
    canopyR, canopyG, canopyB = 0.30, 0.48, 0.18
  end

  local trunkHeight = gs * 2.2
  local trunkWidth = 10

  -- Trunk with branches
  local segments = 10
  for i = 0, segments - 1 do
    local t = i / segments
    local w = trunkWidth - t * 5
    local y1 = baseY - t * trunkHeight
    local y2 = baseY - (t + 1 / segments) * trunkHeight
    local segSway = sway * t * 0.4

    love.graphics.setColor(trunkR * ambientIntensity, trunkG * ambientIntensity, trunkB * ambientIntensity)
    love.graphics.polygon("fill",
      baseX + segSway - w / 2, y1,
      baseX + segSway + w / 2, y1,
      baseX + segSway + w / 2 - 0.3, y2,
      baseX + segSway - w / 2 + 0.3, y2
    )
  end

  -- Branching canopy (sparse, lacy — desert style)
  local canopyX = baseX + sway * 0.4
  local canopyY = baseY - trunkHeight
  local canopyRadius = gs * 1.2

  -- Multiple canopy puffs for lacy look
  for i = 1, 7 do
    local puffAngle = (i / 7) * math.pi * 2 + treeSeed
    local puffDist = canopyRadius * (0.3 + math.sin(treeSeed + i * 2.3) * 0.4)
    local puffX = canopyX + math.cos(puffAngle) * puffDist
    local puffY = canopyY - math.abs(math.sin(puffAngle)) * canopyRadius * 0.5
    local puffR = 8 + math.sin(treeSeed + i) * 4

    love.graphics.setColor(canopyR * ambientIntensity, canopyG * ambientIntensity, canopyB * ambientIntensity, 0.85)
    love.graphics.ellipse("fill", puffX, puffY, puffR * 1.2, puffR * 0.8)

    -- Leaf detail (tiny scattered dots)
    love.graphics.setColor(leafR * ambientIntensity, leafG * ambientIntensity, leafB * ambientIntensity, 0.6)
    for j = 1, 5 do
      local lx = puffX + math.cos(j * 2.1 + i) * puffR * 0.7
      local ly = puffY + math.sin(j * 1.5 + i) * puffR * 0.5
      love.graphics.circle("fill", lx, ly, 2)
    end
  end

  -- Palo verde: yellow flowers in bloom
  if variety == "palo_verde" then
    love.graphics.setColor(0.95 * ambientIntensity, 0.85 * ambientIntensity, 0.2 * ambientIntensity, 0.7)
    for i = 1, 10 do
      local fx = canopyX + math.cos(treeSeed + i * 1.5) * canopyRadius * 0.8
      local fy = canopyY - math.abs(math.sin(treeSeed + i * 2)) * canopyRadius * 0.5
      love.graphics.circle("fill", fx, fy, 2.5)
    end
  end
end

-- Draw eucalyptus tree (tall, peeling bark, drooping leaves)
function M.drawEucalyptus(x, y, gs, time)
  local baseX = x * gs + gs / 2
  local baseY = y * gs + gs
  local ambientColor, ambientIntensity = lighting.getAmbientLight()
  local sway = M.getWindSway(x * gs, time, 2.5)
  local treeSeed = x * 11 + y * 17

  local trunkHeight = gs * 4.0
  local trunkWidth = 14

  -- Trunk with peeling bark texture (Ghost Gum style)
  local segments = 16
  for i = 0, segments - 1 do
    local t = i / segments
    local w = trunkWidth - t * 6
    local y1 = baseY - t * trunkHeight
    local y2 = baseY - (t + 1 / segments) * trunkHeight
    local segSway = sway * t * t * 0.4

    -- White/cream bark (Ghost Gum eucalyptus)
    local barkShade = 0.95 + math.sin(treeSeed + i * 2.5) * 0.05
    love.graphics.setColor(
      0.78 * barkShade * ambientIntensity,
      0.75 * barkShade * ambientIntensity,
      0.68 * barkShade * ambientIntensity
    )
    love.graphics.polygon("fill",
      baseX + segSway - w / 2, y1,
      baseX + segSway + w / 2, y1,
      baseX + segSway + w / 2 - 0.3, y2,
      baseX + segSway - w / 2 + 0.3, y2
    )

    -- Peeling bark patches (orange/tan underneath)
    if math.sin(treeSeed + i * 3.1) > 0.2 then
      love.graphics.setColor(
        0.72 * ambientIntensity,
        0.55 * ambientIntensity,
        0.35 * ambientIntensity,
        0.5
      )
      local patchW = w * 0.4
      local patchX = baseX + segSway + math.sin(treeSeed + i * 1.7) * w * 0.2
      love.graphics.rectangle("fill", patchX - patchW / 2, y1, patchW, (y1 - y2) * 0.6)
    end
  end

  -- Drooping eucalyptus canopy
  local canopyX = baseX + sway * 0.5
  local canopyY = baseY - trunkHeight
  local canopyRadius = gs * 1.5

  -- Main canopy mass
  love.graphics.setColor(0.25 * ambientIntensity, 0.48 * ambientIntensity, 0.28 * ambientIntensity, 0.9)
  love.graphics.ellipse("fill", canopyX, canopyY, canopyRadius, canopyRadius * 0.7)

  -- Drooping leaf clusters
  for i = 1, 9 do
    local drAngle = (i / 9) * math.pi * 2 + treeSeed
    local drDist = canopyRadius * (0.6 + math.sin(treeSeed + i) * 0.3)
    local drX = canopyX + math.cos(drAngle) * drDist
    local drY = canopyY + math.sin(drAngle) * canopyRadius * 0.5 + 5
    local drLen = 12 + math.sin(treeSeed + i * 1.5) * 5

    -- Hanging leaf strand
    love.graphics.setColor(0.22 * ambientIntensity, 0.45 * ambientIntensity, 0.25 * ambientIntensity, 0.8)
    love.graphics.setLineWidth(2)
    love.graphics.line(drX, drY, drX + sway * 0.2, drY + drLen)
    love.graphics.setLineWidth(1)

    -- Leaf tip
    love.graphics.setColor(0.28 * ambientIntensity, 0.52 * ambientIntensity, 0.30 * ambientIntensity, 0.7)
    love.graphics.ellipse("fill", drX + sway * 0.2, drY + drLen, 3, 5)
  end
end

-- Draw boojum tree (bizarre Baja California columnar plant)
function M.drawBoojum(x, y, gs, time)
  local baseX = x * gs + gs / 2
  local baseY = y * gs + gs
  local ambientColor, ambientIntensity = lighting.getAmbientLight()
  local sway = M.getWindSway(x * gs, time, 1.5)

  local trunkHeight = gs * 3.5
  local baseWidth = 16

  -- Tapered inverted-cone trunk (wider at bottom)
  local segments = 12
  for i = 0, segments - 1 do
    local t = i / segments
    local w = baseWidth * (1 - t * 0.85)
    local y1 = baseY - t * trunkHeight
    local y2 = baseY - (t + 1 / segments) * trunkHeight
    local segSway = sway * t * 0.5

    -- Gray-green bark
    love.graphics.setColor(
      0.50 * ambientIntensity,
      0.48 * ambientIntensity,
      0.38 * ambientIntensity
    )
    love.graphics.polygon("fill",
      baseX + segSway - w / 2, y1,
      baseX + segSway + w / 2, y1,
      baseX + segSway + w / 2 - 0.5, y2,
      baseX + segSway - w / 2 + 0.5, y2
    )

    -- Spiny branches sticking out
    if t > 0.1 and t < 0.85 and i % 2 == 0 then
      local branchDir = (i % 4 < 2) and -1 or 1
      love.graphics.setColor(0.42 * ambientIntensity, 0.38 * ambientIntensity, 0.28 * ambientIntensity)
      love.graphics.setLineWidth(1.5)
      local bx = baseX + segSway + branchDir * w / 2
      local by = (y1 + y2) / 2
      love.graphics.line(bx, by, bx + branchDir * 10, by - 3)
      -- Tiny leaves
      love.graphics.setColor(0.30 * ambientIntensity, 0.50 * ambientIntensity, 0.22 * ambientIntensity, 0.7)
      love.graphics.circle("fill", bx + branchDir * 10, by - 3, 2)
    end
  end
  love.graphics.setLineWidth(1)

  -- Yellow flower cluster at tip
  local topX = baseX + sway * 0.5
  local topY = baseY - trunkHeight
  love.graphics.setColor(0.95 * ambientIntensity, 0.82 * ambientIntensity, 0.25 * ambientIntensity)
  love.graphics.ellipse("fill", topX, topY - 3, 4, 6)
end

-- Draw agave rosette
function M.drawAgave(x, y, gs, time)
  local baseX = x * gs + gs / 2
  local baseY = y * gs + gs - 4
  local ambientColor, ambientIntensity = lighting.getAmbientLight()
  local sway = M.getWindSway(x * gs, time, 0.3)

  -- Rosette of thick pointed leaves
  local numLeaves = 12
  for i = 1, numLeaves do
    local angle = (i / numLeaves) * math.pi * 2
    local leafLen = 14 + math.sin(x + i * 1.5) * 3
    local leafSway = sway * 0.1

    local tipX = baseX + math.cos(angle) * leafLen + leafSway
    local tipY = baseY + math.sin(angle) * leafLen * 0.4

    -- Blue-green thick leaf
    local shade = 0.85 + math.sin(i * 1.3) * 0.15
    love.graphics.setColor(
      0.30 * shade * ambientIntensity,
      0.50 * shade * ambientIntensity,
      0.42 * shade * ambientIntensity
    )
    love.graphics.polygon("fill",
      baseX - 2, baseY,
      baseX + 2, baseY,
      tipX, tipY
    )

    -- Spine at tip
    love.graphics.setColor(0.25 * ambientIntensity, 0.15 * ambientIntensity, 0.08 * ambientIntensity)
    love.graphics.circle("fill", tipX, tipY, 1.5)
  end

  -- Central bud
  love.graphics.setColor(0.35 * ambientIntensity, 0.55 * ambientIntensity, 0.45 * ambientIntensity)
  love.graphics.circle("fill", baseX, baseY, 4)
end

-- Draw yucca
function M.drawYucca(x, y, gs, time)
  local baseX = x * gs + gs / 2
  local baseY = y * gs + gs - 2
  local ambientColor, ambientIntensity = lighting.getAmbientLight()
  local sway = M.getWindSway(x * gs, time, 1.5)

  -- Cluster of sword-like leaves
  local numLeaves = 14
  for i = 1, numLeaves do
    local angle = (i / numLeaves) * math.pi * 2
    local leafLen = 18 + math.sin(x + i * 2.1) * 4
    local leafSway = sway * 0.15

    local midX = baseX + math.cos(angle) * leafLen * 0.5
    local midY = baseY - leafLen * 0.4
    local tipX = midX + math.cos(angle) * leafLen * 0.5 + leafSway
    local tipY = midY + leafLen * 0.15  -- Tips droop slightly

    -- Yellowish-green stiff leaf
    love.graphics.setColor(
      0.45 * ambientIntensity,
      0.55 * ambientIntensity,
      0.28 * ambientIntensity
    )
    love.graphics.setLineWidth(2.5)
    love.graphics.line(baseX, baseY, midX, midY)
    love.graphics.setLineWidth(1.5)
    love.graphics.line(midX, midY, tipX, tipY)
  end

  -- Flower stalk (tall white bloom spike)
  love.graphics.setColor(0.55 * ambientIntensity, 0.50 * ambientIntensity, 0.35 * ambientIntensity)
  love.graphics.setLineWidth(3)
  love.graphics.line(baseX, baseY, baseX + sway * 0.3, baseY - gs * 2)
  love.graphics.setLineWidth(1)

  -- White bell flowers
  love.graphics.setColor(0.95 * ambientIntensity, 0.92 * ambientIntensity, 0.82 * ambientIntensity)
  for i = 1, 6 do
    local fy = baseY - gs * 2 + i * 6
    local fx = baseX + sway * 0.3 + math.sin(i * 2.3) * 4
    love.graphics.ellipse("fill", fx, fy, 3, 4)
  end
end

-- ═══════════════════════════════════════
-- DRAW: GEOLOGICAL FEATURES
-- ═══════════════════════════════════════

-- Draw mountain range in the game world (not background)
function M.drawMountain(mtn, gs, time)
  local ambientColor, ambientIntensity = lighting.getAmbientLight()
  local sunsetGlow = lighting.getSunsetGlow()

  local x1 = mtn.x1 * gs
  local y1 = mtn.y1 * gs
  local x2 = (mtn.x2 + 1) * gs
  local y2 = (mtn.y2 + 1) * gs
  local mtnHeight = (mtn.height or 3) * gs

  -- Base mountain fill
  local r = (mtn.color[1] + sunsetGlow * 0.15) * ambientIntensity
  local g = (mtn.color[2] + sunsetGlow * 0.05) * ambientIntensity
  local b = (mtn.color[3] - sunsetGlow * 0.05) * ambientIntensity
  love.graphics.setColor(r, g, b)
  love.graphics.rectangle("fill", x1, y1, x2 - x1, y2 - y1)

  -- Jagged peak silhouette at top
  local peaks = {}
  for px = x1, x2, 4 do
    local peakH = math.sin(px * 0.025 + (mtn.y1 or 0)) * mtnHeight * 0.3
      + math.sin(px * 0.06 + (mtn.x1 or 0)) * mtnHeight * 0.15
      + math.sin(px * 0.12) * mtnHeight * 0.08
    -- Volcanic jaggedness
    if mtn.volcanic then
      peakH = peakH + math.sin(px * 0.15 + 5) * mtnHeight * 0.1
    end
    table.insert(peaks, px)
    table.insert(peaks, y1 - peakH)
  end
  -- Close the polygon along the flat top edge of the mountain tile area
  table.insert(peaks, x2)
  table.insert(peaks, y1)
  table.insert(peaks, x1)
  table.insert(peaks, y1)
  if #peaks >= 6 then
    love.graphics.setColor(
      (mtn.peakColor[1] + sunsetGlow * 0.2) * ambientIntensity,
      (mtn.peakColor[2] + sunsetGlow * 0.05) * ambientIntensity,
      (mtn.peakColor[3] - sunsetGlow * 0.05) * ambientIntensity
    )
    love.graphics.polygon("fill", peaks)
  end

  -- Rocky texture (cracks and strata lines)
  love.graphics.setColor(mtn.color[1] * 0.7 * ambientIntensity, mtn.color[2] * 0.7 * ambientIntensity, mtn.color[3] * 0.7 * ambientIntensity, 0.3)
  for stratum = 0, 3 do
    local sy = y1 + stratum * ((y2 - y1) / 4) + 5
    love.graphics.setLineWidth(1)
    local linePoints = {}
    for px = x1, x2, 8 do
      table.insert(linePoints, px)
      table.insert(linePoints, sy + math.sin(px * 0.1 + stratum) * 3)
    end
    if #linePoints >= 4 then
      love.graphics.line(linePoints)
    end
  end

  -- Sun-facing highlight (eastern face in morning, western in evening)
  local sdx, sdy = lighting.getSunDirection()
  if sdx ~= 0 then
    local highlightSide = sdx > 0 and x1 or (x2 - 15)
    love.graphics.setColor(
      mtn.peakColor[1] * 1.2 * ambientIntensity,
      mtn.peakColor[2] * 1.1 * ambientIntensity,
      mtn.peakColor[3] * 1.05 * ambientIntensity,
      0.15
    )
    love.graphics.rectangle("fill", highlightSide, y1, 15, y2 - y1)
  end

  -- Shadow on opposite face
  local shadowSide = sdx > 0 and (x2 - 20) or x1
  love.graphics.setColor(0, 0, 0, 0.12)
  love.graphics.rectangle("fill", shadowSide, y1, 20, y2 - y1)
end

-- Draw boulder/rock formation
function M.drawBoulder(x, y, gs, size)
  local ambientColor, ambientIntensity = lighting.getAmbientLight()
  local baseX = x * gs + gs / 2
  local baseY = y * gs + gs

  local radius
  if size == "large" then radius = gs * 0.7
  elseif size == "medium" then radius = gs * 0.5
  else radius = gs * 0.35
  end

  -- Main rock body
  love.graphics.setColor(0.55 * ambientIntensity, 0.48 * ambientIntensity, 0.40 * ambientIntensity)
  love.graphics.ellipse("fill", baseX, baseY - radius * 0.5, radius, radius * 0.6)

  -- Rock texture (lighter top, darker base)
  love.graphics.setColor(0.62 * ambientIntensity, 0.55 * ambientIntensity, 0.46 * ambientIntensity, 0.5)
  love.graphics.ellipse("fill", baseX, baseY - radius * 0.7, radius * 0.8, radius * 0.3)

  -- Cracks
  love.graphics.setColor(0.40 * ambientIntensity, 0.35 * ambientIntensity, 0.28 * ambientIntensity, 0.4)
  love.graphics.setLineWidth(1)
  love.graphics.line(baseX - radius * 0.3, baseY - radius * 0.5, baseX + radius * 0.2, baseY - radius * 0.3)
  love.graphics.line(baseX, baseY - radius * 0.6, baseX + radius * 0.1, baseY - radius * 0.2)
end

-- Draw trail sign post
function M.drawTrailSign(x, y, gs, text)
  local ambientColor, ambientIntensity = lighting.getAmbientLight()
  local baseX = x * gs + gs / 2
  local baseY = y * gs + gs

  -- Wooden post
  love.graphics.setColor(0.45 * ambientIntensity, 0.35 * ambientIntensity, 0.22 * ambientIntensity)
  love.graphics.rectangle("fill", baseX - 2, baseY - 28, 4, 28)

  -- Sign board
  love.graphics.setColor(0.55 * ambientIntensity, 0.42 * ambientIntensity, 0.25 * ambientIntensity)
  local font = love.graphics.getFont()
  local tw = font:getWidth(text or "Trail")
  love.graphics.rectangle("fill", baseX - tw / 2 - 4, baseY - 30, tw + 8, 14, 2, 2)

  -- Text
  love.graphics.setColor(0.92 * ambientIntensity, 0.88 * ambientIntensity, 0.78 * ambientIntensity)
  love.graphics.print(text or "Trail", baseX - tw / 2, baseY - 28)
end

-- Draw Berber Suspension Bridge
function M.drawSuspensionBridge(x, y, gs, w, time)
  local ambientColor, ambientIntensity = lighting.getAmbientLight()
  local bridgeLen = (w or 8) * gs
  local startX = x * gs
  local bridgeY = y * gs + gs / 2
  local sway = M.getWindSway(x * gs, time, 0.5)

  -- Support towers (stone pillars)
  love.graphics.setColor(0.48 * ambientIntensity, 0.42 * ambientIntensity, 0.35 * ambientIntensity)
  love.graphics.rectangle("fill", startX - 3, bridgeY - 30, 6, 35)
  love.graphics.rectangle("fill", startX + bridgeLen - 3, bridgeY - 30, 6, 35)

  -- Main cables (catenary curve)
  love.graphics.setColor(0.35 * ambientIntensity, 0.35 * ambientIntensity, 0.38 * ambientIntensity)
  love.graphics.setLineWidth(2.5)
  local cablePoints = {}
  for i = 0, 20 do
    local t = i / 20
    local cx = startX + t * bridgeLen
    -- Catenary sag
    local sag = math.sin(t * math.pi) * 12 + sway * t * (1 - t)
    table.insert(cablePoints, cx)
    table.insert(cablePoints, bridgeY - 25 + sag)
  end
  if #cablePoints >= 4 then
    love.graphics.line(cablePoints)
  end

  -- Deck planks
  for i = 0, math.floor(bridgeLen / 8) - 1 do
    local plankX = startX + i * 8
    local t = (i * 8) / bridgeLen
    local plankSag = math.sin(t * math.pi) * 5 + sway * t * (1 - t) * 0.5

    love.graphics.setColor(0.50 * ambientIntensity, 0.40 * ambientIntensity, 0.28 * ambientIntensity)
    love.graphics.rectangle("fill", plankX, bridgeY + plankSag - 2, 7, 4)
  end

  -- Vertical cables / hangers
  love.graphics.setColor(0.35 * ambientIntensity, 0.35 * ambientIntensity, 0.38 * ambientIntensity, 0.6)
  love.graphics.setLineWidth(1)
  for i = 1, 9 do
    local t = i / 10
    local hx = startX + t * bridgeLen
    local topSag = math.sin(t * math.pi) * 12
    local bottomSag = math.sin(t * math.pi) * 5
    love.graphics.line(hx, bridgeY - 25 + topSag, hx, bridgeY + bottomSag - 2)
  end
  love.graphics.setLineWidth(1)
end

-- Draw cattails (lakeside reeds)
function M.drawCattails(x, y, gs, time)
  local ambientColor, ambientIntensity = lighting.getAmbientLight()
  local sway = M.getWindSway(x * gs, time, 2)
  local baseX = x * gs + gs / 2
  local baseY = y * gs + gs

  for i = 1, 4 do
    local stalkX = baseX + (i - 2.5) * 6
    local stalkSway = sway * 0.5 + math.sin(i * 1.5 + time * 0.3) * 2

    -- Green stalk
    love.graphics.setColor(0.28 * ambientIntensity, 0.48 * ambientIntensity, 0.22 * ambientIntensity)
    love.graphics.setLineWidth(2)
    love.graphics.line(stalkX, baseY, stalkX + stalkSway, baseY - gs * 1.8)

    -- Brown cattail head
    love.graphics.setColor(0.45 * ambientIntensity, 0.30 * ambientIntensity, 0.15 * ambientIntensity)
    love.graphics.ellipse("fill", stalkX + stalkSway, baseY - gs * 1.8, 3, 8)

    -- Leaf blades
    love.graphics.setColor(0.25 * ambientIntensity, 0.42 * ambientIntensity, 0.18 * ambientIntensity, 0.8)
    love.graphics.setLineWidth(1.5)
    love.graphics.line(stalkX, baseY - gs * 0.5, stalkX + 12 + stalkSway * 0.5, baseY - gs * 1.2)
    love.graphics.line(stalkX, baseY - gs * 0.8, stalkX - 10 + stalkSway * 0.3, baseY - gs * 1.4)
  end
  love.graphics.setLineWidth(1)
end

-- ═══════════════════════════════════════
-- DRAW: WILDLIFE
-- ═══════════════════════════════════════

function M.drawRoadrunners()
  local ambientColor, ambientIntensity = lighting.getAmbientLight()
  for _, bird in ipairs(roadrunners) do
    local frame = math.floor(bird.animFrame) % 4
    local dir = bird.direction

    -- Body
    love.graphics.setColor(0.42 * ambientIntensity, 0.38 * ambientIntensity, 0.30 * ambientIntensity)
    love.graphics.ellipse("fill", bird.x, bird.y, 10, 6)

    -- Head
    love.graphics.setColor(0.35 * ambientIntensity, 0.32 * ambientIntensity, 0.28 * ambientIntensity)
    love.graphics.ellipse("fill", bird.x + dir * 10, bird.y - 3, 5, 4)

    -- Crest (head tuft)
    love.graphics.setColor(0.30 * ambientIntensity, 0.28 * ambientIntensity, 0.22 * ambientIntensity)
    love.graphics.polygon("fill",
      bird.x + dir * 14, bird.y - 5,
      bird.x + dir * 12, bird.y - 10,
      bird.x + dir * 10, bird.y - 5
    )

    -- Beak
    love.graphics.setColor(0.55 * ambientIntensity, 0.50 * ambientIntensity, 0.35 * ambientIntensity)
    love.graphics.polygon("fill",
      bird.x + dir * 14, bird.y - 3,
      bird.x + dir * 20, bird.y - 2,
      bird.x + dir * 14, bird.y - 1
    )

    -- Eye
    love.graphics.setColor(0.9, 0.8, 0.2, ambientIntensity)
    love.graphics.circle("fill", bird.x + dir * 12, bird.y - 4, 1.5)
    love.graphics.setColor(0.1, 0.1, 0.1)
    love.graphics.circle("fill", bird.x + dir * 12, bird.y - 4, 0.8)

    -- Legs (animated when running)
    love.graphics.setColor(0.55 * ambientIntensity, 0.45 * ambientIntensity, 0.30 * ambientIntensity)
    local legAnim = bird.moving and (frame % 2) * 4 or 0
    love.graphics.line(bird.x - 3, bird.y + 5, bird.x - 3 + legAnim, bird.y + 12)
    love.graphics.line(bird.x + 3, bird.y + 5, bird.x + 3 - legAnim, bird.y + 12)

    -- Long tail
    love.graphics.setColor(0.38 * ambientIntensity, 0.35 * ambientIntensity, 0.28 * ambientIntensity)
    love.graphics.setLineWidth(2)
    love.graphics.line(bird.x - dir * 10, bird.y, bird.x - dir * 22, bird.y + 2)
    love.graphics.setLineWidth(1)

    -- White belly streak
    love.graphics.setColor(0.85, 0.82, 0.75, 0.4 * ambientIntensity)
    love.graphics.ellipse("fill", bird.x, bird.y + 2, 7, 3)
  end
end

function M.drawLizards()
  local ambientColor, ambientIntensity = lighting.getAmbientLight()
  for _, liz in ipairs(lizards) do
    local dir = liz.direction

    -- Different colors per species
    local bodyR, bodyG, bodyB
    if liz.species == 1 then  -- Collared lizard (bright green/yellow)
      bodyR, bodyG, bodyB = 0.35, 0.55, 0.28
    elseif liz.species == 2 then  -- Horned lizard (sandy)
      bodyR, bodyG, bodyB = 0.58, 0.48, 0.35
    else  -- Whiptail (striped brown)
      bodyR, bodyG, bodyB = 0.45, 0.38, 0.28
    end

    -- Body
    love.graphics.setColor(bodyR * ambientIntensity, bodyG * ambientIntensity, bodyB * ambientIntensity)
    love.graphics.ellipse("fill", liz.x, liz.y, 5, 3)

    -- Head
    love.graphics.ellipse("fill", liz.x + dir * 5, liz.y, 3, 2.5)

    -- Tail
    love.graphics.setLineWidth(1.5)
    love.graphics.line(liz.x - dir * 5, liz.y, liz.x - dir * 12, liz.y + 1)
    love.graphics.setLineWidth(1)

    -- Legs
    love.graphics.line(liz.x - 2, liz.y + 2, liz.x - 4, liz.y + 5)
    love.graphics.line(liz.x + 2, liz.y + 2, liz.x + 4, liz.y + 5)

    -- Eye
    love.graphics.setColor(0.1, 0.1, 0.1)
    love.graphics.circle("fill", liz.x + dir * 6, liz.y - 1, 0.8)

    -- Collar marking (collared lizard)
    if liz.species == 1 then
      love.graphics.setColor(0.1 * ambientIntensity, 0.1 * ambientIntensity, 0.1 * ambientIntensity, 0.5)
      love.graphics.arc("line", liz.x + dir * 3, liz.y, 3, 0, math.pi)
    end

    -- Horns (horned lizard)
    if liz.species == 2 then
      love.graphics.setColor(bodyR * 0.7 * ambientIntensity, bodyG * 0.7 * ambientIntensity, bodyB * 0.7 * ambientIntensity)
      for h = 1, 3 do
        love.graphics.line(liz.x + dir * 4 + h * dir, liz.y - 2, liz.x + dir * 4 + h * dir + dir, liz.y - 4)
      end
    end
  end
end

-- ═══════════════════════════════════════
-- DRAW: HEAT SHIMMER (midday mirage effect)
-- ═══════════════════════════════════════

function M.drawHeatShimmer(gs, time, cameraX, cameraY)
  local shimmer = lighting.getHeatShimmer()
  if shimmer < 0.15 then return end

  -- Wavering translucent bands near the ground (mirage effect)
  love.graphics.setColor(1, 0.98, 0.90, shimmer * 0.08)
  for i = 1, 8 do
    local bandY = 1200 + i * 40 + math.sin(time * 0.8 + i * 1.5) * 10
    local bandX = -cameraX * 0.1 + math.sin(time * 0.3 + i) * 30
    love.graphics.rectangle("fill", bandX - 100, bandY, 2800, 6 + shimmer * 4)
  end
end

-- ═══════════════════════════════════════
-- DRAW: DUST DEVILS
-- ═══════════════════════════════════════

function M.drawDustDevils(time)
  local ambientColor, ambientIntensity = lighting.getAmbientLight()

  for _, dd in ipairs(dustDevils) do
    local fadeIn = math.min(dd.timer / 1, 1)
    local fadeOut = math.max(0, 1 - (dd.timer - dd.lifetime + 2) / 2)
    local alpha = fadeIn * fadeOut * 0.3 * ambientIntensity

    -- Swirling dust particles
    for i = 1, 15 do
      local particleAngle = dd.angle + (i / 15) * math.pi * 2
      local particleRadius = dd.radius * (0.3 + (i / 15) * 0.7)
      local particleHeight = dd.height * (i / 15)

      local px = dd.x + math.cos(particleAngle) * particleRadius
      local py = dd.y - particleHeight + math.sin(particleAngle * 0.5) * 5

      love.graphics.setColor(0.72, 0.62, 0.45, alpha * (1 - i / 15))
      love.graphics.circle("fill", px, py, 2 + (1 - i / 15) * 3)
    end
  end
end

-- ═══════════════════════════════════════
-- DRAW: AYER LAKE
-- ═══════════════════════════════════════

function M.drawAyerLake(gs, time, lakeZone)
  local ambientColor, ambientIntensity = lighting.getAmbientLight()

  local x1 = lakeZone.x1 * gs
  local y1 = lakeZone.y1 * gs
  local x2 = (lakeZone.x2 + 1) * gs
  local y2 = (lakeZone.y2 + 1) * gs

  -- Lake water with depth gradient
  for row = 0, lakeZone.y2 - lakeZone.y1 do
    local t = row / (lakeZone.y2 - lakeZone.y1)
    local depth = 0.7 + t * 0.3
    love.graphics.setColor(
      0.15 * depth * ambientIntensity,
      0.35 * depth * ambientIntensity,
      0.48 * depth * ambientIntensity
    )
    love.graphics.rectangle("fill", x1, y1 + row * gs, x2 - x1, gs)
  end

  -- Shore sediment ring (shallow water edge)
  love.graphics.setColor(0.45 * ambientIntensity, 0.55 * ambientIntensity, 0.42 * ambientIntensity, 0.4)
  love.graphics.rectangle("line", x1 + gs, y1 + gs, x2 - x1 - gs * 2, y2 - y1 - gs * 2)

  -- Ripples
  love.graphics.setColor(0.5, 0.65, 0.75, 0.15 * ambientIntensity)
  for i = 1, 6 do
    local rippleX = x1 + gs * 2 + (i * gs * 2 + math.sin(time * 0.3 + i) * gs) % (x2 - x1 - gs * 4)
    local rippleY = y1 + gs * 2 + (i * gs * 1.5) % (y2 - y1 - gs * 4)
    local rippleR = 5 + math.sin(time * 0.5 + i * 1.3) * 3
    love.graphics.ellipse("line", rippleX, rippleY, rippleR * 2, rippleR)
  end

  -- Water sparkles
  if not lighting.isNight() then
    for i = 1, 15 do
      local sx = x1 + gs + (i * 97 + time * 3) % (x2 - x1 - gs * 2)
      local sy = y1 + gs + (i * 63) % (y2 - y1 - gs * 2)
      local sparkle = math.sin(time * 3 + i * 2.1)
      if sparkle > 0.65 then
        local brightness = (sparkle - 0.65) * 3
        love.graphics.setColor(1, 1, 0.92, 0.4 * brightness * ambientIntensity)
        love.graphics.circle("fill", sx, sy, 2 + brightness * 2)
      end
    end
  end

  -- Mountain reflection in lake (at dawn/dusk)
  local sunsetGlow = lighting.getSunsetGlow()
  if sunsetGlow > 0.2 then
    love.graphics.setColor(
      0.6 * ambientIntensity,
      0.35 * ambientIntensity,
      0.25 * ambientIntensity,
      sunsetGlow * 0.15
    )
    for px = x1 + gs, x2 - gs, 6 do
      local reflectH = math.sin(px * 0.02) * 15 + 20
      local waveDistort = math.sin(time * 0.8 + px * 0.05) * 3
      love.graphics.line(px, y1 + gs + waveDistort, px, y1 + gs + reflectH + waveDistort)
    end
  end
end

-- ═══════════════════════════════════════════════════════════════
-- DRAW: WILDFLOWER GROUND COVER (carpet of color across the desert)
-- ═══════════════════════════════════════════════════════════════

function M.drawWildflowers(gs, time)
  local ambientColor, ambientIntensity = lighting.getAmbientLight()
  if ambientIntensity < 0.15 then return end  -- too dark to see flowers

  for _, f in ipairs(wildflowers) do
    local fx = f.x * gs + gs / 2
    local fy = f.y * gs + gs - 2
    local sway = math.sin(time * 1.2 + f.swayOffset) * wind.currentStrength * 3

    if f.species == 1 then
      -- Mexican gold poppy (brilliant orange-gold cups)
      love.graphics.setColor(0.15 * ambientIntensity, 0.35 * ambientIntensity, 0.12 * ambientIntensity)
      love.graphics.line(fx, fy, fx + sway * 0.5, fy - 8 * f.size)
      love.graphics.setColor(0.95 * ambientIntensity, 0.72 * ambientIntensity, 0.10 * ambientIntensity)
      for p = 1, 4 do
        local pa = (p / 4) * math.pi * 2 + f.petalOffset
        love.graphics.ellipse("fill",
          fx + sway * 0.5 + math.cos(pa) * 3 * f.size,
          fy - 8 * f.size + math.sin(pa) * 2 * f.size,
          2.5 * f.size, 3.5 * f.size)
      end
      love.graphics.setColor(0.20 * ambientIntensity, 0.15 * ambientIntensity, 0.05 * ambientIntensity)
      love.graphics.circle("fill", fx + sway * 0.5, fy - 8 * f.size, 1.2 * f.size)

    elseif f.species == 2 then
      -- Lupine (purple spikes)
      love.graphics.setColor(0.18 * ambientIntensity, 0.32 * ambientIntensity, 0.12 * ambientIntensity)
      love.graphics.line(fx, fy, fx + sway * 0.3, fy - 12 * f.size)
      for p = 0, 4 do
        local py = fy - (3 + p * 2) * f.size
        love.graphics.setColor(0.45 * ambientIntensity, 0.20 * ambientIntensity, 0.65 * ambientIntensity)
        love.graphics.ellipse("fill", fx + sway * 0.3 + math.sin(p + f.petalOffset) * 2, py, 2 * f.size, 1.5 * f.size)
      end

    elseif f.species == 3 then
      -- Globe mallow (brilliant orange spheres)
      love.graphics.setColor(0.18 * ambientIntensity, 0.35 * ambientIntensity, 0.15 * ambientIntensity)
      love.graphics.line(fx, fy, fx + sway * 0.4, fy - 10 * f.size)
      love.graphics.setColor(0.92 * ambientIntensity, 0.45 * ambientIntensity, 0.12 * ambientIntensity)
      love.graphics.circle("fill", fx + sway * 0.4, fy - 10 * f.size, 3 * f.size)
      love.graphics.setColor(0.95 * ambientIntensity, 0.55 * ambientIntensity, 0.18 * ambientIntensity, 0.6)
      love.graphics.circle("fill", fx + sway * 0.4 + 1, fy - 11 * f.size, 2 * f.size)

    elseif f.species == 4 then
      -- Brittlebush (yellow daisy-like on silvery mound)
      -- Silvery leaf mound
      love.graphics.setColor(0.55 * ambientIntensity, 0.58 * ambientIntensity, 0.48 * ambientIntensity, 0.5)
      love.graphics.ellipse("fill", fx, fy - 2, 5 * f.size, 3 * f.size)
      -- Flower stem
      love.graphics.setColor(0.20 * ambientIntensity, 0.35 * ambientIntensity, 0.15 * ambientIntensity)
      love.graphics.line(fx, fy - 4 * f.size, fx + sway * 0.6, fy - 14 * f.size)
      -- Yellow ray flowers
      love.graphics.setColor(0.95 * ambientIntensity, 0.88 * ambientIntensity, 0.20 * ambientIntensity)
      for p = 1, 8 do
        local pa = (p / 8) * math.pi * 2 + f.petalOffset
        love.graphics.ellipse("fill",
          fx + sway * 0.6 + math.cos(pa) * 3 * f.size,
          fy - 14 * f.size + math.sin(pa) * 1.5 * f.size,
          1.5 * f.size, 2.5 * f.size)
      end
      love.graphics.setColor(0.65 * ambientIntensity, 0.45 * ambientIntensity, 0.10 * ambientIntensity)
      love.graphics.circle("fill", fx + sway * 0.6, fy - 14 * f.size, 1.8 * f.size)

    elseif f.species == 5 then
      -- Penstemon (red tubular bells)
      love.graphics.setColor(0.20 * ambientIntensity, 0.38 * ambientIntensity, 0.15 * ambientIntensity)
      love.graphics.line(fx, fy, fx + sway * 0.3, fy - 14 * f.size)
      for p = 0, 3 do
        local py = fy - (4 + p * 3) * f.size
        local px2 = fx + sway * 0.3 + math.sin(p + f.petalOffset) * 3
        love.graphics.setColor(0.85 * ambientIntensity, 0.12 * ambientIntensity, 0.18 * ambientIntensity)
        love.graphics.ellipse("fill", px2, py, 2 * f.size, 2.8 * f.size)
        -- White throat
        love.graphics.setColor(0.95 * ambientIntensity, 0.90 * ambientIntensity, 0.85 * ambientIntensity, 0.5)
        love.graphics.ellipse("fill", px2 + 1.5, py, 1 * f.size, 1.5 * f.size)
      end

    elseif f.species == 6 then
      -- Desert marigold (golden buttons on wiry stems)
      love.graphics.setColor(0.25 * ambientIntensity, 0.38 * ambientIntensity, 0.18 * ambientIntensity)
      love.graphics.line(fx, fy, fx + sway * 0.5, fy - 11 * f.size)
      love.graphics.setColor(0.95 * ambientIntensity, 0.82 * ambientIntensity, 0.15 * ambientIntensity)
      love.graphics.circle("fill", fx + sway * 0.5, fy - 11 * f.size, 2.5 * f.size)
      love.graphics.setColor(0.90 * ambientIntensity, 0.75 * ambientIntensity, 0.10 * ambientIntensity)
      love.graphics.circle("fill", fx + sway * 0.5, fy - 11 * f.size, 1.5 * f.size)
    end
  end
end

-- ═══════════════════════════════════════════════════════════════
-- DRAW: COATIMUNDIS (white-nosed, long-tailed, ring-tailed troop)
-- ═══════════════════════════════════════════════════════════════

function M.drawCoatimundis()
  local ambientColor, ambientIntensity = lighting.getAmbientLight()

  for _, c in ipairs(coatimundis) do
    local dir = c.direction
    local scale = c.isBaby and 0.65 or 1.0
    local frame = math.floor(c.animFrame) % 4
    local bodyLen = 14 * scale
    local time = love.timer.getTime()

    -- ═══ BODY (warm brown, elongated) ═══
    local bodyR, bodyG, bodyB = 0.48, 0.35, 0.22
    love.graphics.setColor(bodyR * ambientIntensity, bodyG * ambientIntensity, bodyB * ambientIntensity)
    love.graphics.ellipse("fill", c.x, c.y, bodyLen, 7 * scale)

    -- Lighter underbelly
    love.graphics.setColor(0.60 * ambientIntensity, 0.50 * ambientIntensity, 0.38 * ambientIntensity, 0.5)
    love.graphics.ellipse("fill", c.x, c.y + 2 * scale, bodyLen * 0.8, 4 * scale)

    -- ═══ HEAD (long pointed snout, white nose) ═══
    local headX = c.x + dir * bodyLen * 0.8
    local headY = c.y - 2 * scale
    -- Foraging: nose pointed down
    if c.foraging then
      headY = c.y + 3 * scale
    end
    love.graphics.setColor(bodyR * ambientIntensity, bodyG * ambientIntensity, bodyB * ambientIntensity)
    love.graphics.ellipse("fill", headX, headY, 6 * scale, 5 * scale)

    -- Long snout
    local snoutX = headX + dir * 7 * scale
    local snoutY = headY + (c.foraging and 3 or 1) * scale
    love.graphics.setColor(0.42 * ambientIntensity, 0.32 * ambientIntensity, 0.20 * ambientIntensity)
    love.graphics.ellipse("fill", snoutX, snoutY, 4 * scale, 3 * scale)

    -- White nose tip (diagnostic feature!)
    love.graphics.setColor(0.92 * ambientIntensity, 0.90 * ambientIntensity, 0.85 * ambientIntensity)
    love.graphics.circle("fill", snoutX + dir * 3 * scale, snoutY, 2 * scale)

    -- Eye
    love.graphics.setColor(0.1, 0.08, 0.05)
    love.graphics.circle("fill", headX + dir * 3 * scale, headY - 2 * scale, 1.2 * scale)
    -- Eye shine
    love.graphics.setColor(0.9, 0.85, 0.7, 0.4 * ambientIntensity)
    love.graphics.circle("fill", headX + dir * 3.3 * scale, headY - 2.3 * scale, 0.5 * scale)

    -- Ears (rounded)
    love.graphics.setColor(bodyR * 0.8 * ambientIntensity, bodyG * 0.8 * ambientIntensity, bodyB * 0.8 * ambientIntensity)
    love.graphics.circle("fill", headX - dir * 1, headY - 5 * scale, 2.5 * scale)
    love.graphics.circle("fill", headX + dir * 2, headY - 5 * scale, 2.5 * scale)

    -- ═══ TAIL (long, ringed, held upright while walking!) ═══
    local tailBaseX = c.x - dir * bodyLen * 0.7
    local tailBaseY = c.y - 1
    local tailSegs = 8
    local tailSway = math.sin(c.tailPhase + time * 2) * 4
    local lastTX, lastTY = tailBaseX, tailBaseY

    for t = 1, tailSegs do
      local tt = t / tailSegs
      -- Tail curves upward then slightly over (characteristic coati pose)
      local tx = lastTX - dir * 3 * (1 - tt * 0.5) * scale
      local ty = tailBaseY - tt * 35 * scale + math.sin(tt * math.pi * 0.4) * 5 + tailSway * tt

      -- Alternating dark/light rings
      if t % 2 == 0 then
        love.graphics.setColor(0.25 * ambientIntensity, 0.20 * ambientIntensity, 0.15 * ambientIntensity)
      else
        love.graphics.setColor(bodyR * ambientIntensity, bodyG * ambientIntensity, bodyB * ambientIntensity)
      end
      love.graphics.setLineWidth(3 * scale - tt * 1.5 * scale)
      love.graphics.line(lastTX, lastTY, tx, ty)
      lastTX, lastTY = tx, ty
    end

    -- ═══ LEGS (short, dark, animated when walking) ═══
    love.graphics.setColor(0.32 * ambientIntensity, 0.25 * ambientIntensity, 0.18 * ambientIntensity)
    love.graphics.setLineWidth(2 * scale)
    local legAnim = c.moving and math.sin(c.animFrame * 2) * 3 or 0
    -- Front legs
    love.graphics.line(c.x + dir * 6 * scale, c.y + 5 * scale, c.x + dir * 6 * scale + legAnim, c.y + 12 * scale)
    love.graphics.line(c.x + dir * 3 * scale, c.y + 5 * scale, c.x + dir * 3 * scale - legAnim, c.y + 12 * scale)
    -- Rear legs
    love.graphics.line(c.x - dir * 6 * scale, c.y + 5 * scale, c.x - dir * 6 * scale - legAnim, c.y + 12 * scale)
    love.graphics.line(c.x - dir * 3 * scale, c.y + 5 * scale, c.x - dir * 3 * scale + legAnim, c.y + 12 * scale)

    -- Claws
    love.graphics.setColor(0.20 * ambientIntensity, 0.15 * ambientIntensity, 0.10 * ambientIntensity)
    love.graphics.circle("fill", c.x + dir * 6 * scale + legAnim, c.y + 12 * scale, 1 * scale)
    love.graphics.circle("fill", c.x - dir * 6 * scale - legAnim, c.y + 12 * scale, 1 * scale)

    love.graphics.setLineWidth(1)
  end
end

-- ═══════════════════════════════════════════════════════════════
-- DRAW: HUMMINGBIRDS (iridescent, tiny, rapid wingbeats)
-- ═══════════════════════════════════════════════════════════════

function M.drawHummingbirds()
  local ambientColor, ambientIntensity = lighting.getAmbientLight()
  local time = love.timer.getTime()

  for _, h in ipairs(hummingbirds) do
    local dir = h.direction
    local wingAngle = math.sin(h.wingPhase) -- oscillates -1 to 1 rapidly

    -- ═══ BODY (tiny iridescent green) ═══
    love.graphics.setColor(0.15 * ambientIntensity, 0.50 * ambientIntensity, 0.22 * ambientIntensity)
    love.graphics.ellipse("fill", h.x, h.y, 5, 3)

    -- Iridescent shimmer (shifts with angle)
    local shimmer = math.sin(time * 8 + h.wingPhase) * 0.5 + 0.5
    love.graphics.setColor(
      0.10 * ambientIntensity + shimmer * 0.15,
      0.55 * ambientIntensity - shimmer * 0.1,
      0.25 * ambientIntensity + shimmer * 0.2,
      0.4
    )
    love.graphics.ellipse("fill", h.x, h.y - 1, 4, 2)

    -- ═══ GORGET (throat patch — species diagnostic) ═══
    if h.species == 1 then
      -- Costa's: brilliant violet-purple
      love.graphics.setColor(0.55 * ambientIntensity, 0.12 * ambientIntensity, 0.70 * ambientIntensity)
    else
      -- Anna's: ruby-rose
      love.graphics.setColor(0.80 * ambientIntensity, 0.10 * ambientIntensity, 0.25 * ambientIntensity)
    end
    love.graphics.ellipse("fill", h.x + dir * 3, h.y - 1, 2.5, 2)

    -- ═══ HEAD ═══
    love.graphics.setColor(0.12 * ambientIntensity, 0.45 * ambientIntensity, 0.18 * ambientIntensity)
    love.graphics.circle("fill", h.x + dir * 5, h.y - 1, 2.5)

    -- Eye
    love.graphics.setColor(0.05, 0.05, 0.05)
    love.graphics.circle("fill", h.x + dir * 6, h.y - 2, 0.8)

    -- ═══ BILL (long, thin, slightly curved) ═══
    love.graphics.setColor(0.15 * ambientIntensity, 0.12 * ambientIntensity, 0.10 * ambientIntensity)
    love.graphics.setLineWidth(1)
    love.graphics.line(h.x + dir * 7, h.y - 1, h.x + dir * 15, h.y - 2)

    -- ═══ WINGS (figure-8 blur) ═══
    local wingY = h.y - 2
    local wingSpan = 8
    local wingX = h.x
    -- Wing blur (semi-transparent because they move so fast)
    love.graphics.setColor(0.40 * ambientIntensity, 0.50 * ambientIntensity, 0.45 * ambientIntensity, 0.3)
    love.graphics.ellipse("fill", wingX, wingY - wingAngle * 4, wingSpan, 2 + math.abs(wingAngle) * 2)
    -- Wing tips flash
    love.graphics.setColor(0.60 * ambientIntensity, 0.65 * ambientIntensity, 0.58 * ambientIntensity, 0.15 + math.abs(wingAngle) * 0.15)
    love.graphics.ellipse("fill", wingX - 3, wingY - wingAngle * 5, 4, 1.5)
    love.graphics.ellipse("fill", wingX + 3, wingY - wingAngle * 5, 4, 1.5)

    -- ═══ TAIL (forked) ═══
    love.graphics.setColor(0.12 * ambientIntensity, 0.38 * ambientIntensity, 0.15 * ambientIntensity)
    love.graphics.setLineWidth(1.5)
    love.graphics.line(h.x - dir * 5, h.y, h.x - dir * 10, h.y + 1)
    love.graphics.line(h.x - dir * 5, h.y, h.x - dir * 10, h.y + 3)
    love.graphics.setLineWidth(1)
  end
end

-- ═══════════════════════════════════════════════════════════════
-- DRAW: BUTTERFLIES (colorful, erratic, species-specific wing patterns)
-- ═══════════════════════════════════════════════════════════════

function M.drawButterflies()
  local ambientColor, ambientIntensity = lighting.getAmbientLight()
  if ambientIntensity < 0.2 then return end

  for _, b in ipairs(butterflies) do
    local wingOpen = math.sin(b.wingPhase)  -- -1 to 1
    if b.landed then
      wingOpen = 0.5 + math.sin(b.wingPhase * 0.3) * 0.3  -- slow flutter when landed
    end
    local wingSpread = math.abs(wingOpen)
    local px = b.x
    local py = b.y - b.z  -- z is height above ground
    local sz = b.size

    -- Wing colors by species
    local wR, wG, wB, wR2, wG2, wB2
    if b.species == 1 then
      -- Painted Lady (orange/brown with white spots)
      wR, wG, wB = 0.88, 0.52, 0.18
      wR2, wG2, wB2 = 0.72, 0.38, 0.12
    elseif b.species == 2 then
      -- Monarch (deep orange with black veins)
      wR, wG, wB = 0.95, 0.55, 0.08
      wR2, wG2, wB2 = 0.85, 0.42, 0.05
    elseif b.species == 3 then
      -- Swallowtail (yellow with black tiger stripes)
      wR, wG, wB = 0.92, 0.88, 0.25
      wR2, wG2, wB2 = 0.15, 0.12, 0.08
    elseif b.species == 4 then
      -- Cloudless Sulfur (bright lemon yellow)
      wR, wG, wB = 0.95, 0.92, 0.30
      wR2, wG2, wB2 = 0.88, 0.85, 0.22
    else
      -- Pipevine Swallowtail (iridescent blue-black)
      wR, wG, wB = 0.15, 0.20, 0.55
      wR2, wG2, wB2 = 0.08, 0.10, 0.35
    end

    -- Upper wings (forewing pair)
    love.graphics.setColor(wR * ambientIntensity, wG * ambientIntensity, wB * ambientIntensity, 0.85)
    love.graphics.ellipse("fill", px - 3 * sz, py - wingSpread * 4 * sz, 4 * sz, (1 + wingSpread * 3) * sz)
    love.graphics.ellipse("fill", px + 3 * sz, py - wingSpread * 4 * sz, 4 * sz, (1 + wingSpread * 3) * sz)

    -- Lower wings (hindwing pair — slightly different color)
    love.graphics.setColor(wR2 * ambientIntensity, wG2 * ambientIntensity, wB2 * ambientIntensity, 0.75)
    love.graphics.ellipse("fill", px - 2.5 * sz, py + wingSpread * 2 * sz, 3 * sz, (1 + wingSpread * 2) * sz)
    love.graphics.ellipse("fill", px + 2.5 * sz, py + wingSpread * 2 * sz, 3 * sz, (1 + wingSpread * 2) * sz)

    -- Body
    love.graphics.setColor(0.12 * ambientIntensity, 0.10 * ambientIntensity, 0.08 * ambientIntensity)
    love.graphics.ellipse("fill", px, py, 1 * sz, 3 * sz)

    -- Monarch-specific: white dots on wing edges
    if b.species == 2 and wingSpread > 0.3 then
      love.graphics.setColor(0.95, 0.95, 0.95, 0.5 * ambientIntensity * wingSpread)
      love.graphics.circle("fill", px - 5 * sz, py - wingSpread * 3 * sz, 0.8 * sz)
      love.graphics.circle("fill", px + 5 * sz, py - wingSpread * 3 * sz, 0.8 * sz)
      love.graphics.circle("fill", px - 4 * sz, py + wingSpread * 1 * sz, 0.6 * sz)
      love.graphics.circle("fill", px + 4 * sz, py + wingSpread * 1 * sz, 0.6 * sz)
    end

    -- Swallowtail tail extensions
    if b.species == 3 and wingSpread > 0.2 then
      love.graphics.setColor(0.15 * ambientIntensity, 0.12 * ambientIntensity, 0.08 * ambientIntensity)
      love.graphics.line(px - 2 * sz, py + wingSpread * 3 * sz, px - 3 * sz, py + wingSpread * 6 * sz)
      love.graphics.line(px + 2 * sz, py + wingSpread * 3 * sz, px + 3 * sz, py + wingSpread * 6 * sz)
    end

    -- Antennae
    love.graphics.setColor(0.15 * ambientIntensity, 0.12 * ambientIntensity, 0.08 * ambientIntensity)
    love.graphics.line(px - 1, py - 3 * sz, px - 3 * sz, py - 6 * sz)
    love.graphics.line(px + 1, py - 3 * sz, px + 3 * sz, py - 6 * sz)
    -- Antenna tips (clubbed)
    love.graphics.circle("fill", px - 3 * sz, py - 6 * sz, 0.6 * sz)
    love.graphics.circle("fill", px + 3 * sz, py - 6 * sz, 0.6 * sz)

    -- Ground shadow when flying
    if not b.landed and b.z > 5 then
      love.graphics.setColor(0, 0, 0, 0.06 * ambientIntensity)
      love.graphics.ellipse("fill", px, b.y + 2, 4 * sz * wingSpread, 1.5 * sz)
    end
  end
end

-- ═══════════════════════════════════════════════════════════════
-- DRAW: POLLEN MOTES / COTTONWOOD FLUFF / DUST SPARKLES
-- ═══════════════════════════════════════════════════════════════

function M.drawPollenMotes(time)
  local ambientColor, ambientIntensity = lighting.getAmbientLight()
  if ambientIntensity < 0.2 then return end

  for _, m in ipairs(pollenMotes) do
    local px = m.x
    local py = m.y - m.z

    if m.type == 1 then
      -- Golden pollen grain
      local glow = math.sin(time * 2 + m.phase) * 0.15 + 0.85
      love.graphics.setColor(0.95 * ambientIntensity * glow, 0.82 * ambientIntensity * glow, 0.25 * ambientIntensity, m.alpha * ambientIntensity)
      love.graphics.circle("fill", px, py, m.size)
    elseif m.type == 2 then
      -- Cottonwood seed fluff (soft white wisp)
      love.graphics.setColor(0.95, 0.95, 0.92, m.alpha * 0.7 * ambientIntensity)
      love.graphics.circle("fill", px, py, m.size * 1.5)
      love.graphics.setColor(1, 1, 0.98, m.alpha * 0.3 * ambientIntensity)
      love.graphics.circle("fill", px, py, m.size * 2.5)
    else
      -- Desert dust sparkle (catches sunlight)
      local sparkle = math.sin(time * 5 + m.phase * 3)
      if sparkle > 0.5 then
        love.graphics.setColor(1, 0.97, 0.85, (sparkle - 0.5) * 2 * m.alpha * ambientIntensity)
        love.graphics.circle("fill", px, py, m.size * 0.8)
        -- Bright flash core
        love.graphics.setColor(1, 1, 0.95, (sparkle - 0.5) * ambientIntensity)
        love.graphics.circle("fill", px, py, m.size * 0.3)
      end
    end
  end
end

-- ═══════════════════════════════════════════════════════════════
-- DRAW: FALLING LEAVES
-- ═══════════════════════════════════════════════════════════════

function M.drawFallingLeaves(time)
  local ambientColor, ambientIntensity = lighting.getAmbientLight()

  for _, l in ipairs(fallingLeaves) do
    love.graphics.push()
    love.graphics.translate(l.x, l.y)
    love.graphics.rotate(l.rotation)

    if l.type == 1 then
      -- Eucalyptus (long sickle-shaped)
      love.graphics.setColor(0.30 * ambientIntensity, 0.48 * ambientIntensity, 0.28 * ambientIntensity, 0.8)
      love.graphics.ellipse("fill", 0, 0, l.size * 0.5, l.size * 1.8)
    elseif l.type == 2 then
      -- Palo verde (tiny compound leaflet)
      love.graphics.setColor(0.40 * ambientIntensity, 0.58 * ambientIntensity, 0.25 * ambientIntensity, 0.7)
      love.graphics.ellipse("fill", 0, 0, l.size * 0.3, l.size * 0.8)
    else
      -- Mesquite (small oblong)
      love.graphics.setColor(0.50 * ambientIntensity, 0.45 * ambientIntensity, 0.28 * ambientIntensity, 0.75)
      love.graphics.ellipse("fill", 0, 0, l.size * 0.4, l.size * 1.2)
    end

    love.graphics.pop()
  end
end

-- ═══════════════════════════════════════════════════════════════
-- DRAW: FIREFLIES (bioluminescent desert night)
-- ═══════════════════════════════════════════════════════════════

function M.drawFireflies(time)
  local hour = lighting.getHour()
  local active = (hour >= 18 or hour < 5.5)
  if not active then return end

  local ambientColor, ambientIntensity = lighting.getAmbientLight()
  -- Fade in at dusk, full at night
  local nightAlpha = 1.0
  if hour >= 18 and hour < 20 then
    nightAlpha = (hour - 18) / 2
  elseif hour >= 4 and hour < 5.5 then
    nightAlpha = (5.5 - hour) / 1.5
  end

  for _, f in ipairs(fireflies) do
    local px = f.x
    local py = f.y - f.z

    if f.glowOn then
      local glowPulse = math.sin(time * 8 + f.glowPhase) * 0.2 + 0.8

      -- Outer glow halo
      love.graphics.setColor(0.55, 0.85, 0.25, 0.12 * nightAlpha * glowPulse)
      love.graphics.circle("fill", px, py, f.size * 8)

      -- Middle glow
      love.graphics.setColor(0.65, 0.90, 0.30, 0.25 * nightAlpha * glowPulse)
      love.graphics.circle("fill", px, py, f.size * 4)

      -- Bright core
      love.graphics.setColor(0.85, 0.95, 0.45, 0.7 * nightAlpha * glowPulse)
      love.graphics.circle("fill", px, py, f.size * 1.5)

      -- Hot center
      love.graphics.setColor(1, 1, 0.8, 0.9 * nightAlpha * glowPulse)
      love.graphics.circle("fill", px, py, f.size * 0.5)
    else
      -- Dim body barely visible
      love.graphics.setColor(0.3, 0.3, 0.2, 0.1 * nightAlpha)
      love.graphics.circle("fill", px, py, f.size * 0.5)
    end
  end
end

-- ═══════════════════════════════════════════════════════════════
-- DRAW: SHADE DAPPLING (light filtering through tree canopies)
-- ═══════════════════════════════════════════════════════════════

function M.drawShadeDapple(gs, time, decorations)
  local hour = lighting.getHour()
  if hour < 6 or hour > 19 then return end  -- no dappling at night

  local ambientColor, ambientIntensity = lighting.getAmbientLight()
  local sdx, sdy = lighting.getSunDirection()

  for _, deco in ipairs(decorations) do
    if deco.type == "desert_tree" or deco.type == "eucalyptus" or deco.type == "palo_verde" then
      local cx = deco.x * gs + gs / 2 + sdx * 20
      local cy = deco.y * gs + gs + 15

      -- Dappled light patches (ground under tree canopy)
      local numDapples = 12
      for i = 1, numDapples do
        local dappleAngle = (i / numDapples) * math.pi * 2 + deco.x * 2.3
        local dappleR = 15 + math.sin(deco.x + i * 1.7) * 10
        local dx2 = math.cos(dappleAngle) * dappleR + sdx * 10
        local dy2 = math.sin(dappleAngle) * dappleR * 0.5

        -- Shadow spots (dark)
        love.graphics.setColor(0, 0, 0, 0.08 * ambientIntensity)
        local spotSize = 3 + math.sin(time * 0.3 + i * 0.7 + deco.x) * 2
        love.graphics.ellipse("fill", cx + dx2, cy + dy2, spotSize * 1.5, spotSize)

        -- Light spots between shadows (sun filtering through)
        if math.sin(time * 0.5 + i * 1.3) > 0.2 then
          love.graphics.setColor(1, 0.97, 0.85, 0.04 * ambientIntensity)
          love.graphics.ellipse("fill", cx + dx2 + 4, cy + dy2 + 2, spotSize * 0.8, spotSize * 0.5)
        end
      end
    end
  end
end

-- ═══════════════════════════════════════════════════════════════
-- DRAW: SHADE RAMADA (open-sided shade structures with bench)
-- ═══════════════════════════════════════════════════════════════

function M.drawRamada(x, y, gs)
  local ambientColor, ambientIntensity = lighting.getAmbientLight()
  local baseX = x * gs
  local baseY = y * gs

  -- Four wooden posts
  love.graphics.setColor(0.45 * ambientIntensity, 0.35 * ambientIntensity, 0.22 * ambientIntensity)
  love.graphics.rectangle("fill", baseX + 2, baseY + 4, 4, 28)
  love.graphics.rectangle("fill", baseX + gs - 6, baseY + 4, 4, 28)
  love.graphics.rectangle("fill", baseX + 2 + gs, baseY + 4, 4, 28)
  love.graphics.rectangle("fill", baseX + gs * 2 - 6, baseY + 4, 4, 28)

  -- Lattice roof (branches/slats)
  love.graphics.setColor(0.50 * ambientIntensity, 0.40 * ambientIntensity, 0.28 * ambientIntensity)
  love.graphics.rectangle("fill", baseX, baseY, gs * 2, 6)
  -- Cross-slats
  for sx = baseX + 4, baseX + gs * 2 - 4, 8 do
    love.graphics.setColor(0.42 * ambientIntensity, 0.35 * ambientIntensity, 0.24 * ambientIntensity, 0.7)
    love.graphics.line(sx, baseY, sx, baseY + 5)
  end

  -- Shade underneath
  love.graphics.setColor(0, 0, 0, 0.10 * ambientIntensity)
  love.graphics.rectangle("fill", baseX + 4, baseY + 6, gs * 2 - 8, 26)

  -- Bench inside
  love.graphics.setColor(0.48 * ambientIntensity, 0.38 * ambientIntensity, 0.25 * ambientIntensity)
  love.graphics.rectangle("fill", baseX + 8, baseY + 18, gs * 2 - 16, 4)
  love.graphics.rectangle("fill", baseX + 10, baseY + 22, 3, 8)
  love.graphics.rectangle("fill", baseX + gs * 2 - 13, baseY + 22, 3, 8)
end

-- ═══════════════════════════════════════════════════════════════
-- DRAW: DRINKING FOUNTAIN (trail amenity)
-- ═══════════════════════════════════════════════════════════════

function M.drawDrinkingFountain(x, y, gs, time)
  local ambientColor, ambientIntensity = lighting.getAmbientLight()
  local baseX = x * gs + gs / 2
  local baseY = y * gs + gs

  -- Stone pedestal
  love.graphics.setColor(0.55 * ambientIntensity, 0.50 * ambientIntensity, 0.45 * ambientIntensity)
  love.graphics.rectangle("fill", baseX - 6, baseY - 20, 12, 20)

  -- Basin
  love.graphics.setColor(0.50 * ambientIntensity, 0.48 * ambientIntensity, 0.42 * ambientIntensity)
  love.graphics.ellipse("fill", baseX, baseY - 20, 10, 4)

  -- Water in basin
  love.graphics.setColor(0.30 * ambientIntensity, 0.55 * ambientIntensity, 0.65 * ambientIntensity, 0.6)
  love.graphics.ellipse("fill", baseX, baseY - 20, 8, 3)

  -- Tiny water trickle
  local trickle = math.sin(time * 4) * 0.5 + 0.5
  love.graphics.setColor(0.40 * ambientIntensity, 0.65 * ambientIntensity, 0.75 * ambientIntensity, 0.3 * trickle)
  love.graphics.line(baseX + 2, baseY - 23, baseX + 2, baseY - 20)
end

-- ═══════════════════════════════════════════════════════════════
-- DRAW: INTERPRETIVE SIGN (educational display)
-- ═══════════════════════════════════════════════════════════════

function M.drawInterpretiveSign(x, y, gs, text)
  local ambientColor, ambientIntensity = lighting.getAmbientLight()
  local baseX = x * gs + gs / 2
  local baseY = y * gs + gs

  -- Angled wooden stand
  love.graphics.setColor(0.42 * ambientIntensity, 0.32 * ambientIntensity, 0.20 * ambientIntensity)
  love.graphics.polygon("fill",
    baseX - 12, baseY,
    baseX + 12, baseY,
    baseX + 10, baseY - 22,
    baseX - 10, baseY - 22)

  -- Display panel (green with white text — NPS style)
  love.graphics.setColor(0.12 * ambientIntensity, 0.28 * ambientIntensity, 0.15 * ambientIntensity)
  love.graphics.rectangle("fill", baseX - 10, baseY - 22, 20, 16, 1, 1)

  -- Border
  love.graphics.setColor(0.72 * ambientIntensity, 0.62 * ambientIntensity, 0.35 * ambientIntensity)
  love.graphics.rectangle("line", baseX - 10, baseY - 22, 20, 16, 1, 1)

  -- Text symbol (simplified — just show an icon)
  love.graphics.setColor(0.92 * ambientIntensity, 0.90 * ambientIntensity, 0.82 * ambientIntensity)
  love.graphics.print("i", baseX - 2, baseY - 20)
end

-- ═══════════════════════════════════════════════════════════════════════════
-- LARGE FANCY ANIMATED TREES
-- Inspired by Octopath Traveler / HD-2D art style
-- Multi-layer canopy with leaf clusters, swaying branches, dappled light,
-- visible root systems, textured bark, seasonal color accents
-- ═══════════════════════════════════════════════════════════════════════════

-- Tree species palette definitions
local FANCY_TREE_SPECIES = {
  -- Red Maple (brilliant crimson canopy)
  red_maple = {
    trunk = {0.38, 0.28, 0.18},
    bark_accent = {0.30, 0.22, 0.14},
    canopy_inner = {0.75, 0.18, 0.12},
    canopy_mid = {0.85, 0.25, 0.10},
    canopy_outer = {0.65, 0.12, 0.08},
    leaf_highlight = {0.95, 0.35, 0.15},
    trunk_height = 5.0,
    trunk_width = 18,
    canopy_radius = 2.2,
    branch_count = 6,
    leaf_clusters = 14,
    root_spread = 1.5,
  },
  -- Golden Ash (warm amber-gold foliage)
  golden_ash = {
    trunk = {0.42, 0.35, 0.25},
    bark_accent = {0.55, 0.42, 0.28},
    canopy_inner = {0.85, 0.72, 0.15},
    canopy_mid = {0.78, 0.62, 0.12},
    canopy_outer = {0.70, 0.55, 0.10},
    leaf_highlight = {1.0, 0.88, 0.30},
    trunk_height = 4.5,
    trunk_width = 16,
    canopy_radius = 2.0,
    branch_count = 5,
    leaf_clusters = 12,
    root_spread = 1.3,
  },
  -- Purple Jacaranda (lavender-violet blooms)
  jacaranda = {
    trunk = {0.35, 0.30, 0.28},
    bark_accent = {0.45, 0.38, 0.32},
    canopy_inner = {0.55, 0.30, 0.70},
    canopy_mid = {0.65, 0.40, 0.80},
    canopy_outer = {0.48, 0.25, 0.62},
    leaf_highlight = {0.78, 0.55, 0.90},
    trunk_height = 4.8,
    trunk_width = 15,
    canopy_radius = 2.3,
    branch_count = 7,
    leaf_clusters = 16,
    root_spread = 1.4,
  },
  -- Copper Beech (deep bronze-copper leaves)
  copper_beech = {
    trunk = {0.50, 0.38, 0.28},
    bark_accent = {0.40, 0.30, 0.22},
    canopy_inner = {0.55, 0.25, 0.15},
    canopy_mid = {0.65, 0.32, 0.18},
    canopy_outer = {0.48, 0.20, 0.12},
    leaf_highlight = {0.78, 0.45, 0.25},
    trunk_height = 5.5,
    trunk_width = 20,
    canopy_radius = 2.5,
    branch_count = 8,
    leaf_clusters = 18,
    root_spread = 1.8,
  },
  -- Silver Birch (white bark, emerald leaves)
  silver_birch = {
    trunk = {0.85, 0.82, 0.78},
    bark_accent = {0.20, 0.18, 0.15},
    canopy_inner = {0.30, 0.58, 0.25},
    canopy_mid = {0.35, 0.65, 0.28},
    canopy_outer = {0.25, 0.50, 0.20},
    leaf_highlight = {0.50, 0.80, 0.40},
    trunk_height = 5.0,
    trunk_width = 12,
    canopy_radius = 1.8,
    branch_count = 6,
    leaf_clusters = 13,
    root_spread = 1.2,
  },
  -- Desert Willow (pink blossoms, graceful drooping)
  desert_willow = {
    trunk = {0.40, 0.32, 0.22},
    bark_accent = {0.50, 0.40, 0.28},
    canopy_inner = {0.88, 0.50, 0.55},
    canopy_mid = {0.82, 0.42, 0.48},
    canopy_outer = {0.75, 0.38, 0.42},
    leaf_highlight = {0.95, 0.65, 0.70},
    trunk_height = 4.0,
    trunk_width = 14,
    canopy_radius = 2.4,
    branch_count = 7,
    leaf_clusters = 15,
    root_spread = 1.6,
  },
}

function M.drawFancyTree(x, y, gs, time, species)
  species = species or "red_maple"
  local sp = FANCY_TREE_SPECIES[species]
  if not sp then sp = FANCY_TREE_SPECIES.red_maple end

  local baseX = x * gs + gs / 2
  local baseY = y * gs + gs
  local ambientColor, ambientIntensity = lighting.getAmbientLight()
  local sway = M.getWindSway(x * gs, time, 3)
  local treeSeed = x * 31 + y * 47

  local trunkH = gs * sp.trunk_height
  local trunkW = sp.trunk_width
  local ai = ambientIntensity  -- shorthand

  -- ═══ LAYER 1: VISIBLE ROOT SYSTEM ═══
  local rootSpread = gs * sp.root_spread
  for i = 1, 5 do
    local rootAngle = (i / 5) * math.pi + math.sin(treeSeed + i * 1.3) * 0.4
    local rootLen = rootSpread * (0.5 + math.sin(treeSeed + i * 2.7) * 0.3)
    local rootEndX = baseX + math.cos(rootAngle) * rootLen
    local rootEndY = baseY + math.abs(math.sin(rootAngle)) * rootLen * 0.3 + 2
    local rootWidth = 4 - i * 0.4

    -- Root with taper
    love.graphics.setColor(sp.trunk[1] * 0.7 * ai, sp.trunk[2] * 0.7 * ai, sp.trunk[3] * 0.7 * ai, 0.8)
    love.graphics.setLineWidth(rootWidth)
    love.graphics.line(baseX, baseY, rootEndX, rootEndY)

    -- Root knobs
    if math.sin(treeSeed + i * 3.5) > 0.3 then
      love.graphics.setColor(sp.trunk[1] * 0.65 * ai, sp.trunk[2] * 0.65 * ai, sp.trunk[3] * 0.65 * ai, 0.7)
      love.graphics.circle("fill", rootEndX, rootEndY, 2.5)
    end
  end
  love.graphics.setLineWidth(1)

  -- ═══ LAYER 2: TEXTURED TRUNK ═══
  local segments = 20
  for i = 0, segments - 1 do
    local t = i / segments
    local nextT = (i + 1) / segments
    local taper = 1 - t * 0.6
    local w = trunkW * taper
    local y1 = baseY - t * trunkH
    local y2 = baseY - nextT * trunkH
    local segSway = sway * t * t * 0.5

    -- Main trunk bark
    local barkVar = math.sin(treeSeed + i * 2.3) * 0.08
    love.graphics.setColor(
      (sp.trunk[1] + barkVar) * ai,
      (sp.trunk[2] + barkVar) * ai,
      (sp.trunk[3] + barkVar) * ai
    )
    love.graphics.polygon("fill",
      baseX + segSway - w / 2, y1,
      baseX + segSway + w / 2, y1,
      baseX + segSway + w / 2 - 0.3, y2,
      baseX + segSway - w / 2 + 0.3, y2
    )

    -- Bark texture lines (horizontal grain)
    if i % 3 == 0 then
      love.graphics.setColor(sp.bark_accent[1] * ai, sp.bark_accent[2] * ai, sp.bark_accent[3] * ai, 0.4)
      local lineY = (y1 + y2) / 2
      love.graphics.line(baseX + segSway - w / 2 + 1, lineY, baseX + segSway + w / 2 - 1, lineY)
    end

    -- Birch-style bark marks (horizontal dark lines for silver_birch)
    if species == "silver_birch" and i % 2 == 0 then
      love.graphics.setColor(sp.bark_accent[1] * ai, sp.bark_accent[2] * ai, sp.bark_accent[3] * ai, 0.5)
      local markY = (y1 + y2) / 2
      local markW = w * (0.3 + math.sin(treeSeed + i) * 0.2)
      local markX = baseX + segSway + math.sin(treeSeed + i * 1.7) * w * 0.15
      love.graphics.rectangle("fill", markX - markW / 2, markY - 1, markW, 2)
    end

    -- Trunk moss / lichen patches (on shaded side)
    if math.sin(treeSeed + i * 1.9) > 0.5 and t > 0.2 and t < 0.7 then
      love.graphics.setColor(0.25 * ai, 0.40 * ai, 0.20 * ai, 0.35)
      local patchX = baseX + segSway - w / 2 + 2
      love.graphics.ellipse("fill", patchX, (y1 + y2) / 2, 3, 4)
    end
  end

  -- ═══ LAYER 3: MAJOR BRANCHES ═══
  local canopyX = baseX + sway * 0.5
  local canopyY = baseY - trunkH
  local canopyR = gs * sp.canopy_radius

  for i = 1, sp.branch_count do
    local brAngle = (i / sp.branch_count) * math.pi * 1.6 - math.pi * 0.3 + math.sin(treeSeed + i) * 0.3
    local brLen = canopyR * (0.4 + math.sin(treeSeed + i * 1.7) * 0.25)
    local brEndX = canopyX + math.cos(brAngle) * brLen
    local brEndY = canopyY - math.abs(math.sin(brAngle)) * brLen * 0.6
    local brSway = sway * 0.3 * math.sin(time * 0.8 + i * 1.2)

    -- Branch with slight curve
    local midX = (canopyX + brEndX + brSway) / 2 + math.sin(treeSeed + i * 2.1) * 8
    local midY = (canopyY + brEndY) / 2 - 5

    local branchWidth = 4 - i * 0.3
    love.graphics.setColor(sp.trunk[1] * 0.9 * ai, sp.trunk[2] * 0.9 * ai, sp.trunk[3] * 0.9 * ai)
    love.graphics.setLineWidth(math.max(1.5, branchWidth))
    love.graphics.line(canopyX, canopyY, midX, midY)
    love.graphics.line(midX, midY, brEndX + brSway, brEndY)

    -- Sub-branches (twigs)
    for j = 1, 2 do
      local subT = 0.5 + j * 0.2
      local subX = canopyX + (brEndX + brSway - canopyX) * subT
      local subY = canopyY + (brEndY - canopyY) * subT
      local subAngle = brAngle + (j == 1 and 0.5 or -0.5)
      local subLen = brLen * 0.25
      love.graphics.setLineWidth(1)
      love.graphics.setColor(sp.trunk[1] * 0.85 * ai, sp.trunk[2] * 0.85 * ai, sp.trunk[3] * 0.85 * ai)
      love.graphics.line(subX, subY,
        subX + math.cos(subAngle) * subLen + brSway * 0.5,
        subY - math.abs(math.sin(subAngle)) * subLen * 0.6)
    end
  end
  love.graphics.setLineWidth(1)

  -- ═══ LAYER 4: BACK CANOPY (dark depth layer) ═══
  love.graphics.setColor(sp.canopy_outer[1] * 0.7 * ai, sp.canopy_outer[2] * 0.7 * ai, sp.canopy_outer[3] * 0.7 * ai, 0.7)
  love.graphics.ellipse("fill", canopyX, canopyY - canopyR * 0.15, canopyR * 1.1, canopyR * 0.75)

  -- ═══ LAYER 5: MAIN CANOPY (mid-tone leaf clusters) ═══
  for i = 1, sp.leaf_clusters do
    local clAngle = (i / sp.leaf_clusters) * math.pi * 2 + treeSeed * 0.1
    local clDist = canopyR * (0.3 + math.sin(treeSeed + i * 1.9) * 0.45)
    local clSway = sway * 0.2 * math.sin(time * 1.2 + i * 0.7)
    local clX = canopyX + math.cos(clAngle) * clDist + clSway
    local clY = canopyY - math.abs(math.sin(clAngle)) * clDist * 0.65 - 3
    local clR = 8 + math.sin(treeSeed + i * 2.3) * 4

    -- Cluster shadow (depth underneath each puff)
    love.graphics.setColor(sp.canopy_outer[1] * 0.5 * ai, sp.canopy_outer[2] * 0.5 * ai, sp.canopy_outer[3] * 0.5 * ai, 0.4)
    love.graphics.ellipse("fill", clX + 1, clY + 2, clR * 1.1, clR * 0.7)

    -- Main leaf cluster
    love.graphics.setColor(sp.canopy_mid[1] * ai, sp.canopy_mid[2] * ai, sp.canopy_mid[3] * ai, 0.85)
    love.graphics.ellipse("fill", clX, clY, clR * 1.1, clR * 0.75)

    -- Inner highlight (sun-facing side)
    love.graphics.setColor(sp.canopy_inner[1] * ai, sp.canopy_inner[2] * ai, sp.canopy_inner[3] * ai, 0.65)
    love.graphics.ellipse("fill", clX - 2, clY - 2, clR * 0.7, clR * 0.5)

    -- Individual leaf detail (tiny marks on each cluster)
    love.graphics.setColor(sp.leaf_highlight[1] * ai, sp.leaf_highlight[2] * ai, sp.leaf_highlight[3] * ai, 0.5)
    for j = 1, 4 do
      local lx = clX + math.cos(j * 1.8 + treeSeed + i) * clR * 0.5
      local ly = clY + math.sin(j * 2.3 + treeSeed + i) * clR * 0.3
      love.graphics.ellipse("fill", lx, ly, 2, 1.5)
    end
  end

  -- ═══ LAYER 6: TOP HIGHLIGHT (sunlit crown) ═══
  love.graphics.setColor(sp.leaf_highlight[1] * ai, sp.leaf_highlight[2] * ai, sp.leaf_highlight[3] * ai, 0.45)
  love.graphics.ellipse("fill", canopyX - canopyR * 0.15, canopyY - canopyR * 0.4, canopyR * 0.6, canopyR * 0.35)

  -- ═══ LAYER 7: ANIMATED LEAF SHIMMER (wind sparkle) ═══
  local shimmerCount = 6
  for i = 1, shimmerCount do
    local shimPhase = math.sin(time * 2.5 + i * 1.4 + treeSeed) * 0.5 + 0.5
    if shimPhase > 0.7 then
      local shimX = canopyX + math.cos(time * 0.3 + i * 2.1 + treeSeed) * canopyR * 0.7
      local shimY = canopyY - math.abs(math.sin(time * 0.4 + i * 1.6 + treeSeed)) * canopyR * 0.5 - 5
      local brightness = (shimPhase - 0.7) / 0.3
      love.graphics.setColor(sp.leaf_highlight[1] * ai, sp.leaf_highlight[2] * ai, sp.leaf_highlight[3] * ai, brightness * 0.6)
      love.graphics.circle("fill", shimX, shimY, 2.5)
      -- Cross-sparkle
      love.graphics.setColor(1 * ai, 1 * ai, 0.95 * ai, brightness * 0.3)
      love.graphics.setLineWidth(1)
      love.graphics.line(shimX - 3, shimY, shimX + 3, shimY)
      love.graphics.line(shimX, shimY - 3, shimX, shimY + 3)
    end
  end

  -- ═══ LAYER 8: DROOPING ELEMENTS (species-specific) ═══
  if species == "desert_willow" or species == "jacaranda" then
    -- Hanging flower/leaf strands
    for i = 1, 8 do
      local drAngle = (i / 8) * math.pi * 2 + treeSeed
      local drDist = canopyR * (0.5 + math.sin(treeSeed + i * 1.3) * 0.3)
      local drX = canopyX + math.cos(drAngle) * drDist
      local drY = canopyY + math.sin(drAngle) * canopyR * 0.3
      local drLen = 15 + math.sin(treeSeed + i * 1.7) * 8
      local drSway = sway * 0.4 * math.sin(time * 1.5 + i * 0.9)

      love.graphics.setColor(sp.canopy_mid[1] * ai, sp.canopy_mid[2] * ai, sp.canopy_mid[3] * ai, 0.6)
      love.graphics.setLineWidth(1.5)
      love.graphics.line(drX, drY, drX + drSway, drY + drLen)
      love.graphics.setLineWidth(1)

      -- Petal/blossom at tip
      love.graphics.setColor(sp.leaf_highlight[1] * ai, sp.leaf_highlight[2] * ai, sp.leaf_highlight[3] * ai, 0.7)
      love.graphics.circle("fill", drX + drSway, drY + drLen, 2)
    end
  end

  -- ═══ LAYER 9: FALLEN PETALS / LEAVES around base ═══
  for i = 1, 6 do
    local px = baseX + math.cos(treeSeed + i * 2.4) * gs * 1.5
    local py = baseY + 3 + math.sin(treeSeed + i * 1.6) * 4
    local petalPhase = math.sin(time * 0.3 + treeSeed + i * 1.1) * 0.3 + 0.5
    love.graphics.setColor(sp.canopy_mid[1] * ai * 0.8, sp.canopy_mid[2] * ai * 0.8, sp.canopy_mid[3] * ai * 0.8, petalPhase * 0.4)
    love.graphics.ellipse("fill", px, py, 3, 1.5, treeSeed + i)
  end
end

-- ═══════════════════════════════════════════════════════════════════════════
-- SUN RENDERING (Mixia-inspired, with desert glow and animated rays)
-- ═══════════════════════════════════════════════════════════════════════════

function M.drawSun(screenW, screenH, time)
  local hour = lighting.getHour()
  local sunAngle = lighting.getSunAngle()
  if not sunAngle then return end  -- below horizon (night)

  -- Sun position tracks across sky east→west
  local sunProgress = (hour - lighting.SUNRISE_HOUR) / (lighting.SUNSET_HOUR - lighting.SUNRISE_HOUR)
  local sunX = screenW * (0.15 + sunProgress * 0.7)  -- east to west
  local sunHeight = math.sin(sunAngle)
  local sunY = 30 + (1 - sunHeight) * 80  -- higher at noon, lower at dawn/dusk

  -- Sun color shifts through the day
  local sunR, sunG, sunB
  if hour < 7 then  -- dawn: orange-gold
    local t = (hour - lighting.SUNRISE_HOUR) / 1.5
    sunR, sunG, sunB = 1.0, 0.65 + t * 0.25, 0.3 + t * 0.35
  elseif hour < 16 then  -- midday: bright white-yellow
    sunR, sunG, sunB = 1.0, 0.97, 0.85
  elseif hour < 18 then  -- afternoon: warm amber
    local t = (hour - 16) / 2
    sunR, sunG, sunB = 1.0, 0.97 - t * 0.25, 0.85 - t * 0.40
  else  -- sunset: deep orange-red
    local t = (hour - 18) / 1.5
    sunR, sunG, sunB = 1.0, 0.72 - t * 0.35, 0.45 - t * 0.25
  end

  -- ═══ OUTER HALO (large soft glow) ═══
  for r = 120, 20, -5 do
    local a = 0.02 + (120 - r) / 120 * 0.15
    love.graphics.setColor(sunR, sunG, sunB, a)
    love.graphics.circle("fill", sunX, sunY, r)
  end

  -- ═══ MIDDLE GLOW (warm corona) ═══
  for r = 50, 10, -3 do
    local a = 0.08 + (50 - r) / 50 * 0.45
    love.graphics.setColor(sunR, sunG * 0.98, sunB * 0.95, a)
    love.graphics.circle("fill", sunX, sunY, r)
  end

  -- ═══ BRIGHT CORE ═══
  love.graphics.setColor(sunR, sunG, sunB, 0.95)
  love.graphics.circle("fill", sunX, sunY, 22)

  -- Inner white-hot center
  love.graphics.setColor(1, 1, 0.97, 0.85)
  love.graphics.circle("fill", sunX, sunY, 12)

  -- ═══ ANIMATED SUN RAYS (rotating slowly) ═══
  local rayCount = 8
  local rayRotation = time * 0.15  -- slow rotation
  for i = 1, rayCount do
    local rayAngle = (i / rayCount) * math.pi * 2 + rayRotation
    local rayLen = 90 + math.sin(time * 1.5 + i * 1.3) * 25  -- pulse
    local rayWidth = 0.08 + math.sin(time * 0.8 + i * 2.1) * 0.03

    local x1 = sunX + math.cos(rayAngle) * 25
    local y1 = sunY + math.sin(rayAngle) * 25
    local x2 = sunX + math.cos(rayAngle) * rayLen
    local y2 = sunY + math.sin(rayAngle) * rayLen

    -- Ray as thin gradient triangle
    local perpX = -math.sin(rayAngle) * rayLen * rayWidth
    local perpY = math.cos(rayAngle) * rayLen * rayWidth
    love.graphics.setColor(sunR, sunG, sunB, 0.06)
    love.graphics.polygon("fill",
      x1, y1,
      x2 + perpX, y2 + perpY,
      x2 - perpX, y2 - perpY
    )
  end

  -- ═══ LENS FLARE DOTS (subtle, along diagonal) ═══
  local flareAngle = math.pi * 0.75 + math.sin(time * 0.1) * 0.05
  for i = 1, 3 do
    local fd = 60 + i * 45
    local fx = sunX + math.cos(flareAngle) * fd
    local fy = sunY + math.sin(flareAngle) * fd
    local fr = 4 + math.sin(time * 0.7 + i * 2) * 2
    love.graphics.setColor(sunR, sunG * 0.9, sunB * 0.7, 0.06 + math.sin(time + i) * 0.02)
    love.graphics.circle("fill", fx, fy, fr)
  end

  -- ═══ GOD RAYS (angled light shafts, dawn/dusk only) ═══
  local sunsetGlow = lighting.getSunsetGlow()
  if sunsetGlow > 0.2 then
    local rayAlpha = (sunsetGlow - 0.2) * 0.06
    love.graphics.setColor(sunR, sunG * 0.85, sunB * 0.6, rayAlpha)
    for i = 1, 5 do
      local rx = sunX - 100 + i * 50
      love.graphics.polygon("fill",
        rx, sunY + 30,
        rx + 10, sunY + 30,
        rx + 100, screenH,
        rx - 50, screenH
      )
    end
  end
end

return M
