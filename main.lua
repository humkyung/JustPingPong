-- Pong in Love2D
-- 시작 화면: 1=1P(vs AI)  2=2P
-- 조작: P1 W/S  |  P2 Up/Down  |  Space 재시작  |  M 메뉴  |  Esc 종료

local WINDOW_WIDTH   = 800
local WINDOW_HEIGHT  = 600
local PADDLE_WIDTH   = 15
local PADDLE_HEIGHT  = 100
local PADDLE_SPEED   = 400
local PADDLE_MARGIN  = 30
local BALL_SIZE      = 15
local BALL_BASE_SPD  = 300
local SPEED_UP       = 1.05
local WIN_SCORE      = 5

-- AI 튜닝 상수 (값 바꾸면 난이도 조절됨)
local AI_SPEED       = PADDLE_SPEED * 0.75   -- 0.6=쉬움, 0.75=보통, 0.95=어려움
local AI_DEADZONE    = 10                    -- 추적 시 떨림 방지용 허용 오차(px)
local AI_REACT_DIST  = WINDOW_WIDTH * 0.5    -- 공이 이 거리 안에 들어오면 추적 시작

local TRAIL_LENGTH   = 15                    -- 공 잔상 프레임 수
local PARTICLE_BURST = 20                    -- 패들 충돌 시 한 번에 분사할 파티클 수

local player1, player2, ball
local gameState   -- "start" | "play" | "done"
local gameMode    -- "1p" | "2p"
local winner
local fontTitle, fontScore, fontSmall
local hitSound
local hitParticles
local ballTrail

----------------------------------------------------------
-- 초기화
----------------------------------------------------------
function love.load()
    love.window.setTitle("Pong")
    love.window.setMode(WINDOW_WIDTH, WINDOW_HEIGHT)
    love.graphics.setBackgroundColor(0.1, 0.1, 0.15)

    fontTitle = love.graphics.newFont(48)
    fontScore = love.graphics.newFont(64)
    fontSmall = love.graphics.newFont(20)

    -- 효과음 (파일이 없으면 무음으로 진행)
    local ok, src = pcall(love.audio.newSource, "hit.wav", "static")
    if ok then hitSound = src end

    -- 파티클 시스템: 2x2 흰색 텍스처를 점처럼 사용
    local pixel = love.image.newImageData(2, 2)
    pixel:mapPixel(function() return 1, 1, 1, 1 end)
    local particleImg = love.graphics.newImage(pixel)
    hitParticles = love.graphics.newParticleSystem(particleImg, 256)
    hitParticles:setParticleLifetime(0.15, 0.45)
    hitParticles:setSizes(1.5, 0.4)
    hitParticles:setSpeed(80, 260)
    hitParticles:setSpread(math.pi * 2)
    hitParticles:setColors(1, 1, 1, 1, 1, 1, 1, 0)

    resetGame()
    gameState = "start"
end

local function playHit()
    if hitSound then
        hitSound:stop()
        hitSound:play()
    end
end

function resetGame()
    player1 = {
        x = PADDLE_MARGIN,
        y = WINDOW_HEIGHT / 2 - PADDLE_HEIGHT / 2,
        score = 0,
    }
    player2 = {
        x = WINDOW_WIDTH - PADDLE_MARGIN - PADDLE_WIDTH,
        y = WINDOW_HEIGHT / 2 - PADDLE_HEIGHT / 2,
        score = 0,
    }
    resetBall()
    winner = nil
end

function resetBall()
    ball = {
        x  = WINDOW_WIDTH / 2 - BALL_SIZE / 2,
        y  = WINDOW_HEIGHT / 2 - BALL_SIZE / 2,
        dx = (love.math.random(0, 1) == 0 and -1 or 1) * BALL_BASE_SPD,
        dy = love.math.random(-120, 120),
    }
    ballTrail = {}
end

----------------------------------------------------------
-- 충돌 판정 (AABB)
----------------------------------------------------------
local function collides(b, p)
    return b.x < p.x + PADDLE_WIDTH
       and b.x + BALL_SIZE > p.x
       and b.y < p.y + PADDLE_HEIGHT
       and b.y + BALL_SIZE > p.y
end

----------------------------------------------------------
-- AI 패들 업데이트
--   - 공이 자기 쪽으로 올 때만 추적, 가까워질수록 적극적으로
--   - 멀어질 땐 중앙으로 천천히 복귀
----------------------------------------------------------
local function updateAI(dt)
    local paddleCenter = player2.y + PADDLE_HEIGHT / 2
    local targetY

    local ballMovingToAI = ball.dx > 0
    local distanceToAI   = player2.x - ball.x

    if ballMovingToAI and distanceToAI < AI_REACT_DIST then
        targetY = ball.y + BALL_SIZE / 2
    else
        targetY = WINDOW_HEIGHT / 2
    end

    local diff = targetY - paddleCenter
    if math.abs(diff) > AI_DEADZONE then
        local dir = diff > 0 and 1 or -1
        player2.y = player2.y + dir * AI_SPEED * dt
        player2.y = math.max(0, math.min(WINDOW_HEIGHT - PADDLE_HEIGHT, player2.y))
    end
end

----------------------------------------------------------
-- 업데이트
----------------------------------------------------------
function love.update(dt)
    if hitParticles then hitParticles:update(dt) end
    if gameState ~= "play" then return end

    -- P1 조작
    if love.keyboard.isDown("w") then
        player1.y = math.max(0, player1.y - PADDLE_SPEED * dt)
    elseif love.keyboard.isDown("s") then
        player1.y = math.min(WINDOW_HEIGHT - PADDLE_HEIGHT, player1.y + PADDLE_SPEED * dt)
    end

    -- P2 조작 (사람 또는 AI)
    if gameMode == "2p" then
        if love.keyboard.isDown("up") then
            player2.y = math.max(0, player2.y - PADDLE_SPEED * dt)
        elseif love.keyboard.isDown("down") then
            player2.y = math.min(WINDOW_HEIGHT - PADDLE_HEIGHT, player2.y + PADDLE_SPEED * dt)
        end
    else
        updateAI(dt)
    end

    -- 공 이동
    ball.x = ball.x + ball.dx * dt
    ball.y = ball.y + ball.dy * dt

    -- 궤적 기록 (가장 최근이 index 1)
    table.insert(ballTrail, 1, { x = ball.x, y = ball.y })
    while #ballTrail > TRAIL_LENGTH do
        table.remove(ballTrail)
    end

    -- 위/아래 벽 반사
    if ball.y <= 0 then
        ball.y = 0
        ball.dy = -ball.dy
        playHit()
    elseif ball.y + BALL_SIZE >= WINDOW_HEIGHT then
        ball.y = WINDOW_HEIGHT - BALL_SIZE
        ball.dy = -ball.dy
        playHit()
    end

    -- 패들 충돌
    local hitPaddle = false
    if collides(ball, player1) then
        ball.x = player1.x + PADDLE_WIDTH
        ball.dx = math.abs(ball.dx) * SPEED_UP
        local offset = (ball.y + BALL_SIZE / 2) - (player1.y + PADDLE_HEIGHT / 2)
        ball.dy = offset * 6
        hitPaddle = true
    elseif collides(ball, player2) then
        ball.x = player2.x - BALL_SIZE
        ball.dx = -math.abs(ball.dx) * SPEED_UP
        local offset = (ball.y + BALL_SIZE / 2) - (player2.y + PADDLE_HEIGHT / 2)
        ball.dy = offset * 6
        hitPaddle = true
    end

    if hitPaddle then
        playHit()
        hitParticles:setPosition(ball.x + BALL_SIZE / 2, ball.y + BALL_SIZE / 2)
        hitParticles:emit(PARTICLE_BURST)
    end

    -- 득점
    if ball.x < 0 then
        player2.score = player2.score + 1
        if player2.score >= WIN_SCORE then
            winner = (gameMode == "1p") and "AI" or "Player 2"
            gameState = "done"
        else
            resetBall()
        end
    elseif ball.x > WINDOW_WIDTH then
        player1.score = player1.score + 1
        if player1.score >= WIN_SCORE then
            winner, gameState = "Player 1", "done"
        else
            resetBall()
        end
    end
end

----------------------------------------------------------
-- 렌더
----------------------------------------------------------
function love.draw()
    -- 가운데 점선
    love.graphics.setColor(0.3, 0.3, 0.4)
    for y = 0, WINDOW_HEIGHT, 20 do
        love.graphics.rectangle("fill", WINDOW_WIDTH / 2 - 2, y, 4, 10)
    end

    -- 공 궤적 (가장 오래된 것부터 그려서 최신이 위로 오게)
    local ballRadius = BALL_SIZE / 2
    if ballTrail then
        for i = #ballTrail, 1, -1 do
            local pos = ballTrail[i]
            local alpha = (1 - i / TRAIL_LENGTH) * 0.45
            love.graphics.setColor(1, 1, 1, alpha)
            love.graphics.circle("fill", pos.x + ballRadius, pos.y + ballRadius, ballRadius)
        end
    end

    -- 패들 & 공
    love.graphics.setColor(1, 1, 1)
    love.graphics.rectangle("fill", player1.x, player1.y, PADDLE_WIDTH, PADDLE_HEIGHT)
    love.graphics.rectangle("fill", player2.x, player2.y, PADDLE_WIDTH, PADDLE_HEIGHT)
    love.graphics.circle("fill", ball.x + ballRadius, ball.y + ballRadius, ballRadius)

    -- 충돌 파티클
    if hitParticles then
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(hitParticles)
    end

    -- 점수
    love.graphics.setFont(fontScore)
    love.graphics.printf(tostring(player1.score), 0, 40, WINDOW_WIDTH / 2 - 40, "right")
    love.graphics.printf(tostring(player2.score), WINDOW_WIDTH / 2 + 40, 40, WINDOW_WIDTH / 2 - 40, "left")

    -- 플레이 중 모드 표시 (좌하단)
    if gameState == "play" then
        love.graphics.setFont(fontSmall)
        love.graphics.setColor(0.5, 0.5, 0.6)
        local label = (gameMode == "1p") and "1P vs AI" or "2 Players"
        love.graphics.print(label, 10, WINDOW_HEIGHT - 28)
        love.graphics.setColor(1, 1, 1)
    end

    -- 상태별 메시지
    if gameState == "start" then
        love.graphics.setFont(fontTitle)
        love.graphics.printf("PONG", 0, WINDOW_HEIGHT / 2 - 110, WINDOW_WIDTH, "center")
        love.graphics.setFont(fontSmall)
        love.graphics.printf("Press 1  -  1 Player (vs AI)", 0, WINDOW_HEIGHT / 2 - 30, WINDOW_WIDTH, "center")
        love.graphics.printf("Press 2  -  2 Players", 0, WINDOW_HEIGHT / 2, WINDOW_WIDTH, "center")
        love.graphics.setColor(0.5, 0.5, 0.6)
        love.graphics.printf("P1: W / S        P2: Up / Down", 0, WINDOW_HEIGHT / 2 + 50, WINDOW_WIDTH, "center")
        love.graphics.setColor(1, 1, 1)
    elseif gameState == "done" then
        love.graphics.setFont(fontTitle)
        love.graphics.printf(winner .. " wins!", 0, WINDOW_HEIGHT / 2 - 60, WINDOW_WIDTH, "center")
        love.graphics.setFont(fontSmall)
        love.graphics.printf("SPACE: rematch     M: menu", 0, WINDOW_HEIGHT / 2 + 10, WINDOW_WIDTH, "center")
    end
end

----------------------------------------------------------
-- 입력
----------------------------------------------------------
function love.keypressed(key)
    if key == "escape" then
        love.event.quit()
        return
    end

    if gameState == "start" then
        if key == "1" then
            gameMode = "1p"
            gameState = "play"
        elseif key == "2" then
            gameMode = "2p"
            gameState = "play"
        end
    elseif gameState == "done" then
        if key == "space" then
            resetGame()
            gameState = "play"
        elseif key == "m" then
            resetGame()
            gameState = "start"
        end
    elseif gameState == "play" then
        if key == "m" then
            resetGame()
            gameState = "start"
        end
    end
end