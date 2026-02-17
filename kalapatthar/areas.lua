-- kalapatthar/areas.lua
-- Kala Patthar — A Nepali mountain village in Deep Space
-- Stone lodges with coloured roofs, terraced paths, prayer flags,
-- suspension bridges spanning gorges between building clusters,
-- views of distant glaciers and Himalayan giants under eternal starlight.

local M = {}

M.GRID_SIZE = 32
M.WORLD_WIDTH = 50
M.WORLD_HEIGHT = 40

M.COLORS = {
  stone = {0.45, 0.40, 0.35},
  darkStone = {0.30, 0.27, 0.23},
  lightStone = {0.58, 0.53, 0.46},
  earth = {0.40, 0.32, 0.22},
  mud = {0.48, 0.38, 0.26},
  slate = {0.38, 0.36, 0.34},
  darkWood = {0.35, 0.22, 0.12},
  wood = {0.50, 0.35, 0.20},
  lightWood = {0.62, 0.48, 0.30},
  bamboo = {0.55, 0.52, 0.30},
  roofRed = {0.72, 0.18, 0.12},
  roofBlue = {0.15, 0.32, 0.65},
  roofGreen = {0.12, 0.50, 0.22},
  roofYellow = {0.80, 0.68, 0.15},
  roofRust = {0.60, 0.30, 0.15},
  flagBlue = {0.15, 0.30, 0.75},
  flagWhite = {0.92, 0.90, 0.88},
  flagRed = {0.78, 0.15, 0.12},
  flagGreen = {0.12, 0.55, 0.25},
  flagYellow = {0.90, 0.78, 0.15},
  snow = {0.92, 0.94, 0.97},
  ice = {0.70, 0.85, 0.95},
  glacier = {0.60, 0.78, 0.90},
  deepSpace = {0.04, 0.04, 0.12},
  twilight = {0.12, 0.08, 0.20},
  gold = {0.90, 0.75, 0.20},
  brass = {0.72, 0.58, 0.20},
  stupa = {0.88, 0.82, 0.68},
  water = {0.20, 0.45, 0.65},
  rope = {0.55, 0.42, 0.25},
}

M.FLAG_COLORS = {
  M.COLORS.flagBlue, M.COLORS.flagWhite, M.COLORS.flagRed,
  M.COLORS.flagGreen, M.COLORS.flagYellow,
}

M.zones = {
  {id = "village_center", name = "Village Center", x1 = 16, y1 = 15, x2 = 34, y2 = 27,
   description = "The heart of the village. Stone lodges cluster around a central stupa."},
  {id = "west_ridge", name = "West Ridge", x1 = 5, y1 = 10, x2 = 15, y2 = 22,
   description = "A ridge of prayer walls and the memorial shrine."},
  {id = "east_terrace", name = "East Terrace", x1 = 35, y1 = 12, x2 = 47, y2 = 24,
   description = "Terraced lookout with the observatory. Glaciers visible below."},
  {id = "upper_village", name = "Upper Village", x1 = 18, y1 = 5, x2 = 32, y2 = 14,
   description = "Higher lodges along the trail to the summit."},
  {id = "meditation_glade", name = "Meditation Glade", x1 = 20, y1 = 28, x2 = 32, y2 = 37,
   description = "A sheltered clearing where the Sage's stone shelter stands."},
  {id = "south_gorge", name = "South Gorge", x1 = 5, y1 = 25, x2 = 15, y2 = 37,
   description = "A deep gorge with a bridge to the meditation glade."},
  {id = "north_pass", name = "North Pass", x1 = 8, y1 = 3, x2 = 42, y2 = 7,
   description = "The pass above the village. Wind howls through the col."},
}

M.buildings = {
  {id = "expedition_hq", name = "Expedition HQ", x = 20, y = 18, width = 5, height = 4,
   doorX = 22, doorY = 22, interior = "expedition_hq",
   style = "lodge", color = M.COLORS.stone, roofColor = M.COLORS.roofRed,
   windowColor = {0.90, 0.70, 0.30}, stories = 2},
  {id = "storyteller_tent", name = "Storyteller's Lodge", x = 27, y = 17, width = 4, height = 3,
   doorX = 29, doorY = 20, interior = "storyteller_tent",
   style = "lodge", color = M.COLORS.lightStone, roofColor = M.COLORS.roofBlue,
   windowColor = {0.85, 0.75, 0.40}, stories = 1},
  {id = "climber_lodge", name = "Climber's Lodge", x = 16, y = 21, width = 4, height = 3,
   doorX = 18, doorY = 24, interior = "climber_lodge",
   style = "lodge", color = M.COLORS.darkStone, roofColor = M.COLORS.roofGreen,
   windowColor = {0.80, 0.65, 0.30}, stories = 2},
  {id = "tea_house", name = "Tea House", x = 31, y = 20, width = 4, height = 3,
   doorX = 33, doorY = 23, interior = "tea_house",
   style = "lodge", color = M.COLORS.stone, roofColor = M.COLORS.roofYellow,
   windowColor = {0.95, 0.80, 0.35}, stories = 1},
  {id = "sage_shelter", name = "Sage's Shelter", x = 24, y = 31, width = 5, height = 4,
   doorX = 26, doorY = 35, interior = "sage_shelter",
   style = "temple", color = M.COLORS.stupa, roofColor = M.COLORS.gold,
   windowColor = {1.0, 0.90, 0.50}, stories = 1},
  {id = "shrine", name = "Memorial Shrine", x = 8, y = 14, width = 3, height = 3,
   doorX = 9, doorY = 17, interior = "shrine",
   style = "temple", color = M.COLORS.stupa, roofColor = M.COLORS.gold,
   windowColor = {1.0, 0.85, 0.40}, stories = 1},
  {id = "observatory", name = "Star Observatory", x = 40, y = 16, width = 4, height = 3,
   doorX = 42, doorY = 19, interior = "observatory",
   style = "dome", color = {0.35, 0.38, 0.45}, roofColor = {0.50, 0.55, 0.60},
   windowColor = {0.60, 0.75, 1.0}, stories = 1},
  {id = "supply_depot", name = "Supply Depot", x = 22, y = 8, width = 4, height = 3,
   doorX = 24, doorY = 11, interior = "supply_depot",
   style = "lodge", color = M.COLORS.darkStone, roofColor = M.COLORS.roofRust,
   windowColor = {0.85, 0.65, 0.30}, stories = 1},
}

M.bridges = {
  {id = "west_bridge", name = "West Bridge",
   x1 = 14, y1 = 18, x2 = 17, y2 = 18, width = 2, depth = 5,
   description = "A swaying rope bridge over the western gorge."},
  {id = "east_bridge", name = "East Bridge",
   x1 = 34, y1 = 19, x2 = 38, y2 = 19, width = 2, depth = 7,
   description = "A long bridge with glacier views below."},
  {id = "south_bridge", name = "South Bridge",
   x1 = 25, y1 = 27, x2 = 25, y2 = 30, width = 2, depth = 4,
   description = "A short bridge over a rocky ravine."},
  {id = "upper_bridge", name = "Upper Bridge",
   x1 = 24, y1 = 13, x2 = 24, y2 = 16, width = 2, depth = 3,
   description = "Wooden steps and rope rails on a steep descent."},
  {id = "gorge_bridge", name = "Gorge Bridge",
   x1 = 10, y1 = 22, x2 = 10, y2 = 26, width = 2, depth = 8,
   description = "The longest bridge in the village. Don't look down."},
}

M.npcs = {
  {name = "Tenzing", x = 23, y = 20, gender = "male",
   dialogue = "Welcome to Kala Patthar, the highest outpost in Deep Space. We keep watch over the galaxy's legends from here. Have you heard of the four Muses?"},
  {name = "Pemba", x = 25, y = 25, gender = "female",
   dialogue = "The four Muses once played together \xe2\x80\x94 Melo, Djolt, Tierra, and Clarity. Their instruments held the power of the cosmos itself. But they were scattered across the galaxy."},
  {name = "Dorje", x = 19, y = 19, gender = "male",
   dialogue = "They say Melo lives on Mixia now, in the lower quarters. He waits endlessly for his Perfect Piano \xe2\x80\x94 a red electric piano, like a Nord. Beautiful tone, warm as sunset. Someone told me it's locked away in the Temple of Peril."},
  {name = "Lakpa", x = 30, y = 22, gender = "female",
   dialogue = "Djolt is wired up at The Singularity, spinning invisible records on invisible decks. He's waiting for the Decks of Destiny \xe2\x80\x94 a turntable like a Pioneer DJ vinyl deck. It's supposedly inside a dungeon deep within the black hole at Singularity."},
  {name = "Mingma", x = 21, y = 24, gender = "male",
   dialogue = "Tierra... she lives in Leucadia, near the beach. She's missing her Gravitron Guitar \xe2\x80\x94 a beautiful acoustic, like a Martin dreadnought. Word is, someone brought it to the Greenhouse on Cereus."},
  {name = "Dawa", x = 32, y = 21, gender = "female",
   dialogue = "Clarity has the purest voice in the galaxy. She settled in Cereus, among the desert flowers. But her Mystic Microphone \xe2\x80\x94 a classic Shure SM58 \xe2\x80\x94 is on loan to the Studio at Hometown Station."},
  {name = "Karma", x = 10, y = 16, gender = "male",
   dialogue = "Each cairn here represents a pilot who sought the Muses' blessing. If you bring each Muse their instrument, they grant you a power beyond technology. The Sage can tell you more."},
  {name = "Nima", x = 7, y = 19, gender = "female",
   dialogue = "Melo's power is over time itself. When he plays the Perfect Piano, everything slows \xe2\x80\x94 except you. Thirty seconds before the melody fades."},
  {name = "Ang Tshering", x = 42, y = 20, gender = "male",
   dialogue = "Djolt's power is lightning. The Decks of Destiny channel chain lightning through your weapons for fifteen seconds. Every shot arcs to nearby enemies."},
  {name = "Phurba", x = 38, y = 17, gender = "female",
   dialogue = "From this terrace you can see the whole glacier field. On a clear night, you can see all the way to the named constellations."},
  {name = "Pasang", x = 23, y = 33, gender = "male",
   dialogue = "Tierra's power reshapes the battlefield. With the Gravitron Guitar, the edges of space bend \xe2\x80\x94 you can fly off one side of the screen and appear on the other."},
  {name = "Yangzom", x = 28, y = 34, gender = "female",
   dialogue = "Clarity's power is vision. The Mystic Microphone cuts through any fog, mist, or darkness for the rest of the stage. Nothing can hide from her voice."},
  {name = "Tashi", x = 26, y = 10, gender = "male",
   dialogue = "The summit trail leads further up the mountain, but the peak is closed for now. The Sage says the path will open when all four Muses have been reunited with their instruments."},
  {name = "Rinzin", x = 8, y = 28, gender = "male",
   dialogue = "This gorge goes deep. In the starlight you can see ice formations hundreds of meters below. The bridges here have held for generations \xe2\x80\x94 the Sherpas built them to last."},
}

M.decorations = {
  {type = "prayer_flags", x1 = 18, y1 = 17, x2 = 26, y2 = 17},
  {type = "prayer_flags", x1 = 28, y1 = 16, x2 = 33, y2 = 16},
  {type = "prayer_flags", x1 = 7, y1 = 12, x2 = 13, y2 = 12},
  {type = "prayer_flags", x1 = 22, y1 = 30, x2 = 29, y2 = 30},
  {type = "prayer_flags", x1 = 37, y1 = 14, x2 = 44, y2 = 14},
  {type = "prayer_flags", x1 = 20, y1 = 7, x2 = 28, y2 = 7},
  {type = "prayer_flags", x1 = 16, y1 = 23, x2 = 20, y2 = 23},
  {type = "prayer_flags", x1 = 31, y1 = 23, x2 = 34, y2 = 23},
  {type = "cairn", x = 9, y = 15},
  {type = "cairn", x = 11, y = 18},
  {type = "cairn", x = 25, y = 32},
  {type = "cairn", x = 38, y = 21},
  {type = "cairn", x = 23, y = 12},
  {type = "mani_wall", x1 = 6, y1 = 13, x2 = 12, y2 = 13},
  {type = "mani_wall", x1 = 22, y1 = 29, x2 = 28, y2 = 29},
  {type = "stupa", x = 25, y = 19},
  {type = "stupa", x = 9, y = 12},
  {type = "campfire", x = 24, y = 23},
  {type = "campfire", x = 27, y = 33},
  {type = "campfire", x = 39, y = 20},
  {type = "yak", x = 12, y = 20},
  {type = "yak", x = 36, y = 22},
  {type = "yak", x = 28, y = 26},
  {type = "frozen_stream", x1 = 14, y1 = 24, x2 = 14, y2 = 28},
  {type = "frozen_stream", x1 = 36, y1 = 15, x2 = 36, y2 = 21},
  {type = "boulder", x = 4, y = 14},
  {type = "boulder", x = 46, y = 18},
  {type = "boulder", x = 3, y = 30},
  {type = "boulder", x = 47, y = 25},
  {type = "boulder", x = 15, y = 6},
  {type = "boulder", x = 35, y = 6},
  {type = "bench", x = 25, y = 23},
  {type = "bench", x = 28, y = 33},
  {type = "supply_crate", x = 21, y = 22},
  {type = "supply_crate", x = 34, y = 22},
  {type = "firewood", x = 17, y = 20},
  {type = "firewood", x = 30, y = 19},
  {type = "firewood", x = 23, y = 9},
  {type = "bell", x = 24, y = 31},
  {type = "bell", x = 26, y = 31},
}

M.trails = {
  {name = "Village Road", segments = {
    {x1 = 17, y1 = 22, x2 = 34, y2 = 22},
    {x1 = 22, y1 = 17, x2 = 22, y2 = 26},
    {x1 = 29, y1 = 17, x2 = 29, y2 = 24},
  }},
  {name = "West Path", segments = {
    {x1 = 9, y1 = 13, x2 = 9, y2 = 21},
    {x1 = 9, y1 = 18, x2 = 14, y2 = 18},
  }},
  {name = "East Path", segments = {
    {x1 = 38, y1 = 19, x2 = 42, y2 = 19},
    {x1 = 42, y1 = 16, x2 = 42, y2 = 22},
  }},
  {name = "Upper Path", segments = {
    {x1 = 24, y1 = 8, x2 = 24, y2 = 13},
    {x1 = 21, y1 = 10, x2 = 27, y2 = 10},
  }},
  {name = "Meditation Path", segments = {
    {x1 = 25, y1 = 30, x2 = 25, y2 = 35},
    {x1 = 23, y1 = 33, x2 = 29, y2 = 33},
  }},
  {name = "Gorge Path", segments = {
    {x1 = 10, y1 = 22, x2 = 10, y2 = 29},
    {x1 = 8, y1 = 28, x2 = 12, y2 = 28},
  }},
  {name = "West Bridge", segments = {
    {x1 = 14, y1 = 18, x2 = 17, y2 = 18},
    {x1 = 14, y1 = 19, x2 = 17, y2 = 19},
  }},
  {name = "East Bridge", segments = {
    {x1 = 34, y1 = 19, x2 = 38, y2 = 19},
    {x1 = 34, y1 = 20, x2 = 38, y2 = 20},
  }},
  {name = "South Bridge", segments = {
    {x1 = 25, y1 = 27, x2 = 25, y2 = 30},
    {x1 = 26, y1 = 27, x2 = 26, y2 = 30},
  }},
  {name = "Upper Bridge", segments = {
    {x1 = 24, y1 = 13, x2 = 24, y2 = 16},
    {x1 = 25, y1 = 13, x2 = 25, y2 = 16},
  }},
  {name = "Gorge Bridge", segments = {
    {x1 = 10, y1 = 22, x2 = 10, y2 = 26},
    {x1 = 11, y1 = 22, x2 = 11, y2 = 26},
  }},
}

M.mountains = {
  {name = "North Wall", x1 = 0, y1 = 0, x2 = 49, y2 = 3},
  {name = "West Cliff", x1 = 0, y1 = 0, x2 = 3, y2 = 39},
  {name = "East Cliff", x1 = 47, y1 = 0, x2 = 49, y2 = 39},
  {name = "South Wall", x1 = 0, y1 = 38, x2 = 49, y2 = 39},
}

M.gorges = {
  {id = "west_gorge", x1 = 14, y1 = 14, x2 = 16, y2 = 22, depth = 200},
  {id = "east_gorge", x1 = 35, y1 = 15, x2 = 37, y2 = 23, depth = 300},
  {id = "south_ravine", x1 = 23, y1 = 27, x2 = 27, y2 = 30, depth = 150},
  {id = "main_gorge", x1 = 9, y1 = 22, x2 = 12, y2 = 26, depth = 400},
}

M.spawnX = 25
M.spawnY = 22

local stars = {}

function M.initStars()
  stars = {}
  for i = 1, 400 do
    table.insert(stars, {
      x = math.random(0, 1400),
      y = math.random(0, 800),
      size = math.random() * 2 + 0.3,
      brightness = math.random() * 0.5 + 0.5,
      twinklePhase = math.random() * math.pi * 2,
      color = math.random() < 0.15 and "warm" or "cool",
    })
  end
end

function M.getStars() return stars end

local snowParticles = {}

function M.initSnow()
  snowParticles = {}
  for i = 1, 250 do
    table.insert(snowParticles, {
      x = math.random(0, 1400),
      y = math.random(0, 800),
      size = math.random() * 2.5 + 0.5,
      speed = math.random() * 25 + 8,
      drift = (math.random() - 0.5) * 8,
      layer = math.random(1, 3),
      opacity = math.random() * 0.4 + 0.2,
      wobble = math.random() * math.pi * 2,
    })
  end
end

function M.getSnow() return snowParticles end

function M.getZoneAt(tileX, tileY)
  for _, zone in ipairs(M.zones) do
    if tileX >= zone.x1 and tileX <= zone.x2 and tileY >= zone.y1 and tileY <= zone.y2 then
      return zone
    end
  end
  return nil
end

function M.getBuildingAt(tileX, tileY)
  for _, b in ipairs(M.buildings) do
    if tileX >= b.x and tileX < b.x + b.width and tileY >= b.y and tileY < b.y + b.height then
      return b
    end
  end
  return nil
end

function M.isMountain(tileX, tileY)
  for _, m in ipairs(M.mountains) do
    if tileX >= m.x1 and tileX <= m.x2 and tileY >= m.y1 and tileY <= m.y2 then
      return true
    end
  end
  return false
end

function M.isGorge(tileX, tileY)
  for _, g in ipairs(M.gorges) do
    if tileX >= g.x1 and tileX <= g.x2 and tileY >= g.y1 and tileY <= g.y2 then
      return true, g
    end
  end
  return false
end

function M.isOnBridge(tileX, tileY)
  for _, br in ipairs(M.bridges) do
    local minX = math.min(br.x1, br.x2)
    local maxX = math.max(br.x1, br.x2)
    local minY = math.min(br.y1, br.y2)
    local maxY = math.max(br.y1, br.y2)
    if br.x1 == br.x2 then
      if tileX >= br.x1 and tileX < br.x1 + br.width and tileY >= minY and tileY <= maxY then
        return true, br
      end
    else
      if tileX >= minX and tileX <= maxX and tileY >= br.y1 and tileY < br.y1 + br.width then
        return true, br
      end
    end
  end
  return false
end

function M.isOnTrail(tileX, tileY)
  for _, trail in ipairs(M.trails) do
    for _, seg in ipairs(trail.segments) do
      local minX = math.min(seg.x1, seg.x2)
      local maxX = math.max(seg.x1, seg.x2)
      local minY = math.min(seg.y1, seg.y2)
      local maxY = math.max(seg.y1, seg.y2)
      if tileX >= minX and tileX <= maxX and tileY >= minY and tileY <= maxY then
        return true, trail.name
      end
    end
  end
  return false
end

function M.createCollisionMap()
  local map = {}
  for y = 0, M.WORLD_HEIGHT - 1 do
    map[y] = {}
    for x = 0, M.WORLD_WIDTH - 1 do
      if M.isMountain(x, y) then
        map[y][x] = true
      end
      local isGorge = M.isGorge(x, y)
      local onBridge = M.isOnBridge(x, y)
      if isGorge and not onBridge then
        map[y][x] = true
      end
    end
  end
  for _, b in ipairs(M.buildings) do
    for by = b.y, b.y + b.height - 1 do
      for bx = b.x, b.x + b.width - 1 do
        if map[by] then map[by][bx] = true end
      end
    end
    -- Clear door tile and approach tile so player can enter
    if map[b.doorY] then map[b.doorY][b.doorX] = nil end
    if map[b.doorY - 1] then map[b.doorY - 1][b.doorX] = nil end
  end
  for _, d in ipairs(M.decorations) do
    if d.type == "boulder" or d.type == "stupa" then
      if map[d.y] then map[d.y][d.x] = true end
    end
  end
  for _, trail in ipairs(M.trails) do
    for _, seg in ipairs(trail.segments) do
      local minX = math.min(seg.x1, seg.x2)
      local maxX = math.max(seg.x1, seg.x2)
      local minY = math.min(seg.y1, seg.y2)
      local maxY = math.max(seg.y1, seg.y2)
      for y = minY, maxY do
        for x = minX, maxX do
          if map[y] then map[y][x] = nil end
        end
      end
    end
  end
  return map
end

return M
