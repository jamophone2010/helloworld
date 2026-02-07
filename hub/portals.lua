local M = {}

function M.getNearbyPortal(player, portals)
  if not portals then return nil end
  
  for _, portal in ipairs(portals) do
    if player.gridX == portal.x and player.gridY == portal.y then
      return portal
    end
  end
  return nil
end

function M.getEnteredPortal(player, portals)
  if not portals then return nil end
  
  for _, portal in ipairs(portals) do
    if player.gridX == portal.x and player.gridY == portal.y and not player.moving then
      return portal
    end
  end
  return nil
end

return M
