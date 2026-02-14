-- singularity/areas.lua
-- Cosmic village alongside a black hole - Interstellar tesseract inspired
-- Paths floating among stars with warm amber/gold color palette

local M = {}

M.GRID_SIZE = 32

-- Village dimensions
M.WIDTH = 45
M.HEIGHT = 35

-- Interstellar color palette
M.COLORS = {
  void = {0.02, 0.02, 0.04},           -- Deep space black
  amber = {0.95, 0.65, 0.2},           -- Warm amber (tesseract)
  gold = {1.0, 0.85, 0.4},             -- Bright gold highlights
  copper = {0.8, 0.5, 0.25},           -- Copper accents
  rust = {0.6, 0.35, 0.15},            -- Dark rust
  orange = {1.0, 0.5, 0.1},            -- Hot orange
  cream = {1.0, 0.95, 0.85},           -- Warm white
  purple = {0.3, 0.15, 0.4},           -- Deep space purple
  starlight = {0.9, 0.85, 0.7}         -- Star glow
}

-- Zone definitions - floating platforms in the void
M.zones = {
  void = {
    name = "The Void",
    x1 = 0, y1 = 0, x2 = 44, y2 = 34,
    groundColor = nil,  -- No ground - pure void with stars
    isVoid = true
  },
  event_horizon = {
    name = "Event Horizon Plaza",
    x1 = 18, y1 = 14, x2 = 28, y2 = 22,
    groundColor = {0.15, 0.1, 0.08},  -- Dark platform
    glowColor = {0.95, 0.65, 0.2},    -- Amber glow
    ambientSound = "hum"
  },
  tesseract = {
    name = "The Tesseract",
    x1 = 5, y1 = 5, x2 = 16, y2 = 14,
    groundColor = {0.12, 0.08, 0.06},
    glowColor = {1.0, 0.85, 0.4},     -- Gold grid
    ambientSound = "whispers"
  },
  time_archives = {
    name = "Time Archives",
    x1 = 30, y1 = 5, x2 = 42, y2 = 14,
    groundColor = {0.1, 0.08, 0.05},
    glowColor = {0.8, 0.5, 0.25},     -- Copper glow
    ambientSound = "ticking"
  },
  orbital_ring = {
    name = "Orbital Ring",
    x1 = 5, y1 = 22, x2 = 16, y2 = 30,
    groundColor = {0.08, 0.06, 0.04},
    glowColor = {1.0, 0.5, 0.1},      -- Orange glow
    ambientSound = "pulse"
  },
  quantum_district = {
    name = "Quantum District",
    x1 = 30, y1 = 22, x2 = 42, y2 = 30,
    groundColor = {0.1, 0.07, 0.05},
    glowColor = {0.9, 0.7, 0.3},      -- Amber glow
    ambientSound = "static"
  }
}

-- Star path connections between zones (walkable bridges in the void)
M.starPaths = {
  -- Horizontal paths at y=14 (where tesseract/time_archives meet event_horizon)
  {x1 = 16, y1 = 13, x2 = 18, y2 = 15, glow = {0.95, 0.65, 0.2}},   -- Tesseract to Event Horizon
  {x1 = 28, y1 = 13, x2 = 30, y2 = 15, glow = {0.8, 0.5, 0.25}},    -- Event Horizon to Time Archives
  -- Horizontal paths at y=22 (where event_horizon meets orbital/quantum)
  {x1 = 16, y1 = 21, x2 = 18, y2 = 23, glow = {1.0, 0.5, 0.1}},     -- Orbital to Event Horizon
  {x1 = 28, y1 = 21, x2 = 30, y2 = 23, glow = {0.9, 0.7, 0.3}},     -- Event Horizon to Quantum
  -- Vertical paths
  {x1 = 10, y1 = 14, x2 = 11, y2 = 22, glow = {1.0, 0.85, 0.4}},   -- Tesseract to Orbital
  {x1 = 36, y1 = 14, x2 = 37, y2 = 22, glow = {0.95, 0.6, 0.2}},   -- Time Archives to Quantum
}

-- Buildings floating on platforms
M.buildings = {
  -- Event Horizon Plaza (center)
  {name = "Horizon Observatory", x = 19, y = 15, w = 4, h = 3, doorX = 20, doorY = 18, interior = "observatory",
   color = {0.2, 0.15, 0.1}, glowColor = {0.95, 0.65, 0.2}},
  {name = "Singularity Cafe", x = 24, y = 15, w = 4, h = 3, doorX = 25, doorY = 18, interior = "cafe",
   color = {0.25, 0.18, 0.12}, glowColor = {1.0, 0.85, 0.4}},
  {name = "Gravity Well Inn", x = 19, y = 19, w = 5, h = 3, doorX = 21, doorY = 22, interior = "inn",
   color = {0.18, 0.12, 0.08}, glowColor = {0.8, 0.5, 0.25}},

  -- The Tesseract (northwest)
  {name = "Time Library", x = 6, y = 6, w = 5, h = 4, doorX = 8, doorY = 10, interior = "time_library",
   color = {0.15, 0.1, 0.06}, glowColor = {1.0, 0.85, 0.4}},
  {name = "Bookshelf Tower", x = 12, y = 6, w = 3, h = 4, doorX = 13, doorY = 10, interior = "bookshelf_tower",
   color = {0.12, 0.08, 0.05}, glowColor = {0.95, 0.7, 0.3}},
  {name = "Memory Bank", x = 8, y = 11, w = 4, h = 3, doorX = 9, doorY = 14, interior = "memory_bank",
   color = {0.14, 0.1, 0.07}, glowColor = {0.9, 0.6, 0.2}},

  -- Time Archives (northeast)
  {name = "Chronos Research", x = 31, y = 6, w = 5, h = 4, doorX = 33, doorY = 10, interior = "chronos_lab",
   color = {0.13, 0.09, 0.05}, glowColor = {0.8, 0.5, 0.25}},
  {name = "Temporal Shop", x = 37, y = 6, w = 4, h = 4, doorX = 38, doorY = 10, interior = "temporal_shop",
   color = {0.16, 0.11, 0.07}, glowColor = {0.95, 0.65, 0.2}},
  {name = "Infinity Archives", x = 33, y = 11, w = 5, h = 3, doorX = 35, doorY = 14, interior = "infinity_archives",
   color = {0.11, 0.08, 0.04}, glowColor = {1.0, 0.75, 0.35}},

  -- Orbital Ring (southwest)
  {name = "Mission Control", x = 6, y = 23, w = 5, h = 4, doorX = 8, doorY = 27, interior = "mission_control",
   color = {0.1, 0.12, 0.15}, glowColor = {1.0, 0.5, 0.1}},
  {name = "Hangar Bay", x = 12, y = 23, w = 4, h = 4, doorX = 13, doorY = 27, interior = "hangar",
   color = {0.12, 0.1, 0.08}, glowColor = {0.9, 0.55, 0.15}},
  {name = "Supply Depot", x = 8, y = 28, w = 4, h = 2, doorX = 9, doorY = 30, interior = "supply_depot",
   color = {0.15, 0.12, 0.1}, glowColor = {0.85, 0.5, 0.2}},

  -- Quantum District (southeast)
  {name = "Quantum Lab", x = 31, y = 23, w = 5, h = 4, doorX = 33, doorY = 27, interior = "quantum_lab",
   color = {0.12, 0.1, 0.06}, glowColor = {0.9, 0.7, 0.3}},
  {name = "Probability Bar", x = 37, y = 23, w = 4, h = 4, doorX = 38, doorY = 27, interior = "probability_bar",
   color = {0.18, 0.14, 0.1}, glowColor = {1.0, 0.8, 0.4}},
  {name = "Entanglement Hub", x = 33, y = 28, w = 5, h = 2, doorX = 35, doorY = 30, interior = "entanglement_hub",
   color = {0.1, 0.08, 0.05}, glowColor = {0.95, 0.6, 0.25}},
}

-- NPCs floating on platforms
M.npcs = {
  -- Event Horizon Plaza
  {name = "Dr. Thorne", x = 22, y = 18, dialogue = "The black hole bends not just light, but time itself. We exist in its shadow.", zone = "event_horizon", gender = "male"},
  {name = "Cosmic Wanderer", x = 26, y = 20, dialogue = "I've seen the singularity's heart. There are no words... only equations.", zone = "event_horizon", gender = "male"},
  {name = "Station Keeper", x = 20, y = 20, dialogue = "Welcome to The Singularity. Time moves differently here. Don't be alarmed.", zone = "event_horizon", gender = "female", design = 6},

  -- The Tesseract
  {name = "Archivist TARS", x = 7, y = 10, dialogue = "Honesty setting: 95%. These books contain messages across time.", zone = "tesseract", gender = "male"},
  {name = "Time Librarian", x = 14, y = 11, dialogue = "Every moment is a book. Every choice, a page. We catalog them all.", zone = "tesseract", gender = "female", design = 4},
  {name = "Memory Keeper", x = 11, y = 14, dialogue = "Your memories are safe here. They exist in all times simultaneously.", zone = "tesseract", gender = "female", design = 1},

  -- Time Archives
  {name = "Chronologist", x = 34, y = 10, dialogue = "We study causality loops here. The future has already happened... somewhere.", zone = "time_archives", gender = "male"},
  {name = "Temporal Merchant", x = 40, y = 11, dialogue = "I sell moments. Frozen instants from across the cosmos. Interested?", zone = "time_archives", gender = "male"},
  {name = "Infinity Sage", x = 37, y = 14, dialogue = "Infinity is not a number. It's a direction. The black hole knows this.", zone = "time_archives", gender = "female", design = 1},

  -- Orbital Ring
  {name = "Commander Endurance", x = 8, y = 27, dialogue = "Ready to launch, pilot? The missions await beyond the event horizon.", zone = "orbital_ring", gender = "male"},
  {name = "Docking Chief", x = 14, y = 28, dialogue = "Your ship is secured. The gravitational lensing makes landing... interesting.", zone = "orbital_ring", gender = "male"},
  {name = "Cargo Specialist", x = 11, y = 30, dialogue = "Supplies from across the galaxy. Time dilation keeps them fresh forever.", zone = "orbital_ring", gender = "female", design = 6},

  -- Quantum District
  {name = "Dr. Uncertainty", x = 34, y = 27, dialogue = "Am I here? Am I there? The answer is yes. Quantum superposition is beautiful.", zone = "quantum_district", gender = "female", design = 5},
  {name = "Probability Bartender", x = 40, y = 28, dialogue = "What are the odds you'd visit today? 100%. Now that you're here.", zone = "quantum_district", gender = "male"},
  {name = "Entanglement Expert", x = 37, y = 30, dialogue = "Every particle here is connected to one light-years away. We're never alone.", zone = "quantum_district", gender = "female", design = 3},
}

-- Background stars (generated procedurally)
M.backgroundStars = {}

-- Gravitational lensing rings around black hole (visual effect)
M.blackHolePos = {x = 22, y = 2}  -- Black hole position (above the village)
M.blackHoleRadius = 220  -- Visual size (Interstellar-scale)

-- Spawn point
M.spawnPoint = {x = 22, y = 18}  -- Center of Event Horizon Plaza

-- Initialize background stars
function M.initStars(count)
  M.backgroundStars = {}
  for i = 1, count or 200 do
    table.insert(M.backgroundStars, {
      x = math.random(0, M.WIDTH * M.GRID_SIZE),
      y = math.random(0, M.HEIGHT * M.GRID_SIZE),
      size = math.random() * 2 + 0.5,
      brightness = math.random() * 0.5 + 0.5,
      twinkleSpeed = math.random() * 3 + 1,
      twinkleOffset = math.random() * math.pi * 2,
      -- Some stars have warm colors (amber/gold)
      warmth = math.random()
    })
  end
end

-- Get zone at position
function M.getZoneAt(gridX, gridY)
  -- Check specific zones first (not void)
  for name, zone in pairs(M.zones) do
    if not zone.isVoid and gridX >= zone.x1 and gridX <= zone.x2 and gridY >= zone.y1 and gridY <= zone.y2 then
      return name, zone
    end
  end
  -- Check star paths
  for _, path in ipairs(M.starPaths) do
    if gridX >= path.x1 and gridX <= path.x2 and gridY >= path.y1 and gridY <= path.y2 then
      return "star_path", {name = "Star Path", glowColor = path.glow}
    end
  end
  return "void", M.zones.void
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

-- Check if position is walkable
function M.isWalkable(gridX, gridY)
  -- Check zones
  for name, zone in pairs(M.zones) do
    if not zone.isVoid and gridX >= zone.x1 and gridX <= zone.x2 and gridY >= zone.y1 and gridY <= zone.y2 then
      return true
    end
  end
  -- Check star paths
  for _, path in ipairs(M.starPaths) do
    if gridX >= path.x1 and gridX <= path.x2 and gridY >= path.y1 and gridY <= path.y2 then
      return true
    end
  end
  return false
end

-- Create collision map
function M.createCollisionMap()
  local map = {}
  for y = 0, M.HEIGHT - 1 do
    map[y] = {}
    for x = 0, M.WIDTH - 1 do
      -- Default: void is not walkable
      map[y][x] = true

      -- Check zones
      for name, zone in pairs(M.zones) do
        if not zone.isVoid and x >= zone.x1 and x <= zone.x2 and y >= zone.y1 and y <= zone.y2 then
          map[y][x] = false
        end
      end

      -- Check star paths
      for _, path in ipairs(M.starPaths) do
        if x >= path.x1 and x <= path.x2 and y >= path.y1 and y <= path.y2 then
          map[y][x] = false
        end
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
    -- Door is walkable (and tile above it on the building wall)
    if map[b.doorY] then
      map[b.doorY][b.doorX] = false
    end
    if map[b.doorY - 1] then
      map[b.doorY - 1][b.doorX] = false
    end
  end

  return map
end

return M
