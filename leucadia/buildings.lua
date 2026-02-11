-- leucadia/buildings.lua
-- Interior layouts for buildings in Leucadia beach town

local M = {}

M.GRID_SIZE = 32

M.interiors = {
  -- ═══════════════════════════════════════
  -- BEACH AREA
  -- ═══════════════════════════════════════
  surf_shop = {
    name = "Gnarly Waves Surf Shack",
    width = 14, height = 10,
    exitX = 7, exitY = 9,
    portals = {
      {name = "Shop", x = 7, y = 3, game = "shop", color = {0.2, 0.7, 0.9}}
    },
    npcs = {
      {name = "Surf Bro Jake", x = 5, y = 4, dialogue = "Dude! Check out these boards. Custom shaped right here in Leucadia."},
      {name = "Shop Girl", x = 10, y = 5, dialogue = "We've got wax, leashes, rash guards... everything a pilot-surfer needs!"}
    }
  },
  lifeguard = {
    name = "Lifeguard Station",
    width = 8, height = 8,
    exitX = 4, exitY = 7,
    npcs = {
      {name = "Head Lifeguard", x = 4, y = 3, dialogue = "We watch the skies AND the seas. No one gets lost on our watch."}
    }
  },

  -- ═══════════════════════════════════════
  -- PIER AREA
  -- ═══════════════════════════════════════
  bait_shop = {
    name = "Captain's Bait & Tackle",
    width = 10, height = 8,
    exitX = 5, exitY = 7,
    npcs = {
      {name = "Old Salt", x = 5, y = 3, dialogue = "Fresh bait, sturdy line. That's all a fisherman needs... and patience."},
      {name = "Kid Angler", x = 8, y = 5, dialogue = "I caught a sea bass this big! Well... almost this big."}
    }
  },
  restaurant = {
    name = "Sunset Seafood Grill",
    width = 16, height = 12,
    exitX = 8, exitY = 11,
    npcs = {
      {name = "Chef Maria", x = 5, y = 4, dialogue = "Today's catch: Mahi-mahi with mango salsa. Fresh from the pier!"},
      {name = "Waiter", x = 12, y = 6, dialogue = "Table by the window? Best sunset view in town."},
      {name = "Food Critic", x = 8, y = 8, dialogue = "I've reviewed restaurants across the galaxy. This place? Five stars."}
    }
  },

  -- ═══════════════════════════════════════
  -- TOWN SQUARE
  -- ═══════════════════════════════════════
  general_store = {
    name = "Leucadia General Store",
    width = 14, height = 12,
    exitX = 7, exitY = 11,
    portals = {
      {name = "Shop", x = 7, y = 4, game = "shop", color = {0.6, 0.5, 0.3}}
    },
    npcs = {
      {name = "Shopkeeper Lou", x = 5, y = 5, dialogue = "We've got everything! Snacks, supplies, souvenirs... you name it."},
      {name = "Stock Boy", x = 11, y = 7, dialogue = "New shipment came in yesterday. Got some rare items this time!"}
    }
  },
  bank = {
    name = "First Beach Bank",
    width = 12, height = 10,
    exitX = 6, exitY = 9,
    portals = {
      {name = "Exchange", x = 6, y = 3, game = "casino_exchange", color = {1, 1, 0}}
    },
    npcs = {
      {name = "Teller", x = 4, y = 4, dialogue = "Notes, credits, shells... we accept all forms of currency."},
      {name = "Bank Manager", x = 9, y = 5, dialogue = "Your funds are secure. We've never had a robbery. The beach vibes keep everyone mellow."}
    }
  },
  town_hall = {
    name = "Leucadia Town Hall",
    width = 16, height = 12,
    exitX = 8, exitY = 11,
    npcs = {
      {name = "Secretary", x = 6, y = 4, dialogue = "The mayor is in a meeting about the annual surf festival."},
      {name = "Town Clerk", x = 12, y = 5, dialogue = "Need a permit? Fishing license? Beach bonfire approval? I can help."},
      {name = "Old Timer", x = 8, y = 8, dialogue = "I remember when this was just a small fishing village. Look at it now!"}
    }
  },

  -- ═══════════════════════════════════════
  -- COAST HIGHWAY
  -- ═══════════════════════════════════════
  cafe = {
    name = "The Daily Grind Cafe",
    width = 14, height = 10,
    exitX = 7, exitY = 9,
    npcs = {
      {name = "Barista", x = 5, y = 3, dialogue = "What can I get you? Our cold brew is legendary."},
      {name = "Remote Worker", x = 10, y = 6, dialogue = "Best wifi in town. I run my whole business from this table."},
      {name = "Coffee Snob", x = 3, y = 7, dialogue = "Single origin, light roast, pour-over. Anything else is barbaric."}
    }
  },
  boutique = {
    name = "Coastal Threads Boutique",
    width = 12, height = 10,
    exitX = 6, exitY = 9,
    npcs = {
      {name = "Fashion Designer", x = 6, y = 3, dialogue = "Beach chic meets space age. That's our aesthetic."},
      {name = "Shopper", x = 9, y = 6, dialogue = "This sundress is perfect for watching launches from the beach!"}
    }
  },
  taco_stand = {
    name = "Tio's Taco Stand",
    width = 8, height = 8,
    exitX = 4, exitY = 7,
    npcs = {
      {name = "Tio Miguel", x = 4, y = 3, dialogue = "Best fish tacos on the coast! Secret family recipe, passed down for generations."}
    }
  },
  board_shop = {
    name = "Waverunner Board Shop",
    width = 12, height = 10,
    exitX = 6, exitY = 9,
    portals = {
      {name = "Shop", x = 6, y = 4, game = "shop", color = {0.3, 0.6, 0.8}}
    },
    npcs = {
      {name = "Shaper Dan", x = 4, y = 5, dialogue = "Longboards, shortboards, fish, guns... I've shaped them all."},
      {name = "Pro Surfer", x = 9, y = 4, dialogue = "I ride the big waves at Solar. These boards can handle anything."}
    }
  },

  -- ═══════════════════════════════════════
  -- RESIDENTIAL
  -- ═══════════════════════════════════════
  beach_house_1 = {
    name = "The Sandcastle",
    width = 12, height = 10,
    exitX = 6, exitY = 9,
    npcs = {
      {name = "Beach Mom", x = 5, y = 4, dialogue = "We moved here for the sunsets. Best decision we ever made."},
      {name = "Beach Kid", x = 9, y = 6, dialogue = "My room has a view of the ocean! I can see dolphins every morning!"}
    }
  },
  beach_house_2 = {
    name = "Driftwood Cottage",
    width = 12, height = 10,
    exitX = 6, exitY = 9,
    npcs = {
      {name = "Retired Captain", x = 6, y = 4, dialogue = "I sailed the seven seas... and a few more in other systems. Leucadia is where I rest."}
    }
  },
  beach_house_3 = {
    name = "Oceanview Villa",
    width = 12, height = 10,
    exitX = 6, exitY = 9,
    npcs = {
      {name = "Artist", x = 5, y = 5, dialogue = "The light here is perfect for painting. Golden hour lasts forever."},
      {name = "Musician", x = 9, y = 4, dialogue = "I write songs about the sea. The waves are my metronome."}
    }
  },

  -- ═══════════════════════════════════════
  -- FLOWER FIELDS
  -- ═══════════════════════════════════════
  flower_shop = {
    name = "Petal Pusher Florist",
    width = 12, height = 10,
    exitX = 6, exitY = 9,
    npcs = {
      {name = "Florist Rose", x = 5, y = 4, dialogue = "Fresh flowers from our fields! Ranunculus, roses, sunflowers..."},
      {name = "Delivery Guy", x = 9, y = 6, dialogue = "I deliver bouquets all over town. Everyone loves getting flowers!"}
    }
  },
  greenhouse = {
    name = "Solar Greenhouse",
    width = 16, height = 12,
    exitX = 8, exitY = 11,
    npcs = {
      {name = "Botanist", x = 6, y = 4, dialogue = "We're growing plants from twelve different planets here. Climate controlled perfection."},
      {name = "Gardener's Assistant", x = 12, y = 7, dialogue = "The alien orchids are blooming! Come see, they glow in the dark!"}
    }
  },

  -- ═══════════════════════════════════════
  -- MISSION DISTRICT (Main hub for missions)
  -- ═══════════════════════════════════════
  mission_control = {
    name = "Leucadia Mission Control",
    width = 20, height = 15,
    exitX = 10, exitY = 14,
    portals = {
      {name = "Asteroids", x = 7, y = 6, game = "asteroids", color = {0.3, 0.5, 0.8}},
      {name = "StarFox", x = 13, y = 6, game = "starfox", color = {0.3, 0.5, 1}}
    },
    npcs = {
      {name = "Commander Vega", x = 10, y = 3, dialogue = "Ready for a mission, pilot? The galaxy needs defenders."},
      {name = "Tactical Officer", x = 16, y = 8, dialogue = "Sector activity is elevated. We could use your skills out there."}
    }
  },
  hangar = {
    name = "Beach Hangar",
    width = 18, height = 14,
    exitX = 9, exitY = 13,
    portals = {
      {name = "Ship Selection", x = 8, y = 5, game = "hangar", color = {0.2, 0.7, 0.8}}
    },
    npcs = {
      {name = "Mechanic Rico", x = 5, y = 7, dialogue = "Your ship is looking good! Salt air can be tough on the hull though."},
      {name = "Crew Chief", x = 14, y = 5, dialogue = "All ships fueled and ready. The runway extends right onto the beach!"}
    }
  },
  pilots_lounge = {
    name = "The Prop Wash Lounge",
    width = 14, height = 10,
    exitX = 7, exitY = 9,
    npcs = {
      {name = "Bartender", x = 5, y = 3, dialogue = "What'll it be, flyboy? We've got drinks that'll make you forget the void."},
      {name = "Veteran Pilot", x = 10, y = 6, dialogue = "I've flown every route from Corneria to Venom. Leucadia's my home base now."},
      {name = "Rookie", x = 3, y = 7, dialogue = "First mission tomorrow! Any advice from the pros?"}
    }
  },
  supply_depot = {
    name = "Pilot Supply Depot",
    width = 14, height = 10,
    exitX = 7, exitY = 9,
    portals = {
      {name = "Shop", x = 7, y = 4, game = "shop", color = {0.6, 0.3, 0.8}}
    },
    npcs = {
      {name = "Quartermaster", x = 5, y = 5, dialogue = "Health packs, smart bombs, upgrades... everything a pilot needs."}
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
