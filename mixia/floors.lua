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
    name = "Inside the PC",
    subtitle = "Temple of Peril",
    secret = true,
    unlockCondition = "quest_surface",
    ambience = "dark",
    colorScheme = {bg = {0.05, 0.08, 0.06}, accent = {0.2, 0.8, 0.3}, light = {0.4, 1.0, 0.5}},
    lightLevel = 0.25,
    width = 35,
    height = 22,
    elevatorPos = {x = 17, y = 11},
    buildings = {
      {name = "The PC Case", x = 10, y = 3, w = 14, h = 7, doorX = 16, doorY = 10, interior = "ancient_citadel_maze",
       color = {0.15, 0.15, 0.18}, accentColor = {0.2, 0.8, 0.3},
       archStyle = "industrial"},
    },
    npcs = {
      {name = "BIOS Guardian", x = 12, y = 12, dialogue = "The Case holds components beyond imagination... and hazards beyond survival. Dust bunnies lurk in every corner. Turn back while you can.", gender = "male"},
      {name = "Overclocker", x = 22, y = 12, dialogue = "Beware the dust bunny stampede. Only the swift survive. If you had some Compressed Air, the dust wouldn't be so bad...", gender = "female", design = 3},
    },
    paths = {
      {x1 = 1, y1 = 9, x2 = 33, y2 = 14},
      {x1 = 14, y1 = 8, x2 = 20, y2 = 15},
    },
  },

  [1] = {
    id = 1,
    name = "The Surface",
    subtitle = "Jungle Night Market",
    secret = false,
    ambience = "jungle_night",
    colorScheme = {bg = {0.05, 0.08, 0.04}, accent = {0.2, 0.55, 0.25}, light = {0.3, 0.9, 0.4}},
    lightLevel = 0.3,  -- Nighttime, lit by bioluminescence and neon
    width = 40,
    height = 24,
    elevatorPos = {x = 20, y = 12},
    buildings = {
      {name = "Mos Eisley Cantina", x = 2, y = 2, w = 8, h = 5, doorX = 5, doorY = 7, interior = "surface_cantina",
       color = {0.15, 0.2, 0.12}, accentColor = {0.9, 0.3, 0.1},
       neonSign = {text = "CANTINA", color = {1, 0.3, 0.1}, glowRadius = 40}},
      {name = "Smuggler's Den", x = 28, y = 2, w = 7, h = 5, doorX = 31, doorY = 7, interior = "smugglers_den",
       color = {0.12, 0.15, 0.1}, accentColor = {0.1, 0.7, 1.0},
       neonSign = {text = "SMUGGLER'S", color = {0.1, 0.7, 1.0}, glowRadius = 35}},
      {name = "Smugglers' Shack", x = 14, y = 2, w = 6, h = 4, doorX = 16, doorY = 6, interior = "smugglers_shack",
       color = {0.14, 0.16, 0.1}, accentColor = {1.0, 0.85, 0.2},
       neonSign = {text = "SMUGGLERS'", color = {1.0, 0.85, 0.2}, glowRadius = 30}},
      {name = "Xeno Bazaar", x = 2, y = 15, w = 7, h = 5, doorX = 5, doorY = 20, interior = "xeno_bazaar",
       color = {0.1, 0.18, 0.12}, accentColor = {0.8, 0.2, 0.9},
       neonSign = {text = "XENO BAZAAR", color = {0.8, 0.2, 0.9}, glowRadius = 45}},
      {name = "The Golden Vault", x = 15, y = 15, w = 8, h = 6, doorX = 18, doorY = 21, interior = "golden_vault_casino",
       color = {0.08, 0.06, 0.04}, accentColor = {0.85, 0.7, 0.2},
       neonSign = {text = "GOLDEN VAULT", color = {1.0, 0.85, 0.3}, glowRadius = 50}},
      {name = "Mechanic's Garage", x = 30, y = 15, w = 6, h = 5, doorX = 32, doorY = 20, interior = "surface_mechanic",
       color = {0.12, 0.14, 0.1}, accentColor = {0.4, 0.8, 0.6}},
    },
    npcs = {
      {name = "Captain Vex", x = 10, y = 10, dialogue = "Name's Vex. Fastest ship in the Outer Rim — well, second fastest. Don't tell anyone.", species = "human", style = "smuggler", gender = "male"},
      {name = "Zik'tal", x = 22, y = 9, dialogue = "You want cargo moved? No manifest, no questions. I am the best in this sector.", species = "insectoid", style = "pirate", gender = "male"},
      {name = "Mira Solstice", x = 16, y = 12, dialogue = "I run the night market. Everyone's welcome — if your credits are good.", species = "twi_lek", style = "merchant", gender = "female", design = 1},
      {name = "Groot Jr.", x = 9, y = 18, dialogue = "I am Groot.", species = "flora_colossus", style = "gentle_giant", gender = "male"},
      {name = "Rocket Analog", x = 34, y = 10, dialogue = "Yeah, I'm a talking raccoon-thing. You got a problem with that? Didn't think so.", species = "raccoonoid", style = "scrappy", gender = "male"},
      {name = "DJ Nebula", x = 26, y = 12, dialogue = "The Surface never sleeps! Best beats in the galaxy, right here.", species = "energy_being", style = "performer", gender = "female", design = 2},
      {name = "Tech Scavenger Kira", x = 12, y = 18, dialogue = "Psst! I salvaged a can of Compressed Air from an old server room. Clears dust like nobody's business. 10,000 credits and it's yours... if you've got the winnings.", species = "human", style = "scavenger", gender = "female", design = 4, sellsCompressedAir = true, price = 10000},
    },
    -- Environment features for rendering
    environment = {
      canopy = true,        -- Rainforest canopy overhead
      fireflies = true,     -- Bioluminescent particles
      vines = true,         -- Hanging vines
      mushrooms = true,     -- Glowing mushrooms on ground
      mist = true,          -- Low-lying jungle mist
    },
    paths = {
      {x1 = 1, y1 = 6, x2 = 39, y2 = 15},
      {x1 = 8, y1 = 14, x2 = 29, y2 = 23},
      {x1 = 9, y1 = 5, x2 = 14, y2 = 16},
      {x1 = 22, y1 = 5, x2 = 28, y2 = 16},
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
    -- Backdrop architecture visible through windows/gaps
    backdrop = {
      style = "gothic_industrial",  -- Massive buttresses, cathedral-like factory halls
      features = {"flying_buttresses", "rose_windows", "iron_arches", "steam_vents"},
      depth_layers = 3,  -- Parallax depth
    },
    buildings = {
      {name = "Factory A", x = 2, y = 2, w = 8, h = 6, doorX = 5, doorY = 8, interior = "factory_a",
       color = {0.62, 0.58, 0.52}, accentColor = {0.45, 0.38, 0.32},
       archStyle = "iron_arch"},
      {name = "Factory B", x = 28, y = 2, w = 8, h = 6, doorX = 31, doorY = 8, interior = "factory_b",
       color = {0.58, 0.55, 0.48}, accentColor = {0.42, 0.36, 0.3},
       archStyle = "gothic_window"},
      {name = "Worker Housing", x = 14, y = 2, w = 6, h = 5, doorX = 16, doorY = 7, interior = "worker_housing",
       color = {0.65, 0.6, 0.54}, accentColor = {0.48, 0.42, 0.35}},
      {name = "Power Plant", x = 2, y = 15, w = 7, h = 6, doorX = 5, doorY = 21, interior = "power_plant",
       color = {0.56, 0.52, 0.46}, accentColor = {0.5, 0.42, 0.3},
       archStyle = "cathedral"},
      {name = "Cargo Hub", x = 15, y = 15, w = 7, h = 6, doorX = 18, doorY = 21, interior = "cargo_hub",
       color = {0.6, 0.56, 0.5}, accentColor = {0.45, 0.4, 0.34}},
      {name = "Refinery", x = 28, y = 15, w = 7, h = 6, doorX = 31, doorY = 21, interior = "refinery",
       color = {0.58, 0.54, 0.48}, accentColor = {0.42, 0.38, 0.32},
       archStyle = "iron_arch"},
    },
    npcs = {
      {name = "Factory Foreman", x = 12, y = 11, dialogue = "Keep moving! Quota won't meet itself. Upper District needs their goods.", gender = "male"},
      {name = "Tired Worker", x = 24, y = 10, dialogue = "Twelve-hour shifts, six days a week. But it beats the Lower District.", gender = "female", design = 6},
      {name = "Union Rep", x = 19, y = 13, dialogue = "We're organizing. The workers deserve better. Don't tell management.", gender = "female", design = 6},
      {name = "Cargo Droid", x = 30, y = 12, dialogue = "UNIT CG-7 OPERATIONAL. SHIPMENT STATUS: 847 CONTAINERS PENDING.", gender = "male"},
      {name = "Engineer", x = 14, y = 18, dialogue = "The power grid runs the whole city. Without us, everything goes dark.", gender = "male"},
    },
    paths = {
      {x1 = 1, y1 = 7, x2 = 37, y2 = 15},
      {x1 = 9, y1 = 14, x2 = 28, y2 = 23},
      {x1 = 9, y1 = 6, x2 = 15, y2 = 16},
      {x1 = 21, y1 = 6, x2 = 29, y2 = 16},
      -- Spur paths to upper building doors
      {x1 = 4, y1 = 7, x2 = 6, y2 = 8},
      {x1 = 15, y1 = 6, x2 = 17, y2 = 7},
      {x1 = 30, y1 = 7, x2 = 32, y2 = 8},
      -- Spur paths to lower building doors
      {x1 = 4, y1 = 20, x2 = 6, y2 = 21},
      {x1 = 17, y1 = 20, x2 = 19, y2 = 21},
      {x1 = 30, y1 = 20, x2 = 32, y2 = 21},
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
    -- Fancy architectural views
    backdrop = {
      style = "art_deco",  -- Ornate columns, mosaic floors, grand atriums
      features = {"marble_columns", "mosaic_floors", "grand_arches", "crystal_chandeliers", "gilded_railings"},
      depth_layers = 3,
    },
    buildings = {
      {name = "Grand Bazaar", x = 2, y = 2, w = 9, h = 6, doorX = 6, doorY = 8, interior = "grand_bazaar",
       color = {0.85, 0.8, 0.72}, accentColor = {0.7, 0.6, 0.38},
       archStyle = "grand_arch"},
      {name = "Tech Emporium", x = 29, y = 2, w = 8, h = 6, doorX = 32, doorY = 8, interior = "tech_emporium",
       color = {0.82, 0.78, 0.72}, accentColor = {0.65, 0.58, 0.42},
       archStyle = "crystal_dome"},
      {name = "Entertainment Hub", x = 15, y = 2, w = 7, h = 5, doorX = 18, doorY = 7, interior = "entertainment_hub",
       color = {0.88, 0.82, 0.74}, accentColor = {0.72, 0.55, 0.4},
       archStyle = "art_deco"},
      {name = "Restaurant Row", x = 2, y = 15, w = 8, h = 6, doorX = 5, doorY = 21, interior = "restaurant_row",
       color = {0.84, 0.78, 0.68}, accentColor = {0.7, 0.6, 0.4},
       archStyle = "marble_column"},
      {name = "Mission Control", x = 16, y = 15, w = 8, h = 6, doorX = 19, doorY = 21, interior = "mission_control",
       color = {0.8, 0.76, 0.7}, accentColor = {0.55, 0.5, 0.4}},
      {name = "Bank of Mixia", x = 30, y = 15, w = 7, h = 6, doorX = 33, doorY = 21, interior = "bank",
       color = {0.86, 0.82, 0.74}, accentColor = {0.72, 0.62, 0.38},
       archStyle = "grand_arch"},
    },
    npcs = {
      {name = "Merchant", x = 12, y = 10, dialogue = "Best prices in the sector! Imported goods from a hundred systems!", gender = "male"},
      {name = "Tourist", x = 26, y = 10, dialogue = "Mixia is amazing! The markets here rival Coruscant's. Well, almost.", gender = "female", design = 3},
      {name = "Street Performer", x = 20, y = 12, dialogue = "~juggles~ Tips appreciated! I perform on every level... except the Surface.", gender = "male"},
      {name = "Food Vendor", x = 14, y = 18, dialogue = "Hot noodles! Fresh from the orbital farms! Only 5 credits!", gender = "female", design = 2},
      {name = "Wealthy Shopper", x = 34, y = 12, dialogue = "The Upper District has better boutiques, but I do love browsing here.", gender = "female", design = 1},
    },
    paths = {
      {x1 = 1, y1 = 7, x2 = 39, y2 = 15},
      {x1 = 10, y1 = 14, x2 = 29, y2 = 23},
      {x1 = 10, y1 = 6, x2 = 16, y2 = 16},
      {x1 = 21, y1 = 6, x2 = 30, y2 = 16},
      -- Spur paths to upper building doors
      {x1 = 5, y1 = 7, x2 = 7, y2 = 8},
      {x1 = 17, y1 = 6, x2 = 19, y2 = 7},
      {x1 = 31, y1 = 7, x2 = 33, y2 = 8},
      -- Spur paths to lower building doors
      {x1 = 4, y1 = 20, x2 = 6, y2 = 21},
      {x1 = 18, y1 = 20, x2 = 20, y2 = 21},
      {x1 = 32, y1 = 20, x2 = 34, y2 = 21},
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
    width = 48,
    height = 24,
    elevatorPos = {x = 19, y = 12},
    -- Endless skyline backdrop
    skyline = {
      style = "luxury",
      sparkle = true,          -- Buildings sparkle in sunlight
      buildingCount = 40,      -- Dense city backdrop
      maxHeight = 350,         -- Tall towers
      glassReflections = true, -- Glass facades catch light
    },
    buildings = {
      {name = "Senate Hall", x = 2, y = 2, w = 9, h = 7, doorX = 6, doorY = 9, interior = "senate_hall",
       color = {0.85, 0.87, 0.92}, accentColor = {0.6, 0.7, 0.85}},
      {name = "Luxury Apartments", x = 27, y = 2, w = 8, h = 6, doorX = 30, doorY = 8, interior = "luxury_apartments",
       color = {0.82, 0.85, 0.9}, accentColor = {0.55, 0.65, 0.8}},
      {name = "Embassy Row", x = 14, y = 2, w = 7, h = 5, doorX = 17, doorY = 7, interior = "embassy",
       color = {0.84, 0.86, 0.9}, accentColor = {0.5, 0.6, 0.75}},
      {name = "Grand Hotel", x = 2, y = 15, w = 8, h = 6, doorX = 5, doorY = 21, interior = "grand_hotel",
       color = {0.86, 0.88, 0.9}, accentColor = {0.6, 0.68, 0.82}},
      {name = "Museum", x = 15, y = 15, w = 7, h = 6, doorX = 18, doorY = 21, interior = "museum",
       color = {0.83, 0.85, 0.88}, accentColor = {0.55, 0.62, 0.75}},
      {name = "Opera House", x = 28, y = 15, w = 7, h = 6, doorX = 31, doorY = 21, interior = "opera_house",
       color = {0.84, 0.84, 0.88}, accentColor = {0.58, 0.55, 0.7}},
      {name = "Galaxy PD HQ", x = 40, y = 9, w = 7, h = 5, doorX = 43, doorY = 14, interior = "galaxy_pd_hq",
       color = {0.45, 0.5, 0.65}, accentColor = {0.3, 0.35, 0.55},
       neonSign = {text = "GALAXY PD", color = {0.3, 0.5, 1.0}, glowRadius = 35}},
    },
    npcs = {
      {name = "Senator Vorn", x = 12, y = 11, dialogue = "The Lower Districts need reform, but the Council won't listen. Politics...", gender = "male"},
      {name = "Noble Lady", x = 25, y = 11, dialogue = "The air up here is so much cleaner. I simply couldn't live below Commerce.", gender = "female", design = 1},
      {name = "Embassy Guard", x = 19, y = 10, dialogue = "Move along. Embassy business is classified. For your own safety.", gender = "male"},
      {name = "Art Curator", x = 22, y = 18, dialogue = "Our collection spans ten thousand years of galactic history. Priceless.", gender = "female", design = 3},
      {name = "Butler Droid", x = 32, y = 8, dialogue = "May I be of service? The residents expect the highest standards.", gender = "male"},
      {name = "PD Desk Officer", x = 41, y = 13, dialogue = "Galaxy PD Headquarters. File complaints at the front desk. No weapons inside.", gender = "female", design = 2},
    },
    paths = {
      {x1 = 1, y1 = 8, x2 = 37, y2 = 15},
      {x1 = 10, y1 = 14, x2 = 27, y2 = 23},
      {x1 = 10, y1 = 7, x2 = 15, y2 = 16},
      {x1 = 20, y1 = 6, x2 = 28, y2 = 16},
      -- Dedicated path to Galaxy PD HQ (far right)
      {x1 = 37, y1 = 12, x2 = 44, y2 = 15},
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
    -- Panoramic endless skyline
    skyline = {
      style = "panoramic",
      sparkle = true,          -- Buildings sparkle brilliantly
      buildingCount = 60,      -- Endless city stretching to horizon
      maxHeight = 450,         -- Towering spires
      glassReflections = true,
      sunGlint = true,         -- Dramatic sun glints off glass
      haze = true,             -- Atmospheric haze for depth
    },
    buildings = {
      {name = "Observation Deck", x = 3, y = 3, w = 7, h = 5, doorX = 6, doorY = 8, interior = "observation_deck",
       color = {0.8, 0.85, 0.92}, accentColor = {0.5, 0.65, 0.85}},
      {name = "Hangar Bay", x = 24, y = 3, w = 8, h = 6, doorX = 27, doorY = 9, interior = "hangar",
       color = {0.75, 0.8, 0.87}, accentColor = {0.45, 0.58, 0.75}},
      {name = "Sky Lounge", x = 13, y = 3, w = 6, h = 4, doorX = 15, doorY = 7, interior = "sky_lounge",
       color = {0.82, 0.84, 0.9}, accentColor = {0.55, 0.6, 0.78}},
      {name = "Weather Station", x = 3, y = 14, w = 5, h = 5, doorX = 5, doorY = 19, interior = "weather_station",
       color = {0.78, 0.82, 0.88}, accentColor = {0.48, 0.6, 0.78}},
      {name = "Rooftop Gardens", x = 14, y = 14, w = 7, h = 5, doorX = 17, doorY = 19, interior = "rooftop_gardens",
       color = {0.55, 0.72, 0.58}, accentColor = {0.35, 0.58, 0.4}},
      {name = "Control Tower", x = 26, y = 14, w = 5, h = 5, doorX = 28, doorY = 19, interior = "control_tower",
       color = {0.74, 0.78, 0.85}, accentColor = {0.45, 0.58, 0.75}},
    },
    npcs = {
      {name = "Tower Controller", x = 11, y = 10, dialogue = "All incoming traffic, vector to pad 7. Smooth skies today.", gender = "male"},
      {name = "Pilot", x = 22, y = 10, dialogue = "Best landing pads in the sector. Clear skies, minimal traffic.", gender = "female", design = 2},
      {name = "Gardener", x = 21, y = 15, dialogue = "Real plants, real soil. Imported from the surface... before it was lost.", gender = "female", design = 6},
      {name = "Sunbather", x = 10, y = 9, dialogue = "Pure sunlight. No filters, no smog. Worth every credit to live up here.", gender = "female", design = 5},
      {name = "Meteorologist", x = 8, y = 15, dialogue = "Weather control keeps it perfect. 22 degrees, light breeze. Every day.", gender = "male"},
    },
    paths = {
      {x1 = 1, y1 = 7, x2 = 34, y2 = 14},
      {x1 = 9, y1 = 13, x2 = 25, y2 = 21},
      {x1 = 9, y1 = 6, x2 = 14, y2 = 15},
      {x1 = 18, y1 = 6, x2 = 25, y2 = 15},
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
      -- Also mark tile below door as walkable (where player stands to enter)
      if map[b.doorY - 1] then
        map[b.doorY - 1][b.doorX] = false
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
