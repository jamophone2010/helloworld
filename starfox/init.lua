local M = {}

local player = require("starfox.player")
local weapons = require("starfox.weapons")
local enemies = require("starfox.enemies")
local turrets = require("starfox.turrets")
local terrain = require("starfox.terrain")
local particles = require("starfox.particles")
local wingmen = require("starfox.wingmen")
local boss = require("starfox.boss")
local audio = require("starfox.audio")
local ui = require("starfox.ui")
local levelselect = require("starfox.levelselect")
local levels = require("starfox.levels")
local capitalship = require("starfox.capitalship")
local mothership = require("starfox.mothership")
local allies = require("starfox.allies")
local portals = require("starfox.portals")
local bolse = require("starfox.bolse")
local rival = require("starfox.rival")
local maze = require("starfox.maze")
local venomboss = require("starfox.venomboss")
local sectorzboss = require("starfox.sectorzboss")
local wardenboss = require("starfox.wardenboss")
local sentinelboss = require("starfox.sentinelboss")
local targeting = require("starfox.targeting")
local bossexplosion = require("starfox.bossexplosion")
local supershot = require("starfox.supershot")
local ships = require("starfox.ships")
local abilities = require("starfox.abilities")
local morseinput = require("starfox.morseinput")
local screen = require("starfox.screen")
local prototype = require("starfox.prototype")
local megalith = require("starfox.megalith")
local dynamoboss = require("starfox.dynamoboss")
local synesthesia = require("starfox.synesthesia")
local raid = require("starfox.raid")
local raidboss = require("starfox.raidboss")
local sphereboss = require("starfox.sphereboss")
local machineboss = require("starfox.machineboss")
local muses = require("kalapatthar.muses")

local gameState = {}
local pendingShopItems = {lives = 0, bombs = 0, health = 0}

-- Muse power B-hold tracking (hold B = Muse power, tap B = N/A in starfox)
local museBHoldTimer = 0
local MUSE_B_HOLD_THRESHOLD = 0.3
local museBHeld = false
local chainLightningArcs = {}

-- Progression callbacks (set by main.lua)
M.onMegaAntennaAwarded = nil
M.onPowerAmplifierAwarded = nil

-- Track if entered from asteroids portal
M.enteredFromPortal = false
M.returnToAsteroids = nil

-- Helper function to register kills for both score and supershot tracking
local function registerKill(p, score)
  player.addScore(p, score)
  supershot.registerKill()
  abilities.registerKill(gameState.levelId)
end

function M.load()
  gameState.state = "levelselect"
  gameState.player = nil
  gameState.waveIndex = 1
  gameState.bossDefeated = false
  gameState.levelId = 1
  gameState.levelWaves = nil
  gameState.pauseMenuIndex = 1

  weapons.reset()
  enemies.reset()
  turrets.reset()
  terrain.reset()
  particles.reset()
  wingmen.reset()
  boss.reset()
  capitalship.reset()
  mothership.reset()
  allies.reset()
  portals.reset()
  bolse.reset()
  rival.reset()
  maze.reset()
  venomboss.reset()
  sectorzboss.reset()
  wardenboss.reset()
  sentinelboss.reset()
  megalith.reset()
  dynamoboss.reset()
  targeting.reset()
  bossexplosion.reset()
  supershot.reset()
  abilities.reset()
  morseinput.reset()
  prototype.reset()
  synesthesia.reset()
  raid.reset()
  raidboss.reset()
  sphereboss.reset()
  machineboss.reset()

  audio.load()
  ui.load()
  levelselect.load()
end

function M.startGame()
  gameState.state = "intro"
  gameState.introTimer = 0
  gameState.introTotalDuration = 4.5 -- total intro length before playing
  gameState.player = player.new(M.enteredFromPortal)
  
  -- Disable portal entry animation since we handle intro via yOffset
  -- Also set player to normal play position to avoid clamping jump
  gameState.player.portalEntryActive = false
  gameState.player.portalEntryTimer = 0
  gameState.player.y = screen.HEIGHT - 100

  -- Capture shop items before clearing
  local shopLives = pendingShopItems.lives or 0
  local shopBombs = pendingShopItems.bombs or 0
  local shopHealth = pendingShopItems.health or 0
  local shopLaser = pendingShopItems.laser or false
  pendingShopItems = {lives = 0, bombs = 0, health = 0, laser = false}

  -- Apply shop items (non-health first)
  gameState.player.lives = gameState.player.lives + shopLives
  gameState.player.bombs = gameState.player.bombs + shopBombs
  gameState.player.hasLaser = shopLaser

  gameState.waveIndex = 1
  gameState.bossDefeated = false
  gameState.levelId = levelselect.getSelectedId()
  gameState.levelWaves = levels.getWaves(gameState.levelId)
  gameState.totalEnemiesSpawned = 0
  gameState.notesEarned = 0
  ui.setLevelId(gameState.levelId)

  weapons.reset()
  enemies.reset()
  turrets.reset()
  terrain.reset()
  particles.reset()
  wingmen.reset()
  boss.reset()
  capitalship.reset()
  mothership.reset()
  allies.reset()
  portals.reset()
  bolse.reset()
  rival.reset()
  maze.reset()
  venomboss.reset()
  sectorzboss.reset()
  wardenboss.reset()
  sentinelboss.reset()
  megalith.reset()
  dynamoboss.reset()
  targeting.reset()
  bossexplosion.reset()
  supershot.reset()
  abilities.reset()
  morseinput.reset()
  prototype.reset()
  synesthesia.reset()
  raid.reset()
  raidboss.reset()
  sphereboss.reset()
  machineboss.reset()

  -- Reset Muse combat state for new level
  muses.resetCombatState()
  museBHeld = false
  museBHoldTimer = 0
  chainLightningArcs = {}

  -- Apply selected ship stats
  ships.applyToPlayer(gameState.player)

  -- Sector Y: Start with full special gauge
  if gameState.levelId == 3 then
    local def = ships.getSelectedDef()
    if def and def.hasSpecial then
      abilities.gauge = abilities.getGaugeMax()
    end
  end

  -- Aquas: Initialize fog cloud system
  if gameState.levelId == 6 then
    terrain.initFog()
  end

  -- Re-apply shop health bonus after ship stats (additive to new max)
  if shopHealth > 0 then
    gameState.player.maxHealth = gameState.player.maxHealth + shopHealth
    gameState.player.health = gameState.player.maxHealth
  end

  -- Check if Prototype is on this sector - if so, it will appear during the level
  if prototype.prototypeOnMap and prototype.prototypeMapSector == gameState.levelId then
    gameState.prototypeWillAppear = true
    gameState.prototypeAppearTimer = 15 + math.random() * 20  -- Appear 15-35 seconds in
  else
    gameState.prototypeWillAppear = false
    gameState.prototypeAppearTimer = 0
  end

  -- Wire morse code activation for special ability
  morseinput.onActivate = function()
    local isSectorY = gameState.levelId == 3
    if (abilities.isReady() or isSectorY) and gameState.state == "playing" then
      local activated = abilities.activate(gameState.player, isSectorY)
      if activated then
        -- Lancer: start multi-lock targeting immediately
        if abilities.abilityType == "multilock" then
          targeting.overrideMaxLocks = 9999
          targeting.startLocking()
        end
      end
    end
  end
end

function M.enterLevelSelect()
  gameState.state = "levelselect"
  gameState.pauseMenuIndex = 1
  ui.resetVictory()
  levelselect.load()
end

-- Start a specific level directly (used by asteroids portals)
function M.startLevel(levelId)
  -- Mark that we entered from a portal (not hub)
  M.enteredFromPortal = true
  levelselect.accessFromHub = false

  -- Find and select the level in levelselect
  local locations = levelselect.getLocations()
  for i, loc in ipairs(locations) do
    if loc.id == levelId then
      levelselect.setSelectedIndex(i)
      break
    end
  end

  M.startGame()
end

-- Set callback for returning to asteroids from portal
function M.setReturnToAsteroids(callback)
  M.returnToAsteroids = callback
end

-- Sync progression state from hub to levelselect
function M.setProgression(hasMegaAntenna, hasPowerAmplifier)
  levelselect.hasMegaAntenna = hasMegaAntenna or false
  levelselect.hasPowerAmplifier = hasPowerAmplifier or false
end

-- Sync Spread Beam upgrade from Orion dungeon
function M.setHasSpreadBeam(val)
  weapons.setHasSpreadBeam(val)
end

-- Sync Hyper Beam upgrade from Messier dungeon
function M.setHasHyperBeam(val)
  weapons.setHasHyperBeam(val)
end

-- Sync Seeker Missiles upgrade from Outer Space dungeon
function M.setHasSeeker(val)
  weapons.setHasSeeker(val)
end

-- Sync Super Bombs upgrade from Bomb Broker dungeon
function M.setHasSuperBombs(val)
  weapons.setHasSuperBombs(val)
end

-- Set return to hub callback for station selection
function M.setReturnToHub(callback)
  levelselect.returnToHub = callback
end

-- Set visited portal levels for Floor 4 level select restriction
function M.setVisitedPortalLevels(levels)
  levelselect.visitedPortalLevels = levels or {}
  -- When called from hub, mark that we're accessing from hub (restricts level select)
  levelselect.accessFromHub = true
  M.enteredFromPortal = false
end

function M.exitToHub()
  if returnToHub then
    returnToHub()
  end
end

function M.getNotesEarned()
  return (gameState.notesEarned or 0) + supershot.getTotalBonusNotes()
end

function M.setShopItems(items)
  pendingShopItems = items or {lives = 0, bombs = 0, health = 0}
end

function M.update(dt)
  if gameState.state == "fadingtostation" then
    gameState.fadeTimer = gameState.fadeTimer + dt
    if gameState.fadeTimer >= gameState.fadeDuration then
      -- Fade complete, return to hub
      if levelselect.returnToHub then
        levelselect.returnToHub()
      end
    end
  elseif gameState.state == "restarting" then
    gameState.fadeTimer = gameState.fadeTimer + dt
    if gameState.fadeTimer >= gameState.fadeDuration then
      -- Fade complete, restart the level
      M.startGame()
    end
  elseif gameState.state == "fadingtoportal" then
    gameState.fadeTimer = gameState.fadeTimer + dt
    if gameState.fadeTimer >= gameState.fadeDuration then
      -- Fade complete, return to asteroids
      if M.returnToAsteroids then
        M.returnToAsteroids()
      end
    end
  elseif gameState.state == "intro" then
    gameState.introTimer = gameState.introTimer + dt
    
    -- Gradually start moving stars from 2.5s onwards (when ship starts entering)
    if gameState.introTimer >= 2.5 then
      local accelProgress = (gameState.introTimer - 2.5) / 2.0  -- 0 to 1 over 2 seconds
      terrain.update(dt * accelProgress)  -- Gradually increase terrain speed
    end
    
    if gameState.introTimer >= gameState.introTotalDuration then
      gameState.state = "playing"
      -- Just reset scroll offset without regenerating stars to avoid jump
      terrain.scrollOffset = 0
    end
  elseif gameState.state == "playing" then
    M.updatePlaying(dt)
  elseif gameState.state == "paused" or gameState.state == "options" then
    -- Don't update game logic when paused
  elseif gameState.state == "levelselect" or gameState.state == "levelselect_paused" or gameState.state == "levelselect_options" then
    levelselect.update(dt)
  elseif gameState.state == "victory" then
    terrain.update(dt)
    ui.updateVictory(dt)
  elseif gameState.state == "gameover" or gameState.state == "warp" then
    -- Decelerate stars during gameover
    if gameState.state == "gameover" then
      terrain.starSpeedMultiplier = math.max(0, terrain.starSpeedMultiplier - dt * 0.5)
    end
    terrain.update(dt)
    particles.update(dt)
  elseif gameState.state == "playerdeath" then
    -- Player death during boss fight: update boss, particles, decelerate stars, count down respawn
    terrain.starSpeedMultiplier = math.max(0.2, terrain.starSpeedMultiplier - dt * 0.5)
    terrain.update(dt)
    particles.update(dt)
    -- Keep bosses animating during death
    boss.update(dt, gameState.deathX, gameState.deathY)
    venomboss.update(dt, gameState.deathX, gameState.deathY)
    sectorzboss.update(dt, gameState.deathX, gameState.deathY)
    wardenboss.update(dt, gameState.deathX, gameState.deathY)
    sentinelboss.update(dt, gameState.deathX, gameState.deathY)
    megalith.update(dt, gameState.deathX, gameState.deathY)
    dynamoboss.update(dt, gameState.deathX, gameState.deathY)
    synesthesia.update(dt, gameState.deathX, gameState.deathY)
    raidboss.update(dt, gameState.deathX, gameState.deathY)
    sphereboss.update(dt, gameState.deathX, gameState.deathY)
    machineboss.update(dt, gameState.deathX, gameState.deathY)
    mothership.update(dt, gameState.deathX, gameState.deathY)
    bolse.update(dt, gameState.deathX, gameState.deathY)
    rival.update(dt, gameState.deathX, gameState.deathY, {})
    bossexplosion.update(dt)
    gameState.deathRespawnTimer = gameState.deathRespawnTimer - dt
    if gameState.deathRespawnTimer <= 0 then
      -- Respawn player
      gameState.state = "playing"
      gameState.player.health = gameState.player.maxHealth
      gameState.player.invulnerableTimer = 3
      gameState.player.x = screen.WIDTH / 2
      gameState.player.y = screen.HEIGHT - 100
      terrain.starSpeedMultiplier = 1.0
    end
  end
end

function M.updatePlaying(dt)
  local dx, dy = 0, 0
  if not gameState.player.stunned then
    if love.keyboard.isDown("left") then dx = dx - 1 end
    if love.keyboard.isDown("right") then dx = dx + 1 end
    if love.keyboard.isDown("up") then dy = dy - 1 end
    if love.keyboard.isDown("down") then dy = dy + 1 end
  end

  player.move(gameState.player, dx, dy)
  player.update(gameState.player, dt)

  -- Tierra Muse power: allow screen wrap instead of clamping
  if muses.hasScreenWrap() then
    local sw = screen.WIDTH
    local sh = screen.HEIGHT
    if gameState.player.x < 0 then gameState.player.x = sw end
    if gameState.player.x > sw then gameState.player.x = 0 end
    if gameState.player.y < 0 then gameState.player.y = sh end
    if gameState.player.y > sh then gameState.player.y = 0 end
  end

  -- Space: targeting/shooting (weapon-dependent) -- blocked when stunned
  if love.keyboard.isDown("space") and not gameState.player.stunned then
    if abilities.isPhaseCloakActive() then
      -- Phantom special: shotgun blast (single shot per press)
      if not gameState.player.shotgunHeld then
        weapons.fireShotgun(gameState.player)
        gameState.player.shotgunHeld = true
      end
    elseif gameState.player.currentWeapon == "laser" and gameState.player.hasLaser then
      -- Spartan Laser: start firing on press
      if not gameState.player.laserFiring then
        weapons.startSpartanLaser(gameState.player)
      end
    elseif abilities.canContinuousShoot() then
      -- Paladin special: charge shot (targeting disabled during special)
      if not weapons.paladinCharging then
        weapons.startPaladinCharge()
      end
    else
      -- Blaster: use targeting system (disabled during Paladin special)
      if not targeting.active and not abilities.shouldReflectBullets() then
        targeting.startLocking()
      end
    end
  else
    -- Handle release
    if abilities.isPhaseCloakActive() then
      -- Clear shotgun hold flag for next press
      gameState.player.shotgunHeld = false
    elseif gameState.player.currentWeapon == "laser" and gameState.player.laserFiring then
      weapons.stopSpartanLaser(gameState.player)
    elseif weapons.paladinCharging then
      -- Release Paladin charge shot
      weapons.firePaladinBlast(gameState.player)
    elseif targeting.active then
      local targets = targeting.releaseLocks()
      if #targets > 0 then
        -- Check for fully-targeted squadrons and drop their shields
        local checkedSquadrons = {}
        for _, t in ipairs(targets) do
          if t.ref and t.ref.squadronId and not checkedSquadrons[t.ref.squadronId] then
            checkedSquadrons[t.ref.squadronId] = true
            -- Check if all squadron members were targeted
            local members = enemies.getSquadronMembers(t.ref.squadronId)
            local allTargeted = #members > 0
            for _, m in ipairs(members) do
              local found = false
              for _, tt in ipairs(targets) do
                if tt.ref == m then found = true; break end
              end
              if not found then allTargeted = false; break end
            end
            if allTargeted then
              enemies.dropSquadronShields(t.ref.squadronId)
              -- Visual feedback: shield break effect
              for _, m in ipairs(members) do
                particles.spawn(m.x, m.y, 12, {1, 0.8, 0.2})
              end
            end
          end
        end
        weapons.fireHomingMissiles(gameState.player, targets)
      else
        weapons.shoot(gameState.player)
      end
    end
  end

  targeting.update(dt, gameState.player, enemies.enemies)

  terrain.update(dt)
  weapons.update(dt, gameState.player)
  weapons.updateSpartanLaser(dt, gameState.player)
  weapons.updatePaladinCharge(dt)

  -- Update abilities and morse input
  abilities.update(dt, gameState.player)
  morseinput.update(dt)

  -- Update Muse powers
  muses.updateCombat(dt)

  -- B-hold detection: if B is held, track duration
  if museBHeld then
    museBHoldTimer = museBHoldTimer + dt
    if museBHoldTimer >= MUSE_B_HOLD_THRESHOLD and not muses.powerActive then
      if muses.canActivate() then
        muses.activate()
      end
    end
  end

  -- Djolt: update chain lightning visual arcs
  for i = #chainLightningArcs, 1, -1 do
    chainLightningArcs[i].timer = chainLightningArcs[i].timer - dt
    if chainLightningArcs[i].timer <= 0 then
      table.remove(chainLightningArcs, i)
    end
  end

  -- Handle Lancer multi-lock expiry: auto-release all locks with barrage
  if not abilities.isMultiLockActive() and targeting.overrideMaxLocks then
    targeting.overrideMaxLocks = nil
    -- Release all locked targets as a barrage
    if targeting.active then
      local targets = targeting.releaseLocks()
      if #targets > 0 then
        -- Check for fully-targeted squadrons and drop their shields
        local checkedSquadrons = {}
        for _, t in ipairs(targets) do
          if t.ref and t.ref.squadronId and not checkedSquadrons[t.ref.squadronId] then
            checkedSquadrons[t.ref.squadronId] = true
            local members = enemies.getSquadronMembers(t.ref.squadronId)
            local allTargeted = #members > 0
            for _, m in ipairs(members) do
              local found = false
              for _, tt in ipairs(targets) do
                if tt.ref == m then found = true; break end
              end
              if not found then allTargeted = false; break end
            end
            if allTargeted then
              enemies.dropSquadronShields(t.ref.squadronId)
              for _, m in ipairs(members) do
                particles.spawn(m.x, m.y, 12, {1, 0.8, 0.2})
              end
            end
          end
        end
        weapons.fireHomingMissiles(gameState.player, targets)
        abilities.spawnMultiLockBarrage(gameState.player.x, gameState.player.y, #targets)
        -- Extra explosion particles per target for bloom effect
        for _, t in ipairs(targets) do
          particles.spawn(t.x, t.y, 12, {1, 0.7, 0.2})
        end
      end
    end
  end

  -- Reflect bullets if Paladin shield is active
  if abilities.shouldReflectBullets() then
    weapons.mirrorProjectiles(gameState.player.x, gameState.player.y, abilities.reflectRadius, true)
    weapons.mirrorProjectiles(gameState.player.x, gameState.player.y, abilities.reflectRadius, true, rival.getLasers())
  end

  -- Barrel roll reflection (disabled during Paladin special)
  if gameState.player.barrelRolling and not abilities.shouldReflectBullets() then
    weapons.mirrorProjectiles(gameState.player.x, gameState.player.y, 40, false)  -- Smaller radius for barrel roll
    weapons.mirrorProjectiles(gameState.player.x, gameState.player.y, 40, false, rival.getLasers())
  end

  local enemySpeedScale = abilities.getEnemySpeedScale()
  local attractEnemies = abilities.shouldAttractEnemies()

  -- Melo Muse power: slow all enemies
  if muses.isTimeSlowed() then
    enemySpeedScale = enemySpeedScale * muses.getTimeScale()
  end

  local escaped = enemies.update(dt, gameState.player.x, gameState.player.y, enemySpeedScale, attractEnemies)
  gameState.player.enemiesEscaped = gameState.player.enemiesEscaped + escaped
  turrets.update(dt, terrain.getScrollOffset(), gameState.player.x, gameState.player.y)
  capitalship.update(dt, gameState.player.x, gameState.player.y)
  mothership.update(dt, gameState.player.x, gameState.player.y)
  allies.update(dt, gameState.player.x, gameState.player.y, enemies.enemies)
  portals.update(dt)
  particles.update(dt)
  bossexplosion.update(dt)
  wingmen.update(dt, gameState.player.x, gameState.player.y)
  boss.update(dt, gameState.player.x, gameState.player.y)
  bolse.update(dt, gameState.player.x, gameState.player.y)
  rival.update(dt, gameState.player.x, gameState.player.y, weapons.lasers)
  rival.updateLasers(dt)
  maze.update(dt)
  venomboss.update(dt, gameState.player.x, gameState.player.y)
  sectorzboss.update(dt, gameState.player.x, gameState.player.y)
  wardenboss.update(dt, gameState.player.x, gameState.player.y)
  sentinelboss.update(dt, gameState.player.x, gameState.player.y)
  megalith.update(dt, gameState.player.x, gameState.player.y)
  dynamoboss.update(dt, gameState.player.x, gameState.player.y)
  synesthesia.update(dt, gameState.player.x, gameState.player.y)
  raid.update(dt, gameState.player.x, gameState.player.y)
  raidboss.update(dt, gameState.player.x, gameState.player.y)
  sphereboss.update(dt, gameState.player.x, gameState.player.y)
  machineboss.update(dt, gameState.player.x, gameState.player.y)

  -- Update Prototype encounter
  if gameState.prototypeWillAppear and not prototype.isActive() then
    gameState.prototypeAppearTimer = gameState.prototypeAppearTimer - dt
    if gameState.prototypeAppearTimer <= 0 then
      gameState.prototypeWillAppear = false
      prototype.startEncounter()
      -- Move the Prototype on the map (it's now engaged, will flee after)
    end
  end

  if prototype.isActive() then
    prototype.update(dt, gameState.player.x, gameState.player.y, gameState.player.stunned)
    -- Handle Prototype projectiles
    local protoProjectiles = prototype.getPendingProjectiles(gameState.player.x, gameState.player.y)
    for _, proj in ipairs(protoProjectiles) do
      if proj.type == "emp" then
        table.insert(weapons.lasers, {
          x = proj.x, y = proj.y,
          vx = proj.vx, vy = proj.vy,
          damage = proj.damage,
          width = proj.width, height = proj.height,
          owner = "prototype_emp",
          stunDuration = proj.stunDuration,
          reflectable = true,
        })
      elseif proj.type == "laser" then
        table.insert(weapons.lasers, {
          x = proj.x, y = proj.y,
          vx = proj.vx, vy = proj.vy,
          damage = proj.damage,
          width = proj.width, height = proj.height,
          owner = "prototype",
          reflectable = true,
        })
      end
    end
    -- Check if player can pick up defeated Prototype
    if prototype.shipPickupReady then
      if prototype.checkPickup(gameState.player.x, gameState.player.y, gameState.player.width, gameState.player.height) then
        gameState.state = "prototype_acquired"
        gameState.prototypeAcquireTimer = 0
      end
    end
  end

  supershot.update(dt)

  M.spawnWaves()
  if not abilities.shouldSuppressShooting() then
    M.handleEnemyShooting()
  end
  M.checkCollisions()
  M.checkSpartanLaserCollisions()
  M.checkPortals()

  if not player.isAlive(gameState.player) then
    -- Spawn death explosion at player position
    particles.spawn(gameState.player.x, gameState.player.y, 30, {1, 0.6, 0.1})
    particles.spawn(gameState.player.x, gameState.player.y, 20, {1, 0.2, 0})
    particles.spawn(gameState.player.x, gameState.player.y, 10, {1, 1, 0.5})
    gameState.state = "gameover"
    prototype.onPlayerDefeated()
  elseif gameState.player.justDied then
    gameState.player.justDied = false
    -- Died during boss fight (lives remaining) - check if any boss is active
    local bossIsActive = (boss.currentBoss ~= nil and boss.currentBoss.active)
      or mothership.isActive()
      or bolse.isActive()
      or rival.isActive()
      or venomboss.isActive()
      or sectorzboss.isActive()
      or wardenboss.isActive()
      or sentinelboss.isActive()
      or megalith.isActive()
      or dynamoboss.isActive()
      or synesthesia.isActive()
      or raidboss.isActive()
      or sphereboss.isActive()
      or machineboss.isActive()
    if bossIsActive then
      -- Spawn explosion particles at player position
      particles.spawn(gameState.player.x, gameState.player.y, 30, {1, 0.6, 0.1})
      particles.spawn(gameState.player.x, gameState.player.y, 20, {1, 0.2, 0})
      particles.spawn(gameState.player.x, gameState.player.y, 10, {1, 1, 0.5})
      -- Store death position and hide player off-screen during death
      gameState.deathX = gameState.player.x
      gameState.deathY = gameState.player.y
      gameState.player.x = -200
      gameState.player.y = -200
      gameState.player.invulnerable = true
      gameState.state = "playerdeath"
      gameState.deathRespawnTimer = 3.0
    end
  end

  -- Catch venomboss laser-reflect self-kill (bypasses checkCollisions)
  if venomboss.boss and not venomboss.boss.active and venomboss.boss.health <= 0
     and not bossexplosion.isActive() and not gameState.bossDefeated then
    bossexplosion.start(venomboss.boss.x, venomboss.boss.y, venomboss.boss.width, venomboss.boss.height)
    gameState.bossDefeated = true
  end

  -- Wait for boss explosion to finish before checking victory
  if bossexplosion.isActive() then
    return
  end

  -- Victory conditions
  -- Only count finalboss and area6boss as victory, not midboss (unless midboss is the only boss)
  local finalBossDefeated = false
  local midbossOnlyDefeated = false
  if boss.currentBoss and not boss.currentBoss.active then
    if boss.currentBoss.type == "finalboss" or boss.currentBoss.type == "area6boss" then
      finalBossDefeated = true
    elseif boss.currentBoss.type == "midboss" then
      midbossOnlyDefeated = true
    end
  end

  local bossVictory = gameState.bossDefeated or finalBossDefeated or mothership.isDefeated() or venomboss.isDefeated() or sectorzboss.isDefeated() or wardenboss.isDefeated() or sentinelboss.isDefeated() or megalith.isDefeated() or dynamoboss.isDefeated() or synesthesia.isDefeated() or raidboss.isDefeated() or sphereboss.isDefeated() or machineboss.isDefeated()

  -- Auto-victory only for levels without boss enemies
  -- Don't auto-complete levels that have/had bosses, motherships, etc.
  -- EXCEPT: Allow victory after midboss on Meteo (level 2) if it's the only boss
  local hasBossEnemy = boss.currentBoss ~= nil or
                       mothership.isActive() or mothership.isDefeated() or
                       bolse.isActive() or
                       rival.isActive() or
                       venomboss.isActive() or venomboss.isDefeated() or
                       sectorzboss.isActive() or sectorzboss.isDefeated() or
                       wardenboss.isActive() or wardenboss.isDefeated() or
                       sentinelboss.isActive() or sentinelboss.isDefeated() or
                       megalith.isActive() or megalith.isDefeated() or
                       dynamoboss.isActive() or dynamoboss.isDefeated() or
                       synesthesia.isActive() or synesthesia.isDefeated() or
                       raidboss.isActive() or raidboss.isDefeated() or
                       sphereboss.isActive() or sphereboss.isDefeated() or
                       machineboss.isActive() or machineboss.isDefeated()

  local allWavesSpawned = gameState.waveIndex > #gameState.levelWaves
  local noEnemiesRemain = #enemies.enemies == 0 and
                          #turrets.turrets == 0 and
                          #capitalship.ships == 0 and
                          not boss.isActive() and
                          not bolse.isActive() and
                          not rival.isActive() and
                          not mothership.isActive() and
                          not venomboss.isActive() and
                          not sectorzboss.isActive() and
                          not wardenboss.isActive() and
                          not sentinelboss.isActive() and
                          not megalith.isActive() and
                          not dynamoboss.isActive() and
                          not synesthesia.isBossActive() and
                          not raidboss.isActive() and
                          not sphereboss.isActive() and
                          not machineboss.isActive()

  -- Only allow auto-victory if no boss enemies exist/existed in this level
  -- OR if midboss was defeated on Meteo (level 2)
  local autoVictory = allWavesSpawned and noEnemiesRemain and (not hasBossEnemy or (midbossOnlyDefeated and gameState.levelId == 2))

  if bossVictory or autoVictory then
    gameState.notesEarned = math.floor(gameState.player.enemiesDefeated / 10)
    ui.resetVictory()
    gameState.state = "victory"

    -- If Prototype is still active during victory, make it warp out
    if prototype.isActive() and not prototype.defeated then
      prototype.flee()  -- Triggers warp-out, stays on map
    end

    -- Award progression items for boss levels
    if gameState.levelId == 19 and M.onMegaAntennaAwarded then
      M.onMegaAntennaAwarded()
      levelselect.hasMegaAntenna = true
    elseif gameState.levelId == 20 and M.onPowerAmplifierAwarded then
      M.onPowerAmplifierAwarded()
      levelselect.hasPowerAmplifier = true
    end

    -- Track first level beaten for Prototype quest
    if gameState.levelId == 1 and prototype.questStarted and not prototype.firstLevelBeaten then
      prototype.firstLevelBeaten = true
      prototype.trySpawnOnMap()
    elseif prototype.questStarted and not prototype.questComplete then
      -- After any level victory, move Prototype on map and try to spawn
      prototype.moveOnMap()
      prototype.trySpawnOnMap()
    end
  end
end

function M.spawnWaves()
  local levelTime = terrain.getLevelTime()
  local levelWaves = gameState.levelWaves

  while gameState.waveIndex <= #levelWaves do
    local wave = levelWaves[gameState.waveIndex]

    if levelTime >= wave.time then
      if wave.type == "wave" then
        local actualCount = enemies.spawnFormation(wave.formation, wave.x, -50, wave.count)
        gameState.totalEnemiesSpawned = gameState.totalEnemiesSpawned + actualCount
      elseif wave.type == "turret" then
        turrets.spawn(wave.x, terrain.getScrollOffset() + 100)
        gameState.totalEnemiesSpawned = gameState.totalEnemiesSpawned + 1
      elseif wave.type == "capitalship" then
        capitalship.spawn(wave.x)
        gameState.totalEnemiesSpawned = gameState.totalEnemiesSpawned + 1
      elseif wave.type == "mothership" then
        mothership.spawn(wave.x)
        gameState.totalEnemiesSpawned = gameState.totalEnemiesSpawned + 1
      elseif wave.type == "allies" then
        allies.spawnSquadron(gameState.player.x, gameState.player.y)
      elseif wave.type == "midboss" then
        boss.spawnMidBoss()
        gameState.totalEnemiesSpawned = gameState.totalEnemiesSpawned + 1
        wingmen.triggerBossWarning()
      elseif wave.type == "finalboss" then
        boss.spawnFinalBoss()
        gameState.totalEnemiesSpawned = gameState.totalEnemiesSpawned + 1
        wingmen.triggerBossWarning()
      elseif wave.type == "area6boss" then
        boss.spawnArea6Boss()
        gameState.totalEnemiesSpawned = gameState.totalEnemiesSpawned + 1
        wingmen.triggerBossWarning()
      elseif wave.type == "callout" then
        wingmen[wave.message]()
      elseif wave.type == "portal" then
        portals.spawn(wave.x)
      elseif wave.type == "bolsestation" then
        bolse.spawn(wave.x or screen.WIDTH / 2)
        gameState.totalEnemiesSpawned = gameState.totalEnemiesSpawned + 7
      elseif wave.type == "rival" then
        -- On Sector Z, skip if rival was already spawned this run
        if gameState.levelId ~= 12 or not gameState.sectorZRivalSpawned then
          local noRespawn = gameState.levelId == 12
          rival.spawn(screen.WIDTH / 2, -50, wave.hp, wave.variant, noRespawn)
          gameState.totalEnemiesSpawned = gameState.totalEnemiesSpawned + 1
          gameState.sectorZRivalSpawned = true
        end
      elseif wave.type == "mazestart" then
        maze.activate()
      elseif wave.type == "mazewall" then
        maze.spawnWallRow(wave.pattern)
      elseif wave.type == "mazeend" then
        maze.deactivate()
      elseif wave.type == "venomboss" then
        venomboss.spawn()
        gameState.totalEnemiesSpawned = gameState.totalEnemiesSpawned + 1
        wingmen.triggerBossWarning()
      elseif wave.type == "wardenboss" then
        -- Warden boss (Inner Ring guardian) - 5-phase Elden Ring style
        wardenboss.spawn()
        gameState.totalEnemiesSpawned = gameState.totalEnemiesSpawned + 1
        wingmen.triggerBossWarning()
      elseif wave.type == "sentinelboss" then
        -- Sentinel boss (Middle Ring guardian) - 5-phase Elden Ring style
        sentinelboss.spawn()
        gameState.totalEnemiesSpawned = gameState.totalEnemiesSpawned + 1
        wingmen.triggerBossWarning()
      elseif wave.type == "sectorzboss" then
        -- Sector Z boss: 7-phase Elden Ring-inspired boss
        sectorzboss.spawn()
        gameState.totalEnemiesSpawned = gameState.totalEnemiesSpawned + 1
        wingmen.triggerBossWarning()
      elseif wave.type == "megalithboss" then
        -- Megalith of Memories: 10-phase endgame raid boss
        megalith.spawn()
        gameState.totalEnemiesSpawned = gameState.totalEnemiesSpawned + 1
        wingmen.triggerBossWarning()
      elseif wave.type == "dynamoboss" then
        -- Distant Dynamo: 8-phase Power Supply Overlord
        dynamoboss.spawn()
        gameState.totalEnemiesSpawned = gameState.totalEnemiesSpawned + 1
        wingmen.triggerBossWarning()
      elseif wave.type == "synesthesia_start" then
        -- Synesthesia Installation: activate raid terrain/visualization
        synesthesia.spawn()
      elseif wave.type == "synesthesiaboss" then
        -- Synesthesia Installation: GPU Core Architect - 10-phase boss
        synesthesia.spawnBoss()
        gameState.totalEnemiesSpawned = gameState.totalEnemiesSpawned + 1
        wingmen.triggerBossWarning()
      elseif wave.type == "raid_start" then
        -- Logician's Lament: activate PCB raid terrain
        raid.activate()
      elseif wave.type == "raidboss" then
        -- Logician's Lament: The Logician CPU Die boss - 10-phase
        raidboss.spawn()
        gameState.totalEnemiesSpawned = gameState.totalEnemiesSpawned + 1
        wingmen.triggerBossWarning()
      elseif wave.type == "sphereboss" then
        -- The Sphere: 4-phase final boss with Death Star core run
        sphereboss.spawn()
        gameState.totalEnemiesSpawned = gameState.totalEnemiesSpawned + 1
        wingmen.triggerBossWarning()
      elseif wave.type == "machineboss" then
        -- The Machine: 21-phase ultimate final boss raid
        machineboss.spawn()
        gameState.totalEnemiesSpawned = gameState.totalEnemiesSpawned + 1
        wingmen.triggerBossWarning()
      end

      gameState.waveIndex = gameState.waveIndex + 1
    else
      break
    end
  end
end

function M.handleEnemyShooting()
  for _, enemy in ipairs(enemies.enemies) do
    if enemy.shootTimer <= 0 then
      enemy.shootTimer = math.random() * 2 + 1
      -- Only shoot if enemy is above the player (not passed)
      if math.random() < 0.3 and enemy.y < gameState.player.y then
        weapons.fireEnemyLaser(enemy.x, enemy.y, gameState.player.x, gameState.player.y)
      end
    end
  end

  for _, turret in ipairs(turrets.turrets) do
    if turret.shouldShoot then
      weapons.fireEnemyLaser(turret.x, turret.y, gameState.player.x, gameState.player.y)
    end
  end

  for _, ship in ipairs(capitalship.ships) do
    if ship.shouldShoot then
      weapons.fireEnemyLaser(ship.x, ship.y + 40, gameState.player.x, gameState.player.y)
      weapons.fireEnemyLaser(ship.x - 60, ship.y + 40, gameState.player.x - 50, gameState.player.y)
      weapons.fireEnemyLaser(ship.x + 60, ship.y + 40, gameState.player.x + 50, gameState.player.y)
    end
  end

  if boss.currentBoss and boss.currentBoss.shouldAttack then
    local b = boss.currentBoss
    weapons.fireEnemyLaser(b.x, b.y + 30, gameState.player.x, gameState.player.y)

    if b.type == "finalboss" and b.phase >= 2 then
      weapons.fireEnemyLaser(b.x - 30, b.y + 30, gameState.player.x, gameState.player.y)
      weapons.fireEnemyLaser(b.x + 30, b.y + 30, gameState.player.x, gameState.player.y)
    end

    if b.type == "area6boss" then
      if b.phase == 1 then
        weapons.fireEnemyLaser(b.x - 50, b.y + 40, gameState.player.x, gameState.player.y)
        weapons.fireEnemyLaser(b.x + 50, b.y + 40, gameState.player.x, gameState.player.y)
      elseif b.phase >= 2 and b.spreadAttack then
        weapons.fireEnemyLaser(b.x - 40, b.y + 50, b.x - 100, 700)
        weapons.fireEnemyLaser(b.x + 40, b.y + 50, b.x + 100, 700)
        weapons.fireEnemyLaser(b.x, b.y + 50, b.x - 50, 700)
        weapons.fireEnemyLaser(b.x, b.y + 50, b.x + 50, 700)
      end
    end
  end

  if boss.currentBoss and boss.currentBoss.shouldSpawnFighters then
    enemies.spawn(boss.currentBoss.x - 80, boss.currentBoss.y + 50, "fighter")
    enemies.spawn(boss.currentBoss.x + 80, boss.currentBoss.y + 50, "fighter")
    gameState.totalEnemiesSpawned = gameState.totalEnemiesSpawned + 2
  end

  -- Mothership spawning and shooting
  if mothership.isActive() then
    local m = mothership.mothership
    if m.shouldSpawnFighters then
      local positions = mothership.getSpawnPositions()
      for _, pos in ipairs(positions) do
        enemies.spawn(pos.x, pos.y, "fighter")
      end
      gameState.totalEnemiesSpawned = gameState.totalEnemiesSpawned + #positions
    end
    if m.shouldShoot then
      local positions = mothership.getShootPositions()
      for _, pos in ipairs(positions) do
        weapons.fireEnemyLaser(pos.x, pos.y, gameState.player.x, gameState.player.y)
      end
    end
  end

  -- Ally shooting
  for _, ally in ipairs(allies.allies) do
    if ally.shouldShoot and ally.targetX then
      if ally.converted then
        weapons.fireConvertedAllyLaser(ally.x, ally.y - 10, ally.targetX, ally.targetY)
      else
        weapons.fireAllyLaser(ally.x, ally.y - 10, ally.targetX, ally.targetY)
      end
    end
  end

  -- Bolse turrets shooting
  if bolse.isActive() then
    for _, turret in ipairs(bolse.getTurrets()) do
      if turret.shouldShoot and not turret.destroyed then
        weapons.fireEnemyLaser(turret.worldX, turret.worldY, gameState.player.x, gameState.player.y)
      end
    end
  end

  -- Venom boss shooting
  if venomboss.isActive() and venomboss.boss.shouldAttack then
    local vb = venomboss.boss
    weapons.fireEnemyLaser(vb.x, vb.y + 40, gameState.player.x, gameState.player.y)
    weapons.fireEnemyLaser(vb.x - 40, vb.y + 40, gameState.player.x - 50, gameState.player.y)
    weapons.fireEnemyLaser(vb.x + 40, vb.y + 40, gameState.player.x + 50, gameState.player.y)
  end

  -- Sector Z boss shooting
  if sectorzboss.isActive() then
    local projectiles = sectorzboss.getPendingProjectiles()
    for _, proj in ipairs(projectiles) do
      if proj.type == "blade" or proj.type == "spread" or proj.type == "sweep" then
        local vx = math.cos(proj.angle) * proj.speed
        local vy = math.sin(proj.angle) * proj.speed
        table.insert(weapons.lasers, {
          x = proj.x,
          y = proj.y,
          vx = vx,
          vy = vy,
          damage = proj.damage,
          width = 8,
          height = 8,
          owner = "enemy"
        })
      elseif proj.type == "waterfowl" then
        weapons.fireEnemyLaser(proj.x, proj.y, proj.targetX, proj.targetY)
      elseif proj.type == "deathBlight" then
        -- Death Blight: large fast projectile
        local dx = proj.targetX - proj.x
        local dy = proj.targetY - proj.y
        local dist = math.sqrt(dx*dx + dy*dy)
        if dist > 0 then
          dx = dx / dist
          dy = dy / dist
        else
          dy = 1
        end
        table.insert(weapons.lasers, {
          x = proj.x,
          y = proj.y,
          vx = dx * proj.speed,
          vy = dy * proj.speed,
          damage = proj.damage,
          width = proj.width,
          height = proj.width,
          owner = "enemy"
        })
      end
    end
  end

  -- Warden boss shooting
  if wardenboss.isActive() then
    local projectiles = wardenboss.getPendingProjectiles()
    for _, proj in ipairs(projectiles) do
      if proj.type == "slash" or proj.type == "spread" or proj.type == "sweep" or proj.type == "lightning" then
        local vx = math.cos(proj.angle) * proj.speed
        local vy = math.sin(proj.angle) * proj.speed
        table.insert(weapons.lasers, {
          x = proj.x,
          y = proj.y,
          vx = vx,
          vy = vy,
          damage = proj.damage,
          width = 8,
          height = 8,
          owner = "enemy"
        })
      elseif proj.type == "sentinelLance" then
        weapons.fireEnemyLaser(proj.x, proj.y, proj.targetX, proj.targetY)
      end
    end
  end

  -- Sentinel boss shooting
  if sentinelboss.isActive() then
    local projectiles = sentinelboss.getPendingProjectiles()
    for _, proj in ipairs(projectiles) do
      if proj.type == "scanBeam" or proj.type == "spread" or proj.type == "sweep" or proj.type == "singularityBurst" then
        local vx = math.cos(proj.angle) * proj.speed
        local vy = math.sin(proj.angle) * proj.speed
        table.insert(weapons.lasers, {
          x = proj.x,
          y = proj.y,
          vx = vx,
          vy = vy,
          damage = proj.damage,
          width = 8,
          height = 8,
          owner = "enemy"
        })
      elseif proj.type == "lockOnMissile" or proj.type == "droneStrike" then
        weapons.fireEnemyLaser(proj.x, proj.y, proj.targetX, proj.targetY)
      end
    end
  end

  -- Distant Dynamo boss shooting
  if dynamoboss.isActive() then
    local projectiles = dynamoboss.getPendingProjectiles()
    for _, proj in ipairs(projectiles) do
      if proj.type == "aimed" or proj.type == "spread" or proj.type == "surgeStrike" then
        local vx = math.cos(proj.angle) * proj.speed
        local vy = math.sin(proj.angle) * proj.speed
        table.insert(weapons.lasers, {
          x = proj.x,
          y = proj.y,
          vx = vx,
          vy = vy,
          damage = proj.damage,
          width = 8,
          height = 8,
          owner = "enemy"
        })
      elseif proj.type == "cableWhip" then
        -- Cable whip: wide horizontal sweep
        for sx = 0, screen.WIDTH, 35 do
          if math.abs(sx - proj.safeX) > (proj.safeWidth or 60) / 2 then
            table.insert(weapons.lasers, {
              x = sx, y = proj.y,
              vx = 0, vy = proj.speed,
              damage = proj.damage, width = 30, height = 10,
              owner = "enemy"
            })
          end
        end
      end
    end
  end

  -- Megalith of Memories boss shooting
  if megalith.isActive() then
    local projectiles = megalith.getPendingProjectiles()
    for _, proj in ipairs(projectiles) do
      if proj.type == "aimed" or proj.type == "spread" or proj.type == "sectorSweep"
         or proj.type == "spindleBurst" or proj.type == "sweep" then
        local vx = math.cos(proj.angle) * proj.speed
        local vy = math.sin(proj.angle) * proj.speed
        table.insert(weapons.lasers, {
          x = proj.x,
          y = proj.y,
          vx = vx,
          vy = vy,
          damage = proj.damage,
          width = 8,
          height = 8,
          owner = "enemy"
        })
      elseif proj.type == "ramBolt" then
        -- Electrical bolt between RAM sticks (horizontal beam)
        local dx = proj.x2 - proj.x1
        local dy = proj.y2 - proj.y1
        local dist = math.sqrt(dx * dx + dy * dy)
        if dist > 0 then
          local angle = math.atan2(dy, dx)
          table.insert(weapons.lasers, {
            x = proj.x1, y = proj.y1,
            vx = math.cos(angle) * 200, vy = math.sin(angle) * 200,
            damage = proj.damage, width = proj.width, height = proj.width,
            owner = "enemy"
          })
        end
      elseif proj.type == "overclockSlam" then
        -- Full-width shockwave with one safe gap
        for sx = 0, screen.WIDTH, 40 do
          if math.abs(sx - proj.safeX) > proj.safeWidth / 2 then
            table.insert(weapons.lasers, {
              x = sx, y = proj.y,
              vx = 0, vy = proj.speed,
              damage = proj.damage, width = 35, height = 10,
              owner = "enemy"
            })
          end
        end
      elseif proj.type == "defragBeam" then
        local dx = proj.targetX - proj.x
        local dy = proj.targetY - proj.y
        local dist = math.sqrt(dx * dx + dy * dy)
        if dist > 0 then
          dx = dx / dist
          dy = dy / dist
        else
          dy = 1
        end
        table.insert(weapons.lasers, {
          x = proj.x, y = proj.y,
          vx = dx * proj.speed, vy = dy * proj.speed,
          damage = proj.damage, width = proj.width, height = proj.width,
          owner = "enemy"
        })
      elseif proj.type == "headCrashShockwave" then
        -- Expanding ring of projectiles
        for i = 0, 11 do
          local angle = (i / 12) * math.pi * 2
          table.insert(weapons.lasers, {
            x = proj.x, y = proj.y,
            vx = math.cos(angle) * 300, vy = math.sin(angle) * 300,
            damage = proj.damage, width = 10, height = 10,
            owner = "enemy"
          })
        end
      elseif proj.type == "thermalEvent" then
        -- Screen-wide blast except safe zone - spawn many projectiles
        for sx = 50, screen.WIDTH - 50, 60 do
          for sy = 100, screen.HEIGHT - 50, 60 do
            local dxSafe = sx - proj.safeX
            local dySafe = sy - proj.safeY
            if math.sqrt(dxSafe * dxSafe + dySafe * dySafe) > proj.safeRadius then
              table.insert(weapons.lasers, {
                x = sx, y = sy,
                vx = (math.random() - 0.5) * 50, vy = 150 + math.random() * 100,
                damage = proj.damage, width = 20, height = 20,
                owner = "enemy"
              })
            end
          end
        end
      end
    end
  end

  -- Synesthesia Installation boss shooting
  if synesthesia.isBossActive() then
    local projectiles = synesthesia.getPendingProjectiles()
    for _, proj in ipairs(projectiles) do
      if proj.type == "shaderFragment" or proj.type == "pipelineLance" or proj.type == "spread"
         or proj.type == "sweep" or proj.type == "rasterSweep" or proj.type == "bufferFlood" then
        local vx = math.cos(proj.angle) * proj.speed
        local vy = math.sin(proj.angle) * proj.speed
        table.insert(weapons.lasers, {
          x = proj.x,
          y = proj.y,
          vx = vx,
          vy = vy,
          damage = proj.damage,
          width = 8,
          height = 8,
          owner = "enemy"
        })
      elseif proj.type == "kernelPanic" then
        -- Expanding ring of projectiles from target point
        for i = 0, 15 do
          local angle = (i / 16) * math.pi * 2
          table.insert(weapons.lasers, {
            x = proj.x, y = proj.y,
            vx = math.cos(angle) * 350, vy = math.sin(angle) * 350,
            damage = proj.damage, width = 12, height = 12,
            owner = "enemy"
          })
        end
      end
    end
  end

  -- Logician's Lament raid boss shooting
  if raidboss.isActive() then
    local projectiles = raidboss.getPendingProjectiles()
    for _, proj in ipairs(projectiles) do
      if proj.type == "disc" then
        -- Identity disc: handled as area damage by raidboss itself
      elseif proj.type == "threadLance" or proj.type == "spread" or proj.type == "sweep"
         or proj.type == "dart" or proj.type == "pipelineBurst" then
        local vx = math.cos(proj.angle) * proj.speed
        local vy = math.sin(proj.angle) * proj.speed
        table.insert(weapons.lasers, {
          x = proj.x,
          y = proj.y,
          vx = vx,
          vy = vy,
          damage = proj.damage,
          width = 8,
          height = 8,
          owner = "enemy"
        })
      end
    end
  end

  -- Sphere boss shooting
  if sphereboss.isActive() then
    local projectiles = sphereboss.getPendingProjectiles()
    for _, proj in ipairs(projectiles) do
      if proj.type == "shellVolley" or proj.type == "spread" or proj.type == "sweep"
         or proj.type == "plasmaLance" or proj.type == "mirrorLaser" or proj.type == "mirrorBomb" then
        local vx = math.cos(proj.angle) * proj.speed
        local vy = math.sin(proj.angle) * proj.speed
        table.insert(weapons.lasers, {
          x = proj.x,
          y = proj.y,
          vx = vx,
          vy = vy,
          damage = proj.damage,
          width = 8,
          height = 8,
          owner = "enemy"
        })
      elseif proj.type == "droneSting" then
        weapons.fireEnemyLaser(proj.x, proj.y, proj.targetX, proj.targetY)
      end
    end
  end

  -- The Machine boss shooting
  if machineboss.isActive() then
    local projectiles = machineboss.getPendingProjectiles()
    for _, proj in ipairs(projectiles) do
      if proj.type == "annihilationPulse" then
        -- Screen-wide blast: damage everything except safe zone
        -- Handled in special mechanics section (player collision)
      elseif proj.type == "grindBlade" or proj.type == "pistonStrike" or proj.type == "spread"
         or proj.type == "sweep" or proj.type == "overclockBurst" or proj.type == "chainSaw"
         or proj.type == "drillLance" or proj.type == "hydraulicRam" or proj.type == "arcWelder"
         or proj.type == "pressureBlow" or proj.type == "nanoSwarm" or proj.type == "coreBeam"
         or proj.type == "dimensionRift" or proj.type == "addShot" then
        local vx = math.cos(proj.angle) * proj.speed
        local vy = math.sin(proj.angle) * proj.speed
        table.insert(weapons.lasers, {
          x = proj.x,
          y = proj.y,
          vx = vx,
          vy = vy,
          damage = proj.damage,
          width = proj.width or 8,
          height = proj.width or 8,
          owner = "enemy"
        })
      end
    end

    -- Annihilation Pulse: instant damage check (screen-wide)
    local mb = machineboss.boss
    if mb and mb.annihilationCharging == false and mb.currentAttack == "annihilationPulse" then
      local p = gameState.player
      local dx = p.x - mb.annihilationSafeX
      local dy = p.y - mb.annihilationSafeY
      local dist = math.sqrt(dx * dx + dy * dy)
      if dist > mb.annihilationSafeRadius then
        if not p.invulnerable and not p.barrelRolling then
          player.takeDamage(p, DAMAGE and 40 or 40)
          particles.spawn(p.x, p.y, 20, {1, 0.2, 0.8})
        end
      end
      mb.currentAttack = nil
    end
  end
end

function M.checkSpartanLaserCollisions()
  if not weapons.spartanLaserBeam or not weapons.spartanLaserBeam.active then
    return
  end
  
  local beam = weapons.spartanLaserBeam
  local damage = weapons.getSpartanLaserDamage(beam.fireTime)
  local damagePerFrame = damage * love.timer.getDelta() -- Convert DPS to per-frame damage
  local hitBoss = false
  
  -- Check enemies (beam passes through)
  for j = #enemies.enemies, 1, -1 do
    local enemy = enemies.enemies[j]
    -- Check if enemy is in beam path (vertical line from player upward)
    if math.abs(enemy.x - beam.x) < (beam.width + enemy.width) / 2 and enemy.y < beam.y then
      if enemies.damage(enemy, damagePerFrame) then
        registerKill(gameState.player, enemy.score)
        particles.spawn(enemy.x, enemy.y, 15, {1, 0.5, 0})
        enemies.remove(enemy)
      end
    end
  end
  
  -- Check turrets (beam passes through)
  for j = #turrets.turrets, 1, -1 do
    local turret = turrets.turrets[j]
    if turret.active then
      if math.abs(turret.x - beam.x) < (beam.width + turret.width) / 2 and turret.y < beam.y then
        if turrets.damage(turret, damagePerFrame) then
          registerKill(gameState.player, turret.score)
          particles.spawn(turret.x, turret.y, 15, {1, 0.5, 0})
          turrets.remove(turret)
        end
      end
    end
  end
  
  -- Check capital ships (beam passes through)
  for j = #capitalship.ships, 1, -1 do
    local ship = capitalship.ships[j]
    if math.abs(ship.x - beam.x) < (beam.width + ship.width) / 2 and ship.y < beam.y then
      if capitalship.damage(ship, damagePerFrame) then
        registerKill(gameState.player, ship.score)
        particles.spawn(ship.x, ship.y, 25, {1, 0.5, 0})
        capitalship.destroy(ship)
      end
    end
  end
  
  -- Check boss (beam STOPS here with increasing explosions)
  if boss.isActive() then
    local b = boss.currentBoss
    if math.abs(b.x - beam.x) < (beam.width + b.width) / 2 and b.y < beam.y then
      hitBoss = true
      -- Set beam end position to boss surface
      beam.actualEndY = b.y + b.height / 2
      
      -- Spawn fewer, smaller, more colorful explosions
      local explosionIntensity = math.floor(beam.fireTime * 2) + 3
      local impactY = beam.actualEndY
      local colors = {{1, 0.7, 0}, {1, 0.5, 0.2}, {1, 0.9, 0.3}, {1, 0.3, 0}}
      for j = 1, math.min(math.floor(beam.fireTime * 2) + 1, 3) do
        local offsetX = (math.random() - 0.5) * beam.width
        local color = colors[math.random(1, #colors)]
        particles.spawn(beam.x + offsetX, impactY + math.random(-2, 2), explosionIntensity, color)
      end
      
      local hitArm = nil
      if b.type == "finalboss" and b.phase == 1 then
        if beam.x < b.x and not b.leftArm.destroyed then
          hitArm = "left"
        elseif beam.x >= b.x and not b.rightArm.destroyed then
          hitArm = "right"
        end
      elseif b.type == "area6boss" and b.phase == 1 then
        if beam.x < b.x and not b.leftShield.destroyed then
          hitArm = "left"
        elseif beam.x >= b.x and not b.rightShield.destroyed then
          hitArm = "right"
        end
      end
      
      if boss.damage(damagePerFrame, hitArm) then
        registerKill(gameState.player, b.score)
        particles.spawn(b.x, b.y, 30, {1, 0.5, 0})
        if b.type == "finalboss" or b.type == "area6boss" then
          bossexplosion.start(b.x, b.y, b.width, b.height)
          gameState.bossDefeated = true
          weapons.stopSpartanLaser(gameState.player)
        end
      end
    end
  end
  
  -- Check mothership (beam STOPS here with increasing explosions)
  if not hitBoss and mothership.isActive() then
    local m = mothership.mothership
    if math.abs(m.x - beam.x) < (beam.width + m.width) / 2 and m.y < beam.y then
      hitBoss = true
      -- Set beam end position to mothership surface
      beam.actualEndY = m.y + m.height / 2
      
      -- Spawn fewer, smaller, more colorful explosions
      local explosionIntensity = math.floor(beam.fireTime * 2) + 3
      local impactY = beam.actualEndY
      local colors = {{1, 0.7, 0}, {1, 0.5, 0.2}, {1, 0.9, 0.3}, {0.9, 0.3, 0}}
      for j = 1, math.min(math.floor(beam.fireTime * 2) + 1, 4) do
        local offsetX = (math.random() - 0.5) * beam.width
        local color = colors[math.random(1, #colors)]
        particles.spawn(beam.x + offsetX, impactY + math.random(-4, 4), explosionIntensity, color)
      end
      
      local result = mothership.damage(damagePerFrame)
      if result.dead then
        registerKill(gameState.player, m.score)
        particles.spawn(m.x, m.y, 40, {1, 0.5, 0})
        bossexplosion.start(m.x, m.y, m.width, m.height)
        turrets.reset()
        enemies.reset()
        weapons.stopSpartanLaser(gameState.player)
      elseif result.hullDestroyed then
        particles.spawn(m.x, m.y, 20, {1, 0.3, 0})
      end
    end
  end
  
  -- Check Bolse station (beam STOPS here with increasing explosions)
  if not hitBoss and bolse.isActive() then
    local s = bolse.getStation()
    
    -- Check turrets (beam passes through turrets)
    for _, turret in ipairs(s.turrets) do
      if not turret.destroyed then
        if math.abs(turret.worldX - beam.x) < (beam.width + 15) and turret.worldY < beam.y then
          if bolse.damageTurret(turret, damagePerFrame) then
            registerKill(gameState.player, 100)
            particles.spawn(turret.worldX, turret.worldY, 12, {1, 0.5, 0})
            if s.phase == 1 then
              local destroyedCount = 0
              for _, t in ipairs(s.turrets) do
                if t.destroyed then destroyedCount = destroyedCount + 1 end
              end
              if destroyedCount >= 4 then
                wingmen.triggerCoreExposed()
              end
            end
          end
        end
      end
    end
    
    -- Check core (only when exposed) - beam STOPS here
    if s.coreExposed then
      if math.abs(s.x - beam.x) < (beam.width + 40) and s.y < beam.y then
        hitBoss = true
        -- Set beam end position to core surface
        beam.actualEndY = s.y + 40
        
        -- Spawn fewer, smaller, more colorful explosions
        local explosionIntensity = math.floor(beam.fireTime * 2) + 3
        local impactY = beam.actualEndY
        local colors = {{0.3, 0.8, 1}, {0.5, 0.9, 1}, {0.7, 1, 1}, {0.2, 0.6, 0.9}}
        for j = 1, math.min(math.floor(beam.fireTime * 2) + 1, 4) do
          local offsetX = (math.random() - 0.5) * beam.width
          local color = colors[math.random(1, #colors)]
          particles.spawn(beam.x + offsetX, impactY + math.random(-5, 5), explosionIntensity, color)
        end
        
        if bolse.damageCore(damagePerFrame) then
          registerKill(gameState.player, s.score)
          particles.spawn(s.x, s.y, 40, {1, 0.5, 0})
          bossexplosion.start(s.x, s.y, 250, 250)
          gameState.bossDefeated = true
          rival.retreat()
          weapons.stopSpartanLaser(gameState.player)
        end
      end
    end
  end
  
  -- Check rival (beam STOPS here with increasing explosions)
  if not hitBoss and rival.isActive() then
    local r = rival.getRival()
    if r and not r.reflecting then
      if math.abs(r.x - beam.x) < (beam.width + r.width) / 2 and r.y < beam.y then
        hitBoss = true
        -- Set beam end position to rival surface
        beam.actualEndY = r.y + r.height / 2
        
        -- Spawn fewer, smaller, more colorful explosions
        local explosionIntensity = math.floor(beam.fireTime * 2) + 3
        local impactY = beam.actualEndY
        local colors = {{0.9, 0.4, 1}, {0.8, 0.2, 1}, {1, 0.5, 1}, {0.7, 0.3, 0.9}}
        for j = 1, math.min(math.floor(beam.fireTime * 2) + 1, 3) do
          local offsetX = (math.random() - 0.5) * beam.width
          local color = colors[math.random(1, #colors)]
          particles.spawn(beam.x + offsetX, impactY + math.random(-3, 3), explosionIntensity, color)
        end
        
        if rival.damage(damagePerFrame) then
          registerKill(gameState.player, r.score)
          particles.spawn(r.x, r.y, 20, {1, 0.3, 0})
          if gameState.levelId ~= 12 then gameState.bossDefeated = true end
          weapons.stopSpartanLaser(gameState.player)
        else
          abilities.registerBossDamage(damagePerFrame, gameState.levelId)
        end
      end
    end
  end

  -- Check Venom boss (beam STOPS here with increasing explosions)
  if not hitBoss and venomboss.isActive() then
    local vb = venomboss.boss
    if math.abs(vb.x - beam.x) < (beam.width + vb.width) / 2 and vb.y < beam.y then
      hitBoss = true
      -- Set beam end position to Venom boss surface
      beam.actualEndY = vb.y + vb.height / 2

      -- Spawn fewer, smaller, more colorful explosions
      local explosionIntensity = math.floor(beam.fireTime * 2.5) + 4
      local impactY = beam.actualEndY
      local colors = {{1, 0.3, 0}, {1, 0.5, 0.1}, {1, 0.7, 0.2}, {0.9, 0.2, 0.1}}
      for j = 1, math.min(math.floor(beam.fireTime * 2) + 1, 4) do
        local offsetX = (math.random() - 0.5) * beam.width
        local color = colors[math.random(1, #colors)]
        particles.spawn(beam.x + offsetX, impactY + math.random(-6, 6), explosionIntensity, color)
      end

      if venomboss.damage(damagePerFrame) then
        registerKill(gameState.player, vb.score)
        particles.spawn(vb.x, vb.y, 40, {1, 0.3, 0})
        bossexplosion.start(vb.x, vb.y, vb.width, vb.height)
        gameState.bossDefeated = true
        weapons.stopSpartanLaser(gameState.player)
      else
        abilities.registerBossDamage(damagePerFrame, gameState.levelId)
      end
    end
  end

  -- Check Sector Z boss (beam STOPS here with increasing explosions)
  if not hitBoss and sectorzboss.isActive() then
    local szb = sectorzboss.boss
    if math.abs(szb.x - beam.x) < (beam.width + szb.width) / 2 and szb.y < beam.y then
      hitBoss = true
      -- Set beam end position to Sector Z boss surface
      beam.actualEndY = szb.y + szb.height / 2

      -- Spawn crimson explosions (Elden Ring aesthetic)
      local explosionIntensity = math.floor(beam.fireTime * 3) + 5
      local impactY = beam.actualEndY
      local colors = {{1, 0.1, 0.1}, {0.9, 0.2, 0.3}, {1, 0.3, 0.2}, {0.8, 0.1, 0.2}}
      for j = 1, math.min(math.floor(beam.fireTime * 2) + 1, 5) do
        local offsetX = (math.random() - 0.5) * beam.width
        local color = colors[math.random(1, #colors)]
        particles.spawn(beam.x + offsetX, impactY + math.random(-8, 8), explosionIntensity, color)
      end

      if sectorzboss.damage(damagePerFrame) then
        registerKill(gameState.player, szb.score)
        particles.spawn(szb.x, szb.y, 50, {1, 0.2, 0.2})
        bossexplosion.start(szb.x, szb.y, szb.width, szb.height)
        gameState.bossDefeated = true
        weapons.stopSpartanLaser(gameState.player)
      else
        abilities.registerBossDamage(damagePerFrame, gameState.levelId)
      end
    end
  end

  -- Check Warden boss (beam STOPS here with golden explosions)
  if not hitBoss and wardenboss.isActive() then
    local wb = wardenboss.boss
    if math.abs(wb.x - beam.x) < (beam.width + wb.width) / 2 and wb.y < beam.y then
      hitBoss = true
      beam.actualEndY = wb.y + wb.height / 2

      local explosionIntensity = math.floor(beam.fireTime * 3) + 5
      local impactY = beam.actualEndY
      local colors = {{1, 0.7, 0.1}, {0.9, 0.5, 0.1}, {1, 0.8, 0.3}, {0.8, 0.3, 0.1}}
      for j = 1, math.min(math.floor(beam.fireTime * 2) + 1, 5) do
        local offsetX = (math.random() - 0.5) * beam.width
        local color = colors[math.random(1, #colors)]
        particles.spawn(beam.x + offsetX, impactY + math.random(-8, 8), explosionIntensity, color)
      end

      local hitArm = nil
      if not wb.guardsDown then
        if beam.x < wb.x and not wb.leftGuard.destroyed then
          hitArm = "left"
        elseif beam.x >= wb.x and not wb.rightGuard.destroyed then
          hitArm = "right"
        end
      end

      if wardenboss.damage(damagePerFrame, hitArm) then
        registerKill(gameState.player, wb.score)
        particles.spawn(wb.x, wb.y, 50, {0.8, 0.4, 0.1})
        bossexplosion.start(wb.x, wb.y, wb.width, wb.height)
        gameState.bossDefeated = true
        weapons.stopSpartanLaser(gameState.player)
      else
        abilities.registerBossDamage(damagePerFrame, gameState.levelId)
      end
    end
  end

  -- Check Sentinel boss (beam STOPS here with cyan/electric explosions)
  if not hitBoss and sentinelboss.isActive() then
    local sb = sentinelboss.boss
    if math.abs(sb.x - beam.x) < (beam.width + sb.width) / 2 and sb.y < beam.y then
      hitBoss = true
      beam.actualEndY = sb.y + sb.height / 2

      local explosionIntensity = math.floor(beam.fireTime * 3) + 5
      local impactY = beam.actualEndY
      local colors = {{0.2, 0.7, 1}, {0.1, 0.5, 0.9}, {0.4, 0.8, 1}, {0.1, 0.3, 0.8}}
      for j = 1, math.min(math.floor(beam.fireTime * 2) + 1, 5) do
        local offsetX = (math.random() - 0.5) * beam.width
        local color = colors[math.random(1, #colors)]
        particles.spawn(beam.x + offsetX, impactY + math.random(-8, 8), explosionIntensity, color)
      end

      local hitArm = nil
      if not sb.guardsDown then
        if beam.x < sb.x and not sb.leftGuard.destroyed then
          hitArm = "left"
        elseif beam.x >= sb.x and not sb.rightGuard.destroyed then
          hitArm = "right"
        end
      end

      if sentinelboss.damage(damagePerFrame, hitArm) then
        registerKill(gameState.player, sb.score)
        particles.spawn(sb.x, sb.y, 50, {0.2, 0.5, 1.0})
        bossexplosion.start(sb.x, sb.y, sb.width, sb.height)
        gameState.bossDefeated = true
        weapons.stopSpartanLaser(gameState.player)
      else
        abilities.registerBossDamage(damagePerFrame, gameState.levelId)
      end
    end
  end

  -- Check Megalith boss (beam STOPS here with circuit-board explosions)
  if not hitBoss and megalith.isActive() then
    local mb = megalith.boss
    if math.abs(mb.x - beam.x) < (beam.width + mb.width) / 2 and mb.y < beam.y then
      hitBoss = true
      beam.actualEndY = mb.y + mb.height / 2

      local explosionIntensity = math.floor(beam.fireTime * 3) + 5
      local impactY = beam.actualEndY
      local colors = {{0.1, 1, 0.6}, {0.2, 0.8, 1}, {0.4, 1, 0.8}, {0, 0.6, 0.4}}
      for j = 1, math.min(math.floor(beam.fireTime * 2) + 1, 5) do
        local offsetX = (math.random() - 0.5) * beam.width
        local color = colors[math.random(1, #colors)]
        particles.spawn(beam.x + offsetX, impactY + math.random(-8, 8), explosionIntensity, color)
      end

      if megalith.damage(damagePerFrame) then
        registerKill(gameState.player, mb.score)
        particles.spawn(mb.x, mb.y, 60, {0.2, 1, 0.8})
        bossexplosion.start(mb.x, mb.y, mb.width, mb.height)
        gameState.bossDefeated = true
        weapons.stopSpartanLaser(gameState.player)
      else
        abilities.registerBossDamage(damagePerFrame, gameState.levelId)
      end
    end
  end

  -- Check Distant Dynamo boss (beam STOPS here with orange/copper explosions)
  if not hitBoss and dynamoboss.isActive() then
    local db = dynamoboss.boss
    if math.abs(db.x - beam.x) < (beam.width + db.width) / 2 and db.y < beam.y then
      hitBoss = true
      beam.actualEndY = db.y + db.height / 2

      local explosionIntensity = math.floor(beam.fireTime * 3) + 5
      local impactY = beam.actualEndY
      local colors = {{1, 0.6, 0.1}, {1, 0.45, 0.05}, {0.9, 0.35, 0.05}, {1, 0.8, 0.3}}
      for j = 1, math.min(math.floor(beam.fireTime * 2) + 1, 5) do
        local offsetX = (math.random() - 0.5) * beam.width
        local color = colors[math.random(1, #colors)]
        particles.spawn(beam.x + offsetX, impactY + math.random(-8, 8), explosionIntensity, color)
      end

      -- Check if hitting regulators
      local hitArm = nil
      if not db.regulatorsDown then
        if beam.x < db.x and not db.leftRegulator.destroyed then
          hitArm = "left"
        elseif beam.x >= db.x and not db.rightRegulator.destroyed then
          hitArm = "right"
        end
      end

      if dynamoboss.damage(damagePerFrame, hitArm) then
        registerKill(gameState.player, db.score)
        particles.spawn(db.x, db.y, 60, {1, 0.5, 0.1})
        bossexplosion.start(db.x, db.y, db.width, db.height)
        gameState.bossDefeated = true
        weapons.stopSpartanLaser(gameState.player)
      else
        abilities.registerBossDamage(damagePerFrame, gameState.levelId)
      end
    end
  end

  -- Check Synesthesia boss (beam STOPS here with chromatic explosions)
  if not hitBoss and synesthesia.isBossActive() then
    local sb = synesthesia.boss
    if math.abs(sb.x - beam.x) < (beam.width + sb.width) / 2 and sb.y < beam.y then
      hitBoss = true
      beam.actualEndY = sb.y + sb.height / 2

      local explosionIntensity = math.floor(beam.fireTime * 3) + 5
      local impactY = beam.actualEndY
      -- Chromatic rainbow explosions
      local hue = (love.timer.getTime() * 0.5) % 1.0
      local colors = {
        {0.5 + 0.5 * math.sin(hue * 6.28), 0.3, 1},
        {1, 0.5 + 0.5 * math.sin(hue * 6.28 + 2), 0.3},
        {0.3, 1, 0.5 + 0.5 * math.sin(hue * 6.28 + 4)},
        {1, 0.3, 0.5 + 0.5 * math.sin(hue * 6.28 + 1)}
      }
      for j = 1, math.min(math.floor(beam.fireTime * 2) + 1, 5) do
        local offsetX = (math.random() - 0.5) * beam.width
        local color = colors[math.random(1, #colors)]
        particles.spawn(beam.x + offsetX, impactY + math.random(-8, 8), explosionIntensity, color)
      end

      local hitArm = nil
      if not sb.shieldCoresDown then
        if beam.x < sb.x and not sb.leftShieldCore.destroyed then
          hitArm = "left"
        elseif beam.x >= sb.x and not sb.rightShieldCore.destroyed then
          hitArm = "right"
        end
      end

      if synesthesia.damage(damagePerFrame, hitArm) then
        registerKill(gameState.player, sb.score)
        particles.spawn(sb.x, sb.y, 60, {1, 0.5, 1})
        bossexplosion.start(sb.x, sb.y, sb.width, sb.height)
        gameState.bossDefeated = true
        weapons.stopSpartanLaser(gameState.player)
      else
        abilities.registerBossDamage(damagePerFrame, gameState.levelId)
      end
    end
  end

  -- Check Logician raid boss (beam STOPS here with Tron cyan explosions)
  if not hitBoss and raidboss.isActive() then
    local rb = raidboss.boss
    if math.abs(rb.x - beam.x) < (beam.width + rb.width) / 2 and rb.y < beam.y then
      hitBoss = true
      beam.actualEndY = rb.y + rb.height / 2

      local explosionIntensity = math.floor(beam.fireTime * 3) + 5
      local impactY = beam.actualEndY
      local colors = {{0, 0.9, 1}, {0, 0.7, 1}, {0.2, 1, 1}, {0.1, 0.5, 0.9}}
      for j = 1, math.min(math.floor(beam.fireTime * 2) + 1, 5) do
        local offsetX = (math.random() - 0.5) * beam.width
        local color = colors[math.random(1, #colors)]
        particles.spawn(beam.x + offsetX, impactY + math.random(-8, 8), explosionIntensity, color)
      end

      if raidboss.damage(damagePerFrame) then
        registerKill(gameState.player, rb.score)
        particles.spawn(rb.x, rb.y, 60, {0, 0.9, 1})
        bossexplosion.start(rb.x, rb.y, rb.width, rb.height)
        gameState.bossDefeated = true
        weapons.stopSpartanLaser(gameState.player)
      else
        abilities.registerBossDamage(damagePerFrame, gameState.levelId)
      end
    end
  end

  -- Check Sphere boss (beam STOPS here with orange-white Death Star core explosions)
  if not hitBoss and sphereboss.isActive() then
    local spb = sphereboss.boss
    if math.abs(spb.x - beam.x) < (beam.width + spb.width) / 2 and spb.y < beam.y then
      hitBoss = true
      beam.actualEndY = spb.y + spb.height / 2

      local explosionIntensity = math.floor(beam.fireTime * 3) + 5
      local impactY = beam.actualEndY
      local colors = {{1, 0.7, 0.3}, {1, 0.5, 0.1}, {1, 0.9, 0.5}, {0.9, 0.3, 0.1}}
      for j = 1, math.min(math.floor(beam.fireTime * 2) + 1, 5) do
        local offsetX = (math.random() - 0.5) * beam.width
        local color = colors[math.random(1, #colors)]
        particles.spawn(beam.x + offsetX, impactY + math.random(-8, 8), explosionIntensity, color)
      end

      if sphereboss.damage(damagePerFrame) then
        registerKill(gameState.player, spb.score)
        particles.spawn(spb.x, spb.y, 60, {1, 0.8, 0.3})
        bossexplosion.start(spb.x, spb.y, spb.width, spb.height)
        gameState.bossDefeated = true
        weapons.stopSpartanLaser(gameState.player)
      else
        abilities.registerBossDamage(damagePerFrame, gameState.levelId)
      end
    end
  end

  -- Check The Machine boss (beam STOPS here with industrial orange-red explosions)
  if not hitBoss and machineboss.isActive() then
    local mb = machineboss.boss
    if math.abs(mb.x - beam.x) < (beam.width + mb.width) / 2 and mb.y < beam.y then
      hitBoss = true
      beam.actualEndY = mb.y + mb.height / 2

      local explosionIntensity = math.floor(beam.fireTime * 3) + 5
      local impactY = beam.actualEndY
      local colors = {{1, 0.4, 0.1}, {1, 0.3, 0}, {0.9, 0.5, 0.2}, {1, 0.6, 0.1}}
      for j = 1, math.min(math.floor(beam.fireTime * 2) + 1, 5) do
        local offsetX = (math.random() - 0.5) * beam.width
        local color = colors[math.random(1, #colors)]
        particles.spawn(beam.x + offsetX, impactY + math.random(-8, 8), explosionIntensity, color)
      end

      -- Check if hitting armor plates
      local hitArm = nil
      if mb.phase <= 4 then
        if beam.x < mb.x and not mb.leftArmor.destroyed then
          hitArm = "left"
        elseif beam.x >= mb.x and not mb.rightArmor.destroyed then
          hitArm = "right"
        end
      end
      -- Check shield generator
      if not hitArm and mb.phase >= 8 and mb.phase <= 10 and mb.shieldGenerator.active and not mb.shieldGenerator.destroyed then
        local shield = machineboss.getShieldPosition()
        if shield and math.abs(shield.x - beam.x) < (beam.width + shield.width) / 2 then
          hitArm = "shield"
        end
      end

      if machineboss.damage(damagePerFrame, hitArm) then
        registerKill(gameState.player, mb.score)
        particles.spawn(mb.x, mb.y, 60, {1, 0.5, 0.2})
        bossexplosion.start(mb.x, mb.y, mb.width, mb.height)
        gameState.bossDefeated = true
        weapons.stopSpartanLaser(gameState.player)
      else
        abilities.registerBossDamage(damagePerFrame, gameState.levelId)
      end
    end

    -- Spartan Laser vs Machine adds
    if not hitBoss then
      for aIdx = #mb.adds, 1, -1 do
        local add = mb.adds[aIdx]
        if math.abs(add.x - beam.x) < (beam.width + 20) and add.y < beam.y then
          local killed, healthRegen, missileRegen = machineboss.damageAdd(aIdx, damagePerFrame)
          if killed then
            particles.spawn(add.x, add.y, 15, {0.2, 1, 0.4})
            registerKill(gameState.player, 200)
            local p = gameState.player
            p.health = math.min(p.maxHealth, p.health + healthRegen)
            p.missiles = math.min((p.maxMissiles or 10), p.missiles + missileRegen)
          end
        end
      end
    end
  end
end

function M.checkCollisions()
  for i = #weapons.lasers, 1, -1 do
    local laser = weapons.lasers[i]

    if laser.owner == "player" then
      for j = #enemies.enemies, 1, -1 do
        local enemy = enemies.enemies[j]
        if M.checkHit(laser, enemy) then
          if enemies.damage(enemy, laser.damage) then
            -- Mistral conversion: convert killed enemy to wingman
            if abilities.isConvertActive() then
              local converted = allies.spawnConverted(enemy.x, enemy.y)
              abilities.registerConversion()
              particles.spawn(enemy.x, enemy.y, 20, {0.6, 0.1, 1})
            else
              particles.spawn(enemy.x, enemy.y, 15, {1, 0.5, 0})
            end
            registerKill(gameState.player, enemy.score)

            -- Djolt chain lightning: arc to nearby enemies on kill
            if muses.hasChainLightning() then
              local arcRange = 200
              local arcsUsed = 0
              for k = #enemies.enemies, 1, -1 do
                if arcsUsed >= 3 then break end
                if k ~= j then
                  local other = enemies.enemies[k]
                  local dist = math.sqrt((enemy.x - other.x)^2 + (enemy.y - other.y)^2)
                  if dist < arcRange then
                    table.insert(chainLightningArcs, {
                      x1 = enemy.x, y1 = enemy.y, x2 = other.x, y2 = other.y,
                      timer = 0.3, color = muses.MUSES.djolt.color,
                    })
                    if enemies.damage(other, 50) then
                      registerKill(gameState.player, other.score)
                      particles.spawn(other.x, other.y, 15, {0.3, 0.8, 1})
                      enemies.remove(other)
                    end
                    arcsUsed = arcsUsed + 1
                  end
                end
              end
            end

            enemies.remove(enemy)
          end

          if not laser.piercing then
            table.remove(weapons.lasers, i)
          end
          break
        end
      end

      for j = #turrets.turrets, 1, -1 do
        local turret = turrets.turrets[j]
        if turret.active and M.checkHitRect(laser, turret) then
          if turrets.damage(turret, laser.damage) then
            registerKill(gameState.player, turret.score)
            particles.spawn(turret.x, turret.y, 15, {1, 0.5, 0})
            turrets.remove(turret)
          end

          if not laser.piercing then
            table.remove(weapons.lasers, i)
          end
          break
        end
      end

      for j = #capitalship.ships, 1, -1 do
        local ship = capitalship.ships[j]
        if M.checkHitRect(laser, ship) then
          if capitalship.damage(ship, laser.damage) then
            registerKill(gameState.player, ship.score)
            particles.spawn(ship.x, ship.y, 25, {1, 0.5, 0})
            capitalship.destroy(ship)
          end

          if not laser.piercing then
            table.remove(weapons.lasers, i)
          end
          break
        end
      end

      if boss.isActive() then
        local b = boss.currentBoss
        if M.checkHitRect(laser, b) then
          local hitArm = nil
          if b.type == "finalboss" and b.phase == 1 then
            if laser.x < b.x and not b.leftArm.destroyed then
              hitArm = "left"
            elseif laser.x >= b.x and not b.rightArm.destroyed then
              hitArm = "right"
            end
          elseif b.type == "area6boss" and b.phase == 1 then
            if laser.x < b.x and not b.leftShield.destroyed then
              hitArm = "left"
            elseif laser.x >= b.x and not b.rightShield.destroyed then
              hitArm = "right"
            end
          end

          if boss.damage(laser.damage, hitArm) then
            registerKill(gameState.player, b.score)
            particles.spawn(b.x, b.y, 30, {1, 0.5, 0})
            if b.type == "finalboss" or b.type == "area6boss" then
              bossexplosion.start(b.x, b.y, b.width, b.height)
              gameState.bossDefeated = true
            end
          else
            abilities.registerBossDamage(laser.damage, gameState.levelId)
          end

          if not laser.piercing then
            table.remove(weapons.lasers, i)
          end
        end
      end

      -- Player lasers vs mothership
      if mothership.isActive() then
        local m = mothership.mothership
        if M.checkHitRect(laser, m) then
          local result = mothership.damage(laser.damage)
          if result.dead then
            registerKill(gameState.player, m.score)
            particles.spawn(m.x, m.y, 40, {1, 0.5, 0})
            bossexplosion.start(m.x, m.y, m.width, m.height)
            -- Destroy all turrets and enemies when mothership is destroyed
            turrets.reset()
            enemies.reset()
          elseif result.hullDestroyed then
            particles.spawn(m.x, m.y, 20, {1, 0.3, 0})
            abilities.registerBossDamage(laser.damage, gameState.levelId)
          else
            abilities.registerBossDamage(laser.damage, gameState.levelId)
          end
          if not laser.piercing then
            table.remove(weapons.lasers, i)
          end
        end
      end

      -- Player lasers vs Bolse station
      if bolse.isActive() then
        local s = bolse.getStation()
        local hitSomething = false

        -- Check turrets
        for _, turret in ipairs(s.turrets) do
          if not turret.destroyed then
            if M.checkHitCircle(laser, turret.worldX, turret.worldY, 15) then
              if bolse.damageTurret(turret, laser.damage) then
                registerKill(gameState.player, 100)
                particles.spawn(turret.worldX, turret.worldY, 12, {1, 0.5, 0})
                if s.phase == 1 then
                  local destroyedCount = 0
                  for _, t in ipairs(s.turrets) do
                    if t.destroyed then destroyedCount = destroyedCount + 1 end
                  end
                  if destroyedCount >= 4 then
                    wingmen.triggerCoreExposed()
                  end
                end
              end
              hitSomething = true
              break
            end
          end
        end

        -- Check core (only when exposed)
        if not hitSomething and s.coreExposed then
          if M.checkHitCircle(laser, s.x, s.y, 40) then
            if bolse.damageCore(laser.damage) then
              registerKill(gameState.player, s.score)
              particles.spawn(s.x, s.y, 40, {1, 0.5, 0})
              bossexplosion.start(s.x, s.y, 250, 250)
              gameState.bossDefeated = true
              rival.retreat()
            end
            hitSomething = true
          end
        end

        if hitSomething and not laser.piercing then
          table.remove(weapons.lasers, i)
        end
      end

      -- Player lasers vs Rival (skip if reflecting)
      if rival.isActive() then
        local r = rival.getRival()
        if r and not r.reflecting then
          if M.checkHitRect(laser, r) then
            if rival.damage(laser.damage) then
              registerKill(gameState.player, r.score)
              particles.spawn(r.x, r.y, 20, {1, 0.3, 0})
              if gameState.levelId ~= 12 then gameState.bossDefeated = true end
            else
              particles.spawn(r.x, r.y, 5, {1, 0.5, 0})
              abilities.registerBossDamage(laser.damage, gameState.levelId)
            end
            if not laser.piercing then
              table.remove(weapons.lasers, i)
            end
          end
        end
      end

      -- Player lasers reflect enemy rival lasers
      for j = #rival.getLasers(), 1, -1 do
        local enemyLaser = rival.getLasers()[j]
        if enemyLaser.reflectable and M.checkHitRect(laser, enemyLaser) then
          enemyLaser.vx = -enemyLaser.vx
          enemyLaser.vy = -enemyLaser.vy
          enemyLaser.owner = "player"
          if not laser.piercing then
            table.remove(weapons.lasers, i)
          end
          break
        end
      end

      -- Player lasers vs Venom boss (skip if teleporting)
      if venomboss.isActive() then
        local vb = venomboss.boss
        if M.checkHitRect(laser, vb) then
          if venomboss.damage(laser.damage) then
            registerKill(gameState.player, vb.score)
            particles.spawn(vb.x, vb.y, 40, {1, 0.3, 0})
            bossexplosion.start(vb.x, vb.y, vb.width, vb.height)
            gameState.bossDefeated = true
          else
            particles.spawn(laser.x, laser.y, 5, {1, 0.5, 0})
            abilities.registerBossDamage(laser.damage, gameState.levelId)
          end
          if not laser.piercing then
            table.remove(weapons.lasers, i)
          end
        end
      end

      -- Player lasers vs Sector Z boss
      if sectorzboss.isActive() then
        local szb = sectorzboss.boss
        if M.checkHitRect(laser, szb) then
          if sectorzboss.damage(laser.damage) then
            registerKill(gameState.player, szb.score)
            particles.spawn(szb.x, szb.y, 50, {1, 0.2, 0.2})
            bossexplosion.start(szb.x, szb.y, szb.width, szb.height)
            gameState.bossDefeated = true
          else
            particles.spawn(laser.x, laser.y, 5, {1, 0.4, 0.4})
            abilities.registerBossDamage(laser.damage, gameState.levelId)
          end
          if not laser.piercing then
            table.remove(weapons.lasers, i)
          end
        end
      end

      -- Player lasers vs Warden boss (5-phase Elden Ring style)
      if wardenboss.isActive() then
        local wb = wardenboss.boss
        if M.checkHitRect(laser, wb) then
          local hitArm = nil
          if not wb.guardsDown then
            if laser.x < wb.x and not wb.leftGuard.destroyed then
              hitArm = "left"
            elseif laser.x >= wb.x and not wb.rightGuard.destroyed then
              hitArm = "right"
            end
          end
          if wardenboss.damage(laser.damage, hitArm) then
            registerKill(gameState.player, wb.score)
            particles.spawn(wb.x, wb.y, 50, {0.8, 0.4, 0.1})
            bossexplosion.start(wb.x, wb.y, wb.width, wb.height)
            gameState.bossDefeated = true
          else
            particles.spawn(laser.x, laser.y, 5, {1, 0.6, 0.2})
            abilities.registerBossDamage(laser.damage, gameState.levelId)
          end
          if not laser.piercing then
            table.remove(weapons.lasers, i)
          end
        end
      end

      -- Player lasers vs Sentinel boss (5-phase Elden Ring style)
      if sentinelboss.isActive() then
        local sb = sentinelboss.boss
        if M.checkHitRect(laser, sb) then
          local hitArm = nil
          if not sb.guardsDown then
            if laser.x < sb.x and not sb.leftGuard.destroyed then
              hitArm = "left"
            elseif laser.x >= sb.x and not sb.rightGuard.destroyed then
              hitArm = "right"
            end
          end
          if sentinelboss.damage(laser.damage, hitArm) then
            registerKill(gameState.player, sb.score)
            particles.spawn(sb.x, sb.y, 50, {0.2, 0.5, 1.0})
            bossexplosion.start(sb.x, sb.y, sb.width, sb.height)
            gameState.bossDefeated = true
          else
            particles.spawn(laser.x, laser.y, 5, {0.3, 0.7, 1.0})
            abilities.registerBossDamage(laser.damage, gameState.levelId)
          end
          if not laser.piercing then
            table.remove(weapons.lasers, i)
          end
        end
      end

      -- Player lasers vs Megalith of Memories (10-phase endgame raid)
      if megalith.isActive() then
        local mb = megalith.boss
        if M.checkHitRect(laser, mb) then
          if megalith.damage(laser.damage) then
            registerKill(gameState.player, mb.score)
            particles.spawn(mb.x, mb.y, 60, {0.2, 1, 0.8})
            bossexplosion.start(mb.x, mb.y, mb.width, mb.height)
            gameState.bossDefeated = true
          else
            particles.spawn(laser.x, laser.y, 5, {0.1, 0.8, 0.6})
            abilities.registerBossDamage(laser.damage, gameState.levelId)
          end
          if not laser.piercing then
            table.remove(weapons.lasers, i)
          end
        end
      end

      -- Player lasers vs Distant Dynamo (8-phase Power Supply Overlord)
      if dynamoboss.isActive() then
        local db = dynamoboss.boss
        if M.checkHitRect(laser, db) then
          local hitArm = nil
          if not db.regulatorsDown then
            if laser.x < db.x and not db.leftRegulator.destroyed then
              hitArm = "left"
            elseif laser.x >= db.x and not db.rightRegulator.destroyed then
              hitArm = "right"
            end
          end
          if dynamoboss.damage(laser.damage, hitArm) then
            registerKill(gameState.player, db.score)
            particles.spawn(db.x, db.y, 60, {1, 0.5, 0.1})
            bossexplosion.start(db.x, db.y, db.width, db.height)
            gameState.bossDefeated = true
          else
            particles.spawn(laser.x, laser.y, 5, {1, 0.6, 0.15})
            abilities.registerBossDamage(laser.damage, gameState.levelId)
          end
          if not laser.piercing then
            table.remove(weapons.lasers, i)
          end
        end
      end

      -- Player lasers vs Synesthesia Installation (10-phase GPU Core boss)
      if synesthesia.isBossActive() then
        local sb = synesthesia.boss
        if M.checkHitRect(laser, sb) then
          local hitArm = nil
          if not sb.shieldCoresDown then
            if laser.x < sb.x and not sb.leftShieldCore.destroyed then
              hitArm = "left"
            elseif laser.x >= sb.x and not sb.rightShieldCore.destroyed then
              hitArm = "right"
            end
          end
          if synesthesia.damage(laser.damage, hitArm) then
            registerKill(gameState.player, sb.score)
            particles.spawn(sb.x, sb.y, 60, {1, 0.5, 1})
            bossexplosion.start(sb.x, sb.y, sb.width, sb.height)
            gameState.bossDefeated = true
          else
            particles.spawn(laser.x, laser.y, 5, {0.8, 0.3, 1})
            abilities.registerBossDamage(laser.damage, gameState.levelId)
          end
          if not laser.piercing then
            table.remove(weapons.lasers, i)
          end
        end

        -- Player lasers vs puzzle nodes
        local puzzleTargets = synesthesia.getPuzzleTargets()
        if puzzleTargets then
          for pIdx, pTarget in ipairs(puzzleTargets) do
            if pTarget and not pTarget.hit then
              local dist = math.sqrt((laser.x - pTarget.x)^2 + (laser.y - pTarget.y)^2)
              if dist < (pTarget.radius or 20) then
                synesthesia.onPuzzleNodeHit(pIdx)
                particles.spawn(pTarget.x, pTarget.y, 15, {0.5, 1, 0.5})
                if not laser.piercing then
                  table.remove(weapons.lasers, i)
                end
                break
              end
            end
          end
        end
      end

      -- Player lasers vs Logician raid boss (10-phase CPU die boss)
      if raidboss.isActive() then
        local rb = raidboss.boss
        if M.checkHitRect(laser, rb) then
          if raidboss.damage(laser.damage) then
            registerKill(gameState.player, rb.score)
            particles.spawn(rb.x, rb.y, 60, {0, 0.9, 1})
            bossexplosion.start(rb.x, rb.y, rb.width, rb.height)
            gameState.bossDefeated = true
          else
            particles.spawn(laser.x, laser.y, 5, {0, 0.8, 1})
            abilities.registerBossDamage(laser.damage, gameState.levelId)
          end
          if not laser.piercing then
            table.remove(weapons.lasers, i)
          end
        end
      end

      -- Player lasers vs Sphere boss (4-phase final boss)
      if sphereboss.isActive() then
        local spb = sphereboss.boss
        -- Phase 1: Check shell plates first
        if spb.phase == 1 and not spb.allPlatesDestroyed then
          local plates = sphereboss.getShellPlatePositions()
          for _, plate in ipairs(plates) do
            if M.checkHitCircle(laser, plate.x, plate.y, plate.radius) then
              sphereboss.damage(laser.damage, plate.idx)
              particles.spawn(laser.x, laser.y, 8, {1, 0.6, 0.2})
              if not laser.piercing then
                table.remove(weapons.lasers, i)
              end
              break
            end
          end
        elseif M.checkHitRect(laser, spb) then
          -- Phase 4: Check clone hit
          if spb.phase == 4 and spb.clone then
            local c = spb.clone
            if laser.x > c.x - c.width/2 and laser.x < c.x + c.width/2
               and laser.y > c.y - c.height/2 and laser.y < c.y + c.height/2 then
              if c.stunned then
                if sphereboss.damage(laser.damage) then
                  registerKill(gameState.player, spb.score)
                  particles.spawn(spb.x, spb.y, 60, {1, 0.8, 0.3})
                  bossexplosion.start(spb.x, spb.y, spb.width, spb.height)
                  gameState.bossDefeated = true
                else
                  particles.spawn(laser.x, laser.y, 8, {1, 0.5, 0})
                  abilities.registerBossDamage(laser.damage, gameState.levelId)
                end
              else
                particles.spawn(laser.x, laser.y, 3, {0.5, 0.5, 1})
              end
              if not laser.piercing then
                table.remove(weapons.lasers, i)
              end
            end
          else
            if sphereboss.damage(laser.damage) then
              registerKill(gameState.player, spb.score)
              particles.spawn(spb.x, spb.y, 60, {1, 0.8, 0.3})
              bossexplosion.start(spb.x, spb.y, spb.width, spb.height)
              gameState.bossDefeated = true
            else
              particles.spawn(laser.x, laser.y, 5, {1, 0.6, 0.2})
              abilities.registerBossDamage(laser.damage, gameState.levelId)
            end
            if not laser.piercing then
              table.remove(weapons.lasers, i)
            end
          end
        end

        -- Player lasers vs puzzle nodes (Phase 3)
        local puzzleTargets = sphereboss.getPuzzleTargets()
        if puzzleTargets then
          for pIdx, pTarget in ipairs(puzzleTargets) do
            if pTarget and not pTarget.hit then
              local dist = math.sqrt((laser.x - pTarget.x)^2 + (laser.y - pTarget.y)^2)
              if dist < (pTarget.radius or 18) then
                sphereboss.onPuzzleNodeHit(pIdx)
                particles.spawn(pTarget.x, pTarget.y, 15, {0.5, 1, 0.5})
                if not laser.piercing then
                  table.remove(weapons.lasers, i)
                end
                break
              end
            end
          end
        end

        -- Player lasers vs puzzle drones (Phase 3)
        if spb.phase == 3 and spb.puzzleDrones then
          for dIdx = #spb.puzzleDrones, 1, -1 do
            local drone = spb.puzzleDrones[dIdx]
            local dist = math.sqrt((laser.x - drone.x)^2 + (laser.y - drone.y)^2)
            if dist < 20 then
              if sphereboss.damageDrone(dIdx, laser.damage) then
                particles.spawn(drone.x, drone.y, 12, {1, 0.5, 0})
                registerKill(gameState.player, 50)
              else
                particles.spawn(laser.x, laser.y, 5, {1, 0.5, 0})
              end
              if not laser.piercing then
                table.remove(weapons.lasers, i)
              end
              break
            end
          end
        end
      end

      -- Player lasers vs The Machine boss (21-phase final boss)
      if machineboss.isActive() then
        local mb = machineboss.boss
        local hitMachine = false

        -- Phase 1-4: Check armor plates first
        if mb.phase <= 4 then
          local plates = machineboss.getArmorPositions()
          for _, plate in ipairs(plates) do
            if laser.x > plate.x - plate.width/2 and laser.x < plate.x + plate.width/2
               and laser.y > plate.y - plate.height/2 and laser.y < plate.y + plate.height/2 then
              machineboss.damage(laser.damage, plate.idx)
              particles.spawn(laser.x, laser.y, 8, {1, 0.5, 0.2})
              if not laser.piercing then
                table.remove(weapons.lasers, i)
              end
              hitMachine = true
              break
            end
          end
        end

        -- Phase 8-10: Check shield generator
        if not hitMachine then
          local shield = machineboss.getShieldPosition()
          if shield then
            if laser.x > shield.x - shield.width/2 and laser.x < shield.x + shield.width/2
               and laser.y > shield.y - shield.height/2 and laser.y < shield.y + shield.height/2 then
              machineboss.damage(laser.damage, "shield")
              particles.spawn(laser.x, laser.y, 8, {0.3, 0.8, 1})
              if not laser.piercing then
                table.remove(weapons.lasers, i)
              end
              hitMachine = true
            end
          end
        end

        -- Check adds (killing gives health + missile regen)
        if not hitMachine then
          for aIdx = #mb.adds, 1, -1 do
            local add = mb.adds[aIdx]
            local dist = math.sqrt((laser.x - add.x)^2 + (laser.y - add.y)^2)
            if dist < 20 then
              local killed, healthRegen, missileRegen = machineboss.damageAdd(aIdx, laser.damage)
              if killed then
                particles.spawn(add.x, add.y, 15, {0.2, 1, 0.4})
                registerKill(gameState.player, 200)
                -- Apply regen rewards
                local p = gameState.player
                p.health = math.min(p.maxHealth, p.health + healthRegen)
                p.missiles = math.min((p.maxMissiles or 10), p.missiles + missileRegen)
              else
                particles.spawn(laser.x, laser.y, 5, {1, 0.5, 0})
              end
              if not laser.piercing then
                table.remove(weapons.lasers, i)
              end
              hitMachine = true
              break
            end
          end
        end

        -- Check main body
        if not hitMachine and M.checkHitRect(laser, mb) then
          if machineboss.damage(laser.damage) then
            registerKill(gameState.player, mb.score)
            particles.spawn(mb.x, mb.y, 60, {1, 0.5, 0.2})
            bossexplosion.start(mb.x, mb.y, mb.width, mb.height)
            gameState.bossDefeated = true
          else
            particles.spawn(laser.x, laser.y, 5, {1, 0.4, 0.1})
            abilities.registerBossDamage(laser.damage, gameState.levelId)
          end
          if not laser.piercing then
            table.remove(weapons.lasers, i)
          end
        end
      end

      -- Player lasers vs raid puzzle input nodes
      if raid.isActive() then
        raid.checkLaserPuzzleHit(laser.x, laser.y)
      end

      -- Reflected prototype projectiles hitting the Prototype back
      if laser.reflected and prototype.isActive() then
        local ship = prototype.getShip()
        if ship and M.checkHitRect(laser, ship) then
          if laser.isEmp then
            -- Reflected EMP weakens the Prototype's shield
            prototype.onReflectedEmpHit()
            particles.spawn(laser.x, laser.y, 20, {0.2, 0.5, 1.0})
          elseif prototype.shieldActive then
            -- Normal reflected lasers bounce off shield
            particles.spawn(laser.x, laser.y, 5, {0.3, 0.6, 1.0})
          else
            -- Shield is down, damage applies
            prototype.damage(laser.damage)
            particles.spawn(laser.x, laser.y, 10, {1, 0.5, 0})
          end
          table.remove(weapons.lasers, i)
        end
      end

      -- Player lasers (non-reflected) hitting the Prototype
      if not laser.reflected and prototype.isActive() then
        local ship = prototype.getShip()
        if ship and M.checkHitRect(laser, ship) then
          if prototype.shieldActive then
            -- All normal player fire bounces off shield
            particles.spawn(laser.x, laser.y, 5, {0.3, 0.6, 1.0})
          else
            -- Shield is down, damage applies
            prototype.damage(laser.damage)
            particles.spawn(laser.x, laser.y, 10, {1, 0.5, 0})
          end
          if not laser.piercing then
            table.remove(weapons.lasers, i)
          end
        end
      end

      -- Maze blocks player lasers
      if maze.isActive() and maze.checkLaserCollision(laser) then
        particles.spawn(laser.x, laser.y, 5, {0.5, 0.5, 0.5})
        table.remove(weapons.lasers, i)
      end

    elseif laser.owner == "ally" then
      -- Ally lasers vs enemies
      for j = #enemies.enemies, 1, -1 do
        local enemy = enemies.enemies[j]
        if M.checkHit(laser, enemy) then
          if enemies.damage(enemy, laser.damage) then
            registerKill(gameState.player, enemy.score)
            particles.spawn(enemy.x, enemy.y, 15, {1, 0.5, 0})
            enemies.remove(enemy)
          end
          table.remove(weapons.lasers, i)
          break
        end
      end

    elseif laser.owner == "enemy" then
      -- Maze blocks enemy lasers too
      if maze.isActive() and maze.checkLaserCollision(laser) then
        particles.spawn(laser.x, laser.y, 5, {0.5, 0.5, 0.5})
        table.remove(weapons.lasers, i)
      elseif M.checkHitPlayer(laser, gameState.player) then
        player.takeDamage(gameState.player, laser.damage)
        table.remove(weapons.lasers, i)
      else
        -- Enemy lasers vs allies
        for j = #allies.allies, 1, -1 do
          local ally = allies.allies[j]
          if M.checkHit(laser, ally) then
            if allies.damage(ally, laser.damage) then
              particles.spawn(ally.x, ally.y, 12, {0.3, 0.5, 1})
            end
            table.remove(weapons.lasers, i)
            break
          end
        end
      end

    -- Prototype EMP stun bullets
    elseif laser.owner == "prototype_emp" then
      if M.checkHitPlayer(laser, gameState.player) then
        -- EMP stuns the player (doesn't damage, immobilizes for 3s)
        -- Clarity Muse power: immune to stun effects
        if not gameState.player.barrelRolling and not gameState.player.invulnerable and not muses.hasClarity() then
          gameState.player.stunned = true
          gameState.player.stunnedTimer = laser.stunDuration or 3
        end
        particles.spawn(laser.x, laser.y, 15, {0.2, 0.5, 1.0})
        table.remove(weapons.lasers, i)
      end

    -- Prototype normal lasers
    elseif laser.owner == "prototype" then
      if M.checkHitPlayer(laser, gameState.player) then
        -- Prototype laser hits player
        if not gameState.player.barrelRolling and not gameState.player.invulnerable then
          player.takeDamage(gameState.player, laser.damage)
        end
        table.remove(weapons.lasers, i)
      end
    end
  end

  -- Shotgun pellets vs enemies (Phantom special)
  for i = #weapons.shotgunPellets, 1, -1 do
    local pellet = weapons.shotgunPellets[i]
    local hit = false

    for j = #enemies.enemies, 1, -1 do
      local enemy = enemies.enemies[j]
      if M.checkHit(pellet, enemy) then
        -- Distance-based damage: closer = more damage
        local dist = math.sqrt((pellet.x - enemy.x)^2 + (pellet.y - enemy.y)^2)
        local damageMultiplier = math.max(1, 5 - (dist / 50))  -- Up to 5x at point blank
        local finalDamage = math.floor(pellet.damage * damageMultiplier)

        if enemies.damage(enemy, finalDamage) then
          registerKill(gameState.player, enemy.score)
          particles.spawn(enemy.x, enemy.y, 15, {0.5, 0.5, 0.8})
          enemies.remove(enemy)
        else
          particles.spawn(pellet.x, pellet.y, 5, {0.5, 0.5, 0.8})
        end
        hit = true
        break
      end
    end

    if hit then
      table.remove(weapons.shotgunPellets, i)
    end
  end

  -- Charged blasts vs enemies (Paladin special)
  for i = #weapons.chargedBlasts, 1, -1 do
    local blast = weapons.chargedBlasts[i]

    -- Damage enemies in blast radius as it travels
    for j = #enemies.enemies, 1, -1 do
      local enemy = enemies.enemies[j]
      local dist = math.sqrt((blast.x - enemy.x)^2 + (blast.y - enemy.y)^2)

      -- Check if enemy is in radius and hasn't been hit yet
      if dist < blast.currentRadius and not blast.hitEnemies[enemy] then
        blast.hitEnemies[enemy] = true

        if enemies.damage(enemy, blast.damage) then
          registerKill(gameState.player, enemy.score)
          particles.spawn(enemy.x, enemy.y, 20, {0.3, 1, 0.5})
          enemies.remove(enemy)
        else
          -- Small hit effect for non-killing hits
          particles.spawn(enemy.x, enemy.y, 8, {0.3, 1, 0.5})
        end
      end
    end
  end

  -- Clean up expired blasts and spawn final explosion
  for i = #weapons.chargedBlasts, 1, -1 do
    local blast = weapons.chargedBlasts[i]
    if blast.y < -50 or blast.age >= blast.maxAge then
      -- Spawn fancy explosion with bloom at end of life
      particles.spawnPaladinExplosion(blast.x, blast.y, blast.currentRadius, blast.chargeLevel)
      table.remove(weapons.chargedBlasts, i)
    end
  end

  -- Rival lasers vs player (and reflected rival lasers vs rival)
  for i = #rival.getLasers(), 1, -1 do
    local laser = rival.getLasers()[i]
    if laser.owner == "player" then
      -- Reflected bullet: can damage Wolf
      if rival.isActive() then
        local r = rival.getRival()
        if r and not r.reflecting and M.checkHitRect(laser, r) then
          if rival.damage(laser.damage) then
            registerKill(gameState.player, r.score)
            particles.spawn(r.x, r.y, 20, {1, 0.3, 0})
            if gameState.levelId ~= 12 then gameState.bossDefeated = true end
          else
            particles.spawn(r.x, r.y, 5, {1, 0.5, 0})
          end
          table.remove(rival.getLasers(), i)
        end
      end
    elseif M.checkHitPlayer(laser, gameState.player) then
      player.takeDamage(gameState.player, laser.damage)
      table.remove(rival.getLasers(), i)
    end
  end

  -- Missiles vs enemies
  for i = #weapons.missiles, 1, -1 do
    local missile = weapons.missiles[i]
    local hit = false

    -- Missiles vs basic enemies
    for j = #enemies.enemies, 1, -1 do
      local enemy = enemies.enemies[j]
      if M.checkHitBox(missile, enemy) then
        if enemies.damage(enemy, missile.damage) then
          registerKill(gameState.player, enemy.score)
          particles.spawn(enemy.x, enemy.y, 15, {1, 0.5, 0})
          enemies.remove(enemy)
        end
        particles.spawn(missile.x, missile.y, 8, {1, 1, 0})
        table.remove(weapons.missiles, i)
        hit = true
        break
      end
    end

    if not hit then
      -- Missiles vs turrets
      for j = #turrets.turrets, 1, -1 do
        local turret = turrets.turrets[j]
        if turret.active and M.checkHitBox(missile, turret) then
          if turrets.damage(turret, missile.damage) then
            registerKill(gameState.player, turret.score)
            particles.spawn(turret.x, turret.y, 15, {1, 0.5, 0})
            turrets.remove(turret)
          end
          particles.spawn(missile.x, missile.y, 8, {1, 1, 0})
          table.remove(weapons.missiles, i)
          hit = true
          break
        end
      end
    end

    if not hit then
      -- Missiles vs capital ships
      for j = #capitalship.ships, 1, -1 do
        local ship = capitalship.ships[j]
        if M.checkHitBox(missile, ship) then
          if capitalship.damage(ship, missile.damage) then
            registerKill(gameState.player, ship.score)
            particles.spawn(ship.x, ship.y, 25, {1, 0.5, 0})
            capitalship.destroy(ship)
          end
          particles.spawn(missile.x, missile.y, 8, {1, 1, 0})
          table.remove(weapons.missiles, i)
          hit = true
          break
        end
      end
    end

    if not hit and boss.isActive() then
      local b = boss.currentBoss
      if M.checkHitBox(missile, b) then
        local hitArm = nil
        if b.type == "finalboss" and b.phase == 1 then
          if missile.x < b.x and not b.leftArm.destroyed then
            hitArm = "left"
          elseif missile.x >= b.x and not b.rightArm.destroyed then
            hitArm = "right"
          end
        elseif b.type == "area6boss" and b.phase == 1 then
          if missile.x < b.x and not b.leftShield.destroyed then
            hitArm = "left"
          elseif missile.x >= b.x and not b.rightShield.destroyed then
            hitArm = "right"
          end
        end

        if boss.damage(missile.damage, hitArm) then
          registerKill(gameState.player, b.score)
          particles.spawn(b.x, b.y, 30, {1, 0.5, 0})
          if b.type == "finalboss" or b.type == "area6boss" then
            bossexplosion.start(b.x, b.y, b.width, b.height)
            gameState.bossDefeated = true
          end
        end
        particles.spawn(missile.x, missile.y, 8, {1, 1, 0})
        table.remove(weapons.missiles, i)
        hit = true
      end
    end

    if not hit and mothership.isActive() then
      local m = mothership.mothership
      if M.checkHitBox(missile, m) then
        local result = mothership.damage(missile.damage)
        if result.dead then
          registerKill(gameState.player, m.score)
          particles.spawn(m.x, m.y, 40, {1, 0.5, 0})
          bossexplosion.start(m.x, m.y, m.width, m.height)
          -- Destroy all turrets and enemies when mothership is destroyed
          turrets.reset()
          enemies.reset()
        elseif result.hullDestroyed then
          particles.spawn(m.x, m.y, 20, {1, 0.3, 0})
        end
        particles.spawn(missile.x, missile.y, 8, {1, 1, 0})
        table.remove(weapons.missiles, i)
        hit = true
      end
    end

    if not hit and bolse.isActive() then
      local s = bolse.getStation()
      for j = #s.turrets, 1, -1 do
        local t = s.turrets[j]
        if not t.destroyed and M.checkHitCircle(missile, t.worldX, t.worldY, 15) then
          if bolse.damageTurret(t, missile.damage) then
            registerKill(gameState.player, 100)
            particles.spawn(t.worldX, t.worldY, 12, {1, 0.5, 0})
          end
          particles.spawn(missile.x, missile.y, 8, {1, 1, 0})
          table.remove(weapons.missiles, i)
          hit = true
          break
        end
      end

      -- Check core (only when exposed)
      if not hit and s.coreExposed then
        if M.checkHitCircle(missile, s.x, s.y, 40) then
          if bolse.damageCore(missile.damage) then
            registerKill(gameState.player, s.score)
            particles.spawn(s.x, s.y, 40, {1, 0.5, 0})
            bossexplosion.start(s.x, s.y, 250, 250)
            gameState.bossDefeated = true
            rival.retreat()
          end
          particles.spawn(missile.x, missile.y, 8, {1, 1, 0})
          table.remove(weapons.missiles, i)
          hit = true
        end
      end
    end

    if not hit and rival.isActive() then
      local r = rival.rival
      if M.checkHitBox(missile, r) then
        if rival.damage(missile.damage) then
          registerKill(gameState.player, r.score)
          particles.spawn(r.x, r.y, 25, {1, 0.5, 0})
          if gameState.levelId ~= 12 then gameState.bossDefeated = true end
        else
          abilities.registerBossDamage(missile.damage, gameState.levelId)
        end
        particles.spawn(missile.x, missile.y, 8, {1, 1, 0})
        table.remove(weapons.missiles, i)
        hit = true
      end
    end

    if not hit and venomboss.isActive() then
      local vb = venomboss.boss
      if M.checkHitBox(missile, vb) then
        if venomboss.damage(missile.damage) then
          registerKill(gameState.player, vb.score)
          particles.spawn(vb.x, vb.y, 40, {1, 0.5, 0})
          bossexplosion.start(vb.x, vb.y, vb.width, vb.height)
        else
          abilities.registerBossDamage(missile.damage, gameState.levelId)
        end
        particles.spawn(missile.x, missile.y, 8, {1, 1, 0})
        table.remove(weapons.missiles, i)
        hit = true
      end
    end

    if not hit and sectorzboss.isActive() then
      local szb = sectorzboss.boss
      if M.checkHitBox(missile, szb) then
        if sectorzboss.damage(missile.damage) then
          registerKill(gameState.player, szb.score)
          particles.spawn(szb.x, szb.y, 50, {1, 0.2, 0.2})
          bossexplosion.start(szb.x, szb.y, szb.width, szb.height)
          gameState.bossDefeated = true
        else
          abilities.registerBossDamage(missile.damage, gameState.levelId)
        end
        particles.spawn(missile.x, missile.y, 8, {1, 1, 0})
        table.remove(weapons.missiles, i)
        hit = true
      end
    end

    -- Missiles vs Megalith boss
    if not hit and megalith.isActive() then
      local mb = megalith.boss
      if M.checkHitBox(missile, mb) then
        if megalith.damage(missile.damage) then
          registerKill(gameState.player, mb.score)
          particles.spawn(mb.x, mb.y, 60, {0.2, 1, 0.8})
          bossexplosion.start(mb.x, mb.y, mb.width, mb.height)
          gameState.bossDefeated = true
        else
          abilities.registerBossDamage(missile.damage, gameState.levelId)
        end
        particles.spawn(missile.x, missile.y, 8, {1, 1, 0})
        table.remove(weapons.missiles, i)
        hit = true
      end
    end

    -- Missiles vs Distant Dynamo boss
    if not hit and dynamoboss.isActive() then
      local db = dynamoboss.boss
      if M.checkHitBox(missile, db) then
        if dynamoboss.damage(missile.damage) then
          registerKill(gameState.player, db.score)
          particles.spawn(db.x, db.y, 60, {1, 0.5, 0.1})
          bossexplosion.start(db.x, db.y, db.width, db.height)
          gameState.bossDefeated = true
        else
          abilities.registerBossDamage(missile.damage, gameState.levelId)
        end
        particles.spawn(missile.x, missile.y, 8, {1, 1, 0})
        table.remove(weapons.missiles, i)
        hit = true
      end
    end

    -- Missiles vs Synesthesia boss
    if not hit and synesthesia.isBossActive() then
      local sb = synesthesia.boss
      if M.checkHitBox(missile, sb) then
        if synesthesia.damage(missile.damage) then
          registerKill(gameState.player, sb.score)
          particles.spawn(sb.x, sb.y, 60, {1, 0.5, 1})
          bossexplosion.start(sb.x, sb.y, sb.width, sb.height)
          gameState.bossDefeated = true
        else
          abilities.registerBossDamage(missile.damage, gameState.levelId)
        end
        particles.spawn(missile.x, missile.y, 8, {1, 1, 0})
        table.remove(weapons.missiles, i)
        hit = true
      end
    end

    -- Missiles vs Logician raid boss
    if not hit and raidboss.isActive() then
      local rb = raidboss.boss
      if M.checkHitBox(missile, rb) then
        if raidboss.damage(missile.damage) then
          registerKill(gameState.player, rb.score)
          particles.spawn(rb.x, rb.y, 60, {0, 0.9, 1})
          bossexplosion.start(rb.x, rb.y, rb.width, rb.height)
          gameState.bossDefeated = true
        else
          abilities.registerBossDamage(missile.damage, gameState.levelId)
        end
        particles.spawn(missile.x, missile.y, 8, {1, 1, 0})
        table.remove(weapons.missiles, i)
        hit = true
      end
    end

    -- Missiles vs Prototype
    if not hit and prototype.isActive() then
      local ship = prototype.getShip()
      if ship and M.checkHitBox(missile, ship) then
        if prototype.shieldActive then
          particles.spawn(missile.x, missile.y, 5, {0.3, 0.6, 1.0})
        else
          prototype.damage(missile.damage)
          particles.spawn(missile.x, missile.y, 10, {1, 0.5, 0})
        end
        table.remove(weapons.missiles, i)
        hit = true
      end
    end

    -- Missiles vs Sphere boss
    if not hit and sphereboss.isActive() then
      local spb = sphereboss.boss
      if M.checkHitBox(missile, spb) then
        if sphereboss.damage(missile.damage) then
          registerKill(gameState.player, spb.score)
          particles.spawn(spb.x, spb.y, 60, {1, 0.8, 0.3})
          bossexplosion.start(spb.x, spb.y, spb.width, spb.height)
          gameState.bossDefeated = true
        else
          abilities.registerBossDamage(missile.damage, gameState.levelId)
        end
        particles.spawn(missile.x, missile.y, 8, {1, 1, 0})
        table.remove(weapons.missiles, i)
        hit = true
      end
      -- Missiles vs clone (Phase 4 — missiles stun the clone!)
      if not hit and spb.phase == 4 and spb.clone and not spb.clone.stunned then
        local c = spb.clone
        if missile.x > c.x - c.width/2 and missile.x < c.x + c.width/2
           and missile.y > c.y - c.height/2 and missile.y < c.y + c.height/2 then
          sphereboss.stunClone(3)
          particles.spawn(c.x, c.y, 20, {0.5, 0.5, 1})
          table.remove(weapons.missiles, i)
          hit = true
        end
      end
    end

    -- Missiles vs The Machine boss
    if not hit and machineboss.isActive() then
      local mb = machineboss.boss

      -- Missiles vs adds (killing gives regen)
      for aIdx = #mb.adds, 1, -1 do
        local add = mb.adds[aIdx]
        local dist = math.sqrt((missile.x - add.x)^2 + (missile.y - add.y)^2)
        if dist < 25 then
          local killed, healthRegen, missileRegen = machineboss.damageAdd(aIdx, missile.damage)
          if killed then
            particles.spawn(add.x, add.y, 15, {0.2, 1, 0.4})
            registerKill(gameState.player, 200)
            local p = gameState.player
            p.health = math.min(p.maxHealth, p.health + healthRegen)
            p.missiles = math.min((p.maxMissiles or 10), p.missiles + missileRegen)
          end
          particles.spawn(missile.x, missile.y, 8, {1, 1, 0})
          table.remove(weapons.missiles, i)
          hit = true
          break
        end
      end

      -- Missiles vs main body
      if not hit and M.checkHitBox(missile, mb) then
        local hitArm = nil
        if mb.phase <= 4 then
          if missile.x < mb.x and not mb.leftArmor.destroyed then
            hitArm = "left"
          elseif missile.x >= mb.x and not mb.rightArmor.destroyed then
            hitArm = "right"
          end
        end
        if not hitArm and mb.phase >= 8 and mb.phase <= 10 and mb.shieldGenerator.active and not mb.shieldGenerator.destroyed then
          hitArm = "shield"
        end

        if machineboss.damage(missile.damage, hitArm) then
          registerKill(gameState.player, mb.score)
          particles.spawn(mb.x, mb.y, 60, {1, 0.5, 0.2})
          bossexplosion.start(mb.x, mb.y, mb.width, mb.height)
          gameState.bossDefeated = true
        else
          abilities.registerBossDamage(missile.damage, gameState.levelId)
        end
        particles.spawn(missile.x, missile.y, 8, {1, 1, 0})
        table.remove(weapons.missiles, i)
        hit = true
      end
    end
  end

  for _, bomb in ipairs(weapons.bombs) do
    for j = #enemies.enemies, 1, -1 do
      local enemy = enemies.enemies[j]
      local dist = math.sqrt((bomb.x - enemy.x)^2 + (bomb.y - enemy.y)^2)
      if dist < bomb.radius then
        registerKill(gameState.player, enemy.score)
        particles.spawn(enemy.x, enemy.y, 10, {1, 0.5, 0})
        enemies.remove(enemy)
      end
    end

    for j = #capitalship.ships, 1, -1 do
      local ship = capitalship.ships[j]
      local dist = math.sqrt((bomb.x - ship.x)^2 + (bomb.y - ship.y)^2)
      if dist < bomb.radius then
        if capitalship.damage(ship, bomb.damage) then
          registerKill(gameState.player, ship.score)
          particles.spawn(ship.x, ship.y, 25, {1, 0.5, 0})
          capitalship.destroy(ship)
        end
      end
    end

    if boss.isActive() then
      local b = boss.currentBoss
      local dist = math.sqrt((bomb.x - b.x)^2 + (bomb.y - b.y)^2)
      if dist < bomb.radius then
        if boss.damage(bomb.damage) then
          registerKill(gameState.player, b.score)
          particles.spawn(b.x, b.y, 30, {1, 0.5, 0})
          if b.type == "finalboss" or b.type == "area6boss" then
            bossexplosion.start(b.x, b.y, b.width, b.height)
            gameState.bossDefeated = true
          end
        end
      end
    end

    if mothership.isActive() then
      local m = mothership.mothership
      local dist = math.sqrt((bomb.x - m.x)^2 + (bomb.y - m.y)^2)
      if dist < bomb.radius then
        local result = mothership.damage(bomb.damage)
        if result.dead then
          registerKill(gameState.player, m.score)
          particles.spawn(m.x, m.y, 40, {1, 0.5, 0})
          bossexplosion.start(m.x, m.y, m.width, m.height)
          -- Destroy all turrets and enemies when mothership is destroyed
          turrets.reset()
          enemies.reset()
        end
      end
    end

    -- Bomb vs Bolse station
    if bolse.isActive() then
      local s = bolse.getStation()
      for _, turret in ipairs(s.turrets) do
        if not turret.destroyed then
          local dist = math.sqrt((bomb.x - turret.worldX)^2 + (bomb.y - turret.worldY)^2)
          if dist < bomb.radius then
            if bolse.damageTurret(turret, bomb.damage) then
              registerKill(gameState.player, 100)
              particles.spawn(turret.worldX, turret.worldY, 12, {1, 0.5, 0})
            end
          end
        end
      end
      if s.coreExposed then
        local dist = math.sqrt((bomb.x - s.x)^2 + (bomb.y - s.y)^2)
        if dist < bomb.radius then
          if bolse.damageCore(bomb.damage) then
            registerKill(gameState.player, s.score)
            particles.spawn(s.x, s.y, 40, {1, 0.5, 0})
            bossexplosion.start(s.x, s.y, 250, 250)
            gameState.bossDefeated = true
            rival.retreat()
          end
        end
      end
    end

    -- Bomb vs Rival
    if rival.isActive() then
      local r = rival.getRival()
      if r and not r.reflecting then
        local dist = math.sqrt((bomb.x - r.x)^2 + (bomb.y - r.y)^2)
        if dist < bomb.radius then
          if rival.damage(bomb.damage) then
            registerKill(gameState.player, r.score)
            particles.spawn(r.x, r.y, 20, {1, 0.3, 0})
            if gameState.levelId ~= 12 then gameState.bossDefeated = true end
          end
        end
      end
    end

    -- Bomb vs Venom boss
    if venomboss.isActive() then
      local vb = venomboss.boss
      local dist = math.sqrt((bomb.x - vb.x)^2 + (bomb.y - vb.y)^2)
      if dist < bomb.radius then
        if venomboss.damage(bomb.damage) then
          registerKill(gameState.player, vb.score)
          particles.spawn(vb.x, vb.y, 40, {1, 0.3, 0})
          bossexplosion.start(vb.x, vb.y, vb.width, vb.height)
          gameState.bossDefeated = true
        end
      end
    end

    -- Bomb vs Sector Z boss
    if sectorzboss.isActive() then
      local szb = sectorzboss.boss
      local dist = math.sqrt((bomb.x - szb.x)^2 + (bomb.y - szb.y)^2)
      if dist < bomb.radius then
        if sectorzboss.damage(bomb.damage) then
          registerKill(gameState.player, szb.score)
          particles.spawn(szb.x, szb.y, 50, {1, 0.2, 0.2})
          bossexplosion.start(szb.x, szb.y, szb.width, szb.height)
          gameState.bossDefeated = true
        end
      end
    end

    -- Bomb vs Warden boss
    if wardenboss.isActive() then
      local wb = wardenboss.boss
      local dist = math.sqrt((bomb.x - wb.x)^2 + (bomb.y - wb.y)^2)
      if dist < bomb.radius then
        if wardenboss.damage(bomb.damage) then
          registerKill(gameState.player, wb.score)
          particles.spawn(wb.x, wb.y, 50, {0.8, 0.4, 0.1})
          bossexplosion.start(wb.x, wb.y, wb.width, wb.height)
          gameState.bossDefeated = true
        end
      end
    end

    -- Bomb vs Sentinel boss
    if sentinelboss.isActive() then
      local sb = sentinelboss.boss
      local dist = math.sqrt((bomb.x - sb.x)^2 + (bomb.y - sb.y)^2)
      if dist < bomb.radius then
        if sentinelboss.damage(bomb.damage) then
          registerKill(gameState.player, sb.score)
          particles.spawn(sb.x, sb.y, 50, {0.2, 0.5, 1.0})
          bossexplosion.start(sb.x, sb.y, sb.width, sb.height)
          gameState.bossDefeated = true
        end
      end
    end

    -- Bomb vs Megalith boss
    if megalith.isActive() then
      local mb = megalith.boss
      local dist = math.sqrt((bomb.x - mb.x)^2 + (bomb.y - mb.y)^2)
      if dist < bomb.radius then
        if megalith.damage(bomb.damage) then
          registerKill(gameState.player, mb.score)
          particles.spawn(mb.x, mb.y, 60, {0.2, 1, 0.8})
          bossexplosion.start(mb.x, mb.y, mb.width, mb.height)
          gameState.bossDefeated = true
        end
      end
    end

    -- Bomb vs Distant Dynamo boss
    if dynamoboss.isActive() then
      local db = dynamoboss.boss
      local dist = math.sqrt((bomb.x - db.x)^2 + (bomb.y - db.y)^2)
      if dist < bomb.radius then
        if dynamoboss.damage(bomb.damage) then
          registerKill(gameState.player, db.score)
          particles.spawn(db.x, db.y, 60, {1, 0.5, 0.1})
          bossexplosion.start(db.x, db.y, db.width, db.height)
          gameState.bossDefeated = true
        end
      end
    end

    -- Bomb vs Synesthesia boss
    if synesthesia.isBossActive() then
      local sb = synesthesia.boss
      local dist = math.sqrt((bomb.x - sb.x)^2 + (bomb.y - sb.y)^2)
      if dist < bomb.radius then
        if synesthesia.damage(bomb.damage) then
          registerKill(gameState.player, sb.score)
          particles.spawn(sb.x, sb.y, 60, {1, 0.5, 1})
          bossexplosion.start(sb.x, sb.y, sb.width, sb.height)
          gameState.bossDefeated = true
        end
      end
    end

    -- Bomb vs Logician raid boss
    if raidboss.isActive() then
      local rb = raidboss.boss
      local dist = math.sqrt((bomb.x - rb.x)^2 + (bomb.y - rb.y)^2)
      if dist < bomb.radius then
        if raidboss.damage(bomb.damage) then
          registerKill(gameState.player, rb.score)
          particles.spawn(rb.x, rb.y, 60, {0, 0.9, 1})
          bossexplosion.start(rb.x, rb.y, rb.width, rb.height)
          gameState.bossDefeated = true
        end
      end
    end

    -- Bomb vs Prototype
    if prototype.isActive() then
      local ship = prototype.getShip()
      if ship then
        local dist = math.sqrt((bomb.x - ship.x)^2 + (bomb.y - ship.y)^2)
        if dist < bomb.radius then
          if prototype.shieldActive then
            -- Bombs bounce off the shield harmlessly
            particles.spawn(ship.x, ship.y, 10, {0.3, 0.6, 1.0})
          else
            prototype.damage(bomb.damage)
            particles.spawn(ship.x, ship.y, 15, {1, 0.5, 0})
          end
        end
      end
    end

    -- Bomb vs Sphere boss
    if sphereboss.isActive() then
      local spb = sphereboss.boss
      local dist = math.sqrt((bomb.x - spb.x)^2 + (bomb.y - spb.y)^2)
      if dist < bomb.radius then
        if sphereboss.damage(bomb.damage) then
          registerKill(gameState.player, spb.score)
          particles.spawn(spb.x, spb.y, 60, {1, 0.8, 0.3})
          bossexplosion.start(spb.x, spb.y, spb.width, spb.height)
          gameState.bossDefeated = true
        end
      end
      -- Bomb stuns the clone (Phase 4)
      if spb.phase == 4 and spb.clone and not spb.clone.stunned then
        local c = spb.clone
        local cDist = math.sqrt((bomb.x - c.x)^2 + (bomb.y - c.y)^2)
        if cDist < bomb.radius then
          sphereboss.stunClone(4)
          particles.spawn(c.x, c.y, 25, {0.5, 0.5, 1})
        end
      end
    end

    -- Bomb vs The Machine boss
    if machineboss.isActive() then
      local mb = machineboss.boss

      -- Bomb vs adds
      for aIdx = #mb.adds, 1, -1 do
        local add = mb.adds[aIdx]
        local dist = math.sqrt((bomb.x - add.x)^2 + (bomb.y - add.y)^2)
        if dist < bomb.radius then
          local killed, healthRegen, missileRegen = machineboss.damageAdd(aIdx, bomb.damage)
          if killed then
            particles.spawn(add.x, add.y, 15, {0.2, 1, 0.4})
            registerKill(gameState.player, 200)
            local p = gameState.player
            p.health = math.min(p.maxHealth, p.health + healthRegen)
            p.missiles = math.min((p.maxMissiles or 10), p.missiles + missileRegen)
          end
        end
      end

      -- Bomb vs main body
      local dist = math.sqrt((bomb.x - mb.x)^2 + (bomb.y - mb.y)^2)
      if dist < bomb.radius then
        if machineboss.damage(bomb.damage) then
          registerKill(gameState.player, mb.score)
          particles.spawn(mb.x, mb.y, 60, {1, 0.5, 0.2})
          bossexplosion.start(mb.x, mb.y, mb.width, mb.height)
          gameState.bossDefeated = true
        end
      end
    end
  end

  for _, enemy in ipairs(enemies.enemies) do
    if M.checkHitPlayer(enemy, gameState.player) then
      player.takeDamage(gameState.player, 10)
      particles.spawn(enemy.x, enemy.y, 10, {1, 0.5, 0})
      enemies.remove(enemy)
      break
    end
  end

  -- Maze wall collision with player (Phantom phase cloak bypasses)
  if maze.isActive() and not abilities.isPhasing() then
    local p = gameState.player
    if maze.checkCollision(p.x, p.y, 20) then
      if not p.barrelRolling and not p.invulnerable then
        player.takeDamage(p, 15)
        particles.spawn(p.x, p.y, 10, {0.5, 0.5, 0.5})
      end
    end
  end

  -- Venom boss continuous laser vs player
  if venomboss.isActive() then
    local p = gameState.player
    local vb = venomboss.boss
    if vb.laserActive then
      -- Barrel roll can reflect the laser
      if p.barrelRolling then
        local dist = venomboss.pointToLaserDistance(p.x, p.y)
        if dist < 60 then
          venomboss.reflectLaser()
        end
      elseif venomboss.checkLaserHitPlayer(p.x, p.y, 20) then
        if not p.invulnerable then
          player.takeDamage(p, 2)
        end
      end
    end
  end

  -- Sector Z boss special mechanics
  if sectorzboss.isActive() then
    local p = gameState.player

    -- Gravity Well: pull player toward boss
    local gx, gy, strength = sectorzboss.getGravityPull()
    if strength and strength > 0 then
      local dx = gx - p.x
      local dy = gy - p.y
      local dist = math.sqrt(dx*dx + dy*dy)
      if dist > 1 then
        local pullX = (dx / dist) * strength * love.timer.getDelta()
        local pullY = (dy / dist) * strength * love.timer.getDelta()
        p.x = math.max(30, math.min(screen.WIDTH - 30, p.x + pullX))
        p.y = math.max(30, math.min(screen.HEIGHT - 30, p.y + pullY))
      end
    end

    -- Scarlet Rot zones: DOT damage
    if not p.invulnerable then
      local rotDamage = sectorzboss.checkRotZoneDamage(p.x, p.y, 20)
      if rotDamage > 0 then
        player.takeDamage(p, rotDamage)
        particles.spawn(p.x, p.y, 8, {0.8, 0.2, 0.1})
      end
    end
  end

  -- Warden boss special mechanics
  if wardenboss.isActive() then
    local p = gameState.player

    -- Void Prison zones: DOT damage
    if not p.invulnerable then
      local prisonDamage = wardenboss.checkPrisonZoneDamage(p.x, p.y, 20)
      if prisonDamage > 0 then
        player.takeDamage(p, prisonDamage)
        particles.spawn(p.x, p.y, 8, {0.6, 0.2, 0.8})
      end
    end
  end

  -- Sentinel boss special mechanics
  if sentinelboss.isActive() then
    local p = gameState.player

    -- Gravity Well: pull player toward boss (Phase 5)
    local gx, gy, strength = sentinelboss.getGravityPull()
    if strength and strength > 0 then
      local dx = gx - p.x
      local dy = gy - p.y
      local dist = math.sqrt(dx*dx + dy*dy)
      if dist > 1 then
        local pullX = (dx / dist) * strength * love.timer.getDelta()
        local pullY = (dy / dist) * strength * love.timer.getDelta()
        p.x = math.max(30, math.min(screen.WIDTH - 30, p.x + pullX))
        p.y = math.max(30, math.min(screen.HEIGHT - 30, p.y + pullY))
      end
    end

    -- EMP zones: DOT damage
    if not p.invulnerable then
      local empDamage = sentinelboss.checkEmpZoneDamage(p.x, p.y, 20)
      if empDamage > 0 then
        player.takeDamage(p, empDamage)
        particles.spawn(p.x, p.y, 8, {0.2, 0.6, 1.0})
      end
    end
  end

  -- Megalith of Memories special mechanics
  if megalith.isActive() then
    local p = gameState.player
    local mb = megalith.boss

    -- Gravity Well (Act III)
    local gx, gy, strength = megalith.getGravityPull()
    if strength and strength > 0 then
      local dx = gx - p.x
      local dy = gy - p.y
      local dist = math.sqrt(dx*dx + dy*dy)
      if dist > 1 then
        local pullX = (dx / dist) * strength * love.timer.getDelta()
        local pullY = (dy / dist) * strength * love.timer.getDelta()
        p.x = math.max(30, math.min(screen.WIDTH - 30, p.x + pullX))
        p.y = math.max(30, math.min(screen.HEIGHT - 30, p.y + pullY))
      end
    end

    if not p.invulnerable then
      -- Memory leak zones (Act I)
      local leakDmg = megalith.checkMemoryLeakDamage(p.x, p.y, 20)
      if leakDmg > 0 then
        player.takeDamage(p, leakDmg)
        particles.spawn(p.x, p.y, 8, {0.3, 1, 0.4})
      end

      -- Bad sector zones (Act II)
      local sectorDmg = megalith.checkBadSectorDamage(p.x, p.y, 20)
      if sectorDmg > 0 then
        player.takeDamage(p, sectorDmg)
        particles.spawn(p.x, p.y, 8, {0.8, 0.3, 0.1})
      end

      -- Seek arm (Act II)
      local seekDmg = megalith.checkSeekArmHit(p.x, p.y, p.width, p.height)
      if seekDmg > 0 then
        player.takeDamage(p, seekDmg)
        particles.spawn(p.x, p.y, 12, {0.6, 0.6, 0.6})
      end

      -- Boulder sweep (Act II)
      local boulderDmg = megalith.checkBoulderSweepHit(p.x, p.y, p.width, p.height)
      if boulderDmg > 0 then
        player.takeDamage(p, boulderDmg)
        particles.spawn(p.x, p.y, 12, {0.5, 0.4, 0.3})
      end

      -- Data surge (Act I)
      local surgeDmg = megalith.checkDataSurgeHit(p.x, p.y, 20)
      if surgeDmg > 0 then
        player.takeDamage(p, surgeDmg)
        particles.spawn(p.x, p.y, 10, {0, 1, 1})
      end

      -- Spindle lasers (Act III)
      local spindleDmg = megalith.checkSpindleLaserHit(p.x, p.y, 20)
      if spindleDmg > 0 then
        player.takeDamage(p, spindleDmg)
        particles.spawn(p.x, p.y, 10, {1, 0.8, 0.2})
      end

      -- Magnetic pulse (Act III)
      local pulseDmg = megalith.checkMagneticPulseHit(p.x, p.y, 20)
      if pulseDmg > 0 then
        player.takeDamage(p, pulseDmg)
        particles.spawn(p.x, p.y, 15, {0.4, 0.2, 1})
      end

      -- Platter edges (Act III)
      local platterDmg = megalith.checkPlatterHit(p.x, p.y, 20)
      if platterDmg > 0 then
        player.takeDamage(p, platterDmg)
        particles.spawn(p.x, p.y, 8, {0.7, 0.7, 0.7})
      end

      -- Actuator arms (Act III)
      local armDmg = megalith.checkActuatorArmHit(p.x, p.y, 20)
      if armDmg > 0 then
        player.takeDamage(p, armDmg)
        particles.spawn(p.x, p.y, 10, {0.5, 0.3, 0.1})
      end

      -- Debris (Act III)
      local debrisDmg = megalith.checkDebrisHit(p.x, p.y, p.width, p.height)
      if debrisDmg > 0 then
        player.takeDamage(p, debrisDmg)
        particles.spawn(p.x, p.y, 12, {0.6, 0.4, 0.2})
      end
    end

    -- Puzzle gate checks (Act I)
    if mb.puzzleActive then
      megalith.checkPuzzleGate(p.x, p.y, p.width, p.height)
    end
  end

  -- Distant Dynamo special mechanics
  if dynamoboss.isActive() then
    local p = gameState.player
    local db = dynamoboss.boss

    -- Magnetic pull (Phase 5+)
    local gx, gy, strength = dynamoboss.getGravityPull()
    if strength and strength > 0 then
      local dx = gx - p.x
      local dy = gy - p.y
      local dist = math.sqrt(dx*dx + dy*dy)
      if dist > 1 then
        local pullX = (dx / dist) * strength * love.timer.getDelta()
        local pullY = (dy / dist) * strength * love.timer.getDelta()
        p.x = math.max(30, math.min(screen.WIDTH - 30, p.x + pullX))
        p.y = math.max(30, math.min(screen.HEIGHT - 30, p.y + pullY))
      end
    end

    if not p.invulnerable then
      -- Capacitor zone DOT (Phase 3+)
      local capDmg = dynamoboss.checkCapacitorZoneDamage(p.x, p.y, 20)
      if capDmg > 0 then
        player.takeDamage(p, capDmg)
        particles.spawn(p.x, p.y, 8, {1, 0.6, 0.1})
      end

      -- Cable obstacle collisions
      local cableDmg = dynamoboss.checkCableCollision(p.x, p.y, 20)
      if cableDmg > 0 then
        player.takeDamage(p, cableDmg)
        particles.spawn(p.x, p.y, 10, {0.9, 0.4, 0.05})
      end

      -- Inductor blade collisions (Phase 4+)
      local inductorDmg = dynamoboss.checkInductorCollision(p.x, p.y, 20)
      if inductorDmg > 0 then
        player.takeDamage(p, inductorDmg)
        particles.spawn(p.x, p.y, 12, {1, 0.5, 0.15})
      end

      -- Arc flash wave damage (Phase 5+)
      local arcDmg = dynamoboss.checkArcFlashDamage(p.x, p.y, 20)
      if arcDmg > 0 then
        player.takeDamage(p, arcDmg)
        particles.spawn(p.x, p.y, 10, {1, 0.7, 0.2})
      end

      -- Overload pulse damage (Phase 7+)
      local overloadDmg = dynamoboss.checkOverloadDamage(p.x, p.y, 20)
      if overloadDmg > 0 then
        player.takeDamage(p, overloadDmg)
        particles.spawn(p.x, p.y, 15, {1, 0.3, 0.05})
      end
    end
  end

  -- Synesthesia Installation special mechanics
  if synesthesia.isActive() or synesthesia.isBossActive() then
    local p = gameState.player

    -- Gravity pull (Tensor Core phase)
    local gx, gy, strength = synesthesia.getGravityPull()
    if strength and strength > 0 then
      local dx = gx - p.x
      local dy = gy - p.y
      local dist = math.sqrt(dx*dx + dy*dy)
      if dist > 1 then
        local pullX = (dx / dist) * strength * love.timer.getDelta()
        local pullY = (dy / dist) * strength * love.timer.getDelta()
        p.x = math.max(30, math.min(screen.WIDTH - 30, p.x + pullX))
        p.y = math.max(30, math.min(screen.HEIGHT - 30, p.y + pullY))
      end
    end

    if not p.invulnerable and not p.barrelRolling then
      -- Heatsink fin collisions (terrain section)
      local finHit, finDmg = synesthesia.checkFinCollision(p.x, p.y, p.width, p.height)
      if finHit then
        player.takeDamage(p, finDmg)
        particles.spawn(p.x, p.y, 10, {0.6, 0.6, 0.7})
      end

      -- Circuit trace arc damage (terrain section)
      local arcHit, arcDmg = synesthesia.checkTraceArcDamage(p.x, p.y, 20)
      if arcHit then
        player.takeDamage(p, arcDmg)
        particles.spawn(p.x, p.y, 12, {0.2, 0.8, 1})
      end

      -- Capacitor boulder collisions (terrain section)
      local boulderHit, boulderDmg = synesthesia.checkBoulderCollision(p.x, p.y, p.width, p.height)
      if boulderHit then
        player.takeDamage(p, boulderDmg)
        particles.spawn(p.x, p.y, 12, {0.4, 0.3, 0.2})
      end

      -- Laser grid damage (terrain section)
      local gridHit, gridDmg = synesthesia.checkLaserGridDamage(p.x, p.y, 20)
      if gridHit then
        player.takeDamage(p, gridDmg)
        particles.spawn(p.x, p.y, 10, {1, 0.2, 0.2})
      end

      -- VRM explosion damage (terrain section)
      local vrmHit, vrmDmg = synesthesia.checkVRMDamage(p.x, p.y, 20)
      if vrmHit then
        player.takeDamage(p, vrmDmg)
        particles.spawn(p.x, p.y, 15, {1, 0.6, 0})
      end

      -- PCB bridge collapse damage (terrain section)
      local bridgeHit, bridgeDmg = synesthesia.checkBridgeDamage(p.x, p.y, p.width, p.height)
      if bridgeHit then
        player.takeDamage(p, bridgeDmg)
        particles.spawn(p.x, p.y, 8, {0.3, 0.5, 0.2})
      end

      -- Overclock zone DOT (boss phase)
      local oclkDmg = synesthesia.checkOverclockZoneDamage(p.x, p.y, 20)
      if oclkDmg > 0 then
        player.takeDamage(p, oclkDmg)
        particles.spawn(p.x, p.y, 8, {1, 0.4, 0})
      end

      -- Thermal throttle wave damage (boss phase)
      local thermDmg = synesthesia.checkThermalWaveDamage(p.x, p.y, 20)
      if thermDmg > 0 then
        player.takeDamage(p, thermDmg)
        particles.spawn(p.x, p.y, 12, {1, 0.3, 0.1})
      end

      -- Raytrace bouncing beam damage (boss phase)
      local rayDmg = synesthesia.checkRaytraceBeamDamage(p.x, p.y, 20)
      if rayDmg > 0 then
        player.takeDamage(p, rayDmg)
        particles.spawn(p.x, p.y, 10, {0.5, 1, 0.5})
      end
    end
  end

  -- Logician's Lament special mechanics
  if raidboss.isActive() then
    local p = gameState.player

    -- Gravity Well: pull player toward boss
    local gx, gy, strength = raidboss.getGravityPull()
    if strength and strength > 0 then
      local dx = gx - p.x
      local dy = gy - p.y
      local dist = math.sqrt(dx*dx + dy*dy)
      if dist > 1 then
        local pullX = (dx / dist) * strength * love.timer.getDelta()
        local pullY = (dy / dist) * strength * love.timer.getDelta()
        p.x = math.max(30, math.min(screen.WIDTH - 30, p.x + pullX))
        p.y = math.max(30, math.min(screen.HEIGHT - 30, p.y + pullY))
      end
    end

    if not p.invulnerable and not p.barrelRolling then
      -- Identity Disc damage
      local discDmg = raidboss.checkDiscDamage(p.x, p.y, 20)
      if discDmg > 0 then
        player.takeDamage(p, discDmg)
        particles.spawn(p.x, p.y, 12, {0, 0.9, 1})
      end

      -- Grid zone slam damage
      local gridDmg = raidboss.checkGridZoneDamage(p.x, p.y, 20)
      if gridDmg > 0 then
        player.takeDamage(p, gridDmg)
        particles.spawn(p.x, p.y, 10, {1, 0.5, 0})
      end

      -- Lightcycle wall damage
      local wallDmg = raidboss.checkLightWallDamage(p.x, p.y, 20)
      if wallDmg > 0 then
        player.takeDamage(p, wallDmg)
        particles.spawn(p.x, p.y, 10, {0, 0.9, 1})
      end

      -- Rolling capacitor boulder damage
      local boulderDmg = raidboss.checkBoulderDamage(p.x, p.y, 20)
      if boulderDmg > 0 then
        player.takeDamage(p, boulderDmg)
        particles.spawn(p.x, p.y, 15, {1, 0.5, 0})
      end

      -- Via pit trap damage
      local pitDmg = raidboss.checkPitTrapDamage(p.x, p.y, 20)
      if pitDmg > 0 then
        player.takeDamage(p, pitDmg)
        particles.spawn(p.x, p.y, 10, {0.6, 0.3, 0})
      end

      -- Overclock EMP pulse damage
      local empDmg = raidboss.checkOverclockDamage(p.x, p.y, 20)
      if empDmg > 0 then
        player.takeDamage(p, empDmg)
        particles.spawn(p.x, p.y, 15, {0.3, 0.5, 1})
      end

      -- Cache flood damage
      local cacheDmg = raidboss.checkCacheFloodDamage(p.x, p.y, 20)
      if cacheDmg > 0 then
        player.takeDamage(p, cacheDmg)
        particles.spawn(p.x, p.y, 10, {0, 1, 0.3})
      end

      -- Derez beam damage
      local derezDmg = raidboss.checkDerezBeamDamage(p.x, p.y, 20)
      if derezDmg > 0 then
        player.takeDamage(p, derezDmg)
        particles.spawn(p.x, p.y, 12, {0.8, 0.2, 1})
      end

      -- Swinging blade damage (Indiana Jones)
      local bladeDmg = raidboss.checkBladeCollision(p.x, p.y, 20)
      if bladeDmg > 0 then
        player.takeDamage(p, bladeDmg)
        particles.spawn(p.x, p.y, 12, {1, 0.2, 0})
      end
    end
  end

  -- Raid PCB terrain collision
  if raid.isActive() then
    local p = gameState.player
    if not p.invulnerable and not p.barrelRolling then
      local compDmg = raid.checkComponentCollision(p.x, p.y, p.width, p.height)
      if compDmg > 0 then
        player.takeDamage(p, compDmg)
        particles.spawn(p.x, p.y, 8, {0.5, 0.5, 0.5})
      end

      local hazardDmg = raid.checkHazardCollision(p.x, p.y, p.width, p.height)
      if hazardDmg > 0 then
        player.takeDamage(p, hazardDmg)
        particles.spawn(p.x, p.y, 10, {1, 0.8, 0})
      end
    end

    -- Puzzle gate blocking
    if raid.checkGateCollision(p.x, p.y, p.width, p.height) then
      -- Push player back slightly
      p.y = p.y + 2
    end
  end

  -- The Sphere special mechanics
  if sphereboss.isActive() then
    local p = gameState.player
    local spb = sphereboss.boss

    -- Phase 2: Gravity tether pull
    if spb.phase == 2 then
      local pullX, pullY, maxStr = sphereboss.getGravityTetherPull(p.x, p.y)
      if maxStr and maxStr > 0 then
        p.x = math.max(30, math.min(screen.WIDTH - 30, p.x + pullX * love.timer.getDelta()))
        p.y = math.max(30, math.min(screen.HEIGHT - 30, p.y + pullY * love.timer.getDelta()))
      end

      -- Gravity tether DOT damage
      if not p.invulnerable then
        local tetherDmg = sphereboss.checkTetherDamage(p.x, p.y, 20)
        if tetherDmg > 0 then
          player.takeDamage(p, tetherDmg)
          particles.spawn(p.x, p.y, 8, {0.3, 0.5, 1})
        end
      end

      -- Laser ring damage
      if not p.invulnerable and not p.barrelRolling then
        if sphereboss.checkLaserRingHit(p.x, p.y, 20) then
          player.takeDamage(p, 18)
          particles.spawn(p.x, p.y, 15, {1, 0.4, 0.1})
        end
      end
    end

    -- Phase 4: Barrel roll near clone to stun it (reflect mechanic)
    if spb.phase == 4 and spb.clone and not spb.clone.stunned and p.barrelRolling then
      local c = spb.clone
      local dist = math.sqrt((p.x - c.x)^2 + (p.y - c.y)^2)
      if dist < 80 then
        sphereboss.stunClone(3)
        particles.spawn(c.x, c.y, 20, {0.5, 0.5, 1})
      end
    end
  end

  -- The Machine special mechanics
  if machineboss.isActive() then
    local p = gameState.player
    local mb = machineboss.boss
    local dt = love.timer.getDelta()

    -- Magnetic pull (Phase 11+)
    local pullX, pullY, pullStr = machineboss.getGravityPull()
    if pullStr > 0 then
      local dx = pullX - p.x
      local dy = pullY - p.y
      local dist = math.sqrt(dx * dx + dy * dy)
      if dist > 10 then
        local pullForce = pullStr * 120
        p.x = math.max(30, math.min(screen.WIDTH - 30, p.x + (dx / dist) * pullForce * dt))
        p.y = math.max(30, math.min(screen.HEIGHT - 30, p.y + (dy / dist) * pullForce * dt))
      end
    end

    -- Steam vent DOT (Phase 3+)
    if not p.invulnerable then
      local steamDmg = machineboss.checkSteamVentDamage(p.x, p.y, 15)
      if steamDmg > 0 then
        player.takeDamage(p, steamDmg)
        particles.spawn(p.x, p.y, 8, {0.8, 0.8, 0.8})
      end
    end

    -- Molten slag DOT (Phase 8+)
    if not p.invulnerable then
      local slagDmg = machineboss.checkSlagZoneDamage(p.x, p.y, 15)
      if slagDmg > 0 then
        player.takeDamage(p, slagDmg)
        particles.spawn(p.x, p.y, 10, {1, 0.4, 0})
      end
    end

    -- Gear crush damage (Phase 4+)
    if not p.invulnerable and not p.barrelRolling then
      local gearDmg = machineboss.checkGearDamage(p.x, p.y, 15)
      if gearDmg > 0 then
        player.takeDamage(p, gearDmg)
        particles.spawn(p.x, p.y, 12, {0.6, 0.6, 0.6})
      end
    end

    -- Turbine blade instant-kill zone (Phase 13+)
    if not p.invulnerable and not p.barrelRolling then
      local turbDmg = machineboss.checkTurbineDamage(p.x, p.y, 15)
      if turbDmg > 0 then
        player.takeDamage(p, turbDmg)
        particles.spawn(p.x, p.y, 20, {1, 0.2, 0.2})
      end
    end

    -- Conveyor push (Phase 12+)
    local pushX, pushY = machineboss.checkConveyorPush(p.x, p.y)
    if pushX ~= 0 or pushY ~= 0 then
      p.x = math.max(30, math.min(screen.WIDTH - 30, p.x + pushX * dt))
      p.y = math.max(30, math.min(screen.HEIGHT - 30, p.y + pushY * dt))
    end

    -- Quantum cut damage (Phase 15+)
    if not p.invulnerable and not p.barrelRolling then
      local qDmg = machineboss.checkQuantumCutDamage(p.x, p.y, 15)
      if qDmg > 0 then
        player.takeDamage(p, qDmg)
        particles.spawn(p.x, p.y, 15, {0.8, 0.2, 1})
      end
    end

    -- Time dilation slow + DOT (Phase 16+)
    local slowFactor = machineboss.checkTimeFieldSlow(p.x, p.y)
    if slowFactor < 1 then
      -- Slow player movement (applied via speed multiplier effect)
      p.speedMultiplier = slowFactor
    else
      if p.speedMultiplier and p.speedMultiplier < 1 then
        p.speedMultiplier = 1
      end
    end

    if not p.invulnerable then
      local timeDmg = machineboss.checkTimeFieldDamage(p.x, p.y, 15)
      if timeDmg > 0 then
        player.takeDamage(p, timeDmg)
        particles.spawn(p.x, p.y, 8, {0.5, 0.3, 1})
      end
    end

    -- Barrier collision (push player)
    if machineboss.checkBarrierCollision(p.x, p.y, 15) then
      if not p.invulnerable and not p.barrelRolling then
        player.takeDamage(p, 15)
        particles.spawn(p.x, p.y, 10, {0.7, 0.7, 0.7})
      end
      -- Push player away from center of boss
      local dx = p.x - mb.x
      local dy = p.y - mb.y
      local dist = math.sqrt(dx * dx + dy * dy)
      if dist > 5 then
        p.x = math.max(30, math.min(screen.WIDTH - 30, p.x + (dx / dist) * 100 * dt))
        p.y = math.max(30, math.min(screen.HEIGHT - 30, p.y + (dy / dist) * 100 * dt))
      end
    end
  end
end

function M.checkPortals()
  if portals.checkCollision(gameState.player.x, gameState.player.y) then
    particles.spawn(gameState.player.x, gameState.player.y, 20, {0.5, 0.8, 1})

    if portals.getCollected() == 3 then
      wingmen.triggerWarpProgress()
    elseif portals.getCollected() == 6 then
      wingmen.triggerWarpAlmost()
    elseif portals.isWarpReady() then
      wingmen.triggerWarpReady()
    end
  end

  -- Check for warp victory (alternate ending)
  if portals.isWarpReady() and terrain.getLevelTime() > 60 then
    portals.triggerWarp()
    gameState.state = "warp"
  end
end

function M.checkHit(laser, entity)
  return laser.x > entity.x - entity.width/2 and
         laser.x < entity.x + entity.width/2 and
         laser.y > entity.y - entity.height/2 and
         laser.y < entity.y + entity.height/2
end

function M.checkHitRect(laser, entity)
  return laser.x > entity.x - entity.width/2 and
         laser.x < entity.x + entity.width/2 and
         laser.y > entity.y - entity.height/2 and
         laser.y < entity.y + entity.height/2
end

function M.checkHitPlayer(entity, p)
  local dist = math.sqrt((entity.x - p.x)^2 + (entity.y - p.y)^2)
  return dist < 25
end

function M.checkHitCircle(laser, cx, cy, radius)
  local dist = math.sqrt((laser.x - cx)^2 + (laser.y - cy)^2)
  return dist < radius
end

function M.checkHitBox(a, b)
  return a.x - a.width/2 < b.x + b.width/2 and
         a.x + a.width/2 > b.x - b.width/2 and
         a.y - a.height/2 < b.y + b.height/2 and
         a.y + a.height/2 > b.y - b.height/2
end

function M.draw()
  if gameState.state == "intro" then
    ui.drawBackground()
    ui.drawPlayer(gameState.player, gameState.introTimer)
    ui.drawIntro(gameState.introTimer, levels.getName(gameState.levelId), gameState.levelId, levels.getEnemyCount(gameState.levelId))
  elseif gameState.state == "levelselect" then
    ui.drawLevelSelect()
  elseif gameState.state == "levelselect_paused" then
    -- Draw level select in background
    ui.drawLevelSelect()
    -- Draw pause menu overlay
    ui.drawPauseMenu(gameState.pauseMenuIndex, true)
  elseif gameState.state == "levelselect_options" then
    -- Draw level select in background
    ui.drawLevelSelect()
    -- Draw options menu overlay
    ui.drawOptionsMenu()
  elseif gameState.state == "playing" then
    ui.drawBackground()
    ui.drawPortals()
    ui.drawTurrets()
    ui.drawCapitalShips()
    ui.drawMothership()
    ui.drawEnemies()
    ui.drawBoss()
    ui.drawBolseStation()
    ui.drawVenomBoss()
    ui.drawSectorZBoss()
    ui.drawWardenBoss()
    ui.drawSentinelBoss()
    ui.drawMegalith()
    ui.drawDynamoBoss()
    ui.drawSynesthesia()
    ui.drawSphereBoss()
    ui.drawMachineBoss()
    raid.draw()
    raidboss.draw()
    ui.drawMaze()
    ui.drawRival()
    ui.drawRivalLasers()
    ui.drawLasers()
    ui.drawMissiles()
    ui.drawShotgunPellets()
    ui.drawChargedBlasts()
    ui.drawTargetingCrosshairs(gameState.player)
    ui.drawBombs()
    ui.drawWingmen()
    ui.drawAllies()
    ui.drawPlayer(gameState.player)
    abilities.drawEffects(gameState.player)
    ui.drawParticles()
    bossexplosion.draw()
    -- Aquas: Draw front fog cloud layer over everything (like flying through clouds)
    if ui.isAquas() then
      ui.drawFogClouds("front")
    end
    -- Draw Prototype encounter
    if prototype.isActive() then
      prototype.draw()
    end
    ui.drawHUD(gameState.player, terrain.getLevelTime(), boss.isActive(), levels.getName(gameState.levelId), portals.getCollected(), gameState.totalEnemiesSpawned)

    -- Draw Muse power visual effects
    -- Melo: time slow red tint
    if muses.isTimeSlowed() then
      love.graphics.setColor(0.8, 0.3, 0.3, 0.06 + math.sin(love.timer.getTime() * 2) * 0.03)
      love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
    end

    -- Djolt: chain lightning arcs
    for _, arc in ipairs(chainLightningArcs) do
      local segments = 6
      local prevX, prevY = arc.x1, arc.y1
      for s = 1, segments do
        local t = s / segments
        local nx = arc.x1 + (arc.x2 - arc.x1) * t + (math.random() - 0.5) * 20
        local ny = arc.y1 + (arc.y2 - arc.y1) * t + (math.random() - 0.5) * 20
        if s == segments then nx, ny = arc.x2, arc.y2 end
        love.graphics.setColor(arc.color[1], arc.color[2], arc.color[3], arc.timer * 1.5)
        love.graphics.setLineWidth(3)
        love.graphics.line(prevX, prevY, nx, ny)
        love.graphics.setColor(1, 1, 1, arc.timer * 2)
        love.graphics.setLineWidth(1)
        love.graphics.line(prevX, prevY, nx, ny)
        prevX, prevY = nx, ny
      end
    end

    -- Clarity: golden shimmer
    if muses.hasClarity() then
      love.graphics.setColor(0.9, 0.85, 0.4, 0.04 + math.sin(love.timer.getTime() * 1.5) * 0.02)
      love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
    end

    -- Muse HUD
    muses.drawMuseHUD()

    supershot.draw()
  elseif gameState.state == "prototype_acquired" then
    -- Draw game frozen in background
    ui.drawBackground()
    ui.drawPortals()
    ui.drawEnemies()
    ui.drawLasers()
    ui.drawPlayer(gameState.player)
    ui.drawParticles()
    -- Draw the acquisition screen overlay
    prototype.drawAcquisitionScreen(love.timer.getTime())
  elseif gameState.state == "gameover" then
    ui.drawBackground()
    ui.drawParticles()
    ui.drawGameOver(gameState.player.enemiesDefeated)
  elseif gameState.state == "playerdeath" then
    -- Draw the battle scene without the player ship
    ui.drawBackground()
    ui.drawTurrets()
    ui.drawCapitalShips()
    ui.drawMothership()
    ui.drawEnemies()
    ui.drawBoss()
    ui.drawBolseStation()
    ui.drawVenomBoss()
    ui.drawSectorZBoss()
    ui.drawWardenBoss()
    ui.drawSentinelBoss()
    ui.drawMegalith()
    ui.drawDynamoBoss()
    ui.drawSynesthesia()
    ui.drawSphereBoss()
    ui.drawMachineBoss()
    raid.draw()
    raidboss.draw()
    ui.drawLasers()
    ui.drawParticles()
    bossexplosion.draw()
    -- Show respawn countdown
    ui.drawRespawnCountdown(gameState.deathRespawnTimer)
    ui.drawHUD(gameState.player, terrain.getLevelTime(), boss.isActive(), levels.getName(gameState.levelId), portals.getCollected(), gameState.totalEnemiesSpawned)
  elseif gameState.state == "victory" then
    ui.drawBackground()
    ui.drawVictory(gameState.player.enemiesDefeated, gameState.totalEnemiesSpawned, gameState.notesEarned)
  elseif gameState.state == "warp" then
    ui.drawBackground()
    ui.drawWarp(gameState.player.enemiesDefeated)
  elseif gameState.state == "postlevel" then
    ui.drawBackground()
    ui.drawPostLevelMenu(gameState.postLevelIndex)
  elseif gameState.state == "fadingtoportal" then
    ui.drawBackground()
    local fadeAlpha = gameState.fadeTimer / gameState.fadeDuration
    love.graphics.setColor(0, 0, 0, fadeAlpha)
    love.graphics.rectangle("fill", 0, 0, screen.WIDTH, screen.HEIGHT)
  elseif gameState.state == "fadingtostation" then
    ui.drawBackground()
    local fadeAlpha = gameState.fadeTimer / gameState.fadeDuration
    love.graphics.setColor(0, 0, 0, fadeAlpha)
    love.graphics.rectangle("fill", 0, 0, screen.WIDTH, screen.HEIGHT)
  elseif gameState.state == "restarting" then
    -- Draw current game state in background (same as playing state)
    ui.drawBackground()
    ui.drawPortals()
    ui.drawTurrets()
    ui.drawCapitalShips()
    ui.drawMothership()
    ui.drawEnemies()
    ui.drawBoss()
    ui.drawBolseStation()
    ui.drawVenomBoss()
    ui.drawSectorZBoss()
    ui.drawWardenBoss()
    ui.drawSentinelBoss()
    ui.drawMegalith()
    ui.drawDynamoBoss()
    ui.drawSynesthesia()
    ui.drawSphereBoss()
    ui.drawMachineBoss()
    raid.draw()
    raidboss.draw()
    ui.drawMaze()
    ui.drawRival()
    ui.drawRivalLasers()
    ui.drawLasers()
    ui.drawMissiles()
    ui.drawShotgunPellets()
    ui.drawChargedBlasts()
    ui.drawTargetingCrosshairs(gameState.player)
    ui.drawBombs()
    ui.drawWingmen()
    ui.drawAllies()
    ui.drawPlayer(gameState.player)
    abilities.drawEffects(gameState.player)
    ui.drawParticles()
    bossexplosion.draw()
    ui.drawHUD(gameState.player, terrain.getLevelTime(), boss.isActive(), levels.getName(gameState.levelId), portals.getCollected(), gameState.totalEnemiesSpawned)
    supershot.draw()
    -- White fade overlay
    local fadeAlpha = gameState.fadeTimer / gameState.fadeDuration
    love.graphics.setColor(1, 1, 1, fadeAlpha)
    love.graphics.rectangle("fill", 0, 0, screen.WIDTH, screen.HEIGHT)
  elseif gameState.state == "paused" then
    -- Draw game in background
    ui.drawBackground()
    ui.drawPortals()
    ui.drawTurrets()
    ui.drawCapitalShips()
    ui.drawMothership()
    ui.drawEnemies()
    ui.drawBoss()
    ui.drawBolseStation()
    ui.drawVenomBoss()
    ui.drawSectorZBoss()
    ui.drawWardenBoss()
    ui.drawSentinelBoss()
    ui.drawMegalith()
    ui.drawDynamoBoss()
    ui.drawSynesthesia()
    ui.drawSphereBoss()
    ui.drawMachineBoss()
    raid.draw()
    raidboss.draw()
    ui.drawMaze()
    ui.drawRival()
    ui.drawRivalLasers()
    ui.drawLasers()
    ui.drawMissiles()
    ui.drawShotgunPellets()
    ui.drawChargedBlasts()
    ui.drawTargetingCrosshairs(gameState.player)
    ui.drawBombs()
    ui.drawWingmen()
    ui.drawAllies()
    ui.drawPlayer(gameState.player)
    abilities.drawEffects(gameState.player)
    ui.drawParticles()
    bossexplosion.draw()
    ui.drawHUD(gameState.player, terrain.getLevelTime(), boss.isActive(), levels.getName(gameState.levelId), portals.getCollected(), gameState.totalEnemiesSpawned)
    supershot.draw()
    -- Draw pause menu overlay
    ui.drawPauseMenu(gameState.pauseMenuIndex, false, M.enteredFromPortal)
  elseif gameState.state == "options" then
    -- Draw game in background
    ui.drawBackground()
    ui.drawPortals()
    ui.drawTurrets()
    ui.drawCapitalShips()
    ui.drawMothership()
    ui.drawEnemies()
    ui.drawBoss()
    ui.drawBolseStation()
    ui.drawVenomBoss()
    ui.drawSectorZBoss()
    ui.drawWardenBoss()
    ui.drawSentinelBoss()
    ui.drawMegalith()
    ui.drawDynamoBoss()
    ui.drawSynesthesia()
    ui.drawSphereBoss()
    ui.drawMachineBoss()
    raid.draw()
    raidboss.draw()
    ui.drawMaze()
    ui.drawRival()
    ui.drawRivalLasers()
    ui.drawLasers()
    ui.drawMissiles()
    ui.drawShotgunPellets()
    ui.drawChargedBlasts()
    ui.drawTargetingCrosshairs(gameState.player)
    ui.drawBombs()
    ui.drawWingmen()
    ui.drawAllies()
    ui.drawPlayer(gameState.player)
    abilities.drawEffects(gameState.player)
    ui.drawParticles()
    bossexplosion.draw()
    ui.drawHUD(gameState.player, terrain.getLevelTime(), boss.isActive(), levels.getName(gameState.levelId), portals.getCollected(), gameState.totalEnemiesSpawned)
    supershot.draw()
    -- Draw options menu overlay
    ui.drawOptionsMenu()
  end
end

function M.keypressed(key)
  if gameState.state == "levelselect" then
    if key == "up" then
      levelselect.navigate("up")
    elseif key == "down" then
      levelselect.navigate("down")
    elseif key == "left" then
      levelselect.navigate("left")
    elseif key == "right" then
      levelselect.navigate("right")
    elseif key == "space" or key == "return" then
      M.startGame()
    elseif key == "escape" then
      gameState.state = "levelselect_paused"
      gameState.pauseMenuIndex = 1
    end
  elseif gameState.state == "levelselect_paused" then
    if key == "escape" then
      gameState.state = "levelselect"
    elseif key == "up" then
      gameState.pauseMenuIndex = gameState.pauseMenuIndex - 1
      if gameState.pauseMenuIndex < 1 then
        gameState.pauseMenuIndex = 3
      end
    elseif key == "down" then
      gameState.pauseMenuIndex = gameState.pauseMenuIndex + 1
      if gameState.pauseMenuIndex > 3 then
        gameState.pauseMenuIndex = 1
      end
    elseif key == "return" or key == "space" then
      if gameState.pauseMenuIndex == 1 then
        -- Resume
        gameState.state = "levelselect"
      elseif gameState.pauseMenuIndex == 2 then
        -- Options (placeholder for now)
        gameState.state = "levelselect_options"
      elseif gameState.pauseMenuIndex == 3 then
        -- Exit to Station with fade to black
        gameState.state = "fadingtostation"
        gameState.fadeTimer = 0
        gameState.fadeDuration = 0.5
      end
    end
  elseif gameState.state == "playing" then
    -- Handle Prototype defeat dialogue first
    if prototype.hasDialogue() then
      if key == "return" or key == "e" then
        prototype.advanceDialogue()
        return
      end
    end

    if key == "escape" then
      gameState.state = "paused"
      gameState.pauseMenuIndex = 1
    elseif key == "z" then
      player.barrelRoll(gameState.player)
    elseif key == "x" then
      if player.useBomb(gameState.player) then
        weapons.fireBomb(gameState.player)
      end
    elseif key == "c" then
      player.switchWeapon(gameState.player)
    elseif key == "v" then
      -- Via transition in raid level
      if raid.isActive() then
        raid.tryViaTransition()
      end
    elseif key == "left" then
      player.tryDodge(gameState.player, "left")
    elseif key == "right" then
      player.tryDodge(gameState.player, "right")
    elseif key == "b" then
      -- Muse power activation (hold B)
      if muses.activePower and muses.canActivate() then
        museBHeld = true
        museBHoldTimer = 0
      end
    end
    -- Forward to morse input (special ability trigger)
    morseinput.keypressed(key)
  elseif gameState.state == "paused" then
    if key == "escape" then
      gameState.state = "playing"
    elseif key == "up" then
      gameState.pauseMenuIndex = gameState.pauseMenuIndex - 1
      if gameState.pauseMenuIndex < 1 then
        gameState.pauseMenuIndex = 5
      end
    elseif key == "down" then
      gameState.pauseMenuIndex = gameState.pauseMenuIndex + 1
      if gameState.pauseMenuIndex > 5 then
        gameState.pauseMenuIndex = 1
      end
    elseif key == "return" or key == "space" then
      if gameState.pauseMenuIndex == 1 then
        -- Resume
        gameState.state = "playing"
      elseif gameState.pauseMenuIndex == 2 then
        -- Restart Level with fade to white
        gameState.state = "restarting"
        gameState.fadeTimer = 0
        gameState.fadeDuration = 0.7
      elseif gameState.pauseMenuIndex == 3 then
        -- Options (placeholder for now)
        gameState.state = "options"
      elseif gameState.pauseMenuIndex == 4 then
        -- Return to Map/Portal
        if M.enteredFromPortal and M.returnToAsteroids then
          M.enteredFromPortal = false
          M.returnToAsteroids()
        else
          M.enterLevelSelect()
        end
      elseif gameState.pauseMenuIndex == 5 then
        -- Return to Station with fade to black
        M.enteredFromPortal = false
        gameState.state = "fadingtostation"
        gameState.fadeTimer = 0
        gameState.fadeDuration = 0.5
      end
    end
  elseif gameState.state == "options" then
    if key == "escape" then
      gameState.state = "paused"
    end
  elseif gameState.state == "levelselect_options" then
    if key == "escape" then
      gameState.state = "levelselect_paused"
    end
  elseif gameState.state == "prototype_acquired" then
    if key == "return" or key == "space" then
      -- Complete the quest, add ship to hangar
      prototype.completeQuest()
      -- Notify the hub via callback
      if M.onPrototypeAcquired then
        M.onPrototypeAcquired()
      end
      -- Return to playing state
      gameState.state = "playing"
    end
  elseif (gameState.state == "gameover" or gameState.state == "victory" or gameState.state == "warp") and key == "r" then
    -- Open post-level menu with 3 options
    gameState.state = "postlevel"
    gameState.postLevelIndex = 1
  elseif gameState.state == "postlevel" then
    if key == "up" then
      gameState.postLevelIndex = gameState.postLevelIndex - 1
      if gameState.postLevelIndex < 1 then
        gameState.postLevelIndex = 3
      end
    elseif key == "down" then
      gameState.postLevelIndex = gameState.postLevelIndex + 1
      if gameState.postLevelIndex > 3 then
        gameState.postLevelIndex = 1
      end
    elseif key == "return" or key == "space" then
      if gameState.postLevelIndex == 1 then
        -- Return to Portal (asteroids world map near portal) with fade to black
        if M.returnToAsteroids then
          M.enteredFromPortal = false
          -- Start fade to black, then call returnToAsteroids
          gameState.state = "fadingtoportal"
          gameState.fadeTimer = 0
          gameState.fadeDuration = 0.5
        else
          M.enterLevelSelect()
        end
      elseif gameState.postLevelIndex == 2 then
        -- Go To World Map (Lylat System level select)
        M.enterLevelSelect()
      elseif gameState.postLevelIndex == 3 then
        -- Return To Station (hub) with fade to black
        M.enteredFromPortal = false
        gameState.state = "fadingtostation"
        gameState.fadeTimer = 0
        gameState.fadeDuration = 0.5
      end
    end
  end
end

function M.getLevelId()
  return gameState.levelId
end

function M.getScore()
  if gameState.player then
    return gameState.player.enemiesDefeated
  end
  return 0
end

function M.keyreleased(key)
  if gameState.state == "playing" then
    morseinput.keyreleased(key)

    -- Muse power B-hold release
    if key == "b" and museBHeld then
      if muses.powerActive then
        -- Release hold — deactivate toggle powers (Melo, Tierra)
        if muses.activePower == "melo" or muses.activePower == "tierra" then
          muses.deactivate()
        end
      end
      museBHeld = false
      museBHoldTimer = 0
    end
  end
end

return M
