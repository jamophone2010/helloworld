local M = {}

local sounds = {}

function M.load()
  -- Uncomment when audio assets are available:
  -- sounds.deal = love.audio.newSource("assets/card_deal.wav", "static")
  -- sounds.flip = love.audio.newSource("assets/card_flip.wav", "static")
  -- sounds.win = love.audio.newSource("assets/win.wav", "static")
  -- sounds.lose = love.audio.newSource("assets/lose.wav", "static")
  -- sounds.chip = love.audio.newSource("assets/chip.wav", "static")
end

function M.playDeal()
  -- if sounds.deal then sounds.deal:play() end
end

function M.playFlip()
  -- if sounds.flip then sounds.flip:play() end
end

function M.playWin()
  -- if sounds.win then sounds.win:play() end
end

function M.playLose()
  -- if sounds.lose then sounds.lose:play() end
end

function M.playChip()
  -- if sounds.chip then sounds.chip:play() end
end

return M
