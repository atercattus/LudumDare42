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

local borderRadius = 800
local borderRadiusSpeed = 50
local playerSpeed = 400

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
        borderRadiusSpeed = 0
        playerSpeed = 0
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

    portals[#portals + 1] = portal

    return portal
end

local function spawnEnemy(portal)
    local enemy = display.newImageRect(levelGroup, "data/evil.png", 128, 128)
    enemy.name = "enemy"

    enemy.x = portal.x + 128
    enemy.y = portal.y

    enemies[#enemies + 1] = enemy

    return enemy
end

local function updatePortal(portal, deltaTime)
    -- ...
end

local function updatePortals(deltaTime)
    local to_delete = {}
    for i, portal in ipairs(portals) do
        if not isObjInsideBorder(portal) then
            to_delete[#to_delete + 1] = i
        else
            updatePortal(portal, deltaTime)
        end
    end

    for i = #to_delete, 1, -1 do
        local portal = portals[to_delete[i]]
        portal:removeSelf()
        table.remove(portals, to_delete[i])
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

    updatePlayer(deltaTime)
    updateBorderRadius(deltaTime)
    updatePortals(deltaTime)

    -- ...
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
        levelGroup.x = W/2
        levelGroup.y = H/2
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
