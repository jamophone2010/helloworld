local M = {}

local enemies = require("starfox.enemies")

M.ships = {}

function M.reset()
  M.ships = {}
end

function M.spawn(x)
  local ship = {
    x = x,
    y = -100,
    width = 200,
    height = 80,
    health = 20,
    maxHealth = 20,
    score = 300,
    vy = 40,
    shootTimer = 2,
    active = true
  }
  table.insert(M.ships, ship)
  return ship
end

function M.update(dt, playerX, playerY)
  for i = #M.ships, 1, -1 do
    local ship = M.ships[i]

    ship.y = ship.y + ship.vy * dt
    ship.shootTimer = ship.shootTimer - dt

    if ship.shootTimer <= 0 then
      ship.shootTimer = 2
      ship.shouldShoot = true
    else
      ship.shouldShoot = false
    end

    if ship.y > 700 then
      table.remove(M.ships, i)
    end
  end
end

function M.damage(ship, amount)
  ship.health = ship.health - amount
  return ship.health <= 0
end

function M.destroy(ship)
  -- Spawn 3 fighter escorts when destroyed
  enemies.spawn(ship.x - 60, ship.y, "fighter")
  enemies.spawn(ship.x, ship.y + 30, "fighter")
  enemies.spawn(ship.x + 60, ship.y, "fighter")

  M.remove(ship)
end

function M.remove(ship)
  for i, s in ipairs(M.ships) do
    if s == ship then
      table.remove(M.ships, i)
      return true
    end
  end
  return false
end

return M
