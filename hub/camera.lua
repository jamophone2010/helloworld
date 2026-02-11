local M = {}

function M.new()
  return {
    x = 0,
    y = 0
  }
end

function M.update(camera, playerX, playerY)
  -- Center camera on player using actual screen dimensions
  camera.x = playerX
  camera.y = playerY
end

return M
