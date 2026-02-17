-- kalapatthar/buildings.lua
-- Interior definitions for Kala Patthar Base Camp

local M = {}

-- Interior definitions keyed by building id
local interiors = {
  -- ==========================================
  -- EXPEDITION HQ — the main lodge, info hub
  -- ==========================================
  expedition_hq = {
    name = "Expedition HQ",
    width = 12, height = 10,
    exitX = 6, exitY = 10,
    floorColor = {0.35, 0.25, 0.18},   -- dark wood planks
    wallColor = {0.40, 0.30, 0.22},
    npcs = {
      {name = "Captain Kami", x = 6, y = 3, gender = "male",
       dialogue = "I've led expeditions across Deep Space for twenty years. The legends of the four Muses are real — I've met pilots who gained their powers. Melo, Djolt, Tierra, Clarity. Each one guards a cosmic gift."},
      {name = "Navigator Sonam", x = 3, y = 5, gender = "female",
       dialogue = "If you're heading out to find the Muses, here's what I know: Melo is on Mixia, Djolt at Singularity, Tierra in Leucadia, and Clarity on Cereus. Each is waiting for a lost instrument to be returned."},
      {name = "Cartographer Rinchen", x = 9, y = 5, gender = "male",
       dialogue = "I've mapped every station in the galaxy. The instruments are scattered — the Perfect Piano in the Temple of Peril, the Decks of Destiny inside the black hole, the Gravitron Guitar at the Cereus Greenhouse, and the Mystic Microphone at the Hometown Studio."},
    },
    portals = {
      {game = "planetmap", x = 10, y = 3, label = "Planet Map"},
      {game = "shop", x = 2, y = 3, label = "Supply Shop"},
    },
    furniture = {
      {type = "table", x = 6, y = 4},
      {type = "map_wall", x = 6, y = 1},
      {type = "stove", x = 10, y = 2},
      {type = "bookshelf", x = 2, y = 2},
      {type = "lantern", x = 4, y = 4},
      {type = "lantern", x = 8, y = 4},
    },
  },

  -- ==========================================
  -- STORYTELLER'S TENT — deeper Muse lore
  -- ==========================================
  storyteller_tent = {
    name = "Storyteller's Tent",
    width = 10, height = 8,
    exitX = 5, exitY = 8,
    floorColor = {0.50, 0.35, 0.22},   -- woven rug
    wallColor = {0.55, 0.40, 0.15},     -- canvas
    npcs = {
      {name = "Storyteller Gyalzen", x = 5, y = 3, gender = "male",
       dialogue = "Gather round, pilgrim. Long ago, the four Muses performed a single concert that echoed across every station in the galaxy. Their music bent light, slowed time, and cleared the void of darkness. Then their instruments were stolen, scattered to the corners of space. They wait still."},
      {name = "Scribe Dolma", x = 3, y = 5, gender = "female",
       dialogue = "I've recorded every account of the Muses' powers: Melo slows time itself with his Perfect Piano — everything freezes except you, for thirty seconds. Djolt's Decks of Destiny channel chain lightning through your weapons for fifteen seconds."},
      {name = "Bard Tenzin", x = 7, y = 5, gender = "male",
       dialogue = "Tierra's Gravitron Guitar bends the edges of space — you can wrap around the screen, appearing on the opposite side. And Clarity's Mystic Microphone cuts through any fog, mist, or darkness for the rest of the stage. Each power has a thirty-second cooldown after use."},
    },
    furniture = {
      {type = "cushion", x = 4, y = 4},
      {type = "cushion", x = 6, y = 4},
      {type = "incense", x = 5, y = 2},
      {type = "scroll_rack", x = 2, y = 2},
      {type = "lantern", x = 8, y = 2},
    },
  },

  -- ==========================================
  -- CLIMBER'S LODGE — rumors and tips
  -- ==========================================
  climber_lodge = {
    name = "Climber's Lodge",
    width = 10, height = 8,
    exitX = 5, exitY = 8,
    floorColor = {0.30, 0.25, 0.20},
    wallColor = {0.35, 0.28, 0.22},
    npcs = {
      {name = "Veteran Ang Dorji", x = 3, y = 3, gender = "male",
       dialogue = "I tried to retrieve the Perfect Piano from the Temple of Peril once. Never made it past the second chamber. That place is no joke — but Melo needs it. He's been waiting on Mixia for years."},
      {name = "Scout Lhakpa", x = 7, y = 5, gender = "female",
       dialogue = "The dungeon inside Singularity's black hole... they say reality folds in there. The Decks of Destiny are deep inside. Djolt says he can feel them spinning, even from the surface."},
    },
    portals = {
      {game = "hangar", x = 2, y = 3, label = "Hangar"},
    },
    furniture = {
      {type = "bunk", x = 8, y = 2},
      {type = "bunk", x = 8, y = 4},
      {type = "stove", x = 2, y = 2},
      {type = "climbing_gear_rack", x = 5, y = 2},
    },
  },

  -- ==========================================
  -- TEA HOUSE — warmth, gossip, side info
  -- ==========================================
  tea_house = {
    name = "Himalayan Tea House",
    width = 10, height = 8,
    exitX = 5, exitY = 8,
    floorColor = {0.40, 0.30, 0.20},
    wallColor = {0.45, 0.35, 0.25},
    npcs = {
      {name = "Tea Master Pema", x = 5, y = 3, gender = "female",
       dialogue = "Hot butter tea, fresh from the kettle. You look like you've been traveling far. The Muses? Oh yes, everyone here has a story. The Greenhouse on Cereus has the most beautiful music playing — it must be Tierra's guitar."},
      {name = "Trader Nurbu", x = 3, y = 5, gender = "male",
       dialogue = "I've been to the Studio at Hometown Station. There's a microphone there that doesn't belong — a silver Shure SM58 with cosmic engravings. Must be Clarity's Mystic Microphone. They're just using it for recording sessions."},
    },
    furniture = {
      {type = "counter", x = 5, y = 2},
      {type = "kettle", x = 6, y = 2},
      {type = "table", x = 3, y = 6},
      {type = "table", x = 7, y = 6},
      {type = "lantern", x = 2, y = 2},
      {type = "lantern", x = 8, y = 2},
    },
  },

  -- ==========================================
  -- SAGE'S SHELTER — Muse power management
  -- ==========================================
  sage_shelter = {
    name = "The Sage's Shelter",
    width = 12, height = 10,
    exitX = 6, exitY = 10,
    floorColor = {0.55, 0.50, 0.40},   -- polished stone
    wallColor = {0.60, 0.55, 0.45},
    npcs = {
      {name = "The Sage", x = 6, y = 3, gender = "male",
       dialogue = "I am the keeper of the Muses' legacy. When you return an instrument to its Muse, their power awakens within you. Hold the B button in combat to channel it. Come speak with me to choose which Muse's power is active. Only one may be channeled at a time.",
       isSage = true},
      {name = "Acolyte Chime", x = 3, y = 6, gender = "female",
       dialogue = "The Sage has meditated here since before the stations were built. He alone understands how the Muses' powers connect to a pilot's spirit. Each power has a thirty-second cooldown after its effect ends."},
    },
    furniture = {
      {type = "altar", x = 6, y = 2},
      {type = "meditation_mat", x = 4, y = 4},
      {type = "meditation_mat", x = 8, y = 4},
      {type = "incense", x = 3, y = 2},
      {type = "incense", x = 9, y = 2},
      {type = "prayer_wheel", x = 2, y = 5},
      {type = "prayer_wheel", x = 10, y = 5},
      {type = "muse_pedestal", x = 3, y = 8, label = "Melo"},
      {type = "muse_pedestal", x = 5, y = 8, label = "Djolt"},
      {type = "muse_pedestal", x = 7, y = 8, label = "Tierra"},
      {type = "muse_pedestal", x = 9, y = 8, label = "Clarity"},
    },
  },

  -- ==========================================
  -- MEMORIAL SHRINE — reverence and history
  -- ==========================================
  shrine = {
    name = "Memorial Shrine",
    width = 8, height = 6,
    exitX = 4, exitY = 6,
    floorColor = {0.45, 0.40, 0.35},
    wallColor = {0.50, 0.45, 0.40},
    npcs = {
      {name = "Monk Lama Tsering", x = 4, y = 2, gender = "male",
       dialogue = "This shrine honors the harmony the Muses once brought to the galaxy. Four pedestals, four instruments, four gifts. The cycle of music and silence turns eternal. Seek them, pilot, and restore what was lost."},
    },
    furniture = {
      {type = "statue", x = 4, y = 1},
      {type = "candle", x = 2, y = 2},
      {type = "candle", x = 6, y = 2},
      {type = "prayer_flags_indoor", x = 4, y = 1},
    },
  },

  -- ==========================================
  -- STAR OBSERVATORY — cosmic knowledge
  -- ==========================================
  observatory = {
    name = "Star Observatory",
    width = 10, height = 8,
    exitX = 5, exitY = 8,
    floorColor = {0.20, 0.22, 0.28},
    wallColor = {0.25, 0.28, 0.35},
    npcs = {
      {name = "Astronomer Tsewang", x = 5, y = 3, gender = "male",
       dialogue = "From here I track the constellations. The Muses' instruments resonate at specific frequencies — when all four are returned, a new star is said to appear in the sky. I'm still waiting to see it."},
      {name = "Stargazer Kelsang", x = 7, y = 5, gender = "female",
       dialogue = "Deep Space is vast, but Kala Patthar sits at a convergence point. All the station routes pass near here. It's why the Sage chose this place — equidistant from all the Muses."},
    },
    portals = {
      {game = "lookout", x = 5, y = 2, label = "Telescope"},
    },
    furniture = {
      {type = "telescope", x = 5, y = 1},
      {type = "star_chart", x = 2, y = 2},
      {type = "star_chart", x = 8, y = 2},
      {type = "desk", x = 3, y = 5},
    },
  },

  -- ==========================================
  -- SUPPLY DEPOT — equipment and prep
  -- ==========================================
  supply_depot = {
    name = "Supply Depot",
    width = 10, height = 8,
    exitX = 5, exitY = 8,
    floorColor = {0.30, 0.25, 0.20},
    wallColor = {0.35, 0.30, 0.25},
    npcs = {
      {name = "Quartermaster Jigme", x = 5, y = 3, gender = "male",
       dialogue = "Need supplies for the road? I've got rations, oxygen, and star charts. The Muses' instruments aren't for sale though — you'll have to earn those the hard way."},
    },
    portals = {
      {game = "shop", x = 3, y = 3, label = "Supplies"},
    },
    furniture = {
      {type = "crate_stack", x = 2, y = 2},
      {type = "crate_stack", x = 8, y = 2},
      {type = "barrel", x = 2, y = 5},
      {type = "barrel", x = 8, y = 5},
      {type = "shelf", x = 5, y = 1},
    },
  },
}

-- Create collision map for an interior
function M.createInteriorCollisionMap(interiorId)
  local interior = interiors[interiorId]
  if not interior then return {} end

  local map = {}
  for y = 0, interior.height do
    map[y] = {}
    for x = 0, interior.width do
      -- Walls on perimeter
      if x == 0 or x == interior.width or y == 0 then
        map[y][x] = true
      end
    end
  end

  -- Exit is walkable
  if map[interior.exitY] then
    map[interior.exitY][interior.exitX] = nil
  end

  -- Portals are walkable
  if interior.portals then
    for _, portal in ipairs(interior.portals) do
      if map[portal.y] then
        map[portal.y][portal.x] = nil
      end
    end
  end

  -- Furniture is collidable (some types)
  if interior.furniture then
    for _, f in ipairs(interior.furniture) do
      if f.type == "table" or f.type == "counter" or f.type == "stove" or
         f.type == "bookshelf" or f.type == "statue" or f.type == "altar" or
         f.type == "telescope" or f.type == "crate_stack" or f.type == "barrel" or
         f.type == "shelf" or f.type == "bunk" or f.type == "scroll_rack" or
         f.type == "climbing_gear_rack" or f.type == "desk" or f.type == "prayer_wheel" then
        if map[f.y] then
          map[f.y][f.x] = true
        end
      end
    end
  end

  -- NPCs are collidable
  if interior.npcs then
    for _, n in ipairs(interior.npcs) do
      if map[n.y] then
        map[n.y][n.x] = true
      end
    end
  end

  return map
end

function M.getInterior(interiorId)
  return interiors[interiorId]
end

function M.isAtExit(gridX, gridY, interiorId)
  local interior = interiors[interiorId]
  if not interior then return false end
  return gridX == interior.exitX and gridY == interior.exitY
end

return M
