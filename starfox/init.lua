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
local targeting = require("starfox.targeting")
local bossexplosion = require("starfox.bossexplosion")
local supershot = require("starfox.supershot")
local ships = require("starfox.ships")
local abilities = require("starfox.abilities")
local morseinput = require("starfox.morseinput")

local gameState = {}
local pendingShopItems = {lives = 0, bombs = 0, health = 0}

-- Progression callbacks (set by main.lua)
M.onMegaAntennaAwarded = nil
M.onPowerAmplifierAwarded = nil

-- Helper function to register kills for both score and supershot tracking
local function registerKill(p, score)
  player.addScore(p, score)
  supershot.registerKill()
  abilities.registerKill(gameState.levelId)
end

function M.load()
  gameState.state = "menu"
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
  targeting.reset()
  bossexplosion.reset()
  supershot.reset()
  abilities.reset()
  morseinput.reset()

  audio.load()
  ui.load()
end

function M.startGame()
  gameState.state = "playing"
  gameState.player = player.new()

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
  targeting.reset()
  bossexplosion.reset()
  supershot.reset()
  abilities.reset()
  morseinput.reset()

  -- Apply selected ship stats
  ships.applyToPlayer(gameState.player)

  -- Sector Y: Start with full special gauge
  if gameState.levelId == 3 then
    local def = ships.getSelectedDef()
    if def and def.hasSpecial then
      abilities.gauge = abilities.getGaugeMax()
    end
  end

  -- Re-apply shop health bonus after ship stats (additive to new max)
  if shopHealth > 0 then
    gameState.player.maxHealth = gameState.player.maxHealth + shopHealth
    gameState.player.health = gameState.player.maxHealth
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

-- Sync progression state from hub to levelselect
function M.setProgression(hasMegaAntenna, hasPowerAmplifier)
  levelselect.hasMegaAntenna = hasMegaAntenna or false
  levelselect.hasPowerAmplifier = hasPowerAmplifier or false
end

-- Set return to hub callback for station selection
function M.setReturnToHub(callback)
  levelselect.returnToHub = callback
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
  if gameState.state == "playing" then
    M.updatePlaying(dt)
  elseif gameState.state == "paused" or gameState.state == "options" then
    -- Don't update game logic when paused
  elseif gameState.state == "levelselect" or gameState.state == "levelselect_paused" or gameState.state == "levelselect_options" then
    levelselect.update(dt)
  elseif gameState.state == "victory" then
    terrain.update(dt)
    ui.updateVictory(dt)
  elseif gameState.state == "gameover" or gameState.state == "warp" then
    terrain.update(dt)
  end
end

function M.updatePlaying(dt)
  local dx, dy = 0, 0
  if love.keyboard.isDown("left") then dx = dx - 1 end
  if love.keyboard.isDown("right") then dx = dx + 1 end
  if love.keyboard.isDown("up") then dy = dy - 1 end
  if love.keyboard.isDown("down") then dy = dy + 1 end

  player.move(gameState.player, dx, dy)
  player.update(gameState.player, dt)

  -- Space: targeting/shooting (weapon-dependent)
  if love.keyboard.isDown("space") then
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

  -- Handle Lancer multi-lock expiry: auto-release all locks with barrage
  if not abilities.isMultiLockActive() and targeting.overrideMaxLocks then
    targeting.overrideMaxLocks = nil
    -- Release all locked targets as a barrage
    if targeting.active then
      local targets = targeting.releaseLocks()
      if #targets > 0 then
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
  end

  -- Barrel roll reflection (disabled during Paladin special)
  if gameState.player.barrelRolling and not abilities.shouldReflectBullets() then
    weapons.mirrorProjectiles(gameState.player.x, gameState.player.y, 40, false)  -- Smaller radius for barrel roll
  end

  local enemySpeedScale = abilities.getEnemySpeedScale()
  local attractEnemies = abilities.shouldAttractEnemies()
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

  supershot.update(dt)

  M.spawnWaves()
  if not abilities.shouldSuppressShooting() then
    M.handleEnemyShooting()
  end
  M.checkCollisions()
  M.checkSpartanLaserCollisions()
  M.checkPortals()

  if not player.isAlive(gameState.player) then
    gameState.state = "gameover"
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

  local bossVictory = gameState.bossDefeated or finalBossDefeated or mothership.isDefeated() or venomboss.isDefeated()

  -- Auto-victory only for levels without boss enemies
  -- Don't auto-complete levels that have/had bosses, motherships, etc.
  -- EXCEPT: Allow victory after midboss on Meteo (level 2) if it's the only boss
  local hasBossEnemy = boss.currentBoss ~= nil or
                       mothership.isActive() or mothership.isDefeated() or
                       bolse.isActive() or
                       rival.isActive() or
                       venomboss.isActive() or venomboss.isDefeated()

  local allWavesSpawned = gameState.waveIndex > #gameState.levelWaves
  local noEnemiesRemain = #enemies.enemies == 0 and
                          #turrets.turrets == 0 and
                          #capitalship.ships == 0 and
                          not boss.isActive() and
                          not bolse.isActive() and
                          not rival.isActive() and
                          not mothership.isActive() and
                          not venomboss.isActive()

  -- Only allow auto-victory if no boss enemies exist/existed in this level
  -- OR if midboss was defeated on Meteo (level 2)
  local autoVictory = allWavesSpawned and noEnemiesRemain and (not hasBossEnemy or (midbossOnlyDefeated and gameState.levelId == 2))

  if bossVictory or autoVictory then
    gameState.notesEarned = math.floor(gameState.player.enemiesDefeated / 10)
    ui.resetVictory()
    gameState.state = "victory"

    -- Award progression items for boss levels
    if gameState.levelId == 19 and M.onMegaAntennaAwarded then
      M.onMegaAntennaAwarded()
      levelselect.hasMegaAntenna = true
    elseif gameState.levelId == 20 and M.onPowerAmplifierAwarded then
      M.onPowerAmplifierAwarded()
      levelselect.hasPowerAmplifier = true
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
        bolse.spawn(wave.x or 400)
        gameState.totalEnemiesSpawned = gameState.totalEnemiesSpawned + 7
      elseif wave.type == "rival" then
        rival.spawn(400, -50, wave.hp, wave.variant)
        gameState.totalEnemiesSpawned = gameState.totalEnemiesSpawned + 1
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
        -- Warden boss (Inner Ring guardian)
        boss.spawnFinalBoss() -- Reuse finalboss logic
        boss.currentBoss.type = "wardenboss"
        boss.currentBoss.health = 80
        boss.currentBoss.maxHealth = 80
        boss.currentBoss.score = 800
        gameState.totalEnemiesSpawned = gameState.totalEnemiesSpawned + 1
        wingmen.triggerBossWarning()
      elseif wave.type == "sentinelboss" then
        -- Sentinel boss (Middle Ring guardian)
        boss.spawnFinalBoss() -- Reuse finalboss logic
        boss.currentBoss.type = "sentinelboss"
        boss.currentBoss.health = 120
        boss.currentBoss.maxHealth = 120
        boss.currentBoss.score = 1200
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
      if math.random() < 0.3 then
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
          gameState.bossDefeated = true
          weapons.stopSpartanLaser(gameState.player)
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
              gameState.bossDefeated = true
            else
              particles.spawn(r.x, r.y, 5, {1, 0.5, 0})
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

  -- Rival lasers vs player
  for i = #rival.getLasers(), 1, -1 do
    local laser = rival.getLasers()[i]
    if M.checkHitPlayer(laser, gameState.player) then
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
          gameState.bossDefeated = true
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
            gameState.bossDefeated = true
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
  if gameState.state == "menu" then
    ui.drawMenu()
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
  elseif gameState.state == "gameover" then
    ui.drawBackground()
    ui.drawGameOver(gameState.player.enemiesDefeated)
  elseif gameState.state == "victory" then
    ui.drawBackground()
    ui.drawVictory(gameState.player.enemiesDefeated, gameState.totalEnemiesSpawned, gameState.notesEarned)
  elseif gameState.state == "warp" then
    ui.drawBackground()
    ui.drawWarp(gameState.player.enemiesDefeated)
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
    ui.drawPauseMenu(gameState.pauseMenuIndex, false)
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
  if gameState.state == "menu" and key == "space" then
    M.enterLevelSelect()
  elseif gameState.state == "levelselect" then
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
        -- Exit to Station
        M.exitToHub()
      end
    end
  elseif gameState.state == "playing" then
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
    elseif key == "left" then
      player.tryDodge(gameState.player, "left")
    elseif key == "right" then
      player.tryDodge(gameState.player, "right")
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
        -- Restart Level
        M.startGame()
      elseif gameState.pauseMenuIndex == 3 then
        -- Options (placeholder for now)
        gameState.state = "options"
      elseif gameState.pauseMenuIndex == 4 then
        -- Return to Map
        M.enterLevelSelect()
      elseif gameState.pauseMenuIndex == 5 then
        -- Return to Station
        M.exitToHub()
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
  elseif (gameState.state == "gameover" or gameState.state == "victory" or gameState.state == "warp") and key == "r" then
    M.enterLevelSelect()
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
  end
end

return M
