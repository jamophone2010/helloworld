local M = {}

M.PORTALS = {
  {
    name = "Slot Machine",
    x = 200,
    y = 150,
    radius = 60,
    color = {1, 0.8, 0},
    game = "slotmachine"
  },
  {
    name = "Roulette",
    x = 600,
    y = 150,
    radius = 60,
    color = {1, 0.2, 0.2},
    game = "roulette"
  },
  {
    name = "Blackjack",
    x = 200,
    y = 450,
    radius = 60,
    color = {0.2, 0.8, 0.2},
    game = "blackjack"
  },
  {
    name = "starfox",
    x = 600,
    y = 450,
    radius = 40,
    color = {0.3, 0.5, 1},
    game = "starfox"
  },
  {
    name = "Asteroids",
    x = 60,
    y = 50,
    radius = 100,
    color = {0.3, 0.5, 0.8},
    game = "asteroids"
  }
}

function M.checkCollision(player, portal)
  local dx = player.x - portal.x
  local dy = player.y - portal.y
  local distance = math.sqrt(dx * dx + dy * dy)

  return distance < (player.radius + portal.radius)
end

function M.getNearbyPortal(player)
  for _, portal in ipairs(M.PORTALS) do
    local dx = player.x - portal.x
    local dy = player.y - portal.y
    local distance = math.sqrt(dx * dx + dy * dy)

    if distance < portal.radius + 30 then
      return portal
    end
  end
  return nil
end

function M.getEnteredPortal(player)
  for _, portal in ipairs(M.PORTALS) do
    if M.checkCollision(player, portal) then
      return portal
    end
  end
  return nil
end

return M
