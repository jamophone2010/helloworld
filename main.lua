-- Pong Game

function love.load()
    -- Set window title
    love.window.setTitle("Pong")

    -- Game settings
    windowWidth = love.graphics.getWidth()
    windowHeight = love.graphics.getHeight()

    -- Paddle settings
    paddleWidth = 20
    paddleHeight = 100
    paddleSpeed = 400

    -- Left paddle (Player 1)
    paddle1 = {
        x = 30,
        y = windowHeight / 2 - paddleHeight / 2,
        width = paddleWidth*2,
        height = paddleHeight,
        dy = 0
    }

    -- Right paddle (Player 2)
    paddle2 = {
        x = windowWidth - 30 - paddleWidth,
        y = windowHeight / 2 - paddleHeight / 2,
        width = paddleWidth,
        height = paddleHeight,
        dy = 0
    }

    -- Ball settings
    ball = {
        x = windowWidth / 2,
        y = windowHeight / 2,
        width = 15,
        height = 15,
        dx = 300,
        dy = 200
    }

    -- Score
    score1 = 0
    score2 = 0

    -- Font
    scoreFont = love.graphics.newFont(32)
end

function love.update(dt)
    -- Player 1 controls (W and S keys)
    if love.keyboard.isDown('w') then
        paddle1.dy = -paddleSpeed
    elseif love.keyboard.isDown('s') then
        paddle1.dy = paddleSpeed
    else
        paddle1.dy = 0
    end

    -- Player 2 controls (Up and Down arrow keys)
    if love.keyboard.isDown('up') then
        paddle2.dy = -paddleSpeed
    elseif love.keyboard.isDown('down') then
        paddle2.dy = paddleSpeed
    else
        paddle2.dy = 0
    end

    -- Update paddle positions
    paddle1.y = paddle1.y + paddle1.dy * dt
    paddle2.y = paddle2.y + paddle2.dy * dt

    -- Keep paddles in bounds
    if paddle1.y < 0 then
        paddle1.y = 0
    elseif paddle1.y > windowHeight - paddle1.height then
        paddle1.y = windowHeight - paddle1.height
    end

    if paddle2.y < 0 then
        paddle2.y = 0
    elseif paddle2.y > windowHeight - paddle2.height then
        paddle2.y = windowHeight - paddle2.height
    end

    -- Update ball position
    ball.x = ball.x + ball.dx * dt
    ball.y = ball.y + ball.dy * dt

    -- Ball collision with top and bottom walls
    if ball.y <= 0 then
        ball.y = 0
        ball.dy = -ball.dy
    end

    if ball.y >= windowHeight - ball.height then
        ball.y = windowHeight - ball.height
        ball.dy = -ball.dy
    end

    -- Ball collision with paddles
    if checkCollision(ball, paddle1) then
        ball.x = paddle1.x + paddle1.width
        ball.dx = -ball.dx * 1.05  -- Increase speed slightly
        ball.dy = ball.dy + paddle1.dy * 0.3  -- Add paddle momentum
    end

    if checkCollision(ball, paddle2) then
        ball.x = paddle2.x - ball.width
        ball.dx = -ball.dx * 1.05
        ball.dy = ball.dy + paddle2.dy * 0.3
    end

    -- Score when ball goes off screen
    if ball.x < 0 then
        score2 = score2 + 1
        resetBall()
    end

    if ball.x > windowWidth then
        score1 = score1 + 1
        resetBall()
    end
end

function love.draw()
    -- Clear screen
    love.graphics.clear(0, 0, 0)

    -- Draw center line
    love.graphics.setColor(1, 1, 1, 0.3)
    for i = 0, windowHeight, 30 do
        love.graphics.rectangle('fill', windowWidth / 2 - 2, i, 4, 15)
    end

    -- Draw paddles
    love.graphics.setColor(1, 1, 1)
    love.graphics.rectangle('fill', paddle1.x, paddle1.y, paddle1.width, paddle1.height)
    love.graphics.rectangle('fill', paddle2.x, paddle2.y, paddle2.width, paddle2.height)

    -- Draw ball
    love.graphics.rectangle('fill', ball.x, ball.y, ball.width, ball.height)

    -- Draw scores
    love.graphics.setFont(scoreFont)
    love.graphics.printf(tostring(score1), windowWidth / 2 - 100, 50, 100, 'center')
    love.graphics.printf(tostring(score2), windowWidth / 2, 50, 100, 'center')

    -- Draw instructions
    love.graphics.setFont(love.graphics.newFont(14))
    love.graphics.printf("Player 1: W/S  |  Player 2: UP/DOWN  |  R: Reset", 0, windowHeight - 25, windowWidth, 'center')
end

function love.keypressed(key)
    -- Reset game with R key
    if key == 'r' then
        score1 = 0
        score2 = 0
        resetBall()
    end

    -- Quit with Escape
    if key == 'escape' then
        love.event.quit()
    end
end

function checkCollision(a, b)
    return a.x < b.x + b.width and
           a.x + a.width > b.x and
           a.y < b.y + b.height and
           a.y + a.height > b.y
end

function resetBall()
    ball.x = windowWidth / 2
    ball.y = windowHeight / 2

    -- Random direction
    ball.dx = (math.random(2) == 1) and 300 or -300
    ball.dy = math.random(-200, 200)
end
