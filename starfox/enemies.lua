local M = {}

M.enemies = {}

function M.reset()
  M.enemies = {}
end

function M.spawn(x, y, type)
  local enemy = {
    x = x,
    y = y,
    type = type or "fighter",
    health = 1,
    score = 10,
    width = 25,
    height = 25,
    shootTimer = math.random() * 2 + 1
  }

  if type == "fighter" then
    enemy.vx = 0
    enemy.vy = 150
    enemy.health = 1
    enemy.score = 10
  end

  table.insert(M.enemies, enemy)
  return enemy
end

function M.spawnFormation(formation, x, y, count)
  local enemies = {}

  if formation == "v" then
    for i = 1, count do
      local offset = (i - math.ceil(count / 2)) * 40
      local yOff = math.abs(offset) * 0.5
      table.insert(enemies, M.spawn(x + offset, y - yOff, "fighter"))
    end
  elseif formation == "line" then
    for i = 1, count do
      local offset = (i - math.ceil(count / 2)) * 50
      table.insert(enemies, M.spawn(x + offset, y, "fighter"))
    end
  elseif formation == "wave" then
    for i = 1, count do
      local offset = (i - 1) * 60
      table.insert(enemies, M.spawn(100 + offset, y, "fighter"))
    end
  end

  return enemies
end

function M.update(dt, playerX, playerY)
  for i = #M.enemies, 1, -1 do
    local enemy = M.enemies[i]

    if enemy.vx then
      enemy.x = enemy.x + enemy.vx * dt
    end
    if enemy.vy then
      enemy.y = enemy.y + enemy.vy * dt
    end

    enemy.shootTimer = enemy.shootTimer - dt

    if enemy.y > 650 or enemy.y < -50 then
      table.remove(M.enemies, i)
    end
  end
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
