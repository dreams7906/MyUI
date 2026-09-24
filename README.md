# MyUI

A single-file Luau interface library for Roblox, styled after the "NERV / DEV" layout: header cards (brand, profile, clock, FPS/ping), a sidebar with icons, sub-tabs, two-column gradient-headed sections, and a rainbow footer tag.

Every icon, the HSV color wheel and the window shadow are drawn from plain GuiObjects. The library needs **no uploaded image assets**, so nothing can fail to load.

```lua
local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/dreams7906/MyUI/main/MyUI.lua"))()
```

See [`Example.lua`](Example.lua) for a script that recreates the reference layout and uses every element.

## Features

- **Tabs → sub-tabs → sections.** Sub-tabs filter sections, and an automatic **All** sub-tab shows everything. Sections sit in two independently scrolling columns and collapse when you click their header.
- **Global search.** A search box filters the current tab by section and element titles.
- **Elements:** toggle, button (including side-by-side and confirm-to-click buttons), slider, text/number input, dropdown, color picker, keybind, label, paragraph and divider.
- **Dropdowns** include built-in search, multi-select with checkboxes, and a live player list.
- **Color picker** with a hue/saturation **wheel**, value and alpha bars, hex and RGB input, rainbow mode, and copy/paste.
- **Keybinds** support Toggle, Hold and Always modes (right-click to switch). They can attach to a toggle and show in an optional keybind list overlay.
- **Config system:** create, load, **overwrite** (with confirmation) and delete configs, plus **auto save**, **auto load**, and clipboard import/export.
- **UI customization:** 10 theme presets, per-color editing, saved custom themes, 13 fonts, window transparency, interface scale and an animations switch. These settings persist across sessions.
- **Extras:** notifications, tooltips, a menu toggle key, a resizable and draggable window, a mobile toggle button, streamer mode ("Hide Identity"), and clean unloading.

## Window

```lua
local Window = Library:CreateWindow({
	Title = "NERV / DEV",               -- brand card title
	SubTitle = "Grand Piece Online",    -- brand card subtitle
	Icon = "sparkle",                   -- built-in icon name, asset id, or a text glyph
	Footer = "Developer Mode",          -- bottom-right tag
	FooterRainbow = true,               -- rainbow gradient on the tag (default true)
	ConfigFolder = "NERV/GPO",          -- where configs/themes/settings are stored
	ToggleKey = Enum.KeyCode.RightShift,
	Size = UDim2.fromOffset(880, 500),  -- also accepts Vector2
	MinSize = Vector2.new(680, 430),    -- resize limit
	Theme = "Nerv",                     -- default preset (saved settings take priority)
	Font = "Gotham",
	AutoSave = false,                   -- default for the Auto Save toggle
	AutoLoad = true,                    -- load the autoload config after your script runs
	SettingsTab = true,                 -- add the built-in Settings tab
	MobileButton = nil,                 -- nil = only on touch devices, true/false to force
	Scale = nil,                        -- nil = fit to the screen
})

Window:SelectTab("Farm")         -- by title, index or tab object
Window:Toggle()                  -- show/hide (also: Library:Toggle())
Window:SetScale(0.9)
Window:SetTitle("New title")
Window:SetSubTitle("New subtitle")
Window:SetFooter("Beta")
```

## Tabs, sub-tabs and sections

```lua
local Farm = Window:AddTab({ Title = "Farm", Icon = "sprout" })
local Progression = Farm:AddSubTab("Progression")
local Fishing = Farm:AddSubTab("Fishing")

local LevelFarm = Progression:AddSection({ Title = "Level Farm", Side = "Left" })
local Shared = Farm:AddSection({ Title = "Always Visible", Side = "Right" })
```

- A section created from a sub-tab shows under that sub-tab and under **All**.
- A section created straight from the tab shows under every sub-tab.
- Pass `ShowAll = false` to `AddTab` to drop the **All** sub-tab.
- `Side` accepts `"Left"`, `"Right"`, `1` or `2`. If you leave it out, the section goes to the shorter column.
- Sections accept `Collapsed = true` (start collapsed) and `Collapsible = false`.
- Section methods: `:SetCollapsed(bool)`, `:SetVisible(bool)` and `:SetTitle(text)`.
- The **⋮** button on a sidebar tab opens a quick menu of its sub-tabs.

**Built-in icons:** `grid`, `sprout`, `scan`, `compass`, `sliders`, `clock`, `info`, `alert`, `check`, `x`, `search`, `user`, `home`, `sword`, `eye`, `gear`, `folder`, `list`, `palette`, `keyboard`, `globe`, `target`, `crosshair`, `zap`, `code`, `save`, `plus`, `minus`, `sparkle`. You can also pass `"rbxassetid://123"`, a number, or a short text glyph.

## Elements

Every element takes either `(flag, options)` or `(options)` with `options.Flag`. If you leave the flag out, one is generated from the tab, section and title, so the element is still saved in configs. Pass `Save = false` to keep an element out of configs.

### Toggle

```lua
local Toggle = Section:AddToggle("AutoFarm", {
	Title = "Auto Farm",
	Default = false,
	Description = "Optional grey text under the title",
	Tooltip = "Shown on hover",
	Callback = function(value) end,
})
Toggle:AddKeybind("AutoFarmKey", { Default = Enum.KeyCode.F, Mode = "Toggle" })  -- presses flip the toggle
Toggle:AddColorPicker("AutoFarmColor", { Default = Color3.new(1, 0, 0) })
```

Enabled toggles switch their title to bold white, matching the reference.

### Button

```lua
Section:AddButton({ Title = "Teleport", Callback = function() end })
	:AddButton({ Title = "Reset", Confirm = true, Callback = function() end }) -- same row
```

`Confirm = true`, or a string, requires a second click within 2.5 s.

### Slider

```lua
Section:AddSlider("Speed", {
	Title = "Walk Speed", Min = 16, Max = 200, Default = 16,
	Increment = 1,            -- or Rounding = 2 (decimal places)
	Suffix = " studs",
	CallbackOnRelease = false, -- true = fire only when the drag ends
	Callback = function(value) end,
})
```

Click the value to type an exact number.

### Input

```lua
Section:AddInput("Limit", {
	Title = "Strength Max", Default = 800, Placeholder = "0-5000",
	Numeric = true, Min = 0, Max = 5000,  -- Value is a number when Numeric
	Finished = true,                      -- fire on focus lost instead of every keystroke
	MaxLength = 10, ClearTextOnFocus = false,
	Callback = function(value) end,
})
```

### Dropdown

```lua
local Style = Section:AddDropdown("FightingStyle", {
	Title = "Fighting Style",
	Values = { "Auto", "Combat", "Sword" },
	Default = "Auto",           -- or an index (1)
	Multi = false,              -- true = checkbox multi-select
	Searchable = true,          -- search box inside the list
	AllowNull = false,          -- let clicking the selected value clear it
	Placeholder = "None",
	Callback = function(value) end,
})
Section:AddDropdown("Target", { Title = "Player", SpecialType = "Player", ExcludeLocal = true })

Style:SetValues({ "A", "B" })   -- alias :Refresh()
Style:AddValue("C")
Style:RemoveValue("A")
Style:GetSelected()             -- array, in list order
```

For multi-select dropdowns, `Value` is a set such as `{ Sandora = true, Roca = true }`. `SetValue` accepts either a set or an array. When the search box has focus, Enter picks the first match.

### Color picker

```lua
local Picker = Section:AddColorPicker("ESPColor", {
	Title = "ESP Color",
	Default = Color3.fromRGB(61, 124, 222),
	Transparency = 0,          -- include this to show the alpha bar
	Callback = function(color, transparency) end,
})
Picker:SetValue(Color3.new(1, 0, 0), 0.5)
Picker:SetRainbow(true)
```

### Keybind

```lua
local Dash = Section:AddKeybind("Dash", {
	Title = "Dash",
	Default = Enum.KeyCode.Q,  -- or "Q", "MouseButton2", "None"
	Mode = "Toggle",           -- "Toggle" | "Hold" | "Always"
	Callback = function(state) end,       -- state changes
	ChangedCallback = function(key) end,  -- key changes
})
Dash:OnClick(function() end)  -- every press, any mode
Dash:GetState()
Dash:SetValue("E", "Hold")
```

To rebind, click the key chip and press a key: Backspace clears it and Esc cancels. Right-click the chip to change the mode. Keybinds ignore presses while a text box has focus.

### Label, paragraph, divider

```lua
local Status = Section:AddLabel("Level Farm: Disabled")  -- RichText supported
Status:SetText("Level Farm: <b>Enabled</b>")
local Tips = Section:AddParagraph({ Title = "Tips", Content = "..." })
Tips:SetContent("...")
Section:AddDivider("optional label")
```

### Shared element API

| Member | Description |
| --- | --- |
| `.Value` | Current value |
| `:SetValue(value)` | Sets the value and fires callbacks when it changes |
| `:OnChanged(fn)` | Extra change listener (chainable) |
| `:SetVisible(bool)` | Shows or hides the element |
| `:SetTitle(text)` | Renames the element (search follows the new title) |
| `:SetTooltip(text)` | Sets the hover tooltip |
| `:Destroy()` | Removes the element and its flag |

`Library.Flags[flag]` holds each flag's plain value, and `Library.Options[flag]` holds the element object.

## Config system

Files live in your executor's workspace:

```
<ConfigFolder>/
  configs/<name>.json   saved configs
  themes/<name>.json    custom themes
  autoload.txt          config loaded on startup
  settings.json         theme, font, scale, menu key, auto save, ...
```

The **Settings → Configs** page covers all of this. The same actions are available from code:

```lua
Library:SaveConfig("main")          -- fails if it exists...
Library:SaveConfig("main", true)    -- ...unless you overwrite
Library:LoadConfig("main")
Library:DeleteConfig("main")
Library:GetConfigs()                -- { "main", ... }
Library:SetAutoload("main")         -- nil clears it
Library:GetAutoload()
Library:LoadAutoloadConfig()        -- runs automatically unless AutoLoad = false
Library:SetAutoSave(true)
Library:ExportConfig()              -- JSON string
Library:ImportConfig(json)
```

- **Auto save** writes to the active config, which is the last one you saved or loaded. If there is none, it writes to `autosave`. It waits for one quiet second after the last change, so dragging a slider writes once.
- **Auto load** runs right after your script finishes. If a loaded config holds flags for elements you create later, those elements receive their values when they are created.
- Unloading flushes any pending autosave.
- Without executor file functions (for example in Studio), configs are kept in memory for the session.

## Customization

```lua
Library:SetTheme("Midnight")                        -- presets: Nerv, Crimson, Emerald, Amethyst,
                                                    -- Amber, Sakura, Glacier, Midnight, Mono, Daylight
Library:SetThemeColor("Accent", Color3.fromRGB(255, 80, 120))
Library:SaveTheme("Mine")                           -- saved under themes/, listed with presets
Library:SetTheme("Mine")
Library:SetFont("Builder Sans")                     -- Gotham, Builder Sans, Roboto, Ubuntu, Nunito,
                                                    -- Source Sans, Arimo, Josefin Sans, Titillium Web,
                                                    -- Jura, Michroma, Oswald, Roboto Mono
Library.Animations = false                          -- instant state changes, lowest overhead
Library:SetKeybindListVisible(true)
Library:Notify({ Title = "Hi", Content = "Rich <b>text</b>", Type = "Success", Duration = 4 })
-- Type: "Info" | "Success" | "Warning" | "Error"; also Library:Notify("text", seconds)
```

**Theme keys:** `Accent`, `AccentGlow`, `AccentDark`, `Background`, `Panel`, `Element`, `Hover`, `Border`, `Text`, `SubText`, `DimText`, `OnAccent`, plus the numeric `Transparency`.

## Performance

- **Shared input handling.** One `InputBegan`, `InputChanged` and `InputEnded` connection drives every drag, keybind and popup. Keybinds are found through a key → keybind map, not by looping over all of them.
- **Reused popups.** Dropdown lists, the color picker and context menus are built once per window and reused. Dropdown rows are pooled, and the color wheel is built the first time it opens.
- **Cheap theme switching.** A theme change repaints only the instances registered for theme colors. Bursts of edits, such as dragging a color, are merged into one repaint.
- **Idle rainbow costs nothing.** Rainbow mode uses one throttled Heartbeat connection that exists only while a picker is in rainbow mode.
- **Low per-frame work.** The header stats update once per second, and the only per-frame work is an integer frame counter.
- **Error isolation.** Callbacks run in their own thread with error reporting, so a broken callback can't stall the UI.

## Lifetime

```lua
Library:OnUnload(function() end)
Library:Unload()  -- disconnects everything and destroys the GUI
```

Running the script again automatically unloads the previous copy with the same title, so interfaces don't stack.
