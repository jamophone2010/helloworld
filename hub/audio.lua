local M = {}

local sounds = {}

function M.load()
  -- Uncomment when audio assets are available:
  -- sounds.portal = love.audio.newSource("assets/portal.wav", "static")
  -- sounds.walk = love.audio.newSource("assets/walk.wav", "static")
end

function M.playPortal()
  -- if sounds.portal then sounds.portal:play() end
end

function M.playWalk()
  -- if sounds.walk then sounds.walk:play() end
end

return M
