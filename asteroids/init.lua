local M = {}

local ship = require("asteroids.ship")
local bullet = require("asteroids.bullet")
local asteroid = require("asteroids.asteroid")
local ufo = require("asteroids.ufo")
local powerup = require("asteroids.powerup")
local particle = require("asteroids.particle")
local level = require("asteroids.level")
local audio = require("asteroids.audio")
local ui = require("asteroids.ui")

local gameState = {}

function M.load()
  gameState.state = "menu"
  gameState.width = 1366
  gameState.height = 768

  audio.load()
  ui.load()
end

function M.startGame()
  gameState.ship = ship.new(gameState.width / 2, gameState.height / 2)
  gameState.bullets = {}
  gameState.asteroids = {}
  gameState.ufos = {}
  gameState.powerups = {}
  gameState.particles = {}
  gameState.level = level.new()
  gameState.score = 0
  gameState.health = 100
  gameState.damageTimer = 0

  gameState.asteroids = level.spawnAsteroids(gameState.level, gameState.width, gameState.height)
  gameState.state = "playing"
end

function M.update(dt)
  if gameState.state == "playing" then
    M.updatePlaying(dt)
  end
end

function M.updatePlaying(dt)
  ship.update(gameState.ship, dt)
  ship.wrap(gameState.ship, gameState.width, gameState.height)

  gameState.damageTimer = math.max(0, gameState.damageTimer - dt)
  if gameState.damageTimer <= 0 then
    gameState.health = math.min(100, gameState.health + dt)
  end

  for i = #gameState.bullets, 1, -1 do
    bullet.update(gameState.bullets[i], dt)
    bullet.wrap(gameState.bullets[i], gameState.width, gameState.height)

    if not bullet.isAlive(gameState.bullets[i]) then
      table.remove(gameState.bullets, i)
    end
  end

  for _, a in ipairs(gameState.asteroids) do
    asteroid.update(a, dt)
    asteroid.wrap(a, gameState.width, gameState.height)
  end

  for i = #gameState.ufos, 1, -1 do
    local u = gameState.ufos[i]
    ufo.update(u, dt)

    if ufo.canShoot(u) then
      local angle = ufo.shoot(u, gameState.ship.x, gameState.ship.y)
      table.insert(gameState.bullets, bullet.new(u.x, u.y, angle, "ufo"))
    end

    if ufo.isOffScreen(u, gameState.width) then
      table.remove(gameState.ufos, i)
    end
  end

  for i = #gameState.powerups, 1, -1 do
    powerup.update(gameState.powerups[i], dt)

    if not powerup.isAlive(gameState.powerups[i]) then
      table.remove(gameState.powerups, i)
    end
  end

  particle.update(gameState.particles, dt)

  level.update(gameState.level, dt, #gameState.asteroids)

  if level.shouldSpawnUFO(gameState.level) then
    local side = math.random() < 0.5 and -50 or gameState.width + 50
    local y = math.random(100, gameState.height - 100)
    table.insert(gameState.ufos, ufo.new(side, y))
  end

  if gameState.level.cleared then
    level.nextLevel(gameState.level)
    gameState.asteroids = level.spawnAsteroids(gameState.level, gameState.width, gameState.height)
  end

  M.checkCollisions()

  if gameState.health <= 0 then
    gameState.state = "game_over"
  end
end

function M.checkCollisions()
  for i = #gameState.bullets, 1, -1 do
    local b = gameState.bullets[i]

    for j = #gameState.asteroids, 1, -1 do
      local a = gameState.asteroids[j]
      local dist = math.sqrt((b.x - a.x)^2 + (b.y - a.y)^2)

      if dist < asteroid.getRadius(a) and b.owner == "player" then
        local splits, score = asteroid.split(a)
        gameState.score = gameState.score + score

        for _, split in ipairs(splits) do
          table.insert(gameState.asteroids, split)
        end

        for _, p in ipairs(particle.new(a.x, a.y)) do
          table.insert(gameState.particles, p)
        end
        table.remove(gameState.asteroids, j)
        table.remove(gameState.bullets, i)
        break
      end
    end
  end

  for i = #gameState.bullets, 1, -1 do
    local b = gameState.bullets[i]

    for j = #gameState.ufos, 1, -1 do
      local u = gameState.ufos[j]
      local dist = math.sqrt((b.x - u.x)^2 + (b.y - u.y)^2)

      if dist < u.size and b.owner == "player" then
        gameState.score = gameState.score + u.score
        for _, p in ipairs(particle.new(u.x, u.y)) do
          table.insert(gameState.particles, p)
        end

        if math.random() < 0.3 then
          table.insert(gameState.powerups, powerup.new(u.x, u.y))
        end

        table.remove(gameState.ufos, j)
        table.remove(gameState.bullets, i)
        break
      end
    end
  end

  if not gameState.ship.invulnerable and not gameState.ship.dead then
    for _, a in ipairs(gameState.asteroids) do
      local dist = math.sqrt((gameState.ship.x - a.x)^2 + (gameState.ship.y - a.y)^2)

      if dist < asteroid.getRadius(a) + gameState.ship.size then
        gameState.health = gameState.health - 25
        gameState.damageTimer = 3
        ship.die(gameState.ship)
        for _, p in ipairs(particle.new(a.x, a.y)) do
          table.insert(gameState.particles, p)
        end
        break
      end
    end

    for i = #gameState.bullets, 1, -1 do
      local b = gameState.bullets[i]

      if b.owner == "ufo" then
        local dist = math.sqrt((gameState.ship.x - b.x)^2 + (gameState.ship.y - b.y)^2)

        if dist < gameState.ship.size then
          gameState.health = gameState.health - 15
          gameState.damageTimer = 3
          table.remove(gameState.bullets, i)
        end
      end
    end
  end

  for i = #gameState.powerups, 1, -1 do
    local p = gameState.powerups[i]
    local dist = math.sqrt((gameState.ship.x - p.x)^2 + (gameState.ship.y - p.y)^2)

    if dist < gameState.ship.size + p.size then
      local healAmount = powerup.apply(p, gameState.ship)
      gameState.health = math.min(100, gameState.health + healAmount)
      table.remove(gameState.powerups, i)
    end
  end
end

function M.draw()
  love.graphics.setBackgroundColor(0, 0, 0)

  if gameState.state == "menu" then
    ui.drawMenu()
  elseif gameState.state == "playing" then
    local color = gameState.level.color
    if not gameState.ship.dead then
      ui.drawShip(gameState.ship, color)
    end

    for _, a in ipairs(gameState.asteroids) do
      ui.drawAsteroid(a, color)
    end

    for _, b in ipairs(gameState.bullets) do
      ui.drawBullet(b)
    end

    for _, u in ipairs(gameState.ufos) do
      ui.drawUFO(u)
    end

    for _, p in ipairs(gameState.powerups) do
      ui.drawPowerup(p)
    end

    for _, p in ipairs(gameState.particles) do
      ui.drawParticle(p)
    end

    ui.drawHUD(gameState.health, gameState.score, gameState.level.number)
  elseif gameState.state == "game_over" then
    ui.drawGameOver(gameState.score, gameState.level.number)
  end
end

function M.keypressed(key)
  if gameState.state == "menu" and key == "space" then
    M.startGame()
  elseif gameState.state == "game_over" and key == "r" then
    gameState.state = "menu"
  elseif gameState.state == "playing" and not gameState.ship.dead then
    if key == "space" and ship.shoot(gameState.ship) then
      local cos = math.cos(gameState.ship.angle)
      local sin = math.sin(gameState.ship.angle)
      local bx = gameState.ship.x + cos * gameState.ship.size
      local by = gameState.ship.y + sin * gameState.ship.size

      table.insert(gameState.bullets, bullet.new(bx, by, gameState.ship.angle, "player"))
    elseif key == "x" then
      local damaged = ship.hyperspace(gameState.ship, gameState.width, gameState.height)
      if damaged then
        gameState.health = gameState.health - 50
      end
    end
  end
end

function M.update(dt)
  if gameState.state == "playing" then
    M.updatePlaying(dt)

    if not gameState.ship.dead then
      if love.keyboard.isDown("left") then
        ship.rotate(gameState.ship, -1, dt)
      end
      if love.keyboard.isDown("right") then
        ship.rotate(gameState.ship, 1, dt)
      end
      if love.keyboard.isDown("up") then
        ship.thrust(gameState.ship, dt)
      end
    end
  end
end

return M
