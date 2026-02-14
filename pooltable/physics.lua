-- pooltable/physics.lua
-- 2D physics simulation for pool balls

local M = {}

local balls = require("pooltable.balls")

local FRICTION = 0.985        -- per-frame friction multiplier
local STOP_THRESHOLD = 0.4    -- velocity below this = stopped
local RESTITUTION = 0.92      -- bounciness of ball-ball collisions
local WALL_RESTITUTION = 0.75 -- bounciness of ball-wall collisions
local BALL_RADIUS = balls.BALL_RADIUS

-- Update all ball physics for one frame
function M.update(ballList, tableInfo, dt)
  local pocketed = {}

  -- Move balls
  for _, b in ipairs(ballList) do
    if b.active then
      b.x = b.x + b.vx * dt * 60
      b.y = b.y + b.vy * dt * 60

      -- Apply friction
      b.vx = b.vx * FRICTION
      b.vy = b.vy * FRICTION

      -- Stop if very slow
      if math.abs(b.vx) < STOP_THRESHOLD and math.abs(b.vy) < STOP_THRESHOLD then
        b.vx = 0
        b.vy = 0
      end

      -- Spin visual
      local speed = math.sqrt(b.vx * b.vx + b.vy * b.vy)
      b.angle = b.angle + speed * 0.02 * dt * 60
    end
  end

  -- Ball-ball collisions
  for i = 1, #ballList do
    local a = ballList[i]
    if a.active then
      for j = i + 1, #ballList do
        local b2 = ballList[j]
        if b2.active then
          local dx = b2.x - a.x
          local dy = b2.y - a.y
          local dist = math.sqrt(dx * dx + dy * dy)
          local minDist = BALL_RADIUS * 2

          if dist < minDist and dist > 0 then
            -- Normalize collision vector
            local nx = dx / dist
            local ny = dy / dist

            -- Relative velocity
            local dvx = a.vx - b2.vx
            local dvy = a.vy - b2.vy
            local dvn = dvx * nx + dvy * ny

            -- Only resolve if moving towards each other
            if dvn > 0 then
              local impulse = dvn * RESTITUTION

              a.vx = a.vx - impulse * nx
              a.vy = a.vy - impulse * ny
              b2.vx = b2.vx + impulse * nx
              b2.vy = b2.vy + impulse * ny
            end

            -- Separate overlapping balls
            local overlap = minDist - dist
            local sepX = nx * overlap * 0.5
            local sepY = ny * overlap * 0.5
            a.x = a.x - sepX
            a.y = a.y - sepY
            b2.x = b2.x + sepX
            b2.y = b2.y + sepY
          end
        end
      end
    end
  end

  -- Wall collisions + pocket detection
  local playX = tableInfo.playX
  local playY = tableInfo.playY
  local playW = tableInfo.playW
  local playH = tableInfo.playH
  local pockets = tableInfo.pockets

  for _, b in ipairs(ballList) do
    if b.active then
      -- Check pockets first
      for _, pocket in ipairs(pockets) do
        local dx = b.x - pocket.x
        local dy = b.y - pocket.y
        local dist = math.sqrt(dx * dx + dy * dy)
        if dist < pocket.radius then
          -- Ball pocketed!
          b.active = false
          b.pocketed = true
          b.vx = 0
          b.vy = 0
          table.insert(pocketed, b)
          break
        end
      end

      -- Wall bounces (only if still active)
      if b.active then
        if b.x - BALL_RADIUS < playX then
          b.x = playX + BALL_RADIUS
          b.vx = math.abs(b.vx) * WALL_RESTITUTION
        elseif b.x + BALL_RADIUS > playX + playW then
          b.x = playX + playW - BALL_RADIUS
          b.vx = -math.abs(b.vx) * WALL_RESTITUTION
        end

        if b.y - BALL_RADIUS < playY then
          b.y = playY + BALL_RADIUS
          b.vy = math.abs(b.vy) * WALL_RESTITUTION
        elseif b.y + BALL_RADIUS > playY + playH then
          b.y = playY + playH - BALL_RADIUS
          b.vy = -math.abs(b.vy) * WALL_RESTITUTION
        end
      end
    end
  end

  return pocketed
end

-- Apply shot force to cue ball
function M.shoot(cueBall, power, angle)
  local maxSpeed = 18
  local speed = power * maxSpeed
  cueBall.vx = math.cos(angle) * speed
  cueBall.vy = math.sin(angle) * speed
end

return M
