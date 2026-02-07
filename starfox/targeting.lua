local M = {}

M.active = false
M.locks = {}
M.lockedEnemies = {}

local LOCK_THRESHOLD = 0.1
local MAX_LOCKS = 4
local LOCK_HORIZONTAL_RANGE = 40
local LOCK_DURATION = 1.0

-- Override max locks for abilities (e.g. Lancer multi-lock)
M.overrideMaxLocks = nil

local function getMaxLocks()
  return M.overrideMaxLocks or MAX_LOCKS
end

function M.reset()
  M.active = false
  M.locks = {}
  M.lockedEnemies = {}
  M.overrideMaxLocks = nil
end

function M.startLocking()
  M.active = true
end

function M.update(dt, player, enemies)
  if not M.active then return end

  -- Instant lock for enemies in dodge path (narrow path only, even during multilock)
  if player.dodging and player.dodgeStartX then
    local minX = math.min(player.dodgeStartX, player.x)
    local maxX = math.max(player.dodgeStartX, player.x)

    for _, enemy in ipairs(enemies) do
      local dy = enemy.y - player.y
      local inPath = enemy.x >= minX and enemy.x <= maxX
      if inPath and dy < 0 and #M.lockedEnemies < getMaxLocks() then
        local alreadyLocked = M.locks[enemy] and M.locks[enemy].locked
        if not alreadyLocked then
          M.locks[enemy] = {lockTimer = LOCK_THRESHOLD, locked = true, lockDuration = 0}
          table.insert(M.lockedEnemies, enemy)
        end
      end
    end
  end

  for _, enemy in ipairs(enemies) do
    local dx = enemy.x - player.x
    local dy = enemy.y - player.y
    local horizontalDist = math.abs(dx)
    local isInRange = horizontalDist < LOCK_HORIZONTAL_RANGE and dy < 0

    if M.locks[enemy] then
      if M.locks[enemy].locked then
        -- Update lock duration for locked enemies
        M.locks[enemy].lockDuration = M.locks[enemy].lockDuration + dt
        -- Remove lock after 1 second (unless override is active, e.g. Lancer multilock)
        if M.locks[enemy].lockDuration >= LOCK_DURATION and not M.overrideMaxLocks then
          M.removeLock(enemy)
        end
      elseif isInRange then
        -- Still acquiring lock
        M.locks[enemy].lockTimer = M.locks[enemy].lockTimer + dt
        if M.locks[enemy].lockTimer >= LOCK_THRESHOLD
           and #M.lockedEnemies < getMaxLocks() then
          M.locks[enemy].locked = true
          M.locks[enemy].lockDuration = 0
          table.insert(M.lockedEnemies, enemy)
        end
      else
        -- Not locked yet and out of range
        M.removeLock(enemy)
      end
    elseif isInRange then
      -- Start new lock attempt
      M.locks[enemy] = {lockTimer = 0, locked = false, lockDuration = 0}
    end
  end

  -- Clean dead enemies
  for enemy in pairs(M.locks) do
    local found = false
    for _, e in ipairs(enemies) do
      if e == enemy then
        found = true
        break
      end
    end
    if not found then
      M.removeLock(enemy)
    end
  end
end

function M.releaseLocks()
  local targets = {}
  for _, enemy in ipairs(M.lockedEnemies) do
    table.insert(targets, {x = enemy.x, y = enemy.y, ref = enemy})
  end
  local savedOverride = M.overrideMaxLocks
  M.reset()
  M.overrideMaxLocks = savedOverride  -- Preserve override for Lancer multi-lock
  return targets
end

function M.removeLock(enemy)
  M.locks[enemy] = nil
  for i, e in ipairs(M.lockedEnemies) do
    if e == enemy then
      table.remove(M.lockedEnemies, i)
      break
    end
  end
end

function M.getLockProgress(enemy)
  if M.locks[enemy] then
    return math.min(1, M.locks[enemy].lockTimer / LOCK_THRESHOLD)
  end
  return 0
end

return M
