local M = {}

-- Format seconds into HH:MM:SS
function M.formatTime(seconds)
  seconds = seconds or 0
  local hours = math.floor(seconds / 3600)
  local mins = math.floor((seconds % 3600) / 60)
  local secs = math.floor(seconds % 60)
  return string.format("%02d:%02d:%02d", hours, mins, secs)
end

-- Parse highScores from string format {1:100,2:200,...}
local function parseHighScores(str)
  local scores = {}
  if not str then return scores end

  -- Remove braces
  str = str:gsub("^{", ""):gsub("}$", "")

  for levelId, score in string.gmatch(str, "(%d+):(%d+)") do
    scores[tonumber(levelId)] = tonumber(score)
  end
  return scores
end

-- Serialize highScores to string format
local function serializeHighScores(scores)
  if not scores or next(scores) == nil then
    return "{}"
  end

  local parts = {}
  for levelId, score in pairs(scores) do
    table.insert(parts, levelId .. ":" .. score)
  end
  table.sort(parts)
  return "{" .. table.concat(parts, ",") .. "}"
end

-- Parse a string set from format [key1|key2|key3]
local function parseStringSet(str)
  local set = {}
  if not str then return set end
  str = str:gsub("^%[", ""):gsub("%]$", "")
  if str == "" then return set end
  for item in str:gmatch("([^|]+)") do
    set[item] = true
  end
  return set
end

-- Serialize a string set to format [key1|key2|key3]
local function serializeStringSet(set)
  if not set or next(set) == nil then
    return "[]"
  end
  local parts = {}
  for key, _ in pairs(set) do
    table.insert(parts, tostring(key))
  end
  table.sort(parts)
  return "[" .. table.concat(parts, "|") .. "]"
end

-- Get save data from a slot
function M.getSave(slot)
  if slot < 1 or slot > 3 then
    return nil
  end

  local filename = "save_" .. slot .. ".dat"
  local contents, err = love.filesystem.read(filename)

  if not contents then
    return nil
  end

  -- Parse the save data
  local saveData = {}

  -- Extract highScores first (has nested structure)
  local highScoresStr = contents:match("highScores:({[^}]*})")
  if highScoresStr then
    saveData.highScores = parseHighScores(highScoresStr)
  else
    saveData.highScores = {}
  end

  -- Extract purchasedShips (string set in [brackets])
  local purchasedShipsStr = contents:match("purchasedShips:(%[[^%]]*%])")
  saveData.purchasedShips = parseStringSet(purchasedShipsStr)
  -- Default: starwing is always purchased
  if next(saveData.purchasedShips) == nil then
    saveData.purchasedShips = { starwing = true }
  end

  -- Extract unlockedQuests (string set in [brackets])
  local unlockedQuestsStr = contents:match("unlockedQuests:(%[[^%]]*%])")
  saveData.unlockedQuests = parseStringSet(unlockedQuestsStr)

  -- Parse remaining simple key:value pairs
  for key, value in string.gmatch(contents, "([%w_]+):([^,}%]]+)") do
    if key == "highScores" or key == "purchasedShips" or key == "unlockedQuests" then
      -- Already handled above
    elseif key == "credits" or key == "notes" or key == "level" or key == "timePlayed" or key == "currentFloor" then
      saveData[key] = tonumber(value)
    elseif key == "hasMegaAntenna" or key == "hasPowerAmplifier" then
      saveData[key] = (value == "true")
    elseif key == "selectedShip" then
      -- Ship ID - strip quotes
      saveData[key] = value:match("^'(.*)'") or value
    else
      -- String value - strip quotes
      saveData[key] = value:match("^['\"](.*)['\".]?$") or value
    end
  end

  -- Defaults for new fields
  saveData.currentFloor = saveData.currentFloor or 2

  return saveData
end

-- Save game data to a slot
function M.saveSave(slot, saveData)
  if slot < 1 or slot > 3 then
    return false
  end

  local filename = "save_" .. slot .. ".dat"

  -- Format save data as string
  local saveString = string.format(
    "name:'%s',credits:%d,notes:%d,level:%d,lastPlayed:'%s',timePlayed:%d,selectedShip:'%s',hasMegaAntenna:%s,hasPowerAmplifier:%s,currentFloor:%d,highScores:%s,purchasedShips:%s,unlockedQuests:%s",
    saveData.name or "Unnamed",
    saveData.credits or 0,
    saveData.notes or 0,
    saveData.level or 1,
    os.date("%Y-%m-%d %H:%M"),
    saveData.timePlayed or 0,
    saveData.selectedShip or "starwing",
    saveData.hasMegaAntenna and "true" or "false",
    saveData.hasPowerAmplifier and "true" or "false",
    saveData.currentFloor or 2,
    serializeHighScores(saveData.highScores),
    serializeStringSet(saveData.purchasedShips or { starwing = true }),
    serializeStringSet(saveData.unlockedQuests or {})
  )

  local success, err = love.filesystem.write(filename, saveString)
  if not success then
    print("Error saving: " .. err)
  end
  return success
end

-- Delete a save file
function M.deleteSave(slot)
  if slot < 1 or slot > 3 then
    return false
  end

  local filename = "save_" .. slot .. ".dat"
  return love.filesystem.remove(filename)
end

return M
