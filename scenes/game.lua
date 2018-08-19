local appScale = appScale
local gameBuildVersion = gameBuildVersion
local fontName = fontName

local require = require
local print = print
local tostring = tostring
local mathSqrt = math.sqrt
local mathMax = math.max
local mathMin = math.min
local mathAbs = math.abs
local mathRandom = math.random
local mathFloor = math.floor
local tonumber = tonumber
local Runtime = Runtime

local display = display
local graphics = graphics

local tableRemove = table.remove
local displayNewRect = display.newRect
local audio = audio
local systemGetTimer = system.getTimer
local transitionTo = transition.to
local easingOutBack = easing.outBack
local timerPerformWithDelay = timer.performWithDelay
local timerCancel = timer.cancel

local composer = require('composer')
local utils = require('utils')
local pool = require('libs.pool')

local sqr = utils.sqr
local vectorToAngle = utils.vectorToAngle
local vectorLen = utils.vectorLen
local distanceBetween = utils.distanceBetween
local vector = utils.vector
local hasCollidedCircle = utils.hasCollidedCircle
local sinCos = utils.sinCos

-- ===============
-- КОНСТАНТЫ
-- ===============

local borderRadiusSpeed = 35

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

local gunTypeDropHeart = gunTypeMaxValue + 1 -- костыль для выпадения сердечек

local rocketDamageRadius = 200
local explosionImageSize = 64

local groundSize = 1024

local minimalDistanceFromPlayerToNewPortal = 450

local playerMaximumHealth = 10

local playerStandartSpeed = 550

-- длительность появления из портала
local enemySpawnAnimDelay = 400

-- запрет на это время стрелять сразу после появления из портала
local enemyShotFreezeAfterSpawn = 1000

local healthBarFrameFull = 1
local healthBarFrameHalf = 2
local healthBarFrameNone = 3

local gunsInfo = {
    -- время последнего выстрела из этой пушки (заполняется при инициализации)
    lastShots = {},
    -- интервалы между выстрелами каждой пушки
    shotIntervals = {
        [gunTypePistol] = 200,
        [gunTypeShotgun] = 450,
        [gunTypeMachinegun] = 100,
        [gunTypeRocketLauncher] = 700,
    },
    -- скорости патронов из пушек
    speeds = {
        [gunTypePistol] = 1400,
        [gunTypeShotgun] = 1100,
        [gunTypeMachinegun] = 2500,
        [gunTypeRocketLauncher] = 1000,
    },
    -- расстояние от рукоятки до конца ствола (чтобы снаряд вылетал откуда надо)
    barrelLengths = {
        [gunTypePistol] = 40,
        [gunTypeShotgun] = 60,
        [gunTypeMachinegun] = 70,
        [gunTypeRocketLauncher] = 80,
    },
    -- урон от оружия
    damages = {
        [gunTypePistol] = 4,
        [gunTypeShotgun] = 3,
        [gunTypeMachinegun] = 5,
        [gunTypeRocketLauncher] = 10,
    },
}

local portalHP = 20

local enemyGuardMaxDistance = 270 -- максимальное расстояние, на которое Страж отходит от своего портала
local enemyShooterDistance = 500 -- расстояние, на котором стрелок старается держаться от игрока

local enemyShootMaxDistance = 800 -- максимальное расстояние от врага до игрока, при котором враг будет стрелять (чтобы снаряды не летели через весь уровень)

local enemyShooterShootInterval = 2000 -- как часто стрелок стреляет
local enemyShooterShootSpeed = playerStandartSpeed * 1.2 -- скорость выстрелов стрелка

local enemyGuardShootInterval = 6000 -- как часто страж стреляет
local enemyGuardShootSpeed = playerStandartSpeed / 2 -- скорость выстрелов стража

local enemyTypePortal = 0
local enemyTypeSlow = 2 -- медленно идет на игрока
local enemyTypeShooter = 1 -- старается держаться на расстоянии выстрела. и стреляет
local enemyTypeGuard = 3 -- защитник портала. неуязвим, пока портал цел
local enemyTypeFast = 4 -- бежит на игрока и при контакте гибнет
local enemyTypeMaxValue = enemyTypeFast

local enemyInfo = {
    speeds = {
        [enemyTypeSlow] = playerStandartSpeed / 3,
        [enemyTypeFast] = playerStandartSpeed * 1.1,
        [enemyTypeShooter] = playerStandartSpeed / 2,
        [enemyTypeGuard] = 100,
    },
    damages = {
        [enemyTypeSlow] = 1,
        [enemyTypeFast] = 2,
        [enemyTypeShooter] = 2,
        [enemyTypeGuard] = 3,
    },
    HPs = {
        [enemyTypeSlow] = 3,
        [enemyTypeFast] = 5,
        [enemyTypeShooter] = 5,
        [enemyTypeGuard] = 99999, -- он програмно неуязвим
    },
    scales = {
        [enemyTypeSlow] = 0.9,
        [enemyTypeFast] = 1,
        [enemyTypeShooter] = 1.1,
        [enemyTypeGuard] = 1.6,
    },
}

-- ===============
-- ДИНАМИКА
-- ===============

local scene = composer.newScene()

function scene:updateActiveGunInUI(currentGunType)
    if currentGunType == nil then
        currentGunType = gunTypePistol
    end

    self.activeGunSelection.x = self.ammoBlocksTexts[currentGunType].iconObj.x
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

    if self.poolBullets == nil then
        local sceneSelf = self
        self.poolBullets = pool:new(function()
            local ammo = displayNewRect(0, 0, ammoWidth, ammoHeight)
            sceneSelf.levelGroup:insert(ammo)
            ammo.name = "ammo"
            ammo.fill = { type = "image", sheet = sceneSelf.ammoImageSheet, frame = gunType }

            return ammo
        end)
    end

    local ammo = self.poolBullets:get()
    ammo.isVisible = true

    ammo.gunType = gunType
    ammo.fill.frame = gunType
    ammo.x = 0
    ammo.y = 0
    ammo.rotation = 0
    ammo.speed = gunsInfo.speeds[gunType]
    ammo.xScale = 2
    ammo.yScale = 2

    self.ammoInFlight[#self.ammoInFlight + 1] = ammo

    return ammo
end

function scene:ammoPut(ammo)
    ammo.isVisible = false
    self.poolBullets:put(ammo)
end

function scene:onKey(event)
    if event.phase == 'down' then
        if "1" <= event.keyName and event.keyName <= "4" then
            self:switchGun(tonumber(event.keyName))
        elseif "mediaPause" == event.keyName then
            self.gameInPause = not self.gameInPause
            self.pauseText.isVisible = self.gameInPause
            if self.gameInPause then
                audio.pause()
            else
                audio.resume()
            end
        elseif "f12" == event.keyName then -- ToDo: выпилить из релиза
            for gunType = 1, #self.ammoAllowed do
                self.ammoAllowed[gunType] = 1000 + self.ammoAllowed[gunType]
                self:updateAmmoAllowed(gunType)
            end
        elseif "f11" == event.keyName then -- ToDo: выпилить из релиза
            self.playerHP = playerMaximumHealth
            self:updateHealthBar()
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
        local currentTime = systemGetTimer()
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
    display.setDefault("textureWrapX", "repeat")
    display.setDefault("textureWrapY", "repeat")

    self.border = display.newCircle(self.levelGroup, 0, 0, self.borderRadius)
    self.border.fill = { type = "image", filename = "data/ground.png" }
    self.border.strokeWidth = 30
    self.border:setStrokeColor(178 / 256, 16 / 256, 48 / 256)

    display.setDefault("textureWrapX", "clampToEdge")
    display.setDefault("textureWrapY", "clampToEdge")
end

function scene:setupAim()
    self.aim = display.newImageRect(self.view, "data/aim.png", 32, 32)
    self.aim.name = "aim"
    self.aim.xScale = 2
    self.aim.yScale = 2
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
        fontSize = 54,
        align = 'right',
    })
    self.scoresText:setFillColor(1, 1, 0.4)
    self.scoresText.anchorX = 1
    self.scoresText.anchorY = 0
    self.scoresText.x = self.W
    self.scoresText.y = display.safeScreenOriginY
end

function scene:updateScores()
    self.scoresText.text = "Portals: " .. (self.portalsCreatedForAllTime - #self.portals)
end

function scene:updateDebug(currentTime)
    if self.updateDebugLastTime == nil then
        self.updateDebugLastTime = currentTime
    elseif self.updateDebugLastTime + 500 > currentTime then
        return
    end
    self.updateDebugLastTime = currentTime

    self.debugText.text = "Build: " .. gameBuildVersion .. " FPS: " .. scene.FPS
end

function scene:isObjInsideBorder(obj, customSize)
    local objSize
    if customSize == nil then
        objSize = mathSqrt(sqr(obj.width) + sqr(obj.height))
    else
        objSize = customSize
    end

    objSize = objSize / (1 / 0.7) -- для близости к спрайту

    local distanceFromCentre = mathSqrt(sqr(obj.x) + sqr(obj.y))

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
    local vec = sinCos(obj.rotation)
    return {
        x = obj.x + vec[2] * delta,
        y = obj.y + vec[1] * delta
    }
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

function scene:shot()
    local gunType = self.player.gun.gunType

    local barrelLength = gunsInfo.barrelLengths[gunType]

    if gunType ~= gunTypePistol then
        local cnt = self.ammoAllowed[gunType]
        if cnt == 0 then
            -- нечем стрелять
            audio.play(self.soundNoAmmo)

            -- меняем ствол
            for newGunType = gunType - 1, gunTypePistol + 1, -1 do
                if self.ammoAllowed[newGunType] > 0 then
                    self:switchGun(newGunType)
                    return
                end
            end
            self:switchGun(gunTypePistol)

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
        -- шотган стреляет дробью

        local sectorAngle = 30 -- сектор разброса дроби
        local shotsCnt = 6 -- число дробинок
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

    -- оружие "выпадает из рук" и сам герой падает на землю
    self.player.gun.isVisible = false
    transitionTo(self.player, { time = 1000, rotation = 90 })

    local blur = displayNewRect(self.view, -self.W, -self.H, 3 * self.W, 3 * self.H)
    blur.anchorX = 0
    blur.anchorY = 0
    blur.alpha = 0
    blur.fill = { 0, 0, 0, 1 }
    transitionTo(blur, { time = 1000, alpha = 1 })

    local closedPortals = mathMax(0, self.portalsCreatedForAllTime - #self.portals)
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
    local currentTime = systemGetTimer()

    if self.playerInvulnBefore >= currentTime then
        return
    end

    -- даю игроку при получении урона неуязвимость на секунду
    self.playerInvulnBefore = currentTime + 1000

    self.playerHP = mathMax(0, self.playerHP - damage)
    audio.play(self.soundHit)
    self:updateHealthBar()
    if self.playerHP == 0 then
        self:playerDied()
    else
        self:makeSomeBlood(self.player)
    end
end

function scene:updateBorderRadius(deltaTime)
    self.borderRadius = self.borderRadius - borderRadiusSpeed * deltaTime
    if self.borderRadius < 0 then
        self.borderRadius = 0
    end
    self.border.path.radius = self.borderRadius
    self.border.fill.scaleX = groundSize / self.borderRadius
    self.border.fill.scaleY = groundSize / self.borderRadius
end

function scene:setupPlayer()
    local options = {
        width = 96,
        height = 144,
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
            frames = { 2, 3, 4, 1 },
            time = 350,
            loopCount = 0,
            loopDirection = "forward"
        }
    }

    local playerImage = display.newSprite(imageSheet, playerSequenceData)

    playerImage:setSequence("stay")
    playerImage:play()

    playerImage.name = "player_image"

    local gun = displayNewRect(0, 0, 140, 50)
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

    self:updateScores()

    local portal = display.newImageRect(self.levelGroup, "data/portal.png", 128, 128)
    portal.name = "portal"
    portal.xScale = 1.2
    portal.yScale = 1.2

    portal.HP = portalHP

    local radius = self.borderRadius * 0.8
    if first then
        -- в первый раз создаем портал поближе. может, и всегда так будет :)
        radius = radius / 1.15
    end

    -- выбор места под портал (чтобы не прямо рядом с игроком)
    for try = 1, 10 do -- чтобы не бесконечно место выбирать
        local vec = sinCos(mathRandom(360) - 90)
        portal.x = vec[2] * radius
        portal.y = vec[1] * radius

        if distanceBetween(portal, self.player) >= minimalDistanceFromPlayerToNewPortal then
            break
        end
    end

    portal.lastTimeEnemySpawn = 0

    -- указатель на портал
    local pointerToPortal = displayNewRect(0, 0, 64, 32)
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
    local rand = 100 - mathRandom(100)
    -- ToDo: увеличивать вероятность выпадения более сложных противников с развитием

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

    local enemy = displayNewRect(0, 0, enemyWidth, enemyHeight)
    self.levelGroup:insert(enemy)

    enemy.HP = enemyInfo.HPs[enemyType]
    enemy.createdAt = systemGetTimer()

    if enemyType == enemyTypeGuard then
        enemy.portal = portal
        portal.guard = enemy
    elseif enemyType == enemyTypeShooter then
        -- чтобы они не кучковались (если их будет несколько), расставляю их с небольшим рандомом
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

    local spawnAnimSpeed = mathRandom(100, 200)
    local pos = self:calcMoveTowardsPosition(portal, self.player, spawnAnimSpeed)

    local targetX = pos.x
    local targetY = pos.y
    enemy.x = portal.x
    enemy.y = portal.y

    self.enemies[#self.enemies + 1] = enemy

    -- плавное появление из центра портала в отведенную точку в сторону игрока
    enemy.alpha = 0
    enemy.inSpawnAnim = true
    transitionTo(enemy, {
        time = enemySpawnAnimDelay / 200 * spawnAnimSpeed,
        alpha = 1,
        x = targetX,
        y = targetY,
        onComplete = function()
            enemy.inSpawnAnim = false
        end
    })

    return enemy
end

function scene:portalSpawnInterval()
    local cnt = mathMax(1, mathFloor(self.portalsCreatedForAllTime / 10))
    return 1000 * cnt
end

function scene:updatePortal(portal, deltaTime)
    local currentTime = systemGetTimer()
    local delta = currentTime - portal.lastTimeEnemySpawn
    if delta > self:portalSpawnInterval() then
        portal.lastTimeEnemySpawn = currentTime
        self:spawnEnemy(portal)
    end

    -- указание в сторону портала
    local player = self.player
    local angle = 90 - vectorToAngle(vector(portal.x, portal.y, player.x, player.y))
    local pointer = portal.pointerToPortal
    pointer.x = player.x
    pointer.y = player.y
    pointer.rotation = angle
    self:moveTowards(pointer, portal, 100)
end

function scene:updatePortals(deltaTime)
    for i = 1, #self.portals do
        local portal = self.portals[i]
        if not self:isObjInsideBorder(portal) then
            self:moveTo(portal, { x = 0, y = 0 }, borderRadiusSpeed, deltaTime)
        end
        self:updatePortal(portal, deltaTime)
    end
end

function scene:enemyShotToPlayer(enemy)
    if (systemGetTimer() - enemy.createdAt) < (enemyShotFreezeAfterSpawn + enemySpawnAnimDelay) then
        -- не стрелять в игрока сразу после появления
        return
    end

    if distanceBetween(enemy, self.player) > enemyShootMaxDistance then
        return
    end

    local ammo = displayNewRect(0, 0, enemyAmmoWidth, enemyAmmoHeight)
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

    local pos = self:calcMoveForwardPosition(ammo, 60) -- 60 для 128px выходит норм
    ammo.x = pos.x
    ammo.y = pos.y

    ammo.xScale = ammoScale
    ammo.yScale = ammoScale

    self.enemyAmmoInFlight[#self.enemyAmmoInFlight + 1] = ammo
end

function scene:updateEnemy(enemy, deltaTime)
    local enemySpeed = enemyInfo.speeds[enemy.enemyType]

    if enemy.enemyType == enemyTypeGuard then
        -- Стражи тоже иногда стреляют
        local currentTime = systemGetTimer()
        local lastShotTime = enemy.lastShotTime or 0
        if lastShotTime + enemyGuardShootInterval < currentTime then
            enemy.lastShotTime = currentTime
            self:enemyShotToPlayer(enemy)
        end

        -- Стражи не отходят далеко от своего портала
        local distance = distanceBetween(enemy, enemy.portal)
        if distance >= enemyGuardMaxDistance then
            -- Страж старается встать на линию между игроком и порталом
            local pos = self:calcMoveTowardsPosition(enemy.portal, self.player, enemyGuardMaxDistance)
            self:moveTo(enemy, { x = pos.x, y = pos.y }, enemySpeed, deltaTime)
            return
        end
    elseif enemy.enemyType == enemyTypeShooter then
        -- Стрелки стреляют. Вот так неожиданно
        local currentTime = systemGetTimer()
        local lastShotTime = enemy.lastShotTime or 0
        if lastShotTime + enemyShooterShootInterval < currentTime then
            enemy.lastShotTime = currentTime
            self:enemyShotToPlayer(enemy)
        end

        -- Стрелки стараются держаться на расстоянии

        local toPlayerDist = distanceBetween(enemy, self.player)

        if toPlayerDist < (enemyShooterDistance * enemy.distanceMult) then
            -- Если до игрока слишком близко, то смотрим,
            --   если мы отойдем подальше, то не окажемся ли у барьера
            local deltaDist = enemySpeed * deltaTime
            local newPos = self:calcMoveTowardsPosition(enemy, { x = self.player.x, y = self.player.y }, -deltaDist)

            local newPosRadius = vectorLen(newPos)
            if (newPosRadius + enemyWidth) < self.borderRadius then
                -- отходит от игрока
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
        local rnd = 100 - mathRandom(100)
        if rnd < 50 then
            gunType = gunTypeRocketLauncher
            ammoQuantity = mathRandom(1, 3)
        elseif rnd < 20 then
            gunType = gunTypeMachinegun
            ammoQuantity = mathRandom(50, 70)
        else
            gunType = gunTypeShotgun
            ammoQuantity = mathRandom(10, 25)
        end
    elseif enemyType == enemyTypeShooter then
        local rnd = 100 - mathRandom(100)
        if rnd <= 1 then
            gunType = gunTypeRocketLauncher
            ammoQuantity = 1
        elseif rnd < 50 then
            gunType = gunTypeMachinegun
            ammoQuantity = mathRandom(20, 40)
        elseif rnd < 10 then
            gunType = gunTypeShotgun
            ammoQuantity = mathRandom(5, 10)
        end
    elseif enemyType == enemyTypeFast then
        local rnd = 100 - mathRandom(100)
        if rnd < 20 then
            gunType = gunTypeMachinegun
            ammoQuantity = mathRandom(10, 20)
        elseif rnd < 30 then
            gunType = gunTypeShotgun
            ammoQuantity = mathRandom(5, 15)
        end
    elseif enemyType == enemyTypeSlow then
        local rnd = 100 - mathRandom(100)
        if rnd < 8 then
            gunType = gunTypeMachinegun
            ammoQuantity = mathRandom(5, 10)
        elseif rnd < 15 then
            gunType = gunTypeShotgun
            ammoQuantity = mathRandom(2, 3)
        end
    else
        -- не реализовано
        return
    end

    if not gunType then
        if mathRandom(100) >= 97 then
            -- иногда можно и сердечко выкинуть
            gunType = gunTypeDropHeart
            ammoQuantity = 1
        else
            -- дроп не в этот раз
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

function scene:enemyDied(enemyIdx, denyDropAmmo, playerAmmo)
    local enemy = self.enemies[enemyIdx]

    if not denyDropAmmo then
        self:dropAmmo(enemy.enemyType, enemy)
    end

    self.totalScore = self.totalScore + enemyInfo.damages[enemy.enemyType]

    local diedPos = (playerAmmo ~= nil)
            and self:calcMoveTowardsPosition(enemy, playerAmmo, -50)
            or { x = enemy.x, y = enemy.y }

    tableRemove(self.enemies, enemyIdx)
    transitionTo(enemy, {
        time = 200,
        alpha = 0,
        x = diedPos.x,
        y = diedPos.y,
        onComplete = function()
            enemy:removeSelf()
        end,
    })
end

function scene:updateEnemies(deltaTime)
    local to_delete = {}

    for i = 1, #self.enemies do
        local enemy = self.enemies[i]

        -- поворот в сторону игрока
        local playerInTheLeft = self.player.x < enemy.x
        local scale = mathAbs(enemy.xScale)
        enemy.xScale = playerInTheLeft and -scale or scale

        if enemy.inSpawnAnim then
            -- Пока идет анимация, никаких действий. И уж тем более никакой гибели от Барьера
        elseif not self:isObjInsideBorder(enemy) then
            if enemy.enemyType == enemyTypeGuard then
                -- Страж не гибнет от барьера, а, как и портал, движется с ним
                self:moveTo(enemy, { x = 0, y = 0 }, borderRadiusSpeed, deltaTime)
            else
                to_delete[#to_delete + 1] = i
            end
        else
            self:updateEnemy(enemy, deltaTime)
        end
    end

    for i = #to_delete, 1, -1 do
        self:enemyDied(to_delete[i], true)
    end
end

function scene:makeSomeBlood(obj, isEnemy)
    if isEnemy then
        if obj.fill ~= nil then
            obj.fill.effect = "filter.brightness"
            obj.fill.effect.intensity = 0.9

            timerPerformWithDelay(100, function()
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

    local scale = mathRandom(80, 120) / 100
    bloodImage.xScale = scale
    bloodImage.yScale = scale
    bloodImage.rotation = mathRandom(360)

    timerPerformWithDelay(100, function()
        bloodImage:removeSelf()
    end)
end

function scene:enemyGotDamage(enemyIdx, ammo)
    local damage = ammo.damage
    local enemy = self.enemies[enemyIdx]

    if enemy == nil then
        -- похоже что этого врага уже и так разорвало ракетницей
        return
    end

    if enemy.enemyType == enemyTypeGuard then
        -- страж портала неуязвим
        return
    end

    self:makeSomeBlood(enemy, true)

    local HP = enemy.HP - damage
    if HP <= 0 then
        self:enemyDied(enemyIdx, false, ammo)
    else
        enemy.HP = HP
    end
end

function scene:getNewPortslsCount()
    local cnt = self.portalsCreatedForAllTime
    if cnt <= 4 then -- первые два предполагаются учетными (с текстом на экране)
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

function scene:portalDestroed(portalIdx, playerAmmo)
    local portal = self.portals[portalIdx]

    if portal.guard then
        -- если у портала был Страж, то он тоже гибнет
        for enemyIdx = 1, #self.enemies do
            local enemy = self.enemies[enemyIdx]
            if enemy == portal.guard then
                enemy.portal = nil
                portal.guard = nil
                self:enemyDied(enemyIdx, false, playerAmmo)
                break
            end
        end
    end

    -- маркер, указывающий на портал, тоже больше не нужен
    portal.pointerToPortal:removeSelf()
    portal.pointerToPortal = nil

    self:dropAmmo(enemyTypePortal, portal)

    portal:removeSelf()
    tableRemove(self.portals, portalIdx)

    self:updateScores()

    self.totalScore = self.totalScore + 100 -- да.... хардкод

    self.borderRadius = self.borderRadius + 250
    audio.play(self.soundExtension)
    transitionTo(self.border.path, {
        time = 1000,
        radius = self.borderRadius,
        transition = easingOutBack,
        onComplete = function()
            self.borderRadius = self.border.path.radius
        end,
    })
    transitionTo(self.border.fill, {
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
        -- похоже что этот портал уже и так разорвало ракетницей
        return
    end

    local HP = portal.HP - damage
    if HP <= 0 then
        self:portalDestroed(portalIdx, ammo)
    else
        portal.HP = HP
        self:makeSomeBlood(portal, true)
    end
end

function scene:getEnemyDamage(enemy)
    return enemyInfo.damages[enemy.enemyType]
end

function scene:playerCheckCollisions()
    if not self:isObjInsideBorder(self.player, self.player.playerImage.width * mathSqrt(2)) then
        self:playerGotDamage(damageFromBorder)
        return
    end

    for enemyIdx = 1, #self.enemies do
        local enemy = self.enemies[enemyIdx]
        if hasCollidedCircle(self.player, enemy) then
            self:playerGotDamage(self:getEnemyDamage(enemy))
            if enemy.enemyType == enemyTypeFast then
                self:fastEnemyExplosion(self.player)
                self:enemyDied(enemyIdx, true)
            end
            return
        end
    end

    for i = 1, #self.portals do
        local portal = self.portals[i]
        if hasCollidedCircle(self.player, portal) then
            self:playerGotDamage(damageFromPortal)
            return
        end
    end
end

function scene:updateHealthBar()
    local hp = self.playerHP
    for i = 1, #self.healthBars do
        local hb = self.healthBars[i]

        local needIndex = 0
        if hp >= i * 2 then
            needIndex = healthBarFrameFull
        elseif hp >= (i * 2) - 1 then
            needIndex = healthBarFrameHalf
        else
            needIndex = healthBarFrameNone
        end

        if hb.frame ~= needIndex then
            hb:setFrame(needIndex)
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

    -- смена анимаций
    if isMoving and self.player.playerImage.sequence ~= "run" then
        self.player.playerImage:setSequence("run")
        self.player.playerImage:play()
    elseif not isMoving and self.player.playerImage.sequence ~= "stay" then
        self.player.playerImage:setSequence("stay")
        self.player.playerImage:play()
    end

    -- перемещение игрока
    self.player.x = self.player.x + dX
    self.player.y = self.player.y + dY

    -- "камера" следует за игроком
    self.levelGroup.x = self.levelGroup.x - dX
    self.levelGroup.y = self.levelGroup.y - dY

    -- направление взгляда
    local dir = (self.mousePos.x > 0) and 1 or -1
    self.player.xScale = dir

    -- направление пушки
    local vec = { x = self.mousePos.x, y = -self.mousePos.y }
    if vec.y == 0 then
        return
    end
    local angle = vectorToAngle(vec)

    if self.player.xScale < 0 then
        angle = 360 - angle
    end
    self.player.gun.rotation = angle - 90

    -- стрельба
    if self.pressedKeys.mouseLeft then
        local currentTime = systemGetTimer()
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
    local scale = (2 * rocketDamageRadius) / explosionImageSize
    explosionImage.xScale = scale
    explosionImage.yScale = scale

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
        -- пока без особенностей для обычных пушек
        return false
    end

    self:explosion(enemyOrPortal)

    -- нужно нанести урон всем противникам в области
    local to_delete = {}
    for enemyIdx = 1, #self.enemies do
        local enemy = self.enemies[enemyIdx]
        if distanceBetween(ammo, enemy) < rocketDamageRadius then
            to_delete[#to_delete + 1] = enemyIdx
        end
    end

    for i = #to_delete, 1, -1 do
        local enemyIdx = to_delete[i]
        self:enemyGotDamage(enemyIdx, ammo)
    end

    local to_delete = {}
    for portalIdx = 1, #self.portals do
        local portal = self.portals[portalIdx]
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

-- updateAmmo вернет true, если пулю нужно удалять
function scene:updateAmmo(ammo, deltaTime)
    local collided = false

    local got_damage = {}
    for enemyIdx = 1, #self.enemies do
        local enemy = self.enemies[enemyIdx]
        if hasCollidedCircle(ammo, enemy) then
            if not self:ammoCollideAnim(ammo, enemy) then -- может удалять то, что было задано в got_damage
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
    for i = 1, #self.portals do
        local portal = self.portals[i]
        if hasCollidedCircle(ammo, portal) then
            if not self:ammoCollideAnim(ammo, portal) then -- может удалять то, что было задано в got_damage
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
    -- Пули игрока
    local to_delete = {}
    for i = 1, #self.ammoInFlight do
        local ammo = self.ammoInFlight[i]

        if not self:isObjInsideBorder(ammo) then
            to_delete[#to_delete + 1] = i
        elseif self:updateAmmo(ammo, deltaTime) then
            -- Пуля с чем-то столкнулась, тоже удаляем
            to_delete[#to_delete + 1] = i
        end
    end

    for i = #to_delete, 1, -1 do
        local ammo = self.ammoInFlight[to_delete[i]]
        tableRemove(self.ammoInFlight, to_delete[i])
        self:ammoPut(ammo)
    end

    -- Пули врагов
    local to_delete = {}
    for i = 1, #self.enemyAmmoInFlight do
        local ammo = self.enemyAmmoInFlight[i]

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
        tableRemove(self.enemyAmmoInFlight, to_delete[i])
        ammo:removeSelf()
    end
end

function scene:updateAmmoDrops(deltaTime)
    local to_delete = {}
    for i = 1, #self.ammoDrops do
        local drop = self.ammoDrops[i]

        if not self:isObjInsideBorder(drop) then
            to_delete[#to_delete + 1] = i
        elseif hasCollidedCircle(self.player, drop) then
            local can_delete = true
            if drop.gunType == gunTypeDropHeart then
                if self.playerHP < playerMaximumHealth then
                    audio.play(self.soundHeart)
                    self.playerHP = mathMin(playerMaximumHealth, self.playerHP + drop.quantity)
                    self:updateHealthBar()
                else
                    -- не поднимаем сердечки, если у нас и так уже максимальное здоровье
                    can_delete = false
                end
            else
                audio.play(self.soundAmmo)
                self.ammoAllowed[drop.gunType] = self.ammoAllowed[drop.gunType] + drop.quantity
                self:updateAmmoAllowed(drop.gunType)
            end

            if can_delete then
                to_delete[#to_delete + 1] = i
            end
        end
    end

    for i = #to_delete, 1, -1 do
        local dropIdx = to_delete[i]
        self.ammoDrops[dropIdx]:removeSelf()
        tableRemove(self.ammoDrops, dropIdx)
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
        numFrames = self.gunsCount + 1, -- +1 для сердечка
    }
    self.ammoBlocksImageSheet = graphics.newImageSheet("data/ammo_blocks.png", options)

    local lastHeartSprite = self.healthBars[#self.healthBars]
    local X = lastHeartSprite.x + lastHeartSprite.contentWidth * 1.5

    self.activeGunSelection = display.newRoundedRect(self.view, 0, display.safeScreenOriginY, 1, 1, 10) -- размеры задаются ниже
    self.activeGunSelection.anchorX = 0
    self.activeGunSelection.anchorY = 0
    self.activeGunSelection.fill = { 0.5, 0.5, 0.5 }

    for gunType = 1, self.gunsCount do
        self.ammoAllowed[gunType] = 0

        local icon = display.newRect(0, 0,
            ammoBlockWidth * ammoIconScale,
            ammoBlockHeight * ammoIconScale)
        self.view:insert(icon)
        self.ammoBlocksIcons[gunType] = icon
        icon.fill = { type = "image", sheet = self.ammoBlocksImageSheet, frame = gunType }
        icon.x = X + (gunType - 1) * (2 * lastHeartSprite.contentWidth)
        icon.y = display.safeScreenOriginY - 10
        icon.anchorX = 0
        icon.anchorY = 0
        icon.xScale = appScale
        icon.yScale = appScale

        local text = display.newText({
            parent = self.view,
            text = (gunType == gunTypePistol) and "Inf" or "0",
            width = self.W,
            font = fontName,
            fontSize = 54,
            align = 'left',
        })
        text.iconObj = icon
        text:setFillColor(1, 1, 0.4)
        text.anchorX = 0
        text.anchorY = 0.5
        text.x = icon.x + icon.contentWidth + 10
        text.y = icon.y + icon.contentHeight / 2

        self.ammoBlocksTexts[gunType] = text

        self:updateAmmoAllowed(gunType)
    end

    local gunInfoWidth = self.ammoBlocksTexts[2].x - self.ammoBlocksTexts[1].x
    self.activeGunSelection.width = gunInfoWidth
    self.activeGunSelection.height = lastHeartSprite.contentHeight
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

function scene:setupPauseText()
    self.pauseText = display.newEmbossedText({
        parent = self.view,
        text = "PAUSE",
        font = fontName,
        fontSize = 220,
        align = 'center',
    })
    self.pauseText:setFillColor(1, 0.2, 0.3)
    self.pauseText.anchorX = 0.5
    self.pauseText.anchorY = 0.5
    self.pauseText.x = self.W / 2
    self.pauseText.y = self.H / 2

    local color = {
        highlight = { r = 1, g = 1, b = 1 },
        shadow = { r = 0.1, g = 0.1, b = 0.1 }
    }
    self.pauseText:setEmbossColor(color)

    self.pauseText.isVisible = false
end

function scene:setupDebugText()
    self.debugText = display.newText({
        parent = self.view,
        text = "DEBUG",
        font = fontName,
        fontSize = 30,
        align = 'left',
    })
    self.debugText:setFillColor(0.8, 0.8, 0.8)
    self.debugText.anchorX = 0
    self.debugText.anchorY = 1
    self.debugText.x = display.screenOriginX
    self.debugText.y = display.safeScreenOriginY + display.safeActualContentHeight
end

function scene:setupHealthBar()
    local width = 80

    self.barsImageSheet = graphics.newImageSheet("data/hearts.png", {
        width = width,
        height = 64,
        numFrames = 3,
    })

    self.healthBars = {}
    for i = 1, playerMaximumHealth / 2 do
        local hb = display.newSprite(self.view, self.barsImageSheet, {
            name = "heart",
            start = 1,
            count = 3,
        })
        self.healthBars[i] = hb

        hb:setFrame(healthBarFrameFull)

        hb.x = display.safeScreenOriginX + (i - 1) * (width * appScale)
        hb.y = display.safeScreenOriginY
        hb.anchorX = 0
        hb.anchorY = 0
        hb.xScale = appScale
        hb.yScale = appScale
    end
end

-- ===========================================================================================

function scene:onEnterFrame(event)
    if self.lastEnterFrameTime == 0 then
        self.lastEnterFrameTime = systemGetTimer()
        return
    end
    local deltaTime = (event.time - self.lastEnterFrameTime) / 1000
    self.lastEnterFrameTime = event.time
    if deltaTime <= 0 then
        return
    end

    self.renderedFrames = self.renderedFrames + 1

    self:updateDebug(event.time)

    if self.gameInPause then
        return
    end

    self:updatePlayer(deltaTime)
    self:updateBorderRadius(deltaTime)
    self:updatePortals(deltaTime)
    self:updateEnemies(deltaTime)
    self:updateAmmos(deltaTime)
    self:updateAmmoDrops(deltaTime)
end

function scene:create(event)
    self.soundNoAmmo = audio.loadSound("data/no_ammo.wav")
    self.soundLose = audio.loadSound("data/lose.wav")
    self.soundBoom = audio.loadSound("data/boom.wav")
    self.soundHit = audio.loadSound("data/hit.wav")
    self.soundHeart = audio.loadSound("data/heart.wav")
    self.soundAmmo = audio.loadSound("data/heart.wav") -- пока такой звук
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

    for i = 1, #self.soundGuns do
        audio.dispose(self.soundGuns[i])
    end
    self.soundGuns = {}
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
    audio.stop()

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
    self.ammoDrops = {}
    self.enemyAmmoInFlight = {}
    self.scoresText = nil

    self.portalsCreatedForAllTime = 0
    self.totalScore = 0

    self.playerHP = playerMaximumHealth
    self.playerInvulnBefore = 0

    self.aim = nil

    self.gameInPause = false

    self.borderRadius = 1000
    self.playerSpeed = playerStandartSpeed

    self.enemyImageSheet = nil

    self.gunsCount = 0
    self.gunsImageSheet = nil
    self.ammoImageSheet = nil
    self.ammoBlocksImageSheet = nil

    if self.activeGunSelection ~= nil then
        self.activeGunSelection:removeSelf()
        self.activeGunSelection = nil
    end

    self.enemyAmmoImageSheet = nil
    self.pointsImageSheet = nil
    self.explosionImageSheet = nil
    self.shotFireImageSheet = nil
    self.fastEnemyExplosionImageSheet = nil

    self.ammoBlocksIcons = {}
    self.ammoBlocksTexts = {}

    self.ammoAllowed = {}

    self.lastEnterFrameTime = 0

    self.shotImage = nil

    self.pauseText = nil
    self.debugText = nil

    self.barsImageSheet = nil

    if self.healthBars ~= nil then
        for i = 1, #self.healthBars do
            self.healthBars[i]:removeSelf()
        end
        self.healthBars = {}
    end

    self.poolBullets = nil
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

        scene:setupEnemies()
        scene:setupEnemyAmmo()

        scene:setupPoints()
        scene:setupExplosion()
        scene:setupFastEnemyExplosion()

        scene:setupBorder()

        scene:setupShotFire()

        scene:setupPauseText()
        scene:setupDebugText()

        scene:setupHealthBar()

        scene:setupGunsAndAmmo()

        scene:setupPlayer()

        scene:spawnPortal(true)

        -- для подсчета FPS самому
        scene.renderedFrames = 0
        scene.FPS = display.fps -- хоть что-то, а не 0
        local previousFPS = 0
        scene.FPSCalcTimer = timerPerformWithDelay(1000, function()
            scene.FPS = scene.renderedFrames - previousFPS -- ToDo: хорошо бы поделить на время
            previousFPS = scene.renderedFrames
        end, -1)

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

        timerCancel(scene.FPSCalcTimer)
        scene.FPSCalcTimer = nil

        Runtime:removeEventListener("enterFrame", onEnterFrame)
        Runtime:removeEventListener("key", onKey)
        Runtime:removeEventListener("mouse", onMouseEvent)
    end
end)

return scene
