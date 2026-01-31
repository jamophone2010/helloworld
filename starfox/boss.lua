local M = {}

M.currentBoss = nil

function M.reset()
  M.currentBoss = nil
end

function M.spawnMidBoss()
  M.currentBoss = {
    type = "midboss",
    x = 400,
    y = -100,
    targetY = 100,
    width = 80,
    height = 60,
    health = 20,
    maxHealth = 20,
    score = 500,
    phase = 1,
    attackTimer = 2,
    active = true,
    entering = true
  }
  return M.currentBoss
end

function M.spawnFinalBoss()
  M.currentBoss = {
    type = "finalboss",
    x = 400,
    y = -150,
    targetY = 80,
    width = 150,
    height = 100,
    health = 50,
    maxHealth = 50,
    score = 2000,
    phase = 1,
    attackTimer = 2,
    active = true,
    entering = true,
    leftArm = {health = 15, x = -60, destroyed = false},
    rightArm = {health = 15, x = 60, destroyed = false}
  }
  return M.currentBoss
end

function M.update(dt, playerX, playerY)
  local boss = M.currentBoss
  if not boss or not boss.active then return end

  if boss.entering then
    boss.y = boss.y + 100 * dt
    if boss.y >= boss.targetY then
      boss.y = boss.targetY
      boss.entering = false
    end
    return
  end

  boss.attackTimer = boss.attackTimer - dt

  if boss.type == "midboss" then
    boss.x = boss.x + math.sin(love.timer.getTime() * 2) * 100 * dt

    if boss.attackTimer <= 0 then
      boss.attackTimer = 2
      boss.shouldAttack = true
    else
      boss.shouldAttack = false
    end

  elseif boss.type == "finalboss" then
    if boss.phase == 1 then
      boss.x = 400 + math.sin(love.timer.getTime()) * 100

      if boss.leftArm.destroyed and boss.rightArm.destroyed then
        boss.phase = 2
        boss.attackTimer = 1
      end
    elseif boss.phase == 2 then
      if boss.attackTimer <= 0 then
        boss.attackTimer = 0.8
        boss.shouldAttack = true
      else
        boss.shouldAttack = false
      end

      if boss.health < boss.maxHealth * 0.3 then
        boss.phase = 3
      end
    elseif boss.phase == 3 then
      boss.x = boss.x + math.sin(love.timer.getTime() * 3) * 150 * dt

      if boss.attackTimer <= 0 then
        boss.attackTimer = 0.5
        boss.shouldAttack = true
      else
        boss.shouldAttack = false
      end
    end
  end
end

function M.damage(amount, hitArm)
  local boss = M.currentBoss
  if not boss then return false end

  if boss.type == "finalboss" and boss.phase == 1 then
    if hitArm == "left" and not boss.leftArm.destroyed then
      boss.leftArm.health = boss.leftArm.health - amount
      if boss.leftArm.health <= 0 then
        boss.leftArm.destroyed = true
      end
      return false
    elseif hitArm == "right" and not boss.rightArm.destroyed then
      boss.rightArm.health = boss.rightArm.health - amount
      if boss.rightArm.health <= 0 then
        boss.rightArm.destroyed = true
      end
      return false
    end
    return false
  end

  boss.health = boss.health - amount

  if boss.health <= 0 then
    boss.active = false
    return true
  end

  return false
end

function M.isActive()
  return M.currentBoss ~= nil and M.currentBoss.active
end

function M.isDefeated()
  return M.currentBoss ~= nil and not M.currentBoss.active
end

return M
