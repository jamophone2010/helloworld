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
      {name = "Surf Bro Jake", x = 5, y = 4, dialogue = "Dude! Check out these boards. Custom shaped right here in Leucadia.", gender = "male"},
      {name = "Shop Girl", x = 10, y = 5, dialogue = "We've got wax, leashes, rash guards... everything a pilot-surfer needs!", gender = "female", design = 5}
    }
  },
  lifeguard = {
    name = "Lifeguard Station",
    width = 8, height = 8,
    exitX = 4, exitY = 7,
    npcs = {
      {name = "Head Lifeguard", x = 4, y = 3, dialogue = "We watch the skies AND the seas. No one gets lost on our watch.", gender = "female", design = 2}
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
      {name = "Old Salt", x = 5, y = 3, dialogue = "Fresh bait, sturdy line. That's all a fisherman needs... and patience.", gender = "male"},
      {name = "Kid Angler", x = 8, y = 5, dialogue = "I caught a sea bass this big! Well... almost this big.", gender = "male"}
    }
  },
  restaurant = {
    name = "Sunset Seafood Grill",
    width = 16, height = 12,
    exitX = 8, exitY = 11,
    npcs = {
      {name = "Chef Maria", x = 5, y = 4, dialogue = "Today's catch: Mahi-mahi with mango salsa. Fresh from the pier!", gender = "female", design = 6},
      {name = "Waiter", x = 12, y = 6, dialogue = "Table by the window? Best sunset view in town.", gender = "male"},
      {name = "Food Critic", x = 8, y = 8, dialogue = "I've reviewed restaurants across the galaxy. This place? Five stars.", gender = "male"}
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
      {name = "Shopkeeper Lou", x = 5, y = 5, dialogue = "We've got everything! Snacks, supplies, souvenirs... you name it.", gender = "male"},
      {name = "Stock Boy", x = 11, y = 7, dialogue = "New shipment came in yesterday. Got some rare items this time!", gender = "male"}
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
      {name = "Teller", x = 4, y = 4, dialogue = "Notes, credits, shells... we accept all forms of currency.", gender = "female", design = 4},
      {name = "Bank Manager", x = 9, y = 5, dialogue = "Your funds are secure. We've never had a robbery. The beach vibes keep everyone mellow.", gender = "male"}
    }
  },
  town_hall = {
    name = "Leucadia Town Hall",
    width = 16, height = 12,
    exitX = 8, exitY = 11,
    npcs = {
      {name = "Secretary", x = 6, y = 4, dialogue = "The mayor is in a meeting about the annual surf festival.", gender = "female", design = 3},
      {name = "Town Clerk", x = 12, y = 5, dialogue = "Need a permit? Fishing license? Beach bonfire approval? I can help.", gender = "male"},
      {name = "Old Timer", x = 8, y = 8, dialogue = "I remember when this was just a small fishing village. Look at it now!", gender = "male"}
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
      {name = "Barista", x = 5, y = 3, dialogue = "What can I get you? Our cold brew is legendary.", gender = "female", design = 2},
      {name = "Remote Worker", x = 10, y = 6, dialogue = "Best wifi in town. I run my whole business from this table.", gender = "male"},
      {name = "Coffee Snob", x = 3, y = 7, dialogue = "Single origin, light roast, pour-over. Anything else is barbaric.", gender = "male"}
    }
  },
  boutique = {
    name = "Coastal Threads Boutique",
    width = 12, height = 10,
    exitX = 6, exitY = 9,
    npcs = {
      {name = "Fashion Designer", x = 6, y = 3, dialogue = "Beach chic meets space age. That's our aesthetic.", gender = "female", design = 1},
      {name = "Shopper", x = 9, y = 6, dialogue = "This sundress is perfect for watching launches from the beach!", gender = "female", design = 5}
    }
  },
  taco_stand = {
    name = "Tio's Taco Stand",
    width = 8, height = 8,
    exitX = 4, exitY = 7,
    npcs = {
      {name = "Tio Miguel", x = 4, y = 3, dialogue = "Best fish tacos on the coast! Secret family recipe, passed down for generations.", gender = "male"}
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
      {name = "Shaper Dan", x = 4, y = 5, dialogue = "Longboards, shortboards, fish, guns... I've shaped them all.", gender = "male"},
      {name = "Pro Surfer", x = 9, y = 4, dialogue = "I ride the big waves at Solar. These boards can handle anything.", gender = "female", design = 2}
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
      {name = "Beach Mom", x = 5, y = 4, dialogue = "We moved here for the sunsets. Best decision we ever made.", gender = "female", design = 6},
      {name = "Beach Kid", x = 9, y = 6, dialogue = "My room has a view of the ocean! I can see dolphins every morning!", gender = "male"}
    }
  },
  beach_house_2 = {
    name = "Driftwood Cottage",
    width = 12, height = 10,
    exitX = 6, exitY = 9,
    portals = {
      {name = "Trapdoor", x = 9, y = 7, game = "secret_base", color = {0.3, 0.35, 0.4},
       description = "A heavy steel trapdoor concealed beneath a weathered rug. Navy insignia etched into the handle.",
       isTrapdoor = true}
    },
    npcs = {
      {name = "Retired Captain", x = 6, y = 4, dialogue = "I sailed the seven seas... and a few more in other systems. Leucadia is where I rest. Don't mind the rug in the corner.", gender = "male"}
    }
  },
  beach_house_3 = {
    name = "Oceanview Villa",
    width = 12, height = 10,
    exitX = 6, exitY = 9,
    npcs = {
      {name = "Artist", x = 5, y = 5, dialogue = "The light here is perfect for painting. Golden hour lasts forever.", gender = "female", design = 1},
      {name = "Musician", x = 9, y = 4, dialogue = "I write songs about the sea. The waves are my metronome.", gender = "male"}
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
      {name = "Florist Rose", x = 5, y = 4, dialogue = "Fresh flowers from our fields! Ranunculus, roses, sunflowers...", gender = "female", design = 1},
      {name = "Delivery Guy", x = 9, y = 6, dialogue = "I deliver bouquets all over town. Everyone loves getting flowers!", gender = "male"}
    }
  },
  greenhouse = {
    name = "Solar Greenhouse",
    width = 16, height = 12,
    exitX = 8, exitY = 11,
    npcs = {
      {name = "Botanist", x = 6, y = 4, dialogue = "We're growing plants from twelve different planets here. Climate controlled perfection.", gender = "female", design = 4},
      {name = "Gardener's Assistant", x = 12, y = 7, dialogue = "The alien orchids are blooming! Come see, they glow in the dark!", gender = "male"}
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
      {name = "Asteroids", x = 6, y = 6, game = "asteroids", color = {0.3, 0.5, 0.8}},
      {name = "StarFox", x = 10, y = 6, game = "starfox", color = {0.3, 0.5, 1}},
      {name = "Planet Map", x = 14, y = 6, game = "planetmap", color = {0.5, 0.3, 0.7}}
    },
    npcs = {
      {name = "Commander Vega", x = 10, y = 3, dialogue = "Check the Planet Map to explore new worlds and stations.", gender = "female", design = 2},
      {name = "Tactical Officer", x = 16, y = 8, dialogue = "The galaxy is vast. The map shows all known systems.", gender = "male"}
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
      {name = "Mechanic Rico", x = 5, y = 7, dialogue = "Your ship is looking good! Salt air can be tough on the hull though.", gender = "male"},
      {name = "Crew Chief", x = 14, y = 5, dialogue = "All ships fueled and ready. The runway extends right onto the beach!", gender = "female", design = 2}
    }
  },
  pilots_lounge = {
    name = "The Prop Wash Lounge",
    width = 14, height = 10,
    exitX = 7, exitY = 9,
    npcs = {
      {name = "Bartender", x = 5, y = 3, dialogue = "What'll it be, flyboy? We've got drinks that'll make you forget the void.", gender = "male"},
      {name = "Veteran Pilot", x = 10, y = 6, dialogue = "I've flown every route from Corneria to Venom. Leucadia's my home base now.", gender = "female", design = 6},
      {name = "Rookie", x = 3, y = 7, dialogue = "First mission tomorrow! Any advice from the pros?", gender = "male"}
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
      {name = "Quartermaster", x = 5, y = 5, dialogue = "Health packs, smart bombs, upgrades... everything a pilot needs.", gender = "male"}
    }
  },

  -- ═══════════════════════════════════════
  -- SECRET BASE: USS PENDLETON (Aircraft Carrier)
  -- Camp Pendleton / San Diego Navy inspired
  -- Accessed via trapdoor in Driftwood Cottage
  -- ═══════════════════════════════════════
  carrier_hangar = {
    name = "Hangar Bay 1",
    width = 24, height = 16,
    exitX = 12, exitY = 15,
    portals = {
      {name = "Ship Selection", x = 12, y = 5, game = "hangar", color = {0.5, 0.55, 0.65}},
    },
    npcs = {
      {name = "Air Boss Mitchell", x = 8, y = 4, dialogue = "I control every launch and recovery on this deck. One wrong call and a pilot doesn't come home. No pressure.", gender = "male", design = 3},
      {name = "Plane Captain Ortiz", x = 16, y = 7, dialogue = "Every bird on this deck is my responsibility. Pre-flight, post-flight, I know these fighters better than the pilots do.", gender = "female", design = 6},
      {name = "Fueling Crew Davis", x = 6, y = 10, dialogue = "JP-5 fuel, thousands of gallons. One spark and this whole bay goes up. We don't make mistakes.", gender = "male"},
      {name = "LSO Rodriguez", x = 18, y = 10, dialogue = "Landing Signal Officer. I grade every trap. Bolter, fair, OK, no grade... pilots hate my scores.", gender = "male", design = 5},
    },
    decorations = {
      {type = "fighter_jet", x = 4, y = 3, w = 6, h = 3, collision = true, variant = "f18_hornet"},
      {type = "fighter_jet", x = 14, y = 3, w = 6, h = 3, collision = true, variant = "f35_lightning"},
      {type = "tool_cart", x = 2, y = 8, collision = true},
      {type = "fuel_line", x = 10, y = 12, w = 4, collision = false},
      {type = "fire_extinguisher", x = 22, y = 2, collision = true},
      {type = "status_board", x = 11, y = 1, collision = false},
    },
    zones = {
      {name = "hangar_floor", x1 = 0, y1 = 0, x2 = 23, y2 = 15, floor = "steel_nonskid"},
    },
  },
  carrier_bridge = {
    name = "Combat Information Center",
    width = 20, height = 16,
    exitX = 10, exitY = 15,
    npcs = {
      {name = "Captain Torres", x = 10, y = 3, dialogue = "I've commanded this carrier for three tours. San Diego to deep space and back. She's never let me down.", gender = "male", design = 5},
      {name = "Helm Officer Park", x = 6, y = 5, dialogue = "All ahead full, aye. Heading two-seven-zero. The Pacific's calm today... for now.", gender = "female", design = 2},
      {name = "Radar Tech Kowalski", x = 14, y = 7, dialogue = "Multiple contacts bearing north. Probably civilian traffic out of San Diego Bay. Probably.", gender = "male"},
      {name = "Comms Officer Vasquez", x = 10, y = 9, dialogue = "All channels monitored. Camp Pendleton confirms green status. Fleet comm is nominal.", gender = "female", design = 4},
    },
    decorations = {
      {type = "radar_screen", x = 3, y = 2, w = 3, h = 2, collision = true},
      {type = "radar_screen", x = 14, y = 2, w = 3, h = 2, collision = true},
      {type = "navigation_chart", x = 8, y = 1, w = 4, h = 1, collision = false},
      {type = "helm_console", x = 5, y = 5, w = 2, collision = true},
      {type = "captain_chair", x = 10, y = 3, collision = false},
      {type = "window_panoramic", x = 0, y = 0, w = 20, h = 1, collision = true},
    },
    zones = {
      {name = "bridge_deck", x1 = 0, y1 = 0, x2 = 19, y2 = 15, floor = "bridge_tile"},
    },
  },
  carrier_mess = {
    name = "Mess Deck",
    width = 18, height = 14,
    exitX = 9, exitY = 13,
    npcs = {
      {name = "Chef Gutierrez", x = 6, y = 3, dialogue = "Feeding 5,000 sailors three meals a day. My Carne Asada Fridays are legendary — San Diego recipe, passed down from my abuela.", gender = "male", design = 3},
      {name = "Mess Specialist Tran", x = 12, y = 5, dialogue = "Midrats at midnight. Best kept secret on the ship. The sliders hit different at 0200.", gender = "female", design = 6},
      {name = "Hungry Marine", x = 8, y = 8, dialogue = "Pendleton chow was rough, but carrier food? This is the Ritz compared to MREs in the field.", gender = "male"},
      {name = "Coffee Addict", x = 14, y = 9, dialogue = "Navy runs on coffee. I'm on cup number seven. Don't judge me — we've been at general quarters since 0400.", gender = "female", design = 2},
    },
    decorations = {
      {type = "serving_line", x = 2, y = 2, w = 8, h = 1, collision = true},
      {type = "mess_table", x = 3, y = 5, w = 4, h = 2, collision = true},
      {type = "mess_table", x = 11, y = 5, w = 4, h = 2, collision = true},
      {type = "mess_table", x = 3, y = 9, w = 4, h = 2, collision = true},
      {type = "mess_table", x = 11, y = 9, w = 4, h = 2, collision = true},
      {type = "soda_machine", x = 16, y = 3, collision = true},
      {type = "tv_screen", x = 9, y = 1, collision = false},
    },
  },
  carrier_armory = {
    name = "Weapons Bay / Armory",
    width = 20, height = 14,
    exitX = 10, exitY = 13,
    portals = {
      {name = "Shop", x = 10, y = 5, game = "shop", color = {0.8, 0.3, 0.2}},
    },
    npcs = {
      {name = "Weapons Officer Briggs", x = 6, y = 4, dialogue = "Sidewinders, Harpoons, JDAMs — everything's inventoried down to the last round. Accountability is life and death.", gender = "male", design = 5},
      {name = "Ordnance Handler Pike", x = 14, y = 6, dialogue = "Red shirt on the flight deck means I handle the bombs. Yeah, it's as dangerous as it sounds.", gender = "female", design = 6},
      {name = "Marine Armorer Cruz", x = 8, y = 9, dialogue = "Camp Pendleton armorers are the best. I can field-strip an M4 blindfolded. Wanna see?", gender = "male", design = 3},
    },
    decorations = {
      {type = "weapons_rack", x = 1, y = 1, w = 2, h = 10, collision = true},
      {type = "weapons_rack", x = 17, y = 1, w = 2, h = 10, collision = true},
      {type = "missile_rack", x = 6, y = 2, w = 3, h = 2, collision = true},
      {type = "ammo_crate", x = 12, y = 2, w = 2, h = 2, collision = true},
      {type = "workbench", x = 7, y = 8, w = 6, h = 1, collision = true},
    },
  },
  carrier_berthing = {
    name = "Crew Berthing",
    width = 16, height = 12,
    exitX = 8, exitY = 11,
    npcs = {
      {name = "Boatswain's Mate Hull", x = 5, y = 4, dialogue = "Rack, locker, and six inches of personal space. Home sweet home for six months at sea.", gender = "male"},
      {name = "Seaman Apprentice Lee", x = 11, y = 5, dialogue = "First deployment out of San Diego. My family watched us pull out of the harbor. Mom cried.", gender = "male"},
      {name = "Petty Officer Nakamura", x = 7, y = 8, dialogue = "Hot-racking means three sailors share two bunks. You learn to sleep fast and sleep anywhere.", gender = "female", design = 4},
    },
    decorations = {
      {type = "bunk_rack", x = 1, y = 1, w = 2, h = 8, collision = true},
      {type = "bunk_rack", x = 5, y = 1, w = 2, h = 8, collision = true},
      {type = "bunk_rack", x = 9, y = 1, w = 2, h = 8, collision = true},
      {type = "bunk_rack", x = 13, y = 1, w = 2, h = 8, collision = true},
      {type = "footlocker", x = 3, y = 9, collision = true},
      {type = "footlocker", x = 7, y = 9, collision = true},
      {type = "footlocker", x = 11, y = 9, collision = true},
    },
  },
  carrier_warroom = {
    name = "War Room / SCIF",
    width = 20, height = 14,
    exitX = 10, exitY = 13,
    portals = {
      {name = "Planet Map", x = 10, y = 4, game = "planetmap", color = {0.1, 0.4, 0.9}},
    },
    npcs = {
      {name = "Intel Chief Blackwood", x = 7, y = 4, dialogue = "Everything in this room is TS/SCI. What you see here, stays here. That's not a suggestion.", gender = "male", design = 5},
      {name = "Analyst Reeves", x = 14, y = 6, dialogue = "We're tracking fleet movements across twelve sectors. The data feeds come straight from Pendleton's satellite arrays.", gender = "female", design = 2},
      {name = "SEAL Liaison Frost", x = 8, y = 9, dialogue = "Coronado trained me. The only easy day was yesterday. I'm here to coordinate special ops.", gender = "male", design = 6},
      {name = "Cryptologist Pham", x = 14, y = 10, dialogue = "I break codes for a living. The enemy thinks their comms are secure. They're not.", gender = "female", design = 4},
    },
    decorations = {
      {type = "holo_table", x = 7, y = 3, w = 6, h = 4, collision = true},
      {type = "classified_screen", x = 1, y = 1, w = 4, h = 2, collision = true},
      {type = "classified_screen", x = 15, y = 1, w = 4, h = 2, collision = true},
      {type = "secure_terminal", x = 3, y = 8, collision = true},
      {type = "secure_terminal", x = 16, y = 8, collision = true},
      {type = "shredder", x = 18, y = 12, collision = true},
    },
    zones = {
      {name = "scif", x1 = 0, y1 = 0, x2 = 19, y2 = 13, floor = "secure_tile"},
    },
  },
  carrier_engineering = {
    name = "Main Engineering",
    width = 16, height = 12,
    exitX = 8, exitY = 11,
    npcs = {
      {name = "Chief Engineer Tanaka", x = 6, y = 4, dialogue = "Four nuclear reactors, two shafts, 280,000 horsepower. I keep this city at sea running. You're welcome.", gender = "male", design = 3},
      {name = "Machinist's Mate Webb", x = 12, y = 6, dialogue = "If it's broken, I fix it. If it's not broken, I maintain it. Nothing stops on my watch.", gender = "female", design = 6},
      {name = "Nuke Tech Alvarez", x = 8, y = 9, dialogue = "Nuclear-trained out of San Diego. The reactor is my baby. Stable, clean, and putting out enough power for a small city.", gender = "male"},
    },
    decorations = {
      {type = "reactor_console", x = 2, y = 2, w = 4, h = 3, collision = true},
      {type = "reactor_console", x = 10, y = 2, w = 4, h = 3, collision = true},
      {type = "steam_pipe", x = 0, y = 6, w = 16, h = 1, collision = false},
      {type = "pressure_gauge", x = 7, y = 1, w = 2, h = 1, collision = false},
      {type = "toolbox", x = 3, y = 9, collision = true},
      {type = "toolbox", x = 12, y = 9, collision = true},
    },
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
