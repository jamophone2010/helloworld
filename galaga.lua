-- Galaga-like Game

function love.load()
    love.window.setTitle("Galaga")
    
    -- Window settings
    windowWidth = love.graphics.getWidth()
    windowHeight = love.graphics.getHeight()
    
    -- Player spaceship
    player = {
        x = windowWidth / 2,
        y = windowHeight - 50,
        width = 30,
        height = 30,
        speed = 300,
        health = 3
    }
    
    -- Bullets
    bullets = {}
    bulletSpeed = 500
    bulletWidth = 5
    bulletHeight = 15
    
    -- Enemy bullets
    enemyBullets = {}
    enemyBulletSpeed = 300
    
    -- Enemies
    enemies = {}
    createEnemyFormation()
    enemySpeed = 60
    enemyDirection = 1
    enemyDropDistance = 30
    
    -- Game state
    score = 0
    gameOver = false
    font = love.graphics.newFont(24)
    largeFont = love.graphics.newFont(48)
end

function createEnemyFormation()
    enemies = {}
    local rows = 3
    local cols = 8
    local startX = 50
    local startY = 40
    local spacing = (windowWidth - 100) / cols
    
    for row = 1, rows do
        for col = 1, cols do
            table.insert(enemies, {
                x = startX + col * spacing,
                y = startY + row * 50,
                width = 25,
                height = 25,
                shootTimer = math.random(1, 3),
                active = true
            })
        end
    end
end

function love.update(dt)
    if gameOver then return end
    
    -- Player movement
    if love.keyboard.isDown("left") and player.x > 0 then
        player.x = player.x - player.speed * dt
    end
    if love.keyboard.isDown("right") and player.x + player.width < windowWidth then
        player.x = player.x + player.speed * dt
    end
    
    -- Update bullets
    for i = #bullets, 1, -1 do
        bullets[i].y = bullets[i].y - bulletSpeed * dt
        
        -- Remove bullets that go off screen
        if bullets[i].y < 0 then
            table.remove(bullets, i)
        end
    end
    
    -- Update enemy bullets
    for i = #enemyBullets, 1, -1 do
        enemyBullets[i].y = enemyBullets[i].y + enemyBulletSpeed * dt
        
        -- Check collision with player
        if checkCollision(enemyBullets[i].x, enemyBullets[i].y, 5, 10,
                          player.x, player.y, player.width, player.height) then
            table.remove(enemyBullets, i)
            player.health = player.health - 1
            if player.health <= 0 then
                gameOver = true
            end
        elseif enemyBullets[i].y > windowHeight then
            table.remove(enemyBullets, i)
        end
    end
    
    -- Update enemies
    local minX = math.huge
    local maxX = 0
    
    for i, enemy in ipairs(enemies) do
        if enemy.active then
            minX = math.min(minX, enemy.x)
            maxX = math.max(maxX, enemy.x)
            
            enemy.shootTimer = enemy.shootTimer - dt
            if enemy.shootTimer <= 0 then
                table.insert(enemyBullets, {
                    x = enemy.x + enemy.width / 2,
                    y = enemy.y + enemy.height,
                    width = 5,
                    height = 10
                })
                enemy.shootTimer = math.random(1, 4)
            end
        end
    end
    
    -- Move enemies
    if minX <= 10 or maxX >= windowWidth - 10 then
        enemyDirection = -enemyDirection
        for i, enemy in ipairs(enemies) do
            if enemy.active then
                enemy.y = enemy.y + enemyDropDistance
            end
        end
    end
    
    for i, enemy in ipairs(enemies) do
        if enemy.active then
            enemy.x = enemy.x + enemySpeed * enemyDirection * dt
        end
    end
    
    -- Check bullet-enemy collisions
    for i = #bullets, 1, -1 do
        for j = #enemies, 1, -1 do
            if enemies[j].active and checkCollision(
                bullets[i].x, bullets[i].y, bulletWidth, bulletHeight,
                enemies[j].x, enemies[j].y, enemies[j].width, enemies[j].height) then
                enemies[j].active = false
                table.remove(bullets, i)
                score = score + 10
                break
            end
        end
    end
    
    -- Check if all enemies defeated
    local allDefeated = true
    for i, enemy in ipairs(enemies) do
        if enemy.active then
            allDefeated = false
            break
        end
    end
    
    if allDefeated then
        createEnemyFormation()
        enemySpeed = enemySpeed + 30
    end
    
    -- Check if enemies reached bottom
    for i, enemy in ipairs(enemies) do
        if enemy.active and enemy.y > windowHeight then
            gameOver = true
        end
    end
end

function love.draw()
    love.graphics.setBackgroundColor(0.1, 0.1, 0.2)
    
    -- Draw player
    love.graphics.setColor(0, 1, 0)
    love.graphics.rectangle("fill", player.x, player.y, player.width, player.height)
    
    -- Draw bullets
    love.graphics.setColor(1, 1, 0)
    for i, bullet in ipairs(bullets) do
        love.graphics.rectangle("fill", bullet.x, bullet.y, bulletWidth, bulletHeight)
    end
    
    -- Draw enemies
    love.graphics.setColor(1, 0, 0)
    for i, enemy in ipairs(enemies) do
        if enemy.active then
            love.graphics.rectangle("fill", enemy.x, enemy.y, enemy.width, enemy.height)
            -- Draw alien pattern
            love.graphics.setColor(1, 0.5, 0.5)
            love.graphics.rectangle("fill", enemy.x + 5, enemy.y + 5, 5, 5)
            love.graphics.rectangle("fill", enemy.x + 15, enemy.y + 5, 5, 5)
            love.graphics.setColor(1, 0, 0)
        end
    end
    
    -- Draw enemy bullets
    love.graphics.setColor(1, 0.5, 0)
    for i, bullet in ipairs(enemyBullets) do
        love.graphics.rectangle("fill", bullet.x, bullet.y, bullet.width, bullet.height)
    end
    
    -- Draw UI
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(font)
    love.graphics.print("Score: " .. score, 10, 10)
    love.graphics.print("Health: " .. player.health, 10, 40)
    
    -- Draw game over screen
    if gameOver then
        love.graphics.setFont(largeFont)
        love.graphics.printf("GAME OVER", 0, windowHeight / 2 - 50, windowWidth, "center")
        love.graphics.setFont(font)
        love.graphics.printf("Final Score: " .. score, 0, windowHeight / 2 + 20, windowWidth, "center")
        love.graphics.printf("Press R to Restart", 0, windowHeight / 2 + 60, windowWidth, "center")
    end
end

function love.keypressed(key)
    if key == "space" and not gameOver then
        table.insert(bullets, {
            x = player.x + player.width / 2 - bulletWidth / 2,
            y = player.y,
            width = bulletWidth,
            height = bulletHeight
        })
    end
    
    if key == "r" and gameOver then
        love.load()
    end
end

function checkCollision(x1, y1, w1, h1, x2, y2, w2, h2)
    return x1 < x2 + w2 and
           x1 + w1 > x2 and
           y1 < y2 + h2 and
           y1 + h1 > y2
end
