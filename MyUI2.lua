--!nonstrict
--[[
	MyUI 2 · "Peek" layout with a mascot, for Roblox
	https://github.com/dreams7906/MyUI

	    local Library = loadstring(game:HttpGet(
	        "https://raw.githubusercontent.com/dreams7906/MyUI/main/MyUI2.lua"
	    ))()

	A blue header band with tabs, pill filters, three columns of cards, a
	light and a dark theme, and a peeking chibi mascot who blushes and talks
	when you click her. Everything (icons, mascot, color wheel) is drawn from
	plain GuiObjects; no uploaded images are needed. See README.md.
]]

local cloneref = cloneref or function(instance)
	return instance
end

local function GetService(name)
	return cloneref(game:GetService(name))
end

local Players = GetService("Players")
local TweenService = GetService("TweenService")
local UserInputService = GetService("UserInputService")
local RunService = GetService("RunService")
local HttpService = GetService("HttpService")
local CoreGui = GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer

local rgb = Color3.fromRGB
local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)

local MB1 = Enum.UserInputType.MouseButton1
local MB2 = Enum.UserInputType.MouseButton2
local MB3 = Enum.UserInputType.MouseButton3
local TOUCH = Enum.UserInputType.Touch
local MOUSE_MOVE = Enum.UserInputType.MouseMovement
local KEYBOARD = Enum.UserInputType.Keyboard

local Library = {
	Version = "2.0.0",
	Flags = {},
	Options = {},
	Unloaded = false,

	Folder = "MyUI2",
	AutoSave = false,
	ActiveConfig = nil,
	LastSaved = nil,

	Theme = {},
	ThemeName = "Dark",
	FontName = "Gotham",
	Scale = 1,
	Animations = true,
	MenuKey = "RightShift",
	NotifySide = "Right",
	ShowKeybinds = false,

	MascotEnabled = true,
	MascotSpeech = true,
	MascotFollow = true,
	MascotReactions = true,

	Connections = {},
	_pending = {},
	_unload = {},
	_status = {},
}

--------------------------------------------------------------------------------
-- Utilities
--------------------------------------------------------------------------------

local Util = {}

function Util.Trim(text)
	return (string.gsub(tostring(text or ""), "^%s*(.-)%s*$", "%1"))
end

function Util.Lower(text)
	return string.lower(tostring(text or ""))
end

function Util.Decimals(step)
	local text = tostring(step)
	local dot = string.find(text, ".", 1, true)
	return dot and #text - dot or 0
end

function Util.Snap(value, step, min)
	local snapped = min + math.floor((value - min) / step + 0.5) * step
	return tonumber(string.format("%." .. Util.Decimals(step) .. "f", snapped))
end

function Util.Format(value, step)
	return string.format("%." .. Util.Decimals(step) .. "f", value)
end

function Util.Inside(gui, position)
	local p, s = gui.AbsolutePosition, gui.AbsoluteSize
	return position.X >= p.X and position.X <= p.X + s.X and position.Y >= p.Y and position.Y <= p.Y + s.Y
end

function Util.Sanitize(name)
	return Util.Trim((string.gsub(tostring(name or ""), "[^%w%s%-_%.%(%)]", "")))
end

function Util.ToHex(color)
	return string.upper(color:ToHex())
end

function Util.FromHex(text)
	text = string.gsub(tostring(text or ""), "[#%s]", "")
	if #text == 3 then
		text = string.gsub(text, "%x", "%0%0")
	end
	if not string.match(text, "^%x%x%x%x%x%x$") then
		return nil
	end
	return Color3.fromHex(text)
end

function Util.Keys(dictionary, order)
	local list = {}
	if order then
		for _, value in order do
			if dictionary[value] then
				table.insert(list, value)
			end
		end
	else
		for key in dictionary do
			table.insert(list, key)
		end
	end
	return list
end

local function Encode(data)
	local ok, result = pcall(HttpService.JSONEncode, HttpService, data)
	return ok and result or nil
end

local function Decode(text)
	if type(text) ~= "string" or text == "" then
		return nil
	end
	local ok, result = pcall(HttpService.JSONDecode, HttpService, text)
	return ok and result or nil
end

local function Connect(signal, callback)
	local connection = signal:Connect(callback)
	table.insert(Library.Connections, connection)
	return connection
end

local lastErrorToast = 0
local function SafeCall(callback, ...)
	if type(callback) ~= "function" then
		return
	end
	task.spawn(function(...)
		local ok, err = xpcall(callback, debug.traceback, ...)
		if not ok then
			warn("[MyUI] callback error: " .. tostring(err))
			if os.clock() - lastErrorToast > 2 and Library.Notify then
				lastErrorToast = os.clock()
				Library:Notify({
					Title = "Callback error",
					Content = string.match(tostring(err), "^[^\n]*") or "unknown error",
					Type = "Error",
				})
			end
		end
	end, ...)
end

local KeyAliases = {
	LeftShift = "LShift", RightShift = "RShift", LeftControl = "LCtrl", RightControl = "RCtrl",
	LeftAlt = "LAlt", RightAlt = "RAlt", LeftSuper = "LWin", RightSuper = "RWin",
	Return = "Enter", Backspace = "Back", CapsLock = "Caps", PageUp = "PgUp", PageDown = "PgDn",
	Insert = "Ins", Delete = "Del", Escape = "Esc",
	MouseButton1 = "MB1", MouseButton2 = "MB2", MouseButton3 = "MB3",
	Zero = "0", One = "1", Two = "2", Three = "3", Four = "4",
	Five = "5", Six = "6", Seven = "7", Eight = "8", Nine = "9",
	Minus = "-", Equals = "=", LeftBracket = "[", RightBracket = "]", Semicolon = ";",
	Quote = "'", Comma = ",", Period = ".", Slash = "/", BackSlash = "\\", Backquote = "`",
}

local function KeyDisplay(name)
	if not name or name == "None" then
		return "None"
	end
	return KeyAliases[name] or name
end

local function InputName(input)
	local kind = input.UserInputType
	if kind == KEYBOARD then
		return input.KeyCode.Name
	elseif kind == MB1 then
		return "MouseButton1"
	elseif kind == MB2 then
		return "MouseButton2"
	elseif kind == MB3 then
		return "MouseButton3"
	elseif input.KeyCode.Value ~= 0 then
		return input.KeyCode.Name
	end
	return nil
end

--------------------------------------------------------------------------------
-- File system (executor API with an in-memory fallback for Studio)
--------------------------------------------------------------------------------

local FS = {
	write = writefile,
	read = readfile,
	isfile = isfile,
	isfolder = isfolder,
	makefolder = makefolder,
	list = listfiles,
	delete = delfile,
}
local HasFS = FS.write ~= nil and FS.read ~= nil and FS.isfile ~= nil
	and FS.isfolder ~= nil and FS.makefolder ~= nil and FS.list ~= nil
local MemoryFiles = {}

local File = {}

function File.Exists(path)
	if HasFS then
		local ok, result = pcall(FS.isfile, path)
		return ok and result == true
	end
	return MemoryFiles[path] ~= nil
end

function File.Read(path)
	if HasFS then
		local ok, result = pcall(FS.read, path)
		return ok and result or nil
	end
	return MemoryFiles[path]
end

function File.Write(path, content)
	if HasFS then
		return (pcall(FS.write, path, content))
	end
	MemoryFiles[path] = content
	return true
end

function File.Delete(path)
	if HasFS then
		if not FS.delete then
			return false
		end
		return (pcall(FS.delete, path))
	end
	MemoryFiles[path] = nil
	return true
end

function File.MakeFolder(path)
	if not HasFS then
		return
	end
	local current = ""
	for part in string.gmatch(path, "[^/\\]+") do
		current = current == "" and part or current .. "/" .. part
		local ok, exists = pcall(FS.isfolder, current)
		if not (ok and exists) then
			pcall(FS.makefolder, current)
		end
	end
end

-- Returns the base names (without extension) of every `.json` file in a folder.
function File.ListJson(folder)
	local names = {}
	if HasFS then
		local ok, list = pcall(FS.list, folder)
		if ok and type(list) == "table" then
			for _, path in list do
				local name = string.match(tostring(path), "([^/\\]+)%.json$")
				if name then
					table.insert(names, name)
				end
			end
		end
	else
		local prefix = folder .. "/"
		for path in MemoryFiles do
			if string.sub(path, 1, #prefix) == prefix then
				local name = string.match(string.sub(path, #prefix + 1), "^([^/\\]+)%.json$")
				if name then
					table.insert(names, name)
				end
			end
		end
	end
	table.sort(names, function(a, b)
		return string.lower(a) < string.lower(b)
	end)
	return names
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Theme: one light and one dark palette
--------------------------------------------------------------------------------

local Palettes = {
	Dark = {
		Accent = rgb(66, 133, 244),
		AccentGlow = rgb(118, 168, 255),
		AccentDark = rgb(38, 92, 200),
		Header = rgb(45, 92, 222),
		HeaderDark = rgb(27, 58, 156),
		HeaderText = rgb(255, 255, 255),
		Background = rgb(27, 27, 30),
		Panel = rgb(37, 37, 41),
		Element = rgb(46, 46, 51),
		Inset = rgb(30, 30, 34),
		Pill = rgb(44, 45, 50),
		Hover = rgb(55, 56, 62),
		Border = rgb(50, 51, 57),
		Text = rgb(236, 236, 239),
		SubText = rgb(206, 207, 212),
		DimText = rgb(133, 134, 141),
		OnAccent = rgb(255, 255, 255),
		Track = rgb(60, 61, 67),
		Knob = rgb(242, 242, 245),
		Good = rgb(82, 214, 134),
	},
	Light = {
		Accent = rgb(52, 112, 236),
		AccentGlow = rgb(102, 156, 252),
		AccentDark = rgb(32, 82, 190),
		Header = rgb(48, 98, 230),
		HeaderDark = rgb(32, 72, 186),
		HeaderText = rgb(255, 255, 255),
		Background = rgb(235, 238, 243),
		Panel = rgb(255, 255, 255),
		Element = rgb(240, 242, 246),
		Inset = rgb(244, 245, 248),
		Pill = rgb(255, 255, 255),
		Hover = rgb(226, 230, 237),
		Border = rgb(221, 225, 232),
		Text = rgb(24, 26, 32),
		SubText = rgb(58, 62, 72),
		DimText = rgb(128, 134, 146),
		OnAccent = rgb(255, 255, 255),
		Track = rgb(206, 211, 220),
		Knob = rgb(255, 255, 255),
		Good = rgb(26, 160, 88),
	},
}

for key, value in Palettes.Dark do
	Library.Theme[key] = value
end

-- instance -> { [property] = themeKey | function(theme) }
-- These are strong tables on purpose: Roblox can garbage-collect the Lua
-- wrapper of a live Instance, which silently empties weak-keyed tables.
-- Destroyed instances are swept out instead (see SweepRegistries).
local Registry = {}
-- text instance -> font weight name
local FontRegistry = {}
-- functions re-run after the theme changes (stateful elements repaint themselves)
local ThemeListeners = {}

local sweepQueued, registrations = false, 0

-- Drops entries for destroyed instances. Deferred so it never runs while an
-- instance is still being built (and therefore has no Parent yet).
local function SweepRegistries()
	sweepQueued = false
	for instance in Registry do
		if instance.Parent == nil then
			Registry[instance] = nil
		end
	end
	for instance in FontRegistry do
		if instance.Parent == nil then
			FontRegistry[instance] = nil
		end
	end
end

local function Registered()
	registrations += 1
	if registrations >= 400 and not sweepQueued then
		registrations = 0
		sweepQueued = true
		task.defer(SweepRegistries)
	end
end

local function Resolve(value)
	if type(value) == "function" then
		return value(Library.Theme)
	end
	return Library.Theme[value]
end

local function Bind(instance, map)
	local entry = Registry[instance]
	if not entry then
		entry = {}
		Registry[instance] = entry
		Registered()
	end
	for property, key in map do
		entry[property] = key
		instance[property] = Resolve(key)
	end
	return instance
end

local function OnTheme(callback)
	table.insert(ThemeListeners, callback)
	return callback
end

local function AccentSequence(theme)
	return ColorSequence.new(theme.Accent, theme.Accent)
end

--------------------------------------------------------------------------------
-- Fonts
--------------------------------------------------------------------------------

local FontChoices = {
	{ "Gotham", Enum.Font.Gotham },
	{ "Builder Sans", Enum.Font.BuilderSans },
	{ "Roboto", Enum.Font.Roboto },
	{ "Ubuntu", Enum.Font.Ubuntu },
	{ "Nunito", Enum.Font.Nunito },
	{ "Source Sans", Enum.Font.SourceSans },
	{ "Arimo", Enum.Font.Arimo },
	{ "Josefin Sans", Enum.Font.JosefinSans },
	{ "Titillium Web", Enum.Font.TitilliumWeb },
	{ "Jura", Enum.Font.Jura },
	{ "Michroma", Enum.Font.Michroma },
	{ "Oswald", Enum.Font.Oswald },
	{ "Roboto Mono", Enum.Font.RobotoMono },
}

local FontNames = {}
for _, choice in FontChoices do
	table.insert(FontNames, choice[1])
end

local function FontFamily(name)
	for _, choice in FontChoices do
		if choice[1] == name then
			local ok, font = pcall(Font.fromEnum, choice[2])
			if ok and font then
				return font.Family
			end
		end
	end
	return "rbxasset://fonts/families/GothamSSm.json"
end

local CurrentFamily = FontFamily("Gotham")
local MonoFamily = FontFamily("Roboto Mono")
local FontCache = {}

-- Weights are Enum.FontWeight names, plus "Mono" / "MonoBold" for the
-- monospace family used by stats and status lines.
local function GetFont(weight)
	local font = FontCache[weight]
	if not font then
		if weight == "Mono" or weight == "MonoBold" then
			font = Font.new(MonoFamily, weight == "Mono" and Enum.FontWeight.Medium or Enum.FontWeight.Bold)
		else
			font = Font.new(CurrentFamily, Enum.FontWeight[weight])
		end
		FontCache[weight] = font
	end
	return font
end

local function SetWeight(instance, weight)
	if not FontRegistry[instance] then
		Registered()
	end
	FontRegistry[instance] = weight
	instance.FontFace = GetFont(weight)
end

--------------------------------------------------------------------------------
-- Instance factory
--------------------------------------------------------------------------------

local TextClasses = { TextLabel = true, TextButton = true, TextBox = true }

local ClassDefaults = {
	Frame = { BorderSizePixel = 0 },
	CanvasGroup = { BorderSizePixel = 0 },
	ScrollingFrame = {
		BorderSizePixel = 0,
		BackgroundTransparency = 1,
		ScrollBarThickness = 2,
		ScrollBarImageTransparency = 0.3,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
	},
	TextLabel = { BorderSizePixel = 0, BackgroundTransparency = 1, Text = "", TextXAlignment = Enum.TextXAlignment.Left },
	TextButton = { BorderSizePixel = 0, AutoButtonColor = false, Text = "" },
	TextBox = {
		BorderSizePixel = 0,
		BackgroundTransparency = 1,
		ClearTextOnFocus = false,
		Text = "",
		TextXAlignment = Enum.TextXAlignment.Left,
	},
	ImageLabel = { BorderSizePixel = 0, BackgroundTransparency = 1 },
}

local Create

local function ApplyShorthand(instance, key, value)
	if key == "Corner" then
		Create("UICorner", {
			CornerRadius = typeof(value) == "UDim" and value or UDim.new(0, value),
			Parent = instance,
		})
	elseif key == "Stroke" then
		local spec = type(value) == "table" and value or { Color = value }
		local stroke = Create("UIStroke", {
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Thickness = spec.Thickness or 1,
			Transparency = spec.Transparency or 0,
			Parent = instance,
		})
		Bind(stroke, { Color = spec.Color or "Border" })
	elseif key == "Padding" then
		local spec = type(value) == "table" and value or { value, value, value, value }
		Create("UIPadding", {
			PaddingTop = UDim.new(0, spec[1] or 0),
			PaddingBottom = UDim.new(0, spec[2] or 0),
			PaddingLeft = UDim.new(0, spec[3] or 0),
			PaddingRight = UDim.new(0, spec[4] or 0),
			Parent = instance,
		})
	elseif key == "List" then
		-- Built directly: `Padding` is itself a Create() shorthand key.
		local layout = Instance.new("UIListLayout")
		layout.FillDirection = value.Horizontal and Enum.FillDirection.Horizontal or Enum.FillDirection.Vertical
		layout.Padding = UDim.new(0, value.Padding or 0)
		layout.HorizontalAlignment = value.HAlign or Enum.HorizontalAlignment.Left
		layout.VerticalAlignment = value.VAlign or Enum.VerticalAlignment.Top
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Parent = instance
	end
end

local Shorthands = { Corner = true, Stroke = true, Padding = true, List = true }

function Create(className, props, children)
	local instance = Instance.new(className)
	local defaults = ClassDefaults[className]
	if defaults then
		for key, value in defaults do
			instance[key] = value
		end
	end
	local parent, shorthand
	if props then
		for key, value in props do
			if key == "Parent" then
				parent = value
			elseif key == "Theme" then
				Bind(instance, value)
			elseif key == "Weight" then
				SetWeight(instance, value)
			elseif Shorthands[key] then
				shorthand = shorthand or {}
				shorthand[key] = value
			else
				instance[key] = value
			end
		end
	end
	if TextClasses[className] and not FontRegistry[instance] then
		SetWeight(instance, "Medium")
	end
	if shorthand then
		for key, value in shorthand do
			ApplyShorthand(instance, key, value)
		end
	end
	if children then
		for _, child in children do
			child.Parent = instance
		end
	end
	if parent then
		instance.Parent = parent
	end
	return instance
end

--------------------------------------------------------------------------------
-- Tweening
--------------------------------------------------------------------------------

local TweenInfos = {}

local function Set(instance, props)
	for key, value in props do
		instance[key] = value
	end
end

local function Tween(instance, props, duration, style, direction)
	if not Library.Animations then
		Set(instance, props)
		return nil
	end
	duration = duration or 0.2
	style = style or Enum.EasingStyle.Quint
	direction = direction or Enum.EasingDirection.Out
	local byStyle = TweenInfos[style]
	if not byStyle then
		byStyle = {}
		TweenInfos[style] = byStyle
	end
	local key = direction == Enum.EasingDirection.Out and duration or -duration
	local info = byStyle[key]
	if not info then
		info = TweenInfo.new(duration, style, direction)
		byStyle[key] = info
	end
	local tween = TweenService:Create(instance, info, props)
	tween:Play()
	return tween
end

local function Animate(instant)
	return instant and Set or Tween
end

--------------------------------------------------------------------------------
-- Vector icons (drawn from frames on a 24x24 grid)
--------------------------------------------------------------------------------

local Icons = {}
local Painter = {}
Painter.__index = Painter

function Painter:_Add(instance, property)
	table.insert(self.Parts, { instance, property })
	return instance
end

function Painter:Line(x1, y1, x2, y2, fade)
	local u, t = self.U, self.T
	local dx, dy = (x2 - x1) * u, (y2 - y1) * u
	local length = math.sqrt(dx * dx + dy * dy) + t
	-- Axis-aligned strokes skip Rotation entirely: they render crisper.
	local vertical = math.abs(dx) < 1e-6
	local line = Create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset((x1 + x2) / 2 * u, (y1 + y2) / 2 * u),
		Size = vertical and UDim2.fromOffset(t, length) or UDim2.fromOffset(length, t),
		Rotation = (vertical or math.abs(dy) < 1e-6) and 0 or math.deg(math.atan2(dy, dx)),
		BackgroundColor3 = self.Color,
		Corner = UDim.new(1, 0),
		Parent = self.Frame,
	})
	if fade then
		Create("UIGradient", {
			Rotation = vertical and 90 or 0,
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.9),
				NumberSequenceKeypoint.new(0.5, 0),
				NumberSequenceKeypoint.new(1, 0.9),
			}),
			Parent = line,
		})
	end
	return self:_Add(line, "BackgroundColor3")
end

function Painter:Circle(cx, cy, r, filled)
	local u, t = self.U, self.T
	local d = filled and 2 * r * u or 2 * r * u - t
	local circle = Create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(cx * u, cy * u),
		Size = UDim2.fromOffset(d, d),
		BackgroundColor3 = self.Color,
		BackgroundTransparency = filled and 0 or 1,
		Corner = UDim.new(1, 0),
		Parent = self.Frame,
	})
	if filled then
		return self:_Add(circle, "BackgroundColor3")
	end
	return self:_Add(Create("UIStroke", { Thickness = t, Color = self.Color, Parent = circle }), "Color")
end

-- A filled circle in the icon's mask color (used to carve the moon's crescent).
function Painter:Mask(cx, cy, r)
	local u = self.U
	local mask = Create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(cx * u, cy * u),
		Size = UDim2.fromOffset(2 * r * u, 2 * r * u),
		BackgroundColor3 = self.MaskColor or BLACK,
		Corner = UDim.new(1, 0),
		Parent = self.Frame,
	})
	table.insert(self.Masks, mask)
	return mask
end

function Painter:Rect(x, y, w, h, radius, filled, rotation)
	local u, t = self.U, self.T
	local rect = Create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset((x + w / 2) * u, (y + h / 2) * u),
		Size = filled and UDim2.fromOffset(w * u, h * u) or UDim2.fromOffset(w * u - t, h * u - t),
		Rotation = rotation or 0,
		BackgroundColor3 = self.Color,
		BackgroundTransparency = filled and 0 or 1,
		Corner = (radius or 0) >= 99 and UDim.new(1, 0) or UDim.new(0, (radius or 0) * u),
		Parent = self.Frame,
	})
	if filled then
		return self:_Add(rect, "BackgroundColor3")
	end
	return self:_Add(Create("UIStroke", { Thickness = t, Color = self.Color, Parent = rect }), "Color")
end

Icons.grid = function(p)
	p:Rect(3, 3, 7.5, 7.5, 2)
	p:Rect(13.5, 3, 7.5, 7.5, 2)
	p:Rect(3, 13.5, 7.5, 7.5, 2)
	p:Rect(13.5, 13.5, 7.5, 7.5, 2)
end
Icons.sprout = function(p)
	p:Line(12, 21, 12, 11.5)
	p:Rect(3.6, 6.6, 9.6, 5, 99, false, 32)
	p:Rect(11, 4.6, 10.6, 5.2, 99, false, -40)
end
Icons.scan = function(p)
	p:Line(3, 8, 3, 3)
	p:Line(3, 3, 8, 3)
	p:Line(16, 3, 21, 3)
	p:Line(21, 3, 21, 8)
	p:Line(21, 16, 21, 21)
	p:Line(21, 21, 16, 21)
	p:Line(8, 21, 3, 21)
	p:Line(3, 21, 3, 16)
	p:Circle(12, 12, 4)
	p:Circle(12, 12, 1.4, true)
end
Icons.compass = function(p)
	p:Circle(12, 12, 9.5)
	p:Rect(9.6, 5.5, 4.8, 13, 99, false, 45)
end
Icons.sliders = function(p)
	p:Line(3, 6, 21, 6)
	p:Line(3, 12, 21, 12)
	p:Line(3, 18, 21, 18)
	p:Circle(8, 6, 2.4, true)
	p:Circle(16, 12, 2.4, true)
	p:Circle(10, 18, 2.4, true)
end
Icons.clock = function(p)
	p:Circle(12, 12, 9.5)
	p:Line(12, 12, 12, 6.5)
	p:Line(12, 12, 15.5, 14.5)
end
Icons.info = function(p)
	p:Circle(12, 12, 9.5)
	p:Line(12, 11, 12, 16.5)
	p:Circle(12, 7.6, 1.3, true)
end
Icons.alert = function(p)
	p:Circle(12, 12, 9.5)
	p:Line(12, 7, 12, 13)
	p:Circle(12, 16.6, 1.3, true)
end
Icons.check = function(p)
	p:Line(5, 12.5, 10, 17.5)
	p:Line(10, 17.5, 19, 7)
end
Icons.x = function(p)
	p:Line(6, 6, 18, 18)
	p:Line(18, 6, 6, 18)
end
Icons.search = function(p)
	p:Circle(10.5, 10.5, 6.5)
	p:Line(15.5, 15.5, 20.5, 20.5)
end
Icons.user = function(p)
	p:Circle(12, 7.5, 4)
	p:Rect(4.5, 14, 15, 8, 5)
end
Icons.home = function(p)
	p:Line(3, 11, 12, 3.5)
	p:Line(12, 3.5, 21, 11)
	p:Rect(5.5, 10, 13, 11, 2)
end
Icons.sword = function(p)
	p:Line(7, 17, 20, 4)
	p:Line(4.5, 14.5, 9.5, 19.5)
	p:Line(7, 17, 3.5, 20.5)
end
Icons.eye = function(p)
	p:Rect(2, 6.5, 20, 11, 99)
	p:Circle(12, 12, 3, true)
end
Icons.gear = function(p)
	p:Circle(12, 12, 3.2)
	p:Circle(12, 12, 7)
	for i = 0, 7 do
		local a = i * math.pi / 4
		p:Line(12 + math.cos(a) * 7.5, 12 + math.sin(a) * 7.5, 12 + math.cos(a) * 9.8, 12 + math.sin(a) * 9.8)
	end
end
Icons.folder = function(p)
	p:Rect(3, 7, 18, 13.5, 2.5)
	p:Line(4, 4.5, 9, 4.5)
	p:Line(9, 4.5, 11, 7)
end
Icons.list = function(p)
	p:Circle(4.5, 6, 1.4, true)
	p:Circle(4.5, 12, 1.4, true)
	p:Circle(4.5, 18, 1.4, true)
	p:Line(9, 6, 21, 6)
	p:Line(9, 12, 21, 12)
	p:Line(9, 18, 21, 18)
end
Icons.palette = function(p)
	p:Circle(12, 12, 9.5)
	p:Circle(8, 10, 1.6, true)
	p:Circle(12, 7, 1.6, true)
	p:Circle(16, 10, 1.6, true)
	p:Circle(14.5, 15.5, 1.6, true)
end
Icons.keyboard = function(p)
	p:Rect(2, 5.5, 20, 13, 3)
	p:Circle(6.5, 10, 1, true)
	p:Circle(10.2, 10, 1, true)
	p:Circle(13.8, 10, 1, true)
	p:Circle(17.5, 10, 1, true)
	p:Line(8, 14.5, 16, 14.5)
end
Icons.globe = function(p)
	p:Circle(12, 12, 9.5)
	p:Rect(8, 2.5, 8, 19, 99)
	p:Line(2.5, 12, 21.5, 12)
end
Icons.target = function(p)
	p:Circle(12, 12, 9.5)
	p:Circle(12, 12, 5.5)
	p:Circle(12, 12, 1.6, true)
end
Icons.crosshair = function(p)
	p:Circle(12, 12, 7.5)
	p:Line(12, 1.5, 12, 6)
	p:Line(12, 18, 12, 22.5)
	p:Line(1.5, 12, 6, 12)
	p:Line(18, 12, 22.5, 12)
end
Icons.zap = function(p)
	p:Line(13.5, 2.5, 5, 13.5)
	p:Line(5, 13.5, 12, 13.5)
	p:Line(12, 13.5, 10.5, 21.5)
	p:Line(10.5, 21.5, 19, 10.5)
	p:Line(19, 10.5, 12, 10.5)
	p:Line(12, 10.5, 13.5, 2.5)
end
Icons.code = function(p)
	p:Line(8, 7, 3, 12)
	p:Line(3, 12, 8, 17)
	p:Line(16, 7, 21, 12)
	p:Line(21, 12, 16, 17)
end
Icons.save = function(p)
	p:Rect(3.5, 3.5, 17, 17, 2.5)
	p:Rect(8, 3.5, 8, 5.5, 1)
	p:Rect(7, 13, 10, 7.5, 1)
end
Icons.plus = function(p)
	p:Line(12, 5, 12, 19)
	p:Line(5, 12, 19, 12)
end
Icons.minus = function(p)
	p:Line(5, 12, 19, 12)
end
Icons.dots = function(p)
	p:Circle(12, 5, 1.8, true)
	p:Circle(12, 12, 1.8, true)
	p:Circle(12, 19, 1.8, true)
end
Icons.updown = function(p)
	p:Line(7.5, 9.5, 12, 5)
	p:Line(12, 5, 16.5, 9.5)
	p:Line(7.5, 14.5, 12, 19)
	p:Line(12, 19, 16.5, 14.5)
end
Icons.chevron = function(p)
	p:Line(6, 9, 12, 15)
	p:Line(12, 15, 18, 9)
end
Icons.grip = function(p)
	p:Circle(19, 19, 1.6, true)
	p:Circle(13, 19, 1.6, true)
	p:Circle(19, 13, 1.6, true)
	p:Circle(7, 19, 1.6, true)
	p:Circle(13, 13, 1.6, true)
	p:Circle(19, 7, 1.6, true)
end
Icons.star = function(p)
	for i = 0, 4 do
		local a = math.rad(-90 + i * 72)
		p:Line(12, 12.5, 12 + math.cos(a) * 9, 12.5 + math.sin(a) * 9)
	end
	p:Circle(12, 12.5, 4.2, true)
end
Icons.sun = function(p)
	p:Circle(12, 12, 4.5)
	for i = 0, 7 do
		local a = i * math.pi / 4
		p:Line(12 + math.cos(a) * 7.8, 12 + math.sin(a) * 7.8, 12 + math.cos(a) * 10, 12 + math.sin(a) * 10)
	end
end
Icons.moon = function(p)
	p:Circle(11, 13, 8.5, true)
	p:Mask(16.5, 8.5, 7.5)
end
Icons.fish = function(p)
	p:Rect(2, 7, 15, 10, 99)
	p:Line(16, 12, 21.5, 7)
	p:Line(16, 12, 21.5, 17)
	p:Circle(6.5, 11, 1.3, true)
end
Icons.heart = function(p)
	p:Circle(8.6, 9.6, 4.6, true)
	p:Circle(15.4, 9.6, 4.6, true)
	p:Rect(7, 9.4, 10, 10, 1.5, true, 45)
end
Icons.flag = function(p)
	p:Line(5, 3, 5, 21)
	p:Rect(5, 4, 14, 9, 1.5)
end
Icons.pumpkin = function(p)
	p:Rect(2.5, 7, 19, 14, 99)
	p:Rect(8.5, 7, 7, 14, 99)
	p:Line(12, 7, 13.5, 3.5)
end
Icons.kraken = function(p)
	p:Circle(12, 8.5, 6)
	p:Line(7.5, 14, 4, 21)
	p:Line(10.5, 15, 9.5, 21.5)
	p:Line(13.5, 15, 14.5, 21.5)
	p:Line(16.5, 14, 20, 21)
	p:Circle(10, 8, 1, true)
	p:Circle(14, 8, 1, true)
end
Icons.bike = function(p)
	p:Circle(6, 16, 4)
	p:Circle(18, 16, 4)
	p:Line(6, 16, 10.5, 9.5)
	p:Line(10.5, 9.5, 16.5, 9.5)
	p:Line(16.5, 9.5, 18, 16)
	p:Line(10.5, 9.5, 12.5, 16)
	p:Line(15, 6.5, 18.5, 6.5)
end
Icons.sparkle = function(p)
	p:Line(12, 1, 12, 23, true)
	p:Line(1, 12, 23, 12, true)
	p:Rect(8, 8, 8, 8, 1.5, true, 45)
	p:Circle(12, 12, 2.2, true)
end

local function StrokeFor(size)
	return math.clamp(math.floor(size / 11 * 2 + 0.5) / 2, 1, 3)
end

-- Builds an icon from a built-in name, an asset id ("rbxassetid://..." or a
-- number) or a short text glyph. Returns { Frame, Parts } for recoloring.
local function BuildIcon(name, size, color, maskColor)
	color = color or WHITE
	local frame = Create("Frame", { Size = UDim2.fromOffset(size, size), BackgroundTransparency = 1 })
	local icon = { Frame = frame, Parts = {}, Masks = {}, Color = color }
	local builder = type(name) == "string" and Icons[string.lower(name)]
	if builder then
		builder(setmetatable({
			Frame = frame,
			Parts = icon.Parts,
			Masks = icon.Masks,
			MaskColor = maskColor,
			U = size / 24,
			T = StrokeFor(size),
			Color = color,
		}, Painter))
	elseif type(name) == "number" or (type(name) == "string" and (string.find(name, "rbxasset") or string.match(name, "^%d+$"))) then
		local image = Create("ImageLabel", {
			Size = UDim2.fromScale(1, 1),
			Image = (type(name) == "number" or string.match(name, "^%d+$")) and "rbxassetid://" .. name or name,
			ImageColor3 = color,
			Parent = frame,
		})
		table.insert(icon.Parts, { image, "ImageColor3" })
	else
		local label = Create("TextLabel", {
			Size = UDim2.fromScale(1, 1),
			Text = tostring(name or ""),
			TextScaled = true,
			TextColor3 = color,
			TextXAlignment = Enum.TextXAlignment.Center,
			Weight = "Bold",
			Parent = frame,
		})
		table.insert(icon.Parts, { label, "TextColor3" })
	end
	return icon
end

local function PaintIcon(icon, color, instant)
	icon.Color = color
	for _, part in icon.Parts do
		if instant or not Library.Animations then
			part[1][part[2]] = color
		else
			Tween(part[1], { [part[2]] = color })
		end
	end
end

local function BindIcon(icon, key)
	for _, part in icon.Parts do
		Bind(part[1], { [part[2]] = key })
	end
	return icon
end

Library.Icons = Icons

--------------------------------------------------------------------------------
-- Screen, shared input dispatch and floating layers
--------------------------------------------------------------------------------

local ScreenGui
local Pointer = Vector2.zero -- last pointer position in GUI space
local KeyMap = {} -- input name -> { keybind, ... }
local AllKeybinds = {}
local Drag = { Move = nil, Stop = nil }

-- One InputChanged/InputEnded pair drives every drag (window, sliders, color
-- wheel...) instead of each element owning its own connections.
local function StartDrag(move, stop)
	Drag.Move, Drag.Stop = move, stop
end

local function WindowScale()
	local window = Library.Window
	return window and window.UIScale.Scale or Library.Scale
end

local function ParentGui(gui)
	local protect = (syn and syn.protect_gui) or protectgui
	if protect then
		pcall(protect, gui)
	end
	if gethui then
		pcall(function()
			gui.Parent = gethui()
		end)
	end
	if not gui.Parent then
		pcall(function()
			gui.Parent = CoreGui
		end)
	end
	if not gui.Parent then
		gui.Parent = LocalPlayer:WaitForChild("PlayerGui")
	end
end

local function Ripple(button)
	if not Library.Animations then
		return
	end
	local scale = WindowScale()
	local size = math.max(button.AbsoluteSize.X, button.AbsoluteSize.Y) / scale * 1.5
	local position = (Pointer - button.AbsolutePosition) / scale
	local circle = Create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(position.X, position.Y),
		Size = UDim2.fromOffset(0, 0),
		BackgroundColor3 = Library.Theme.AccentGlow,
		BackgroundTransparency = 0.8,
		Corner = UDim.new(1, 0),
		ZIndex = 3,
		Parent = button,
	})
	Tween(circle, { Size = UDim2.fromOffset(size, size), BackgroundTransparency = 1 }, 0.5)
	task.delay(0.5, circle.Destroy, circle)
end

--------------------------------------------------------------------------------
-- Popups (dropdown lists, color picker, context menus). Only one is open at a
-- time; clicking anywhere outside it closes it.
--------------------------------------------------------------------------------

local Popup = { Active = nil }

function Popup.Close()
	local active = Popup.Active
	if not active then
		return
	end
	Popup.Active = nil
	if active.Connection then
		active.Connection:Disconnect()
	end
	active.Frame.Visible = false
	if active.OnClose then
		active.OnClose()
	end
end

function Popup.Place(active)
	local frame, anchor = active.Frame, active.Anchor
	local ap, as = anchor.AbsolutePosition, anchor.AbsoluteSize
	if active.Clip then
		local cp, cs = active.Clip.AbsolutePosition, active.Clip.AbsoluteSize
		if ap.Y + as.Y < cp.Y or ap.Y > cp.Y + cs.Y then
			Popup.Close()
			return
		end
	end
	local scale = WindowScale()
	local origin = active.Window.Overlay.AbsolutePosition
	local screen = ScreenGui.AbsoluteSize
	local width, height = frame.Size.X.Offset * scale, frame.Size.Y.Offset * scale
	local x = active.Align == "Right" and ap.X + as.X - width or ap.X
	local y = ap.Y + as.Y + 4 * scale
	if y + height > screen.Y - 6 and ap.Y - height - 4 * scale > 6 then
		y = ap.Y - height - 4 * scale
	end
	x = math.clamp(x, 6, math.max(6, screen.X - width - 6))
	frame.Position = UDim2.fromOffset((x - origin.X) / scale, (y - origin.Y) / scale)
end

function Popup.Open(frame, anchor, options)
	Popup.Close()
	local active = {
		Frame = frame,
		Anchor = anchor,
		Window = options.Window,
		Clip = options.Clip,
		Align = options.Align,
		OnClose = options.OnClose,
	}
	Popup.Active = active
	frame.Visible = true
	Popup.Place(active)
	if Popup.Active ~= active then
		return nil
	end
	local target = frame.Position
	frame.Position = target - UDim2.fromOffset(0, 6)
	Tween(frame, { Position = target }, 0.18)
	active.Connection = anchor:GetPropertyChangedSignal("AbsolutePosition"):Connect(function()
		if Popup.Active == active then
			Popup.Place(active)
		end
	end)
	return active
end

function Popup.Resize(frame, width, height)
	frame.Size = UDim2.fromOffset(width, height)
	local active = Popup.Active
	if active and active.Frame == frame then
		Popup.Place(active)
	end
end

function Popup.IsOpen(frame, anchor)
	local active = Popup.Active
	return active ~= nil and active.Frame == frame and (anchor == nil or active.Anchor == anchor)
end

--------------------------------------------------------------------------------
-- Tooltip
--------------------------------------------------------------------------------

local Tooltip = { Token = 0 }

function Tooltip.Build()
	Tooltip.Label = Create("TextLabel", {
		Size = UDim2.new(),
		AutomaticSize = Enum.AutomaticSize.XY,
		BackgroundTransparency = 0,
		Theme = { BackgroundColor3 = "Panel", TextColor3 = "SubText" },
		TextSize = 12,
		TextWrapped = true,
		Visible = false,
		ZIndex = 50,
		Corner = 5,
		Stroke = "Border",
		Padding = { 5, 5, 8, 8 },
		Parent = ScreenGui,
	})
	Create("UISizeConstraint", { MaxSize = Vector2.new(260, math.huge), Parent = Tooltip.Label })
	Tooltip.Scale = Create("UIScale", { Scale = Library.Scale, Parent = Tooltip.Label })
end

function Tooltip.Move(position)
	Tooltip.Label.Position = UDim2.fromOffset(position.X + 14, position.Y + 16)
end

function Tooltip.Show(text)
	Tooltip.Token += 1
	local token = Tooltip.Token
	task.delay(0.35, function()
		if Tooltip.Token ~= token or Library.Unloaded or not Tooltip.Label then
			return
		end
		Tooltip.Label.Text = text
		Tooltip.Move(Pointer)
		Tooltip.Label.Visible = true
	end)
end

function Tooltip.Hide()
	Tooltip.Token += 1
	if Tooltip.Label then
		Tooltip.Label.Visible = false
	end
end

-- `source` is either a string or a table with a `Tooltip` field, so element
-- tooltips can be changed later with :SetTooltip().
local function AttachTooltip(gui, source)
	if source == nil or source == "" then
		return
	end
	gui.MouseEnter:Connect(function()
		local text = type(source) == "table" and source.Tooltip or source
		if type(text) == "string" and text ~= "" then
			Tooltip.Show(text)
		end
	end)
	gui.MouseLeave:Connect(Tooltip.Hide)
end

--------------------------------------------------------------------------------
-- Notifications
--------------------------------------------------------------------------------

local Notifications = { Count = 0 }

local NotifyColors = {
	Success = rgb(72, 199, 116),
	Warning = rgb(240, 180, 60),
	Error = rgb(235, 77, 75),
}
local NotifyIcons = { Info = "info", Success = "check", Warning = "alert", Error = "x" }

function Notifications.Build()
	Notifications.Holder = Create("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(0, 300, 1, -32),
		List = { Padding = 8, VAlign = Enum.VerticalAlignment.Bottom },
		Parent = ScreenGui,
	})
	Notifications.Scale = Create("UIScale", { Scale = Library.Scale, Parent = Notifications.Holder })
	Notifications.Layout = Notifications.Holder:FindFirstChildOfClass("UIListLayout")
	Notifications.Place()
end

function Notifications.Place()
	local left = Library.NotifySide == "Left"
	Notifications.Holder.AnchorPoint = Vector2.new(left and 0 or 1, 1)
	Notifications.Holder.Position = left and UDim2.new(0, 16, 1, -16) or UDim2.new(1, -16, 1, -16)
end

function Library:Notify(options, duration)
	if self.Unloaded then
		return nil
	end
	if type(options) ~= "table" then
		options = { Content = tostring(options), Duration = duration }
	end
	self:_Gui()
	local kind = NotifyIcons[options.Type] and options.Type or "Info"
	local color = NotifyColors[kind] or self.Theme.Accent
	local glow = color:Lerp(WHITE, 0.35)
	local lifetime = math.max(tonumber(options.Duration) or 4, 0.5)
	local side = self.NotifySide == "Left" and -1 or 1
	Notifications.Count += 1

	local holder = Create("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = Notifications.Count,
		Parent = Notifications.Holder,
	})
	-- A CanvasGroup lets the whole card fade as one layer.
	local card = Create("CanvasGroup", {
		Position = UDim2.new(side * 0.4, 0, 0, 0),
		Size = UDim2.new(1, 0, 0, 60),
		Theme = { BackgroundColor3 = "Panel" },
		GroupTransparency = 1,
		Corner = 9,
		Parent = holder,
	})
	local tint = Create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = color, Parent = card })
	Create("UIGradient", {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.8),
			NumberSequenceKeypoint.new(0.45, 0.96),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Parent = tint,
	})
	Create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, -2, 1, -2),
		BackgroundTransparency = 1,
		Corner = 8,
		Stroke = "Border",
		Parent = card,
	})
	local edge = Create("Frame", {
		Position = UDim2.fromOffset(0, 0),
		Size = UDim2.new(0, 3, 1, 0),
		BackgroundColor3 = WHITE,
		Parent = card,
	})
	Create("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(glow, color),
		Parent = edge,
	})

	local badge = Create("Frame", {
		Position = UDim2.fromOffset(15, 14),
		Size = UDim2.fromOffset(32, 32),
		BackgroundColor3 = color,
		BackgroundTransparency = 0.84,
		Corner = UDim.new(1, 0),
		Parent = card,
	})
	Create("UIStroke", { Color = color, Transparency = 0.55, Parent = badge })
	local icon = BuildIcon(NotifyIcons[kind], 15, glow)
	icon.Frame.AnchorPoint = Vector2.new(0.5, 0.5)
	icon.Frame.Position = UDim2.fromScale(0.5, 0.5)
	icon.Frame.Parent = badge

	local text = Create("Frame", {
		Position = UDim2.fromOffset(60, 0),
		Size = UDim2.new(1, -100, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Padding = { 13, 16, 0, 0 },
		List = { Padding = 3 },
		Parent = card,
	})
	Create("TextLabel", {
		Size = UDim2.new(1, 0, 0, 16),
		Text = options.Title or self.Window and self.Window.Title or "Notification",
		TextSize = 13,
		Weight = "Bold",
		Theme = { TextColor3 = "Text" },
		TextTruncate = Enum.TextTruncate.AtEnd,
		LayoutOrder = 1,
		Parent = text,
	})
	if options.Content and options.Content ~= "" then
		Create("TextLabel", {
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Text = options.Content,
			TextSize = 12,
			TextWrapped = true,
			RichText = true,
			Theme = { TextColor3 = "SubText" },
			LayoutOrder = 2,
			Parent = text,
		})
	end
	Create("TextLabel", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -32, 0, 14),
		Size = UDim2.fromOffset(40, 14),
		Text = os.date("%H:%M"),
		TextSize = 10,
		TextXAlignment = Enum.TextXAlignment.Right,
		Theme = { TextColor3 = "DimText" },
		Parent = card,
	})
	local close = Create("TextButton", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -8, 0, 10),
		Size = UDim2.fromOffset(20, 20),
		Theme = { BackgroundColor3 = "Hover" },
		BackgroundTransparency = 1,
		Corner = 5,
		Parent = card,
	})
	local closeIcon = BuildIcon("x", 10, self.Theme.DimText)
	closeIcon.Frame.AnchorPoint = Vector2.new(0.5, 0.5)
	closeIcon.Frame.Position = UDim2.fromScale(0.5, 0.5)
	closeIcon.Frame.Parent = close
	close.MouseEnter:Connect(function()
		Tween(close, { BackgroundTransparency = 0 })
		PaintIcon(closeIcon, Library.Theme.Text)
	end)
	close.MouseLeave:Connect(function()
		Tween(close, { BackgroundTransparency = 1 })
		PaintIcon(closeIcon, Library.Theme.DimText)
	end)

	local track = Create("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 3),
		Theme = { BackgroundColor3 = "Element" },
		Parent = card,
	})
	local fill = Create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE, Parent = track })
	Create("UIGradient", { Color = ColorSequence.new(color, glow), Parent = fill })

	-- The card's height follows its text column explicitly, so the full-size
	-- decoration layers never feed back into an automatic size.
	local function Fit()
		card.Size = UDim2.new(1, 0, 0, math.max(60, text.AbsoluteSize.Y / Notifications.Scale.Scale))
	end
	text:GetPropertyChangedSignal("AbsoluteSize"):Connect(Fit)
	Fit()

	local closed, hovered = false, false
	local function Close()
		if closed then
			return
		end
		closed = true
		Tween(card, { Position = UDim2.new(side * 0.4, 0, 0, 0), GroupTransparency = 1 }, 0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
		task.delay(Library.Animations and 0.3 or 0, function()
			if not holder.Parent then
				return
			end
			local height = holder.AbsoluteSize.Y / Notifications.Scale.Scale
			holder.AutomaticSize = Enum.AutomaticSize.None
			holder.Size = UDim2.new(1, 0, 0, height)
			Tween(holder, { Size = UDim2.new(1, 0, 0, 0) }, 0.22)
			task.delay(Library.Animations and 0.24 or 0, holder.Destroy, holder)
		end)
	end

	close.Activated:Connect(Close)
	-- Hovering pauses the countdown so a notification can be read.
	card.MouseEnter:Connect(function()
		hovered = true
	end)
	card.MouseLeave:Connect(function()
		hovered = false
	end)
	Tween(card, { Position = UDim2.new(), GroupTransparency = 0 }, 0.45)
	task.spawn(function()
		local remaining, last = lifetime, os.clock()
		while not closed and remaining > 0 and not Library.Unloaded do
			task.wait(0.03)
			local now = os.clock()
			if not hovered then
				remaining -= now - last
			end
			last = now
			fill.Size = UDim2.fromScale(math.max(remaining / lifetime, 0), 1)
		end
		Close()
	end)
	return { Close = Close }
end

--------------------------------------------------------------------------------
-- Keybind list overlay
--------------------------------------------------------------------------------

local KeybindList = { Rows = {} }

function KeybindList.Build()
	local frame = Create("Frame", {
		Position = UDim2.new(0, 16, 0.4, 0),
		Size = UDim2.fromOffset(210, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Theme = { BackgroundColor3 = "Panel" },
		Visible = Library.ShowKeybinds,
		Corner = 7,
		Stroke = "Border",
		Parent = ScreenGui,
	})
	KeybindList.Frame = frame
	KeybindList.Scale = Create("UIScale", { Scale = Library.Scale, Parent = frame })

	local header = Create("TextButton", { Size = UDim2.new(1, 0, 0, 30), BackgroundTransparency = 1, Parent = frame })
	local icon = BindIcon(BuildIcon("keyboard", 15), "AccentGlow")
	icon.Frame.AnchorPoint = Vector2.new(0, 0.5)
	icon.Frame.Position = UDim2.new(0, 10, 0.5, 0)
	icon.Frame.Parent = header
	Create("TextLabel", {
		Position = UDim2.fromOffset(32, 0),
		Size = UDim2.new(1, -40, 1, 0),
		Text = "Keybinds",
		TextSize = 12,
		Weight = "Bold",
		Theme = { TextColor3 = "Text" },
		Parent = header,
	})
	local line = Create("Frame", {
		Position = UDim2.new(0, 10, 0, 29),
		Size = UDim2.new(1, -20, 0, 1),
		BackgroundColor3 = WHITE,
		Parent = frame,
	})
	Create("UIGradient", { Theme = { Color = AccentSequence }, Parent = line })

	KeybindList.List = Create("Frame", {
		Position = UDim2.fromOffset(0, 32),
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Padding = { 4, 8, 10, 10 },
		List = { Padding = 2 },
		Parent = frame,
	})
	KeybindList.Empty = Create("TextLabel", {
		Size = UDim2.new(1, 0, 0, 18),
		Text = "No keybinds set",
		TextSize = 11,
		Theme = { TextColor3 = "DimText" },
		LayoutOrder = 100000,
		Parent = KeybindList.List,
	})

	header.InputBegan:Connect(function(input)
		if input.UserInputType ~= MB1 and input.UserInputType ~= TOUCH then
			return
		end
		local start, origin = input.Position, frame.Position
		StartDrag(function(move)
			local delta = move.Position - start
			frame.Position = UDim2.new(origin.X.Scale, origin.X.Offset + delta.X, origin.Y.Scale, origin.Y.Offset + delta.Y)
		end)
	end)
	OnTheme(KeybindList.Refresh)
end

function KeybindList.Row(index)
	local row = KeybindList.Rows[index]
	if row then
		return row
	end
	local frame = Create("Frame", {
		Size = UDim2.new(1, 0, 0, 18),
		BackgroundTransparency = 1,
		LayoutOrder = index,
		Parent = KeybindList.List,
	})
	row = {
		Frame = frame,
		Key = Create("TextLabel", {
			Size = UDim2.new(0, 52, 1, 0),
			TextSize = 11,
			Weight = "Bold",
			TextTruncate = Enum.TextTruncate.AtEnd,
			Parent = frame,
		}),
		Name = Create("TextLabel", {
			Position = UDim2.fromOffset(56, 0),
			Size = UDim2.new(1, -106, 1, 0),
			TextSize = 11,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Parent = frame,
		}),
		Mode = Create("TextLabel", {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.fromScale(1, 0),
			Size = UDim2.new(0, 48, 1, 0),
			TextSize = 10,
			TextXAlignment = Enum.TextXAlignment.Right,
			Parent = frame,
		}),
	}
	KeybindList.Rows[index] = row
	return row
end

function KeybindList.Refresh()
	local frame = KeybindList.Frame
	if not frame or not frame.Visible then
		return
	end
	local theme = Library.Theme
	local count = 0
	for _, keybind in AllKeybinds do
		if not keybind.Internal and not keybind.Destroyed and keybind.Value ~= "None" then
			count += 1
			local row = KeybindList.Row(count)
			local active = keybind:GetState()
			row.Key.Text = "[" .. KeyDisplay(keybind.Value) .. "]"
			row.Name.Text = keybind.Title
			row.Mode.Text = keybind.Mode
			row.Key.TextColor3 = active and theme.AccentGlow or theme.DimText
			row.Name.TextColor3 = active and theme.Text or theme.SubText
			row.Mode.TextColor3 = theme.DimText
			row.Frame.Visible = true
		end
	end
	for index = count + 1, #KeybindList.Rows do
		KeybindList.Rows[index].Frame.Visible = false
	end
	KeybindList.Empty.Visible = count == 0
end

function Library:SetKeybindListVisible(visible)
	self.ShowKeybinds = visible == true
	self:_Gui()
	KeybindList.Frame.Visible = self.ShowKeybinds
	KeybindList.Refresh()
	self:_SaveSettings()
end

--------------------------------------------------------------------------------
-- Global input handling
--------------------------------------------------------------------------------

local function OnInputBegan(input)
	local kind = input.UserInputType
	if kind == MB1 or kind == MB2 or kind == TOUCH then
		Pointer = Vector2.new(input.Position.X, input.Position.Y)
		local active = Popup.Active
		if active and not Util.Inside(active.Frame, Pointer) and not Util.Inside(active.Anchor, Pointer) then
			Popup.Close()
		end
	end

	local binding = Library._binding
	if binding then
		binding:_Capture(input)
		return
	end
	if UserInputService:GetFocusedTextBox() then
		return
	end

	local name = InputName(input)
	if not name then
		return
	end
	if name == Library.MenuKey and Library.Window and os.clock() - (Library._lastMenuToggle or 0) > 0.05 then
		Library._lastMenuToggle = os.clock()
		Library.Window:Toggle()
	end
	local list = KeyMap[name]
	if list then
		for _, keybind in table.clone(list) do
			keybind:_Press()
		end
	end
end

local function OnInputChanged(input)
	local kind = input.UserInputType
	if kind == MOUSE_MOVE or kind == TOUCH then
		Pointer = Vector2.new(input.Position.X, input.Position.Y)
		if Drag.Move then
			Drag.Move(input)
		end
		if Tooltip.Label and Tooltip.Label.Visible then
			Tooltip.Move(Pointer)
		end
		if Library._pointerHook then
			Library._pointerHook(Pointer)
		end
	end
end

local function OnInputEnded(input)
	local kind = input.UserInputType
	if (kind == MB1 or kind == TOUCH) and (Drag.Move or Drag.Stop) then
		local stop = Drag.Stop
		Drag.Move, Drag.Stop = nil, nil
		if stop then
			stop(input)
		end
	end
	if Library._binding then
		return
	end
	local name = InputName(input)
	local list = name and KeyMap[name]
	if list then
		for _, keybind in table.clone(list) do
			keybind:_Release()
		end
	end
end

function Library:_Gui()
	if ScreenGui then
		return ScreenGui
	end
	ScreenGui = Create("ScreenGui", {
		Name = string.sub(HttpService:GenerateGUID(false), 1, 8),
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		ResetOnSpawn = false,
		IgnoreGuiInset = false,
		DisplayOrder = 10000,
	})
	ParentGui(ScreenGui)
	self.ScreenGui = ScreenGui
	Tooltip.Build()
	Notifications.Build()
	KeybindList.Build()
	Connect(UserInputService.InputBegan, OnInputBegan)
	Connect(UserInputService.InputChanged, OnInputChanged)
	Connect(UserInputService.InputEnded, OnInputEnded)
	return ScreenGui
end

--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- Mascot: an original chibi girl drawn from rounded frames. She peeks over an
-- edge: her head lives in one layer (drawn *behind* whatever covers the area
-- under the edge) and her hands in another layer drawn *in front* of it.
--------------------------------------------------------------------------------

local MascotColors = {
	Hair = rgb(34, 31, 43),
	HairShine = rgb(92, 86, 118),
	Skin = rgb(255, 231, 218),
	Line = rgb(66, 44, 50),
	Iris = rgb(56, 172, 146),
	IrisDark = rgb(22, 94, 82),
	IrisLight = rgb(150, 232, 210),
	Blush = rgb(255, 132, 154),
	BlushLine = rgb(236, 92, 118),
	Mouth = rgb(176, 66, 82),
	Tongue = rgb(255, 150, 160),
	Sweat = rgb(160, 214, 255),
	Ribbon = rgb(255, 108, 146),
	RibbonDark = rgb(214, 70, 112),
}

-- Width/height of the drawing; y = 112 is the edge she holds on to.
local STAGE_W, STAGE_H = 124, 112

local function Blob(parent, x, y, w, h, color, extra)
	local blob = Create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(w, h),
		BackgroundColor3 = color,
		Corner = extra and extra.Radius and UDim.new(0, extra.Radius) or UDim.new(1, 0),
		Parent = parent,
	})
	if extra then
		blob.Rotation = extra.Rotation or 0
		blob.BackgroundTransparency = extra.Transparency or 0
		if extra.Outline then
			Create("UIStroke", {
				Color = MascotColors.Line,
				Thickness = extra.Outline,
				Transparency = extra.OutlineTransparency or 0.4,
				Parent = blob,
			})
		end
	end
	return blob
end

local function Layer(parent)
	return Create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = parent })
end

local Mascot = {}
Mascot.__index = Mascot

-- headParent/handsParent: containers for the two layers. position: bottom
-- centre of the drawing (the edge), in the parents' coordinate space.
local function BuildMascot(headParent, handsParent, position, scale, images)
	local mascot = setmetatable({ Mood = "Idle", Hidden = false, Tweens = {} }, Mascot)
	local c = MascotColors

	local function Stage(parent)
		local stage = Create("Frame", {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = position,
			Size = UDim2.fromOffset(STAGE_W, STAGE_H),
			BackgroundTransparency = 1,
			Parent = parent,
		})
		Create("UIScale", { Scale = scale or 1, Parent = stage })
		return stage
	end
	mascot.Stage = Stage(headParent)
	mascot.HandStage = Stage(handsParent)
	-- Head: moves when ducking. Body: idle breathing / hops, inside Head.
	mascot.Head = Layer(mascot.Stage)
	mascot.Body = Layer(mascot.Head)
	mascot.Hands = Layer(mascot.HandStage)
	local body = mascot.Body

	if images and images.Idle then
		-- Custom artwork: swap images per mood instead of drawing a face.
		mascot.Images = images
		mascot.Image = Create("ImageLabel", {
			Size = UDim2.fromScale(1, 1),
			Image = images.Idle,
			ScaleType = Enum.ScaleType.Fit,
			Parent = body,
		})
	else
		-- Hair behind the face
		Blob(body, 62, 54, 102, 90, c.Hair)
		Blob(body, 18, 90, 28, 72, c.Hair, { Rotation = 8 })
		Blob(body, 106, 90, 28, 72, c.Hair, { Rotation = -8 })
		-- Face
		Blob(body, 62, 85, 76, 66, c.Skin, { Radius = 30, Outline = 1.2, OutlineTransparency = 0.55 })
		-- Fringe: a band of hair plus pointed strands over the forehead
		Blob(body, 62, 44, 90, 28, c.Hair)
		for _, strand in { { 30, 56, 14 }, { 42, 59, 15 }, { 55, 61, 13 }, { 69, 61, 13 }, { 82, 59, 15 }, { 94, 56, 14 } } do
			Blob(body, strand[1], strand[2], strand[3], strand[3], c.Hair, { Radius = 3, Rotation = 45 })
		end
		Blob(body, 26, 84, 10, 50, c.Hair, { Rotation = 5 })
		Blob(body, 98, 84, 10, 50, c.Hair, { Rotation = -5 })
		-- Shine and a stray strand on top
		Blob(body, 44, 25, 28, 5, c.HairShine, { Rotation = -16, Transparency = 0.25 })
		Blob(body, 69, 22, 10, 4, c.HairShine, { Rotation = 12, Transparency = 0.45 })
		Blob(body, 68, 6, 4, 16, c.Hair, { Rotation = 22 })
		Blob(body, 73, 0, 4, 10, c.Hair, { Rotation = 70 })
		-- Ribbon
		Blob(body, 99, 30, 16, 10, c.Ribbon, { Rotation = -28 })
		Blob(body, 110, 39, 16, 10, c.Ribbon, { Rotation = 38 })
		Blob(body, 105, 35, 7, 7, c.RibbonDark)

		-- Eyes: open (with a gaze layer that follows the cursor), closed,
		-- happy (^ ^) and squeezed (> <)
		mascot.EyesOpen = Layer(body)
		mascot.Gaze = {}
		for index, x in { 45, 79 } do
			local side = index == 1 and -1 or 1
			Blob(mascot.EyesOpen, x, 79, 19, 23, WHITE, { Outline = 1, OutlineTransparency = 0.35 })
			local look = Layer(mascot.EyesOpen)
			table.insert(mascot.Gaze, look)
			local iris = Blob(look, x, 80.5, 14, 18, WHITE)
			Create("UIGradient", {
				Rotation = 90,
				Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, c.IrisDark),
					ColorSequenceKeypoint.new(0.55, c.Iris),
					ColorSequenceKeypoint.new(1, c.IrisLight),
				}),
				Parent = iris,
			})
			Blob(look, x, 81.5, 6, 8, c.IrisDark)
			Blob(look, x - 3.5, 75, 5.5, 5.5, WHITE)
			Blob(look, x + 3.5, 85, 2.5, 2.5, WHITE)
			Blob(mascot.EyesOpen, x, 68.5, 23, 3.5, c.Line, { Rotation = side * 7 })
			Blob(mascot.EyesOpen, x + side * 12, 70.5, 7, 3, c.Line, { Rotation = side * 35 })
		end
		mascot.EyesClosed = Layer(body)
		mascot.EyesHappy = Layer(body)
		mascot.EyesSqueeze = Layer(body)
		for index, x in { 45, 79 } do
			Blob(mascot.EyesClosed, x, 81, 20, 3.5, c.Line)
			Blob(mascot.EyesHappy, x - 5, 81, 12, 3.5, c.Line, { Rotation = -35 })
			Blob(mascot.EyesHappy, x + 5, 81, 12, 3.5, c.Line, { Rotation = 35 })
			local point = index == 1 and 1 or -1
			Blob(mascot.EyesSqueeze, x - point, 77, 13, 3.5, c.Line, { Rotation = point * 28 })
			Blob(mascot.EyesSqueeze, x - point, 84, 13, 3.5, c.Line, { Rotation = -point * 28 })
		end

		-- Blush (cheeks plus little "///" marks)
		mascot.Blush = Layer(body)
		mascot.BlushParts = {}
		for _, x in { 37, 87 } do
			table.insert(mascot.BlushParts, { Blob(mascot.Blush, x, 93, 15, 7, c.Blush), 0.45 })
			for offset = -3.5, 3.5, 3.5 do
				table.insert(mascot.BlushParts, { Blob(mascot.Blush, x + offset, 92.5, 1.7, 7, c.BlushLine, { Rotation = 25 }), 0.2 })
			end
		end

		-- Mouths
		mascot.Mouths = {
			Small = Layer(body),
			Smile = Layer(body),
			Wavy = Layer(body),
			Open = Layer(body),
		}
		Blob(mascot.Mouths.Small, 62, 97, 7, 4, c.Mouth)
		Blob(mascot.Mouths.Smile, 62, 96.5, 13, 8, c.Mouth)
		Blob(mascot.Mouths.Smile, 62, 99, 7, 3.5, c.Tongue)
		for step, rotation in { 25, -25, 25 } do
			Blob(mascot.Mouths.Wavy, 55.5 + step * 3.5, 97, 6, 2, c.Line, { Rotation = rotation })
		end
		Blob(mascot.Mouths.Open, 62, 97, 7, 9, c.Mouth)

		mascot.Sweat = Layer(body)
		Blob(mascot.Sweat, 100, 64, 7, 10, c.Sweat, { Rotation = -15 })
		Blob(mascot.Sweat, 99, 66, 2.5, 3.5, WHITE, { Transparency = 0.2 })

		-- Hands gripping the edge (drawn in front of whatever hides her body)
		mascot.HandParts = {}
		for _, x in { 40, 84 } do
			local hand = Blob(mascot.Hands, x, 110, 22, 13, c.Skin, { Outline = 1.2, OutlineTransparency = 0.3 })
			table.insert(mascot.HandParts, hand)
			for offset = -5, 5, 5 do
				table.insert(mascot.HandParts, Blob(mascot.Hands, x + offset, 106.5, 1.5, 5, c.Line, { Transparency = 0.45 }))
			end
		end
	end

	-- Clickable area over her head
	mascot.Hit = Create("TextButton", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromOffset(62, 0),
		Size = UDim2.fromOffset(100, 112),
		BackgroundTransparency = 1,
		ZIndex = 5,
		Parent = mascot.Stage,
	})

	mascot:SetMood("Idle", true)
	return mascot
end

local MascotMoods = {
	-- eyes, mouth, blush, sweat
	Idle = { "Open", "Small", false, false },
	Happy = { "Happy", "Smile", 0.5, false },
	Blush = { "Open", "Wavy", 1, false },
	Flustered = { "Squeeze", "Wavy", 1, true },
	Surprised = { "Open", "Open", false, false },
}

function Mascot:SetMood(mood, instant)
	local spec = MascotMoods[mood]
	if not spec then
		return
	end
	self.Mood = mood
	if self.Images then
		self.Image.Image = self.Images[mood] or self.Images.Idle
		return
	end
	self.EyesOpen.Visible = spec[1] == "Open"
	self.EyesClosed.Visible = false
	self.EyesHappy.Visible = spec[1] == "Happy"
	self.EyesSqueeze.Visible = spec[1] == "Squeeze"
	for name, layer in self.Mouths do
		layer.Visible = name == spec[2]
	end
	self.Sweat.Visible = spec[4]
	local animate = Animate(instant)
	for _, part in self.BlushParts do
		local strength = spec[3] or 0
		animate(part[1], { BackgroundTransparency = 1 - (1 - part[2]) * strength }, 0.3)
	end
end

function Mascot:Blink()
	if self.Images or self.Hidden or not self.EyesOpen.Visible then
		return
	end
	self.EyesOpen.Visible = false
	self.EyesClosed.Visible = true
	task.delay(0.11, function()
		if self.Mood and MascotMoods[self.Mood][1] == "Open" then
			self.EyesClosed.Visible = false
			self.EyesOpen.Visible = true
		end
	end)
end

-- Points her pupils at a screen position (pupils move at most ~2.5px).
function Mascot:Look(target)
	if not self.Gaze then
		return
	end
	local stage = self.Stage
	local scale = stage.AbsoluteSize.X / STAGE_W
	local eyes = stage.AbsolutePosition + Vector2.new(62, 80) * scale
	local delta = target - eyes
	local distance = delta.Magnitude
	local offset = distance > 1 and delta / distance * math.min(distance / 90, 1) or Vector2.zero
	for _, look in self.Gaze do
		look.Position = UDim2.fromOffset(offset.X * 2.6, offset.Y * 2)
	end
end

function Mascot:_Loop(instance, info, props)
	local tween = TweenService:Create(instance, info, props)
	table.insert(self.Tweens, tween)
	if not self.Paused then
		tween:Play()
	end
	return tween
end

function Mascot:SetPaused(paused)
	self.Paused = paused
	for _, tween in self.Tweens do
		if paused then
			tween:Pause()
		else
			tween:Play()
		end
	end
end

function Mascot:StartIdle()
	self:_Loop(self.Body, TweenInfo.new(1.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
		Position = UDim2.fromOffset(0, 1.5),
	})
end

function Mascot:Hop()
	Tween(self.Head, { Position = UDim2.fromOffset(0, -5) }, 0.12, Enum.EasingStyle.Quad)
	task.delay(Library.Animations and 0.12 or 0, function()
		if not self.Hidden then
			Tween(self.Head, { Position = UDim2.new() }, 0.25, Enum.EasingStyle.Bounce)
		end
	end)
end

local function FadeHands(mascot, visible)
	for _, part in mascot.HandParts or {} do
		local stroke = part:FindFirstChildOfClass("UIStroke")
		local base = part.Size.X.Offset < 3 and 0.45 or 0
		Tween(part, { BackgroundTransparency = visible and base or 1 }, 0.2)
		if stroke then
			Tween(stroke, { Transparency = visible and 0.3 or 1 }, 0.2)
		end
	end
	Tween(mascot.Hands, { Position = UDim2.fromOffset(0, visible and 0 or 6) }, 0.25)
end

-- Ducks below the edge; Peek brings her back.
function Mascot:Hide()
	self.Hidden = true
	FadeHands(self, false)
	Tween(self.Head, { Position = UDim2.fromOffset(0, 86) }, 0.4, Enum.EasingStyle.Back, Enum.EasingDirection.In)
end

function Mascot:Peek()
	self.Hidden = false
	FadeHands(self, true)
	Tween(self.Head, { Position = UDim2.new() }, 0.55, Enum.EasingStyle.Back)
end

--------------------------------------------------------------------------------
-- Window
--------------------------------------------------------------------------------

local Window = {}
Window.__index = Window
local Tab = {}
Tab.__index = Tab
local SubTab = {}
SubTab.__index = SubTab
local Section = {}
Section.__index = Section

local HEADER_H = 98
local MASCOT_RIGHT = 300 -- distance of the mascot's centre from the window's right edge
local BUBBLE_TEXT = rgb(28, 30, 36)

local MascotLines = {
	Greeting = {
		"Y-you're back! N-not that I was waiting...",
		"Oh. It's you again... h-hi.",
		"W-welcome back! I kept the farm warm.",
		"You took forever... I mean, hello!",
	},
	Click = {
		"H-hey! Don't poke me!",
		"It's not like I enjoy it...",
		"S-stop staring at me...",
		"I-I'm not blushing! It's the lighting!",
		"B-baka! I'm busy farming!",
		"...again? Fine. Just once more.",
		"Hmph. Did you need something?",
	},
	Pat = {
		"...you can hold it. Just this once.",
		"Mmh... okay, that's nice.",
		"D-don't tell anyone about this.",
	},
	Spam = { "S-stop it!", "W-what is wrong with you?!" },
	Hide = { "That's it, I'm hiding!", "I'm leaving! Hmph!" },
	Return = { "...is it safe now?", "Okay... I'm back. No poking." },
	Idle = {
		"*yawn*... still farming?",
		"You've been at this a while...",
		"I-I'll keep watch. Not for you.",
		"Don't forget to save your config!",
	},
	React = {
		"%s? Good choice.",
		"Ooh, %s... fine, I'll watch.",
		"%s on! Don't overdo it.",
	},
}

local function Pick(list)
	return list[math.random(1, #list)]
end

local function ReadSize(value, fallback)
	if typeof(value) == "UDim2" then
		return Vector2.new(value.X.Offset, value.Y.Offset)
	elseif typeof(value) == "Vector2" then
		return value
	end
	return fallback
end

local function KeyName(value)
	if typeof(value) == "EnumItem" then
		return value.Name
	elseif type(value) == "string" and value ~= "" then
		return value
	end
	return "None"
end

local function Clock(seconds)
	seconds = math.floor(seconds)
	return string.format("%02d:%02d:%02d", math.floor(seconds / 3600), math.floor(seconds / 60) % 60, seconds % 60)
end

local function CharacterState()
	local character = LocalPlayer and LocalPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return "Loading"
	end
	return humanoid.Health > 0 and "Ready" or "Dead"
end

local function Hex(color)
	return "#" .. Util.ToHex(color)
end

-- Inline icon helper: builds, binds and places an icon in one call.
local function PlaceIcon(name, size, key, parent, anchor, position)
	local icon = BuildIcon(name, size)
	if key then
		BindIcon(icon, key)
	end
	icon.Frame.AnchorPoint = anchor or Vector2.new(0.5, 0.5)
	icon.Frame.Position = position or UDim2.fromScale(0.5, 0.5)
	icon.Frame.Parent = parent
	return icon
end

function Library:CreateWindow(options)
	options = options or {}
	local title = options.Title

	-- Running the script again replaces every older copy (MyUI or MyUI2)
	-- instead of stacking UIs that all listen for the menu key.
	local env = (getgenv and getgenv()) or _G
	local stale = {}
	for key, previous in env do
		if type(key) == "string" and string.sub(key, 1, 6) == "__MyUI" and previous ~= self then
			stale[key] = previous
		end
	end
	for key, previous in stale do
		env[key] = nil
		if type(previous) == "table" and type(previous.Unload) == "function" then
			pcall(previous.Unload, previous)
		end
	end
	env.__MyUI2 = self
	self:OnUnload(function()
		if env.__MyUI2 == self then
			env.__MyUI2 = nil
		end
	end)

	local folderName = string.gsub(Util.Sanitize(title or "Hub"), "%s+", "_")
	self.Folder = options.ConfigFolder or options.Folder or ("MyUI2/" .. (folderName ~= "" and folderName or "Hub"))
	File.MakeFolder(self.Folder .. "/configs")

	if options.ToggleKey then
		self.MenuKey = KeyName(options.ToggleKey)
	end
	if options.Theme == "Light" or options.Theme == "Dark" then
		self.ThemeName = options.Theme
	end
	self.AutoSave = options.AutoSave == true
	local mascotOptions = type(options.Mascot) == "table" and options.Mascot or {}
	if options.Mascot == false then
		self.MascotEnabled = false
	end
	self:_LoadSettings()
	for key, value in Palettes[self.ThemeName] do
		self.Theme[key] = value
	end

	local size = ReadSize(options.Size, Vector2.new(900, 560))
	if not self._savedScale then
		local camera = workspace.CurrentCamera
		local viewport = camera and camera.ViewportSize or Vector2.new(1920, 1080)
		local fit = viewport.X > 100 and math.min((viewport.X - 40) / size.X, (viewport.Y - 110) / size.Y) or 1
		self.Scale = options.Scale or math.clamp(fit, 0.5, 1)
	end

	local gui = self:_Gui()
	Tooltip.Scale.Scale = self.Scale
	Notifications.Scale.Scale = self.Scale
	KeybindList.Scale.Scale = self.Scale
	Notifications.Place()
	KeybindList.Frame.Visible = self.ShowKeybinds
	self:ApplyTheme()

	local window = setmetatable({
		Title = title or "",
		Tabs = {},
		Query = "",
		Visible = true,
		Columns = math.clamp(tonumber(options.Columns) or 3, 1, 4),
		MinSize = ReadSize(options.MinSize, Vector2.new(760, 460)),
		DefaultSize = size,
		Started = os.clock(),
		_sayToken = 0,
	}, Window)
	self.Window = window

	local root = Create("Frame", {
		Name = "Window",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(size.X, size.Y),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	window.Root = root
	window.UIScale = Create("UIScale", { Scale = self.Scale, Parent = root })

	local saved = self._savedWindow
	if type(saved) == "table" then
		local camera = workspace.CurrentCamera
		local viewport = camera and camera.ViewportSize or Vector2.new(1920, 1080)
		local width, height, x, y = tonumber(saved.W), tonumber(saved.H), tonumber(saved.X), tonumber(saved.Y)
		if width and height then
			root.Size = UDim2.fromOffset(math.max(width, window.MinSize.X), math.max(height, window.MinSize.Y))
		end
		if x and y and math.abs(x) < viewport.X / 2 - 40 and math.abs(y) < viewport.Y / 2 - 40 then
			root.Position = UDim2.new(0.5, x, 0.5, y)
		end
	end

	for index, transparency in { 0.78, 0.88, 0.94 } do
		Create("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0.5, 6),
			Size = UDim2.new(1, index * 10, 1, index * 10),
			BackgroundColor3 = BLACK,
			BackgroundTransparency = transparency,
			Corner = 24 + index * 5,
			Parent = root,
		})
	end

	local main = Create("Frame", {
		Name = "Main",
		Size = UDim2.fromScale(1, 1),
		Theme = { BackgroundColor3 = "Header" },
		Corner = 22,
		Stroke = { Color = "Border", Transparency = 0.2 },
		Parent = root,
	})
	window.Main = main

	----------------------------------------------------------------------------
	-- Header band (ZIndex 1): title, author line and the tab strip
	----------------------------------------------------------------------------

	local header = Create("Frame", { Size = UDim2.new(1, 0, 0, HEADER_H), BackgroundTransparency = 1, ZIndex = 1, Parent = main })
	local sheen = Create("Frame", {
		Size = UDim2.new(1, 0, 0, 56),
		BackgroundColor3 = WHITE,
		Corner = 22,
		Parent = header,
	})
	Create("UIGradient", {
		Rotation = 90,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.86),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Parent = sheen,
	})
	local dragArea = Create("TextButton", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = header })

	window._title = Create("TextLabel", {
		Position = UDim2.fromOffset(24, 13),
		Size = UDim2.new(0.5, -60, 0, 24),
		Text = title or "",
		TextSize = 19,
		Weight = "Bold",
		TextTruncate = Enum.TextTruncate.AtEnd,
		Theme = { TextColor3 = "HeaderText" },
		Parent = header,
	})
	if not title then
		-- No title given: show the current game's name.
		task.spawn(function()
			local ok, info = pcall(function()
				return GetService("MarketplaceService"):GetProductInfo(game.PlaceId)
			end)
			if ok and type(info) == "table" and type(info.Name) == "string" and window._title.Text == "" then
				window:SetTitle(info.Name)
			end
		end)
	end

	local byline = Create("Frame", {
		Position = UDim2.fromOffset(24, 39),
		Size = UDim2.new(0, 0, 0, 16),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		List = { Horizontal = true, Padding = 5, VAlign = Enum.VerticalAlignment.Center },
		Parent = header,
	})
	local sparkle = PlaceIcon(options.Icon or "sparkle", 12, "HeaderText", byline)
	sparkle.Frame.LayoutOrder = 1
	window._author = Create("TextLabel", {
		Size = UDim2.fromOffset(0, 16),
		AutomaticSize = Enum.AutomaticSize.X,
		Text = "by " .. tostring(options.Author or "MyUI") .. " ·",
		TextSize = 12,
		Weight = "SemiBold",
		TextTransparency = 0.08,
		Theme = { TextColor3 = "HeaderText" },
		LayoutOrder = 2,
		Parent = byline,
	})
	local badge = Create("TextLabel", {
		Size = UDim2.fromOffset(0, 15),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 0.74,
		Text = tostring(options.Badge or "DEV"),
		TextSize = 10,
		Weight = "Bold",
		TextXAlignment = Enum.TextXAlignment.Center,
		Theme = { BackgroundColor3 = "HeaderText", TextColor3 = "HeaderText" },
		Corner = 4,
		Padding = { 0, 0, 5, 5 },
		LayoutOrder = 3,
		Visible = options.Badge ~= false,
		Parent = byline,
	})
	window._badge = badge
	window._version = Create("TextLabel", {
		Size = UDim2.fromOffset(0, 16),
		AutomaticSize = Enum.AutomaticSize.X,
		Text = tostring(options.Version or ("v" .. self.Version)),
		TextSize = 12,
		Weight = "SemiBold",
		Theme = { TextColor3 = "HeaderText" },
		LayoutOrder = 4,
		Parent = byline,
	})

	-- Tab strip with a sliding "folder tab" highlight whose concave ears blend
	-- into the body below.
	-- Inset so the first tab's concave ear stays inside the window edge.
	local strip = Create("Frame", {
		Position = UDim2.fromOffset(26, HEADER_H - 36),
		Size = UDim2.new(1, -52, 0, 36),
		BackgroundTransparency = 1,
		Parent = header,
	})
	local highlight = Create("Frame", {
		Size = UDim2.fromOffset(0, 38),
		Theme = { BackgroundColor3 = "Background" },
		Corner = 12,
		Visible = false,
		Parent = strip,
	})
	Create("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 14),
		Theme = { BackgroundColor3 = "Background" },
		Parent = highlight,
	})
	for _, side in { -1, 1 } do
		local x = side < 0 and UDim.new(0, -12) or UDim.new(1, 0)
		Create("Frame", {
			Position = UDim2.new(x, UDim.new(0, 24)),
			Size = UDim2.fromOffset(12, 14),
			Theme = { BackgroundColor3 = "Background" },
			Parent = highlight,
		})
		Create("Frame", {
			Position = UDim2.new(side < 0 and UDim.new(0, -24) or UDim.new(1, 0), UDim.new(0, 12)),
			Size = UDim2.fromOffset(24, 24),
			Theme = { BackgroundColor3 = "Header" },
			Corner = UDim.new(1, 0),
			ZIndex = 2,
			Parent = highlight,
		})
	end
	window._highlight = highlight
	window.TabList = Create("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 3,
		List = { Horizontal = true, Padding = 2 },
		Parent = strip,
	})
	window._strip = strip

	----------------------------------------------------------------------------
	-- Mascot (ZIndex 2, drawn behind the body) and her hands (ZIndex 5)
	----------------------------------------------------------------------------

	local mascotLayer = Create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 2, Parent = main })
	local handsLayer = Create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 5, Parent = main })
	window._mascotLayers = { mascotLayer, handsLayer }
	if options.Mascot ~= false then
		window.Mascot = BuildMascot(mascotLayer, handsLayer, UDim2.new(1, -MASCOT_RIGHT, 0, HEADER_H), 1.12, mascotOptions.Images)
		window.Mascot:StartIdle()
		window.Mascot:SetPaused(true)
		mascotLayer.Visible = self.MascotEnabled
		handsLayer.Visible = self.MascotEnabled
	end
	for kind, list in mascotOptions.Lines or {} do
		if type(list) == "table" and #list > 0 then
			MascotLines[kind] = list
		end
	end

	----------------------------------------------------------------------------
	-- Body (ZIndex 3 cover + ZIndex 4 content)
	----------------------------------------------------------------------------

	local cover = Create("Frame", {
		Position = UDim2.fromOffset(0, HEADER_H),
		Size = UDim2.new(1, 0, 1, -HEADER_H),
		Theme = { BackgroundColor3 = "Background" },
		Corner = 22,
		ZIndex = 3,
		Parent = main,
	})
	Create("Frame", { Size = UDim2.new(1, 0, 0, 24), Theme = { BackgroundColor3 = "Background" }, Parent = cover })

	local body = Create("Frame", {
		Position = UDim2.fromOffset(0, HEADER_H),
		Size = UDim2.new(1, 0, 1, -HEADER_H),
		BackgroundTransparency = 1,
		ZIndex = 4,
		Parent = main,
	})
	window.Content = body

	-- Toolbar right side: expanding search + live stats
	local toolbar = Create("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -20, 0, 14),
		Size = UDim2.fromOffset(0, 30),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		ZIndex = 2,
		List = {
			Horizontal = true,
			Padding = 14,
			HAlign = Enum.HorizontalAlignment.Right,
			VAlign = Enum.VerticalAlignment.Center,
		},
		Parent = body,
	})
	window._toolbar = toolbar
	local search = Create("TextButton", {
		Size = UDim2.fromOffset(30, 30),
		Theme = { BackgroundColor3 = "Pill" },
		ClipsDescendants = true,
		LayoutOrder = 1,
		Corner = UDim.new(1, 0),
		Stroke = { Color = "Border", Transparency = 0.4 },
		Parent = toolbar,
	})
	PlaceIcon("search", 13, "SubText", search, Vector2.new(0.5, 0.5), UDim2.fromOffset(15, 15))
	local searchBox = Create("TextBox", {
		Position = UDim2.fromOffset(30, 0),
		Size = UDim2.new(1, -40, 1, 0),
		PlaceholderText = "Search...",
		TextSize = 12,
		Visible = false,
		Theme = { TextColor3 = "Text", PlaceholderColor3 = "DimText" },
		Parent = search,
	})
	window.SearchBox = searchBox
	local function Expand(open)
		window._searchOpen = open
		searchBox.Visible = true
		Tween(search, { Size = UDim2.fromOffset(open and 200 or 30, 30) }, 0.3)
		if open then
			searchBox:CaptureFocus()
		else
			task.delay(Library.Animations and 0.3 or 0, function()
				if not window._searchOpen then
					searchBox.Visible = false
				end
			end)
		end
	end
	search.Activated:Connect(function()
		if not window._searchOpen then
			Expand(true)
		end
	end)
	searchBox.FocusLost:Connect(function()
		if searchBox.Text == "" then
			Expand(false)
		end
	end)
	searchBox:GetPropertyChangedSignal("Text"):Connect(function()
		local query = Util.Lower(Util.Trim(searchBox.Text))
		if query ~= window.Query then
			window.Query = query
			if window.CurrentTab then
				window.CurrentTab:ApplyFilter()
			end
		end
	end)
	local stats = Create("TextLabel", {
		Size = UDim2.fromOffset(0, 30),
		AutomaticSize = Enum.AutomaticSize.X,
		TextSize = 12,
		Weight = "Mono",
		RichText = true,
		Theme = { TextColor3 = "DimText" },
		LayoutOrder = 2,
		Parent = toolbar,
	})
	local function RefreshStats()
		local theme = Library.Theme
		local value = '<font color="' .. Hex(theme.Text) .. '"><b>%s</b></font>'
		local players = #Players:GetPlayers() .. "/" .. tostring(Players.MaxPlayers)
		stats.Text = "Server " .. string.format(value, players)
			.. "   Session " .. string.format(value, Clock(os.clock() - window.Started))
			.. "   Char " .. string.format(value, CharacterState())
	end
	RefreshStats()
	OnTheme(RefreshStats)
	toolbar:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		for _, tab in window.Tabs do
			tab:_FitPills()
		end
	end)

	local grip = Create("TextButton", {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -9, 1, -9),
		Size = UDim2.fromOffset(20, 20),
		BackgroundTransparency = 1,
		ZIndex = 6,
		Parent = main,
	})
	PlaceIcon("grip", 18, "DimText", grip)
	AttachTooltip(grip, "Drag to resize - double-click to reset")

	----------------------------------------------------------------------------
	-- Header controls (ZIndex 6): speech bubble, theme, menu key, close
	----------------------------------------------------------------------------

	local controls = Create("Frame", { Size = UDim2.new(1, 0, 0, HEADER_H), BackgroundTransparency = 1, ZIndex = 6, Parent = main })

	local bubble = Create("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -(MASCOT_RIGHT + 62), 0, 36),
		Size = UDim2.fromOffset(0, 30),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = WHITE,
		BackgroundTransparency = 1,
		Corner = UDim.new(1, 0),
		Padding = { 0, 0, 14, 16 },
		Parent = controls,
	})
	local bubbleScale = Create("UIScale", { Parent = bubble })
	local tail = Create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, 13, 0.5, 0),
		Size = UDim2.fromOffset(10, 10),
		Rotation = 45,
		BackgroundColor3 = WHITE,
		BackgroundTransparency = 1,
		Corner = 2,
		Parent = bubble,
	})
	local bubbleText = Create("TextLabel", {
		Size = UDim2.fromOffset(0, 30),
		AutomaticSize = Enum.AutomaticSize.X,
		TextSize = 12,
		Weight = "Bold",
		TextColor3 = BUBBLE_TEXT,
		TextTransparency = 1,
		MaxVisibleGraphemes = 0,
		Parent = bubble,
	})
	window._bubble = { Frame = bubble, Tail = tail, Text = bubbleText, Scale = bubbleScale }

	local buttons = Create("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -18, 0, 35),
		Size = UDim2.fromOffset(0, 34),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		List = {
			Horizontal = true,
			Padding = 8,
			HAlign = Enum.HorizontalAlignment.Right,
			VAlign = Enum.VerticalAlignment.Center,
		},
		Parent = controls,
	})
	local themeButton = Create("TextButton", {
		Size = UDim2.fromOffset(34, 34),
		Theme = { BackgroundColor3 = "HeaderDark" },
		LayoutOrder = 1,
		Corner = UDim.new(1, 0),
		Parent = buttons,
	})
	local moon = PlaceIcon("moon", 16, "HeaderText", themeButton)
	for _, mask in moon.Masks do
		Bind(mask, { BackgroundColor3 = "HeaderDark" })
	end
	local sun = PlaceIcon("sun", 17, "HeaderText", themeButton)
	local function PaintThemeButton(spin)
		moon.Frame.Visible = Library.ThemeName == "Dark"
		sun.Frame.Visible = Library.ThemeName == "Light"
		if spin then
			local icon = moon.Frame.Visible and moon.Frame or sun.Frame
			icon.Rotation = -90
			Tween(icon, { Rotation = 0 }, 0.45, Enum.EasingStyle.Back)
		end
	end
	PaintThemeButton()
	window._paintThemeButton = PaintThemeButton
	themeButton.Activated:Connect(function()
		Library:ToggleTheme()
	end)
	AttachTooltip(themeButton, "Switch between dark and light")

	local keyPill = Create("TextButton", {
		Size = UDim2.fromOffset(0, 30),
		AutomaticSize = Enum.AutomaticSize.X,
		Theme = { BackgroundColor3 = "HeaderDark", TextColor3 = "HeaderText" },
		TextSize = 12,
		Weight = "MonoBold",
		LayoutOrder = 2,
		Corner = 8,
		Padding = { 0, 0, 11, 11 },
		Parent = buttons,
	})
	window._keyPill = keyPill
	AttachTooltip(keyPill, "Menu key - click, then press a new key")
	-- Clicking the pill rebinds the menu key through the shared capture path.
	local capture = {}
	function capture:_CancelCapture()
		if Library._binding == capture then
			Library._binding = nil
		end
		window:_UpdateKeyPill()
	end
	function capture:_Capture(input)
		local kind = input.UserInputType
		if kind == KEYBOARD and input.KeyCode ~= Enum.KeyCode.Escape and input.KeyCode ~= Enum.KeyCode.Backspace then
			Library._binding = nil
			if Library._menuKeybind then
				Library._menuKeybind:SetValue(input.KeyCode.Name)
			else
				Library.MenuKey = input.KeyCode.Name
				Library:_SaveSettings()
			end
			window:_UpdateKeyPill()
		elseif kind == KEYBOARD or kind == MB1 or kind == TOUCH then
			capture:_CancelCapture()
		end
	end
	keyPill.Activated:Connect(function()
		if Library._binding then
			Library._binding:_CancelCapture()
		end
		Library._binding = capture
		keyPill.Text = "..."
	end)

	local close = Create("TextButton", {
		Size = UDim2.fromOffset(34, 34),
		BackgroundColor3 = WHITE,
		LayoutOrder = 3,
		Corner = UDim.new(1, 0),
		Parent = buttons,
	})
	local closeIcon = PlaceIcon("x", 13, nil, close)
	PaintIcon(closeIcon, rgb(30, 32, 40), true)
	close.MouseEnter:Connect(function()
		Tween(close, { BackgroundColor3 = rgb(255, 228, 232) })
	end)
	close.MouseLeave:Connect(function()
		Tween(close, { BackgroundColor3 = WHITE })
	end)
	close.Activated:Connect(function()
		window:Toggle(false)
		if not window._closeHinted then
			window._closeHinted = true
			Library:Notify({
				Title = "Hidden",
				Content = "Press <b>" .. KeyDisplay(Library.MenuKey) .. "</b> to bring the menu back.",
				Duration = 4,
			})
		end
	end)

	window.Overlay = Create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 10, Parent = root })

	----------------------------------------------------------------------------
	-- Dragging, resizing and the once-a-second stats tick
	----------------------------------------------------------------------------

	dragArea.InputBegan:Connect(function(input)
		if input.UserInputType ~= MB1 and input.UserInputType ~= TOUCH then
			return
		end
		local start, origin = input.Position, root.Position
		StartDrag(function(move)
			local delta = move.Position - start
			root.Position = UDim2.new(origin.X.Scale, origin.X.Offset + delta.X, origin.Y.Scale, origin.Y.Offset + delta.Y)
		end, function()
			Library:_SaveSettings()
		end)
	end)

	local lastGripClick = 0
	grip.InputBegan:Connect(function(input)
		if input.UserInputType ~= MB1 and input.UserInputType ~= TOUCH then
			return
		end
		if os.clock() - lastGripClick < 0.35 then
			-- Double-click: back to the default size.
			local current = root.Size
			local target = UDim2.fromOffset(window.DefaultSize.X, window.DefaultSize.Y)
			local scale = WindowScale()
			Tween(root, {
				Size = target,
				Position = root.Position + UDim2.fromOffset(
					(window.DefaultSize.X - current.X.Offset) * scale / 2,
					(window.DefaultSize.Y - current.Y.Offset) * scale / 2
				),
			}, 0.35)
			Library:_SaveSettings()
			return
		end
		lastGripClick = os.clock()
		local start, startSize, startPosition = input.Position, root.Size, root.Position
		StartDrag(function(move)
			local scale = WindowScale()
			local delta = move.Position - start
			local screen = ScreenGui.AbsoluteSize
			local minimum = window.MinSize
			local width = math.clamp(startSize.X.Offset + delta.X / scale, minimum.X, math.max(minimum.X, screen.X / scale))
			local height = math.clamp(startSize.Y.Offset + delta.Y / scale, minimum.Y, math.max(minimum.Y, screen.Y / scale))
			root.Size = UDim2.fromOffset(width, height)
			root.Position = startPosition
				+ UDim2.fromOffset((width - startSize.X.Offset) * scale / 2, (height - startSize.Y.Offset) * scale / 2)
		end, function()
			Library:_SaveSettings()
		end)
	end)

	task.spawn(function()
		while not Library.Unloaded do
			task.wait(1)
			if root.Visible then
				RefreshStats()
			end
		end
	end)

	if options.MobileButton == true
		or (options.MobileButton ~= false and UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled)
	then
		window:_MobileButton(options.Icon)
	end

	window:_UpdateKeyPill()
	if window.Mascot then
		window:_MascotBrain()
	end
	if options.SettingsTab ~= false then
		window:_BuildSettings(options)
	end
	if options.AutoLoad ~= false then
		task.defer(function()
			if not Library.Unloaded then
				Library:LoadAutoloadConfig()
			end
		end)
	end
	OnTheme(function()
		window:_PaintTabs(true)
	end)

	if options.LoadingScreen ~= false then
		window:_Loading(options)
	else
		window.Root.Visible = true
		window:_Shown()
	end
	return window
end

--------------------------------------------------------------------------------
-- Speech bubble and the mascot's behaviour
--------------------------------------------------------------------------------

-- Types `text` into the speech bubble. Optional `mood` is held while talking.
function Window:Say(text, duration, mood)
	local bubble = self._bubble
	if not bubble or Library.Unloaded or not Library.MascotSpeech or not Library.MascotEnabled then
		return
	end
	self._sayToken += 1
	local token = self._sayToken
	text = tostring(text)
	bubble.Text.Text = text
	bubble.Text.MaxVisibleGraphemes = 0
	bubble.Scale.Scale = 0.85
	Tween(bubble.Scale, { Scale = 1 }, 0.35, Enum.EasingStyle.Back)
	Tween(bubble.Frame, { BackgroundTransparency = 0 }, 0.18)
	Tween(bubble.Tail, { BackgroundTransparency = 0 }, 0.18)
	Tween(bubble.Text, { TextTransparency = 0 }, 0.18)
	if mood and self.Mascot then
		self.Mascot:SetMood(mood)
	end
	task.spawn(function()
		local count = utf8.len(text) or #text
		for index = 1, count do
			if token ~= self._sayToken or Library.Unloaded then
				return
			end
			bubble.Text.MaxVisibleGraphemes = index
			local char = string.sub(text, index, index)
			task.wait((char == "." or char == "!" or char == "?") and 0.08 or char == "," and 0.06 or 0.026)
		end
		bubble.Text.MaxVisibleGraphemes = -1
		task.wait(duration or (1.8 + count * 0.03))
		if token ~= self._sayToken or Library.Unloaded then
			return
		end
		Tween(bubble.Frame, { BackgroundTransparency = 1 }, 0.25)
		Tween(bubble.Tail, { BackgroundTransparency = 1 }, 0.25)
		Tween(bubble.Text, { TextTransparency = 1 }, 0.25)
		Tween(bubble.Scale, { Scale = 0.9 }, 0.25)
		if mood and self.Mascot and not self.Mascot.Hidden then
			self.Mascot:SetMood("Idle")
		end
	end)
end

function Window:_MascotBrain()
	local window = self
	local mascot = self.Mascot
	local clicks, firstClick = 0, 0
	local holding, patted = 0, false
	local lastReaction = 0

	mascot.Hit.MouseButton1Down:Connect(function()
		holding += 1
		patted = false
		local token = holding
		task.delay(0.9, function()
			if holding == token and not mascot.Hidden then
				patted = true
				window:Say(Pick(MascotLines.Pat), nil, "Happy")
			end
		end)
	end)
	local function Release()
		holding += 1
	end
	mascot.Hit.MouseButton1Up:Connect(Release)
	mascot.Hit.MouseLeave:Connect(Release)
	mascot.Hit.Activated:Connect(function()
		if patted or mascot.Hidden or window._sulking then
			patted = false
			return
		end
		if os.clock() - firstClick > 6 then
			clicks, firstClick = 0, os.clock()
		end
		clicks += 1
		mascot:Hop()
		if clicks >= 6 then
			-- Poked too often: she hides for a few seconds.
			clicks = 0
			window._sulking = true
			window:Say(Pick(MascotLines.Hide), 1.2, "Flustered")
			task.delay(1.6, function()
				mascot:Hide()
				task.wait(4.5)
				if Library.Unloaded then
					return
				end
				mascot:Peek()
				window._sulking = false
				window:Say(Pick(MascotLines.Return), nil, "Blush")
			end)
		elseif clicks >= 4 then
			window:Say(Pick(MascotLines.Spam), nil, "Flustered")
		else
			window:Say(Pick(MascotLines.Click), nil, math.random() < 0.5 and "Blush" or "Happy")
		end
	end)

	-- Reacts to toggles being switched on (rarely, so it stays charming).
	Library._mascotReact = function(element)
		if not Library.MascotReactions or Library._loading or os.clock() - lastReaction < 25 or math.random() > 0.3 then
			return
		end
		lastReaction = os.clock()
		window:Say(string.format(Pick(MascotLines.React), element.Title), nil, "Happy")
	end
	Library._pointerHook = function(pointer)
		if window.Visible and Library.MascotFollow and Library.MascotEnabled then
			mascot:Look(pointer)
		end
	end

	-- Blinks every few seconds; says an idle line now and then.
	task.spawn(function()
		local nextIdle = os.clock() + math.random(45, 80)
		while not Library.Unloaded do
			task.wait(2.2 + math.random() * 3.5)
			if window.Visible and Library.MascotEnabled then
				mascot:Blink()
				if math.random() < 0.2 then
					task.wait(0.2)
					mascot:Blink()
				end
				if os.clock() > nextIdle and not window._sulking then
					nextIdle = os.clock() + math.random(60, 120)
					window:Say(Pick(MascotLines.Idle))
				end
			end
		end
	end)
end

function Window:SetMascotVisible(visible)
	Library.MascotEnabled = visible == true
	for _, layer in self._mascotLayers do
		layer.Visible = Library.MascotEnabled
	end
	if not Library.MascotEnabled and self._bubble then
		self._sayToken += 1
		self._bubble.Frame.BackgroundTransparency = 1
		self._bubble.Tail.BackgroundTransparency = 1
		self._bubble.Text.TextTransparency = 1
	end
	Library:_SaveSettings()
end

-- Runs every time the window appears.
function Window:_Shown()
	local mascot = self.Mascot
	if not mascot then
		return
	end
	mascot:SetPaused(false)
	if os.clock() - (self._hiddenAt or 0) > 1.5 and not self._sulking then
		mascot:SetMood("Surprised")
		mascot:Hop()
		task.delay(0.35, function()
			if self.Visible then
				self:Say(Pick(MascotLines.Greeting), nil, "Blush")
			end
		end)
	end
end

function Window:_UpdateKeyPill()
	if Library._binding then
		return
	end
	self._keyPill.Text = KeyDisplay(Library.MenuKey)
end

--------------------------------------------------------------------------------
-- Loading screen: a card with a progress bar while the script builds its tabs;
-- the mascot peeks over its top edge. Disable with `LoadingScreen = false`.
--------------------------------------------------------------------------------

function Window:_Loading(options)
	local window = self
	local duration = math.max(tonumber(options.LoadingTime) or 3.5, 0.3)
	local scaleValue = Library.Scale
	self._loading = true
	self.Visible = false
	self.Root.Visible = false

	local card = Create("CanvasGroup", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(340, 150),
		Theme = { BackgroundColor3 = "Background" },
		GroupTransparency = 1,
		ZIndex = 30,
		Corner = 20,
		Parent = ScreenGui,
	})
	local cardScale = Create("UIScale", { Scale = scaleValue * 0.9, Parent = card })
	local band = Create("Frame", { Size = UDim2.new(1, 0, 0, 58), Theme = { BackgroundColor3 = "Header" }, Parent = card })
	Create("TextLabel", {
		Position = UDim2.fromOffset(20, 10),
		Size = UDim2.new(1, -40, 0, 22),
		Text = window._title.Text ~= "" and window._title.Text or "Loading",
		TextSize = 17,
		Weight = "Bold",
		TextTruncate = Enum.TextTruncate.AtEnd,
		Theme = { TextColor3 = "HeaderText" },
		Parent = band,
	})
	Create("TextLabel", {
		Position = UDim2.fromOffset(20, 32),
		Size = UDim2.new(1, -40, 0, 16),
		Text = window._author.Text .. " " .. window._version.Text,
		TextSize = 12,
		Weight = "SemiBold",
		TextTransparency = 0.1,
		Theme = { TextColor3 = "HeaderText" },
		Parent = band,
	})
	local status = Create("TextLabel", {
		Position = UDim2.fromOffset(20, 74),
		Size = UDim2.new(1, -100, 0, 16),
		Text = "Preparing interface...",
		TextSize = 12,
		Weight = "Mono",
		Theme = { TextColor3 = "DimText" },
		Parent = card,
	})
	local percent = Create("TextLabel", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -20, 0, 74),
		Size = UDim2.fromOffset(60, 16),
		Text = "0%",
		TextSize = 12,
		Weight = "MonoBold",
		TextXAlignment = Enum.TextXAlignment.Right,
		Theme = { TextColor3 = "Text" },
		Parent = card,
	})
	local track = Create("Frame", {
		Position = UDim2.fromOffset(20, 100),
		Size = UDim2.new(1, -40, 0, 8),
		Theme = { BackgroundColor3 = "Track" },
		Corner = UDim.new(1, 0),
		Parent = card,
	})
	local fill = Create("Frame", {
		Size = UDim2.fromScale(0, 1),
		Theme = { BackgroundColor3 = "Accent" },
		Corner = UDim.new(1, 0),
		Parent = track,
	})
	Create("TextLabel", {
		Position = UDim2.fromOffset(20, 116),
		Size = UDim2.new(1, -40, 0, 20),
		Text = "Press " .. KeyDisplay(Library.MenuKey) .. " to toggle the menu",
		TextSize = 11,
		Theme = { TextColor3 = "DimText" },
		Parent = card,
	})

	-- A second, smaller copy of the mascot peeking over the card.
	local peeker
	if self.Mascot and Library.MascotEnabled then
		local layer = Create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 29, Parent = ScreenGui })
		local hands = Create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 31, Parent = ScreenGui })
		peeker = BuildMascot(layer, hands, UDim2.new(0.5, 96 * scaleValue, 0.5, -75 * scaleValue), scaleValue * 0.75)
		peeker.Layers = { layer, hands }
		peeker.Head.Position = UDim2.fromOffset(0, 86)
		for _, part in peeker.HandParts or {} do
			part.BackgroundTransparency = 1
			local stroke = part:FindFirstChildOfClass("UIStroke")
			if stroke then
				stroke.Transparency = 1
			end
		end
		peeker.Hidden = true
	end

	Tween(card, { GroupTransparency = 0 }, 0.6)
	Tween(cardScale, { Scale = scaleValue }, 0.7, Enum.EasingStyle.Back)
	if peeker then
		task.delay(Library.Animations and 0.6 or 0, function()
			peeker:SetMood("Surprised")
			peeker:Peek()
		end)
	end

	task.spawn(function()
		local steps = { "Preparing interface", "Loading configs", "Waking her up", "Almost there", "Ready" }
		local start = os.clock()
		while not Library.Unloaded do
			local alpha = math.clamp((os.clock() - start) / duration, 0, 1)
			local eased = alpha < 0.5 and 4 * alpha ^ 3 or 1 - (-2 * alpha + 2) ^ 3 / 2
			fill.Size = UDim2.fromScale(eased, 1)
			percent.Text = math.floor(eased * 100 + 0.5) .. "%"
			status.Text = steps[math.min(#steps, math.floor(alpha * (#steps - 1)) + 1)] .. (alpha < 1 and "..." or "")
			if peeker and alpha > 0.55 and peeker.Mood == "Surprised" then
				peeker:SetMood("Idle")
			end
			if alpha >= 1 then
				break
			end
			task.wait()
		end
		if peeker then
			peeker:SetMood("Happy")
		end
		task.wait(0.6)
		if peeker then
			peeker:Hide()
		end
		Tween(card, { GroupTransparency = 1 }, 0.45)
		Tween(cardScale, { Scale = scaleValue * 1.05 }, 0.45)
		task.wait(Library.Animations and 0.45 or 0)
		card:Destroy()
		if peeker then
			for _, layer in peeker.Layers do
				layer:Destroy()
			end
		end
		window._loading = false
		if not Library.Unloaded then
			window:Toggle(true)
		end
	end)
end

function Window:_MobileButton(iconName)
	local button = Create("TextButton", {
		Position = UDim2.fromOffset(16, 16),
		Size = UDim2.fromOffset(46, 46),
		Theme = { BackgroundColor3 = "Header" },
		Corner = UDim.new(1, 0),
		Stroke = { Color = "HeaderText", Transparency = 0.6 },
		Parent = ScreenGui,
	})
	PlaceIcon(iconName or "sparkle", 24, "HeaderText", button)
	button.InputBegan:Connect(function(input)
		if input.UserInputType ~= MB1 and input.UserInputType ~= TOUCH then
			return
		end
		local start, origin, moved = input.Position, button.Position, false
		StartDrag(function(move)
			local delta = move.Position - start
			if delta.Magnitude > 6 then
				moved = true
			end
			if moved then
				button.Position = UDim2.new(origin.X.Scale, origin.X.Offset + delta.X, origin.Y.Scale, origin.Y.Offset + delta.Y)
			end
		end, function()
			if not moved then
				self:Toggle()
			end
		end)
	end)
	self.MobileButton = button
end

function Window:Toggle(state)
	if self._loading then
		return
	end
	if state == nil then
		state = not self.Visible
	end
	state = state == true
	if state == self.Visible and self.Root.Visible == state then
		return
	end
	self.Visible = state
	Popup.Close()
	Tooltip.Hide()
	if Library._binding then
		Library._binding:_CancelCapture()
	end
	self._toggleToken = (self._toggleToken or 0) + 1
	local token = self._toggleToken
	if state then
		self.Root.Visible = true
		self.UIScale.Scale = Library.Scale * 0.94
		Tween(self.UIScale, { Scale = Library.Scale }, 0.35, Enum.EasingStyle.Back)
		self:_Shown()
	else
		self._hiddenAt = os.clock()
		if self.Mascot then
			self.Mascot:SetPaused(true)
		end
		Tween(self.UIScale, { Scale = Library.Scale * 0.94 }, 0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		task.delay(Library.Animations and 0.14 or 0, function()
			if self._toggleToken == token and not self.Visible then
				self.Root.Visible = false
				self.UIScale.Scale = Library.Scale
			end
		end)
	end
end

function Window:SetScale(scale)
	scale = math.clamp(tonumber(scale) or 1, 0.4, 2)
	Library.Scale = scale
	Library._savedScale = true
	Popup.Close()
	self.UIScale.Scale = scale
	Tooltip.Scale.Scale = scale
	Notifications.Scale.Scale = scale
	KeybindList.Scale.Scale = scale
	Library:_SaveSettings()
end

function Window:SetTitle(text)
	self.Title = tostring(text)
	self._title.Text = self.Title
end
Window.SetSubTitle = Window.SetTitle

function Window:SetAuthor(text)
	self._author.Text = "by " .. tostring(text) .. " ·"
end

function Window:SetVersion(text)
	self._version.Text = tostring(text)
end

function Window:SetBadge(text)
	self._badge.Visible = text ~= nil and text ~= false
	if self._badge.Visible then
		self._badge.Text = tostring(text)
	end
end

function Window:SelectTab(target)
	local tab = target
	if type(target) ~= "table" then
		for index, candidate in self.Tabs do
			if candidate.Title == target or index == target then
				tab = candidate
				break
			end
		end
	end
	if type(tab) ~= "table" or self.CurrentTab == tab then
		return
	end
	Popup.Close()
	local previous = self.CurrentTab
	self.CurrentTab = tab
	if previous then
		previous.Page.Visible = false
	end
	tab.Page.Visible = true
	tab.Scroll.Position = UDim2.fromOffset(14, 66)
	Tween(tab.Scroll, { Position = UDim2.fromOffset(14, 56) }, 0.3)
	self:_PaintTabs()
	tab:ApplyFilter()
	tab:_FitPills()
end

-- Recolours tab labels and slides the highlight under the current tab.
function Window:_PaintTabs(instant)
	local theme = Library.Theme
	local animate = Animate(instant)
	for _, tab in self.Tabs do
		local active = tab == self.CurrentTab
		animate(tab.Label, {
			TextColor3 = active and theme.Text or theme.HeaderText,
			TextTransparency = active and 0 or 0.16,
		})
		PaintIcon(tab.Icon, active and theme.Accent or theme.HeaderText, instant)
	end
	self:_MoveHighlight(instant)
end

function Window:_MoveHighlight(instant)
	local tab = self.CurrentTab
	local highlight = self._highlight
	if not tab then
		highlight.Visible = false
		return
	end
	local scale = WindowScale()
	local x = (tab.Button.AbsolutePosition.X - self._strip.AbsolutePosition.X) / scale
	local width = tab.Button.AbsoluteSize.X / scale
	if width <= 0 then
		return
	end
	local target = { Position = UDim2.fromOffset(x, 0), Size = UDim2.fromOffset(width, 38) }
	if instant or not highlight.Visible then
		Set(highlight, target)
	else
		Tween(highlight, target, 0.35)
	end
	highlight.Visible = true
end

--------------------------------------------------------------------------------
-- Tabs (header strip) and their pages
--------------------------------------------------------------------------------

function Window:AddTab(options)
	if type(options) == "string" then
		options = { Title = options }
	end
	options = options or {}
	local window = self
	local tab = setmetatable({
		Window = self,
		Title = options.Title or options.Name or "Tab",
		IsSettings = options.IsSettings == true,
		ShowAll = options.ShowAll ~= false,
		Sections = {},
		SubTabs = {},
		SubButtons = {},
		ActiveSub = nil,
		Columns = {},
		_counts = {},
	}, Tab)

	local button = Create("TextButton", {
		Size = UDim2.fromOffset(0, 36),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		LayoutOrder = options.Order or (#self.Tabs + 1),
		Padding = { 0, 0, 14, 15 },
		List = { Horizontal = true, Padding = 7, VAlign = Enum.VerticalAlignment.Center },
		Parent = self.TabList,
	})
	tab.Button = button
	tab.Icon = BuildIcon(options.Icon or "grid", 15, Library.Theme.HeaderText)
	tab.Icon.Frame.LayoutOrder = 1
	tab.Icon.Frame.Parent = button
	tab.Label = Create("TextLabel", {
		Size = UDim2.fromOffset(0, 36),
		AutomaticSize = Enum.AutomaticSize.X,
		Text = tab.Title,
		TextSize = 13,
		Weight = "SemiBold",
		LayoutOrder = 2,
		Parent = button,
	})
	button.Activated:Connect(function()
		window:SelectTab(tab)
		window._picked = true
		Library._lastTab = tab.Title
		Library:_SaveSettings()
	end)
	button.MouseEnter:Connect(function()
		if window.CurrentTab ~= tab then
			Tween(tab.Label, { TextTransparency = 0 })
		end
	end)
	button.MouseLeave:Connect(function()
		if window.CurrentTab ~= tab then
			Tween(tab.Label, { TextTransparency = 0.16 })
		end
	end)
	local function Follow()
		if window.CurrentTab == tab then
			window:_MoveHighlight(true)
		end
	end
	button:GetPropertyChangedSignal("AbsoluteSize"):Connect(Follow)
	button:GetPropertyChangedSignal("AbsolutePosition"):Connect(Follow)

	-- Page: pill bar + one scrolling area holding the columns
	local page = Create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false, Parent = self.Content })
	tab.Page = page
	tab.PillBar = Create("Frame", {
		Position = UDim2.fromOffset(20, 14),
		Size = UDim2.new(1, -440, 0, 30),
		BackgroundTransparency = 1,
		List = { Horizontal = true, Padding = 6, VAlign = Enum.VerticalAlignment.Center },
		Parent = page,
	})
	tab.Heading = Create("TextLabel", {
		Size = UDim2.fromOffset(0, 30),
		AutomaticSize = Enum.AutomaticSize.X,
		Text = tab.Title,
		TextSize = 16,
		Weight = "Bold",
		Theme = { TextColor3 = "Text" },
		Parent = tab.PillBar,
	})
	tab.Scroll = Create("ScrollingFrame", {
		Position = UDim2.fromOffset(14, 56),
		Size = UDim2.new(1, -22, 1, -64),
		ScrollBarThickness = 3,
		Theme = { ScrollBarImageColor3 = "DimText" },
		Padding = { 2, 14, 6, 8 },
		Parent = page,
	})
	local grid = Create("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		List = { Horizontal = true, Padding = 12 },
		Parent = tab.Scroll,
	})
	local count = self.Columns
	for index = 1, count do
		tab.Columns[index] = Create("Frame", {
			Size = UDim2.new(1 / count, -12 * (count - 1) / count, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			LayoutOrder = index,
			List = { Padding = 12 },
			Parent = grid,
		})
		tab._counts[index] = 0
	end
	tab.NoResults = Create("TextLabel", {
		Position = UDim2.fromOffset(0, 70),
		Size = UDim2.new(1, 0, 0, 40),
		Text = "Nothing matches your search",
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Center,
		Theme = { TextColor3 = "DimText" },
		Visible = false,
		Parent = page,
	})
	tab.PillBar:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		tab:_FitPills()
	end)

	table.insert(self.Tabs, tab)
	if not self._picked and Library._lastTab == tab.Title then
		self._picked = true
		self:SelectTab(tab)
	elseif not self.CurrentTab or (not self._picked and self.CurrentTab.IsSettings and not options.IsSettings) then
		self:SelectTab(tab)
	else
		self:_PaintTabs(true)
	end
	return tab
end

function Tab:Select()
	self.Window:SelectTab(self)
end

--------------------------------------------------------------------------------
-- Pills (sub-tabs) with a "+N" overflow menu
--------------------------------------------------------------------------------

function Tab:_Pill(title, sub, order)
	local tab = self
	local button = Create("TextButton", {
		Size = UDim2.fromOffset(0, 28),
		AutomaticSize = Enum.AutomaticSize.X,
		LayoutOrder = order,
		Corner = UDim.new(1, 0),
		Stroke = { Color = "Border", Transparency = 0.35 },
		Padding = { 0, 0, 11, 13 },
		List = { Horizontal = true, Padding = 6, VAlign = Enum.VerticalAlignment.Center },
		Parent = self.PillBar,
	})
	local dot = Create("Frame", { Size = UDim2.fromOffset(6, 6), Corner = UDim.new(1, 0), LayoutOrder = 1, Parent = button })
	local label = Create("TextLabel", {
		Size = UDim2.fromOffset(0, 28),
		AutomaticSize = Enum.AutomaticSize.X,
		Text = title,
		TextSize = 12,
		Weight = "SemiBold",
		LayoutOrder = 2,
		Parent = button,
	})
	local entry = { Sub = sub, Button = button, Dot = dot, Label = label, Title = title }
	if sub ~= false then
		table.insert(self.SubButtons, entry)
		button.Activated:Connect(function()
			tab:SelectSubTab(sub)
		end)
	end
	button.MouseEnter:Connect(function()
		if entry.Sub == false or tab.ActiveSub ~= sub then
			Tween(button, { BackgroundColor3 = Library.Theme.Hover })
		end
	end)
	button.MouseLeave:Connect(function()
		tab:_PaintPills()
	end)
	button:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		tab:_FitPills()
	end)
	return entry
end

function Tab:_PaintPills(instant)
	local theme = Library.Theme
	local animate = Animate(instant)
	local hiddenActive = false
	for _, entry in self.SubButtons do
		local active = entry.Sub == self.ActiveSub
		if active and not entry.Button.Visible then
			hiddenActive = true
		end
		animate(entry.Button, {
			BackgroundColor3 = active and theme.Good or theme.Pill,
			BackgroundTransparency = active and 0.84 or 0,
		})
		animate(entry.Dot, { BackgroundColor3 = active and theme.Good or theme.DimText })
		animate(entry.Label, { TextColor3 = active and theme.Good or theme.SubText })
	end
	local more = self._more
	if more then
		animate(more.Button, {
			BackgroundColor3 = hiddenActive and theme.Good or theme.Pill,
			BackgroundTransparency = hiddenActive and 0.84 or 0,
		})
		animate(more.Dot, { BackgroundColor3 = hiddenActive and theme.Good or theme.DimText })
		animate(more.Label, { TextColor3 = hiddenActive and theme.Good or theme.SubText })
	end
end

-- Hides pills that don't fit and collects them behind a "+N" pill.
function Tab:_FitPills()
	if #self.SubButtons == 0 or not self.Page.Visible then
		return
	end
	local scale = WindowScale()
	local toolbar = self.Window._toolbar.AbsoluteSize.X / scale
	self.PillBar.Size = UDim2.new(1, -(toolbar + 56), 0, 30)
	local available = self.PillBar.AbsoluteSize.X / scale
	if available <= 0 then
		return
	end
	local used, hidden, cut = 0, {}, false
	for index, entry in self.SubButtons do
		local width = entry.Button.AbsoluteSize.X / scale
		if width > 0 and entry.Button.Visible then
			entry.Width = width
		end
		width = entry.Width or (#entry.Title * 7 + 36)
		local reserve = index < #self.SubButtons and 52 or 0
		if not cut and (index == 1 or used + width + reserve <= available) then
			entry.Button.Visible = true
			used += width + 6
		else
			cut = true
			entry.Button.Visible = false
			table.insert(hidden, entry)
		end
	end
	self._hidden = hidden
	self._more.Button.Visible = #hidden > 0
	self._more.Label.Text = "+" .. #hidden
	self:_PaintPills(true)
end

function Tab:AddSubTab(options)
	if type(options) == "string" then
		options = { Title = options }
	end
	options = options or {}
	local tab = self
	if #self.SubTabs == 0 then
		self.Heading.Visible = false
		if self.ShowAll then
			self:_Pill("All", nil, 0)
		end
		self._more = self:_Pill("+0", false, 100000)
		self._more.Button.Visible = false
		self._more.Button.Activated:Connect(function()
			local items = {}
			for _, entry in tab._hidden or {} do
				table.insert(items, {
					Text = entry.Title,
					Checked = tab.ActiveSub == entry.Sub,
					Callback = function()
						tab:SelectSubTab(entry.Sub)
					end,
				})
			end
			self.Window:_Menu().Open(tab._more.Button, items, { Width = 160 })
		end)
		OnTheme(function()
			self:_PaintPills(true)
		end)
	end
	local sub = setmetatable({ Tab = self, Title = options.Title or options.Name or "SubTab" }, SubTab)
	table.insert(self.SubTabs, sub)
	sub.Entry = self:_Pill(sub.Title, sub, #self.SubTabs)
	if not self.ShowAll and #self.SubTabs == 1 then
		self.ActiveSub = sub
	end
	self:_PaintPills(true)
	self:_FitPills()
	self:ApplyFilter()
	return sub
end

function Tab:SelectSubTab(sub)
	if type(sub) == "string" then
		for _, candidate in self.SubTabs do
			if candidate.Title == sub then
				sub = candidate
				break
			end
		end
		if type(sub) == "string" then
			sub = nil
		end
	end
	if sub == nil and not self.ShowAll then
		return
	end
	Popup.Close()
	self.ActiveSub = sub
	self:_PaintPills()
	self.Scroll.CanvasPosition = Vector2.zero
	self:ApplyFilter()
end

function Tab:AddSection(options, side)
	return self:_AddSection(options, side, nil)
end

function SubTab:AddSection(options, side)
	return self.Tab:_AddSection(options, side, self)
end

function SubTab:Select()
	self.Tab.Window:SelectTab(self.Tab)
	self.Tab:SelectSubTab(self)
end

-- Sections with a sub-tab show under "All" and their own pill; sections added
-- straight to the tab show under every pill. A search query overrides both.
function Tab:ApplyFilter()
	local query = self.Window.Query or ""
	local any = false
	for _, section in self.Sections do
		local visible
		if query == "" then
			visible = self.ActiveSub == nil or section.SubTab == nil or section.SubTab == self.ActiveSub
			for _, element in section.Elements do
				element._match = true
				element:_Refresh()
			end
			section.Body.Visible = not section.Collapsed
		else
			local titleMatch = string.find(section.SearchText, query, 1, true) ~= nil
			local matches = 0
			for _, element in section.Elements do
				local match = titleMatch
					or (element.SearchText ~= nil and string.find(element.SearchText, query, 1, true) ~= nil)
				element._match = match
				element:_Refresh()
				if match and not element.Hidden then
					matches += 1
				end
			end
			visible = titleMatch or matches > 0
			section.Body.Visible = true
		end
		visible = visible and not section.Hidden
		section.Frame.Visible = visible
		any = any or visible
	end
	self.NoResults.Visible = query ~= "" and not any
end

--------------------------------------------------------------------------------
-- Sections (cards)
--------------------------------------------------------------------------------

local ColumnNames = { Left = 1, Middle = 2, Center = 2, Centre = 2 }

function Tab:_AddSection(options, side, sub)
	if type(options) ~= "table" then
		options = { Title = options, Side = side }
	end
	side = options.Side or side
	local count = #self.Columns
	local column
	if type(side) == "number" then
		column = math.clamp(math.floor(side), 1, count)
	elseif side == "Right" then
		column = count
	elseif ColumnNames[side] then
		column = math.min(ColumnNames[side], count)
	else
		column = 1
		for index = 2, count do
			if self._counts[index] < self._counts[column] then
				column = index
			end
		end
	end
	self._counts[column] += 1

	local section = setmetatable({
		Tab = self,
		SubTab = sub,
		Title = options.Title or options.Name or "Section",
		Elements = {},
		Order = 0,
		Collapsed = false,
		Hidden = false,
	}, Section)
	section.SearchText = Util.Lower(section.Title)
	section.Column = self.Scroll

	local frame = Create("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Theme = { BackgroundColor3 = "Panel" },
		LayoutOrder = #self.Sections + 1,
		Corner = 14,
		Stroke = { Color = "Border", Transparency = 0.45 },
		Padding = { 12, 12, 12, 12 },
		List = { Padding = 10 },
		Parent = self.Columns[column],
	})
	section.Frame = frame

	local header = Create("TextButton", {
		Size = UDim2.new(1, 0, 0, 28),
		BackgroundTransparency = 1,
		LayoutOrder = 1,
		Parent = frame,
	})
	local tile = Create("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.fromOffset(28, 28),
		BackgroundColor3 = typeof(options.Color) == "Color3" and options.Color or Library.Theme.Accent,
		Corner = 8,
		Parent = header,
	})
	if typeof(options.Color) ~= "Color3" then
		Bind(tile, { BackgroundColor3 = "Accent" })
	end
	Create("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(WHITE, rgb(205, 205, 210)),
		Parent = tile,
	})
	PlaceIcon(options.Icon or "star", 16, nil, tile)
	section._title = Create("TextLabel", {
		Position = UDim2.fromOffset(38, 0),
		Size = UDim2.new(1, -86, 1, 0),
		Text = section.Title,
		TextSize = 15,
		Weight = "Bold",
		TextTruncate = Enum.TextTruncate.AtEnd,
		Theme = { TextColor3 = "Text" },
		Parent = header,
	})
	section._count = Create("TextLabel", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -22, 0.5, 0),
		Size = UDim2.fromOffset(40, 16),
		TextSize = 11,
		Weight = "Mono",
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = header,
	})
	local chevron = PlaceIcon("chevron", 12, "DimText", header, Vector2.new(1, 0.5), UDim2.new(1, -2, 0.5, 0))
	section._chevron = chevron

	section.Body = Create("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = 2,
		List = { Padding = 7 },
		Parent = frame,
	})

	header.Activated:Connect(function()
		if options.Collapsible ~= false then
			section:SetCollapsed(not section.Collapsed)
		end
	end)
	OnTheme(function()
		section:_UpdateCount()
	end)
	if options.Collapsed then
		section:SetCollapsed(true)
	end

	table.insert(self.Sections, section)
	section:_UpdateCount()
	self:ApplyFilter()
	return section
end

-- The header count shows how many toggles the card has, in the accent colour
-- while at least one of them is on.
function Section:_UpdateCount()
	local total, on = 0, 0
	for _, element in self.Elements do
		if element.Type == "Toggle" then
			total += 1
			if element.Value then
				on += 1
			end
		end
	end
	self._count.Text = total > 0 and tostring(total) or ""
	self._count.TextColor3 = on > 0 and Library.Theme.Accent or Library.Theme.DimText
end

function Section:SetCollapsed(collapsed)
	self.Collapsed = collapsed == true
	self.Body.Visible = not self.Collapsed or self.Tab.Window.Query ~= ""
	Tween(self._chevron.Frame, { Rotation = self.Collapsed and -90 or 0 })
end

function Section:SetVisible(visible)
	self.Hidden = not visible
	self.Tab:ApplyFilter()
end

function Section:SetTitle(title)
	self.Title = title
	self.SearchText = Util.Lower(title)
	self._title.Text = title
end

function Section:_NextOrder()
	self.Order += 1
	return self.Order
end

function Section:_Register(element)
	element.SearchText = element.SearchText or (element.Title and Util.Lower(element.Title))
	table.insert(self.Elements, element)
	if element.Type == "Toggle" then
		self:_UpdateCount()
	end
	if self.Tab.Window.Query ~= "" then
		self.Tab:ApplyFilter()
	end
	return element
end
-- Elements
--------------------------------------------------------------------------------

local Element = {}
Element.__index = Element

local function Class()
	local class = setmetatable({}, { __index = Element })
	class.__index = class
	return class
end

-- Accepts both `(flag, options)` and `(options)` with `options.Flag`.
local function Args(flag, options)
	if type(flag) == "table" then
		options = flag
		flag = options.Flag
	end
	options = options or {}
	local title = options.Title or options.Text or options.Name or flag or ""
	return flag, options, tostring(title)
end

local function AutoFlag(section, title)
	local base = section.Tab.Title .. "/" .. section.Title .. "/" .. title
	local flag, index = base, 1
	while Library.Options[flag] do
		index += 1
		flag = base .. "#" .. index
	end
	return flag
end

function Section:_Element(class, kind, flag, options, title, saveable)
	local element = setmetatable({
		Type = kind,
		Section = self,
		Tab = self.Tab,
		Window = self.Tab.Window,
		Title = title,
		Callback = options.Callback,
		Tooltip = options.Tooltip,
		Changed = {},
		Save = saveable and options.Save ~= false,
		Hidden = false,
		_match = true,
	}, class)
	if saveable and options.Save ~= false then
		element.Flag = flag or AutoFlag(self, title)
	elseif flag then
		element.Flag = flag
	end
	return element
end

local function RegisterOption(element)
	local flag = element.Flag
	if not flag then
		return
	end
	if Library.Options[flag] then
		warn("[MyUI] duplicate flag '" .. tostring(flag) .. "', the newer element replaces it")
	end
	Library.Options[flag] = element
	Library.Flags[flag] = element.Value
	local pending = Library._pending[flag]
	if pending ~= nil and element.Deserialize then
		Library._pending[flag] = nil
		local loading = Library._loading
		Library._loading = true
		pcall(element.Deserialize, element, pending)
		Library._loading = loading
	end
end

function Element:OnChanged(callback)
	table.insert(self.Changed, callback)
	return self
end

function Element:_Store()
	if self.Flag then
		Library.Flags[self.Flag] = self.Value
	end
end

function Element:_Emit(...)
	self:_Store()
	SafeCall(self.Callback, ...)
	for _, callback in self.Changed do
		SafeCall(callback, ...)
	end
	if self.Save and not self._quiet then
		Library:_QueueSave()
	end
end

function Element:_Refresh()
	if self.Holder then
		self.Holder.Visible = not self.Hidden and self._match ~= false
	end
end

function Element:SetVisible(visible)
	self.Hidden = not visible
	self:_Refresh()
end

function Element:SetTitle(title)
	self.Title = tostring(title)
	self.SearchText = Util.Lower(self.Title)
	if self._title then
		self._title.Text = self.Title
	end
end

function Element:SetTooltip(text)
	self.Tooltip = text
end

function Element:GetValue()
	return self.Value
end

-- Restores the value the element was created with (right-click a row).
function Element:Reset()
	local default = self.Default
	if self.Type == "ColorPicker" then
		self:SetRainbow(false)
		self:SetValue(default[1], default[2])
	elseif self.Type == "Keybind" then
		self:SetValue(default[1], default[2])
	elseif self.Type == "Dropdown" and self.Multi then
		self:SetValue(table.clone(default))
	else
		self:SetValue(default)
	end
end

local function AttachReset(element, gui)
	local function Open()
		element.Window:_Menu().Open(gui, {
			{
				Text = "Reset to default",
				Callback = function()
					element:Reset()
				end,
			},
		}, { Width = 150, Clip = element.Section.Column })
	end
	if gui:IsA("GuiButton") then
		gui.MouseButton2Click:Connect(Open)
	else
		gui.InputBegan:Connect(function(input)
			if input.UserInputType == MB2 then
				Open()
			end
		end)
	end
end

function Element:Destroy()
	self.Destroyed = true
	if self.Flag and Library.Options[self.Flag] == self then
		Library.Options[self.Flag] = nil
		Library.Flags[self.Flag] = nil
	end
	local list = self.Section and self.Section.Elements
	local index = list and table.find(list, self)
	if index then
		table.remove(list, index)
	end
	if self._Unmap then
		self:_Unmap()
	end
	if self.Holder then
		self.Holder:Destroy()
	end
end

-- A row with a title on the left and a right-aligned slot for widgets.
function Section:_TitleRow(title, options, reserve, lazySlot)
	local holder = Create("TextButton", {
		Size = UDim2.new(1, 0, 0, 22),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = self:_NextOrder(),
		Parent = self.Body,
	})
	local label = Create("TextLabel", {
		Size = UDim2.new(1, -reserve, 0, 22),
		Text = title,
		TextSize = 13,
		Theme = { TextColor3 = "SubText" },
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = holder,
	})
	if options.Description then
		Create("TextLabel", {
			Position = UDim2.fromOffset(0, 22),
			Size = UDim2.new(1, -reserve, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Text = options.Description,
			TextSize = 11,
			TextWrapped = true,
			Weight = "Regular",
			Theme = { TextColor3 = "DimText" },
			Parent = holder,
		})
	end
	if lazySlot then
		return holder, label, nil
	end
	return holder, label, Section._Slot(holder, reserve)
end

-- The right-aligned widget slot; toggles only create it once an add-on is added.
function Section._Slot(holder, reserve)
	return Create("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -(reserve > 0 and reserve - 2 or 0), 0, 0),
		Size = UDim2.new(0, 0, 0, 22),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		List = {
			Horizontal = true,
			Padding = 6,
			HAlign = Enum.HorizontalAlignment.Right,
			VAlign = Enum.VerticalAlignment.Center,
		},
		Parent = holder,
	})
end

-- Keeps a row title from running underneath its right-hand widgets.
local function FitTitle(label, slot, reserve)
	local function Fit()
		local width = slot.AbsoluteSize.X / WindowScale()
		label.Size = UDim2.new(1, -(reserve + (width > 0 and width + 8 or 0)), 0, 22)
	end
	slot:GetPropertyChangedSignal("AbsoluteSize"):Connect(Fit)
	Fit()
end

--------------------------------------------------------------------------------
-- Toggle
--------------------------------------------------------------------------------

local Toggle = Class()

function Section:AddToggle(flag, options)
	local title
	flag, options, title = Args(flag, options)
	local toggle = self:_Element(Toggle, "Toggle", flag, options, title, true)
	toggle.Value = options.Default == true
	toggle.Default = toggle.Value

	local holder, label = self:_TitleRow(title, options, 44, true)
	toggle.Holder, toggle._title = holder, label
	AttachReset(toggle, holder)

	local switch = Create("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 1),
		Size = UDim2.fromOffset(36, 20),
		Theme = { BackgroundColor3 = "Track" },
		Corner = UDim.new(1, 0),
		Parent = holder,
	})
	toggle._fill = Create("Frame", {
		Size = UDim2.fromScale(1, 1),
		Theme = { BackgroundColor3 = "Accent" },
		BackgroundTransparency = 1,
		Corner = UDim.new(1, 0),
		Parent = switch,
	})
	toggle._knob = Create("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 3, 0.5, 0),
		Size = UDim2.fromOffset(14, 14),
		Theme = { BackgroundColor3 = "Knob" },
		Corner = UDim.new(1, 0),
		Parent = switch,
	})
	Create("UIStroke", { Color = BLACK, Transparency = 0.85, Parent = toggle._knob })

	holder.Activated:Connect(function()
		toggle:SetValue(not toggle.Value)
	end)
	holder.MouseEnter:Connect(function()
		Tween(label, { TextColor3 = Library.Theme.Text })
	end)
	holder.MouseLeave:Connect(function()
		Tween(label, { TextColor3 = Library.Theme.SubText })
	end)
	AttachTooltip(holder, toggle)
	OnTheme(function()
		toggle:_Render(true)
	end)

	toggle:_Render(true)
	self:_Register(toggle)
	RegisterOption(toggle)
	return toggle
end

function Toggle:_Render(instant)
	local on = self.Value
	local animate = Animate(instant)
	animate(self._fill, { BackgroundTransparency = on and 0 or 1 })
	animate(self._knob, { Position = on and UDim2.new(1, -17, 0.5, 0) or UDim2.new(0, 3, 0.5, 0) })
end

function Toggle:SetValue(value, silent)
	value = value == true
	if value == self.Value then
		return
	end
	self.Value = value
	self:_Render()
	self.Section:_UpdateCount()
	if silent then
		self:_Store()
	else
		self:_Emit(value)
		if value and Library._mascotReact then
			Library._mascotReact(self)
		end
	end
	KeybindList.Refresh()
end

function Toggle:Serialize()
	return { Type = "Toggle", Value = self.Value }
end

function Toggle:Deserialize(data)
	if type(data) == "table" and data.Type == "Toggle" then
		self:SetValue(data.Value == true)
	end
end

--------------------------------------------------------------------------------
-- Button (supports several side-by-side buttons in one row)
--------------------------------------------------------------------------------

local Button = Class()

function Section:AddButton(options, callback)
	if type(options) ~= "table" then
		options = { Title = options, Callback = callback }
	end
	local title = tostring(options.Title or options.Text or options.Name or "Button")
	local button = self:_Element(Button, "Button", nil, options, title, false)
	button.Buttons = {}
	button.Holder = Create("Frame", {
		Size = UDim2.new(1, 0, 0, 30),
		BackgroundTransparency = 1,
		LayoutOrder = self:_NextOrder(),
		List = { Horizontal = true, Padding = 6 },
		Parent = self.Body,
	})
	button:_Add(options)
	self:_Register(button)
	return button
end

function Button:_Add(options)
	local entry = {
		Title = tostring(options.Title or options.Text or options.Name or "Button"),
		Callback = options.Callback,
		Confirm = options.Confirm,
		Armed = 0,
	}
	local instance = Create("TextButton", {
		Size = UDim2.fromScale(1, 1),
		Theme = { BackgroundColor3 = "Element", TextColor3 = "Text" },
		Text = entry.Title,
		TextSize = 13,
		Weight = "SemiBold",
		TextTruncate = Enum.TextTruncate.AtEnd,
		ClipsDescendants = true,
		LayoutOrder = #self.Buttons + 1,
		Corner = 8,
		Stroke = { Color = "Border", Transparency = 0.4 },
		Parent = self.Holder,
	})
	entry.Instance = instance
	local stroke = instance:FindFirstChildOfClass("UIStroke")

	instance.MouseEnter:Connect(function()
		Tween(instance, { BackgroundColor3 = Library.Theme.Hover })
		Tween(stroke, { Color = Library.Theme.Accent })
	end)
	instance.MouseLeave:Connect(function()
		Tween(instance, { BackgroundColor3 = Library.Theme.Element })
		Tween(stroke, { Color = Library.Theme.Border })
	end)
	instance.Activated:Connect(function()
		Ripple(instance)
		if entry.Confirm and entry.Armed == 0 then
			entry.Armed += 1
			local token = entry.Armed
			instance.Text = type(entry.Confirm) == "string" and entry.Confirm or "Click again to confirm"
			instance.TextColor3 = Library.Theme.AccentGlow
			task.delay(2.5, function()
				if entry.Armed == token then
					entry.Armed = 0
					instance.Text = entry.Title
					instance.TextColor3 = Library.Theme.Text
				end
			end)
			return
		end
		if entry.Armed ~= 0 then
			entry.Armed = 0
			instance.Text = entry.Title
			instance.TextColor3 = Library.Theme.Text
		end
		SafeCall(entry.Callback)
	end)
	AttachTooltip(instance, options.Tooltip)

	table.insert(self.Buttons, entry)
	local count = #self.Buttons
	for _, other in self.Buttons do
		other.Instance.Size = UDim2.new(1 / count, -6 * (count - 1) / count, 1, 0)
	end
	local titles = {}
	for _, other in self.Buttons do
		table.insert(titles, other.Title)
	end
	self.SearchText = Util.Lower(table.concat(titles, " "))
	return self
end

function Button:AddButton(options, callback)
	if type(options) ~= "table" then
		options = { Title = options, Callback = callback }
	end
	return self:_Add(options)
end

function Button:SetTitle(title, index)
	local entry = self.Buttons[index or 1]
	if entry then
		entry.Title = tostring(title)
		entry.Instance.Text = entry.Title
	end
end

function Button:Fire(index)
	local entry = self.Buttons[index or 1]
	if entry then
		SafeCall(entry.Callback)
	end
end

--------------------------------------------------------------------------------
-- Slider
--------------------------------------------------------------------------------

local Slider = Class()

function Section:AddSlider(flag, options)
	local title
	flag, options, title = Args(flag, options)
	local slider = self:_Element(Slider, "Slider", flag, options, title, true)
	slider.Min = options.Min or 0
	slider.Max = options.Max or 100
	slider.Step = options.Increment or options.Step or (options.Rounding and 10 ^ -options.Rounding) or 1
	slider.Suffix = options.Suffix or ""
	slider.OnRelease = options.CallbackOnRelease == true
	slider.Value = math.clamp(Util.Snap(options.Default or slider.Min, slider.Step, slider.Min), slider.Min, slider.Max)

	local holder = Create("Frame", {
		Size = UDim2.new(1, 0, 0, 38),
		BackgroundTransparency = 1,
		LayoutOrder = self:_NextOrder(),
		Parent = self.Body,
	})
	slider.Holder = holder
	slider._title = Create("TextLabel", {
		Size = UDim2.new(1, -84, 0, 18),
		Text = title,
		TextSize = 13,
		Theme = { TextColor3 = "SubText" },
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = holder,
	})
	slider._box = Create("TextBox", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.fromOffset(80, 18),
		TextSize = 12,
		Weight = "MonoBold",
		TextXAlignment = Enum.TextXAlignment.Right,
		Theme = { TextColor3 = "Text" },
		Parent = holder,
	})
	slider._track = Create("Frame", {
		Position = UDim2.fromOffset(0, 27),
		Size = UDim2.new(1, 0, 0, 6),
		Theme = { BackgroundColor3 = "Track" },
		Corner = UDim.new(1, 0),
		Parent = holder,
	})
	slider._fill = Create("Frame", {
		Size = UDim2.fromScale(0, 1),
		Theme = { BackgroundColor3 = "Accent" },
		Corner = UDim.new(1, 0),
		Parent = slider._track,
	})
	slider._knob = Create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.fromOffset(14, 14),
		Theme = { BackgroundColor3 = "Knob" },
		Corner = UDim.new(1, 0),
		Stroke = { Color = "Accent", Thickness = 2 },
		Parent = slider._track,
	})
	local hit = Create("TextButton", {
		Position = UDim2.fromOffset(0, 19),
		Size = UDim2.new(1, 0, 0, 22),
		BackgroundTransparency = 1,
		Parent = holder,
	})

	hit.InputBegan:Connect(function(input)
		if input.UserInputType ~= MB1 and input.UserInputType ~= TOUCH then
			return
		end
		slider._dragging = true
		Tween(slider._knob, { Size = UDim2.fromOffset(17, 17) }, 0.15)
		slider:_FromX(input.Position.X)
		StartDrag(function(move)
			slider:_FromX(move.Position.X)
		end, function()
			slider._dragging = false
			Tween(slider._knob, { Size = UDim2.fromOffset(14, 14) }, 0.15)
			if slider.OnRelease and slider._releaseValue ~= slider.Value then
				slider._releaseValue = slider.Value
				slider:_Emit(slider.Value)
			end
		end)
	end)
	slider.Default = slider.Value
	AttachReset(slider, hit)
	hit.MouseEnter:Connect(function()
		Tween(slider._title, { TextColor3 = Library.Theme.Text })
	end)
	hit.MouseLeave:Connect(function()
		Tween(slider._title, { TextColor3 = Library.Theme.SubText })
	end)
	slider._box.FocusLost:Connect(function()
		local number = tonumber(string.match(slider._box.Text, "%-?%d+%.?%d*"))
		if number then
			slider:SetValue(number)
		end
		slider:_Render(true)
	end)
	AttachTooltip(holder, slider)

	slider._releaseValue = slider.Value
	slider:_Render(true)
	self:_Register(slider)
	RegisterOption(slider)
	return slider
end

function Slider:_FromX(x)
	local track = self._track
	local percent = math.clamp((x - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
	self:SetValue(self.Min + (self.Max - self.Min) * percent, false, true)
end

function Slider:_Render(instant)
	local range = self.Max - self.Min
	local percent = range == 0 and 0 or (self.Value - self.Min) / range
	local animate = Animate(instant or self._dragging)
	animate(self._fill, { Size = UDim2.fromScale(percent, 1) })
	animate(self._knob, { Position = UDim2.fromScale(percent, 0.5) })
	if not self._box:IsFocused() then
		self._box.Text = Util.Format(self.Value, self.Step) .. self.Suffix
	end
end

function Slider:SetValue(value, silent, instant)
	value = tonumber(value)
	if not value then
		return
	end
	value = math.clamp(Util.Snap(value, self.Step, self.Min), self.Min, self.Max)
	local changed = value ~= self.Value
	self.Value = value
	self:_Render(instant)
	if not changed then
		return
	end
	if silent then
		self:_Store()
	elseif not (self.OnRelease and self._dragging) then
		self._releaseValue = value
		self:_Emit(value)
	end
end

function Slider:SetMin(min)
	self.Min = min
	self:SetValue(math.max(self.Value, min))
	self:_Render(true)
end

function Slider:SetMax(max)
	self.Max = max
	self:SetValue(math.min(self.Value, max))
	self:_Render(true)
end

function Slider:Serialize()
	return { Type = "Slider", Value = self.Value }
end

function Slider:Deserialize(data)
	if type(data) == "table" and data.Type == "Slider" then
		self:SetValue(data.Value)
	end
end

--------------------------------------------------------------------------------
-- Input
--------------------------------------------------------------------------------

local Input = Class()

-- Label on the left, the box on the right (or full width with no title).
local function BoxedRow(section, title, height)
	local hasTitle = title ~= ""
	local holder = Create("Frame", {
		Size = UDim2.new(1, 0, 0, height),
		BackgroundTransparency = 1,
		LayoutOrder = section:_NextOrder(),
		Parent = section.Body,
	})
	local label
	if hasTitle then
		label = Create("TextLabel", {
			Size = UDim2.new(0.56, -8, 1, 0),
			Text = title,
			TextSize = 13,
			Theme = { TextColor3 = "SubText" },
			TextTruncate = Enum.TextTruncate.AtEnd,
			Parent = holder,
		})
	end
	return holder, label, hasTitle and UDim2.fromScale(0.56, 0) or UDim2.new(), hasTitle and UDim2.fromScale(0.44, 1) or UDim2.fromScale(1, 1)
end

function Section:AddInput(flag, options)
	local title
	flag, options, title = Args(flag, options)
	local input = self:_Element(Input, "Input", flag, options, title, true)
	input.Numeric = options.Numeric == true
	input.Finished = options.Finished == true
	input.MaxLength = options.MaxLength
	input.Min, input.Max = options.Min, options.Max
	if input.Numeric then
		input.Value = tonumber(options.Default) or 0
	else
		input.Value = options.Default ~= nil and tostring(options.Default) or ""
	end

	local holder, label, boxPosition, boxSize = BoxedRow(self, title, 28)
	input.Holder, input._title = holder, label
	local box = Create("Frame", {
		Position = boxPosition,
		Size = boxSize,
		Theme = { BackgroundColor3 = "Element" },
		Corner = 8,
		Stroke = { Color = "Border", Transparency = 0.5 },
		Parent = holder,
	})
	local stroke = box:FindFirstChildOfClass("UIStroke")
	input.Default = input.Value
	AttachReset(input, box)
	input._box = Create("TextBox", {
		Position = UDim2.fromOffset(12, 0),
		Size = UDim2.new(1, -24, 1, 0),
		Text = tostring(input.Value),
		PlaceholderText = options.Placeholder or "",
		TextSize = 13,
		Weight = "SemiBold",
		ClearTextOnFocus = options.ClearTextOnFocus == true,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Theme = { TextColor3 = "Text", PlaceholderColor3 = "DimText" },
		Parent = box,
	})

	input._box:GetPropertyChangedSignal("Text"):Connect(function()
		if input._setting then
			return
		end
		local text = input._box.Text
		local clean = text
		if input.Numeric then
			clean = string.gsub(clean, "[^%d%.%-]", "")
		end
		if input.MaxLength and #clean > input.MaxLength then
			clean = string.sub(clean, 1, input.MaxLength)
		end
		if clean ~= text then
			input._box.Text = clean
			return
		end
		if not input.Finished then
			input:_Commit()
		end
	end)
	input._box.Focused:Connect(function()
		Tween(stroke, { Color = Library.Theme.Accent })
	end)
	input._box.FocusLost:Connect(function()
		Tween(stroke, { Color = Library.Theme.Border })
		input:_Commit(true)
	end)
	AttachTooltip(box, input)

	self:_Register(input)
	RegisterOption(input)
	return input
end

function Input:_Commit(final)
	local text = self._box.Text
	if self.Numeric then
		local number = tonumber(text)
		if number == nil then
			if final then
				self:_Show(self.Value)
			end
			return
		end
		if self.Min then
			number = math.max(number, self.Min)
		end
		if self.Max then
			number = math.min(number, self.Max)
		end
		self:SetValue(number)
		if final then
			self:_Show(self.Value)
		end
	else
		self:SetValue(text)
	end
end

function Input:_Show(value)
	self._setting = true
	self._box.Text = tostring(value)
	self._setting = false
end

function Input:SetValue(value, silent)
	if self.Numeric then
		value = tonumber(value) or self.Value
	else
		value = tostring(value or "")
	end
	if not self._box:IsFocused() and self._box.Text ~= tostring(value) then
		self:_Show(value)
	end
	if value == self.Value then
		return
	end
	self.Value = value
	if silent then
		self:_Store()
	else
		self:_Emit(value)
	end
end

function Input:Serialize()
	return { Type = "Input", Value = self.Value }
end

function Input:Deserialize(data)
	if type(data) == "table" and data.Type == "Input" then
		self:SetValue(data.Value)
	end
end

--------------------------------------------------------------------------------
-- Dropdown
--------------------------------------------------------------------------------

local Dropdown = Class()

local function PlayerNames(excludeLocal)
	local names = {}
	for _, player in Players:GetPlayers() do
		if not (excludeLocal and player == LocalPlayer) then
			table.insert(names, player.Name)
		end
	end
	table.sort(names, function(a, b)
		return string.lower(a) < string.lower(b)
	end)
	return names
end

function Section:AddDropdown(flag, options)
	local title
	flag, options, title = Args(flag, options)
	local dropdown = self:_Element(Dropdown, "Dropdown", flag, options, title, true)
	dropdown.Multi = options.Multi == true
	dropdown.Searchable = options.Searchable ~= false and options.Search ~= false
	dropdown.AllowNull = options.AllowNull == true
	dropdown.Placeholder = options.Placeholder or "None"
	dropdown.Values = table.clone(options.Values or {})
	if options.SpecialType == "Player" then
		dropdown.Values = PlayerNames(options.ExcludeLocal)
		local function Update()
			task.defer(function()
				if not dropdown.Destroyed then
					dropdown:SetValues(PlayerNames(options.ExcludeLocal))
				end
			end)
		end
		Connect(Players.PlayerAdded, Update)
		Connect(Players.PlayerRemoving, Update)
	end
	dropdown.Value = dropdown.Multi and {} or nil

	local holder, label, boxPosition, boxSize = BoxedRow(self, title, 28)
	dropdown.Holder, dropdown._title = holder, label
	local box = Create("TextButton", {
		Position = boxPosition,
		Size = boxSize,
		Theme = { BackgroundColor3 = "Element" },
		Corner = 8,
		Stroke = { Color = "Border", Transparency = 0.5 },
		Parent = holder,
	})
	dropdown._box = box
	dropdown._stroke = box:FindFirstChildOfClass("UIStroke")
	dropdown._label = Create("TextLabel", {
		Position = UDim2.fromOffset(11, 0),
		Size = UDim2.new(1, -34, 1, 0),
		TextSize = 12,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = box,
	})
	dropdown._arrow = BindIcon(BuildIcon("chevron", 12), "SubText")
	dropdown._arrow.Frame.AnchorPoint = Vector2.new(1, 0.5)
	dropdown._arrow.Frame.Position = UDim2.new(1, -10, 0.5, 0)
	dropdown._arrow.Frame.Parent = box

	box.Activated:Connect(function()
		local popup = dropdown.Window:_Dropdown()
		if Popup.IsOpen(popup.Frame, box) then
			Popup.Close()
		else
			popup.Open(dropdown)
		end
	end)
	box.MouseEnter:Connect(function()
		Tween(box, { BackgroundColor3 = Library.Theme.Hover })
	end)
	box.MouseLeave:Connect(function()
		Tween(box, { BackgroundColor3 = Library.Theme.Element })
	end)
	AttachTooltip(box, dropdown)
	OnTheme(function()
		dropdown:_Display()
	end)

	local default = options.Default
	if default ~= nil then
		if not dropdown.Multi and type(default) == "number" and not table.find(dropdown.Values, default) then
			default = dropdown.Values[default]
		end
		dropdown:SetValue(default, true)
	end
	dropdown.Default = dropdown.Multi and table.clone(dropdown.Value) or dropdown.Value
	AttachReset(dropdown, box)
	dropdown:_Display()
	self:_Register(dropdown)
	RegisterOption(dropdown)
	return dropdown
end

function Dropdown:_IsSelected(value)
	if self.Multi then
		return self.Value[value] == true
	end
	return self.Value == value
end

function Dropdown:GetSelected()
	if not self.Multi then
		return self.Value ~= nil and { self.Value } or {}
	end
	local list, seen = {}, {}
	for _, value in self.Values do
		if self.Value[value] and not seen[value] then
			seen[value] = true
			table.insert(list, value)
		end
	end
	for value in self.Value do
		if not seen[value] then
			table.insert(list, value)
		end
	end
	return list
end

function Dropdown:_Display()
	local text
	if self.Multi then
		local selected = self:GetSelected()
		for index, value in selected do
			selected[index] = tostring(value)
		end
		if #selected > 2 then
			text = #selected .. " selected"
		elseif #selected > 0 then
			text = table.concat(selected, ", ")
		end
	elseif self.Value ~= nil then
		text = tostring(self.Value)
	end
	self._label.Text = text or self.Placeholder
	self._label.TextColor3 = text and Library.Theme.Text or Library.Theme.DimText
end

function Dropdown:_SetOpen(open)
	Tween(self._stroke, { Color = open and Library.Theme.Accent or Library.Theme.Border })
	PaintIcon(self._arrow, open and Library.Theme.AccentGlow or Library.Theme.SubText)
end

function Dropdown:SetValue(value, silent)
	if self.Multi then
		local set = {}
		if type(value) == "table" then
			for key, item in value do
				if type(key) == "number" and type(item) ~= "boolean" then
					set[item] = true
				elseif item == true then
					set[key] = true
				end
			end
		elseif value ~= nil then
			set[value] = true
		end
		self.Value = set
	else
		if value ~= nil and not table.find(self.Values, value) then
			value = nil
		end
		if value == self.Value then
			return
		end
		self.Value = value
	end
	self:_Display()
	local popup = self.Window._dropdownPopup
	if popup and popup.Current == self then
		popup.Paint()
	end
	if silent then
		self:_Store()
	else
		self:_Emit(self.Value)
	end
end

function Dropdown:_Pick(value)
	if self.Multi then
		local set = table.clone(self.Value)
		set[value] = not set[value] or nil
		self:SetValue(set)
	else
		if self.Value == value then
			if self.AllowNull then
				self:SetValue(nil)
			end
		else
			self:SetValue(value)
		end
		Popup.Close()
	end
end

function Dropdown:SetValues(values)
	self.Values = table.clone(values or {})
	if self.Multi then
		local kept, changed = {}, false
		for value in self.Value do
			if table.find(self.Values, value) then
				kept[value] = true
			else
				changed = true
			end
		end
		if changed then
			self:SetValue(kept)
		end
	elseif self.Value ~= nil and not table.find(self.Values, self.Value) then
		self:SetValue(nil)
	end
	self:_Display()
	local popup = self.Window._dropdownPopup
	if popup and popup.Current == self then
		popup.Refresh()
	end
end
Dropdown.Refresh = Dropdown.SetValues

function Dropdown:AddValue(value)
	if not table.find(self.Values, value) then
		local values = table.clone(self.Values)
		table.insert(values, value)
		self:SetValues(values)
	end
end

function Dropdown:RemoveValue(value)
	local index = table.find(self.Values, value)
	if index then
		local values = table.clone(self.Values)
		table.remove(values, index)
		self:SetValues(values)
	end
end

function Dropdown:Serialize()
	return { Type = "Dropdown", Value = self.Multi and self:GetSelected() or self.Value }
end

function Dropdown:Deserialize(data)
	if type(data) == "table" and data.Type == "Dropdown" then
		self:SetValue(data.Value)
	end
end

--------------------------------------------------------------------------------
-- Color picker
--------------------------------------------------------------------------------

local ColorPicker = Class()
local RainbowPickers = {}
local RainbowConnection

local function UpdateRainbowLoop()
	if next(RainbowPickers) and not RainbowConnection then
		local elapsed = 0
		RainbowConnection = RunService.Heartbeat:Connect(function(delta)
			elapsed += delta
			if elapsed < 1 / 30 then
				return
			end
			elapsed = 0
			local hue = (os.clock() * 0.12) % 1
			for picker in RainbowPickers do
				picker._quiet = true
				picker:SetHSV(hue, picker.Sat, picker.Val)
				picker._quiet = false
			end
		end)
	elseif not next(RainbowPickers) and RainbowConnection then
		RainbowConnection:Disconnect()
		RainbowConnection = nil
	end
end

local function NewColorPicker(section, parent, flag, options, title)
	local picker = section:_Element(ColorPicker, "ColorPicker", flag, options, title, true)
	local color = typeof(options.Default) == "Color3" and options.Default or WHITE
	picker.Hue, picker.Sat, picker.Val = color:ToHSV()
	picker.HasAlpha = type(options.Transparency) == "number"
	picker.Transparency = picker.HasAlpha and options.Transparency or 0
	picker.Value = color
	picker.Rainbow = false

	local swatch = Create("TextButton", {
		Size = UDim2.fromOffset(32, 18),
		BackgroundColor3 = color,
		Corner = 6,
		Stroke = "Border",
		LayoutOrder = 10,
		Parent = parent,
	})
	picker._swatch = swatch
	picker.Default = { color, picker.Transparency }
	AttachReset(picker, swatch)
	swatch.Activated:Connect(function()
		local popup = picker.Window:_ColorPopup()
		if Popup.IsOpen(popup.Frame, swatch) then
			Popup.Close()
		else
			popup.Open(picker)
		end
	end)
	picker:_Paint()
	RegisterOption(picker)
	return picker
end

function Section:AddColorPicker(flag, options)
	local title
	flag, options, title = Args(flag, options)
	local holder, label, slot = self:_TitleRow(title, options, 0)
	local picker = NewColorPicker(self, slot, flag, options, title)
	picker.Holder, picker._title = holder, label
	AttachReset(picker, holder)
	FitTitle(label, slot, 0)
	AttachTooltip(holder, picker)
	self:_Register(picker)
	return picker
end

function ColorPicker:_Paint()
	self._swatch.BackgroundColor3 = self.Value
	self._swatch.BackgroundTransparency = self.HasAlpha and self.Transparency * 0.85 or 0
	local popup = self.Window._colorPopup
	if popup and popup.Current == self then
		popup.Sync()
	end
end

function ColorPicker:SetHSV(hue, sat, val, transparency, silent)
	self.Hue, self.Sat, self.Val = hue, sat, val
	if transparency ~= nil then
		self.Transparency = math.clamp(transparency, 0, 1)
	end
	self.Value = Color3.fromHSV(hue, sat, val)
	self:_Paint()
	if silent then
		self:_Store()
	else
		self:_Emit(self.Value, self.Transparency)
	end
end

function ColorPicker:SetValue(color, transparency, silent)
	if typeof(color) ~= "Color3" then
		return
	end
	local hue, sat, val = color:ToHSV()
	if sat == 0 or val == 0 then
		hue = self.Hue
	end
	self:SetHSV(hue, sat, val, transparency, silent)
end
ColorPicker.SetValueRGB = ColorPicker.SetValue

function ColorPicker:SetRainbow(enabled)
	self.Rainbow = enabled == true
	RainbowPickers[self] = self.Rainbow or nil
	UpdateRainbowLoop()
	local popup = self.Window._colorPopup
	if popup and popup.Current == self then
		popup.Sync()
	end
	if self.Save then
		Library:_QueueSave()
	end
end

function ColorPicker:Serialize()
	return {
		Type = "ColorPicker",
		Hex = Util.ToHex(self.Value),
		Transparency = self.Transparency,
		Rainbow = self.Rainbow,
	}
end

function ColorPicker:Deserialize(data)
	if type(data) == "table" and data.Type == "ColorPicker" then
		local color = Util.FromHex(data.Hex)
		if color then
			self:SetValue(color, tonumber(data.Transparency))
		end
		self:SetRainbow(data.Rainbow == true)
	end
end

--------------------------------------------------------------------------------
-- Keybind
--------------------------------------------------------------------------------

local Keybind = Class()
local KeybindModes = { "Toggle", "Hold", "Always" }

local function NewKeybind(section, parent, flag, options, title)
	local keybind = section:_Element(Keybind, "Keybind", flag, options, title, not options.Internal)
	keybind.Value = KeyName(options.Default)
	keybind.Mode = table.find(KeybindModes, options.Mode) and options.Mode or "Toggle"
	keybind.State = keybind.Mode == "Always"
	keybind.Clicked = {}
	keybind.ChangedCallback = options.ChangedCallback
	keybind.Internal = options.Internal == true
	keybind.ModeLocked = options.ModeLocked == true or keybind.Internal
	keybind.Default = { keybind.Value, keybind.Mode }

	local button = Create("TextButton", {
		Size = UDim2.fromOffset(0, 22),
		AutomaticSize = Enum.AutomaticSize.X,
		Theme = { BackgroundColor3 = "Element" },
		TextSize = 11,
		Weight = "MonoBold",
		LayoutOrder = 5,
		Corner = 6,
		Stroke = { Color = "Border", Transparency = 0.5 },
		Padding = { 0, 0, 8, 8 },
		Parent = parent,
	})
	keybind._button = button
	button.Activated:Connect(function()
		if Library._binding == keybind then
			return
		end
		if Library._binding then
			Library._binding:_CancelCapture()
		end
		Library._binding = keybind
		button.Text = "..."
		button.TextColor3 = Library.Theme.AccentGlow
	end)
	button.MouseButton2Click:Connect(function()
		if keybind.ModeLocked then
			return
		end
		local items = {}
		for _, mode in KeybindModes do
			table.insert(items, {
				Text = mode,
				Checked = keybind.Mode == mode,
				Callback = function()
					keybind:SetMode(mode)
				end,
			})
		end
		keybind.Window:_Menu().Open(button, items, { Width = 110, Align = "Right", Clip = section.Column })
	end)
	OnTheme(function()
		keybind:_Render()
	end)

	keybind:_Render()
	keybind:_Map()
	table.insert(AllKeybinds, keybind)
	if keybind.Internal then
		Library.MenuKey = keybind.Value
	end
	RegisterOption(keybind)
	return keybind
end

function Section:AddKeybind(flag, options)
	local title
	flag, options, title = Args(flag, options)
	local holder, label, slot = self:_TitleRow(title, options, 0)
	local keybind = NewKeybind(self, slot, flag, options, title)
	keybind.Holder, keybind._title = holder, label
	if not keybind.Internal then
		AttachReset(keybind, holder)
	end
	FitTitle(label, slot, 0)
	AttachTooltip(holder, keybind)
	self:_Register(keybind)
	return keybind
end

function Keybind:_Render()
	local button = self._button
	if Library._binding == self then
		return
	end
	button.Text = KeyDisplay(self.Value)
	button.TextColor3 = self.Value == "None" and Library.Theme.DimText or Library.Theme.SubText
end

function Keybind:_Unmap()
	local list = self._mapped and KeyMap[self._mapped]
	local index = list and table.find(list, self)
	if index then
		table.remove(list, index)
	end
	self._mapped = nil
end

function Keybind:_Map()
	self:_Unmap()
	if self.Internal or self.Value == "None" then
		return
	end
	KeyMap[self.Value] = KeyMap[self.Value] or {}
	table.insert(KeyMap[self.Value], self)
	self._mapped = self.Value
end

function Keybind:_CancelCapture()
	if Library._binding == self then
		Library._binding = nil
	end
	self:_Render()
end

function Keybind:_Capture(input)
	local kind = input.UserInputType
	local name
	if kind == KEYBOARD then
		local code = input.KeyCode
		if code == Enum.KeyCode.Escape then
			self:_CancelCapture()
			return
		elseif code == Enum.KeyCode.Backspace or code == Enum.KeyCode.Delete then
			name = "None"
		else
			name = code.Name
		end
	elseif kind == MB2 then
		name = "MouseButton2"
	elseif kind == MB3 then
		name = "MouseButton3"
	elseif kind == MB1 or kind == TOUCH then
		self:_CancelCapture()
		return
	elseif input.KeyCode.Value ~= 0 then
		name = input.KeyCode.Name
	else
		return
	end
	Library._binding = nil
	self:SetValue(name)
end

function Keybind:SetValue(key, mode)
	key = KeyName(key)
	if self.Internal and key == "None" then
		-- Never let the menu key be cleared, or keyboard users lose the UI.
		Library:Notify({ Title = "Keybind", Content = "The interface toggle key can't be empty.", Type = "Warning" })
		key = self.Value
	end
	local changed = key ~= self.Value
	self.Value = key
	if mode then
		self:SetMode(mode)
	end
	self:_Map()
	self:_Render()
	if self.Internal then
		Library.MenuKey = key
		if Library.Window then
			Library.Window:_UpdateKeyPill()
		end
		Library:_SaveSettings()
	end
	if changed then
		if self.Flag then
			Library.Flags[self.Flag] = key
		end
		SafeCall(self.ChangedCallback, key)
		for _, callback in self.Changed do
			SafeCall(callback, key)
		end
		if self.Save then
			Library:_QueueSave()
		end
	end
	KeybindList.Refresh()
end

function Keybind:SetMode(mode)
	if not table.find(KeybindModes, mode) or mode == self.Mode then
		return
	end
	local previous = self.Mode
	self.Mode = mode
	if mode == "Always" then
		self:_Apply(true)
	elseif previous == "Always" then
		self:_Apply(false)
	end
	if self.Save then
		Library:_QueueSave()
	end
	KeybindList.Refresh()
end

function Keybind:_Apply(state)
	if self.LinkedToggle then
		self.LinkedToggle:SetValue(state)
		SafeCall(self.Callback, state)
	elseif self.State ~= state then
		self.State = state
		SafeCall(self.Callback, state)
	end
	KeybindList.Refresh()
end

function Keybind:_Press()
	for _, callback in self.Clicked do
		SafeCall(callback)
	end
	if self.Mode == "Toggle" then
		self:_Apply(not self:GetState())
	elseif self.Mode == "Hold" then
		self._held = true
		self:_Apply(true)
	end
end

function Keybind:_Release()
	if self.Mode == "Hold" and self._held then
		self._held = false
		self:_Apply(false)
	end
end

function Keybind:GetState()
	if self.LinkedToggle then
		return self.LinkedToggle.Value
	end
	return self.State
end

function Keybind:OnClick(callback)
	table.insert(self.Clicked, callback)
	return self
end

function Keybind:Serialize()
	return { Type = "Keybind", Key = self.Value, Mode = self.Mode }
end

function Keybind:Deserialize(data)
	if type(data) == "table" and data.Type == "Keybind" then
		self:SetValue(data.Key, data.Mode)
	end
end

--------------------------------------------------------------------------------
-- Toggle add-ons (keybind / color picker in the toggle's row)
--------------------------------------------------------------------------------

function Toggle:_Addon()
	if not self._slot then
		self._slot = Section._Slot(self.Holder, 44)
		FitTitle(self._title, self._slot, 44)
	end
	return self._slot
end

function Toggle:AddKeybind(flag, options)
	local title
	flag, options, title = Args(flag, options)
	if title == "" or title == flag then
		title = self.Title
	end
	local keybind = NewKeybind(self.Section, self:_Addon(), flag, options, title)
	if options.SyncToggleState ~= false then
		keybind.LinkedToggle = self
	end
	self._keybind = keybind
	return keybind
end

function Toggle:AddColorPicker(flag, options)
	local title
	flag, options, title = Args(flag, options)
	if title == "" or title == flag then
		title = self.Title .. " Color"
	end
	local picker = NewColorPicker(self.Section, self:_Addon(), flag, options, title)
	return picker
end

--------------------------------------------------------------------------------
-- Label, paragraph, divider
--------------------------------------------------------------------------------

local Label = Class()

function Section:AddLabel(text, options)
	if type(text) == "table" then
		options = text
		text = options.Text or options.Title
	end
	options = options or {}
	local label = self:_Element(Label, "Label", nil, options, tostring(text or ""), false)
	local plain = options.Style == "Plain"
	label.Holder = Create("Frame", {
		Size = UDim2.new(1, 0, 0, plain and 0 or 26),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = plain and 1 or 0,
		Theme = { BackgroundColor3 = "Inset" },
		LayoutOrder = self:_NextOrder(),
		Corner = 8,
		Padding = plain and 0 or { 6, 6, 22, 10 },
		Parent = self.Body,
	})
	if not plain then
		Create("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0, -11, 0, 7),
			Size = UDim2.fromOffset(5, 5),
			Theme = { BackgroundColor3 = options.Color or "DimText" },
			Corner = UDim.new(1, 0),
			Parent = label.Holder,
		})
	end
	label._title = Create("TextLabel", {
		Size = UDim2.new(1, 0, 0, plain and 0 or 14),
		AutomaticSize = Enum.AutomaticSize.Y,
		Text = label.Title,
		TextSize = options.TextSize or (plain and 12 or 11),
		TextWrapped = true,
		RichText = true,
		Weight = plain and "Medium" or "Mono",
		Theme = { TextColor3 = options.Color or (plain and "SubText" or "DimText") },
		Parent = label.Holder,
	})
	self:_Register(label)
	return label
end

function Label:SetText(text)
	self:SetTitle(text)
end

local Paragraph = Class()

function Section:AddParagraph(options, content)
	if type(options) ~= "table" then
		options = { Title = options, Content = content }
	end
	local paragraph = self:_Element(Paragraph, "Paragraph", nil, options, tostring(options.Title or ""), false)
	paragraph.Holder = Create("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = self:_NextOrder(),
		List = { Padding = 3 },
		Parent = self.Body,
	})
	paragraph._title = Create("TextLabel", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Text = paragraph.Title,
		TextSize = 13,
		TextWrapped = true,
		Weight = "Bold",
		Theme = { TextColor3 = "Text" },
		LayoutOrder = 1,
		Parent = paragraph.Holder,
	})
	paragraph._content = Create("TextLabel", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Text = tostring(options.Content or ""),
		TextSize = 12,
		TextWrapped = true,
		RichText = true,
		Theme = { TextColor3 = "SubText" },
		LayoutOrder = 2,
		Parent = paragraph.Holder,
	})
	paragraph.SearchText = Util.Lower(paragraph.Title .. " " .. tostring(options.Content or ""))
	self:_Register(paragraph)
	return paragraph
end

function Paragraph:SetContent(content)
	self._content.Text = tostring(content)
	self.SearchText = Util.Lower(self.Title .. " " .. tostring(content))
end

function Section:AddDivider(text)
	local divider = self:_Element(Label, "Divider", nil, {}, "", false)
	divider.Holder = Create("Frame", {
		Size = UDim2.new(1, 0, 0, text and 16 or 6),
		BackgroundTransparency = 1,
		LayoutOrder = self:_NextOrder(),
		Parent = self.Body,
	})
	Create("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.new(1, 0, 0, 1),
		Theme = { BackgroundColor3 = "Border" },
		Parent = divider.Holder,
	})
	if text then
		divider._title = Create("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(0, 16),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundTransparency = 0,
			Text = tostring(text),
			TextSize = 11,
			Weight = "SemiBold",
			Theme = { BackgroundColor3 = "Panel", TextColor3 = "DimText" },
			Padding = { 0, 0, 8, 8 },
			Parent = divider.Holder,
		})
	end
	divider.SearchText = nil
	table.insert(self.Elements, divider)
	return divider
end

Section.AddTextbox = Section.AddInput
Section.AddColorpicker = Section.AddColorPicker

--------------------------------------------------------------------------------
-- Shared popups. Each window builds these once, lazily, and every dropdown /
-- color picker / keybind reuses them, so opening one never creates instances
-- after the first time.
--------------------------------------------------------------------------------

function Window:_Menu()
	if self._menu then
		return self._menu
	end
	local window = self
	local menu = { Rows = {} }
	menu.Frame = Create("Frame", {
		Size = UDim2.fromOffset(150, 40),
		Visible = false,
		Theme = { BackgroundColor3 = "Panel" },
		Corner = 6,
		Stroke = "Border",
		Padding = { 4, 4, 4, 4 },
		List = { Padding = 2 },
		Parent = self.Overlay,
	})

	local function Row(index)
		local row = menu.Rows[index]
		if row then
			return row
		end
		row = {}
		row.Button = Create("TextButton", {
			Size = UDim2.new(1, 0, 0, 26),
			Theme = { BackgroundColor3 = "Hover" },
			BackgroundTransparency = 1,
			LayoutOrder = index,
			Corner = 5,
			Parent = menu.Frame,
		})
		row.Label = Create("TextLabel", {
			Position = UDim2.fromOffset(10, 0),
			Size = UDim2.new(1, -30, 1, 0),
			TextSize = 12,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Parent = row.Button,
		})
		row.Dot = Create("Frame", {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -10, 0.5, 0),
			Size = UDim2.fromOffset(6, 6),
			Theme = { BackgroundColor3 = "AccentGlow" },
			Corner = UDim.new(1, 0),
			Parent = row.Button,
		})
		row.Button.MouseEnter:Connect(function()
			Tween(row.Button, { BackgroundTransparency = 0 })
		end)
		row.Button.MouseLeave:Connect(function()
			Tween(row.Button, { BackgroundTransparency = 1 })
		end)
		row.Button.Activated:Connect(function()
			local callback = row.Callback
			Popup.Close()
			SafeCall(callback)
		end)
		menu.Rows[index] = row
		return row
	end

	function menu.Open(anchor, items, options)
		options = options or {}
		local theme = Library.Theme
		for index, item in items do
			local row = Row(index)
			row.Label.Text = item.Text
			row.Label.TextColor3 = item.Checked and theme.Text or theme.SubText
			SetWeight(row.Label, item.Checked and "SemiBold" or "Medium")
			row.Dot.Visible = item.Checked == true
			row.Callback = item.Callback
			row.Button.BackgroundTransparency = 1
			row.Button.Visible = true
		end
		for index = #items + 1, #menu.Rows do
			menu.Rows[index].Button.Visible = false
		end
		menu.Frame.Size = UDim2.fromOffset(options.Width or 150, #items * 28 + 6)
		Popup.Open(menu.Frame, anchor, { Window = window, Clip = options.Clip, Align = options.Align })
	end

	self._menu = menu
	return menu
end

function Window:_Dropdown()
	if self._dropdownPopup then
		return self._dropdownPopup
	end
	local window = self
	local popup = { Entries = {}, Count = 0, Current = nil, Width = 200 }
	popup.Frame = Create("Frame", {
		Size = UDim2.fromOffset(200, 100),
		Visible = false,
		Theme = { BackgroundColor3 = "Panel" },
		Corner = 6,
		Stroke = "Border",
		Parent = self.Overlay,
	})
	popup.Search = Create("Frame", {
		Position = UDim2.fromOffset(6, 6),
		Size = UDim2.new(1, -12, 0, 28),
		Theme = { BackgroundColor3 = "Element" },
		Corner = 5,
		Stroke = "Border",
		Parent = popup.Frame,
	})
	local icon = BindIcon(BuildIcon("search", 13), "DimText")
	icon.Frame.AnchorPoint = Vector2.new(0, 0.5)
	icon.Frame.Position = UDim2.new(0, 9, 0.5, 0)
	icon.Frame.Parent = popup.Search
	popup.Box = Create("TextBox", {
		Position = UDim2.fromOffset(28, 0),
		Size = UDim2.new(1, -34, 1, 0),
		PlaceholderText = "Search...",
		TextSize = 12,
		Theme = { TextColor3 = "Text", PlaceholderColor3 = "DimText" },
		Parent = popup.Search,
	})
	popup.List = Create("ScrollingFrame", {
		Position = UDim2.fromOffset(6, 40),
		Size = UDim2.new(1, -12, 0, 100),
		ScrollBarThickness = 3,
		Theme = { ScrollBarImageColor3 = "Accent" },
		List = { Padding = 2 },
		Parent = popup.Frame,
	})
	popup.Empty = Create("TextLabel", {
		Size = UDim2.new(1, 0, 0, 26),
		Text = "No results",
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Center,
		Theme = { TextColor3 = "DimText" },
		Visible = false,
		LayoutOrder = -1,
		Parent = popup.List,
	})

	local function Entry(index)
		local entry = popup.Entries[index]
		if entry then
			return entry
		end
		entry = {}
		entry.Button = Create("TextButton", {
			Size = UDim2.new(1, -4, 0, 26),
			Theme = { BackgroundColor3 = "Hover" },
			BackgroundTransparency = 1,
			LayoutOrder = index,
			Corner = 5,
			Parent = popup.List,
		})
		entry.Label = Create("TextLabel", {
			Position = UDim2.fromOffset(10, 0),
			Size = UDim2.new(1, -40, 1, 0),
			TextSize = 12,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Parent = entry.Button,
		})
		entry.Bar = Create("Frame", {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.fromScale(0, 0.5),
			Size = UDim2.fromOffset(2, 12),
			Theme = { BackgroundColor3 = "AccentGlow" },
			Corner = UDim.new(1, 0),
			Parent = entry.Button,
		})
		entry.Check = Create("Frame", {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -8, 0.5, 0),
			Size = UDim2.fromOffset(14, 14),
			Theme = { BackgroundColor3 = "Accent" },
			Corner = 4,
			Stroke = "Border",
			Parent = entry.Button,
		})
		entry.Tick = BindIcon(BuildIcon("check", 12), "OnAccent")
		entry.Tick.Frame.AnchorPoint = Vector2.new(0.5, 0.5)
		entry.Tick.Frame.Position = UDim2.fromScale(0.5, 0.5)
		entry.Tick.Frame.Parent = entry.Check
		entry.Button.MouseEnter:Connect(function()
			Tween(entry.Button, { BackgroundTransparency = 0 })
		end)
		entry.Button.MouseLeave:Connect(function()
			Tween(entry.Button, { BackgroundTransparency = 1 })
		end)
		entry.Button.Activated:Connect(function()
			if popup.Current and entry.Index then
				popup.Current:_Pick(popup.Current.Values[entry.Index])
			end
		end)
		popup.Entries[index] = entry
		return entry
	end

	function popup.Paint()
		local dropdown = popup.Current
		if not dropdown then
			return
		end
		local theme = Library.Theme
		for index = 1, popup.Count do
			local entry = popup.Entries[index]
			local selected = dropdown:_IsSelected(dropdown.Values[index])
			entry.Label.TextColor3 = selected and theme.Text or theme.SubText
			SetWeight(entry.Label, selected and "SemiBold" or "Medium")
			entry.Bar.Visible = selected and not dropdown.Multi
			entry.Check.Visible = dropdown.Multi
			entry.Check.BackgroundTransparency = selected and 0 or 1
			entry.Tick.Frame.Visible = selected
		end
	end

	function popup.Filter()
		local dropdown = popup.Current
		if not dropdown then
			return
		end
		local query = Util.Lower(Util.Trim(popup.Box.Text))
		local shown = 0
		for index = 1, popup.Count do
			local entry = popup.Entries[index]
			local visible = query == "" or string.find(entry.Lower, query, 1, true) ~= nil
			entry.Button.Visible = visible
			if visible then
				shown += 1
			end
		end
		popup.Empty.Visible = shown == 0
		local rows = math.clamp(shown, 1, 8)
		local listHeight = rows * 28 - 2
		local top = dropdown.Searchable and 40 or 6
		popup.Search.Visible = dropdown.Searchable
		popup.List.Position = UDim2.fromOffset(6, top)
		popup.List.Size = UDim2.new(1, -12, 0, listHeight)
		Popup.Resize(popup.Frame, popup.Width, top + listHeight + 6)
	end

	function popup.Refresh()
		local dropdown = popup.Current
		if not dropdown then
			return
		end
		local values = dropdown.Values
		for index, value in values do
			local entry = Entry(index)
			local text = tostring(value)
			entry.Index = index
			entry.Lower = Util.Lower(text)
			entry.Label.Text = text
		end
		for index = #values + 1, #popup.Entries do
			local entry = popup.Entries[index]
			entry.Index = nil
			entry.Button.Visible = false
		end
		popup.Count = #values
		popup.Filter()
		popup.Paint()
	end

	function popup.Open(dropdown)
		popup.Current = dropdown
		popup.Width = math.max(dropdown._box.AbsoluteSize.X / WindowScale(), 150)
		popup.Frame.Size = UDim2.fromOffset(popup.Width, 100)
		popup.Box.Text = ""
		popup.Refresh()
		popup.List.CanvasPosition = Vector2.zero
		Popup.Open(popup.Frame, dropdown._box, {
			Window = window,
			Clip = dropdown.Section.Column,
			OnClose = function()
				if popup.Current == dropdown then
					popup.Current = nil
				end
				dropdown:_SetOpen(false)
			end,
		})
		dropdown:_SetOpen(true)
		if dropdown.Searchable and #dropdown.Values > 8 and UserInputService.KeyboardEnabled then
			popup.Box:CaptureFocus()
		end
	end

	popup.Box:GetPropertyChangedSignal("Text"):Connect(popup.Filter)
	popup.Box.FocusLost:Connect(function(enter)
		local dropdown = popup.Current
		if not (enter and dropdown) then
			return
		end
		for index = 1, popup.Count do
			local entry = popup.Entries[index]
			if entry.Button.Visible then
				dropdown:_Pick(dropdown.Values[index])
				return
			end
		end
	end)
	OnTheme(popup.Paint)

	self._dropdownPopup = popup
	return popup
end

function Window:_ColorPopup()
	if self._colorPopup then
		return self._colorPopup
	end
	local window = self
	local popup = { H = 0, S = 0, V = 1, A = 0 }
	local WHEEL = 140

	popup.Frame = Create("Frame", {
		Size = UDim2.fromOffset(208, 232),
		Visible = false,
		Theme = { BackgroundColor3 = "Panel" },
		Corner = 8,
		Stroke = "Border",
		Parent = self.Overlay,
	})
	local body = Create("Frame", {
		Position = UDim2.fromOffset(12, 12),
		Size = UDim2.new(1, -24, 1, -24),
		BackgroundTransparency = 1,
		Parent = popup.Frame,
	})

	-- Hue/saturation wheel: diameter bars, each fading hue -> white -> opposite hue.
	local wheel = Create("Frame", {
		Size = UDim2.fromOffset(WHEEL, WHEEL),
		BackgroundTransparency = 1,
		Parent = body,
	})
	local bars = 60
	local barWidth = math.ceil(math.pi * WHEEL / (bars * 2)) + 2
	for index = 0, bars - 1 do
		local rotation = index * 180 / bars
		local bar = Create("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(barWidth, WHEEL),
			Rotation = rotation,
			BackgroundColor3 = WHITE,
			Parent = wheel,
		})
		Create("UIGradient", {
			Rotation = 90,
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromHSV(rotation / 360, 1, 1)),
				ColorSequenceKeypoint.new(0.5, WHITE),
				ColorSequenceKeypoint.new(1, Color3.fromHSV((rotation + 180) % 360 / 360, 1, 1)),
			}),
			Parent = bar,
		})
	end
	popup.Shade = Create("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = BLACK,
		BackgroundTransparency = 1,
		Corner = UDim.new(1, 0),
		Parent = wheel,
	})
	local rim = Create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(WHEEL - 2, WHEEL - 2),
		BackgroundTransparency = 1,
		Corner = UDim.new(1, 0),
		Parent = wheel,
	})
	Bind(Create("UIStroke", { Thickness = 4, Parent = rim }), { Color = "Panel" })
	popup.Cursor = Create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(12, 12),
		Corner = UDim.new(1, 0),
		Parent = wheel,
	})
	Create("UIStroke", { Thickness = 2, Color = WHITE, Parent = popup.Cursor })
	local wheelHit = Create("TextButton", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = wheel })

	local function VerticalBar(x)
		local bar = Create("Frame", {
			Position = UDim2.fromOffset(x, 0),
			Size = UDim2.fromOffset(12, WHEEL),
			Theme = { BackgroundColor3 = "Element" },
			Corner = UDim.new(1, 0),
			Stroke = "Border",
			Parent = body,
		})
		local fill = Create("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = WHITE,
			Corner = UDim.new(1, 0),
			Parent = bar,
		})
		local gradient = Create("UIGradient", { Rotation = 90, Parent = fill })
		local cursor = Create("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0),
			Size = UDim2.fromOffset(18, 6),
			BackgroundColor3 = WHITE,
			Corner = UDim.new(1, 0),
			Stroke = { Color = "Background", Thickness = 1 },
			ZIndex = 2,
			Parent = bar,
		})
		local hit = Create("TextButton", {
			Position = UDim2.fromOffset(-4, 0),
			Size = UDim2.new(1, 8, 1, 0),
			BackgroundTransparency = 1,
			ZIndex = 3,
			Parent = bar,
		})
		return bar, fill, gradient, cursor, hit
	end
	local _, valueFill, valueGradient, valueCursor, valueHit = VerticalBar(WHEEL + 10)
	local alphaBar, alphaFill, alphaGradient, alphaCursor, alphaHit = VerticalBar(WHEEL + 32)
	alphaGradient.Transparency = NumberSequence.new(0, 1)
	valueFill.BackgroundColor3 = WHITE

	local function Field(position, size)
		local frame = Create("Frame", {
			Position = position,
			Size = size,
			Theme = { BackgroundColor3 = "Element" },
			Corner = 5,
			Stroke = "Border",
			Parent = body,
		})
		return Create("TextBox", {
			Position = UDim2.fromOffset(6, 0),
			Size = UDim2.new(1, -12, 1, 0),
			TextSize = 12,
			Weight = "SemiBold",
			TextXAlignment = Enum.TextXAlignment.Center,
			Theme = { TextColor3 = "Text" },
			Parent = frame,
		})
	end
	local hexBox = Field(UDim2.fromOffset(0, WHEEL + 10), UDim2.new(0.42, -3, 0, 26))
	local rgbBox = Field(UDim2.new(0.42, 3, 0, WHEEL + 10), UDim2.new(0.58, -3, 0, 26))

	local actions = Create("Frame", {
		Position = UDim2.fromOffset(0, WHEEL + 42),
		Size = UDim2.new(1, 0, 0, 26),
		BackgroundTransparency = 1,
		List = { Horizontal = true, Padding = 6 },
		Parent = body,
	})
	local function Action(text, width, order)
		local button = Create("TextButton", {
			Size = UDim2.new(width, -4, 1, 0),
			Theme = { BackgroundColor3 = "Element", TextColor3 = "SubText" },
			Text = text,
			TextSize = 12,
			Weight = "SemiBold",
			LayoutOrder = order,
			Corner = 5,
			Stroke = "Border",
			Parent = actions,
		})
		button.MouseEnter:Connect(function()
			Tween(button, { BackgroundColor3 = Library.Theme.Hover })
		end)
		button.MouseLeave:Connect(function()
			Tween(button, { BackgroundColor3 = Library.Theme.Element })
		end)
		return button
	end
	local rainbowButton = Action("Rainbow", 0.4, 1)
	local copyButton = Action("Copy", 0.3, 2)
	local pasteButton = Action("Paste", 0.3, 3)

	function popup.Render()
		local color = Color3.fromHSV(popup.H, popup.S, popup.V)
		local angle = math.rad(popup.H * 360)
		local radius = popup.S * WHEEL / 2
		popup.Cursor.Position = UDim2.new(0.5, math.sin(angle) * radius, 0.5, -math.cos(angle) * radius)
		popup.Cursor.BackgroundColor3 = color
		popup.Shade.BackgroundTransparency = popup.V
		valueGradient.Color = ColorSequence.new(Color3.fromHSV(popup.H, popup.S, 1), BLACK)
		valueCursor.Position = UDim2.fromScale(0.5, 1 - popup.V)
		alphaFill.BackgroundColor3 = color
		alphaCursor.Position = UDim2.fromScale(0.5, popup.A)
		if not hexBox:IsFocused() then
			hexBox.Text = "#" .. Util.ToHex(color)
		end
		if not rgbBox:IsFocused() then
			rgbBox.Text = string.format(
				"%d, %d, %d",
				math.floor(color.R * 255 + 0.5),
				math.floor(color.G * 255 + 0.5),
				math.floor(color.B * 255 + 0.5)
			)
		end
		local rainbow = popup.Current and popup.Current.Rainbow
		rainbowButton.TextColor3 = rainbow and Library.Theme.AccentGlow or Library.Theme.SubText
	end

	function popup.Sync()
		local picker = popup.Current
		if not picker then
			return
		end
		popup.H, popup.S, popup.V, popup.A = picker.Hue, picker.Sat, picker.Val, picker.Transparency
		popup.Render()
	end

	local function Push()
		popup.Render()
		if popup.Current then
			popup.Current:SetHSV(popup.H, popup.S, popup.V, popup.A)
		end
	end

	local function FromWheel(position)
		local center = wheel.AbsolutePosition + wheel.AbsoluteSize / 2
		local dx, dy = position.X - center.X, position.Y - center.Y
		local radius = wheel.AbsoluteSize.X / 2
		popup.S = math.clamp(math.sqrt(dx * dx + dy * dy) / math.max(radius, 1), 0, 1)
		popup.H = (math.deg(math.atan2(dx, -dy)) % 360) / 360
		if popup.Current and popup.Current.Rainbow then
			popup.Current:SetRainbow(false)
		end
		Push()
	end

	local function FromBar(bar, position)
		return math.clamp((position.Y - bar.AbsolutePosition.Y) / math.max(bar.AbsoluteSize.Y, 1), 0, 1)
	end

	local function Draggable(hit, handler)
		hit.InputBegan:Connect(function(input)
			if input.UserInputType ~= MB1 and input.UserInputType ~= TOUCH then
				return
			end
			handler(input.Position)
			StartDrag(function(move)
				handler(move.Position)
			end)
		end)
	end
	Draggable(wheelHit, FromWheel)
	Draggable(valueHit, function(position)
		popup.V = 1 - FromBar(valueHit.Parent, position)
		Push()
	end)
	Draggable(alphaHit, function(position)
		popup.A = FromBar(alphaBar, position)
		Push()
	end)

	hexBox.FocusLost:Connect(function()
		local color = Util.FromHex(hexBox.Text)
		if color then
			local h, s, v = color:ToHSV()
			popup.H = (s > 0 and v > 0) and h or popup.H
			popup.S, popup.V = s, v
			Push()
		else
			popup.Render()
		end
	end)
	rgbBox.FocusLost:Connect(function()
		local r, g, b = string.match(rgbBox.Text, "(%d+)%D+(%d+)%D+(%d+)")
		if r then
			local h, s, v = rgb(math.min(tonumber(r), 255), math.min(tonumber(g), 255), math.min(tonumber(b), 255)):ToHSV()
			popup.H = (s > 0 and v > 0) and h or popup.H
			popup.S, popup.V = s, v
			Push()
		else
			popup.Render()
		end
	end)
	rainbowButton.Activated:Connect(function()
		if popup.Current then
			popup.Current:SetRainbow(not popup.Current.Rainbow)
		end
	end)
	copyButton.Activated:Connect(function()
		local picker = popup.Current
		if not picker then
			return
		end
		Library._copiedColor = { picker.Value, picker.Transparency }
		local hex = "#" .. Util.ToHex(picker.Value)
		if setclipboard then
			pcall(setclipboard, hex)
		end
		Library:Notify({ Title = "Color copied", Content = hex, Duration = 2 })
	end)
	pasteButton.Activated:Connect(function()
		local copied = Library._copiedColor
		if popup.Current and copied then
			popup.Current:SetValue(copied[1], popup.Current.HasAlpha and copied[2] or nil)
		end
	end)

	function popup.Open(picker)
		popup.Current = picker
		alphaBar.Visible = picker.HasAlpha
		popup.Frame.Size = UDim2.fromOffset(picker.HasAlpha and 208 or 186, 232)
		popup.Sync()
		Popup.Open(popup.Frame, picker._swatch, {
			Window = window,
			Clip = picker.Section.Column,
			Align = "Right",
			OnClose = function()
				if popup.Current == picker then
					popup.Current = nil
				end
			end,
		})
	end
	OnTheme(popup.Render)

	self._colorPopup = popup
	return popup
end

--------------------------------------------------------------------------------
-- Theme API
--------------------------------------------------------------------------------

-- Repaints every theme-bound instance. `animated` cross-fades colors instead
-- of snapping, which is what the light/dark switch uses.
function Library:ApplyTheme(animated)
	local fade = animated and self.Animations
	for instance, map in Registry do
		for property, key in map do
			local value = Resolve(key)
			if fade and typeof(value) == "Color3" and property ~= "PlaceholderColor3" then
				Tween(instance, { [property] = value }, 0.35, Enum.EasingStyle.Sine)
			else
				instance[property] = value
			end
		end
	end
	for _, listener in ThemeListeners do
		listener(self.Theme)
	end
end

function Library:_QueueTheme()
	if self._themeQueued then
		return
	end
	self._themeQueued = true
	task.delay(0.03, function()
		self._themeQueued = false
		if not self.Unloaded then
			self:ApplyTheme()
		end
	end)
end

function Library:GetThemes()
	return { "Dark", "Light" }
end

-- `theme` is "Dark" or "Light" (any casing).
function Library:SetTheme(theme)
	local name = type(theme) == "string" and (string.lower(theme) == "light" and "Light" or string.lower(theme) == "dark" and "Dark")
	if not name then
		return false
	end
	self.ThemeName = name
	for key, value in Palettes[name] do
		self.Theme[key] = value
	end
	self:ApplyTheme(true)
	if self._syncThemeUI then
		self._syncThemeUI()
	end
	self:_SaveSettings()
	return true
end

function Library:ToggleTheme()
	return self:SetTheme(self.ThemeName == "Dark" and "Light" or "Dark")
end

--------------------------------------------------------------------------------
-- Interface settings (theme, scale, menu key, mascot...) persist per folder in
-- settings.json, separately from configs.
--------------------------------------------------------------------------------

function Library:_SaveSettings()
	if self._settingsQueued or not self.Window then
		return
	end
	self._settingsQueued = true
	task.delay(0.5, function()
		self._settingsQueued = false
		if self.Unloaded then
			return
		end
		local root = self.Window.Root
		File.Write(self.Folder .. "/settings.json", Encode({
			Theme = self.ThemeName,
			Scale = self._savedScale and self.Scale or nil,
			Animations = self.Animations,
			MenuKey = self.MenuKey,
			Keybinds = self.ShowKeybinds,
			NotifySide = self.NotifySide,
			AutoSave = self.AutoSave,
			Mascot = self.MascotEnabled,
			MascotSpeech = self.MascotSpeech,
			MascotFollow = self.MascotFollow,
			MascotReactions = self.MascotReactions,
			Window = root and {
				X = root.Position.X.Offset,
				Y = root.Position.Y.Offset,
				W = root.Size.X.Offset,
				H = root.Size.Y.Offset,
			} or nil,
			Tab = self._lastTab,
		}) or "{}")
	end)
end

function Library:_LoadSettings()
	local data = Decode(File.Read(self.Folder .. "/settings.json"))
	if type(data) ~= "table" then
		return
	end
	if data.Theme == "Dark" or data.Theme == "Light" then
		self.ThemeName = data.Theme
	end
	if type(data.Scale) == "number" then
		self.Scale = math.clamp(data.Scale, 0.4, 2)
		self._savedScale = true
	end
	for key, field in {
		Animations = "Animations",
		Keybinds = "ShowKeybinds",
		AutoSave = "AutoSave",
		Mascot = "MascotEnabled",
		MascotSpeech = "MascotSpeech",
		MascotFollow = "MascotFollow",
		MascotReactions = "MascotReactions",
	} do
		if type(data[key]) == "boolean" then
			self[field] = data[key]
		end
	end
	if type(data.MenuKey) == "string" then
		self.MenuKey = data.MenuKey
	end
	if data.NotifySide == "Left" or data.NotifySide == "Right" then
		self.NotifySide = data.NotifySide
	end
	if type(data.Window) == "table" then
		self._savedWindow = data.Window
	end
	if type(data.Tab) == "string" then
		self._lastTab = data.Tab
	end
end

--------------------------------------------------------------------------------
-- Configs
--------------------------------------------------------------------------------

local function ConfigPath(name)
	return Library.Folder .. "/configs/" .. name .. ".json"
end

function Library:_Status()
	for _, listener in self._status do
		pcall(listener)
	end
end

function Library:GetConfigs()
	return File.ListJson(self.Folder .. "/configs")
end

function Library:_Collect()
	local flags = {}
	for flag, option in self.Options do
		if option.Save and option.Serialize and not option.Destroyed then
			local ok, value = pcall(option.Serialize, option)
			if ok then
				flags[flag] = value
			end
		end
	end
	for flag, value in self._pending do
		if flags[flag] == nil then
			flags[flag] = value
		end
	end
	return {
		Meta = { Library = "MyUI", Version = self.Version, Saved = os.date("%Y-%m-%d %H:%M:%S") },
		Flags = flags,
	}
end

function Library:ExportConfig()
	return Encode(self:_Collect())
end

function Library:SaveConfig(name, overwrite)
	name = Util.Sanitize(name)
	if name == "" then
		return false, "Enter a config name first"
	end
	if File.Exists(ConfigPath(name)) and not overwrite then
		return false, "'" .. name .. "' already exists - use Overwrite"
	end
	local encoded = self:ExportConfig()
	if not encoded then
		return false, "Could not encode the config"
	end
	if not File.Write(ConfigPath(name), encoded) then
		return false, "Could not write the config file"
	end
	self.ActiveConfig = name
	self.LastSaved = os.date("%H:%M:%S")
	self:_Status()
	return true
end

function Library:_Apply(data)
	if type(data) ~= "table" or type(data.Flags) ~= "table" then
		return false, "The config data is invalid"
	end
	self._loading = true
	for flag, value in data.Flags do
		local option = self.Options[flag]
		if option and option.Deserialize then
			local ok, err = pcall(option.Deserialize, option, value)
			if not ok then
				warn("[MyUI] failed to load '" .. tostring(flag) .. "': " .. tostring(err))
			end
		elseif not option then
			self._pending[flag] = value
		end
	end
	self._loading = false
	return true
end

function Library:LoadConfig(name)
	name = Util.Sanitize(name)
	if name == "" then
		return false, "Select a config first"
	end
	if not File.Exists(ConfigPath(name)) then
		return false, "'" .. name .. "' does not exist"
	end
	local data = Decode(File.Read(ConfigPath(name)))
	if not data then
		return false, "'" .. name .. "' is corrupted"
	end
	local ok, err = self:_Apply(data)
	if not ok then
		return false, err
	end
	self.ActiveConfig = name
	self:_Status()
	return true
end

function Library:ImportConfig(text)
	local data = Decode(text)
	if not data then
		return false, "That isn't valid config JSON"
	end
	return self:_Apply(data)
end

function Library:DeleteConfig(name)
	name = Util.Sanitize(name)
	if name == "" or not File.Exists(ConfigPath(name)) then
		return false, "Select an existing config"
	end
	if not File.Delete(ConfigPath(name)) then
		return false, "Could not delete the file"
	end
	if self.ActiveConfig == name then
		self.ActiveConfig = nil
	end
	if self:GetAutoload() == name then
		self:SetAutoload(nil)
	end
	self:_Status()
	return true
end

function Library:GetAutoload()
	if self._autoload == nil then
		local name = Util.Sanitize(File.Read(self.Folder .. "/autoload.txt") or "")
		self._autoload = name ~= "" and File.Exists(ConfigPath(name)) and name or false
	end
	return self._autoload or nil
end

function Library:SetAutoload(name)
	name = name and Util.Sanitize(name) or ""
	if name ~= "" and not File.Exists(ConfigPath(name)) then
		return false, "'" .. name .. "' does not exist"
	end
	File.Write(self.Folder .. "/autoload.txt", name)
	self._autoload = name ~= "" and name or false
	self:_Status()
	return true
end

function Library:LoadAutoloadConfig()
	if self._autoloaded then
		return false
	end
	self._autoloaded = true
	local name = self:GetAutoload()
	if not name then
		return false
	end
	local ok, err = self:LoadConfig(name)
	self:Notify({
		Title = ok and "Config loaded" or "Autoload failed",
		Content = ok and ("Autoloaded <b>" .. name .. "</b>") or err,
		Type = ok and "Success" or "Error",
	})
	return ok
end

function Library:SetAutoSave(enabled)
	self.AutoSave = enabled == true
	self:_SaveSettings()
	if self.AutoSave then
		self:_QueueSave()
	end
end

-- Autosave waits for a quiet second after the last change, so dragging a
-- slider writes the file once instead of on every step.
function Library:_QueueSave()
	if not self.AutoSave or self._loading or self.Unloaded then
		return
	end
	self._saveAt = os.clock() + 1
	if self._saveQueued then
		return
	end
	self._saveQueued = true
	task.spawn(function()
		while os.clock() < self._saveAt do
			task.wait(self._saveAt - os.clock())
		end
		self._saveQueued = false
		if self.AutoSave and not self.Unloaded then
			self:SaveConfig(self.ActiveConfig or "autosave", true)
		end
	end)
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Built-in Settings tab
--------------------------------------------------------------------------------

function Window:_BuildSettings(options)
	local window = self
	local tab = self:AddTab({
		Title = options.SettingsTitle or "Settings",
		Icon = "sliders",
		Order = 100000,
		ShowAll = false,
		IsSettings = true,
	})
	local configs = tab:AddSubTab("Configs")
	local interface = tab:AddSubTab("Interface")

	local function Report(ok, err, success)
		Library:Notify({
			Title = ok and "Done" or "Something went wrong",
			Content = ok and success or err,
			Type = ok and "Success" or "Error",
			Duration = 3,
		})
	end
	-- Configs ------------------------------------------------------------------
	local manager = configs:AddSection({ Title = "Configuration", Side = 1, Icon = "folder", Color = rgb(66, 133, 244) })
	local nameBox = manager:AddInput({ Title = "Config Name", Placeholder = "e.g. farming", Save = false })
	local list = manager:AddDropdown({ Title = "Configs", Values = Library:GetConfigs(), Save = false, Placeholder = "Select a config" })
	local function RefreshList(select)
		list:SetValues(Library:GetConfigs())
		if select then
			list:SetValue(select, true)
		end
	end
	manager:AddButton({
		Title = "Create",
		Tooltip = "Save the current settings as a new config",
		Callback = function()
			local name = Util.Sanitize(nameBox.Value)
			local ok, err = Library:SaveConfig(name, false)
			Report(ok, err, "Created <b>" .. name .. "</b>")
			if ok then
				RefreshList(name)
			end
		end,
	}):AddButton({
		Title = "Load",
		Callback = function()
			local ok, err = Library:LoadConfig(list.Value or "")
			Report(ok, err, "Loaded <b>" .. tostring(list.Value) .. "</b>")
		end,
	})
	manager:AddButton({
		Title = "Overwrite",
		Confirm = "Confirm overwrite",
		Tooltip = "Replace the selected config with the current settings",
		Callback = function()
			local name = list.Value or Util.Sanitize(nameBox.Value)
			local ok, err = Library:SaveConfig(name or "", true)
			Report(ok, err, "Overwrote <b>" .. tostring(name) .. "</b>")
			if ok then
				RefreshList(name)
			end
		end,
	}):AddButton({
		Title = "Delete",
		Confirm = "Confirm delete",
		Callback = function()
			local name = list.Value
			local ok, err = Library:DeleteConfig(name or "")
			Report(ok, err, "Deleted <b>" .. tostring(name) .. "</b>")
			RefreshList()
		end,
	})
	manager:AddButton({
		Title = "Refresh List",
		Callback = function()
			RefreshList(list.Value)
		end,
	})

	local automation = configs:AddSection({ Title = "Automation", Side = 2, Icon = "zap", Color = rgb(245, 166, 35) })
	automation:AddToggle({
		Title = "Auto Save",
		Default = Library.AutoSave,
		Save = false,
		Description = "Writes every change to the active config (or 'autosave').",
		Callback = function(value)
			Library:SetAutoSave(value)
		end,
	})
	automation:AddButton({
		Title = "Set Autoload",
		Tooltip = "Load the selected config automatically on startup",
		Callback = function()
			local name = list.Value or Library.ActiveConfig
			if not name then
				Report(false, "Select or save a config first")
				return
			end
			local ok, err = Library:SetAutoload(name)
			Report(ok, err, "<b>" .. name .. "</b> will load on startup")
		end,
	}):AddButton({
		Title = "Clear Autoload",
		Callback = function()
			Library:SetAutoload(nil)
			Report(true, nil, "Autoload cleared")
		end,
	})
	local status = automation:AddLabel("")
	local knownConfigs = table.concat(list.Values, "\0")
	local function UpdateStatus()
		-- Autosave can create files behind the user's back; keep the list current.
		local configs = Library:GetConfigs()
		local joined = table.concat(configs, "\0")
		if joined ~= knownConfigs then
			knownConfigs = joined
			list:SetValues(configs)
		end
		status:SetText(string.format(
			"Active: <b>%s</b>\nAutoload: <b>%s</b>\nLast saved: %s%s",
			Library.ActiveConfig or "none",
			Library:GetAutoload() or "none",
			Library.LastSaved or "never",
			HasFS and "" or "\n<i>File functions unavailable: configs last for this session only.</i>"
		))
	end
	table.insert(Library._status, UpdateStatus)
	UpdateStatus()

	local share = configs:AddSection({ Title = "Share", Side = 3, Icon = "code", Color = rgb(38, 186, 160) })
	share:AddButton({
		Title = "Copy Config To Clipboard",
		Callback = function()
			if not setclipboard then
				Report(false, "Your executor has no setclipboard")
				return
			end
			pcall(setclipboard, Library:ExportConfig())
			Report(true, nil, "Config JSON copied")
		end,
	})
	local importBox = share:AddInput({ Title = "Import", Placeholder = "Paste config JSON", Save = false, Finished = true })
	share:AddButton({
		Title = "Import Config",
		Callback = function()
			local ok, err = Library:ImportConfig(importBox.Value)
			Report(ok, err, "Config imported")
			if ok then
				importBox:SetValue("")
			end
		end,
	})

	-- Interface ----------------------------------------------------------------
	local look = interface:AddSection({ Title = "Appearance", Side = 1, Icon = "sun", Color = rgb(245, 166, 35) })
	local themeList = look:AddDropdown({
		Title = "Theme",
		Values = { "Dark", "Light" },
		Default = Library.ThemeName,
		Save = false,
		Searchable = false,
		Callback = function(value)
			if value and value ~= Library.ThemeName then
				Library:SetTheme(value)
			end
		end,
	})
	function Library._syncThemeUI()
		themeList:SetValue(Library.ThemeName, true)
		if window._paintThemeButton then
			window._paintThemeButton(true)
		end
	end
	look:AddSlider({
		Title = "Interface Scale",
		Min = 50,
		Max = 150,
		Increment = 5,
		Default = math.floor(Library.Scale * 100 / 5 + 0.5) * 5,
		Suffix = "%",
		Save = false,
		CallbackOnRelease = true,
		Callback = function(value)
			window:SetScale(value / 100)
		end,
	})
	look:AddToggle({
		Title = "Animations",
		Default = Library.Animations,
		Save = false,
		Callback = function(value)
			Library.Animations = value
			Library:_SaveSettings()
		end,
	})
	look:AddLabel("Tip: the moon button in the header switches themes too.")

	local menu = interface:AddSection({ Title = "Menu", Side = 2, Icon = "keyboard", Color = rgb(66, 133, 244) })
	Library._menuKeybind = menu:AddKeybind({
		Title = "Toggle Interface",
		Default = Library.MenuKey,
		Internal = true,
		Tooltip = "Click, then press a key. The header pill does the same.",
	})
	menu:AddToggle({
		Title = "Keybind List",
		Default = Library.ShowKeybinds,
		Save = false,
		Callback = function(value)
			Library:SetKeybindListVisible(value)
		end,
	})
	menu:AddDropdown({
		Title = "Notifications",
		Values = { "Right", "Left" },
		Default = Library.NotifySide,
		Save = false,
		Searchable = false,
		Callback = function(value)
			if value then
				Library.NotifySide = value
				Notifications.Place()
				Library:_SaveSettings()
			end
		end,
	})
	menu:AddButton({
		Title = "Test Notification",
		Callback = function()
			Library:Notify({ Title = "Hello!", Content = "Notifications look like this.", Type = "Success" })
		end,
	})
	menu:AddButton({
		Title = "Unload Interface",
		Confirm = "Click again to unload",
		Callback = function()
			Library:Unload()
		end,
	})

	local buddy = interface:AddSection({ Title = "Mascot", Side = 3, Icon = "heart", Color = rgb(255, 108, 146) })
	buddy:AddToggle({
		Title = "Show Mascot",
		Default = Library.MascotEnabled,
		Save = false,
		Callback = function(value)
			window:SetMascotVisible(value)
		end,
	})
	buddy:AddToggle({
		Title = "Speech Bubbles",
		Default = Library.MascotSpeech,
		Save = false,
		Callback = function(value)
			Library.MascotSpeech = value
			Library:_SaveSettings()
		end,
	})
	buddy:AddToggle({
		Title = "Follow Cursor",
		Default = Library.MascotFollow,
		Save = false,
		Callback = function(value)
			Library.MascotFollow = value
			if not value and window.Mascot then
				window.Mascot:Look(window.Mascot.Stage.AbsolutePosition + Vector2.new(62, 300))
			end
			Library:_SaveSettings()
		end,
	})
	buddy:AddToggle({
		Title = "React To Toggles",
		Default = Library.MascotReactions,
		Save = false,
		Callback = function(value)
			Library.MascotReactions = value
			Library:_SaveSettings()
		end,
	})
	buddy:AddButton({
		Title = "Say Something",
		Callback = function()
			window:Say(Pick(MascotLines.Click), nil, "Blush")
		end,
	})
	buddy:AddLabel("Click her to make her blush. Hold to pat. Don't poke too much.")

	local about = interface:AddSection({ Title = "About", Side = 3, Icon = "info", Color = rgb(140, 100, 240) })
	local executor = "Unknown"
	if identifyexecutor then
		local ok, name, version = pcall(identifyexecutor)
		if ok and name then
			executor = tostring(name) .. (version and (" " .. tostring(version)) or "")
		end
	end
	about:AddParagraph({
		Title = "MyUI v" .. Library.Version,
		Content = string.format(
			"Executor: %s\nFile system: %s\nPlace ID: %s\nConfig folder: %s",
			executor,
			HasFS and "available" or "session only",
			tostring(game.PlaceId),
			Library.Folder
		),
	})

	self.SettingsTab = tab
	return tab
end

-- Lifetime
--------------------------------------------------------------------------------

function Library:OnUnload(callback)
	table.insert(self._unload, callback)
end

function Library:Toggle(state)
	if self.Window then
		self.Window:Toggle(state)
	end
end

function Library:Unload()
	if self.Unloaded then
		return
	end
	if self._saveQueued and self.AutoSave then
		self:SaveConfig(self.ActiveConfig or "autosave", true)
	end
	Popup.Close()
	self.Unloaded = true
	for _, callback in self._unload do
		task.spawn(pcall, callback)
	end
	for _, connection in self.Connections do
		connection:Disconnect()
	end
	table.clear(self.Connections)
	if RainbowConnection then
		RainbowConnection:Disconnect()
		RainbowConnection = nil
	end
	table.clear(RainbowPickers)
	table.clear(KeyMap)
	table.clear(ThemeListeners)
	table.clear(Registry)
	table.clear(FontRegistry)
	self._binding = nil
	if ScreenGui then
		ScreenGui:Destroy()
		ScreenGui = nil
	end
end

return Library
