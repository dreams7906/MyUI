--[[
	MyUI example: recreates the "NERV / DEV" reference layout and shows off
	every element. The game logic is placeholder - wire the callbacks to your own
	functions.
]]

local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/dreams7906/MyUI/main/MyUI.lua"))()
local Options = Library.Options

local Window = Library:CreateWindow({
	Title = "NERV / DEV",
	SubTitle = "Grand Piece Online",
	Icon = "sparkle",
	Footer = "Developer Mode",
	ConfigFolder = "NERV/GrandPieceOnline",
	ToggleKey = Enum.KeyCode.RightShift,
	Size = UDim2.fromOffset(880, 500),
})

--------------------------------------------------------------------------------
-- Main: a tour of every element type
--------------------------------------------------------------------------------
local Main = Window:AddTab({ Title = "Main", Icon = "grid" })

local Showcase = Main:AddSection({ Title = "Showcase", Side = "Left" })
Showcase:AddToggle("ShowcaseToggle", {
	Title = "Simple Toggle",
	Default = false,
	Tooltip = "Toggles can carry keybinds and color pickers too.",
	Callback = function(value)
		print("Simple Toggle ->", value)
	end,
})
Showcase:AddSlider("WalkSpeed", {
	Title = "Walk Speed",
	Min = 16,
	Max = 200,
	Default = 16,
	Increment = 1,
	Callback = function(value)
		local character = game:GetService("Players").LocalPlayer.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.WalkSpeed = value
		end
	end,
})
Showcase:AddSlider("FieldOfView", { Title = "Field Of View", Min = 50, Max = 120, Default = 70, Suffix = "°" })
Showcase:AddInput("Nickname", { Title = "Nickname", Placeholder = "Type anything...", Finished = true })
Showcase:AddButton({
	Title = "Notify",
	Callback = function()
		Library:Notify({ Title = "Hello", Content = "This is a notification.", Duration = 4 })
	end,
}):AddButton({
	Title = "Danger",
	Confirm = true,
	Callback = function()
		Library:Notify({ Title = "Confirmed", Content = "You clicked twice.", Type = "Warning" })
	end,
})

local Pickers = Main:AddSection({ Title = "Pickers", Side = "Right" })
Pickers:AddDropdown("Weapon", {
	Title = "Weapon",
	Values = { "Katana", "Flintlock", "Cannon", "Bisento", "Pipe", "Dual Daggers" },
	Default = "Katana",
})
Pickers:AddDropdown("Islands", {
	Title = "Islands (multi-select)",
	Values = {
		"Sandora", "Roca", "Orange Town", "Shells Town", "Baratie", "Fishman Island",
		"Marineford", "Kori Island", "Arlong Park", "Loguetown", "Reverse Mountain",
	},
	Multi = true,
	Default = { "Sandora", "Roca" },
})
Pickers:AddDropdown("Target", { Title = "Target Player", SpecialType = "Player", ExcludeLocal = true })
Pickers:AddColorPicker("AccentColor", { Title = "Highlight Color", Default = Color3.fromRGB(61, 124, 222) })
Pickers:AddColorPicker("GlowColor", { Title = "Glow (with alpha)", Default = Color3.fromRGB(255, 92, 205), Transparency = 0.25 })
Pickers:AddKeybind("Dash", {
	Title = "Dash",
	Default = Enum.KeyCode.Q,
	Mode = "Toggle",
	Callback = function(state)
		print("Dash keybind state:", state)
	end,
})

local Info = Main:AddSection({ Title = "Info", Side = "Right" })
Info:AddParagraph({
	Title = "Tips",
	Content = "Right-click a keybind to change its mode. Use the search box to filter any tab. "
		.. "Configs, themes and fonts live in the Settings tab.",
})
Info:AddDivider("status")
local Clock = Info:AddLabel("Session: 0s")
task.spawn(function()
	local started = os.clock()
	while not Library.Unloaded do
		Clock:SetText(string.format("Session: %ds", os.clock() - started))
		task.wait(1)
	end
end)

--------------------------------------------------------------------------------
-- Farm: mirrors the reference screenshot (All / Progression / Fishing / Kraken)
--------------------------------------------------------------------------------
local Farm = Window:AddTab({ Title = "Farm", Icon = "sprout" })
local Progression = Farm:AddSubTab("Progression")
local Fishing = Farm:AddSubTab("Fishing")
local Kraken = Farm:AddSubTab("Kraken")

local LevelFarm = Progression:AddSection({ Title = "Level Farm", Side = "Left" })
local LevelStatus
local LevelToggle = LevelFarm:AddToggle("LevelFarm", {
	Title = "Level Farm",
	Callback = function(value)
		LevelStatus:SetText("Level Farm: " .. (value and "Enabled" or "Disabled"))
	end,
})
LevelToggle:AddKeybind("LevelFarmKey", { Default = Enum.KeyCode.F })
LevelFarm:AddToggle("BuyGeppo", { Title = "Buy Geppo", Default = true })
LevelFarm:AddToggle("GetHakiV1", { Title = "Get Haki V1", Default = true })
LevelStatus = LevelFarm:AddLabel("Level Farm: Disabled")

local Combat = Progression:AddSection({ Title = "Combat", Side = "Right" })
Combat:AddDropdown("FightingStyle", {
	Title = "Fighting Style",
	Values = { "Auto", "Combat", "Black Leg", "Sword", "Gun", "Devil Fruit" },
	Default = "Auto",
})

local AutoStats = Progression:AddSection({ Title = "Auto Stats", Side = "Left" })
for _, stat in { "Strength", "Stamina", "Defense", "Gun Mastery", "Sword Mastery", "Devil Fruit" } do
	AutoStats:AddToggle("AutoStat_" .. stat, { Title = stat })
end

local Limits = Progression:AddSection({ Title = "Point limits", Side = "Right" })
for _, stat in { "Strength", "Stamina", "Defense" } do
	Limits:AddInput(stat .. "Max", { Title = stat .. " Max", Default = 800, Numeric = true, Min = 0, Max = 5000 })
end

local AutoFish = Fishing:AddSection({ Title = "Auto Fish", Side = "Left" })
AutoFish:AddToggle("AutoFish", { Title = "Auto Fish" })
AutoFish:AddToggle("AutoSell", { Title = "Auto Sell Fish" })
AutoFish:AddSlider("CastDelay", { Title = "Cast Delay", Min = 0, Max = 5, Default = 0.5, Increment = 0.1, Suffix = "s" })
local Bait = Fishing:AddSection({ Title = "Bait", Side = "Right" })
Bait:AddDropdown("BaitTypes", { Title = "Use Baits", Values = { "Worm", "Squid", "Shrimp", "Golden" }, Multi = true })

local KrakenSection = Kraken:AddSection({ Title = "Kraken", Side = "Left" })
KrakenSection:AddToggle("AutoKraken", { Title = "Auto Kraken" })
KrakenSection:AddSlider("KrakenDistance", { Title = "Attack Distance", Min = 5, Max = 60, Default = 25, Suffix = " studs" })

--------------------------------------------------------------------------------
-- ESP: toggles with inline color pickers
--------------------------------------------------------------------------------
local ESP = Window:AddTab({ Title = "ESP", Icon = "scan" })
local Visuals = ESP:AddSection({ Title = "Visuals", Side = "Left" })
Visuals:AddToggle("PlayerESP", { Title = "Players" }):AddColorPicker("PlayerESPColor", {
	Default = Color3.fromRGB(108, 162, 242),
})
Visuals:AddToggle("ChestESP", { Title = "Chests" }):AddColorPicker("ChestESPColor", {
	Default = Color3.fromRGB(240, 180, 60),
})
Visuals:AddToggle("FruitESP", { Title = "Devil Fruits" }):AddColorPicker("FruitESPColor", {
	Default = Color3.fromRGB(236, 92, 152),
})
local ESPSettings = ESP:AddSection({ Title = "Settings", Side = "Right" })
ESPSettings:AddSlider("ESPDistance", { Title = "Max Distance", Min = 100, Max = 5000, Default = 1500, Increment = 50 })
ESPSettings:AddToggle("ESPNames", { Title = "Show Names", Default = true })
ESPSettings:AddToggle("ESPDistanceText", { Title = "Show Distance", Default = true })

--------------------------------------------------------------------------------
-- World
--------------------------------------------------------------------------------
local World = Window:AddTab({ Title = "World", Icon = "compass" })
local Lighting = World:AddSection({ Title = "Lighting", Side = "Left" })
Lighting:AddToggle("FullBright", { Title = "Full Bright" })
Lighting:AddSlider("ClockTime", { Title = "Time Of Day", Min = 0, Max = 24, Default = 14, Increment = 0.5 })
local Movement = World:AddSection({ Title = "Movement", Side = "Right" })
Movement:AddToggle("Noclip", { Title = "Noclip" }):AddKeybind("NoclipKey", { Default = Enum.KeyCode.N, Mode = "Hold" })
Movement:AddToggle("InfiniteJump", { Title = "Infinite Jump" })

--------------------------------------------------------------------------------
-- React to changes anywhere via Options
--------------------------------------------------------------------------------
Options.FightingStyle:OnChanged(function(style)
	print("Fighting style is now", style)
end)

Library:OnUnload(function()
	print("MyUI unloaded")
end)

-- The Settings tab (configs, themes, fonts, scale, keybind list, etc.) is added
-- automatically. Your autoload config, if you set one, loads after this script.
