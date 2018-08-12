local composer = require("composer")

math.randomseed(os.time())
display.setStatusBar(display.HiddenStatusBar)

function myUnhandledErrorListener(event)
    print("OOOPS", event.errorMessage) -- ToDo: отсылать на сервак?
    return true
end

Runtime:addEventListener("unhandledError", myUnhandledErrorListener)

display.setDefault( "textureWrapX", "repeat" )
display.setDefault( "textureWrapY", "repeat" )

composer.gotoScene("scenes.menu")
