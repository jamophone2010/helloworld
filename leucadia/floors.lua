-- leucadia/floors.lua
-- Underground / hidden floor system for Leucadia beach town
-- Floor -1: Secret Base (USS Pendleton aircraft carrier, Camp Pendleton / San Diego Navy inspired)
-- Accessed via trapdoor in Driftwood Cottage (Beach House 2)

local M = {}

M.GRID_SIZE = 32

-- Naval color palette
M.COLORS = {
  steel = {0.35, 0.38, 0.42},         -- Steel hull plating
  deck = {0.28, 0.3, 0.34},           -- Flight deck gray
  bulkhead = {0.25, 0.28, 0.32},      -- Interior bulkhead
  navy_blue = {0.1, 0.15, 0.3},       -- Navy blue accents
  haze_gray = {0.45, 0.48, 0.52},     -- Haze gray (ship paint)
  warning_red = {0.8, 0.2, 0.15},     -- Warning/ordnance red
  safety_yellow = {0.9, 0.8, 0.2},    -- Safety yellow markings
  ocean = {0.15, 0.3, 0.5},           -- Deep ocean backdrop
  white = {0.85, 0.87, 0.9},          -- Clean white markings
  pipe = {0.5, 0.45, 0.35},           -- Pipe/conduit color
}

-- Floor metadata
M.floors = {
  [-1] = {
    id = -1,
    name = "Secret Base",
    subtitle = "USS Pendleton",
    secret = true,
    unlockCondition = "trapdoor_leucadia",
    ambience = "carrier",
    colorScheme = {bg = {0.18, 0.2, 0.25}, accent = {0.35, 0.4, 0.5}, light = {0.7, 0.75, 0.85}},
    lightLevel = 0.55,
    width = 50,
    height = 28,
    -- Aircraft carrier flight deck backdrop
    backdrop = {
      style = "aircraft_carrier",
      features = {"flight_deck", "control_tower", "catapults", "arresting_wires", "radar_arrays",
                  "hull_plating", "waterline", "anchor_chains", "signal_flags"},
      depth_layers = 4,
    },
    buildings = {
      -- Flight Deck / Hangar Bay (topside)
      {name = "Flight Deck Hangar", x = 2, y = 2, w = 12, h = 6, doorX = 7, doorY = 8, interior = "carrier_hangar",
       color = {0.35, 0.38, 0.42}, accentColor = {0.5, 0.55, 0.6},
       archStyle = "steel_bulkhead",
       neonSign = {text = "HANGAR BAY 1", color = {0.9, 0.2, 0.2}, glowRadius = 30}},
      -- Island / Command Tower
      {name = "Command Island", x = 36, y = 2, w = 10, h = 7, doorX = 40, doorY = 9, interior = "carrier_bridge",
       color = {0.3, 0.35, 0.4}, accentColor = {0.6, 0.65, 0.7},
       archStyle = "radar_dome",
       neonSign = {text = "CIC", color = {0.2, 0.9, 0.3}, glowRadius = 25}},
      -- Below-Deck Mess Hall
      {name = "Mess Hall", x = 18, y = 2, w = 8, h = 5, doorX = 21, doorY = 7, interior = "carrier_mess",
       color = {0.4, 0.38, 0.35}, accentColor = {0.55, 0.5, 0.42}},
      -- Armory / Weapons Bay
      {name = "Weapons Bay", x = 2, y = 17, w = 9, h = 6, doorX = 6, doorY = 23, interior = "carrier_armory",
       color = {0.32, 0.3, 0.28}, accentColor = {0.8, 0.3, 0.2},
       neonSign = {text = "ORDNANCE", color = {1.0, 0.4, 0.1}, glowRadius = 30}},
      -- Crew Quarters / Berthing
      {name = "Crew Berthing", x = 15, y = 17, w = 8, h = 6, doorX = 18, doorY = 23, interior = "carrier_berthing",
       color = {0.38, 0.36, 0.34}, accentColor = {0.5, 0.48, 0.44}},
      -- War Room / Intel Center
      {name = "War Room", x = 28, y = 17, w = 9, h = 6, doorX = 32, doorY = 23, interior = "carrier_warroom",
       color = {0.25, 0.28, 0.35}, accentColor = {0.1, 0.5, 0.9},
       neonSign = {text = "CLASSIFIED", color = {1.0, 0.1, 0.1}, glowRadius = 20}},
      -- Machine Shop / Engineering
      {name = "Engineering", x = 40, y = 17, w = 7, h = 6, doorX = 43, doorY = 23, interior = "carrier_engineering",
       color = {0.4, 0.35, 0.3}, accentColor = {0.6, 0.5, 0.3}},
    },
    npcs = {
      {name = "Admiral Hawkins", x = 25, y = 10, dialogue = "Welcome aboard the USS Pendleton, sailor. This carrier has protected these waters since before your grandparents were born. Semper Fi.", gender = "male"},
      {name = "Master Chief Reyes", x = 15, y = 12, dialogue = "Deck crew, look alive! We've got birds inbound. I want that flight deck spotless in five mikes.", gender = "male"},
      {name = "Petty Officer Chen", x = 32, y = 11, dialogue = "I run the CIC watch rotation. Every radar contact gets logged. Every. Single. One.", gender = "female", design = 2},
      {name = "Gunner's Mate Diaz", x = 8, y = 20, dialogue = "Pendleton's got enough ordnance to level a small moon. Don't touch anything without authorization.", gender = "male", design = 5},
      {name = "Corpsman Santos", x = 20, y = 14, dialogue = "I patch up Marines and sailors alike. Camp Pendleton trained me well — you learn fast when the stakes are real.", gender = "female", design = 4},
      {name = "Marine Sgt. Oorah", x = 38, y = 13, dialogue = "Camp Pendleton is the finest training ground in the galaxy. Every Marine who walks these decks earned their place.", gender = "male", design = 6},
      {name = "Navigator Kim", x = 44, y = 10, dialogue = "San Diego Bay to deep space — this carrier's sailed them all. Current heading: classified.", gender = "female", design = 3},
      {name = "Deck Hand Rookie", x = 10, y = 13, dialogue = "First deployment! The flight deck is louder than I expected. They weren't kidding about the jet blast.", gender = "male"},
    },
    environment = {
      steel_floors = true,      -- Metallic deck plating
      fluorescent = true,       -- Harsh overhead lighting
      pipes = true,             -- Exposed pipes along ceilings
      hull_creaking = true,     -- Ambient hull sounds
      sea_spray = true,         -- Occasional sea mist from topside
      signal_flags = true,      -- Navy signal flags strung overhead
    },
    paths = {
      -- Main fore-aft corridor (flight deck level)
      {x1 = 1, y1 = 8, x2 = 49, y2 = 16},
      -- Port side passage
      {x1 = 1, y1 = 14, x2 = 12, y2 = 24},
      -- Starboard side passage
      {x1 = 35, y1 = 14, x2 = 48, y2 = 24},
      -- Cross-passage below deck
      {x1 = 12, y1 = 22, x2 = 40, y2 = 25},
      -- Spur paths to upper building doors
      {x1 = 6, y1 = 7, x2 = 8, y2 = 8},
      {x1 = 20, y1 = 6, x2 = 22, y2 = 7},
      {x1 = 39, y1 = 8, x2 = 41, y2 = 9},
      -- Spur paths to lower building doors
      {x1 = 5, y1 = 22, x2 = 7, y2 = 23},
      {x1 = 17, y1 = 22, x2 = 19, y2 = 23},
      {x1 = 31, y1 = 22, x2 = 33, y2 = 23},
      {x1 = 42, y1 = 22, x2 = 44, y2 = 23},
    },
  },
}

-- Get floor definition
function M.getFloor(floorId)
  return M.floors[floorId]
end

-- Get building at position on a floor
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

-- Create collision map for a floor
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

  return map
end

return M
