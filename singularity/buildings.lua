-- singularity/buildings.lua
-- Interior layouts for buildings in The Singularity
-- Interstellar tesseract-inspired aesthetic

local M = {}

M.GRID_SIZE = 32

M.interiors = {
  -- ═══════════════════════════════════════
  -- EVENT HORIZON PLAZA
  -- ═══════════════════════════════════════
  observatory = {
    name = "Horizon Observatory",
    width = 16, height = 12,
    exitX = 8, exitY = 11,
    npcs = {
      {name = "Astronomer Kip", x = 8, y = 4, dialogue = "Through this lens, you can see light bending around Gargantua. Time slows near the horizon.", gender = "male"},
      {name = "Data Analyst", x = 12, y = 6, dialogue = "We're receiving signals from... inside the black hole? Impossible, yet the data is clear.", gender = "female", design = 4}
    }
  },
  cafe = {
    name = "Singularity Cafe",
    width = 12, height = 10,
    exitX = 6, exitY = 9,
    npcs = {
      {name = "Cosmic Barista", x = 5, y = 3, dialogue = "Coffee brewed at the edge of infinity. Time dilation keeps it perpetually fresh.", gender = "female", design = 2},
      {name = "Regular", x = 9, y = 5, dialogue = "I've been sitting here for what feels like years. Might have been minutes. Hard to tell.", gender = "male"}
    }
  },
  inn = {
    name = "Gravity Well Inn",
    width = 14, height = 10,
    exitX = 7, exitY = 9,
    npcs = {
      {name = "Innkeeper", x = 5, y = 3, dialogue = "Rest here. One night in our rooms equals a week outside. Best sleep in the cosmos.", gender = "female", design = 6},
      {name = "Weary Traveler", x = 10, y = 6, dialogue = "I came to study the singularity. That was... how many years ago? I've lost count.", gender = "male"}
    }
  },

  -- ═══════════════════════════════════════
  -- THE TESSERACT (Time Library Area)
  -- ═══════════════════════════════════════
  time_library = {
    name = "The Time Library",
    width = 18, height = 14,
    exitX = 9, exitY = 13,
    npcs = {
      {name = "Curator CASE", x = 6, y = 5, dialogue = "Every book here is a window to another moment. Touch one and experience it.", gender = "male"},
      {name = "Scholar", x = 12, y = 7, dialogue = "I'm reading my own future. It's... complicated. Full of paradoxes.", gender = "male"},
      {name = "Young Researcher", x = 8, y = 10, dialogue = "They say Murph's equation is hidden somewhere in these stacks. The key to everything.", gender = "female", design = 5}
    }
  },
  bookshelf_tower = {
    name = "Bookshelf Tower",
    width = 10, height = 12,
    exitX = 5, exitY = 11,
    npcs = {
      {name = "Tower Keeper", x = 5, y = 4, dialogue = "Each shelf is a different timeline. Careful which books you pull.", gender = "male"}
    }
  },
  memory_bank = {
    name = "Memory Bank",
    width = 12, height = 10,
    exitX = 6, exitY = 9,
    portals = {
      {name = "Memory Deposit", x = 6, y = 3, game = "casino_exchange", color = {0.95, 0.65, 0.2}}
    },
    npcs = {
      {name = "Memory Banker", x = 4, y = 4, dialogue = "Store your precious memories here. They'll be safe across all timelines.", gender = "female", design = 4}
    }
  },

  -- ═══════════════════════════════════════
  -- TIME ARCHIVES
  -- ═══════════════════════════════════════
  chronos_lab = {
    name = "Chronos Research Lab",
    width = 16, height = 12,
    exitX = 8, exitY = 11,
    npcs = {
      {name = "Dr. Chronos", x = 6, y = 4, dialogue = "We're mapping causal loops. The black hole creates... temporal echoes.", gender = "male", design = 4},
      {name = "Lab Assistant", x = 12, y = 6, dialogue = "Yesterday I met myself from next week. Strangest conversation I'll ever have.", gender = "female", design = 3}
    }
  },
  temporal_shop = {
    name = "Temporal Treasures",
    width = 12, height = 10,
    exitX = 6, exitY = 9,
    portals = {
      {name = "Shop", x = 6, y = 3, game = "shop", color = {0.95, 0.65, 0.2}}
    },
    npcs = {
      {name = "Temporal Merchant", x = 4, y = 4, dialogue = "I sell artifacts from all times. This watch? It runs backwards near the horizon.", gender = "male"}
    }
  },
  infinity_archives = {
    name = "Infinity Archives",
    width = 16, height = 10,
    exitX = 8, exitY = 9,
    npcs = {
      {name = "Infinity Keeper", x = 6, y = 3, dialogue = "These scrolls contain infinite knowledge. Literally infinite. Don't try to read them all.", gender = "female", design = 1},
      {name = "Lost Scholar", x = 12, y = 5, dialogue = "I've been reading the same scroll for what feels like eternity. It keeps changing.", gender = "male"}
    }
  },

  -- ═══════════════════════════════════════
  -- ORBITAL RING (Mission Area)
  -- ═══════════════════════════════════════
  mission_control = {
    name = "Singularity Mission Control",
    width = 18, height = 14,
    exitX = 9, exitY = 13,
    portals = {
      {name = "Asteroids", x = 5, y = 6, game = "asteroids", color = {1.0, 0.5, 0.1}},
      {name = "StarFox", x = 9, y = 6, game = "starfox", color = {0.95, 0.65, 0.2}},
      {name = "Planet Map", x = 13, y = 6, game = "planetmap", color = {0.8, 0.4, 0.6}}
    },
    npcs = {
      {name = "Commander Cooper", x = 9, y = 3, dialogue = "Check the Planet Map to navigate the warped galaxy.", gender = "male"},
      {name = "Mission Analyst", x = 14, y = 8, dialogue = "Time and space bend near the singularity. The map compensates.", gender = "female", design = 4}
    }
  },
  hangar = {
    name = "Orbital Hangar",
    width = 16, height = 12,
    exitX = 8, exitY = 11,
    portals = {
      {name = "Ship Selection", x = 7, y = 5, game = "hangar", color = {1.0, 0.5, 0.1}}
    },
    npcs = {
      {name = "Chief Engineer", x = 4, y = 6, dialogue = "Your ship is calibrated for extreme gravitational stress. She'll hold.", gender = "male"},
      {name = "Test Pilot", x = 12, y = 7, dialogue = "I once slingshot around the black hole. Aged three minutes, my family aged three years.", gender = "female", design = 2}
    }
  },
  supply_depot = {
    name = "Orbital Supply Depot",
    width = 12, height = 8,
    exitX = 6, exitY = 7,
    portals = {
      {name = "Shop", x = 6, y = 3, game = "shop", color = {0.85, 0.5, 0.2}}
    },
    npcs = {
      {name = "Quartermaster", x = 4, y = 4, dialogue = "Supplies for your journey. Time-preserved, radiation-shielded.", gender = "male"}
    }
  },

  -- ═══════════════════════════════════════
  -- QUANTUM DISTRICT
  -- ═══════════════════════════════════════
  quantum_lab = {
    name = "Quantum Research Laboratory",
    width = 16, height = 12,
    exitX = 8, exitY = 11,
    portals = {
      {name = "Access Hatch", x = 13, y = 8, game = "science_lab", color = {0.05, 0.15, 0.45},
       description = "A heavy reinforced hatch in the floor. NASA insignia and 'AUTHORIZED PERSONNEL ONLY' stenciled in white.",
       isTrapdoor = true}
    },
    npcs = {
      {name = "Quantum Physicist", x = 6, y = 4, dialogue = "We study superposition here. I'm both excited and bored about our findings.", gender = "male"},
      {name = "Lab Technician", x = 12, y = 6, dialogue = "Don't observe the experiments too closely. You'll collapse the wave function.", gender = "female", design = 3},
      {name = "Visiting Scientist", x = 8, y = 3, dialogue = "The black hole's effects on quantum states are... unprecedented. Have you seen the Science Lab below? It's remarkable.", gender = "male"}
    }
  },
  probability_bar = {
    name = "The Probability Bar",
    width = 14, height = 10,
    exitX = 7, exitY = 9,
    npcs = {
      {name = "Quantum Bartender", x = 5, y = 3, dialogue = "Your drink is in a superposition of all flavors until you taste it.", gender = "male"},
      {name = "Lucky Gambler", x = 10, y = 5, dialogue = "I always win here. Or always lose. Depends on which timeline you ask.", gender = "male"},
      {name = "Philosopher", x = 3, y = 7, dialogue = "Is chance real, or is everything determined? The black hole knows, but won't tell.", gender = "female", design = 1}
    }
  },
  entanglement_hub = {
    name = "Entanglement Communications Hub",
    width = 14, height = 8,
    exitX = 7, exitY = 7,
    npcs = {
      {name = "Comms Officer", x = 5, y = 3, dialogue = "We send messages through entangled particles. Instant, across any distance.", gender = "female", design = 2},
      {name = "Distant Voice", x = 10, y = 4, dialogue = "I'm not really here. My entangled twin is speaking for me from a distant star.", gender = "male"}
    }
  },
}

-- Create collision map for an interior
function M.createInteriorCollisionMap(interiorId)
  local interior = M.interiors[interiorId]
  if not interior then return {} end

  local map = {}
  for y = 0, interior.height - 1 do
    map[y] = {}
    for x = 0, interior.width - 1 do
      -- Walls around perimeter
      if y == 0 or y == interior.height - 1 or x == 0 or x == interior.width - 1 then
        if not (x == interior.exitX and y == interior.exitY) then
          map[y][x] = true
        end
      end
    end
  end
  return map
end

-- Get interior definition
function M.getInterior(interiorId)
  return M.interiors[interiorId]
end

-- Check if at exit
function M.isAtExit(gridX, gridY, interiorId)
  local interior = M.interiors[interiorId]
  if interior then
    return gridX == interior.exitX and gridY == interior.exitY
  end
  return false
end

return M
