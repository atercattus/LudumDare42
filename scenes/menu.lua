local composer = require("composer")

local scene = composer.newScene()

local gameName = 'Weeding of Demons'

local fontName = 'data/kitchen-police.regular.ttf' -- https://www.1001fonts.com/kitchen-police-font.html

-- ===========================================================================================

function scene:create(event)
    local W, H = display.contentWidth, display.contentHeight
    local sceneGroup = self.view

    local titleText = display.newText({ text = gameName, width = W, font = fontName, fontSize = 72, align = 'center' })
    sceneGroup:insert(titleText)
    titleText:setFillColor(1, 1, 0.4)
    titleText.anchorX = 0.5
    titleText.anchorY = 0
    titleText.x = W / 2
    titleText.y = 10

    local controls = [[
Destroy all demonic portals

Beware of the barrier



Controls

Movement:
WSAD or Arrow Keys

Select gun:
1,2,3,4 or mouse wheel

Fire:
Left mouse button
        ]]

    local controlsText = display.newText({ text = controls, width = W, font = fontName, fontSize = 46, align = 'center' })
    sceneGroup:insert(controlsText)
    controlsText:setFillColor(0.8, 0.8, 0.8)
    controlsText.anchorX = 0
    controlsText.anchorY = 0
    controlsText.x = 0
    controlsText.y = 150

    local startGameText = display.newText({ text = 'Fight!', width = W, font = fontName, fontSize = 90, align = 'center' })
    sceneGroup:insert(startGameText)
    startGameText:setFillColor(1, 1, 1)
    startGameText.anchorX = 0.5
    startGameText.anchorY = 0.5
    startGameText.x = W / 2
    startGameText.y = H - (H - (controlsText.y + controlsText.height)) / 2

    startGameText:addEventListener("touch", function(event)
        if event.phase == 'ended' then
            composer.gotoScene('scenes.game')
            return true
        end
        return false
    end)

    local startGameTextScaleFunc
    startGameTextScaleFunc = function()
        transition.scaleTo(startGameText, {
            time = 1500,
            xScale = 1.2,
            yScale = 1.2,
            onComplete = function()
                transition.scaleTo(startGameText, { time = 1500, xScale = 1, yScale = 1, onComplete = startGameTextScaleFunc })
            end
        })
    end
    startGameTextScaleFunc()
end

scene:addEventListener("create", scene)

return scene
