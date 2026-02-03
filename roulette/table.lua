local M = {}

local GRID_START_X = 250
local GRID_START_Y = 50
local CELL_WIDTH = 40
local CELL_HEIGHT = 40

M.GRID_NUMBERS = {
  {3, 6, 9, 12, 15, 18, 21, 24, 27, 30, 33, 36},
  {2, 5, 8, 11, 14, 17, 20, 23, 26, 29, 32, 35},
  {1, 4, 7, 10, 13, 16, 19, 22, 25, 28, 31, 34}
}

function M.new()
  return {
    gridX = GRID_START_X,
    gridY = GRID_START_Y,
    cellWidth = CELL_WIDTH,
    cellHeight = CELL_HEIGHT
  }
end

function M.getNumberPosition(table, number)
  for row = 1, 3 do
    for col = 1, 12 do
      if M.GRID_NUMBERS[row][col] == number then
        local x = table.gridX + (col - 1) * table.cellWidth
        local y = table.gridY + row * table.cellHeight
        return x, y
      end
    end
  end
  return nil, nil
end

function M.getBetFromClick(table, mx, my)
  local gridX = table.gridX
  local gridY = table.gridY
  local cellW = table.cellWidth
  local cellH = table.cellHeight

  if mx >= gridX and mx <= gridX + cellW and my >= gridY and my <= gridY + cellH then
    return {type = "straight", numbers = {0}}
  end

  if mx >= gridX + cellW and mx <= gridX + 2 * cellW and my >= gridY and my <= gridY + cellH then
    return {type = "straight", numbers = {"00"}}
  end

  for row = 1, 3 do
    for col = 1, 12 do
      local x = gridX + (col - 1) * cellW
      local y = gridY + row * cellH

      if mx >= x and mx < x + cellW and my >= y and my < y + cellH then
        return {type = "straight", numbers = {M.GRID_NUMBERS[row][col]}}
      end
    end
  end

  if my >= gridY + 4 * cellH and my <= gridY + 5 * cellH then
    if mx >= gridX and mx < gridX + 4 * cellW then
      return {type = "dozen", numbers = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12}}
    elseif mx >= gridX + 4 * cellW and mx < gridX + 8 * cellW then
      return {type = "dozen", numbers = {13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24}}
    elseif mx >= gridX + 8 * cellW and mx < gridX + 12 * cellW then
      return {type = "dozen", numbers = {25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36}}
    end
  end

  if mx >= gridX + 12 * cellW and mx <= gridX + 13 * cellW then
    if my >= gridY + cellH and my < gridY + 2 * cellH then
      return {type = "column", numbers = {3, 6, 9, 12, 15, 18, 21, 24, 27, 30, 33, 36}}
    elseif my >= gridY + 2 * cellH and my < gridY + 3 * cellH then
      return {type = "column", numbers = {2, 5, 8, 11, 14, 17, 20, 23, 26, 29, 32, 35}}
    elseif my >= gridY + 3 * cellH and my < gridY + 4 * cellH then
      return {type = "column", numbers = {1, 4, 7, 10, 13, 16, 19, 22, 25, 28, 31, 34}}
    end
  end

  if my >= gridY + 5 * cellH and my <= gridY + 6 * cellH then
    local sectionWidth = (12 * cellW) / 6
    local section = math.floor((mx - gridX) / sectionWidth)

    if section == 0 then
      return {type = "low", numbers = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18}}
    elseif section == 1 then
      return {type = "even", numbers = {2, 4, 6, 8, 10, 12, 14, 16, 18, 20, 22, 24, 26, 28, 30, 32, 34, 36}}
    elseif section == 2 then
      return {type = "red", numbers = {1, 3, 5, 7, 9, 12, 14, 16, 18, 19, 21, 23, 25, 27, 30, 32, 34, 36}}
    elseif section == 3 then
      return {type = "black", numbers = {2, 4, 6, 8, 10, 11, 13, 15, 17, 20, 22, 24, 26, 28, 29, 31, 33, 35}}
    elseif section == 4 then
      return {type = "odd", numbers = {1, 3, 5, 7, 9, 11, 13, 15, 17, 19, 21, 23, 25, 27, 29, 31, 33, 35}}
    elseif section == 5 then
      return {type = "high", numbers = {19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36}}
    end
  end

  return nil
end

return M
