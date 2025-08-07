-- BetterPopupTranslateSelection UI Components
-- Chrome-style translation popup with context menu

local config = dofile(hs.spoons.resourcePath("config.lua"))
local ui = {}

-- UI State
local currentPopup = nil
local currentUserContent = nil
local hideTimer = nil
local contextMenu = nil
local contextMenuTimer = nil
local contextMenuClickChecker = nil
local contextMenuEventWatchers = {}
local popupEventWatchers = {}
local buttonChecker = nil
local currentTranslatedText = nil

-- Cleanup function for all watchers and timers
function ui.cleanupAllWatchers()
    if buttonChecker then buttonChecker:stop(); buttonChecker = nil end
    if currentUserContent then currentUserContent = nil end
    
    for key, watcher in pairs(popupEventWatchers) do
        if watcher and type(watcher.stop) == "function" then watcher:stop() end
    end
    popupEventWatchers = {}
    
    for key, watcher in pairs(contextMenuEventWatchers) do
        if watcher and type(watcher.stop) == "function" then watcher:stop() end
    end
    contextMenuEventWatchers = {}
end

ui.cleanupAllWatchers()

-- Create minimalistic Chrome-style popup HTML
function ui.createPopupHTML(translatedText, sourceLang, targetLang)
    local escapedText = translatedText:gsub('&', '&amp;'):gsub('<', '&lt;'):gsub('>', '&gt;')
                                      :gsub('"', '&quot;'):gsub("'", '&#39;'):gsub('\n', '<br>')
    
    return string.format([[
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'SF Pro Text', sans-serif;
            background: white; padding: %dpx; border-radius: 8px;
            box-shadow: 0 4px 20px rgba(0,0,0,0.15); user-select: text;
        }
        .copy-btn {
            margin-top: 12px; padding: 8px 16px; font-size: 13px; color: #5f6368;
            background: #f8f9fa; border: 1px solid #dadce0; border-radius: 4px;
            cursor: pointer; transition: all 0.2s; width: 100%%; text-align: center;
            user-select: none; -webkit-user-select: none;
        }
        .copy-btn:hover { background: #e8eaed; border-color: #c7c7c7; }
        .copy-btn:active { background: #dadce0; }
        .copy-btn.copied { background: #188038; color: white; border-color: #188038; }
        .header { 
            display: flex; justify-content: space-between; align-items: center;
            padding-bottom: 10px; border-bottom: 1px solid #e0e0e0; margin-bottom: 12px;
        }
        .languages { display: flex; align-items: center; font-size: 13px; color: #5f6368; font-weight: 500; }
        .lang-source { color: #1a73e8; }
        .arrow { margin: 0 8px; color: #9aa0a6; }
        .lang-target { color: #188038; }
        .close-btn {
            width: 20px; height: 20px; border: none; background: none; cursor: pointer;
            display: flex; align-items: center; justify-content: center; border-radius: 50%%;
            transition: background 0.2s; user-select: none; -webkit-user-select: none;
        }
        .close-btn:hover { background: #f1f3f4; }
        .translated-text {
            font-size: 16px; color: #202124; line-height: 1.6; word-wrap: break-word;
            word-break: break-word; white-space: pre-wrap; min-height: 40px;
            max-height: calc(100vh - 120px); overflow-y: auto; padding-right: 8px;
            user-select: text; -webkit-user-select: text;
        }
        .translated-text::-webkit-scrollbar { width: 5px; }
        .translated-text::-webkit-scrollbar-track { background: #f1f3f4; border-radius: 2px; }
        .translated-text::-webkit-scrollbar-thumb { background: #dadce0; border-radius: 2px; }
        .translated-text::-webkit-scrollbar-thumb:hover { background: #bdc1c6; }
    </style>
</head>
<body>
    <div class="header">
        <div class="languages">
            <span class="lang-source">%s</span>
            <span class="arrow">→</span>
            <span class="lang-target">%s</span>
        </div>
        <button class="close-btn" id="closeBtn">
            <svg viewBox="0 0 24 24" fill="#5f6368" width="16" height="16">
                <path d="M19 6.41L17.59 5 12 10.59 6.41 5 5 6.41 10.59 12 5 17.59 6.41 19 12 13.41 17.59 19 19 17.59 13.41 12z"/>
            </svg>
        </button>
    </div>
    <div class="translated-text" id="translatedText">%s</div>
    <button class="copy-btn" id="copyBtn">Copy translation</button>
    
    <script>
        window.closeClicked = false;
        window.copyClicked = false;
        
        function sendMessage(action, data) {
            try {
                if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.popupHandler) {
                    window.webkit.messageHandlers.popupHandler.postMessage({ action: action, data: data });
                    return;
                }
            } catch (error) {}
            
            if (action === 'close-popup') window.closeClicked = true;
            else if (action === 'copy-translation') window.copyClicked = true;
        }
        
        document.getElementById('closeBtn').addEventListener('click', function() {
            sendMessage('close-popup');
        });
        
        document.getElementById('copyBtn').addEventListener('click', function(e) {
            e.preventDefault(); e.stopPropagation();
            const btn = document.getElementById('copyBtn');
            btn.classList.add('copied'); btn.innerText = 'Copied!';
            sendMessage('copy-translation');
            setTimeout(() => {
                if (btn) { btn.classList.remove('copied'); btn.innerText = 'Copy translation'; }
            }, 2000);
        });
        
        document.addEventListener('keydown', (e) => {
            if (e.key === 'Escape') sendMessage('close-popup');
        });
    </script>
</body>
</html>]], config.POPUP_PADDING, config.getLangName(sourceLang), config.getLangName(targetLang), escapedText)
end

-- Safe clipboard operation with error handling
local function safeSetClipboard(text)
    config.log("Setting clipboard content:", text and text:sub(1, 50) or "nil")
    
    hs.pasteboard.clearContents()
    hs.timer.usleep(50000) -- 50ms delay
    
    local success = hs.pasteboard.setContents(text)
    config.log("Clipboard setContents success:", success)
    
    hs.timer.doAfter(0.1, function()
        local verification = hs.pasteboard.getContents()
        config.log("Clipboard verification:", verification and verification:sub(1, 50) or "nil")
        if success then
            hs.alert.show("Copied!", 0.5)
        else
            hs.alert.show("Copy failed!", 1)
        end
    end)
    
    return success
end

-- Show translation popup with dynamic sizing
function ui.showPopup(originalText, translatedText, sourceLang, targetLang)
    config.log("Showing popup:", sourceLang, "->", targetLang)
    
    if currentPopup then ui.hidePopup() end
    if hideTimer then hideTimer:stop(); hideTimer = nil end
    
    currentTranslatedText = translatedText
    
    -- Calculate dynamic popup dimensions
    local screen = hs.screen.mainScreen():frame()
    local maxHeight = screen.h - 100
    local charCount = #translatedText
    local charsPerLine = 60
    local estimatedLines = math.ceil(charCount / charsPerLine)
    local lineHeight = 26
    local headerHeight = 60
    local buttonHeight = 45
    local padding = config.POPUP_PADDING * 2
    
    local popupHeight = math.min(maxHeight, 
        math.max(config.POPUP_MIN_HEIGHT + headerHeight + buttonHeight,
                headerHeight + padding + buttonHeight + (estimatedLines * lineHeight)))
    
    -- Position popup near mouse
    local mousePos = hs.mouse.absolutePosition()
    local x = mousePos.x - config.POPUP_WIDTH / 2
    local y = mousePos.y - popupHeight - 20
    
    -- Keep popup on screen
    if x < screen.x + 10 then x = screen.x + 10
    elseif x + config.POPUP_WIDTH > screen.x + screen.w - 10 then
        x = screen.x + screen.w - config.POPUP_WIDTH - 10
    end
    if y < screen.y + 10 then y = mousePos.y + 30 end
    
    -- Create user content controller for JavaScript communication
    local userContentController = nil
    local useMessageHandlers = false
    
    if hs.webview.usercontent then
        local success, result = pcall(function()
            return hs.webview.usercontent.new("popupHandler")
        end)
        
        if success and result then
            userContentController = result
            currentUserContent = result
            useMessageHandlers = true
            
            userContentController:setCallback(function(message)
                config.log("Received webview message:", hs.inspect(message))
                local action = nil
                
                if type(message) == "table" then
                    action = message.action or message.body or message[1]
                    if type(action) == "table" then action = action.action end
                elseif type(message) == "string" then
                    action = message
                end
                
                if action == "copy-translation" then
                    if currentTranslatedText then
                        safeSetClipboard(currentTranslatedText)
                        hs.timer.doAfter(0.5, function() ui.hidePopup() end)
                    end
                elseif action == "close-popup" then
                    ui.hidePopup()
                end
            end)
        end
    end
    
    -- Create webview with appropriate parameters
    local rect = hs.geometry.rect(x, y, config.POPUP_WIDTH, popupHeight)
    
    if userContentController and type(userContentController) == "userdata" then
        local success, webview = pcall(function()
            return hs.webview.new(rect, {}, userContentController)
        end)
        
        if success and webview then
            currentPopup = webview
        else
            success, webview = pcall(function()
                return hs.webview.new(rect, userContentController)
            end)
            if success and webview then
                currentPopup = webview
            else
                currentPopup = hs.webview.new(rect)
                useMessageHandlers = false
            end
        end
    else
        currentPopup = hs.webview.new(rect)
        useMessageHandlers = false
    end
    
    -- Configure webview behavior
    currentPopup:windowStyle(hs.webview.windowMasks.utility | 
                            hs.webview.windowMasks.HUD | 
                            hs.webview.windowMasks.nonactivating)
        :behavior(hs.drawing.windowBehaviors.stationary | 
                 hs.drawing.windowBehaviors.transient |
                 hs.drawing.windowBehaviors.canJoinAllSpaces)
        :allowTextEntry(true):allowGestures(true)
        :allowMagnificationGestures(false):allowNavigationGestures(false)
        :allowNewWindows(false):shadow(true):closeOnEscape(true)
        :deleteOnClose(true):level(hs.drawing.windowLevels.floating + 1)
    
    -- Fallback to JavaScript polling if messageHandlers unavailable
    if not useMessageHandlers then
        config.log("Using JavaScript polling fallback")
        buttonChecker = hs.timer.new(0.3, function()
            if not currentPopup then return end
            
            currentPopup:evaluateJavaScript("window.closeClicked", function(closeResult)
                if closeResult == true then
                    if buttonChecker then buttonChecker:stop() end
                    ui.hidePopup()
                    return
                end
                
                currentPopup:evaluateJavaScript("window.copyClicked", function(copyResult)
                    if copyResult == true and currentTranslatedText then
                        currentPopup:evaluateJavaScript("window.copyClicked = false", function() end)
                        safeSetClipboard(currentTranslatedText)
                        hs.timer.doAfter(0.5, function() ui.hidePopup() end)
                    end
                end)
            end)
        end)
        buttonChecker:start()
    end
    
    -- Load HTML and show
    currentPopup:html(ui.createPopupHTML(translatedText, sourceLang, targetLang)):show()
    
    -- Auto-hide timer
    hideTimer = hs.timer.doAfter(config.POPUP_AUTO_HIDE_DELAY, function() ui.hidePopup() end)
    
    -- Event watchers for dismissing popup
    popupEventWatchers.click = hs.eventtap.new({
        hs.eventtap.event.types.leftMouseDown,
        hs.eventtap.event.types.rightMouseDown
    }, function(event)
        if not currentPopup then return false end
        
        local mousePos = hs.mouse.absolutePosition()
        local popupFrame = currentPopup:frame()
        
        if popupFrame then
            local isOutside = mousePos.x < popupFrame.x or mousePos.x > popupFrame.x + popupFrame.w or
                             mousePos.y < popupFrame.y or mousePos.y > popupFrame.y + popupFrame.h
            if isOutside then ui.hidePopup() end
        end
        return false
    end)
    
    popupEventWatchers.keyboard = hs.eventtap.new({hs.eventtap.event.types.keyDown}, function(event)
        if not currentPopup then return false end
        if event:getKeyCode() == 53 then ui.hidePopup() end -- ESC
        return false
    end)
    
    if hs.application and hs.application.watcher then
        popupEventWatchers.appWatcher = hs.application.watcher.new(function(appName, eventType, appObject)
            if eventType == hs.application.watcher.activated and currentPopup then
                if appName ~= "Hammerspoon" then ui.hidePopup() end
            end
        end)
    end
    
    -- Start all watchers
    for key, watcher in pairs(popupEventWatchers) do
        if watcher and watcher.start then watcher:start() end
    end
end

-- Hide translation popup and cleanup
function ui.hidePopup()
    config.log("hidePopup called")
    
    if buttonChecker then buttonChecker:stop(); buttonChecker = nil end
    
    for key, watcher in pairs(popupEventWatchers) do
        if watcher and type(watcher.stop) == "function" then watcher:stop() end
    end
    popupEventWatchers = {}
    
    if hideTimer then hideTimer:stop(); hideTimer = nil end
    if currentUserContent then currentUserContent = nil end
    if currentPopup then currentPopup:delete(); currentPopup = nil; currentTranslatedText = nil end
end

-- Show context menu with translate button
function ui.showContextMenu(text, translateCallback)
    config.log("Showing context menu")
    if contextMenu then return end
    
    ui.hideContextMenu()
    if currentPopup then ui.hidePopup() end
    
    local mousePos = hs.mouse.absolutePosition()
    
    local html = [[
<!DOCTYPE html>
<html>
<head>
    <style>
        body { margin: 0; padding: 8px; font-family: -apple-system, BlinkMacSystemFont, 'SF Pro Text', sans-serif;
               background: white; border-radius: 6px; box-shadow: 0 2px 10px rgba(0,0,0,0.2); }
        .translate-btn { display: flex; align-items: center; padding: 6px 12px; background: #1a73e8;
                        color: white; border: none; border-radius: 4px; font-size: 14px; cursor: pointer;
                        transition: background 0.2s; white-space: nowrap; }
        .translate-btn:hover { background: #1557b0; }
        .translate-icon { width: 16px; height: 16px; margin-right: 6px; }
    </style>
</head>
<body>
    <button class="translate-btn" id="translateBtn">
        <svg class="translate-icon" viewBox="0 0 24 24" fill="white">
            <path d="M12.65 15.67c.14-.36.05-.77-.23-1.05l-2.09-2.06.03-.03A17.52 17.52 0 0 0 14.07 6h1.94c.54 0 .99-.45.99-.99v-.02c0-.54-.45-.99-.99-.99H10V3c0-.55-.45-1-1-1s-1 .45-1 1v1H1.99C1.45 4 1 4.45 1 4.99s.45.99.99.99h10.18A15.66 15.66 0 0 1 9 11.35c-.81-.89-1.49-1.86-2.06-2.88A.885.885 0 0 0 6.16 8c-.69 0-1.13.75-.79 1.35.63 1.13 1.4 2.21 2.3 3.21L3.3 16.87a.99.99 0 0 0 0 1.42c.39.39 1.02.39 1.42 0L9 14l2.02 2.02c.27.27.65.42 1.02.42.77 0 1.32-.77 1.08-1.53l-.01-.02z"/>
        </svg>
        Translate to English
    </button>
    <script>
        window.translateClicked = false;
        document.getElementById('translateBtn').onclick = function(e) {
            e.preventDefault(); window.translateClicked = true;
        };
    </script>
</body>
</html>]]
    
    -- Position context menu
    local screen = hs.screen.mainScreen():frame()
    local x = mousePos.x + 10
    local y = mousePos.y - config.CONTEXT_MENU_HEIGHT / 2
    
    if x + config.CONTEXT_MENU_WIDTH > screen.x + screen.w - 10 then
        x = mousePos.x - config.CONTEXT_MENU_WIDTH - 10
    end
    if y < screen.y + 10 then y = screen.y + 10
    elseif y + config.CONTEXT_MENU_HEIGHT > screen.y + screen.h - 10 then
        y = screen.y + screen.h - config.CONTEXT_MENU_HEIGHT - 10
    end
    
    -- Create context menu webview
    local rect = hs.geometry.rect(x, y, config.CONTEXT_MENU_WIDTH, config.CONTEXT_MENU_HEIGHT)
    contextMenu = hs.webview.new(rect)
        :windowStyle(hs.webview.windowMasks.utility | hs.webview.windowMasks.nonactivating | hs.webview.windowMasks.borderless)
        :behavior(hs.drawing.windowBehaviors.stationary | hs.drawing.windowBehaviors.transient | hs.drawing.windowBehaviors.canJoinAllSpaces)
        :allowTextEntry(false):allowGestures(false):allowNavigationGestures(false):allowNewWindows(false)
        :shadow(true):closeOnEscape(true):deleteOnClose(true):html(html)
        :level(hs.drawing.windowLevels.floating + 1):show()
    
    -- Poll for button click
    contextMenuClickChecker = hs.timer.new(0.1, function()
        if contextMenu then
            local success, error = pcall(function()
                contextMenu:evaluateJavaScript("window.translateClicked || false", function(result)
                    if result == true then
                        if contextMenuClickChecker then contextMenuClickChecker:stop(); contextMenuClickChecker = nil end
                        ui.hideContextMenu()
                        if translateCallback then translateCallback() end
                    end
                end)
            end)
            if not success then
                if contextMenuClickChecker then contextMenuClickChecker:stop(); contextMenuClickChecker = nil end
            end
        end
    end)
    
    if contextMenuClickChecker then contextMenuClickChecker:start() end
    
    -- Auto-hide timer
    contextMenuTimer = hs.timer.doAfter(5, function() ui.hideContextMenu() end)
    
    -- Event watchers for context menu
    contextMenuEventWatchers.click = hs.eventtap.new({
        hs.eventtap.event.types.leftMouseDown,
        hs.eventtap.event.types.rightMouseDown,
        hs.eventtap.event.types.leftMouseDragged
    }, function(event)
        if event:getType() == hs.eventtap.event.types.leftMouseDragged then
            ui.hideContextMenu(); return false
        end
        
        local clickPos = hs.mouse.absolutePosition()
        local menuFrame = contextMenu and contextMenu:frame()
        
        if menuFrame then
            if clickPos.x < menuFrame.x or clickPos.x > menuFrame.x + menuFrame.w or
               clickPos.y < menuFrame.y or clickPos.y > menuFrame.y + menuFrame.h then
                ui.hideContextMenu()
            end
        end
        return false
    end)
    
    contextMenuEventWatchers.keyboard = hs.eventtap.new({hs.eventtap.event.types.keyDown}, function(event)
        if event:getKeyCode() ~= 53 then ui.hideContextMenu() end
        return false
    end)
    
    contextMenuEventWatchers.scroll = hs.eventtap.new({hs.eventtap.event.types.scrollWheel}, function(event)
        ui.hideContextMenu(); return false
    end)
    
    for _, watcher in pairs(contextMenuEventWatchers) do watcher:start() end
end

-- Hide context menu and cleanup
function ui.hideContextMenu()
    for _, watcher in pairs(contextMenuEventWatchers) do
        if watcher then watcher:stop() end
    end
    contextMenuEventWatchers = {}
    
    if contextMenuClickChecker then contextMenuClickChecker:stop(); contextMenuClickChecker = nil end
    if contextMenuTimer then contextMenuTimer:stop(); contextMenuTimer = nil end
    if contextMenu then contextMenu:delete(); contextMenu = nil end
end

-- Show error message
function ui.showError(message)
    hs.alert.show("Translation failed: " .. message, 2)
end

return ui