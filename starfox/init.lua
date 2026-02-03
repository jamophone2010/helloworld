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

local gameState = {}

function M.load()
  gameState.state = "menu"
  gameState.player = nil
  gameState.waveIndex = 1
  gameState.bossDefeated = false
  gameState.levelId = 1
  gameState.levelWaves = nil

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

  audio.load()
  ui.load()
end

function M.startGame()
  gameState.state = "playing"
  gameState.player = player.new()
  gameState.waveIndex = 1
  gameState.bossDefeated = false
  gameState.levelId = levelselect.getSelectedId()
  gameState.levelWaves = levels.getWaves(gameState.levelId)
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
end

function M.enterLevelSelect()
  gameState.state = "levelselect"
  levelselect.load()
end

function M.update(dt)
  if gameState.state == "playing" then
    M.updatePlaying(dt)
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

  terrain.update(dt)
  weapons.update(dt, gameState.player)

  if gameState.player.barrelRolling then
    weapons.mirrorProjectiles(gameState.player.x, gameState.player.y)
  end

  enemies.update(dt, gameState.player.x, gameState.player.y)
  turrets.update(dt, terrain.getScrollOffset(), gameState.player.x, gameState.player.y)
  capitalship.update(dt, gameState.player.x, gameState.player.y)
  mothership.update(dt, gameState.player.x, gameState.player.y)
  allies.update(dt, gameState.player.x, gameState.player.y, enemies.enemies)
  portals.update(dt)
  particles.update(dt)
  wingmen.update(dt, gameState.player.x, gameState.player.y)
  boss.update(dt, gameState.player.x, gameState.player.y)
  bolse.update(dt, gameState.player.x, gameState.player.y)
  rival.update(dt, gameState.player.x, gameState.player.y, weapons.lasers)
  rival.updateLasers(dt)
  maze.update(dt)
  venomboss.update(dt, gameState.player.x, gameState.player.y)

  M.spawnWaves()
  M.handleEnemyShooting()
  M.checkCollisions()
  M.checkPortals()

  if not player.isAlive(gameState.player) then
    gameState.state = "gameover"
  end

  if gameState.bossDefeated or mothership.isDefeated() or venomboss.isDefeated() then
    gameState.state = "victory"
  end
end

function M.spawnWaves()
  local levelTime = terrain.getLevelTime()
  local levelWaves = gameState.levelWaves

  while gameState.waveIndex <= #levelWaves do
    local wave = levelWaves[gameState.waveIndex]

    if levelTime >= wave.time then
      if wave.type == "wave" then
        enemies.spawnFormation(wave.formation, wave.x, -50, wave.count)
      elseif wave.type == "turret" then
        turrets.spawn(wave.x, terrain.getScrollOffset() - 100)
      elseif wave.type == "capitalship" then
        capitalship.spawn(wave.x)
      elseif wave.type == "mothership" then
        mothership.spawn(wave.x)
      elseif wave.type == "allies" then
        allies.spawnSquadron(gameState.player.x, gameState.player.y)
      elseif wave.type == "midboss" then
        boss.spawnMidBoss()
        wingmen.triggerBossWarning()
      elseif wave.type == "finalboss" then
        boss.spawnFinalBoss()
        wingmen.triggerBossWarning()
      elseif wave.type == "area6boss" then
        boss.spawnArea6Boss()
        wingmen.triggerBossWarning()
      elseif wave.type == "callout" then
        wingmen[wave.message]()
      elseif wave.type == "portal" then
        portals.spawn(wave.x)
      elseif wave.type == "bolsestation" then
        bolse.spawn(wave.x or 400)
      elseif wave.type == "rival" then
        rival.spawn(400, -50, wave.hp, wave.variant)
      elseif wave.type == "mazestart" then
        maze.activate()
      elseif wave.type == "mazewall" then
        maze.spawnWallRow(wave.pattern)
      elseif wave.type == "mazeend" then
        maze.deactivate()
      elseif wave.type == "venomboss" then
        venomboss.spawn()
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
  end

  -- Mothership spawning and shooting
  if mothership.isActive() then
    local m = mothership.mothership
    if m.shouldSpawnFighters then
      local positions = mothership.getSpawnPositions()
      for _, pos in ipairs(positions) do
        enemies.spawn(pos.x, pos.y, "fighter")
      end
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
      weapons.fireAllyLaser(ally.x, ally.y - 10, ally.targetX, ally.targetY)
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

function M.checkCollisions()
  for i = #weapons.lasers, 1, -1 do
    local laser = weapons.lasers[i]

    if laser.owner == "player" then
      for j = #enemies.enemies, 1, -1 do
        local enemy = enemies.enemies[j]
        if M.checkHit(laser, enemy) then
          if enemies.damage(enemy, laser.damage) then
            player.addScore(gameState.player, enemy.score)
            particles.spawn(enemy.x, enemy.y, 15, {1, 0.5, 0})
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
            player.addScore(gameState.player, turret.score)
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
            player.addScore(gameState.player, ship.score)
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
            player.addScore(gameState.player, b.score)
            particles.spawn(b.x, b.y, 30, {1, 0.5, 0})
            if b.type == "finalboss" or b.type == "area6boss" then
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
            player.addScore(gameState.player, m.score)
            particles.spawn(m.x, m.y, 40, {1, 0.5, 0})
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
                player.addScore(gameState.player, 100)
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
              player.addScore(gameState.player, s.score)
              particles.spawn(s.x, s.y, 40, {1, 0.5, 0})
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
              player.addScore(gameState.player, r.score)
              particles.spawn(r.x, r.y, 20, {1, 0.3, 0})
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
            player.addScore(gameState.player, vb.score)
            particles.spawn(vb.x, vb.y, 40, {1, 0.3, 0})
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

  -- Rival lasers vs player
  for i = #rival.getLasers(), 1, -1 do
    local laser = rival.getLasers()[i]
    if M.checkHitPlayer(laser, gameState.player) then
      player.takeDamage(gameState.player, laser.damage)
      table.remove(rival.getLasers(), i)
    end
  end

  for _, bomb in ipairs(weapons.bombs) do
    for j = #enemies.enemies, 1, -1 do
      local enemy = enemies.enemies[j]
      local dist = math.sqrt((bomb.x - enemy.x)^2 + (bomb.y - enemy.y)^2)
      if dist < bomb.radius then
        player.addScore(gameState.player, enemy.score)
        particles.spawn(enemy.x, enemy.y, 10, {1, 0.5, 0})
        enemies.remove(enemy)
      end
    end

    for j = #capitalship.ships, 1, -1 do
      local ship = capitalship.ships[j]
      local dist = math.sqrt((bomb.x - ship.x)^2 + (bomb.y - ship.y)^2)
      if dist < bomb.radius then
        if capitalship.damage(ship, bomb.damage) then
          player.addScore(gameState.player, ship.score)
          particles.spawn(ship.x, ship.y, 25, {1, 0.5, 0})
          capitalship.destroy(ship)
        end
      end
    end

    if boss.isActive() then
      local b = boss.currentBoss
      local dist = math.sqrt((bomb.x - b.x)^2 + (bomb.y - b.y)^2)
      if dist < bomb.radius then
        boss.damage(bomb.damage)
      end
    end

    if mothership.isActive() then
      local m = mothership.mothership
      local dist = math.sqrt((bomb.x - m.x)^2 + (bomb.y - m.y)^2)
      if dist < bomb.radius then
        local result = mothership.damage(bomb.damage)
        if result.dead then
          player.addScore(gameState.player, m.score)
          particles.spawn(m.x, m.y, 40, {1, 0.5, 0})
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
              player.addScore(gameState.player, 100)
              particles.spawn(turret.worldX, turret.worldY, 12, {1, 0.5, 0})
            end
          end
        end
      end
      if s.coreExposed then
        local dist = math.sqrt((bomb.x - s.x)^2 + (bomb.y - s.y)^2)
        if dist < bomb.radius then
          if bolse.damageCore(bomb.damage) then
            player.addScore(gameState.player, s.score)
            particles.spawn(s.x, s.y, 40, {1, 0.5, 0})
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
            player.addScore(gameState.player, r.score)
            particles.spawn(r.x, r.y, 20, {1, 0.3, 0})
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
          player.addScore(gameState.player, vb.score)
          particles.spawn(vb.x, vb.y, 40, {1, 0.3, 0})
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

  -- Maze wall collision with player
  if maze.isActive() then
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
    player.addScore(gameState.player, 100)

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

function M.draw()
  if gameState.state == "menu" then
    ui.drawMenu()
  elseif gameState.state == "levelselect" then
    ui.drawLevelSelect()
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
    ui.drawBombs()
    ui.drawWingmen()
    ui.drawAllies()
    ui.drawPlayer(gameState.player)
    ui.drawParticles()
    ui.drawHUD(gameState.player, terrain.getLevelTime(), boss.isActive(), levels.getName(gameState.levelId), portals.getCollected())
  elseif gameState.state == "gameover" then
    ui.drawBackground()
    ui.drawGameOver(gameState.player.score)
  elseif gameState.state == "victory" then
    ui.drawBackground()
    ui.drawVictory(gameState.player.score)
  elseif gameState.state == "warp" then
    ui.drawBackground()
    ui.drawWarp(gameState.player.score)
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
      gameState.state = "menu"
    end
  elseif gameState.state == "playing" then
    if key == "space" then
      if gameState.player.charging then
        weapons.releaseCharge(gameState.player)
      else
        weapons.shoot(gameState.player)
      end
    elseif key == "z" then
      player.barrelRoll(gameState.player)
    elseif key == "x" then
      if player.useBomb(gameState.player) then
        weapons.fireBomb(gameState.player)
      end
    elseif key == "left" then
      player.tryDodge(gameState.player, "left")
    elseif key == "right" then
      player.tryDodge(gameState.player, "right")
    end
  elseif (gameState.state == "gameover" or gameState.state == "victory" or gameState.state == "warp") and key == "r" then
    M.enterLevelSelect()
  end
end

return M
