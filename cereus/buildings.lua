-- cereus/buildings.lua
-- Interior layouts for buildings in Cereus desert hub (Boyce Thompson Arboretum)
-- Historic stone buildings, research facilities, and garden structures

local M = {}

M.GRID_SIZE = 32

M.interiors = {
  -- ═══════════════════════════════════════
  -- SMITH BUILDING (1925 — original HQ, locally quarried rock)
  -- Lichen-covered interior walls, flagstone floors
  -- ═══════════════════════════════════════
  smith_building = {
    name = "Smith Building (est. 1925)",
    width = 16, height = 12,
    exitX = 8, exitY = 11,
    portals = {
      {name = "Archive", x = 4, y = 3, game = "lookout", color = {0.6, 0.5, 0.3}},
      {name = "Herbarium", x = 12, y = 3, game = "planetmap", color = {0.3, 0.6, 0.3}},
    },
    npcs = {
      {name = "Curator Thompson", x = 8, y = 5, dialogue = "This building was constructed from locally quarried volcanic rock in 1925. Notice the lichen patterns on the interior walls — we've preserved them exactly as they were.", gender = "male"},
      {name = "Archivist Pen", x = 13, y = 7, dialogue = "Our herbarium contains pressed specimens dating back to the founding. Over 40,000 sheets cataloguing desert flora worldwide.", gender = "female", design = 4},
    },
    features = {"flagstone_floor", "lichen_walls", "specimen_cabinets", "historical_photos"}
  },

  -- ═══════════════════════════════════════
  -- VISITOR CENTER / GIFT SHOP
  -- ═══════════════════════════════════════
  visitor_center = {
    name = "Cereus Visitor Center",
    width = 12, height = 10,
    exitX = 6, exitY = 9,
    portals = {
      {name = "Shop", x = 3, y = 3, game = "shop", color = {0.8, 0.6, 0.3}},
    },
    npcs = {
      {name = "Welcome Guide", x = 5, y = 4, dialogue = "Welcome to Cereus! We have nearly 5 miles of trails through 392 acres of desert habitat. The Main Loop is our most popular — 1.5 miles, fully accessible.", gender = "female", design = 5},
      {name = "Gift Shop Amy", x = 9, y = 5, dialogue = "Prickly pear candy, desert sage candles, cactus-print scarves... everything a desert explorer needs! Proceeds support plant conservation.", gender = "female", design = 3},
    }
  },

  -- ═══════════════════════════════════════
  -- PICKET POST HOUSE (Founder's 7,000 sq ft mansion)
  -- "Castle on the Rock" overlooking the arboretum
  -- ═══════════════════════════════════════
  picketpost_house = {
    name = "Picket Post House — Thompson Estate",
    width = 20, height = 14,
    exitX = 10, exitY = 13,
    portals = {
      {name = "Observatory", x = 16, y = 3, game = "lookout", color = {0.2, 0.3, 0.6}},
    },
    npcs = {
      {name = "Caretaker Ortiz", x = 8, y = 5, dialogue = "William Boyce Thompson built this house in 1924. Mining magnate turned conservationist. He spent his fortune saving plants from extinction.", gender = "male"},
      {name = "Estate Docent", x = 14, y = 8, dialogue = "From this balcony, Thompson could survey the entire arboretum. On clear days, you can see the Superstition Mountains. The fireplace is original Arizona sandstone.", gender = "female", design = 1},
      {name = "Ghost of W.B. Thompson", x = 4, y = 4, dialogue = "A man's true wealth is measured by what he preserves for future generations, not what he digs from the earth...", gender = "male"},
    },
    features = {"grand_fireplace", "trophy_room", "library", "mountain_view_balcony", "original_furnishings"}
  },

  -- ═══════════════════════════════════════
  -- GARDEN PAVILION (demonstration garden ramada)
  -- ═══════════════════════════════════════
  garden_pavilion = {
    name = "Demonstration Garden Pavilion",
    width = 12, height = 8,
    exitX = 6, exitY = 7,
    npcs = {
      {name = "Master Gardener Rosa", x = 5, y = 3, dialogue = "This is our xeriscape demonstration area. Every plant here survives on rainfall alone — no irrigation. Desert gardening at its finest.", gender = "female", design = 6},
      {name = "Volunteer Don", x = 9, y = 4, dialogue = "We host workshops every Saturday — propagation, grafting, desert food forests. The prickly pear fruit is delicious once you know how to harvest it!", gender = "male"},
    }
  },

  -- ═══════════════════════════════════════
  -- GREENHOUSE (herb garden and propagation)
  -- ═══════════════════════════════════════
  greenhouse = {
    name = "Arid Lands Greenhouse",
    width = 14, height = 10,
    exitX = 7, exitY = 9,
    portals = {
      {name = "Seed Bank", x = 7, y = 2, game = "science_lab", color = {0.4, 0.7, 0.4}},
    },
    npcs = {
      {name = "Propagator Kim", x = 4, y = 4, dialogue = "We grow rare cacti from seed here. Some of these species are extinct in the wild — our greenhouse is their last refuge.", gender = "female", design = 2},
      {name = "Intern Diego", x = 10, y = 6, dialogue = "I'm grafting moon cactus onto dragon fruit rootstock. Desert horticulture is basically plant surgery. So cool.", gender = "male"},
    },
    features = {"grow_lights", "misting_system", "rare_specimens", "seed_storage"}
  },

  -- ═══════════════════════════════════════
  -- RESEARCH STATION (modern conservation facility)
  -- ═══════════════════════════════════════
  research_station = {
    name = "Desert Conservation Research Station",
    width = 14, height = 10,
    exitX = 7, exitY = 9,
    portals = {
      {name = "Lab", x = 3, y = 3, game = "science_lab", color = {0.3, 0.6, 0.8}},
      {name = "Data Center", x = 11, y = 3, game = "lookout", color = {0.5, 0.5, 0.7}},
    },
    npcs = {
      {name = "Dr. Oasis", x = 7, y = 5, dialogue = "We're studying how saguaros survive climate change. Their internal water storage is extraordinary — natural engineering millions of years in the making.", gender = "female", design = 4},
      {name = "Tech Specialist Kai", x = 11, y = 7, dialogue = "Our sensor network monitors soil moisture, air temperature, and pollinator activity across all 392 acres. Real-time desert intelligence.", gender = "male"},
    },
    features = {"microscopes", "climate_monitors", "specimen_cases", "digital_herbarium"}
  },

  -- ═══════════════════════════════════════
  -- ARID NURSERY
  -- ═══════════════════════════════════════
  arid_nursery = {
    name = "Arid Lands Nursery",
    width = 12, height = 8,
    exitX = 6, exitY = 7,
    portals = {
      {name = "Plant Sale", x = 6, y = 2, game = "shop", color = {0.5, 0.7, 0.3}},
    },
    npcs = {
      {name = "Nursery Manager", x = 4, y = 4, dialogue = "Take home a piece of the desert! We have saguaro seedlings, barrel cacti, and desert wildflower seed mixes. All ethically sourced.", gender = "female", design = 5},
    }
  },

  -- ═══════════════════════════════════════
  -- BRIDGE HOUSE (Berber Suspension Bridge access)
  -- ═══════════════════════════════════════
  bridge_house = {
    name = "Berber Bridge Gatehouse",
    width = 10, height = 8,
    exitX = 5, exitY = 7,
    npcs = {
      {name = "Bridge Keeper Sol", x = 5, y = 3, dialogue = "The Berber Suspension Bridge was built in 2004 — 100 feet spanning Queen Creek Wash. Best view of the canyon. Watch your step, it sways!", gender = "male"},
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
        else
          map[y][x] = false
        end
      else
        map[y][x] = false
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
