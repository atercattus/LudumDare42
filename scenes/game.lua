local composer = require("composer")

local sqrt = math.sqrt
local randomInt = require('utils').randomInt
local sqr = require('utils').sqr

local pressedKeys = {
    left = false,
    right = false,
    top = false,
    down = false,
}

local W, H
local scene = composer.newScene()
local levelGroup

local border
local player
local enemies = {}
local portals = {}
local scoresText

local gameInPause = false

local borderRadius = 800
local borderRadiusSpeed = 50
local playerSpeed = 400

local enemySpeed = 70 -- пока для всех одинаковая

local function onKey(event)
    if event.keyName == 'left' or event.keyName == 'a' then
        pressedKeys.left = event.phase == 'down'
    elseif event.keyName == 'right' or event.keyName == 'd' then
        pressedKeys.right = event.phase == 'down'
    elseif event.keyName == 'up' or event.keyName == 'w' then
        pressedKeys.top = event.phase == 'down'
    elseif event.keyName == 'down' or event.keyName == 's' then
        pressedKeys.down = event.phase == 'down'
    end
    return true
end

local function setupBorder()
    border = display.newCircle(levelGroup, 0, 0, borderRadius)
    border:setFillColor(0, 0, 0, 0)
    border.strokeWidth = 30
    border:setStrokeColor(0.4, 0.8, 1)
end

local function setupScores(sceneGroup)
    scoresText = display.newText({
        parent = sceneGroup,
        text = "",
        width = W,
        font = 'data/kitchen-police.regular.ttf', -- https://www.1001fonts.com/kitchen-police-font.html
        fontSize = 42,
        align = 'center',
    })
    scoresText:setFillColor(1, 1, 0.4)
    scoresText.anchorX = 0.5
    scoresText.anchorY = 0
    scoresText.x = W / 2
    scoresText.y = 0
end

local function updateScores()
    scoresText.text = "Radius: " .. math.round(borderRadius)
end

local function isObjInsideBorder(obj)
    local halfObjSize = sqrt(sqr(obj.width) + sqr(obj.height)) / (2 / 0.7) -- 0.7 для близости к спрайту
    local distanceFromCentre = sqrt(sqr(obj.x) + sqr(obj.y))

    return (distanceFromCentre + halfObjSize) < borderRadius
end

local function moveTo(obj, target, speed, deltaTime)
    local vec = { x = target.x - obj.x, y = target.y - obj.y }
    local vecLen = sqrt(sqr(vec.x) + sqr(vec.y))

    local distance = speed * deltaTime
    if vecLen < distance then
        obj.x = target.x
        obj.y = target.y
        return
    end

    vec.x = vec.x / vecLen * distance
    vec.y = vec.y / vecLen * distance

    obj.x = obj.x + vec.x
    obj.y = obj.y + vec.y
end

local function updatePlayer(deltaTime)
    local dX, dY = 0, 0

    if pressedKeys.left or pressedKeys.right then
        local dir = pressedKeys.left and -1 or 1
        dX = dir * playerSpeed * deltaTime
    end
    if pressedKeys.top or pressedKeys.down then
        local dir = pressedKeys.top and -1 or 1
        dY = dir * playerSpeed * deltaTime
    end

    -- перемещение игрока
    player.x = player.x + dX
    player.y = player.y + dY

    -- "камера" следует за игроком
    levelGroup.x = levelGroup.x - dX
    levelGroup.y = levelGroup.y - dY
end

local function updateBorderRadius(deltaTime)
    borderRadius = borderRadius - borderRadiusSpeed * deltaTime
    if borderRadius < 0 then
        borderRadius = 0
    end
    border.path.radius = borderRadius

    updateScores()

    if not isObjInsideBorder(player) then
        gameInPause = true
        border:setStrokeColor(1, 0.3, 0.4)
    end
end

local function spawnPlayer()
    player = display.newImageRect(levelGroup, "data/man.png", 128, 128)
    player.name = "player"
end

local function spawnPortal(first)
    local portal = display.newImageRect(levelGroup, "data/portal.png", 128, 128)
    portal.name = "portal"

    local radius = borderRadius * 0.8
    if first then
        -- в первый раз создаем портал поближе. может, и всегда так будет :)
        radius = radius / 2
    end

    local A = randomInt(360)
    local angle = math.rad(A - 90)
    portal.x = math.cos(angle) * radius
    portal.y = math.sin(angle) * radius

    portal.lastTimeEnemySpawn = 0

    portals[#portals + 1] = portal

    return portal
end

local function spawnEnemy(portal)
    local enemy = display.newImageRect(levelGroup, "data/evil.png", 128, 128)
    enemy.name = "enemy"

    -- ToDo: нужно спавнить в сторону центра
    enemy.x = portal.x + randomInt(-1, 1) * 128
    enemy.y = portal.y + randomInt(-1, 1) * 128

    enemies[#enemies + 1] = enemy

    return enemy
end

local function updatePortal(portal, deltaTime)
    local currentTime = system.getTimer()
    local delta = currentTime - portal.lastTimeEnemySpawn
    if delta > 2000 then
        portal.lastTimeEnemySpawn = currentTime
        spawnEnemy(portal)
    end

    -- ...
end

local function updatePortals(deltaTime)
    for i, portal in ipairs(portals) do
        if not isObjInsideBorder(portal) then
            moveTo(portal, { x = 0, y = 0 }, borderRadiusSpeed, deltaTime)
        end
        updatePortal(portal, deltaTime)
    end
end

local function updateEnemy(enemy, deltaTime)
    moveTo(enemy, {x=player.x, y=player.y}, enemySpeed, deltaTime)
end

local function updateEnemies(deltaTime)
    local to_delete = {}

    for i, enemy in ipairs(enemies) do
        if not isObjInsideBorder(enemy) then
            to_delete[#to_delete + 1] = i
        else
            updateEnemy(enemy, deltaTime)
        end
    end

    for i = #to_delete, 1, -1 do
        local enemy = enemies[to_delete[i]]
        enemy:removeSelf()
        table.remove(enemies, to_delete[i])
    end
end

local lastEnterFrameTime
local function onEnterFrame(event)
    if (not lastEnterFrameTime) then
        lastEnterFrameTime = system.getTimer()
        return
    end
    local deltaTime = (event.time - lastEnterFrameTime) / 1000
    lastEnterFrameTime = event.time
    if deltaTime <= 0 then
        return
    end

    if gameInPause then
        return
    end

    updatePlayer(deltaTime)
    updateBorderRadius(deltaTime)
    updatePortals(deltaTime)
    updateEnemies(deltaTime)
end

-- ===========================================================================================

function scene:create(event)
    --ambientSound = audio.loadSound("data/ambient-menu.wav")
end

function scene:destroy(event)
    --audio.dispose(ambientSound)
end

function scene:show(event)
    local sceneGroup = self.view

    if (event.phase == "will") then
        W, H = display.contentWidth, display.contentHeight

        levelGroup = display.newGroup()
        levelGroup.x = W / 2
        levelGroup.y = H / 2
        sceneGroup:insert(levelGroup)

        setupScores(sceneGroup)
        updateScores()

        setupBorder()
        spawnPlayer()
        local portal = spawnPortal(true)
        --local enemy = spawnEnemy(portal)

        Runtime:addEventListener("enterFrame", onEnterFrame)
        Runtime:addEventListener("key", onKey)
    end
end

function scene:hide(event)
    if (event.phase == "did") then
        Runtime:removeEventListener("enterFrame", onEnterFrame)
        Runtime:removeEventListener("key", onKey)
    end
end

scene:addEventListener("create", scene)
scene:addEventListener("destroy", scene)
scene:addEventListener("show", scene)
scene:addEventListener("hide", scene)

return scene
