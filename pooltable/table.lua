-- pooltable/table.lua
-- Pool table geometry and pocket definitions

local M = {}

-- Table dimensions (positioned centrally on a 1366x768 screen)
local TABLE_X = 183      -- Left edge of outer rail
local TABLE_Y = 80       -- Top edge of outer rail
local TABLE_W = 1000     -- Outer width
local TABLE_H = 500      -- Outer height
local RAIL_W = 35        -- Width of the cushion rail
local POCKET_RADIUS = 16 -- Pocket opening radius
local CORNER_POCKET_R = 18
local SIDE_POCKET_R = 15

function M.new()
  local playX = TABLE_X + RAIL_W
  local playY = TABLE_Y + RAIL_W
  local playW = TABLE_W - RAIL_W * 2
  local playH = TABLE_H - RAIL_W * 2

  -- Six pocket positions (corners + side midpoints)
  local pockets = {
    -- Top-left corner
    {x = playX + 6,          y = playY + 6,          radius = CORNER_POCKET_R, name = "top_left"},
    -- Top-right corner
    {x = playX + playW - 6,  y = playY + 6,          radius = CORNER_POCKET_R, name = "top_right"},
    -- Bottom-left corner
    {x = playX + 6,          y = playY + playH - 6,  radius = CORNER_POCKET_R, name = "bottom_left"},
    -- Bottom-right corner
    {x = playX + playW - 6,  y = playY + playH - 6,  radius = CORNER_POCKET_R, name = "bottom_right"},
    -- Top-center side pocket
    {x = playX + playW / 2,  y = playY + 2,          radius = SIDE_POCKET_R, name = "top_center"},
    -- Bottom-center side pocket
    {x = playX + playW / 2,  y = playY + playH - 2,  radius = SIDE_POCKET_R, name = "bottom_center"},
  }

  return {
    -- Outer rail bounds
    outerX = TABLE_X,
    outerY = TABLE_Y,
    outerW = TABLE_W,
    outerH = TABLE_H,
    -- Play area (felt surface inside rails)
    playX = playX,
    playY = playY,
    playW = playW,
    playH = playH,
    railW = RAIL_W,
    pockets = pockets,
    pocketRadius = POCKET_RADIUS,
  }
end

return M
