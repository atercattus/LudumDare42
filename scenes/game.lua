local composer = require("composer")
local utils = require('utils')

local round = math.round
local sqrt = math.sqrt
local tonumber = tonumber

local randomInt = utils.randomInt
local enabled = utils.enabled
local sqr = utils.sqr
local vectorToAngle = utils.vectorToAngle
local vectorLen = utils.vectorLen
local distanceBetween = utils.distanceBetween
local vector = utils.vector
local hasCollidedCircle = utils.hasCollidedCircle

-- ===============
-- ���������
-- ===============

local fontName = 'data/ErikaOrmig.ttf'

local damageFromPortal = 3
local damageFromBorder = 99999

local enemyAmmoWidth = 32
local enemyAmmoHeight = 32

local ammoIconScale = 2.5

local ammoWidth = 32
local ammoHeight = 16

local ammoBlockWidth = 24
local ammoBlockHeight = 32

local enemyWidth = 128
local enemyHeight = 128

local gunTypePistol = 1
local gunTypeShotgun = 2
local gunTypeMachinegun = 3
local gunTypeRocketLauncher = 4
local gunTypeMaxValue = gunTypeRocketLauncher

local gunTypeDropHeart = gunTypeMaxValue + 1 -- ������� ��� ��������� ��������

local rocketDamageRadius = 300
local explosionImageSize = 64

local groundSize = 1024

local gunsInfo = {
    -- ����� ���������� �������� �� ���� ����� (����������� ��� �������������)
    lastShots = {},
    -- ��������� ����� ���������� ������ �����
    shotIntervals = {
        [gunTypePistol] = 200,
        [gunTypeShotgun] = 450,
        [gunTypeMachinegun] = 100,
        [gunTypeRocketLauncher] = 700,
    },
    -- �������� �������� �� �����
    speeds = {
        [gunTypePistol] = 1400,
        [gunTypeShotgun] = 1100,
        [gunTypeMachinegun] = 2500,
        [gunTypeRocketLauncher] = 1000,
    },
    -- ���������� �� �������� �� ����� ������ (����� ������ ������� ������ ����)
    barrelLengths = {
        [gunTypePistol] = 40,
        [gunTypeShotgun] = 60,
        [gunTypeMachinegun] = 70,
        [gunTypeRocketLauncher] = 80,
    },
    -- ���� �� ������
    damages = {
        [gunTypePistol] = 4,
        [gunTypeShotgun] = 2,
        [gunTypeMachinegun] = 5,
        [gunTypeRocketLauncher] = 10,
    },
}

local portalHP = 20

local enemyGuardMaxDistance = 270 -- ������������ ����������, �� ������� ����� ������� �� ������ �������
local enemyShooterDistance = 500 -- ����������, �� ������� ������� ��������� ��������� �� ������

local enemyShootMaxDistance = 800 -- ������������ ���������� �� ����� �� ������, ��� ������� ���� ����� �������� (����� ������� �� ������ ����� ���� �������)

local enemyShooterShootInterval = 2000 -- ��� ����� ������� ��������
local enemyShooterShootSpeed = 400 -- �������� ��������� �������

local enemyGuardShootInterval = 6000 -- ��� ����� ����� ��������
local enemyGuardShootSpeed = 200 -- �������� ��������� ������

local enemyTypePortal = 0
local enemyTypeSlow = 2 -- �������� ���� �� ������
local enemyTypeShooter = 1 -- ��������� ��������� �� ���������� ��������. � ��������
local enemyTypeGuard = 3 -- �������� �������. ��������, ���� ������ ���
local enemyTypeFast = 4 -- ����� �� ������ � ��� �������� ������
local enemyTypeMaxValue = enemyTypeFast

local enemyInfo = {
    speeds = {
        [enemyTypeSlow] = 70,
        [enemyTypeFast] = 300,
        [enemyTypeShooter] = 100,
        [enemyTypeGuard] = 60,
    },
    damages = {
        [enemyTypeSlow] = 1,
        [enemyTypeFast] = 2,
        [enemyTypeShooter] = 2,
        [enemyTypeGuard] = 3,
    },
    HPs = {
        [enemyTypeSlow] = 2,
        [enemyTypeFast] = 5,
        [enemyTypeShooter] = 4,
        [enemyTypeGuard] = 99999, -- �� ��������� ��������
    },
    scales = {
        [enemyTypeSlow] = 0.9,
        [enemyTypeFast] = 1,
        [enemyTypeShooter] = 1.1,
        [enemyTypeGuard] = 1.6,
    },
}

-- ===============
-- ��������
-- ===============

local scene = composer.newScene()

function scene:updateActiveGunInUI(currentGunType)
    if currentGunType == nil then
        currentGunType = gunTypePistol
    end

    for gunType, text in ipairs(self.ammoBlocksTexts) do
        if currentGunType == gunType then
            text:setFillColor(1, 1, 1)
            text.size = 48
        else
            text:setFillColor(1, 1, 0.4)
            text.size = 42
        end
    end
end

function scene:switchGun(num)
    if num < gunTypePistol or num > gunTypeMaxValue then
        return
    elseif self.gameInPause then
        return
    end

    self:updateActiveGunInUI(num)

    self.player.gun.gunType = num
    self.player.gun.fill.frame = num
end

function scene:ammoGet(gunType)
    local ammo
    if #self.ammoInCache > 0 then
        ammo = self.ammoInCache[#self.ammoInCache]
        table.remove(self.ammoInCache, #self.ammoInCache)
        ammo.isVisible = true
    else
        ammo = display.newRect(0, 0, ammoWidth, ammoHeight)
        self.levelGroup:insert(ammo)
        ammo.name = "ammo"
        ammo.fill = { type = "image", sheet = self.ammoImageSheet, frame = gunType }
    end

    ammo.gunType = gunType
    ammo.fill.frame = gunType
    ammo.x = 0
    ammo.y = 0
    ammo.rotation = 0
    ammo.speed = gunsInfo.speeds[gunType]

    self.ammoInFlight[#self.ammoInFlight + 1] = ammo

    return ammo
end

function scene:ammoPut(ammo)
    ammo.isVisible = false
    self.ammoInCache[#self.ammoInCache + 1] = ammo
end

function scene:onKey(event)
    if event.phase == 'down' then
        if "1" <= event.keyName and event.keyName <= "4" then
            self:switchGun(tonumber(event.keyName))
        elseif "f12" == event.keyName then -- ToDo: �������� �� ������
            for gunType, _ in ipairs(self.ammoAllowed) do
                self.ammoAllowed[gunType] = 1000 + self.ammoAllowed[gunType]
                self:updateAmmoAllowed(gunType)
            end
        elseif "f11" == event.keyName then -- ToDo: �������� �� ������
            self.playerHP = self.playerHP + 1000
            self:updateHeart()
        end
    end

    if event.keyName == 'left' or event.keyName == 'a' then
        self.pressedKeys.left = event.phase == 'down'
    elseif event.keyName == 'right' or event.keyName == 'd' then
        self.pressedKeys.right = event.phase == 'down'
    elseif event.keyName == 'up' or event.keyName == 'w' then
        self.pressedKeys.top = event.phase == 'down'
    elseif event.keyName == 'down' or event.keyName == 's' then
        self.pressedKeys.down = event.phase == 'down'
    end
    return true
end

function scene:onMouseEvent(event)
    self.mousePos.x = event.x - self.W / 2
    self.mousePos.y = event.y - self.H / 2

    if event.scrollY ~= 0 then
        local currentTime = system.getTimer()
        if self.mouseScrollLastTime + 100 < currentTime then
            self.mouseScrollLastTime = currentTime

            local nextGunType = self.player.gun.gunType + ((event.scrollY < 0) and -1 or 1)
            if nextGunType < gunTypePistol then
                nextGunType = gunTypeMaxValue
            elseif nextGunType > gunTypeMaxValue then
                nextGunType = gunTypePistol
            end
            self:switchGun(nextGunType)
        end
        return
    end

    self.pressedKeys.mouseLeft = event.isPrimaryButtonDown

    self.aim.x = event.x
    self.aim.y = event.y
end

function scene:setupBorder()
    self.border = display.newCircle(self.levelGroup, 0, 0, self.borderRadius)
    self.border.fill = { type = "image", filename = "data/ground.png" }
    self.border.strokeWidth = 30
    self.border:setStrokeColor(1, 0.3, 0.3)
end

function scene:setupAim()
    self.aim = display.newImageRect(self.view, "data/aim.png", 32, 32)
    self.aim.name = "aim"
    self.aim.anchorX = 0.5
    self.aim.anchorY = 0.5
end

function scene:setupShotFire()
    local options = {
        width = 32,
        height = 32,
        numFrames = 2,
    }
    self.shotFireImageSheet = graphics.newImageSheet("data/shot_fire.png", options)
end

function scene:setupScores()
    self.scoresText = display.newText({
        parent = self.view,
        text = "",
        width = self.W,
        font = fontName,
        fontSize = 48,
        align = 'center',
    })
    self.scoresText:setFillColor(1, 1, 0.4)
    self.scoresText.anchorX = 0.5
    self.scoresText.anchorY = 0
    self.scoresText.x = self.W / 2
    self.scoresText.y = 0

    self.raduisText = display.newText({
        parent = self.view,
        text = "",
        width = self.W,
        font = fontName,
        fontSize = 42,
        align = 'right',
    })
    self.raduisText:setFillColor(1, 1, 0.4)
    self.raduisText.anchorX = 1
    self.raduisText.anchorY = 0
    self.raduisText.x = self.W
    self.raduisText.y = 0
end

function scene:updateScores()
    self.scoresText.text = "Score: " .. tostring(self.totalScore)
    self.raduisText.text = "Radius: " .. round(self.borderRadius)
end

function scene:isObjInsideBorder(obj, customSize)
    local objSize
    if customSize == nil then
        objSize = sqrt(sqr(obj.width) + sqr(obj.height))
    else
        objSize = customSize
    end

    objSize = objSize / (1 / 0.7) -- ��� �������� � �������

    local distanceFromCentre = sqrt(sqr(obj.x) + sqr(obj.y))

    return (distanceFromCentre + (objSize / 2)) < self.borderRadius
end

function scene:moveTo(obj, target, speed, deltaTime)
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

function scene:calcMoveForwardPosition(obj, delta)
    local angle = math.rad(obj.rotation)
    local vec = { x = math.cos(angle), y = math.sin(angle) }

    vec.x = vec.x * delta
    vec.y = vec.y * delta

    return { x = obj.x + vec.x, y = obj.y + vec.y }
end

function scene:moveForward(obj, delta)
    local pos = self:calcMoveForwardPosition(obj, delta)
    obj.x = pos.x
    obj.y = pos.y
end

function scene:calcMoveTowardsPosition(obj, target, delta)
    local vec = vector(obj.x, obj.y, target.x, target.y)
    local vecLen = vectorLen(vec)

    local pos = { x = obj.x, y = obj.y }

    if vecLen ~= 0 then
        pos.x = pos.x + delta * (vec.x / vecLen)
        pos.y = pos.y + delta * (vec.y / vecLen)
    end

    return pos
end

function scene:moveTowards(obj, target, delta)
    local pos = self:calcMoveTowardsPosition(obj, target, delta)
    obj.x = pos.x
    obj.y = pos.y
end

function scene:updateAmmoAllowed(gunType)
    if gunType == gunTypePistol then
        return
    end
    self.ammoBlocksTexts[gunType].text = tostring(self.ammoAllowed[gunType])
end

function scene:updateHeart()
    self.heartIconText.text = tostring(self.playerHP)
end

function scene:shot()
    local gunType = self.player.gun.gunType

    local barrelLength = gunsInfo.barrelLengths[gunType]

    if gunType ~= gunTypePistol then
        local cnt = self.ammoAllowed[gunType]
        if cnt == 0 then
            -- ����� ��������
            audio.play(self.soundNoAmmo)
            return
        end
        self.ammoAllowed[gunType] = cnt - 1
        self:updateAmmoAllowed(gunType)
    end

    audio.play(self.soundGuns[gunType])

    local angle = self.player.gun.rotation
    if self.player.xScale < 0 then
        angle = -angle + 180
    end

    local shotFirePosAndRotation = self:calcMoveForwardPosition({
        rotation = angle,
        x = self.player.x,
        y = self.player.y
    }, barrelLength)
    shotFirePosAndRotation.rotation = angle
    self:shotFire(shotFirePosAndRotation)

    if self.player.gun.gunType ~= gunTypeShotgun then
        local ammo = self:ammoGet(gunType)
        ammo.x = self.player.x
        ammo.y = self.player.y

        ammo.rotation = angle
        ammo.damage = gunsInfo.damages[gunType]

        local pos = self:calcMoveForwardPosition(ammo, barrelLength)
        ammo.x = pos.x
        ammo.y = pos.y
    else
        -- ������ �������� ������

        local sectorAngle = 30 -- ������ �������� �����
        local shotsCnt = 6 -- ����� ��������
        local angleStep = sectorAngle / (shotsCnt - 1)

        angle = angle - (sectorAngle / 2)

        for i = 1, shotsCnt do
            local ammo = self:ammoGet(gunType)
            ammo.x = self.player.x
            ammo.y = self.player.y

            ammo.rotation = angle
            angle = angle + angleStep

            ammo.damage = gunsInfo.damages[gunType]

            local pos = self:calcMoveForwardPosition(ammo, barrelLength)
            ammo.x = pos.x
            ammo.y = pos.y
        end
    end
end

function scene:playerDied()
    if self.melodyChannel ~= nil then
        audio.stop(self.melodyChannel)
        self.melodyChannel = nil
    end

    audio.play(self.soundLose)
    self.gameInPause = true

    self.player.playerImage:setSequence("stay")
    self.player.playerImage:play()

    -- ������ "�������� �� ���" � ��� ����� ������ �� �����
    self.player.gun.isVisible = false
    transition.to(self.player, { time = 1000, rotation = 90 })

    local blur = display.newRect(self.view, -self.W, -self.H, 3 * self.W, 3 * self.H)
    blur.anchorX = 0
    blur.anchorY = 0
    blur.alpha = 0
    blur.fill = { 0, 0, 0, 1 }
    transition.to(blur, { time = 1000, alpha = 1 })

    local closedPortals = math.max(0, self.portalsCreatedForAllTime - #self.portals)
    local scores = "Your score: " .. tostring(self.totalScore)
            .. "\n\nClosed portals: " .. tostring(closedPortals)
    local gameOverText = display.newText({
        parent = self.view,
        text = scores .. "\n\nTry again!",
        width = self.W,
        font = fontName,
        fontSize = 64,
        align = 'center',
    })
    self.view:insert(gameOverText)
    gameOverText:setFillColor(1, 1, 1)
    gameOverText.anchorX = 0.5
    gameOverText.anchorY = 0.5
    gameOverText.x = self.W / 2
    gameOverText.y = self.H / 2

    blur:addEventListener("touch", function(event)
        if event.phase == 'began' then
            composer.gotoScene('scenes.menu')
            return true
        end
        return false
    end)
end

function scene:playerGotDamage(damage)
    local currentTime = system.getTimer()

    if self.playerInvulnBefore >= currentTime then
        return
    end

    -- ��� ������ ��� ��������� ����� ������������ �� �������
    self.playerInvulnBefore = currentTime + 1000

    self.playerHP = math.max(0, self.playerHP - damage)
    audio.play(self.soundHit)
    self:updateHeart()
    if self.playerHP == 0 then
        self:playerDied()
    else
        self:makeSomeBlood(self.player)
    end
end

function scene:updateBorderRadius(deltaTime)
    self.borderRadius = self.borderRadius - self.borderRadiusSpeed * deltaTime
    if self.borderRadius < 0 then
        self.borderRadius = 0
    end
    self.border.path.radius = self.borderRadius
    self.border.fill.scaleX = groundSize / self.borderRadius
    self.border.fill.scaleY = groundSize / self.borderRadius
end

function scene:setupPlayer()
    local options = {
        width = 84,
        height = 136,
        numFrames = 4,
    }
    local imageSheet = graphics.newImageSheet("data/player.png", options)

    local playerSequenceData = {
        {
            name = "stay",
            frames = { 1 },
            time = 500,
            loopCount = 0,
            --loopDirection = "forward"
        },
        {
            name = "run",
            frames = { 2, 1, 4, 1 },
            time = 350,
            loopCount = 0,
            loopDirection = "forward"
        }
    }

    local playerImage = display.newSprite(imageSheet, playerSequenceData)

    playerImage:setSequence("stay")
    playerImage:play()

    playerImage.name = "player_image"

    local gun = display.newRect(0, 0, 140, 50)
    gun.name = "player_gun"
    gun.fill = { type = "image", sheet = self.gunsImageSheet, frame = 1 }
    gun.anchorX = 0.3
    gun.anchorY = 0.4

    self.player = display.newGroup()
    self.levelGroup:insert(self.player)
    self.player.name = "player"

    self.player:insert(playerImage)
    self.player.playerImage = playerImage
    self.player:insert(gun)
    self.player.gun = gun

    self:switchGun(gunTypePistol)
end

function scene:spawnPortal(first)
    self.portalsCreatedForAllTime = self.portalsCreatedForAllTime + 1

    local portal = display.newImageRect(self.levelGroup, "data/portal.png", 128, 128)
    portal.name = "portal"
    portal.xScale = 1.2
    portal.yScale = 1.2

    portal.HP = portalHP

    local radius = self.borderRadius * 0.8
    if first then
        -- � ������ ��� ������� ������ �������. �����, � ������ ��� ����� :)
        radius = radius / 1.15
    end

    local A = randomInt(360)
    local angle = math.rad(A - 90)
    portal.x = math.cos(angle) * radius
    portal.y = math.sin(angle) * radius

    portal.lastTimeEnemySpawn = 0

    -- ��������� �� ������
    local pointerToPortal = display.newRect(0, 0, 64, 32)
    self.levelGroup:insert(pointerToPortal)
    portal.pointerToPortal = pointerToPortal
    pointerToPortal.fill = { type = "image", sheet = self.pointsImageSheet, frame = 1 }
    pointerToPortal.x = portal.x
    pointerToPortal.y = portal.y
    pointerToPortal.anchorX = 0.5
    pointerToPortal.anchorY = 0.5

    self.portals[#self.portals + 1] = portal

    return portal
end

function scene:getNewEnemyType(portal)
    local rand = 100 - randomInt(100)
    -- ToDo: ����������� ����������� ��������� ����� ������� ����������� � ���������

    local level = self.portalsCreatedForAllTime

    if (level > 3) and (not portal.guard) and (rand < 30) then
        return enemyTypeGuard
    elseif (level > 3) and (rand < 10) then
        return enemyTypeShooter
    elseif rand < 20 then
        return enemyTypeFast
    else
        return enemyTypeSlow
    end
end

function scene:spawnEnemy(portal)
    local enemyType = self:getNewEnemyType(portal)

    local enemy = display.newRect(0, 0, enemyWidth, enemyHeight)
    self.levelGroup:insert(enemy)

    enemy.HP = enemyInfo.HPs[enemyType]

    if enemyType == enemyTypeGuard then
        enemy.portal = portal
        portal.guard = enemy
    elseif enemyType == enemyTypeShooter then
        -- ����� ��� �� ����������� (���� �� ����� ���������), ���������� �� � ��������� ��������
        enemy.distanceMult = 0.7
    end

    enemy.name = "enemy"
    enemy.enemyType = enemyType

    enemy.fill = { type = "image", sheet = self.enemyImageSheet, frame = enemyType }
    enemy.anchorX = 0.5
    enemy.anchorY = 0.5

    local scale = enemyInfo.scales[enemyType]
    enemy.xScale = scale
    enemy.yScale = scale

    -- ToDo: ����� �������� � ������� ������
    enemy.x = portal.x + randomInt(-1, 1) * enemyWidth
    enemy.y = portal.y + randomInt(-1, 1) * enemyHeight

    self.enemies[#self.enemies + 1] = enemy

    -- ������� ���������
    enemy.alpha = 0
    transition.to(enemy, { time = 400, alpha = 1 })

    return enemy
end

function scene:portalSpawnInterval()
    local cnt = math.max(1, math.floor(self.portalsCreatedForAllTime / 10))
    return 1000 * cnt
end

function scene:updatePortal(portal, deltaTime)
    local currentTime = system.getTimer()
    local delta = currentTime - portal.lastTimeEnemySpawn
    if delta > self:portalSpawnInterval() then
        portal.lastTimeEnemySpawn = currentTime
        self:spawnEnemy(portal)
    end

    -- �������� � ������� �������
    local player = self.player
    local angle = 90 - vectorToAngle(vector(portal.x, portal.y, player.x, player.y))
    local pointer = portal.pointerToPortal
    pointer.x = player.x
    pointer.y = player.y
    pointer.rotation = angle
    self:moveTowards(pointer, portal, 100)
end

function scene:updatePortals(deltaTime)
    for i, portal in ipairs(self.portals) do
        if not self:isObjInsideBorder(portal) then
            self:moveTo(portal, { x = 0, y = 0 }, self.borderRadiusSpeed, deltaTime)
        end
        self:updatePortal(portal, deltaTime)
    end
end

function scene:enemyShotToPlayer(enemy)
    if distanceBetween(enemy, self.player) > enemyShootMaxDistance then
        return
    end

    local ammo = display.newRect(0, 0, enemyAmmoWidth, enemyAmmoHeight)
    self.levelGroup:insert(ammo)
    ammo.name = "enemy_ammo"

    local ammoFrame = (enemy.enemyType == enemyTypeShooter)
            and 1
            or 2
    local ammoSpeed = (enemy.enemyType == enemyTypeShooter)
            and enemyShooterShootSpeed
            or enemyGuardShootSpeed
    local ammoScale = (enemy.enemyType == enemyTypeShooter)
            and 1
            or 2

    ammo.fill = { type = "image", sheet = self.enemyAmmoImageSheet, frame = ammoFrame }

    ammo.rotation = 0
    ammo.speed = ammoSpeed
    ammo.damage = enemyInfo.damages[enemy.enemyType]

    ammo.x = enemy.x
    ammo.y = enemy.y

    local vec = vector(enemy.x, enemy.y, self.player.x, self.player.y)
    ammo.rotation = 90 - vectorToAngle(vec)

    local pos = self:calcMoveForwardPosition(ammo, 60) -- 60 ��� 128px ������� ����
    ammo.x = pos.x
    ammo.y = pos.y

    ammo.xScale = ammoScale
    ammo.yScale = ammoScale

    self.enemyAmmoInFlight[#self.enemyAmmoInFlight + 1] = ammo
end

function scene:updateEnemy(enemy, deltaTime)
    local enemySpeed = enemyInfo.speeds[enemy.enemyType]

    if enemy.enemyType == enemyTypeGuard then
        -- ������ ���� ������ ��������
        local currentTime = system.getTimer()
        local lastShotTime = enemy.lastShotTime or 0
        if lastShotTime + enemyGuardShootInterval < currentTime then
            enemy.lastShotTime = currentTime
            self:enemyShotToPlayer(enemy)
        end

        -- ������ �� ������� ������ �� ������ �������
        local distance = distanceBetween(enemy, enemy.portal)
        if distance >= enemyGuardMaxDistance then
            return
        end
    elseif enemy.enemyType == enemyTypeShooter then
        -- ������� ��������. ��� ��� ����������
        local currentTime = system.getTimer()
        local lastShotTime = enemy.lastShotTime or 0
        if lastShotTime + enemyShooterShootInterval < currentTime then
            enemy.lastShotTime = currentTime
            self:enemyShotToPlayer(enemy)
        end

        -- ������� ��������� ��������� �� ����������

        local toPlayerDist = distanceBetween(enemy, self.player)

        if toPlayerDist < (enemyShooterDistance * enemy.distanceMult) then
            -- ���� �� ������ ������� ������, �� �������,
            --   ���� �� ������� ��������, �� �� �������� �� � �������
            local deltaDist = enemySpeed * deltaTime
            local newPos = self:calcMoveTowardsPosition(enemy, { x = self.player.x, y = self.player.y }, -deltaDist)

            local newPosRadius = vectorLen(newPos)
            if (newPosRadius + enemyWidth) < self.borderRadius then
                -- ������� �� ������
                self:moveTowards(enemy, { x = self.player.x, y = self.player.y }, -deltaDist)
                return
            end
        end
    end

    self:moveTo(enemy, { x = self.player.x, y = self.player.y }, enemySpeed, deltaTime)
end

function scene:dropAmmo(enemyType, enemyObj)
    local gunType
    local ammoQuantity
    if enemyType == enemyTypePortal then
        local rnd = 100 - randomInt(100)
        if rnd < 70 then
            gunType = gunTypeRocketLauncher
            ammoQuantity = 3
        elseif rnd < 15 then
            gunType = gunTypeMachinegun
            ammoQuantity = 35
        else
            gunType = gunTypeShotgun
            ammoQuantity = 20
        end
    elseif enemyType == enemyTypeShooter then
        local rnd = 100 - randomInt(100)
        if rnd < 5 then
            gunType = gunTypeRocketLauncher
            ammoQuantity = randomInt(1, 2)
        elseif rnd < 50 then
            gunType = gunTypeMachinegun
            ammoQuantity = 30
        elseif rnd < 10 then
            gunType = gunTypeShotgun
            ammoQuantity = 10
        end
    elseif enemyType == enemyTypeFast then
        local rnd = 100 - randomInt(100)
        if rnd < 3 then
            gunType = gunTypeMachinegun
            ammoQuantity = 20
        elseif rnd < 10 then
            gunType = gunTypeShotgun
            ammoQuantity = 10
        end
    elseif enemyType == enemyTypeSlow then
        local rnd = 100 - randomInt(100)
        if rnd < 3 then
            gunType = gunTypeMachinegun
            ammoQuantity = 10
        elseif rnd < 10 then
            gunType = gunTypeShotgun
            ammoQuantity = 2
        end
    else
        -- �� �����������
        return
    end

    if not gunType then
        if randomInt(100) >= 97 then
            -- ������ ����� � �������� ��������
            gunType = gunTypeDropHeart
            ammoQuantity = 1
        else
            -- ���� �� � ���� ���
            return
        end
    end

    local ammoIconScale = 3

    local drop = display.newRect(0, 0,
        ammoBlockWidth * ammoIconScale,
        ammoBlockHeight * ammoIconScale)
    self.levelGroup:insert(drop)

    drop.gunType = gunType
    drop.quantity = ammoQuantity

    drop.fill = { type = "image", sheet = self.ammoBlocksImageSheet, frame = gunType }
    drop.x = enemyObj.x
    drop.y = enemyObj.y
    drop.anchorX = 0
    drop.anchorY = 0

    self.ammoDrops[#self.ammoDrops + 1] = drop
end

function scene:enemyDied(enemyIdx, denyDropAmmo)
    local enemy = self.enemies[enemyIdx]

    if not denyDropAmmo then
        self:dropAmmo(enemy.enemyType, enemy)
    end

    self.totalScore = self.totalScore + 1 -- ���� �� ���� ���������

    table.remove(self.enemies, enemyIdx)
    transition.to(enemy, {
        time = 200,
        alpha = 0,
        onComplete = function()
            enemy:removeSelf()
        end,
    })
end

function scene:updateEnemies(deltaTime)
    local to_delete = {}

    for i, enemy in ipairs(self.enemies) do
        -- ������� � ������� ������
        local playerInTheLeft = self.player.x < enemy.x
        local scale = math.abs(enemy.xScale)
        enemy.xScale = playerInTheLeft and -scale or scale

        if not self:isObjInsideBorder(enemy) then
            if enemy.enemyType == enemyTypeGuard then
                -- ����� �� ������ �� �������, � ��� � ������ �������� � ���
                self:moveTo(enemy, { x = 0, y = 0 }, self.borderRadiusSpeed, deltaTime)
            else
                to_delete[#to_delete + 1] = i
            end
        else
            self:updateEnemy(enemy, deltaTime)
        end
    end

    for i = #to_delete, 1, -1 do
        self:enemyDied(to_delete[i])
    end
end

function scene:makeSomeBlood(obj, isEnemy)
    if isEnemy then
        if obj.fill ~= nil then
            obj.fill.effect = "filter.brightness"
            obj.fill.effect.intensity = 0.9

            timer.performWithDelay(100, function()
                if obj.fill ~= nil then
                    obj.fill.effect = nil
                end
            end)
        end
        return
    end

    local bloodImage = display.newImageRect(self.levelGroup, "data/blood.png", 64, 64)
    bloodImage.x = obj.x
    bloodImage.y = obj.y
    bloodImage.anchorX = 0.5
    bloodImage.anchorY = 0.5

    local scale = randomInt(80, 120) / 100
    bloodImage.xScale = scale
    bloodImage.yScale = scale
    bloodImage.rotation = randomInt(360)

    timer.performWithDelay(100, function()
        bloodImage:removeSelf()
    end)
end

function scene:enemyGotDamage(enemyIdx, ammo)
    local damage = ammo.damage
    local enemy = self.enemies[enemyIdx]

    if enemy == nil then
        -- ������ ��� ����� ����� ��� � ��� ��������� ����������
        return
    end

    if enemy.enemyType == enemyTypeGuard then
        -- ����� ������� ��������
        self:makeSomeBlood(enemy, true)
        return
    end

    local HP = enemy.HP - damage
    if HP <= 0 then
        self:enemyDied(enemyIdx)
    else
        enemy.HP = HP
        self:makeSomeBlood(enemy, true)
    end
end

function scene:getNewPortslsCount()
    local cnt = self.portalsCreatedForAllTime
    if cnt <= 4 then -- ������ ��� �������������� �������� (� ������� �� ������)
        return 1
    elseif cnt <= 7 then
        return 2
    elseif cnt <= 15 then
        return 3
    elseif cnt <= 20 then
        return 4
    else
        return 5
    end
end

function scene:portalDestroed(portalIdx)
    local portal = self.portals[portalIdx]

    if portal.guard then
        -- ���� � ������� ��� �����, �� �� ���� ������
        for enemyIdx, enemy in ipairs(self.enemies) do
            if enemy == portal.guard then
                enemy.portal = nil
                portal.guard = nil
                self:enemyDied(enemyIdx)
                break
            end
        end
    end

    -- ������, ����������� �� ������, ���� ������ �� �����
    portal.pointerToPortal:removeSelf()
    portal.pointerToPortal = nil

    self:dropAmmo(enemyTypePortal, portal)

    portal:removeSelf()
    table.remove(self.portals, portalIdx)

    self.totalScore = self.totalScore + 50

    self.playerSpeed = math.min(700, self.playerSpeed + 20)

    self.borderRadius = self.borderRadius + 250
    audio.play(self.soundExtension)
    transition.to(self.border.path, {
        time = 1000,
        radius = self.borderRadius,
        onComplete = function()
            self.borderRadius = self.border.path.radius
        end,
    })
    transition.to(self.border.fill, {
        time = 1000,
        scaleX = groundSize / self.borderRadius,
        scaleY = groundSize / self.borderRadius,
    })

    local cntNew = self:getNewPortslsCount() - #self.portals
    for i = 1, cntNew do
        self:spawnPortal()
    end
end

function scene:portalGotDamage(portalIdx, ammo)
    local damage = ammo.damage
    local portal = self.portals[portalIdx]

    if portal == nil then
        -- ������ ��� ���� ������ ��� � ��� ��������� ����������
        return
    end

    local HP = portal.HP - damage
    if HP <= 0 then
        self:portalDestroed(portalIdx)
    else
        portal.HP = HP
        self:makeSomeBlood(portal, true)
    end
end

function scene:getEnemyDamage(enemy)
    return enemyInfo.damages[enemy.enemyType]
end

function scene:playerCheckCollisions()
    if not self:isObjInsideBorder(self.player, self.player.playerImage.width * sqrt(2)) then
        self:playerGotDamage(damageFromBorder)
        return
    end

    for enemyIdx, enemy in ipairs(self.enemies) do
        if hasCollidedCircle(self.player, enemy) then
            self:playerGotDamage(self:getEnemyDamage(enemy))
            if enemy.enemyType == enemyTypeFast then
                self:fastEnemyExplosion(self.player)
                self:enemyDied(enemyIdx, true)
            end
            return
        end
    end

    for i, portal in ipairs(self.portals) do
        if hasCollidedCircle(self.player, portal) then
            self:playerGotDamage(damageFromPortal)
            return
        end
    end
end

function scene:updatePlayer(deltaTime)
    local dX, dY = 0, 0

    local isMoving = false

    if self.pressedKeys.left or self.pressedKeys.right then
        isMoving = true
        local dir = self.pressedKeys.left and -1 or 1
        dX = dir * self.playerSpeed * deltaTime
    end
    if self.pressedKeys.top or self.pressedKeys.down then
        isMoving = true
        local dir = self.pressedKeys.top and -1 or 1
        dY = dir * self.playerSpeed * deltaTime
    end

    -- ����� ��������
    if isMoving and self.player.playerImage.sequence ~= "run" then
        self.player.playerImage:setSequence("run")
        self.player.playerImage:play()
    elseif not isMoving and self.player.playerImage.sequence ~= "stay" then
        self.player.playerImage:setSequence("stay")
        self.player.playerImage:play()
    end

    -- ����������� ������
    self.player.x = self.player.x + dX
    self.player.y = self.player.y + dY

    -- "������" ������� �� �������
    self.levelGroup.x = self.levelGroup.x - dX
    self.levelGroup.y = self.levelGroup.y - dY

    -- ����������� �������
    local dir = (self.mousePos.x > 0) and 1 or -1
    self.player.xScale = dir

    -- ����������� �����
    local vec = { x = self.mousePos.x, y = -self.mousePos.y }
    if vec.y == 0 then
        return
    end
    local angle = vectorToAngle(vec)

    if self.player.xScale < 0 then
        angle = 360 - angle
    end
    self.player.gun.rotation = angle - 90

    -- ��������
    if self.pressedKeys.mouseLeft then
        local currentTime = system.getTimer()
        local delta = currentTime - gunsInfo.lastShots[self.player.gun.gunType]
        if delta >= gunsInfo.shotIntervals[self.player.gun.gunType] then
            gunsInfo.lastShots[self.player.gun.gunType] = currentTime
            self:shot()
        end
    end

    self:playerCheckCollisions()
end

function scene:explosion(posObj)
    audio.play(self.soundBoom)

    local explosionSequenceData = {
        {
            name = "boom",
            frames = { 1, 2, 3, 4, 5, 6, 7 },
            time = 500,
            loopCount = 1,
            loopDirection = "forward"
        },
    }
    local explosionImage = display.newSprite(self.explosionImageSheet, explosionSequenceData)
    self.levelGroup:insert(explosionImage)
    explosionImage.x = posObj.x
    explosionImage.y = posObj.y
    explosionImage.xScale = rocketDamageRadius / explosionImageSize
    explosionImage.yScale = rocketDamageRadius / explosionImageSize

    explosionImage:addEventListener("sprite", function(event)
        local thisSprite = event.target
        if (event.phase == "ended") then
            thisSprite:removeSelf()
        end
    end)

    explosionImage:setSequence("boom")
    explosionImage:play()
end

function scene:shotFire(posObj)
    local shotFireSequenceData = {
        {
            name = "boom",
            frames = { 1, 2 },
            time = 50,
            loopCount = 1,
            loopDirection = "forward"
        },
    }

    if scene.shotImage == nil then
        scene.shotImage = display.newSprite(self.shotFireImageSheet, shotFireSequenceData)
        self.levelGroup:insert(scene.shotImage)
    end

    scene.shotImage.x = posObj.x
    scene.shotImage.y = posObj.y
    scene.shotImage.rotation = posObj.rotation

    scene.shotImage:setSequence("boom")
    scene.shotImage:play()
end

function scene:fastEnemyExplosion(posObj)
    local explosionSequenceData = {
        {
            name = "boom",
            frames = { 1, 2, 3, 4, 5, 6, 7 },
            time = 500,
            loopCount = 1,
            loopDirection = "forward"
        },
    }
    local explosionImage = display.newSprite(self.fastEnemyExplosionImageSheet, explosionSequenceData)
    self.levelGroup:insert(explosionImage)
    explosionImage.x = posObj.x
    explosionImage.y = posObj.y
    explosionImage.xScale = 2
    explosionImage.yScale = 2

    explosionImage:addEventListener("sprite", function(event)
        local thisSprite = event.target
        if (event.phase == "ended") then
            thisSprite:removeSelf()
        end
    end)

    explosionImage:setSequence("boom")
    explosionImage:play()
end

function scene:ammoCollideAnim(ammo, enemyOrPortal)
    if ammo.gunType ~= gunTypeRocketLauncher then
        -- ���� ��� ������������ ��� ������� �����
        return false
    end

    self:explosion(enemyOrPortal)

    -- ����� ������� ���� ���� ����������� � �������
    local to_delete = {}
    for enemyIdx, enemy in ipairs(self.enemies) do
        if distanceBetween(ammo, enemy) < rocketDamageRadius then
            to_delete[#to_delete + 1] = enemyIdx
        end
    end

    for i = #to_delete, 1, -1 do
        local enemyIdx = to_delete[i]
        self:enemyGotDamage(enemyIdx, ammo)
    end

    local to_delete = {}
    for portalIdx, portal in ipairs(self.portals) do
        if distanceBetween(ammo, portal) < rocketDamageRadius then
            to_delete[#to_delete + 1] = portalIdx
        end
    end

    for i = #to_delete, 1, -1 do
        local enemyIdx = to_delete[i]
        self:portalGotDamage(enemyIdx, ammo)
    end

    return true
end

-- updateAmmo ������ true, ���� ���� ����� �������
function scene:updateAmmo(ammo, deltaTime)
    local collided = false

    local got_damage = {}
    for enemyIdx, enemy in ipairs(self.enemies) do
        if hasCollidedCircle(ammo, enemy) then
            if not self:ammoCollideAnim(ammo, enemy) then -- ����� ������� ��, ��� ���� ������ � got_damage
                got_damage[#got_damage + 1] = enemyIdx
            end
            collided = true
        end
    end
    for i = #got_damage, 1, -1 do
        local enemyIdx = got_damage[i]
        self:enemyGotDamage(enemyIdx, ammo)
    end

    local got_damage = {}
    for i, portal in ipairs(self.portals) do
        if hasCollidedCircle(ammo, portal) then
            if not self:ammoCollideAnim(ammo, portal) then -- ����� ������� ��, ��� ���� ������ � got_damage
                got_damage[#got_damage + 1] = i
            end
            collided = true
        end
    end
    for i = #got_damage, 1, -1 do
        local idx = got_damage[i]
        self:portalGotDamage(idx, ammo)
    end

    if collided then
        return true
    end

    self:moveForward(ammo, ammo.speed * deltaTime)

    return false
end

function scene:updateAmmos(deltaTime)
    -- ���� ������
    local to_delete = {}
    for i, ammo in ipairs(self.ammoInFlight) do
        if not self:isObjInsideBorder(ammo) then
            to_delete[#to_delete + 1] = i
        elseif self:updateAmmo(ammo, deltaTime) then
            -- ���� � ���-�� �����������, ���� �������
            to_delete[#to_delete + 1] = i
        end
    end

    for i = #to_delete, 1, -1 do
        local ammo = self.ammoInFlight[to_delete[i]]
        table.remove(self.ammoInFlight, to_delete[i])
        self:ammoPut(ammo)
    end

    -- ���� ������
    local to_delete = {}
    for i, ammo in ipairs(self.enemyAmmoInFlight) do
        if not self:isObjInsideBorder(ammo) then
            to_delete[#to_delete + 1] = i
        elseif hasCollidedCircle(ammo, self.player) then
            self:playerGotDamage(ammo.damage)
            to_delete[#to_delete + 1] = i
        else
            self:moveForward(ammo, ammo.speed * deltaTime)
        end
    end

    for i = #to_delete, 1, -1 do
        local ammo = self.enemyAmmoInFlight[to_delete[i]]
        table.remove(self.enemyAmmoInFlight, to_delete[i])
        ammo:removeSelf()
    end
end

function scene:updateAmmoDrops(deltaTime)
    local to_delete = {}
    for i, drop in ipairs(self.ammoDrops) do
        if not self:isObjInsideBorder(drop) then
            to_delete[#to_delete + 1] = i
        elseif hasCollidedCircle(self.player, drop) then
            if drop.gunType == gunTypeDropHeart then
                audio.play(self.soundHeart)
                self.playerHP = self.playerHP + drop.quantity
                self:updateHeart()
            else
                audio.play(self.soundAmmo)
                self.ammoAllowed[drop.gunType] = self.ammoAllowed[drop.gunType] + drop.quantity
                self:updateAmmoAllowed(drop.gunType)
            end
            to_delete[#to_delete + 1] = i
        end
    end

    for i = #to_delete, 1, -1 do
        local dropIdx = to_delete[i]
        self.ammoDrops[dropIdx]:removeSelf()
        table.remove(self.ammoDrops, dropIdx)
    end
end

function scene:setupGunsAndAmmo()
    self.gunsCount = 4
    local options = {
        width = 148,
        height = 64,
        numFrames = self.gunsCount,
    }
    self.gunsImageSheet = graphics.newImageSheet("data/guns.png", options)

    local options = {
        width = ammoWidth,
        height = ammoHeight,
        numFrames = self.gunsCount,
    }
    self.ammoImageSheet = graphics.newImageSheet("data/ammo.png", options)

    for i = 1, self.gunsCount do
        gunsInfo.lastShots[i] = 0
    end

    local options = {
        width = ammoBlockWidth,
        height = ammoBlockHeight,
        numFrames = self.gunsCount + 1, -- +1 ��� ��������
    }
    self.ammoBlocksImageSheet = graphics.newImageSheet("data/ammo_blocks.png", options)

    for gunType = 1, self.gunsCount do
        self.ammoAllowed[gunType] = 0

        local icon = display.newRect(0, 0,
            ammoBlockWidth * ammoIconScale,
            ammoBlockHeight * ammoIconScale)
        self.view:insert(icon)
        self.ammoBlocksIcons[gunType] = icon
        icon.fill = { type = "image", sheet = self.ammoBlocksImageSheet, frame = gunType }
        icon.x = 0
        icon.y = 10 + (gunType - 1) * ammoBlockHeight * ammoIconScale
        icon.anchorX = 0
        icon.anchorY = 0

        local text = display.newText({
            parent = self.view,
            text = (gunType == gunTypePistol) and "--" or "0",
            width = self.W,
            font = fontName,
            fontSize = 42,
            align = 'left',
        })
        text:setFillColor(1, 1, 0.4)
        text.anchorX = 0
        text.anchorY = 0
        text.x = icon.x + icon.contentWidth + 10
        text.y = icon.y * 1.03

        self.ammoBlocksTexts[gunType] = text

        self:updateAmmoAllowed(gunType)
    end
end

function scene:setupHeart()
    self.heartIcon = display.newRect(0, 0,
        ammoBlockWidth * ammoIconScale,
        ammoBlockHeight * ammoIconScale)
    self.view:insert(self.heartIcon)
    self.heartIcon.fill = { type = "image", sheet = self.ammoBlocksImageSheet, frame = self.gunsCount + 1 }
    self.heartIcon.x = 0
    self.heartIcon.y = 10 + self.gunsCount * ammoBlockHeight * ammoIconScale
    self.heartIcon.anchorX = 0
    self.heartIcon.anchorY = 0

    self.heartIconText = display.newText({
        parent = self.view,
        text = "0",
        width = self.W,
        font = fontName,
        fontSize = 42,
        align = 'left',
    })
    self.heartIconText:setFillColor(1, 0.9, 0.9)
    self.heartIconText.anchorX = 0
    self.heartIconText.anchorY = 0
    self.heartIconText.x = self.heartIcon.x + self.heartIcon.contentWidth + 10
    self.heartIconText.y = self.heartIcon.y * 1.03

    -- �������� ������
    local scaleFunc
    scaleFunc = function()
        transition.scaleTo(self.heartIcon, {
            time = 800,
            xScale = 1.1,
            yScale = 1.1,
            onComplete = function()
                transition.scaleTo(self.heartIcon, { time = 800, xScale = 1, yScale = 1, onComplete = scaleFunc })
            end
        })
    end
    scaleFunc()

    self:updateHeart()
end

function scene:setupEnemies()
    local options = {
        width = 128,
        height = 128,
        numFrames = enemyTypeMaxValue,
    }
    self.enemyImageSheet = graphics.newImageSheet("data/enemies.png", options)
end

function scene:setupEnemyAmmo()
    local options = {
        width = enemyAmmoWidth,
        height = enemyAmmoHeight,
        numFrames = 2,
    }
    self.enemyAmmoImageSheet = graphics.newImageSheet("data/enemy_ammo.png", options)
end

function scene:setupPoints()
    local options = {
        width = 64,
        height = 32,
        numFrames = 1,
    }
    self.pointsImageSheet = graphics.newImageSheet("data/pointers.png", options)
end

function scene:setupExplosion()
    local options = {
        width = explosionImageSize,
        height = explosionImageSize,
        numFrames = 7,
    }
    self.explosionImageSheet = graphics.newImageSheet("data/explosion.png", options)
end

function scene:setupFastEnemyExplosion()
    local options = {
        width = 64,
        height = 64,
        numFrames = 7,
    }
    self.fastEnemyExplosionImageSheet = graphics.newImageSheet("data/fast_enemy_explosion.png", options)
end

function scene:onEnterFrame(event)
    if self.lastEnterFrameTime == 0 then
        self.lastEnterFrameTime = system.getTimer()
        return
    end
    local deltaTime = (event.time - self.lastEnterFrameTime) / 1000
    self.lastEnterFrameTime = event.time
    if deltaTime <= 0 then
        return
    end

    if self.gameInPause then
        return
    end

    self:updatePlayer(deltaTime)
    self:updateBorderRadius(deltaTime)
    self:updatePortals(deltaTime)
    self:updateEnemies(deltaTime)
    self:updateAmmos(deltaTime)
    self:updateAmmoDrops(deltaTime)

    self:updateScores()
end

-- ===========================================================================================

function scene:create(event)
    self.soundNoAmmo = audio.loadSound("data/no_ammo.wav")
    self.soundLose = audio.loadSound("data/lose.wav")
    self.soundBoom = audio.loadSound("data/boom.wav")
    self.soundHit = audio.loadSound("data/hit.wav")
    self.soundHeart = audio.loadSound("data/heart.wav")
    self.soundAmmo = audio.loadSound("data/heart.wav") -- ���� ����� ����
    self.soundExtension = audio.loadSound("data/extension.wav")

    self.soundGuns = {}
    self.soundGuns[gunTypePistol] = audio.loadSound("data/pistol.wav")
    self.soundGuns[gunTypeShotgun] = audio.loadSound("data/shotgun.wav")
    self.soundGuns[gunTypeMachinegun] = audio.loadSound("data/shotgun.wav")
    self.soundGuns[gunTypeRocketLauncher] = audio.loadSound("data/rocket.wav")
end

function scene:destroy(event)
    audio.dispose(self.soundNoAmmo)
    audio.dispose(self.soundLose)
    audio.dispose(self.soundBoom)
    audio.dispose(self.soundHit)
    audio.dispose(self.soundHeart)
    audio.dispose(self.soundExtension)

    for _, sound in ipairs(self.soundGuns) do
        audio.dispose(sound)
    end
end

scene:addEventListener("create", scene)
scene:addEventListener("destroy", scene)

local function onEnterFrame(event)
    scene:onEnterFrame(event)
end

local function onKey(event)
    scene:onKey(event)
end

local function onMouseEvent(event)
    scene:onMouseEvent(event)
end

function scene:reset()
    for i = self.view.numChildren, 1, -1 do
        self.view[i]:removeSelf()
    end

    self.pressedKeys = {
        mouseLeft = false,
        left = false,
        right = false,
        top = false,
        down = false,
    }
    self.mousePos = {
        x = 0,
        y = 0,
    }

    self.mouseScrollLastTime = 0

    self.W, self.H = 0, 0

    if self.levelGroup ~= nil then
        self.levelGroup:removeSelf()
    end
    self.levelGroup = nil

    if self.border ~= nil then
        self.border:removeSelf()
    end
    self.border = nil
    self.player = nil
    self.enemies = {}
    self.portals = {}
    self.ammoInFlight = {}
    self.ammoInCache = {}
    self.ammoDrops = {}
    self.enemyAmmoInFlight = {}
    self.scoresText = nil
    self.raduisText = nil

    self.portalsCreatedForAllTime = 0
    self.totalScore = 0

    self.playerHP = 10
    self.playerInvulnBefore = 0

    self.aim = nil

    self.gameInPause = false

    self.borderRadius = 800
    self.borderRadiusSpeed = 50
    self.playerSpeed = 400

    self.enemyImageSheet = nil

    self.gunsCount = 0
    self.gunsImageSheet = nil
    self.ammoImageSheet = nil
    self.ammoBlocksImageSheet = nil

    self.enemyAmmoImageSheet = nil
    self.pointsImageSheet = nil
    self.explosionImageSheet = nil
    self.shotFireImageSheet = nil
    self.fastEnemyExplosionImageSheet = nil

    self.ammoBlocksIcons = {}
    self.ammoBlocksTexts = {}

    self.heartIcon = nil
    self.heartIconText = nil

    self.ammoAllowed = {}

    self.lastEnterFrameTime = 0

    self.shotImage = nil
end

scene:addEventListener("show", function(event)
    if (event.phase == "will") then
        scene:reset()

        scene.soundMelody = audio.loadSound("data/melody.wav")

        scene.melodyChannel = audio.play(scene.soundMelody, { loops = -1 })
        audio.setVolume(0.75, { channel = scene.melodyChannel })

        scene.W, scene.H = display.contentWidth, display.contentHeight

        scene.levelGroup = display.newGroup()
        scene.levelGroup.x = scene.W / 2
        scene.levelGroup.y = scene.H / 2
        scene.view:insert(scene.levelGroup)

        scene:setupAim()

        scene:setupScores()
        scene:updateScores()

        scene:setupGunsAndAmmo()

        scene:setupHeart()

        scene:setupEnemies()
        scene:setupEnemyAmmo()

        scene:setupPoints()
        scene:setupExplosion()
        scene:setupFastEnemyExplosion()

        scene:setupBorder()
        scene:setupPlayer()

        scene:setupShotFire()

        scene:spawnPortal(true)

        Runtime:addEventListener("enterFrame", onEnterFrame)
        Runtime:addEventListener("key", onKey)
        Runtime:addEventListener("mouse", onMouseEvent)
    end
end)

scene:addEventListener("hide", function(event)
    if (event.phase == "did") then
        if scene.melodyChannel ~= nil then
            audio.stop(scene.melodyChannel)
            scene.melodyChannel = nil
        end

        audio.dispose(scene.soundMelody)

        Runtime:removeEventListener("enterFrame", onEnterFrame)
        Runtime:removeEventListener("key", onKey)
        Runtime:removeEventListener("mouse", onMouseEvent)
    end
end)

return scene
