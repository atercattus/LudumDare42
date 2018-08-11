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

local enemyAmmoWidth = 30
local enemyAmmoHeight = 30

local ammoIconScale = 2.5

local ammoWidth = 16
local ammoHeight = 6

local ammoBlockWidth = 18
local ammoBlockHeight = 19

local gunTypePistol = 1
local gunTypeShotgun = 2
local gunTypeMachinegun = 3
local gunTypeRocketLauncher = 4
local gunTypeMaxValue = gunTypeRocketLauncher

local gunTypeDropHeart = gunTypeMaxValue + 1 -- ������� ��� ��������� ��������

local rocketDamageRadius = 300

local gunsInfo = {
    -- ����� ���������� �������� �� ���� ����� (����������� ��� �������������)
    lastShots = {},
    -- ��������� ����� ���������� ������ �����
    shotIntervals = {
        [gunTypePistol] = 150,
        [gunTypeShotgun] = 500,
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
        [gunTypePistol] = 64,
        [gunTypeShotgun] = 70,
        [gunTypeMachinegun] = 116,
        [gunTypeRocketLauncher] = 108,
    },
    -- ���� �� ������
    damages = {
        [gunTypePistol] = 1,
        [gunTypeShotgun] = 2,
        [gunTypeMachinegun] = 2,
        [gunTypeRocketLauncher] = 10,
    },
}

local portalHP = 3

local enemyGuardMaxDistance = 200 -- ������������ ����������, �� ������� ����� ������� �� ������ �������
local enemyShooterDistance = 500 -- ����������, �� ������� ������� ��������� ��������� �� ������

local enemyShooterShootInterval = 2000 -- ��� ����� ������� ��������
local enemyShooterShootSpeed = 400 -- �������� ��������� �������

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
        [enemyTypeFast] = 1,
        [enemyTypeShooter] = 3,
        [enemyTypeGuard] = 99999, -- �� ��������� ��������
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
        if event.keyName == 'space' then -- ToDo: ������� �� ������
            self.gameInPause = not self.gameInPause
            return
        elseif "1" <= event.keyName and event.keyName <= "4" then
            self:switchGun(tonumber(event.keyName))
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
            self:switchGun(nextGunType)
        end
    end

    self.pressedKeys.mouseLeft = event.isPrimaryButtonDown

    self.aim.x = event.x
    self.aim.y = event.y
end

function scene:setupBorder()
    self.border = display.newCircle(self.levelGroup, 0, 0, self.borderRadius)
    self.border:setFillColor(1, 1, 1, 0.3)
    self.border.strokeWidth = 30
    self.border:setStrokeColor(0.4, 0.8, 1)
end

function scene:setupAim()
    self.aim = display.newImageRect(self.view, "data/aim.png", 32, 32)
    self.aim.name = "aim"
    self.aim.anchorX = 0.5
    self.aim.anchorY = 0.5
end

function scene:setupScores()
    self.scoresText = display.newText({
        parent = self.view,
        text = "",
        width = self.W,
        font = fontName,
        fontSize = 42,
        align = 'left',
    })
    self.scoresText:setFillColor(1, 1, 0.4)
    self.scoresText.anchorX = 0.5
    self.scoresText.anchorY = 0
    self.scoresText.x = self.W * 4 / 3 - 100
    self.scoresText.y = 0
end

function scene:updateScores()
    self.scoresText.text = "Radius: " .. round(self.borderRadius)
            .. "\nPortals: " .. tostring(#self.portals)
            .. "\nScore: " .. tostring(self.totalScore)
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

function scene:moveTowards(obj, target, delta)
    local vec = vector(obj.x, obj.y, target.x, target.y)
    local vecLen = vectorLen(vec)
    if vecLen == 0 then
        return
    end

    obj.x = obj.x + delta * (vec.x / vecLen)
    obj.y = obj.y + delta * (vec.y / vecLen)
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
    audio.play(self.soundLose)
    self.gameInPause = true

    local blur = display.newRect(self.view, 0, 0, self.W, self.H)
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
    end
end

function scene:updateBorderRadius(deltaTime)
    self.borderRadius = self.borderRadius - self.borderRadiusSpeed * deltaTime
    if self.borderRadius < 0 then
        self.borderRadius = 0
    end
    self.border.path.radius = self.borderRadius
end

function scene:setupPlayer()
    local playerImage = display.newImageRect("data/man.png", 128, 128)
    playerImage.name = "player_image"

    local gun = display.newRect(0, 0, 140, 50)
    gun.name = "player_gun"
    gun.fill = { type = "image", sheet = self.gunsImageSheet, frame = 1 }
    gun.anchorX = 0.2
    gun.anchorY = 0.2

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

    self.portals[#self.portals + 1] = portal

    return portal
end

function scene:getNewEnemyType(portal)
    local rand = 100 - randomInt(100)
    -- ToDo: ����������� ����������� ��������� ����� ������� ����������� � ���������

    if (self.portalsCreatedForAllTime > 3) and (not portal.guard) and (rand < 30) then
        return enemyTypeGuard
    elseif rand < 10 then
        return enemyTypeShooter
    elseif rand < 20 then
        return enemyTypeFast
    else
        return enemyTypeSlow
    end
end

function scene:spawnEnemy(portal)
    local enemyType = self:getNewEnemyType(portal)

    local enemy = display.newRect(0, 0, 128, 128)
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

    -- ToDo: ����� �������� � ������� ������
    enemy.x = portal.x + randomInt(-1, 1) * 128
    enemy.y = portal.y + randomInt(-1, 1) * 128

    self.enemies[#self.enemies + 1] = enemy

    return enemy
end

function scene:updatePortal(portal, deltaTime)
    local currentTime = system.getTimer()
    local delta = currentTime - portal.lastTimeEnemySpawn
    if delta > 1000 then -- ToDo: ������������ ������ ������
        portal.lastTimeEnemySpawn = currentTime
        self:spawnEnemy(portal)
    end
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
    local ammo = display.newRect(0, 0, enemyAmmoWidth, enemyAmmoHeight)
    self.levelGroup:insert(ammo)
    ammo.name = "enemy_ammo"
    ammo.fill = { type = "image", sheet = self.enemyAmmoImageSheet, frame = 1 }

    ammo.rotation = 0
    ammo.speed = enemyShooterShootSpeed
    ammo.damage = enemyInfo.damages[enemy.enemyType]

    ammo.x = enemy.x
    ammo.y = enemy.y

    local vec = vector(enemy.x, enemy.y, self.player.x, self.player.y)
    ammo.rotation = 90 - vectorToAngle(vec)

    local pos = self:calcMoveForwardPosition(ammo, 60) -- 60 ��� 128px ������� ����
    ammo.x = pos.x
    ammo.y = pos.y

    self.enemyAmmoInFlight[#self.enemyAmmoInFlight + 1] = ammo
end

function scene:updateEnemy(enemy, deltaTime)
    local enemySpeed = enemyInfo.speeds[enemy.enemyType]

    if enemy.enemyType == enemyTypeGuard then
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

        local deltaDist = enemySpeed * deltaTime

        local toPlayerDist = distanceBetween(enemy, self.player)
        local toCentreDist = vectorLen(enemy) + deltaDist
        if (toPlayerDist < (enemyShooterDistance * enemy.distanceMult)) and (toCentreDist < self.borderRadius) then
            -- ������� �� ������
            self:moveTowards(enemy, { x = self.player.x, y = self.player.y }, -deltaDist)
            return
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
            ammoQuantity = 5
        elseif rnd < 15 then
            gunType = gunTypeMachinegun
            ammoQuantity = 30
        else
            gunType = gunTypeShotgun
            ammoQuantity = 15
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
        if (self.playerHP < 5) and (randomInt(100) >= 90) then
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

    enemy:removeSelf()
    table.remove(self.enemies, enemyIdx)

    self.totalScore = self.totalScore + 1 -- ���� �� ���� ���������
end

function scene:updateEnemies(deltaTime)
    local to_delete = {}

    for i, enemy in ipairs(self.enemies) do
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

function scene:enemyGotDamage(enemyIdx, damage)
    local enemy = self.enemies[enemyIdx]

    if enemy == nil then
        -- ������ ��� ����� ����� ��� � ��� ��������� ����������
        return
    end

    if enemy.enemyType == enemyTypeGuard then
        -- ����� ������� ��������
        return
    end

    local HP = enemy.HP - damage
    if HP <= 0 then
        self:enemyDied(enemyIdx)
    else
        enemy.HP = HP
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
    elseif cnt <= 30 then
        return 5
    else
        return 6
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

    local cntNew = self:getNewPortslsCount() - #self.portals
    for i = 1, cntNew do
        self:spawnPortal()
    end
end

function scene:portalGotDamage(portalIdx, damage)
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

    if self.pressedKeys.left or self.pressedKeys.right then
        local dir = self.pressedKeys.left and -1 or 1
        dX = dir * self.playerSpeed * deltaTime
    end
    if self.pressedKeys.top or self.pressedKeys.down then
        local dir = self.pressedKeys.top and -1 or 1
        dY = dir * self.playerSpeed * deltaTime
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

function scene:ammoCollideAnim(ammo)
    if ammo.gunType ~= gunTypeRocketLauncher then
        -- ���� ��� ������ �������� ��� ������� �����
        return
    end

    audio.play(self.soundBoom)

    local r = display.newCircle(self.levelGroup, ammo.x, ammo.y, rocketDamageRadius)
    r.fill = { 1, 0.4, 0.4, 0.3 }
    timer.performWithDelay(300, function()
        r:removeSelf()
    end)

    -- ����� ������� ���� ���� ����������� � �������
    local to_delete = {}
    for enemyIdx, enemy in ipairs(self.enemies) do
        if distanceBetween(ammo, enemy) < rocketDamageRadius then
            to_delete[#to_delete + 1] = enemyIdx
        end
    end

    for i = #to_delete, 1, -1 do
        local enemyIdx = to_delete[i]
        self:enemyGotDamage(enemyIdx, ammo.damage)
    end

    local to_delete = {}
    for portalIdx, portal in ipairs(self.portals) do
        if distanceBetween(ammo, portal) < rocketDamageRadius then
            to_delete[#to_delete + 1] = portalIdx
        end
    end

    for i = #to_delete, 1, -1 do
        local enemyIdx = to_delete[i]
        self:portalGotDamage(enemyIdx, ammo.damage)
    end
end

-- updateAmmo ������ true, ���� ���� ����� �������
function scene:updateAmmo(ammo, deltaTime)
    local collided = false

    local got_damage = {}
    for enemyIdx, enemy in ipairs(self.enemies) do
        if hasCollidedCircle(ammo, enemy) then
            self:ammoCollideAnim(ammo) -- ����� ������� ��, ��� ���� ������ � got_damage
            got_damage[#got_damage + 1] = enemyIdx
            collided = true
        end
    end
    for i = #got_damage, 1, -1 do
        local enemyIdx = got_damage[i]
        self:enemyGotDamage(enemyIdx, ammo.damage)
    end

    local got_damage = {}
    for i, portal in ipairs(self.portals) do
        if hasCollidedCircle(ammo, portal) then
            self:ammoCollideAnim(ammo) -- ����� ������� ��, ��� ���� ������ � got_damage
            got_damage[#got_damage + 1] = i
            collided = true
        end
    end
    for i = #got_damage, 1, -1 do
        local idx = got_damage[i]
        self:portalGotDamage(idx, ammo.damage)
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
        width = 140,
        height = 50,
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
        icon.x = 10
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
        text.y = icon.y

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
    self.heartIcon.x = 10
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
    self.heartIconText:setFillColor(1, 1, 0.4)
    self.heartIconText.anchorX = 0
    self.heartIconText.anchorY = 0
    self.heartIconText.x = self.heartIcon.x + self.heartIcon.contentWidth + 10
    self.heartIconText.y = self.heartIcon.y

    self:updateHeart()
end

function scene:setupEnemies()
    local options = {
        width = 128,
        height = 128,
        numFrames = enemyTypeMaxValue,
    }
    self.enemyImageSheet = graphics.newImageSheet("data/evil.png", options)
end

function scene:setupEnemyAmmo()
    local options = {
        width = enemyAmmoWidth,
        height = enemyAmmoHeight,
        numFrames = 1,
    }
    self.enemyAmmoImageSheet = graphics.newImageSheet("data/enemy_ammo.png", options)
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

    self.ammoBlocksIcons = {}
    self.ammoBlocksTexts = {}

    self.heartIcon = nil
    self.heartIconText = nil

    self.ammoAllowed = {}

    self.lastEnterFrameTime = 0
end

scene:addEventListener("show", function(event)
    if (event.phase == "will") then
        scene:reset()

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

        scene:setupBorder()
        scene:setupPlayer()
        scene:spawnPortal(true)

        Runtime:addEventListener("enterFrame", onEnterFrame)
        Runtime:addEventListener("key", onKey)
        Runtime:addEventListener("mouse", onMouseEvent)
    end
end)

scene:addEventListener("hide", function(event)
    if (event.phase == "did") then
        Runtime:removeEventListener("enterFrame", onEnterFrame)
        Runtime:removeEventListener("key", onKey)
        Runtime:removeEventListener("mouse", onMouseEvent)
    end
end)

return scene
