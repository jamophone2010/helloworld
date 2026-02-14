-- pooltable/balls.lua
-- Ball definitions and state management for pool table

local M = {}

-- Ball colors (solids 1-7, 8-ball, stripes 9-15)
M.BALL_COLORS = {
  [0]  = {0.95, 0.95, 0.92}, -- Cue ball (off-white)
  [1]  = {0.9, 0.8, 0.1},    -- Yellow (solid)
  [2]  = {0.1, 0.2, 0.7},    -- Blue (solid)
  [3]  = {0.8, 0.15, 0.1},   -- Red (solid)
  [4]  = {0.25, 0.1, 0.35},  -- Purple (solid)
  [5]  = {0.85, 0.4, 0.1},   -- Orange (solid)
  [6]  = {0.15, 0.5, 0.2},   -- Green (solid)
  [7]  = {0.5, 0.15, 0.1},   -- Maroon (solid)
  [8]  = {0.08, 0.08, 0.08}, -- Black (8-ball)
  [9]  = {0.9, 0.8, 0.1},    -- Yellow (stripe)
  [10] = {0.1, 0.2, 0.7},    -- Blue (stripe)
  [11] = {0.8, 0.15, 0.1},   -- Red (stripe)
  [12] = {0.25, 0.1, 0.35},  -- Purple (stripe)
  [13] = {0.85, 0.4, 0.1},   -- Orange (stripe)
  [14] = {0.15, 0.5, 0.2},   -- Green (stripe)
  [15] = {0.5, 0.15, 0.1},   -- Maroon (stripe)
}

M.BALL_RADIUS = 8
M.CUE_BALL_ID = 0

function M.isStripe(id)
  return id >= 9 and id <= 15
end

function M.isSolid(id)
  return id >= 1 and id <= 7
end

function M.is8Ball(id)
  return id == 8
end

function M.isCueBall(id)
  return id == 0
end

function M.newBall(id, x, y)
  return {
    id = id,
    x = x,
    y = y,
    vx = 0,
    vy = 0,
    active = true,    -- on table
    pocketed = false,
    spin = 0,
    angle = 0,
  }
end

-- Create initial rack of 15 balls in triangle formation
function M.rackBalls(tableInfo)
  local balls = {}
  local cx = tableInfo.playX + tableInfo.playW * 0.72
  local cy = tableInfo.playY + tableInfo.playH / 2
  local r = M.BALL_RADIUS
  local spacing = r * 2.15

  -- Triangle layout: row 1 has 1 ball, row 5 has 5 balls
  -- Standard 8-ball rack: 8-ball in center (row 3, pos 2)
  local rackOrder = {
    {1},
    {9, 2},
    {3, 8, 10},
    {11, 4, 5, 12},
    {13, 6, 7, 14, 15},
  }

  -- Shuffle within constraints (8-ball stays center, corners must be 1 solid + 1 stripe)
  -- For simplicity, randomize row contents keeping 8-ball fixed
  local solids = {1, 2, 3, 4, 5, 6, 7}
  local stripes = {9, 10, 11, 12, 13, 14, 15}

  -- Shuffle solids and stripes
  for i = #solids, 2, -1 do
    local j = math.random(i)
    solids[i], solids[j] = solids[j], solids[i]
  end
  for i = #stripes, 2, -1 do
    local j = math.random(i)
    stripes[i], stripes[j] = stripes[j], stripes[i]
  end

  -- Build rack positions
  local positions = {}
  local si, sti = 1, 1
  for row = 1, 5 do
    for col = 1, row do
      if row == 3 and col == 2 then
        -- 8-ball in the center
        local bx = cx + (row - 1) * spacing * 0.866
        local by = cy + (col - 1) * spacing - (row - 1) * spacing / 2
        table.insert(positions, M.newBall(8, bx, by))
      elseif (row == 5 and col == 1) then
        -- First corner: solid
        local bx = cx + (row - 1) * spacing * 0.866
        local by = cy + (col - 1) * spacing - (row - 1) * spacing / 2
        table.insert(positions, M.newBall(solids[si], bx, by))
        si = si + 1
      elseif (row == 5 and col == 5) then
        -- Last corner: stripe
        local bx = cx + (row - 1) * spacing * 0.866
        local by = cy + (col - 1) * spacing - (row - 1) * spacing / 2
        table.insert(positions, M.newBall(stripes[sti], bx, by))
        sti = sti + 1
      else
        -- Alternate solids and stripes
        local bx = cx + (row - 1) * spacing * 0.866
        local by = cy + (col - 1) * spacing - (row - 1) * spacing / 2
        if math.random() < 0.5 and si <= #solids then
          table.insert(positions, M.newBall(solids[si], bx, by))
          si = si + 1
        elseif sti <= #stripes then
          table.insert(positions, M.newBall(stripes[sti], bx, by))
          sti = sti + 1
        elseif si <= #solids then
          table.insert(positions, M.newBall(solids[si], bx, by))
          si = si + 1
        end
      end
    end
  end

  -- Add cue ball
  local cueBallX = tableInfo.playX + tableInfo.playW * 0.25
  local cueBallY = tableInfo.playY + tableInfo.playH / 2
  table.insert(positions, 1, M.newBall(0, cueBallX, cueBallY))

  return positions
end

-- Check if all balls of a type are pocketed
function M.allPocketed(balls, ballType)
  for _, b in ipairs(balls) do
    if b.id ~= 0 and b.id ~= 8 then
      if ballType == "solids" and M.isSolid(b.id) and b.active then
        return false
      elseif ballType == "stripes" and M.isStripe(b.id) and b.active then
        return false
      end
    end
  end
  return true
end

-- Check if any balls are still moving
function M.anyMoving(balls)
  for _, b in ipairs(balls) do
    if b.active and (math.abs(b.vx) > 0.5 or math.abs(b.vy) > 0.5) then
      return true
    end
  end
  return false
end

-- Get cue ball
function M.getCueBall(balls)
  for _, b in ipairs(balls) do
    if b.id == 0 then return b end
  end
  return nil
end

return M
