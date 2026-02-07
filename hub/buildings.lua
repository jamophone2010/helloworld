-- hub/buildings.lua (REWRITTEN)
-- Interior layouts for all buildings across all 7 floors of the space station
-- Building positions/exteriors are defined in floors.lua
-- This file defines what's INSIDE each building

local M = {}

M.GRID_SIZE = 32

-- Interior layouts keyed by building ID from floors.lua
M.interiors = {
  -- ═══════════════════════════════════════
  -- FLOOR 0: Sub-Level Zero (Secret)
  -- ═══════════════════════════════════════
  forbidden_archive = {
    name = "Forbidden Archive",
    width = 16, height = 12,
    exitX = 8, exitY = 11,
    npcs = {
      {name = "Archivist", x = 8, y = 4, dialogue = "These records predate the station... Handle with care."}
    }
  },
  reactor_core = {
    name = "Reactor Core",
    width = 14, height = 14,
    exitX = 7, exitY = 13,
    npcs = {
      {name = "Engineer", x = 7, y = 6, dialogue = "Don't touch anything. One wrong move and this whole deck goes up."}
    }
  },

  -- ═══════════════════════════════════════
  -- FLOOR 1: Cargo Bay (Slateport Style)
  -- ═══════════════════════════════════════
  cargo_office = {
    name = "Cargo Office",
    width = 12, height = 10,
    exitX = 6, exitY = 9,
    npcs = {
      {name = "Dock Master", x = 5, y = 3, dialogue = "Shipments in, shipments out. That's all we do down here."},
      {name = "Clerk", x = 9, y = 3, dialogue = "Need to track a package? Check the manifest."}
    }
  },
  storage_a = {
    name = "Storage Unit A",
    width = 10, height = 8,
    exitX = 5, exitY = 7
  },
  storage_b = {
    name = "Storage Unit B",
    width = 10, height = 8,
    exitX = 5, exitY = 7
  },
  maintenance = {
    name = "Maintenance Bay",
    width = 14, height = 10,
    exitX = 7, exitY = 9,
    npcs = {
      {name = "Technician", x = 5, y = 4, dialogue = "These old conduits need replacing. Budget keeps getting cut."}
    }
  },
  freight_elevator = {
    name = "Freight Elevator",
    width = 8, height = 8,
    exitX = 4, exitY = 7
  },

  -- ═══════════════════════════════════════
  -- FLOOR 2: Commerce Deck
  -- ═══════════════════════════════════════
  casino = {
    name = "Bellagio Casino & Boutique",
    width = 30, height = 20,
    exitX = 14, exitY = 19,
    portals = {
      {name = "Slot Machine", x = 7, y = 5, game = "slotmachine", color = {1, 0.8, 0}},
      {name = "Blackjack", x = 13, y = 5, game = "blackjack", color = {0.2, 0.8, 0.2}},
      {name = "Roulette", x = 21, y = 5, game = "roulette", color = {1, 0.2, 0.2}},
      {name = "Cashier", x = 22, y = 10, game = "casino_exchange", color = {1, 1, 0}},
      {name = "Shop", x = 8, y = 11, game = "shop", color = {0.6, 0.3, 0.8}}
    },
    npcs = {
      {name = "Blackjack Dealer", x = 14, y = 4, dialogue = "Care for a hand of blackjack?"},
      {name = "Croupier", x = 22, y = 4, dialogue = "Place your bets! The wheel awaits."},
      {name = "Shop Clerk", x = 6, y = 11, dialogue = "Welcome to our boutique!"}
    },
    zones = {
      {name = "foyer", x1 = 0, y1 = 0, x2 = 29, y2 = 2, floor = "marble"},
      {name = "fountain", x1 = 1, y1 = 3, x2 = 3, y2 = 7, floor = "marble"},
      {name = "gaming", x1 = 5, y1 = 3, x2 = 29, y2 = 8, floor = "carpet_red"},
      {name = "boutique", x1 = 0, y1 = 9, x2 = 17, y2 = 14, floor = "marble"},
      {name = "cashier", x1 = 18, y1 = 9, x2 = 27, y2 = 11, floor = "marble"},
      {name = "lounge", x1 = 0, y1 = 15, x2 = 29, y2 = 17, floor = "carpet_dark"},
      {name = "exit", x1 = 12, y1 = 18, x2 = 17, y2 = 19, floor = "marble"}
    },
    decorations = {
      {type = "fountain", x = 2, y = 5, collision = true},
      {type = "sculpture", x = 4, y = 16, collision = true},
      {type = "sculpture", x = 22, y = 16, collision = true},
      {type = "counter", x = 5, y = 11, w = 5, collision = true},
      {type = "slots", x = 6, y = 5, w = 3, h = 2},
      {type = "blackjack_table", x = 12, y = 5, w = 3, h = 2},
      {type = "roulette_table", x = 20, y = 5, w = 4, h = 3}
    }
  },
  item_shop = {
    name = "Quantum Supply Co.",
    width = 12, height = 10,
    exitX = 6, exitY = 9,
    portals = {
      {name = "Shop", x = 6, y = 3, game = "shop", color = {0.6, 0.3, 0.8}}
    },
    npcs = {
      {name = "Shopkeeper", x = 4, y = 3, dialogue = "Best prices on the station! Lives, bombs, upgrades..."}
    }
  },
  cosmetics = {
    name = "Neon Threads Boutique",
    width = 12, height = 10,
    exitX = 6, exitY = 9,
    npcs = {
      {name = "Stylist", x = 6, y = 3, dialogue = "Looking to change your look? We've got the latest station fashion."},
      {name = "Model", x = 9, y = 5, dialogue = "This outfit cost me a month's salary, but totally worth it."}
    }
  },
  shipbuilder = {
    name = "Nova Shipworks",
    width = 16, height = 12,
    exitX = 8, exitY = 11,
    portals = {
      {name = "Ship Catalog", x = 7, y = 4, game = "shipyard", color = {0.2, 0.7, 0.8}}
    },
    npcs = {
      {name = "Shipwright", x = 5, y = 5, dialogue = "Every ship is hand-assembled. Well, robot-assembled. But with love."},
      {name = "Test Pilot", x = 12, y = 7, dialogue = "I've flown every model here. The Phantom is something else..."}
    }
  },
  bank = {
    name = "Stellar Trust Bank",
    width = 14, height = 10,
    exitX = 7, exitY = 9,
    portals = {
      {name = "Exchange", x = 7, y = 3, game = "casino_exchange", color = {1, 1, 0}}
    },
    npcs = {
      {name = "Teller", x = 5, y = 3, dialogue = "Notes to Credits, Credits to Notes. Standard rates apply."},
      {name = "Manager", x = 10, y = 5, dialogue = "Your funds are safe with us. We've never been robbed. ...yet."}
    }
  },
  food_court = {
    name = "Starlight Eatery",
    width = 16, height = 12,
    exitX = 8, exitY = 11,
    npcs = {
      {name = "Chef", x = 4, y = 3, dialogue = "Today's special: Nebula Noodles with stardust seasoning!"},
      {name = "Patron", x = 10, y = 7, dialogue = "The food here isn't bad for a space station. Try the ramen."},
      {name = "Waiter", x = 12, y = 4, dialogue = "Table for one? Right this way."}
    }
  },

  -- ═══════════════════════════════════════
  -- FLOOR 3: Residential Deck
  -- ═══════════════════════════════════════
  hotel = {
    name = "Celestial Grand Hotel",
    width = 16, height = 12,
    exitX = 8, exitY = 11,
    npcs = {
      {name = "Concierge", x = 8, y = 3, dialogue = "Welcome to the Celestial Grand. Finest rooms on the station."},
      {name = "Bellhop", x = 4, y = 6, dialogue = "Need your bags carried? I've got anti-grav carts!"},
      {name = "Guest", x = 12, y = 7, dialogue = "The view from room 307 is incredible. You can see the nebula!"}
    }
  },
  hangout = {
    name = "The Gravity Well Lounge",
    width = 14, height = 10,
    exitX = 7, exitY = 9,
    npcs = {
      {name = "Bartender", x = 7, y = 2, dialogue = "What'll it be? We've got drinks from twelve systems."},
      {name = "Regular", x = 3, y = 6, dialogue = "I come here every cycle. Best spot on the station to unwind."},
      {name = "Musician", x = 11, y = 4, dialogue = "I play here on weekends. The acoustics are great."}
    }
  },
  mainstage = {
    name = "The Mainstage",
    width = 20, height = 14,
    exitX = 10, exitY = 13,
    portals = {
      {name = "Watch Show", x = 9, y = 5, game = "mainstage", color = {1, 0.3, 0.8}}
    },
    npcs = {
      {name = "Stage Manager", x = 5, y = 8, dialogue = "Tonight's show is going to be spectacular. Take a seat!"},
      {name = "Groupie", x = 15, y = 10, dialogue = "Hypernova is my FAVORITE band! They rock so hard!"}
    }
  },
  studio = {
    name = "Studio 3 Broadcasting",
    width = 14, height = 10,
    exitX = 7, exitY = 9,
    portals = {
      {name = "Studio Console", x = 6, y = 3, game = "studio", color = {0.0, 0.8, 1.0}}
    },
    npcs = {
      {name = "DJ Orbit", x = 4, y = 4, dialogue = "Hey! Welcome to Studio 3. Want to pick the next track?"}
    }
  },
  park = {
    name = "Atrium Garden",
    width = 18, height = 14,
    exitX = 9, exitY = 13,
    npcs = {
      {name = "Gardener", x = 5, y = 5, dialogue = "Real trees, real soil. Imported from three different planets."},
      {name = "Jogger", x = 14, y = 9, dialogue = "Five laps around the atrium is exactly one kilometer!"},
      {name = "Child", x = 9, y = 7, dialogue = "Look at the butterflies! They're not real but they're pretty."}
    }
  },
  library = {
    name = "Starlight Archives",
    width = 14, height = 12,
    exitX = 7, exitY = 11,
    npcs = {
      {name = "Librarian", x = 7, y = 3, dialogue = "We have over two million digital volumes. Looking for anything specific?"},
      {name = "Scholar", x = 11, y = 7, dialogue = "I'm researching ancient flight patterns. Fascinating stuff."}
    }
  },

  -- ═══════════════════════════════════════
  -- FLOOR 4: Flight Deck
  -- ═══════════════════════════════════════
  hangar = {
    name = "Hangar Bay",
    width = 20, height = 14,
    exitX = 10, exitY = 13,
    portals = {
      {name = "Ship Selection", x = 9, y = 5, game = "hangar", color = {0.2, 0.7, 0.8}}
    },
    npcs = {
      {name = "Mechanic", x = 5, y = 7, dialogue = "Pick your ride! Each ship has unique abilities."},
      {name = "Crew Chief", x = 15, y = 5, dialogue = "All ships are fueled and ready for launch."}
    }
  },
  mission_control = {
    name = "Mission Control",
    width = 20, height = 15,
    exitX = 10, exitY = 14,
    portals = {
      {name = "Asteroids", x = 7, y = 6, game = "asteroids", color = {0.3, 0.5, 0.8}},
      {name = "StarFox", x = 13, y = 6, game = "starfox", color = {0.3, 0.5, 1}}
    },
    npcs = {
      {name = "Commander", x = 10, y = 3, dialogue = "Ready for a mission, pilot? Choose your assignment."},
      {name = "Analyst", x = 16, y = 8, dialogue = "Sensor data shows heavy enemy activity in Sector Y."}
    }
  },
  repair_bay = {
    name = "Repair Bay",
    width = 14, height = 10,
    exitX = 7, exitY = 9,
    npcs = {
      {name = "Engineer", x = 5, y = 4, dialogue = "Bring your damaged ships here. We'll have them good as new."},
      {name = "Droid", x = 10, y = 6, dialogue = "BEEP BOOP. Structural integrity assessment complete."}
    }
  },
  briefing_room = {
    name = "Briefing Room",
    width = 16, height = 12,
    exitX = 8, exitY = 11,
    npcs = {
      {name = "Tactical Officer", x = 8, y = 4, dialogue = "Mission objectives are on the screen. Study them carefully."},
      {name = "Pilot", x = 4, y = 8, dialogue = "I've run Corneria dozens of times. Happy to share tips."}
    }
  },
  armory = {
    name = "Armory",
    width = 12, height = 10,
    exitX = 6, exitY = 9,
    portals = {
      {name = "Shop", x = 6, y = 3, game = "shop", color = {0.6, 0.3, 0.8}}
    },
    npcs = {
      {name = "Quartermaster", x = 4, y = 4, dialogue = "Weapons, shields, upgrades. Everything a pilot needs."}
    }
  },

  -- ═══════════════════════════════════════
  -- FLOOR 5: Lookout (Skyfall Macau)
  -- ═══════════════════════════════════════
  observatory = {
    name = "Observatory",
    width = 18, height = 14,
    exitX = 9, exitY = 13,
    portals = {
      {name = "Lookout Deck", x = 8, y = 5, game = "lookout", color = {0.6, 0.2, 0.8}}
    },
    npcs = {
      {name = "Astronomer", x = 12, y = 6, dialogue = "Look through the telescope! You can see the Horsehead Nebula tonight."}
    }
  },
  sky_lounge = {
    name = "Sky Lounge",
    width = 16, height = 12,
    exitX = 8, exitY = 11,
    npcs = {
      {name = "Bartender", x = 8, y = 3, dialogue = "Best view on the station, best drinks too. What's your pleasure?"},
      {name = "VIP Guest", x = 13, y = 6, dialogue = "I paid extra for this booth. Worth every credit."}
    }
  },
  piano_bar = {
    name = "Piano Bar",
    width = 14, height = 10,
    exitX = 7, exitY = 9,
    npcs = {
      {name = "Unit P-88", x = 5, y = 4, dialogue = "♪ ... Shall I play something for you?"},
      {name = "Listener", x = 10, y = 6, dialogue = "The robot plays better than any human I've heard."}
    }
  },
  vip_lounge = {
    name = "VIP Lounge",
    width = 12, height = 10,
    exitX = 6, exitY = 9,
    npcs = {
      {name = "Host", x = 6, y = 3, dialogue = "Welcome to the exclusive floor. Only the station's finest up here."}
    }
  },

  -- ═══════════════════════════════════════
  -- FLOOR 6: Apex Tower (Secret)
  -- ═══════════════════════════════════════
  command_bridge = {
    name = "Command Bridge",
    width = 20, height = 14,
    exitX = 10, exitY = 13,
    npcs = {
      {name = "Admiral", x = 10, y = 4, dialogue = "Welcome to the bridge, Commander. The station is yours."},
      {name = "Navigator", x = 6, y = 6, dialogue = "All systems nominal. Course is steady."},
      {name = "Comms Officer", x = 14, y = 6, dialogue = "Receiving transmissions from allied stations."}
    }
  },
  war_room = {
    name = "War Room",
    width = 14, height = 10,
    exitX = 7, exitY = 9,
    npcs = {
      {name = "Strategist", x = 7, y = 4, dialogue = "The holographic map shows enemy positions across three sectors."}
    }
  },
  captains_quarters = {
    name = "Captain's Quarters",
    width = 12, height = 10,
    exitX = 6, exitY = 9,
    npcs = {
      {name = "Personal Droid", x = 4, y = 4, dialogue = "Captain's quarters are in order. Shall I prepare anything?"}
    }
  }
}

-- Create collision map for an interior
function M.createInteriorCollisionMap(interiorId)
  local interior = M.interiors[interiorId]
  if not interior then return {} end

  local map = {}
  for y = 0, interior.height - 1 do
    map[y] = {}
    for x = 0, interior.width - 1 do
      -- Walls around the perimeter
      if y == 0 or y == interior.height - 1 or x == 0 or x == interior.width - 1 then
        if not (x == interior.exitX and y == interior.exitY) then
          map[y][x] = true
        end
      end
    end
  end

  -- Add collision for decorations
  if interior.decorations then
    for _, deco in ipairs(interior.decorations) do
      if deco.collision then
        local w = deco.w or 1
        local h = deco.h or 1
        for dy = 0, h - 1 do
          for dx = 0, w - 1 do
            if map[deco.y + dy] then
              map[deco.y + dy][deco.x + dx] = true
            end
          end
        end
      end
    end
  end

  return map
end

-- Get interior definition by id
function M.getInterior(interiorId)
  return M.interiors[interiorId]
end

-- Check if at exit position
function M.isAtExit(gridX, gridY, interiorId)
  local interior = M.interiors[interiorId]
  if interior then
    return gridX == interior.exitX and gridY == interior.exitY
  end
  return false
end

return M
