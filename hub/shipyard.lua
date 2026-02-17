-- hub/shipyard.lua
-- Ship purchasing system on Floor 2 (Commerce Deck)
-- Ships must be purchased here before they become available in the Hangar on Floor 4
-- Shows ship stats, previews, and prices

local M = {}

M.active = false
M.selectedShip = 1
M.confirmingPurchase = false
M.time = 0
M.previewAngle = 0
M.purchasedShips = {} -- Tracks which ships have been bought (by id)
M.onPurchase = nil -- Callback: onPurchase(shipId)

-- Ship catalog (must match starfox/ships.lua definitions)
-- Starwing is free (starter ship, always available)
M.catalog = {
  {
    id = "starwing",
    name = "Starwing",
    price = 0,
    currency = "notes",
    description = "Standard-issue fighter. Reliable and balanced.",
    stats = {health = 3, speed = 1.0, fireRate = 1.0, special = "none"},
    color = {0.6, 0.6, 0.7},
    shape = "balanced",
    tier = "starter"
  },
  {
    id = "lancer",
    name = "Lancer",
    price = 500,
    currency = "notes",
    description = "Precision targeting craft. Locks on to multiple enemies.",
    stats = {health = 2, speed = 1.25, fireRate = 1.25, special = "multilock"},
    color = {0.3, 0.8, 1.0},
    shape = "sleek",
    tier = "advanced"
  },
  {
    id = "paladin",
    name = "Paladin",
    price = 500,
    currency = "notes",
    description = "Heavy armored defender. Slower but extremely tough.",
    stats = {health = 5, speed = 0.75, fireRate = 0.75, special = "reflectshield"},
    color = {0.9, 0.8, 0.2},
    shape = "heavy",
    tier = "advanced"
  },
  {
    id = "mistral",
    name = "Mistral",
    price = 800,
    currency = "notes",
    description = "Lightning-fast interceptor. Fragile but deadly speed.",
    stats = {health = 1, speed = 1.5, fireRate = 1.5, special = "phaseshift"},
    color = {0.7, 0.3, 0.9},
    shape = "fast",
    tier = "elite"
  },
  {
    id = "phantom",
    name = "Phantom",
    price = 1200,
    currency = "notes",
    description = "Experimental stealth craft. The pinnacle of engineering.",
    stats = {health = 2, speed = 1.25, fireRate = 1.0, special = "cloak"},
    color = {0.2, 0.2, 0.3},
    shape = "stealth",
    tier = "legendary"
  },
  {
    id = "firebird",
    name = "Firebird",
    price = 0,
    currency = "notes",
    description = "Born from Vela's pulsar fire. Immune to cold, bullets burn, Inferno clears all.",
    stats = {health = 4, speed = 1.1, fireRate = 1.0, special = "inferno"},
    color = {0.75, 0.12, 0.08},
    shape = "muscle",
    tier = "legendary",
    dropOnly = true  -- Cannot be purchased, only obtained from Vela dungeon boss
  },
}

function M.enter(purchasedList)
  M.active = true
  M.time = 0
  M.confirmingPurchase = false
  M.selectedShip = 1
  -- Starwing is always purchased
  M.purchasedShips = purchasedList or {starwing = true}
  if not M.purchasedShips.starwing then
    M.purchasedShips.starwing = true
  end
end

function M.exit()
  M.active = false
  return M.purchasedShips
end

function M.update(dt)
  if not M.active then return end
  M.time = M.time + dt
  M.previewAngle = M.previewAngle + dt * 0.8
end

function M.keypressed(key, notes)
  if not M.active then return false end
  notes = notes or 0

  if M.confirmingPurchase then
    if key == "return" then
      -- Process purchase
      local ship = M.catalog[M.selectedShip]
      if ship and not M.purchasedShips[ship.id] and notes >= ship.price then
        M.purchasedShips[ship.id] = true
        if M.onPurchase then
          M.onPurchase(ship.id, ship.price)
        end
      end
      M.confirmingPurchase = false
      return true
    elseif key == "escape" then
      M.confirmingPurchase = false
      return true
    end
    return true
  end

  if key == "escape" then
    M.exit()
    return true
  elseif key == "up" then
    M.selectedShip = M.selectedShip - 1
    if M.selectedShip < 1 then M.selectedShip = #M.catalog end
    return true
  elseif key == "down" then
    M.selectedShip = M.selectedShip + 1
    if M.selectedShip > #M.catalog then M.selectedShip = 1 end
    return true
  elseif key == "return" then
    local ship = M.catalog[M.selectedShip]
    if ship and not M.purchasedShips[ship.id] and ship.price > 0 then
      M.confirmingPurchase = true
    end
    return true
  end

  return false
end

-- Draw a ship preview (rotating wireframe-style)
local function drawShipPreview(ship, cx, cy, size, time)
  local r, g, b = ship.color[1], ship.color[2], ship.color[3]
  local angle = M.previewAngle

  -- Ship silhouette based on shape type
  love.graphics.push()
  love.graphics.translate(cx, cy)

  -- Gentle rotation feel (oscillate scale for 3D illusion)
  local scaleX = 0.8 + 0.2 * math.cos(angle)
  love.graphics.scale(scaleX, 1)

  local hw = size / 2
  local hh = size / 3

  -- Hull glow
  for i = 3, 1, -1 do
    love.graphics.setColor(r, g, b, 0.05 / i)
    love.graphics.circle("fill", 0, 0, size * 0.6 + i * 8)
  end

  -- Draw ship shape
  local vertices = {}
  if ship.shape == "balanced" then
    vertices = {hw, 0, -hw*0.3, -hh, -hw, 0, -hw*0.3, hh}
  elseif ship.shape == "sleek" then
    vertices = {hw, 0, hw*0.3, -hh*0.8, -hw*0.5, -hh*0.4, -hw, 0, -hw*0.5, hh*0.4, hw*0.3, hh*0.8}
  elseif ship.shape == "heavy" then
    vertices = {hw*0.8, 0, hw*0.5, -hh, -hw*0.3, -hh*1.2, -hw, -hh*0.8, -hw, hh*0.8, -hw*0.3, hh*1.2, hw*0.5, hh}
  elseif ship.shape == "fast" then
    vertices = {hw*1.2, 0, hw*0.2, -hh*0.6, -hw*0.8, -hh*0.3, -hw, 0, -hw*0.8, hh*0.3, hw*0.2, hh*0.6}
  elseif ship.shape == "stealth" then
    vertices = {hw, 0, hw*0.3, -hh*0.5, -hw*0.2, -hh*0.8, -hw, -hh*0.3, -hw, hh*0.3, -hw*0.2, hh*0.8, hw*0.3, hh*0.5}
  elseif ship.shape == "muscle" then
    -- 1969 Pontiac GTO inspired: wide, aggressive stance, hood scoop
    vertices = {hw*1.1, 0, hw*0.6, -hh*0.9, hw*0.1, -hh*1.0, -hw*0.1, -hh*1.0, -hw*0.6, -hh*0.9, -hw*1.1, 0, -hw*0.7, hh*0.7, -hw*0.3, hh*1.0, hw*0.3, hh*1.0, hw*0.7, hh*0.7}
    -- Fire effect drawn separately below
  end

  if #vertices >= 6 then
    -- Filled hull
    love.graphics.setColor(r * 0.3, g * 0.3, b * 0.3, 0.8)
    love.graphics.polygon("fill", vertices)

    -- Neon outline
    love.graphics.setColor(r, g, b, 0.9)
    love.graphics.setLineWidth(2)
    love.graphics.polygon("line", vertices)
    love.graphics.setLineWidth(1)
  end

  -- Engine glow
  local enginePulse = 0.5 + 0.5 * math.sin(time * 5)
  love.graphics.setColor(0.3, 0.5, 1.0, enginePulse * 0.6)
  love.graphics.circle("fill", -hw * 0.8, 0, size * 0.08)

  -- Gentle fire aura for Firebird (muscle shape)
  if ship.shape == "muscle" then
    local firePulse = 0.5 + 0.3 * math.sin(time * 3) + 0.2 * math.sin(time * 7)
    -- Soft red outer glow
    love.graphics.setColor(0.9, 0.15, 0.05, 0.06 * firePulse)
    love.graphics.circle("fill", 0, 0, size * 0.9)
    -- Warm orange mid glow
    love.graphics.setColor(1, 0.4, 0.08, 0.08 * firePulse)
    love.graphics.circle("fill", 0, 0, size * 0.5)
    -- Small flickering flame wisps
    for fi = 1, 4 do
      local fAngle = time * 2 + fi * 1.57
      local fx = math.cos(fAngle) * hw * 0.6
      local fy = math.sin(fAngle) * hh * 0.5
      love.graphics.setColor(1, 0.3 + math.sin(time * 5 + fi) * 0.2, 0.05, 0.12 * firePulse)
      love.graphics.circle("fill", fx, fy, 3 + math.sin(time * 8 + fi) * 1.5)
    end
  end

  love.graphics.pop()
end

-- Draw a stat bar
local function drawStatBar(x, y, w, label, value, maxVal, r, g, b)
  love.graphics.setColor(0.6, 0.6, 0.7)
  love.graphics.print(label, x, y)

  love.graphics.setColor(0.1, 0.1, 0.15)
  love.graphics.rectangle("fill", x + 80, y + 2, w, 12, 2)

  local fill = value / maxVal
  love.graphics.setColor(r, g, b, 0.8)
  love.graphics.rectangle("fill", x + 80, y + 2, w * fill, 12, 2)

  love.graphics.setColor(r, g, b, 0.4)
  love.graphics.setLineWidth(1)
  love.graphics.rectangle("line", x + 80, y + 2, w, 12, 2)
end

function M.draw(notes)
  if not M.active then return end
  notes = notes or 0

  local screenW, screenH = love.graphics.getDimensions()

  -- Dark shipyard background
  love.graphics.setColor(0.02, 0.03, 0.06)
  love.graphics.rectangle("fill", 0, 0, screenW, screenH)

  -- Grid pattern (hangar floor feel)
  love.graphics.setColor(0.05, 0.06, 0.1)
  for x = 0, screenW, 40 do
    love.graphics.line(x, 0, x, screenH)
  end
  for y = 0, screenH, 40 do
    love.graphics.line(0, y, screenW, y)
  end

  -- Title
  love.graphics.setColor(0.0, 0.8, 1.0)
  love.graphics.printf("═══ SHIPYARD ═══", 0, 15, screenW, "center")

  -- Funds display
  love.graphics.setColor(0.8, 0.8, 0.2)
  love.graphics.printf("Notes: " .. notes .. "♪", 0, 40, screenW - 40, "right")

  -- === LEFT: Ship list ===
  local listX = 30
  local listY = 70

  for i, ship in ipairs(M.catalog) do
    local sy = listY + (i - 1) * 50
    local isSelected = i == M.selectedShip
    local isPurchased = M.purchasedShips[ship.id]

    -- Selection box
    if isSelected then
      love.graphics.setColor(0.0, 0.4, 0.6, 0.3)
      love.graphics.rectangle("fill", listX, sy, 300, 46, 4)
      love.graphics.setColor(0.0, 0.8, 1.0, 0.7)
      love.graphics.setLineWidth(2)
      love.graphics.rectangle("line", listX, sy, 300, 46, 4)
      love.graphics.setLineWidth(1)
    end

    -- Ship color dot
    love.graphics.setColor(ship.color[1], ship.color[2], ship.color[3])
    love.graphics.circle("fill", listX + 15, sy + 23, 6)

    -- Ship name
    love.graphics.setColor(isPurchased and 0.5 or 1, isPurchased and 0.5 or 1, isPurchased and 0.5 or 1)
    love.graphics.print(ship.name, listX + 30, sy + 5)

    -- Tier badge
    local tierColors = {
      starter = {0.5, 0.5, 0.5},
      advanced = {0.3, 0.7, 1.0},
      elite = {0.7, 0.3, 0.9},
      legendary = {1.0, 0.8, 0.2}
    }
    local tc = tierColors[ship.tier] or {0.5, 0.5, 0.5}
    love.graphics.setColor(tc[1], tc[2], tc[3], 0.8)
    love.graphics.print("[" .. ship.tier:upper() .. "]", listX + 30, sy + 24)

    -- Price or OWNED
    if isPurchased then
      love.graphics.setColor(0.2, 0.8, 0.2)
      love.graphics.print("OWNED", listX + 220, sy + 12)
    elseif ship.dropOnly then
      love.graphics.setColor(0.6, 0.4, 0.2)
      love.graphics.print("BOSS DROP", listX + 210, sy + 12)
    elseif ship.price == 0 then
      love.graphics.setColor(0.5, 0.8, 0.5)
      love.graphics.print("FREE", listX + 220, sy + 12)
    else
      local canAfford = notes >= ship.price
      love.graphics.setColor(canAfford and 0.8 or 0.5, canAfford and 0.8 or 0.3, canAfford and 0.2 or 0.3)
      love.graphics.print(ship.price .. "♪", listX + 220, sy + 12)
    end
  end

  -- === RIGHT: Ship preview and details ===
  local ship = M.catalog[M.selectedShip]
  if ship then
    local detailX = 370
    local detailY = 70

    -- Ship preview
    drawShipPreview(ship, detailX + 250, detailY + 140, 120, M.time)

    -- Ship name (large)
    love.graphics.setColor(ship.color[1], ship.color[2], ship.color[3])
    love.graphics.printf(ship.name, detailX + 80, detailY + 280, 340, "center")

    -- Description
    love.graphics.setColor(0.7, 0.7, 0.8)
    love.graphics.printf(ship.description, detailX + 50, detailY + 310, 400, "center")

    -- Stats
    local statsY = detailY + 350
    drawStatBar(detailX + 70, statsY, 150, "Health", ship.stats.health, 5, 0.2, 0.8, 0.2)
    drawStatBar(detailX + 70, statsY + 22, 150, "Speed", ship.stats.speed, 1.5, 0.2, 0.6, 1.0)
    drawStatBar(detailX + 70, statsY + 44, 150, "Fire Rate", ship.stats.fireRate, 1.5, 1.0, 0.5, 0.2)

    -- Special ability
    love.graphics.setColor(0.8, 0.6, 1.0)
    love.graphics.print("Special: " .. (ship.stats.special == "none" and "—" or ship.stats.special), detailX + 70, statsY + 72)

    -- Purchase prompt
    local isPurchased = M.purchasedShips[ship.id]
    if isPurchased then
      love.graphics.setColor(0.2, 0.8, 0.2, 0.8)
      love.graphics.printf("✓ Ship acquired - available in Hangar (Floor 4)", detailX + 50, statsY + 110, 400, "center")
    elseif ship.price == 0 then
      love.graphics.setColor(0.5, 0.8, 0.5)
      love.graphics.printf("Included with station clearance", detailX + 50, statsY + 110, 400, "center")
    else
      local canAfford = notes >= ship.price
      if canAfford then
        love.graphics.setColor(0.0, 0.8, 1.0, 0.6 + 0.4 * math.sin(M.time * 3))
        love.graphics.printf("Press ENTER to purchase for " .. ship.price .. "♪", detailX + 50, statsY + 110, 400, "center")
      else
        love.graphics.setColor(0.6, 0.3, 0.3)
        love.graphics.printf("Insufficient Notes (" .. ship.price .. "♪ required)", detailX + 50, statsY + 110, 400, "center")
      end
    end
  end

  -- Confirm dialog
  if M.confirmingPurchase then
    local ship2 = M.catalog[M.selectedShip]
    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.rectangle("fill", screenW/2 - 200, screenH/2 - 60, 400, 120, 8)
    love.graphics.setColor(0.0, 0.8, 1.0, 0.9)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", screenW/2 - 200, screenH/2 - 60, 400, 120, 8)
    love.graphics.setLineWidth(1)

    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("Purchase " .. ship2.name .. " for " .. ship2.price .. "♪?", screenW/2 - 180, screenH/2 - 40, 360, "center")
    love.graphics.setColor(0.0, 0.8, 0.4)
    love.graphics.printf("ENTER to confirm", screenW/2 - 180, screenH/2 + 10, 360, "center")
    love.graphics.setColor(0.8, 0.3, 0.3)
    love.graphics.printf("ESC to cancel", screenW/2 - 180, screenH/2 + 35, 360, "center")
  end

  -- Controls
  love.graphics.setColor(0.4, 0.4, 0.5, 0.6)
  love.graphics.printf("↑↓ Browse  |  ENTER Purchase  |  ESC Exit", 0, screenH - 22, screenW, "center")
end

return M
