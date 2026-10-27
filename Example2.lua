--[[
	MyUI 2 example: recreates the "Grand Piece Online" reference layout with
	the peeking mascot. Click her to make her blush, hold to pat her, and don't
	poke her too many times. Game logic is placeholder - wire the callbacks to
	your own functions.
]]

-- Change these per game.
local HubName = "XX" -- shown as "by XX" under the title
local GameName = "Grand Piece Online" -- the big title; nil = detect the game's name

local LIBRARY_URL = "https://raw.githubusercontent.com/dreams7906/MyUI/claude/cool-hawking-qhmbhp/MyUI2.lua"

local source = game:HttpGet(LIBRARY_URL)
local chunk, compileError = loadstring(source)
if not chunk then
	error("MyUI2 failed to load from " .. LIBRARY_URL .. "\n" .. tostring(compileError)
		.. "\nResponse started with: " .. string.sub(source, 1, 80))
end
local Library = chunk()
if type(Library) ~= "table" then
	error("MyUI2 did not return the library (response started with: " .. string.sub(source, 1, 80) .. ")")
end
local Options = Library.Options

local Window = Library:CreateWindow({
	Title = GameName,
	Author = HubName,
	Badge = "DEV",
	Version = "v2.4",
	Theme = "Dark", -- "Dark" or "Light"; the moon button in the header switches live
	ToggleKey = Enum.KeyCode.RightShift,
	ConfigFolder = "XX/" .. string.gsub(GameName or tostring(game.PlaceId), "%W", ""),
	LoadingTime = 3.5,
	Size = UDim2.fromOffset(900, 560),
})

local GREEN = Color3.fromRGB(46, 196, 110)
local ORANGE = Color3.fromRGB(245, 120, 40)
local TEAL = Color3.fromRGB(38, 172, 196)
local PURPLE = Color3.fromRGB(132, 92, 236)
local RED = Color3.fromRGB(232, 72, 86)
local PINK = Color3.fromRGB(240, 96, 150)

--------------------------------------------------------------------------------
-- Main: a tour of every element type
--------------------------------------------------------------------------------
local Main = Window:AddTab({ Title = "Main", Icon = "home" })

local Player = Main:AddSection({ Title = "Player", Icon = "user", Color = PINK, Side = 1 })
Player:AddSlider("WalkSpeed", {
	Title = "Walk Speed",
	Min = 16,
	Max = 200,
	Default = 16,
	Callback = function(value)
		local character = game:GetService("Players").LocalPlayer.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.WalkSpeed = value
		end
	end,
})
Player:AddSlider("JumpPower", { Title = "Jump Power", Min = 50, Max = 300, Default = 50 })
Player:AddToggle("InfiniteStamina", { Title = "Infinite Stamina" })
Player:AddKeybind("Dash", { Title = "Dash", Default = Enum.KeyCode.Q })

local Tools = Main:AddSection({ Title = "Tools", Icon = "zap", Color = ORANGE, Side = 2 })
Tools:AddDropdown("Weapon", { Title = "Weapon", Values = { "Katana", "Flintlock", "Cannon", "Bisento" }, Default = "Katana" })
Tools:AddDropdown("Islands", {
	Title = "Islands",
	Values = { "Sandora", "Roca", "Orange Town", "Shells Town", "Baratie", "Fishman Island", "Marineford", "Loguetown" },
	Multi = true,
	Default = { "Sandora", "Roca" },
})
Tools:AddColorPicker("HighlightColor", { Title = "Highlight", Default = Color3.fromRGB(66, 133, 244) })
Tools:AddButton({
	Title = "Notify",
	Callback = function()
		Library:Notify({ Title = "Hello", Content = "This is a notification.", Type = "Success" })
	end,
}):AddButton({
	Title = "Talk",
	Callback = function()
		Window:Say("H-hi! You pressed a button just to see me?", nil, "Blush")
	end,
})

local Info = Main:AddSection({ Title = "Info", Icon = "info", Color = PURPLE, Side = 3 })
Info:AddParagraph({
	Title = "Welcome back",
	Content = "Right-click any row to reset it. Use the search button to filter a tab. "
		.. "Configs, theme and mascot options live in Settings.",
})
local Status = Info:AddLabel("Session started")

--------------------------------------------------------------------------------
-- Farm: mirrors the reference screenshot
--------------------------------------------------------------------------------
local Farm = Window:AddTab({ Title = "Farm", Icon = "bike" })
local Baal = Farm:AddSubTab("Ba'al")
local Level = Farm:AddSubTab("Level")
local Fishing = Farm:AddSubTab("Fishing")
local Kraken = Farm:AddSubTab("Kraken")
local Halloween = Farm:AddSubTab("Halloween")
local Bosses = Farm:AddSubTab("Bosses")
local Events = Farm:AddSubTab("Events")

local LevelFarm = Level:AddSection({ Title = "Level Farm", Icon = "star", Color = GREEN, Side = 1 })
local LevelStatus = LevelFarm:AddLabel("Level Farm: Disabled")
LevelFarm:AddToggle("LevelFarm", {
	Title = "Level Farm",
	Callback = function(value)
		LevelStatus:SetText("Level Farm: " .. (value and "Enabled" or "Disabled"))
	end,
}):AddKeybind("LevelFarmKey", { Default = Enum.KeyCode.F })
LevelFarm:AddToggle("BuyGeppo", { Title = "Buy Geppo", Default = true })
LevelFarm:AddToggle("GetHakiV1", { Title = "Get Haki V1", Default = true })

local HalloweenFarm = Halloween:AddSection({ Title = "Halloween Farm", Icon = "pumpkin", Color = ORANGE, Side = 1 })
HalloweenFarm:AddToggle("HalloweenFarm", { Title = "Halloween Farm" })
HalloweenFarm:AddToggle("UpgradeBasket", { Title = "Upgrade Basket", Default = true })
HalloweenFarm:AddToggle("BuyOnMax", { Title = "Buy On Max" })
HalloweenFarm:AddToggle("HalloweenSpawn", { Title = "Auto Set Spawn", Default = true })
HalloweenFarm:AddToggle("PeliChests", { Title = "Collect Peli Chests", Default = true })
HalloweenFarm:AddToggle("OtherSides", { Title = "Other Sides", Default = true })
HalloweenFarm:AddInput("HalloweenWebhook", { Title = "Webhook", Placeholder = "Discord webhook URL" })

local FishingFarm = Fishing:AddSection({ Title = "Fishing", Icon = "fish", Color = TEAL, Side = 2 })
FishingFarm:AddLabel("Notifications: No messages")
local FishStatus = FishingFarm:AddLabel("Fish Farm: Disabled")
FishingFarm:AddToggle("FishFarm", {
	Title = "Fish Farm",
	Callback = function(value)
		FishStatus:SetText("Fish Farm: " .. (value and "Enabled" or "Disabled"))
	end,
})
FishingFarm:AddToggle("FishBelowPlayer", { Title = "Fish Below Player" })
FishingFarm:AddToggle("LevelBelow375", { Title = "Level Farm Below 375" })
FishingFarm:AddToggle("AutoMerchant", { Title = "Auto Merchant" })
FishingFarm:AddToggle("FishStoreFruit", { Title = "Auto Store Fruit", Default = true })
FishingFarm:AddToggle("FishSpawn", { Title = "Auto Set Spawn" })
FishingFarm:AddToggle("FishingTitle", { Title = "Auto Equip Fishing Title" })
FishingFarm:AddInput("BaitAmount", { Title = "Common Bait Amount", Default = 300, Numeric = true, Min = 0 })
FishingFarm:AddInput("MerchantWebhook", { Title = "Merchant Webhook", Placeholder = "Discord webhook URL" })
FishingFarm:AddInput("FishFruitWebhook", { Title = "Fruit Webhook", Placeholder = "Uses Merchant Webhook" })
FishingFarm:AddDropdown("FishBait", {
	Title = "Selected Fish Bait",
	Values = { "Common", "Uncommon", "Rare", "Legendary", "Golden" },
	Multi = true,
	Default = { "Common", "Uncommon", "Rare" },
})

local KrakenFarm = Kraken:AddSection({ Title = "Kraken Farm", Icon = "kraken", Color = PURPLE, Side = 3 })
KrakenFarm:AddToggle("KrakenFarm", { Title = "Kraken Farm" })
KrakenFarm:AddToggle("KrakenStoreFruit", { Title = "Auto Store Fruit", Default = true })
KrakenFarm:AddToggle("KrakenSpawn", { Title = "Auto Set Spawn" })
KrakenFarm:AddInput("KrakenWebhook", { Title = "Fruit Webhook", Placeholder = "Discord webhook URL" })
KrakenFarm:AddInput("AnchorAccount", { Title = "Anchor account", Placeholder = "Party owner's exact name" })
KrakenFarm:AddInput("KrakenCount", { Title = "Kraken Count", Default = 3, Numeric = true, Min = 1, Max = 50 })
KrakenFarm:AddToggle("PauseForConfig", { Title = "Pause for Config" })
KrakenFarm:AddToggle("KillAttacks", { Title = "Kill Attacks", Default = true })
KrakenFarm:AddToggle("AnchorAttacks", { Title = "Anchor Attacks", Default = true })
KrakenFarm:AddDropdown("AccountType", { Title = "Account Type", Values = { "Kill", "Solo", "Anchor" }, Default = "Kill" })
KrakenFarm:AddLabel("Solo and Kill Only will be integrated soon.")
KrakenFarm:AddLabel("Kraken Farm: Disabled")

local BaalFarm = Baal:AddSection({ Title = "Ba'al", Icon = "flag", Color = RED, Side = 2 })
BaalFarm:AddToggle("BaalFarm", { Title = "Ba'al Farm" })
BaalFarm:AddToggle("BaalHop", { Title = "Server Hop When Dead" })
local BossSection = Bosses:AddSection({ Title = "Bosses", Icon = "sword", Color = RED, Side = 1 })
BossSection:AddDropdown("BossTarget", { Title = "Target", Values = { "Logia Lord", "Sea King", "Marine Admiral" } })
BossSection:AddToggle("BossFarm", { Title = "Boss Farm" })
local EventSection = Events:AddSection({ Title = "Events", Icon = "sparkle", Color = PINK, Side = 3 })
EventSection:AddToggle("EventNotify", { Title = "Notify On Event" })

--------------------------------------------------------------------------------
-- ESP and World
--------------------------------------------------------------------------------
local ESP = Window:AddTab({ Title = "ESP", Icon = "eye" })
local Visuals = ESP:AddSection({ Title = "Visuals", Icon = "eye", Color = TEAL, Side = 1 })
Visuals:AddToggle("PlayerESP", { Title = "Players" }):AddColorPicker("PlayerESPColor", { Default = Color3.fromRGB(118, 168, 255) })
Visuals:AddToggle("ChestESP", { Title = "Chests" }):AddColorPicker("ChestESPColor", { Default = Color3.fromRGB(245, 180, 60) })
Visuals:AddToggle("FruitESP", { Title = "Devil Fruits" }):AddColorPicker("FruitESPColor", { Default = PINK })
local ESPOptions = ESP:AddSection({ Title = "Options", Icon = "sliders", Color = PURPLE, Side = 2 })
ESPOptions:AddSlider("ESPDistance", { Title = "Max Distance", Min = 100, Max = 5000, Default = 1500, Increment = 50 })
ESPOptions:AddToggle("ESPNames", { Title = "Show Names", Default = true })

local World = Window:AddTab({ Title = "World", Icon = "globe" })
local Lighting = World:AddSection({ Title = "Lighting", Icon = "sun", Color = ORANGE, Side = 1 })
Lighting:AddToggle("FullBright", { Title = "Full Bright" })
Lighting:AddSlider("ClockTime", { Title = "Time Of Day", Min = 0, Max = 24, Default = 14, Increment = 0.5 })
local Movement = World:AddSection({ Title = "Movement", Icon = "compass", Color = GREEN, Side = 2 })
Movement:AddToggle("Noclip", { Title = "Noclip" }):AddKeybind("NoclipKey", { Default = Enum.KeyCode.N, Mode = "Hold" })

Options.AccountType:OnChanged(function(value)
	Status:SetText("Account type: " .. tostring(value))
end)
