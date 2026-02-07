local M = {}

local fonts = {}
local crawlText = "A long time ago, in a galaxy far, far away....\n\n" ..
"Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. " ..
"Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. " ..
"Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. " ..
"Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.\n\n" ..
"Sed ut perspiciatis unde omnis iste natus error sit voluptatem accusantium doloremque laudantium, " ..
"totam rem aperiam, eaque ipsa quae ab illo inventore veritatis et quasi architecto beatae vitae dicta sunt explicabo.\n\n" ..
"Prepare yourself for an epic adventure..."

local startTime = 0
local duration = 100 -- Duration of crawl in seconds
local isComplete = false

M.onComplete = nil

function M.load()
  fonts.crawl = love.graphics.newFont(60)
  fonts.title = love.graphics.newFont(60)
  startTime = love.timer.getTime()
  isComplete = false
end

function M.update(dt)
  local elapsedTime = love.timer.getTime() - startTime
  if elapsedTime >= duration then
    isComplete = true
    if M.onComplete then
      M.onComplete()
    end
  end
end

function M.draw()
  -- Black background
  love.graphics.setColor(0, 0, 0)
  love.graphics.rectangle("fill", 0, 0, 1366, 768)

  -- Title at top
  love.graphics.setFont(fonts.title)
  love.graphics.setColor(1, 1, 0)
  love.graphics.printf("STARLIGHT SYMPHONY", 0, 80, 1366, "center")

  -- Crawl text with perspective effect
  local elapsedTime = love.timer.getTime() - startTime
  local progress = math.min(elapsedTime / duration, 1)
  
  -- Calculate position and scale
  local startY = 768
  local endY = -400
  local currentY = startY + (endY - startY) * progress
  
  -- Scale changes over time (gets smaller as it goes away)
  local startScale = 0.5
  local endScale = 0.3
  local currentScale = startScale + (endScale - startScale) * progress
  
  -- Opacity fades out
  local opacity = 1 - progress
  
  love.graphics.setFont(fonts.crawl)
  love.graphics.setColor(1, 1, 0, opacity)
  
  -- Draw text with scaling effect centered
  local centerX = 683 -- Center of screen width
  local centerY = currentY
  
  -- Save graphics state
  love.graphics.push()
  love.graphics.translate(centerX, centerY)
  love.graphics.scale(currentScale)
  
  -- Draw the crawl text centered at origin
  love.graphics.printf(crawlText, -683, 0, 1366, "center")
  
  love.graphics.pop()

  -- Skip instruction
  love.graphics.setFont(love.graphics.newFont(14))
  love.graphics.setColor(0.7, 0.7, 0.7, 0.5)
  love.graphics.printf("Press SPACE to skip", 0, 700, 1366, "center")
end

function M.keypressed(key)
  if key == "space" or key == "return" or key == "escape" then
    isComplete = true
    if M.onComplete then
      M.onComplete()
    end
  end
end

function M.mousepressed(x, y, button)
  -- Not used
end

return M
