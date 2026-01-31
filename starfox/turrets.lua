local M = {}

M.turrets = {}

function M.reset()
  M.turrets = {}
end

function M.spawn(x, terrainY)
  table.insert(M.turrets, {
    x = x,
    terrainY = terrainY,
    y = 0,
    health = 2,
    score = 20,
    width = 30,
    height = 20,
    shootTimer = math.random() * 1 + 0.5,
    active = false
  })
end

function M.update(dt, scrollOffset, playerX, playerY)
  for i = #M.turrets, 1, -1 do
    local turret = M.turrets[i]

    turret.y = turret.terrainY - scrollOffset

    turret.active = turret.y > -50 and turret.y < 650

    if turret.active then
      turret.shootTimer = turret.shootTimer - dt

      if turret.shootTimer <= 0 then
        turret.shootTimer = 1.5
        turret.shouldShoot = true
      else
        turret.shouldShoot = false
      end
    end

    if turret.y > 700 then
      table.remove(M.turrets, i)
    end
  end
end

function M.damage(turret, amount)
  turret.health = turret.health - amount
  return turret.health <= 0
end

function M.remove(turret)
  for i, t in ipairs(M.turrets) do
    if t == turret then
      table.remove(M.turrets, i)
      return true
    end
  end
  return false
end

return M
