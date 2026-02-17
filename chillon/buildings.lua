-- chillon/buildings.lua
-- Building interiors for Chillon — Swiss-French alpine town
-- Watchmaker ateliers, instrument workshops, jazz pavilion,
-- thermal baths, mountain refuge, time-speed shop

local M = {}
local GRID = 32

-- ═══════════════════════════════════════
-- INTERIOR DEFINITIONS
-- Each interior: dimensions, exit, portals, NPCs, furniture style
-- ═══════════════════════════════════════

M.interiors = {
  -- ── Café du Lac ─────────────────────────
  cafe = {
    name = "Café du Lac",
    width = 12, height = 10,
    exitX = 5, exitY = 9,
    floorColor = {0.55, 0.45, 0.35},  -- Warm wood plank
    wallColor = {0.65, 0.58, 0.48},   -- Cream plaster
    npcs = {
      {name = "Barista Léon", x = 3, y = 2, dialogue = "Café crème? I grind the beans by clockwork — the Horlogers built me a mill that turns exactly forty-two times per minute. Beethoven liked his coffee with exactly sixty beans, you know."},
      {name = "Pianiste Claire", x = 9, y = 4, dialogue = "I play Chopin every evening at seven. The Nocturne in E-flat — it was written for nights like these, when the snow is falling and the lamps are lit."}
    },
    furniture = {"tables", "chairs", "counter", "piano", "fireplace", "wine_rack"}
  },

  -- ── Fromagerie Vieux ────────────────────
  fromagerie = {
    name = "Fromagerie Vieux",
    width = 10, height = 8,
    exitX = 4, exitY = 7,
    floorColor = {0.50, 0.42, 0.32},
    wallColor = {0.60, 0.55, 0.45},
    npcs = {
      {name = "Fromager Gaspard", x = 3, y = 2, dialogue = "This Gruyère has aged eighteen months in our alpine caves. The cold is the secret — everything matures slowly in Chillon. Like a fugue by Bach, the flavor builds layer by layer."}
    },
    furniture = {"cheese_wheels", "aging_racks", "counter", "copper_pots"}
  },

  -- ── Maison du Commerce (Trading Post) ──
  trading_post = {
    name = "Maison du Commerce",
    width = 12, height = 10,
    exitX = 6, exitY = 9,
    floorColor = {0.48, 0.42, 0.36},
    wallColor = {0.58, 0.52, 0.45},
    npcs = {
      {name = "Commerçant Fabrice", x = 6, y = 2, dialogue = "Alpine crystals, thermal wool, precision tools — everything passes through Chillon. Our merchants have traded with every hub in the system."}
    },
    furniture = {"display_cases", "shelves", "counter", "crates", "scales"},
    portals = {
      {name = "Shop", x = 10, y = 2, w = 2, h = 1, game = "shop", label = "BOUTIQUE"}
    }
  },

  -- ── Hôtel de Ville (Town Hall) ──────────
  town_hall = {
    name = "Hôtel de Ville",
    width = 14, height = 12,
    exitX = 6, exitY = 11,
    floorColor = {0.45, 0.40, 0.35},
    wallColor = {0.62, 0.58, 0.50},
    npcs = {
      {name = "Archiviste Renée", x = 3, y = 3, dialogue = "The records of Chillon date back four centuries. Every watchmaker, every luthier, every composer who passed through — all documented. History is the greatest instrument of all."},
      {name = "Conseiller Moreau", x = 10, y = 3, dialogue = "We govern by consensus in Chillon. Decisions are made like music — everyone plays their part, and the mayor keeps tempo."}
    },
    furniture = {"long_table", "chairs", "chandelier", "bookshelves", "coat_of_arms", "grandfather_clock"},
    portals = {
      {name = "Asteroids", x = 1, y = 1, w = 2, h = 1, game = "asteroids", label = "ASTEROIDS"},
      {name = "Star Fox", x = 5, y = 1, w = 2, h = 1, game = "starfox", label = "STAR FOX"},
      {name = "Planet Map", x = 9, y = 1, w = 2, h = 1, game = "planetmap", label = "PLANET MAP"}
    }
  },

  -- ── Atelier Horloger (Watchmaker) ───────
  watchmaker = {
    name = "Atelier Horloger",
    width = 12, height = 10,
    exitX = 5, exitY = 9,
    floorColor = {0.42, 0.38, 0.32},
    wallColor = {0.58, 0.52, 0.44},
    npcs = {
      {name = "Apprenti Julien", x = 3, y = 4, dialogue = "Maître Renard says a watchmaker must have the hands of a surgeon and the soul of a composer. Each gear is a note — if one is out of tune, the whole mechanism fails."},
      {name = "Horlogère Mathilde", x = 9, y = 3, dialogue = "This tourbillon compensates for gravity's pull on the balance wheel. Three hundred years of innovation, all to gain a single second of accuracy. Liszt wrote his études the same way — relentless precision in pursuit of beauty."}
    },
    furniture = {"workbenches", "magnifying_lamps", "gear_displays", "tool_wall", "pendulum_clocks", "chronometer_cases"}
  },

  -- ── Lutherie des Alpes (Luthier) ────────
  luthier = {
    name = "Lutherie des Alpes",
    width = 10, height = 8,
    exitX = 4, exitY = 7,
    floorColor = {0.48, 0.40, 0.30},
    wallColor = {0.55, 0.48, 0.38},
    npcs = {
      {name = "Luthier Émile", x = 6, y = 3, dialogue = "The cello takes two years to build. The wood must cure, the varnish must rest. Bach wrote his suites for an instrument exactly like this one — designed to sing like a human voice."}
    },
    furniture = {"instrument_wall", "workbench", "wood_racks", "varnish_table", "strings_display", "half_finished_violin"}
  },

  -- ── Thermes de Chillon (Thermal Baths) ──
  thermal_baths = {
    name = "Thermes de Chillon",
    width = 14, height = 10,
    exitX = 6, exitY = 9,
    floorColor = {0.45, 0.50, 0.55},   -- Wet stone
    wallColor = {0.55, 0.52, 0.48},
    npcs = {
      {name = "Thérapeute Adèle", x = 4, y = 4, dialogue = "The volcanic springs run at exactly forty-two degrees. Our engineers channel this heat through the entire town. A civilized response to the cold — not brute force, but elegant thermodynamics."}
    },
    furniture = {"hot_pools", "steam_pipes", "stone_benches", "towel_racks", "copper_fixtures"}
  },

  -- ── Laboratoire Cryo (Cryo Lab) ────────
  cryo_lab = {
    name = "Laboratoire Cryo",
    width = 10, height = 8,
    exitX = 4, exitY = 7,
    floorColor = {0.38, 0.42, 0.48},
    wallColor = {0.48, 0.50, 0.55},
    npcs = {
      {name = "Chercheur Noël", x = 6, y = 3, dialogue = "We study the crystalline structure of alpine ice. Each snowflake is a unique timepiece — its geometry records the exact temperature and humidity of its birth. Nature's own chronometer."}
    },
    furniture = {"cryo_chambers", "microscopes", "sample_cases", "temperature_displays", "lab_benches"}
  },

  -- ── Refuge du Col (Mountain Refuge) ─────
  refuge = {
    name = "Refuge du Col",
    width = 8, height = 6,
    exitX = 3, exitY = 5,
    floorColor = {0.40, 0.35, 0.28},
    wallColor = {0.50, 0.44, 0.36},
    npcs = {
      {name = "Gardien Marcel", x = 4, y = 2, dialogue = "The wind at the Col du Temps can knock a man flat. But on clear nights, you can hear the chapel bells from here — Beethoven's Ode to Joy carried on the mountain air."}
    },
    furniture = {"bunk_beds", "wood_stove", "supplies", "ice_axes", "rope_coils"}
  },

  -- ── L'Observatoire ──────────────────────
  observatory = {
    name = "L'Observatoire",
    width = 10, height = 10,
    exitX = 4, exitY = 9,
    floorColor = {0.35, 0.34, 0.34},
    wallColor = {0.48, 0.46, 0.44},
    npcs = {
      {name = "Astronome Céline", x = 5, y = 3, dialogue = "Our telescope was ground by the same artisans who make the watch crystals. Precision is in Chillon's blood. Tonight I'm charting the Orion Nebula — a symphony of light that's been playing for ten thousand years."}
    },
    furniture = {"telescope", "star_charts", "orrery", "computation_desk", "dome_mechanism"},
    portals = {
      {name = "Ship Selection", x = 1, y = 1, w = 2, h = 1, game = "hangar", label = "HANGAR"},
      {name = "Exchange", x = 7, y = 1, w = 2, h = 1, game = "casino_exchange", label = "EXCHANGE"}
    }
  },

  -- ── Chalet Bois-Joli (Forest Chalet) ────
  forest_chalet = {
    name = "Chalet Bois-Joli",
    width = 10, height = 8,
    exitX = 4, exitY = 7,
    floorColor = {0.42, 0.36, 0.28},
    wallColor = {0.52, 0.45, 0.35},
    npcs = {
      {name = "Ermite Gaspar", x = 5, y = 3, dialogue = "I came here to listen. Not to people — to the forest. The wind in the pines plays in F-sharp minor. Chopin knew this key well. It is the key of solitude."}
    },
    furniture = {"fireplace", "rocking_chair", "bookshelf", "fur_rug", "candles", "writing_desk"}
  },

  -- ── Cabane du Guide ─────────────────────
  guide_cabin = {
    name = "Cabane du Guide",
    width = 8, height = 6,
    exitX = 3, exitY = 5,
    floorColor = {0.38, 0.34, 0.26},
    wallColor = {0.48, 0.42, 0.32},
    npcs = {
      {name = "Guide Félix", x = 4, y = 2, dialogue = "I've guided climbers up every peak in the Dents du Midi. The mountains don't keep time the way we do. Up there, an hour feels like a minute — or a year."}
    },
    furniture = {"climbing_gear", "maps_table", "boot_rack", "wood_stove"}
  },

  -- ── Pavillon du Jazz (Jazz Pavilion) ────
  jazz_pavilion = {
    name = "Pavillon du Jazz",
    width = 16, height = 10,
    exitX = 8, exitY = 9,
    floorColor = {0.35, 0.32, 0.30},   -- Dark stage floor
    wallColor = {0.42, 0.40, 0.38},
    npcs = {
      {name = "Trompettiste Louis", x = 4, y = 3, dialogue = "Miles, Coltrane, Monk — the greats all played festivals like this. Jazz is the language of freedom. Every note is a choice, every silence is a statement."},
      {name = "Organisatrice Sylvie", x = 12, y = 4, dialogue = "Twenty years running the Chillon Jazz Festival. We've had performers from every hub in the system. The mountains make the acoustics perfect — natural amplification."},
      {name = "Batteur Kofi", x = 8, y = 2, dialogue = "Rhythm is the oldest form of timekeeping. Before clocks, before watches — there was the drum. The horlogers and the musicians, we are cousins."}
    },
    furniture = {"stage", "drum_kit", "speakers", "lighting_rig", "audience_seats", "bar_counter", "sound_board"}
  },

  -- ── Boutique du Temps (Time Shop) ───────
  time_shop = {
    name = "Boutique du Temps",
    width = 12, height = 10,
    exitX = 5, exitY = 9,
    floorColor = {0.40, 0.38, 0.35},
    wallColor = {0.55, 0.50, 0.45},
    npcs = {
      {name = "Chronomancien Alois", x = 6, y = 3, dialogue = "Time is not constant — the Horlogers proved this centuries ago. With the right mechanism, you can nudge the tempo of reality itself. Browse my collection. Each piece bends the clock a little differently."}
    },
    furniture = {"display_cases", "pendulum_wall", "hourglass_collection", "chronometer_shelf", "mystical_gears"},
    portals = {
      {name = "Time Shop", x = 9, y = 2, w = 2, h = 1, game = "shop", label = "BOUTIQUE DU TEMPS"}
    }
  },

  -- ── Chapelle Saint-Bernard ──────────────
  chapel = {
    name = "Chapelle Saint-Bernard",
    width = 10, height = 12,
    exitX = 4, exitY = 11,
    floorColor = {0.45, 0.42, 0.40},
    wallColor = {0.60, 0.58, 0.55},
    npcs = {
      {name = "Carillonneur Baptiste", x = 5, y = 3, dialogue = "Two hundred bells, tuned to perfection. At noon, the carillon plays the first fugue from Bach's Well-Tempered Clavier. At midnight, the Art of the Fugue. The bells have rung without interruption for three hundred years."}
    },
    furniture = {"pews", "altar", "bell_mechanism", "stained_glass", "organ_pipes", "candelabras"}
  }
}

-- ═══════════════════════════════════════
-- UTILITY FUNCTIONS
-- ═══════════════════════════════════════

function M.createInteriorCollisionMap(interior)
  local map = {}
  for y = 0, interior.height - 1 do
    map[y] = {}
    for x = 0, interior.width - 1 do
      -- Walls around perimeter
      if y == 0 or y == interior.height - 1 or x == 0 or x == interior.width - 1 then
        map[y][x] = true
      else
        map[y][x] = false
      end
    end
  end

  -- Exit is walkable
  if map[interior.exitY] then
    map[interior.exitY][interior.exitX] = false
  end

  -- Portals are walkable
  if interior.portals then
    for _, portal in ipairs(interior.portals) do
      for py = portal.y, portal.y + portal.h - 1 do
        for px = portal.x, portal.x + portal.w - 1 do
          if map[py] and map[py][px] ~= nil then
            map[py][px] = false
          end
        end
      end
    end
  end

  -- NPCs are collidable
  if interior.npcs then
    for _, npc in ipairs(interior.npcs) do
      if map[npc.y] and map[npc.y][npc.x] ~= nil then
        map[npc.y][npc.x] = true
      end
    end
  end

  return map
end

function M.getInterior(name)
  return M.interiors[name]
end

function M.isAtExit(interior, gridX, gridY)
  return gridX == interior.exitX and gridY == interior.exitY
end

return M
