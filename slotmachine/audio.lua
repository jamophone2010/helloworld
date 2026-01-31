local M = {}

local sounds = {}

function M.load()
  -- Uncomment when audio assets are available:
  -- sounds.spin = love.audio.newSource("assets/spin.wav", "static")
  -- sounds.stop = love.audio.newSource("assets/stop.wav", "static")
  -- sounds.win = love.audio.newSource("assets/win.wav", "static")
  -- sounds.coin = love.audio.newSource("assets/coin.wav", "static")
end

function M.playSpin()
  -- if sounds.spin then sounds.spin:play() end
end

function M.playStop()
  -- if sounds.stop then sounds.stop:play() end
end

function M.playWin()
  -- if sounds.win then sounds.win:play() end
end

function M.playCoin()
  -- if sounds.coin then sounds.coin:play() end
end

return M
