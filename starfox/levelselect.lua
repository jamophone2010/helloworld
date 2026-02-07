local M = {}

-- Progression state (set externally from hub)
M.hasMegaAntenna = false
M.hasPowerAmplifier = false
M.returnToHub = nil -- Callback to return to hub

-- Ring configuration
local RINGS = {
  center = { -- Space Station at center
    radius = 0,
    name = "The Station",
    subtitle = "~ Return to thy haven ~",
    color = {0.85, 0.75, 0.55},
    accessible = function() return true end
  },
  inner = { -- Blue path - immediate access
    radius = 120,
    name = "The Near Reaches",
    subtitle = "~ Seek not permission, for these lands lie open ~",
    color = {0.4, 0.5, 0.7},
    accessible = function() return true end
  },
  middle = { -- Yellow path - needs Mega Antenna
    radius = 200,
    name = "The Middle Marches",
    subtitle = "~ The Mega Antenna unlocks passage ~",
    color = {0.75, 0.65, 0.3},
    accessible = function() return M.hasMegaAntenna end
  },
  outer = { -- Red path - needs Power Amplifier
    radius = 280,
    name = "The Outer Darkness",
    subtitle = "~ Only the Power Amplifier pierces this veil ~",
    color = {0.7, 0.3, 0.3},
    accessible = function() return M.hasPowerAmplifier end
  }
}

-- Level definitions with ring assignments
local LOCATIONS = {
  -- Center: Space Station
  {id = 0, name = "Station", ring = "center", angle = 0,
   description = "Return to the safety of thy haven"},

  -- Inner Ring (Blue Path) - 4 levels evenly spaced
  {id = 1, name = "Corneria", ring = "inner", angle = 0,
   description = "Where journeys begin, the homeworld awaits"},
  {id = 2, name = "Meteo", ring = "inner", angle = 90,
   description = "An asteroid field of ancient stone and starlight"},
  {id = 4, name = "Fortuna", ring = "inner", angle = 180,
   description = "A world of mist and forgotten battles"},
  {id = 8, name = "Sector X", ring = "inner", angle = 270,
   description = "The ruins of a weapon, vast and terrible"},

  -- Inner Ring Boss
  {id = 19, name = "Warden", ring = "inner", angle = 45, isBoss = true,
   description = "Guardian of the Near Reaches. Defeat to claim the Mega Antenna"},

  -- Middle Ring (Yellow Path) - 5 levels evenly spaced
  {id = 5, name = "Katina", ring = "middle", angle = 0,
   description = "A besieged outpost, allies cry for aid"},
  {id = 11, name = "Titania", ring = "middle", angle = 72,
   description = "Desert wastes hide secrets beneath the sand"},
  {id = 7, name = "Solar", ring = "middle", angle = 144,
   description = "The burning heart of flame and fury"},
  {id = 10, name = "Macbeth", ring = "middle", angle = 216,
   description = "Iron rails lead to a fortress of steel"},
  {id = 13, name = "Bolse", ring = "middle", angle = 288,
   description = "A satellite of war, orbiting doom"},

  -- Middle Ring Boss
  {id = 20, name = "Sentinel", ring = "middle", angle = 36, isBoss = true,
   description = "Guardian of the Middle Marches. Defeat to claim the Power Amplifier"},

  -- Outer Ring (Red Path) - 9 levels evenly spaced
  {id = 3, name = "Sector Y", ring = "outer", angle = 0,
   description = "A graveyard of ships, echoes of war"},
  {id = 6, name = "Aquas", ring = "outer", angle = 40,
   description = "Beneath the waves, leviathans stir"},
  {id = 9, name = "Zoness", ring = "outer", angle = 80,
   description = "A paradise defiled, poisoned waters"},
  {id = 12, name = "Sector Z", ring = "outer", angle = 120,
   description = "Missiles fly through the void of space"},
  {id = 15, name = "Fichina", ring = "outer", angle = 160,
   description = "Ice and treachery, a base betrayed"},
  {id = 14, name = "Area 6", ring = "outer", angle = 200,
   description = "The final defense, an armada awaits"},
  {id = 16, name = "Outer", ring = "outer", angle = 240,
   description = "Beyond the known, into darkness"},
  {id = 17, name = "Venom II", ring = "outer", angle = 280,
   description = "The shadow of evil, doubled in might"},
  {id = 18, name = "Venom", ring = "outer", angle = 320,
   description = "The dark throne, where Andross awaits"}
}

local selectedIndex = 1
local parchmentTexture = {}
local scrollTime = 0
local fadeAlpha = 0

-- LOTR-style decorative elements
local decorations = {
  corners = {},
  vines = {}
}

function M.load()
  selectedIndex = 1
  scrollTime = 0
  fadeAlpha = 1

  -- Generate parchment texture pattern
  parchmentTexture = {}
  for i = 1, 200 do
    table.insert(parchmentTexture, {
      x = math.random(800),
      y = math.random(600),
      size = math.random(2, 8),
      alpha = math.random() * 0.15 + 0.05
    })
  end

  -- Generate vine decorations for borders
  decorations.vines = {}
  for i = 1, 40 do
    table.insert(decorations.vines, {
      x = math.random() < 0.5 and math.random(0, 60) or math.random(740, 800),
      y = math.random(600),
      length = math.random(20, 60),
      curve = math.random() * 2 - 1
    })
  end
end

function M.getSelected()
  return LOCATIONS[selectedIndex]
end

function M.getSelectedId()
  return LOCATIONS[selectedIndex].id
end

function M.getLocations()
  return LOCATIONS
end

function M.getRings()
  return RINGS
end

-- Check if a location is accessible based on progression
function M.isAccessible(location)
  if location.id == 0 then return true end
  local ring = RINGS[location.ring]
  return ring and ring.accessible()
end

-- Navigate between locations
function M.navigate(direction)
  local current = LOCATIONS[selectedIndex]
  local currentRing = RINGS[current.ring]
  local best = nil
  local bestScore = math.huge

  -- Calculate current position
  local cx, cy = 400, 300
  if current.ring ~= "center" then
    local rad = math.rad(current.angle - 90)
    cx = 400 + math.cos(rad) * currentRing.radius
    cy = 300 + math.sin(rad) * currentRing.radius
  end

  for i, loc in ipairs(LOCATIONS) do
    if i ~= selectedIndex then
      local ring = RINGS[loc.ring]
      local lx, ly = 400, 300
      if loc.ring ~= "center" then
        local rad = math.rad(loc.angle - 90)
        lx = 400 + math.cos(rad) * ring.radius
        ly = 300 + math.sin(rad) * ring.radius
      end

      local dx = lx - cx
      local dy = ly - cy
      local dist = math.sqrt(dx*dx + dy*dy)

      local valid = false
      local score = dist

      if direction == "up" and dy < -20 then
        valid = true
        score = dist + math.abs(dx) * 0.5
      elseif direction == "down" and dy > 20 then
        valid = true
        score = dist + math.abs(dx) * 0.5
      elseif direction == "left" and dx < -20 then
        valid = true
        score = dist + math.abs(dy) * 0.5
      elseif direction == "right" and dx > 20 then
        valid = true
        score = dist + math.abs(dy) * 0.5
      end

      if valid and score < bestScore then
        bestScore = score
        best = i
      end
    end
  end

  if best then
    selectedIndex = best
  end
end

function M.update(dt)
  scrollTime = scrollTime + dt

  -- Fade in effect
  if fadeAlpha > 0 then
    fadeAlpha = fadeAlpha - dt * 2
    if fadeAlpha < 0 then fadeAlpha = 0 end
  end
end

function M.draw()
  local centerX, centerY = 400, 300

  -- Background: aged parchment
  love.graphics.setColor(0.92, 0.87, 0.76)
  love.graphics.rectangle("fill", 0, 0, 800, 600)

  -- Parchment texture spots (age marks)
  for _, spot in ipairs(parchmentTexture) do
    love.graphics.setColor(0.7, 0.6, 0.45, spot.alpha)
    love.graphics.circle("fill", spot.x, spot.y, spot.size)
  end

  -- Darker edges (vignette effect)
  love.graphics.setColor(0.4, 0.3, 0.2, 0.3)
  for i = 0, 40 do
    local alpha = (40 - i) / 40 * 0.4
    love.graphics.setColor(0.3, 0.2, 0.1, alpha * 0.3)
    love.graphics.rectangle("line", i, i, 800 - i*2, 600 - i*2)
  end

  -- Decorative border
  love.graphics.setColor(0.45, 0.35, 0.2)
  love.graphics.setLineWidth(3)
  love.graphics.rectangle("line", 15, 15, 770, 570)
  love.graphics.setLineWidth(1)
  love.graphics.rectangle("line", 20, 20, 760, 560)

  -- Corner flourishes
  local flourish = "~*~"
  love.graphics.setColor(0.4, 0.3, 0.15)
  love.graphics.print(flourish, 25, 18)
  love.graphics.print(flourish, 755, 18)
  love.graphics.print(flourish, 25, 565)
  love.graphics.print(flourish, 755, 565)

  -- Title with LOTR styling
  love.graphics.setColor(0.25, 0.15, 0.05)
  local title = "~ The Lylat Realms ~"
  local titleWidth = love.graphics.getFont():getWidth(title)
  love.graphics.print(title, centerX - titleWidth/2, 35)

  -- Subtitle
  love.graphics.setColor(0.4, 0.3, 0.15)
  local subtitle = "Choose thy destination, brave pilot"
  local subWidth = love.graphics.getFont():getWidth(subtitle)
  love.graphics.print(subtitle, centerX - subWidth/2, 55)

  -- Draw ring circles
  love.graphics.setLineWidth(2)
  for name, ring in pairs(RINGS) do
    if ring.radius > 0 then
      local accessible = ring.accessible()
      if accessible then
        love.graphics.setColor(ring.color[1], ring.color[2], ring.color[3], 0.4)
      else
        love.graphics.setColor(0.5, 0.45, 0.4, 0.2)
      end
      love.graphics.circle("line", centerX, centerY, ring.radius)

      -- Ring label
      love.graphics.setColor(ring.color[1] * 0.7, ring.color[2] * 0.7, ring.color[3] * 0.7, accessible and 0.8 or 0.3)
      local labelY = centerY - ring.radius - 12
      local labelWidth = love.graphics.getFont():getWidth(ring.name)
      love.graphics.print(ring.name, centerX - labelWidth/2, labelY)
    end
  end
  love.graphics.setLineWidth(1)

  -- Draw locations
  for i, loc in ipairs(LOCATIONS) do
    local ring = RINGS[loc.ring]
    local x, y = centerX, centerY

    if ring.radius > 0 then
      local rad = math.rad(loc.angle - 90)
      x = centerX + math.cos(rad) * ring.radius
      y = centerY + math.sin(rad) * ring.radius
    end

    local isSelected = (i == selectedIndex)
    local accessible = M.isAccessible(loc)

    -- Location marker
    local markerSize = isSelected and 14 or 10
    if loc.isBoss then
      markerSize = isSelected and 16 or 12
    end

    -- Pulsing effect for selected
    if isSelected then
      local pulse = math.sin(scrollTime * 4) * 0.2 + 0.8
      markerSize = markerSize * pulse
    end

    if loc.id == 0 then
      -- Space Station - special icon (diamond shape)
      love.graphics.setColor(0.7, 0.6, 0.4, accessible and 1 or 0.4)
      local s = markerSize
      love.graphics.polygon("fill", x, y-s, x+s, y, x, y+s, x-s, y)
      love.graphics.setColor(0.3, 0.2, 0.1)
      love.graphics.polygon("line", x, y-s, x+s, y, x, y+s, x-s, y)
    elseif loc.isBoss then
      -- Boss marker (star shape)
      if accessible then
        love.graphics.setColor(0.8, 0.5, 0.2)
      else
        love.graphics.setColor(0.5, 0.45, 0.4, 0.4)
      end
      -- Draw star
      local points = {}
      for j = 0, 9 do
        local r = (j % 2 == 0) and markerSize or (markerSize * 0.5)
        local a = math.rad(j * 36 - 90)
        table.insert(points, x + math.cos(a) * r)
        table.insert(points, y + math.sin(a) * r)
      end
      love.graphics.polygon("fill", points)
      love.graphics.setColor(0.3, 0.2, 0.1)
      love.graphics.polygon("line", points)
    else
      -- Regular location marker (circle)
      if accessible then
        love.graphics.setColor(ring.color[1], ring.color[2], ring.color[3])
      else
        love.graphics.setColor(0.5, 0.45, 0.4, 0.4)
      end
      love.graphics.circle("fill", x, y, markerSize)
      love.graphics.setColor(0.3, 0.2, 0.1)
      love.graphics.circle("line", x, y, markerSize)
    end

    -- Location name
    if isSelected or loc.id == 0 then
      love.graphics.setColor(0.2, 0.1, 0.05, accessible and 1 or 0.5)
      local nameWidth = love.graphics.getFont():getWidth(loc.name)
      love.graphics.print(loc.name, x - nameWidth/2, y + markerSize + 4)
    end
  end

  -- Selected location info panel (bottom)
  local selected = LOCATIONS[selectedIndex]
  local accessible = M.isAccessible(selected)

  -- Info panel background
  love.graphics.setColor(0.85, 0.8, 0.7, 0.9)
  love.graphics.rectangle("fill", 50, 500, 700, 80, 5, 5)
  love.graphics.setColor(0.4, 0.3, 0.2)
  love.graphics.rectangle("line", 50, 500, 700, 80, 5, 5)

  -- Selected name
  love.graphics.setColor(0.25, 0.15, 0.05)
  local selName = "~ " .. selected.name .. " ~"
  local selWidth = love.graphics.getFont():getWidth(selName)
  love.graphics.print(selName, 400 - selWidth/2, 510)

  -- Description
  love.graphics.setColor(0.4, 0.3, 0.15)
  local descWidth = love.graphics.getFont():getWidth(selected.description)
  love.graphics.print(selected.description, 400 - descWidth/2, 530)

  -- Access status
  if not accessible then
    love.graphics.setColor(0.6, 0.3, 0.2)
    local ring = RINGS[selected.ring]
    local lockMsg = ring.subtitle
    local lockWidth = love.graphics.getFont():getWidth(lockMsg)
    love.graphics.print(lockMsg, 400 - lockWidth/2, 550)
  else
    love.graphics.setColor(0.3, 0.5, 0.3)
    local accessMsg = "Press ENTER to embark upon this quest"
    if selected.id == 0 then
      accessMsg = "Press ENTER to return to thy haven"
    end
    local accessWidth = love.graphics.getFont():getWidth(accessMsg)
    love.graphics.print(accessMsg, 400 - accessWidth/2, 550)
  end

  -- Progression indicators (top right)
  love.graphics.setColor(0.4, 0.3, 0.15)
  love.graphics.print("Artifacts:", 650, 75)

  if M.hasMegaAntenna then
    love.graphics.setColor(0.6, 0.5, 0.2)
    love.graphics.print("[Mega Antenna]", 650, 95)
  else
    love.graphics.setColor(0.5, 0.45, 0.4, 0.5)
    love.graphics.print("[???]", 650, 95)
  end

  if M.hasPowerAmplifier then
    love.graphics.setColor(0.6, 0.5, 0.2)
    love.graphics.print("[Power Amplifier]", 650, 115)
  else
    love.graphics.setColor(0.5, 0.45, 0.4, 0.5)
    love.graphics.print("[???]", 650, 115)
  end

  -- Controls hint (bottom left)
  love.graphics.setColor(0.5, 0.4, 0.3, 0.7)
  love.graphics.print("Arrow keys: Navigate", 60, 75)
  love.graphics.print("ENTER: Select", 60, 95)
  love.graphics.print("ESC: Return", 60, 115)

  -- Fade overlay
  if fadeAlpha > 0 then
    love.graphics.setColor(0, 0, 0, fadeAlpha)
    love.graphics.rectangle("fill", 0, 0, 800, 600)
  end
end

function M.keypressed(key)
  if key == "up" or key == "down" or key == "left" or key == "right" then
    M.navigate(key)
  elseif key == "return" or key == "space" then
    local selected = LOCATIONS[selectedIndex]
    if M.isAccessible(selected) then
      if selected.id == 0 then
        -- Return to station (hub) instead of starting a mission
        if M.returnToHub then
          M.returnToHub()
        end
        return false
      end
      return true -- Signal to start mission
    end
  elseif key == "escape" then
    -- Find and select station
    for i, loc in ipairs(LOCATIONS) do
      if loc.id == 0 then
        selectedIndex = i
        break
      end
    end
  end
  return false
end

return M
