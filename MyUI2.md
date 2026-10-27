# MyUI 2: Peek layout

A second, independent library in this repo with a different look: a blue header band with tabs, pill filters, three columns of cards, a light and a dark theme, and a peeking chibi mascot who blushes and talks when you click her.

Like MyUI, everything (icons, the mascot, the color wheel) is drawn from plain GuiObjects, so it needs **no uploaded images**.

```lua
local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/dreams7906/MyUI/claude/cool-hawking-qhmbhp/MyUI2.lua"))()
```

See [`Example2.lua`](Example2.lua) for a script that recreates the reference layout (Farm tab with Ba'al / Level / Fishing / Kraken / Halloween pills) and uses every element.

MyUI and MyUI 2 replace each other when you run them, so use one per game.

## The look

- **Header band:** the big title (your game name), a "by NAME · DEV v2.4" line, and tabs with a sliding "folder tab" highlight that merges into the body.
- **Header buttons:** a moon/sun button that switches dark and light, a key pill showing the menu key (click it to rebind), and a close button.
- **Pill row:** sub-tabs as pills with a green active state. Pills that don't fit collapse into a **+N** pill that opens a menu.
- **Search and stats:** a search button that expands into a box, and live monospace stats: `Server 1/20   Session 00:01:22   Char Ready`.
- **Cards:** three columns in one scrolling page. Each card has a colored icon tile, a title, a toggle count (blue while one is on) and a collapse chevron.
- **Rows:** labels on the left with switches, inputs and dropdowns on the right. Status lines appear as monospace "• Level Farm: Disabled" rows.
- **Window:** resizable from the bottom-right grip (double-click the grip to reset the size), draggable by the header, and it remembers its position, size and last tab.
- **Loading screen:** a loading card with the mascot peeking over its top edge.

## The mascot

An original chibi girl (dark hair, teal eyes, pink ribbon) peeks over the edge of the header, gripping it with both hands. She:

- **blinks** and breathes, and her **eyes follow your cursor**;
- **blushes** (or smiles) and says a line in the speech bubble when you **click** her. The bubble types the line out letter by letter;
- gets **patted** if you **hold** the mouse on her;
- gets flustered, then **ducks behind the panel** for a few seconds, if you poke her too many times;
- **greets** you when the menu opens, says an idle line now and then, and sometimes **reacts** when you switch a toggle on.

Everything is adjustable in **Settings → Interface → Mascot**: show/hide her, speech bubbles, follow cursor, and reactions.

```lua
Window:Say("H-hi!", 3, "Blush")      -- text, seconds to hold (optional), mood (optional)
Window.Mascot:SetMood("Happy")       -- Idle, Happy, Blush, Flustered, Surprised
Window.Mascot:Hide()                 -- duck behind the panel
Window.Mascot:Peek()                 -- come back up
Window:SetMascotVisible(false)
```

### Your own lines or artwork

```lua
Library:CreateWindow({
	Mascot = {
		Lines = {
			Greeting = { "Welcome back, captain!" },
			Click = { "Hey!", "That tickles!" },
			Pat = { "...fine, you can stay." },
			Idle = { "Still grinding?" },
			-- also: Spam, Hide, Return, React (React uses %s for the toggle name)
		},
		-- Optional: use uploaded artwork instead of the drawn character.
		-- Images = { Idle = "rbxassetid://...", Blush = "rbxassetid://...", Happy = "rbxassetid://..." },
	},
})
```

Pass `Mascot = false` to turn her off completely.

## Window

```lua
local Window = Library:CreateWindow({
	Title = "Grand Piece Online",  -- big title; leave it out to show the game's real name
	Author = "XX",                 -- shown as "by XX"
	Badge = "DEV",                 -- the little tag (false hides it)
	Version = "v2.4",
	Icon = "sparkle",              -- icon before "by XX"
	Theme = "Dark",                -- "Dark" or "Light" (saved choice wins)
	ToggleKey = Enum.KeyCode.RightShift,
	ConfigFolder = "XX/GPO",
	Columns = 3,                   -- cards per row (1-4)
	Size = UDim2.fromOffset(900, 560),
	MinSize = Vector2.new(760, 460),
	LoadingScreen = true,
	LoadingTime = 3.5,
	AutoSave = false,
	AutoLoad = true,
	SettingsTab = true,
	Mascot = { ... },              -- see above, or false
})

Window:SetTitle("Blox Fruits")
Window:SetAuthor("XX")
Window:SetVersion("v3.0")
Window:SetBadge("BETA")
Window:Toggle()
Library:ToggleTheme()               -- or Library:SetTheme("Light")
```

## Tabs, pills and cards

```lua
local Farm = Window:AddTab({ Title = "Farm", Icon = "bike" })
local Fishing = Farm:AddSubTab("Fishing")            -- a pill

local Card = Fishing:AddSection({
	Title = "Fishing",
	Icon = "fish",
	Color = Color3.fromRGB(38, 172, 196),            -- icon tile color (default: accent)
	Side = 2,                                        -- column 1-3, or "Left" / "Middle" / "Right"
})
```

- A card created from a pill shows under that pill and under **All**. A card created straight from the tab shows under every pill.
- Pass `ShowAll = false` to `AddTab` to drop the **All** pill.
- Leaving `Side` out puts the card in the shortest column.

**Icons:** everything from MyUI plus `star`, `sun`, `moon`, `fish`, `heart`, `flag`, `pumpkin`, `kraken`, `bike`.

## Elements, configs and keybinds

The element API is the same as MyUI's, so the [README](README.md#elements) applies:

- **Same elements:** `AddToggle` (with `:AddKeybind` / `:AddColorPicker`), `AddButton`, `AddSlider`, `AddInput`, `AddDropdown`, `AddColorPicker`, `AddKeybind`, `AddLabel`, `AddParagraph` and `AddDivider`.
- **Same helpers:** right-click reset, `Library.Options` / `Library.Flags`, and the whole config system (save, load, overwrite, delete, auto save, auto load, import/export).

Differences:

- `AddLabel(text)` draws a monospace status row with a bullet. Pass `{ Style = "Plain" }` for normal text.
- Inputs and dropdowns sit on one line, with the label left and the box right.
- A multi-select dropdown shows "3 selected" once more than two items are picked.
- Only two themes: `Library:SetTheme("Dark" | "Light")`. Switching cross-fades every color.
