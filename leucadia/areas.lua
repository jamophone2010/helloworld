-- leucadia/areas.lua
-- Beach town layout inspired by Carlsbad/Leucadia, California
-- Single large outdoor map with distinct zones (Cianwood City style but larger)

local M = {}

M.GRID_SIZE = 32

-- Town dimensions (larger than Cianwood)
M.WIDTH = 50
M.HEIGHT = 40

-- Zone definitions for visual theming
M.zones = {
  beach = {
    name = "Leucadia Beach",
    x1 = 0, y1 = 28, x2 = 30, y2 = 39,
    groundColor = {0.95, 0.9, 0.7},  -- Sandy
    ambientSound = "waves"
  },
  pier = {
    name = "The Pier",
    x1 = 31, y1 = 30, x2 = 49, y2 = 39,
    groundColor = {0.45, 0.35, 0.25},  -- Wooden planks
    ambientSound = "waves"
  },
  ocean = {
    name = "Pacific Ocean",
    x1 = 35, y1 = 35, x2 = 49, y2 = 39,
    groundColor = {0.2, 0.5, 0.7},  -- Ocean blue
    isWater = true
  },
  town_square = {
    name = "Town Square",
    x1 = 18, y1 = 16, x2 = 32, y2 = 27,
    groundColor = {0.7, 0.65, 0.55},  -- Cobblestone
    ambientSound = "crowd"
  },
  coast_highway = {
    name = "Coast Highway 101",
    x1 = 0, y1 = 12, x2 = 17, y2 = 27,
    groundColor = {0.5, 0.5, 0.5},  -- Pavement
    ambientSound = "traffic"
  },
  residential = {
    name = "Beachside Homes",
    x1 = 0, y1 = 0, x2 = 25, y2 = 11,
    groundColor = {0.4, 0.65, 0.35},  -- Grass
    ambientSound = "birds"
  },
  flower_fields = {
    name = "Flower Fields",
    x1 = 26, y1 = 0, x2 = 49, y2 = 15,
    groundColor = {0.5, 0.7, 0.4},  -- Lush grass
    ambientSound = "birds"
  },
  mission_district = {
    name = "Mission District",
    x1 = 33, y1 = 16, x2 = 49, y2 = 29,
    groundColor = {0.6, 0.55, 0.45},  -- Adobe/terracotta
    ambientSound = "crowd"
  }
}

-- Buildings in the town
M.buildings = {
  -- Beach Area
  {name = "Surf Shack", x = 5, y = 26, w = 5, h = 3, doorX = 7, doorY = 28, interior = "surf_shop",
   color = {0.2, 0.6, 0.8}, roofColor = {0.15, 0.45, 0.6}},
  {name = "Lifeguard Tower", x = 18, y = 28, w = 3, h = 2, doorX = 19, doorY = 29, interior = "lifeguard",
   color = {0.9, 0.3, 0.2}, roofColor = {0.95, 0.95, 0.95}},

  -- Pier Area
  {name = "Bait & Tackle", x = 35, y = 30, w = 4, h = 3, doorX = 36, doorY = 32, interior = "bait_shop",
   color = {0.5, 0.4, 0.3}, roofColor = {0.35, 0.25, 0.15}},
  {name = "Seafood Grill", x = 41, y = 30, w = 5, h = 3, doorX = 43, doorY = 32, interior = "restaurant",
   color = {0.6, 0.2, 0.15}, roofColor = {0.4, 0.15, 0.1}},

  -- Town Square
  {name = "General Store", x = 18, y = 17, w = 5, h = 4, doorX = 20, doorY = 20, interior = "general_store",
   color = {0.55, 0.45, 0.35}, roofColor = {0.4, 0.3, 0.2}},
  {name = "Bank of Leucadia", x = 25, y = 17, w = 5, h = 4, doorX = 27, doorY = 20, interior = "bank",
   color = {0.4, 0.4, 0.5}, roofColor = {0.3, 0.3, 0.4}},
  {name = "Town Hall", x = 21, y = 22, w = 6, h = 4, doorX = 24, doorY = 25, interior = "town_hall",
   color = {0.7, 0.65, 0.55}, roofColor = {0.5, 0.25, 0.2}},

  -- Coast Highway
  {name = "Beachside Cafe", x = 3, y = 14, w = 5, h = 4, doorX = 5, doorY = 17, interior = "cafe",
   color = {0.85, 0.75, 0.6}, roofColor = {0.65, 0.55, 0.4}},
  {name = "Boutique", x = 10, y = 14, w = 4, h = 4, doorX = 11, doorY = 17, interior = "boutique",
   color = {0.8, 0.5, 0.6}, roofColor = {0.6, 0.35, 0.45}},
  {name = "Taco Stand", x = 3, y = 20, w = 3, h = 3, doorX = 4, doorY = 22, interior = "taco_stand",
   color = {0.9, 0.7, 0.2}, roofColor = {0.7, 0.5, 0.1}},
  {name = "Board Shop", x = 8, y = 20, w = 4, h = 4, doorX = 9, doorY = 23, interior = "board_shop",
   color = {0.3, 0.5, 0.7}, roofColor = {0.2, 0.35, 0.5}},

  -- Residential
  {name = "Beach House 1", x = 3, y = 3, w = 5, h = 4, doorX = 5, doorY = 6, interior = "beach_house_1",
   color = {0.9, 0.9, 0.85}, roofColor = {0.3, 0.5, 0.6}},
  {name = "Beach House 2", x = 10, y = 3, w = 5, h = 4, doorX = 12, doorY = 6, interior = "beach_house_2",
   color = {0.85, 0.85, 0.75}, roofColor = {0.6, 0.3, 0.25}},
  {name = "Beach House 3", x = 17, y = 3, w = 5, h = 4, doorX = 19, doorY = 6, interior = "beach_house_3",
   color = {0.75, 0.85, 0.9}, roofColor = {0.4, 0.55, 0.65}},

  -- Flower Fields
  {name = "Flower Shop", x = 30, y = 5, w = 5, h = 4, doorX = 32, doorY = 8, interior = "flower_shop",
   color = {0.9, 0.7, 0.8}, roofColor = {0.7, 0.5, 0.6}},
  {name = "Greenhouse", x = 40, y = 3, w = 6, h = 5, doorX = 42, doorY = 7, interior = "greenhouse",
   color = {0.4, 0.6, 0.4}, roofColor = {0.6, 0.8, 0.6}},

  -- Mission District (main hub for missions)
  {name = "Mission Control", x = 36, y = 18, w = 7, h = 5, doorX = 39, doorY = 22, interior = "mission_control",
   color = {0.25, 0.35, 0.5}, roofColor = {0.15, 0.2, 0.35}},
  {name = "Hangar", x = 44, y = 18, w = 5, h = 5, doorX = 46, doorY = 22, interior = "hangar",
   color = {0.4, 0.4, 0.45}, roofColor = {0.3, 0.3, 0.35}},
  {name = "Pilot's Lounge", x = 36, y = 24, w = 5, h = 4, doorX = 38, doorY = 27, interior = "pilots_lounge",
   color = {0.5, 0.4, 0.35}, roofColor = {0.35, 0.25, 0.2}},
  {name = "Supply Depot", x = 43, y = 24, w = 5, h = 4, doorX = 45, doorY = 27, interior = "supply_depot",
   color = {0.45, 0.5, 0.4}, roofColor = {0.3, 0.35, 0.25}}
}

-- NPCs wandering outside
M.npcs = {
  -- Beach
  {name = "Surfer Dude", x = 10, y = 32, dialogue = "Waves are gnarly today, bro! Perfect for catching some barrels.", zone = "beach"},
  {name = "Sunbather", x = 14, y = 35, dialogue = "The sun feels amazing... I could lay here forever.", zone = "beach"},
  {name = "Beach Kid", x = 22, y = 33, dialogue = "I found a cool shell! Wanna see?", zone = "beach"},
  {name = "Lifeguard", x = 19, y = 30, dialogue = "Stay safe out there! The rip currents can be tricky.", zone = "beach"},

  -- Pier
  {name = "Old Fisherman", x = 38, y = 34, dialogue = "Been fishing this pier for 40 years. The halibut are running today.", zone = "pier"},
  {name = "Tourist", x = 44, y = 33, dialogue = "What a beautiful view! I can see dolphins out there!", zone = "pier"},

  -- Town Square
  {name = "Mayor Garcia", x = 24, y = 24, dialogue = "Welcome to Leucadia! Our little beach town is the jewel of the coast.", zone = "town_square"},
  {name = "Street Musician", x = 28, y = 23, dialogue = "~strums guitar~ Any requests? I know all the beach classics.", zone = "town_square"},
  {name = "Local Artist", x = 20, y = 22, dialogue = "I paint the sunsets here. Every one is different, you know?", zone = "town_square"},

  -- Coast Highway
  {name = "Skater", x = 6, y = 18, dialogue = "This sidewalk is perfect for cruising. Smooth concrete all the way!", zone = "coast_highway"},
  {name = "Dog Walker", x = 12, y = 22, dialogue = "My pup loves the beach! We walk here every day.", zone = "coast_highway"},
  {name = "Jogger", x = 8, y = 25, dialogue = "Morning runs along the coast... nothing beats it!", zone = "coast_highway"},

  -- Residential
  {name = "Retired Pilot", x = 8, y = 8, dialogue = "I flew missions back in the day. Those youngsters at Mission Control remind me of my squadron.", zone = "residential"},
  {name = "Neighbor Nancy", x = 15, y = 5, dialogue = "The neighborhood watch keeps things peaceful. Well, mostly the ocean does.", zone = "residential"},

  -- Flower Fields
  {name = "Gardener", x = 35, y = 10, dialogue = "The ranunculus are in bloom! Fifty acres of color stretching to the horizon.", zone = "flower_fields"},
  {name = "Bee Keeper", x = 44, y = 8, dialogue = "My bees love these flowers. Best honey in the whole system.", zone = "flower_fields"},

  -- Mission District
  {name = "Deck Chief Luna", x = 40, y = 25, dialogue = "Ready to fly, pilot? We've got missions waiting.", zone = "mission_district"},
  {name = "Mechanic Rusty", x = 47, y = 20, dialogue = "Your ship is fueled and ready. I tuned up the engines myself.", zone = "mission_district"},
  {name = "Intel Officer", x = 38, y = 20, dialogue = "We're tracking enemy movements in several sectors. Check Mission Control for details.", zone = "mission_district"}
}

-- Decorations and obstacles
M.decorations = {
  -- Palm trees along beach
  {type = "palm_tree", x = 2, y = 30},
  {type = "palm_tree", x = 8, y = 29},
  {type = "palm_tree", x = 15, y = 30},
  {type = "palm_tree", x = 25, y = 29},

  -- Beach umbrellas
  {type = "umbrella", x = 6, y = 34, color = {0.9, 0.2, 0.2}},
  {type = "umbrella", x = 12, y = 36, color = {0.2, 0.6, 0.9}},
  {type = "umbrella", x = 20, y = 35, color = {0.9, 0.9, 0.2}},

  -- Town square fountain
  {type = "fountain", x = 24, y = 19, w = 3, h = 3},

  -- Flower patches in flower fields
  {type = "flowers", x = 28, y = 2, w = 4, h = 3, color = {1.0, 0.3, 0.4}},
  {type = "flowers", x = 34, y = 1, w = 5, h = 2, color = {1.0, 0.8, 0.2}},
  {type = "flowers", x = 38, y = 10, w = 3, h = 3, color = {0.9, 0.4, 0.7}},
  {type = "flowers", x = 45, y = 6, w = 3, h = 2, color = {0.3, 0.5, 0.9}},

  -- Benches
  {type = "bench", x = 22, y = 21},
  {type = "bench", x = 27, y = 21},
  {type = "bench", x = 5, y = 16},

  -- Street lamps along highway
  {type = "lamp", x = 1, y = 15},
  {type = "lamp", x = 1, y = 19},
  {type = "lamp", x = 1, y = 23},
  {type = "lamp", x = 14, y = 15},
  {type = "lamp", x = 14, y = 23}
}

-- Spawn point when entering town
M.spawnPoint = {x = 24, y = 26}  -- Center of town square

-- Get zone at position
function M.getZoneAt(gridX, gridY)
  for name, zone in pairs(M.zones) do
    if gridX >= zone.x1 and gridX <= zone.x2 and gridY >= zone.y1 and gridY <= zone.y2 then
      return name, zone
    end
  end
  return nil, nil
end

-- Get building at door position
function M.getBuildingAt(gridX, gridY)
  for _, b in ipairs(M.buildings) do
    if gridX == b.doorX and gridY == b.doorY then
      return b
    end
  end
  return nil
end

-- Create collision map for the town
function M.createCollisionMap()
  local map = {}
  for y = 0, M.HEIGHT - 1 do
    map[y] = {}
    for x = 0, M.WIDTH - 1 do
      -- Perimeter walls
      if y == 0 or y == M.HEIGHT - 1 or x == 0 or x == M.WIDTH - 1 then
        map[y][x] = true
      else
        map[y][x] = false
      end
    end
  end

  -- Buildings are solid except doors
  for _, b in ipairs(M.buildings) do
    for by = b.y, b.y + b.h - 1 do
      for bx = b.x, b.x + b.w - 1 do
        if map[by] and map[by][bx] ~= nil then
          map[by][bx] = true
        end
      end
    end
    -- Door is walkable
    if map[b.doorY] then
      map[b.doorY][b.doorX] = false
    end
  end

  -- Ocean is not walkable (except pier)
  local oceanZone = M.zones.ocean
  for y = oceanZone.y1, oceanZone.y2 do
    for x = oceanZone.x1, oceanZone.x2 do
      if map[y] and map[y][x] ~= nil then
        map[y][x] = true
      end
    end
  end

  -- Pier walkway over ocean
  for y = 30, 34 do
    for x = 31, 49 do
      if map[y] and map[y][x] ~= nil then
        map[y][x] = false
      end
    end
  end

  -- Decorations with collision
  for _, deco in ipairs(M.decorations) do
    if deco.type == "palm_tree" or deco.type == "fountain" or deco.type == "lamp" then
      local w = deco.w or 1
      local h = deco.h or 1
      for dy = 0, h - 1 do
        for dx = 0, w - 1 do
          if map[deco.y + dy] and map[deco.y + dy][deco.x + dx] ~= nil then
            map[deco.y + dy][deco.x + dx] = true
          end
        end
      end
    end
  end

  return map
end

return M
