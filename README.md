# BetterPopupTranslateSelection.spoon

A Hammerspoon Spoon for Chrome-style popup translation with context menu on text selection.

## Features
- Context menu on text selection
- Chrome-style minimalistic popup
- API-keyless translation (Google Translate, LibreTranslate)
- Multiple app targeting
- Configurable via JSON or Lua

## Installation

1. Clone into your Spoons directory:
```bash
git clone https://github.com/rshlin/BetterPopupTranslateSelection.spoon.git ~/.hammerspoon/Spoons/BetterPopupTranslateSelection.spoon
```

2. Remove git tracking (optional, for local customization):
```bash
rm -rf ~/.hammerspoon/Spoons/BetterPopupTranslateSelection.spoon/.git
```

3. Configure and load in `~/.hammerspoon/init.lua`:
```lua
local translator = hs.loadSpoon("BetterPopupTranslateSelection")
translator:init():start()
```

## Configuration

### Method 1: JSON Configuration
Create `~/.config/hammerspoon-bpts/config.json`:
```json
{
  "APP_NAMES": ["Safari", "Chrome"],
  "DEBUG": false,
  "SHOW_CONTEXT_ON_SELECTION": true,
  "DEFAULT_TARGET_LANG": "en"
}
```

### Method 2: Lua Configuration
```lua
translator:configure({
    APP_NAMES = {"Safari"},
    DEBUG = true
}):init():start()
```

### Method 3: Mixed (JSON + Lua overrides)
```lua
-- JSON provides base config, Lua overrides specific values
translator:configure({
    DEBUG = true  -- Override JSON's DEBUG setting
}):init():start()
```

## Configuration Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `APP_NAMES` | Array | `[]` | Apps to monitor (empty = inactive) |
| `DEBUG` | Boolean | `false` | Enable debug logging |
| `SHOW_CONTEXT_ON_SELECTION` | Boolean | `true` | Show context menu vs auto-translate |
| `DEFAULT_TARGET_LANG` | String | `"en"` | Target language code |
| `DEFAULT_SOURCE_LANG` | String | `"auto"` | Source language (auto-detect) |
| `HOTKEY_TRANSLATE` | Array | `[["cmd","shift"], "t"]` | Translation hotkey |
| `HOTKEY_GLOBAL` | Array | `[["cmd","shift"], "g"]` | Global translation hotkey |
| `POPUP_WIDTH` | Number | `500` | Popup width in pixels |
| `POPUP_AUTO_HIDE_DELAY` | Number | `15` | Auto-hide delay in seconds |

## Usage

1. Select text in configured app
2. Context menu appears with "Translate to English" button
3. Click button to see translation in Chrome-style popup
4. Click "Copy translation" to copy to clipboard

## Example Configuration

See `config.example.json` for Safari configuration example.

## Uninstall

1. Remove the spoon directory:
```bash
rm -rf ~/.hammerspoon/Spoons/BetterPopupTranslateSelection.spoon
```

2. Remove JSON config (if created):
```bash
rm -rf ~/.config/hammerspoon-bpts
```

3. Remove or comment out the spoon configuration from `~/.hammerspoon/init.lua`

4. Reload Hammerspoon (Cmd+Ctrl+R)

## License

MIT