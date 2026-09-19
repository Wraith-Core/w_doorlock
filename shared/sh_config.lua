Config = {}

-- Key of the door prompt (a w_lib prompt key name: 'E', 'G', 'ENTER' ...) --
Config.KeyPress = 'E'

-- Hold time of the door prompt in ms (false = a plain press, the original behaviour) --
Config.PromptHold = false

-- Position of the door prompt group --
Config.PromptPosition = 'center-left' -- 'bottom-right' | 'center-right' | 'top-right' | 'bottom-left' | 'center-left' | 'top-left'

-- Debug output goes through w.print.debug: set the convar w_lib:printlevel:w_doorlock "debug" to see it.
-- The system language (Arabic / English) is the library's: convar w_lib:locale and the player's /w_lib choice.

-------------------------------------------------

WCore = w.framework:getCoreObject()
