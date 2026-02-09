-- hub/floors.lua
-- Defines the 7-floor space station structure
-- Floor 0: Secret Bottom (unlocked by quest)
-- Floor 1: Basement/Warehouse (dockworkers, cargo)
-- Floor 2: Casino/Shops (casino, item shop, cosmetics, shipbuilder)
-- Floor 3: Residential (hotel, hangout, mainstage, studio)
-- Floor 4: Flight Deck/Hangar (hangar, starfox/asteroids portals)
-- Floor 5: Lookout (piano robot, high scores, galaxy panorama)
-- Floor 6: Secret Top (unlocked by progression)

local M = {}

M.GRID_SIZE = 32

-- Floor metadata
M.floors = {
  [0] = {
    id = 0,
    name = "Sub-Level Zero",
    subtitle = "Restricted Area",
    secret = true,
    unlockCondition = "quest_floor0", -- NPC quest on floor 3
    ambience = "eerie",
    colorScheme = {bg = {0.02, 0.02, 0.06}, neon = {0.8, 0.1, 0.1}, accent = {0.4, 0.0, 0.0}},
    width = 30,
    height = 20,
    elevatorPos = {x = 15, y = 10},
    windowStyle = "void", -- looks into deep space void
    buildings = {
      {name = "Archives", x = 3, y = 3, w = 6, h = 5, doorX = 5, doorY = 7, interior = "forbidden_archive",
       color = {0.5, 0.0, 0.0}, neonColor = {1.0, 0.1, 0.1}},
      {name = "Reactor Core", x = 21, y = 3, w = 6, h = 5, doorX = 23, doorY = 7, interior = "reactor_core",
       color = {0.4, 0.1, 0.0}, neonColor = {1.0, 0.3, 0.0}},

    },
    npcs = {
      {name = "Rogue AI", x = 12, y = 10, dialogue = "I've been down here since the station was built. They forgot about me... but I remember everything."},
      {name = "Maintenance Droid", x = 18, y = 15, dialogue = "Bzzt... structural integrity at 97.3%. The sub-levels hold secrets older than the station itself."},
      {name = "Shadow Broker", x = 10, y = 14, dialogue = "Information is the real currency. Credits come and go, but knowledge... that's power."},
    },
    paths = {
      -- Open area below buildings (doors at y=7 connect to y=8)
      {x1 = 1, y1 = 8, x2 = 28, y2 = 18},
    },
  },

  [1] = {
    id = 1,
    name = "Cargo Bay",
    subtitle = "Warehouse District",
    secret = false,
    ambience = "industrial",
    colorScheme = {bg = {0.06, 0.05, 0.08}, neon = {1.0, 0.6, 0.1}, accent = {0.6, 0.3, 0.0}},
    width = 30,
    height = 20,
    elevatorPos = {x = 15, y = 10},
    windowStyle = "docking", -- views of docking bays and cargo ships
    buildings = {
      {name = "Warehouse A", x = 2, y = 2, w = 7, h = 5, doorX = 5, doorY = 6, interior = "storage_a",
       color = {0.3, 0.25, 0.15}, neonColor = {1.0, 0.6, 0.1}},
      {name = "Warehouse B", x = 21, y = 2, w = 7, h = 5, doorX = 24, doorY = 6, interior = "storage_b",
       color = {0.3, 0.25, 0.15}, neonColor = {1.0, 0.6, 0.1}},
      {name = "Foreman's Office", x = 12, y = 2, w = 5, h = 4, doorX = 14, doorY = 5, interior = "maintenance",
       color = {0.2, 0.2, 0.3}, neonColor = {0.3, 0.7, 1.0}},
      {name = "Loading Bay", x = 2, y = 14, w = 8, h = 4, doorX = 5, doorY = 17, interior = "freight_elevator",
       color = {0.25, 0.2, 0.15}, neonColor = {1.0, 0.8, 0.2}},
      {name = "Cargo Office", x = 22, y = 14, w = 6, h = 4, doorX = 24, doorY = 17, interior = "cargo_office",
       color = {0.2, 0.2, 0.25}, neonColor = {0.4, 0.8, 1.0}},
    },
    npcs = {
      {name = "Dockworker Pete", x = 8, y = 10, dialogue = "These crates aren't gonna move themselves! ...Actually, the droids do most of it. I just supervise."},
      {name = "Dockworker Maya", x = 20, y = 8, dialogue = "We got a fresh shipment of Tibanna gas from the outer rim. That stuff powers the best weapons."},
      {name = "Foreman Briggs", x = 14, y = 8, dialogue = "Keep the aisles clear! Last week someone left a crate of thermal detonators in the walkway."},
      {name = "Cargo Droid CX-7", x = 12, y = 12, dialogue = "Inventory scan: 4,237 crates. 12 unaccounted for. This is... concerning."},
      {name = "Stowaway Kid", x = 25, y = 12, dialogue = "Shh! Don't tell anyone I'm here. I snuck aboard at the last port. This station is amazing!"},
    },
    paths = {
      -- Main corridor between building rows
      {x1 = 1, y1 = 7, x2 = 28, y2 = 13},
      -- Foreman's Office connector (door at y=5, tile y=6 bridges to corridor)
      {x1 = 13, y1 = 6, x2 = 15, y2 = 6},
      -- Vertical gap between bottom buildings
      {x1 = 10, y1 = 13, x2 = 21, y2 = 18},
      -- Bottom strip below bottom buildings
      {x1 = 1, y1 = 18, x2 = 28, y2 = 18},
    },
    -- Slateport-style crate decorations
    crates = {
      {x = 3, y = 8, w = 2, h = 1, color = {0.5, 0.35, 0.15}},
      {x = 7, y = 9, w = 1, h = 1, color = {0.4, 0.3, 0.1}},
      {x = 22, y = 9, w = 3, h = 1, color = {0.5, 0.35, 0.15}},
      {x = 26, y = 8, w = 2, h = 2, color = {0.45, 0.3, 0.1}},
      {x = 4, y = 12, w = 1, h = 1, color = {0.5, 0.35, 0.15}},
      {x = 18, y = 11, w = 2, h = 1, color = {0.4, 0.3, 0.1}},
      {x = 10, y = 7, w = 1, h = 1, color = {0.5, 0.35, 0.15}},
      {x = 27, y = 12, w = 1, h = 1, color = {0.45, 0.3, 0.1}},
    },
  },

  [2] = {
    id = 2,
    name = "Commerce Deck",
    subtitle = "Casino & Shopping District",
    secret = false,
    ambience = "vibrant",
    colorScheme = {bg = {0.04, 0.02, 0.08}, neon = {1.0, 0.0, 0.8}, accent = {0.0, 1.0, 0.8}},
    width = 35,
    height = 22,
    elevatorPos = {x = 17, y = 11},
    windowStyle = "nebula", -- colorful nebula views
    buildings = {
      {name = "Casino", x = 2, y = 2, w = 8, h = 6, doorX = 5, doorY = 7, interior = "casino",
       color = {0.5, 0.35, 0.0}, neonColor = {1.0, 0.85, 0.0}},
      {name = "Item Shop", x = 25, y = 2, w = 6, h = 5, doorX = 27, doorY = 6, interior = "item_shop",
       color = {0.3, 0.1, 0.4}, neonColor = {0.8, 0.2, 1.0}},
      {name = "Cosmetics Boutique", x = 13, y = 2, w = 6, h = 5, doorX = 15, doorY = 6, interior = "cosmetics",
       color = {0.4, 0.1, 0.3}, neonColor = {1.0, 0.3, 0.7}},
      {name = "Shipbuilder", x = 2, y = 14, w = 7, h = 5, doorX = 5, doorY = 18, interior = "shipbuilder",
       color = {0.1, 0.2, 0.4}, neonColor = {0.2, 0.6, 1.0}},
      {name = "Bank", x = 14, y = 14, w = 6, h = 5, doorX = 16, doorY = 18, interior = "bank",
       color = {0.2, 0.0, 0.3}, neonColor = {0.5, 0.0, 1.0}},
      {name = "Food Court", x = 26, y = 14, w = 6, h = 5, doorX = 28, doorY = 18, interior = "food_court",
       color = {0.3, 0.15, 0.0}, neonColor = {1.0, 0.5, 0.0}},
    },
    npcs = {
      {name = "Neon Barker", x = 10, y = 9, dialogue = "Step right up! The Casino's hot tonight! Triple jackpot on the slots!"},
      {name = "Window Shopper", x = 20, y = 9, dialogue = "Have you seen the new Phantom ship at the Shipbuilder? Sleek as a shadow..."},
      {name = "Street Musician", x = 17, y = 20, dialogue = "♪ Across the stars we fly, through nebulae on high... ♪ Tips appreciated!"},
      {name = "Security Guard", x = 12, y = 12, dialogue = "Keep it civil on the Commerce Deck. We've had some... rowdy customers lately."},
      {name = "Tourist", x = 24, y = 10, dialogue = "I came here all the way from the Andromeda sector! Your Cantina has the best Bantha milk."},
    },
    paths = {
      -- Main corridor between building rows
      {x1 = 1, y1 = 8, x2 = 33, y2 = 13},
      -- Cosmetics connector (door at y=6, tile y=7 bridges to corridor)
      {x1 = 14, y1 = 7, x2 = 16, y2 = 7},
      -- Item Shop connector (door at y=6, tile y=7 bridges to corridor)
      {x1 = 26, y1 = 7, x2 = 28, y2 = 7},
      -- Left gap between Shipbuilder and Bank
      {x1 = 9, y1 = 13, x2 = 13, y2 = 20},
      -- Right gap between Bank and Food Court
      {x1 = 20, y1 = 13, x2 = 25, y2 = 20},
      -- Bottom strip below bottom buildings
      {x1 = 1, y1 = 19, x2 = 33, y2 = 20},
    },
  },

  [3] = {
    id = 3,
    name = "Residential Deck",
    subtitle = "Living Quarters",
    secret = false,
    ambience = "warm",
    colorScheme = {bg = {0.04, 0.03, 0.06}, neon = {0.3, 0.8, 1.0}, accent = {1.0, 0.6, 0.3}},
    width = 35,
    height = 22,
    elevatorPos = {x = 17, y = 11},
    windowStyle = "starfield", -- calm starfield views
    buildings = {
      {name = "Hotel & Spa", x = 2, y = 2, w = 7, h = 5, doorX = 5, doorY = 6, interior = "hotel",
       color = {0.4, 0.15, 0.1}, neonColor = {1.0, 0.4, 0.3}},
      {name = "The Hangout", x = 14, y = 2, w = 7, h = 5, doorX = 17, doorY = 6, interior = "hangout",
       color = {0.1, 0.3, 0.15}, neonColor = {0.2, 1.0, 0.4}},
      {name = "Mainstage", x = 26, y = 2, w = 7, h = 5, doorX = 29, doorY = 6, interior = "mainstage",
       color = {0.3, 0.1, 0.35}, neonColor = {0.8, 0.2, 1.0}},
      {name = "Studio", x = 2, y = 14, w = 7, h = 5, doorX = 5, doorY = 18, interior = "studio",
       color = {0.15, 0.15, 0.3}, neonColor = {0.4, 0.4, 1.0}},
      {name = "Park", x = 14, y = 14, w = 7, h = 5, doorX = 17, doorY = 18, interior = "park",
       color = {0.05, 0.25, 0.1}, neonColor = {0.1, 0.8, 0.3}},
      {name = "Library", x = 26, y = 14, w = 6, h = 5, doorX = 28, doorY = 18, interior = "library",
       color = {0.2, 0.15, 0.1}, neonColor = {1.0, 0.8, 0.3}},
    },
    npcs = {
      {name = "Resident Yuki", x = 10, y = 9, dialogue = "I love living on the station. The view from my apartment at night... you can see three nebulae."},
      {name = "Chef Marco", x = 22, y = 9, dialogue = "I make the best carbonara this side of the Milky Way. Beethoven would approve — he appreciated fine things."},
      {name = "Professor Lin", x = 17, y = 20, dialogue = "Did you know Bach composed over 1,000 works? Music is the mathematics of the soul."},
      {name = "Mysterious Stranger", x = 8, y = 12, dialogue = "There are levels of this station most people never see. Deep below... and high above. Complete my task and I'll show you."},
      {name = "Kid with a Dog", x = 28, y = 11, dialogue = "My dog Cosmo loves chasing the cargo droids on Floor 1! Don't tell the Foreman."},
    },
    paths = {
      -- Main corridor between building rows
      {x1 = 1, y1 = 7, x2 = 33, y2 = 13},
      -- Left gap between Studio and Park
      {x1 = 9, y1 = 13, x2 = 13, y2 = 20},
      -- Right gap between Park and Library
      {x1 = 21, y1 = 13, x2 = 25, y2 = 20},
      -- Bottom strip below bottom buildings
      {x1 = 1, y1 = 19, x2 = 33, y2 = 20},
    },
  },

  [4] = {
    id = 4,
    name = "Flight Deck",
    subtitle = "Hangar Bay",
    secret = false,
    ambience = "mechanical",
    colorScheme = {bg = {0.03, 0.04, 0.08}, neon = {0.2, 0.8, 1.0}, accent = {1.0, 0.4, 0.1}},
    width = 35,
    height = 22,
    elevatorPos = {x = 17, y = 11},
    windowStyle = "launch", -- launch bay doors, ships departing
    buildings = {
      {name = "Hangar", x = 2, y = 2, w = 8, h = 6, doorX = 5, doorY = 7, interior = "hangar",
       color = {0.15, 0.25, 0.35}, neonColor = {0.2, 0.7, 0.9}},
      {name = "Mission Control", x = 25, y = 2, w = 8, h = 6, doorX = 28, doorY = 7, interior = "mission_control",
       color = {0.1, 0.15, 0.35}, neonColor = {0.3, 0.4, 1.0}},
      {name = "Repair Bay", x = 2, y = 14, w = 7, h = 5, doorX = 5, doorY = 18, interior = "repair_bay",
       color = {0.25, 0.2, 0.1}, neonColor = {1.0, 0.7, 0.2}},
      {name = "Briefing Room", x = 14, y = 14, w = 7, h = 5, doorX = 17, doorY = 18, interior = "briefing_room",
       color = {0.15, 0.1, 0.25}, neonColor = {0.6, 0.3, 1.0}},
      {name = "Armory", x = 26, y = 14, w = 6, h = 5, doorX = 28, doorY = 18, interior = "armory",
       color = {0.2, 0.1, 0.1}, neonColor = {1.0, 0.2, 0.2}},
    },
    npcs = {
      {name = "Deck Chief Ramos", x = 12, y = 9, dialogue = "All pilots report to the flight deck! We've got bogeys on the long-range scanners."},
      {name = "Mechanic Torque", x = 20, y = 9, dialogue = "Your ship's in good shape. But if you want the REAL upgrades, talk to the Shipbuilder on Floor 2."},
      {name = "Pilot Ace", x = 8, y = 12, dialogue = "I've flown every route from Corneria to Venom. Sector Y is where the real dogfighters earn their wings."},
      {name = "Navigation Droid", x = 30, y = 10, dialogue = "Plotting course... Warning: Asteroid density in Sector X exceeds safe parameters by 340%."},
      {name = "Recruit", x = 22, y = 12, dialogue = "Is it true the Phantom can phase through walls? I heard the test pilot went invisible for a whole minute!"},
    },
    paths = {
      -- Main corridor between building rows
      {x1 = 1, y1 = 8, x2 = 33, y2 = 13},
      -- Left gap between Repair Bay and Briefing Room
      {x1 = 9, y1 = 13, x2 = 13, y2 = 20},
      -- Right gap between Briefing Room and Armory
      {x1 = 21, y1 = 13, x2 = 25, y2 = 20},
      -- Bottom strip below bottom buildings
      {x1 = 1, y1 = 19, x2 = 33, y2 = 20},
    },
  },

  [5] = {
    id = 5,
    name = "Lookout",
    subtitle = "Observatory",
    secret = false,
    ambience = "serene",
    -- Skyfall Macau dark purple color scheme
    colorScheme = {bg = {0.04, 0.01, 0.08}, neon = {0.6, 0.2, 1.0}, accent = {0.3, 0.1, 0.5}},
    width = 30,
    height = 20,
    elevatorPos = {x = 15, y = 10},
    windowStyle = "panorama", -- full spiral galaxy panorama
    buildings = {
      {name = "Observatory", x = 3, y = 2, w = 7, h = 5, doorX = 6, doorY = 6, interior = "observatory",
       color = {0.15, 0.05, 0.25}, neonColor = {0.5, 0.1, 0.9}},
      {name = "Captain's Quarters", x = 20, y = 2, w = 7, h = 5, doorX = 23, doorY = 6, interior = "captains_quarters",
       color = {0.2, 0.1, 0.3}, neonColor = {0.7, 0.3, 1.0}},
      {name = "Sky Lounge", x = 3, y = 13, w = 5, h = 4, doorX = 5, doorY = 16, interior = "sky_lounge",
       color = {0.1, 0.05, 0.2}, neonColor = {0.3, 0.0, 0.6}},
      {name = "Piano Bar", x = 22, y = 13, w = 5, h = 4, doorX = 24, doorY = 16, interior = "piano_bar",
       color = {0.1, 0.08, 0.25}, neonColor = {0.4, 0.2, 0.8}},
    },
    npcs = {
      {name = "Piano Robot", x = 12, y = 8, dialogue = "♪ Clair de Lune, by Claude Debussy. A piece that captures the essence of moonlight on still water. ♪"},
      {name = "Astronomer Vega", x = 18, y = 8, dialogue = "That spiral galaxy out there... NGC 4414. Forty million light-years away. And yet, here we are, looking at it."},
      {name = "Philosopher Sage", x = 10, y = 15, dialogue = "Mozart said 'The music is not in the notes, but in the silence between.' Wise words for a pilot too."},
      {name = "Old Captain", x = 20, y = 15, dialogue = "I've seen the edge of the galaxy. It's not an edge at all — it's a beginning. Chopin understood beginnings."},
    },
    paths = {
      -- Main corridor between building rows
      {x1 = 1, y1 = 7, x2 = 28, y2 = 12},
      -- Center gap between Sky Lounge and Piano Bar
      {x1 = 8, y1 = 12, x2 = 21, y2 = 18},
      -- Bottom strip below bottom buildings
      {x1 = 1, y1 = 17, x2 = 28, y2 = 18},
    },
  },

  [6] = {
    id = 6,
    name = "Apex Tower",
    subtitle = "Command Bridge",
    secret = true,
    unlockCondition = "quest_floor6", -- unlocked after clearing certain levels
    ambience = "majestic",
    colorScheme = {bg = {0.02, 0.02, 0.05}, neon = {1.0, 0.85, 0.3}, accent = {0.3, 0.6, 1.0}},
    width = 25,
    height = 18,
    elevatorPos = {x = 12, y = 9},
    windowStyle = "cosmos", -- all-encompassing cosmic view
    buildings = {
      {name = "Command Bridge", x = 3, y = 2, w = 8, h = 5, doorX = 6, doorY = 6, interior = "command_bridge",
       color = {0.2, 0.15, 0.05}, neonColor = {1.0, 0.8, 0.2}},
      {name = "War Room", x = 15, y = 2, w = 6, h = 5, doorX = 17, doorY = 6, interior = "war_room",
       color = {0.15, 0.15, 0.15}, neonColor = {1.0, 1.0, 1.0}},
    },
    npcs = {
      {name = "Station Commander", x = 12, y = 8, dialogue = "You've proven yourself worthy of the highest level. Few ever reach the Apex. Welcome, pilot."},
      {name = "Ancient Hologram", x = 8, y = 8, dialogue = "I am the echo of this station's first captain. Vivaldi's Four Seasons played at our maiden voyage. What a day..."},
    },
    paths = {
      -- Open area below buildings (doors at y=6 connect to y=7)
      {x1 = 1, y1 = 7, x2 = 23, y2 = 16},
    },
  },
}

-- Floor order for elevator display (excludes secrets until unlocked)
M.elevatorOrder = {1, 2, 3, 4, 5}

-- Get floor definition
function M.getFloor(floorId)
  return M.floors[floorId]
end

-- Get elevator-visible floors (respects secret unlock conditions)
function M.getElevatorFloors(unlockedQuests)
  local result = {}
  -- Always show standard floors
  for _, id in ipairs(M.elevatorOrder) do
    table.insert(result, id)
  end
  -- Add secret floors if unlocked
  if unlockedQuests and unlockedQuests["quest_floor0"] then
    table.insert(result, 1, 0) -- prepend floor 0
  end
  if unlockedQuests and unlockedQuests["quest_floor6"] then
    table.insert(result, 6) -- append floor 6
  end
  return result
end

-- Get building at a specific grid position on a floor
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

-- Check if position is on elevator
function M.isOnElevator(floorId, gridX, gridY)
  local floor = M.floors[floorId]
  if not floor then return false end
  local ep = floor.elevatorPos
  return gridX >= ep.x - 1 and gridX <= ep.x + 1 and gridY >= ep.y - 1 and gridY <= ep.y + 1
end

-- Create collision map for a floor
function M.createFloorCollisionMap(floorId)
  local floor = M.floors[floorId]
  if not floor then return {} end

  local map = {}
  for y = 0, floor.height - 1 do
    map[y] = {}
    for x = 0, floor.width - 1 do
      -- Default: walls on perimeter
      if y == 0 or y == floor.height - 1 or x == 0 or x == floor.width - 1 then
        map[y][x] = true
      else
        map[y][x] = false
      end
    end
  end

  -- Buildings are solid except at doors
  if floor.buildings then
    -- Need a font to calculate sign widths for collision
    local font = love.graphics.getFont()
    
    for _, b in ipairs(floor.buildings) do
      for by = b.y, b.y + b.h - 1 do
        for bx = b.x, b.x + b.w - 1 do
          if map[by] and map[by][bx] ~= nil then
            map[by][bx] = true
          end
        end
      end
      
      -- Neon sign above building - calculate actual sign width in grid tiles
      if b.y > 0 and b.name then
        local signPixelWidth = font:getWidth(b.name) + 20
        local signGridWidth = math.ceil(signPixelWidth / 32)
        local buildingCenterX = b.x + b.w / 2
        local signStartX = math.floor(buildingCenterX - signGridWidth / 2)
        local signEndX = signStartX + signGridWidth - 1
        
        -- Mark sign tiles as solid
        for sx = signStartX, signEndX do
          if sx >= 0 and sx < floor.width and map[b.y - 1] and map[b.y - 1][sx] ~= nil then
            map[b.y - 1][sx] = true
          end
        end
      end
      
      -- Door is walkable
      if map[b.doorY] then
        map[b.doorY][b.doorX] = false
      end
    end
  end

  -- Paths are walkable (clear any collisions, but preserve perimeter walls and buildings)
  if floor.paths then
    for _, path in ipairs(floor.paths) do
      for py = path.y1, path.y2 do
        for px = path.x1, path.x2 do
          if map[py] and map[py][px] ~= nil then
            -- Don't clear perimeter walls
            local isPerimeter = (py == 0 or py == floor.height - 1 or px == 0 or px == floor.width - 1)
            
            -- Don't clear buildings (check if this tile is part of a building)
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

  -- Elevator area is walkable
  local ep = floor.elevatorPos
  for ey = ep.y - 1, ep.y + 1 do
    for ex = ep.x - 1, ep.x + 1 do
      if map[ey] and map[ey][ex] ~= nil then
        map[ey][ex] = false
      end
    end
  end

  -- Crates are solid (warehouse floor)
  if floor.crates then
    for _, crate in ipairs(floor.crates) do
      for cy = crate.y, crate.y + (crate.h or 1) - 1 do
        for cx = crate.x, crate.x + (crate.w or 1) - 1 do
          if map[cy] and map[cy][cx] ~= nil then
            map[cy][cx] = true
          end
        end
      end
    end
  end

  return map
end

return M
