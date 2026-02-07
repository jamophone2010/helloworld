local M = {}

M.GRID_SIZE = 32

-- Building definitions for the outdoor town
M.outdoorBuildings = {
  {
    name = "Casino",
    x = 5, y = 3,
    width = 6, height = 5,
    doorX = 7, doorY = 7,
    color = {1, 0.8, 0.2},
    interior = "casino"
  },
  {
    name = "Mission Control",
    x = 15, y = 3,
    width = 6, height = 5,
    doorX = 17, doorY = 7,
    color = {0.3, 0.5, 1},
    interior = "mission"
  },
  {
    name = "Shop",
    x = 5, y = 12,
    width = 4, height = 4,
    doorX = 6, doorY = 15,
    color = {0.6, 0.3, 0.8},
    interior = "shop"
  },
  {
    name = "Inn",
    x = 15, y = 12,
    width = 4, height = 4,
    doorX = 16, doorY = 15,
    color = {0.8, 0.3, 0.3},
    interior = "inn"
  },
  {
    name = "Community Center",
    x = 10, y = 12,
    width = 4, height = 4,
    doorX = 11, doorY = 15,
    color = {0.3, 0.8, 0.3},
    interior = "community"
  },
  {
    name = "Hangar",
    x = 21, y = 12,
    width = 4, height = 4,
    doorX = 22, doorY = 15,
    color = {0.2, 0.7, 0.8},
    interior = "hangar"
  }
}

-- Interior layouts
M.interiors = {
  casino = {
    name = "Bellagio Casino & Boutique",
    width = 30,
    height = 20,
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
  mission = {
    name = "Mission Control",
    width = 20,
    height = 15,
    exitX = 10, exitY = 14,
    portals = {
      {name = "Asteroids", x = 7, y = 6, game = "asteroids", color = {0.3, 0.5, 0.8}},
      {name = "StarFox", x = 13, y = 6, game = "starfox", color = {0.3, 0.5, 1}}
    }
  },
  shop = {
    name = "Shop",
    width = 12,
    height = 10,
    exitX = 6, exitY = 9,
    portals = {
      {name = "Shop", x = 6, y = 3, game = "shop", color = {0.6, 0.3, 0.8}}
    }
  },
  inn = {
    name = "Inn",
    width = 12,
    height = 10,
    exitX = 6, exitY = 9,
    npcs = {
      {name = "Innkeeper", x = 3, y = 3, dialogue = "Rest up, traveler!"},
      {name = "Traveler", x = 9, y = 5, dialogue = "I've heard the casino games are quite exciting!"}
    }
  },
  community = {
    name = "Community Center",
    width = 12,
    height = 10,
    exitX = 6, exitY = 9,
    npcs = {
      {name = "Elder", x = 6, y = 3, dialogue = "Welcome to our town!"},
      {name = "Child", x = 4, y = 6, dialogue = "Have you tried the missions? They're fun!"},
      {name = "Villager", x = 8, y = 6, dialogue = "The asteroids game is quite challenging."}
    }
  },
  hangar = {
    name = "Hangar",
    width = 14,
    height = 10,
    exitX = 7, exitY = 9,
    portals = {
      {name = "Ship Selection", x = 6, y = 3, game = "hangar", color = {0.2, 0.7, 0.8}}
    },
    npcs = {
      {name = "Mechanic", x = 3, y = 5, dialogue = "Pick your ride! Each ship has unique abilities."}
    }
  }
}

function M.createCollisionMap(location, isInterior)
  local map = {}

  if isInterior then
    local interior = M.interiors[location]
    if not interior then return map end

    for y = 0, interior.height - 1 do
      map[y] = {}
      for x = 0, interior.width - 1 do
        -- Walls around the perimeter (but not at the exit)
        if y == 0 or y == interior.height - 1 or x == 0 or x == interior.width - 1 then
          -- Allow passage at the exit
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
  else
    -- Outdoor town collision map
    for y = 0, 20 do
      map[y] = {}
      for x = 0, 24 do
        map[y][x] = false
        -- Buildings are solid except at doors
        for _, building in ipairs(M.outdoorBuildings) do
          if x >= building.x and x < building.x + building.width and
             y >= building.y and y < building.y + building.height then
            -- Allow passage through the door
            if not (x == building.doorX and y == building.doorY) then
              map[y][x] = true
            end
          end
        end
      end
    end
  end
  
  return map
end

function M.getBuilding(gridX, gridY)
  for _, building in ipairs(M.outdoorBuildings) do
    if gridX == building.doorX and gridY == building.doorY then
      return building
    end
  end
  return nil
end

function M.isAtExit(gridX, gridY, interiorName)
  local interior = M.interiors[interiorName]
  if interior then
    return gridX == interior.exitX and gridY == interior.exitY
  end
  return false
end

return M
