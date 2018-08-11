local composer = require("composer")

local randomInt = require('utils').randomInt

local pressedKeys = {
    left = false,
    right = false,
    top = false,
    down = false,
}

local W, H
local scene = composer.newScene()
local sceneGroup
local levelGroup

local border
local player
local enemies = {}
local portals = {}

local borderRadius = 450
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

    if pressedKeys.left or pressedKeys.right then
        local dir = pressedKeys.left and -1 or 1
        local dX = dir * playerSpeed * deltaTime
        levelGroup.x = levelGroup.x - dX
    end
    if pressedKeys.top or pressedKeys.down then
        local dir = pressedKeys.top and -1 or 1
        local dY = dir * playerSpeed * deltaTime
        levelGroup.y = levelGroup.y - dY
    end

    -- ...
end

local function setupBorder()
    border = display.newCircle(levelGroup, W / 2, H / 2, borderRadius)
    border:setFillColor(0, 0, 0, 0)
    border.strokeWidth = 30
    border:setStrokeColor(0.4, 0.8, 1)
end

local function spawnPlayer()
    player = display.newImageRect(sceneGroup, "data/man.png", 128, 128)
    player.x = W / 2
    player.y = H / 2
end

local function spawnPortal()
    --    print("borderRadius", borderRadius)

    local portal = display.newImageRect(levelGroup, "data/portal.png", 128, 128)
    portal.x = W / 2 + randomInt(-2, 2) * portal.width
    portal.y = H / 2 + randomInt(-2, 2) * portal.height

    portals[#portals + 1] = portal

    return portal
end

local function spawnEnemy(portal)
    local enemy = display.newImageRect(levelGroup, "data/evil.png", 128, 128)
    enemy.x = portal.x + 128
    enemy.y = portal.y

    enemies[#enemies + 1] = enemy

    return enemy
end

-- ===========================================================================================

function scene:create(event)
    --ambientSound = audio.loadSound("data/ambient-menu.wav")
end

function scene:destroy(event)
    --audio.dispose(ambientSound)
end

function scene:show(event)
    sceneGroup = self.view

    if (event.phase == "will") then
        W, H = display.contentWidth, display.contentHeight

        levelGroup = display.newGroup()
        sceneGroup:insert(levelGroup)

        setupBorder()
        spawnPlayer()
        local portal = spawnPortal()
        local enemy = spawnEnemy(portal)

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
