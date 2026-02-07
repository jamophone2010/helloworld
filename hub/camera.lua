local M = {}

function M.new()
  return {
    x = 0,
    y = 0,
    screenWidth = 800,
    screenHeight = 600
  }
end

function M.update(camera, playerX, playerY)
  -- Center camera on player
  camera.x = playerX - camera.screenWidth / 2
  camera.y = playerY - camera.screenHeight / 2
  
  -- Optional: Add bounds to camera if desired
  -- For now, allow free camera movement
end

return M
