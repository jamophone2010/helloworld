local M = {}

function M.new()
  return {
    x = 0,
    y = 0
  }
end

function M.update(camera, playerX, playerY)
  camera.x = 0
  camera.y = 0
end

return M
