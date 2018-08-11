local composer = require("composer")

math.randomseed(os.time())
display.setStatusBar(display.HiddenStatusBar)

function myUnhandledErrorListener(event)
    print("OOOPS", event.errorMessage) -- ToDo: �������� �� ������?
    return true
end

Runtime:addEventListener("unhandledError", myUnhandledErrorListener)

composer.gotoScene("scenes.game")
