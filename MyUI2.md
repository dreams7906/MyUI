# MyUI 2: Peek layout

A second, independent library in this repo with a different look:

- a blue header band with tabs;
- pill filters and three columns of cards;
- a light and a dark theme;
- **Hiyori**, an anime girl who peeks over the panel. She blinks and follows your cursor, and when you click her she blushes and talks.

```lua
local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/dreams7906/MyUI/claude/cool-hawking-qhmbhp/MyUI2.lua"))()
```

See [`Example2.lua`](Example2.lua) for a short tour that uses every element: a **Main** tab with Basics / Inputs / Pickers pills and a **Mascot** tab to play with her moods and emotes.

MyUI and MyUI 2 replace each other when you run them, so use one per game.

## The look

- **Header band:** the big title, a "by NAME · DEV v1.0" line, and tabs with a sliding "folder tab" highlight that merges into the body.
- **Header buttons:** a moon/sun button that switches dark and light, a key pill showing the menu key (click it to rebind), and a close button.
- **Pill row:** sub-tabs as pills with a green active state. Pills that don't fit collapse into a **+N** pill that opens a menu.
- **Search and stats:** a search button that expands into a box, and live monospace stats: `Server 1/20   Session 00:01:22   Char Ready`.
- **Cards:** three columns in one scrolling page. Each card has a colored icon tile, a title, a toggle count (blue while one is on) and a collapse chevron.
- **Rows:** labels on the left with switches, inputs and dropdowns on the right. Status lines appear as monospace "• Example Toggle: Off" rows.
- **Window:** resizable from the bottom-right grip (double-click the grip to reset the size), draggable by the header. It remembers its position, size and last tab.
- **Loading screen:** a loading card with Hiyori peeking over its top edge.

## The mascot: Hiyori

Hiyori Momose is the official sample character of [Live2D](https://www.live2d.com/). Her Live2D model was rendered into a sprite sheet ([`assets/hiyori.png`](assets/hiyori.png), 25 frames). The library swaps the frames and animates them with tweens.

What she does:

- **Idle:** she breathes and sways a little, blinks every few seconds, and turns her head toward your cursor (left, centre, right, or looking down).
- **Click her:** she hops, blushes or smiles, hearts float up, and she says a line in the speech bubble. Her mouth moves while the line types out.
- **Hold the mouse on her:** you pat her head. She closes her eyes happily, squishes with each pat, and more hearts float up.
- **Too many pokes:** first she gets flustered and shakes her head (with a sweat drop). After six pokes she pouts, ducks behind the panel and comes back a few seconds later.
- **Leave her alone:** after about a minute without mouse movement she gets sleepy and "zzz" floats up. Moving the mouse wakes her with a start.
- **Other moments:** she greets you with sparkles when the menu opens. Now and then she says an idle line or reacts when you switch a toggle on.

Everything is adjustable in **Settings → Interface → Mascot**: show/hide her, speech bubbles, follow cursor, and reactions.

```lua
Window:Say("Hello!", 3, "Smile")    -- text, seconds to hold (optional), mood (optional)

local Hiyori = Window.Mascot
Hiyori:SetMood("Blush")              -- Idle, Smile, Happy, Blush, Pat, Flustered, Surprised, Pout, Sleepy, Wink
Hiyori:Emote("Hearts")               -- Hearts, Sparkles, Shock, Sweat, Sleep
Hiyori:Hop()
Hiyori:Squish()
Hiyori:Shake()
Hiyori:Hide()                        -- duck behind the panel
Hiyori:Peek()                        -- come back up
Window:SetMascotVisible(false)
```

### Options

```lua
Library:CreateWindow({
	Mascot = {
		Size = 150,                  -- frame size in pixels (her head and shoulders)
		Lines = {
			Greeting = { "Welcome back, captain!" },
			Click = { "Hey!", "That tickles!" },
			Pat = { "...fine, you can stay." },
			Idle = { "Still grinding?" },
			-- also: Spam, Hide, Return, Wake, React (React uses %s for the toggle name)
		},
		-- Your own artwork instead of the sheet (one image per mood, Idle required):
		-- Images = { Idle = "rbxassetid://...", Blush = "rbxassetid://...", Happy = "rbxassetid://..." },
	},
})
```

Pass `Mascot = false` to turn her off completely.

## Icons

Icons are [Lucide](https://lucide.dev/), plus a few from [Tabler](https://tabler.io/icons), taken from [Iconify](https://icon-sets.iconify.design/). About 390 of them are packed into [`assets/icons.png`](assets/icons.png), with names in [`assets/icons.json`](assets/icons.json). Use any packed name wherever an icon is accepted:

```lua
Window:AddTab({ Title = "Combat", Icon = "swords" })
Tab:AddSection({ Title = "Fishing", Icon = "fish", Color = Color3.fromRGB(38, 172, 196) })
```

A few examples: `house`, `settings`, `user`, `users`, `swords`, `crosshair`, `target`, `eye`, `zap`, `flame`, `star`, `crown`, `gem`, `coins`, `gift`, `package`, `map`, `compass`, `rocket`, `car`, `bike`, `fish`, `ghost`, `skull`, `heart`, `bell`, `palette`, `sliders-horizontal`, `wand-sparkles`, `bot`. The full list is in `tools/icons/icons.txt`.

The old short names still work (`home`, `gear`, `grid`, `sliders`, `alert`, `chevron`...). You can also pass an asset id (`"rbxassetid://123"`) or a short text glyph.

**Adding icons.** Add Lucide names, or `set:name` from any Iconify set (for example `mdi:sword` or `game-icons:fishing-pole`), to [`tools/icons/icons.txt`](tools/icons/icons.txt). Then rebuild the sheet:

```bash
npm i playwright @iconify-json/lucide @iconify-json/tabler   # plus @iconify-json/<set> for other sets
node tools/icons/build.js
```

## How the images load

- **Download and cache:** on the first run the library downloads the icon sheet (~200 KB) and Hiyori's sheet (~370 KB) from this repo's `assets` folder into `MyUI2/assets` in your executor's workspace, then shows them with `getcustomasset`. Later runs use the cached copies, and only the small `icons.json` is checked for updates.
- **Fallback:** if your executor has no `getcustomasset` or the download fails, icons fall back to the built-in drawn set and Hiyori stays hidden. Everything else works the same.
- **Uploaded copies:** you can upload the two PNGs to Roblox yourself and point the library at them. Set this before `CreateWindow`:

```lua
Library.Assets = { Icons = "rbxassetid://...", Mascot = "rbxassetid://..." }
-- Library.Assets = false            -- never download anything
-- Library.AssetUrl = "https://raw.githubusercontent.com/<you>/<repo>/<branch>/assets/"
```

## Window

```lua
local Window = Library:CreateWindow({
	Title = "Example",             -- big title; leave it out to show the game's real name
	Author = "XX",                 -- shown as "by XX"
	Badge = "DEV",                 -- the little tag (false hides it)
	Version = "v1.0",
	Icon = "sparkles",             -- icon before "by XX"
	Theme = "Dark",                -- "Dark" or "Light" (saved choice wins)
	ToggleKey = Enum.KeyCode.RightShift,
	ConfigFolder = "XX/Example",
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

Window:SetTitle("My Hub")
Window:SetAuthor("XX")
Window:SetVersion("v2.0")
Window:SetBadge("BETA")
Window:Toggle()
Library:ToggleTheme()               -- or Library:SetTheme("Light")
```

## Tabs, pills and cards

```lua
local Main = Window:AddTab({ Title = "Main", Icon = "house" })
local Basics = Main:AddSubTab("Basics")             -- a pill

local Card = Basics:AddSection({
	Title = "Toggles",
	Icon = "toggle-right",
	Color = Color3.fromRGB(46, 196, 110),           -- icon tile color (default: accent)
	Side = 1,                                       -- column 1-3, or "Left" / "Middle" / "Right"
})
```

- A card created from a pill shows under that pill and under **All**. A card created straight from the tab shows under every pill.
- Pass `ShowAll = false` to `AddTab` to drop the **All** pill.
- Leaving `Side` out puts the card in the shortest column.

## Elements, configs and keybinds

The element API is the same as MyUI's, so the [README](README.md#elements) applies:

- **Same elements:** `AddToggle` (with `:AddKeybind` / `:AddColorPicker`), `AddButton`, `AddSlider`, `AddInput`, `AddDropdown`, `AddColorPicker`, `AddKeybind`, `AddLabel`, `AddParagraph` and `AddDivider`.
- **Same helpers:** right-click reset, `Library.Options` / `Library.Flags`, and the whole config system (save, load, overwrite, delete, auto save, auto load, import/export).

Differences:

- `AddLabel(text)` draws a monospace status row with a bullet. Pass `{ Style = "Plain" }` for normal text.
- Inputs and dropdowns sit on one line, with the label left and the box right.
- A multi-select dropdown shows "3 selected" once more than two items are picked.
- Only two themes: `Library:SetTheme("Dark" | "Light")`. Switching cross-fades every color.

## Credits

- **Hiyori Momose** © Live2D Inc. Rendered from the [Cubism sample model](https://github.com/Live2D/CubismWebSamples) and used under the [Live2D Free Material License](https://www.live2d.com/eula/live2d-free-material-license-agreement_en.html). Read its terms before using her in a commercial project.
- **Icons:** [Lucide](https://lucide.dev/) (ISC) and [Tabler Icons](https://tabler.io/icons) (MIT), via [Iconify](https://iconify.design/).
