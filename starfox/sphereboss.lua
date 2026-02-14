local M = {}
local screen = require("starfox.screen")

M.boss = nil

-- The Sphere: Final boss — 4-phase Death Star core run
-- Phase 1: Outer Shell — rotating shield plates, aimed volleys
-- Phase 2: Inner Shell — gravity tethers, sweeping laser rings
-- Phase 3: Reactor Puzzle — solve puzzle nodes while drones attack
-- Phase 4: The Mirror — fight your own clone that mimics your moves

-- Damage values
local DAMAGE = {
  shellVolley = 10,       -- Phase 1: aimed triple volleys
  shieldBurst = 14,       -- Phase 1: shield plate explosion on destroy
  gravityTether = 6,      -- Phase 2: gravity DOT per tick
  laserRing = 18,         -- Phase 2: sweeping laser ring hits
  plasmaLance = 12,       -- Phase 2: targeted lance bolts
  droneSting = 8,         -- Phase 3: puzzle-phase drone shots
  mirrorLaser = 10,       -- Phase 4: clone's copied attacks
  mirrorBomb = 20,        -- Phase 4: clone's bomb attack
}

-- Phase HP thresholds (out of 400 total)
-- Phase 1: 400-300 (outer shell)
-- Phase 2: 300-180 (inner shell)
-- Phase 3: 180-100 (puzzle — boss invuln, must solve puzzle, drones damage)
-- Phase 4: 100-0 (mirror clone)
local PHASE_THRESHOLDS = {400, 300, 180, 100}

-- Shell plate max HP
local SHELL_PLATE_HP = 25

function M.reset()
  M.boss = nil
end

function M.spawn()
  M.boss = {
    x = screen.WIDTH / 2,
    y = -180,
    width = 170,
    height = 130,
    health = 400,
    maxHealth = 400,
    score = 20000,
    phase = 1,
    active = true,
    entering = true,
    targetY = 110,

    -- Movement
    baseX = screen.WIDTH / 2,
    moveAngle = 0,

    -- Attack states
    attackTimer = 3,
    currentAttack = nil,
    shouldAttack = false,
    comboCount = 0,

    -- Projectile tracking
    pendingProjectiles = {},

    -- Invuln during transitions
    phaseTransitioning = false,
    transitionTimer = 0,

    -- Background depth progression (0.0 = outer trench, 1.0 = core)
    tunnelDepth = 0,
    tunnelSpeed = 0,

    -- ═══════════════════════════════════════
    -- PHASE 1: Outer Shell
    -- ═══════════════════════════════════════
    shellPlates = {
      {health = SHELL_PLATE_HP, angle = 0,            destroyed = false},
      {health = SHELL_PLATE_HP, angle = math.pi / 2,  destroyed = false},
      {health = SHELL_PLATE_HP, angle = math.pi,      destroyed = false},
      {health = SHELL_PLATE_HP, angle = 3*math.pi/2,  destroyed = false},
    },
    shellRotation = 0,
    shellRotSpeed = 0.8,
    allPlatesDestroyed = false,
    volleyTimer = 0,
    volleyCooldown = 2.2,

    -- ═══════════════════════════════════════
    -- PHASE 2: Inner Shell
    -- ═══════════════════════════════════════
    gravityTethers = {},
    tetherSpawnTimer = 0,
    laserRingAngle = 0,
    laserRingSpeed = 1.5,
    laserRingActive = false,
    laserRingTimer = 0,
    laserRingCooldown = 6,
    lanceTimer = 0,
    lanceCooldown = 2.0,

    -- ═══════════════════════════════════════
    -- PHASE 3: Reactor Puzzle
    -- ═══════════════════════════════════════
    puzzleActive = false,
    puzzleNodes = {},       -- nodes to shoot in order
    puzzleSequence = {},    -- correct order
    puzzleCurrentIdx = 1,   -- which node is next
    puzzleSolved = false,
    puzzleFlashTimer = 0,
    puzzleDrones = {},
    puzzleDroneTimer = 0,
    puzzleDroneCooldown = 3,
    puzzleFailTimer = 0,   -- flashes red on wrong hit

    -- ═══════════════════════════════════════
    -- PHASE 4: The Mirror (Clone)
    -- ═══════════════════════════════════════
    clone = nil,            -- spawned when phase 4 starts
    cloneStunned = false,
    cloneStunTimer = 0,
    cloneStunCooldown = 0,
    cloneAttackTimer = 0,
    cloneBombTimer = 0,
  }
end

function M.isActive()
  return M.boss ~= nil and M.boss.active
end

function M.isDefeated()
  return M.boss ~= nil and not M.boss.active and M.boss.health <= 0
end

-- ═══════════════════════════════════════════════════
-- UPDATE
-- ═══════════════════════════════════════════════════

function M.update(dt, playerX, playerY)
  local b = M.boss
  if not b or not b.active then return end

  b.shouldAttack = false
  b.pendingProjectiles = {}

  -- Entry animation
  if b.entering then
    b.y = b.y + 70 * dt
    if b.y >= b.targetY then
      b.y = b.targetY
      b.entering = false
    end
    return
  end

  -- Phase transition invuln
  if b.phaseTransitioning then
    b.transitionTimer = b.transitionTimer - dt
    if b.transitionTimer <= 0 then
      b.phaseTransitioning = false
      M.onPhaseStart()
    end
    return
  end

  M.updatePhase()
  M.updateTunnelDepth(dt)

  if b.phase == 1 then
    M.updatePhase1(dt, playerX, playerY)
  elseif b.phase == 2 then
    M.updatePhase2(dt, playerX, playerY)
  elseif b.phase == 3 then
    M.updatePhase3(dt, playerX, playerY)
  elseif b.phase == 4 then
    M.updatePhase4(dt, playerX, playerY)
  end

  M.updateMovement(dt)
end

function M.updatePhase()
  local b = M.boss
  local oldPhase = b.phase

  -- Determine phase from health
  local newPhase = 1
  for i = #PHASE_THRESHOLDS, 1, -1 do
    if b.health <= PHASE_THRESHOLDS[i] then
      newPhase = i
    end
  end

  -- Phase 3 requires puzzle solve to leave; clamp at 3 until solved
  if oldPhase == 3 and not b.puzzleSolved then
    newPhase = 3
  end

  if newPhase > oldPhase then
    b.phase = newPhase
    b.phaseTransitioning = true
    b.transitionTimer = 2.0
    -- Cancel active attacks
    b.laserRingActive = false
    b.gravityTethers = {}
  end
end

function M.onPhaseStart()
  local b = M.boss
  b.attackTimer = 1.5

  if b.phase == 3 then
    M.initPuzzle()
  elseif b.phase == 4 then
    M.initClone()
  end
end

-- Tunnel depth drives the background visuals — deeper = closer to core
function M.updateTunnelDepth(dt)
  local b = M.boss
  local targetDepth = (b.phase - 1) / 3  -- 0, 0.33, 0.66, 1.0
  b.tunnelSpeed = (targetDepth - b.tunnelDepth) * 2
  b.tunnelDepth = b.tunnelDepth + b.tunnelSpeed * dt
  b.tunnelDepth = math.max(0, math.min(1, b.tunnelDepth))
end

function M.updateMovement(dt)
  local b = M.boss
  if b.phaseTransitioning then return end

  local speed = 1.0
  if b.phase == 2 then speed = 1.6 end
  if b.phase == 4 then speed = 0.8 end  -- Mirror phase: boss stays more centered

  b.moveAngle = b.moveAngle + speed * dt
  local range = 80 + (b.phase * 15)
  if b.phase == 3 then range = 40 end  -- Puzzle phase: minimal movement
  b.x = b.baseX + math.sin(b.moveAngle) * range

  -- Slight vertical bob
  if b.phase >= 2 then
    b.y = b.targetY + math.sin(b.moveAngle * 0.5) * 20
  end
end

-- ═══════════════════════════════════════════════════
-- PHASE 1: Outer Shell — Rotating shield plates + aimed volleys
-- Destroy all 4 plates to expose the core
-- ═══════════════════════════════════════════════════

function M.updatePhase1(dt, playerX, playerY)
  local b = M.boss

  -- Rotate shell plates
  b.shellRotation = b.shellRotation + b.shellRotSpeed * dt

  -- Fire aimed volleys from intact plates
  b.volleyTimer = b.volleyTimer - dt
  if b.volleyTimer <= 0 then
    b.volleyTimer = b.volleyCooldown
    M.fireShellVolley(playerX, playerY)
  end

  -- Check if all plates destroyed
  if not b.allPlatesDestroyed then
    local allGone = true
    for _, plate in ipairs(b.shellPlates) do
      if not plate.destroyed then allGone = false; break end
    end
    if allGone then
      b.allPlatesDestroyed = true
      -- Core is now vulnerable — standard attacks only
      b.volleyCooldown = 1.5
    end
  end

  -- When core exposed, fire spread attacks
  if b.allPlatesDestroyed then
    b.attackTimer = b.attackTimer - dt
    if b.attackTimer <= 0 then
      b.attackTimer = 1.8
      M.fireSpreadPattern(playerX, playerY)
    end
  end
end

function M.fireShellVolley(playerX, playerY)
  local b = M.boss

  -- Each intact plate fires a triple volley
  for _, plate in ipairs(b.shellPlates) do
    if not plate.destroyed then
      local pAngle = plate.angle + b.shellRotation
      local px = b.x + math.cos(pAngle) * 70
      local py = b.y + math.sin(pAngle) * 45

      local aimAngle = math.atan2(playerY - py, playerX - px)
      for offset = -1, 1 do
        table.insert(b.pendingProjectiles, {
          type = "shellVolley",
          x = px,
          y = py,
          angle = aimAngle + offset * 0.2,
          speed = 280,
          damage = DAMAGE.shellVolley
        })
      end
      b.shouldAttack = true
      b.currentAttack = "shellVolley"
    end
  end
end

-- ═══════════════════════════════════════════════════
-- PHASE 2: Inner Shell — Gravity tethers + sweeping laser ring + lances
-- ═══════════════════════════════════════════════════

function M.updatePhase2(dt, playerX, playerY)
  local b = M.boss

  -- Gravity tether zones (DOT)
  M.updateGravityTethers(dt, playerX, playerY)

  -- Sweeping laser ring
  M.updateLaserRing(dt)

  -- Plasma lances (aimed shots)
  b.lanceTimer = b.lanceTimer - dt
  if b.lanceTimer <= 0 and not b.laserRingActive then
    b.lanceTimer = b.lanceCooldown
    M.firePlasmaLances(playerX, playerY)
  end

  -- General attack timer for spread/sweep patterns
  b.attackTimer = b.attackTimer - dt
  if b.attackTimer <= 0 and not b.laserRingActive then
    b.attackTimer = 2.2
    local roll = math.random(100)
    if roll < 50 then
      M.fireSpreadPattern(playerX, playerY)
    else
      M.fireSweepPattern(playerX, playerY)
    end
  end
end

function M.updateGravityTethers(dt, playerX, playerY)
  local b = M.boss

  b.tetherSpawnTimer = b.tetherSpawnTimer - dt
  if b.tetherSpawnTimer <= 0 and #b.gravityTethers < 3 then
    b.tetherSpawnTimer = 5
    table.insert(b.gravityTethers, {
      x = math.random(120, screen.WIDTH - 120),
      y = math.random(280, screen.HEIGHT - 100),
      radius = 55,
      lifetime = 7,
      damage = DAMAGE.gravityTether,
      damageTimer = 0,
      pullStrength = 130,
    })
  end

  for i = #b.gravityTethers, 1, -1 do
    local t = b.gravityTethers[i]
    t.lifetime = t.lifetime - dt
    t.damageTimer = t.damageTimer - dt
    if t.lifetime <= 0 then
      table.remove(b.gravityTethers, i)
    end
  end
end

function M.updateLaserRing(dt)
  local b = M.boss

  if b.laserRingActive then
    b.laserRingAngle = b.laserRingAngle + b.laserRingSpeed * dt
    b.laserRingTimer = b.laserRingTimer - dt
    if b.laserRingTimer <= 0 then
      b.laserRingActive = false
      b.laserRingCooldown = 6
    end
  else
    b.laserRingCooldown = b.laserRingCooldown - dt
    if b.laserRingCooldown <= 0 then
      b.laserRingActive = true
      b.laserRingTimer = 4  -- ring active for 4 seconds
      b.laserRingAngle = 0
    end
  end
end

function M.firePlasmaLances(playerX, playerY)
  local b = M.boss
  -- 2 lances aimed at player with slight spread
  for i = -1, 1, 2 do
    local angle = math.atan2(playerY - b.y, playerX - b.x) + i * 0.15
    table.insert(b.pendingProjectiles, {
      type = "plasmaLance",
      x = b.x + i * 40,
      y = b.y + 50,
      angle = angle,
      speed = 360,
      damage = DAMAGE.plasmaLance,
    })
  end
  b.shouldAttack = true
  b.currentAttack = "plasmaLance"
end

-- ═══════════════════════════════════════════════════
-- PHASE 3: Reactor Puzzle
-- Boss is invulnerable. 4 reactor nodes appear around the boss.
-- They flash in a sequence; player must shoot them in order.
-- Meanwhile, drones attack the player.
-- Solving the puzzle drops the boss to phase 4 HP.
-- ═══════════════════════════════════════════════════

function M.initPuzzle()
  local b = M.boss

  b.puzzleActive = true
  b.puzzleSolved = false
  b.puzzleCurrentIdx = 1
  b.puzzleDrones = {}
  b.puzzleDroneTimer = 2
  b.puzzleFlashTimer = 0

  -- Create 4 puzzle nodes arranged around the boss
  local nodePositions = {
    {x = b.x - 120, y = b.y - 60},
    {x = b.x + 120, y = b.y - 60},
    {x = b.x - 120, y = b.y + 80},
    {x = b.x + 120, y = b.y + 80},
  }

  b.puzzleNodes = {}
  for i, pos in ipairs(nodePositions) do
    table.insert(b.puzzleNodes, {
      x = pos.x,
      y = pos.y,
      radius = 18,
      hit = false,
      idx = i,
      flashPhase = 0,
    })
  end

  -- Generate random sequence (all 4 nodes, each once)
  b.puzzleSequence = {1, 2, 3, 4}
  -- Fisher-Yates shuffle
  for i = 4, 2, -1 do
    local j = math.random(i)
    b.puzzleSequence[i], b.puzzleSequence[j] = b.puzzleSequence[j], b.puzzleSequence[i]
  end
end

function M.updatePhase3(dt, playerX, playerY)
  local b = M.boss

  if b.puzzleSolved then return end

  -- Animate puzzle node flash sequence
  b.puzzleFlashTimer = b.puzzleFlashTimer + dt

  -- Update puzzle node positions (they orbit the boss slightly)
  local time = love.timer.getTime()
  for i, node in ipairs(b.puzzleNodes) do
    local baseAngle = (i - 1) * (math.pi / 2) + time * 0.3
    local dist = 110
    node.x = b.x + math.cos(baseAngle) * dist
    node.y = b.y + math.sin(baseAngle) * (dist * 0.6)
  end

  -- Spawn attack drones that harass the player
  M.updatePuzzleDrones(dt, playerX, playerY)
end

function M.updatePuzzleDrones(dt, playerX, playerY)
  local b = M.boss

  -- Update existing drones
  for i = #b.puzzleDrones, 1, -1 do
    local d = b.puzzleDrones[i]
    d.timer = d.timer - dt
    d.orbitAngle = d.orbitAngle + d.orbitSpeed * dt

    -- Drones circle around edges and fire at player
    d.x = d.anchorX + math.cos(d.orbitAngle) * d.orbitRadius
    d.y = d.anchorY + math.sin(d.orbitAngle) * d.orbitRadius * 0.5

    d.attackTimer = d.attackTimer - dt
    if d.attackTimer <= 0 then
      d.attackTimer = 2.5
      table.insert(b.pendingProjectiles, {
        type = "droneSting",
        x = d.x,
        y = d.y,
        targetX = playerX,
        targetY = playerY,
        damage = DAMAGE.droneSting,
      })
      b.shouldAttack = true
      b.currentAttack = "droneSting"
    end

    if d.timer <= 0 then
      table.remove(b.puzzleDrones, i)
    end
  end

  -- Spawn new drones
  b.puzzleDroneTimer = b.puzzleDroneTimer - dt
  if b.puzzleDroneTimer <= 0 and #b.puzzleDrones < 4 then
    b.puzzleDroneTimer = b.puzzleDroneCooldown
    local side = math.random() < 0.5 and 1 or -1
    table.insert(b.puzzleDrones, {
      x = screen.WIDTH / 2 + side * 200,
      y = 200,
      anchorX = screen.WIDTH / 2 + side * 200,
      anchorY = 250,
      orbitAngle = math.random() * math.pi * 2,
      orbitSpeed = 1.5 + math.random() * 1.0,
      orbitRadius = 60 + math.random() * 40,
      timer = 8,
      attackTimer = 1.5,
      health = 8,
    })
  end
end

-- Called by init.lua when a puzzle node is shot
function M.onPuzzleNodeHit(nodeIdx)
  local b = M.boss
  if not b or not b.puzzleActive or b.puzzleSolved then return end

  local expectedNode = b.puzzleSequence[b.puzzleCurrentIdx]

  if nodeIdx == expectedNode then
    -- Correct node!
    b.puzzleNodes[nodeIdx].hit = true
    b.puzzleCurrentIdx = b.puzzleCurrentIdx + 1

    if b.puzzleCurrentIdx > #b.puzzleSequence then
      -- Puzzle solved!
      b.puzzleSolved = true
      b.puzzleActive = false
      b.puzzleDrones = {}
      -- Force health to phase 4 threshold and trigger transition
      b.health = PHASE_THRESHOLDS[4]
      b.phase = 4
      b.phaseTransitioning = true
      b.transitionTimer = 2.5
    end
  else
    -- Wrong node — reset progress, flash red
    b.puzzleCurrentIdx = 1
    b.puzzleFailTimer = 0.8
    for _, node in ipairs(b.puzzleNodes) do
      node.hit = false
    end
  end
end

-- Get puzzle targets for collision checking in init.lua
function M.getPuzzleTargets()
  local b = M.boss
  if not b or not b.puzzleActive or b.puzzleSolved then return nil end
  return b.puzzleNodes
end

-- ═══════════════════════════════════════════════════
-- PHASE 4: The Mirror — Clone fight
-- A ghostly copy of the player's ship appears.
-- It mirrors the player's position (inverted) and fires back.
-- Stun it (barrel roll reflect / bomb) to break the mirroring
-- and create a damage window.
-- ═══════════════════════════════════════════════════

function M.initClone()
  local b = M.boss

  b.clone = {
    x = screen.WIDTH / 2,
    y = 150,
    width = 40,
    height = 40,
    mirrorX = 0,
    mirrorY = 0,
    stunned = false,
    stunTimer = 0,
    attackTimer = 2,
    bombTimer = 8,
    health = 100,     -- Same as phase 4 boss HP
    invulnFlash = 0,
  }
  b.cloneStunned = false
  b.cloneStunTimer = 0
end

function M.updatePhase4(dt, playerX, playerY)
  local b = M.boss
  if not b.clone then return end

  local c = b.clone

  -- Mirror positioning: clone mirrors player across center of screen
  if not c.stunned then
    -- Mirror X across screen center
    c.mirrorX = screen.WIDTH - playerX
    -- Mirror Y: clone stays in upper portion, inverted from player's position
    c.mirrorY = screen.HEIGHT - playerY

    -- Smoothly move toward mirror position
    local lerpSpeed = 6 * dt
    c.x = c.x + (c.mirrorX - c.x) * lerpSpeed
    c.y = c.y + (c.mirrorY - c.y) * lerpSpeed

    -- Clamp clone to playable area
    c.x = math.max(40, math.min(screen.WIDTH - 40, c.x))
    c.y = math.max(60, math.min(screen.HEIGHT - 100, c.y))
  else
    -- Stunned: drift slowly, vulnerable
    c.stunTimer = c.stunTimer - dt
    c.x = c.x + math.sin(love.timer.getTime() * 3) * 30 * dt
    if c.stunTimer <= 0 then
      c.stunned = false
      c.invulnFlash = 1.0  -- Brief invuln after stun ends
    end
  end

  -- Invuln flash after stun wears off
  if c.invulnFlash > 0 then
    c.invulnFlash = c.invulnFlash - dt * 2
  end

  -- Clone attacks: fires mirrored lasers
  c.attackTimer = c.attackTimer - dt
  if c.attackTimer <= 0 and not c.stunned then
    c.attackTimer = 1.5
    -- Fire at player
    local angle = math.atan2(playerY - c.y, playerX - c.x)
    for offset = -1, 1 do
      table.insert(b.pendingProjectiles, {
        type = "mirrorLaser",
        x = c.x,
        y = c.y,
        angle = angle + offset * 0.15,
        speed = 320,
        damage = DAMAGE.mirrorLaser,
      })
    end
    b.shouldAttack = true
    b.currentAttack = "mirrorLaser"
  end

  -- Clone bomb: periodic large burst
  c.bombTimer = c.bombTimer - dt
  if c.bombTimer <= 0 and not c.stunned then
    c.bombTimer = 10
    -- Omnidirectional burst
    for i = 0, 11 do
      local angle = (i / 12) * math.pi * 2
      table.insert(b.pendingProjectiles, {
        type = "mirrorBomb",
        x = c.x,
        y = c.y,
        angle = angle,
        speed = 200,
        damage = DAMAGE.mirrorBomb,
      })
    end
    b.shouldAttack = true
    b.currentAttack = "mirrorBomb"
  end

  -- Boss health is synced to clone health
  b.health = c.health
end

-- Stun the clone (called when a reflected projectile or bomb hits it)
function M.stunClone(duration)
  local b = M.boss
  if not b or not b.clone then return end
  if b.clone.invulnFlash > 0 then return end

  b.clone.stunned = true
  b.clone.stunTimer = duration or 3
end

-- ═══════════════════════════════════════════════════
-- SHARED ATTACK PATTERNS
-- ═══════════════════════════════════════════════════

function M.fireSpreadPattern(playerX, playerY)
  local b = M.boss
  local count = 5
  if b.phase >= 2 then count = 7 end

  for i = 1, count do
    local angle = math.pi / 2 + ((i - (count + 1) / 2) * 0.22)
    table.insert(b.pendingProjectiles, {
      type = "spread",
      x = b.x,
      y = b.y + 55,
      angle = angle,
      speed = 280,
      damage = DAMAGE.shellVolley,
    })
  end
  b.shouldAttack = true
  b.currentAttack = "spread"
end

function M.fireSweepPattern(playerX, playerY)
  local b = M.boss

  for i = 0, 9 do
    local delay = i * 0.07
    local angle = math.pi / 2 - 0.55 + (i * 0.11)
    table.insert(b.pendingProjectiles, {
      type = "sweep",
      x = b.x,
      y = b.y + 55,
      angle = angle,
      speed = 370,
      damage = DAMAGE.plasmaLance,
      delay = delay,
    })
  end
  b.shouldAttack = true
  b.currentAttack = "sweep"
end

-- ═══════════════════════════════════════════════════
-- DAMAGE
-- ═══════════════════════════════════════════════════

function M.damage(amount, hitTarget)
  local b = M.boss
  if not b or not b.active then return false end
  if b.phaseTransitioning then return false end

  -- Phase 1: Must hit shell plates when they exist
  if b.phase == 1 and not b.allPlatesDestroyed then
    if hitTarget and hitTarget >= 1 and hitTarget <= 4 then
      local plate = b.shellPlates[hitTarget]
      if plate and not plate.destroyed then
        plate.health = plate.health - amount
        if plate.health <= 0 then
          plate.destroyed = true
        end
      end
    end
    return false
  end

  -- Phase 3: Boss is invulnerable during puzzle (damage drones instead)
  if b.phase == 3 and not b.puzzleSolved then
    return false
  end

  -- Phase 4: Damage goes to clone only when stunned
  if b.phase == 4 and b.clone then
    if b.clone.stunned then
      b.clone.health = b.clone.health - amount
      b.health = b.clone.health
      if b.clone.health <= 0 then
        b.clone.health = 0
        b.health = 0
        b.active = false
        return true
      end
    end
    -- Not stunned = invulnerable
    return false
  end

  -- Phases 1 (core exposed) and 2: direct damage
  b.health = b.health - amount
  if b.health <= 0 then
    b.health = 0
    b.active = false
    return true
  end
  return false
end

-- Damage a puzzle drone specifically
function M.damageDrone(droneIdx, amount)
  local b = M.boss
  if not b or b.phase ~= 3 then return false end

  local drone = b.puzzleDrones[droneIdx]
  if drone then
    drone.health = drone.health - amount
    if drone.health <= 0 then
      table.remove(b.puzzleDrones, droneIdx)
      return true
    end
  end
  return false
end

-- ═══════════════════════════════════════════════════
-- SPECIAL MECHANICS QUERIES (for init.lua)
-- ═══════════════════════════════════════════════════

-- Get gravity tether pull (Phase 2)
function M.getGravityTetherPull(playerX, playerY)
  local b = M.boss
  if not b or b.phase ~= 2 then return 0, 0, 0 end

  local totalPullX, totalPullY = 0, 0
  local maxStrength = 0

  for _, t in ipairs(b.gravityTethers) do
    local dx = t.x - playerX
    local dy = t.y - playerY
    local dist = math.sqrt(dx * dx + dy * dy)
    if dist < t.radius * 2.5 and dist > 1 then
      local strength = t.pullStrength * (1 - dist / (t.radius * 2.5))
      totalPullX = totalPullX + (dx / dist) * strength
      totalPullY = totalPullY + (dy / dist) * strength
      if strength > maxStrength then maxStrength = strength end
    end
  end

  return totalPullX, totalPullY, maxStrength
end

-- Check tether DOT damage
function M.checkTetherDamage(playerX, playerY, playerRadius)
  local b = M.boss
  if not b or b.phase ~= 2 then return 0 end

  local totalDamage = 0
  for _, t in ipairs(b.gravityTethers) do
    local dx = playerX - t.x
    local dy = playerY - t.y
    local dist = math.sqrt(dx * dx + dy * dy)

    if dist < t.radius + playerRadius and t.damageTimer <= 0 then
      t.damageTimer = 0.5
      totalDamage = totalDamage + t.damage
    end
  end
  return totalDamage
end

-- Check laser ring hit (Phase 2)
function M.checkLaserRingHit(playerX, playerY, playerRadius)
  local b = M.boss
  if not b or not b.laserRingActive then return false end

  -- Laser ring = 4 beams rotating from boss center
  local ringRadius = 250
  for i = 0, 3 do
    local beamAngle = b.laserRingAngle + (i * math.pi / 2)
    -- Check if player is near the beam line
    local bx = b.x + math.cos(beamAngle) * ringRadius
    local by = b.y + math.sin(beamAngle) * ringRadius

    -- Simple line-circle collision: beam from boss center to (bx,by)
    local dx = bx - b.x
    local dy = by - b.y
    local fx = b.x - playerX
    local fy = b.y - playerY

    local a = dx * dx + dy * dy
    local b_coef = 2 * (fx * dx + fy * dy)
    local c = fx * fx + fy * fy - (playerRadius + 8) * (playerRadius + 8)

    local disc = b_coef * b_coef - 4 * a * c
    if disc >= 0 then
      disc = math.sqrt(disc)
      local t1 = (-b_coef - disc) / (2 * a)
      local t2 = (-b_coef + disc) / (2 * a)
      if (t1 >= 0 and t1 <= 1) or (t2 >= 0 and t2 <= 1) then
        return true
      end
    end
  end
  return false
end

-- Get shell plate positions for collision detection
function M.getShellPlatePositions()
  local b = M.boss
  if not b or b.phase ~= 1 then return {} end

  local positions = {}
  for i, plate in ipairs(b.shellPlates) do
    if not plate.destroyed then
      local pAngle = plate.angle + b.shellRotation
      table.insert(positions, {
        idx = i,
        x = b.x + math.cos(pAngle) * 70,
        y = b.y + math.sin(pAngle) * 45,
        radius = 22,
      })
    end
  end
  return positions
end

-- Get clone for collision checking
function M.getClone()
  local b = M.boss
  if not b or b.phase ~= 4 then return nil end
  return b.clone
end

-- Get pending projectiles for weapons system
function M.getPendingProjectiles()
  local b = M.boss
  if not b then return {} end
  return b.pendingProjectiles
end

-- Get current attack info for HUD warnings
function M.getAttackWarning()
  local b = M.boss
  if not b then return nil end

  if b.phaseTransitioning then
    return "ENTERING THE CORE", b.transitionTimer / 2.0
  elseif b.laserRingActive then
    return "LASER RING", b.laserRingTimer / 4
  elseif b.phase == 3 and not b.puzzleSolved then
    return "DESTROY THE REACTOR", 1
  elseif b.phase == 4 and b.clone and not b.clone.stunned then
    return "STUN THE MIRROR", 1
  end

  return nil
end

-- Get phase name for display
function M.getPhaseName()
  local b = M.boss
  if not b then return "" end

  local names = {
    "OUTER SHELL",
    "INNER SHELL",
    "REACTOR CORE",
    "THE MIRROR"
  }
  return names[b.phase] or ""
end

-- Get tunnel depth for background rendering
function M.getTunnelDepth()
  local b = M.boss
  if not b then return 0 end
  return b.tunnelDepth
end

return M
