-- hub/planetmap.lua
-- LOTR-style map of planets and stations in the galaxy

local M = {}

M.returnToHub = nil

-- Station definitions with circular arrangement (hub worlds only)
local PLANETS = {
  -- Inner ring - Core stations
  {id = 1, name = "Hometown Station", type = "station", ring = "inner", angle = 0,
   description = "The neon heart of commerce and adventure. A bustling hub where traders, pilots, and dreamers converge beneath flickering holograms.",
   hubType = "hometown"},
  {id = 2, name = "Leucadia", type = "station", ring = "inner", angle = 120,
   description = "Sun-drenched beach paradise on the California coast. Surfers and pilots alike find rest among the palms and golden sand.",
   hubType = "leucadia"},
  {id = 3, name = "Singularity", type = "station", ring = "inner", angle = 240,
   description = "A station perched at the very edge of a black hole. Time bends here, and so does reality.",
   hubType = "singularity"},
  
  -- Middle ring - Outer stations
  {id = 4, name = "Mixia", type = "station", ring = "middle", angle = 90,
   description = "A vertical city planet of endless towers stretching into the clouds. Elevators connect worlds within worlds.",
   hubType = "mixia"},
  {id = 5, name = "Elendil", type = "station", ring = "middle", angle = 270,
   description = "A medieval fantasy village nestled among rolling hills and ancient oaks. Half-timbered houses line cobblestone paths beside a gentle river.",
   hubType = "elendil"},
  {id = 6, name = "Chillon", type = "station", ring = "middle", angle = 180,
   description = "An ice planet of towering snow-capped peaks and Nordic longhouses. Troll-infested mountain trails wind through frozen valleys beneath the aurora borealis.",
   hubType = "chillon"},

  -- Outer ring - Deep Space
  {id = 7, name = "Kala Patthar", type = "station", ring = "outer", angle = 45,
   description = "A remote mountaineering outpost in Deep Space, inspired by Everest Base Camp. Prayer flags snap in the cosmic wind as sherpas share legends of the four Muses.",
   hubType = "kalapatthar"},

  {id = 8, name = "Cereus", type = "station", ring = "middle", angle = 0,
   description = "A desert arboretum inspired by Arizona's Boyce Thompson, where ancient saguaros stand sentinel over winding trails through cactus gardens and eucalyptus groves.",
   hubType = "cereus"},
}

local selectedIndex = 1
local scrollTime = 0
local stars = {}
local nebulae = {}

-- Ring radii for layout
local RINGS = {
  inner = 100,
  middle = 180,
  outer = 260
}

function M.enter()
  selectedIndex = 1
  scrollTime = 0
  
  -- Generate starfield
  stars = {}
  for i = 1, 200 do
    table.insert(stars, {
      x = math.random(0, 800),
      y = math.random(0, 600),
      size = math.random() * 2 + 0.5,
      brightness = math.random() * 0.5 + 0.5,
      twinklePhase = math.random() * math.pi * 2
    })
  end
  
  -- Generate nebula clouds
  nebulae = {}
  for i = 1, 5 do
    table.insert(nebulae, {
      x = math.random(100, 700),
      y = math.random(100, 500),
      size = math.random(80, 150),
      color = {
        math.random() * 0.3 + 0.3,
        math.random() * 0.3 + 0.2,
        math.random() * 0.4 + 0.4
      },
      alpha = math.random() * 0.15 + 0.05
    })
  end
end

function M.update(dt)
  scrollTime = scrollTime + dt
end

function M.draw()
  local screenW = love.graphics.getWidth()
  local screenH = love.graphics.getHeight()
  local centerX = screenW / 2
  local centerY = screenH / 2
  
  -- Space background
  love.graphics.setColor(0.02, 0.02, 0.08)
  love.graphics.rectangle("fill", 0, 0, screenW, screenH)
  
  -- Draw nebulae
  for _, nebula in ipairs(nebulae) do
    love.graphics.setColor(nebula.color[1], nebula.color[2], nebula.color[3], nebula.alpha)
    for i = 1, 3 do
      local spread = nebula.size * (i * 0.4)
      love.graphics.circle("fill", nebula.x, nebula.y, spread)
    end
  end
  
  -- Draw stars
  for _, star in ipairs(stars) do
    local twinkle = math.sin(scrollTime * 2 + star.twinklePhase) * 0.3 + 0.7
    love.graphics.setColor(1, 1, 1, star.brightness * twinkle)
    love.graphics.circle("fill", star.x, star.y, star.size)
  end
  
  -- Draw connection rings with labels
  love.graphics.setLineWidth(2)
  local ringNames = {inner = "Inner Ring", middle = "Middle Ring", outer = "Outer Ring"}
  local ringColors = {
    inner = {0.4, 0.5, 0.7, 0.3},
    middle = {0.5, 0.4, 0.6, 0.3},
    outer = {0.6, 0.4, 0.4, 0.3}
  }
  for ringName, radius in pairs(RINGS) do
    local rc = ringColors[ringName] or {0.3, 0.3, 0.4, 0.3}
    love.graphics.setColor(rc[1], rc[2], rc[3], rc[4])
    love.graphics.circle("line", centerX, centerY, radius)
    -- Ring label
    love.graphics.setColor(rc[1] + 0.2, rc[2] + 0.2, rc[3] + 0.2, 0.5)
    love.graphics.print(ringNames[ringName] or ringName, centerX + radius - 30, centerY - radius - 16)
  end
  
  -- Draw connections between all stations
  love.graphics.setColor(0.4, 0.4, 0.5, 0.15)
  love.graphics.setLineWidth(1)
  for i, planet in ipairs(PLANETS) do
    for j, other in ipairs(PLANETS) do
      if i < j then
        local angle1 = math.rad(planet.angle)
        local angle2 = math.rad(other.angle)
        local r1 = RINGS[planet.ring]
        local r2 = RINGS[other.ring]
        local x1 = centerX + math.cos(angle1) * r1
        local y1 = centerY + math.sin(angle1) * r1
        local x2 = centerX + math.cos(angle2) * r2
        local y2 = centerY + math.sin(angle2) * r2
        love.graphics.line(x1, y1, x2, y2)
      end
    end
  end
  
  -- Draw planets/stations
  for i, planet in ipairs(PLANETS) do
    local angle = math.rad(planet.angle)
    local radius = RINGS[planet.ring]
    local x = centerX + math.cos(angle) * radius
    local y = centerY + math.sin(angle) * radius
    
    local isSelected = (i == selectedIndex)
    
    -- Glow for selected
    if isSelected then
      love.graphics.setColor(0.8, 0.7, 0.3, 0.3)
      love.graphics.circle("fill", x, y, 18)
    end
    
    -- Station icon - octagon shape
    local stationColor = {
      hometown = {0.5, 0.6, 0.7},
      leucadia = {0.4, 0.7, 0.5},
      singularity = {0.6, 0.4, 0.7},
      mixia = {0.7, 0.6, 0.4},
      kalapatthar = {0.7, 0.5, 0.3},
      cereus = {0.85, 0.65, 0.3},
      elendil = {0.3, 0.7, 0.4},
      chillon = {0.5, 0.6, 0.8},
    }
    local sc = stationColor[planet.hubType] or {0.5, 0.6, 0.7}
    love.graphics.setColor(sc[1], sc[2], sc[3])
    local points = {}
    for a = 0, 7 do
      local pa = a * math.pi / 4
      table.insert(points, x + math.cos(pa) * 12)
      table.insert(points, y + math.sin(pa) * 12)
    end
    love.graphics.polygon("fill", points)
    love.graphics.setColor(sc[1] + 0.2, sc[2] + 0.2, sc[3] + 0.2)
    love.graphics.polygon("line", points)
    
    -- Planet name
    love.graphics.setColor(0.8, 0.8, 0.9)
    local nameWidth = love.graphics.getFont():getWidth(planet.name)
    love.graphics.print(planet.name, x - nameWidth / 2, y + 15)
  end
  
  -- Selected planet info panel (LOTR style parchment)
  local selected = PLANETS[selectedIndex]
  local panelW = 400
  local panelH = 150
  local panelX = centerX - panelW / 2
  local panelY = screenH - panelH - 20
  
  -- Parchment background
  love.graphics.setColor(0.12, 0.10, 0.08, 0.85)
  love.graphics.rectangle("fill", panelX, panelY, panelW, panelH, 10, 10)
  love.graphics.setColor(0.4, 0.35, 0.25)
  love.graphics.setLineWidth(3)
  love.graphics.rectangle("line", panelX, panelY, panelW, panelH, 10, 10)
  
  -- Decorative corners
  love.graphics.setColor(0.6, 0.5, 0.3)
  love.graphics.setLineWidth(2)
  local cornerSize = 15
  -- Top left
  love.graphics.line(panelX + 5, panelY + 5, panelX + cornerSize, panelY + 5)
  love.graphics.line(panelX + 5, panelY + 5, panelX + 5, panelY + cornerSize)
  -- Top right
  love.graphics.line(panelX + panelW - 5, panelY + 5, panelX + panelW - cornerSize, panelY + 5)
  love.graphics.line(panelX + panelW - 5, panelY + 5, panelX + panelW - 5, panelY + cornerSize)
  -- Bottom left
  love.graphics.line(panelX + 5, panelY + panelH - 5, panelX + cornerSize, panelY + panelH - 5)
  love.graphics.line(panelX + 5, panelY + panelH - 5, panelX + 5, panelY + panelH - cornerSize)
  -- Bottom right
  love.graphics.line(panelX + panelW - 5, panelY + panelH - 5, panelX + panelW - cornerSize, panelY + panelH - 5)
  love.graphics.line(panelX + panelW - 5, panelY + panelH - 5, panelX + panelW - 5, panelY + panelH - cornerSize)
  
  -- Planet name
  love.graphics.setColor(0.9, 0.85, 0.7)
  love.graphics.print(selected.name, panelX + 20, panelY + 15)
  
  -- Ring indicator
  local ringNames = {inner = "Inner Ring", middle = "Middle Ring", outer = "Outer Ring"}
  local ringColors = {
    inner = {0.6, 0.8, 1.0},
    middle = {0.8, 0.7, 1.0},
    outer = {1.0, 0.7, 0.6}
  }
  local rc = ringColors[selected.ring] or {0.7, 0.7, 0.8}
  love.graphics.setColor(rc[1], rc[2], rc[3])
  love.graphics.print(ringNames[selected.ring] or "Unknown", panelX + 20, panelY + 40)
  
  -- Description
  love.graphics.setColor(0.8, 0.75, 0.65)
  love.graphics.printf(selected.description, panelX + 20, panelY + 60, panelW - 40, "left")
  
  -- Action prompt
  love.graphics.setColor(0.7, 0.9, 0.7)
  love.graphics.print("~ ENTER to Travel ~", panelX + 20, panelY + panelH - 30)
  
  -- Instructions
  love.graphics.setColor(0.6, 0.6, 0.7, 0.7)
  love.graphics.print("Arrow Keys: Navigate", 20, screenH - 40)
  love.graphics.print("ESC: Return", 20, screenH - 20)
end

function M.keypressed(key)
  if key == "escape" then
    if M.returnToHub then
      M.returnToHub()
    end
  elseif key == "up" or key == "left" then
    selectedIndex = selectedIndex - 1
    if selectedIndex < 1 then
      selectedIndex = #PLANETS
    end
  elseif key == "down" or key == "right" then
    selectedIndex = selectedIndex + 1
    if selectedIndex > #PLANETS then
      selectedIndex = 1
    end
  elseif key == "return" or key == "space" then
    local selected = PLANETS[selectedIndex]
    if selected.hubType and M.returnToHub then
      -- Travel to this station (internal transfer, not from space)
      M.returnToHub({hubType = selected.hubType, fromPlanetMap = true})
    end
  end
end

return M
