local M = {}
local screen = require("starfox.screen")

function M.reset()
  M.currentBoss = nil
end

function M.spawnMidBoss()
  M.currentBoss = {
    type = "midboss",
    x = screen.WIDTH / 2,
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
    x = screen.WIDTH / 2,
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

function M.spawnArea6Boss()
  M.currentBoss = {
    type = "area6boss",
    x = screen.WIDTH / 2,
    y = -180,
    targetY = 100,
    width = 180,
    height = 120,
    health = 50,
    maxHealth = 120,
    score = 5000,
    phase = 1,
    attackTimer = 2,
    active = true,
    entering = true,
    spawnTimer = 0,
    leftShield = {health = 20, x = -70, destroyed = false},
    rightShield = {health = 20, x = 70, destroyed = false}
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
      boss.x = screen.WIDTH / 2 + math.sin(love.timer.getTime()) * 100

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

  elseif boss.type == "area6boss" then
    if boss.phase == 1 then
      -- Phase 1: Shield generators active
      boss.x = screen.WIDTH / 2 + math.sin(love.timer.getTime() * 0.8) * 120

      if boss.attackTimer <= 0 then
        boss.attackTimer = 1.8
        boss.shouldAttack = true
      else
        boss.shouldAttack = false
      end

      if boss.leftShield.destroyed and boss.rightShield.destroyed then
        boss.phase = 2
        boss.health = 50
        boss.attackTimer = 1
      end

    elseif boss.phase == 2 then
      -- Phase 2: Core exposed, 4-way spread attacks
      boss.x = screen.WIDTH / 2 + math.sin(love.timer.getTime() * 1.5) * 80

      if boss.attackTimer <= 0 then
        boss.attackTimer = 0.6
        boss.shouldAttack = true
        boss.spreadAttack = true
      else
        boss.shouldAttack = false
        boss.spreadAttack = false
      end

      if boss.health <= 30 then
        boss.phase = 3
        boss.spawnTimer = 0
      end

    elseif boss.phase == 3 then
      -- Phase 3: Critical mode, erratic movement, spawns fighters
      boss.x = boss.x + math.sin(love.timer.getTime() * 4) * 200 * dt

      if boss.attackTimer <= 0 then
        boss.attackTimer = 0.4
        boss.shouldAttack = true
      else
        boss.shouldAttack = false
      end

      boss.spawnTimer = boss.spawnTimer - dt
      if boss.spawnTimer <= 0 then
        boss.spawnTimer = 3
        boss.shouldSpawnFighters = true
      else
        boss.shouldSpawnFighters = false
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

  if boss.type == "area6boss" and boss.phase == 1 then
    if hitArm == "left" and not boss.leftShield.destroyed then
      boss.leftShield.health = boss.leftShield.health - amount
      if boss.leftShield.health <= 0 then
        boss.leftShield.destroyed = true
      end
      return false
    elseif hitArm == "right" and not boss.rightShield.destroyed then
      boss.rightShield.health = boss.rightShield.health - amount
      if boss.rightShield.health <= 0 then
        boss.rightShield.destroyed = true
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
