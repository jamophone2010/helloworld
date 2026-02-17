-- cereus/areas.lua
-- Desert hub world layout inspired by Boyce Thompson Arboretum, Superior, AZ
-- Outdoor botanical garden in the Sonoran Desert surrounded by natural mountains
-- Named "Cereus" after the night-blooming cereus cactus native to Arizona

local M = {}

M.GRID_SIZE = 32

-- World dimensions (large outdoor area — 392 acres compressed)
M.WIDTH = 70
M.HEIGHT = 55

-- ═══════════════════════════════════════
-- ZONE DEFINITIONS
-- ═══════════════════════════════════════

M.zones = {
  -- Main Entry & Visitor Center (south central)
  visitor_center = {
    name = "Visitor Center",
    x1 = 28, y1 = 44, x2 = 42, y2 = 52,
    groundColor = {0.82, 0.72, 0.58},  -- Packed desert earth / flagstone
    ambientSound = "desert_wind"
  },
  -- Main Loop Trail (central ring path)
  main_loop = {
    name = "Main Loop Trail",
    x1 = 10, y1 = 15, x2 = 60, y2 = 43,
    groundColor = {0.78, 0.68, 0.52},  -- Sandy desert soil
    ambientSound = "desert_birds"
  },
  -- Cactus Garden (west side — Arizona desert natives)
  cactus_garden = {
    name = "Cactus Garden",
    x1 = 2, y1 = 18, x2 = 15, y2 = 35,
    groundColor = {0.85, 0.75, 0.55},  -- Reddish sandy soil
    ambientSound = "desert_wind"
  },
  -- Wallace Desert Garden (east — Australian/African arid plants)
  wallace_garden = {
    name = "Wallace Desert Garden",
    x1 = 50, y1 = 18, x2 = 65, y2 = 32,
    groundColor = {0.88, 0.78, 0.60},  -- Light sandy earth
    ambientSound = "desert_birds"
  },
  -- South American Desert Exhibit
  south_american = {
    name = "South American Exhibit",
    x1 = 50, y1 = 33, x2 = 65, y2 = 43,
    groundColor = {0.80, 0.70, 0.50},  -- Clay-ish desert
    ambientSound = "desert_wind"
  },
  -- Eucalyptus Forest (northwest grove)
  eucalyptus_forest = {
    name = "Eucalyptus Forest",
    x1 = 2, y1 = 5, x2 = 18, y2 = 17,
    groundColor = {0.55, 0.50, 0.38},  -- Shaded leaf litter
    ambientSound = "forest_birds"
  },
  -- Queen Creek Canyon (north central — rocky canyon with wash)
  queen_creek = {
    name = "Queen Creek Canyon",
    x1 = 22, y1 = 2, x2 = 48, y2 = 14,
    groundColor = {0.70, 0.55, 0.40},  -- Rocky canyon floor
    ambientSound = "creek_water"
  },
  -- Ayer Lake (northeast — man-made reservoir)
  ayer_lake = {
    name = "Ayer Lake",
    x1 = 48, y1 = 2, x2 = 62, y2 = 14,
    groundColor = {0.25, 0.45, 0.55},  -- Riparian lakeside
    isWater = true,
    ambientSound = "lake_water"
  },
  -- Picketpost Mountain (north — volcanic peaks, impassable cliffs)
  picketpost = {
    name = "Picketpost Mountain",
    x1 = 0, y1 = 0, x2 = 21, y2 = 4,
    groundColor = {0.50, 0.40, 0.32},  -- Dark volcanic rock
    ambientSound = "mountain_wind"
  },
  -- Eastern Mountains
  east_mountains = {
    name = "Magma Ridge",
    x1 = 63, y1 = 0, x2 = 69, y2 = 54,
    groundColor = {0.55, 0.42, 0.35},
    ambientSound = "mountain_wind"
  },
  -- Southern Foothills
  south_foothills = {
    name = "Desert Foothills",
    x1 = 0, y1 = 50, x2 = 69, y2 = 54,
    groundColor = {0.72, 0.60, 0.45},
    ambientSound = "desert_wind"
  },
  -- Western Cliffs
  west_cliffs = {
    name = "Arnett Canyon",
    x1 = 0, y1 = 0, x2 = 1, y2 = 54,
    groundColor = {0.52, 0.42, 0.35},
    ambientSound = "mountain_wind"
  },
}

-- ═══════════════════════════════════════
-- MOUNTAIN RANGES (impassable terrain forming natural borders)
-- These create the Arizona canyon feel around the arboretum
-- ═══════════════════════════════════════

M.mountains = {
  -- Picketpost Mountain range (north) — volcanic formation looming over the garden
  {x1 = 0, y1 = 0, x2 = 21, y2 = 3, height = 5, color = {0.45, 0.35, 0.28}, 
   peakColor = {0.60, 0.50, 0.40}, name = "Picketpost Mountain", volcanic = true},
  {x1 = 22, y1 = 0, x2 = 69, y2 = 1, height = 3, color = {0.50, 0.40, 0.32},
   peakColor = {0.62, 0.52, 0.42}, name = "Canyon Ridge"},

  -- Western cliffs (Arnett Canyon walls)
  {x1 = 0, y1 = 0, x2 = 1, y2 = 54, height = 4, color = {0.48, 0.38, 0.30},
   peakColor = {0.58, 0.48, 0.38}, name = "Arnett Cliffs"},

  -- Eastern ridge (Magma Ridge)
  {x1 = 65, y1 = 0, x2 = 69, y2 = 54, height = 4, color = {0.50, 0.38, 0.30},
   peakColor = {0.65, 0.50, 0.38}, name = "Magma Ridge", volcanic = true},

  -- Southern foothills
  {x1 = 0, y1 = 52, x2 = 69, y2 = 54, height = 2, color = {0.55, 0.45, 0.35},
   peakColor = {0.68, 0.55, 0.42}, name = "South Foothills"},
}

-- ═══════════════════════════════════════
-- BUILDINGS (historic structures of the arboretum)
-- ═══════════════════════════════════════

M.buildings = {
  -- Smith Building (1925 — original headquarters, locally quarried rock)
  {name = "Smith Building", x = 30, y = 45, w = 6, h = 4, doorX = 33, doorY = 49, interior = "smith_building",
   color = {0.62, 0.55, 0.45}, roofColor = {0.50, 0.38, 0.28},
   style = "historic_stone", year = 1925},

  -- Visitor Center / Gift Shop
  {name = "Visitor Center", x = 36, y = 46, w = 5, h = 3, doorX = 38, doorY = 49, interior = "visitor_center",
   color = {0.72, 0.65, 0.52}, roofColor = {0.55, 0.40, 0.28},
   style = "adobe"},

  -- Picket Post House (7000 sq ft "Castle on the Rock" — founder's mansion on hill)
  {name = "Picket Post House", x = 6, y = 4, w = 8, h = 5, doorX = 10, doorY = 9, interior = "picketpost_house",
   color = {0.70, 0.60, 0.48}, roofColor = {0.45, 0.35, 0.25},
   style = "castle", year = 1924, elevated = true},

  -- Demonstration Garden Pavilion
  {name = "Garden Pavilion", x = 18, y = 28, w = 5, h = 3, doorX = 20, doorY = 31, interior = "garden_pavilion",
   color = {0.78, 0.70, 0.55}, roofColor = {0.60, 0.45, 0.30},
   style = "ramada"},

  -- Herb Garden Greenhouse
  {name = "Greenhouse", x = 42, y = 25, w = 6, h = 4, doorX = 45, doorY = 29, interior = "greenhouse",
   color = {0.55, 0.70, 0.55}, roofColor = {0.50, 0.65, 0.50},
   style = "greenhouse"},

  -- Research Station (modern addition)
  {name = "Research Station", x = 55, y = 36, w = 6, h = 4, doorX = 58, doorY = 40, interior = "research_station",
   color = {0.60, 0.58, 0.55}, roofColor = {0.42, 0.40, 0.38},
   style = "modern"},

  -- Arid Lands Nursery
  {name = "Arid Nursery", x = 8, y = 25, w = 5, h = 3, doorX = 10, doorY = 28, interior = "arid_nursery",
   color = {0.72, 0.62, 0.48}, roofColor = {0.55, 0.42, 0.30},
   style = "adobe"},

  -- Suspension Bridge Gatehouse (Berber Bridge access)
  {name = "Bridge House", x = 32, y = 10, w = 4, h = 3, doorX = 34, doorY = 13, interior = "bridge_house",
   color = {0.58, 0.50, 0.40}, roofColor = {0.45, 0.38, 0.28},
   style = "stone"},
}

-- ═══════════════════════════════════════
-- NPCs (naturalists, rangers, visitors, researchers)
-- ═══════════════════════════════════════

M.npcs = {
  -- Visitor Center area
  {name = "Ranger Delgado", x = 34, y = 48, dialogue = "Welcome to Cereus — Arizona's oldest botanical sanctuary. Grab a trail map. The Main Loop is wheelchair-accessible and absolutely gorgeous.", gender = "female", design = 2},
  {name = "Gift Shop Clerk", x = 39, y = 48, dialogue = "We've got prickly pear jelly, desert wildflower honey, and hand-painted saguaro ornaments. Support conservation!", gender = "female", design = 5},

  -- Main Loop Trail
  {name = "Botanist Dr. Reyes", x = 25, y = 30, dialogue = "We maintain over 20,000 plants from 3,900 taxa here. This specimen is a Boojum tree — Fouquieria columnaris. Magnificent, isn't it?", gender = "male"},
  {name = "Trail Guide Maya", x = 40, y = 35, dialogue = "Stay on the marked trails, please! The desert looks barren but it's teeming with life. Watch your step for Gila monsters.", gender = "female", design = 3},

  -- Cactus Garden
  {name = "Cactus Expert Hal", x = 8, y = 28, dialogue = "This old-growth saguaro is over 200 years old. See the arms? Each one takes 75 years to grow. Patience personified.", gender = "male"},
  {name = "Desert Painter", x = 12, y = 22, dialogue = "I've painted these sunsets for twenty years and never captured the same sky twice. The Sonoran Desert is infinite art.", gender = "female", design = 1},

  -- Queen Creek Canyon
  {name = "Geologist Stone", x = 35, y = 8, dialogue = "Picketpost Mountain is a volcanic plug — the solidified magma core of an ancient eruption. 18 million years old.", gender = "male"},
  {name = "Birdwatcher Iris", x = 28, y = 6, dialogue = "Shh! Harris's hawk nesting in that ironwood. We've documented over 270 bird species in this canyon. Incredible diversity.", gender = "female", design = 6},

  -- Ayer Lake
  {name = "Fisherman Earl", x = 52, y = 8, dialogue = "Ayer Lake was built in 1929 to irrigate the gardens. Now it's a riparian oasis — great blue herons, javelinas at dawn.", gender = "male"},
  {name = "Photographer Luz", x = 56, y = 12, dialogue = "The reflections at golden hour are unreal. Picketpost Mountain mirrored in the lake... I've seen bobcats drinking at dusk.", gender = "female", design = 4},

  -- Wallace Desert Garden
  {name = "Dr. Wallace Jr.", x = 55, y = 25, dialogue = "My grandfather Herbert started collecting these Australian desert plants in the 1940s. Spinifex, mulga, bottle trees — all thriving.", gender = "male"},

  -- South American Exhibit
  {name = "Researcher Alma", x = 58, y = 38, dialogue = "These Puya raimondii from the Andes bloom once in 80 years then die. We may witness it any decade now.", gender = "female", design = 2},

  -- Eucalyptus Forest
  {name = "Arborist Chen", x = 10, y = 12, dialogue = "William Boyce Thompson planted these eucalyptus in 1925. The bark peels like parchment — Ghost Gum from Australia.", gender = "male"},

  -- Picket Post House
  {name = "Historian Grace", x = 8, y = 8, dialogue = "Picket Post House — Thompson's 'Castle on the Rock.' 7,000 square feet overlooking his life's work. He spent his mining fortune on conservation.", gender = "female", design = 3},

  -- Near Berber Bridge
  {name = "Engineer Navarro", x = 35, y = 12, dialogue = "The Berber Suspension Bridge spans 100 feet over Queen Creek Wash. Built in 2004 — finest view in the arboretum.", gender = "male"},

  -- Wildlife observers & new encounters
  {name = "Wildlife Biologist Rosa", x = 20, y = 32, dialogue = "Shh — see that troop of coatimundis? White-nosed, ringed tails held straight up. They forage together like a little army, flipping rocks with their long snouts.", gender = "female", design = 4},
  {name = "Butterfly Guide Kai", x = 42, y = 28, dialogue = "We've counted over 100 butterfly species here! Painted ladies in spring, monarchs in fall, and those bright sulfur butterflies year-round. Watch the penstemon beds.", gender = "male", design = 5},
  {name = "Young Naturalist Mia", x = 28, y = 20, dialogue = "I just saw a Costa's hummingbird! Did you know their wings beat 50 times per second? The gorget flashes purple like a tiny jewel.", gender = "female", design = 1},
  {name = "Volunteer Gardener Hank", x = 14, y = 42, dialogue = "The superbloom this year is magnificent. Gold poppies, lupine, globe mallow... when the desert decides to bloom, it goes ALL in.", gender = "male", design = 6},
}

-- ═══════════════════════════════════════
-- DECORATIONS (desert flora, geological features, infrastructure)
-- ═══════════════════════════════════════

M.decorations = {
  -- ═══ SAGUARO CACTI (Sonoran Desert icons) ═══
  {type = "saguaro", x = 5, y = 20, arms = 3, height = 4},
  {type = "saguaro", x = 10, y = 19, arms = 2, height = 3},
  {type = "saguaro", x = 14, y = 23, arms = 4, height = 5},
  {type = "saguaro", x = 3, y = 30, arms = 1, height = 3},
  {type = "saguaro", x = 12, y = 32, arms = 3, height = 4},
  {type = "saguaro", x = 7, y = 35, arms = 2, height = 3},
  -- Scattered along trails
  {type = "saguaro", x = 20, y = 20, arms = 2, height = 3},
  {type = "saguaro", x = 45, y = 22, arms = 3, height = 4},
  {type = "saguaro", x = 60, y = 28, arms = 1, height = 3},

  -- ═══ BARREL CACTI ═══
  {type = "barrel_cactus", x = 6, y = 22},
  {type = "barrel_cactus", x = 11, y = 26},
  {type = "barrel_cactus", x = 4, y = 28},
  {type = "barrel_cactus", x = 13, y = 30},
  {type = "barrel_cactus", x = 53, y = 22},
  {type = "barrel_cactus", x = 57, y = 27},

  -- ═══ PRICKLY PEAR CLUMPS ═══
  {type = "prickly_pear", x = 8, y = 24, w = 2, h = 1},
  {type = "prickly_pear", x = 3, y = 33, w = 1, h = 1},
  {type = "prickly_pear", x = 15, y = 29, w = 2, h = 1},
  {type = "prickly_pear", x = 52, y = 30, w = 2, h = 1},

  -- ═══ OCOTILLO ═══
  {type = "ocotillo", x = 9, y = 21},
  {type = "ocotillo", x = 14, y = 27},
  {type = "ocotillo", x = 55, y = 20},
  {type = "ocotillo", x = 62, y = 30},

  -- ═══ IRONWOOD / PALO VERDE TREES ═══
  {type = "desert_tree", x = 25, y = 18, variety = "palo_verde"},
  {type = "desert_tree", x = 30, y = 16, variety = "ironwood"},
  {type = "desert_tree", x = 38, y = 19, variety = "palo_verde"},
  {type = "desert_tree", x = 42, y = 17, variety = "ironwood"},
  {type = "desert_tree", x = 50, y = 15, variety = "palo_verde"},
  {type = "desert_tree", x = 28, y = 38, variety = "mesquite"},
  {type = "desert_tree", x = 35, y = 42, variety = "mesquite"},

  -- ═══ EUCALYPTUS TREES (forest grove) ═══
  {type = "eucalyptus", x = 4, y = 7},
  {type = "eucalyptus", x = 7, y = 6},
  {type = "eucalyptus", x = 10, y = 8},
  {type = "eucalyptus", x = 13, y = 7},
  {type = "eucalyptus", x = 16, y = 9},
  {type = "eucalyptus", x = 5, y = 11},
  {type = "eucalyptus", x = 9, y = 13},
  {type = "eucalyptus", x = 14, y = 12},
  {type = "eucalyptus", x = 17, y = 14},
  {type = "eucalyptus", x = 3, y = 15},

  -- ═══ BOOJUM TREES (bizarre Baja California species) ═══
  {type = "boojum", x = 53, y = 36},
  {type = "boojum", x = 57, y = 39},
  {type = "boojum", x = 61, y = 37},

  -- ═══ LARGE FANCY TREES (colorful arboretum specimens) ═══
  {type = "fancy_tree", x = 22, y = 12, species = "red_maple"},
  {type = "fancy_tree", x = 34, y = 10, species = "golden_ash"},
  {type = "fancy_tree", x = 45, y = 13, species = "jacaranda"},
  {type = "fancy_tree", x = 15, y = 20, species = "copper_beech"},
  {type = "fancy_tree", x = 55, y = 18, species = "silver_birch"},
  {type = "fancy_tree", x = 28, y = 25, species = "desert_willow"},
  {type = "fancy_tree", x = 40, y = 30, species = "red_maple"},
  {type = "fancy_tree", x = 18, y = 35, species = "jacaranda"},
  {type = "fancy_tree", x = 48, y = 28, species = "golden_ash"},
  {type = "fancy_tree", x = 60, y = 25, species = "copper_beech"},
  {type = "fancy_tree", x = 32, y = 38, species = "silver_birch"},
  {type = "fancy_tree", x = 8, y = 30, species = "desert_willow"},
  {type = "fancy_tree", x = 52, y = 42, species = "jacaranda"},
  {type = "fancy_tree", x = 26, y = 46, species = "golden_ash"},
  {type = "fancy_tree", x = 42, y = 22, species = "red_maple"},

  -- ═══ AGAVE / YUCCA ═══
  {type = "agave", x = 6, y = 26},
  {type = "agave", x = 11, y = 34},
  {type = "agave", x = 56, y = 24},
  {type = "agave", x = 59, y = 35},
  {type = "yucca", x = 22, y = 42},
  {type = "yucca", x = 47, y = 40},

  -- ═══ ROCKS & BOULDERS ═══
  {type = "boulder", x = 24, y = 5, size = "large"},
  {type = "boulder", x = 30, y = 4, size = "medium"},
  {type = "boulder", x = 40, y = 3, size = "large"},
  {type = "boulder", x = 18, y = 16, size = "small"},
  {type = "boulder", x = 44, y = 14, size = "medium"},

  -- ═══ BENCHES along trails ═══
  {type = "bench", x = 22, y = 25},
  {type = "bench", x = 35, y = 32},
  {type = "bench", x = 48, y = 28},
  {type = "bench", x = 15, y = 40},
  {type = "bench", x = 55, y = 10},

  -- ═══ TRAIL SIGNS ═══
  {type = "trail_sign", x = 20, y = 44, text = "Main Loop →"},
  {type = "trail_sign", x = 16, y = 18, text = "← Cactus Garden"},
  {type = "trail_sign", x = 48, y = 18, text = "Wallace Garden →"},
  {type = "trail_sign", x = 25, y = 14, text = "Queen Creek ↑"},
  {type = "trail_sign", x = 50, y = 6, text = "Ayer Lake →"},

  -- ═══ BERBER SUSPENSION BRIDGE ═══
  {type = "suspension_bridge", x = 30, y = 7, w = 8, h = 1},

  -- ═══ WATER FEATURES ═══
  -- Queen Creek Wash (seasonal stream through canyon)
  {type = "creek", x = 24, y = 4, x2 = 46, y2 = 4, seasonal = true},
  -- Ayer Lake shore decorations
  {type = "cattails", x = 49, y = 5},
  {type = "cattails", x = 51, y = 3},
  {type = "cattails", x = 55, y = 4},
  {type = "cattails", x = 60, y = 6},

  -- ═══ LAMP POSTS (along main trails) ═══
  {type = "lamp", x = 30, y = 43},
  {type = "lamp", x = 22, y = 36},
  {type = "lamp", x = 45, y = 36},
  {type = "lamp", x = 16, y = 25},
  {type = "lamp", x = 50, y = 25},

  -- ═══ SHADE RAMADAS (open-sided rest shelters with benches) ═══
  {type = "ramada", x = 24, y = 30},   -- Main Loop west rest area
  {type = "ramada", x = 44, y = 24},   -- Near Greenhouse overlook
  {type = "ramada", x = 12, y = 38},   -- Cactus Garden viewpoint
  {type = "ramada", x = 56, y = 8},    -- Ayer Lake shore picnic

  -- ═══ DRINKING FOUNTAINS (trail amenities) ═══
  {type = "fountain", x = 30, y = 42},  -- Near Visitor Center
  {type = "fountain", x = 20, y = 22},  -- Main Loop north
  {type = "fountain", x = 48, y = 22},  -- Near Wallace Garden
  {type = "fountain", x = 40, y = 12},  -- Queen Creek overlook

  -- ═══ INTERPRETIVE SIGNS (educational markers) ═══
  {type = "interp_sign", x = 6, y = 20, text = "Saguaro"},
  {type = "interp_sign", x = 54, y = 22, text = "Spinifex"},
  {type = "interp_sign", x = 34, y = 6, text = "Geology"},
  {type = "interp_sign", x = 50, y = 5, text = "Riparian"},
  {type = "interp_sign", x = 10, y = 10, text = "Eucalyptus"},
  {type = "interp_sign", x = 56, y = 36, text = "Puya"},

  -- ═══ FLOWER BEDS (cultivated display patches along paths) ═══
  {type = "flower_bed", x = 26, y = 44, species = "poppy"},
  {type = "flower_bed", x = 38, y = 44, species = "poppy"},
  {type = "flower_bed", x = 19, y = 30, species = "penstemon"},
  {type = "flower_bed", x = 46, y = 30, species = "globe_mallow"},
  {type = "flower_bed", x = 30, y = 18, species = "lupine"},
  {type = "flower_bed", x = 42, y = 18, species = "brittlebush"},

  -- ═══ STEPPING STONES (decorative path crossings) ═══
  {type = "stepping_stones", x = 22, y = 18, direction = "vertical"},
  {type = "stepping_stones", x = 48, y = 18, direction = "vertical"},
  {type = "stepping_stones", x = 28, y = 36, direction = "horizontal"},
  {type = "stepping_stones", x = 42, y = 36, direction = "horizontal"},
}

-- Spawn point (Visitor Center entrance)
M.spawnPoint = {x = 35, y = 50}

-- ═══════════════════════════════════════
-- TRAIL PATHS (walkable packed-earth corridors)
-- These define the ~5 miles of trails through the arboretum
-- ═══════════════════════════════════════

M.trails = {
  -- Main Loop (1.5-mile wheelchair-accessible loop)
  {name = "Main Loop", segments = {
    {x1 = 28, y1 = 44, x2 = 42, y2 = 50},   -- Visitor Center plaza
    {x1 = 18, y1 = 36, x2 = 28, y2 = 44},   -- West main loop
    {x1 = 18, y1 = 18, x2 = 22, y2 = 36},   -- North west leg
    {x1 = 22, y1 = 15, x2 = 48, y2 = 18},   -- Northern stretch
    {x1 = 48, y1 = 18, x2 = 52, y2 = 36},   -- North east leg
    {x1 = 42, y1 = 36, x2 = 52, y2 = 44},   -- East main loop
  }},
  -- Queen Creek Trail (canyon exploration)
  {name = "Queen Creek Trail", segments = {
    {x1 = 22, y1 = 4, x2 = 48, y2 = 15},
  }},
  -- Ayer Lake Trail (lakeside path)
  {name = "Ayer Lake Trail", segments = {
    {x1 = 48, y1 = 4, x2 = 62, y2 = 16},
  }},
  -- Cactus Garden paths
  {name = "Cactus Trail", segments = {
    {x1 = 2, y1 = 18, x2 = 18, y2 = 36},
  }},
  -- Wallace Garden paths
  {name = "Wallace Trail", segments = {
    {x1 = 50, y1 = 18, x2 = 64, y2 = 32},
  }},
  -- South American paths
  {name = "South American Trail", segments = {
    {x1 = 50, y1 = 33, x2 = 64, y2 = 44},
  }},
  -- Eucalyptus Forest paths
  {name = "Eucalyptus Trail", segments = {
    {x1 = 2, y1 = 5, x2 = 18, y2 = 18},
  }},
  -- Connector to Picket Post House
  {name = "Summit Trail", segments = {
    {x1 = 4, y1 = 4, x2 = 14, y2 = 10},
  }},
}

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

-- Check if position is on a mountain (impassable)
function M.isMountain(gridX, gridY)
  for _, mtn in ipairs(M.mountains) do
    if gridX >= mtn.x1 and gridX <= mtn.x2 and gridY >= mtn.y1 and gridY <= mtn.y2 then
      return true, mtn
    end
  end
  return false, nil
end

-- Check if position is in Ayer Lake (water)
function M.isLake(gridX, gridY)
  local zone = M.zones.ayer_lake
  if gridX >= zone.x1 + 1 and gridX <= zone.x2 - 1 and
     gridY >= zone.y1 + 1 and gridY <= zone.y2 - 1 then
    return true
  end
  return false
end

-- Create collision map for the arboretum
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

  -- Mountains are solid
  for _, mtn in ipairs(M.mountains) do
    for my = mtn.y1, mtn.y2 do
      for mx = mtn.x1, mtn.x2 do
        if map[my] and map[my][mx] ~= nil then
          map[my][mx] = true
        end
      end
    end
  end

  -- Ayer Lake core is not walkable (shore is)
  local lake = M.zones.ayer_lake
  for ly = lake.y1 + 1, lake.y2 - 1 do
    for lx = lake.x1 + 1, lake.x2 - 1 do
      if map[ly] and map[ly][lx] ~= nil then
        map[ly][lx] = true
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
    -- Tile in front of door
    if map[b.doorY - 1] then
      map[b.doorY - 1][b.doorX] = false
    end
  end

  -- Decorations with collision (large plants, boulders)
  for _, deco in ipairs(M.decorations) do
    if deco.type == "saguaro" or deco.type == "boulder" or deco.type == "eucalyptus"
       or deco.type == "boojum" or deco.type == "lamp" or deco.type == "fancy_tree" then
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

  -- Trail paths are always walkable (override any accidental blocks)
  for _, trail in ipairs(M.trails) do
    for _, seg in ipairs(trail.segments) do
      for ty = seg.y1, seg.y2 do
        for tx = seg.x1, seg.x2 do
          if map[ty] and map[ty][tx] ~= nil then
            -- Don't override buildings or mountains
            local isMtn = false
            for _, mtn in ipairs(M.mountains) do
              if tx >= mtn.x1 and tx <= mtn.x2 and ty >= mtn.y1 and ty <= mtn.y2 then
                isMtn = true
                break
              end
            end
            local isBldg = false
            for _, b in ipairs(M.buildings) do
              if tx >= b.x and tx < b.x + b.w and ty >= b.y and ty < b.y + b.h then
                isBldg = true
                break
              end
            end
            if not isMtn and not isBldg then
              map[ty][tx] = false
            end
          end
        end
      end
    end
  end

  return map
end

return M
