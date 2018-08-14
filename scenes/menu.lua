local composer = require("composer")

local scene = composer.newScene()

local gameName = 'Oh no! This is monsters!'

local fontName = 'data/ErikaOrmig.ttf' -- https://www.1001fonts.com/erika-ormig-font.html

-- ===========================================================================================

function scene:create(event)
    local W, H = display.contentWidth, display.contentHeight
    local sceneGroup = self.view

    local titleText = display.newText({ text = gameName, width = W, font = fontName, fontSize = appScale * 90, align = 'center' })
    sceneGroup:insert(titleText)
    titleText:setFillColor(1, 1, 0.4)
    titleText.anchorX = 0.5
    titleText.anchorY = 0
    titleText.x = W / 2
    titleText.y = 10

    local howto = [[
Destroy all portals!

Do not touch the Barrier]]

    local howtoText = display.newText({ text = howto, width = W, font = fontName, fontSize = appScale * 54, align = 'center' })
    sceneGroup:insert(howtoText)
    howtoText:setFillColor(0.8, 0.8, 0.8)
    howtoText.anchorX = 0
    howtoText.anchorY = 0
    howtoText.x = 0
    howtoText.y = titleText.contentHeight + titleText.y + 40

    local controls = display.newImageRect("data/controls.png", 512, 512)
    sceneGroup:insert(controls)
    controls.x = W / 2
    controls.y = howtoText.contentHeight + howtoText.y
    controls.anchorX = 0.5
    controls.anchorY = 0
    controls.xScale = appScale
    controls.yScale = appScale

    scene.mouseReleased = false
    scene.mouseClicked = false
    self.view:addEventListener("mouse", function(event)
        if event.isPrimaryButtonDown then
            if scene.mouseReleased then
                scene.mouseClicked = true
            end
        else
            if not scene.mouseReleased then
                scene.mouseReleased = true
            elseif scene.mouseClicked then
                scene.mouseReleased = false
                scene.mouseClicked = false
                composer.gotoScene('scenes.game')
            end
        end
        return true
    end)

    local startGameScaleFunc
    startGameScaleFunc = function()
        transition.scaleTo(controls, {
            time = 2500,
            xScale = appScale * 1.07,
            yScale = appScale * 1.07,
            onComplete = function()
                transition.scaleTo(controls, { time = 2500, xScale = appScale * 1, yScale = appScale * 1, onComplete = startGameScaleFunc })
            end
        })
    end
    startGameScaleFunc()
end

scene:addEventListener("create", scene)

scene:addEventListener("show", function(event)
    scene.mouseReleased = false
    scene.mouseClicked = false
end)

return scene
