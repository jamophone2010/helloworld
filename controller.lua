-- controller.lua
-- Manages controller type selection, button-to-key mapping, and gamepad input.
--
-- Supported controller types:
--   1. Keyboard Only    (no gamepad mapping)
--   2. Nintendo Switch   (Joy-Con pair)
--   3. Switch Pro Controller
--   4. Xbox One Controller
--   5. PlayStation Controller
--
-- The game's existing input is entirely keyboard-driven (love.keyboard.isDown
-- and love.keypressed).  This module maps gamepad buttons/axes to the same
-- keyboard keys so every module works without changes.
--
-- Button label tables are provided per-controller so the UI can show
-- contextual prompts (e.g. "A" vs "B" vs "South").

local M = {}

-- ───────────────────────────────────────
-- Controller presets
-- ───────────────────────────────────────

M.TYPES = {
  { id = "keyboard",    label = "Keyboard Only" },
  { id = "switch",      label = "Nintendo Switch" },
  { id = "switch_pro",  label = "Switch Pro Controller" },
  { id = "xbox",        label = "Xbox One Controller" },
  { id = "playstation", label = "PlayStation Controller" },
}

-- Current selection index (default: Keyboard Only)
M.currentIndex = 1

-- ───────────────────────────────────────
-- Gamepad → keyboard mapping per controller type
-- ───────────────────────────────────────
-- LÖVE uses Xbox-style button names internally regardless of physical
-- controller, so the *mapping* is the same for all gamepads.  The
-- difference between the three controller presets is only the button
-- *labels* shown in UI prompts.

-- Gamepad button  →  keyboard key
M.buttonMap = {
  a          = "e",        -- Confirm / interact / shoot
  b          = "escape",   -- Cancel / back
  x          = "space",    -- Secondary action
  y          = "z",        -- Run / sprint
  start      = "escape",   -- Pause
  back       = "tab",      -- Map / info
  dpup       = "up",
  dpdown     = "down",
  dpleft     = "left",
  dpright    = "right",
  leftshoulder  = "q",     -- L bumper
  rightshoulder = "w",     -- R bumper
}

-- Axis deadzone
M.DEADZONE = 0.35

-- Tracked analog stick state → simulated key holds
-- (so love.keyboard.isDown in game modules picks them up)
M.axisKeys = {
  leftx_neg  = false,  -- left stick left  → "left"
  leftx_pos  = false,  -- left stick right → "right"
  lefty_neg  = false,  -- left stick up    → "up"
  lefty_pos  = false,  -- left stick down  → "down"
}

-- ───────────────────────────────────────
-- Display labels per controller type
-- ───────────────────────────────────────
-- Used by UI modules to show context-sensitive prompts.
-- Keys match LÖVE gamepad button names.

M.labels = {
  keyboard = {
    confirm = "E", cancel = "ESC", action = "SPACE", run = "Z",
    up = "↑", down = "↓", left = "←", right = "→",
  },
  switch = {
    confirm = "A", cancel = "B", action = "Y", run = "X",
    up = "D-pad ↑", down = "D-pad ↓", left = "D-pad ←", right = "D-pad →",
    start = "+", back = "-", lb = "L", rb = "R",
  },
  switch_pro = {
    confirm = "A", cancel = "B", action = "Y", run = "X",
    up = "D-pad ↑", down = "D-pad ↓", left = "D-pad ←", right = "D-pad →",
    start = "+", back = "-", lb = "L", rb = "R",
  },
  xbox = {
    confirm = "A", cancel = "B", action = "X", run = "Y",
    up = "D-pad ↑", down = "D-pad ↓", left = "D-pad ←", right = "D-pad →",
    start = "Menu", back = "View", lb = "LB", rb = "RB",
  },
  playstation = {
    confirm = "✕", cancel = "○", action = "□", run = "△",
    up = "D-pad ↑", down = "D-pad ↓", left = "D-pad ←", right = "D-pad →",
    start = "Options", back = "Share", lb = "L1", rb = "R1",
  },
}

-- ───────────────────────────────────────
-- Persistence
-- ───────────────────────────────────────

local SAVE_FILE = "controller.dat"

function M.save()
  local t = M.TYPES[M.currentIndex]
  love.filesystem.write(SAVE_FILE, t.id)
end

function M.loadSaved()
  if love.filesystem.getInfo(SAVE_FILE) then
    local data = love.filesystem.read(SAVE_FILE)
    if data then
      data = data:match("^%s*(.-)%s*$")  -- trim
      for i, t in ipairs(M.TYPES) do
        if t.id == data then
          M.currentIndex = i
          return
        end
      end
    end
  end
  M.currentIndex = 1
end

-- ───────────────────────────────────────
-- Init
-- ───────────────────────────────────────

function M.init()
  M.loadSaved()
end

-- ───────────────────────────────────────
-- Queries
-- ───────────────────────────────────────

function M.getCurrentId()
  return M.TYPES[M.currentIndex].id
end

function M.getCurrentLabel()
  return M.TYPES[M.currentIndex].label
end

function M.isGamepad()
  return M.currentIndex > 1
end

function M.getLabels()
  return M.labels[M.getCurrentId()] or M.labels.keyboard
end

-- ───────────────────────────────────────
-- Preset cycling (for UI)
-- ───────────────────────────────────────

function M.nextPreset()
  M.currentIndex = M.currentIndex + 1
  if M.currentIndex > #M.TYPES then M.currentIndex = 1 end
end

function M.prevPreset()
  M.currentIndex = M.currentIndex - 1
  if M.currentIndex < 1 then M.currentIndex = #M.TYPES end
end

-- ───────────────────────────────────────
-- Double-tap dodge tracking (gamepad)
-- ───────────────────────────────────────
-- Tracks d-pad and analog stick left/right presses to detect
-- double-taps for the dodge mechanic.  Uses a more generous
-- window than the keyboard (0.3s vs 0.15s) because releasing
-- and re-deflecting a stick takes longer than tapping a key.

M.DODGE_WINDOW = 0.3  -- seconds between taps to count as double-tap

local dodgeTap = {
  left  = { lastTime = 0, count = 0 },
  right = { lastTime = 0, count = 0 },
}

--- Record a directional press (called internally on d-pad or stick edge).
--- Returns true if this press completes a double-tap.
function M.registerTap(direction)
  if direction ~= "left" and direction ~= "right" then return false end
  local tap = dodgeTap[direction]
  local now = love.timer.getTime()
  if (now - tap.lastTime) < M.DODGE_WINDOW then
    tap.count = tap.count + 1
  else
    tap.count = 1
  end
  tap.lastTime = now

  if tap.count >= 2 then
    tap.count = 0       -- reset so the next dodge needs two fresh taps
    return true
  end
  return false
end

--- Reset dodge tap state (e.g. on pause / state change).
function M.resetDodgeTaps()
  dodgeTap.left.lastTime  = 0
  dodgeTap.left.count     = 0
  dodgeTap.right.lastTime = 0
  dodgeTap.right.count    = 0
end

-- ───────────────────────────────────────
-- Gamepad → keyboard bridge
-- ───────────────────────────────────────
-- Called from main.lua's love.gamepadpressed / love.gamepadreleased.
-- Returns the mapped keyboard key (or nil) so main.lua can fire
-- love.keypressed / love.keyreleased with it.

function M.mapButton(gamepadButton)
  if not M.isGamepad() then return nil end
  return M.buttonMap[gamepadButton]
end

--- Process left-stick axes each frame.  Returns a table of
--- {key, pressed} pairs for any simulated key state changes.
function M.updateAxes(joystick)
  if not M.isGamepad() or not joystick then return {} end

  local changes = {}

  local lx = joystick:getGamepadAxis("leftx")
  local ly = joystick:getGamepadAxis("lefty")

  -- Left
  local wantLeft = lx < -M.DEADZONE
  if wantLeft ~= M.axisKeys.leftx_neg then
    M.axisKeys.leftx_neg = wantLeft
    table.insert(changes, { key = "left", pressed = wantLeft })
    -- Register tap for double-tap dodge detection
    if wantLeft then M.registerTap("left") end
  end
  -- Right
  local wantRight = lx > M.DEADZONE
  if wantRight ~= M.axisKeys.leftx_pos then
    M.axisKeys.leftx_pos = wantRight
    table.insert(changes, { key = "right", pressed = wantRight })
    if wantRight then M.registerTap("right") end
  end
  -- Up  (LÖVE Y-axis: negative = up)
  local wantUp = ly < -M.DEADZONE
  if wantUp ~= M.axisKeys.lefty_neg then
    M.axisKeys.lefty_neg = wantUp
    table.insert(changes, { key = "up", pressed = wantUp })
  end
  -- Down
  local wantDown = ly > M.DEADZONE
  if wantDown ~= M.axisKeys.lefty_pos then
    M.axisKeys.lefty_pos = wantDown
    table.insert(changes, { key = "down", pressed = wantDown })
  end

  return changes
end

return M
