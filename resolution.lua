-- resolution.lua
-- Manages screen resolution settings and virtual-resolution scaling.
-- The game is designed at a virtual resolution of 1366×768.
-- All rendering is done to a canvas at virtual resolution, then scaled
-- to fill the real window, so every module keeps its positions as-is.

local M = {}

-- Virtual (design) resolution — all game code targets this
M.VIRTUAL_W = 1366
M.VIRTUAL_H = 768

-- Available resolution presets (label, width, height)
M.PRESETS = {
  { label = "1366×768",   w = 1366, h = 768  },
  { label = "1920×1080",  w = 1920, h = 1080 },
  { label = "2560×1440",  w = 2560, h = 1440 },
  { label = "3840×2160",  w = 3840, h = 2160 },
}

-- Current preset index (default: 1366×768)
M.currentIndex = 1

-- The off-screen canvas that all game drawing targets
M.canvas = nil

-- Scale and offset for drawing the canvas onto the real window
M.scaleX = 1
M.scaleY = 1
M.scale  = 1
M.offsetX = 0
M.offsetY = 0

-- Save file path
local SAVE_FILE = "resolution.dat"

-- ───────────────────────────────────────
-- Persistence
-- ───────────────────────────────────────

function M.save()
  local preset = M.PRESETS[M.currentIndex]
  local data = preset.w .. "," .. preset.h
  love.filesystem.write(SAVE_FILE, data)
end

function M.loadSaved()
  if love.filesystem.getInfo(SAVE_FILE) then
    local data = love.filesystem.read(SAVE_FILE)
    if data then
      local w, h = data:match("^(%d+),(%d+)$")
      w, h = tonumber(w), tonumber(h)
      if w and h then
        for i, preset in ipairs(M.PRESETS) do
          if preset.w == w and preset.h == h then
            M.currentIndex = i
            return
          end
        end
      end
    end
  end
  -- Default to 1366×768
  M.currentIndex = 1
end

-- ───────────────────────────────────────
-- Initialisation (call from love.load)
-- ───────────────────────────────────────

function M.init()
  M.loadSaved()
  M.apply()
end

function M.apply()
  local preset = M.PRESETS[M.currentIndex]
  love.window.setMode(preset.w, preset.h, { resizable = false, vsync = -1 })

  -- Create / recreate the virtual-resolution canvas
  M.canvas = love.graphics.newCanvas(M.VIRTUAL_W, M.VIRTUAL_H)
  M.canvas:setFilter("linear", "linear")

  -- Compute uniform scale to fit virtual res inside real window (letterbox)
  local realW, realH = love.graphics.getDimensions()
  M.scaleX = realW / M.VIRTUAL_W
  M.scaleY = realH / M.VIRTUAL_H
  M.scale  = math.min(M.scaleX, M.scaleY)
  M.offsetX = math.floor((realW - M.VIRTUAL_W * M.scale) / 2)
  M.offsetY = math.floor((realH - M.VIRTUAL_H * M.scale) / 2)
end

-- ───────────────────────────────────────
-- Rendering helpers (call from main.lua)
-- ───────────────────────────────────────

--- Call at the very start of love.draw() to redirect drawing to the canvas.
function M.beginDraw()
  love.graphics.setCanvas(M.canvas)
  love.graphics.clear(0, 0, 0, 1)
  love.graphics.setColor(1, 1, 1, 1)
end

--- Call at the very end of love.draw() to present the canvas scaled.
function M.endDraw()
  love.graphics.setCanvas()  -- back to real screen
  love.graphics.clear(0, 0, 0, 1)
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.draw(M.canvas, M.offsetX, M.offsetY, 0, M.scale, M.scale)
end

-- ───────────────────────────────────────
-- Input coordinate mapping
-- ───────────────────────────────────────

--- Convert real window coordinates to virtual coordinates.
function M.toVirtual(realX, realY)
  local vx = (realX - M.offsetX) / M.scale
  local vy = (realY - M.offsetY) / M.scale
  return vx, vy
end

-- ───────────────────────────────────────
-- Preset cycling (for UI)
-- ───────────────────────────────────────

function M.nextPreset()
  M.currentIndex = M.currentIndex + 1
  if M.currentIndex > #M.PRESETS then M.currentIndex = 1 end
end

function M.prevPreset()
  M.currentIndex = M.currentIndex - 1
  if M.currentIndex < 1 then M.currentIndex = #M.PRESETS end
end

function M.getCurrentLabel()
  return M.PRESETS[M.currentIndex].label
end

return M
