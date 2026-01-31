local M = {}
local terrain = require("starfox.terrain")
local weapons = require("starfox.weapons")
local enemies = require("starfox.enemies")
local turrets = require("starfox.turrets")
local boss = require("starfox.boss")
local particles = require("starfox.particles")
local wingmen = require("starfox.wingmen")
local hud = require("starfox.hud")

local fonts = {}

function M.load()
  fonts.large = love.graphics.newFont(36)
  fonts.normal = love.graphics.newFont(20)
  hud.load()
end

function M.drawBackground()
  love.graphics.setBackgroundColor(0.02, 0.02, 0.1)

  for _, star in ipairs(terrain.stars) do
    local alpha = 0.3 + (star.speed / 80) * 0.7
    love.graphics.setColor(1, 1, 1, alpha)
    love.graphics.circle("fill", star.x, star.y, star.size)
  end
end

function M.drawPlayer(player)
  if player.invulnerable and math.floor(love.timer.getTime() * 10) % 2 == 0 then
    return
  end

  love.graphics.push()
  love.graphics.translate(player.x, player.y)

  if player.barrelRolling then
    love.graphics.rotate(player.barrelRollAngle)
  end

  love.graphics.setColor(0.3, 0.5, 1)
  love.graphics.polygon("fill", 0, -20, -15, 15, 15, 15)

  love.graphics.setColor(0.5, 0.7, 1)
  love.graphics.polygon("fill", -25, 10, -15, 5, -15, 15, -25, 15)
  love.graphics.polygon("fill", 25, 10, 15, 5, 15, 15, 25, 15)

  love.graphics.setColor(1, 1, 1)
  love.graphics.polygon("line", 0, -20, -15, 15, 15, 15)

  if player.charging and player.chargeLevel > 0.2 then
    local size = 5 + player.chargeLevel * 15
    love.graphics.setColor(0.3, 0.8, 1, 0.5 + player.chargeLevel * 0.5)
    love.graphics.circle("fill", 0, -20, size)
  end

  love.graphics.pop()
end

function M.drawWingmen()
  for _, wingman in ipairs(wingmen.wingmen) do
    love.graphics.setColor(0.5, 0.5, 0.5)
    love.graphics.polygon("fill", wingman.x, wingman.y - 10, wingman.x - 8, wingman.y + 8, wingman.x + 8, wingman.y + 8)
  end
end

function M.drawLasers()
  for _, laser in ipairs(weapons.lasers) do
    if laser.owner == "player" then
      if laser.charged then
        love.graphics.setColor(0.3, 0.8, 1)
      else
        love.graphics.setColor(0, 1, 0)
      end
    else
      love.graphics.setColor(1, 0.3, 0.3)
    end
    love.graphics.rectangle("fill", laser.x - laser.width/2, laser.y - laser.height/2, laser.width, laser.height)
  end
end

function M.drawBombs()
  for _, bomb in ipairs(weapons.bombs) do
    love.graphics.setColor(1, 1, 0.5, bomb.alpha)
    love.graphics.circle("line", bomb.x, bomb.y, bomb.radius)
    love.graphics.circle("line", bomb.x, bomb.y, bomb.radius * 0.8)
  end
end

function M.drawEnemies()
  for _, enemy in ipairs(enemies.enemies) do
    love.graphics.setColor(1, 0.3, 0.3)
    love.graphics.polygon("fill", enemy.x, enemy.y + 15, enemy.x - 12, enemy.y - 10, enemy.x + 12, enemy.y - 10)
  end
end

function M.drawTurrets()
  for _, turret in ipairs(turrets.turrets) do
    if turret.active then
      love.graphics.setColor(0.5, 0.5, 0.5)
      love.graphics.rectangle("fill", turret.x - 15, turret.y, 30, 15)
      love.graphics.setColor(0.8, 0.3, 0.3)
      love.graphics.circle("fill", turret.x, turret.y, 10)
    end
  end
end

function M.drawBoss()
  local b = boss.currentBoss
  if not b or not b.active then return end

  if b.type == "midboss" then
    love.graphics.setColor(0.6, 0.2, 0.2)
    love.graphics.rectangle("fill", b.x - b.width/2, b.y - b.height/2, b.width, b.height)
    love.graphics.setColor(1, 0.3, 0.3)
    love.graphics.circle("fill", b.x, b.y, 20)
  elseif b.type == "finalboss" then
    love.graphics.setColor(0.4, 0.4, 0.4)
    love.graphics.rectangle("fill", b.x - b.width/2, b.y - b.height/2, b.width, b.height)

    if not b.leftArm.destroyed then
      love.graphics.setColor(0.5, 0.3, 0.3)
      love.graphics.rectangle("fill", b.x + b.leftArm.x - 25, b.y + 20, 50, 30)
    end
    if not b.rightArm.destroyed then
      love.graphics.setColor(0.5, 0.3, 0.3)
      love.graphics.rectangle("fill", b.x + b.rightArm.x - 25, b.y + 20, 50, 30)
    end

    if b.phase >= 2 then
      love.graphics.setColor(1, 0.5, 0)
      love.graphics.circle("fill", b.x, b.y, 25)
    end
  end
end

function M.drawParticles()
  for _, p in ipairs(particles.particles) do
    local alpha = p.life / p.maxLife
    love.graphics.setColor(p.color[1], p.color[2], p.color[3], alpha)
    love.graphics.circle("fill", p.x, p.y, p.size)
  end
end

function M.drawHUD(player, levelTime, bossActive)
  local callout = wingmen.getCurrentCallout()
  local bossHealth, bossMaxHealth = nil, nil

  if bossActive and boss.currentBoss then
    bossHealth = boss.currentBoss.health
    bossMaxHealth = boss.currentBoss.maxHealth
  end

  hud.draw(player, levelTime, callout, bossHealth, bossMaxHealth)
end

function M.drawMenu()
  love.graphics.setBackgroundColor(0, 0, 0)
  love.graphics.setFont(fonts.large)
  love.graphics.setColor(0.3, 0.5, 1)
  love.graphics.printf("STARFOX 2D", 0, 200, 800, "center")

  love.graphics.setFont(fonts.normal)
  love.graphics.setColor(1, 1, 1)
  love.graphics.printf("CORNERIA", 0, 250, 800, "center")
  love.graphics.printf("Press SPACE to start", 0, 320, 800, "center")
  love.graphics.printf("Arrows: Move | SPACE: Shoot | Z: Barrel Roll | X: Bomb", 0, 360, 800, "center")
end

function M.drawGameOver(score)
  love.graphics.setFont(fonts.large)
  love.graphics.setColor(1, 0, 0)
  love.graphics.printf("MISSION FAILED", 0, 200, 800, "center")

  love.graphics.setFont(fonts.normal)
  love.graphics.setColor(1, 1, 1)
  love.graphics.printf("Final Score: " .. score, 0, 280, 800, "center")
  love.graphics.printf("Press R to retry", 0, 340, 800, "center")
end

function M.drawVictory(score)
  love.graphics.setFont(fonts.large)
  love.graphics.setColor(0, 1, 0)
  love.graphics.printf("MISSION COMPLETE", 0, 200, 800, "center")

  love.graphics.setFont(fonts.normal)
  love.graphics.setColor(1, 1, 1)
  love.graphics.printf("Final Score: " .. score, 0, 280, 800, "center")
  love.graphics.printf("Press R to play again", 0, 340, 800, "center")
end

return M
