-- BetterPopupTranslateSelection Core Translation Logic
-- API-keyless translation services with fallbacks

local config = dofile(hs.spoons.resourcePath("config.lua"))
local core = {}

-- Google Translate using web endpoint (no API key required)
function core.googleTranslate(text, targetLang, sourceLang, callback)
    targetLang = targetLang or config.DEFAULT_TARGET_LANG
    sourceLang = sourceLang or config.DEFAULT_SOURCE_LANG
    
    config.log("Google Translate:", sourceLang, "->", targetLang)
    
    local url = string.format(
        "https://translate.googleapis.com/translate_a/single?client=gtx&sl=%s&tl=%s&dt=t&q=%s",
        sourceLang, targetLang, hs.http.encodeForQuery(text)
    )
    
    hs.http.doAsyncRequest(url, "GET", nil, nil, function(status, body, headers)
        if status == 200 then
            local success, response = pcall(hs.json.decode, body)
            if success and response then
                local translatedText = nil
                local detectedLang = sourceLang
                
                -- Extract and concatenate all translation parts
                if response[1] then
                    local parts = {}
                    for i, part in ipairs(response[1]) do
                        if part[1] then
                            table.insert(parts, part[1])
                        end
                    end
                    if #parts > 0 then
                        translatedText = table.concat(parts, "")
                    end
                end
                
                -- Extract detected language
                if response[2] then
                    detectedLang = response[2] or sourceLang
                elseif response[8] and response[8][1] and response[8][1][1] then
                    detectedLang = response[8][1][1] or sourceLang
                end
                
                if translatedText then
                    config.log("Google translation successful, detected:", detectedLang)
                    callback(translatedText, nil, detectedLang)
                else
                    config.log("No translation found in Google response")
                    callback(nil, "No translation found")
                end
            else
                config.log("Failed to parse Google response")
                callback(nil, "Failed to parse translation response")
            end
        else
            config.log("Google Translate HTTP error:", status)
            callback(nil, "Translation service error: " .. tostring(status))
        end
    end)
end

-- LibreTranslate as fallback (no API key required)
function core.libreTranslate(text, targetLang, sourceLang, callback)
    targetLang = targetLang or config.DEFAULT_TARGET_LANG
    sourceLang = sourceLang or config.DEFAULT_SOURCE_LANG
    
    config.log("LibreTranslate:", sourceLang, "->", targetLang)
    
    local url = "https://libretranslate.de/translate"
    local payload = string.format("q=%s&source=%s&target=%s&format=text",
        hs.http.encodeForQuery(text), sourceLang, targetLang)
    
    local headers = { ["Content-Type"] = "application/x-www-form-urlencoded" }
    
    hs.http.doAsyncRequest(url, "POST", payload, headers, function(status, body, headers)
        if status == 200 then
            local success, response = pcall(hs.json.decode, body)
            if success and response and response.translatedText then
                config.log("LibreTranslate successful")
                callback(response.translatedText, nil, sourceLang)
            else
                config.log("Failed to parse LibreTranslate response")
                callback(nil, "Failed to parse translation")
            end
        else
            config.log("LibreTranslate HTTP error:", status)
            callback(nil, "LibreTranslate error: " .. tostring(status))
        end
    end)
end

-- macOS native translation using Shortcuts
function core.macosTranslate(text, targetLang, callback)
    config.log("Attempting macOS native translation")
    
    local shortcutScript = string.format([[
        do shell script "echo '%s' | shortcuts run 'Translate Text' 2>/dev/null || echo ''"
    ]], text:gsub("'", "'\\''"))
    
    hs.osascript.applescript(shortcutScript, function(success, result, descriptor)
        if success and result and result ~= "" then
            config.log("macOS translation successful")
            callback(result, nil, "auto")
        else
            config.log("macOS translation not available")
            callback(nil, "macOS translation not available")
        end
    end)
end

-- Main translation function with intelligent fallbacks
function core.translate(text, targetLang, sourceLang, callback)
    targetLang = targetLang or config.DEFAULT_TARGET_LANG
    sourceLang = sourceLang or config.DEFAULT_SOURCE_LANG
    
    config.log("Starting translation:", #text, "chars")
    
    if config.USE_GOOGLE_FIRST then
        core.googleTranslate(text, targetLang, sourceLang, function(result, error, detectedLang)
            if result then
                callback(result, nil, detectedLang or sourceLang, targetLang)
            else
                config.log("Google failed, trying LibreTranslate")
                core.libreTranslate(text, targetLang, sourceLang, function(result2, error2, detectedLang2)
                    if result2 then
                        callback(result2, nil, detectedLang2 or sourceLang, targetLang)
                    elseif config.USE_MACOS_FALLBACK then
                        config.log("LibreTranslate failed, trying macOS")
                        core.macosTranslate(text, targetLang, function(result3, error3, detectedLang3)
                            callback(result3, error3 or error2 or error, detectedLang3 or sourceLang, targetLang)
                        end)
                    else
                        callback(nil, error2 or error, sourceLang, targetLang)
                    end
                end)
            end
        end)
    else
        core.libreTranslate(text, targetLang, sourceLang, function(result, error, detectedLang)
            callback(result, error, detectedLang or sourceLang, targetLang)
        end)
    end
end

return core