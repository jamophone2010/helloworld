local M = {}

local sounds = {}

function M.load()
  -- Uncomment when audio assets are available:
  -- sounds.laser = love.audio.newSource("assets/laser.wav", "static")
  -- sounds.charge = love.audio.newSource("assets/charge.wav", "static")
  -- sounds.bomb = love.audio.newSource("assets/bomb.wav", "static")
  -- sounds.explosion = love.audio.newSource("assets/explosion.wav", "static")
  -- sounds.barrelRoll = love.audio.newSource("assets/barrel_roll.wav", "static")
  -- sounds.wingman = love.audio.newSource("assets/wingman.wav", "static")
end

function M.playLaser()
  -- if sounds.laser then sounds.laser:clone():play() end
end

function M.playCharge()
  -- if sounds.charge then sounds.charge:play() end
end

function M.playBomb()
  -- if sounds.bomb then sounds.bomb:play() end
end

function M.playExplosion()
  -- if sounds.explosion then sounds.explosion:clone():play() end
end

function M.playBarrelRoll()
  -- if sounds.barrelRoll then sounds.barrelRoll:play() end
end

function M.playWingman()
  -- if sounds.wingman then sounds.wingman:play() end
end

return M
