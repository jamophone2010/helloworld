local M = {}

local sounds = {}

function M.load()
  -- Uncomment when audio assets are available:
  -- sounds.thrust = love.audio.newSource("assets/thrust.wav", "static")
  -- sounds.shoot = love.audio.newSource("assets/shoot.wav", "static")
  -- sounds.explode = love.audio.newSource("assets/explode.wav", "static")
  -- sounds.powerup = love.audio.newSource("assets/powerup.wav", "static")
  -- sounds.ufo = love.audio.newSource("assets/ufo.wav", "static")
end

function M.playThrust()
  -- if sounds.thrust then sounds.thrust:play() end
end

function M.playShoot()
  -- if sounds.shoot then sounds.shoot:play() end
end

function M.playExplode()
  -- if sounds.explode then sounds.explode:play() end
end

function M.playPowerup()
  -- if sounds.powerup then sounds.powerup:play() end
end

function M.playUFO()
  -- if sounds.ufo then sounds.ufo:play() end
end

return M
