local M = {}
local screen = require("starfox.screen")

function M.reset()
  M.enemies = {}
end

function M.spawn(x, y, type, color)
  local enemy = {
    x = x,
    y = y,
    type = type or "fighter",
    color = color or "red",
    health = 1,
    maxHealth = 1,
    score = 10,
    width = 25,
    height = 25,
    shootTimer = math.random() * 2 + 1
  }

  if type == "fighter" then
    enemy.vx = 0
    enemy.vy = 150

    if color == "red" then
      enemy.health = 1
      enemy.maxHealth = 1
      enemy.score = 10
    elseif color == "green" then
      enemy.health = 2
      enemy.maxHealth = 2
      enemy.score = 20
    elseif color == "blue" then
      enemy.health = 3
      enemy.maxHealth = 3
      enemy.score = 30
    else
      enemy.health = 1
      enemy.maxHealth = 1
      enemy.score = 10
    end
  end

  table.insert(M.enemies, enemy)
  return enemy
end

function M.spawnFormation(formation, x, y, count, color)
  local enemies = {}

  if formation == "v" then
    for i = 1, count do
      local offset = (i - math.ceil(count / 2)) * 40
      local yOff = math.abs(offset) * 0.5
      table.insert(enemies, M.spawn(x + offset, y + yOff, "fighter", color))
    end
  elseif formation == "line" then
    for i = 1, count do
      local offset = (i - math.ceil(count / 2)) * 50
      table.insert(enemies, M.spawn(x + offset, y, "fighter", color))
    end
  elseif formation == "wave" then
    for i = 1, count do
      local offset = (i - 1) * 60
      table.insert(enemies, M.spawn(100 + offset, y, "fighter", color))
    end
  elseif formation == "diamond" then
    -- Diamond: red sides, blue/green center
    table.insert(enemies, M.spawn(x, y - 40, "fighter", "blue"))
    table.insert(enemies, M.spawn(x - 50, y, "fighter", "red"))
    table.insert(enemies, M.spawn(x + 50, y, "fighter", "red"))
    table.insert(enemies, M.spawn(x, y + 40, "fighter", "green"))
  elseif formation == "box" then
    -- Box: green corners, blue center
    table.insert(enemies, M.spawn(x - 40, y - 40, "fighter", "red"))
    table.insert(enemies, M.spawn(x + 40, y - 40, "fighter", "red"))
    table.insert(enemies, M.spawn(x, y, "fighter", "blue"))
    table.insert(enemies, M.spawn(x - 40, y + 40, "fighter", "red"))
    table.insert(enemies, M.spawn(x + 40, y + 40, "fighter", "red"))
  elseif formation == "triangle" then
    -- Triangle: red base, green/blue tip
    table.insert(enemies, M.spawn(x, y - 50, "fighter", "blue"))
    table.insert(enemies, M.spawn(x - 30, y, "fighter", "green"))
    table.insert(enemies, M.spawn(x + 30, y, "fighter", "green"))
    table.insert(enemies, M.spawn(x - 60, y + 30, "fighter", "red"))
    table.insert(enemies, M.spawn(x + 60, y + 30, "fighter", "red"))
  end

  return #enemies
end

function M.update(dt, playerX, playerY, speedScale, attractToPlayer)
  local escapedCount = 0
  local scaledDt = dt * (speedScale or 1.0)
  for i = #M.enemies, 1, -1 do
    local enemy = M.enemies[i]

    -- Attract enemies toward player if ability active
    if attractToPlayer and playerX and playerY then
      local dx = playerX - enemy.x
      local dy = playerY - enemy.y
      local dist = math.sqrt(dx * dx + dy * dy)
      if dist > 1 then
        local attractSpeed = 80
        enemy.x = enemy.x + (dx / dist) * attractSpeed * scaledDt
        enemy.y = enemy.y + (dy / dist) * attractSpeed * scaledDt
      end
    end

    if enemy.vx then
      enemy.x = enemy.x + enemy.vx * scaledDt
    end
    if enemy.vy then
      enemy.y = enemy.y + enemy.vy * scaledDt
    end

    enemy.shootTimer = enemy.shootTimer - dt

    if enemy.y > screen.HEIGHT + 50 or enemy.y < -50 then
      -- Count enemies that escaped through the bottom
      if enemy.y > screen.HEIGHT + 50 then
        escapedCount = escapedCount + 1
      end
      table.remove(M.enemies, i)
    end
  end
  return escapedCount
end

function M.damage(enemy, amount)
  enemy.health = enemy.health - amount
  return enemy.health <= 0
end

function M.remove(enemy)
  for i, e in ipairs(M.enemies) do
    if e == enemy then
      table.remove(M.enemies, i)
      return true
    end
  end
  return false
end

return M
