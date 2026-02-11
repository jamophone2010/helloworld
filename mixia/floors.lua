-- mixia/floors.lua
-- Multi-level city planet structure (Coruscant/Taris inspired)
-- Level 5: Skyline Terrace (rooftops, landing pads, bright sun)
-- Level 4: Upper District (government, wealthy, clean)
-- Level 3: Commerce Level (shops, markets, entertainment)
-- Level 2: Industrial Zone (factories, workers)
-- Level 1: Lower District (gritty, gangs, dim)
-- Level 0: The Surface (ancient ruins, dark, dangerous - secret)

local M = {}

M.GRID_SIZE = 32

-- Daylight city color palette
M.COLORS = {
  sky = {0.6, 0.8, 0.95},           -- Bright daylight blue
  sun = {1.0, 0.95, 0.8},           -- Warm sunlight
  cloud = {0.95, 0.95, 0.98},       -- White clouds
  white = {0.92, 0.92, 0.94},       -- Clean white buildings
  gray = {0.7, 0.72, 0.75},         -- Gray metal/concrete
  gold = {0.85, 0.75, 0.5},         -- Gold accents
  green = {0.4, 0.7, 0.45},         -- Parks/plants
  industrial = {0.55, 0.5, 0.45},   -- Industrial brown
  rust = {0.6, 0.45, 0.35},         -- Rusty metal
  grime = {0.35, 0.33, 0.3},        -- Lower city grime
  dark = {0.15, 0.13, 0.12},        -- Surface darkness
}

-- Floor metadata
M.floors = {
  [0] = {
    id = 0,
    name = "The Surface",
    subtitle = "Ancient Ruins",
    secret = true,
    unlockCondition = "quest_surface",
    ambience = "dark",
    colorScheme = {bg = M.COLORS.dark, accent = {0.4, 0.25, 0.2}, light = {0.5, 0.35, 0.25}},
    lightLevel = 0.2,  -- Very dark
    width = 35,
    height = 22,
    elevatorPos = {x = 17, y = 11},
    buildings = {
      {name = "Ancient Temple", x = 3, y = 3, w = 8, h = 6, doorX = 6, doorY = 8, interior = "ancient_temple",
       color = {0.3, 0.25, 0.2}, accentColor = {0.5, 0.35, 0.25}},
      {name = "Outcast Camp", x = 25, y = 3, w = 6, h = 5, doorX = 27, doorY = 7, interior = "outcast_camp",
       color = {0.25, 0.22, 0.18}, accentColor = {0.45, 0.35, 0.25}},
      {name = "Buried Vault", x = 14, y = 14, w = 6, h = 5, doorX = 16, doorY = 18, interior = "buried_vault",
       color = {0.2, 0.18, 0.15}, accentColor = {0.4, 0.3, 0.2}},
    },
    npcs = {
      {name = "Surface Dweller", x = 10, y = 10, dialogue = "You shouldn't be down here. The surface hasn't seen sunlight in centuries."},
      {name = "Ruin Scholar", x = 20, y = 12, dialogue = "These ruins predate the city above. A civilization lost to time..."},
      {name = "Outcast Elder", x = 28, y = 10, dialogue = "We were cast down here by the Upper District. But we survive."},
    },
    paths = {
      {x1 = 1, y1 = 9, x2 = 33, y2 = 13},
      {x1 = 10, y1 = 13, x2 = 24, y2 = 20},
    },
  },

  [1] = {
    id = 1,
    name = "Lower District",
    subtitle = "The Slums",
    secret = false,
    ambience = "gritty",
    colorScheme = {bg = M.COLORS.grime, accent = {0.5, 0.4, 0.35}, light = {0.6, 0.5, 0.4}},
    lightLevel = 0.4,  -- Dim, filtered light
    width = 35,
    height = 22,
    elevatorPos = {x = 17, y = 11},
    buildings = {
      {name = "Cantina", x = 2, y = 2, w = 7, h = 5, doorX = 5, doorY = 6, interior = "lower_cantina",
       color = {0.4, 0.35, 0.3}, accentColor = {0.7, 0.5, 0.3}},
      {name = "Black Market", x = 25, y = 2, w = 6, h = 5, doorX = 27, doorY = 6, interior = "black_market",
       color = {0.35, 0.3, 0.28}, accentColor = {0.55, 0.4, 0.3}},
      {name = "Gang HQ", x = 13, y = 2, w = 5, h = 4, doorX = 15, doorY = 5, interior = "gang_hq",
       color = {0.38, 0.32, 0.28}, accentColor = {0.6, 0.35, 0.3}},
      {name = "Flophouse", x = 2, y = 14, w = 6, h = 5, doorX = 4, doorY = 18, interior = "flophouse",
       color = {0.36, 0.32, 0.28}, accentColor = {0.5, 0.4, 0.35}},
      {name = "Pawn Shop", x = 14, y = 14, w = 5, h = 5, doorX = 16, doorY = 18, interior = "pawn_shop",
       color = {0.4, 0.35, 0.3}, accentColor = {0.65, 0.5, 0.35}},
      {name = "Clinic", x = 26, y = 14, w = 5, h = 5, doorX = 28, doorY = 18, interior = "lower_clinic",
       color = {0.42, 0.4, 0.38}, accentColor = {0.6, 0.55, 0.5}},
    },
    npcs = {
      {name = "Shady Dealer", x = 8, y = 10, dialogue = "Looking for something... off the books? I can help. For a price."},
      {name = "Gang Member", x = 20, y = 8, dialogue = "This is Vulkar territory. Watch your step, offworlder."},
      {name = "Street Urchin", x = 12, y = 12, dialogue = "Spare some credits? I haven't eaten since the cargo ships stopped coming."},
      {name = "Weary Worker", x = 24, y = 12, dialogue = "Used to work Industrial. Now? I just try to survive down here."},
      {name = "Old Beggar", x = 10, y = 16, dialogue = "I remember when the sun reached this level. That was... fifty years ago."},
    },
    paths = {
      {x1 = 1, y1 = 7, x2 = 33, y2 = 13},
      {x1 = 9, y1 = 13, x2 = 25, y2 = 20},
    },
  },

  [2] = {
    id = 2,
    name = "Industrial Zone",
    subtitle = "Factory District",
    secret = false,
    ambience = "industrial",
    colorScheme = {bg = M.COLORS.industrial, accent = M.COLORS.rust, light = {0.7, 0.6, 0.5}},
    lightLevel = 0.6,  -- Filtered sunlight, smog
    width = 38,
    height = 24,
    elevatorPos = {x = 19, y = 12},
    buildings = {
      {name = "Factory A", x = 2, y = 2, w = 8, h = 6, doorX = 5, doorY = 7, interior = "factory_a",
       color = {0.5, 0.45, 0.4}, accentColor = {0.65, 0.55, 0.45}},
      {name = "Factory B", x = 28, y = 2, w = 8, h = 6, doorX = 31, doorY = 7, interior = "factory_b",
       color = {0.48, 0.43, 0.38}, accentColor = {0.6, 0.5, 0.4}},
      {name = "Worker Housing", x = 14, y = 2, w = 6, h = 5, doorX = 16, doorY = 6, interior = "worker_housing",
       color = {0.52, 0.48, 0.44}, accentColor = {0.65, 0.58, 0.5}},
      {name = "Power Plant", x = 2, y = 15, w = 7, h = 6, doorX = 5, doorY = 20, interior = "power_plant",
       color = {0.45, 0.42, 0.38}, accentColor = {0.7, 0.55, 0.35}},
      {name = "Cargo Hub", x = 15, y = 15, w = 7, h = 6, doorX = 18, doorY = 20, interior = "cargo_hub",
       color = {0.5, 0.47, 0.42}, accentColor = {0.62, 0.55, 0.45}},
      {name = "Refinery", x = 28, y = 15, w = 7, h = 6, doorX = 31, doorY = 20, interior = "refinery",
       color = {0.47, 0.43, 0.38}, accentColor = {0.6, 0.5, 0.38}},
    },
    npcs = {
      {name = "Factory Foreman", x = 10, y = 10, dialogue = "Keep moving! Quota won't meet itself. Upper District needs their goods."},
      {name = "Tired Worker", x = 22, y = 9, dialogue = "Twelve-hour shifts, six days a week. But it beats the Lower District."},
      {name = "Union Rep", x = 16, y = 12, dialogue = "We're organizing. The workers deserve better. Don't tell management."},
      {name = "Cargo Droid", x = 26, y = 12, dialogue = "UNIT CG-7 OPERATIONAL. SHIPMENT STATUS: 847 CONTAINERS PENDING."},
      {name = "Engineer", x = 8, y = 18, dialogue = "The power grid runs the whole city. Without us, everything goes dark."},
    },
    paths = {
      {x1 = 1, y1 = 8, x2 = 36, y2 = 14},
      {x1 = 10, y1 = 14, x2 = 27, y2 = 22},
    },
  },

  [3] = {
    id = 3,
    name = "Commerce Level",
    subtitle = "Market District",
    secret = false,
    ambience = "vibrant",
    colorScheme = {bg = {0.75, 0.75, 0.78}, accent = M.COLORS.gold, light = M.COLORS.sun},
    lightLevel = 0.85,  -- Bright, colorful
    width = 40,
    height = 24,
    elevatorPos = {x = 20, y = 12},
    buildings = {
      {name = "Grand Bazaar", x = 2, y = 2, w = 9, h = 6, doorX = 6, doorY = 7, interior = "grand_bazaar",
       color = {0.8, 0.75, 0.65}, accentColor = {0.9, 0.8, 0.5}},
      {name = "Tech Emporium", x = 29, y = 2, w = 8, h = 6, doorX = 32, doorY = 7, interior = "tech_emporium",
       color = {0.75, 0.78, 0.82}, accentColor = {0.5, 0.7, 0.9}},
      {name = "Entertainment Hub", x = 15, y = 2, w = 7, h = 5, doorX = 18, doorY = 6, interior = "entertainment_hub",
       color = {0.82, 0.72, 0.75}, accentColor = {0.95, 0.6, 0.7}},
      {name = "Restaurant Row", x = 2, y = 15, w = 8, h = 6, doorX = 5, doorY = 20, interior = "restaurant_row",
       color = {0.78, 0.7, 0.62}, accentColor = {0.9, 0.75, 0.5}},
      {name = "Mission Control", x = 16, y = 15, w = 8, h = 6, doorX = 19, doorY = 20, interior = "mission_control",
       color = {0.7, 0.72, 0.78}, accentColor = {0.5, 0.65, 0.85}},
      {name = "Bank of Mixia", x = 30, y = 15, w = 7, h = 6, doorX = 33, doorY = 20, interior = "bank",
       color = {0.8, 0.78, 0.72}, accentColor = {0.85, 0.75, 0.45}},
    },
    npcs = {
      {name = "Merchant", x = 10, y = 10, dialogue = "Best prices in the sector! Imported goods from a hundred systems!"},
      {name = "Tourist", x = 25, y = 9, dialogue = "Mixia is amazing! The markets here rival Coruscant's. Well, almost."},
      {name = "Street Performer", x = 18, y = 12, dialogue = "~juggles~ Tips appreciated! I perform on every level... except the Surface."},
      {name = "Food Vendor", x = 8, y = 18, dialogue = "Hot noodles! Fresh from the orbital farms! Only 5 credits!"},
      {name = "Wealthy Shopper", x = 32, y = 10, dialogue = "The Upper District has better boutiques, but I do love browsing here."},
    },
    paths = {
      {x1 = 1, y1 = 8, x2 = 38, y2 = 14},
      {x1 = 11, y1 = 14, x2 = 28, y2 = 22},
    },
  },

  [4] = {
    id = 4,
    name = "Upper District",
    subtitle = "Government Quarter",
    secret = false,
    ambience = "elegant",
    colorScheme = {bg = M.COLORS.white, accent = M.COLORS.gold, light = M.COLORS.sun},
    lightLevel = 0.95,  -- Bright sunlight
    width = 38,
    height = 24,
    elevatorPos = {x = 19, y = 12},
    buildings = {
      {name = "Senate Hall", x = 2, y = 2, w = 9, h = 7, doorX = 6, doorY = 8, interior = "senate_hall",
       color = M.COLORS.white, accentColor = M.COLORS.gold},
      {name = "Luxury Apartments", x = 27, y = 2, w = 8, h = 6, doorX = 30, doorY = 7, interior = "luxury_apartments",
       color = {0.9, 0.9, 0.92}, accentColor = {0.7, 0.75, 0.8}},
      {name = "Embassy Row", x = 14, y = 2, w = 7, h = 5, doorX = 17, doorY = 6, interior = "embassy",
       color = {0.88, 0.88, 0.9}, accentColor = {0.6, 0.65, 0.75}},
      {name = "Grand Hotel", x = 2, y = 15, w = 8, h = 6, doorX = 5, doorY = 20, interior = "grand_hotel",
       color = {0.92, 0.9, 0.85}, accentColor = {0.85, 0.75, 0.5}},
      {name = "Museum", x = 15, y = 15, w = 7, h = 6, doorX = 18, doorY = 20, interior = "museum",
       color = {0.9, 0.88, 0.85}, accentColor = {0.75, 0.7, 0.6}},
      {name = "Opera House", x = 28, y = 15, w = 7, h = 6, doorX = 31, doorY = 20, interior = "opera_house",
       color = {0.88, 0.85, 0.82}, accentColor = {0.8, 0.6, 0.55}},
    },
    npcs = {
      {name = "Senator Vorn", x = 10, y = 10, dialogue = "The Lower Districts need reform, but the Council won't listen. Politics..."},
      {name = "Noble Lady", x = 24, y = 9, dialogue = "The air up here is so much cleaner. I simply couldn't live below Commerce."},
      {name = "Embassy Guard", x = 18, y = 8, dialogue = "Move along. Embassy business is classified. For your own safety."},
      {name = "Art Curator", x = 20, y = 18, dialogue = "Our collection spans ten thousand years of galactic history. Priceless."},
      {name = "Butler Droid", x = 30, y = 10, dialogue = "May I be of service? The residents expect the highest standards."},
    },
    paths = {
      {x1 = 1, y1 = 9, x2 = 36, y2 = 14},
      {x1 = 11, y1 = 14, x2 = 26, y2 = 22},
    },
  },

  [5] = {
    id = 5,
    name = "Skyline Terrace",
    subtitle = "Rooftop Level",
    secret = false,
    ambience = "serene",
    colorScheme = {bg = M.COLORS.sky, accent = M.COLORS.cloud, light = M.COLORS.sun},
    lightLevel = 1.0,  -- Full sunlight, open sky
    width = 35,
    height = 22,
    elevatorPos = {x = 17, y = 11},
    buildings = {
      {name = "Observation Deck", x = 3, y = 3, w = 7, h = 5, doorX = 6, doorY = 7, interior = "observation_deck",
       color = {0.85, 0.88, 0.92}, accentColor = {0.6, 0.75, 0.9}},
      {name = "Hangar Bay", x = 24, y = 3, w = 8, h = 6, doorX = 27, doorY = 8, interior = "hangar",
       color = {0.8, 0.82, 0.85}, accentColor = {0.5, 0.6, 0.75}},
      {name = "Sky Lounge", x = 13, y = 3, w = 6, h = 4, doorX = 15, doorY = 6, interior = "sky_lounge",
       color = {0.88, 0.85, 0.9}, accentColor = {0.7, 0.6, 0.8}},
      {name = "Weather Station", x = 3, y = 14, w = 5, h = 5, doorX = 5, doorY = 18, interior = "weather_station",
       color = {0.82, 0.85, 0.88}, accentColor = {0.55, 0.7, 0.85}},
      {name = "Rooftop Gardens", x = 14, y = 14, w = 7, h = 5, doorX = 17, doorY = 18, interior = "rooftop_gardens",
       color = {0.6, 0.75, 0.55}, accentColor = {0.4, 0.65, 0.4}},
      {name = "Control Tower", x = 26, y = 14, w = 5, h = 5, doorX = 28, doorY = 18, interior = "control_tower",
       color = {0.78, 0.8, 0.85}, accentColor = {0.5, 0.65, 0.8}},
    },
    npcs = {
      {name = "Tower Controller", x = 10, y = 10, dialogue = "All incoming traffic, vector to pad 7. Smooth skies today."},
      {name = "Pilot", x = 26, y = 10, dialogue = "Best landing pads in the sector. Clear skies, minimal traffic."},
      {name = "Gardener", x = 18, y = 16, dialogue = "Real plants, real soil. Imported from the surface... before it was lost."},
      {name = "Sunbather", x = 8, y = 8, dialogue = "Pure sunlight. No filters, no smog. Worth every credit to live up here."},
      {name = "Meteorologist", x = 6, y = 16, dialogue = "Weather control keeps it perfect. 22 degrees, light breeze. Every day."},
    },
    paths = {
      {x1 = 1, y1 = 8, x2 = 33, y2 = 13},
      {x1 = 10, y1 = 13, x2 = 24, y2 = 20},
    },
  },
}

-- Floor order for elevator (excludes secrets)
M.elevatorOrder = {1, 2, 3, 4, 5}

-- Get floor definition
function M.getFloor(floorId)
  return M.floors[floorId]
end

-- Get elevator-visible floors
function M.getElevatorFloors(unlockedQuests)
  local result = {}
  for _, id in ipairs(M.elevatorOrder) do
    table.insert(result, id)
  end
  if unlockedQuests and unlockedQuests["quest_surface"] then
    table.insert(result, 1, 0)
  end
  return result
end

-- Get building at position
function M.getBuildingAt(floorId, gridX, gridY)
  local floor = M.floors[floorId]
  if not floor then return nil end
  for _, b in ipairs(floor.buildings) do
    if gridX == b.doorX and gridY == b.doorY then
      return b
    end
  end
  return nil
end

-- Check if on elevator
function M.isOnElevator(floorId, gridX, gridY)
  local floor = M.floors[floorId]
  if not floor then return false end
  local ep = floor.elevatorPos
  return gridX >= ep.x - 1 and gridX <= ep.x + 1 and gridY >= ep.y - 1 and gridY <= ep.y + 1
end

-- Create collision map
function M.createFloorCollisionMap(floorId)
  local floor = M.floors[floorId]
  if not floor then return {} end

  local map = {}
  for y = 0, floor.height - 1 do
    map[y] = {}
    for x = 0, floor.width - 1 do
      if y == 0 or y == floor.height - 1 or x == 0 or x == floor.width - 1 then
        map[y][x] = true
      else
        map[y][x] = false
      end
    end
  end

  -- Buildings solid except doors
  if floor.buildings then
    for _, b in ipairs(floor.buildings) do
      for by = b.y, b.y + b.h - 1 do
        for bx = b.x, b.x + b.w - 1 do
          if map[by] and map[by][bx] ~= nil then
            map[by][bx] = true
          end
        end
      end
      if map[b.doorY] then
        map[b.doorY][b.doorX] = false
      end
    end
  end

  -- Paths walkable
  if floor.paths then
    for _, path in ipairs(floor.paths) do
      for py = path.y1, path.y2 do
        for px = path.x1, path.x2 do
          if map[py] and map[py][px] ~= nil then
            local isPerimeter = (py == 0 or py == floor.height - 1 or px == 0 or px == floor.width - 1)
            local isBuilding = false
            if floor.buildings then
              for _, b in ipairs(floor.buildings) do
                if px >= b.x and px < b.x + b.w and py >= b.y and py < b.y + b.h then
                  isBuilding = true
                  break
                end
              end
            end
            if not isPerimeter and not isBuilding then
              map[py][px] = false
            end
          end
        end
      end
    end
  end

  -- Elevator walkable
  local ep = floor.elevatorPos
  for ey = ep.y - 1, ep.y + 1 do
    for ex = ep.x - 1, ep.x + 1 do
      if map[ey] and map[ey][ex] ~= nil then
        map[ey][ex] = false
      end
    end
  end

  return map
end

return M
