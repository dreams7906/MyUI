--[[
	MyUI 2 example: a small tour of every element. Replace the cards with your
	own features; the callbacks below only show how values come back to you.

	Click the girl on the header to make her blush, hold the mouse on her to
	pat her, and leave her alone for a while to watch her doze off.
]]

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
	Title = "Example",
	Author = "XX", -- shown as "by XX"
	Badge = "DEV",
	Version = "v1.0",
	Icon = "sparkles", -- any icon name from the sheet (Lucide names)
	Theme = "Dark", -- "Dark" or "Light"; the moon button in the header switches live
	ToggleKey = Enum.KeyCode.RightShift,
	ConfigFolder = "XX/Example",
})

local GREEN = Color3.fromRGB(46, 196, 110)
local ORANGE = Color3.fromRGB(245, 140, 40)
local TEAL = Color3.fromRGB(38, 172, 196)
local PURPLE = Color3.fromRGB(132, 92, 236)
local PINK = Color3.fromRGB(240, 96, 150)
local RED = Color3.fromRGB(232, 72, 86)

--------------------------------------------------------------------------------
-- Main: one card per kind of element. Pills filter the cards.
--------------------------------------------------------------------------------
local Main = Window:AddTab({ Title = "Main", Icon = "house" })
local Basics = Main:AddSubTab("Basics")
local Inputs = Main:AddSubTab("Inputs")
local Pickers = Main:AddSubTab("Pickers")

local Toggles = Basics:AddSection({ Title = "Toggles", Icon = "toggle-right", Color = GREEN, Side = 1 })
local ToggleStatus = Toggles:AddLabel("Example Toggle: Off")
Toggles:AddToggle("ExampleToggle", {
	Title = "Example Toggle",
	Callback = function(value)
		ToggleStatus:SetText("Example Toggle: " .. (value and "On" or "Off"))
	end,
})
Toggles:AddToggle("WithKeybind", { Title = "With A Keybind" }):AddKeybind("WithKeybindKey", { Default = Enum.KeyCode.F })
Toggles:AddToggle("WithColor", { Title = "With A Color", Default = true }):AddColorPicker("WithColorValue", {
	Default = Color3.fromRGB(118, 168, 255),
})

local Buttons = Basics:AddSection({ Title = "Buttons", Icon = "mouse-pointer-click", Color = ORANGE, Side = 2 })
Buttons:AddButton({
	Title = "Notify",
	Callback = function()
		Library:Notify({ Title = "Hello", Content = "This is a notification.", Type = "Success" })
	end,
}):AddButton({
	Title = "Talk",
	Callback = function()
		Window:Say("You pressed a button just to see me? Ehehe~", nil, "Blush")
	end,
})
Buttons:AddButton({
	Title = "Confirm Me",
	Confirm = true, -- asks for a second click
	Callback = function()
		Library:Notify({ Title = "Confirmed", Content = "You clicked twice.", Type = "Info" })
	end,
})

local Sliders = Inputs:AddSection({ Title = "Sliders", Icon = "sliders-horizontal", Color = PURPLE, Side = 1 })
Sliders:AddSlider("WalkSpeed", {
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
Sliders:AddSlider("ExampleRange", { Title = "Example Range", Min = 0, Max = 100, Default = 50, Suffix = "%" })
Sliders:AddSlider("Precision", { Title = "Precision", Min = 0, Max = 1, Default = 0.5, Increment = 0.05 })

local Text = Inputs:AddSection({ Title = "Text", Icon = "type", Color = TEAL, Side = 2 })
Text:AddInput("ExampleText", { Title = "Text", Placeholder = "Type anything" })
Text:AddInput("ExampleNumber", { Title = "Number", Default = 10, Numeric = true, Min = 0, Max = 100 })

local Dropdowns = Pickers:AddSection({ Title = "Dropdowns", Icon = "list", Color = PINK, Side = 1 })
Dropdowns:AddDropdown("SingleChoice", { Title = "Single", Values = { "Option A", "Option B", "Option C" }, Default = "Option A" })
local many = {}
for index = 1, 24 do
	table.insert(many, "Item " .. index)
end
Dropdowns:AddDropdown("MultiChoice", { Title = "Multi + Search", Values = many, Multi = true, Default = { "Item 1", "Item 2" } })

local Colors = Pickers:AddSection({ Title = "Colors And Keys", Icon = "palette", Color = RED, Side = 2 })
Colors:AddColorPicker("ExampleColor", { Title = "Color", Default = Color3.fromRGB(66, 133, 244) })
Colors:AddKeybind("ExampleKey", {
	Title = "Keybind",
	Default = Enum.KeyCode.G,
	Callback = function()
		Library:Notify({ Title = "Keybind", Content = "You pressed the example key.", Type = "Info" })
	end,
})

-- A card made from the tab itself shows under every pill.
local Info = Main:AddSection({ Title = "Info", Icon = "info", Color = PURPLE, Side = 3 })
Info:AddParagraph({
	Title = "Welcome",
	Content = "Right-click any row to reset it. The search button filters this tab. "
		.. "Configs, theme and mascot options live in Settings.",
})
local Status = Info:AddLabel("Single: Option A")

Options.SingleChoice:OnChanged(function(value)
	Status:SetText("Single: " .. tostring(value))
end)

--------------------------------------------------------------------------------
-- Mascot: play with her moods and emotes
--------------------------------------------------------------------------------
local MascotTab = Window:AddTab({ Title = "Mascot", Icon = "heart" })

local Moods = MascotTab:AddSection({ Title = "Moods", Icon = "smile", Color = PINK, Side = 1 })
Moods:AddDropdown("MascotMood", {
	Title = "Mood",
	Values = { "Idle", "Smile", "Happy", "Blush", "Pat", "Flustered", "Surprised", "Pout", "Sleepy", "Wink" },
	Default = "Idle",
	Save = false,
	Callback = function(mood)
		if Window.Mascot then
			Window.Mascot:SetMood(mood)
		end
	end,
})
Moods:AddButton({
	Title = "Hop",
	Callback = function()
		if Window.Mascot then
			Window.Mascot:Hop()
		end
	end,
}):AddButton({
	Title = "Hide",
	Callback = function()
		if Window.Mascot then
			Window.Mascot:Hide()
		end
	end,
}):AddButton({
	Title = "Peek",
	Callback = function()
		if Window.Mascot then
			Window.Mascot:Peek()
		end
	end,
})

local Emotes = MascotTab:AddSection({ Title = "Emotes", Icon = "sparkles", Color = ORANGE, Side = 2 })
for _, emote in { "Hearts", "Sparkles", "Shock", "Sweat", "Sleep" } do
	Emotes:AddButton({
		Title = emote,
		Callback = function()
			if Window.Mascot then
				Window.Mascot:Emote(emote)
			end
		end,
	})
end

local Speech = MascotTab:AddSection({ Title = "Speech", Icon = "message-circle", Color = TEAL, Side = 3 })
Speech:AddInput("MascotLine", {
	Title = "Say",
	Placeholder = "Type a line, press Enter",
	Finished = true,
	Save = false,
	Callback = function(text)
		if text ~= "" then
			Window:Say(text, nil, "Smile")
		end
	end,
})
Speech:AddLabel("Mascot: Hiyori Momose (c) Live2D Inc.", { Style = "Plain" })
