local hyper = {"ctrl", "alt", "cmd"}

-- reload configuration
hs.loadSpoon("ReloadConfiguration")
spoon.ReloadConfiguration:start()

-- fetch not-checked-in settings
local my_config = {}
pcall(function()
  my_config = dofile(hs.configdir .. "/my_config.lua")
end)

-- defeat paste blocking
hs.hotkey.bind(hyper, "V", function() hs.eventtap.keyStrokes(hs.pasteboard.getContents()) end)

hs.loadSpoon("SpoonInstall")
spoon.SpoonInstall.use_syncinstall = true

-- clipboard
spoon.SpoonInstall:andUse("ClipboardTool", {
  start = true,
  hotkeys = {
    show_clipboard = {hyper, "c"},
  },
})

-- caffeine
hs.caffeinate.set("displayIdle", my_config.prevent_screen_sleep or false, true)
spoon.SpoonInstall:andUse("Caffeine", { start = true })

-- push-to-talk for zoom
spoon.SpoonInstall:andUse("PushToTalk", {
  start = true,
  config = {
    defaultState = 'push-to-talk',
    app_switcher = { ['zoom.us'] = 'push-to-talk' }
  }
})

-- window movement
hs.loadSpoon('MiroWindowsManager')
spoon.MiroWindowsManager:bindHotkeys({
    up = {hyper, "up"},
    right = {hyper, "right"},
    down = {hyper, "down"},
    left = {hyper, "left"},
    fullscreen = {hyper, "f"},
})
spoon.MiroWindowsManager.sizes = {2, 3, 6/5, 3/2}
spoon.MiroWindowsManager.GRID = {w = 6, h = 1}
hs.window.animationDuration = 0

-- stay
hs.loadSpoon('Stay')
spoon.Stay.logger.setLogLevel('debug')
spoon.Stay:start()

-- ControlEscape
hs.loadSpoon('ControlEscape'):start() -- Load Hammerspoon bits from https://github.com/jasonrudolph/ControlEscape.spoon

-- Text expansion
ht = hs.loadSpoon("HammerText")
ht.keywords = my_config.ht_keywords or {}
ht:start()

-- regular scrolling for non-continuous input devices
reverse_mouse_scroll = hs.eventtap.new({hs.eventtap.event.types.scrollWheel}, function(event)
    -- detect if this is touchpad or mouse
    local isTrackpad = event:getProperty(hs.eventtap.event.properties.scrollWheelEventIsContinuous)
    if isTrackpad == 1 then
        return false -- trackpad: pass the event along
    end

    event:setProperty(hs.eventtap.event.properties.scrollWheelEventDeltaAxis1,
        -event:getProperty(hs.eventtap.event.properties.scrollWheelEventDeltaAxis1))
    return false -- pass the event along
end):start()
