-- BetterPopupTranslateSelection Configuration
-- All configurable parameters externalized for versatility

local config = {
    -- Debug and logging
    DEBUG = false,
    
    -- App targeting (array of app names, use {"*"} for all apps)
    -- Default: empty (spoon inactive until configured)
    APP_NAMES = {},
    
    -- Translation settings
    DEFAULT_TARGET_LANG = "en",
    DEFAULT_SOURCE_LANG = "auto",
    
    -- UI dimensions and behavior
    POPUP_WIDTH = 500,
    POPUP_MIN_HEIGHT = 60,
    POPUP_MAX_HEIGHT = 800,
    POPUP_PADDING = 15,
    POPUP_AUTO_HIDE_DELAY = 15,
    
    -- Context menu settings
    CONTEXT_MENU_WIDTH = 180,
    CONTEXT_MENU_HEIGHT = 45,
    SHOW_CONTEXT_ON_SELECTION = true,
    
    -- Hotkeys (set to nil to disable)
    HOTKEY_TRANSLATE = { { "cmd", "shift" }, "t" },
    HOTKEY_GLOBAL = { { "cmd", "shift" }, "g" },
    
    -- Translation service preferences
    USE_GOOGLE_FIRST = true,
    USE_MACOS_FALLBACK = true,
    
    -- Interaction timing
    DOUBLE_CLICK_INTERVAL = 0.3,
    SELECTION_DELAY = 0.2,
    CLIPBOARD_DELAY = 200000,
    
    -- Language display names
    LANG_NAMES = {
        en = "English", es = "Spanish", fr = "French", de = "German", it = "Italian",
        pt = "Portuguese", ru = "Russian", ja = "Japanese", ko = "Korean", zh = "Chinese",
        ar = "Arabic", hi = "Hindi", auto = "Auto"
    }
}

-- Debug logging function
function config.log(...)
    if config.DEBUG then
        print("[BetterPopupTranslateSelection]", ...)
    end
end

-- Get language display name
function config.getLangName(code)
    if not code then return "Auto" end
    if type(code) ~= "string" then code = tostring(code) end
    return config.LANG_NAMES[code] or code:upper()
end

-- Check if current app matches target apps
function config.isTargetApp(appName)
    if not appName then return false end
    
    -- Return false if no apps configured (spoon inactive)
    if #config.APP_NAMES == 0 then return false end
    
    -- Check if monitoring all apps
    for _, name in ipairs(config.APP_NAMES) do
        if name == "*" then return true end
    end
    
    -- Check for exact or partial match
    for _, name in ipairs(config.APP_NAMES) do
        if appName == name or appName:find(name) then
            return true
        end
    end
    
    return false
end

-- Load JSON config from file
function config.loadJSON()
    local configPath = os.getenv("HOME") .. "/.config/hammerspoon-bpts/config.json"
    local file = io.open(configPath, "r")
    
    if file then
        local content = file:read("*all")
        file:close()
        
        local success, jsonConfig = pcall(hs.json.decode, content)
        if success and jsonConfig then
            config.log("Loaded JSON config from:", configPath)
            return jsonConfig
        else
            config.log("Failed to parse JSON config:", configPath)
        end
    else
        config.log("No JSON config found at:", configPath)
    end
    
    return nil
end

-- Configuration update method (merges config into current)
function config.update(userConfig)
    if userConfig then
        for key, value in pairs(userConfig) do
            if config[key] ~= nil or key == "APP_NAME" then
                config[key] = value
            end
        end
        -- Handle legacy APP_NAME config
        if userConfig.APP_NAME then
            config.APP_NAMES = {userConfig.APP_NAME}
        end
    end
end

return config