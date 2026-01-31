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

local gameState = {}

local LEVEL_WAVES = {
  {time = 2, type = "wave", formation = "v", x = 400, count = 5},
  {time = 8, type = "wave", formation = "line", x = 400, count = 4},
  {time = 15, type = "wave", formation = "v", x = 300, count = 5},
  {time = 20, type = "wave", formation = "v", x = 500, count = 5},
  {time = 25, type = "callout", message = "triggerEnemyWarning"},
  {time = 30, type = "turret", x = 200},
  {time = 32, type = "turret", x = 600},
  {time = 35, type = "wave", formation = "line", x = 400, count = 6},
  {time = 40, type = "turret", x = 400},
  {time = 45, type = "callout", message = "triggerBossWarning"},
  {time = 47, type = "midboss"},
  {time = 65, type = "wave", formation = "v", x = 400, count = 7},
  {time = 70, type = "turret", x = 150},
  {time = 70, type = "turret", x = 650},
  {time = 75, type = "wave", formation = "wave", x = 400, count = 8},
  {time = 80, type = "callout", message = "triggerCover"},
  {time = 85, type = "wave", formation = "v", x = 300, count = 5},
  {time = 85, type = "wave", formation = "v", x = 500, count = 5},
  {time = 95, type = "callout", message = "triggerBossWarning"},
  {time = 100, type = "finalboss"}
}

function M.load()
  gameState.state = "menu"
  gameState.player = nil
  gameState.waveIndex = 1
  gameState.bossDefeated = false

  weapons.reset()
  enemies.reset()
  turrets.reset()
  terrain.reset()
  particles.reset()
  wingmen.reset()
  boss.reset()

  audio.load()
  ui.load()
end

function M.startGame()
  gameState.state = "playing"
  gameState.player = player.new()
  gameState.waveIndex = 1
  gameState.bossDefeated = false

  weapons.reset()
  enemies.reset()
  turrets.reset()
  terrain.reset()
  particles.reset()
  wingmen.reset()
  boss.reset()
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
  enemies.update(dt, gameState.player.x, gameState.player.y)
  turrets.update(dt, terrain.getScrollOffset(), gameState.player.x, gameState.player.y)
  particles.update(dt)
  wingmen.update(dt, gameState.player.x, gameState.player.y)
  boss.update(dt, gameState.player.x, gameState.player.y)

  M.spawnWaves()
  M.handleEnemyShooting()
  M.checkCollisions()

  if not player.isAlive(gameState.player) then
    gameState.state = "gameover"
  end

  if gameState.bossDefeated then
    gameState.state = "victory"
  end
end

function M.spawnWaves()
  local levelTime = terrain.getLevelTime()

  while gameState.waveIndex <= #LEVEL_WAVES do
    local wave = LEVEL_WAVES[gameState.waveIndex]

    if levelTime >= wave.time then
      if wave.type == "wave" then
        enemies.spawnFormation(wave.formation, wave.x, -50, wave.count)
      elseif wave.type == "turret" then
        turrets.spawn(wave.x, terrain.getScrollOffset() - 100)
      elseif wave.type == "midboss" then
        boss.spawnMidBoss()
        wingmen.triggerBossWarning()
      elseif wave.type == "finalboss" then
        boss.spawnFinalBoss()
        wingmen.triggerBossWarning()
      elseif wave.type == "callout" then
        wingmen[wave.message]()
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

  if boss.currentBoss and boss.currentBoss.shouldAttack then
    local b = boss.currentBoss
    weapons.fireEnemyLaser(b.x, b.y + 30, gameState.player.x, gameState.player.y)

    if b.type == "finalboss" and b.phase >= 2 then
      weapons.fireEnemyLaser(b.x - 30, b.y + 30, gameState.player.x, gameState.player.y)
      weapons.fireEnemyLaser(b.x + 30, b.y + 30, gameState.player.x, gameState.player.y)
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
          end

          if boss.damage(laser.damage, hitArm) then
            player.addScore(gameState.player, b.score)
            particles.spawn(b.x, b.y, 30, {1, 0.5, 0})
            gameState.bossDefeated = true
          end

          if not laser.piercing then
            table.remove(weapons.lasers, i)
          end
        end
      end

    elseif laser.owner == "enemy" then
      if M.checkHitPlayer(laser, gameState.player) then
        player.takeDamage(gameState.player, laser.damage)
        table.remove(weapons.lasers, i)
      end
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

    if boss.isActive() then
      local b = boss.currentBoss
      local dist = math.sqrt((bomb.x - b.x)^2 + (bomb.y - b.y)^2)
      if dist < bomb.radius then
        boss.damage(bomb.damage)
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

function M.draw()
  if gameState.state == "menu" then
    ui.drawMenu()
  elseif gameState.state == "playing" then
    ui.drawBackground()
    ui.drawTurrets()
    ui.drawEnemies()
    ui.drawBoss()
    ui.drawLasers()
    ui.drawBombs()
    ui.drawWingmen()
    ui.drawPlayer(gameState.player)
    ui.drawParticles()
    ui.drawHUD(gameState.player, terrain.getLevelTime(), boss.isActive())
  elseif gameState.state == "gameover" then
    ui.drawBackground()
    ui.drawGameOver(gameState.player.score)
  elseif gameState.state == "victory" then
    ui.drawBackground()
    ui.drawVictory(gameState.player.score)
  end
end

function M.keypressed(key)
  if gameState.state == "menu" and key == "space" then
    M.startGame()
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
    end
  elseif (gameState.state == "gameover" or gameState.state == "victory") and key == "r" then
    M.startGame()
  end
end

return M
