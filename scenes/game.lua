local composer = require("composer")

local round = math.round
local sqrt = math.sqrt
local tonumber = tonumber

local randomInt = require('utils').randomInt
local sqr = require('utils').sqr
local vec2Angle = require('utils').vectorToAngle
local vectorLen = require('utils').vectorLen

local pressedKeys = {
    mouseLeft = false,
    left = false,
    right = false,
    top = false,
    down = false,
}
local mousePos = {
    x = 0,
    y = 0,
}

local W, H
local scene = composer.newScene()
local levelGroup

local border
local player
local enemies = {}
local portals = {}
local ammoInFlight = {}
local ammoInCache = {}
local scoresText

local aim

local gameInPause = false

local borderRadius = 1200
local borderRadiusSpeed = 50
local playerSpeed = 400

local enemySpeed = 70 -- ���� ��� ���� ����������

local gunsCount
local gunsImageSheet
local ammoImageSheet

local ammoWidth = 16
local ammoHeight = 6

local gunTypePistol = 1
local gunTypeShotgun = 2
local gunTypeMachinegun = 3
local gunTypeRocketLauncher = 4
local gunTypeMaxValue = gunTypeRocketLauncher

local gunsInfo = {
    -- ����� ���������� �������� �� ���� ����� (����������� ��� �������������)
    lastShots = {},
    -- ��������� ����� ���������� ������ �����
    shotIntervals = {
        [gunTypePistol] = 200,
        [gunTypeShotgun] = 400,
        [gunTypeMachinegun] = 100,
        [gunTypeRocketLauncher] = 1000,
    },
    -- �������� �������� �� �����
    speeds = {
        [gunTypePistol] = 1400,
        [gunTypeShotgun] = 1100,
        [gunTypeMachinegun] = 2500,
        [gunTypeRocketLauncher] = 700,
    },
    -- ���������� �� �������� �� ����� ������ (����� ������ ������� ������ ����)
    barrelLengths = {
        [gunTypePistol] = 64,
        [gunTypeShotgun] = 70,
        [gunTypeMachinegun] = 116,
        [gunTypeRocketLauncher] = 108,
    },
}

local function switchGun(num)
    if num < gunTypePistol or num > gunTypeMaxValue then
        return
    elseif gameInPause then
        return
    end

    player.gun.gunType = num
    player.gun.fill.frame = num
end

local function ammoGet(gunType)
    local ammo
    if #ammoInCache > 0 then
        ammo = ammoInCache[#ammoInCache]
        table.remove(ammoInCache, #ammoInCache)
        ammo.isVisible = true
    else
        ammo = display.newRect(0, 0, ammoWidth, ammoHeight)
        levelGroup:insert(ammo)
        ammo.name = "ammo"
        ammo.fill = { type = "image", sheet = ammoImageSheet, frame = gunType }
    end

    ammo.gunType = gunType
    ammo.fill.frame = gunType
    ammo.x = 0
    ammo.y = 0
    ammo.rotation = 0
    ammo.speed = gunsInfo.speeds[gunType]

    ammoInFlight[#ammoInFlight + 1] = ammo

    return ammo
end

local function ammoPut(ammo)
    ammo.isVisible = false
    ammoInCache[#ammoInCache + 1] = ammo
end

local function onKey(event)
    if event.phase == 'down' then
        if event.keyName == 'space' then -- ToDo: ������� �� ������
            gameInPause = not gameInPause
            return
        elseif "1" <= event.keyName and event.keyName <= "4" then
            switchGun(tonumber(event.keyName))
        end
    end

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

local function onMouseEvent(event)
    mousePos.x = event.x - W / 2
    mousePos.y = event.y - H / 2

    pressedKeys.mouseLeft = event.isPrimaryButtonDown

    aim.x = event.x
    aim.y = event.y
end

local function setupBorder()
    border = display.newCircle(levelGroup, 0, 0, borderRadius)
    border:setFillColor(1, 1, 1, 0.3)
    border.strokeWidth = 30
    border:setStrokeColor(0.4, 0.8, 1)
end

local function setupAim(sceneGroup)
    aim = display.newImageRect(sceneGroup, "data/aim.png", 32, 32)
    aim.name = "aim"
    aim.anchorX = 0.5
    aim.anchorY = 0.5
end

local function setupScores(sceneGroup)
    scoresText = display.newText({
        parent = sceneGroup,
        text = "",
        width = W,
        font = 'data/kitchen-police.regular.ttf', -- https://www.1001fonts.com/kitchen-police-font.html
        fontSize = 42,
        align = 'left',
    })
    scoresText:setFillColor(1, 1, 0.4)
    scoresText.anchorX = 0
    scoresText.anchorY = 0
    scoresText.x = 0
    scoresText.y = 0
end

local function updateScores()
    scoresText.text = "Radius: " .. round(borderRadius)
end

local function isObjInsideBorder(obj, customSize)
    local objSize
    if customSize == nil then
        objSize = sqrt(sqr(obj.width) + sqr(obj.height))
    else
        objSize = customSize
    end

    objSize = objSize / (1 / 0.7) -- ��� �������� � �������

    local distanceFromCentre = sqrt(sqr(obj.x) + sqr(obj.y))

    return (distanceFromCentre + (objSize / 2)) < borderRadius
end

local function moveTo(obj, target, speed, deltaTime)
    local vec = { x = target.x - obj.x, y = target.y - obj.y }
    local vecLen = vectorLen(vec)

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

local function calcMoveForwardPosition(obj, delta)
    local angle = math.rad(obj.rotation)
    local vec = { x = math.cos(angle), y = math.sin(angle) }

    vec.x = vec.x * delta
    vec.y = vec.y * delta

    return { x = obj.x + vec.x, y = obj.y + vec.y }
end

local function moveForward(obj, delta)
    local pos = calcMoveForwardPosition(obj, delta)
    obj.x = pos.x
    obj.y = pos.y
end

local function shot()
    local ammo = ammoGet(player.gun.gunType)
    ammo.x = player.x
    ammo.y = player.y

    local angle = player.gun.rotation
    if player.xScale < 0 then
        angle = -angle + 180
    end
    ammo.rotation = angle

    local barrelLength = gunsInfo.barrelLengths[player.gun.gunType]

    local pos = calcMoveForwardPosition(ammo, barrelLength)
    ammo.x = pos.x
    ammo.y = pos.y
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

    -- ����������� ������
    player.x = player.x + dX
    player.y = player.y + dY

    -- "������" ������� �� �������
    levelGroup.x = levelGroup.x - dX
    levelGroup.y = levelGroup.y - dY

    -- ����������� �������
    local dir = (mousePos.x > 0) and 1 or -1
    player.xScale = dir

    -- ����������� �����
    local vec = { x = mousePos.x, y = -mousePos.y }
    if vec.y == 0 then
        return
    end
    local angle = vec2Angle(vec)

    if player.xScale < 0 then
        angle = 360 - angle
    end
    player.gun.rotation = angle - 90

    -- ��������
    if pressedKeys.mouseLeft then
        local currentTime = system.getTimer()
        local delta = currentTime - gunsInfo.lastShots[player.gun.gunType]
        if delta >= gunsInfo.shotIntervals[player.gun.gunType] then
            gunsInfo.lastShots[player.gun.gunType] = currentTime
            shot()
        end
    end
end

local function updateBorderRadius(deltaTime)
    borderRadius = borderRadius - borderRadiusSpeed * deltaTime
    if borderRadius < 0 then
        borderRadius = 0
    end
    border.path.radius = borderRadius

    updateScores()

    if not isObjInsideBorder(player, player.playerImage.width * sqrt(2)) then
        gameInPause = true
        border:setStrokeColor(1, 0.3, 0.4)
    end
end

local function setupPlayer()
    local playerImage = display.newImageRect("data/man.png", 128, 128)
    playerImage.name = "player_image"

    local gun = display.newRect(0, 0, 140, 50)
    gun.name = "player_gun"
    gun.fill = { type = "image", sheet = gunsImageSheet, frame = 1 }
    gun.anchorX = 0.2
    gun.anchorY = 0.2

    player = display.newGroup()
    levelGroup:insert(player)
    player.name = "player"

    player:insert(playerImage)
    player.playerImage = playerImage
    player:insert(gun)
    player.gun = gun

    switchGun(gunTypePistol)
end

local function spawnPortal(first)
    local portal = display.newImageRect(levelGroup, "data/portal.png", 128, 128)
    portal.name = "portal"

    local radius = borderRadius * 0.8
    if first then
        -- � ������ ��� ������� ������ �������. �����, � ������ ��� ����� :)
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

    -- ToDo: ����� �������� � ������� ������
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
    moveTo(enemy, { x = player.x, y = player.y }, enemySpeed, deltaTime)
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

local function updateAmmo(ammo, deltaTime)
    moveForward(ammo, ammo.speed * deltaTime)
end

local function updateAmmos(deltaTime)
    local to_delete = {}
    for i, ammo in ipairs(ammoInFlight) do
        -- ToDo: �������� � ��������� � �������
        if not isObjInsideBorder(ammo) then
            to_delete[#to_delete + 1] = i
        else
            updateAmmo(ammo, deltaTime)
        end
    end

    for i = #to_delete, 1, -1 do
        local ammo = ammoInFlight[to_delete[i]]
        table.remove(ammoInFlight, to_delete[i])
        ammoPut(ammo)
    end
end

local function setupGunsAndAmmo()
    gunsCount = 4
    local options = {
        width = 140,
        height = 50,
        numFrames = gunsCount,
    }
    gunsImageSheet = graphics.newImageSheet("data/guns.png", options)

    local options = {
        width = ammoWidth,
        height = ammoHeight,
        numFrames = gunsCount,
    }
    ammoImageSheet = graphics.newImageSheet("data/ammo.png", options)

    for i = 1, gunsCount do
        gunsInfo.lastShots[i] = 0
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
    updateAmmos(deltaTime)
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

        setupAim(sceneGroup)

        setupScores(sceneGroup)
        updateScores()

        setupGunsAndAmmo()

        setupBorder()
        setupPlayer()
        local portal = spawnPortal(true)
        --local enemy = spawnEnemy(portal)

        Runtime:addEventListener("enterFrame", onEnterFrame)
        Runtime:addEventListener("key", onKey)
        Runtime:addEventListener("mouse", onMouseEvent)
    end
end

function scene:hide(event)
    if (event.phase == "did") then
        Runtime:removeEventListener("enterFrame", onEnterFrame)
        Runtime:removeEventListener("key", onKey)
        Runtime:removeEventListener("mouse", onMouseEvent)
    end
end

scene:addEventListener("create", scene)
scene:addEventListener("destroy", scene)
scene:addEventListener("show", scene)
scene:addEventListener("hide", scene)

return scene
