-- BetterPopupTranslateSelection.spoon
-- Versatile translation popup with Chrome-style UI and app-configurable targeting
-- Supports API-keyless Google Translate, LibreTranslate, and macOS fallbacks

local obj = {}
obj.__index = obj

-- Metadata
obj.name = "BetterPopupTranslateSelection"
obj.version = "1.0"
obj.author = "VipTalk Translation"
obj.homepage = "https://github.com/Hammerspoon/hammerspoon"
obj.license = "MIT"

-- Load modular components using dofile (Hammerspoon Spoon requirement)
local config = dofile(hs.spoons.resourcePath("config.lua"))
local core = dofile(hs.spoons.resourcePath("core.lua"))
local ui = dofile(hs.spoons.resourcePath("ui.lua"))

-- State management
obj.lastSelectedText = nil
obj.clickTimer = nil
obj.clickCount = 0
obj.eventTaps = {}
obj.currentSelectedText = nil
obj.originalApp = nil
obj.luaConfig = nil  -- Store lua-provided config for later application

-- Get selected text using accessibility API and clipboard fallback
local function getSelectedText()
    config.log("Getting selected text...")
    
    -- Method 1: Accessibility API
    local elem = hs.uielement.focusedElement()
    if elem then
        local text = elem:selectedText()
        if text and text:len() > 0 then
            config.log("Got text from accessibility API:", text:sub(1, 50))
            return text
        end
    end
    
    -- Method 2: Clipboard method (preserving original)
    config.log("Trying clipboard method...")
    local oldClipboard = hs.pasteboard.getContents()
    hs.eventtap.keyStroke({"cmd"}, "c")
    hs.timer.usleep(config.CLIPBOARD_DELAY)
    local newClipboard = hs.pasteboard.getContents()
    
    if newClipboard and newClipboard ~= oldClipboard then
        config.log("Got text from clipboard:", newClipboard:sub(1, 50))
        hs.timer.doAfter(0.5, function()
            if hs.pasteboard.getContents() == newClipboard then
                hs.pasteboard.setContents(oldClipboard)
            end
        end)
        return newClipboard
    end
    
    config.log("No text found")
    return nil
end

-- Main translation orchestration
local function translateSelection(targetLang, sourceLang, text, skipAppCheck)
    local app = hs.application.frontmostApplication()
    local appName = app and app:name() or "Unknown"
    config.log("translateSelection called - Current app:", appName, "Skip check:", skipAppCheck)
    
    local appToRestore = obj.originalApp or app
    
    -- Check app targeting unless skipped
    if not skipAppCheck and not config.isTargetApp(appName) then
        config.log("Not target app, current:", appName, "targets:", table.concat(config.APP_NAMES, ", "))
        return
    end
    
    text = text or getSelectedText()
    
    if text and text:len() > 0 then
        config.log("Translating text of length:", text:len())
        hs.alert.show("Translating...", 0.5)
        
        core.translate(text, targetLang, sourceLang, function(translation, error, detectedSource, usedTarget)
            config.log("Translation callback received, success:", translation ~= nil)
            
            -- Restore focus before showing popup
            if appToRestore and appToRestore:name() ~= "Hammerspoon" then
                config.log("Restoring focus to:", appToRestore:name())
                appToRestore:activate()
                hs.timer.doAfter(0.05, function()
                    if translation then
                        ui.showPopup(text, translation, detectedSource, usedTarget)
                    else
                        ui.showError(error or "Unknown error")
                    end
                    obj.originalApp = nil
                end)
            else
                if translation then
                    ui.showPopup(text, translation, detectedSource, usedTarget)
                else
                    ui.showError(error or "Unknown error")
                end
                obj.originalApp = nil
            end
        end)
        
        obj.lastSelectedText = text
    else
        config.log("No text selected")
        hs.alert.show("No text selected", 1)
    end
end

-- Show context menu for selected text
local function showSelectionContextMenu()
    local text = getSelectedText()
    if text and text:len() > 0 then
        config.log("Showing context menu for selection")
        obj.currentSelectedText = text
        
        -- Store current app BEFORE showing menu (important!)
        obj.originalApp = hs.application.frontmostApplication()
        local appName = obj.originalApp and obj.originalApp:name() or "Unknown"
        config.log("Storing original app:", appName)
        
        -- Show context menu with translate callback
        ui.showContextMenu(text, function()
            config.log("Context menu callback triggered for text:", obj.currentSelectedText:sub(1, 50))
            config.log("Original app was:", obj.originalApp and obj.originalApp:name() or "Unknown")
            
            -- Call translateSelection with a flag to skip app check
            translateSelection(config.DEFAULT_TARGET_LANG, config.DEFAULT_SOURCE_LANG, obj.currentSelectedText, true)
        end)
    else
        config.log("No text selected for context menu")
    end
end

-- Configuration method for external customization
function obj:configure(userConfig)
    -- Store lua config to be applied during init (highest priority)
    obj.luaConfig = userConfig
    return self
end

-- Initialize the spoon
function obj:init()
    -- Clean up any existing handlers first to prevent duplicates
    if obj.eventTaps then
        for _, tap in pairs(obj.eventTaps) do
            if tap then tap:stop() end
        end
    end
    obj.eventTaps = {}
    
    config.log("Initializing BetterPopupTranslateSelection")
    
    -- Apply configuration in priority order: default -> json -> lua
    -- 1. Default config is already loaded
    -- 2. Apply JSON config if it exists
    local jsonConfig = config.loadJSON()
    if jsonConfig then
        config.update(jsonConfig)
    end
    
    -- 3. Apply lua-provided config if it exists (highest priority)
    if obj.luaConfig then
        config.update(obj.luaConfig)
    end
    
    -- Check if any apps are configured
    if #config.APP_NAMES == 0 then
        print("========================================")
        print("BetterPopupTranslateSelection: INACTIVE")
        print("No apps configured. Configure with:")
        print("  :configure({ APP_NAMES = {\"AppName\"} })")
        print("  or create ~/.config/hammerspoon-bpts/config.json")
        print("========================================")
        return self
    end
    
    -- Set up hotkeys if configured
    if config.HOTKEY_TRANSLATE then
        hs.hotkey.bind(config.HOTKEY_TRANSLATE[1], config.HOTKEY_TRANSLATE[2], function()
            config.log("Translation hotkey pressed")
            translateSelection(config.DEFAULT_TARGET_LANG, config.DEFAULT_SOURCE_LANG, nil, false)
        end)
    end
    
    if config.HOTKEY_GLOBAL then
        hs.hotkey.bind(config.HOTKEY_GLOBAL[1], config.HOTKEY_GLOBAL[2], function()
            config.log("Global translation hotkey pressed")
            local oldAppNames = config.APP_NAMES
            config.APP_NAMES = {"*"}
            translateSelection(config.DEFAULT_TARGET_LANG, config.DEFAULT_SOURCE_LANG, nil, false)
            config.APP_NAMES = oldAppNames
        end)
    end
    
    -- Double-click detection
    obj.eventTaps.doubleClick = hs.eventtap.new({hs.eventtap.event.types.leftMouseDown}, function(event)
        local app = hs.application.frontmostApplication()
        local appName = app and app:name() or "Unknown"
        
        if app and config.isTargetApp(appName) then
            obj.clickCount = obj.clickCount + 1
            config.log("Click detected in", appName, "count:", obj.clickCount)
            
            if obj.clickCount == 1 then
                if obj.clickTimer then obj.clickTimer:stop() end
                obj.clickTimer = hs.timer.doAfter(config.DOUBLE_CLICK_INTERVAL, function()
                    obj.clickCount = 0
                end)
            elseif obj.clickCount == 2 then
                obj.clickCount = 0
                if obj.clickTimer then obj.clickTimer:stop(); obj.clickTimer = nil end
                
                hs.timer.doAfter(config.SELECTION_DELAY, function()
                    config.log("Processing double-click selection")
                    if config.SHOW_CONTEXT_ON_SELECTION then
                        showSelectionContextMenu()
                    else
                        translateSelection(config.DEFAULT_TARGET_LANG, config.DEFAULT_SOURCE_LANG, nil, false)
                    end
                end)
            elseif obj.clickCount > 2 then
                obj.clickCount = 0
            end
        end
        
        return false
    end)
    
    -- Text selection detection (mouse drag)
    local mouseDownTime = nil
    local mouseDownPos = nil
    local dragDetected = false
    
    obj.eventTaps.selection = hs.eventtap.new({
        hs.eventtap.event.types.leftMouseDown,
        hs.eventtap.event.types.leftMouseUp,
        hs.eventtap.event.types.leftMouseDragged
    }, function(event)
        local app = hs.application.frontmostApplication()
        local appName = app and app:name() or "Unknown"
        
        if app and config.isTargetApp(appName) then
            local eventType = event:getType()
            
            if eventType == hs.eventtap.event.types.leftMouseDown then
                mouseDownTime = hs.timer.absoluteTime()
                mouseDownPos = hs.mouse.absolutePosition()
                dragDetected = false
                
            elseif eventType == hs.eventtap.event.types.leftMouseDragged then
                if mouseDownPos then
                    local currentPos = hs.mouse.absolutePosition()
                    local distance = math.sqrt((currentPos.x - mouseDownPos.x)^2 + (currentPos.y - mouseDownPos.y)^2)
                    if distance > 5 then
                        dragDetected = true
                        config.log("Drag detected, distance:", distance)
                    end
                end
                
            elseif eventType == hs.eventtap.event.types.leftMouseUp then
                if mouseDownTime then
                    local duration = (hs.timer.absoluteTime() - mouseDownTime) / 1000000000
                    config.log("Mouse up, duration:", duration, "drag:", dragDetected)
                    
                    if dragDetected or duration > 0.15 then
                        config.log("Text selection likely, processing...")
                        hs.timer.doAfter(config.SELECTION_DELAY, function()
                            if config.SHOW_CONTEXT_ON_SELECTION then
                                showSelectionContextMenu()
                            else
                                translateSelection(config.DEFAULT_TARGET_LANG, config.DEFAULT_SOURCE_LANG, nil, false)
                            end
                        end)
                    end
                    
                    mouseDownTime = nil
                    mouseDownPos = nil
                    dragDetected = false
                end
            end
        end
        
        return false
    end)
    
    -- Start event taps
    obj.eventTaps.doubleClick:start()
    obj.eventTaps.selection:start()
    
    print("========================================")
    print("BetterPopupTranslateSelection: ACTIVE")
    print("Debug mode:", config.DEBUG and "ON" or "OFF")
    print("Target apps:", (#config.APP_NAMES == 1 and config.APP_NAMES[1] == "*") and "All apps" or table.concat(config.APP_NAMES, ", "))
    if config.HOTKEY_TRANSLATE then
        print("Hotkeys:")
        print("  " .. table.concat(config.HOTKEY_TRANSLATE[1], "+") .. "+" .. config.HOTKEY_TRANSLATE[2] .. ": Translate selected text")
    end
    if config.HOTKEY_GLOBAL then
        print("  " .. table.concat(config.HOTKEY_GLOBAL[1], "+") .. "+" .. config.HOTKEY_GLOBAL[2] .. ": Global translate")
    end
    print("  Double-click: Auto-translate word")
    print("  Text selection: Auto-translate (drag or hold > 0.15s)")
    print("========================================")
    
    return self
end

-- Start the spoon
function obj:start()
    return self
end

-- Stop and cleanup
function obj:stop()
    config.log("Cleaning up BetterPopupTranslateSelection")
    
    for _, tap in pairs(obj.eventTaps) do
        if tap then tap:stop() end
    end
    
    ui.hidePopup()
    ui.hideContextMenu()
    
    return self
end

return obj