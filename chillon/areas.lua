-- chillon/areas.lua
-- Chillon: Swiss-French alpine lakeside town (Montreux × Chamonix)
-- Cobblestone promenades, watchmaker ateliers, lakefront jazz stages,
-- alpine chalets, instrument workshops, and snow-capped peaks

local M = {}

M.GRID_SIZE = 32

-- World dimensions
M.WIDTH = 55
M.HEIGHT = 45

-- ═══════════════════════════════════════
-- ZONE DEFINITIONS
-- Warm alpine palette: cream stone, slate roofs, lake blue,
-- chalet timber, snow white, pine green
-- ═══════════════════════════════════════

M.zones = {
  -- Central village (lakefront promenade)
  village_square = {
    name = "Place de l'Horloge",
    x1 = 18, y1 = 18, x2 = 38, y2 = 32,
    groundColor = {0.58, 0.54, 0.48},  -- Warm cobblestone
    ambientSound = "crowd"
  },

  -- Western pine forest (hiking trails)
  pine_forest = {
    name = "Forêt des Aiguilles",
    x1 = 0, y1 = 18, x2 = 17, y2 = 32,
    groundColor = {0.25, 0.30, 0.22},  -- Forest floor with needles
    ambientSound = "birds"
  },

  -- Eastern lake (Lac de Chillon)
  frozen_lake = {
    name = "Lac de Chillon",
    x1 = 37, y1 = 22, x2 = 48, y2 = 32,
    groundColor = {0.30, 0.48, 0.62},  -- Deep alpine lake blue
    isLake = true,
    ambientSound = "water_lapping"
  },

  -- Northern peaks (Mont Blanc massif)
  north_peaks = {
    name = "Les Dents du Midi",
    x1 = 0, y1 = 0, x2 = 54, y2 = 8,
    groundColor = {0.42, 0.40, 0.38},  -- Alpine granite
    isMountain = true,
    ambientSound = "wind"
  },

  -- Mountain pass (trail to summit)
  mountain_pass = {
    name = "Col du Temps",
    x1 = 22, y1 = 5, x2 = 32, y2 = 17,
    groundColor = {0.48, 0.46, 0.42},  -- Rocky trail
    ambientSound = "wind"
  },

  -- Artisan quarter (watchmakers and instrument shops)
  artisan_quarter = {
    name = "Quartier des Horlogers",
    x1 = 0, y1 = 9, x2 = 12, y2 = 17,
    groundColor = {0.55, 0.50, 0.45},  -- Clean cobblestone
    ambientSound = "ticking"
  },

  -- Thermal springs (engineered heating district)
  thermal_district = {
    name = "Les Thermes",
    x1 = 42, y1 = 9, x2 = 54, y2 = 21,
    groundColor = {0.52, 0.48, 0.44},  -- Warm flagstone
    ambientSound = "steam"
  },

  -- Southern snowfield (open alpine meadow)
  snowfield = {
    name = "Pré Blanc",
    x1 = 0, y1 = 33, x2 = 54, y2 = 44,
    groundColor = {0.82, 0.85, 0.90},  -- Deep packed snow
    ambientSound = "wind"
  },

  -- Lakeside promenade (jazz festival grounds)
  lakefront = {
    name = "Promenade du Jazz",
    x1 = 37, y1 = 18, x2 = 48, y2 = 21,
    groundColor = {0.52, 0.50, 0.46},  -- Polished flagstone
    ambientSound = "jazz"
  },

  -- Observatory ridge
  observatory_ridge = {
    name = "Belvédère",
    x1 = 42, y1 = 0, x2 = 54, y2 = 8,
    groundColor = {0.40, 0.38, 0.36},  -- Wind-scoured rock
    isMountain = true,
    ambientSound = "wind"
  },

  -- Western cliffs
  western_cliffs = {
    name = "Falaise Ouest",
    x1 = 0, y1 = 0, x2 = 12, y2 = 8,
    groundColor = {0.38, 0.36, 0.34},  -- Ice-covered granite
    isMountain = true,
    ambientSound = "wind"
  },

  -- Mountain slopes (rocky terrain between zones)
  west_slope = {
    name = "Versant Ouest",
    x1 = 13, y1 = 9, x2 = 21, y2 = 17,
    groundColor = {0.40, 0.38, 0.36},  -- Rocky slope
    isMountain = true,
    ambientSound = "wind"
  },
  east_slope = {
    name = "Versant Est",
    x1 = 33, y1 = 9, x2 = 41, y2 = 17,
    groundColor = {0.42, 0.40, 0.37},  -- Rocky slope
    isMountain = true,
    ambientSound = "wind"
  },
  eastern_shore = {
    name = "Rive Est",
    x1 = 49, y1 = 22, x2 = 53, y2 = 32,
    groundColor = {0.36, 0.38, 0.40},  -- Rocky lakeshore
    isMountain = true,
    ambientSound = "wind"
  }
}

-- ═══════════════════════════════════════
-- BUILDINGS
-- Swiss chalets, stone ateliers, lakefront pavilions
-- ═══════════════════════════════════════

M.buildings = {
  -- Place de l'Horloge (central square)
  {name = "Café du Lac", x = 19, y = 18, w = 7, h = 4, doorX = 22, doorY = 22, interior = "cafe",
   color = {0.65, 0.58, 0.48}, roofColor = {0.35, 0.32, 0.30}, timberColor = {0.45, 0.35, 0.25},
   style = "chalet"},
  {name = "Fromagerie Vieux", x = 30, y = 18, w = 5, h = 4, doorX = 32, doorY = 22, interior = "fromagerie",
   color = {0.62, 0.56, 0.46}, roofColor = {0.30, 0.28, 0.27}, timberColor = {0.42, 0.34, 0.24},
   style = "chalet"},
  {name = "Maison du Commerce", x = 20, y = 26, w = 6, h = 4, doorX = 23, doorY = 30, interior = "trading_post",
   color = {0.60, 0.55, 0.48}, roofColor = {0.32, 0.30, 0.28}, timberColor = {0.40, 0.32, 0.22},
   style = "chalet"},
  {name = "Hôtel de Ville", x = 30, y = 26, w = 7, h = 4, doorX = 33, doorY = 30, interior = "town_hall",
   color = {0.68, 0.62, 0.52}, roofColor = {0.28, 0.26, 0.25}, timberColor = {0.48, 0.40, 0.30},
   style = "greathall"},

  -- Mountain pass
  {name = "Refuge du Col", x = 24, y = 10, w = 4, h = 3, doorX = 26, doorY = 13, interior = "refuge",
   color = {0.55, 0.50, 0.44}, roofColor = {0.38, 0.35, 0.32}, timberColor = {0.42, 0.36, 0.28},
   style = "cabin"},
  {name = "L'Observatoire", x = 29, y = 6, w = 4, h = 5, doorX = 31, doorY = 11, interior = "observatory",
   color = {0.58, 0.55, 0.52}, roofColor = {0.32, 0.30, 0.30}, timberColor = {0.40, 0.38, 0.34},
   style = "tower"},

  -- Artisan quarter (watchmakers + instrument workshops)
  {name = "Atelier Horloger", x = 3, y = 10, w = 6, h = 4, doorX = 6, doorY = 14, interior = "watchmaker",
   color = {0.62, 0.58, 0.50}, roofColor = {0.30, 0.28, 0.26}, timberColor = {0.44, 0.36, 0.26},
   style = "chalet"},
  {name = "Lutherie des Alpes", x = 7, y = 14, w = 4, h = 3, doorX = 9, doorY = 17, interior = "luthier",
   color = {0.58, 0.52, 0.44}, roofColor = {0.32, 0.30, 0.28}, timberColor = {0.40, 0.34, 0.24},
   style = "chalet"},

  -- Thermal district
  {name = "Thermes de Chillon", x = 44, y = 12, w = 5, h = 4, doorX = 46, doorY = 16, interior = "thermal_baths",
   color = {0.60, 0.56, 0.50}, roofColor = {0.35, 0.33, 0.30}, timberColor = {0.42, 0.36, 0.28},
   style = "chalet"},
  {name = "Laboratoire Cryo", x = 49, y = 15, w = 4, h = 3, doorX = 51, doorY = 18, interior = "cryo_lab",
   color = {0.55, 0.52, 0.50}, roofColor = {0.30, 0.28, 0.28}, timberColor = {0.38, 0.34, 0.30},
   style = "cabin"},

  -- Pine forest
  {name = "Chalet Bois-Joli", x = 5, y = 22, w = 5, h = 4, doorX = 7, doorY = 26, interior = "forest_chalet",
   color = {0.52, 0.45, 0.35}, roofColor = {0.30, 0.28, 0.24}, timberColor = {0.42, 0.35, 0.25},
   style = "cabin"},
  {name = "Cabane du Guide", x = 12, y = 26, w = 4, h = 3, doorX = 14, doorY = 29, interior = "guide_cabin",
   color = {0.48, 0.42, 0.32}, roofColor = {0.32, 0.28, 0.24}, timberColor = {0.38, 0.30, 0.22},
   style = "cabin"},

  -- Lakefront
  {name = "Pavillon du Jazz", x = 40, y = 18, w = 6, h = 3, doorX = 43, doorY = 21, interior = "jazz_pavilion",
   color = {0.50, 0.48, 0.45}, roofColor = {0.35, 0.34, 0.32}, timberColor = {0.40, 0.36, 0.30},
   style = "pavilion"},

  -- Snowfield
  {name = "Boutique du Temps", x = 22, y = 36, w = 5, h = 3, doorX = 24, doorY = 39, interior = "time_shop",
   color = {0.60, 0.56, 0.50}, roofColor = {0.32, 0.30, 0.28}, timberColor = {0.44, 0.38, 0.28},
   style = "chalet"},
  {name = "Chapelle Saint-Bernard", x = 38, y = 38, w = 5, h = 4, doorX = 40, doorY = 42, interior = "chapel",
   color = {0.65, 0.62, 0.58}, roofColor = {0.30, 0.28, 0.27}, timberColor = {0.45, 0.40, 0.35},
   style = "chapel"}
}

-- ═══════════════════════════════════════
-- NPCs (Swiss-French alpine, classical music lovers,
--  watchmakers, instrument craftspeople, engineers)
-- ═══════════════════════════════════════

M.npcs = {
  -- Place de l'Horloge
  {name = "Maire Delacroix", x = 34, y = 25, dialogue = "Welcome to Chillon! Our little town has kept time for the galaxy since before the Great Freeze. The watchmakers here are the finest anywhere — and in July, we host the greatest jazz festival this side of the nebula.", zone = "village_square", gender = "female", design = 2},
  {name = "Chef Arnaud", x = 33, y = 22, dialogue = "Raclette fresh from the wheel, fondue bubbling in copper pots, and vin chaud to warm your bones. In Chillon, the cold is just an excuse to eat better.", zone = "village_square", gender = "male"},
  {name = "Marchande Céleste", x = 22, y = 25, dialogue = "Swiss chocolate, alpine honey, thermal wool — everything you need for the mountain cold. My grandmother survived sixty winters on nothing but cheese and determination.", zone = "village_square", gender = "female", design = 3},
  {name = "Prof. Abelard", x = 25, y = 23, dialogue = "Bach's Goldberg Variations — have you heard them played on our mechanical organ? Each note is a tiny miracle of springs and hammers, frozen in time. Pure mathematics made audible.", zone = "village_square", gender = "male"},

  -- Mountain pass
  {name = "Guide Margaux", x = 27, y = 12, dialogue = "The Col du Temps is named for the strange way time flows near the summit. Your watch will run slow up there — or fast. The horlogers say it's magnetic fields. I say it's magic.", zone = "mountain_pass", gender = "female", design = 5},
  {name = "Astronome Voss", x = 30, y = 9, dialogue = "From the observatory, I can resolve individual stars in the Pleiades. But lately I've been watching something else — a slow movement in the constellations. Like Beethoven's Seventh, building toward something immense.", zone = "mountain_pass", gender = "male"},

  -- Artisan quarter
  {name = "Maître Horloger Renard", x = 5, y = 13, dialogue = "Sixty-three jewels, four hundred and twelve components, each smaller than a grain of rice. This chronometer will keep perfect time for a thousand years. That is the heritage of Chillon.", zone = "artisan_quarter", gender = "male"},
  {name = "Luthière Solange", x = 10, y = 16, dialogue = "I use only alpine spruce for the soundboard — three hundred years old, grown slowly in the cold. Stradivari understood this: the best instruments are born of patience. Like Chopin's Ballades, they cannot be rushed.", zone = "artisan_quarter", gender = "female", design = 4},

  -- Thermal district
  {name = "Dr. Fontaine", x = 47, y = 15, dialogue = "Our geothermal system pipes volcanic heat through every building in Chillon. While others freeze, we dine in comfort. Chopin composed his Nocturnes in warmth like this, you know.", zone = "thermal_district", gender = "female", design = 4},
  {name = "Ingénieur Pascal", x = 50, y = 13, dialogue = "The cryo-stabilizers keep the lake from freezing solid. An entire ecosystem preserved under glass-clear water. Liszt would have called it 'transcendental.'", zone = "thermal_district", gender = "male"},

  -- Pine forest
  {name = "Garde-Forestier Hugo", x = 8, y = 25, dialogue = "The alpine ibex have returned to the Aiguilles this season. I count them at dawn — forty-seven, last I checked. Nature's own symphony, no conductor required.", zone = "pine_forest", gender = "male"},
  {name = "Botaniste Elise", x = 14, y = 28, dialogue = "Edelweiss grows above the tree line, but only where the snow melts just so. Each bloom is a tiny clock — it opens at dawn and closes at dusk, perfectly timed.", zone = "pine_forest", gender = "female", design = 6},

  -- Lakefront / Jazz festival
  {name = "Saxophoniste Théo", x = 43, y = 20, dialogue = "The Festival de Jazz de Chillon! We've had legends play this stage — under the stars, with the mountains behind us. Tonight it's a Coltrane tribute. You should stay.", zone = "lakefront", gender = "male"},
  {name = "Chanteuse Mireille", x = 41, y = 19, dialogue = "Between sets, I walk the promenade and listen to the lake. Debussy heard water this way too — that's why the Arabesques shimmer the way they do. Music is everywhere if you're listening.", zone = "lakefront", gender = "female", design = 2},

  -- Snowfield
  {name = "Bergère Annette", x = 24, y = 38, dialogue = "The Pré Blanc looks empty, but listen — beneath the snow, the springs are running. In Chillon, nothing is ever truly still. Even time has its tempo.", zone = "snowfield", gender = "female", design = 3},
  {name = "Archéologue Duval", x = 40, y = 41, dialogue = "The chapel dates to before colonization. The bell tower contains a mechanical carillon — two hundred bells playing Bach's Art of the Fugue at noon. Still perfectly in tune after all these centuries.", zone = "snowfield", gender = "male"}
}

-- ═══════════════════════════════════════
-- DECORATIONS
-- ═══════════════════════════════════════

M.decorations = {
  -- Pine trees — alpine forest
  {type = "pine_tree", x = 2, y = 19, variety = 1},
  {type = "pine_tree", x = 5, y = 20, variety = 2},
  {type = "pine_tree", x = 8, y = 19, variety = 1},
  {type = "pine_tree", x = 11, y = 20, variety = 2},
  {type = "pine_tree", x = 14, y = 19, variety = 1},
  {type = "pine_tree", x = 3, y = 24, variety = 2},
  {type = "pine_tree", x = 9, y = 23, variety = 1},
  {type = "pine_tree", x = 15, y = 25, variety = 2},
  {type = "pine_tree", x = 1, y = 28, variety = 1},
  {type = "pine_tree", x = 6, y = 29, variety = 2},
  {type = "pine_tree", x = 11, y = 30, variety = 1},
  {type = "pine_tree", x = 16, y = 28, variety = 2},
  -- Scattered pines around village
  {type = "pine_tree", x = 17, y = 20, variety = 1},
  {type = "pine_tree", x = 38, y = 20, variety = 2},
  {type = "pine_tree", x = 39, y = 28, variety = 1},
  -- Mountain pass pines (sparse, windswept)
  {type = "pine_tree", x = 23, y = 7, variety = 1},
  {type = "pine_tree", x = 31, y = 8, variety = 2},
  -- Thermal district pines
  {type = "pine_tree", x = 43, y = 10, variety = 1},
  {type = "pine_tree", x = 52, y = 11, variety = 2},

  -- Street lamps (wrought-iron, Belle Époque style)
  {type = "street_lamp", x = 18, y = 23},
  {type = "street_lamp", x = 38, y = 23},
  {type = "street_lamp", x = 18, y = 30},
  {type = "street_lamp", x = 38, y = 30},
  {type = "street_lamp", x = 27, y = 18},
  {type = "street_lamp", x = 27, y = 30},
  {type = "street_lamp", x = 39, y = 19},
  {type = "street_lamp", x = 45, y = 19},

  -- Clocktower (central square landmark)
  {type = "clocktower", x = 28, y = 24},

  -- Fountain (village center)
  {type = "fountain", x = 25, y = 20},

  -- Jazz festival stage elements (lakefront)
  {type = "jazz_stage", x = 41, y = 19, w = 4, h = 2},
  {type = "string_lights", x = 38, y = 18, w = 10},
  {type = "festival_banner", x = 40, y = 17},
  {type = "festival_banner", x = 46, y = 17},

  -- Benches (promenade + village)
  {type = "bench", x = 24, y = 24},
  {type = "bench", x = 35, y = 22},
  {type = "bench", x = 39, y = 21},
  {type = "bench", x = 44, y = 21},

  -- Flower boxes and planters
  {type = "flower_box", x = 21, y = 22},
  {type = "flower_box", x = 36, y = 26},
  {type = "flower_box", x = 31, y = 22},

  -- Watch display case (artisan quarter)
  {type = "watch_display", x = 4, y = 12},
  {type = "watch_display", x = 10, y = 16},

  -- Boulders (alpine)
  {type = "boulder", x = 14, y = 12},
  {type = "boulder", x = 20, y = 8},
  {type = "boulder", x = 33, y = 7},
  {type = "boulder", x = 48, y = 20},
  {type = "boulder", x = 3, y = 32},

  -- Snow drifts
  {type = "snowdrift", x = 25, y = 35, w = 3, h = 1},
  {type = "snowdrift", x = 35, y = 37, w = 2, h = 1},
  {type = "snowdrift", x = 12, y = 36, w = 3, h = 1},
  {type = "snowdrift", x = 42, y = 36, w = 2, h = 1},

  -- Hot spring pools (thermal district)
  {type = "hot_spring_pool", x = 45, y = 17, w = 3, h = 2},
  {type = "hot_spring_pool", x = 50, y = 10, w = 2, h = 2},

  -- Wooden bridges
  {type = "wooden_bridge", x = 16, y = 31, w = 3, h = 1},
  {type = "wooden_bridge", x = 38, y = 24, w = 1, h = 3},

  -- Wine barrels (café and fromagerie)
  {type = "barrel", x = 20, y = 22},
  {type = "barrel", x = 37, y = 22},

  -- Supply crates
  {type = "supply_crate", x = 21, y = 26},
  {type = "supply_crate", x = 36, y = 28},

  -- Ice formations near lake
  {type = "ice_pillar", x = 40, y = 23},
  {type = "ice_pillar", x = 46, y = 25},
  {type = "ice_pillar", x = 42, y = 30},

  -- Frozen waterfall (cliff side)
  {type = "frozen_waterfall", x = 1, y = 10, w = 2, h = 4}
}

-- Spawn point (village center)
M.spawnPoint = {x = 27, y = 25}

-- ═══════════════════════════════════════
-- GORGES (void areas under bridges — impassable except on bridges)
-- ═══════════════════════════════════════

M.gorges = {
  -- Ravine between pine forest and snowfield (spanned by west bridge)
  {id = "west_ravine", x1 = 14, y1 = 30, x2 = 20, y2 = 32, depth = 180},
  -- Gorge between village square and frozen lake (spanned by east bridge)
  {id = "east_gorge", x1 = 37, y1 = 23, x2 = 39, y2 = 27, depth = 250},
}

-- Bridges span the gorges (use decoration positions)
M.bridges = {
  {id = "west_bridge", x = 16, y = 31, w = 3, h = 1},
  {id = "east_bridge", x = 38, y = 24, w = 1, h = 3},
}

-- ═══════════════════════════════════════
-- MOUNTAIN TRAILS (walkable paths through mountain zones)
-- ═══════════════════════════════════════

M.trails = {
  -- Main trail: village → mountain pass
  {name = "Sentier du Nord",
   segments = {
     {x1 = 25, y1 = 18, x2 = 28, y2 = 18},
     {x1 = 26, y1 = 13, x2 = 28, y2 = 17},
     {x1 = 24, y1 = 8, x2 = 28, y2 = 12},
   }},
  -- Trail to artisan quarter
  {name = "Chemin des Horlogers",
   segments = {
     {x1 = 18, y1 = 17, x2 = 12, y2 = 17},
     {x1 = 4, y1 = 14, x2 = 11, y2 = 17},
   }},
  -- Trail to thermal district
  {name = "Allée des Thermes",
   segments = {
     {x1 = 36, y1 = 20, x2 = 42, y2 = 20},
     {x1 = 42, y1 = 14, x2 = 44, y2 = 19},
   }},
  -- Lakefront promenade
  {name = "Promenade du Lac",
   segments = {
     {x1 = 36, y1 = 26, x2 = 39, y2 = 26},
   }},
  -- Snowfield trail
  {name = "Sentier du Sud",
   segments = {
     {x1 = 24, y1 = 28, x2 = 28, y2 = 33},
   }}
}

-- ═══════════════════════════════════════
-- PARTICLE / STAR SYSTEMS
-- ═══════════════════════════════════════

local particles = {}
local stars = {}

function M.initParticles(count)
  particles = {}
  for i = 1, count do
    table.insert(particles, {
      x = math.random(0, M.WIDTH * M.GRID_SIZE),
      y = math.random(0, M.HEIGHT * M.GRID_SIZE),
      size = 1 + math.random() * 2,
      speed = 5 + math.random() * 10,
      phase = math.random() * math.pi * 2,
      brightness = 0.3 + math.random() * 0.7,
      type = "snow"
    })
  end
end

function M.initStars(count)
  stars = {}
  for i = 1, count do
    table.insert(stars, {
      x = math.random(0, 800),
      y = math.random(0, 200),
      size = 0.5 + math.random() * 1.5,
      twinklePhase = math.random() * math.pi * 2,
      brightness = 0.3 + math.random() * 0.7
    })
  end
end

function M.getParticles() return particles end
function M.getStars() return stars end

-- ═══════════════════════════════════════
-- UTILITY FUNCTIONS
-- ═══════════════════════════════════════

function M.getZoneAt(gridX, gridY)
  -- Mountain pass takes priority (it overlaps north_peaks)
  local pass = M.zones.mountain_pass
  if gridX >= pass.x1 and gridX <= pass.x2 and gridY >= pass.y1 and gridY <= pass.y2 then
    return "mountain_pass", pass
  end
  -- Lakefront priority (overlaps with frozen_lake area)
  local lf = M.zones.lakefront
  if gridX >= lf.x1 and gridX <= lf.x2 and gridY >= lf.y1 and gridY <= lf.y2 then
    return "lakefront", lf
  end
  -- Observatory ridge priority
  local ridge = M.zones.observatory_ridge
  if gridX >= ridge.x1 and gridX <= ridge.x2 and gridY >= ridge.y1 and gridY <= ridge.y2 then
    return "observatory_ridge", ridge
  end
  -- Western cliffs priority
  local cliffs = M.zones.western_cliffs
  if gridX >= cliffs.x1 and gridX <= cliffs.x2 and gridY >= cliffs.y1 and gridY <= cliffs.y2 then
    return "western_cliffs", cliffs
  end
  for name, zone in pairs(M.zones) do
    if name ~= "mountain_pass" and name ~= "lakefront" and name ~= "observatory_ridge" and name ~= "western_cliffs" then
      if gridX >= zone.x1 and gridX <= zone.x2 and gridY >= zone.y1 and gridY <= zone.y2 then
        return name, zone
      end
    end
  end
  return nil, nil
end

function M.getBuildingAt(gridX, gridY)
  for _, b in ipairs(M.buildings) do
    if gridX == b.doorX and gridY == b.doorY then
      return b
    end
  end
  return nil
end

-- Check if a tile is in a gorge
function M.isGorge(gridX, gridY)
  for _, g in ipairs(M.gorges) do
    if gridX >= g.x1 and gridX <= g.x2 and gridY >= g.y1 and gridY <= g.y2 then
      return true, g
    end
  end
  return false
end

-- Check if a tile is on a bridge (walkable over gorge)
function M.isOnBridge(gridX, gridY)
  for _, br in ipairs(M.bridges) do
    if gridX >= br.x and gridX < br.x + br.w and gridY >= br.y and gridY < br.y + br.h then
      return true, br
    end
  end
  return false
end

-- Check if a tile is on a trail
function M.isOnTrail(gridX, gridY)
  for _, trail in ipairs(M.trails) do
    for _, seg in ipairs(trail.segments) do
      local minX = math.min(seg.x1, seg.x2)
      local maxX = math.max(seg.x1, seg.x2)
      local minY = math.min(seg.y1, seg.y2)
      local maxY = math.max(seg.y1, seg.y2)
      if gridX >= minX and gridX <= maxX and gridY >= minY and gridY <= maxY then
        return true
      end
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
      -- Perimeter walls
      if y == 0 or y == M.HEIGHT - 1 or x == 0 or x == M.WIDTH - 1 then
        map[y][x] = true
      else
        map[y][x] = false
      end
    end
  end

  -- Gorges are impassable (void) except where bridges span them
  for y = 0, M.HEIGHT - 1 do
    for x = 0, M.WIDTH - 1 do
      local isGorge = M.isGorge(x, y)
      local onBridge = M.isOnBridge(x, y)
      if isGorge and not onBridge then
        map[y][x] = true
      end
    end
  end

  -- Mountains and rocky slopes are solid
  for _, zoneName in ipairs({"north_peaks", "observatory_ridge", "western_cliffs", "west_slope", "east_slope", "eastern_shore"}) do
    local zone = M.zones[zoneName]
    for y = zone.y1, zone.y2 do
      for x = zone.x1, zone.x2 do
        if map[y] and map[y][x] ~= nil then
          map[y][x] = true
        end
      end
    end
  end

  -- Lake is impassable (deep water) except the lakefront promenade
  local lake = M.zones.frozen_lake
  for y = lake.y1, lake.y2 do
    for x = lake.x1, lake.x2 do
      if map[y] and map[y][x] ~= nil then
        map[y][x] = true
      end
    end
  end

  -- Mountain pass trails override mountains to be walkable
  for y = 0, M.HEIGHT - 1 do
    for x = 0, M.WIDTH - 1 do
      if M.isOnTrail(x, y) then
        if map[y] and map[y][x] ~= nil then
          if not (y == 0 or y == M.HEIGHT - 1 or x == 0 or x == M.WIDTH - 1) then
            map[y][x] = false
          end
        end
      end
    end
  end

  -- Lakefront promenade is walkable
  local lf = M.zones.lakefront
  for y = lf.y1, lf.y2 do
    for x = lf.x1, lf.x2 do
      if map[y] and map[y][x] ~= nil then
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
    if map[b.doorY] then
      map[b.doorY][b.doorX] = false
    end
    if map[b.doorY - 1] then
      map[b.doorY - 1][b.doorX] = false
    end
  end

  -- Collidable decorations
  for _, deco in ipairs(M.decorations) do
    if deco.type == "pine_tree" or deco.type == "boulder" or deco.type == "clocktower"
       or deco.type == "fountain" or deco.type == "supply_crate" or deco.type == "barrel"
       or deco.type == "ice_pillar" or deco.type == "frozen_waterfall"
       or deco.type == "watch_display" or deco.type == "jazz_stage" then
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
