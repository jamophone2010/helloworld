local M = {}

M.allies = {}

local ALLY_OFFSETS = {
  {x = -120, y = 40},
  {x = 120, y = 40},
  {x = -60, y = 70},
  {x = 60, y = 70}
}

local ALLY_NAMES = {"Bill", "Husky", "Cat", "Dog"}

function M.reset()
  M.allies = {}
end

function M.spawn(x, y, name)
  local ally = {
    x = x,
    y = y,
    name = name or "Ally",
    width = 25,
    height = 25,
    health = 30,
    maxHealth = 30,
    shootTimer = math.random() * 0.5 + 1,
    targetX = nil,
    targetY = nil,
    shouldShoot = false,
    active = true
  }
  table.insert(M.allies, ally)
  return ally
end

function M.spawnSquadron(playerX, playerY)
  for i, offset in ipairs(ALLY_OFFSETS) do
    M.spawn(playerX + offset.x, playerY + offset.y, ALLY_NAMES[i])
  end
end

function M.update(dt, playerX, playerY, enemies)
  for i = #M.allies, 1, -1 do
    local ally = M.allies[i]
    if not ally.active then
      table.remove(M.allies, i)
    else
      -- Follow player loosely
      local offset = ALLY_OFFSETS[((i - 1) % #ALLY_OFFSETS) + 1]
      local targetX = playerX + offset.x
      local targetY = playerY + offset.y

      ally.x = ally.x + (targetX - ally.x) * dt * 1.5
      ally.y = ally.y + (targetY - ally.y) * dt * 1.5

      -- Keep in bounds
      ally.x = math.max(30, math.min(770, ally.x))
      ally.y = math.max(100, math.min(570, ally.y))

      -- Shooting logic
      ally.shootTimer = ally.shootTimer - dt
      ally.shouldShoot = false

      if ally.shootTimer <= 0 then
        -- Find nearest enemy within range
        local nearestDist = 400
        local nearestEnemy = nil

        for _, enemy in ipairs(enemies) do
          local dist = math.sqrt((enemy.x - ally.x)^2 + (enemy.y - ally.y)^2)
          if dist < nearestDist then
            nearestDist = dist
            nearestEnemy = enemy
          end
        end

        if nearestEnemy then
          ally.targetX = nearestEnemy.x
          ally.targetY = nearestEnemy.y
          ally.shouldShoot = true
          ally.shootTimer = 1.5
        else
          ally.shootTimer = 0.3  -- Check again soon
        end
      end
    end
  end
end

function M.damage(ally, amount)
  ally.health = ally.health - amount
  if ally.health <= 0 then
    ally.active = false
    return true
  end
  return false
end

function M.remove(ally)
  for i, a in ipairs(M.allies) do
    if a == ally then
      table.remove(M.allies, i)
      return true
    end
  end
  return false
end

return M
