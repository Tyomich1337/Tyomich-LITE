local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local previousUnload = rawget(_G, "LUMIN_ADMIN_UNLOAD")
if type(previousUnload) == "function" then
	pcall(previousUnload)
end

for _, oldGui in ipairs(playerGui:GetChildren()) do
	if oldGui:IsA("ScreenGui")
		and oldGui.Name == "LuminAdminPanel"
	then
		pcall(function()
			oldGui:Destroy()
		end)
	end
end

local npcFolder = Workspace:FindFirstChild("_NPCS_")

if not npcFolder then
	npcFolder = Instance.new("Folder")
	npcFolder.Name = "__LUMIN_EMPTY_NPCS"
end

local assetsRoot = ReplicatedStorage:FindFirstChild("Assets")
local npcRenderAssets =
	assetsRoot
	and assetsRoot:FindFirstChild("_NPC_SYSTEM_RENDER_ASSETS_")
	or nil

if not npcRenderAssets then
	npcRenderAssets = Instance.new("Folder")
	npcRenderAssets.Name = "__LUMIN_EMPTY_RENDER_ASSETS"
end

local S = {
    shluhaBuild = true,
    liteBuild = true,
    modelPreviewsEnabled = false,
    uiAnimationsEnabled = false,
    audio = {groups={}, rebind=nil},
	playerCameraMode = player.CameraMode,
	playerCameraMinZoom = player.CameraMinZoomDistance,
	playerCameraMaxZoom = player.CameraMaxZoomDistance,
	panelToggleKey = Enum.KeyCode.G,
	uiToggleKey = Enum.KeyCode.F8,
	waitingForUiBind = false,
	waitingForPanelBind = false,
	morphRegistry = {},
	animationContainers = {},
	morphDirty = true,
	cameraDirty = true,
	lastMorphScan = 0,
	lastCameraScan = 0,

	cameraNpcEntries = {},
	cameraNpcButtons = {},
	cameraNpcSignature = "",
	selectedCameraNpcKey = nil,
	spectateActive = false,
	spectateTarget = nil,

	freecamActive = false,
	freecamSpeed = 36,
	freecamSmoothness = 0,
	freecamVelocity = Vector3.zero,
	freecamYaw = 0,
	freecamPitch = 0,
	freecamLookHeld = false,
	freecamSavedType = nil,
	freecamSavedSubject = nil,
	freecamCFrame = nil,

	cameraPriority = Enum.RenderPriority.Last.Value,
	cameraFightFrames = 0,
	thirdHardOverride = false,
	cameraRenderBound = false,
	lastCameraUiMode = "",
	thirdDistance = 12,
	thirdYaw = 0,
	thirdPitch = math.rad(-10),
	thirdLookHeld = false,

	spectateRoot = nil,
	spectateDistance = 10,
	spectateRenderedDistance = nil,
	spectateYaw = 0,
	spectatePitch = math.rad(-8),
	spectateLookHeld = false,
	spectatePivotOffset = Vector3.zero,
	spectateRadius = 4,
	spectateMouseSensitivity = 0.0055,

	activeVisualTarget = nil,
	activeVisualParts = {},
	activeVisualFollowers = {},

	uiEntries = {},
	uiButtons = {},
	uiHidden = {},
	uiOriginal = {},
	uiSignature = "",
	uiDirty = true,
	uiLastScan = 0,
	uiMaxRendered = 350,

	unloading = false,
	allUiHidden = false,

	morphRunState = false,
	morphLastDriverState = "",
	morphLastDriverSpeed = 0,
	morphDriverIdleSpeed = 0.45,
	morphDriverRunEnter = 12.5,
	morphDriverRunExit = 7.5,

	morphPoseBones = {},
	morphPoseMotors = {},
	morphAnimatorGuard = nil,
	morphDescendantGuard = nil,
	morphBlockedTags = {},
	morphTagConnections = {},
	morphForeignTrackWarnings = 0,
	morphNeutralIdle = false,

	moveWalkSpeed = 16,
	moveAcceleration = false,
	moveStartSpeed = 16,
	moveMaxSpeed = 90,
	moveRampTime = 3,
	moveRampElapsed = 0,
	moveSpeedFov = false,
	moveFovThreshold = 25,
	moveFovBoost = 20,
	moveJumpValue = 50,
	moveFlySpeed = 50,
	moveFly = false,
	moveNoclip = false,
	moveInfiniteJump = false,
	moveLockStats = false,
	moveFlyConnection = nil,
	moveNoclipConnection = nil,
	moveNoclipOriginal = {},
	moveSavedCharacter = nil,
	moveOriginalWalkSpeed = nil,
	moveOriginalJumpPower = nil,
	moveOriginalJumpHeight = nil,
	moveOriginalUseJumpPower = nil,
	moveOriginalFov = nil,

	spectateAutoFollow = false,
	spectateFollowSmooth = 6.5,
	spectateFollowCFrame = nil,

	rootConnections = {},

	activeSliderSetFromX = nil,
}
S.economyMode=false
pcall(function()
    if type(readfile)=="function" and type(isfile)=="function" and isfile("TyomichLiteSettings.json") then
        local raw=readfile("TyomichLiteSettings.json")
        if #raw<=8192 then local settings=HttpService:JSONDecode(raw);S.economyMode=type(settings)=="table" and settings.economyMode==true end
    end
end)


function ugKeepRootConnection(connection)
	if typeof(connection) == "RBXScriptConnection" then
		table.insert(S.rootConnections, connection)
	end

	return connection
end

function ugDisconnectRootConnections()
	for _, connection in ipairs(S.rootConnections) do
		if typeof(connection) == "RBXScriptConnection"
			and connection.Connected
		then
			pcall(function()
				connection:Disconnect()
			end)
		end
	end

	table.clear(S.rootConnections)
	S.activeSliderSetFromX = nil
end

S.rootConnections[#S.rootConnections + 1] =
	UserInputService.InputChanged:Connect(function(input)
		local setter = S.activeSliderSetFromX

		if setter
			and input.UserInputType == Enum.UserInputType.MouseMovement
		then
			setter(input.Position.X)
		end
	end)

S.rootConnections[#S.rootConnections + 1] =
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			S.activeSliderSetFromX = nil
		end
	end)

local MORPH_RUN_SPEED = 13
local MORPH_YAW_DEGREES = 0

local MORPH_OFFSET_MIN = -10
local MORPH_OFFSET_MAX = 10
local MORPH_OFFSET_STEP = 0.1

local CAMERA_MIN_ZOOM = 2.5
local CAMERA_MAX_ZOOM_MIN = 10
local CAMERA_MAX_ZOOM_MAX = 150
local CAMERA_MAX_ZOOM_STEP = 1
local cameraMaxZoom = 100
local thirdPerson = false

local morphModel = nil
local morphRoot = nil
local morphAnimator = nil
local morphTracks = {}
local morphCurrentTrack = nil
local morphCurrentState = nil
local morphActiveName = nil

local selectedMorphName = nil
local morphNames = {}
local morphButtons = {}
local morphListSignature = ""

local customMorphSources = {}
local customMorphMeta = {}
local customAssetIdToName = {}
local selectedCustomMorphName = nil

local selectedAnimationNpcName = nil
local animationNpcButtons = {}
local animationListSignature = ""
local animationBinds = {}
local animationBindModes = {}
local waitingForAnimationBind = nil
local manualAnimationTrack = nil
local manualAnimationName = nil
local manualAnimationNpcName = nil
local manualStopConnection = nil

local morphOffsets = {}

local hiddenPartLTM = {}
local hiddenPartTransparency = {}
local hiddenPartCastShadow = {}
local hiddenTransparency = {}
local hiddenEnabled = {}
local hiddenVisible = {}

local activeTab = "Morph"

local selectMorph

local CAMERA_BIND_NAME = "LuminAdminThirdPerson"
local MOUSE_BIND_NAME = "LuminAdminMouse"
local MORPH_BIND_NAME = "LuminAdminMorph"

S.FREECAM_BIND_NAME = "LuminAdminUniversalFreecam"
S.SPECTATE_BIND_NAME = "LuminAdminUniversalSpectate"

RunService:UnbindFromRenderStep(CAMERA_BIND_NAME)
RunService:UnbindFromRenderStep(S.FREECAM_BIND_NAME)
RunService:UnbindFromRenderStep(S.SPECTATE_BIND_NAME)
RunService:UnbindFromRenderStep(MOUSE_BIND_NAME)
RunService:UnbindFromRenderStep(MORPH_BIND_NAME)

function S.controlledCharacter()
    if S.soul and S.soul.active and S.soul.actor and S.soul.actor.Parent then return S.soul.actor end
    return player.Character
end

local COL = {
	bg = Color3.fromRGB(17, 20, 27),
	panel = Color3.fromRGB(20, 24, 32),
	panel2 = Color3.fromRGB(25, 30, 40),
	titlebar = Color3.fromRGB(14, 17, 23),
	sidebar = Color3.fromRGB(19, 23, 31),
	button = Color3.fromRGB(34, 41, 54),
	buttonHover = Color3.fromRGB(45, 57, 75),
	buttonSelected = Color3.fromRGB(36, 66, 88),
	accent = Color3.fromRGB(100, 196, 228),
	green = Color3.fromRGB(42, 78, 93),
	gold = Color3.fromRGB(42, 58, 76),
	blue = Color3.fromRGB(37, 62, 82),
	purple = Color3.fromRGB(37, 62, 82),
	text = Color3.fromRGB(235, 241, 248),
	subtext = Color3.fromRGB(168, 181, 199),
	dim = Color3.fromRGB(125, 141, 162),
	stroke = Color3.fromRGB(59, 73, 91),
	slider = Color3.fromRGB(49, 63, 82),
}

if S.shluhaBuild and not S.liteBuild then
    COL.bg=Color3.fromRGB(19,18,25)
    COL.panel=Color3.fromRGB(27,24,33)
    COL.panel2=Color3.fromRGB(35,29,42)
    COL.titlebar=Color3.fromRGB(25,19,29)
    COL.sidebar=Color3.fromRGB(25,22,32)
    COL.button=Color3.fromRGB(48,37,53)
    COL.buttonHover=Color3.fromRGB(73,48,64)
    COL.buttonSelected=Color3.fromRGB(116,57,53)
    COL.accent=Color3.fromRGB(255,154,104)
    COL.green=Color3.fromRGB(37,92,85)
    COL.gold=Color3.fromRGB(116,70,42)
    COL.blue=Color3.fromRGB(49,70,88)
    COL.purple=Color3.fromRGB(76,51,89)
    COL.stroke=Color3.fromRGB(83,62,82)
    COL.slider=Color3.fromRGB(110,72,82)
end

local oldGui = playerGui:FindFirstChild("LuminAdminPanel")
if oldGui then
	oldGui:Destroy()
end

for _, child in ipairs(Workspace:GetChildren()) do
	if child:IsA("Model") and string.sub(child.Name, 1, 14) == "__LOCAL_MORPH_" then
		child:Destroy()
	end
end

function corner(parent, radius)
	local item = Instance.new("UICorner")
	item.CornerRadius = UDim.new(0, radius or 8)
	item.Parent = parent
	return item
end

function stroke(parent, color, transparency, thickness)
	local item = Instance.new("UIStroke")
	item.Color = color or COL.stroke
	item.Transparency = transparency or 0
	item.Thickness = thickness or 1
	item.Parent = parent
	return item
end

function makeLabel(parent, text, size, position, textSize, color, font)
	local label = Instance.new("TextLabel")
	label.Size = size
	label.Position = position or UDim2.new()
	label.BackgroundTransparency = 1
	label.Text = text or ""
	label.TextColor3 = color or COL.text
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.Font = font or Enum.Font.Gotham
	label.TextSize = textSize or 13
	label.Parent = parent
	return label
end

S.uiTweens = setmetatable({}, {__mode = "k"})
function S.animateUi(object, properties, duration)
	local previous = S.uiTweens[object]
	if previous then previous:Cancel() end
	if S.economyMode or S.uiAnimationsEnabled == false then
		S.uiTweens[object] = nil
		for property, value in pairs(properties) do object[property] = value end
		return
	end
	local tween = game:GetService("TweenService"):Create(object, TweenInfo.new(duration or 0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), properties)
	S.uiTweens[object] = tween
	tween.Completed:Once(function()
		if S.uiTweens[object] == tween then S.uiTweens[object] = nil end
	end)
	tween:Play()
end

function S.styleSwitch(button)
	if not string.match(button.Text, ": ON$") and not string.match(button.Text, ": OFF$") then return end
	local caption = makeLabel(button, "", UDim2.new(1, -62, 1, 0), UDim2.fromOffset(10, 0), 10, COL.text, Enum.Font.GothamMedium)
	caption.TextTruncate = Enum.TextTruncate.AtEnd
	local track = Instance.new("Frame")
	track.Size = UDim2.fromOffset(34, 18)
	track.Position = UDim2.new(1, -44, 0.5, -9)
	track.BorderSizePixel = 0
	track.Parent = button
	corner(track, 9)
	local dot = Instance.new("Frame")
	dot.Size = UDim2.fromOffset(12, 12)
	dot.BackgroundColor3 = COL.text
	dot.BorderSizePixel = 0
	dot.Parent = track
	corner(dot, 6)
	local function update()
		local enabled = string.match(button.Text, ": ON$") ~= nil or string.match(button.Text, ": HARD$") ~= nil
		local text = button.Text:gsub(": ON$", ""):gsub(": OFF$", ""):gsub(": HARD$", "")
		local names = {FREECAM = "Free camera", ["AUTO FOLLOW"] = "Auto follow", ["Cutscene protection"] = "Camera protection", ["Color correction"] = "Color grading"}
		caption.Text = names[text] or text
		button.TextTransparency = 1
		S.animateUi(track, {BackgroundColor3 = enabled and COL.accent or COL.stroke})
		S.animateUi(dot, {Position = UDim2.fromOffset(enabled and 19 or 3, 3)})
	end
	button:GetPropertyChangedSignal("Text"):Connect(update)
	update()
end

S.npcCards = {}
function S.makeNpcCard(button, name, detail, source)
	button.Size = UDim2.new(1, -4, 0, 104)
	button.Text = ""
	local border = stroke(button, COL.stroke, 0.45, 1)
	local preview = Instance.new("ViewportFrame")
	preview.Size = UDim2.fromOffset(84, 84)
	preview.Position = UDim2.fromOffset(10, 10)
	preview.BackgroundColor3 = COL.panel
	preview.BorderSizePixel = 0
	preview.Ambient = Color3.fromRGB(190, 190, 205)
	preview.LightColor = Color3.fromRGB(255, 245, 230)
	preview.LightDirection = Vector3.new(-1, -1, -1)
	preview.Active = false
	preview.Parent = button
	corner(preview, 8)
	local placeholder = makeLabel(button, "3D", UDim2.fromOffset(84, 84), UDim2.fromOffset(10, 10), 12, COL.dim)
	placeholder.TextXAlignment = Enum.TextXAlignment.Center
	local title = makeLabel(button, (S.localModelLabels and S.localModelLabels[name]) or name, UDim2.new(1, -116, 0, 38), UDim2.fromOffset(104, 12), 12, COL.text, Enum.Font.GothamBold)
	title.TextWrapped = true
	title.TextTruncate = Enum.TextTruncate.AtEnd
	local subtitle = makeLabel(button, detail, UDim2.new(1, -116, 0, 20), UDim2.fromOffset(104, 53), 9, COL.subtext)
	subtitle.TextTruncate = Enum.TextTruncate.AtEnd
	local action = makeLabel(button, "", UDim2.new(1, -116, 0, 18), UDim2.fromOffset(104, 76), 9, COL.accent, Enum.Font.GothamBold)
    if button.Parent:GetAttribute("CompactCards") then
        preview.Size = UDim2.fromOffset(56,56); preview.Position = UDim2.fromOffset(8,8)
        placeholder.Size = preview.Size; placeholder.Position = preview.Position
        title.Position = UDim2.fromOffset(72,8); title.Size = UDim2.new(1,-80,0,36); title.TextSize = 11
        subtitle.Position = UDim2.fromOffset(8,68); subtitle.Size = UDim2.new(1,-16,0,16)
        action.Position = UDim2.fromOffset(72,46); action.Size = UDim2.new(1,-80,0,18)
    end
	local function selected()
		local active = button:GetAttribute("Selected") == true
		action.Text = active and "SELECTED" or "SELECT  →"
		S.animateUi(border, {Color = active and COL.accent or COL.stroke, Transparency = active and 0 or 0.45})
	end
	button:GetAttributeChangedSignal("Selected"):Connect(selected)
	selected()
	S.npcCards[button] = {viewport = preview, placeholder = placeholder, source = source, title = title}
	if S.economyMode or S.modelPreviewsEnabled==false then
        preview.Visible=false;placeholder.Visible=false
        S.npcCards[button].titleHome={title.Position,title.Size}
        title.Position=UDim2.fromOffset(8,8);title.Size=UDim2.new(1,-48,0,38)
    end
    button.Destroying:Connect(function() S.npcCards[button] = nil end)
end

function S.cleanDetachedVisualClone(clone)
	assert(clone.Parent == nil, "Visual copy must be detached before cleanup")
	local collection = game:GetService("CollectionService")
	local objects = clone:GetDescendants()
	table.insert(objects, 1, clone)
	local function internal(value)
		return value == nil or value == clone or value:IsDescendantOf(clone)
	end
	for _, object in ipairs(objects) do
		for _, tag in ipairs(collection:GetTags(object)) do collection:RemoveTag(object, tag) end
		for attribute in pairs(object:GetAttributes()) do object:SetAttribute(attribute, nil) end
		if object:IsA("ObjectValue") and not internal(object.Value) then object.Value = nil end
		if object:IsA("JointInstance") or object:IsA("WeldConstraint") then
			if not internal(object.Part0) then object.Part0 = nil end
			if not internal(object.Part1) then object.Part1 = nil end
		elseif object:IsA("Constraint") then
			pcall(function()
				if not internal(object.Attachment0) then object.Attachment0 = nil end
				if not internal(object.Attachment1) then object.Attachment1 = nil end
			end)
		end
	end
end

function S.buildNpcPreview(card)
	if S.economyMode or S.modelPreviewsEnabled == false then return end
	local source = card.source
	if type(source) == "function" then
		local ok, result = pcall(source)
		source = ok and result or nil
	end
	if not source or not source:IsA("Model") or not source.Parent then
		card.placeholder.Text = "No model"
		return
	end
	if #source:GetDescendants() > 1800 then
		card.placeholder.Text = "Complex\nmodel"
		return
	end
	local archivable = source.Archivable
	local ok, clone = pcall(function()
		source.Archivable = true
		return source:Clone()
	end)
	pcall(function() source.Archivable = archivable end)
	if not ok or not clone then card.placeholder.Text = "No preview" return end
	local world
	local camera
	local success = pcall(function()
		S.cleanDetachedVisualClone(clone)
		for _, object in ipairs(clone:GetDescendants()) do
			if object:IsA("LuaSourceContainer") or object:IsA("Sound") or object:IsA("ParticleEmitter") or object:IsA("Trail") or object:IsA("Beam") or object:IsA("LayerCollector") then
				object:Destroy()
			elseif object:IsA("BasePart") then
				object.Anchored = true
				object.CanCollide = false
				object.CanTouch = false
				object.CanQuery = false
			elseif object:IsA("Humanoid") then
				object.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
			end
		end
		if not clone:FindFirstChildWhichIsA("BasePart", true) then error("No geometry") end
		clone:PivotTo(CFrame.new())
		local cf, size = clone:GetBoundingBox()
		world = Instance.new("WorldModel")
		clone.Parent = world
		camera = Instance.new("Camera")
		camera.FieldOfView = 35
		local root = clone:FindFirstChild("HumanoidRootPart", true) or clone.PrimaryPart
		local forward = root and root:IsA("BasePart") and root.CFrame.LookVector or Vector3.new(0, 0, -1)
		local direction = (forward + Vector3.new(0.25, 0.12, 0)).Unit
		local radius = math.max(size.Magnitude * 0.5, 0.5)
		local distance = radius / math.sin(math.rad(17.5)) * 1.08
		camera.CFrame = CFrame.lookAt(cf.Position + direction * distance, cf.Position)
		camera.Parent = card.viewport
		world.Parent = card.viewport
		card.viewport.CurrentCamera = camera
	end)
	if not success then
		clone:Destroy()
		if world then world:Destroy() end
		if camera then camera:Destroy() end
		card.placeholder.Text = "No preview"
		return
	end
	card.loaded = true
	card.placeholder.Visible = false
	card.viewport.ImageTransparency = 1
	S.animateUi(card.viewport, {ImageTransparency = 0}, 0.18)
end

function S.updateNpcPreviews()
	local loaded = 0
	local candidate
	for button, card in pairs(S.npcCards) do
		local previews = not S.economyMode and S.modelPreviewsEnabled ~= false
		card.viewport.Visible = previews
		card.placeholder.Visible = previews and not card.loaded
		if not card.titleHome then card.titleHome = {card.title.Position, card.title.Size} end
		card.title.Position = previews and card.titleHome[1] or UDim2.fromOffset(8,8)
		card.title.Size = previews and card.titleHome[2] or UDim2.new(1,button:FindFirstChild("MorphFavorite") and -48 or -16,0,38)
		local visible = button.Parent ~= nil
		local ancestor = button
		while visible and ancestor do
			if ancestor:IsA("GuiObject") and not ancestor.Visible then visible = false end
            if ancestor:IsA("ScrollingFrame") then
                visible = visible and button.AbsolutePosition.Y + button.AbsoluteSize.Y > ancestor.AbsolutePosition.Y and button.AbsolutePosition.Y < ancestor.AbsolutePosition.Y + ancestor.AbsoluteSize.Y
            end
			ancestor = ancestor.Parent
		end
		local scroll = button.Parent
		if visible and scroll and scroll:IsA("ScrollingFrame") then
			visible = button.AbsolutePosition.Y + button.AbsoluteSize.Y > scroll.AbsolutePosition.Y
				and button.AbsolutePosition.Y < scroll.AbsolutePosition.Y + scroll.AbsoluteSize.Y
		end
		if not previews or not visible or (card.loaded and loaded >= (S.modelPreviewLimit or 8)) then
			if card.loaded then
				card.viewport.CurrentCamera = nil
				for _, child in ipairs(card.viewport:GetChildren()) do
					if child:IsA("WorldModel") or child:IsA("Camera") then child:Destroy() end
				end
				card.loaded = false
				card.attempted = nil
				card.placeholder.Visible = previews
			end
		elseif card.loaded then
			loaded += 1
		elseif not card.attempted and not candidate then
			candidate = card
		end
	end
	if candidate and loaded < (S.modelPreviewLimit or 8) then
		candidate.attempted = true
		S.buildNpcPreview(candidate)
	end
end

S.actionCallbacks=setmetatable({},{__mode="k"})
S.sliderActions=setmetatable({},{__mode="k"})
function S.connectAction(button,callback)
    S.workspaceActionsDirty=true
    local connection=button.MouseButton1Click:Connect(callback)
    local list=S.actionCallbacks[button]
    if not list then
        list={};S.actionCallbacks[button]=list
        button.Destroying:Connect(function() S.actionCallbacks[button]=nil end)
    end
    table.insert(list,{callback=callback,connection=connection})
    return connection
end
function makeButton(parent, text, size, position, normalColor)
	local button = Instance.new("TextButton")
	button.Size = size
	button.Position = position or UDim2.new()
	button.BackgroundColor3 = normalColor or COL.button
	button.BorderSizePixel = 0
	button.AutoButtonColor = false
	button.Text = text
	button:SetAttribute("ActionTitle",text)
	button.TextColor3 = COL.text
	button.Font = Enum.Font.GothamMedium
	button.TextSize = 13
	button.Parent = parent
	corner(button, 7)

	local function updateContrast()
		local c = button.BackgroundColor3
		local brightness = c.R * 0.2126 + c.G * 0.7152 + c.B * 0.0722
		button.TextColor3 = brightness > 0.55 and COL.bg or COL.text
	end
	button:GetPropertyChangedSignal("BackgroundColor3"):Connect(updateContrast)
	updateContrast()

	local baseColor = button.BackgroundColor3

	button.MouseEnter:Connect(function()
		if not button:GetAttribute("Selected") then
			S.animateUi(button, {BackgroundColor3 = COL.buttonHover})
		end
	end)

	button.MouseLeave:Connect(function()
		if button:GetAttribute("Selected") then
			S.animateUi(button, {BackgroundColor3 = COL.buttonSelected})
		else
			S.animateUi(button, {BackgroundColor3 = baseColor})
		end
	end)

	S.styleSwitch(button)
	if S.shluhaBuild and not S.liteBuild then
		local pressScale=Instance.new("UIScale")
		pressScale.Parent=button
		button.MouseButton1Down:Connect(function() S.animateUi(pressScale,{Scale=0.965},0.09) end)
		button.MouseButton1Up:Connect(function() S.animateUi(pressScale,{Scale=1},0.19) end)
		button.MouseLeave:Connect(function() S.animateUi(pressScale,{Scale=1},0.19) end)
	end
	return button
end

function makeSection(parent, titleText, position, size)
	local frame = Instance.new("Frame")
	frame:SetAttribute("SectionTitle",titleText)
	frame.Size = size
	frame.Position = position
	frame.BackgroundColor3 = COL.panel2
	frame.BorderSizePixel = 0
	frame.Parent = parent
	corner(frame, 10)
	stroke(frame, COL.stroke, 0.35, 1)

	local title = makeLabel(
		frame,
		titleText,
		UDim2.new(1, -24, 0, 24),
		UDim2.new(0, 12, 0, 8),
		12,
		COL.subtext,
		Enum.Font.GothamBold
	)

	return frame, title
end

local gui = Instance.new("ScreenGui")
gui.Name = "LuminAdminPanel"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui
_G.LUMIN_ADMIN_GUI = gui

local main = Instance.new("Frame")
main.Name = "Main"
main.Size = UDim2.new(0, 900, 0, 620)
main.Position = UDim2.new(0.5, -450, 0.5, -310)
main.BackgroundColor3 = COL.bg
main.BorderSizePixel = 0
main.Visible = false
main.Parent = gui
corner(main, 14)
stroke(main, COL.accent, 0.45, 1)

local titlebar = Instance.new("Frame")
titlebar.Size = UDim2.new(1, 0, 0, 44)
titlebar.BackgroundColor3 = COL.titlebar
titlebar.BorderSizePixel = 0
titlebar.Parent = main
corner(titlebar, 14)

local titleFix = Instance.new("Frame")
titleFix.Size = UDim2.new(1, 0, 0, 14)
titleFix.Position = UDim2.new(0, 0, 1, -14)
titleFix.BackgroundColor3 = COL.titlebar
titleFix.BorderSizePixel = 0
titleFix.Parent = titlebar

local title = makeLabel(
	titlebar,
	"Tyomich Admin",
	UDim2.new(1, -110, 1, 0),
	UDim2.new(0, 16, 0, 0),
	16,
	COL.text,
	Enum.Font.GothamBold
)

local subtitle = makeLabel(
	titlebar,
	"local tools",
	UDim2.new(0, 90, 1, 0),
	UDim2.new(0, 132, 0, 1),
	10,
	COL.dim,
	Enum.Font.Gotham
)

local closeButton = makeButton(
	titlebar,
	"×",
	UDim2.new(0, 32, 0, 28),
	UDim2.new(1, -42, 0, 8),
	Color3.fromRGB(34, 24, 27)
)
closeButton.TextSize = 18

local sidebar = Instance.new("Frame")
sidebar.Size = UDim2.new(0, 150, 1, -44)
sidebar.Position = UDim2.new(0, 0, 0, 44)
sidebar.BackgroundColor3 = COL.sidebar
sidebar.BorderSizePixel = 0
sidebar.Parent = main

local sideTitle = makeLabel(
	sidebar,
	"SECTIONS",
	UDim2.new(1, -24, 0, 22),
	UDim2.new(0, 12, 0, 16),
	10,
	COL.dim,
	Enum.Font.GothamBold
)

local content = Instance.new("Frame")
content.Size = UDim2.new(1, -150, 1, -44)
content.Position = UDim2.new(0, 150, 0, 44)
content.BackgroundTransparency = 1
content.Parent = main

local pages = {}
local tabButtons = {}

function createPage(name)
	local page = Instance.new((name == "Morph" or name == "NpcMorph" or name == "Soul" or name == "Btools" or name == "AutoRecord" or name == "Kill" or name == "DeathScene" or name == "Horror" or name == "Insert" or name == "BuildSave" or name == "Avatar") and "ScrollingFrame" or "Frame")
	if page:IsA("ScrollingFrame") then page.BorderSizePixel = 0; page.ScrollBarThickness = 7; page.CanvasSize = UDim2.fromOffset(0, 1500) end
	page.Name = name .. "Page"
	page.Size = UDim2.new(1, 0, 1, 0)
	page.BackgroundTransparency = 1
	page.Visible = false
	page.Parent = content
	pages[name] = page
	return page
end

function selectTab(name)
	if name=="Custom" then name="Morph" end
	activeTab = name
	if S.refreshNavigation then S.refreshNavigation(name) end
	if S.layoutNpcMorphTools then S.layoutNpcMorphTools(name) end

	for tabName, page in pairs(pages) do
		page.Visible = (tabName == name)
		if page.Visible then
			page.Position = UDim2.fromOffset(S.shluhaBuild and 22 or 6, 0)
			S.animateUi(page, {Position = UDim2.fromOffset(0, 0)}, S.shluhaBuild and 0.26 or 0.12)
		end
	end

	for tabName, button in pairs(tabButtons) do
		local selected = (tabName == name)
		button:SetAttribute("Selected", selected)
		button.BackgroundColor3 = selected and COL.buttonSelected or COL.button
		button.TextColor3 = selected and COL.text or COL.subtext
	end

	if name == "UI"
		and ugScanUi
	then
		S.uiDirty = true
		ugScanUi(true)

		if ugRefreshDiagnosticsUi then
			ugRefreshDiagnosticsUi()
		end

	elseif name == "Camera"
		and ugScanCameraNpcs
	then
		S.cameraDirty = true
		ugScanCameraNpcs(not S.economyMode)

	elseif name == "Morph"
		and ugScanMorphs
	then
		S.morphDirty = true
		ugScanMorphs(not S.economyMode)

		if rebuildMorphList then
			rebuildMorphList(true)
		end

	elseif name == "Sounds" and S.refreshSoundTargets then
		S.refreshSoundTargets()

	elseif name == "NpcMorph" and S.refreshNpcMorphList then
		S.refreshNpcMorphList(not S.economyMode)

	elseif name == "Animations"
		and ugScanMorphs
	then
		S.morphDirty = true
		ugScanMorphs(not S.economyMode)

		if rebuildAnimationNpcList then
			rebuildAnimationNpcList(true)
		end
	end
end

function createTabButton(name, text, y)
	local button = makeButton(
		sidebar,
		text,
		UDim2.new(1, -20, 0, 38),
		UDim2.new(0, 10, 0, y),
		COL.button
	)

	button.TextXAlignment = Enum.TextXAlignment.Left
	button.Text = "   " .. text
	button.TextColor3 = COL.subtext
	tabButtons[name] = button

	S.connectAction(button,function()
		selectTab(name)
	end)

	return button
end

createTabButton("Morph", "Morph", 46)
createTabButton("Animations", "Animations", 92)
createTabButton("Camera", "Camera", 184)
createTabButton("UI", "UI", 230)
createTabButton("Movement", "Movement", 276)

S.unloadButton = makeButton(
	sidebar,
	"UNLOAD SCRIPT",
	UDim2.new(1, -20, 0, 36),
	UDim2.new(0, 10, 1, -50),
	Color3.fromRGB(50, 27, 31)
)
S.unloadButton.TextSize = 9
S.unloadButton.Font = Enum.Font.GothamBold

S.panelBindButton = makeButton(
	sidebar,
	"Panel key: G",
	UDim2.new(1, -20, 0, 32),
	UDim2.new(0, 10, 1, -125),
	COL.button
)
S.panelBindButton.TextSize = 10

local sideHint = makeLabel(
	sidebar,
	"G — panel",
	UDim2.new(1, -24, 0, 18),
	UDim2.new(0, 12, 1, -90),
	10,
	COL.dim,
	Enum.Font.Gotham
)

local sideHint2 = makeLabel(
	sidebar,
	"drag the header",
	UDim2.new(1, -24, 0, 18),
	UDim2.new(0, 12, 1, -70),
	9,
	COL.dim,
	Enum.Font.Gotham
)
local morphPage = createPage("Morph")
S.animationPlaybackSpeed = 1
S.animationClockReal = os.clock()
S.animationClockValue = 0
function S.animationClock()
	return S.animationClockValue + (os.clock()-S.animationClockReal)*S.animationPlaybackSpeed
end
function S.setAnimationPlaybackSpeed(value)
	S.animationClockValue = S.animationClock()
	S.animationClockReal = os.clock()
	S.animationPlaybackSpeed = math.clamp(value, 0.25, 10)
	local function adjust(track)
		if track then pcall(function() track:AdjustSpeed(S.animationPlaybackSpeed) end) end
	end
	adjust(morphCurrentTrack)
	adjust(manualAnimationTrack)
	adjust(v144RuntimeCurrentTrack)
	if S.npcMorphBatch then
		for _, record in pairs(S.npcMorphBatch.records) do adjust(record.track) end
	end

end
S.animationSpeeds = {}
function S.getClipSpeed(npcName, animationName)
	local entries = S.animationSpeeds[npcName or ""]
	return entries and entries[string.lower(animationName or "")] or 1
end
function S.activateClipSpeed(npcName, animationName)
	S.speedNpc = npcName
	S.speedClip = string.lower(animationName or "")
	S.setAnimationPlaybackSpeed(S.getClipSpeed(npcName, animationName))
end
function S.saveClipSpeed(npcName, animationName, value)
	local key = string.lower(animationName)
	S.animationSpeeds[npcName] = S.animationSpeeds[npcName] or {}
	S.animationSpeeds[npcName][key] = math.clamp(value, 0.25, 10)
	if morphActiveName == npcName and S.speedNpc == npcName and S.speedClip == key then
		S.setAnimationPlaybackSpeed(S.animationSpeeds[npcName][key])
	end
end
local animationsPage = createPage("Animations")
local cameraPage = createPage("Camera")
S.uiPage = createPage("UI")
S.movementPage = createPage("Movement")

function roundToStep(value, step)
	if step <= 0 then
		return value
	end
	return math.floor((value / step) + 0.5) * step
end

function createSlider(parent, labelText, minValue, maxValue, step, defaultValue, y, callback)
	local holder = Instance.new("Frame")
	holder.Size = UDim2.new(1, -24, 0, 54)
	holder.Position = UDim2.new(0, 12, 0, y)
	holder.BackgroundTransparency = 1
	holder.Parent = parent

	local label = makeLabel(
		holder,
		labelText,
		UDim2.new(0.5, 0, 0, 20),
		UDim2.new(0, 0, 0, 0),
		11,
		COL.subtext,
		Enum.Font.GothamMedium
	)

	local valueLabel = makeLabel(
		holder,
		"0",
		UDim2.new(0.5, 0, 0, 20),
		UDim2.new(0.5, 0, 0, 0),
		11,
		COL.text,
		Enum.Font.GothamBold
	)
	valueLabel.TextXAlignment = Enum.TextXAlignment.Right

	local track = Instance.new("Frame")
	track.Size = UDim2.new(1, 0, 0, 8)
	track.Position = UDim2.new(0, 0, 0, 34)
	track.BackgroundColor3 = COL.slider
	track.BorderSizePixel = 0
	track.Parent = holder
	corner(track, 4)

	local fill = Instance.new("Frame")
	fill.Size = UDim2.new(0, 0, 1, 0)
	fill.BackgroundColor3 = COL.accent
	fill.BorderSizePixel = 0
	fill.Parent = track
	corner(fill, 4)

	local knob = Instance.new("Frame")
	knob.Size = UDim2.new(0, 16, 0, 16)
	knob.AnchorPoint = Vector2.new(0.5, 0.5)
	knob.Position = UDim2.new(0, 0, 0.5, 0)
	knob.BackgroundColor3 = COL.text
	knob.BorderSizePixel = 0
	knob.Parent = track
	corner(knob, 8)

	local value = defaultValue

	local slider = {}

	local function formatValue(v)
		if step < 0.1 then
			return string.format("%.2f", v)
		elseif step < 1 then
			return string.format("%.1f", v)
		end
		return tostring(math.floor(v + 0.5))
	end

	local function setValue(newValue, fireCallback)
		newValue = math.clamp(newValue, minValue, maxValue)
		newValue = roundToStep(newValue, step)
		newValue = math.clamp(newValue, minValue, maxValue)
		value = newValue

		local alpha = 0
		if maxValue ~= minValue then
			alpha = (value - minValue) / (maxValue - minValue)
		end

		fill.Size = UDim2.new(alpha, 0, 1, 0)
		knob.Position = UDim2.new(alpha, 0, 0.5, 0)
		valueLabel.Text = formatValue(value)

		if fireCallback ~= false and callback then
			callback(value)
		end
	end

	local function setFromInputX(x)
		local width = track.AbsoluteSize.X
		if width <= 0 then
			return
		end

		local alpha = math.clamp(
			(x - track.AbsolutePosition.X) / width,
			0,
			1
		)

		local newValue = minValue + (maxValue - minValue) * alpha
		setValue(newValue, true)
	end

	track.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			S.activeSliderSetFromX = setFromInputX
			setFromInputX(input.Position.X)
		end
	end)

	knob.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			S.activeSliderSetFromX = setFromInputX
			setFromInputX(input.Position.X)
		end
	end)

	slider.SetValue = setValue
	slider.GetValue = function()
		return value
	end
	holder.Destroying:Connect(function() S.sliderActions[holder]=nil end)
	S.workspaceActionsDirty=true
	S.sliderActions[holder]={title=labelText,set=setValue,get=function() return value end,min=minValue,max=maxValue}
	slider.Holder = holder
	slider.ValueLabel = valueLabel

	setValue(defaultValue, false)

	return slider
end

local morphHeader = makeLabel(
	morphPage,
	"Local morph",
	UDim2.new(1, -40, 0, 32),
	UDim2.new(0, 24, 0, 20),
	20,
	COL.text,
	Enum.Font.GothamBold
)

local morphDesc = makeLabel(
	morphPage,
	"Select an NPC. Your original appearance is hidden only on your client.",
	UDim2.new(1, -48, 0, 24),
	UDim2.new(0, 24, 0, 54),
	11,
	COL.subtext,
	Enum.Font.Gotham
)

local morphListSection = makeSection(
	morphPage,
	"ALL MORPHS",
	UDim2.new(0, 24, 0, 88),
	UDim2.new(0, 250, 1, -112)
)

local morphSearch = Instance.new("TextBox")
morphSearch.Size = UDim2.new(1, -24, 0, 34)
morphSearch.Position = UDim2.new(0, 12, 0, 38)
morphSearch.BackgroundColor3 = COL.panel
morphSearch.BorderSizePixel = 0
morphSearch.ClearTextOnFocus = false
morphSearch.PlaceholderText = "Search..."
morphSearch.PlaceholderColor3 = COL.dim
morphSearch.Text = ""
morphSearch.TextColor3 = COL.text
morphSearch.TextXAlignment = Enum.TextXAlignment.Left
morphSearch.Font = Enum.Font.Gotham
morphSearch.TextSize = 12
morphSearch.Parent = morphListSection
corner(morphSearch, 7)

local morphSearchPadding = Instance.new("UIPadding")
morphSearchPadding.PaddingLeft = UDim.new(0, 10)
morphSearchPadding.PaddingRight = UDim.new(0, 10)
morphSearchPadding.Parent = morphSearch

local morphScroll = Instance.new("ScrollingFrame")
morphScroll.Size = UDim2.new(1, -24, 1, -86)
morphScroll.Position = UDim2.new(0, 12, 0, 78)
morphScroll.BackgroundTransparency = 1
morphScroll.BorderSizePixel = 0
morphScroll.ScrollBarThickness = 4
morphScroll.ScrollBarImageColor3 = COL.dim
morphScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
morphScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
morphScroll.Parent = morphListSection

local morphLayout = Instance.new("UIListLayout")
morphLayout.Padding = UDim.new(0, 5)
morphLayout.SortOrder = Enum.SortOrder.LayoutOrder
morphLayout.Parent = morphScroll

local morphDetails = makeSection(
	morphPage,
	"SETTINGS",
	UDim2.new(0, 292, 0, 88),
	UDim2.new(1, -316, 1, -112)
)

local selectedMorphLabel = makeLabel(
	morphDetails,
	"Not selected",
	UDim2.new(1, -24, 0, 30),
	UDim2.new(0, 12, 0, 38),
	16,
	COL.text,
	Enum.Font.GothamBold
)

local selectedAnimLabel = makeLabel(
	morphDetails,
	"Animations: —",
	UDim2.new(1, -24, 0, 20),
	UDim2.new(0, 12, 0, 68),
	10,
	COL.subtext,
	Enum.Font.Gotham
)

local morphApplyButton = makeButton(
	morphDetails,
	"APPLY MORPH",
	UDim2.new(0.62, -6, 0, 38),
	UDim2.new(0, 12, 0, 96),
	COL.purple
)
morphApplyButton.Font = Enum.Font.GothamBold

local morphRemoveButton = makeButton(
	morphDetails,
	"REMOVE",
	UDim2.new(0.38, -18, 0, 38),
	UDim2.new(0.62, 6, 0, 96),
	Color3.fromRGB(74, 42, 49)
)

local offsetTitle = makeLabel(
	morphDetails,
	"MORPH POSITION",
	UDim2.new(1, -24, 0, 20),
	UDim2.new(0, 12, 0, 150),
	10,
	COL.dim,
	Enum.Font.GothamBold
)

local morphOffsetX = 0
local morphOffsetY = 0
local morphOffsetZ = 0

function getOffsetForName(name)
	if not name then
		return Vector3.new(0, 0, 0)
	end
	return morphOffsets[name] or Vector3.new(0, 0, 0)
end

function saveSelectedOffset()
	if not selectedMorphName then
		return
	end

	morphOffsets[selectedMorphName] = Vector3.new(
		morphOffsetX,
		morphOffsetY,
		morphOffsetZ
	)
end

local xSlider = createSlider(
	morphDetails,
	"X",
	MORPH_OFFSET_MIN,
	MORPH_OFFSET_MAX,
	MORPH_OFFSET_STEP,
	0,
	174,
	function(value)
		morphOffsetX = value
		saveSelectedOffset()
	end
)

local ySlider = createSlider(
	morphDetails,
	"Y  (height)",
	MORPH_OFFSET_MIN,
	MORPH_OFFSET_MAX,
	MORPH_OFFSET_STEP,
	0,
	228,
	function(value)
		morphOffsetY = value
		saveSelectedOffset()
	end
)

local zSlider = createSlider(
	morphDetails,
	"Z",
	MORPH_OFFSET_MIN,
	MORPH_OFFSET_MAX,
	MORPH_OFFSET_STEP,
	0,
	282,
	function(value)
		morphOffsetZ = value
		saveSelectedOffset()
	end
)

local resetOffsetButton = makeButton(
	morphDetails,
	"RESET X / Y / Z",
	UDim2.new(1, -24, 0, 34),
	UDim2.new(0, 12, 0, 346),
	COL.button
)

local morphStatusLabel = makeLabel(
	morphDetails,
	"Active morph: off",
	UDim2.new(1, -24, 0, 24),
	UDim2.new(0, 12, 1, -38),
	11,
	COL.subtext,
	Enum.Font.GothamMedium
)

local animationsHeader = makeLabel(
	animationsPage,
	"NPC animations",
	UDim2.new(1, -40, 0, 32),
	UDim2.new(0, 24, 0, 20),
	20,
	COL.text,
	Enum.Font.GothamBold
)

local animationsDesc = makeLabel(
	animationsPage,
	"ONCE plays once. LOOP toggles looping. Walk/Run are selected by speed.",
	UDim2.new(1, -48, 0, 24),
	UDim2.new(0, 24, 0, 54),
	11,
	COL.subtext,
	Enum.Font.Gotham
)

local animationNpcSection = makeSection(
	animationsPage,
	"NPC",
	UDim2.new(0, 24, 0, 88),
	UDim2.new(0, 190, 1, -112)
)

local animationNpcScroll = Instance.new("ScrollingFrame")
animationNpcScroll.Size = UDim2.new(1, -24, 1, -52)
animationNpcScroll.Position = UDim2.new(0, 12, 0, 40)
animationNpcScroll.BackgroundTransparency = 1
animationNpcScroll.BorderSizePixel = 0
animationNpcScroll.ScrollBarThickness = 4
animationNpcScroll.ScrollBarImageColor3 = COL.dim
animationNpcScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
animationNpcScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
animationNpcScroll.Parent = animationNpcSection

local animationNpcLayout = Instance.new("UIListLayout")
animationNpcLayout.Padding = UDim.new(0, 5)
animationNpcLayout.SortOrder = Enum.SortOrder.LayoutOrder
animationNpcLayout.Parent = animationNpcScroll

local animationDetailsSection = makeSection(
	animationsPage,
	"ANIMATIONS",
	UDim2.new(0, 230, 0, 88),
	UDim2.new(1, -254, 1, -112)
)

local animationSelectedNpcLabel = makeLabel(
	animationDetailsSection,
	"NPC: —",
	UDim2.new(1, -164, 0, 26),
	UDim2.new(0, 12, 0, 38),
	15,
	COL.text,
	Enum.Font.GothamBold
)

local stopManualAnimationButton = makeButton(
	animationDetailsSection,
	"STOP ANIMATION",
	UDim2.new(0, 140, 0, 30),
	UDim2.new(1, -152, 0, 36),
	Color3.fromRGB(74, 42, 49)
)

local animationHintLabel = makeLabel(
	animationDetailsSection,
	"Bind: click the bind button, then press a key. Esc cancels; Backspace/Delete clears.",
	UDim2.new(1, -24, 0, 34),
	UDim2.new(0, 12, 0, 70),
	9,
	COL.dim,
	Enum.Font.Gotham
)
animationHintLabel.TextWrapped = true
animationHintLabel.TextYAlignment = Enum.TextYAlignment.Top

local animationRunThresholdSlider = createSlider(
	animationDetailsSection,
	"RUN starts at speed",
	4,
	40,
	0.5,
	S.morphDriverRunEnter,
	104,
	function(value)
		S.morphDriverRunEnter = value

		S.morphDriverRunExit =
			math.max(
				S.morphDriverIdleSpeed + 0.1,
				value - 3
			)
	end
)

local animationScroll = Instance.new("ScrollingFrame")
animationScroll.Size = UDim2.new(1, -24, 1, -182)
animationScroll.Position = UDim2.new(0, 12, 0, 168)
animationScroll.BackgroundTransparency = 1
animationScroll.BorderSizePixel = 0
animationScroll.ScrollBarThickness = 4
animationScroll.ScrollBarImageColor3 = COL.dim
animationScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
animationScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
animationScroll.Parent = animationDetailsSection

local animationLayout = Instance.new("UIListLayout")
animationLayout.Padding = UDim.new(0, 5)
animationLayout.SortOrder = Enum.SortOrder.LayoutOrder
animationLayout.Parent = animationScroll

S.moveHeader = makeLabel(
	S.movementPage,
	"Movement",
	UDim2.new(1, -40, 0, 32),
	UDim2.new(0, 24, 0, 20),
	20,
	COL.text,
	Enum.Font.GothamBold
)

S.moveDesc = makeLabel(
	S.movementPage,
	"Local movement tools: speed, jump, fly, noclip, infinite jump and FOV.",
	UDim2.new(1, -48, 0, 24),
	UDim2.new(0, 24, 0, 54),
	11,
	COL.subtext,
	Enum.Font.Gotham
)

S.moveStatsSection = makeSection(
	S.movementPage,
	"SPEED / JUMP",
	UDim2.new(0, 24, 0, 92),
	UDim2.new(0, 330, 0, 274)
)

S.moveStatsScroll = Instance.new("ScrollingFrame")
S.moveStatsScroll.Size = UDim2.new(1, 0, 1, -34)
S.moveStatsScroll.Position = UDim2.new(0, 0, 0, 34)
S.moveStatsScroll.BackgroundTransparency = 1
S.moveStatsScroll.BorderSizePixel = 0
S.moveStatsScroll.ScrollBarThickness = 4
S.moveStatsScroll.CanvasSize = UDim2.fromOffset(0, 640)
S.moveStatsScroll.Parent = S.moveStatsSection

S.moveWalkSlider = createSlider(
	S.moveStatsScroll,
	"WalkSpeed",
	4,
	120,
	1,
	S.moveWalkSpeed,
	8,
	function(value)
		S.moveWalkSpeed = value
		ugApplyMovementStats()
	end
)

S.moveJumpSlider = createSlider(
	S.moveStatsScroll,
	"JumpPower / Height",
	10,
	160,
	2,
	S.moveJumpValue,
	68,
	function(value)
		S.moveJumpValue = value
		ugApplyMovementStats()
	end
)

S.moveLockButton = makeButton(
	S.moveStatsScroll,
	"LOCK VALUES: OFF",
	UDim2.new(1, -24, 0, 36),
	UDim2.new(0, 12, 0, 132),
	COL.button
)
S.moveLockButton.TextSize = 10

S.moveResetButton = makeButton(
	S.moveStatsScroll,
	"RESET MOVEMENT",
	UDim2.new(1, -24, 0, 36),
	UDim2.new(0, 12, 0, 178),
	COL.accent
)
S.moveResetButton.TextSize = 10

S.moveFlySection = makeSection(
	S.movementPage,
	"FLY / NOCLIP",
	UDim2.new(0, 366, 0, 92),
	UDim2.new(1, -390, 0, 274)
)

S.moveFlyButton = makeButton(
	S.moveFlySection,
	"FLY: OFF",
	UDim2.new(1, -24, 0, 38),
	UDim2.new(0, 12, 0, 40),
	COL.purple
)
S.moveFlyButton.Font = Enum.Font.GothamBold

S.moveFlySpeedSlider = createSlider(
	S.moveFlySection,
	"Fly speed",
	10,
	200,
	5,
	S.moveFlySpeed,
	94,
	function(value)
		S.moveFlySpeed = value
	end
)

S.moveNoclipButton = makeButton(
	S.moveFlySection,
	"NOCLIP: OFF",
	UDim2.new(0.5, -18, 0, 38),
	UDim2.new(0, 12, 0, 164),
	COL.button
)
S.moveNoclipButton.TextSize = 10

S.moveInfiniteJumpButton = makeButton(
	S.moveFlySection,
	"INF JUMP: OFF",
	UDim2.new(0.5, -18, 0, 38),
	UDim2.new(0.5, 6, 0, 164),
	COL.button
)
S.moveInfiniteJumpButton.TextSize = 10

S.moveFlyHint = makeLabel(
	S.moveFlySection,
	"Fly: WASD · Q/E down/up · Shift boost. Noclip affects only your character.",
	UDim2.new(1, -24, 0, 44),
	UDim2.new(0, 12, 0, 216),
	9,
	COL.dim,
	Enum.Font.Gotham
)
S.moveFlyHint.TextWrapped = true
S.moveFlyHint.TextYAlignment = Enum.TextYAlignment.Top

S.moveExtraSection = makeSection(
	S.movementPage,
	"EXTRAS",
	UDim2.new(0, 24, 0, 382),
	UDim2.new(1, -48, 0, 144)
)

S.moveFovSlider = createSlider(
	S.moveExtraSection,
	"Field of View",
	40,
	120,
	1,
	70,
	42,
	function(value)
		local camera = Workspace.CurrentCamera

		if camera then
			if S.moveOriginalFov == nil then
				S.moveOriginalFov =
					camera.FieldOfView
			end

			if S.moveSpeedFovCamera == camera then S.moveSpeedFovBase = value end
			camera.FieldOfView = value
		end
	end
)

S.moveExtraHint = makeLabel(
	S.moveExtraSection,
	"LOCK VALUES periodically reapplies WalkSpeed/Jump if the game resets them.",
	UDim2.new(1, -24, 0, 30),
	UDim2.new(0, 12, 0, 100),
	9,
	COL.dim,
	Enum.Font.Gotham
)
S.moveExtraHint.TextWrapped = true
function ugGetMovementCharacter()
	local character = S.controlledCharacter()

	if not character then
		return nil, nil, nil
	end

	local humanoid =
		character:FindFirstChildOfClass(
			"Humanoid"
		)

	local root =
		character:FindFirstChild(
			"HumanoidRootPart"
		)
		or character:FindFirstChild(
			"RootPart"
		)

	if root
		and not root:IsA("BasePart")
	then
		root = nil
	end

	return character, humanoid, root
end

function ugCaptureMovementDefaults()
	local character, humanoid =
		ugGetMovementCharacter()

	if not character
		or not humanoid
	then
		return
	end

	if S.moveSavedCharacter
		== character
	then
		return
	end

	S.moveSavedCharacter = character
	S.moveOriginalWalkSpeed =
		humanoid.WalkSpeed
	S.moveOriginalJumpPower =
		humanoid.JumpPower
	S.moveOriginalJumpHeight =
		humanoid.JumpHeight
	S.moveOriginalUseJumpPower =
		humanoid.UseJumpPower

	if S.moveWalkSpeed == 16 then
		S.moveWalkSpeed =
			humanoid.WalkSpeed
	end

	if S.moveJumpValue == 50 then
		if humanoid.UseJumpPower then
			S.moveJumpValue =
				humanoid.JumpPower
		else
			S.moveJumpValue =
				math.clamp(
					humanoid.JumpHeight
						/
						7.2
						*
						50,
					10,
					160
				)
		end
	end
end

function ugApplyMovementStats()
	local _, humanoid =
		ugGetMovementCharacter()

	if not humanoid then
		return
	end

	ugCaptureMovementDefaults()

	pcall(function()
		humanoid.WalkSpeed =
			(S.speedSwap and S.speedSwap.active and S.speedSwap.value or (S.moveAcceleration and (S.moveRampSpeed or math.min(S.moveStartSpeed, S.moveMaxSpeed)) or S.moveWalkSpeed))
	end)

	pcall(function()
		if humanoid.UseJumpPower then
			humanoid.JumpPower =
				S.moveJumpValue
		else
			humanoid.JumpHeight =
				math.max(
					1,
					S.moveJumpValue
						/
						50
						*
						7.2
				)
		end
	end)
end

function ugMovementJumpVelocity()
	local _, humanoid =
		ugGetMovementCharacter()

	if humanoid then
		if humanoid.UseJumpPower then
			return
				math.max(
					20,
					S.moveJumpValue
				)
		end

		local height =
			math.max(
				1,
				S.moveJumpValue
					/
					50
					*
					7.2
			)

		return
			math.sqrt(
				2
					*
					Workspace.Gravity
					*
					height
			)
	end

	return S.moveJumpValue
end

function ugUpdateMovementButtons()
	if S.moveFlyButton then
		S.moveFlyButton.Text =
			S.moveFly
			and "FLY: ON"
			or "FLY: OFF"

		S.moveFlyButton.BackgroundColor3 =
			S.moveFly
			and COL.purple
			or COL.button
	end

	if S.moveNoclipButton then
		S.moveNoclipButton.Text =
			S.moveNoclip
			and "NOCLIP: ON"
			or "NOCLIP: OFF"
	end

	if S.moveInfiniteJumpButton then
		S.moveInfiniteJumpButton.Text =
			S.moveInfiniteJump
			and "INF JUMP: ON"
			or "INF JUMP: OFF"
	end

	if S.moveLockButton then
		S.moveLockButton.Text =
			S.moveLockStats
			and "LOCK VALUES: ON"
			or "LOCK VALUES: OFF"
	end
end

function S.clearFlyActuator()
    if S.flyVelocity then S.flyVelocity:Destroy();S.flyVelocity=nil end
    if S.flyAttachment then S.flyAttachment:Destroy();S.flyAttachment=nil end
    S.flyRoot=nil
end
function ugStopFly()
    S.clearFlyActuator()
	S.moveFly = false

	if S.moveFlyConnection then
		S.moveFlyConnection:Disconnect()
		S.moveFlyConnection = nil
	end

	local _, humanoid, root =
		ugGetMovementCharacter()

	if root then
		pcall(function()
			root.AssemblyLinearVelocity =
				Vector3.zero
		end)
	end

	if humanoid then
		pcall(function()
			humanoid:ChangeState(
				Enum.HumanoidStateType.GettingUp
			)
		end)
	end

	ugUpdateMovementButtons()
end

function ugStartFly()
	if S.moveFly then
		return
	end

	S.moveFly = true

	if S.moveFlyConnection then
		S.moveFlyConnection:Disconnect()
	end

	S.moveFlyConnection =
		RunService.PreSimulation:Connect(
			function()
				if not S.moveFly then
					return
				end

				local _, humanoid, root =
					ugGetMovementCharacter()

				local camera =
					Workspace.CurrentCamera

				if not root
					or not camera
                    or (humanoid and humanoid.Health<=0)
				then
					S.clearFlyActuator()
					return
				end

				local cf =
					camera.CFrame

				local movement =
					Vector3.zero

				if UserInputService:IsKeyDown(
					Enum.KeyCode.W
				) then
					movement += cf.LookVector
				end

				if UserInputService:IsKeyDown(
					Enum.KeyCode.S
				) then
					movement -= cf.LookVector
				end

				if UserInputService:IsKeyDown(
					Enum.KeyCode.D
				) then
					movement += cf.RightVector
				end

				if UserInputService:IsKeyDown(
					Enum.KeyCode.A
				) then
					movement -= cf.RightVector
				end

				if UserInputService:IsKeyDown(
					Enum.KeyCode.E
				) then
					movement += Vector3.yAxis
				end

				if UserInputService:IsKeyDown(
					Enum.KeyCode.Q
				) then
					movement -= Vector3.yAxis
				end

				local speed =
					S.moveFlySpeed

				if UserInputService:IsKeyDown(
					Enum.KeyCode.LeftShift
				)
					or UserInputService:IsKeyDown(
						Enum.KeyCode.RightShift
					)
				then
					speed *= 2
				end

				local velocity =
					Vector3.zero
				if UserInputService:GetFocusedTextBox() or (S.soul and S.soul.active and S.soul.trip) then movement=Vector3.zero end

				if movement.Magnitude > 0.001 then
					velocity =
						movement.Unit
						*
						speed
				end

                if S.flyRoot~=root or not S.flyVelocity or not S.flyVelocity.Parent then
                    S.clearFlyActuator()
                    local attachment=Instance.new("Attachment");attachment.Name="TyomichFlyAttachment";attachment.Parent=root
                    local actuator=Instance.new("LinearVelocity");actuator.Name="TyomichFlyVelocity";actuator.Attachment0=attachment
                    actuator.RelativeTo=Enum.ActuatorRelativeTo.World;actuator.VelocityConstraintMode=Enum.VelocityConstraintMode.Vector
                    actuator.ForceLimitsEnabled=false;actuator.VectorVelocity=Vector3.zero;actuator.Parent=root
                    S.flyRoot=root;S.flyAttachment=attachment;S.flyVelocity=actuator
                end
                S.flyVelocity.VectorVelocity=velocity
                pcall(function()
                    if S.soul and S.soul.active and not UserInputService:GetFocusedTextBox() then
						local flat=Vector3.new(velocity.X,0,velocity.Z)
						if flat.Magnitude>0.01 then root.CFrame=CFrame.lookAt(root.Position,root.Position+flat.Unit) end
					end
					root.AssemblyLinearVelocity =
						velocity

					root.AssemblyAngularVelocity =
						Vector3.zero
				end)

				if humanoid then
					pcall(function()
						humanoid:ChangeState(
							Enum.HumanoidStateType.Physics
						)
					end)
				end
			end
		)

	ugUpdateMovementButtons()
end

function S.releaseNoclipCharacter()
    if S.noclipPairFolder then S.noclipPairFolder:Destroy(); S.noclipPairFolder=nil end
    S.noclipPairs={}
    S.noclipNextQuery=0
    if S.noclipAdded then S.noclipAdded:Disconnect(); S.noclipAdded=nil end
    if S.noclipRemoved then S.noclipRemoved:Disconnect(); S.noclipRemoved=nil end
    for part,record in pairs(S.noclipParts or {}) do
        record.connection:Disconnect()
        if part.Parent then pcall(function() part.CanCollide=record.original end) end
    end
    S.noclipParts={}
    S.noclipCharacter=nil
    S.moveNoclipOriginal={}
end
function S.refreshNoclipPairs()
    local character=S.noclipCharacter
    local root=character and character:FindFirstChild("HumanoidRootPart")
    if not root or not root:IsA("BasePart") then return end
    local now=os.clock()
    if now<(S.noclipNextQuery or 0) then return end
    S.noclipNextQuery=now+0.1
    local params=OverlapParams.new()
    params.FilterType=Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances={character}
    params.RespectCanCollide=true
    params.MaxParts=64
    local reach=math.min(root.AssemblyLinearVelocity.Magnitude*0.2,24)+8
    local nearby=workspace:GetPartBoundsInBox(root.CFrame,root.Size+Vector3.new(reach*2,reach*2,reach*2),params)
    local humanoid=character:FindFirstChildOfClass("Humanoid")
    local leg=character:FindFirstChild("Left Leg")
    local height=root.Size.Y*0.5+(humanoid and humanoid.HipHeight or 2)
    if humanoid and humanoid.RigType==Enum.HumanoidRigType.R6 and leg and leg:IsA("BasePart") then height+=leg.Size.Y end
    local rayParams=RaycastParams.new()
    rayParams.FilterType=Enum.RaycastFilterType.Exclude
    rayParams.FilterDescendantsInstances={character}
    rayParams.RespectCanCollide=true
    local supports={}
    local radius=math.max(root.Size.X,root.Size.Z)*0.5+0.25
    for _,offset in ipairs({Vector3.zero,Vector3.new(radius,0,0),Vector3.new(-radius,0,0),Vector3.new(0,0,radius),Vector3.new(0,0,-radius)}) do
        local hit=workspace:Raycast(root.Position+offset,Vector3.new(0,-height-3,0),rayParams)
        if hit and hit.Normal.Y>=0.5 and hit.Position.Y<=root.Position.Y-root.Size.Y*0.5 then supports[hit.Instance]=true end
    end
    local wanted={}
    for _,part in ipairs(nearby) do
        if part:IsA("BasePart") and not part:IsA("Terrain") and part.CanCollide and not supports[part] then wanted[part]=true end
    end
    for part,constraint in pairs(S.noclipPairs) do
        if not wanted[part] or constraint.Part0~=root or not constraint.Parent then
            constraint:Destroy()
            S.noclipPairs[part]=nil
        end
    end
    if not S.noclipPairFolder then
        S.noclipPairFolder=Instance.new("Folder")
        S.noclipPairFolder.Name="LuminNoclipPairs"
        S.noclipPairFolder.Parent=character
    end
    for part in pairs(wanted) do
        if not S.noclipPairs[part] then
            local constraint=Instance.new("NoCollisionConstraint")
            constraint.Part0=root
            constraint.Part1=part
            constraint.Parent=S.noclipPairFolder
            S.noclipPairs[part]=constraint
        end
    end
end
function S.bindNoclipCharacter(character)
    S.releaseNoclipCharacter()
    S.noclipCharacter=character
    if not character then return end
    local function add(part)
        if not part:IsA("BasePart") or S.noclipParts[part] then return end
        local record={original=part.CanCollide,writes=0,writing=false}
        S.noclipParts[part]=record
        S.moveNoclipOriginal[part]=record.original
        record.enforce=function()
            if not S.moveNoclip or S.unloading or record.writing or S.noclipParts[part]~=record or record.writes>=4 then return end
            if part.CanCollide then
                record.writes+=1
                record.writing=true
                part.CanCollide=false
                record.writing=false
            end
        end
        record.connection=part:GetPropertyChangedSignal("CanCollide"):Connect(record.enforce)
        record.enforce()
    end
    S.noclipAdded=character.DescendantAdded:Connect(add)
    S.noclipRemoved=character.DescendantRemoving:Connect(function(part)
        local record=S.noclipParts[part]
        if not record then return end
        S.noclipParts[part]=nil
        S.moveNoclipOriginal[part]=nil
        record.connection:Disconnect()
        pcall(function() part.CanCollide=record.original end)
    end)
    for _,part in ipairs(character:GetDescendants()) do add(part) end
end
function ugStopNoclip()
    S.moveNoclip=false
    if S.moveNoclipConnection then S.moveNoclipConnection:Disconnect();S.moveNoclipConnection=nil end
    S.releaseNoclipCharacter()
    ugUpdateMovementButtons()
end
function ugStartNoclip()
    if S.moveNoclip then return end
    S.moveNoclip=true
    S.bindNoclipCharacter(S.controlledCharacter())
    S.moveNoclipConnection=RunService.PreSimulation:Connect(function()
        if not S.moveNoclip or S.unloading then return end
        if S.noclipCharacter~=S.controlledCharacter() then S.bindNoclipCharacter(S.controlledCharacter()) end
        for _,record in pairs(S.noclipParts) do record.writes=0;record.enforce() end
        S.refreshNoclipPairs()
    end)
    ugUpdateMovementButtons()
end

function ugResetMovementTools()
    if S.stopSpeedSwap then S.stopSpeedSwap() end
	S.moveAcceleration = false
	S.moveSpeedFov = false
	S.moveRampElapsed = 0
	S.moveRampSpeed = nil
	S.restoreSpeedFov()
	ugStopFly()
	ugStopNoclip()

	S.moveInfiniteJump = false
	S.moveLockStats = false

	local character, humanoid =
		ugGetMovementCharacter()

	if humanoid
		and (
			S.moveSavedCharacter == character
			or S.moveSavedCharacter == nil
		)
	then
		pcall(function()
			if S.moveOriginalWalkSpeed ~= nil then
				humanoid.WalkSpeed =
					S.moveOriginalWalkSpeed
			end

			if S.moveOriginalUseJumpPower ~= nil then
				humanoid.UseJumpPower =
					S.moveOriginalUseJumpPower
			end

			if S.moveOriginalJumpPower ~= nil then
				humanoid.JumpPower =
					S.moveOriginalJumpPower
			end

			if S.moveOriginalJumpHeight ~= nil then
				humanoid.JumpHeight =
					S.moveOriginalJumpHeight
			end
		end)
	end

	local camera =
		Workspace.CurrentCamera

	if camera
		and S.moveOriginalFov ~= nil
	then
		camera.FieldOfView =
			S.moveOriginalFov
	end

	S.moveSavedCharacter = nil
	S.moveOriginalWalkSpeed = nil
	S.moveOriginalJumpPower = nil
	S.moveOriginalJumpHeight = nil
	S.moveOriginalUseJumpPower = nil
	S.moveOriginalFov = nil

	ugUpdateMovementButtons()
end

S.connectAction(S.moveFlyButton,function()
	if S.moveFly then
		ugStopFly()
	else
		ugStartFly()
	end
end)

S.connectAction(S.moveNoclipButton,function()
	if S.moveNoclip then
		ugStopNoclip()
	else
		ugStartNoclip()
	end
end)

S.connectAction(S.moveInfiniteJumpButton,function()
	S.moveInfiniteJump =
		not S.moveInfiniteJump

	ugUpdateMovementButtons()
end)

S.connectAction(S.moveLockButton,function()
	S.moveLockStats =
		not S.moveLockStats

	if S.moveLockStats then
		ugApplyMovementStats()
	end

	ugUpdateMovementButtons()
end)

S.connectAction(S.moveResetButton,
	ugResetMovementTools
)

S.rootConnections[#S.rootConnections + 1] = UserInputService.JumpRequest:Connect(function()
	if not S.moveInfiniteJump
		or S.unloading
	then
		return
	end

	local _, humanoid, root =
		ugGetMovementCharacter()

	if not root then
		return
	end

	local velocity =
		root.AssemblyLinearVelocity

	root.AssemblyLinearVelocity =
		Vector3.new(
			velocity.X,
			ugMovementJumpVelocity(),
			velocity.Z
		)

	if humanoid then
		pcall(function()
			humanoid:ChangeState(
				Enum.HumanoidStateType.Jumping
			)
		end)
	end
end)

task.spawn(function()
	while gui.Parent do
		if S.moveLockStats
			and not S.unloading
		then
			ugApplyMovementStats()
		end

		task.wait(0.20)
	end
end)

S.rootConnections[#S.rootConnections + 1] = player.CharacterAdded:Connect(function()
	S.moveSavedCharacter = nil
	if S.moveNoclip then S.bindNoclipCharacter(S.controlledCharacter()) end

	if S.moveLockStats then
		task.delay(0.5, function()
			if gui.Parent
				and S.moveLockStats
			then
				ugApplyMovementStats()
			end
		end)
	end
end)

ugCaptureMovementDefaults()
ugUpdateMovementButtons()

S.uiHeader = makeLabel(
	S.uiPage,
	"UI manager",
	UDim2.new(1, -40, 0, 32),
	UDim2.new(0, 24, 0, 20),
	20,
	COL.text,
	Enum.Font.GothamBold
)

S.uiDesc = makeLabel(
	S.uiPage,
	"Automatically scans PlayerGui. Objects are hidden, not deleted, and can be restored.",
	UDim2.new(1, -48, 0, 24),
	UDim2.new(0, 24, 0, 54),
	11,
	COL.subtext,
	Enum.Font.Gotham
)

S.uiBindButton = makeButton(S.uiPage, "UI key: F8", UDim2.fromOffset(210, 30), UDim2.new(1, -234, 0, 22), COL.button)
S.uiBindButton.TextSize = 11

S.uiToolbar = makeSection(
	S.uiPage,
	"FILTER / CONTROLS",
	UDim2.new(0, 24, 0, 92),
	UDim2.new(1, -48, 0, 92)
)

S.uiSearch = Instance.new("TextBox")
S.uiSearch.Size = UDim2.new(1, -338, 0, 34)
S.uiSearch.Position = UDim2.new(0, 12, 0, 40)
S.uiSearch.BackgroundColor3 = COL.panel
S.uiSearch.BorderSizePixel = 0
S.uiSearch.TextColor3 = COL.text
S.uiSearch.PlaceholderColor3 = COL.dim
S.uiSearch.PlaceholderText = "search name / path / class..."
S.uiSearch.Text = ""
S.uiSearch.ClearTextOnFocus = false
S.uiSearch.Font = Enum.Font.Gotham
S.uiSearch.TextSize = 11
S.uiSearch.Parent = S.uiToolbar
corner(S.uiSearch, 7)
stroke(S.uiSearch, COL.stroke, 0.5, 1)

S.uiScanButton = makeButton(
	S.uiToolbar,
	"SCAN",
	UDim2.new(0, 68, 0, 34),
	UDim2.new(1, -314, 0, 40),
	COL.blue
)
S.uiScanButton.TextSize = 10

S.uiHideAllButton = makeButton(
	S.uiToolbar,
	"HIDE ALL",
	UDim2.new(0, 104, 0, 34),
	UDim2.new(1, -238, 0, 40),
	Color3.fromRGB(55, 30, 34)
)
S.uiHideAllButton.TextSize = 9

S.uiRestoreButton = makeButton(
	S.uiToolbar,
	"RESTORE ALL",
	UDim2.new(0, 104, 0, 34),
	UDim2.new(1, -126, 0, 40),
	COL.green
)
S.uiRestoreButton.TextSize = 9

S.diagSection = makeSection(
	S.uiPage,
	"DIAGNOSTICS",
	UDim2.new(0, 24, 0, 196),
	UDim2.new(1, -48, 0, 94)
)

S.diagToggleButton = makeButton(
	S.diagSection,
	"DIAGNOSTICS: OFF",
	UDim2.new(0, 184, 0, 34),
	UDim2.new(0, 12, 0, 38),
	COL.green
)
S.diagToggleButton.TextSize = 10
S.diagToggleButton.Font = Enum.Font.GothamBold

S.diagCleanupButton = makeButton(
	S.diagSection,
	"CLEANUP",
	UDim2.new(0, 104, 0, 34),
	UDim2.new(0, 204, 0, 38),
	COL.button
)
S.diagCleanupButton.TextSize = 10
S.diagCleanupButton.Font = Enum.Font.GothamBold

S.diagStatus = makeLabel(
	S.diagSection,
	"Loading diagnostic manager...",
	UDim2.new(1, -332, 0, 34),
	UDim2.new(0, 320, 0, 38),
	9,
	COL.dim,
	Enum.Font.Gotham
)
S.diagStatus.TextWrapped = true

S.uiListSection = makeSection(
	S.uiPage,
	"PLAYERGUI",
	UDim2.new(0, 24, 0, 302),
	UDim2.new(1, -48, 1, -338)
)

S.uiStatus = makeLabel(
	S.uiListSection,
	"Scanning...",
	UDim2.new(1, -24, 0, 18),
	UDim2.new(0, 12, 0, 34),
	9,
	COL.dim,
	Enum.Font.Gotham
)

S.uiScroll = Instance.new("ScrollingFrame")
S.uiScroll.Size = UDim2.new(1, -24, 1, -64)
S.uiScroll.Position = UDim2.new(0, 12, 0, 56)
S.uiScroll.BackgroundTransparency = 1
S.uiScroll.BorderSizePixel = 0
S.uiScroll.ScrollBarThickness = 4
S.uiScroll.ScrollBarImageColor3 = COL.dim
S.uiScroll.CanvasSize = UDim2.new()
S.uiScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
S.uiScroll.Parent = S.uiListSection

S.uiLayout = Instance.new("UIListLayout")
S.uiLayout.Padding = UDim.new(0, 5)
S.uiLayout.SortOrder = Enum.SortOrder.LayoutOrder
S.uiLayout.Parent = S.uiScroll


function S.restoreSpeedFov()
	if S.moveSpeedFovCamera and S.moveSpeedFovBase then
		pcall(function() S.moveSpeedFovCamera.FieldOfView = S.moveSpeedFovBase end)
	end
	S.moveSpeedFovCamera = nil
	S.moveSpeedFovBase = nil
end
function ugCreateDiagnosticsManager()
	local env =
		(type(getgenv) == "function" and getgenv())
		or _G

	local manager = {

		enabled = false,
		connections = {},
		cleanups = {},
		version = "panel-1.0",
	}

	function manager:IsEnabled()
		return self.enabled == true
	end

	function manager:RegisterConnection(connection)
		if typeof(connection) == "RBXScriptConnection" then
			table.insert(
				self.connections,
				connection
			)

			if not self.enabled
				and connection.Connected
			then
				pcall(function()
					connection:Disconnect()
				end)
			end
		end

		return connection
	end

	function manager:RegisterCleanup(callback)
		if type(callback) == "function" then
			table.insert(
				self.cleanups,
				callback
			)

			if not self.enabled then
				pcall(callback)
			end
		end

		return callback
	end

	function manager:Cleanup()
		local disconnected = 0
		local callbacks = 0

		for _, connection in ipairs(
			self.connections
		) do
			if typeof(connection)
				== "RBXScriptConnection"
				and connection.Connected
			then
				if pcall(function()
					connection:Disconnect()
				end) then
					disconnected += 1
				end
			end
		end

		table.clear(self.connections)

		for _, callback in ipairs(
			self.cleanups
		) do
			if type(callback) == "function"
				and pcall(callback)
			then
				callbacks += 1
			end
		end

		table.clear(self.cleanups)

		return disconnected, callbacks
	end

	function manager:Off()
		self.enabled = false

		local disconnected, callbacks =
			self:Cleanup()

		if type(_G.LuminNpcProbeStop)
			== "function"
		then
			pcall(_G.LuminNpcProbeStop)
		end

		for _, name in ipairs({
			"LuminTDVStatus",
			"LuminTDVBaseline",
			"LuminTDVCooldown",
			"LuminTDVLocalDamageAttr",
			"LuminTDVLocalClone",
			"LuminTDVBurst5",
			"LuminTDVTrueGap",
			"LuminTDVConcurrent2",
		}) do
			if rawget(_G, name) ~= nil then
				_G[name] = nil
			end
		end

		print(
			"[LUMIN DIAG] OFF | disconnected:",
			disconnected,
			"| cleanup callbacks:",
			callbacks
		)

		return disconnected, callbacks
	end

	function manager:On()
		self.enabled = true
		print("[LUMIN DIAG] ON")
	end

	function manager:Status()
		local connected = 0

		for _, connection in ipairs(
			self.connections
		) do
			if typeof(connection)
				== "RBXScriptConnection"
				and connection.Connected
			then
				connected += 1
			end
		end

		return {
			enabled = self.enabled,
			registeredConnections =
				#self.connections,
			connected = connected,
			cleanupCallbacks =
				#self.cleanups,
			version = self.version,
		}
	end

	env.LuminDiagnostics = manager
	_G.LuminDiagnostics = manager

	return manager
end

function ugGetDiagnosticsManager()
	local env =
		(type(getgenv) == "function" and getgenv())
		or _G

	local manager =
		env.LuminDiagnostics
		or _G.LuminDiagnostics

	if type(manager) ~= "table"
		or type(manager.Cleanup) ~= "function"
	then
		manager =
			ugCreateDiagnosticsManager()
	end

	env.LuminDiagnostics = manager
	_G.LuminDiagnostics = manager

	_G.LuminDiagnosticsOn = function()
		if type(manager.On) == "function" then
			manager:On()
		else
			manager.enabled = true
		end

		if ugRefreshDiagnosticsUi then
			ugRefreshDiagnosticsUi()
		end
	end

	_G.LuminDiagnosticsOff = function()
		if type(manager.Off) == "function" then
			manager:Off()
		else
			manager.enabled = false
			manager:Cleanup()
		end

		if ugRefreshDiagnosticsUi then
			ugRefreshDiagnosticsUi()
		end
	end

	_G.LuminDiagnosticsCleanup = function()
		local disconnected, callbacks =
			manager:Cleanup()

		print(
			"[LUMIN DIAG] CLEANUP | disconnected:",
			disconnected,
			"| callbacks:",
			callbacks
		)

		if ugRefreshDiagnosticsUi then
			ugRefreshDiagnosticsUi()
		end

		return disconnected, callbacks
	end

	_G.LuminDiagnosticsStatus = function()
		local status

		if type(manager.Status) == "function" then
			status = manager:Status()
		else
			status = {
				enabled =
					manager.enabled ~= false,
				registeredConnections =
					type(manager.connections)
						== "table"
					and #manager.connections
					or 0,
				cleanupCallbacks =
					type(manager.cleanups)
						== "table"
					and #manager.cleanups
					or 0,
			}
		end

		print(
			"[LUMIN DIAG] STATUS | enabled:",
			status.enabled,
			"| registered:",
			status.registeredConnections or 0,
			"| cleanup:",
			status.cleanupCallbacks or 0
		)

		return status
	end

	return manager
end

function ugGetDiagnosticsStatus()
	local manager =
		ugGetDiagnosticsManager()

	if type(manager.Status) == "function" then
		local ok, status =
			pcall(function()
				return manager:Status()
			end)

		if ok and type(status) == "table" then
			return status
		end
	end

	local connected = 0

	if type(manager.connections) == "table" then
		for _, connection in ipairs(
			manager.connections
		) do
			if typeof(connection)
				== "RBXScriptConnection"
				and connection.Connected
			then
				connected += 1
			end
		end
	end

	return {
		enabled =
			manager.enabled ~= false,
		registeredConnections =
			type(manager.connections) == "table"
				and #manager.connections
				or 0,
		connected = connected,
		cleanupCallbacks =
			type(manager.cleanups) == "table"
				and #manager.cleanups
				or 0,
	}
end

function ugRefreshDiagnosticsUi()
	if not S.diagToggleButton
		or not S.diagToggleButton.Parent
	then
		return
	end

	local status =
		ugGetDiagnosticsStatus()

	local enabled =
		status.enabled ~= false

	S.diagToggleButton.Text =
		enabled
			and "DIAGNOSTICS: ON"
			or "DIAGNOSTICS: OFF"

	S.diagToggleButton.BackgroundColor3 =
		enabled
			and COL.green
			or Color3.fromRGB(55, 30, 34)

	if S.diagStatus then
		S.diagStatus.Text =
			(enabled
				and "New probes allowed"
				or "New probes disabled")
			..
			" · listeners: "
			..
			tostring(
				status.connected
				or status.registeredConnections
				or 0
			)
	end
end

function ugToggleDiagnostics()
	local manager =
		ugGetDiagnosticsManager()

	if manager.enabled ~= false then
		if type(manager.Off) == "function" then
			manager:Off()
		else
			manager.enabled = false
			manager:Cleanup()
		end
	else
		if type(manager.On) == "function" then
			manager:On()
		else
			manager.enabled = true
		end
	end

	ugRefreshDiagnosticsUi()
end

function ugCleanupDiagnostics()
	local manager =
		ugGetDiagnosticsManager()

	local disconnected, callbacks =
		manager:Cleanup()

	print(
		"[LUMIN DIAG] CLEANUP | disconnected:",
		disconnected,
		"| callbacks:",
		callbacks
	)

	ugRefreshDiagnosticsUi()
end

S.connectAction(S.diagToggleButton,function()
	ugToggleDiagnostics()
end)

S.connectAction(S.diagCleanupButton,function()
	ugCleanupDiagnostics()
end)

ugGetDiagnosticsManager()
ugRefreshDiagnosticsUi()

function ugUiIsManaged(object)
	if not object
		or not object.Parent
	then
		return false
	end

	if object == gui
        or (S.horrorEffectsGui and (object==S.horrorEffectsGui or object:IsDescendantOf(S.horrorEffectsGui)))
		or object:IsDescendantOf(gui)
	then
		return false
	end

	if not object:IsDescendantOf(
		playerGui
	)
	then
		return false
	end

	return
		object:IsA("ScreenGui")
		or object:IsA("GuiObject")
end

function ugUiGetProperty(object)
	if object:IsA("ScreenGui") then
		return "Enabled"
	end

	if object:IsA("GuiObject") then
		return "Visible"
	end

	return nil
end

function ugUiGetState(object)
	if not ugUiIsManaged(object) then
		return nil
	end

	if object:IsA("ScreenGui") then
		return object.Enabled
	end

	if object:IsA("GuiObject") then
		return object.Visible
	end

	return nil
end

function ugUiSetRawState(object, value)
	if not ugUiIsManaged(object) then
		return
	end

	pcall(function()
		if object:IsA("ScreenGui") then
			object.Enabled = value
		elseif object:IsA("GuiObject") then
			object.Visible = value
		end
	end)
end

function ugUiHide(object)
	if not ugUiIsManaged(object) then
		return
	end

	if S.uiOriginal[object] == nil then
		S.uiOriginal[object] =
			ugUiGetState(object)
	end

	S.uiHidden[object] = true
	ugUiSetRawState(object, false)

	ugRefreshUiButtons()
end

function ugUiRestore(object)
	if not object then
		return
	end

	S.uiHidden[object] = nil

	local original =
		S.uiOriginal[object]

	S.uiOriginal[object] = nil

	if object.Parent then
		if original == nil then
			original = true
		end

		ugUiSetRawState(
			object,
			original
		)
	end

	ugRefreshUiButtons()
end

function ugUiToggle(object)
	if S.uiHidden[object] then
		ugUiRestore(object)
	else
		ugUiHide(object)
	end
end

function ugUiHideAll()
	local hiddenCount = 0

	for _, object in ipairs(
		playerGui:GetChildren()
	) do
		if object ~= gui then
			if object:IsA("ScreenGui") then
				if not S.uiHidden[object] then
					ugUiHide(object)
					hiddenCount += 1
				end

			elseif object:IsA("GuiObject") then

				if not S.uiHidden[object] then
					ugUiHide(object)
					hiddenCount += 1
				end
			end
		end
	end

	S.allUiHidden = true

	print(
		"[UI]",
		"hide all:",
		hiddenCount
	)

	ugRefreshUiButtons()
end

function ugUiRestoreAll()
	local list = {}

	for object in pairs(
		S.uiHidden
	) do
		table.insert(
			list,
			object
		)
	end

	for _, object in ipairs(list) do
		ugUiRestore(object)
	end

	S.uiHidden = {}
	S.uiOriginal = {}
	S.allUiHidden = false

	S.uiDirty = true

	if gui.Parent then
		ugScanUi(true)
	end
end

function ugUiDepth(object)
	local depth = 0
	local cursor = object.Parent

	while cursor
		and cursor ~= playerGui
	do
		depth += 1
		cursor = cursor.Parent
	end

	return depth
end

function ugUiClassRank(object)
	if object:IsA("ScreenGui") then
		return 0
	end

	if object:IsA("Frame")
		or object:IsA("ScrollingFrame")
	then
		return 1
	end

	if object:IsA("TextButton")
		or object:IsA("ImageButton")
	then
		return 2
	end

	return 3
end

function ugUiBuildPath(object)
	local names = {}
	local cursor = object

	while cursor
		and cursor ~= playerGui
	do
		table.insert(
			names,
			1,
			cursor.Name
		)

		cursor = cursor.Parent
	end

	return table.concat(
		names,
		" > "
	)
end

function ugScanUi(force)
	if not force
		and not S.uiDirty
		and os.clock()
			-
			(S.uiLastScan or 0)
			<
			2
	then
		return
	end

	S.uiLastScan = os.clock()
	S.uiDirty = false

	local entries = {}

	for _, object in ipairs(
		playerGui:GetDescendants()
	) do
		if ugUiIsManaged(object) then
			local path =
				ugUiBuildPath(object)

			table.insert(
				entries,
				{
					object = object,
					path = path,
					pathLower =
						string.lower(path),
					class = object.ClassName,
					classLower =
						string.lower(
							object.ClassName
						),
					depth =
						ugUiDepth(object),
					rank =
						ugUiClassRank(object),
				}
			)
		end
	end

	table.sort(
		entries,
		function(a, b)
			if a.pathLower
				==
				b.pathLower
			then
				return
					a.rank
					<
					b.rank
			end

			return
				a.pathLower
				<
				b.pathLower
		end
	)

	S.uiEntries = entries

	for object in pairs(
		S.uiHidden
	) do
		if not object.Parent then
			S.uiHidden[object] = nil
			S.uiOriginal[object] = nil
		end
	end

	ugRebuildUiList(true)
end

function ugRefreshUiButtons()
	for object, button in pairs(
		S.uiButtons
	) do
		if button
			and button.Parent
		then
			local hidden =
				S.uiHidden[object]
				== true

			button.Text =
				hidden
				and "RESTORE"
				or "HIDE"

			button.BackgroundColor3 =
				hidden
				and COL.green
				or COL.button
		end
	end

	local hiddenCount = 0

	for object in pairs(
		S.uiHidden
	) do
		if object.Parent then
			hiddenCount += 1
		end
	end

	if S.uiStatus then
		S.uiStatus.Text =
			"Found: "
			..
			tostring(
				#S.uiEntries
			)
			..
			" · hidden: "
			..
			tostring(hiddenCount)
	end
end

function ugRebuildUiList(force)
    if not S.uiScroll then return end
    S.uiExpanded=S.uiExpanded or setmetatable({},{__mode="k"})
    local query=(S.uiSearch.Text or ""):lower()
    for _,child in ipairs(S.uiScroll:GetChildren()) do if child~=S.uiLayout then child:Destroy() end end
    S.uiButtons={}
    local children={};local roots={};local entries={};local matched={}
    for _,entry in ipairs(S.uiEntries) do if entry.object.Parent then entries[entry.object]=entry end end
    for object,entry in pairs(entries) do
        local parent=object.Parent
        while parent and parent~=playerGui and not entries[parent] do parent=parent.Parent end
        if entries[parent] then children[parent]=children[parent] or {};table.insert(children[parent],object) else table.insert(roots,object) end
        if (query=="" or entry.pathLower:find(query,1,true) or entry.classLower:find(query,1,true)) and (not S.uiHiddenOnly or S.uiHidden[object]) then
            local cursor=object
            while cursor and cursor~=playerGui do matched[cursor]=true;cursor=cursor.Parent end
        end
    end
    local function sort(list) table.sort(list,function(a,b) return a.Name:lower()<b.Name:lower() end) end
    sort(roots);for _,list in pairs(children) do sort(list) end
    local shown=0
    local function draw(object,depth)
        if not matched[object] or shown>=S.uiMaxRendered then return end
        shown+=1
        local row=Instance.new("Frame");row.Size=UDim2.new(1,-4,0,36);row.BackgroundColor3=COL.panel;row.BorderSizePixel=0;row.LayoutOrder=shown;row.Parent=S.uiScroll
        local branch=children[object] and #children[object]>0
        local expanded=S.uiExpanded[object] or query~="" or S.uiHiddenOnly
        local title=(branch and (expanded and "▾ " or "▸ ") or "· ")..object.Name.."  ["..object.ClassName.."]"
        local indent=math.min(depth,8)*12
        local label=makeButton(row,title,UDim2.new(1,-116-indent,1,0),UDim2.fromOffset(indent,0),COL.panel);label.TextXAlignment=Enum.TextXAlignment.Left;label.TextSize=11;label.TextTruncate=Enum.TextTruncate.AtEnd
        S.connectAction(label,function() S.uiExpanded[object]=not S.uiExpanded[object];ugRebuildUiList(true) end)
        local toggle=makeButton(row,S.uiHidden[object] and "RESTORE" or "HIDE",UDim2.fromOffset(105,30),UDim2.new(1,-109,0,3),COL.button);toggle.TextSize=10
        S.uiButtons[object]=toggle
        S.connectAction(toggle,function() ugUiToggle(object);ugRebuildUiList(true) end)
        if expanded then for _,child in ipairs(children[object] or {}) do draw(child,depth+1) end end
    end
    for _,object in ipairs(roots) do draw(object,0) end
    ugRefreshUiButtons()
end

S.uiSearch:GetPropertyChangedSignal(
	"Text"
):Connect(function()
	S.uiSignature = ""
	ugRebuildUiList(true)
end)

S.connectAction(S.uiScanButton,function()
	S.uiDirty = true
	ugScanUi(true)
end)

S.connectAction(S.uiHideAllButton,
	ugUiHideAll
)

S.connectAction(S.uiRestoreButton,
	ugUiRestoreAll
)

S.rootConnections[#S.rootConnections + 1] = playerGui.DescendantAdded:Connect(function(object)
	if object ~= gui
		and not object:IsDescendantOf(gui)
		and (
			object:IsA("ScreenGui")
			or object:IsA("GuiObject")
		)
	then
		S.uiDirty = true
	end
end)

S.rootConnections[#S.rootConnections + 1] = playerGui.DescendantRemoving:Connect(function(object)
	if S.uiHidden[object] then
		S.uiHidden[object] = nil
		S.uiOriginal[object] = nil
	end

	if object:IsA("ScreenGui")
		or object:IsA("GuiObject")
	then
		S.uiDirty = true
	end
end)

task.spawn(function()
	while gui.Parent do
		if next(S.uiHidden) ~= nil then
			for object in pairs(
				S.uiHidden
			) do
				if object
					and object.Parent
				then
					ugUiSetRawState(
						object,
						false
					)
				else
					S.uiHidden[object] = nil
					S.uiOriginal[object] = nil
				end
			end
		end

		task.wait(0.10)
	end
end)

local cameraHeader = makeLabel(
	cameraPage,
	"Camera",
	UDim2.new(1, -40, 0, 32),
	UDim2.new(0, 24, 0, 20),
	20,
	COL.text,
	Enum.Font.GothamBold
)

local cameraDesc = makeLabel(
	cameraPage,
	"NPC detection, close orbit spectating, third-person unlock and freecam.",
	UDim2.new(1, -48, 0, 24),
	UDim2.new(0, 24, 0, 54),
	11,
	COL.subtext,
	Enum.Font.Gotham
)

local cameraSection = makeSection(
	cameraPage,
	"STANDARD CAMERA",
	UDim2.new(0, 24, 0, 92),
	UDim2.new(0, 330, 0, 215)
)

local cameraToggleButton = makeButton(
	cameraSection,
	"Third person: OFF",
	UDim2.new(0.5, -18, 0, 38),
	UDim2.new(0, 12, 0, 40),
	COL.blue
)
cameraToggleButton.Font = Enum.Font.GothamBold

S.firstPersonButton = makeButton(
	cameraSection,
	"First person",
	UDim2.new(0.5, -18, 0, 38),
	UDim2.new(0.5, 6, 0, 40),
	COL.blue
)
S.firstPersonButton.Font = Enum.Font.GothamBold
S.firstPersonButton.TextSize = 11

local cameraMaxSlider

cameraMaxSlider = createSlider(
	cameraSection,
	"Maximum zoom distance",
	CAMERA_MAX_ZOOM_MIN,
	CAMERA_MAX_ZOOM_MAX,
	CAMERA_MAX_ZOOM_STEP,
	cameraMaxZoom,
	94,
	function(value)
		cameraMaxZoom = value
	end
)

local cameraNote = makeLabel(
	cameraSection,
	"Enable third person manually. The panel yields when the game controls the camera.",
	UDim2.new(1, -24, 0, 44),
	UDim2.new(0, 12, 0, 160),
	9,
	COL.dim,
	Enum.Font.Gotham
)
cameraNote.TextWrapped = true
cameraNote.TextYAlignment = Enum.TextYAlignment.Top

S.freecamSection = makeSection(
	cameraPage,
	"FREECAM",
	UDim2.new(0, 24, 0, 320),
	UDim2.new(0, 330, 0, 215)
)

S.freecamControls = Instance.new("ScrollingFrame")
S.freecamControls.Size = UDim2.new(1, 0, 1, -34)
S.freecamControls.Position = UDim2.new(0, 0, 0, 34)
S.freecamControls.BackgroundTransparency = 1
S.freecamControls.BorderSizePixel = 0
S.freecamControls.ScrollBarThickness = 3
S.freecamControls.CanvasSize = UDim2.new(0, 0, 0, 234)
S.freecamControls.Parent = S.freecamSection

S.freecamToggleButton = makeButton(
	S.freecamControls,
	"FREECAM: OFF",
	UDim2.new(1, -24, 0, 38),
	UDim2.new(0, 12, 0, 6),
	COL.purple
)
S.freecamToggleButton.Font = Enum.Font.GothamBold

S.freecamSpeedSlider = createSlider(
	S.freecamControls,
	"Speed",
	4,
	120,
	2,
	S.freecamSpeed,
	60,
	function(value)
		S.freecamSpeed = value
	end
)

S.freecamSmoothSlider = createSlider(
	S.freecamControls,
	"Smoothing / inertia",
	0,
	100,
	5,
	S.freecamSmoothness,
	120,
	function(value)
		S.freecamSmoothness = value
	end
)

S.freecamHint = makeLabel(
	S.freecamControls,
	"WASD move · Q/E down/up · Shift boost · hold RMB to look around.",
	UDim2.new(1, -24, 0, 44),
	UDim2.new(0, 12, 0, 184),
	9,
	COL.dim,
	Enum.Font.Gotham
)
S.freecamHint.TextWrapped = true
S.freecamHint.TextYAlignment = Enum.TextYAlignment.Top

S.spectateSection = makeSection(
	cameraPage,
	"SPECTATE NPC",
	UDim2.new(0, 366, 0, 92),
	UDim2.new(1, -390, 0, 443)
)

S.cameraNpcSearch = Instance.new("TextBox")
S.cameraNpcSearch.Size = UDim2.new(1, -122, 0, 34)
S.cameraNpcSearch.Position = UDim2.new(0, 12, 0, 40)
S.cameraNpcSearch.BackgroundColor3 = COL.panel
S.cameraNpcSearch.BorderSizePixel = 0
S.cameraNpcSearch.TextColor3 = COL.text
S.cameraNpcSearch.PlaceholderColor3 = COL.dim
S.cameraNpcSearch.PlaceholderText = "search NPC..."
S.cameraNpcSearch.Text = ""
S.cameraNpcSearch.ClearTextOnFocus = false
S.cameraNpcSearch.Font = Enum.Font.Gotham
S.cameraNpcSearch.TextSize = 11
S.cameraNpcSearch.Parent = S.spectateSection
corner(S.cameraNpcSearch, 7)
stroke(S.cameraNpcSearch, COL.stroke, 0.5, 1)

S.cameraRefreshButton = makeButton(
	S.spectateSection,
	"SCAN",
	UDim2.new(0, 86, 0, 34),
	UDim2.new(1, -98, 0, 40),
	COL.button
)
S.cameraRefreshButton.TextSize = 10

S.cameraNpcScroll = Instance.new("ScrollingFrame")
S.cameraNpcScroll.Size = UDim2.new(1, -24, 1, -192)
S.cameraNpcScroll.Position = UDim2.new(0, 12, 0, 84)
S.cameraNpcScroll.BackgroundTransparency = 1
S.cameraNpcScroll.BorderSizePixel = 0
S.cameraNpcScroll.ScrollBarThickness = 4
S.cameraNpcScroll.ScrollBarImageColor3 = COL.dim
S.cameraNpcScroll.CanvasSize = UDim2.new()
S.cameraNpcScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
S.cameraNpcScroll.Parent = S.spectateSection

S.cameraNpcLayout = Instance.new("UIListLayout")
S.cameraNpcLayout.Padding = UDim.new(0, 5)
S.cameraNpcLayout.SortOrder = Enum.SortOrder.LayoutOrder
S.cameraNpcLayout.Parent = S.cameraNpcScroll

S.cameraAutoFollowButton = makeButton(
	S.spectateSection,
	"AUTO FOLLOW: OFF",
	UDim2.new(1, -24, 0, 36),
	UDim2.new(0, 12, 1, -92),
	COL.blue
)
S.cameraAutoFollowButton.TextSize = 10

S.cameraStopSpectateButton = makeButton(
	S.spectateSection,
	"RESTORE CAMERA",
	UDim2.new(1, -24, 0, 36),
	UDim2.new(0, 12, 1, -50),
	COL.accent
)
S.cameraStopSpectateButton.TextSize = 10

local cameraStatus = makeLabel(
	cameraPage,
	"Camera: third person enabled",
	UDim2.new(1, -48, 0, 22),
	UDim2.new(0, 24, 1, -30),
	10,
	COL.subtext,
	Enum.Font.GothamMedium
)
function S.releaseFreecamControls()
    game:GetService("ContextActionService"):UnbindAction("LuminFreecamMovement")
    if S.freecamControlConnection then S.freecamControlConnection:Disconnect(); S.freecamControlConnection = nil end
end
function S.captureFreecamControls()
    S.releaseFreecamControls()
    local service = game:GetService("ContextActionService")
    service:BindActionAtPriority("LuminFreecamMovement", function() return Enum.ContextActionResult.Sink end, false, 3000,
        Enum.PlayerActions.CharacterForward, Enum.PlayerActions.CharacterBackward, Enum.PlayerActions.CharacterLeft, Enum.PlayerActions.CharacterRight, Enum.PlayerActions.CharacterJump,
        Enum.KeyCode.W, Enum.KeyCode.A, Enum.KeyCode.S, Enum.KeyCode.D, Enum.KeyCode.Space, Enum.KeyCode.Q, Enum.KeyCode.E, Enum.KeyCode.LeftShift, Enum.KeyCode.RightShift)
    S.freecamControlConnection = RunService.PreSimulation:Connect(function()
        local character = S.controlledCharacter()
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        if humanoid then humanoid:Move(Vector3.zero, false); humanoid.Jump = false end
    end)
end

function ugGetPlayerCameraSubject()
	local character = S.controlledCharacter()

	if not character then
		return nil
	end

	return
		character:FindFirstChildOfClass("Humanoid")
		or character:FindFirstChild("HumanoidRootPart")
		or character:FindFirstChildWhichIsA("BasePart")
end

function ugGetPlayerCameraRoot()
	local character = S.controlledCharacter()

	if not character then
		return nil
	end

	local root =
		character:FindFirstChild("HumanoidRootPart")
		or character:FindFirstChild("RootPart")
		or character.PrimaryPart

	if root and root:IsA("BasePart") then
		return root
	end

	return
		character:FindFirstChildWhichIsA(
			"BasePart"
		)
end

function ugCameraAnglesFromDirection(direction)
	if not direction
		or direction.Magnitude < 0.0001
	then
		return 0, 0
	end

	local unit = direction.Unit

	return
		math.atan2(
			-unit.X,
			-unit.Z
		),
		math.asin(
			math.clamp(
				unit.Y,
				-1,
				1
			)
		)
end

function ugCameraOrbitCFrame(
	pivot,
	yaw,
	pitch,
	distance
)
	local rotation =
		CFrame.Angles(
			0,
			yaw,
			0
		)
		*
		CFrame.Angles(
			pitch,
			0,
			0
		)

	local position =
		pivot
		-
		rotation.LookVector
		*
		distance

	return
		CFrame.lookAt(
			position,
			pivot,
			Vector3.yAxis
		)
end

function ugForceScriptableCamera(
	cf,
	focusPoint
)
	local camera =
		Workspace.CurrentCamera

	if not camera then
		return
	end

	if camera.CameraType
		~= Enum.CameraType.Scriptable
	then
		camera.CameraType =
			Enum.CameraType.Scriptable
	end

	camera.CFrame = cf
	camera.Focus =
		CFrame.new(
			focusPoint
			or (
				cf.Position
				+
				cf.LookVector
				*
				512
			)
		)
end

function ugCameraModeKey()
	if S.freecamActive then
		return "freecam"
	end

	if S.spectateActive
		and S.spectateTarget
	then
		return
			"spectate:"
			..
			tostring(
				S.spectateTarget.Name
			)
	end

	if thirdPerson
		and S.thirdHardOverride
	then
		return "third-hard"
	end

	if thirdPerson then
		return "third-normal"
	end

	return "normal"
end

function ugUpdateSpectateFollowUI()
	if not S.cameraAutoFollowButton then
		return
	end

	S.cameraAutoFollowButton.Text =
		S.spectateAutoFollow
		and "AUTO FOLLOW: ON"
		or "AUTO FOLLOW: OFF"

	S.cameraAutoFollowButton.BackgroundColor3 =
		S.spectateAutoFollow
		and COL.blue
		or COL.button
end

function updateCameraUI()
	local mode = ugCameraModeKey()

	if S.lastCameraUiMode == mode then
		return
	end

	S.lastCameraUiMode = mode

	if thirdPerson then
		cameraToggleButton.Text =
			S.thirdHardOverride
			and "Third person: HARD"
			or "Third person: ON"
	else
		cameraToggleButton.Text =
			"Third person: OFF"
	end

	S.freecamToggleButton.Text =
		S.freecamActive
		and "FREECAM: ON"
		or "FREECAM: OFF"

	if S.freecamActive then
		cameraStatus.Text =
			"Camera: freecam"

	elseif S.spectateActive
		and S.spectateTarget
	then
		cameraStatus.Text =
			"Spectating: "
			..
			tostring(
				S.spectateTarget.Name
			)

	elseif thirdPerson then
		cameraStatus.Text =
			S.thirdHardOverride
			and "Camera: third person · hard"
			or "Camera: third person"

	else
		cameraStatus.Text =
			"Camera: default"
	end
end

function ugCameraNeedsRenderLoop()
	return
		not S.unloading
		and not S.freecamActive
		and not S.spectateActive
		and thirdPerson
		and S.thirdHardOverride
end

function ugUnbindCameraRender()
	if S.cameraRenderBound then
		RunService:UnbindFromRenderStep(
			CAMERA_BIND_NAME
		)

		S.cameraRenderBound = false
	end
end

function ugEnsureCameraRender()
	local needed =
		ugCameraNeedsRenderLoop()

	if needed
		and not S.cameraRenderBound
	then
		RunService:UnbindFromRenderStep(
			CAMERA_BIND_NAME
		)

		RunService:BindToRenderStep(
			CAMERA_BIND_NAME,
			S.cameraPriority,
			ugCameraRenderStep
		)

		S.cameraRenderBound = true

	elseif not needed
		and S.cameraRenderBound
	then
		ugUnbindCameraRender()
	end
end

function S.restorePlayerCameraSettings()
	player.CameraMinZoomDistance = 0
	player.CameraMaxZoomDistance = S.playerCameraMaxZoom
	player.CameraMinZoomDistance = S.playerCameraMinZoom
	player.CameraMode = S.playerCameraMode
end

function applyThirdPerson()
	if not thirdPerson
		or S.freecamActive
		or S.spectateActive
		or S.thirdHardOverride
	then
		return
	end

	local camera =
		Workspace.CurrentCamera

	if not camera or (camera.CameraType ~= Enum.CameraType.Custom and camera.CameraType ~= Enum.CameraType.Follow) then
		return
	end
	local playerSubject = ugGetPlayerCameraSubject()
	if camera.CameraSubject and camera.CameraSubject ~= playerSubject then
		return
	end

	player.CameraMode =
		Enum.CameraMode.Classic

	player.CameraMinZoomDistance =
		CAMERA_MIN_ZOOM

	player.CameraMaxZoomDistance =
		cameraMaxZoom

	local subject =
		ugGetPlayerCameraSubject()

	if camera then
		camera.CameraType =
			Enum.CameraType.Custom

		if subject then
			camera.CameraSubject =
				subject
		end
	end
end

function ugCheckThirdPersonFight()
	if S.unloading or not thirdPerson or S.freecamActive or S.spectateActive then
		return
	end
	applyThirdPerson()
end

function ugInitThirdOrbit()
	local camera =
		Workspace.CurrentCamera

	local root =
		ugGetPlayerCameraRoot()

	if not camera or not root then
		return
	end

	local pivot =
		root.Position
		+
		Vector3.new(
			0,
			2.2,
			0
		)

	local direction =
		pivot
		-
		camera.CFrame.Position

	local yaw, pitch =
		ugCameraAnglesFromDirection(
			direction
		)

	S.thirdYaw = yaw
	S.thirdPitch =
		math.clamp(
			pitch,
			math.rad(-80),
			math.rad(80)
		)

	S.thirdDistance =
		math.clamp(
			(
				camera.CFrame.Position
				-
				pivot
			).Magnitude,
			5,
			math.max(
				12,
				cameraMaxZoom
			)
		)

	if S.thirdDistance < 5 then
		S.thirdDistance = 12
	end
end

function S.restoreDetachedVisibility()
	local state = S.detachedVisibility
	S.detachedVisibility = nil
	if not state then return end
	if state.added then state.added:Disconnect() end
	if state.removing then state.removing:Disconnect() end
	for part, value in pairs(state.parts) do
		if part.Parent and part.LocalTransparencyModifier == 0 then
			part.LocalTransparencyModifier = value
		end
	end
end

function S.updateDetachedVisibility()
	if S.unloading or (not S.spectateActive and not S.freecamActive) or (morphModel and morphModel.Parent and not S.npcMorphTarget and not S.npcMorphBatch) then
		S.restoreDetachedVisibility()
		return
	end
	local character = S.controlledCharacter()
	if S.detachedVisibility and S.detachedVisibility.character ~= character then
		S.restoreDetachedVisibility()
	end
	if not character or not character.Parent then return end
	local state = S.detachedVisibility
	if not state then
		state = {character = character, parts = {}}
		S.detachedVisibility = state
		local function added(object)
			if object:IsA("BasePart") and state.parts[object] == nil then
				state.parts[object] = object.LocalTransparencyModifier
			end
		end
		for _, object in ipairs(character:GetDescendants()) do added(object) end
		state.added = character.DescendantAdded:Connect(added)
		state.removing = character.DescendantRemoving:Connect(function(object)
			local value = state.parts[object]
			if value ~= nil then
				if object.LocalTransparencyModifier == 0 then object.LocalTransparencyModifier = value end
				state.parts[object] = nil
			end
		end)
	end
	for part in pairs(state.parts) do
		if part.Parent then part.LocalTransparencyModifier = 0 end
	end
end

function ugRestorePlayerCamera()
	S.releaseFreecamControls()
	S.restoreDetachedVisibility()
	S.spectateRenderedDistance = nil
	if S.stopSpectateGuard then S.stopSpectateGuard() end
	S.panelCameraLookHeld = false
	if S.restoreCaptureUi then S.restoreCaptureUi() end
	RunService:UnbindFromRenderStep(S.FREECAM_BIND_NAME)
	RunService:UnbindFromRenderStep(S.SPECTATE_BIND_NAME)
	S.freecamActive = false
	S.spectateActive = false
	S.freecamLookHeld = false
	S.cameraFightFrames = 0
	S.thirdHardOverride = false
	S.thirdLookHeld = false
	S.spectateLookHeld = false
	S.lastCameraUiMode = ""

	UserInputService.MouseBehavior =
		Enum.MouseBehavior.Default

	local camera =
		Workspace.CurrentCamera

	local subject =
		ugGetPlayerCameraSubject()

	if camera then
		camera.CameraType =
			Enum.CameraType.Custom

		if subject then
			camera.CameraSubject =
				subject
		end
	end

	if thirdPerson then
		applyThirdPerson()
	else
		S.restorePlayerCameraSettings()
	end

	ugEnsureCameraRender()
	updateCameraUI()
end

function ugStopSpectate()
    if S.autoRecord and S.autoRecord.active then S.autoRecordStop();return end
	RunService:UnbindFromRenderStep(S.SPECTATE_BIND_NAME)
	S.spectateActive = false
	S.spectateTarget = nil
	S.spectateRoot = nil
	S.spectatePivotOffset = Vector3.zero
	S.spectateFollowCFrame = nil
	S.selectedCameraNpcKey = nil
	S.spectateLookHeld = false
	S.lastCameraUiMode = ""

	ugRestorePlayerCamera()
	ugRefreshCameraNpcButtons()
end

function ugStopFreecam(
	restoreCamera
)
	S.releaseFreecamControls()
	RunService:UnbindFromRenderStep(S.FREECAM_BIND_NAME)
	if not S.freecamActive then
		if restoreCamera then
			ugRestorePlayerCamera()
		end
		return
	end

	S.freecamActive = false
	S.freecamLookHeld = false
	S.lastCameraUiMode = ""

	UserInputService.MouseBehavior =
		Enum.MouseBehavior.Default

	ugEnsureCameraRender()

	if restoreCamera ~= false then
		ugRestorePlayerCamera()
	else
		updateCameraUI()
	end
end

function ugStartFreecam()
    if S.stopKillScene then S.stopKillScene() end
    if S.autoRecordStop then S.autoRecordStop() end
	if S.unloading then
		return
	end

	local camera =
		Workspace.CurrentCamera

	if not camera then
		return
	end

	if S.stopSpectateGuard then S.stopSpectateGuard() end
	S.panelCameraLookHeld = false
	if S.restoreCaptureUi then S.restoreCaptureUi() end

	if S.spectateActive then
		S.spectateActive = false
		S.spectateTarget = nil
		S.spectateRoot = nil
		S.selectedCameraNpcKey = nil
	end

	S.freecamSavedType =
		camera.CameraType

	S.freecamSavedSubject =
		camera.CameraSubject

	S.freecamCFrame =
		camera.CFrame

	local look =
		camera.CFrame.LookVector

	S.freecamPitch =
		math.asin(
			math.clamp(
				look.Y,
				-1,
				1
			)
		)

	S.freecamYaw =
		math.atan2(
			-look.X,
			-look.Z
		)

	S.freecamRenderYaw = S.freecamYaw
	S.freecamRenderPitch = S.freecamPitch
	S.freecamVelocity = Vector3.zero
	S.freecamActive = true
	if S.moveFly then ugStopFly() end
	S.captureFreecamControls()
	S.lastCameraUiMode = ""

	RunService:UnbindFromRenderStep(S.FREECAM_BIND_NAME)
	RunService:UnbindFromRenderStep(S.SPECTATE_BIND_NAME)
	RunService:UnbindFromRenderStep(CAMERA_BIND_NAME)
	S.cameraRenderBound = false
	S.freecamLookHeld = false
	S.spectateLookHeld = false
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	RunService:BindToRenderStep(
		S.FREECAM_BIND_NAME,
		Enum.RenderPriority.Camera.Value + 500,
		S.freecamRenderStep
	)
	updateCameraUI()
	ugRefreshCameraNpcButtons()
end

function ugToggleFreecam()
	if S.freecamActive then
		ugStopFreecam(true)
	else
		ugStartFreecam()
	end
end

local function getSpectateRoot(model)
	if not model or not model.Parent then
		return nil
	end
	if model:IsA("BasePart") then return model end
	return model:FindFirstChild("HumanoidRootPart", true)
		or model:FindFirstChild("RootPart", true)
		or model.PrimaryPart
		or model:FindFirstChildWhichIsA("BasePart", true)
end

function ugSpectateEntry(entry)
    if S.stopKillScene then S.stopKillScene() end
    if S.autoRecordStop then S.autoRecordStop() end
	if not entry
		or not entry.model
		or not entry.model.Parent
	then
		return
	end

	if S.unloading then
		return
	end

	local camera =
		Workspace.CurrentCamera

	if not camera then
		return
	end

	local root = getSpectateRoot(entry.model)

	if S.freecamActive then
		ugStopFreecam(false)
	end

	S.spectateActive = true
	S.spectateTarget = entry.model
    S.audioNpcSelection = entry.model
	S.spectateRoot = nil
	S.selectedCameraNpcKey = entry.key
	S.lastCameraUiMode = ""
	S.spectateFollowCFrame = nil

	local boxCF, boxSize
    if entry.model:IsA("BasePart") then boxCF,boxSize=entry.model.CFrame,entry.model.Size
    else boxCF,boxSize=entry.model:GetBoundingBox() end

	S.spectatePivotOffset = root and root:IsA("BasePart")
		and (boxCF.Position - root.Position)
		or Vector3.zero

	local maxDimension =
		math.max(
			boxSize.X,
			boxSize.Y,
			boxSize.Z
		)

	S.spectateRadius =
		math.max(
			2,
			maxDimension * 0.5
		)

	S.spectateDistance =
		math.clamp(
			maxDimension * 1.35,
			6,
			18
		)

	S.spectateRenderedDistance = S.spectateDistance
	S.spectateYaw = 0
	S.spectatePitch = math.rad(-8)

	print(
		"[CAMERA SPECTATE]",
		entry.model:GetFullName(),
		"| root:",
		root and root:GetFullName() or "pending",
		"| size:",
		boxSize,
		"| distance:",
		string.format(
			"%.2f",
			S.spectateDistance
		)
	)

	RunService:UnbindFromRenderStep(S.FREECAM_BIND_NAME)
	RunService:UnbindFromRenderStep(S.SPECTATE_BIND_NAME)
	RunService:UnbindFromRenderStep(CAMERA_BIND_NAME)
	S.cameraRenderBound = false
	S.freecamLookHeld = false
	S.spectateLookHeld = false
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	RunService:BindToRenderStep(
		S.SPECTATE_BIND_NAME,
		S.cutsceneProtection and Enum.RenderPriority.Last.Value + 100 or Enum.RenderPriority.Camera.Value + 500,
		S.spectateRenderStep
	)
	if S.startSpectateGuard then S.startSpectateGuard() end
	if S.hideCaptureUi then S.hideCaptureUi() end
	updateCameraUI()
	ugRefreshCameraNpcButtons()
end

function S.freecamRenderStep(dt)
    if S.killScene and not S.killScene.cfg.death then return end
	if S.unloading or not S.freecamActive then
		RunService:UnbindFromRenderStep(S.FREECAM_BIND_NAME)
		return
	end

	S.updateDetachedVisibility()
	if S.noShadows or (S.shadowLift or 0) > 0 then S.applyShadowLighting() end

	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end

	if S.freecamActive then
		local tau = S.freecamSmoothness * 0.008
		local elapsed = math.clamp(dt, 0, 0.1)
		local alpha = tau > 0 and (1 - math.exp(-elapsed / tau)) or 1
		S.freecamRenderYaw = (S.freecamRenderYaw or S.freecamYaw) + (S.freecamYaw - (S.freecamRenderYaw or S.freecamYaw)) * alpha
		S.freecamRenderPitch = (S.freecamRenderPitch or S.freecamPitch) + (S.freecamPitch - (S.freecamRenderPitch or S.freecamPitch)) * alpha
		local rotation =
			CFrame.Angles(
				0,
				S.freecamRenderYaw,
				0
			)
			*
			CFrame.Angles(
				S.freecamRenderPitch,
				0,
				0
			)

		local movement =
			Vector3.zero

		if UserInputService:IsKeyDown(Enum.KeyCode.W) then
			movement += rotation.LookVector
		end

		if UserInputService:IsKeyDown(Enum.KeyCode.S) then
			movement -= rotation.LookVector
		end

		if UserInputService:IsKeyDown(Enum.KeyCode.D) then
			movement += rotation.RightVector
		end

		if UserInputService:IsKeyDown(Enum.KeyCode.A) then
			movement -= rotation.RightVector
		end

		if UserInputService:IsKeyDown(Enum.KeyCode.E) then
			movement += Vector3.yAxis
		end

		if UserInputService:IsKeyDown(Enum.KeyCode.Q) then
			movement -= Vector3.yAxis
		end

		local speed =
			S.freecamSpeed

		if UserInputService:IsKeyDown(
			Enum.KeyCode.LeftShift
		)
			or UserInputService:IsKeyDown(
				Enum.KeyCode.RightShift
			)
		then
			speed *= 3
		end

		local position =
			(
				S.freecamCFrame
				or camera.CFrame
			).Position

		local desiredVelocity = movement.Magnitude > 0.001 and movement.Unit * speed or Vector3.zero
		if tau > 0 then
			local previousVelocity = S.freecamVelocity or Vector3.zero
			position += desiredVelocity * elapsed + (previousVelocity - desiredVelocity) * tau * alpha
			S.freecamVelocity = previousVelocity:Lerp(desiredVelocity, alpha)
		else
			S.freecamVelocity = desiredVelocity
			position += desiredVelocity * dt
		end

		local cf =
			CFrame.new(position)
			*
			rotation

		S.freecamCFrame = cf

		camera.CameraType = Enum.CameraType.Scriptable
		camera.CFrame = cf
		camera.Focus = CFrame.new(position + cf.LookVector * 16)

		return
	end

end

function S.spectateRenderStep(dt)
    if S.killScene and not S.killScene.cfg.death then return end
	if S.unloading or not S.spectateActive then
		RunService:UnbindFromRenderStep(S.SPECTATE_BIND_NAME)
		return
	end

	local target = S.spectateTarget
	if not target or not target.Parent then
		ugStopSpectate()
		return
	end
	local root = getSpectateRoot(target)
	if not root or not root:IsA("BasePart") then
		return
	end
	S.updateDetachedVisibility()

	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end

	local focus = root.Position + S.spectatePivotOffset
	local yaw = S.spectateYaw
	local pitch = S.spectatePitch
	local targetDistance = S.spectateDistance
	local distance = S.spectateRenderedDistance or targetDistance
	if dt and dt > 0 then
		local alpha = 1 - math.exp(-14 * dt)
		distance += (targetDistance - distance) * alpha
		if math.abs(targetDistance - distance) < 0.001 then
			distance = targetDistance
		end
	end
	S.spectateRenderedDistance = distance
	if S.spectateAutoFollow and not S.spectateLookHeld then
		local velocity = root.AssemblyLinearVelocity
		local forward = Vector3.new(velocity.X, 0, velocity.Z)
		if forward.Magnitude <= 1 then
			local look = root.CFrame.LookVector
			forward = Vector3.new(look.X, 0, look.Z)
		end
		if forward.Magnitude > 0.01 then
			yaw = math.atan2(-forward.X, -forward.Z)
			S.spectateYaw = yaw
		end
	end
	local rotation = CFrame.Angles(0, yaw, 0) * CFrame.Angles(pitch, 0, 0)
	local offset = S.spectatePositionOffset or Vector3.zero
    focus += CFrame.Angles(0,yaw,0).RightVector * offset.X + Vector3.new(0,offset.Y,0)
    local pos = focus - rotation.LookVector * distance
	if (pos-focus).Magnitude < 0.05 then pos = focus - rotation.LookVector*0.05 end
    local desired
    if S.firstPersonSpectate and S.firstPersonSpectate.enabled then
        pos=S.firstPersonEye(target,root,camera)
        desired=CFrame.new(pos)*rotation
        focus=pos+rotation.LookVector*10
    else
        desired=CFrame.lookAt(pos,focus)
    end
	S.spectateGuardDesired = desired
	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = desired
	camera.Focus = CFrame.new(focus)
end

function ugCameraRenderStep(dt)
    if S.killScene and not S.killScene.cfg.death then return end
	if S.unloading or S.freecamActive or S.spectateActive then
		return
	end

	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end

	if thirdPerson
		and S.thirdHardOverride
	then
		local root =
			ugGetPlayerCameraRoot()

		if not root then
			return
		end

		local pivot =
			root.Position
			+
			Vector3.new(
				0,
				2.2,
				0
			)

		ugForceScriptableCamera(
			ugCameraOrbitCFrame(
				pivot,
				S.thirdYaw,
				S.thirdPitch,
				math.clamp(
					S.thirdDistance,
					5,
					math.max(
						12,
						cameraMaxZoom
					)
				)
			),
			pivot
		)

		return
	end

	ugEnsureCameraRender()
end

S.connectAction(S.firstPersonButton,function()
	if S.unloading then
		return
	end
    if S.setFirstPersonSpectate then
        if not S.spectateActive then
            local actor=S.controlledCharacter()
            if not actor then return end
            ugSpectateEntry({model=actor,key="first-person-self"})
        end
        S.setFirstPersonSpectate(true)
        return
    end
	local camera = Workspace.CurrentCamera
	local character = S.controlledCharacter()
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not camera or not humanoid then
		return
	end

	thirdPerson = false
	ugStopSpectate()
	RunService:UnbindFromRenderStep(CAMERA_BIND_NAME)
	S.cameraRenderBound = false
	player.CameraMinZoomDistance = 0.5
	player.CameraMaxZoomDistance = 0.5
	player.CameraMode = Enum.CameraMode.LockFirstPerson
	camera.CameraSubject = humanoid
	camera.CameraType = Enum.CameraType.Custom
	S.lastCameraUiMode = ""
	updateCameraUI()
end)

S.connectAction(cameraToggleButton,function()
	thirdPerson =
		not thirdPerson

	S.cameraFightFrames = 0
	S.thirdHardOverride = false
	S.lastCameraUiMode = ""

	if thirdPerson then
		ugInitThirdOrbit()
		applyThirdPerson()
	else
		S.restorePlayerCameraSettings()
		ugEnsureCameraRender()

		if not S.freecamActive
			and not S.spectateActive
		then
			local camera =
				Workspace.CurrentCamera

			if camera then
				camera.CameraType =
					Enum.CameraType.Custom

				local subject =
					ugGetPlayerCameraSubject()

				if subject then
					camera.CameraSubject =
						subject
				end
			end
		end
	end

	updateCameraUI()
end)

S.connectAction(S.freecamToggleButton,
	ugToggleFreecam
)

S.connectAction(S.cameraAutoFollowButton,function()
	S.spectateAutoFollow =
		not S.spectateAutoFollow

	S.spectateFollowCFrame = nil

	ugUpdateSpectateFollowUI()
end)

S.connectAction(S.cameraStopSpectateButton,function()
	if S.freecamActive then
		ugStopFreecam(true)
	else
		ugStopSpectate()
	end
end)

S.connectAction(S.cameraRefreshButton,function()
	S.cameraDirty = true
	ugScanCameraNpcs(true)
end)

S.cameraNpcSearch:GetPropertyChangedSignal(
	"Text"
):Connect(function()
	S.cameraNpcSignature = ""
	ugRebuildCameraNpcList(true)
end)

S.spectateGuardConnections = {}
S.spectateCameraConnections = {}
S.spectateGuardBusy = false
S.spectateGuardWrites = 0

function S.stopSpectateGuard()
    if S.clearFirstPersonSpectate then S.clearFirstPersonSpectate() end
	for _, connection in ipairs(S.spectateGuardConnections) do connection:Disconnect() end
	for _, connection in ipairs(S.spectateCameraConnections) do connection:Disconnect() end
	table.clear(S.spectateGuardConnections)
	table.clear(S.spectateCameraConnections)
	S.spectateGuardCamera = nil
	S.spectateGuardDesired = nil
	S.spectateGuardBusy = false
	S.spectateGuardWrites = 0
end

function S.enforceSpectateCamera()
    if S.killScene and not S.killScene.cfg.death then return end
	if S.unloading or not S.spectateActive or not S.cutsceneProtection or S.spectateGuardBusy then return end
	local camera = Workspace.CurrentCamera
	if not camera or camera ~= S.spectateGuardCamera then return end
	if camera.CameraType == Enum.CameraType.Scriptable and camera.CFrame == S.spectateGuardDesired then return end
	if S.spectateGuardWrites >= 8 then return end
	S.spectateGuardWrites += 1
	S.spectateGuardBusy = true
	local ok, message = pcall(S.spectateRenderStep, 0)
	S.spectateGuardBusy = false
	if not ok then warn("[Lumin Camera]", message) end
end

function S.watchSpectateCamera()
	for _, connection in ipairs(S.spectateCameraConnections) do connection:Disconnect() end
	table.clear(S.spectateCameraConnections)
	if S.unloading or not S.spectateActive or not S.cutsceneProtection then
		S.spectateGuardCamera = nil
		return
	end
	S.spectateGuardCamera = Workspace.CurrentCamera
	S.spectateGuardDesired = nil
	local camera = S.spectateGuardCamera
	if not camera then return end
	for _, property in ipairs({"CFrame", "CameraType"}) do
		table.insert(S.spectateCameraConnections, camera:GetPropertyChangedSignal(property):Connect(S.enforceSpectateCamera))
	end
	S.enforceSpectateCamera()
end

function S.startSpectateGuard()
	S.stopSpectateGuard()
	if not S.spectateActive or not S.cutsceneProtection or S.unloading then return end
	table.insert(S.spectateGuardConnections, Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(S.watchSpectateCamera))
	table.insert(S.spectateGuardConnections, RunService.PreRender:Connect(function()
		S.spectateGuardWrites = 0
		S.enforceSpectateCamera()
	end))
	S.watchSpectateCamera()
end

function S.isPointerOverPanel()
	if not main.Visible then return false end
	local position = UserInputService:GetMouseLocation()
	local inset = game:GetService("GuiService"):GetGuiInset()
	if not gui.IgnoreGuiInset then position -= inset end
	local origin = main.AbsolutePosition
	local size = main.AbsoluteSize
	return position.X >= origin.X and position.Y >= origin.Y
		and position.X <= origin.X + size.X and position.Y <= origin.Y + size.Y
end

function S.releaseCameraLook()
	S.freecamLookHeld = false
	S.spectateLookHeld = false
	S.thirdLookHeld = false
	S.panelCameraLookHeld = false
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
end

ugKeepRootConnection(UserInputService.WindowFocusReleased:Connect(S.releaseCameraLook))

S.rootConnections[#S.rootConnections + 1] = UserInputService.InputBegan:Connect(function(input)
	if input.UserInputType
		~= Enum.UserInputType.MouseButton2
	then
		return
	end

	if S.waitingForPanelBind or S.waitingForUiBind or waitingForAnimationBind or UserInputService:GetFocusedTextBox() or S.isPointerOverPanel() then
		return
	end
	S.panelCameraLookHeld = true
	if S.freecamActive then
		S.freecamLookHeld = true
	elseif S.spectateActive then
		S.spectateLookHeld = true
	elseif thirdPerson
		and S.thirdHardOverride
	then
		S.thirdLookHeld = true
	else
		return
	end

	UserInputService.MouseBehavior =
		Enum.MouseBehavior.LockCurrentPosition
end)

S.rootConnections[#S.rootConnections + 1] = UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType
		~= Enum.UserInputType.MouseButton2
	then
		return
	end

	S.releaseCameraLook()
end)

S.rootConnections[#S.rootConnections + 1] = UserInputService.InputChanged:Connect(function(input)
	if input.UserInputType
		== Enum.UserInputType.MouseMovement
	then
		if S.freecamActive
			and S.freecamLookHeld
		then
			S.freecamYaw -=
				input.Delta.X
				*
				0.0025

			S.freecamPitch =
				math.clamp(
					S.freecamPitch
						-
						input.Delta.Y
						*
						0.0025,
					math.rad(-89),
					math.rad(89)
				)

		elseif S.spectateActive
			and S.spectateLookHeld
		then
			S.spectateYaw -=
				input.Delta.X
				*
				S.spectateMouseSensitivity

			S.spectatePitch =
				math.clamp(
					S.spectatePitch
						-
						input.Delta.Y
						*
						S.spectateMouseSensitivity,
					math.rad(-85),
					math.rad(85)
				)

		elseif thirdPerson
			and S.thirdHardOverride
			and S.thirdLookHeld
		then
			S.thirdYaw -=
				input.Delta.X
				*
				0.0025

			S.thirdPitch =
				math.clamp(
					S.thirdPitch
						-
						input.Delta.Y
						*
						0.0025,
					math.rad(-85),
					math.rad(85)
				)
		end

	elseif input.UserInputType
		== Enum.UserInputType.MouseWheel
	then
		if S.isPointerOverPanel() or UserInputService:GetFocusedTextBox() then return end
		local delta =
			input.Position.Z

		if S.spectateActive then
			S.spectateDistance =
				math.clamp(
					S.spectateDistance
						-
						delta
						*
						1.5,
					math.max(
						2.5,
						S.spectateRadius
							*
							0.65
					),
					math.max(
						24,
						S.spectateRadius
							*
							5
					)
				)

		elseif thirdPerson
			and S.thirdHardOverride
		then
			S.thirdDistance =
				math.clamp(
					S.thirdDistance
						-
						delta
						*
						2,
					5,
					math.max(
						12,
						cameraMaxZoom
					)
				)
		end
	end
end)

ugUpdateSpectateFollowUI()

RunService:UnbindFromRenderStep(
	CAMERA_BIND_NAME
)

S.cameraRenderBound = false

task.spawn(function()
	while gui.Parent do
		if thirdPerson
			and not S.freecamActive
			and not S.spectateActive
			and not S.thirdHardOverride
		then
			ugCheckThirdPersonFight()
		end

		task.wait(0.25)
	end
end)
function S.applyKnownMorphAppearance(model)
    local required = {
        ["134031923875296"] = true,
        ["117344367007423"] = true,
        ["77091922748069"] = true,
        ["120358116365097"] = true,
    }
    local found = {}
    local parts = {}
    for _, object in ipairs(model:GetDescendants()) do
        if object:IsA("BasePart") then
            local mesh = object:IsA("MeshPart") and object or object:FindFirstChildOfClass("SpecialMesh")
            local asset = mesh and tostring(mesh.MeshId) or ""
            local id = asset:match("^rbxassetid://(%d+)$") or asset:match("[?&]id=(%d+)") or asset:match("^(%d+)$")
            if id and required[id] then
                found[id] = true
                table.insert(parts, object)
            end
        end
    end
    for id in pairs(required) do if not found[id] then return 0 end end
    for _, part in ipairs(parts) do
        part.Transparency = 0
        part.LocalTransparencyModifier = 0
    end
    return #parts
end

function S.nativeAnimationSummary(npcName)
	local folder = findAnimationFolder(npcName)
	if not folder then
		return "Animations: not found"
	end

	local names = {}

	for _, object in ipairs(folder:GetDescendants()) do
		if object:IsA("Animation") then
			table.insert(names, object.Name)
		end
	end

	table.sort(names)

	if #names == 0 then
		return "Animations: folder exists, no Animation objects"
	end

	if #names > 5 then
		return "Animations: " .. table.concat(names, ", ", 1, 5) .. "..."
	end

	return "Animations: " .. table.concat(names, ", ")
end
getAnimationSummary = S.nativeAnimationSummary

function hideVisualTree(rootObject)
	if not rootObject then
		return
	end

	for _, object in ipairs(rootObject:GetDescendants()) do
		if object:IsA("BasePart") then

			if hiddenPartLTM[object] == nil then
				hiddenPartLTM[object] = object.LocalTransparencyModifier
			end

			if hiddenPartTransparency[object] == nil then
				hiddenPartTransparency[object] = object.Transparency
			end

			if hiddenPartCastShadow[object] == nil then
				hiddenPartCastShadow[object] = object.CastShadow
			end

			object.LocalTransparencyModifier = 1
			object.Transparency = 1
			object.CastShadow = false

		elseif object:IsA("Decal") or object:IsA("Texture") then
			if hiddenTransparency[object] == nil then
				hiddenTransparency[object] = object.Transparency
			end

			object.Transparency = 1

		elseif
			object:IsA("ParticleEmitter")
			or object:IsA("Trail")
			or object:IsA("Beam")
			or object:IsA("Fire")
			or object:IsA("Smoke")
			or object:IsA("Sparkles")
			or object:IsA("BillboardGui")
			or object:IsA("SurfaceGui")
			or object:IsA("Highlight")
		then
			if hiddenEnabled[object] == nil then
				hiddenEnabled[object] = object.Enabled
			end

			object.Enabled = false

		elseif object:IsA("ForceField") then
			if hiddenVisible[object] == nil then
				hiddenVisible[object] = object.Visible
			end

			object.Visible = false
		end
	end

	if rootObject:IsA("BasePart") then
		if hiddenPartLTM[rootObject] == nil then
			hiddenPartLTM[rootObject] = rootObject.LocalTransparencyModifier
		end

		if hiddenPartTransparency[rootObject] == nil then
			hiddenPartTransparency[rootObject] = rootObject.Transparency
		end

		if hiddenPartCastShadow[rootObject] == nil then
			hiddenPartCastShadow[rootObject] = rootObject.CastShadow
		end

		rootObject.LocalTransparencyModifier = 1
		rootObject.Transparency = 1
		rootObject.CastShadow = false
	end
end

function ugEnforceHiddenVisualsFast()
	if S.npcMorphTarget or S.npcMorphBatch then S.hideNpcMorphVisual() end
	for object in pairs(hiddenPartLTM) do
		if object and object.Parent then
			object.LocalTransparencyModifier = 1
			object.Transparency = 1
			object.CastShadow = false
		end
	end

	for object in pairs(hiddenTransparency) do
		if object and object.Parent then
			object.Transparency = 1
		end
	end

	for object in pairs(hiddenEnabled) do
		if object and object.Parent then
			object.Enabled = false
		end
	end

	for object in pairs(hiddenVisible) do
		if object and object.Parent then
			object.Visible = false
		end
	end
end

S.npcMorphHidden = {}
S.npcMorphConnections = {}

function S.restoreNpcMorphVisibility()
	S.npcMorphHiddenTarget = nil
	for _, connection in ipairs(S.npcMorphConnections) do connection:Disconnect() end
	table.clear(S.npcMorphConnections)
	for _, record in pairs(S.npcMorphHidden) do
		for _, connection in ipairs(record.connections) do connection:Disconnect() end
	end
	for part, record in pairs(S.npcMorphHidden) do
		pcall(function() part.LocalTransparencyModifier = record.value end)
	end
	table.clear(S.npcMorphHidden)
end

function S.trackNpcMorphPart(part)
	if S.npcMorphShowOriginals then return end
	if not part:IsA("BasePart") or S.npcMorphHidden[part] then return end
	local record = {value = part.LocalTransparencyModifier, connections = {}, writing = false, writes = 0}
	S.npcMorphHidden[part] = record
	local function enforce()
		if record.writing or record.writes >= 2 or S.npcMorphHidden[part] ~= record or S.unloading then return end
		if part.LocalTransparencyModifier ~= 1 then
			record.value = part.LocalTransparencyModifier
			record.writes += 1
			record.writing = true
			part.LocalTransparencyModifier = 1
			record.writing = false
		end
	end
	record.enforce = enforce
	record.connections[1] = part:GetPropertyChangedSignal("LocalTransparencyModifier"):Connect(enforce)
	record.connections[2] = part.Destroying:Connect(function()
		S.npcMorphHidden[part] = nil
		for _, connection in ipairs(record.connections) do connection:Disconnect() end
	end)
	enforce()
end

function S.hideNpcMorphVisual()
	if S.npcMorphShowOriginals and not S.npcMorphBatch then return end
	if S.npcMorphBatch then
		for _, part in ipairs(S.npcMorphBatch.masterParts or {}) do
			if part.Parent then part.LocalTransparencyModifier = 1 end
		end
		for part, record in pairs(S.npcMorphHidden) do
			if part.Parent then record.writes = 0; record.enforce() end
		end
		return
	end
	local target = S.npcMorphTarget
	if not target or not target:IsDescendantOf(Workspace) then return end
	if S.npcMorphHiddenTarget ~= target then
		S.restoreNpcMorphVisibility()
		S.npcMorphHiddenTarget = target
		S.npcMorphConnections[1] = target.DescendantAdded:Connect(S.trackNpcMorphPart)
		for _, part in ipairs(target:GetDescendants()) do S.trackNpcMorphPart(part) end
	end
	for part, record in pairs(S.npcMorphHidden) do
		if part.Parent then record.writes = 0; record.enforce() end
	end
end

function S.getMorphDriverRoot()
	local batch = S.npcMorphBatch
	if batch then
		local root = batch.driver and batch.driver:IsDescendantOf(Workspace) and getSpectateRoot(batch.driver)
		if not root then
			for target in pairs(batch.records) do
				root = target:IsDescendantOf(Workspace) and getSpectateRoot(target)
				if root then batch.driver = target; break end
			end
		end
		batch.driverCFrame = root and root.CFrame or batch.driverCFrame or CFrame.identity
		return {CFrame = batch.driverCFrame}
	end
	if S.npcMorphTarget or S.npcMorphBatch then
		if not S.npcMorphTarget:IsDescendantOf(Workspace) then
			removeMorph(false)
			if S.npcMorphStatus then S.npcMorphStatus.Text = "NPC disappeared — morph removed" end
			return nil
		end
		return getSpectateRoot(S.npcMorphTarget)
	end
	local character = S.controlledCharacter()
	return character and character:FindFirstChild("HumanoidRootPart")
end

function hideRealCharacter()
	if S.npcMorphTarget or S.npcMorphBatch then S.hideNpcMorphVisual(); return end
	local character = S.controlledCharacter()

	if character then
		hideVisualTree(character)
	end

	local camera = Workspace.CurrentCamera

	if camera then
		for _, object in ipairs(camera:GetChildren()) do
			if object:IsA("Model") and object ~= morphModel then
				local looksLikeCharacter =
					object:FindFirstChildOfClass("Humanoid") ~= nil
					or object:FindFirstChild("HumanoidRootPart", true) ~= nil
					or (
						object:FindFirstChild("Head", true) ~= nil
						and object:FindFirstChildWhichIsA("Motor6D", true) ~= nil
					)

				if looksLikeCharacter then
					hideVisualTree(object)
				end
			end
		end
	end
end

function restoreRealCharacter()
	for object, value in pairs(hiddenPartLTM) do
		if object and object.Parent then
			pcall(function()
				object.LocalTransparencyModifier = value
			end)
		end
	end

	for object, value in pairs(hiddenPartTransparency) do
		if object and object.Parent then
			pcall(function()
				object.Transparency = value
			end)
		end
	end

	for object, value in pairs(hiddenPartCastShadow) do
		if object and object.Parent then
			pcall(function()
				object.CastShadow = value
			end)
		end
	end

	for object, value in pairs(hiddenTransparency) do
		if object and object.Parent then
			pcall(function()
				object.Transparency = value
			end)
		end
	end

	for object, value in pairs(hiddenEnabled) do
		if object and object.Parent then
			pcall(function()
				object.Enabled = value
			end)
		end
	end

	for object, value in pairs(hiddenVisible) do
		if object and object.Parent then
			pcall(function()
				object.Visible = value
			end)
		end
	end

	hiddenPartLTM = {}
	hiddenPartTransparency = {}
	hiddenPartCastShadow = {}
	hiddenTransparency = {}
	hiddenEnabled = {}
	hiddenVisible = {}
end

function clearManualAnimationState()
	if manualStopConnection then
		manualStopConnection:Disconnect()
		manualStopConnection = nil
	end

	manualAnimationTrack = nil
	manualAnimationName = nil
	manualAnimationNpcName = nil
end

function S.stopNativeMorphAnimation()
	local track = manualAnimationTrack

	clearManualAnimationState()

	if track then
		pcall(function()
			track:Stop(0.12)
		end)
	end

	morphCurrentState = nil
end
stopManualAnimation = S.stopNativeMorphAnimation

function stopMorphTracks()
	stopManualAnimation()

	for _, track in pairs(morphTracks) do
		pcall(function()
			track:Stop(0.1)
		end)
	end

	morphTracks = {}
	morphCurrentTrack = nil
	morphCurrentState = nil
end

function ugFindVisualTargetModel(rootModel)
	if not rootModel
		or not rootModel:IsA("Model")
	then
		return nil
	end

	local target =
		rootModel:FindFirstChild(
			"Target",
			true
		)

	if target then
		for _, child in ipairs(
			target:GetDescendants()
		) do
			if child:IsA("Model")
				and child:FindFirstChildWhichIsA(
					"Bone",
					true
				)
			then
				return child
			end
		end

		for _, child in ipairs(
			target:GetDescendants()
		) do
			if child:IsA("Model")
				and child:FindFirstChildWhichIsA(
					"BasePart",
					true
				)
			then
				return child
			end
		end
	end

	for _, child in ipairs(
		rootModel:GetDescendants()
	) do
		if child:IsA("Model")
			and child ~= rootModel
			and child:FindFirstChildWhichIsA(
				"Bone",
				true
			)
		then
			return child
		end
	end

	return nil
end

function ugClearVisualFollowers()
	S.activeVisualTarget = nil
	S.activeVisualParts = {}
	S.activeVisualFollowers = {}
end

function ugRefreshVisualFollowers()
	S.activeVisualFollowers = {}

	if not morphRoot
		or not morphRoot.Parent
	then
		return
	end

	for _, part in ipairs(
		S.activeVisualParts or {}
	) do
		if part
			and part.Parent
			and part:IsA("BasePart")
		then
			table.insert(
				S.activeVisualFollowers,
				{
					part = part,
					relative =
						morphRoot.CFrame
						:ToObjectSpace(
							part.CFrame
						),
				}
			)
		end
	end
end

function ugMoveVisualFollowers(targetRootCFrame)
	for _, item in ipairs(
		S.activeVisualFollowers or {}
	) do
		local part = item.part

		if part
			and part.Parent
		then
			part.CFrame =
				targetRootCFrame
				*
				item.relative

			part.AssemblyLinearVelocity =
				Vector3.zero

			part.AssemblyAngularVelocity =
				Vector3.zero
		end
	end
end

function S.removeNativeMorph(showMessage)
    if S.stopAvatarPhysics then S.stopAvatarPhysics() end
	RunService:UnbindFromRenderStep(MORPH_BIND_NAME)

	if S.morphAnimatorGuard then
		S.morphAnimatorGuard:Disconnect()
		S.morphAnimatorGuard = nil
	end

	if S.morphDescendantGuard then
		S.morphDescendantGuard:Disconnect()
		S.morphDescendantGuard = nil
	end

	for _, connection in ipairs(S.morphTagConnections) do
		pcall(function()
			connection:Disconnect()
		end)
	end

	S.morphTagConnections = {}
	S.morphBlockedTags = {}
	S.morphPoseBones = {}
	S.morphPoseMotors = {}
	S.morphForeignTrackWarnings = 0
	S.morphNeutralIdle = false

	stopMorphTracks()

	if morphModel then
		pcall(function()
			morphModel:Destroy()
		end)
	end

	morphModel = nil
	morphRoot = nil
	morphAnimator = nil
	morphActiveName = nil

	S.morphRunState = false
	S.morphLastDriverState = ""
	S.morphLastDriverSpeed = 0

	ugClearVisualFollowers()

	restoreRealCharacter()

	morphStatusLabel.Text = "Active morph: off"

	if showMessage ~= false then
		selectedAnimLabel.Text = selectedMorphName
			and getAnimationSummary(selectedMorphName)
			or "Animations: —"
	end
end
removeMorph = S.removeNativeMorph

function ugMorphBelongsToClone(object, clone)
	return
		object == clone
		or (
			object
			and object:IsDescendantOf(clone)
		)
end

function ugResetMorphPose()
	for _, bone in ipairs(S.morphPoseBones) do
		if bone and bone.Parent then
			bone.Transform = CFrame.identity
		end
	end

	for _, motor in ipairs(S.morphPoseMotors) do
		if motor and motor.Parent then
			motor.Transform = CFrame.identity
		end
	end
end

function ugStripMorphIdentity(clone)
	local collectionService = game:GetService("CollectionService")
	local objects = {clone}

	for _, object in ipairs(clone:GetDescendants()) do
		table.insert(objects, object)
	end

	local removedTags = 0
	local removedAttributes = 0
	local severedRefs = 0

	S.morphBlockedTags = {}

	for _, object in ipairs(objects) do

		for _, tag in ipairs(collectionService:GetTags(object)) do
			S.morphBlockedTags[tag] = true

			pcall(function()
				collectionService:RemoveTag(object, tag)
			end)

			removedTags += 1
		end

		for attributeName in pairs(object:GetAttributes()) do
			pcall(function()
				object:SetAttribute(attributeName, nil)
			end)

			removedAttributes += 1
		end

		if object:IsA("ObjectValue") then
			local value = object.Value

			if value
				and not ugMorphBelongsToClone(value, clone)
			then
				object.Value = nil
				severedRefs += 1
			end
		end

		if object:IsA("Motor6D")
			or object:IsA("Weld")
			or object:IsA("ManualWeld")
			or object:IsA("Snap")
		then
			if object.Part0
				and not ugMorphBelongsToClone(object.Part0, clone)
			then
				object.Part0 = nil
				severedRefs += 1
			end

			if object.Part1
				and not ugMorphBelongsToClone(object.Part1, clone)
			then
				object.Part1 = nil
				severedRefs += 1
			end
		end
	end

	print(
		"[MORPH ISOLATE]",
		clone.Name,
		"| tags:",
		removedTags,
		"| attrs:",
		removedAttributes,
		"| external refs:",
		severedRefs
	)
end

function ugInstallMorphGuards()
	if not morphModel or not morphAnimator then
		return
	end

	local collectionService = game:GetService("CollectionService")

	if S.morphAnimatorGuard then
		S.morphAnimatorGuard:Disconnect()
	end

	S.morphAnimatorGuard =
		morphAnimator.AnimationPlayed:Connect(function(track)
            if S.avatarMirror and S.avatarMirror.animator==morphAnimator then return end
			task.defer(function()
				if not morphModel
					or not morphModel.Parent
					or not track
				then
					return
				end

				if track == morphCurrentTrack
					or track == manualAnimationTrack
				then
					return
				end

				pcall(function()
					track:Stop(0)
				end)

				if S.morphForeignTrackWarnings < 8 then
					S.morphForeignTrackWarnings += 1

					local animationId = "?"

					pcall(function()
						if track.Animation then
							animationId = track.Animation.AnimationId
						end
					end)

					warn(
						"[MORPH GUARD] stopped foreign track:",
						track.Name,
						animationId
					)
				end
			end)
		end)

	if S.morphDescendantGuard then
		S.morphDescendantGuard:Disconnect()
	end

	S.morphDescendantGuard =
		morphModel.DescendantAdded:Connect(function(object)
			if object == morphAnimator
				or object == morphAnimator.Parent
			then
				return
			end

			if object:IsA("Script")
				or object:IsA("LocalScript")
				or object:IsA("ModuleScript")
				or object:IsA("Humanoid")
				or object:IsA("AnimationController")
				or object:IsA("Animator")
			then
				task.defer(function()
					if object
						and object.Parent
						and morphModel
						and ugMorphBelongsToClone(object, morphModel)
					then
						object:Destroy()
					end
				end)
			end

			task.defer(function()
				if not object
					or not object.Parent
					or not morphModel
					or not ugMorphBelongsToClone(object, morphModel)
				then
					return
				end

				for _, tag in ipairs(collectionService:GetTags(object)) do
					pcall(function()
						collectionService:RemoveTag(object, tag)
					end)
				end

				for attributeName in pairs(object:GetAttributes()) do
					pcall(function()
						object:SetAttribute(attributeName, nil)
					end)
				end
			end)
		end)

	for tag in pairs(S.morphBlockedTags) do
		local connection =
			collectionService:GetInstanceAddedSignal(tag):Connect(function(object)
				if morphModel
					and ugMorphBelongsToClone(object, morphModel)
				then
					pcall(function()
						collectionService:RemoveTag(object, tag)
					end)
				end
			end)

		table.insert(S.morphTagConnections, connection)
	end
end

function ugStopForeignMorphTracks()
    if S.avatarMirror and S.avatarMirror.animator==morphAnimator then return end
	if not morphAnimator then
		return
	end

	for _, track in ipairs(morphAnimator:GetPlayingAnimationTracks()) do
		if track ~= morphCurrentTrack
			and track ~= manualAnimationTrack
		then
			pcall(function()
				track:Stop(0)
			end)
		end
	end
end
function prepareMorphClone(clone, preserveAvatarHumanoid)
	local visualTarget =
		ugFindVisualTargetModel(
			clone
		)

	ugStripMorphIdentity(clone)
    S.applyKnownMorphAppearance(clone)

	for _, object in ipairs(clone:GetDescendants()) do
		if
			object:IsA("Script")
			or object:IsA("LocalScript")
			or object:IsA("ModuleScript")
			or object:IsA("ProximityPrompt")
			or object:IsA("ClickDetector")
			or object:IsA("Sound")
		then
			object:Destroy()
		end
	end

	for _, object in ipairs(clone:GetDescendants()) do
		if (object:IsA("Humanoid") and not preserveAvatarHumanoid)
			or object:IsA("AnimationController")
            or (preserveAvatarHumanoid and object:IsA("Animator"))
		then
			object:Destroy()
		end
	end

    if preserveAvatarHumanoid then
        local humanoid=clone:FindFirstChildOfClass("Humanoid")
        if humanoid then
            humanoid.AutoRotate=false
            humanoid.PlatformStand=true
            humanoid.WalkSpeed=0
            humanoid.JumpPower=0
            humanoid.JumpHeight=0
            humanoid.BreakJointsOnDeath=false
            humanoid.RequiresNeck=false
            humanoid.DisplayDistanceType=Enum.HumanoidDisplayDistanceType.None
            humanoid.AutomaticScalingEnabled=false
            pcall(function() humanoid.EvaluateStateMachine=false end)
        end
    end
	S.morphPoseBones = {}
	S.morphPoseMotors = {}

	for _, object in ipairs(clone:GetDescendants()) do
		if object:IsA("Bone") then
			object.Transform = CFrame.identity
			table.insert(S.morphPoseBones, object)

		elseif object:IsA("Motor6D") then
			object.Transform = CFrame.identity
			table.insert(S.morphPoseMotors, object)
		end
	end

	local root =
		clone:FindFirstChild(
			"HumanoidRootPart",
			true
		)

	if not root
		or not root:IsA("BasePart")
	then
		root =
			clone:FindFirstChild(
				"RootPart",
				true
			)
	end

	if (
		not root
		or not root:IsA("BasePart")
	)
		and clone.PrimaryPart
	then
		root = clone.PrimaryPart
	end

	if not root
		or not root:IsA("BasePart")
	then
		root =
			clone:FindFirstChildWhichIsA(
				"BasePart",
				true
			)
	end

	if not root
		or not root:IsA("BasePart")
	then
		return nil, nil
	end

	S.activeVisualParts = {}
	S.activeVisualTarget = visualTarget

	local targetHasBones =
		visualTarget
		and visualTarget:FindFirstChildWhichIsA(
			"Bone",
			true
		)
		~= nil

	for _, object in ipairs(clone:GetDescendants()) do
		if object:IsA("BasePart") then
			object.CanCollide = false
			object.CanTouch = false
			object.CanQuery = false
			object.Massless = true

			local insideVisualTarget =
				visualTarget
				and object:IsDescendantOf(
					visualTarget
				)

			if insideVisualTarget
				and targetHasBones
			then

				object.Anchored = true

				table.insert(
					S.activeVisualParts,
					object
				)
			else
				object.Anchored = false
			end

			object.AssemblyLinearVelocity =
				Vector3.zero

			object.AssemblyAngularVelocity =
				Vector3.zero
		end
	end

	root.Anchored = true
	root.CanCollide = false
	root.CanTouch = false
	root.CanQuery = false

	return root, visualTarget
end

function ugAnimationSemantic(
	object,
	animationFolder
)
	local cursor = object

	while cursor
		and cursor ~= animationFolder
	do
		local lower =
			string.lower(
				tostring(cursor.Name)
			)

		if lower == "idle"
			or lower == "stand"
		then
			return "idle"
		end

		if lower == "run"
			or lower == "running"
		then
			return "run"
		end

		if lower == "walk"
			or lower == "walking"
		then
			return "walk"
		end

		if lower == "jump"
			or lower == "jumping"
		then
			return "jump"
		end

		if lower == "fall"
			or lower == "falling"
			or lower == "freefall"
		then
			return "fall"
		end

		cursor = cursor.Parent
	end

	return nil
end

function loadMorphAnimations(animationFolder)
	morphTracks = {}

	if not morphAnimator
		or not animationFolder
	then
		return
	end

	local semanticBest = {}

	for _, object in ipairs(
		animationFolder:GetDescendants()
	) do
		if object:IsA("Animation") then
			local key =
				string.lower(
					object.Name
				)

			local animationSnapshot =
				Instance.new("Animation")

			animationSnapshot.Name =
				object.Name

			animationSnapshot.AnimationId =
				object.AnimationId

			local success, track =
				pcall(function()
					return
						morphAnimator:LoadAnimation(
							animationSnapshot
						)
				end)

			animationSnapshot:Destroy()

			if success and track then
				if not morphTracks[key] then
					morphTracks[key] = track
				end

				local semantic =
					ugAnimationSemantic(
						object,
						animationFolder
					)

				if semantic then
					local weightObject =
						object:FindFirstChild(
							"Weight"
						)

					local weight = 1

					if weightObject
						and (
							weightObject:IsA(
								"NumberValue"
							)
							or weightObject:IsA(
								"IntValue"
							)
						)
					then
						weight =
							tonumber(
								weightObject.Value
							)
							or 1
					end

					if not semanticBest[semantic]
						or weight
							>
							semanticBest[semantic].weight
					then
						semanticBest[semantic] = {
							track = track,
							weight = weight,
						}
					end
				end
			else
				if not success then
					warn(
						"[Morph] Failed to load:",
						object:GetFullName()
					)
				end
			end
		end
	end

	for semantic, info in pairs(
		semanticBest
	) do
		morphTracks[semantic] =
			info.track
	end

	if not morphTracks.run
		and morphTracks.walk
	then
		morphTracks.run =
			morphTracks.walk
	end

	if not morphTracks.walk
		and morphTracks.run
	then
		morphTracks.walk =
			morphTracks.run
	end

	for key, track in pairs(
		morphTracks
	) do
		if track then
			if key == "idle"
				or key == "walk"
				or key == "run"
				or key == "angryrun"
			then
				track.Looped = true
			end

			if key == "idle" then
				track.Priority =
					Enum.AnimationPriority.Idle
			elseif key == "walk"
				or key == "run"
				or key == "angryrun"
			then
				track.Priority =
					Enum.AnimationPriority.Movement
			else
				track.Priority =
					Enum.AnimationPriority.Action
			end
		end
	end
end

function playMorphState(state)

	if manualAnimationTrack and manualAnimationTrack.IsPlaying then
		return
	end

    local assigned = S.getLocomotionOverride(morphActiveName, state)
    if not assigned and S.nativeLocomotionTrack and morphTracks.walk == S.nativeLocomotionTrack and (state == "idle" or state == "walk" or state == "run") then
        local track = S.nativeLocomotionTrack
        if morphCurrentTrack and morphCurrentTrack ~= track then morphCurrentTrack:Stop(0.12) end
        local speed = state == "idle" and 0 or math.clamp((S.morphLastDriverSpeed or 0)/16, 0, 3)*S.getClipSpeed(morphActiveName, state)
        morphCurrentTrack, morphCurrentState = track, state
        S.morphNeutralIdle = false
        if not track.IsPlaying then track:Play(0.12, 1, speed) end
        track:AdjustSpeed(speed)
        return
    end
	if morphCurrentState == state then
		return
	end

	local track = morphTracks[assigned and string.lower(assigned) or state]

	if not track then
		if state == "jump" or state == "fall" or state == "falling" then
			return
		end

		track = morphTracks["idle"]
		state = "idle"
	end

	if morphCurrentTrack and morphCurrentTrack ~= track then
		pcall(function()
			morphCurrentTrack:Stop(0.12)
		end)
	end

	S.morphNeutralIdle =
		state == "idle"
		and track == nil

	if S.morphNeutralIdle then
		morphCurrentTrack = nil
		morphCurrentState = "idle"

		ugStopForeignMorphTracks()
		ugResetMorphPose()

		if S.morphLastDriverState ~= "idle" then
			S.morphLastDriverState = "idle"

			print(
				"[MORPH DRIVER]",
				morphActiveName or "?",
				"-> idle (neutral pose)",
				"| local speed:",
				string.format(
					"%.2f",
					S.morphLastDriverSpeed or 0
				)
			)
		end

		return
	end

	S.activateClipSpeed(morphActiveName, assigned or state)
	morphCurrentTrack = track
	morphCurrentState = state

	if S.morphLastDriverState
		~= state
	then
		S.morphLastDriverState =
			state

		print(
			"[MORPH DRIVER]",
			morphActiveName or "?",
			"->",
			state,
			"| local speed:",
			string.format(
				"%.2f",
				S.morphLastDriverSpeed or 0
			)
		)
	end

	if assigned and track then track.Looped = true end
	if track and not track.IsPlaying then
		pcall(function()
			track:Play(0.12, 1, S.animationPlaybackSpeed)
		end)
	end
end

function getMorphState()

	local character =
		S.controlledCharacter()

	if not character then
		S.morphRunState = false
		S.morphLastDriverSpeed = 0
		return "idle"
	end

	local humanoid =
		character:FindFirstChildOfClass(
			"Humanoid"
		)

	local root =
		character:FindFirstChild(
			"HumanoidRootPart"
		)
		or character:FindFirstChild(
			"RootPart"
		)

	if not root
		or not root:IsA("BasePart")
	then
		S.morphRunState = false
		S.morphLastDriverSpeed = 0
		return "idle"
	end

	local velocity =
		root.AssemblyLinearVelocity

	local horizontalSpeed =
		Vector3.new(
			velocity.X,
			0,
			velocity.Z
		).Magnitude

	S.morphLastDriverSpeed =
		horizontalSpeed

	local humanoidState =
		humanoid
		and humanoid:GetState()
		or nil

	if humanoidState
		== Enum.HumanoidStateType.Jumping
	then
		S.morphRunState = false

		if morphTracks.jump then
			return "jump"
		end
	end

	if humanoidState
		== Enum.HumanoidStateType.Freefall
	then
		S.morphRunState = false

		if velocity.Y > 1.5
			and morphTracks.jump
		then
			return "jump"
		end

		if morphTracks.fall then
			return "fall"
		end

		if morphTracks.falling then
			return "falling"
		end
	end

	if humanoid
		and humanoid.FloorMaterial
			== Enum.Material.Air
	then
		if velocity.Y > 3
			and morphTracks.jump
		then
			S.morphRunState = false
			return "jump"

		elseif velocity.Y < -3
			and (
				morphTracks.fall
				or morphTracks.falling
			)
		then
			S.morphRunState = false

			return
				morphTracks.fall
				and "fall"
				or "falling"
		end
	end

	if horizontalSpeed
		<= S.morphDriverIdleSpeed
	then
		S.morphRunState = false
		return "idle"
	end

	if S.morphRunState then
		if horizontalSpeed
			<= S.morphDriverRunExit
		then
			S.morphRunState = false
		end
	else
		if horizontalSpeed
			>= S.morphDriverRunEnter
		then
			S.morphRunState = true
		end
	end

	if S.morphRunState
		and morphTracks.run
	then
		return "run"
	end

	if morphTracks.walk then
		return "walk"
	end

	if morphTracks.run then
		return "run"
	end

	return "idle"
end

function S.applyNativeMorph(npcName)
	if not npcName then
		selectedMorphLabel.Text = "Select an NPC first"
		return
	end

	local sourceNpc = findMorphSourceModel(npcName)

	if not sourceNpc then
		selectedAnimLabel.Text = "Model not found"
		return
	end

	local destination = S.npcMorphPending
	removeMorph(false)
	S.npcMorphTarget = destination

    local savedArchivable = {}
    local sourceObjects = sourceNpc:GetDescendants()
    table.insert(sourceObjects,1,sourceNpc)
    local success, clone = pcall(function()
        for _, object in ipairs(sourceObjects) do
            savedArchivable[object] = object.Archivable
            object.Archivable = true
        end
        return sourceNpc:Clone()
    end)
    for object, value in pairs(savedArchivable) do
        pcall(function() object.Archivable = value end)
    end

	if not success or not clone then
		selectedAnimLabel.Text = "Failed to clone NPC"
		return
	end

	clone.Name = "__LOCAL_MORPH_" .. npcName

	local preparedRoot, visualTarget =
		prepareMorphClone(clone, S.avatarSkins and S.avatarSkins.entries[npcName]~=nil)

	if not preparedRoot then
		clone:Destroy()
		selectedAnimLabel.Text = "NPC has no HumanoidRootPart / RootPart"
		return
	end

    local animationController = S.avatarSkins and S.avatarSkins.entries[npcName] and clone:FindFirstChildOfClass("Humanoid")
    if not animationController then
        animationController=Instance.new("AnimationController")
        animationController.Name=visualTarget and "LocalMorphVisualAnimationController" or "LocalMorphAnimationController"
        animationController.Parent=visualTarget or clone
    end

	local animator =
		Instance.new("Animator")

	animator.Parent =
		animationController

    if S.avatarSkins and S.avatarSkins.entries[npcName] then
        S.stopAvatarPhysics()
        local parts={}
        for _,part in ipairs(clone:GetDescendants()) do
            if part:IsA("BasePart") then parts[#parts+1]=part end
        end
        local function isolate()
            for _,part in ipairs(parts) do
                if part.Parent then
                    part.CanCollide=false
                    part.CanTouch=false
                    part.CanQuery=false
                    part.Massless=true
                end
            end
        end
        isolate()
        S.avatarPhysicsConnection=RunService.PreSimulation:Connect(function()
            if S.unloading or not clone.Parent then S.stopAvatarPhysics();return end
            isolate()
        end)
    end
	clone.Parent = Workspace

	S.nativeScaleModel = clone
	S.nativeBaseScale = sourceNpc:GetScale()
	S.nativeLocomotionTrack = nil
	morphModel = clone
	morphRoot = preparedRoot
	morphAnimator = animator
	morphActiveName = npcName
    if S.avatarSkins and S.avatarSkins.entries[npcName] then S.startAvatarMirror(animator) end

	S.morphRunState = false
	S.morphLastDriverState = ""
	S.morphLastDriverSpeed = 0
	S.morphNeutralIdle = false
	S.morphForeignTrackWarnings = 0

	if visualTarget
		and #S.activeVisualParts > 0
	then
		ugRefreshVisualFollowers()

		print(
			"[DUAL RIG]",
			npcName,
			"| target:",
			visualTarget.Name,
			"| visual parts:",
			#S.activeVisualParts,
			"| bones:",
			#visualTarget:GetDescendants()
		)
	end

	local animationFolder = sourceNpc:FindFirstChildWhichIsA("Animation", true) and sourceNpc or findAnimationFolder(npcName)
	if animationFolder and not S.avatarMirror then
		loadMorphAnimations(animationFolder)
	else
		morphTracks = {}
	end

    local speedController = sourceNpc:FindFirstChild("SpeedController", true)
    local movementAnimation = speedController and speedController:FindFirstChild("IdleAnimation")
    if movementAnimation and movementAnimation:IsA("Animation") and not morphTracks.walk and not morphTracks.run then
        local track = morphTracks[string.lower(movementAnimation.Name)]
        if track then
            morphTracks.idle, morphTracks.walk, morphTracks.run = track, track, track
            S.nativeLocomotionTrack = track
            track.Looped = true
            track.Priority = Enum.AnimationPriority.Movement
        end
    end
	ugInstallMorphGuards()

	local playerRoot = S.getMorphDriverRoot()

	if playerRoot then
		local offset = getOffsetForName(npcName)

		local rotation = v11GetRotation(npcName)

		local targetCF =
			playerRoot.CFrame
			* CFrame.new(
				offset.X,
				offset.Y,
				offset.Z
			)
			* CFrame.Angles(
				math.rad(rotation.X),
				math.rad(rotation.Y),
				math.rad(rotation.Z)
			)

		morphRoot.CFrame =
			targetCF

		ugMoveVisualFollowers(
			targetCF
		)
	end

	hideRealCharacter()

	morphStatusLabel.Text = "Active morph: " .. npcName

	if not S.avatarMirror and not destination and morphTracks["idle"] then
		playMorphState("idle")
	end

	RunService:UnbindFromRenderStep(MORPH_BIND_NAME)

	RunService:BindToRenderStep(
		MORPH_BIND_NAME,
		Enum.RenderPriority.Camera.Value + 250,
		function()
			if
				not morphModel
				or not morphModel.Parent
				or not morphRoot
				or not morphRoot.Parent
			then
				return
			end

			local currentPlayerRoot = S.getMorphDriverRoot()
			if not currentPlayerRoot then
				return
			end

			local offset = getOffsetForName(morphActiveName)

			local rotation = v11GetRotation(morphActiveName)

			local targetCF =
				currentPlayerRoot.CFrame
				* CFrame.new(
					offset.X,
					offset.Y,
					offset.Z
				)
				* CFrame.Angles(
					math.rad(rotation.X),
					math.rad(rotation.Y),
					math.rad(rotation.Z)
				)

			morphRoot.CFrame =
				targetCF

			ugMoveVisualFollowers(
				targetCF
			)

			if morphAnimator and not S.avatarMirror then
				if not S.npcMorphTarget then playMorphState(getMorphState()) end

				ugStopForeignMorphTracks()

				if S.morphNeutralIdle
					and not manualAnimationTrack
					and not S.npcMorphTarget
				then
					ugResetMorphPose()
				end
			end
		end
	)
end
applyMorph = S.applyNativeMorph
S.manualLocomotion = {}
function S.getLocomotionOverride(name, state)
	local map = S.manualLocomotion[name]
	return map and map[state]
end
function S.isLocomotionOverride(name, clip)
	local map = S.manualLocomotion[name]
	return map and (map.idle == clip or map.walk == clip or map.run == clip) or false
end
function S.setLocomotionOverride(name, state, clip)
	if not name or (state ~= "idle" and state ~= "walk" and state ~= "run") then return end
	local map = S.manualLocomotion[name] or {}
	S.manualLocomotion[name] = map
	map[state] = map[state] ~= clip and clip or nil
	if morphActiveName == name then morphCurrentState = nil end
	if S.activeTargetAuto and S.activeTargetAuto.name == name then S.activeTargetAuto.autoState = nil end
	for _, record in pairs(S.multiMorphs or {}) do
		if record.name == name then record.autoState = nil end
	end
	if S.npcMorphBatch then
		for _, record in pairs(S.npcMorphBatch.records or {}) do
			if record.name == name then record.autoState = nil end
		end
	end
end

function S.nativeAnimationObjects(npcName)
	local folder = findAnimationFolder(npcName)
	local result = {}

	if not folder then
		return result
	end

	for _, object in ipairs(folder:GetDescendants()) do
		if object:IsA("Animation") then
			table.insert(result, object)
		end
	end

	table.sort(result, function(a, b)
		return string.lower(a.Name) < string.lower(b.Name)
	end)

	return result
end
getAnimationObjectsForNpc = S.nativeAnimationObjects

function getBindTableForNpc(npcName)
	if not animationBinds[npcName] then
		animationBinds[npcName] = {}
	end

	return animationBinds[npcName]
end

function getAnimationModeTableForNpc(npcName)
	if not animationBindModes[npcName] then
		animationBindModes[npcName] = {}
	end

	return animationBindModes[npcName]
end

function getAnimationMode(npcName, animationName)
	local modes =
		getAnimationModeTableForNpc(
			npcName
		)

	return
		modes[animationName]
		or "once"
end

function setAnimationMode(npcName, animationName, mode)
	if not npcName
		or not animationName
	then
		return
	end

	local modes =
		getAnimationModeTableForNpc(
			npcName
		)

	if mode == "loop" then
		modes[animationName] =
			"loop"
	else
		modes[animationName] =
			"once"
	end
end

function isManualAnimationActive(
	npcName,
	animationName
)

	if morphActiveName == npcName
		and universalLibraryMorphs
		and universalLibraryMorphs[npcName]
	then
		return
			v11UniversalManualMode == true
			and v11UniversalCurrentName
				== animationName
	end

	return
		manualAnimationTrack ~= nil
		and manualAnimationTrack.IsPlaying
		and manualAnimationNpcName
			== npcName
		and manualAnimationName
			== animationName
end

function keyName(binding)
	if not binding
		or binding == Enum.KeyCode.Unknown
	then
		return "—"
	end

	if binding == "MouseButton1" then
		return "LMB"
	elseif binding == "MouseButton2" then
		return "RMB"
	elseif binding == "MouseButton3" then
		return "MMB"
	end

	if typeof(binding) == "EnumItem" then
		return binding.Name
	end

	return tostring(binding)
end

function inputToAnimationBinding(input)
	if input.UserInputType
		== Enum.UserInputType.MouseButton1
	then
		return "MouseButton1"

	elseif input.UserInputType
		== Enum.UserInputType.MouseButton2
	then
		return "MouseButton2"

	elseif input.UserInputType
		== Enum.UserInputType.MouseButton3
	then
		return "MouseButton3"

	elseif input.UserInputType
		== Enum.UserInputType.Keyboard
		and input.KeyCode
		~= Enum.KeyCode.Unknown
	then
		return input.KeyCode
	end

	return nil
end

function S.playNativeMorphAnimation(npcName, animationName, playMode)
	if not npcName or not animationName then
		return false
	end

	if morphActiveName ~= npcName or not morphModel then
		selectMorph(npcName)
		applyMorph(npcName)
	end

	if morphActiveName ~= npcName or not morphAnimator then
		return false
	end

	local track = morphTracks[string.lower(animationName)]

	if not track then
		return false
	end

	stopManualAnimation()

	if morphCurrentTrack and morphCurrentTrack ~= track then
		pcall(function()
			morphCurrentTrack:Stop(0.1)
		end)
	end

	morphCurrentTrack = nil
	morphCurrentState = nil

	S.activateClipSpeed(npcName, animationName)
	manualAnimationTrack = track
	manualAnimationName = animationName
	manualAnimationNpcName = npcName

	local requestedLoop =
		playMode == "loop"

	pcall(function()
		track.Priority = Enum.AnimationPriority.Action4
		track.Looped = requestedLoop
	end)

	pcall(function()
		track:Play(0.1, 1, S.animationPlaybackSpeed)
	end)

	manualStopConnection = track.Stopped:Connect(function()
		if manualAnimationTrack == track then
			clearManualAnimationState()
			morphCurrentState = nil
		end
	end)

	return true
end
playManualMorphAnimation = S.playNativeMorphAnimation

function setAnimationBind(npcName, animationName, binding)
	if not npcName or not animationName then
		return
	end

	local binds = getBindTableForNpc(npcName)

	if binding then

		for otherAnimation, otherKey in pairs(binds) do
			if otherKey == binding then
				binds[otherAnimation] = nil
			end
		end
	end

	binds[animationName] = binding
end

function refreshAnimationNpcSelection()
	for name, button in pairs(animationNpcButtons) do
		local selected = (name == selectedAnimationNpcName)
		button:SetAttribute("Selected", selected)
		button.BackgroundColor3 = selected and COL.buttonSelected or COL.button
		button.TextColor3 = selected and COL.text or COL.subtext
	end
end

function rebuildAnimationRows()
	for _, child in ipairs(animationScroll:GetChildren()) do
		if child:IsA("Frame") or child:IsA("TextLabel") then
			child:Destroy()
		end
	end

	local npcName = selectedAnimationNpcName

	animationSelectedNpcLabel.Text = npcName and ("NPC: " .. npcName) or "NPC: —"

	if not npcName then
		local empty = makeLabel(
			animationScroll,
			"Select an NPC on the left.",
			UDim2.new(1, -4, 0, 34),
			UDim2.new(),
			11,
			COL.dim,
			Enum.Font.Gotham
		)
		empty.LayoutOrder = 1
		return
	end

	local animations = getAnimationObjectsForNpc(npcName)

	if #animations == 0 then
		local empty = makeLabel(
			animationScroll,
			"No Animation objects found. Native NPCs use Assets.Animations.NPCs; custom models use their descendants.",
			UDim2.new(1, -4, 0, 44),
			UDim2.new(),
			10,
			COL.dim,
			Enum.Font.Gotham
		)
		empty.TextWrapped = true
		empty.LayoutOrder = 1
		return
	end

	local binds = getBindTableForNpc(npcName)

	for index, animationObject in ipairs(animations) do
		local animationName = animationObject.Name

		local animationMeta =
			type(animationObject) == "table"
			and animationObject
			or nil

		local isLibraryAnimation =
			animationMeta
			and animationMeta.__LuminLibrary == true
			or false

		local isEmptyLibraryAnimation =
			isLibraryAnimation
			and animationMeta.__LuminEmpty == true
			or false

		local isRuntimeOnlyLibraryAnimation =
			isLibraryAnimation
			and animationMeta.__LuminRuntimeOnly == true
			or false

		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, -4, 0, 42)
		row.BackgroundColor3 = COL.panel
		row.BorderSizePixel = 0
		row.LayoutOrder = index
		row.Parent = animationScroll
		corner(row, 7)
		stroke(row, COL.stroke, 0.55, 1)

		local animationDisplayName =
			animationName

		if isLibraryAnimation then
			if isEmptyLibraryAnimation then
				animationDisplayName =
					animationName
					..
					"  · EMPTY"

			elseif isRuntimeOnlyLibraryAnimation then
				animationDisplayName =
					animationName
					..
					"  · RUNTIME ID"

			else
				animationDisplayName =
					animationName
					..
					string.format(
						"  · %df · %.2fs",
						animationMeta.__LuminFrames
							or 0,
						animationMeta.__LuminDuration
							or 0
					)
			end
		end

		local nameLabel = makeLabel(
			row,
			animationDisplayName,
			UDim2.new(1, -316, 1, 0),
			UDim2.new(0, 10, 0, 0),
			11,
			COL.text,
			Enum.Font.GothamMedium
		)
		nameLabel.TextTruncate = Enum.TextTruncate.AtEnd

		local playButton = makeButton(
			row,
			"PLAY",
			UDim2.new(0, 48, 0, 28),
			UDim2.new(1, -306, 0.5, -14),
			COL.purple
		)
		playButton.TextSize = 10

		local currentMode =
			getAnimationMode(
				npcName,
				animationName
			)

		local modeButton = makeButton(
			row,
			currentMode == "loop"
				and "LOOP"
				or "ONCE",
			UDim2.new(0, 62, 0, 28),
			UDim2.new(1, -252, 0.5, -14),
			currentMode == "loop"
				and COL.buttonSelected
				or COL.button
		)
		modeButton.TextSize = 9

		if isEmptyLibraryAnimation then
			playButton.Text = "EMPTY"
			playButton.BackgroundColor3 =
				COL.button
			nameLabel.TextColor3 =
				COL.dim
		end

		local bindButton = makeButton(
			row,
			"Bind: " .. keyName(binds[animationName]),
			UDim2.new(0, 132, 0, 28),
			UDim2.new(1, -184, 0.5, -14),
			COL.button
		)
		bindButton.TextSize = 10

		local clearButton = makeButton(
			row,
			"×",
			UDim2.new(0, 28, 0, 28),
			UDim2.new(1, -34, 0.5, -14),
			Color3.fromRGB(64, 39, 45)
		)
		clearButton.TextSize = 15
		row.Size = UDim2.new(1, -4, 0, 112)
		nameLabel.Size = UDim2.new(1, -154, 0, 30)
		nameLabel.Position = UDim2.fromOffset(10, 2)
		for _, button in ipairs({playButton, modeButton, bindButton, clearButton}) do
			button.Position = UDim2.new(button.Position.X.Scale, button.Position.X.Offset, 0, 40)
		end
		local speedButton = makeButton(row, string.format("Speed %.2f×", S.getClipSpeed(npcName, animationName)), UDim2.fromOffset(132, 24), UDim2.new(1, -142, 0, 5), COL.slider)
		speedButton.TextSize = 10
		local speedSlider = createSlider(row, "Speed of this animation", 0.25, 10, 0.05, S.getClipSpeed(npcName, animationName), 114, function(value)
			S.saveClipSpeed(npcName, animationName, value)
			speedButton.Text = string.format("Speed %.2f×", value)
		end)
		speedSlider.Holder.Visible = false
		S.connectAction(speedButton,function()
			local expanded = not speedSlider.Holder.Visible
			speedSlider.Holder.Visible = expanded
			row.Size = UDim2.new(1, -4, 0, expanded and 176 or 112)
		end)

		for i, state in ipairs({"idle", "walk", "run"}) do
			local assigned = S.getLocomotionOverride(npcName, state) == animationName
			local roleButton = makeButton(row, (assigned and "✓ " or "Use as ") .. string.upper(state), UDim2.new(1/3, -12, 0, 24), UDim2.new((i-1)/3, 6, 0, 78), assigned and COL.buttonSelected or COL.button)
			roleButton.TextSize = 10
			S.connectAction(roleButton,function()
				if isEmptyLibraryAnimation then
					animationHintLabel.Text = "This animation has no frames or usable ID."
					return
				end
				S.setLocomotionOverride(npcName, state, animationName)
				animationHintLabel.Text = string.upper(state) .. ": " .. (S.getLocomotionOverride(npcName, state) or "automatic detection")
				rebuildAnimationRows()
			end)
		end

		S.connectAction(playButton,function()
			if isEmptyLibraryAnimation then
				animationHintLabel.Text =
					animationName
					..
					" is empty: 0 frames / 0 sec. Use another AnimationId or republish the clip."

				return
			end

			task.spawn(function()
				local mode =
					getAnimationMode(
						npcName,
						animationName
					)

				if mode == "loop"
					and isManualAnimationActive(
						npcName,
						animationName
					)
				then
					stopManualAnimation(npcName)

					animationHintLabel.Text =
						"LOOP disabled: "
						..
						animationName

					return
				end

				local ok =
					playManualMorphAnimation(
						npcName,
						animationName,
						mode
					)

				if not ok then
					animationHintLabel.Text =
						"Failed to play "
						..
						animationName
						..
						". Check the model/Animation."
				else
					animationHintLabel.Text =
						(mode == "loop"
							and "LOOP: "
							or "ONCE: ")
						..
						npcName
						..
						" / "
						..
						animationName
				end
			end)
		end)

		S.connectAction(modeButton,function()
			local oldMode =
				getAnimationMode(
					npcName,
					animationName
				)

			local newMode =
				oldMode == "loop"
				and "once"
				or "loop"

			setAnimationMode(
				npcName,
				animationName,
				newMode
			)

			rebuildAnimationRows()

			animationHintLabel.Text =
				animationName
				..
				(newMode == "loop"
					and ": LOOP — the bind toggles looping."
					or ": ONCE — the bind plays once.")
		end)

		S.connectAction(bindButton,function()
			if S.cancelUiBind then S.cancelUiBind() end
			S.waitingForPanelBind = false
			S.panelBindButton.Text = "Panel key: " .. S.panelToggleKey.Name
			sideHint.Text = S.panelToggleKey.Name .. " — panel"
			waitingForAnimationBind = {
				npcName = npcName,
				animationName = animationName,
				button = bindButton,
			}

			bindButton.Text = "KEY / MOUSE..."
			animationHintLabel.Text =
				"Bind for " .. animationName .. ": key/LMB/RMB/MMB. Current mode: " .. string.upper(getAnimationMode(npcName, animationName)) .. "."
		end)

		S.connectAction(clearButton,function()
			setAnimationBind(npcName, animationName, nil)
			bindButton.Text = "Bind: —"
			animationHintLabel.Text = "Bind cleared: " .. animationName
		end)
	end
end

function selectAnimationNpc(name)
	selectedAnimationNpcName = name
	refreshAnimationNpcSelection()
	rebuildAnimationRows()
end

function rebuildAnimationNpcList(force)
	local signature = table.concat(morphNames, "\31")

	if not force and signature == animationListSignature then
		return
	end

	animationListSignature = signature

	for _, child in ipairs(animationNpcScroll:GetChildren()) do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end

	animationNpcButtons = {}

	for index, name in ipairs(morphNames) do
        if S.economyMode and name~=selectedAnimationNpcName and name~=selectedMorphName then continue end
		local animations = getAnimationObjectsForNpc(name)
		local label = name .. "  · " .. tostring(#animations)

		local button = makeButton(
			animationNpcScroll,
			label,
			UDim2.new(1, -4, 0, 34),
			UDim2.new(),
			COL.button
		)

		button.TextXAlignment = Enum.TextXAlignment.Left
		button.Text = "  " .. label
		button.TextSize = 10
		button.LayoutOrder = index

		animationNpcButtons[name] = button

		S.connectAction(button,function()
			selectAnimationNpc(name)
		end)
	end

	if not selectedAnimationNpcName and #morphNames > 0 then
		selectedAnimationNpcName = selectedMorphName or morphNames[1]
	end

	local stillExists = false
	for _, name in ipairs(morphNames) do
		if name == selectedAnimationNpcName then
			stillExists = true
			break
		end
	end

	if not stillExists then
		selectedAnimationNpcName = morphNames[1]
	end

	selectAnimationNpc(selectedAnimationNpcName)
end

S.connectAction(stopManualAnimationButton,function()
	stopManualAnimation()
	animationHintLabel.Text = "Manual animation stopped."
end)
function updateOffsetSlidersForSelected()
	local offset = getOffsetForName(selectedMorphName)

	morphOffsetX = offset.X
	morphOffsetY = offset.Y
	morphOffsetZ = offset.Z

	xSlider.SetValue(offset.X, false)
	ySlider.SetValue(offset.Y, false)
	zSlider.SetValue(offset.Z, false)
end

function refreshMorphButtonSelection()
	for name, button in pairs(morphButtons) do
		local selected = (name == selectedMorphName)
		button:SetAttribute("Selected", selected)
		button.BackgroundColor3 = selected and COL.buttonSelected or COL.button
		button.TextColor3 = selected and COL.text or COL.subtext
	end
end

selectMorph = function(name)
    if S.profileSelect then S.profileSelect(name) end
	selectedMorphName = name
	selectedMorphLabel.Text = name or "Not selected"

	if name then
		selectedAnimLabel.Text = getAnimationSummary(name)
	else
		selectedAnimLabel.Text = "Animations: —"
	end

	updateOffsetSlidersForSelected()
	refreshMorphButtonSelection()

	if name then
		selectedAnimationNpcName = name
		refreshAnimationNpcSelection()
		rebuildAnimationRows()
	end
end

function getMorphSignature(names)
	return table.concat(names, "\31")
end

function rebuildMorphList(force)
	local newNames = collectMorphNames()
	local signature = getMorphSignature(newNames)

	if not force and signature == morphListSignature then
		return
	end

	morphNames = newNames
	morphListSignature = signature

	for _, child in ipairs(morphScroll:GetChildren()) do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end

	if S.customMorphCards then for _,child in ipairs(S.customMorphCards:GetChildren()) do if child:IsA("TextButton") then child:Destroy() end end end
	morphButtons = {}

	local filter = string.lower(morphSearch.Text or "")
	local order = 0

	for _, name in ipairs(morphNames) do
        if S.economyMode and order>=80 then break end
		local lower = string.lower(name)

		if (filter == "" or string.find(lower, filter, 1, true)) and (not S.matchesMorphFilters or S.matchesMorphFilters(name)) then
			local hasAnimations
			if S.morphHasAnimations then hasAnimations = S.morphHasAnimations(name) else hasAnimations = findAnimationFolder(name) ~= nil end
			local hasAsset = findRenderNpcByName(name) ~= nil
			local isCustom = customMorphSources[name] ~= nil or (S.isCustomCatalog and S.isCustomCatalog(name))
			local displayText = name

			if isCustom and hasAnimations then
				displayText = name .. "   · custom + anim"
			elseif isCustom then
				displayText = name .. "   · custom"
			elseif hasAnimations and hasAsset then
				displayText = name .. "   · asset + anim"
			elseif hasAsset then
				displayText = name .. "   · asset"
			elseif hasAnimations then
				displayText = name .. "   · anim"
			end

			order += 1

			local button = makeButton(
				(isCustom and S.customMorphCards or morphScroll),
				displayText,
				UDim2.new(1, -4, 0, 34),
				UDim2.new(),
				COL.button
			)

			button.TextXAlignment = Enum.TextXAlignment.Left
			button.Text = "  " .. displayText
			button.TextSize = 11
			S.makeNpcCard(button, name, isCustom and "CUSTOM · MORPH" or (hasAnimations and "MORPH · ANIMATIONS" or "MORPH"), function()
				return findMorphSourceModel(name)
			end)
			button.LayoutOrder = order
			if S.addMorphFavorite then S.addMorphFavorite(button, name) end
			morphButtons[name] = button

			S.connectAction(button,function()
				selectMorph(name)
			end)
		end
	end

	if selectedMorphName then
		local stillExists = false

		for _, name in ipairs(morphNames) do
			if name == selectedMorphName then
				stillExists = true
				break
			end
		end

		if not stillExists then
			selectedMorphName = nil
		end
	end

	if not selectedMorphName and #morphNames > 0 then
		local preferred = nil

		for _, name in ipairs(morphNames) do
			if string.lower(name) == "smiley" then
				preferred = name
				break
			end
		end

		selectedMorphName = preferred or morphNames[1]
	end

	selectMorph(selectedMorphName)
	rebuildAnimationNpcList(true)
end

morphSearch:GetPropertyChangedSignal("Text"):Connect(function()
	S.morphSearchRevision = (S.morphSearchRevision or 0) + 1
	local revision = S.morphSearchRevision
	task.delay(0.18, function()
		if gui.Parent and revision == S.morphSearchRevision then rebuildMorphList(true) end
	end)
end)

S.connectAction(morphApplyButton,function()
	applyMorph(selectedMorphName)
end)

S.connectAction(morphRemoveButton,function()
	removeMorph(true)
end)

S.connectAction(resetOffsetButton,function()
	if not selectedMorphName then
		return
	end

	morphOffsets[selectedMorphName] = Vector3.new(0, 0, 0)

	morphOffsetX = 0
	morphOffsetY = 0
	morphOffsetZ = 0

	xSlider.SetValue(0, false)
	ySlider.SetValue(0, false)
	zSlider.SetValue(0, false)
end)

function getCustomModelStats(model)
	local stats = {
		baseParts = 0,
		meshParts = 0,
		motor6D = 0,
		bones = 0,
		animations = 0,
		animationNames = {},
		rootName = "not found",
	}

	local root =
		model:FindFirstChild("HumanoidRootPart", true)
		or model:FindFirstChild("RootPart", true)
		or model.PrimaryPart
		or model:FindFirstChildWhichIsA("BasePart", true)

	if root and root:IsA("BasePart") then
		stats.rootName = root.Name
	end

	for _, object in ipairs(model:GetDescendants()) do
		if object:IsA("BasePart") then
			stats.baseParts += 1
		end

		if object:IsA("MeshPart") then
			stats.meshParts += 1
		elseif object:IsA("Motor6D") then
			stats.motor6D += 1
		elseif object:IsA("Bone") then
			stats.bones += 1
		elseif object:IsA("Animation") then
			stats.animations += 1
			table.insert(stats.animationNames, object.Name)
		end
	end

	table.sort(stats.animationNames, function(a, b)
		return string.lower(a) < string.lower(b)
	end)

	return stats
end
function S.cancelUiBind()
	S.waitingForUiBind = false
	S.uiBindButton.Text = "UI key: " .. S.uiToggleKey.Name
end

S.connectAction(S.uiBindButton,function()
	S.waitingForPanelBind = false
	S.panelBindButton.Text = "Panel key: " .. S.panelToggleKey.Name
	sideHint.Text = S.panelToggleKey.Name .. " — panel"
	if waitingForAnimationBind then
		waitingForAnimationBind = nil
		rebuildAnimationRows()
	end
	if S.waitingForUiBind then
		S.cancelUiBind()
	else
		S.waitingForUiBind = true
		S.uiBindButton.Text = "Press a key · Esc cancels"
	end
end)

function S.toggleGameUi()
	if S.captureUi then
		S.restoreCaptureUi()
		if S.allUiHidden then ugUiRestoreAll() end
		return
	end
	if S.allUiHidden then
		ugUiRestoreAll()
	else
		ugUiHideAll()
	end
end

S.connectAction(S.panelBindButton,function()
	S.cancelUiBind()
	if waitingForAnimationBind then
		waitingForAnimationBind = nil
		rebuildAnimationRows()
	end
	S.waitingForPanelBind = not S.waitingForPanelBind
	S.panelBindButton.Text = S.waitingForPanelBind
		and "Press a key..."
		or ("Panel key: " .. S.panelToggleKey.Name)
	sideHint.Text = S.waitingForPanelBind
		and "Esc — cancel"
		or (S.panelToggleKey.Name .. " — panel")
end)

S.connectAction(closeButton,function()
	S.cancelUiBind()
	S.waitingForPanelBind = false
	S.panelBindButton.Text = "Panel key: " .. S.panelToggleKey.Name
	sideHint.Text = S.panelToggleKey.Name .. " — panel"
	main.Visible = false
end)

S.rootConnections[#S.rootConnections + 1] = UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if S.bindingCapture or S.uiPicking then return end
    if S.localLibraryDialog then return end
    if S.speedSwapInput and S.speedSwapInput(input,gameProcessed) then return end
    if S.killInput and S.killInput(input,gameProcessed) then return end
    if S.btoolsInput and S.btoolsInput(input,gameProcessed) then return end
    if S.shadowInput and S.shadowInput(input,gameProcessed) then return end
    if S.audioCaptureInput and S.audioCaptureInput(input) then return end
    if S.recorderInput and S.recorderInput(input,gameProcessed) then return end
	if S.waitingForUiBind then
		if input.UserInputType ~= Enum.UserInputType.Keyboard or input.KeyCode == Enum.KeyCode.Unknown then return end
		if input.KeyCode == Enum.KeyCode.Escape then S.cancelUiBind() return end
		if input.KeyCode == S.shadowKey or input.KeyCode == S.panelToggleKey or (S.recorder and table.find({S.recorder.keys.record,S.recorder.keys.play,S.recorder.keys.all},input.KeyCode)) then
			S.uiBindButton.Text = "Used by panel · choose another key"
			return
		end
		for _, binds in pairs(animationBinds) do
			for _, binding in pairs(binds) do
				if binding == input.KeyCode then
					S.uiBindButton.Text = "Used by animation · choose another"
					return
				end
			end
		end
		S.uiToggleKey = input.KeyCode
        if S.saveUserSettings then S.saveUserSettings() end
		S.cancelUiBind()
		return
	end

	if S.waitingForPanelBind then
		if input.UserInputType ~= Enum.UserInputType.Keyboard
			or input.KeyCode == Enum.KeyCode.Unknown
		then
			return
		end
		if input.KeyCode ~= Enum.KeyCode.Escape then
			if input.KeyCode == S.shadowKey or input.KeyCode == S.uiToggleKey or (S.recorder and table.find({S.recorder.keys.record,S.recorder.keys.play,S.recorder.keys.all},input.KeyCode)) then
				sideHint.Text = "Used by UI toggle"
				return
			end
			for _, binds in pairs(animationBinds) do
				for _, binding in pairs(binds) do
					if binding == input.KeyCode then
						sideHint.Text = "Used by animation"
						return
					end
				end
			end
			S.panelToggleKey = input.KeyCode
            if S.saveUserSettings then S.saveUserSettings() end
		end
		S.waitingForPanelBind = false
		S.panelBindButton.Text = "Panel key: " .. S.panelToggleKey.Name
		sideHint.Text = S.panelToggleKey.Name .. " — panel"
		return
	end

	if waitingForAnimationBind then
		local request =
			waitingForAnimationBind

		if input.UserInputType
			== Enum.UserInputType.Keyboard
		then
			if input.KeyCode
				== Enum.KeyCode.Escape
			then
				waitingForAnimationBind = nil
				rebuildAnimationRows()
				animationHintLabel.Text =
					"Bind assignment cancelled."
				return
			end

			if input.KeyCode
				== Enum.KeyCode.Backspace
				or input.KeyCode
				== Enum.KeyCode.Delete
			then
				setAnimationBind(
					request.npcName,
					request.animationName,
					nil
				)
				waitingForAnimationBind = nil
				rebuildAnimationRows()
				animationHintLabel.Text =
					"Bind cleared: "
					..
					request.animationName
				return
			end

			if input.KeyCode == S.shadowKey or input.KeyCode == S.panelToggleKey or input.KeyCode == S.uiToggleKey or (S.recorder and table.find({S.recorder.keys.record,S.recorder.keys.play,S.recorder.keys.all},input.KeyCode)) then
				animationHintLabel.Text =
					input.KeyCode.Name .. " is reserved for panel/UI. Choose another key."
				return
			end
		end

		local binding =
			inputToAnimationBinding(
				input
			)

		if binding then
			setAnimationBind(
				request.npcName,
				request.animationName,
				binding
			)

			waitingForAnimationBind = nil
			rebuildAnimationRows()

			animationHintLabel.Text =
				request.animationName
				..
				" → "
				..
				keyName(binding)

			return
		end
	end

	if gameProcessed or UserInputService:GetFocusedTextBox() then
		return
	end

	if input.KeyCode == S.uiToggleKey then
		S.toggleGameUi()
		return
	end

	if input.KeyCode == S.panelToggleKey then
		main.Visible = not main.Visible
		return
	end

	local binding =
		inputToAnimationBinding(
			input
		)

	if binding then
		triggerBoundAnimation(
			binding
		)
        if S.audioTrigger then task.spawn(S.audioTrigger,binding) end
	end
end)

RunService:BindToRenderStep(
	MOUSE_BIND_NAME,
	Enum.RenderPriority.Camera.Value + 300,
	function()
		if S.freecamLookHeld or S.spectateLookHeld or S.thirdLookHeld then
			UserInputService.MouseBehavior = Enum.MouseBehavior.LockCurrentPosition
		elseif main.Visible and Workspace.CurrentCamera and Workspace.CurrentCamera.CameraType ~= Enum.CameraType.Scriptable then
			UserInputService.MouseIconEnabled = true
			if not S.panelCameraLookHeld then
				UserInputService.MouseBehavior = Enum.MouseBehavior.Default
			end
		end
	end
)

local draggingWindow = false
local dragStart = nil
local windowStart = nil

titlebar.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		draggingWindow = true
		dragStart = input.Position
		windowStart = main.Position
	end
end)

S.rootConnections[#S.rootConnections + 1] = UserInputService.InputChanged:Connect(function(input)
	if draggingWindow and input.UserInputType == Enum.UserInputType.MouseMovement then
		local delta = input.Position - dragStart

		main.Position = UDim2.new(
			windowStart.X.Scale,
			windowStart.X.Offset + delta.X,
			windowStart.Y.Scale,
			windowStart.Y.Offset + delta.Y
		)
	end
end)

S.rootConnections[#S.rootConnections + 1] = UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		draggingWindow = false
	end
end)
function S.scanVisitorsMorphs(force)
    if not force and os.clock()-(S.lastMorphScan or 0)<4 then return end
    S.lastMorphScan = os.clock()
    S.morphDirty = false
    local folder = ReplicatedStorage:FindFirstChild("NPCs")
    local chosen = {}
    if folder then
        for _, model in ipairs(folder:GetDescendants()) do
            if model:IsA("Model") and (model:FindFirstChildOfClass("Humanoid") or model:FindFirstChildOfClass("AnimationController")) and model:FindFirstChildWhichIsA("BasePart",true) then
                local path = {}
                local cursor = model
                while cursor and cursor ~= folder do table.insert(path,1,cursor.Name); cursor=cursor.Parent end
                local name = table.concat(path,"/")
                local key, index = name, 2
                while chosen[key] do key=name .. " #" .. index; index+=1 end
                chosen[key] = {model=model,name=key,sourceKind="ReplicatedStorage",score=100,path=model:GetFullName()}
            end
        end
    end
    S.morphRegistry = chosen
end

function S.findVisitorsAnimations(npcName)
    local source = ReplicatedStorage:FindFirstChild("Animations")
    if not source then return nil end
    if not S.visitorAnimationBank then
        S.visitorAnimationBank = Instance.new("Folder")
        S.visitorAnimationBank.Name = "VisitorsAnimationBank"
    end
    if os.clock()-(S.visitorAnimationScan or -10)<4 then return S.visitorAnimationBank end
    S.visitorAnimationScan = os.clock()
    S.visitorAnimationBank:ClearAllChildren()
    local used = {}
    for _, object in ipairs(source:GetDescendants()) do
        if object:IsA("Animation") and object.AnimationId ~= "" then
            local path = {}
            local cursor = object
            while cursor and cursor ~= source do table.insert(path,1,cursor.Name);cursor=cursor.Parent end
            local name = table.concat(path,"/")
            local key, index = name, 2
            while used[string.lower(key)] do key=name .. " #" .. index;index+=1 end
            used[string.lower(key)] = true
            local copy = Instance.new("Animation")
            copy.Name = key
            copy.AnimationId = object.AnimationId
            copy.Parent = S.visitorAnimationBank
        end
    end
    return S.visitorAnimationBank
end

function ugNormalizeName(value)
	return
		string.lower(
			tostring(value or "")
		)
		:gsub("[^%w]", "")
end

function ugCanonicalName(value)
	local s =
		ugNormalizeName(value)

	local suffixes = {
		"renderasset",
		"character",
		"monster",
		"enemy",
		"model",
		"render",
		"npc",
		"rig",
	}

	local changed = true

	while changed do
		changed = false

		for _, suffix in ipairs(
			suffixes
		) do
			if #s > #suffix
				and string.sub(
					s,
					-#suffix
				) == suffix
			then
				s =
					string.sub(
						s,
						1,
						#s - #suffix
					)

				changed = true
				break
			end
		end
	end

	return s
end

function ugPathHasCharacterHint(object)
	local cursor = object

	while cursor do
		local lower =
			string.lower(
				tostring(cursor.Name)
			)

		if string.find(
			lower,
			"morph",
			1,
			true
		)
			or string.find(
				lower,
				"npc",
				1,
				true
			)
			or string.find(
				lower,
				"enemy",
				1,
				true
			)
			or string.find(
				lower,
				"monster",
				1,
				true
			)
			or string.find(
				lower,
				"character",
				1,
				true
			)
			or string.find(
				lower,
				"render",
				1,
				true
			)
		then
			return true
		end

		cursor = cursor.Parent

		if cursor == game then
			break
		end
	end

	return false
end

function ugIsPlayerCharacterModel(model)
	for _, p in ipairs(
		Players:GetPlayers()
	) do
		if p.Character
			and (
				model == p.Character
				or model:IsDescendantOf(
					p.Character
				)
			)
		then
			return true
		end
	end

	return false
end

function ugModelCandidateScore(
	model,
	sourceKind
)
	if S.btoolsFolder and model and model:IsDescendantOf(S.btoolsFolder) then return -1 end
	if not model
		or not model:IsA("Model")
	then
		return -1
	end

	do
		local cursor = model.Parent

		while cursor
			and cursor ~= game
		do
			if cursor.Name == "Target"
				and cursor.Parent
				and cursor.Parent:IsA("Model")
			then
				return -1
			end

			cursor = cursor.Parent
		end
	end

	if string.find(
		model.Name,
		"__LOCAL_MORPH_",
		1,
		true
	) == 1
	then
		return -1
	end

	if sourceKind == "Workspace"
		and ugIsPlayerCharacterModel(
			model
		)
	then
		return -1
	end

	local basePart =
		model:FindFirstChildWhichIsA(
			"BasePart",
			true
		)

	if not basePart then
		return -1
	end

	local score = 0

	if model:FindFirstChildOfClass(
		"Humanoid"
	) then
		score += 10
	end

	if model:FindFirstChildOfClass(
		"AnimationController"
	) then
		score += 7
	end

	if model:FindFirstChild(
		"HumanoidRootPart",
		true
	)
		or model:FindFirstChild(
			"RootPart",
			true
		)
	then
		score += 5
	end

	if model:FindFirstChildWhichIsA(
		"Motor6D",
		true
	) then
		score += 5
	end

	if model:FindFirstChildWhichIsA(
		"Bone",
		true
	) then
		score += 6
	end

	if model:FindFirstChildWhichIsA(
		"Animation",
		true
	) then
		score += 3
	end

	if ugPathHasCharacterHint(
		model
	) then
		score += 5
	end

	if sourceKind == "ReplicatedStorage" then
		score += 2
	end

	return score
end

function ugBuildAnimationIndex()
	S.animationContainers = {}

	local bestScore = {}

	local function registerAnimation(
		animationObject,
		root
	)
		local cursor =
			animationObject.Parent

		local depth = 0

		while cursor
			and cursor ~= root
			and cursor ~= game
		do
			if cursor:IsA("Folder")
				or cursor:IsA("Model")
				or cursor:IsA("Configuration")
				or cursor:IsA("StringValue")
			then
				local raw =
					ugNormalizeName(
						cursor.Name
					)

				local canonical =
					ugCanonicalName(
						cursor.Name
					)

				local pathLower =
					string.lower(
						cursor:GetFullName()
					)

				local score =
					100
					-
					math.min(
						depth,
						50
					)

				if string.find(
					pathLower,
					"anim",
					1,
					true
				) then
					score += 30
				end

				for _, key in ipairs({
					raw,
					canonical,
				}) do
					if key ~= ""
						and (
							not bestScore[key]
							or score
								>
								bestScore[key]
						)
					then
						bestScore[key] =
							score

						S.animationContainers[
							key
						] = cursor
					end
				end
			end

			depth += 1
			cursor = cursor.Parent
		end
	end

	for _, root in ipairs({
		ReplicatedStorage,
		Workspace,
	}) do
		for _, object in ipairs(
			root:GetDescendants()
		) do
			if object:IsA("Animation") then
				registerAnimation(
					object,
					root
				)
			end
		end
	end
end

function ugScanMorphs(force)
    if S.economyMode and not force then return end
    if game.PlaceId == 104522435597696 then return S.scanVisitorsMorphs(force) end
	if not force
		and not S.morphDirty
		and os.clock()
			-
			(S.lastMorphScan or 0)
			<
			8
	then
		return
	end

	S.lastMorphScan = os.clock()
	S.morphDirty = false

	ugBuildAnimationIndex()

	local chosen = {}

	local function consider(
		model,
		sourceKind
	)
		local score =
			ugModelCandidateScore(
				model,
				sourceKind
			)

		local threshold =
			sourceKind == "Workspace"
			and 8
			or 7

		if score < threshold then
			return
		end

		local name =
			model.Name

		local old =
			chosen[name]

		if not old
			or score > old.score
			or (
				score == old.score
				and sourceKind
					== "ReplicatedStorage"
			)
		then
			chosen[name] = {
				model = model,
				name = name,
				sourceKind = sourceKind,
				score = score,
				path = model:GetFullName(),
			}
		end
	end

	for _, model in ipairs(
		ReplicatedStorage:GetDescendants()
	) do
		if model:IsA("Model") then
			consider(
				model,
				"ReplicatedStorage"
			)
		end
	end

	for _, model in ipairs(
		Workspace:GetDescendants()
	) do
		if model:IsA("Model") then
			consider(
				model,
				"Workspace"
			)
		end
	end

	for name, entry in pairs(chosen) do
		local source = entry.model

		if source
			and source.Parent
			and source:FindFirstChildWhichIsA(
				"Animation",
				true
			)
		then
			entry.animationContainer =
				source
		else
			entry.animationContainer =
				S.animationContainers[
					ugNormalizeName(name)
				]
				or
				S.animationContainers[
					ugCanonicalName(name)
				]
		end
	end

	S.morphRegistry = chosen
end

function findAnimationFolder(npcName)
	local customSource =
		customMorphSources[npcName]

	if customSource
		and customSource:FindFirstChildWhichIsA(
			"Animation",
			true
		)
	then
		return customSource
	end

    if game.PlaceId == 104522435597696 then return S.findVisitorsAnimations(npcName) end

	ugScanMorphs(false)

	local entry =
		S.morphRegistry[npcName]

	if entry
		and entry.animationContainer
		and entry.animationContainer.Parent
	then
		return
			entry.animationContainer
	end

	local raw =
		ugNormalizeName(npcName)

	local canonical =
		ugCanonicalName(npcName)

	return
		S.animationContainers[raw]
		or S.animationContainers[
			canonical
		]
end

function findRenderNpcByName(npcName)
	ugScanMorphs(false)

	local entry =
		S.morphRegistry[npcName]

	if entry
		and entry.sourceKind
			== "ReplicatedStorage"
	then
		return entry.model
	end

	return nil
end

function findLiveNpcByName(npcName)
	ugScanMorphs(false)

	local entry =
		S.morphRegistry[npcName]

	if entry
		and entry.sourceKind
			== "Workspace"
	then
		return entry.model
	end

	return nil
end

function findMorphSourceModel(npcName)
	if customMorphSources[npcName] then
		return
			customMorphSources[npcName]
	end

	ugScanMorphs(false)

	local entry =
		S.morphRegistry[npcName]

	return
		entry
		and entry.model
		or nil
end

function S.registryMorphNames()
	ugScanMorphs(false)

	local names = {}
	local used = {}

	for name, entry in pairs(
		S.morphRegistry
	) do
		if entry.model
			and entry.model.Parent
			and not used[name]
		then
			used[name] = true
			table.insert(
				names,
				name
			)
		end
	end

	for catalogName in pairs(
		customMorphSources
	) do
		if not used[catalogName] then
			used[catalogName] = true
			table.insert(
				names,
				catalogName
			)
		end
	end

	table.sort(
		names,
		function(a, b)
			return
				string.lower(a)
				<
				string.lower(b)
		end
	)

	return names
end
collectMorphNames = S.registryMorphNames

function ugCameraCandidate(model)
	if S.btoolsFolder and model and model:IsDescendantOf(S.btoolsFolder) then return nil end
	if not model
		or not model:IsA("Model")
		or ugIsPlayerCharacterModel(
			model
		)
	then
		return nil
	end

	if string.find(
		model.Name,
		"__LOCAL_MORPH_",
		1,
		true
	) == 1
	then
		return nil
	end

	local humanoid =
		model:FindFirstChildOfClass(
			"Humanoid"
		)

	local root =
		model:FindFirstChild(
			"HumanoidRootPart",
			true
		)
		or model:FindFirstChild(
			"RootPart",
			true
		)
		or model.PrimaryPart

	local controller =
		model:FindFirstChildOfClass(
			"AnimationController"
		)

	if not root
		or not root:IsA("BasePart")
	then
		root =
			model:FindFirstChildWhichIsA(
				"BasePart",
				true
			)
	end

	if not root then
		return nil
	end

	local score = 0

	if humanoid then
		score += 10
	end

	if controller then
		score += 6
	end

	if model:FindFirstChild(
		"HumanoidRootPart",
		true
	)
		or model:FindFirstChild(
			"RootPart",
			true
		)
	then
		score += 5
	end

	if model:FindFirstChildWhichIsA(
		"Motor6D",
		true
	) then
		score += 4
	end

	if model:FindFirstChildWhichIsA(
		"Bone",
		true
	) then
		score += 4
	end

	if ugPathHasCharacterHint(
		model
	) then
		score += 2
	end

	if score < 7 then
		return nil
	end

	return {
		model = model,
		root = root,
		subject =
			humanoid
			or root,
		score = score,
	}
end

function ugScanCameraNpcs(force)
    if S.economyMode and not force then return end
	if not force
		and not S.cameraDirty
		and os.clock()
			-
			(S.lastCameraScan or 0)
			<
			4
	then
		return
	end

	S.lastCameraScan = os.clock()
	S.cameraDirty = false

	local raw = {}

	for _, model in ipairs(
		Workspace:GetDescendants()
	) do
		if model:IsA("Model") then
			local item =
				ugCameraCandidate(
					model
				)

			if item then
				table.insert(
					raw,
					item
				)
			end
		end
	end

	local filtered = {}
    local scores={}
    for _,item in ipairs(raw) do scores[item.model]=item.score end

	for _, item in ipairs(raw) do
		local nested = false
		local ancestor =
			item.model.Parent

		while ancestor
			and ancestor ~= Workspace
		do
			if ancestor:IsA("Model") then
                if scores[ancestor] and scores[ancestor]>=item.score then nested=true end
			end

			if nested then
				break
			end

			ancestor = ancestor.Parent
		end

		if not nested then
			table.insert(
				filtered,
				item
			)
		end
	end

	local counts = {}

	for _, item in ipairs(filtered) do
		counts[item.model.Name] =
			(counts[item.model.Name] or 0)
			+
			1
	end

	for _, item in ipairs(filtered) do
		if counts[item.model.Name] > 1 then
			item.displayName =
				item.model.Name
				..
				" · "
				..
				tostring(
					item.model.Parent
					and item.model.Parent.Name
					or "Workspace"
				)
		else
			item.displayName =
				item.model.Name
		end

		item.key =
			item.model:GetFullName()
	end

	table.sort(
		filtered,
		function(a, b)
			return
				string.lower(
					a.displayName
				)
				<
				string.lower(
					b.displayName
				)
		end
	)

	S.cameraNpcEntries =
		filtered

	if S.spectateActive
		and (
			not S.spectateTarget
			or not S.spectateTarget.Parent
		)
	then
		ugStopSpectate()
	end

	ugRebuildCameraNpcList(true)
end

function ugRefreshCameraNpcButtons()
	for key, button in pairs(
		S.cameraNpcButtons
	) do
		local selected =
			key
			==
			S.selectedCameraNpcKey

		button:SetAttribute(
			"Selected",
			selected
		)

		button.BackgroundColor3 =
			selected
			and COL.buttonSelected
			or COL.button

		button.TextColor3 =
			selected
			and COL.text
			or COL.subtext
	end
end

function ugRebuildCameraNpcList(force)
	if not S.cameraNpcScroll then return end
	S.cameraCardRecords = S.cameraCardRecords or {}
	local filter = string.lower(S.cameraNpcSearch.Text or "")
	local present = {}
	local order = 0
	local buttons = {}

	for _, item in ipairs(S.cameraNpcEntries) do
		local model = item.model
		present[model] = true
		local record = S.cameraCardRecords[model]
		local visible = (not S.economyMode or order<80) and (filter == "" or string.find(string.lower(item.displayName), filter, 1, true) ~= nil)
        if S.economyMode and record and not visible then record.button:Destroy();S.cameraCardRecords[model]=nil;record=nil end
		if not record and visible then
			local button = makeButton(S.cameraNpcScroll, "", UDim2.new(1, -4, 0, 104), UDim2.new(), COL.button)
			record = {button = button, entry = item}
			S.cameraCardRecords[model] = record
			S.makeNpcCard(button, item.displayName, "SPECTATE · NPC", model)
			S.connectAction(button,function()
				ugSpectateEntry(record.entry)
			end)
		end
		if record then
			record.entry = item
			record.button.Visible = visible
			local card = S.npcCards[record.button]
			if card then card.title.Text = item.displayName end
			if visible then
				order += 1
				record.button.LayoutOrder = order
			end
			buttons[item.key] = record.button
		end
	end

	for model, record in pairs(S.cameraCardRecords) do
		if not present[model] then
			record.button:Destroy()
			S.cameraCardRecords[model] = nil
		end
	end
	S.cameraNpcButtons = buttons
	if not S.cameraEmptyLabel then
		S.cameraEmptyLabel = makeLabel(S.cameraNpcScroll, "No NPCs found", UDim2.new(1, -4, 0, 34), UDim2.new(), 10, COL.dim, Enum.Font.Gotham)
		S.cameraEmptyLabel.LayoutOrder = 1
	end
	S.cameraEmptyLabel.Visible = order == 0
	ugRefreshCameraNpcButtons()
end

S.rootConnections[#S.rootConnections + 1] = ReplicatedStorage.DescendantAdded:Connect(function(object)
	if object:IsA("Model")
		or object:IsA("Animation")
	then
		S.morphDirty = true
	end
end)

S.rootConnections[#S.rootConnections + 1] = ReplicatedStorage.DescendantRemoving:Connect(function(object)
	if object:IsA("Model")
		or object:IsA("Animation")
	then
		S.morphDirty = true
	end
end)

S.rootConnections[#S.rootConnections + 1] = Workspace.DescendantAdded:Connect(function(object)
	if object:IsA("Model")
		or object:IsA("Animation")
	then
		S.morphDirty = true
		S.cameraDirty = true
	end
end)

S.rootConnections[#S.rootConnections + 1] = Workspace.DescendantRemoving:Connect(function(object)
	if object:IsA("Model")
		or object:IsA("Animation")
	then
		S.morphDirty = true
		S.cameraDirty = true
	end
end)

if not S.economyMode then ugScanMorphs(true) end
if not S.economyMode then ugScanCameraNpcs(true) end

task.spawn(function()
	while gui.Parent do

		if morphModel and morphModel.Parent then
			hideRealCharacter()
		end

		task.wait(0.75)
	end
end)

S.rootConnections[#S.rootConnections + 1] = player.CharacterAdded:Connect(function()
	task.wait(0.5)

	if thirdPerson then
		applyThirdPerson()
	end

end)

updateCameraUI()
cameraMaxSlider.SetValue(cameraMaxZoom, false)

if not S.economyMode then ugScanMorphs(true) end
rebuildMorphList(true)
rebuildAnimationNpcList(true)

selectTab("Morph")

if thirdPerson then
	applyThirdPerson()
end

title.Text = "Tyomich Admin · 14.7.9.1"
subtitle.Position = UDim2.new(0, 290, 0, 1)
subtitle.Size = UDim2.new(0, 210, 1, 0)
subtitle.Text = "no skin module"
gui:SetAttribute("LuminBuild", "14.7.16.12-SoulPrompts")
AssetService = game:GetService("AssetService")

universalLibraryMorphs = {}
universalLibraryAssetId = nil
universalLibraryBytes = 0

v11MorphRotations = {}
v11MorphScales = {}

v11UniversalAnimationConnection = nil
v11UniversalActiveData = nil
v11UniversalPrepared = nil
v11UniversalClipOrder = nil
v11UniversalBoneTargets = {}
v11UniversalMotorByPartName = {}
v11UniversalMotorByName = {}
v11UniversalCurrentClip = nil
v11UniversalCurrentName = nil
v11UniversalStartedAt = 0
v11UniversalLastFrameIndex = 1
v11UniversalBlendFrom = {}
v11UniversalBlendStartedAt = 0
v11UniversalManualMode = false
v11UniversalRunState = false

v144LibraryHumanoid = nil
v144LibraryAnimator = nil
v144RuntimeTracks = {}
v144RuntimeCurrentTrack = nil
v144RuntimeCurrentName = nil
v144RuntimeUsingAnimator = false

v12R15ExtraParts = {}
v12R15ExtraFollowers = {}

V11_HIDE_BIND = "LuminAdminCharacterHideV11"

function v11GetRotation(name)
	if not name then
		return Vector3.new(0, MORPH_YAW_DEGREES or 0, 0)
	end

	return
		v11MorphRotations[name]
		or
		Vector3.new(
			0,
			MORPH_YAW_DEGREES or 0,
			0
		)
end

function v11SetRotation(name, value)
	if name then
		v11MorphRotations[name] = value
	end
end

function v11GetScale(name)
	if not name then
		return 1
	end

	return v11MorphScales[name] or 1
end

function v11SetScale(name, value)
	if not name then
		return
	end

	v11MorphScales[name] =
		math.clamp(
			tonumber(value) or 1,
			0.1,
			3
		)
end

function v11ApplyScaleNow(name)
	if not name
		or morphActiveName ~= name
		or not morphModel
		or not morphModel.Parent
	then
		return
	end

	pcall(function()
		morphModel:ScaleTo(
			v11GetScale(name) * (S.nativeScaleModel == morphModel and S.nativeBaseScale or 1)
		)
	end)

	if v11UniversalActiveData
		and v11UniversalActiveData.rigType == "r15"
		and #v12R15ExtraParts > 0
	then
		v12RefreshR15ExtraFollowers()
	end

	if #S.activeVisualParts > 0 then
		ugRefreshVisualFollowers()
	end
end

offsetTitle.Visible = false

if xSlider.Holder then
	xSlider.Holder.Visible = false
end

if ySlider.Holder then
	ySlider.Holder.Visible = false
end

if zSlider.Holder then
	zSlider.Holder.Visible = false
end

resetOffsetButton.Visible = false

v11TransformScroll = Instance.new("ScrollingFrame")
v11TransformScroll.Name = "TransformSliders"
v11TransformScroll.Size = UDim2.new(1, -24, 1, -196)
v11TransformScroll.Position = UDim2.new(0, 12, 0, 146)
v11TransformScroll.BackgroundTransparency = 1
v11TransformScroll.BorderSizePixel = 0
v11TransformScroll.ScrollBarThickness = 4
v11TransformScroll.ScrollBarImageColor3 = COL.dim
v11TransformScroll.CanvasSize = UDim2.new(0, 0, 0, 520)
v11TransformScroll.Parent = morphDetails

v11PositionTitle = makeLabel(
	v11TransformScroll,
	"POSITION",
	UDim2.new(1, -4, 0, 18),
	UDim2.new(0, 2, 0, 0),
	10,
	COL.dim,
	Enum.Font.GothamBold
)

v11PosX = createSlider(
	v11TransformScroll,
	"Position X",
	-15,
	15,
	0.1,
	0,
	18,
	function(value)
		if selectedMorphName then
			local old = getOffsetForName(selectedMorphName)
			morphOffsets[selectedMorphName] =
				Vector3.new(value, old.Y, old.Z)
		end
	end
)

v11PosY = createSlider(
	v11TransformScroll,
	"Position Y  (height)",
	-15,
	15,
	0.1,
	0,
	72,
	function(value)
		if selectedMorphName then
			local old = getOffsetForName(selectedMorphName)
			morphOffsets[selectedMorphName] =
				Vector3.new(old.X, value, old.Z)
		end
	end
)

v11PosZ = createSlider(
	v11TransformScroll,
	"Position Z",
	-15,
	15,
	0.1,
	0,
	126,
	function(value)
		if selectedMorphName then
			local old = getOffsetForName(selectedMorphName)
			morphOffsets[selectedMorphName] =
				Vector3.new(old.X, old.Y, value)
		end
	end
)

v11RotationTitle = makeLabel(
	v11TransformScroll,
	"ROTATION",
	UDim2.new(1, -4, 0, 18),
	UDim2.new(0, 2, 0, 184),
	10,
	COL.dim,
	Enum.Font.GothamBold
)

v11RotX = createSlider(
	v11TransformScroll,
	"Rotation X",
	-180,
	180,
	1,
	0,
	202,
	function(value)
		if selectedMorphName then
			local old = v11GetRotation(selectedMorphName)
			v11SetRotation(
				selectedMorphName,
				Vector3.new(value, old.Y, old.Z)
			)
		end
	end
)

v11RotY = createSlider(
	v11TransformScroll,
	"Rotation Y",
	-180,
	180,
	1,
	MORPH_YAW_DEGREES or 0,
	256,
	function(value)
		if selectedMorphName then
			local old = v11GetRotation(selectedMorphName)
			v11SetRotation(
				selectedMorphName,
				Vector3.new(old.X, value, old.Z)
			)
		end
	end
)

v11RotZ = createSlider(
	v11TransformScroll,
	"Rotation Z",
	-180,
	180,
	1,
	0,
	310,
	function(value)
		if selectedMorphName then
			local old = v11GetRotation(selectedMorphName)
			v11SetRotation(
				selectedMorphName,
				Vector3.new(old.X, old.Y, value)
			)
		end
	end
)

v11ScaleTitle = makeLabel(
	v11TransformScroll,
	"SCALE",
	UDim2.new(1, -4, 0, 18),
	UDim2.new(0, 2, 0, 368),
	10,
	COL.dim,
	Enum.Font.GothamBold
)

v11Scale = createSlider(
	v11TransformScroll,
	"Scale  (uniform)",
	0.1,
	3,
	0.05,
	1,
	386,
	function(value)
		if selectedMorphName then
			v11SetScale(
				selectedMorphName,
				value
			)

			v11ApplyScaleNow(
				selectedMorphName
			)
		end
	end
)

v11ResetTransform = makeButton(
	v11TransformScroll,
	"RESET POSITION / ROTATION / SCALE",
	UDim2.new(1, -4, 0, 34),
	UDim2.new(0, 2, 0, 450),
	COL.button
)

v11TransformNote = makeLabel(
	v11TransformScroll,
	"Uniform scale keeps skinned meshes and bones aligned.",
	UDim2.new(1, -4, 0, 30),
	UDim2.new(0, 2, 0, 490),
	9,
	COL.dim,
	Enum.Font.Gotham
)
v11TransformNote.TextWrapped = true

function v11RefreshTransformSliders()
	local name = selectedMorphName

	if not name then
		return
	end

	local position = getOffsetForName(name)
	local rotation = v11GetRotation(name)
	local scale = v11GetScale(name)

	v11PosX.SetValue(position.X, false)
	v11PosY.SetValue(position.Y, false)
	v11PosZ.SetValue(position.Z, false)

	v11RotX.SetValue(rotation.X, false)
	v11RotY.SetValue(rotation.Y, false)
	v11RotZ.SetValue(rotation.Z, false)

	v11Scale.SetValue(scale, false)
end

S.connectAction(v11ResetTransform,function()
	if not selectedMorphName then
		return
	end

	morphOffsets[selectedMorphName] =
		Vector3.new(0, 0, 0)

	v11SetRotation(
		selectedMorphName,
		Vector3.new(
			0,
			MORPH_YAW_DEGREES or 0,
			0
		)
	)

	v11SetScale(
		selectedMorphName,
		1
	)

	v11ApplyScaleNow(
		selectedMorphName
	)

	v11RefreshTransformSliders()
end)
function v11V3(t)
	return Vector3.new(t[1], t[2], t[3])
end

function v11C3(t)
	return Color3.new(t[1], t[2], t[3])
end

function v11CF12(t)
	return CFrame.new(table.unpack(t))
end

function v11Enum(enumTable, name, fallback)
	local ok, value = pcall(function()
		return enumTable[name]
	end)

	return ok and value or fallback
end

function v11CompactCF(data)
	local position =
		Vector3.new(
			data[1] or 0,
			data[2] or 0,
			data[3] or 0
		)

	local axis =
		Vector3.new(
			data[4] or 1,
			data[5] or 0,
			data[6] or 0
		)

	if axis.Magnitude < 0.000001 then
		axis = Vector3.new(1, 0, 0)
	else
		axis = axis.Unit
	end

	return
		CFrame.new(position)
		*
		CFrame.fromAxisAngle(
			axis,
			data[7] or 0
		)
end

function v11ApplyPartProps(part, node)
	part.Name = node.name
	part.Size = v11V3(node.size)
	part.Color = v11C3(node.color)

	part.Material =
		v11Enum(
			Enum.Material,
			node.material,
			Enum.Material.Plastic
		)

	part.Transparency =
		node.transparency or 0

	part.Reflectance =
		node.reflectance or 0

	part.CastShadow =
		node.castShadow ~= false

	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Massless = true
	part.Anchored = true
	part.CFrame = v11CF12(node.relativeCFrame)

	if node.materialVariant
		and node.materialVariant ~= ""
	then
		pcall(function()
			part.MaterialVariant =
				node.materialVariant
		end)
	end
end

function v11RebuildBones(meshPart, node, targetTable)
	local ok, editable = pcall(function()
		return AssetService:CreateEditableMeshAsync(
			Content.fromUri(node.meshId),
			{FixedSize = true}
		)
	end)

	if not ok or not editable then
		warn("[LIB] EditableMesh failed:", node.name, editable)
		return
	end

	local boneIds = editable:GetBones()

	if #boneIds == 0 then
		return
	end

	local renderScale =
		meshPart.Size
		/
		meshPart.MeshSize

	local function scaledBind(cf)
		local p = cf.Position

		return
			CFrame.new(
				p.X * renderScale.X,
				p.Y * renderScale.Y,
				p.Z * renderScale.Z
			)
			*
			(cf - p)
	end

	local absolute = {}
	local byId = {}

	for _, boneId in ipairs(boneIds) do
		absolute[boneId] =
			scaledBind(
				editable:GetBoneCFrame(
					boneId
				)
			)

		local bone = Instance.new("Bone")
		bone.Name =
			editable:GetBoneName(
				boneId
			)

		bone.Transform = CFrame.identity

		byId[boneId] = bone
		targetTable[bone.Name] = bone
	end

	for _, boneId in ipairs(boneIds) do
		local bone = byId[boneId]
		local parentId =
			editable:GetBoneParent(
				boneId
			)

		local parentBone =
			parentId
			and byId[parentId]
			or nil

		if parentBone then
			bone.CFrame =
				absolute[parentId]
				:ToObjectSpace(
					absolute[boneId]
				)

			bone.Parent = parentBone
		else
			bone.CFrame =
				absolute[boneId]

			bone.Parent = meshPart
		end
	end
end

function v11CreatePart(node)
	local part

	if node.class == "MeshPart"
		and node.meshId
		and node.meshId ~= ""
	then
		local ok, result = pcall(function()
			return AssetService:CreateMeshPartAsync(
				Content.fromUri(node.meshId),
				{
					CollisionFidelity =
						Enum.CollisionFidelity.Hull,

					RenderFidelity =
						Enum.RenderFidelity.Precise,
				}
			)
		end)

		if ok and result then
			part = result
		end
	end

	if not part then
		if node.class == "WedgePart"
			or node.class == "CornerWedgePart"
			or node.class == "TrussPart"
		then
			local ok, result = pcall(function()
				return Instance.new(node.class)
			end)

			part =
				ok
				and result
				or Instance.new("Part")
		else
			part = Instance.new("Part")
		end
	end

	v11ApplyPartProps(part, node)

	if part:IsA("Part")
		and node.shape
	then
		part.Shape =
			v11Enum(
				Enum.PartType,
				node.shape,
				Enum.PartType.Block
			)
	end

	if node.class == "MeshPart" then
		if part:IsA("MeshPart") then
			if node.textureId
				and node.textureId ~= ""
			then
				pcall(function()
					part.TextureID =
						node.textureId
				end)
			end
		else
			local mesh =
				Instance.new(
					"SpecialMesh"
				)

			mesh.MeshType =
				Enum.MeshType.FileMesh

			mesh.MeshId =
				node.meshId or ""

			mesh.TextureId =
				node.textureId or ""

			mesh.Parent = part
		end
	end

	return part
end

function S.createLibraryEffect(node)
	local propertyTypes = {
		ParticleEmitter = {
			Enabled = "plain",
			Texture = "plain",
			Rate = "plain",
			Brightness = "plain",
			Drag = "plain",
			LightEmission = "plain",
			LightInfluence = "plain",
			LockedToPart = "plain",
			TimeScale = "plain",
			VelocityInheritance = "plain",
			WindAffectsDrag = "plain",
			ZOffset = "plain",
			ShapePartial = "plain",
			FlipbookBlendFrames = "plain",
			FlipbookStartRandom = "plain",
			FlipbookSizeX = "plain",
			FlipbookSizeY = "plain",
			Lifetime = "NumberRange",
			Speed = "NumberRange",
			Rotation = "NumberRange",
			RotSpeed = "NumberRange",
			FlipbookFramerate = "NumberRange",
			Size = "NumberSequence",
			Transparency = "NumberSequence",
			Squash = "NumberSequence",
			Color = "ColorSequence",
			Acceleration = "Vector3",
			SpreadAngle = "Vector2",
			EmissionDirection = "NormalId",
			Orientation = "ParticleOrientation",
			Shape = "ParticleEmitterShape",
			ShapeInOut = "ParticleEmitterShapeInOut",
			ShapeStyle = "ParticleEmitterShapeStyle",
			FlipbookLayout = "ParticleFlipbookLayout",
			FlipbookMode = "ParticleFlipbookMode",
		},
		PointLight = {
			Enabled = "plain",
			Brightness = "plain",
			Range = "plain",
			Shadows = "plain",
			Color = "Color3",
		},
	}
	local object = Instance.new(node.class)
	object.Name = node.name
	object.Enabled = false
	for property, kind in pairs(propertyTypes[node.class]) do
		local value = (node.effectProperties or {})[property]
		if value ~= nil and property ~= "Enabled" then
			local ok, err = pcall(function()
				if kind == "NumberRange" then
					value = NumberRange.new(value[1], value[2])
				elseif kind == "Vector3" then
					value = v11V3(value)
				elseif kind == "Vector2" then
					value = Vector2.new(value[1], value[2])
				elseif kind == "Color3" then
					value = v11C3(value)
				elseif kind == "NumberSequence" or kind == "ColorSequence" then
					local points = {}
					for _, point in ipairs(value) do
						if kind == "NumberSequence" then
							table.insert(points, NumberSequenceKeypoint.new(point[1], point[2], point[3] or 0))
						else
							table.insert(points, ColorSequenceKeypoint.new(point[1], Color3.new(point[2], point[3], point[4])))
						end
					end
					value = kind == "NumberSequence" and NumberSequence.new(points) or ColorSequence.new(points)
				elseif kind ~= "plain" then
					value = Enum[kind][value]
				end
				object[property] = value
			end)
			if not ok then warn("[LIB EFFECT] " .. tostring(node.name) .. "." .. property .. ": " .. tostring(err)) end
		end
	end
	object.Enabled = (node.effectProperties or {}).Enabled == true
	return object
end

function v11CreateNode(node, model)
	if node.class == "Model" then
		if node.parent == nil then
			return model
		end

		local object = Instance.new("Model")
		object.Name = node.name
		return object

	elseif node.class == "Folder" then
		local object = Instance.new("Folder")
		object.Name = node.name
		return object

	elseif node.class == "Accessory" then
		local object = Instance.new("Accessory")
		object.Name = node.name
		return object

	elseif node.class == "Part"
		or node.class == "WedgePart"
		or node.class == "CornerWedgePart"
		or node.class == "TrussPart"
		or node.class == "MeshPart"
		or node.class == "UnionOperation"
	then
		return v11CreatePart(node)

	elseif node.class == "Bone" then
		local object = Instance.new("Bone")
		object.Name = node.name
		object.CFrame = v11CF12(node.cframe)

		if node.transform then
			object.Transform =
				v11CF12(node.transform)
		else
			object.Transform =
				CFrame.identity
		end

		return object

	elseif node.class == "Attachment" then
		local object = Instance.new("Attachment")
		object.Name = node.name
		object.CFrame = v11CF12(node.cframe)
		return object

	elseif node.class == "SpecialMesh" then
		local object = Instance.new("SpecialMesh")
		object.Name = node.name

		object.MeshType =
			v11Enum(
				Enum.MeshType,
				node.meshType,
				Enum.MeshType.FileMesh
			)

		object.MeshId = node.meshId or ""
		object.TextureId = node.textureId or ""
		object.Scale = v11V3(node.scale)
		object.Offset = v11V3(node.offset)
		object.VertexColor = v11V3(node.vertexColor)

		return object

	elseif node.class == "BlockMesh"
		or node.class == "CylinderMesh"
	then
		local object = Instance.new(node.class)
		object.Name = node.name
		object.Scale = v11V3(node.scale)
		object.Offset = v11V3(node.offset)
		return object

	elseif node.class == "Decal"
		or node.class == "Texture"
	then
		local object = Instance.new(node.class)
		object.Name = node.name
		object.Texture = node.texture or ""
		object.Transparency = node.transparency or 0
		object.Color3 = v11C3(node.color)

		object.Face =
			v11Enum(
				Enum.NormalId,
				node.face,
				Enum.NormalId.Front
			)

		if node.class == "Texture" then
			object.StudsPerTileU =
				node.studsPerTileU or 2

			object.StudsPerTileV =
				node.studsPerTileV or 2

			object.OffsetStudsU =
				node.offsetStudsU or 0

			object.OffsetStudsV =
				node.offsetStudsV or 0
		end

		return object

    elseif node.class == "Sound" then
        local object = Instance.new("Sound")
        object.Name = node.name
        for _, property in ipairs({"SoundId", "Volume", "PlaybackSpeed", "Looped", "RollOffMinDistance", "RollOffMaxDistance", "EmitterSize"}) do
            local value = (node.sound or {})[property]
            if value ~= nil then pcall(function() object[property] = value end) end
        end
        pcall(function() object.RollOffMode = Enum.RollOffMode[(node.sound or {}).RollOffMode] end)
        return object
    elseif node.class == "Shirt" or node.class == "Pants" or node.class == "ShirtGraphic" then
        local object = Instance.new(node.class)
        object.Name = node.name
        object[node.class == "Shirt" and "ShirtTemplate" or node.class == "Pants" and "PantsTemplate" or "Graphic"] = node.template or ""
        return object

	elseif node.class == "ParticleEmitter" or node.class == "PointLight" then
		return S.createLibraryEffect(node)

	elseif node.class == "SurfaceAppearance" then
		local object =
			Instance.new(
				"SurfaceAppearance"
			)

		object.Name = node.name

		pcall(function()
			object.ColorMap =
				node.colorMap or ""

			object.NormalMap =
				node.normalMap or ""

			object.MetalnessMap =
				node.metalnessMap or ""

			object.RoughnessMap =
				node.roughnessMap or ""
		end)

		if node.surfaceColor then
			pcall(function() object.Color = v11C3(node.surfaceColor) end)
		end
		if node.alphaMode then
			pcall(function()
				local mode = tostring(node.alphaMode):match("([^%.]+)$")
				object.AlphaMode = v11Enum(Enum.AlphaMode, mode, Enum.AlphaMode.Overlay)
			end)
		end

		return object
	end

	return nil
end

function v12BuildR15Motors(
	model,
	motorByPart,
	motorByName
)
	local joints = {
		{
			name = "Root",
			part0 = "HumanoidRootPart",
			part1 = "LowerTorso",
			attachment = "RootRigAttachment",
		},
		{
			name = "Waist",
			part0 = "LowerTorso",
			part1 = "UpperTorso",
			attachment = "WaistRigAttachment",
		},
		{
			name = "Neck",
			part0 = "UpperTorso",
			part1 = "Head",
			attachment = "NeckRigAttachment",
		},

		{
			name = "LeftShoulder",
			part0 = "UpperTorso",
			part1 = "LeftUpperArm",
			attachment = "LeftShoulderRigAttachment",
		},
		{
			name = "LeftElbow",
			part0 = "LeftUpperArm",
			part1 = "LeftLowerArm",
			attachment = "LeftElbowRigAttachment",
		},
		{
			name = "LeftWrist",
			part0 = "LeftLowerArm",
			part1 = "LeftHand",
			attachment = "LeftWristRigAttachment",
		},

		{
			name = "RightShoulder",
			part0 = "UpperTorso",
			part1 = "RightUpperArm",
			attachment = "RightShoulderRigAttachment",
		},
		{
			name = "RightElbow",
			part0 = "RightUpperArm",
			part1 = "RightLowerArm",
			attachment = "RightElbowRigAttachment",
		},
		{
			name = "RightWrist",
			part0 = "RightLowerArm",
			part1 = "RightHand",
			attachment = "RightWristRigAttachment",
		},

		{
			name = "LeftHip",
			part0 = "LowerTorso",
			part1 = "LeftUpperLeg",
			attachment = "LeftHipRigAttachment",
		},
		{
			name = "LeftKnee",
			part0 = "LeftUpperLeg",
			part1 = "LeftLowerLeg",
			attachment = "LeftKneeRigAttachment",
		},
		{
			name = "LeftAnkle",
			part0 = "LeftLowerLeg",
			part1 = "LeftFoot",
			attachment = "LeftAnkleRigAttachment",
		},

		{
			name = "RightHip",
			part0 = "LowerTorso",
			part1 = "RightUpperLeg",
			attachment = "RightHipRigAttachment",
		},
		{
			name = "RightKnee",
			part0 = "RightUpperLeg",
			part1 = "RightLowerLeg",
			attachment = "RightKneeRigAttachment",
		},
		{
			name = "RightAnkle",
			part0 = "RightLowerLeg",
			part1 = "RightFoot",
			attachment = "RightAnkleRigAttachment",
		},
	}

	local made = 0
	local missing = {}

	for _, info in ipairs(joints) do
		if not motorByPart[info.part1] then
			local part0 =
				model:FindFirstChild(
					info.part0,
					true
				)

			local part1 =
				model:FindFirstChild(
					info.part1,
					true
				)

			local attachment0 =
				part0
				and part0:FindFirstChild(
					info.attachment
				)
				or nil

			local attachment1 =
				part1
				and part1:FindFirstChild(
					info.attachment
				)
				or nil

			if part0
				and part0:IsA("BasePart")
				and part1
				and part1:IsA("BasePart")
				and attachment0
				and attachment0:IsA("Attachment")
				and attachment1
				and attachment1:IsA("Attachment")
			then
				local motor =
					Instance.new(
						"Motor6D"
					)

				motor.Name = info.name
				motor.Part0 = part0
				motor.Part1 = part1

				motor.C0 =
					attachment0.CFrame

				motor.C1 =
					attachment1.CFrame

				motor.Transform =
					CFrame.identity

				motor.Parent = part0

				motorByName[motor.Name] =
					motor

				motorByPart[part1.Name] =
					motor

				made += 1
			else
				table.insert(
					missing,
					info.name
				)
			end
		end
	end

	return made, missing
end

function v12IsStandardR15PartName(name)
	return
		name == "HumanoidRootPart"
		or name == "LowerTorso"
		or name == "UpperTorso"
		or name == "Head"
		or name == "LeftUpperArm"
		or name == "LeftLowerArm"
		or name == "LeftHand"
		or name == "RightUpperArm"
		or name == "RightLowerArm"
		or name == "RightHand"
		or name == "LeftUpperLeg"
		or name == "LeftLowerLeg"
		or name == "LeftFoot"
		or name == "RightUpperLeg"
		or name == "RightLowerLeg"
		or name == "RightFoot"
end

function v12RefreshR15ExtraFollowers()
	v12R15ExtraFollowers = {}

	if not morphRoot
		or not morphRoot.Parent
	then
		return
	end

	for _, part in ipairs(v12R15ExtraParts or {}) do
		if part
			and part.Parent
			and part:IsA("BasePart")
		then
			table.insert(
				v12R15ExtraFollowers,
				{
					part = part,
					relative =
						morphRoot.CFrame
						:ToObjectSpace(
							part.CFrame
						),
				}
			)
		end
	end
end

function v12MoveR15Extras(targetCF)
	for _, item in ipairs(
		v12R15ExtraFollowers or {}
	) do
		local part = item.part

		if part and part.Parent then
			part.CFrame =
				targetCF
				*
				item.relative

			part.AssemblyLinearVelocity =
				Vector3.zero

			part.AssemblyAngularVelocity =
				Vector3.zero
		end
	end
end

function v149ChooseLibraryRoot(model, preferred)
	local function valid(object)
		return object and object:IsA("BasePart") and object:IsDescendantOf(model)
	end
	if valid(model.PrimaryPart) then return model.PrimaryPart end
	if valid(preferred) then return preferred end
	local parts = {}
	for _, object in ipairs(model:GetDescendants()) do
		if object:IsA("BasePart") then table.insert(parts, object) end
	end
	for _, name in ipairs({"HumanoidRootPart", "HumanoidRootPart2"}) do
		for _, part in ipairs(parts) do
			if part.Name == name then return part end
		end
	end
	return parts[1]
end

function v11BuildLibraryMorph(data)
	local model = Instance.new("Model")
	model.Name =
		"__LOCAL_MORPH_[LIB] "
		..
		tostring(data.name or "Morph")

	local objects = {}
	local joints = {}
    local rigidConstraints = {}
	local bones = {}
	local motorByPart = {}
	local motorByName = {}

	for _, node in ipairs(data.nodes or {}) do
		if node.class == "Motor6D"
			or node.class == "Weld"
			or node.class == "WeldConstraint"
		then
			table.insert(joints, node)
        elseif node.class == "RigidConstraint" then
            table.insert(rigidConstraints, node)
		else
			local object =
				v11CreateNode(
					node,
					model
				)

			if object then
				objects[node.id] = object
			end
		end
	end

	for _, node in ipairs(data.nodes or {}) do
		local object = objects[node.id]

		if object
			and object ~= model
		then
			local parent =
				node.parent
				and objects[node.parent]
				or model

			pcall(function()
				object.Parent =
					parent or model
			end)

			if not object.Parent then
				object.Parent = model
			end
		end
	end

	local explicitBoneCount = 0

	for _, node in ipairs(data.nodes or {}) do
		if node.class == "Bone" then
			local bone = objects[node.id]

			if bone
				and bone:IsA("Bone")
			then
				bones[bone.Name] = bone
				explicitBoneCount += 1
			end
		end
	end

	if explicitBoneCount == 0 then
		for _, node in ipairs(data.nodes or {}) do
			if node.class == "MeshPart"
				and node.skinned
				and objects[node.id]
				and objects[node.id]:IsA("MeshPart")
			then
				v11RebuildBones(
					objects[node.id],
					node,
					bones
				)
			end
		end
	end

	model:SetAttribute(
		"LibraryExplicitBones",
		explicitBoneCount
	)

	print(
		"[LIB BONES]",
		tostring(data.name),
		"explicit:",
		explicitBoneCount,
		"| targets:",
		(function()
			local n = 0
			for _ in pairs(bones) do
				n += 1
			end
			return n
		end)()
	)

	for _, node in ipairs(joints) do
		local joint

		if node.class == "Motor6D" then
			joint = Instance.new("Motor6D")
			joint.C0 = v11CF12(node.c0)
			joint.C1 = v11CF12(node.c1)

			if node.transform then
				joint.Transform =
					v11CF12(
						node.transform
					)
			end

		elseif node.class == "Weld" then
			joint = Instance.new("Weld")
			joint.C0 = v11CF12(node.c0)
			joint.C1 = v11CF12(node.c1)

		else
			joint =
				Instance.new(
					"WeldConstraint"
				)
		end

		joint.Name = node.name

		joint.Parent =
			(node.parent
				and objects[node.parent])
			or model

		joint.Part0 =
			node.part0
			and objects[node.part0]
			or nil

		joint.Part1 =
			node.part1
			and objects[node.part1]
			or nil

		objects[node.id] = joint

		if joint:IsA("Motor6D") then
			motorByName[joint.Name] =
				joint

			if joint.Part1 then
				motorByPart[
					joint.Part1.Name
				] = joint
			end
		end
	end

    for _, node in ipairs(rigidConstraints) do
        local a0 = node.attachment0 and objects[node.attachment0]
        local a1 = node.attachment1 and objects[node.attachment1]
        if (a0 and not a0:IsA("Attachment")) or (a1 and not a1:IsA("Attachment")) or (node.enabled ~= false and (not a0 or not a1)) then
            model:Destroy()
            return nil, "Invalid RigidConstraint endpoints: " .. tostring(node.name)
        end
        local constraint = Instance.new("RigidConstraint")
        constraint.Name = node.name or "RigidConstraint"
        constraint.Enabled = false
        constraint.Attachment0 = a0
        constraint.Attachment1 = a1
        constraint.Parent = (node.parent and objects[node.parent]) or model
        constraint.Enabled = node.enabled ~= false
        objects[node.id] = constraint
    end

	if data.rigType == "r15" then
		local made, missing =
			v12BuildR15Motors(
				model,
				motorByPart,
				motorByName
			)

		model:SetAttribute(
			"R15GeneratedMotors",
			made
		)

		print(
			"[LIB R15]",
			tostring(data.name),
			"generated motors:",
			made,
			"/ 15"
		)

		if #missing > 0 then
			warn(
				"[LIB R15] Missing joints:",
				table.concat(
					missing,
					", "
				)
			)
		end
	end

	local preferred = data.primaryPartId and objects[data.primaryPartId]
	if not preferred or not preferred:IsA("BasePart") then
		preferred = data.rootId and objects[data.rootId]
	end
	local root = v149ChooseLibraryRoot(model, preferred)
	if not root or not root:IsA("BasePart") then
		model:Destroy()
		return nil, "No BasePart root."
	end
	model.PrimaryPart = root

	local hasRuntimeMotors =
		next(motorByName) ~= nil

	local r15ExtraParts = {}

	if data.rigType == "r15" then
		for _, object in ipairs(
			model:GetDescendants()
		) do
			if object:IsA("BasePart")
				and not v12IsStandardR15PartName(
					object.Name
				)
			then
				table.insert(
					r15ExtraParts,
					object
				)
			end
		end
	end

	for _, object in ipairs(model:GetDescendants()) do
		if object:IsA("BasePart") then
			object.CanCollide = false
			object.CanTouch = false
			object.CanQuery = false
			object.Massless = true

			if data.rigType == "r15"
				and not v12IsStandardR15PartName(
					object.Name
				)
			then

				object.Anchored = true

			elseif hasRuntimeMotors then
				object.Anchored =
					(object == root)

			else
				object.Anchored = true
			end

			object.AssemblyLinearVelocity =
				Vector3.zero

			object.AssemblyAngularVelocity =
				Vector3.zero
		end
	end

	if data.rigType == "r15" then

		root.Anchored = true
	end

	local runtimeBoneTargetCount = 0

	for _ in pairs(bones) do
		runtimeBoneTargetCount += 1
	end

	if data.stats
		and (tonumber(data.stats.bones) or 0) > 0
		and runtimeBoneTargetCount == 0
	then
		warn(
			"[LIB BONES] Carrier reports",
			data.stats.bones,
			"Bones but runtime rebuilt 0. Re-export this model with Universal Exporter v4."
		)
	end

	local npcVisual = S.npcMorphTarget ~= nil or S.npcMorphBatch ~= nil or data.__luminLocalCapture == true
	local runtimeHumanoid = Instance.new(npcVisual and "AnimationController" or "Humanoid")
	runtimeHumanoid.Name = npcVisual and "__LUMIN_VISUAL_CONTROLLER" or "__LUMIN_LIBRARY_HUMANOID"
	if not npcVisual then
		runtimeHumanoid.RequiresNeck = false
		runtimeHumanoid.AutoRotate = false
		runtimeHumanoid.PlatformStand = true
		runtimeHumanoid.BreakJointsOnDeath = false
		runtimeHumanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		pcall(function()
			runtimeHumanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
		end)
	end

	runtimeHumanoid.Parent =
		model

	local runtimeAnimator =
		Instance.new("Animator")

	runtimeAnimator.Name =
		"__LUMIN_LIBRARY_ANIMATOR"

	runtimeAnimator.Parent =
		runtimeHumanoid

    S.applyKnownMorphAppearance(model)
	model.Parent = Workspace

	return {
		model = model,
		root = root,
		bones = bones,
		motorByPart = motorByPart,
		motorByName = motorByName,
		r15ExtraParts = r15ExtraParts,
		humanoid = not npcVisual and runtimeHumanoid or nil,
		animator = runtimeAnimator,
	}
end
function S.scaleLibraryPose(pose, scale)
	return CFrame.new(pose.Position * scale) * pose.Rotation
end

function v11PrepareAnimations(data)
	local prepared = {}
	local order = {}
	local translationScale = tonumber(data.animationTranslationScale) or 1
	if translationScale ~= translationScale or translationScale <= 0 or translationScale == math.huge then
		translationScale = 1
	end
	local bakedById = {}
	for _, candidate in ipairs(data.animations or {}) do
		local id = tostring(candidate.sourceId or ""):match("%d+")
		if id and #(candidate.frames or {}) > 0 and #(candidate.channels or {}) > 0 then
			bakedById[id] = bakedById[id] or candidate
		end
	end

	for _, clip in ipairs(data.animations or {}) do
		local frames = {}
		local id = tostring(clip.sourceId or ""):match("%d+")
		local frameSource = clip
		if #(clip.frames or {}) == 0 and id and bakedById[id] then
			frameSource = bakedById[id]
		end

		for frameIndex, frame in ipairs(frameSource.frames or {}) do
			local poses = {}
			local raw = frame[2] or {}

			for channelIndex, channelName in ipairs(
				frameSource.channels or {}
			) do
				local value =
					raw[channelIndex]

				if value and value ~= false then
					local pose = v11CompactCF(value)
					poses[channelName] = CFrame.new(pose.Position * translationScale) * pose.Rotation
				end
			end

			frames[frameIndex] = {
				time =
					tonumber(frame[1])
					or 0,

				poses = poses,
			}
		end

		prepared[clip.name] = {
			name = clip.name,
			loop = clip.loop,
			sourceId = clip.sourceId,
			category = clip.category,
			sourceKind = clip.sourceKind,
			duration =
				tonumber(frameSource.duration)
				or 0,

			channels =
				frameSource.channels or {},

			frames = frames,
		}

		table.insert(order, clip.name)
	end

	return prepared, order
end

function v11Target(channelName)
	local bone =
		v11UniversalBoneTargets[
			channelName
		]

	if bone and bone.Parent then
		return bone
	end

	local motor =
		v11UniversalMotorByPartName[
			channelName
		]
		or
		v11UniversalMotorByName[
			channelName
		]

	if motor and motor.Parent then
		return motor
	end

	return nil
end

function v11AnimationSnapshot()
	local result = {}

	for _, clip in pairs(
		v11UniversalPrepared or {}
	) do
		for _, channelName in ipairs(
			clip.channels or {}
		) do
			if result[channelName] == nil then
				local target =
					v11Target(channelName)

				if target then
					result[channelName] =
						(not v144RuntimeUsingAnimator and S.libraryRenderedModel == morphModel and S.libraryRenderedPose and S.libraryRenderedPose[target]) or S.scaleLibraryPose(target.Transform, 1 / morphModel:GetScale())
				end
			end
		end
	end

	return result
end

function v143ShouldManualLoopLibraryClip(name)
	local value =
		v143NormalizeLibraryClipName(
			name
		)

	if string.find(value, "attack", 1, true)
		or string.find(value, "warning", 1, true)
		or string.find(value, "punish", 1, true)
	then
		return false
	end

	return
		string.find(value, "idle", 1, true) ~= nil
		or string.find(value, "run", 1, true) ~= nil
		or string.find(value, "walk", 1, true) ~= nil
		or string.find(value, "move", 1, true) ~= nil
		or string.find(value, "wander", 1, true) ~= nil
end

v143UniversalManualForceLoop = false
v147UniversalManualLoopOverride = nil
v146ManualActionSerial = 0

function S.poseBlendAlpha(elapsed)
    local t = math.clamp(elapsed / 0.35, 0, 1)
    return t * t * (3 - 2 * t)
end

function S.resetLibraryPose()
    S.libraryPoseReturn = {from=v11AnimationSnapshot(), model=morphModel, started=os.clock()}
end

function S.stepLibraryPoseReturn()
    local state = S.libraryPoseReturn
    if not state then return end
    if state.model ~= morphModel or not morphModel or not morphModel.Parent then S.libraryPoseReturn=nil; return end
    local alpha = S.poseBlendAlpha(os.clock()-state.started)
    for channel, pose in pairs(state.from) do
        local target = v11Target(channel)
        if target then
            local blended=pose:Lerp(CFrame.identity,alpha)
            target.Transform=S.scaleLibraryPose(blended,morphModel:GetScale())
            if S.libraryRenderedModel==morphModel and S.libraryRenderedPose then S.libraryRenderedPose[target]=blended end
        end
    end
    if alpha>=1 then S.libraryPoseReturn=nil end
end

function S.libraryTransitionChannels(clip)
    local channels,seen={},{}
    for _,channel in ipairs(clip.channels or {}) do
        local target=v11Target(channel)
        if target and not seen[target] then seen[target]=true;table.insert(channels,channel) end
    end
    for channel in pairs(v11UniversalBlendFrom or {}) do
        local target=v11Target(channel)
        if target and not seen[target] then seen[target]=true;table.insert(channels,channel) end
    end
    return channels
end

function v146ReturnFromManualAction(
	serial,
	name
)
	if serial ~= v146ManualActionSerial
		or not v11UniversalManualMode
		or v11UniversalCurrentName ~= name
	then
		return
	end

	v11UniversalManualMode = false
	v143UniversalManualForceLoop = false
	v147UniversalManualLoopOverride = nil

	v144StopRuntimeTrack(0.06)
    S.resetLibraryPose()
	if S.npcMorphTarget or S.npcMorphBatch then
		v11UniversalCurrentClip = nil
		v11UniversalCurrentName = nil
		return
	end

	local wanted =
		v11ChooseAutoClip()

	if wanted then
		v11SwitchClip(
			wanted,
			true,
			false
		)
	end
end

function v146ScheduleManualActionReturn(
	name,
	clip,
	requestedLoop
)
	v146ManualActionSerial += 1
	local serial =
		v146ManualActionSerial

	if requestedLoop == true then
		return
	end

	if v145ClipHasBakedFrames(
		clip
	) then
		local duration =
			math.max(
                (tonumber(clip.duration) or 0)<=0 and 0.4 or 0.05,
				tonumber(
					clip.duration
				) or 0
			)

		task.spawn(function()
			while serial == v146ManualActionSerial and v11UniversalCurrentName == name and S.animationClock()-v11UniversalStartedAt < duration+0.06 do
				RunService.Heartbeat:Wait()
			end
			v146ReturnFromManualAction(serial, name)
		end)

		return
	end

	task.spawn(function()
		local track =
			v144RuntimeCurrentTrack

		local started =
			os.clock()

		while track
			and track == v144RuntimeCurrentTrack
			and track.Length <= 0
			and os.clock() - started < 2
		do
			RunService.Heartbeat:Wait()
		end

		if serial ~= v146ManualActionSerial then
			return
		end

		local duration =
			track
			and track.Length
			or 0

		if duration <= 0 then
			return
		end

		while serial == v146ManualActionSerial and track == v144RuntimeCurrentTrack and track.IsPlaying do
			RunService.Heartbeat:Wait()
		end

		v146ReturnFromManualAction(
			serial,
			name
		)
	end)
end

function v145ClipHasBakedFrames(clip)
	return
		clip
		and #(clip.frames or {}) > 0
		and #(clip.channels or {}) > 0
end

function v145UseBakedClip(name, clip)
	v144StopRuntimeTrack(0)

	print(
		"[LIB PLAYBACK]",
		tostring(name),
		"-> BAKED | frames:",
		#(clip.frames or {}),
		"| duration:",
		string.format(
			"%.3f",
			tonumber(clip.duration) or 0
		)
	)

	return true
end

function v144StopRuntimeTrack(fadeTime)
	local track =
		v144RuntimeCurrentTrack

	v144RuntimeCurrentTrack = nil
	v144RuntimeCurrentName = nil
	v144RuntimeUsingAnimator = false

	if track then
		pcall(function()
			track:Stop(
				fadeTime or 0.08
			)
		end)
	end
end

function v144GetRuntimeTrack(clip)
	if not clip
		or not v144LibraryAnimator
		or not v144LibraryAnimator.Parent
		or not v144IsRuntimeAnimationId(
			clip.sourceId
		)
	then
		return nil
	end

	local name =
		tostring(clip.name)

	local existing =
		v144RuntimeTracks[name]

	if existing then
		return existing
	end

	local animation =
		Instance.new("Animation")

	animation.Name =
		"__LUMIN_LIB_"
		..
		name

	animation.AnimationId =
		tostring(clip.sourceId)

	local ok, result =
		pcall(function()
			return
				v144LibraryAnimator:
					LoadAnimation(
						animation
					)
		end)

	animation:Destroy()

	if not ok
		or not result
	then
		warn(
			"[LIB RUNTIME] LoadAnimation failed:",
			name,
			tostring(result)
		)

		return nil
	end

	pcall(function()
		result.Priority =
			Enum.AnimationPriority.Action4
	end)

	v144RuntimeTracks[name] =
		result

	return result
end

function v144ShouldLoopClip(name, clip)
	if v11UniversalManualMode
		and v147UniversalManualLoopOverride
			~= nil
	then
		return
			v147UniversalManualLoopOverride
	end

	if not v11UniversalManualMode and S.isLocomotionOverride(morphActiveName, name) then return true end

	if clip
		and clip.loop
	then
		return true
	end

	return
		v143ShouldManualLoopLibraryClip(
			name
		)
end

function v144TryRuntimeClip(name, clip)
	local track =
		v144GetRuntimeTrack(
			clip
		)

	if not track then
		return false
	end

	v144StopRuntimeTrack(0.05)

	track.Looped =
		v144ShouldLoopClip(
			name,
			clip
		)

	local ok, err =
		pcall(function()
			track:Play(
				0.08,
				1,
				S.animationPlaybackSpeed
			)
		end)

	if not ok then
		warn(
			"[LIB RUNTIME] Play failed:",
			name,
			tostring(err)
		)

		return false
	end

	v144RuntimeCurrentTrack =
		track

	v144RuntimeCurrentName =
		name

	v144RuntimeUsingAnimator =
		true

	print(
		"[LIB RUNTIME]",
		name,
		"-> Animator |",
		tostring(clip.sourceId),
		"| loop:",
		tostring(track.Looped)
	)

	if #(clip.frames or {}) > 0 then
		task.delay(0.45, function()
			if v144RuntimeCurrentTrack
				~= track
				or not morphModel
				or not morphModel.Parent
			then
				return
			end

			local evaluated =
				track.TimePosition > 0.01
				or track.WeightCurrent > 0.01

			if not evaluated then
				warn(
					"[LIB RUNTIME]",
					name,
					"did not evaluate; falling back to baked frames"
				)

				v144StopRuntimeTrack(0)

				v11UniversalStartedAt =
					S.animationClock()

				v11UniversalLastFrameIndex =
					1
			end
		end)
	end

	return true
end

function v11SwitchClip(name, force, manual, manualLoop)
	local clip =
		name
		and v11UniversalPrepared
		and v11UniversalPrepared[name]
		or nil

	if not clip then
		return false
	end

	S.activateClipSpeed(morphActiveName, name)

	if not force
		and v11UniversalCurrentName == name
	then
		if manual ~= nil then
			v11UniversalManualMode = manual

			if manual then
				v147UniversalManualLoopOverride =
					manualLoop == true

				v143UniversalManualForceLoop =
					manualLoop == true
			else
				v147UniversalManualLoopOverride =
					nil

				v143UniversalManualForceLoop =
					false
			end
		end

		if v145ClipHasBakedFrames(
			clip
		) then

			if v144RuntimeUsingAnimator
				or v144RuntimeCurrentTrack
			then
				v145UseBakedClip(
					name,
					clip
				)
			end
		else
			if not v144RuntimeUsingAnimator
				or not v144RuntimeCurrentTrack
				or not v144RuntimeCurrentTrack.IsPlaying
			then
				v144TryRuntimeClip(
					name,
					clip
				)
			end
		end

		if manual == true then
			v146ScheduleManualActionReturn(
				name,
				clip,
				manualLoop == true
			)
		end

		return true
	end

	v11UniversalBlendFrom =
		v11AnimationSnapshot()
    S.libraryPoseReturn=nil
    S.libraryBlendChannels=S.libraryTransitionChannels(clip)

	v11UniversalBlendStartedAt =
		S.animationClock()

	v11UniversalCurrentClip = clip
	v11UniversalCurrentName = name
	v11UniversalStartedAt = S.animationClock()
	v11UniversalLastFrameIndex = 1

	if manual ~= nil then
		v11UniversalManualMode = manual

		if manual then
			v147UniversalManualLoopOverride =
				manualLoop == true

			v143UniversalManualForceLoop =
				manualLoop == true
		else
			v147UniversalManualLoopOverride =
				nil

			v143UniversalManualForceLoop =
				false
		end
	end

	if v145ClipHasBakedFrames(
		clip
	) then
		v145UseBakedClip(
			name,
			clip
		)
	else
		if not v144TryRuntimeClip(
			name,
			clip
		)
		then
			v144StopRuntimeTrack(0)

			warn(
				"[LIB PLAYBACK]",
				tostring(name),
				"has neither baked frames nor a usable runtime track"
			)
		end
	end

	if manual == true then
		v146ScheduleManualActionReturn(
			name,
			clip,
			manualLoop == true
		)
	else
		v146ManualActionSerial += 1
	end

	return true
end

function v11FramePair(clip, t)
	local frames = clip.frames
	local count = #frames

	if count == 0 then
		return nil, nil, 0
	end

	if count == 1 then
		return frames[1], frames[1], 0
	end

	if t <= frames[1].time then
		v11UniversalLastFrameIndex = 1
		return frames[1], frames[2], 0
	end

	if t >= frames[count].time then
		v11UniversalLastFrameIndex =
			count - 1

		return
			frames[count - 1],
			frames[count],
			1
	end

	local i =
		math.clamp(
			v11UniversalLastFrameIndex,
			1,
			count - 1
		)

	while i < count - 1
		and frames[i + 1].time < t
	do
		i += 1
	end

	while i > 1
		and frames[i].time > t
	do
		i -= 1
	end

	v11UniversalLastFrameIndex = i

	local a = frames[i]
	local b = frames[i + 1]
	local span = b.time - a.time

	local alpha =
		span > 0
		and math.clamp(
			(t - a.time) / span,
			0,
			1
		)
		or 0

	return a, b, alpha
end

function v147NormalizeClipStateName(value)
	local text =
		string.lower(
			tostring(value or "")
		)

	text =
		string.gsub(
			text,
			"[^%w]",
			""
		)

	return text
end

function v147EnsureLocomotionStateMap(data)
	if not data then
		return
	end

	data.stateMap =
		data.stateMap or {}

	local stateMap =
		data.stateMap

	local categories = {idle=true, walk=true, run=true, fall=true, jump=true, climb=true}
	local candidates = {}
	for _, clip in ipairs(data.animations or {}) do
		local category = string.lower(tostring(clip.category or ""))
		if category == "freefall" then category = "fall" end
		local name = tostring(clip.name or "")
		local attack = string.find(string.lower(name), "attack", 1, true)
		local playable = (#(clip.frames or {}) > 0 and (tonumber(clip.duration) or 0) > 0) or v144IsRuntimeAnimationId(clip.sourceId)
		if categories[category] and not attack and playable then
			local score = (#(clip.frames or {}) > 0 and 1000 or 0) + (tonumber(clip.weight) or 1)
			if not candidates[category] or score > candidates[category].score then
				candidates[category] = {name=name, score=score}
			end
		end
	end
	for category, candidate in pairs(candidates) do
		if not stateMap[category] then stateMap[category] = candidate.name end
	end
	local exactWalk = nil
	local fuzzyWalk = nil
	local exactRun = nil
	local fuzzyRun = nil
	local exactIdle = nil

	for _, clip in ipairs(
		data.animations or {}
	) do
		local name =
			tostring(
				clip.name or ""
			)

		local normalized =
			v147NormalizeClipStateName(
				name
			)

		if normalized == "walk" then
			exactWalk =
				exactWalk or name

		elseif string.find(
			normalized,
			"walk",
			1,
			true
		)
			and not string.find(
				normalized,
				"attack",
				1,
				true
			)
			and not string.find(
				normalized,
				"crawl",
				1,
				true
			)
		then
			fuzzyWalk =
				fuzzyWalk or name
		end

		if normalized == "run" then
			exactRun =
				exactRun or name

		elseif string.find(
			normalized,
			"run",
			1,
			true
		)
			and not string.find(
				normalized,
				"attack",
				1,
				true
			)
		then
			fuzzyRun =
				fuzzyRun or name
		end

		if normalized == "idle" then
			exactIdle =
				exactIdle or name
		end
	end

	if not stateMap.walk then
		stateMap.walk =
			exactWalk
			or fuzzyWalk
	end

	if not stateMap.run then
		stateMap.run =
			exactRun
			or fuzzyRun
			or stateMap.walk
	end

	if not stateMap.idle then
		stateMap.idle =
			exactIdle
	end
end

function v11ChooseAutoClip()
	if S.npcMorphTarget or S.npcMorphBatch then return nil end
	local data = v11UniversalActiveData

	if not data then
		return nil
	end

	v147EnsureLocomotionStateMap(
		data
	)

	local stateMap = table.clone(data.stateMap or {})
	for _, state in ipairs({"idle", "walk", "run"}) do
		local assigned = S.getLocomotionOverride(morphActiveName, state)
		if assigned and v11UniversalPrepared[assigned] then stateMap[state] = assigned end
	end
	local characterNow = S.controlledCharacter()

	if not characterNow then
		return
			stateMap.idle
			or stateMap.walk
			or stateMap.run
			or (
				v11UniversalClipOrder
				and v11UniversalClipOrder[1]
			)
	end

	local humanoid =
		characterNow:FindFirstChildOfClass(
			"Humanoid"
		)

	local root =
		characterNow:FindFirstChild(
			"HumanoidRootPart"
		)

	if not humanoid or not root then
		return
			stateMap.idle
			or stateMap.walk
			or stateMap.run
			or (
				v11UniversalClipOrder
				and v11UniversalClipOrder[1]
			)
	end

	local state = humanoid:GetState()
	local velocity = root.AssemblyLinearVelocity
	local speed =
		Vector3.new(
			velocity.X,
			0,
			velocity.Z
		).Magnitude

	if state ==
		Enum.HumanoidStateType.Jumping
		and stateMap.jump
	then
		return stateMap.jump
	end

	if state ==
		Enum.HumanoidStateType.Freefall
	then
		if velocity.Y > 1.5
			and stateMap.jump
		then
			return stateMap.jump
		elseif stateMap.fall then
			return stateMap.fall
		end
	end

	if speed
		<= S.morphDriverIdleSpeed
	then
		v11UniversalRunState = false

		return
			stateMap.idle
			or stateMap.walk
			or stateMap.run
			or (
				v11UniversalClipOrder
					and v11UniversalClipOrder[1]
			)
	end

	if v11UniversalRunState then
		if speed
			<= S.morphDriverRunExit
		then
			v11UniversalRunState =
				false
		end
	else
		if speed
			>= S.morphDriverRunEnter
		then
			v11UniversalRunState =
				true
		end
	end

	if v11UniversalRunState
		and stateMap.run
	then
		return stateMap.run
	end

	if stateMap.walk then
		return stateMap.walk
	end

	if stateMap.run then
		return stateMap.run
	end

	return
		stateMap.idle
		or (
			v11UniversalClipOrder
				and v11UniversalClipOrder[1]
		)
end

function v11StopUniversalAnimation(reset)
    S.libraryRenderedPose=nil
    S.libraryRenderedModel=nil
    S.libraryPoseReturn=nil
    S.libraryBlendChannels=nil
	v144StopRuntimeTrack(0)

	for name, track in pairs(
		v144RuntimeTracks or {}
	) do
		if track then
			pcall(function()
				track:Stop(0)
			end)
		end

		v144RuntimeTracks[name] = nil
	end

	v144LibraryHumanoid = nil
	v144LibraryAnimator = nil

	if v11UniversalAnimationConnection then
		v11UniversalAnimationConnection:Disconnect()
		v11UniversalAnimationConnection = nil
	end

	if reset then
		for _, bone in pairs(
			v11UniversalBoneTargets or {}
		) do
			if bone and bone.Parent then
				bone.Transform = CFrame.identity
			end
		end

		for _, motor in pairs(
			v11UniversalMotorByName or {}
		) do
			if motor and motor.Parent then
				motor.Transform = CFrame.identity
			end
		end
	end

	v11UniversalActiveData = nil
	v11UniversalPrepared = nil
	v11UniversalClipOrder = nil
	v11UniversalBoneTargets = {}
	v11UniversalMotorByPartName = {}
	v11UniversalMotorByName = {}
	v11UniversalCurrentClip = nil
	v11UniversalCurrentName = nil
	v11UniversalManualMode = false
	v11UniversalRunState = false
	v143UniversalManualForceLoop = false
	v147UniversalManualLoopOverride = nil
	v146ManualActionSerial += 1

	v12R15ExtraParts = {}
	v12R15ExtraFollowers = {}
end

function v11StartUniversalAnimation()
	if v11UniversalAnimationConnection then
		v11UniversalAnimationConnection:Disconnect()
	end

	v11UniversalManualMode = false
	v11UniversalRunState = false
	v147UniversalManualLoopOverride = nil

	local initial =
		v11ChooseAutoClip()

	if initial then
		v11SwitchClip(
			initial,
			true,
			false
		)
	end

	v11UniversalAnimationConnection =
		RunService.PreSimulation:Connect(function()
            S.stepLibraryPoseReturn()
			if not v11UniversalActiveData
				or not morphModel
				or not morphModel.Parent
				or not v11UniversalCurrentClip
			then
				return
			end

			if not v11UniversalManualMode then
				local wanted =
					v11ChooseAutoClip()

				if wanted
					and wanted
						~= v11UniversalCurrentName
				then
					v11SwitchClip(
						wanted,
						false,
						false
					)
				end
			end

			local clip =
				v11UniversalCurrentClip

			if v144RuntimeUsingAnimator
				and v144RuntimeCurrentTrack
			then
				return
			end

			local elapsed =
				S.animationClock()
				-
				v11UniversalStartedAt

			local t

			local effectiveLoop

			if v11UniversalManualMode
				and v147UniversalManualLoopOverride
					~= nil
			then
				effectiveLoop =
					v147UniversalManualLoopOverride
			else
				effectiveLoop =
					clip.loop
					or (not v11UniversalManualMode and S.isLocomotionOverride(morphActiveName, clip.name))
					or v143ShouldManualLoopLibraryClip(
						clip.name
					)
			end

			if effectiveLoop
				and clip.duration > 0
			then
				t =
					elapsed
					%
					clip.duration
			else
				t =
					math.min(
						elapsed,
						clip.duration
					)
			end

			if clip.frames[
				v11UniversalLastFrameIndex
			]
				and t
					<
					clip.frames[
						v11UniversalLastFrameIndex
					].time
			then
				v11UniversalLastFrameIndex = 1
			end

			local a, b, alpha =
				v11FramePair(
					clip,
					t
				)

			if a and b then
                local blend = S.poseBlendAlpha(S.animationClock()-v11UniversalBlendStartedAt)
                S.libraryRenderedModel=morphModel
                S.libraryRenderedPose=S.libraryRenderedPose or {}

				for _, channelName in ipairs(
					S.libraryBlendChannels or clip.channels
				) do
					local target =
						v11Target(
							channelName
						)

					if target then
						local poseA =
							a.poses[channelName]

						local poseB =
							b.poses[channelName]

						local desired

						if poseA and poseB then
							desired =
								poseA:Lerp(
									poseB,
									alpha
								)
						elseif poseA then
							desired = poseA
						elseif poseB then
							desired = poseB
						else
							desired = CFrame.identity
						end

						local from =
							v11UniversalBlendFrom[
								channelName
							]
							or CFrame.identity

						local rendered = from:Lerp(desired, blend)
                        S.libraryRenderedPose[target]=rendered
                        target.Transform = S.scaleLibraryPose(rendered, morphModel:GetScale())
					end
				end
			end

			if not clip.loop
				and not S.isLocomotionOverride(morphActiveName, clip.name)
				and clip.duration > 0
				and elapsed >= clip.duration
				and not v11UniversalManualMode
			then
				local wanted =
					v11ChooseAutoClip()

				if wanted then
					v11SwitchClip(
						wanted,
						true,
						false
					)
				end
			end
		end)
end
function v11ApplyLibraryMorph(catalogName)
	local data =
		universalLibraryMorphs[
			catalogName
		]

	if not data then
		return false
	end

	local batch = S.npcMorphBatchPending or (S.npcMorphBatch and {records = {}, connections = {}, scope = S.npcMorphBatch.scope})
	local destination = not batch and (S.npcMorphPending or S.npcMorphTarget) or nil
	removeMorph(false)
	S.npcMorphBatch = batch
	S.npcMorphTarget = destination

	morphStatusLabel.Text =
		"Building "
		.. catalogName
		.. " ..."

	local runtime, buildError =
		v11BuildLibraryMorph(data)

	if not runtime then
		S.npcMorphTarget = nil
		morphStatusLabel.Text =
			"[LIB] morph error"

		selectedAnimLabel.Text =
			tostring(buildError)

		return false
	end

	if destination and (not destination:IsDescendantOf(Workspace) or not getSpectateRoot(destination)) then
		runtime.model:Destroy()
		S.npcMorphTarget = nil
		return false
	end

	S.captureNpcGroundGeometry(runtime.model, runtime.root, data)

	morphModel = runtime.model
	if batch then
		batch.masterParts = {}
		for _, part in ipairs(morphModel:GetDescendants()) do
			if part:IsA("BasePart") then
				table.insert(batch.masterParts, part)
				part.LocalTransparencyModifier = 1
			end
		end
	end
	morphRoot = runtime.root
	morphAnimator = nil
	morphTracks = {}
	morphActiveName = catalogName

	v11UniversalActiveData = data

	v147EnsureLocomotionStateMap(
		data
	)

	print(
		"[LIB LOCOMOTION]",
		catalogName,
		"| idle:",
		tostring(
			data.stateMap
				and data.stateMap.idle
				or "-"
		),
		"| walk:",
		tostring(
			data.stateMap
				and data.stateMap.walk
				or "-"
		),
		"| run:",
		tostring(
			data.stateMap
				and data.stateMap.run
				or "-"
		),
		"| run enter:",
		tostring(
			S.morphDriverRunEnter
		),
		"| run exit:",
		tostring(
			S.morphDriverRunExit
		)
	)

	v11UniversalBoneTargets =
		runtime.bones or {}

	v11UniversalMotorByPartName =
		runtime.motorByPart or {}

	v11UniversalMotorByName =
		runtime.motorByName or {}

	v12R15ExtraParts =
		runtime.r15ExtraParts or {}

	v144LibraryHumanoid =
		runtime.humanoid

	v144LibraryAnimator =
		runtime.animator

	v144RuntimeTracks = {}
	v144RuntimeCurrentTrack = nil
	v144RuntimeCurrentName = nil
	v144RuntimeUsingAnimator = false

	print(
		"[LIB RUNTIME] Animator:",
		v144LibraryAnimator
			and v144LibraryAnimator:GetFullName()
			or "nil"
	)

	v12R15ExtraFollowers = {}

	v11UniversalPrepared,
	v11UniversalClipOrder =
		v11PrepareAnimations(data)

	v11ApplyScaleNow(catalogName)

	if data.rigType == "r15" then
		v12RefreshR15ExtraFollowers()

		print(
			"[LIB R15]",
			catalogName,
			"extra visual parts:",
			#v12R15ExtraFollowers
		)

		for _, item in ipairs(
			v12R15ExtraFollowers
		) do
			local part = item.part

			print(
				"   visual:",
				part.Name,
				"| class:",
				part.ClassName,
				"| bones:",
				#part:GetDescendants()
			)
		end
	end

	do
		local currentRoot = S.getMorphDriverRoot()

		if currentRoot then
			local position =
				getOffsetForName(
					catalogName
				)

			local rotation =
				v11GetRotation(
					catalogName
				)

			local targetCF =
				currentRoot.CFrame
				*
				CFrame.new(
					position.X,
					position.Y,
					position.Z
				)
				*
				CFrame.Angles(
					math.rad(rotation.X),
					math.rad(rotation.Y),
					math.rad(rotation.Z)
				)

			if S.npcMorphTarget and not batch then
				targetCF = S.groundNpcCFrame(targetCF, S.npcMorphTarget, currentRoot, S.npcGroundSingle)
			end

			if data.rigType == "r15"
				or (
					data.stats
					and (data.stats.motors or 0) > 0
				)
			then

				morphRoot.CFrame =
					targetCF

				if data.rigType == "r15" then
					v12MoveR15Extras(
						targetCF
					)
				end
			else
				morphModel:PivotTo(
					targetCF
				)
			end
		end
	end

	hideRealCharacter()

	v11StartUniversalAnimation()

	RunService:UnbindFromRenderStep(
		MORPH_BIND_NAME
	)

	RunService:BindToRenderStep(
		MORPH_BIND_NAME,
		Enum.RenderPriority.Camera.Value + 250,
		function()
			if morphActiveName ~= catalogName
				or not morphModel
				or not morphModel.Parent
			then
				return
			end

			local currentRoot = S.getMorphDriverRoot()

			if not currentRoot then
				return
			end

			local position =
				getOffsetForName(
					catalogName
				)

			local rotation =
				v11GetRotation(
					catalogName
				)

			local targetCF =
				currentRoot.CFrame
				*
				CFrame.new(
					position.X,
					position.Y,
					position.Z
				)
				*
				CFrame.Angles(
					math.rad(rotation.X),
					math.rad(rotation.Y),
					math.rad(rotation.Z)
				)

			if S.npcMorphTarget and not batch then
				targetCF = S.groundNpcCFrame(targetCF, S.npcMorphTarget, currentRoot, S.npcGroundSingle)
			end

			if data.rigType == "r15"
				or (
					data.stats
					and (data.stats.motors or 0) > 0
				)
			then

				morphRoot.CFrame =
					targetCF

				if data.rigType == "r15" then
					v12MoveR15Extras(
						targetCF
					)
				end

				morphRoot.AssemblyLinearVelocity =
					Vector3.zero

				morphRoot.AssemblyAngularVelocity =
					Vector3.zero
			else
				morphModel:PivotTo(
					targetCF
				)
			end
		end
	)

	morphStatusLabel.Text =
		"Active morph: "
		.. catalogName

	selectedAnimLabel.Text =
		getAnimationSummary(
			catalogName
		)

	if data.rigType == "r15" then
		print(
			"[LIB R15 ACTIVE]",
			catalogName,
			"root:",
			morphRoot.Name,
			"anchored:",
			morphRoot.Anchored,
			"generated:",
			morphModel:GetAttribute(
				"R15GeneratedMotors"
			)
		)
	end

	if batch then S.startNpcBatchWatch() end

	return true
end
function getAnimationSummary(npcName)
	local data =
		universalLibraryMorphs[
			npcName
		]

	if data then
		local states =
			data.stateMap or {}

		local rigText =
			data.rigType == "r15"
			and "R15 · "
			or ""

		return
			rigText
			..
			"Animations: "
			..
			tostring(
				#(data.animations or {})
			)
			..
			" clips"
			..
			" · AUTO idle="
			..
			tostring(states.idle or "-")
			..
			" walk="
			..
			tostring(states.walk or "-")
			..
			" run="
			..
			tostring(states.run or "-")
			..
			" jump="
			..
			tostring(states.jump or "-")
			..
			" fall="
			..
			tostring(states.fall or "-")
	end

	return
		S.nativeAnimationSummary(
			npcName
		)
end

function getAnimationObjectsForNpc(npcName)
	local data =
		universalLibraryMorphs[
			npcName
		]

	if data then
		local result = {}

		for _, clip in ipairs(
			data.animations or {}
		) do
			local frameCount =
				#(clip.frames or {})

			local duration =
				tonumber(
					clip.duration
				) or 0

			local hasDirect =
				frameCount > 0
				and duration > 0

			local hasRuntime =
				v144IsRuntimeAnimationId(
					clip.sourceId
				)

			table.insert(
				result,
				{
					Name = clip.name,
					__LuminLibrary = true,
					__LuminFrames = frameCount,
					__LuminDuration = duration,
					__LuminRuntimeOnly =
						not hasDirect
						and hasRuntime,
					__LuminRuntimeId =
						clip.sourceId,
					__LuminEmpty =
						not hasDirect
						and not hasRuntime,
				}
			)
		end

		table.sort(
			result,
			function(a, b)
				return
					string.lower(a.Name)
					<
					string.lower(b.Name)
			end
		)

		return result
	end

	return
		S.nativeAnimationObjects(
			npcName
		)
end

function collectMorphNames()
	local names =
		S.registryMorphNames()

	local used = {}

	for _, name in ipairs(names) do
		used[name] = true
	end

	for name in pairs(
		universalLibraryMorphs
	) do
		if not used[name] then
			used[name] = true
			table.insert(names, name)
		end
	end

	table.sort(
		names,
		function(a, b)
			return
				string.lower(a)
				<
				string.lower(b)
		end
	)

	return names
end

function applyMorph(npcName)
    if S.avatarSkins then S.avatarSkins.active=S.avatarSkins.entries[npcName] and npcName or nil end
	if S.npcMorphTarget or S.npcMorphBatch then removeMorph(false) end
	if universalLibraryMorphs[
		npcName
	] then
		v11ApplyLibraryMorph(
			npcName
		)
		return
	end

	S.applyNativeMorph(npcName)

	task.defer(function()
		v11ApplyScaleNow(npcName)
	end)
end

function removeMorph(showMessage)
    if showMessage and S.avatarSkins then S.avatarSkins.active=nil end
	if S.removingMorph then return end
	S.removingMorph = true
	if S.restoreActorScene then S.restoreActorScene() end
	if S.restoreKillVisuals then S.restoreKillVisuals() end
	local ownedModel = morphModel
	local batch = S.npcMorphBatch
	local function cleanup(label, callback)
		local ok, err = pcall(callback)
		if not ok then warn("[Lumin cleanup " .. label .. "] " .. tostring(err)) end
	end
	RunService:UnbindFromRenderStep(MORPH_BIND_NAME)
	cleanup("batch", function() if S.stopNpcBatch then S.stopNpcBatch() end end)
	cleanup("animation", function() v11StopUniversalAnimation(false) end)
	cleanup("morph", function() S.removeNativeMorph(showMessage) end)
	if batch then
		for _, connection in ipairs(batch.connections or {}) do cleanup("batch connection", function() connection:Disconnect() end) end
		for _, record in pairs(batch.records or {}) do
			cleanup("batch copy", function()
				if record.connection then record.connection:Disconnect() end
				if record.model then record.model:Destroy() end
			end)
		end
	end
	cleanup("owned model", function() if ownedModel then ownedModel:Destroy() end end)
	morphModel, morphRoot, morphAnimator, morphActiveName = nil, nil, nil, nil
	cleanup("target visibility", S.restoreNpcMorphVisibility)
	cleanup("player visibility", restoreRealCharacter)
	S.npcMorphTarget = nil
	S.npcMorphBatch = nil
	S.npcGroundGeometry = nil
	S.npcGroundSingle = {}
	S.removingMorph = false
end

function S.playLibraryMorphAnimation(
	npcName,
	animationName,
	playMode
)
	if universalLibraryMorphs[
		npcName
	] then
		if morphActiveName ~= npcName
			or not morphModel
		then
			selectMorph(npcName)

			if not v11ApplyLibraryMorph(
				npcName
			) then
				return false
			end
		end

		clearManualAnimationState()

		return
			v11SwitchClip(
				animationName,
				true,
				true,
				playMode == "loop"
			)
	end

	return
		S.playNativeMorphAnimation(
			npcName,
			animationName,
			playMode
		)
end
playManualMorphAnimation = S.playLibraryMorphAnimation

function S.stopLibraryMorphAnimation()
	if morphActiveName
		and universalLibraryMorphs[
			morphActiveName
		]
		and v11UniversalAnimationConnection
	then
		clearManualAnimationState()

		v11UniversalManualMode = false
		v147UniversalManualLoopOverride = nil
		v143UniversalManualForceLoop = false
		v146ManualActionSerial += 1
        S.resetLibraryPose()
		if S.npcMorphTarget or S.npcMorphBatch then
			v144StopRuntimeTrack(0.06)
			v11UniversalCurrentClip = nil
			v11UniversalCurrentName = nil
			return
		end

		local wanted =
			v11ChooseAutoClip()

		if wanted then
			v11SwitchClip(
				wanted,
				true,
				false
			)
		end

		return
	end

	S.stopNativeMorphAnimation()
end
stopManualAnimation = S.stopLibraryMorphAnimation

V11_selectMorphOriginal =
	selectMorph

selectMorph = function(name)
	V11_selectMorphOriginal(name)
	v11RefreshTransformSliders()
end

function rebuildCustomList()
end

S.cutsceneProtection = false
S.autoSpectateUi = false
S.captureUi = nil
function S.restoreCaptureUi()
	local saved = S.captureUi
	S.captureUi = nil
	if not saved then return end
	for _, connection in ipairs(saved.connections) do connection:Disconnect() end
	for object, enabled in pairs(saved.objects) do
		if object.Parent and not S.uiHidden[object] then
			pcall(function() object.Enabled = enabled end)
		end
	end
	for kind, enabled in pairs(saved.core) do
		pcall(function() game:GetService("StarterGui"):SetCoreGuiEnabled(kind, enabled) end)
	end
	main.Visible = saved.panelVisible
end

function S.hideCaptureUi()
	if S.captureUi or not S.spectateActive or not S.autoSpectateUi then return end
	local saved = {objects = {}, core = {}, connections = {}, panelVisible = main.Visible}
	S.captureUi = saved
	local function hide(object)
		if object == gui or object == S.horrorEffectsGui or not object:IsA("ScreenGui") then return end
		if saved.objects[object] ~= nil then return end
		saved.objects[object] = object.Enabled
		table.insert(saved.connections, object:GetPropertyChangedSignal("Enabled"):Connect(function()
			if S.captureUi == saved and object.Enabled then object.Enabled = false end
		end))
		object.Enabled = false
	end
	for _, object in ipairs(playerGui:GetDescendants()) do hide(object) end
	table.insert(saved.connections, playerGui.DescendantAdded:Connect(hide))
	for _, kind in ipairs(Enum.CoreGuiType:GetEnumItems()) do
		if kind ~= Enum.CoreGuiType.All then
			pcall(function()
				local starter = game:GetService("StarterGui")
				saved.core[kind] = starter:GetCoreGuiEnabled(kind)
				starter:SetCoreGuiEnabled(kind, false)
			end)
		end
	end
	main.Visible = false
end

S.cameraNpcScroll.Size = UDim2.new(1, -24, 1, -312)
S.cameraNpcScroll.Position=UDim2.fromOffset(12,124)
function S.initializeCameraChooser()

    local partButton=makeButton(S.spectateSection,"Choose Part",UDim2.new(0.5,-16,0,30),UDim2.fromOffset(12,84),COL.button)
    local modelButton=makeButton(S.spectateSection,"Choose Model",UDim2.new(0.5,-16,0,30),UDim2.new(0.5,4,0,84),COL.button)
    function S.cancelCameraChoose()
        S.cameraChooseMode=nil
        partButton.Text="Choose Part";modelButton.Text="Choose Model"
    end
    local function choose(mode)
        local previous=S.cameraChooseMode
        if S.cancelMorphChoose then S.cancelMorphChoose() end
        S.cancelCameraChoose()
        if previous==mode then return end
        S.cameraChooseMode=mode
        if mode=="Part" then partButton.Text="Click part / Esc" else modelButton.Text="Click model / Esc" end
    end
    S.connectAction(partButton,function() choose("Part") end)
    S.connectAction(modelButton,function() choose("Model") end)
    ugKeepRootConnection(UserInputService.InputBegan:Connect(function(input,processed)
        if not S.cameraChooseMode or S.unloading then return end
        if input.KeyCode==Enum.KeyCode.Escape then S.cancelCameraChoose();return end
        if not S.spectateSection.Parent.Visible then S.cancelCameraChoose();return end
        if processed or UserInputService:GetFocusedTextBox() or input.UserInputType~=Enum.UserInputType.MouseButton1 then return end
        local point=UserInputService:GetMouseLocation()
        for _,object in ipairs(playerGui:GetGuiObjectsAtPosition(point.X,point.Y)) do if object.Active then return end end
        local mouse=player:GetMouse()
        local params=RaycastParams.new()
        params.FilterType=Enum.RaycastFilterType.Exclude
        local ignore={}
        local actor=S.controlledCharacter and S.controlledCharacter() or player.Character
        if actor then table.insert(ignore,actor) end
        params.FilterDescendantsInstances=ignore
        local hit=Workspace:Raycast(mouse.UnitRay.Origin,mouse.UnitRay.Direction*2000,params)
        if not hit or not hit.Instance:IsA("BasePart") then return end
        local target=hit.Instance
        if S.cameraChooseMode=="Model" then
            target=target:FindFirstAncestorOfClass("Model")
            if not target or target==Workspace then modelButton.Text="No model — retry";return end
        end
        if not getSpectateRoot(target) then return end
        S.cameraChooseSuppressUntil=os.clock()+0.2
        S.cancelCameraChoose()
        ugSpectateEntry({model=target,key="picked:"..target:GetFullName(),displayName=target.Name})
    end))
    ugKeepRootConnection(S.spectateSection.Parent:GetPropertyChangedSignal("Visible"):Connect(function()
        if not S.spectateSection.Parent.Visible then S.cancelCameraChoose() end
    end))
end
S.initializeCameraChooser()
S.spectateSection.Size = UDim2.new(1, -390, 1, -133)
S.freecamSection.Size = UDim2.new(0, 330, 1, -361)
S.protectButton = makeButton(S.spectateSection, "Cutscene protection: OFF", UDim2.new(1, -24, 0, 32), UDim2.new(0, 12, 1, -172), COL.button)
S.protectButton.TextSize = 10
S.autoUiButton = makeButton(S.spectateSection, "Auto-hide UI: OFF", UDim2.new(1, -24, 0, 32), UDim2.new(0, 12, 1, -132), COL.button)
S.autoUiButton.TextSize = 10
S.connectAction(S.protectButton,function()
	S.cutsceneProtection = not S.cutsceneProtection
	S.protectButton.Text = "Cutscene protection: " .. (S.cutsceneProtection and "ON" or "OFF")
	S.startSpectateGuard()
	if S.spectateActive then
		RunService:UnbindFromRenderStep(S.SPECTATE_BIND_NAME)
		RunService:BindToRenderStep(S.SPECTATE_BIND_NAME, S.cutsceneProtection and Enum.RenderPriority.Last.Value + 100 or Enum.RenderPriority.Camera.Value + 500, S.spectateRenderStep)
	end
end)
S.connectAction(S.autoUiButton,function()
	S.autoSpectateUi = not S.autoSpectateUi
	S.autoUiButton.Text = "Auto-hide UI: " .. (S.autoSpectateUi and "ON" or "OFF")
	if S.autoSpectateUi then S.hideCaptureUi() else S.restoreCaptureUi() end
end)

createTabButton("Color", "Color correction", 322)
S.colorPage = createPage("Color")
S.colorSection = makeSection(S.colorPage, "COLOR GRADING", UDim2.new(0, 24, 0, 24), UDim2.new(1, -48, 1, -48))
S.colorEffect = Instance.new("ColorCorrectionEffect")
S.colorEffect.Name = "LuminColorCorrection"
S.colorEffect.Enabled = false
S.colorEffect.Parent = game:GetService("Lighting")
S.colorToggle = makeButton(S.colorSection, "Color correction: OFF", UDim2.new(0.5, -18, 0, 32), UDim2.new(0, 12, 0, 38), COL.blue)
S.colorReset = makeButton(S.colorSection, "Reset", UDim2.new(0.5, -18, 0, 32), UDim2.new(0.5, 6, 0, 38), COL.button)
S.connectAction(S.colorToggle,function()
	S.colorEffect.Enabled = not S.colorEffect.Enabled
	S.colorToggle.Text = "Color correction: " .. (S.colorEffect.Enabled and "ON" or "OFF")
end)
S.colorScroll = Instance.new("ScrollingFrame")
S.colorScroll.BackgroundTransparency = 1
S.colorScroll.BorderSizePixel = 0
S.colorScroll.Position = UDim2.fromOffset(0, 76)
S.colorScroll.Size = UDim2.new(1, 0, 1, -88)
S.colorScroll.CanvasSize = UDim2.fromOffset(0, 530)
S.colorScroll.ScrollBarThickness = 5
S.colorScroll.Parent = S.colorSection
S.shadowLift = 0
S.noShadows = false
function S.restoreShadowLighting()
    if not S.shadowOriginal then return end
    local lighting = game:GetService("Lighting")
    lighting.Ambient = S.shadowOriginal.ambient
    lighting.OutdoorAmbient = S.shadowOriginal.outdoor
    lighting.GlobalShadows = S.shadowOriginal.shadows
    S.shadowOriginal = nil
end
function S.applyShadowLighting()
    if S.shadowLift == 0 and not S.noShadows then S.restoreShadowLighting(); return end
    local lighting = game:GetService("Lighting")
    S.shadowOriginal = S.shadowOriginal or {ambient=lighting.Ambient, outdoor=lighting.OutdoorAmbient, shadows=lighting.GlobalShadows}
    local t = S.noShadows and 1 or S.shadowLift/100
    lighting.Ambient = S.shadowOriginal.ambient:Lerp(Color3.new(1,1,1), t)
    lighting.OutdoorAmbient = S.shadowOriginal.outdoor:Lerp(Color3.new(1,1,1), t)
    lighting.GlobalShadows = not S.noShadows and S.shadowOriginal.shadows
end
S.shadowSlider = createSlider(S.colorScroll, "Shadow brightness (gamma)", 0, 100, 1, 0, 400, function(value)
    S.shadowLift = value
    S.applyShadowLighting()
end)
S.shadowButton = makeButton(S.colorScroll, "No shadows: OFF", UDim2.new(1,-24,0,32), UDim2.fromOffset(12,472), COL.button)
function S.toggleShadows()
    S.noShadows = not S.noShadows
    S.shadowButton.Text = "No shadows: " .. (S.noShadows and "ON" or "OFF")
    S.applyShadowLighting()
end
S.connectAction(S.shadowButton,S.toggleShadows)
S.colorSliders = {}
S.colorTint = {1, 1, 1}
do
	local specs = {
		{"Brightness", -0.5, 0.5, 0, "Brightness"},
		{"Contrast", -1, 1, 0, "Contrast"},
		{"Saturation", -1, 1, 0, "Saturation"},
		{"Tint: red", 0, 1, 1, 1},
		{"Tint: green", 0, 1, 1, 2},
		{"Tint: blue", 0, 1, 1, 3},
	}
	for i, spec in ipairs(specs) do
		local property = spec[5]
		S.colorSliders[i] = createSlider(S.colorScroll, spec[1], spec[2], spec[3], 0.01, spec[4], 4 + (i - 1) * 66, function(value)
			if type(property) == "number" then
				S.colorTint[property] = value
				S.colorEffect.TintColor = Color3.new(unpack(S.colorTint))
			else
				S.colorEffect[property] = value
			end
		end)
	end
end
S.connectAction(S.colorReset,function()
    S.noShadows = false
    S.shadowButton.Text = "No shadows: OFF"
    S.shadowSlider.SetValue(0, true)
	for i, slider in ipairs(S.colorSliders) do slider.SetValue(i <= 3 and 0 or 1, true) end
end)

S.resizeHandle = makeButton(main, "◢", UDim2.new(0, 24, 0, 24), UDim2.new(1, -24, 1, -24), COL.button)
S.resizeHandle.ZIndex = 20
S.windowScale = Instance.new("UIScale")
S.windowScale.Parent = main
function S.fitWindow()
	local camera = Workspace.CurrentCamera
	if not camera then return end
	local view = camera.ViewportSize
	S.windowScale.Scale = math.min(1, math.max(0.1, (view.X - 24) / main.Size.X.Offset), math.max(0.1, (view.Y - 60) / main.Size.Y.Offset))
	local scale = S.windowScale.Scale
	local pos = main.AbsolutePosition
	main.Position = UDim2.fromOffset(math.clamp(pos.X, 0, math.max(0, view.X - main.Size.X.Offset * scale)), math.clamp(pos.Y, 0, math.max(0, view.Y - 60 - main.Size.Y.Offset * scale)))
end
main.Size = UDim2.fromOffset(1160, 820)
S.fitWindow()
S.resizeHandle.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		S.resizing = {input = input, position = input.Position, size = main.Size, scale = S.windowScale.Scale}
	end
end)
ugKeepRootConnection(UserInputService.InputChanged:Connect(function(input)
	local resize = S.resizing
	if resize and (input.UserInputType == Enum.UserInputType.MouseMovement or input == resize.input) then
		local delta = (input.Position - resize.position) / resize.scale
		main.Size = UDim2.fromOffset(math.clamp(resize.size.X.Offset + delta.X, 900, 1400), math.clamp(resize.size.Y.Offset + delta.Y, 620, 950))
		S.fitWindow()
	end
end))
ugKeepRootConnection(UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or (S.resizing and input == S.resizing.input) then S.resizing = nil end
end))
S.viewportConnection = nil
function S.watchViewport()
	if S.viewportConnection then S.viewportConnection:Disconnect() end
	local camera = Workspace.CurrentCamera
	if camera then S.viewportConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(S.fitWindow) end
	S.fitWindow()
end
ugKeepRootConnection(Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(S.watchViewport))
S.watchViewport()

S.previewElapsed = 0
ugKeepRootConnection(RunService.Heartbeat:Connect(function(dt)
	if S.unloading or S.economyMode then return end
	if S.modelPreviewsEnabled==false then return end
	S.previewElapsed += dt
	if S.previewElapsed < 0.15 then return end
	S.previewElapsed = 0
	S.updateNpcPreviews()
end))
main:GetPropertyChangedSignal("Visible"):Connect(function()
	if main.Visible then
		main.BackgroundTransparency = 0.12
		S.animateUi(main, {BackgroundTransparency = 0}, 0.14)
	end
end)
S.npcGroundEnabled = false
S.npcGroundSingle = {}

function S.captureNpcGroundGeometry(model, root, data)
	local anchor = ((data.rigType == "r15") or (data.stats and (data.stats.motors or 0) > 0)) and root.CFrame or model:GetPivot()
	local geometry = {scale = model:GetScale(), parts = {}}
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") and part.Transparency < 0.95 then
			table.insert(geometry.parts, {cf = anchor:ToObjectSpace(part.CFrame), size = part.Size})
		end
	end
	S.npcGroundGeometry = geometry
	S.npcGroundSingle = {}
end

function S.groundNpcCFrame(cf, target, root, state)
	local geometry = S.npcGroundGeometry
	if not S.npcGroundEnabled or not geometry or #geometry.parts == 0 then
		state.correction = nil
		return cf
	end
	local humanoid = target:FindFirstChildWhichIsA("Humanoid")
	if humanoid then
		local mode = humanoid:GetState()
		if mode == Enum.HumanoidStateType.Jumping or mode == Enum.HumanoidStateType.Freefall then
			state.nextProbe = 0
			return cf + Vector3.new(0, state.correction or 0, 0)
		end
	end
	local now = os.clock()
	if now >= (state.nextProbe or 0) or not state.probePosition or (root.Position - state.probePosition).Magnitude > 4 then
		state.nextProbe = now + 0.08
		state.probePosition = root.Position
		local ignore = {target, morphModel}
		for _, p in ipairs(Players:GetPlayers()) do
			if p.Character then table.insert(ignore, p.Character) end
		end
		if S.npcMorphBatch then
			for other, record in pairs(S.npcMorphBatch.records) do
				table.insert(ignore, other)
				table.insert(ignore, record.model)
			end
		end
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = ignore
		params.RespectCanCollide = true
		params.IgnoreWater = true
		local hit = Workspace:Raycast(Vector3.new(cf.Position.X, root.Position.Y + 2, cf.Position.Z), Vector3.new(0, -66, 0), params)
		state.floorY = hit and hit.Normal.Y > 0.35 and hit.Position.Y or nil
	end
	if not state.floorY then state.correction = nil; return cf end
	local scale = v11GetScale(morphActiveName) / geometry.scale
	local orientation = cf.Rotation
	local bottom = math.huge
	for _, part in ipairs(geometry.parts) do
		local relative = orientation * (CFrame.new(part.cf.Position * scale) * part.cf.Rotation)
		local half = part.size * (scale * 0.5)
		local extent = math.abs(relative.RightVector.Y) * half.X + math.abs(relative.UpVector.Y) * half.Y + math.abs(relative.LookVector.Y) * half.Z
		bottom = math.min(bottom, relative.Position.Y - extent)
	end
	local wanted = state.floorY - bottom + getOffsetForName(morphActiveName).Y - cf.Position.Y
	local dt = math.clamp(now - (state.time or now), 0, 0.1)
	if state.correction == nil or not state.lastPosition or (root.Position - state.lastPosition).Magnitude > 20 then
		state.correction = wanted
	else
		state.correction += (wanted - state.correction) * (1 - math.exp(-20 * dt))
	end
	state.time = now
	state.lastPosition = root.Position
	return cf + Vector3.new(0, state.correction, 0)
end

function S.stopNpcBatch()
	local batch = S.npcMorphBatch
	S.npcMorphBatch = nil
	if not batch then return end
	for _, connection in ipairs(batch.connections) do connection:Disconnect() end
	for _, record in pairs(batch.records) do
		if record.connection then record.connection:Disconnect() end
		record.model:Destroy()
	end
end

function S.isLocalMorphObject(object)
	while object and object ~= Workspace do
		if string.sub(object.Name, 1, 14) == "__LOCAL_MORPH_" then return true end
		object = object.Parent
	end
	return false
end

function S.createNpcBatchCopy(target)
	local batch = S.npcMorphBatch
	if not batch or not morphModel then return end
	local objects = morphModel:GetDescendants()
	table.insert(objects, 1, morphModel)
	local saved = {}
	for id, object in ipairs(objects) do
		saved[id] = {object.Archivable, object:GetAttribute("__LuminCopyId")}
		object.Archivable = true
		object:SetAttribute("__LuminCopyId", id)
	end
	local ok, copy = pcall(function() return morphModel:Clone() end)
	for id, object in ipairs(objects) do
		object.Archivable = saved[id][1]
		object:SetAttribute("__LuminCopyId", saved[id][2])
	end
	if not ok or not copy then
		warn("[Lumin NPC] Cannot build animation copy", tostring(copy))
		return
	end
	local record = {model = copy, parts = {}, bones = {}, motors = {}, meshes = {}, ground = {}}
	local cloned = copy:GetDescendants()
	table.insert(cloned, 1, copy)
	for _, destination in ipairs(cloned) do
		local id = destination:GetAttribute("__LuminCopyId")
		local source = id and objects[id]
		if source then
			if source == morphRoot then record.root = destination end
			if source:IsA("BasePart") then
				destination.CanCollide = false
				destination.CanTouch = false
				destination.CanQuery = false
				destination.LocalTransparencyModifier = 0
				table.insert(record.parts, {source, destination})
			elseif source:IsA("Bone") then
				table.insert(record.bones, {source, destination})
			elseif source:IsA("Motor6D") then
				table.insert(record.motors, {source, destination})
			elseif source:IsA("SpecialMesh") then
				table.insert(record.meshes, {source, destination})
			end
		end
	end
	S.cleanDetachedVisualClone(copy)
	for _, object in ipairs(cloned) do
		if object:IsA("LuaSourceContainer") then object:Destroy() end
	end
	if not record.root then copy:Destroy(); return end
	record.animator = copy:FindFirstChildWhichIsA("Animator", true)
	copy.Name = "__LOCAL_MORPH_BATCH_" .. target.Name
	batch.records[target] = record
	return record
end

function S.isMrMixMorphTarget(model)
	if not model:IsA("Model") or not model:IsDescendantOf(Workspace) or S.isLocalMorphObject(model) or ugIsPlayerCharacterModel(model) then return false end
	if not model:FindFirstChildOfClass("AnimationController") and not model:FindFirstChildOfClass("Humanoid") then return false end
	if not getSpectateRoot(model) then return false end
	local name = string.lower(model.Name):gsub("[^%w]", "")
	if string.find(name, "mrmix", 1, true) or name == "kitchenrun" then return true end
	local ancestor = model.Parent
	while ancestor and ancestor ~= Workspace do
		local parentName = string.lower(ancestor.Name):gsub("[^%w]", "")
		if parentName == "mrmix" then return true end
		ancestor = ancestor.Parent
	end
	return false
end

function S.findMrMixMorphTargets()
	local found = {}
	local candidates = {}
	for _, object in ipairs(Workspace:GetDescendants()) do
		if S.isMrMixMorphTarget(object) then candidates[object] = true end
	end
	for model in pairs(candidates) do
		local ancestor = model.Parent
		local nested = false
		while ancestor and ancestor ~= Workspace do
			if candidates[ancestor] then nested = true; break end
			ancestor = ancestor.Parent
		end
		if not nested then table.insert(found, {model = model}) end
	end
	return found
end

function S.refreshNpcBatch()
	local batch = S.npcMorphBatch
	if not batch or S.unloading or not morphModel then return end
	local entries
	if batch.scope == "MrMix" then
		entries = S.findMrMixMorphTargets()
	else
		ugScanCameraNpcs(true)
		entries = S.cameraNpcEntries or {}
	end
	local present = {}
	for _, entry in ipairs(entries) do
		local target = entry.model
		if target and target:IsDescendantOf(Workspace) and not S.isLocalMorphObject(target) and not ugIsPlayerCharacterModel(target) and getSpectateRoot(target) then
			present[target] = true
			if not batch.records[target] then S.createNpcBatchCopy(target) end
		end
	end
	for target, record in pairs(batch.records) do
		if not present[target] then
			if record.connection then record.connection:Disconnect() end
			record.model:Destroy()
			batch.records[target] = nil
		end
	end
end

function S.queueNpcBatchRefresh(object)
	local batch = S.npcMorphBatch
	if not batch or S.unloading or (object and S.isLocalMorphObject(object)) then return end
	if object and not (object:IsA("Model") or object:IsA("BasePart") or object:IsA("Humanoid") or object:IsA("AnimationController")) then return end
	batch.dirty = true
end

function S.startNpcBatchWatch()
	local batch = S.npcMorphBatch
	if not batch then return end
	batch.connections[1] = Workspace.DescendantAdded:Connect(S.queueNpcBatchRefresh)
	batch.connections[2] = Workspace.DescendantRemoving:Connect(S.queueNpcBatchRefresh)
	batch.connections[4] = RunService.PreSimulation:Connect(S.syncNpcBatchAnimations)
	batch.elapsed = 0
	batch.connections[3] = RunService.Heartbeat:Connect(function(dt)
		if S.npcMorphBatch ~= batch or S.unloading then return end
		batch.elapsed += dt
		if batch.elapsed < 0.25 or not batch.dirty then return end
		batch.elapsed = 0
		batch.dirty = false
		S.refreshNpcBatch()
	end)
	S.refreshNpcBatch()
end

function S.syncNpcBatchAnimations()
	local batch = S.npcMorphBatch
	if not batch then return end
	local sourceTrack = v144RuntimeUsingAnimator and v144RuntimeCurrentTrack
	local clip = v11UniversalCurrentClip
	local native = sourceTrack and clip and not v145ClipHasBakedFrames(clip)
	local key = native and (tostring(v11UniversalCurrentName) .. ":" .. tostring(v11UniversalStartedAt)) or nil
	for target, record in pairs(batch.records) do
		if record.model.Parent and not S.targetAutoEnabled and not (S.autoRecordOwns and S.autoRecordOwns(target)) then
			if record.trackKey ~= key then
				if record.track then record.track:Stop(0); record.track:Destroy(); record.track = nil end
				record.trackKey = key
				if native and record.animator then
					local animation = Instance.new("Animation")
					animation.AnimationId = tostring(clip.sourceId)
					local ok, track = pcall(function() return record.animator:LoadAnimation(animation) end)
					animation:Destroy()
					if ok then
						record.track = track
						track.Priority = sourceTrack.Priority
						track.Looped = sourceTrack.Looped
						track:Play(0.08, 1, sourceTrack.Speed)
						record.nextSync = 0
					else
						warn("[Lumin NPC Animation]", tostring(track))
					end
				end
			end
			for _, pair in ipairs(record.motors) do
				pair[2].C0 = pair[1].C0
				pair[2].C1 = pair[1].C1
				if not native then pair[2].Transform = pair[1].Transform end
			end
			for _, pair in ipairs(record.bones) do
				pair[2].CFrame = pair[1].CFrame
				if not native then pair[2].Transform = pair[1].Transform end
			end
			if native and record.track and record.track.Length > 0 and os.clock() >= (record.nextSync or 0) then
				record.track:AdjustSpeed(sourceTrack.Speed)
				local elapsed = sourceTrack.TimePosition
				local t = record.track.Looped and elapsed % record.track.Length or math.min(elapsed, record.track.Length)
				if math.abs(record.track.TimePosition - t) > 0.12 then record.track.TimePosition = t end
				record.nextSync = os.clock() + 0.5
			end
		end
	end
end

function S.renderNpcBatch()
	local batch = S.npcMorphBatch
	if not batch or not morphModel or not morphRoot then return end
	local offset = getOffsetForName(morphActiveName)
	local rotation = v11GetRotation(morphActiveName)
	local adjustment = CFrame.new(offset) * CFrame.Angles(math.rad(rotation.X), math.rad(rotation.Y), math.rad(rotation.Z))
	local reference = (batch.driverCFrame or CFrame.identity) * adjustment
	local count = 0
	for target, record in pairs(batch.records) do
		local root = target:IsDescendantOf(Workspace) and getSpectateRoot(target)
		if root and not ugIsPlayerCharacterModel(target) then
			local destination = S.groundNpcCFrame(root.CFrame * adjustment, target, root, record.ground)
			local delta = destination * reference:Inverse()
			local entering = record.model.Parent == nil
			for _, pair in ipairs(record.parts) do
				local source, part = pair[1], pair[2]
				part.Size = source.Size
				if part == record.root or part.Anchored or entering then part.CFrame = delta * source.CFrame end
				part.Transparency = source.Transparency
			end
			for _, pair in ipairs(record.meshes) do
				pair[2].Scale = pair[1].Scale
				pair[2].Offset = pair[1].Offset
			end
			if not record.connection then
				record.connection = target.DescendantAdded:Connect(S.trackNpcMorphPart)
				for _, part in ipairs(target:GetDescendants()) do S.trackNpcMorphPart(part) end
			end
			record.model.Parent = Workspace
			count += 1
		else
			record.model.Parent = nil
		end
	end
	if S.npcMorphStatus then S.npcMorphStatus.Text = (batch.scope == "MrMix" and "All MrMix: " or "All NPCs: ") .. count .. " · Animation: " .. tostring(v11UniversalCurrentName or "not selected") end
end

createTabButton("NpcMorph", "NPCs / players", 368)
S.npcMorphPage = createPage("NpcMorph")
S.npcMorphSection = makeSection(S.npcMorphPage, "NPC / PLAYER MORPH", UDim2.fromOffset(24, 24), UDim2.new(0.42, -36, 1, -48))
S.npcMorphStatus = makeLabel(S.npcMorphSection, "Select a model and apply it to one or all NPCs", UDim2.new(1, -24, 0, 44), UDim2.fromOffset(12, 34), 12, COL.text, Enum.Font.Gotham)
S.npcMorphStatus.TextWrapped = true
S.npcMorphLibraryLabel = makeLabel(S.npcMorphSection, "", UDim2.new(1, -24, 0, 32), UDim2.fromOffset(12, 78), 12, COL.subtext, Enum.Font.Gotham)
S.npcMorphLibraryLabel.TextWrapped = true
S.npcMorphRefresh = makeButton(S.npcMorphSection, "Refresh NPCs", UDim2.new(0.5, -18, 0, 34), UDim2.fromOffset(12, 116), COL.button)
S.npcMorphChoose = makeButton(S.npcMorphSection, "Select model", UDim2.new(0.5, -18, 0, 34), UDim2.new(0.5, 6, 0, 116), COL.button)
S.multiMorphs = {}
function S.removeStoredMorph(target)
    local record = S.multiMorphs[target]
    if not record then return end
    S.multiMorphs[target] = nil
    if record.added then record.added:Disconnect() end
    for part, value in pairs(record.hidden) do
        pcall(function() part.LocalTransparencyModifier = value end)
    end
    record.model:Destroy()
end
function S.clearStoredMorphs()
    local targets = {}
    for target in pairs(S.multiMorphs) do table.insert(targets, target) end
    for _, target in ipairs(targets) do S.removeStoredMorph(target) end
end
function S.storeCurrentMorph()
    local target = S.npcMorphTarget
    local root = target and getSpectateRoot(target)
    if not target or not root or not morphModel or S.npcMorphBatch then return true end
    local previous = S.npcMorphBatch
    S.npcMorphBatch = {records = {}}
    local ok, record = pcall(S.createNpcBatchCopy, target)
    S.npcMorphBatch = previous
    if not ok or not record then return false end
    S.removeStoredMorph(target)
    record.owner = Players:GetPlayerFromCharacter(target)
    record.name = morphActiveName
    record.offset = root.CFrame:ToObjectSpace(morphModel:GetPivot())
    record.hidden = {}
    record.targets = {}
    local mapping = {}
    for _, group in ipairs({record.bones, record.motors}) do
        for _, pair in ipairs(group) do mapping[pair[1]] = pair[2] end
    end
    record.prepared = v11UniversalPrepared
    record.animationIds = {}
    for name, track in pairs(morphTracks or {}) do
        if track.Animation then record.animationIds[string.lower(name)] = track.Animation.AnimationId end
    end
    for _, clip in pairs(record.prepared or {}) do
        for _, channel in ipairs(clip.channels or {}) do record.targets[channel] = mapping[v11Target(channel)] end
    end
    record.clip = v11UniversalCurrentClip
    record.elapsed = record.clip and math.max(0, S.animationClock()-v11UniversalStartedAt) or 0
    record.speed = S.animationPlaybackSpeed
    record.loop = record.clip and (record.clip.loop or v143ShouldManualLoopLibraryClip(record.clip.name))
    if v11UniversalManualMode and v147UniversalManualLoopOverride ~= nil then record.loop = v147UniversalManualLoopOverride end
    if record.clip then
        for _, channel in ipairs(record.clip.channels or {}) do record.targets[channel] = mapping[v11Target(channel)] end
    end
    record.model:PivotTo(morphModel:GetPivot())
    record.model.Parent = Workspace
    record.native = false
    if morphAnimator and record.animator then
        for _, sourceTrack in ipairs(morphAnimator:GetPlayingAnimationTracks()) do
            local animation = sourceTrack.Animation
            if animation then
                local loaded, track = pcall(function() return record.animator:LoadAnimation(animation) end)
                if loaded then
                    track.Priority = sourceTrack.Priority
                    track.Looped = sourceTrack.Looped
                    track:Play(0, 1, sourceTrack.Speed)
                    track.TimePosition = sourceTrack.TimePosition
                    record.native = true
                end
            end
        end
    end
    local function trackPart(part)
        if not part:IsA("BasePart") or record.hidden[part] ~= nil then return end
        local existing = S.npcMorphHidden[part]
        record.hidden[part] = existing and existing.value or part.LocalTransparencyModifier
    end
    for _, part in ipairs(target:GetDescendants()) do trackPart(part) end
    record.added = target.DescendantAdded:Connect(trackPart)
    record.model:PivotTo(morphModel:GetPivot())
    record.model.Parent = Workspace
    record.parts, record.bones, record.motors, record.meshes = nil, nil, nil, nil
    S.multiMorphs[target] = record
    return true
end
ugKeepRootConnection(RunService.PreSimulation:Connect(function(dt)
    for target, record in pairs(S.multiMorphs) do
        local root = target:IsDescendantOf(Workspace) and getSpectateRoot(target)
        local humanoid = target:FindFirstChildWhichIsA("Humanoid")
        if not root or (record.owner and (record.owner.Parent ~= Players or record.owner.Character ~= target or (humanoid and humanoid.Health <= 0))) then
            S.removeStoredMorph(target)
        else
            record.model:PivotTo(root.CFrame * record.offset)
            for part, value in pairs(record.hidden) do
                if part.Parent then part.LocalTransparencyModifier = S.npcMorphShowOriginals and value or 1 end
            end
            S.stepStoredAnimation(record,dt)
        end
    end
end))
S.npcMorphApply = makeButton(S.npcMorphSection, "Apply to selected", UDim2.new(0.5, -18, 0, 34), UDim2.fromOffset(12, 158), COL.button)
S.npcMorphRestore = makeButton(S.npcMorphSection, "Remove selected", UDim2.new(0.5, -18, 0, 34), UDim2.new(0.5, 6, 0, 158), COL.button)
S.npcMorphAll = makeButton(S.npcMorphSection, "ALL NPCs + AUTO-ADD", UDim2.new(1, -24, 0, 34), UDim2.fromOffset(12, 200), COL.button)
S.npcMorphAll.TextSize = 11
S.npcMorphMrMix = makeButton(S.npcMorphSection, "ALL MRMIX + AUTO-ADD", UDim2.new(1, -24, 0, 34), UDim2.fromOffset(12, 242), COL.button)
S.npcMorphMrMix.TextSize = 10
S.npcMorphOriginals = makeButton(S.npcMorphSection, "Originals: hidden", UDim2.new(1, -24, 0, 34), UDim2.fromOffset(12, 284), COL.button)
S.npcMorphOriginals.TextSize = 11
S.connectAction(S.npcMorphOriginals,function()
	S.npcMorphShowOriginals = not S.npcMorphShowOriginals
	S.restoreNpcMorphVisibility()
	if S.npcMorphBatch then
		for _, record in pairs(S.npcMorphBatch.records) do
			if record.connection then record.connection:Disconnect(); record.connection = nil end
		end
	end
	S.npcMorphOriginals.Text = S.npcMorphShowOriginals and "Originals: visible (test)" or "Originals: hidden"
end)
S.npcMorphScroll = Instance.new("ScrollingFrame")
S.npcMorphScroll.BackgroundTransparency = 1
S.npcMorphScroll.BorderSizePixel = 0
S.npcMorphScroll.Position = UDim2.fromOffset(12, 410)
S.npcMorphScroll.Size = UDim2.new(1, -24, 1, -452)
S.npcMorphScroll.ScrollBarThickness = 4
S.npcMorphScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
S.npcMorphScroll.CanvasSize = UDim2.new()
S.npcMorphScroll.Parent = S.npcMorphSection
S.npcMorphLayout = Instance.new("UIListLayout")
S.npcMorphLayout.Padding = UDim.new(0, 8)
S.npcMorphLayout.SortOrder = Enum.SortOrder.LayoutOrder
S.npcMorphLayout.Parent = S.npcMorphScroll
S.npcMorphNote = makeLabel(S.npcMorphSection, "Scroll down for position, scale, animations and binds.", UDim2.new(1, -24, 0, 32), UDim2.new(0, 12, 1, -38), 11, COL.subtext, Enum.Font.Gotham)
S.npcMorphNote.TextWrapped = true

function S.refreshNpcMorphList(forceScan)
	S.npcMorphLibraryLabel.Text = "Model: " .. tostring(selectedMorphName or "not selected")
	if not S.npcMorphShowLibrary and not S.playerMorphMode and ((forceScan == true and not S.economyMode) or not S.cameraNpcEntries) then ugScanCameraNpcs(true) end
	local query = string.lower(S.npcTargetSearch and S.npcTargetSearch.Text or "")
	local function matches(text)
		return query == "" or string.find(string.lower(text), query, 1, true) ~= nil
	end
	for _, child in ipairs(S.npcMorphScroll:GetChildren()) do
		if child:IsA("GuiObject") then
			S.npcCards[child] = nil
			child:Destroy()
		end
	end
	if S.npcMorphShowLibrary then
		local names = collectMorphNames()
		table.sort(names, function(a,b)
			local aLoaded = universalLibraryMorphs[a] ~= nil or customMorphSources[a] ~= nil
			local bLoaded = universalLibraryMorphs[b] ~= nil or customMorphSources[b] ~= nil
			if aLoaded ~= bLoaded then return aLoaded end
			return string.lower(a) < string.lower(b)
		end)
		local shown=0
		for index, name in ipairs(names) do
            if S.economyMode and shown>=80 then break end
			if not matches((S.localModelLabels and S.localModelLabels[name]) or name) then continue end
			shown+=1
			local button = makeButton(S.npcMorphScroll, name, UDim2.new(1, -6, 0, 44), UDim2.new(), COL.button)
			button.LayoutOrder = index
			button.TextWrapped = true
			S.connectAction(button,function()
				selectMorph(name)
				selectAnimationNpc(name)
				S.npcMorphShowLibrary = false
				S.refreshNpcMorphList()
			end)
		end
		if #names == 0 then S.npcMorphStatus.Text = "Load a library in Custom Morph first" end
		return
	end
	if S.playerMorphMode then
		for index, targetPlayer in ipairs(Players:GetPlayers()) do
			if not matches(targetPlayer.DisplayName .. " " .. targetPlayer.Name) then continue end
			local button = makeButton(S.npcMorphScroll, targetPlayer.DisplayName .. " (@" .. targetPlayer.Name .. ")", UDim2.new(1,-6,0,44), UDim2.new(), COL.button)
			button.LayoutOrder = index
			S.makeNpcCard(button, targetPlayer.DisplayName .. " (@" .. targetPlayer.Name .. ")", "PLAYER", function() return targetPlayer.Character end)
            button:SetAttribute("Selected", S.playerMorphSelection == targetPlayer)
			button.BackgroundColor3 = S.playerMorphSelection == targetPlayer and COL.buttonSelected or COL.button
			S.connectAction(button,function()
				S.playerMorphSelection = targetPlayer
				S.npcMorphStatus.Text = "Player: " .. targetPlayer.DisplayName
				S.refreshNpcMorphList()
			end)
		end
		return
	end
	local count = 0
	for _, entry in ipairs(S.cameraNpcEntries or {}) do
        if S.economyMode and count>=80 then break end
		local target = entry.model
		if target and target:IsDescendantOf(Workspace) and not ugIsPlayerCharacterModel(target) and matches(entry.displayName) then
			count += 1
			local button = makeButton(S.npcMorphScroll, "", UDim2.new(1, -6, 0, 104), UDim2.new(), COL.button)
			button.LayoutOrder = count
			S.makeNpcCard(button, entry.displayName, "MORPH TARGET", target)
			button:SetAttribute("Selected", S.npcMorphSelection == target)
			S.connectAction(button,function()
				S.npcMorphSelection = target
                S.audioNpcSelection = target
				for _, other in ipairs(S.npcMorphScroll:GetChildren()) do
					if other:IsA("TextButton") then
						other:SetAttribute("Selected", other == button)
						other.BackgroundColor3 = other == button and COL.buttonSelected or COL.button
					end
				end
				S.npcMorphStatus.Text = "Selected NPC: " .. entry.displayName
			end)
		end
	end
	if count == 0 then
		makeLabel(S.npcMorphScroll, "No NPCs found", UDim2.new(1, -8, 0, 34), UDim2.new(), 12, COL.subtext, Enum.Font.Gotham)
	end
end

S.playerMorphModeButton = makeButton(S.npcMorphSection, "Targets: NPCs", UDim2.new(0.5,-18,0,32), UDim2.fromOffset(12,326), COL.button)
S.playerMorphWatch = makeButton(S.npcMorphSection, "Spectate", UDim2.new(0.5,-18,0,32), UDim2.new(0.5,6,0,326), COL.button)
S.connectAction(S.playerMorphModeButton,function()
	if S.npcTargetSearch then S.npcTargetSearch.Text = "" end
	S.playerMorphMode = not S.playerMorphMode
	S.playerMorphModeButton.Text = S.playerMorphMode and "Targets: players" or "Targets: NPCs"
	S.npcMorphShowLibrary = false
	S.refreshNpcMorphList(true)
end)
S.connectAction(S.playerMorphWatch,function()
	local target = S.playerMorphMode and S.playerMorphSelection and S.playerMorphSelection.Character or (not S.playerMorphMode and S.npcMorphSelection)
	if target and getSpectateRoot(target) then ugSpectateEntry({model=target, displayName=target.Name}) end
end)
S.connectAction(S.npcMorphRefresh,function() S.refreshNpcMorphList(true) end)
S.connectAction(S.npcMorphChoose,function()
	if S.npcTargetSearch then S.npcTargetSearch.Text = "" end
	S.npcMorphShowLibrary = not S.npcMorphShowLibrary
	S.refreshNpcMorphList()
end)
S.connectAction(S.npcMorphRestore,function()
    local target = S.playerMorphMode and S.playerMorphSelection and S.playerMorphSelection.Character or (not S.playerMorphMode and S.npcMorphSelection)
    if not target then return end
    S.removeStoredMorph(target)
    if S.npcMorphTarget == target then removeMorph(false) end
    S.npcMorphStatus.Text = "Selected target morph removed"
end)
S.connectAction(S.npcMorphApply,function()
	local target = S.playerMorphMode and S.playerMorphSelection and S.playerMorphSelection.Character or (not S.playerMorphMode and S.npcMorphSelection)
	local name = selectedMorphName
	if not name or (not universalLibraryMorphs[name] and not findMorphSourceModel(name)) then
		S.npcMorphStatus.Text = "Choose a model with Select model"
		return
	end
	if not target or not target:IsDescendantOf(Workspace) or not getSpectateRoot(target) then
		S.npcMorphStatus.Text = "Target is missing — select it again"
		return
	end
    if S.npcMorphTarget ~= target and not S.storeCurrentMorph() then
        S.npcMorphStatus.Text = "Failed to save previous morph"
        return
    end
    removeMorph(false)
    S.npcMorphPending = target
	local ok, result = pcall(function()
		if universalLibraryMorphs[name] then return v11ApplyLibraryMorph(name) end
		applyMorph(name)
		return morphModel ~= nil and morphActiveName == name
	end)
	S.npcMorphPending = nil
	if not ok or not result then
		removeMorph(false)
		S.npcMorphStatus.Text = "Failed to build morph: " .. tostring(result)
		return
	end
	S.removeStoredMorph(target)
	selectAnimationNpc(name)
	S.npcMorphStatus.Text = target.Name .. " → " .. name .. " · PLAY and binds on the right"
end)

S.npcMorphTools = Instance.new("ScrollingFrame")
S.npcMorphTools.BackgroundTransparency = 1
S.npcMorphTools.BorderSizePixel = 0
S.npcMorphTools.Position = UDim2.new(0.42, 0, 0, 24)
S.npcMorphTools.Size = UDim2.new(0.58, -24, 1, -48)
S.npcMorphTools.CanvasSize = UDim2.fromOffset(0, 1290)
S.npcMorphTools.ScrollBarThickness = 5
S.npcMorphTools.Parent = S.npcMorphPage
S.npcGroundButton = makeButton(v11TransformScroll, "Auto floor Y: OFF", UDim2.new(1, -4, 0, 34), UDim2.fromOffset(2, 534), COL.button)
S.npcGroundNote = makeLabel(v11TransformScroll, "Auto-Y works for one or all NPCs. Position Y adds a floor offset. Without a floor, the usual position is kept.", UDim2.new(1, -8, 0, 66), UDim2.fromOffset(2, 576), 11, COL.subtext, Enum.Font.Gotham)
S.npcGroundNote.TextWrapped = true
v11TransformScroll.CanvasSize = UDim2.fromOffset(0, 650)
S.connectAction(S.npcGroundButton,function()
	S.npcGroundEnabled = not S.npcGroundEnabled
	S.npcGroundSingle = {}
	if S.npcMorphBatch then
		for _, record in pairs(S.npcMorphBatch.records) do record.ground = {} end
	end
	S.npcGroundButton.Text = S.npcGroundEnabled and "Auto floor Y: ON" or "Auto floor Y: OFF"
end)
S.npcMorphToolsHome = {
	{object = v11TransformScroll, parent = v11TransformScroll.Parent, position = v11TransformScroll.Position, size = v11TransformScroll.Size},
	{object = animationDetailsSection, parent = animationDetailsSection.Parent, position = animationDetailsSection.Position, size = animationDetailsSection.Size},
}

function S.layoutNpcMorphTools(name)
	if name == "NpcMorph" then
		v11TransformScroll.Parent = S.npcMorphTools
		v11TransformScroll.Position = UDim2.fromOffset(6, 0)
		v11TransformScroll.Size = UDim2.new(1, -18, 0, 655)
		animationDetailsSection.Parent = S.npcMorphTools
		animationDetailsSection.Position = UDim2.fromOffset(6, 665)
		animationDetailsSection.Size = UDim2.new(1, -18, 0, 610)
		if selectedMorphName then
			selectAnimationNpc(selectedMorphName)
			v11RefreshTransformSliders()
		end
	else
		for _, item in ipairs(S.npcMorphToolsHome) do
			item.object.Parent = item.parent
			item.object.Position = item.position
			item.object.Size = item.size
		end
		if name == "Animations" then rebuildAnimationRows() end
	end
end

function S.applyNpcMorphGroup(scope)
	local name = selectedMorphName
	if not name or not universalLibraryMorphs[name] then
		S.npcMorphStatus.Text = "Select an imported model with Model [LIB]"
		return
	end
	S.npcMorphBatchPending = {records = {}, connections = {}, scope = scope}
	local ok, result = pcall(v11ApplyLibraryMorph, name)
	S.npcMorphBatchPending = nil
	if not ok or not result then
		removeMorph(false)
		S.npcMorphStatus.Text = "Failed to apply: " .. tostring(result)
	end
end
S.connectAction(S.npcMorphAll,function() S.applyNpcMorphGroup("All") end)
S.connectAction(S.npcMorphMrMix,function() S.applyNpcMorphGroup("MrMix") end)

S.spectatePositionOffset = Vector3.zero
S.cameraOffsetBlocker = Instance.new("TextButton")
S.cameraOffsetBlocker.Size = UDim2.fromScale(1,1)
S.cameraOffsetBlocker.BackgroundTransparency = 1
S.cameraOffsetBlocker.Text = ""
S.cameraOffsetBlocker.AutoButtonColor = false
S.cameraOffsetBlocker.Active = true
S.cameraOffsetBlocker.Visible = false
S.cameraOffsetBlocker.ZIndex = 79
S.cameraOffsetBlocker.Parent = cameraPage
S.cameraOffsetPopup = Instance.new("Frame")
S.cameraOffsetPopup.Active = true
S.cameraOffsetPopup.Size = UDim2.fromOffset(310, 192)
S.cameraOffsetPopup.Position = UDim2.new(1,-326,0,78)
S.cameraOffsetPopup.BackgroundColor3 = COL.panel
S.cameraOffsetPopup.Visible = false
S.cameraOffsetPopup.ZIndex = 80
S.cameraOffsetPopup.Parent = cameraPage
S.cameraOffsetToggle = makeButton(cameraPage, "Camera center X / Y", UDim2.fromOffset(170,30), UDim2.new(1,-194,0,24), COL.button)
S.cameraOffsetToggle.ZIndex = 82
function S.setCameraOffsetPopup(visible)
    S.cameraOffsetPopup.Visible = visible
    S.cameraOffsetBlocker.Visible = visible
    if not visible then S.activeSliderSetFromX = nil end
end
S.connectAction(S.cameraOffsetToggle,function() S.setCameraOffsetPopup(not S.cameraOffsetPopup.Visible) end)
S.connectAction(S.cameraOffsetBlocker,function() S.setCameraOffsetPopup(false) end)
S.cameraOffsetSliders = {}
for index, axis in ipairs({"X", "Y"}) do
	S.cameraOffsetSliders[index] = createSlider(S.cameraOffsetPopup, "Camera " .. axis, -30, 30, 0.1, 0, 14+(index-1)*64, function(value)
		local v = S.spectatePositionOffset
		S.spectatePositionOffset = Vector3.new(index == 1 and value or v.X, index == 2 and value or v.Y, 0)
	end)
end
S.cameraOffsetReset = makeButton(S.cameraOffsetPopup, "Reset · character center", UDim2.new(1,-24,0,30), UDim2.fromOffset(12,148), COL.button)
S.connectAction(S.cameraOffsetReset,function()
	for _, slider in ipairs(S.cameraOffsetSliders) do slider.SetValue(0,true) end
end)
for _, object in ipairs(S.cameraOffsetPopup:GetDescendants()) do
	if object:IsA("GuiObject") then object.ZIndex = 81 end
end
S.rootConnections[#S.rootConnections + 1] = RunService.Heartbeat:Connect(function()
	if S.unloading or S.removingMorph or S.npcMorphBatch then return end
	local target = S.npcMorphTarget
	if not target then return end
	local humanoid = target:FindFirstChildOfClass("Humanoid")
	if not target:IsDescendantOf(Workspace) or (Players:GetPlayerFromCharacter(target) and humanoid and humanoid.Health <= 0) then
		removeMorph(false)
		if S.npcMorphStatus then S.npcMorphStatus.Text = "Target died or disappeared — morph removed" end
	end
end)
S.killVisualRecords = {}
S.killVisualNextScan = 0
S.killVisualNames = {
	dus = "dusjumpscare", gus = "gusjumpscare", kus = "kusjumpscare",
	lost = "lostjumpscare", ashy = "ashyjumpscare", lurker = "lurkerkill",
	sandman = "sandmanjumpscare", scar = "scarjumpscare", bloodman = "bloodmankill",
}
function S.releaseKillVisual(model)
	local record = S.killVisualRecords[model]
	if not record then return end
	S.killVisualRecords[model] = nil
	if record.added then record.added:Disconnect() end
	for part, state in pairs(record.parts) do
		state.connection:Disconnect()
		pcall(function() part.LocalTransparencyModifier = state.original end)
	end
end
function S.restoreKillVisuals()
	local models = {}
	for model in pairs(S.killVisualRecords) do table.insert(models,model) end
	for _, model in ipairs(models) do S.releaseKillVisual(model) end
	S.killVisualNextScan = 0
	S.killVisualKey = nil
end
function S.trackKillVisual(model)
	if S.killVisualRecords[model] then return end
	local record = {parts={}}
	S.killVisualRecords[model] = record
	local function add(part)
		if not part:IsA("BasePart") or record.parts[part] then return end
		local state = {original=part.LocalTransparencyModifier, writing=false, writes=0}
		record.parts[part] = state
		state.enforce = function()
			if S.unloading or S.killVisualRecords[model] ~= record or state.writing or state.writes >= 2 then return end
			if part.Parent and part.LocalTransparencyModifier ~= 1 then
				state.writing = true
				state.writes += 1
				part.LocalTransparencyModifier = 1
				state.writing = false
			end
		end
		state.connection = part:GetPropertyChangedSignal("LocalTransparencyModifier"):Connect(state.enforce)
		state.enforce()
	end
	record.added = model.DescendantAdded:Connect(add)
	for _, part in ipairs(model:GetDescendants()) do add(part) end
end
function S.updateKillVisuals()
	if S.unloading then return end
	local wanted = {}
	local function include(target)
		if not target or not target:IsDescendantOf(Workspace) or ugIsPlayerCharacterModel(target) then return end
		local name = S.killVisualNames[string.lower(target.Name)]
		if name then wanted[name] = true end
	end
	if morphModel and morphModel.Parent and not S.npcMorphShowOriginals then
		if S.npcMorphBatch then
			for target in pairs(S.npcMorphBatch.records) do include(target) end
		else
			include(S.npcMorphTarget)
		end
	end
	if not S.npcMorphShowOriginals then
		for target in pairs(S.multiMorphs or {}) do include(target) end
	end
	local keys = {}
	for name in pairs(wanted) do table.insert(keys,name) end
	table.sort(keys)
	local key = table.concat(keys,"|")
	local folder = Workspace:FindFirstChild("Jumpscares")
	local remove = {}
	for model in pairs(S.killVisualRecords) do
		if not folder or not model:IsDescendantOf(folder) or not wanted[string.lower(model.Name)] then table.insert(remove,model) end
	end
	for _, model in ipairs(remove) do S.releaseKillVisual(model) end
	if key ~= S.killVisualKey or os.clock() >= S.killVisualNextScan then
		S.killVisualKey = key
		S.killVisualNextScan = os.clock()+0.15
		if folder and next(wanted) then
			for _, model in ipairs(folder:GetDescendants()) do
				if model:IsA("Model") and wanted[string.lower(model.Name)] then S.trackKillVisual(model) end
			end
		end
	end
	for _, record in pairs(S.killVisualRecords) do
		for part, state in pairs(record.parts) do
			if part.Parent then state.writes=0; state.enforce() end
		end
	end
end
S.KILL_VISUAL_BIND = "LuminKillVisualHide"
RunService:UnbindFromRenderStep(S.KILL_VISUAL_BIND)
RunService:BindToRenderStep(S.KILL_VISUAL_BIND, Enum.RenderPriority.Last.Value+300, S.updateKillVisuals)
S.soundRules = {}
S.soundMuted = {}
S.soundRows = {}
S.soundScanAt = 0
function S.soundId(sound)
	local raw = tostring((sound:IsA("AudioPlayer") and sound.Asset or sound.SoundId) or "")
	return raw:match("%d+") or raw
end
S.soundRuleTargets = {}
S.gameSoundRules = {}
S.deadSoundOwners = {}
S.gameSoundCache = setmetatable({},{__mode="k"})
S.soundMode = "npc"
S.gameSoundFilter = "all"
function S.isGameSound(sound)
    if not (sound:IsA("Sound") or sound:IsA("AudioPlayer")) or sound.Name=="__LUMIN_CUSTOM_AUDIO" or sound.Name=="__LUMIN_REPLAY_AUDIO" then return false end
    local node=sound.Parent
    while node and node~=game do
        if node==Workspace or node==game:GetService("SoundService") or node==player then return true end
        if node==Workspace:FindFirstChild("Jumpscares") then return false end
        if node:IsA("Model") and (node:FindFirstChildOfClass("Humanoid") or ugIsPlayerCharacterModel(node)) then return node==player.Character end
        node=node.Parent
    end
    return false
end
function S.indexGameSounds()
    for _,root in ipairs({Workspace,game:GetService("SoundService"),player}) do
        for _,object in ipairs(root:GetDescendants()) do if (object:IsA("Sound") or object:IsA("AudioPlayer")) then S.gameSoundCache[object]=true end end
    end
end
function S.soundRelease(sound)
    local record=S.soundMuted[sound]
    if not record then return end
    S.soundMuted[sound]=nil
    record.destroyed:Disconnect()
    pcall(function()
        if sound:IsA("Sound") and sound.SoundGroup==S.npcMuteGroup then sound.SoundGroup=record.group end
        if sound.Volume==0 then sound.Volume=record.volume end
    end)
end
function S.soundMute(sound)
    if not S.npcMuteGroup then
        local group=Instance.new("SoundGroup")
        group.Name="__LUMIN_NPC_MUTE"
        group.Volume=0
        group.Parent=game:GetService("SoundService")
        S.npcMuteGroup=group
    end
    local record=S.soundMuted[sound]
    if not record then
        record={group=sound:IsA("Sound") and sound.SoundGroup or nil,volume=sound.Volume}
        S.soundMuted[sound]=record
        record.destroyed=sound.Destroying:Connect(function()
            S.soundMuted[sound]=nil
            record.destroyed:Disconnect()
        end)
    end
    if sound:IsA("Sound") and sound.SoundGroup~=S.npcMuteGroup then
        record.group=sound.SoundGroup
        sound.SoundGroup=S.npcMuteGroup
    end
    if sound.Volume~=0 then record.volume=sound.Volume;sound.Volume=0 end
end
S.soundEnforceAt=0
function S.enforceMutedVolumes()
    if S.npcMuteGroup and S.npcMuteGroup.Volume~=0 then S.npcMuteGroup.Volume=0 end
    for sound,record in pairs(S.soundMuted) do
        if sound.Parent and sound.Volume~=0 then
            record.volume=sound.Volume
            sound.Volume=0
        end
    end
end
function S.soundSources(target)
	local result = {target}
	local related = S.killVisualNames[string.lower(target.Name)]
	local folder = Workspace:FindFirstChild("Jumpscares")
	if related and folder then
		for _, object in ipairs(folder:GetDescendants()) do
			if object:IsA("Model") and object.Name:lower() == related then table.insert(result,object) end
		end
	end
	return result
end
function S.enforceSoundRules()
	local wanted = {}
    local models = {}
    for scope in pairs(S.soundRules) do
        local model=S.soundRuleTargets[scope]
        if model and model:IsDescendantOf(Workspace) and model:GetFullName()==scope then
            table.insert(models,model)
        else
            S.soundRuleTargets[scope]=nil
            local cursor=Workspace
            for segment in scope:gmatch("[^.]+") do
                if segment~="Workspace" then cursor=cursor and cursor:FindFirstChild(segment) end
            end
            if cursor and cursor:IsA("Model") and cursor~=Workspace and cursor:GetFullName()==scope then
                S.soundRuleTargets[scope]=cursor
                table.insert(models,cursor)
            end
        end
    end
	for _, model in ipairs(models) do
		local rules = S.soundRules[model:GetFullName()]
		for _, source in ipairs(S.soundSources(model)) do
			for _, object in ipairs(source:GetDescendants()) do
				if (object:IsA("Sound") or object:IsA("AudioPlayer")) and object.Name~="__LUMIN_CUSTOM_AUDIO" and object.Name~="__LUMIN_REPLAY_AUDIO" and rules[S.soundId(object)]~=false and (rules["*"] or rules[S.soundId(object)]) then wanted[object] = true end
			end
		end
	end
    if next(S.gameSoundRules) then
        for sound in pairs(S.gameSoundCache) do
            if S.isGameSound(sound) and S.gameSoundRules[S.soundId(sound)]~=false and (S.gameSoundRules["*"] or S.gameSoundRules[S.soundId(sound)]) then wanted[sound]=true end
        end
    end
	for sound,owner in pairs(S.deadSoundOwners) do if sound.Parent and owner then wanted[sound]=true end end
	local release = {}
	for sound in pairs(S.soundMuted) do if not wanted[sound] then table.insert(release,sound) end end
	for _, sound in ipairs(release) do S.soundRelease(sound) end
	for sound in pairs(wanted) do S.soundMute(sound) end
end
function S.restoreAllSounds()
    S.gameSoundRules={}
	S.soundRules = {}
    S.soundRuleTargets = {}
	local release = {}
	for sound in pairs(S.soundMuted) do table.insert(release,sound) end
	for _, sound in ipairs(release) do S.soundRelease(sound) end
    if S.npcMuteGroup then S.npcMuteGroup:Destroy(); S.npcMuteGroup=nil end
end
createTabButton("Sounds", "Sounds", 414)
S.soundPage = createPage("Sounds")
S.soundLeft = makeSection(S.soundPage, "SOUND SOURCE", UDim2.fromOffset(18,20), UDim2.new(0.36,-24,1,-40))
S.soundRight = makeSection(S.soundPage, "SOUNDS AND MUSIC", UDim2.new(0.36,0,0,20), UDim2.new(0.64,-18,1,-40))
S.soundHint = makeLabel(S.soundRight, "Select an NPC. SoundId rules affect only it and its kill animation model.", UDim2.new(1,-24,0,58), UDim2.fromOffset(12,36), 11, COL.subtext, Enum.Font.Gotham)
S.soundHint.TextWrapped = true
S.soundRefresh = makeButton(S.soundLeft, "Refresh list", UDim2.new(1,-24,0,30), UDim2.fromOffset(12,78), COL.button)
S.soundNpcMode=makeButton(S.soundLeft,"NPC",UDim2.new(0.5,-16,0,30),UDim2.fromOffset(12,38),COL.buttonSelected)
S.soundGameMode=makeButton(S.soundLeft,"Game",UDim2.new(0.5,-16,0,30),UDim2.new(0.5,4,0,38),COL.button)
S.soundMuteAll=makeButton(S.soundRight,"Mute all (NPC)",UDim2.new(0.5,-16,0,30),UDim2.fromOffset(12,100),COL.button)
S.soundReset = makeButton(S.soundRight, "Restore all sounds", UDim2.new(0.5,-16,0,30), UDim2.new(0.5,4,0,100), COL.button)
for _, spec in ipairs({{key="soundTargets", parent=S.soundLeft, y=118},{key="soundList", parent=S.soundRight, y=140}}) do
	local scroll = Instance.new("ScrollingFrame")
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.Position = UDim2.fromOffset(12,spec.y)
	scroll.Size = UDim2.new(1,-24,1,-spec.y-12)
	scroll.CanvasSize = UDim2.new()
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.ScrollBarThickness = 4
	scroll.Parent = spec.parent
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0,6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = scroll
	S[spec.key] = scroll
end
function S.refreshSoundRows()
	for _, child in ipairs(S.soundList:GetChildren()) do if child:IsA("GuiObject") then child:Destroy() end end
	S.soundRows = {}
	local target = S.soundSelected
	if S.soundMode=="npc" and (not target or not target:IsDescendantOf(Workspace)) then
		S.soundHint.Text = "Target disappeared. Refresh the list. Saved rules will apply when it returns."
		return
	end
    local isGame=S.soundMode=="game"
	local scope = not isGame and target:GetFullName() or "Game audio"
	S.soundHint.Text = isGame and "Game music / ambience. NPCs and custom MP3s are excluded. IDs are grouped." or scope .. " · includes the related kill model. Matching IDs are grouped."
	local groups, ids = {}, {}
    local objects={}
    if isGame then
        for sound in pairs(S.gameSoundCache) do
            if S.isGameSound(sound) and (S.gameSoundFilter=="all" or S.gameSoundFilter=="playing" and sound.IsPlaying or S.gameSoundFilter=="looped" and sound.Looped) then table.insert(objects,sound) end
        end
    else
        for _,source in ipairs(S.soundSources(target)) do for _,object in ipairs(source:GetDescendants()) do table.insert(objects,object) end end
    end
		for _, object in ipairs(objects) do
			if (object:IsA("Sound") or object:IsA("AudioPlayer")) and object.Name~="__LUMIN_CUSTOM_AUDIO" and object.Name~="__LUMIN_REPLAY_AUDIO" then
				local id = S.soundId(object)
				if id ~= "" then
					if not groups[id] then groups[id]={}; table.insert(ids,id) end
					table.insert(groups[id],object)
				end
			end
		end
	table.sort(ids)
	for index, id in ipairs(ids) do
		local sounds = groups[id]
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1,-5,0,112)
		row.BackgroundColor3 = COL.panel
		row.LayoutOrder = index
		row.Parent = S.soundList
		local info = makeLabel(row, "", UDim2.new(1,-16,0,70), UDim2.fromOffset(8,4), 10, COL.text, Enum.Font.Gotham)
		info.TextWrapped = true
		local button = makeButton(row, "", UDim2.new(1,-16,0,28), UDim2.fromOffset(8,78), COL.button)
		local function update()
			local playing, looped = false, false
			for _, sound in ipairs(sounds) do if sound.Parent then playing = playing or sound.IsPlaying; looped = looped or sound.Looped end end
			local rules=isGame and S.gameSoundRules or S.soundRules[scope] or {}
            local muted = rules[id]~=false and (rules["*"] or rules[id])
			info.Text = sounds[1].Name .. " · ID " .. id .. "\n" .. (playing and "Playing" or "Not playing") .. (looped and " · Loop" or "") .. " · objects: " .. #sounds .. "\n" .. sounds[1]:GetFullName()
			button.Text = muted and "Restore sound" or "Mute"
			button.BackgroundColor3 = muted and COL.buttonSelected or COL.button
		end
		S.connectAction(button,function()
            local rules=isGame and S.gameSoundRules or S.soundRules[scope] or {}
            if rules["*"] then if rules[id]==false then rules[id]=nil else rules[id]=false end
            else rules[id]=not rules[id] and true or nil end
            if isGame then S.gameSoundRules=rules else
			    S.soundRules[scope] = next(rules) and rules or nil
                S.soundRuleTargets[scope] = next(rules) and target or nil
            end
			S.enforceSoundRules()
			update()
		end)
		S.soundRows[#S.soundRows+1] = update
		update()
	end
	if #ids == 0 then S.soundHint.Text = scope .. " · No Sound with a SoundId found. Refresh while the sound is playing." end
end
function S.refreshSoundTargets()
	ugScanCameraNpcs(not S.economyMode)
	for _, child in ipairs(S.soundTargets:GetChildren()) do if child:IsA("GuiObject") then child:Destroy() end end
    if S.soundMode=="game" then
        S.indexGameSounds()
        for index,kind in ipairs({"all","playing","looped"}) do
            local button=makeButton(S.soundTargets,kind=="all" and "All game sounds" or kind=="playing" and "Playing now" or "Looped / music candidates",UDim2.new(1,-5,0,40),UDim2.new(),COL.button)
            button.LayoutOrder=index;button.TextWrapped=true
            S.connectAction(button,function() S.gameSoundFilter=kind;S.refreshSoundRows() end)
        end
        S.refreshSoundRows()
        return
    end
	for index, entry in ipairs(S.cameraNpcEntries or {}) do
		local target = entry.model
		if target and target:IsDescendantOf(Workspace) and not ugIsPlayerCharacterModel(target) then
			local button = makeButton(S.soundTargets, entry.displayName or target.Name, UDim2.new(1,-5,0,40), UDim2.new(), COL.button)
			button.LayoutOrder = index
			button.TextWrapped = true
			S.connectAction(button,function() S.soundSelected=target; S.audioNpcSelection=target; S.refreshSoundRows() end)
		end
	end
	S.refreshSoundRows()
end
S.connectAction(S.soundRefresh,S.refreshSoundTargets)
S.connectAction(S.soundReset,function()
    if S.soundMode=="game" then S.gameSoundRules={} else S.soundRules={};S.soundRuleTargets={} end
    S.enforceSoundRules();S.refreshSoundRows()
end)
S.connectAction(S.soundMuteAll,function()
    if S.soundMode=="game" then S.indexGameSounds();S.gameSoundRules={["*"]=true}
    elseif S.soundSelected and S.soundSelected:IsDescendantOf(Workspace) then
        local scope=S.soundSelected:GetFullName()
        S.soundRules[scope]={["*"]=true};S.soundRuleTargets[scope]=S.soundSelected
    else S.soundHint.Text="Select an NPC first";return end
    S.enforceSoundRules();S.refreshSoundRows()
end)
S.connectAction(S.soundNpcMode,function()
    S.soundMode="npc";S.soundNpcMode.BackgroundColor3=COL.buttonSelected;S.soundGameMode.BackgroundColor3=COL.button;S.soundMuteAll.Text="Mute all (NPC)";S.refreshSoundTargets()
end)
S.connectAction(S.soundGameMode,function()
    S.soundMode="game";S.soundGameMode.BackgroundColor3=COL.buttonSelected;S.soundNpcMode.BackgroundColor3=COL.button;S.soundMuteAll.Text="Mute all (game)";S.refreshSoundTargets()
end)
S.rootConnections[#S.rootConnections+1]=game.DescendantAdded:Connect(function(object)
    if not S.unloading and (object:IsA("Sound") or object:IsA("AudioPlayer")) then
        S.gameSoundCache[object]=true
        if S.isGameSound(object) and S.gameSoundRules[S.soundId(object)]~=false and (S.gameSoundRules["*"] or S.gameSoundRules[S.soundId(object)]) then S.soundMute(object) end
    end
end)
S.rootConnections[#S.rootConnections+1] = RunService.Heartbeat:Connect(function()
	if S.unloading then return end
    if os.clock()>=S.soundEnforceAt then
        S.soundEnforceAt=os.clock()+0.1
        if next(S.soundMuted) then S.enforceMutedVolumes() end
    end
	if os.clock() >= S.soundScanAt then
		S.soundScanAt = os.clock()+0.5
		if next(S.soundRules) or next(S.soundMuted) or next(S.gameSoundRules) then S.enforceSoundRules() end
		if main.Visible and activeTab == "Sounds" then for _, update in ipairs(S.soundRows) do update() end end
	end
end)

S.rootConnections[#S.rootConnections+1] = Workspace.DescendantAdded:Connect(function(object)
    if S.unloading or not next(S.soundRules) or not object:IsA("Model") then return end
    local scope=object:GetFullName()
    if S.soundRules[scope] then S.soundRuleTargets[scope]=object end
end)
function S.makeSceneRagdoll(copy)
    local parts={}
    local motors={}
    for _,object in ipairs(copy:GetDescendants()) do
        if object:IsA("Animator") or object:IsA("AnimationController") or object:IsA("Humanoid") or object:IsA("BodyMover") or object:IsA("AlignPosition") or object:IsA("AlignOrientation") or object:IsA("LinearVelocity") or object:IsA("AngularVelocity") or object:IsA("VectorForce") then
            object:Destroy()
        elseif object:IsA("Motor6D") or object:IsA("AnimationConstraint") then
            table.insert(motors,object)
        elseif object:IsA("BasePart") then
            table.insert(parts,object)
            object.Massless=false
            object.CanTouch=false
            object.CanQuery=false
            object.CollisionGroup="Default"
            object.CanCollide=object.Transparency<0.95 and object.Name~="HumanoidRootPart" and object.Name~="RootPart" and not object:FindFirstAncestorOfClass("Accessory")
            object.CustomPhysicalProperties=PhysicalProperties.new(0.7,0.6,0,100,100)
        end
    end
    for _,motor in ipairs(motors) do
        local first,second=motor.Part0,motor.Part1
        if first and second and first:IsDescendantOf(copy) and second:IsDescendantOf(copy) then
            local frame=second.CFrame*motor.C1
            local a0=Instance.new("Attachment");a0.CFrame=first.CFrame:ToObjectSpace(frame);a0.Parent=first
            local a1=Instance.new("Attachment");a1.CFrame=second.CFrame:ToObjectSpace(frame);a1.Parent=second
            local socket=Instance.new("BallSocketConstraint")
            socket.Attachment0=a0;socket.Attachment1=a1;socket.LimitsEnabled=true;socket.UpperAngle=80
            socket.TwistLimitsEnabled=true;socket.TwistLowerAngle=-55;socket.TwistUpperAngle=55
            socket.MaxFrictionTorque=0;socket.Parent=first
            local collision=Instance.new("NoCollisionConstraint");collision.Part0=first;collision.Part1=second;collision.Parent=first
            motor:Destroy()
        end
    end
    for _,part in ipairs(parts) do
        part.Anchored=false
        part.AssemblyLinearVelocity=Vector3.zero
        part.AssemblyAngularVelocity=Vector3.zero
    end
    return parts,#motors
end
function S.restoreActorScene()
	local scene = S.actorScene
	S.actorScene = nil
	if not scene then return end
	for _, connection in ipairs(scene.connections) do connection:Disconnect() end
	for part, value in pairs(scene.hidden) do
		pcall(function() part.LocalTransparencyModifier = value end)
	end
	if scene.copy then scene.copy:Destroy() end
end
function S.startActorScene()
	local actor = S.playerMorphSelection
	local character = actor and actor.Character
	local root = character and getSpectateRoot(character)
	if not actor or actor.Parent ~= Players or not root or not character:IsDescendantOf(Workspace) then
		S.npcMorphStatus.Text = "Select a player for the staged scene"
		return
	end
	S.restoreActorScene()
	local source = (S.npcMorphTarget == character and morphModel) or (S.multiMorphs[character] and S.multiMorphs[character].model) or character
	local archivable = source.Archivable
	source.Archivable = true
	local ok, copy = pcall(function() return source:Clone() end)
	source.Archivable = archivable
	if not ok or not copy then S.npcMorphStatus.Text = "Failed to copy actor"; return end
	local built, scene = pcall(function()
		S.cleanDetachedVisualClone(copy)
		copy.Name = "__LOCAL_MORPH_ACTOR_SCENE"
		for _, object in ipairs(copy:GetDescendants()) do
			if object:IsA("LuaSourceContainer") or object:IsA("Humanoid") or object:IsA("AnimationController") or object:IsA("Animator") or object:IsA("Sound") or object:IsA("Tool") or object:IsA("ProximityPrompt") or object:IsA("ClickDetector") then
				object:Destroy()
			elseif object:IsA("BasePart") then
				object.Anchored = true
				object.CanCollide = false
				object.CanTouch = false
				object.CanQuery = false
				object.LocalTransparencyModifier = 0
			end
		end
		local start = source:GetPivot()
		copy:PivotTo(start)
        local parts = S.makeSceneRagdoll(copy)
        local origin = S.controlledCharacter() and getSpectateRoot(S.controlledCharacter())
        local delta = origin and root.Position-origin.Position or Vector3.zero
        local direction = Vector3.new(delta.X, 0, delta.Z)
        if direction.Magnitude < 0.1 then
            local camera = Workspace.CurrentCamera
            local forward = camera and camera.CFrame.LookVector or root.CFrame.LookVector
            direction = Vector3.new(forward.X, 0, forward.Z)
        end
        direction = direction.Magnitude > 0.1 and direction.Unit or Vector3.new(0,0,-1)
        return {actor=actor, character=character, source=source, copy=copy, parts=parts, direction=direction, hidden={}, connections={}}

	end)
	if not built then copy:Destroy(); S.npcMorphStatus.Text = "Scene error: " .. tostring(scene); return end
	S.actorScene = scene
	local function hide(object)
		if object:IsA("BasePart") and scene.hidden[object] == nil then
			scene.hidden[object] = object.LocalTransparencyModifier
            for _, part in ipairs(scene.parts) do
                local constraint = Instance.new("NoCollisionConstraint")
                constraint.Part0 = part
                constraint.Part1 = object
                constraint.Parent = part
            end
			object.LocalTransparencyModifier = 1
		end
	end
	for _, model in ipairs(source == character and {character} or {character,source}) do
		for _, object in ipairs(model:GetDescendants()) do hide(object) end
		table.insert(scene.connections, model.DescendantAdded:Connect(hide))
	end
    copy.Parent = Workspace
    for _, part in ipairs(scene.parts) do
        part.Anchored = false
        part.AssemblyLinearVelocity = Vector3.zero
        part.AssemblyAngularVelocity = Vector3.zero
    end
    task.defer(function()
        if S.actorScene ~= scene then return end
        local assemblies = {}
        local random = Random.new()
        for _, part in ipairs(scene.parts) do
            local assembly = part.AssemblyRootPart or part
            if not assemblies[assembly] then
                assemblies[assembly] = true
                local mass = assembly.AssemblyMass
                if mass > 0 and mass < math.huge then
                    assembly:ApplyImpulse((scene.direction*5 + Vector3.new(0,1,0))*mass)
                    assembly:ApplyAngularImpulse((Vector3.yAxis:Cross(scene.direction)*2 + Vector3.new(random:NextNumber(-2,2),random:NextNumber(-1,1),random:NextNumber(-2,2)))*mass)
                end
            end
        end
    end)
    task.delay(5,function() if S.actorScene==scene and scene.copy then scene.copy:Destroy();scene.copy=nil;scene.parts={} end end)
	S.npcMorphStatus.Text = "Staged death: " .. actor.DisplayName .. " · Restore actor cancels the scene"
end
S.actorDeathButton = makeButton(S.npcMorphSection, "Hit / fall", UDim2.new(0.5,-18,0,32), UDim2.fromOffset(12,368), COL.button)
S.actorRestoreButton = makeButton(S.npcMorphSection, "Restore actor", UDim2.new(0.5,-18,0,32), UDim2.new(0.5,6,0,368), COL.button)
S.actorDeathButton.TextSize = 10
S.actorRestoreButton.TextSize = 10
S.connectAction(S.actorDeathButton,S.startActorScene)
S.connectAction(S.actorRestoreButton,function()
	S.restoreActorScene()
	S.npcMorphStatus.Text = "Staged scene removed"
end)
S.ACTOR_SCENE_BIND = "LuminActorScene"
RunService:UnbindFromRenderStep(S.ACTOR_SCENE_BIND)
RunService:BindToRenderStep(S.ACTOR_SCENE_BIND, Enum.RenderPriority.Last.Value+400, function(dt)
	local scene = S.actorScene
	if not scene or S.unloading then return end
	if scene.actor.Parent ~= Players or scene.actor.Character ~= scene.character or not scene.character:IsDescendantOf(Workspace) or not scene.source:IsDescendantOf(Workspace) then
		S.restoreActorScene()
		return
	end
	for part in pairs(scene.hidden) do if part.Parent then part.LocalTransparencyModifier=1 end end
end)

S.multiRemoveAll = makeButton(S.npcMorphTools, "Remove all NPC and player morphs", UDim2.new(1,-24,0,34), UDim2.fromOffset(12,1294), COL.button)
S.npcMorphTools.CanvasSize = UDim2.fromOffset(0,1340)
S.connectAction(S.multiRemoveAll,function()
    S.clearStoredMorphs()
    if S.npcMorphTarget or S.npcMorphBatch then removeMorph(false) end
    S.npcMorphStatus.Text = "All target morphs removed"
end)
function S.stepStoredAnimation(record,dt)
    if record.returnClip and record.native and record.ownedTrack then
        record.returnElapsed=(record.returnElapsed or 0)+dt
        local track=record.ownedTrack
        if record.returnElapsed>0.15 and (not track.IsPlaying or (track.Length>0 and track.TimePosition>=track.Length-0.05)) then
            local idle=record.returnClip;record.returnClip=nil;record.returning=true
            S.playStoredAnimation(record,idle,"loop")
            record.returning=nil
        end
    end
    local clip = record.clip
    local transition=record.poseBlend
    if transition then transition.elapsed+=dt end
    if not clip and transition then
        local alpha=S.poseBlendAlpha(transition.elapsed)
        for object,pose in pairs(transition.from) do
            if object.Parent then object.Transform=S.scaleLibraryPose(pose:Lerp(CFrame.identity,alpha),record.model:GetScale()) end
        end
        if alpha>=1 then record.poseBlend=nil end
        return
    end
    if clip and not record.native and #(clip.frames or {}) > 0 then
        record.elapsed += dt*record.speed
        local t = record.loop and clip.duration > 0 and record.elapsed % clip.duration or math.min(record.elapsed, clip.duration)
        local frames = clip.frames
        local index = 1
        while index < #frames and frames[index+1].time <= t do index += 1 end
        local a, b = frames[index], frames[math.min(index+1,#frames)]
        local alpha = b.time > a.time and math.clamp((t-a.time)/(b.time-a.time),0,1) or 0
        for channel, object in pairs(record.targets) do
            if object.Parent then
                local first, second = a.poses[channel], b.poses[channel]
                local pose = first and second and first:Lerp(second, alpha) or first or second or CFrame.identity
                if transition then pose=(transition.from[object] or CFrame.identity):Lerp(pose,S.poseBlendAlpha(transition.elapsed)) end
                object.Transform = S.scaleLibraryPose(pose, record.model:GetScale())
            end
        end
        if transition and transition.elapsed>=0.35 then record.poseBlend=nil end
        if not record.loop and record.elapsed>=math.max(clip.duration,clip.duration<=0 and 0.4 or 0.05)+0.06 then
            if record.returnClip then
                local idle=record.returnClip;record.returnClip=nil
                S.playStoredAnimation(record,idle,"loop")
            elseif not record.holdFinalPose then S.stopStoredAnimation(record) end
        end
    end
end
function S.stopStoredAnimation(record)
    if record.ownedTrack then
        local old=record.ownedTrack;old:Stop(record.returning and 0.35 or 0)
        if record.returning then task.delay(0.4,function() old:Destroy() end) else old:Destroy() end
        record.ownedTrack=nil
    end
    if record.animator then
        for _, track in ipairs(record.animator:GetPlayingAnimationTracks()) do track:Stop(record.returning and 0.35 or 0.08) end
    end
    local from={}
    for _, object in pairs(record.targets or {}) do
        if object.Parent then from[object]=S.scaleLibraryPose(object.Transform,1/record.model:GetScale()) end
    end
    record.poseBlend={from=from,elapsed=0}
    record.clip = nil
    record.playingName = nil
    record.native = false
    record.loop = false
end
function S.playStoredAnimation(record, name, mode)
    if record.playingName == name and record.loop and mode == "loop" then
        S.stopStoredAnimation(record)
        return true
    end
    local clip = record.prepared and record.prepared[name]
    local id = clip and clip.sourceId or record.animationIds[string.lower(name)]
    local baked = clip and #(clip.frames or {}) > 0
    if not baked and (not id or id == "") then return false end
    local track
    if not baked then
        if not record.animator then return false end
        local animation = Instance.new("Animation")
        animation.AnimationId = id
        local ok, result = pcall(function() return record.animator:LoadAnimation(animation) end)
        animation:Destroy()
        if not ok then return false end
        track = result
    end
    S.stopStoredAnimation(record)
    record.elapsed = 0
    record.speed = S.getClipSpeed(record.name, name)
    record.loop = mode == "loop"
    record.playingName = name
    record.clip = clip
    record.native = track ~= nil
    record.ownedTrack = track
    if track then
        record.poseBlend=nil
        track.Priority = Enum.AnimationPriority.Action4
        track.Looped = record.loop
        track:Play(record.returning and 0.35 or 0.08, 1, record.speed)
    end
    return true
end

function playManualMorphAnimation(npcName, animationName, playMode)
    local found, played = false, false
    for _, record in pairs(S.multiMorphs) do
        if record.name == npcName then
            found = true
            if S.playStoredAnimation(record, animationName, playMode) then played = true end
        end
    end
    if morphActiveName == npcName and morphModel then
        return S.playLibraryMorphAnimation(npcName, animationName, playMode) or played
    end
    if found then return played end
    return S.playLibraryMorphAnimation(npcName, animationName, playMode)
end

function stopManualAnimation(npcName)
    if npcName then
        for _, record in pairs(S.multiMorphs) do
            if record.name == npcName then S.stopStoredAnimation(record) end
        end
        if morphActiveName ~= npcName then return end
    end
    return S.stopLibraryMorphAnimation()
end
function triggerBoundAnimation(binding)
    local names = {}
    if morphActiveName and morphModel then names[morphActiveName] = true end
    for _, record in pairs(S.multiMorphs) do names[record.name] = true end
    local triggered = false
    for name in pairs(names) do
        for animation, key in pairs(animationBinds[name] or {}) do
            if key == binding then
                local modelName, clipName = name, animation
                local mode = getAnimationMode(modelName, clipName)
                task.spawn(function()
                    if mode == "loop" and morphActiveName == modelName and isManualAnimationActive(modelName, clipName) then
                        stopManualAnimation(modelName)
                    else
                        playManualMorphAnimation(modelName, clipName, mode)
                    end
                end)
                triggered = true
                break
            end
        end
    end
    return triggered
end
S.targetAutoEnabled = false
S.targetAutoIdleSpeed = 0.8
S.targetAutoRunSpeed = 16
function S.targetAutoClip(name, state, prepared, ids)
    local assigned = S.getLocomotionOverride(name, state)
    if assigned then
        if prepared and prepared[assigned] then return assigned end
        local key = string.lower(assigned)
        if ids and ids[key] then return key end
    end
    local data = universalLibraryMorphs[name]
    local mapped = data and data.stateMap and data.stateMap[state]
    if mapped and prepared and prepared[mapped] then return mapped end
    if ids and ids[state] then return state end
    local names = {}
    for clipName in pairs(prepared or {}) do table.insert(names, clipName) end
    table.sort(names)
    for _, clipName in ipairs(names) do
        local clip = prepared[clipName]
        local normalized = v147NormalizeClipStateName(clipName)
        if not normalized:find("attack",1,true) and (clip.category == state or normalized == state or normalized == state .. "anim") then return clipName end
    end
    return nil
end
function S.targetMotionState(record, root, dt)
    local position = root.Position
    local delta = record.motionPosition and position-record.motionPosition or Vector3.zero
    record.motionPosition = position
    local planar = Vector3.new(delta.X,0,delta.Z)
    local speed = dt > 0 and planar.Magnitude/math.max(dt,0.001) or 0
    if delta.Magnitude > 30 then speed = 0 end
    record.motionSpeed = (record.motionSpeed or speed) + (speed-(record.motionSpeed or speed))*(1-math.exp(-12*dt))
    speed = record.motionSpeed
    local runThreshold = record.motionState == "run" and math.max(S.targetAutoIdleSpeed+0.5,S.targetAutoRunSpeed-1) or S.targetAutoRunSpeed
    local idleThreshold = record.motionState == "idle" and S.targetAutoIdleSpeed+0.15 or S.targetAutoIdleSpeed
    local state = speed <= idleThreshold and "idle" or (speed >= runThreshold and "run" or "walk")
    if record.motionCandidate ~= state then record.motionCandidate = state; record.motionStable = 0 end
    record.motionStable = (record.motionStable or 0)+dt
    if not record.motionState or record.motionStable >= 0.15 then record.motionState = state end
    return record.motionState
end
function S.updateTargetAuto(target, record, dt, active)
    if S.autoRecordOwns and S.autoRecordOwns(target) then return end
    if not S.targetAutoEnabled or not target or not target:IsDescendantOf(Workspace) then return end
    local root = getSpectateRoot(target)
    if not root then return end
    local state = S.targetMotionState(record, root, dt)
    if record.autoState == state then return end
    record.autoState = state
    local clip = S.targetAutoClip(record.name, state, record.prepared, record.animationIds)
    if not clip then return end
    if active then
        S.playLibraryMorphAnimation(record.name, clip, "loop")
    else
        if record.playingName ~= clip or not record.loop then S.playStoredAnimation(record,clip,"loop") end
    end
end
function S.prepareBatchAuto(record)
    record.name = morphActiveName
    record.prepared = v11UniversalPrepared
    record.animationIds = {}
    record.targets = {}
    local mapping = {}
    for _, group in ipairs({record.bones,record.motors}) do
        for _, pair in ipairs(group) do mapping[pair[1]] = pair[2] end
    end
    for _, clip in pairs(record.prepared or {}) do
        for _, channel in ipairs(clip.channels or {}) do record.targets[channel] = mapping[v11Target(channel)] end
    end
    record.autoOwned = true
    record.autoState = nil
    if record.track then record.track:Stop(0.08); record.track:Destroy(); record.track = nil end
end
S.targetAutoButton = makeButton(S.npcMorphTools, "Auto idle / walk / run: OFF", UDim2.new(1,-24,0,34), UDim2.fromOffset(12,1340), COL.button)
S.targetAutoIdleSlider = createSlider(S.npcMorphTools, "Idle: speed below (stud/s)", 0, 5, 0.1, 0.8, 1384, function(value)
    S.targetAutoIdleSpeed = value
end)
S.targetAutoRunSlider = createSlider(S.npcMorphTools, "Run: speed above (stud/s)", 6, 80, 0.5, 16, 1450, function(value)
    S.targetAutoRunSpeed = value
end)
S.targetAutoNote = makeLabel(S.npcMorphTools, "For NPC and player morphs. Walk between thresholds. PLAY and binds last until the movement state changes.", UDim2.new(1,-24,0,58), UDim2.fromOffset(12,1516), 11, COL.subtext, Enum.Font.Gotham)
S.targetAutoNote.TextWrapped = true
S.npcMorphTools.CanvasSize = UDim2.fromOffset(0,1590)
S.connectAction(S.targetAutoButton,function()
    S.targetAutoEnabled = not S.targetAutoEnabled
    S.targetAutoButton.Text = "Auto idle / walk / run: " .. (S.targetAutoEnabled and "ON" or "OFF")
    S.activeTargetAuto = nil
    for _, record in pairs(S.multiMorphs) do
        record.autoState = nil
        if not S.targetAutoEnabled then S.stopStoredAnimation(record) end
    end
    if S.npcMorphBatch then
        for _, record in pairs(S.npcMorphBatch.records) do
            record.autoOwned = nil
            record.autoState = nil
            record.trackKey = nil
            if not S.targetAutoEnabled then S.stopStoredAnimation(record) end
        end
    end
    if not S.targetAutoEnabled and S.npcMorphTarget then S.stopLibraryMorphAnimation() end
end)
ugKeepRootConnection(RunService.PreSimulation:Connect(function(dt)
    if S.unloading or not S.targetAutoEnabled then return end
    if S.npcMorphTarget and morphModel then
        if not S.activeTargetAuto or S.activeTargetAuto.model ~= morphModel then
            local ids = {}
            for name, track in pairs(morphTracks or {}) do if track.Animation then ids[name] = track.Animation.AnimationId end end
            S.activeTargetAuto = {model=morphModel, name=morphActiveName, prepared=v11UniversalPrepared, animationIds=ids}
        end
        S.updateTargetAuto(S.npcMorphTarget,S.activeTargetAuto,dt,true)
    end
    for target, record in pairs(S.multiMorphs) do S.updateTargetAuto(target,record,dt,false) end
    if S.npcMorphBatch then
        for target, record in pairs(S.npcMorphBatch.records) do
            if record.model.Parent then
                if not record.autoOwned then S.prepareBatchAuto(record) end
                S.updateTargetAuto(target,record,dt,false)
                S.stepStoredAnimation(record,dt)
            end
        end
    end
end))
S.recorder = {keys={record=Enum.KeyCode.Z,play=Enum.KeyCode.X}, loop=false,takes={},selected={},playbacks={},sounds=false,nextId=0}
function S.recorderSource()
    local character = S.controlledCharacter()
    if morphModel and morphModel.Parent and not S.npcMorphTarget and not S.npcMorphBatch then return morphModel,character end
    if character and S.multiMorphs[character] then return S.multiMorphs[character].model,character end
    if character and S.npcMorphTarget == character and morphModel then return morphModel,character end
    return character,character
end
function S.recorderStatus(message)
    S.recorderLabel.Text = message
end
function S.recorderRefreshTakes()
    for _,child in ipairs(S.recorderList:GetChildren()) do child:Destroy() end
    for i,take in ipairs(S.recorder.takes) do
        local button=makeButton(S.recorderList,(S.recorder.selected[take.id] and "✓ " or "○ ")..take.name..string.format(" · %.1f sec",take.frames[#take.frames].time),UDim2.new(1,-8,0,32),UDim2.fromOffset(0,(i-1)*36),S.recorder.selected[take.id] and COL.buttonSelected or COL.button)
        S.connectAction(button,function() S.recorder.selected[take.id]=not S.recorder.selected[take.id];S.recorderRefreshTakes() end)
    end
    S.recorderList.CanvasSize=UDim2.fromOffset(0,#S.recorder.takes*36)
end
function S.recorderStopPlayback()
    for _,playback in ipairs(S.recorder.playbacks) do playback.actor:Destroy() end
    S.recorder.playbacks={}
end
function S.recorderStop()
    local r=S.recorder
    r.countdown=nil
    S.recorderCountdown.Visible=false
    if r.recording then
        r.recording=nil
        local take=r.take
        r.take=nil
        if take and #take.frames>=2 then
            r.nextId+=1;take.id=r.nextId;take.name="Take "..take.id
            take.source=nil;take.character=nil;take.soundIds=nil;take.partIds=nil
            for _,channels in ipairs({take.parts,take.bones,take.motors}) do for _,channel in ipairs(channels) do channel.source=nil end end
            table.insert(r.takes,take);r.selected={[take.id]=true}
            S.recorderStatus(string.format("%s · %.1f sec · latest selected",take.name,take.frames[#take.frames].time))
            S.recorderRefreshTakes()
        elseif take then take.template:Destroy();S.recorderStatus("Recording too short") end
    else
        S.recorderStopPlayback()
        S.recorderStatus("Stopped · takes remain in memory")
    end
end
function S.recorderCaptureSounds(take)
    local result={}
    if not take.captureSounds then return result end
    local candidates=take.source:GetDescendants()
    if take.character and take.character~=take.source then
        for _,sound in ipairs(take.character:GetDescendants()) do
            if S.isFootstepSound and S.isFootstepSound(sound) then table.insert(candidates,sound) end
        end
    end
    for _,sound in ipairs(candidates) do
        if #result>=32 then break end
        if sound:IsA("Sound") and sound.Playing and sound.SoundId~="" then
            local parent=sound.Parent
            while parent and parent~=take.source and not parent:IsA("BasePart") do parent=parent.Parent end
            local parentId=take.partIds[parent]
            if not parentId and take.character and take.character~=take.source and sound:IsDescendantOf(take.character) and S.isFootstepSound(sound) then
                local root=take.source.PrimaryPart or take.source:FindFirstChild("HumanoidRootPart",true)
                parentId=take.partIds[root] or (take.parts[1] and take.parts[1].id)
            end
            if parentId then
                local id=take.soundIds[sound]
                if not id then take.nextSoundId+=1;id=take.nextSoundId;take.soundIds[sound]=id end
                table.insert(result,{id=id,parent=parentId,asset=sound.SoundId,position=sound.TimePosition,volume=sound.Volume,speed=sound.PlaybackSpeed,loop=sound.Looped,min=sound.RollOffMinDistance,max=sound.RollOffMaxDistance,mode=sound.RollOffMode})
            end
        end
    end
    return result
end
function S.recorderRenderSounds(playback,frame,time)
    local wanted={}
    for _,entry in ipairs(frame.sounds or {}) do
        local parent=playback.objects[entry.parent]
        if parent then
            wanted[entry.id]=true
            local sound=playback.sounds[entry.id]
            local created=not sound
            if created then sound=Instance.new("Sound");sound.Name="__LUMIN_REPLAY_AUDIO";sound.SoundId=entry.asset;sound.Parent=parent;playback.sounds[entry.id]=sound end
            if sound.SoundId~=entry.asset then sound.SoundId=entry.asset;created=true end
            sound.Volume=entry.volume;sound.PlaybackSpeed=entry.speed;sound.Looped=entry.loop
            sound.RollOffMinDistance=entry.min;sound.RollOffMaxDistance=entry.max;sound.RollOffMode=entry.mode
            local expected=entry.position+math.max(0,time-frame.time)*entry.speed
            if entry.loop and sound.TimeLength>0 then expected=expected%sound.TimeLength end
            if created or math.abs(sound.TimePosition-expected)>0.35 then sound.TimePosition=expected end
            if not sound.Playing then sound:Play() end
        end
    end
    for id,sound in pairs(playback.sounds) do if not wanted[id] then sound:Destroy();playback.sounds[id]=nil end end
end
function S.recorderClone(source)
    local originals = source:GetDescendants()
    table.insert(originals,1,source)
    local saved = {}
    local ok, copy = pcall(function()
        for index, object in ipairs(originals) do
            saved[object] = {archivable=object.Archivable, id=object:GetAttribute("__LuminRecordId")}
            object.Archivable = true
            object:SetAttribute("__LuminRecordId",index)
        end
        return source:Clone()
    end)
    for object, value in pairs(saved) do
        pcall(function() object.Archivable=value.archivable; object:SetAttribute("__LuminRecordId",value.id) end)
    end
    if not ok or not copy then return nil,"Failed to copy model" end
    local built, take = pcall(function()
        local cloneIds = {}
        for _, object in ipairs(copy:GetDescendants()) do cloneIds[object] = object:GetAttribute("__LuminRecordId") end
        S.cleanDetachedVisualClone(copy)
        for object, id in pairs(cloneIds) do object:SetAttribute("__LuminRecordId",id) end
        copy.Name = "__LOCAL_MORPH_REPLAY"
        local parts, bones, motors = {},{},{}
        for _, object in ipairs(copy:GetDescendants()) do
            local index = object:GetAttribute("__LuminRecordId")
            local original = index and originals[index]
            if original and object:IsA("BasePart") then
                object.Anchored=true
                object.CanCollide=false
                object.CanTouch=false
                object.CanQuery=false
                object.LocalTransparencyModifier=0
                table.insert(parts,{source=original,id=index})
            elseif original and object:IsA("Bone") then
                table.insert(bones,{source=original,id=index})
            elseif original and object:IsA("Motor6D") then
                table.insert(motors,{source=original,id=index})
            end
        end
        for _, object in ipairs(copy:GetDescendants()) do
            if object:IsA("LuaSourceContainer") or object:IsA("Sound") or object:IsA("BodyMover") or object:IsA("ProximityPrompt") or object:IsA("ClickDetector") or object:IsA("ParticleEmitter") or object:IsA("Trail") or object:IsA("Beam") then
                object:Destroy()
            elseif object:IsA("Humanoid") then
                object.AutomaticScalingEnabled=false
                object.BreakJointsOnDeath=false
                object.RequiresNeck=false
                object.AutoRotate=false
                object.DisplayDistanceType=Enum.HumanoidDisplayDistanceType.None
                pcall(function() object.EvaluateStateMachine=false end)
            elseif object:IsA("Constraint") then
                object.Enabled=false
            end
        end
        local surviving={}
        for _, object in ipairs(copy:GetDescendants()) do
            local id=object:GetAttribute("__LuminRecordId")
            if id then surviving[id]=true end
        end
        for _, group in ipairs({parts,bones,motors}) do
            for _, channel in ipairs(group) do
                if not surviving[channel.id] then error("Part of the rig disappeared while copying") end
            end
        end
        local count=#parts+#bones+#motors
        if #parts==0 then error("Model contains no parts") end
        if count>600 then error("Rig too complex: more than 600 channels") end
        return {template=copy,source=source,character=S.controlledCharacter(),parts=parts,bones=bones,motors=motors,frames={},limit=math.min(120,math.floor(180000/count/30))}
    end)
    if not built then copy:Destroy();return nil,tostring(take) end
    return take
end
function S.recorderBegin()
    local r=S.recorder
    if #r.takes>=20 then S.recorderStatus("20-take limit: delete unused takes");return end
    local used=0
    for _,take in ipairs(r.takes) do used+=#take.frames*(#take.parts+#take.bones+#take.motors) end
    local source=S.recorderSource()
    if not source or not source:IsDescendantOf(Workspace) then S.recorderStatus("Character has not spawned");return end
    local take,err=S.recorderClone(source)
    if not take then S.recorderStatus(err);return end
    S.recorderStopPlayback()
    take.limit=math.min(take.limit,math.floor((1800000-used)/(#take.parts+#take.bones+#take.motors)/30))
    if take.limit<1 then take.template:Destroy();S.recorderStatus("Recording memory full: delete unused takes");return end
    take.captureSounds=r.sounds;take.soundIds={};take.nextSoundId=0;take.partIds={}
    for _,channel in ipairs(take.parts) do take.partIds[channel.source]=channel.id end
    r.take=take
    r.recording={started=os.clock(),nextSample=0}
    S.recorderStatus("Recording · limit "..take.limit.." sec · press again to finish")
end
function S.recorderToggleRecord()
    local r=S.recorder
    if r.recording or r.countdown then S.recorderStop();return end
    S.recorderStopPlayback()
    r.countdown=os.clock()+3
    S.recorderCountdown.Text="3"
    S.recorderCountdown.Visible=true
    S.recorderStatus("Preparing · a new take will be added")
end
function S.recorderPlay(all)
    local r=S.recorder
    if r.recording then S.recorderStop() end
    r.countdown=nil;S.recorderCountdown.Visible=false
    if #r.playbacks>0 then S.recorderStopPlayback();S.recorderStatus("Playback stopped");return end
    local started=os.clock()
    for _,take in ipairs(r.takes) do
        if all==true or r.selected[take.id] then
            local copy=take.template:Clone()
            local objects={}
            for _,object in ipairs(copy:GetDescendants()) do
                local id=object:GetAttribute("__LuminRecordId")
                if id then objects[id]=object end
            end
            local playback={actor=copy,take=take,started=started,index=1,objects=objects,sounds={}}
            table.insert(r.playbacks,playback)
            copy.Parent=Workspace
            S.recorderRender(0,playback)
        end
    end
    S.recorderStatus(#r.playbacks>0 and ("Simultaneous takes: "..#r.playbacks) or "Select takes in the list")
end
function S.recorderRender(time,playback)
    local take=playback.take
    if playback.lastTime and time<playback.lastTime then
        for _,sound in pairs(playback.sounds) do sound:Destroy() end
        playback.sounds={}
    end
    playback.lastTime=time
    local frames=take.frames
    local index=playback.index
    if frames[index].time>time then index=1 end
    while index<#frames and frames[index+1].time<=time do index+=1 end
    playback.index=index
    local a,b=frames[index],frames[math.min(index+1,#frames)]
    S.recorderRenderSounds(playback,a,time)
    local alpha=b.time>a.time and math.clamp((time-a.time)/(b.time-a.time),0,1) or 0
    for i,channel in ipairs(take.motors) do
        local motor=playback.objects[channel.id]
        motor.C0=a.motors[i].c0:Lerp(b.motors[i].c0,alpha)
        motor.C1=a.motors[i].c1:Lerp(b.motors[i].c1,alpha)
        motor.Transform=a.motors[i].transform:Lerp(b.motors[i].transform,alpha)
    end
    for i,channel in ipairs(take.parts) do
        local part=playback.objects[channel.id]
        part.CFrame=a.parts[i].cf:Lerp(b.parts[i].cf,alpha)
        local size=a.parts[i].size:Lerp(b.parts[i].size,alpha)
        if (part.Size-size).Magnitude>0.0001 then part.Size=size end
        part.Anchored=true
        part.Transparency=a.parts[i].transparency
    end
    for i,channel in ipairs(take.bones) do
        local bone=playback.objects[channel.id]
        bone.CFrame=a.bones[i].cf:Lerp(b.bones[i].cf,alpha)
        bone.Transform=a.bones[i].transform:Lerp(b.bones[i].transform,alpha)
    end
end
function S.recorderTick()
    local r=S.recorder
    local now=os.clock()
    if r.countdown then
        local left=math.ceil(r.countdown-now)
        if left<=0 then r.countdown=nil;S.recorderCountdown.Visible=false;S.recorderBegin()
        else S.recorderCountdown.Text=tostring(left) end
    end
    if r.recording then
        local take=r.take
        local source,character=S.recorderSource()
        if source~=take.source or character~=take.character or not source:IsDescendantOf(Workspace) then S.recorderStop();S.recorderStatus("Recording ended: character or morph changed");return end
        local humanoid=character and character:FindFirstChildWhichIsA("Humanoid")
        if humanoid and humanoid.Health<=0 then S.recorderStop();return end
        local time=now-r.recording.started
        if time>=r.recording.nextSample then
            local frame={time=#take.frames==0 and 0 or time,parts={},bones={},motors={}}
            for i,channel in ipairs(take.parts) do
                local part=channel.source
                if not part:IsDescendantOf(source) then S.recorderStop();return end
                frame.parts[i]={cf=part.CFrame,size=part.Size,transparency=part.Transparency}
            end
            for i,channel in ipairs(take.bones) do
                local bone=channel.source
                if not bone:IsDescendantOf(source) then S.recorderStop();return end
                frame.bones[i]={cf=bone.CFrame,transform=bone.Transform}
            end
            for i,channel in ipairs(take.motors) do
                local motor=channel.source
                if not motor:IsDescendantOf(source) then S.recorderStop();return end
                frame.motors[i]={c0=motor.C0,c1=motor.C1,transform=motor.Transform}
            end
            frame.sounds=S.recorderCaptureSounds(take)
            table.insert(take.frames,frame)
            r.recording.nextSample=time+1/30
            S.recorderStatus(string.format("Recording %.1f / %d sec",time,take.limit))
        end
        if time>=take.limit then S.recorderStop() end
    end
    for i=#r.playbacks,1,-1 do
        local playback=r.playbacks[i]
        local frames=playback.take.frames
        local duration=frames[#frames].time
        local time=now-playback.started
        if r.loop and duration>0 then time=time%duration end
        S.recorderRender(math.min(time,duration),playback)
        if not r.loop and time>=duration then playback.actor:Destroy();table.remove(r.playbacks,i) end
    end
end
function S.recorderInput(input,processed)
    local r=S.recorder
    if S.waitingForUiBind or S.waitingForPanelBind or waitingForAnimationBind then r.rebind=nil;return false end
    if input.UserInputType~=Enum.UserInputType.Keyboard or input.KeyCode==Enum.KeyCode.Unknown then return false end
    local key=input.KeyCode
    if r.rebind then
        if key==Enum.KeyCode.Escape then r.rebind=nil;return true end
        if key==S.shadowKey or key==S.panelToggleKey or key==S.uiToggleKey then S.recorderStatus("Key used by panel/UI");return true end
        for action,value in pairs(r.keys) do if action~=r.rebind and value==key then S.recorderStatus("Key used by recorder");return true end end
        for _, binds in pairs(animationBinds) do for _, value in pairs(binds) do if value==key then S.recorderStatus("Key used by animation");return true end end end
        for _,group in ipairs(S.audio and S.audio.groups or {}) do if group.key==key.Name then S.recorderStatus("Key used by sound");return true end end
        r.keys[r.rebind]=key
        r.bindButtons[r.rebind].Text=key.Name
        r.rebind=nil
        if S.saveUserSettings then S.saveUserSettings() end
        S.recorderStatus("Key saved")
        return true
    end
    if processed or UserInputService:GetFocusedTextBox() then return false end
    if key==S.panelToggleKey or key==S.uiToggleKey then return false end
    if key==r.keys.record then S.recorderToggleRecord();return true end
    if key==r.keys.play then S.recorderPlay();return true end
    if key==r.keys.all then S.recorderPlay(true);return true end
    return false
end
function S.recorderUnload()
    RunService:UnbindFromRenderStep("LuminRoleRecorder")
    S.recorder.countdown=nil
    S.recorder.recording=nil
    S.recorderStopPlayback()
    if S.recorder.take then S.recorder.take.template:Destroy();S.recorder.take=nil end
    for _,take in ipairs(S.recorder.takes) do take.template:Destroy() end
    S.recorder.takes={};S.recorder.selected={}
end
createTabButton("Recorder","Role recorder",460)
S.recorderPage=createPage("Recorder")
S.recorderSection=makeSection(S.recorderPage,"ROLE RECORDER",UDim2.fromOffset(24,24),UDim2.new(1,-48,1,-48))
S.recorderLabel=makeLabel(S.recorderSection,"Multiple takes in memory · select takes in the list",UDim2.new(1,-24,0,54),UDim2.fromOffset(12,38),13,COL.text,Enum.Font.Gotham)
S.recorderLabel.TextWrapped=true
S.recorder.bindButtons={}
for i,item in ipairs({{"record","Record / finish",S.recorderToggleRecord},{"play","Play selected / stop",function() S.recorderPlay() end},{"all","Play all / stop",function() S.recorderPlay(true) end}}) do
    local action=item[1]
    local button=makeButton(S.recorderSection,item[2],UDim2.new(1,-130,0,36),UDim2.fromOffset(12,106+(i-1)*50),COL.button)
    S.connectAction(button,item[3])
    local bind=makeButton(S.recorderSection,(S.recorder.keys[action] and S.recorder.keys[action].Name or "Bind: —"),UDim2.fromOffset(94,36),UDim2.new(1,-106,0,106+(i-1)*50),COL.button)
    S.recorder.bindButtons[action]=bind
    S.connectAction(bind,function() S.recorder.rebind=action;S.recorderStatus("Press a key · Esc cancels") end)
end
S.recorderLoopButton=makeButton(S.recorderSection,"Loop playback: OFF",UDim2.new(0.5,-18,0,32),UDim2.fromOffset(12,258),COL.button)
S.connectAction(S.recorderLoopButton,function() S.recorder.loop=not S.recorder.loop;S.recorderLoopButton.Text="Loop playback: "..(S.recorder.loop and "ON" or "OFF") end)
S.recorderSoundButton=makeButton(S.recorderSection,"Record sounds: OFF",UDim2.new(0.5,-18,0,32),UDim2.new(0.5,6,0,258),COL.button)
S.connectAction(S.recorderSoundButton,function()
    S.recorder.sounds=not S.recorder.sounds
    S.recorderSoundButton.Text="Record sounds: "..(S.recorder.sounds and "ON" or "OFF")
    if S.saveUserSettings then S.saveUserSettings() end
end)
S.recorderDeleteButton=makeButton(S.recorderSection,"Delete selected",UDim2.new(0.5,-18,0,32),UDim2.fromOffset(12,300),COL.button)
S.connectAction(S.recorderDeleteButton,function()
    if S.recorder.recording or S.recorder.countdown then S.recorderStatus("Finish recording first");return end
    S.recorderStopPlayback()
    for i=#S.recorder.takes,1,-1 do
        local take=S.recorder.takes[i]
        if S.recorder.selected[take.id] then take.template:Destroy();table.remove(S.recorder.takes,i) end
    end
    S.recorder.selected={};S.recorderRefreshTakes();S.recorderStatus("Selected takes deleted")
end)
S.recorderClearSelection=makeButton(S.recorderSection,"Clear selection",UDim2.new(0.5,-18,0,32),UDim2.new(0.5,6,0,300),COL.button)
S.connectAction(S.recorderClearSelection,function() S.recorder.selected={};S.recorderRefreshTakes() end)
S.recorderNote=makeLabel(S.recorderSection,"Up to 20 takes per session. X plays selected takes together. Enable audio before recording: captures up to 32 Sounds inside the character/morph. Camera and game actions are not recorded.",UDim2.new(1,-24,0,66),UDim2.fromOffset(12,340),11,COL.subtext,Enum.Font.Gotham)
S.recorderNote.TextWrapped=true
S.recorderList=Instance.new("ScrollingFrame")
S.recorderList.Position=UDim2.fromOffset(12,414);S.recorderList.Size=UDim2.new(1,-24,1,-426)
S.recorderList.BackgroundTransparency=1;S.recorderList.ScrollBarThickness=5;S.recorderList.Parent=S.recorderSection
S.recorderCountdown=makeLabel(gui,"3",UDim2.fromOffset(160,160),UDim2.new(0.5,-80,0.5,-80),72,COL.text,Enum.Font.GothamBold)
S.recorderCountdown.ZIndex=200
S.recorderCountdown.Visible=false
RunService:UnbindFromRenderStep("LuminRoleRecorder")
RunService:BindToRenderStep("LuminRoleRecorder",Enum.RenderPriority.Last.Value+500,function()
    if S.unloading then return end
    local ok,err=pcall(S.recorderTick)
    if not ok then S.recorderStop();S.recorderStopPlayback();S.recorderStatus("Recording stopped: "..tostring(err)) end
end)
S.overlayEnabled = false
S.overlayLastSend = 0
S.overlayBusy = false
S.overlayDefaultSelected = true
S.overlaySelection = {}
S.overlayContourEnabled = false
S.overlayHighlights = {}
createTabButton("NpcOverlay", "NPC markers", 506)
S.overlayPage = createPage("NpcOverlay")
S.overlaySection = makeSection(S.overlayPage, "NPC MARKERS AND OUTLINES", UDim2.fromOffset(24,24), UDim2.new(1,-48,1,-48))
S.overlayButton = makeButton(S.overlaySection, "External markers: OFF", UDim2.new(0.5,-18,0,36), UDim2.fromOffset(12,54), COL.button)
S.overlayContourButton = makeButton(S.overlaySection, "Outline (in recording): OFF", UDim2.new(0.5,-18,0,36), UDim2.new(0.5,6,0,54), COL.button)
S.overlayStatus = makeLabel(S.overlaySection, "Launch LuminNpcOverlay using Start.vbs. Markers use a separate Windows overlay.", UDim2.new(1,-24,0,74), UDim2.fromOffset(12,96), 13, COL.text, Enum.Font.Gotham)
S.overlayStatus.TextWrapped = true
function S.overlayIsSelected(name)
    local selected = S.overlaySelection[name]
    if selected == nil then return S.overlayDefaultSelected end
    return selected
end
S.overlaySelectAll = makeButton(S.overlaySection, "Select all", UDim2.new(0.5,-18,0,30), UDim2.fromOffset(12,176), COL.button)
S.overlaySelectNone = makeButton(S.overlaySection, "Deselect all", UDim2.new(0.5,-18,0,30), UDim2.new(0.5,6,0,176), COL.button)
S.overlayList = Instance.new("ScrollingFrame")
S.overlayList.BackgroundTransparency = 1
S.overlayList.BorderSizePixel = 0
S.overlayList.Size = UDim2.new(1,-24,1,-226)
S.overlayList.Position = UDim2.fromOffset(12,218)
S.overlayList.ScrollBarThickness = 5
S.overlayList.Parent = S.overlaySection
function S.refreshOverlayList()
    local counts = {}
    for _, item in ipairs(S.cameraNpcEntries or {}) do
        if item.model and item.model:IsDescendantOf(Workspace) and not ugIsPlayerCharacterModel(item.model) then
            counts[item.model.Name] = (counts[item.model.Name] or 0)+1
        end
    end
    local names = {}
    for name in pairs(counts) do table.insert(names,name) end
    table.sort(names)
    for _, child in ipairs(S.overlayList:GetChildren()) do child:Destroy() end
    for index, name in ipairs(names) do
        local button = makeButton(S.overlayList, "", UDim2.new(1,-8,0,32), UDim2.fromOffset(0,(index-1)*38), COL.button)
        local function refresh()
            local selected = S.overlayIsSelected(name)
            button.Text = (selected and "✓ " or "○ ") .. name .. " (" .. counts[name] .. ")"
            button.BackgroundColor3 = selected and COL.buttonSelected or COL.button
        end
        refresh()
        S.connectAction(button,function()
            S.overlaySelection[name] = not S.overlayIsSelected(name)
            S.refreshOverlayContours()
            refresh()
        end)
    end
    S.overlayList.CanvasSize = UDim2.fromOffset(0,#names*38)
end
S.connectAction(S.overlaySelectAll,function()
    S.overlaySelection = {}
    S.overlayDefaultSelected = true
    S.refreshOverlayList()
    S.refreshOverlayContours()
end)
S.connectAction(S.overlaySelectNone,function()
    S.overlaySelection = {}
    S.overlayDefaultSelected = false
    S.refreshOverlayList()
    S.refreshOverlayContours()
end)
function S.refreshOverlayContours()
    local wanted = {}
    if S.overlayContourEnabled and not S.unloading then
        for _, item in ipairs(S.cameraNpcEntries or {}) do
            local model = item.model
            if model and model:IsDescendantOf(Workspace) and not ugIsPlayerCharacterModel(model) and S.overlayIsSelected(model.Name) then
                wanted[model] = true
            end
        end
    end
    for model, highlight in pairs(S.overlayHighlights) do
        if not wanted[model] or not highlight.Parent then
            highlight:Destroy()
            S.overlayHighlights[model] = nil
        end
    end
    for model in pairs(wanted) do
        if not S.overlayHighlights[model] then
            if not S.overlayHighlightFolder or not S.overlayHighlightFolder.Parent then
                S.overlayHighlightFolder = Instance.new("Folder")
                S.overlayHighlightFolder.Name = "__LUMIN_NPC_OUTLINES"
                S.overlayHighlightFolder.Parent = Workspace
            end
            local highlight = Instance.new("Highlight")
            highlight.Name = "NpcOutline"
            highlight.Adornee = model
            highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
            highlight.FillTransparency = 1
            highlight.OutlineTransparency = 0
            highlight.OutlineColor = Color3.fromRGB(255,55,65)
            highlight.Parent = S.overlayHighlightFolder
            S.overlayHighlights[model] = highlight
        end
    end
end
function S.overlayUnload()
    S.overlayEnabled = false
    S.overlayContourEnabled = false
    for _, highlight in pairs(S.overlayHighlights) do highlight:Destroy() end
    S.overlayHighlights = {}
    if S.overlayHighlightFolder then S.overlayHighlightFolder:Destroy(); S.overlayHighlightFolder = nil end
end
S.connectAction(S.overlayContourButton,function()
    S.overlayContourEnabled = not S.overlayContourEnabled
    S.overlayContourButton.Text = "Outline (in recording): " .. (S.overlayContourEnabled and "ON" or "OFF")
    S.refreshOverlayContours()
end)
S.refreshOverlayList()
S.connectAction(S.overlayButton,function()
    S.overlayEnabled = not S.overlayEnabled
    S.overlayButton.Text = "External markers: " .. (S.overlayEnabled and "ON" or "OFF")
    if not S.overlayEnabled then S.overlayStatus.Text = "Disabled. External markers will disappear within a second." end
end)
ugKeepRootConnection(RunService.Heartbeat:Connect(function()
    if S.unloading or not S.overlayEnabled or S.overlayBusy or os.clock()-S.overlayLastSend < 0.05 then return end
    S.overlayLastSend = os.clock()
    local camera = Workspace.CurrentCamera
    if not camera or camera.ViewportSize.X < 1 or camera.ViewportSize.Y < 1 then return end
    local entries = {}
    for _, item in ipairs(S.cameraNpcEntries or {}) do
        local model = item.model
        if model and model:IsDescendantOf(Workspace) and not ugIsPlayerCharacterModel(model) and S.overlayIsSelected(model.Name) then
            local root = getSpectateRoot(model)
            if root then
                local point = camera:WorldToViewportPoint(root.Position)
                local relative = camera.CFrame:PointToObjectSpace(root.Position)
                table.insert(entries, {name=item.displayName or model.Name, x=point.X/camera.ViewportSize.X, y=point.Y/camera.ViewportSize.Y, z=point.Z, dx=relative.X, dy=-relative.Y, distance=(root.Position-camera.CFrame.Position).Magnitude})
            end
        end
    end
    table.sort(entries, function(a,b) return a.distance < b.distance end)
    while #entries > 80 do table.remove(entries) end
    local requestFn = request or http_request or (syn and syn.request)
    if type(requestFn) ~= "function" then
        S.overlayEnabled = false
        S.overlayButton.Text = "External markers: OFF"
        S.overlayStatus.Text = "No request function to connect to the helper."
        return
    end
    S.overlayBusy = true
    task.spawn(function()
        local ok, response = pcall(function()
            return requestFn({Url="http://127.0.0.1:18764/frame", Method="POST", Headers={["Content-Type"]="application/json"}, Body=HttpService:JSONEncode({version=1, entries=entries})})
        end)
        S.overlayBusy = false
        if S.unloading or not S.overlayEnabled then return end
        if ok and response and tonumber(response.StatusCode) == 200 then
            S.overlayStatus.Text = "Helper connection: OK · NPCs: " .. #entries .. "\nDistance is measured from the camera. Check that markers are absent from OBS recordings."
        else
            S.overlayLastSend = os.clock()+1
            S.overlayStatus.Text = "No connection. Run Start.vbs in LuminNpcOverlay."
        end
    end)
end))
task.spawn(function()
    while gui.Parent and not S.unloading do
        if S.overlayEnabled or S.overlayContourEnabled or (main.Visible and activeTab == "NpcOverlay") then
            pcall(ugScanCameraNpcs, false)
            S.refreshOverlayList()
        end
        S.refreshOverlayContours()
        task.wait(4)
    end
end)
S.userSettingsWritable=true
S.modelPreviewsEnabled=false
S.modelPreviewLimit=2
S.uiAnimationsEnabled=false
function S.saveUserSettings()
    if not S.userSettingsWritable or type(writefile)~="function" then return end
    local keys={}
    for action,key in pairs(S.recorder.keys) do keys[action]=key.Name end
    local ok,err=pcall(function()
        writefile("TyomichLiteSettings.json",HttpService:JSONEncode({version=1,economyMode=S.economyMode,panel=S.panelToggleKey.Name,ui=S.uiToggleKey.Name,recorder=keys,recordSounds=S.recorder.sounds,shadow=S.shadowKey and S.shadowKey.Name,modelPreviews=S.modelPreviewsEnabled,previewLimit=S.modelPreviewLimit,uiAnimations=S.uiAnimationsEnabled}))
    end)
    if not ok then S.recorderStatus("Failed to save keys: "..tostring(err)) end
    return ok
end
do
    if type(readfile)~="function" or type(isfile)~="function" then
        S.userSettingsWritable=false
    else
        local ok,err=pcall(function()
            if not isfile("TyomichLiteSettings.json") then return end
            local raw=readfile("TyomichLiteSettings.json")
            assert(#raw<8192,"Settings file too large")
            local data=HttpService:JSONDecode(raw)
            assert(type(data)=="table" and data.version==1 and type(data.recorder)=="table" and type(data.recordSounds)=="boolean","Invalid settings format")
            local seen={}
            local function key(value)
                assert(type(value)=="string","Invalid key")
                local result=Enum.KeyCode[value]
                assert(result and result~=Enum.KeyCode.Unknown and result~=Enum.KeyCode.Escape and not seen[value],"Key unavailable or invalid")
                seen[value]=true
                return result
            end
            local panel=key(data.panel)
            local ui=key(data.ui)
            local keys={record=key(data.recorder.record),play=key(data.recorder.play)}
            if data.recorder.all then keys.all=key(data.recorder.all) end
            local shadow=data.shadow and key(data.shadow) or nil
            S.shadowKey=shadow
            S.panelToggleKey=panel;S.uiToggleKey=ui;S.recorder.keys=keys;S.recorder.sounds=data.recordSounds
            S.modelPreviewsEnabled=data.modelPreviews~=false
            S.uiAnimationsEnabled=data.uiAnimations~=false
            if data.previewLimit==2 or data.previewLimit==4 or data.previewLimit==8 then S.modelPreviewLimit=data.previewLimit end
        end)
        if not ok then S.userSettingsWritable=false;warn("LuminSettings: "..tostring(err).."; file will not be overwritten") end
    end
end
S.panelBindButton.Text="Panel key: "..S.panelToggleKey.Name
S.uiBindButton.Text="UI key: "..S.uiToggleKey.Name
sideHint.Text=S.panelToggleKey.Name.." — panel"
for action,button in pairs(S.recorder.bindButtons) do button.Text=S.recorder.keys[action] and S.recorder.keys[action].Name or "Bind: —" end
S.recorderSoundButton.Text="Record sounds: "..(S.recorder.sounds and "ON" or "OFF")
S.morphCardsSection = morphListSection
S.morphFavorites = {}
S.morphFavoriteFile = "LuminProfiles/favorites_" .. tostring(game.PlaceId) .. ".json"
do
    local ok, saved = pcall(function()
        if type(isfile)=="function" and type(readfile)=="function" and isfile(S.morphFavoriteFile) then
            return HttpService:JSONDecode(readfile(S.morphFavoriteFile))
        end
    end)
    if ok and type(saved)=="table" then
        for key, value in pairs(saved) do if type(key)=="string" and value==true then S.morphFavorites[key]=true end end
    end
end
function S.morphFavoriteKey(name)
    local data = universalLibraryMorphs[name]
    if data then return "library:" .. tostring(data.__luminLibraryId or "") .. ":" .. tostring(data.name or name) end
    local source = customMorphSources[name]
    if source then return "custom:" .. name end
    local entry = S.morphRegistry and S.morphRegistry[name]
    return "native:" .. tostring(entry and entry.path or name)
end
function S.morphHasAnimations(name)
    local data = universalLibraryMorphs[name]
    if data then return #(data.animations or {}) > 0 end
    local folder = findAnimationFolder(name)
    return folder ~= nil and folder:FindFirstChildWhichIsA("Animation",true) ~= nil
end
function S.matchesMorphFilters(name)
    if S.morphSourceFilter and S.morphSourceFilter ~= "All" then
        local isLocal = false
        for _, loadedName in pairs(S.localLibrary and S.localLibrary.loaded or {}) do
            if loadedName == name then isLocal = true; break end
        end
        if S.morphSourceFilter == "Local" and not isLocal then return false end
        if S.morphSourceFilter == "Library" and (isLocal or not universalLibraryMorphs[name]) then return false end
    end
    return (not S.onlyAnimatedMorphs or S.morphHasAnimations(name)) and (not S.onlyFavoriteMorphs or S.morphFavorites[S.morphFavoriteKey(name)]==true)
end
function S.addMorphFavorite(button, name)
    local key = S.morphFavoriteKey(name)
    local star = makeButton(button, S.morphFavorites[key] and "★" or "☆", UDim2.fromOffset(28,28), UDim2.new(1,-32,0,4), COL.panel)
    star.Name = "MorphFavorite"
    star.TextSize = 20
    star.ZIndex = button.ZIndex + 4
    star.TextColor3 = S.morphFavorites[key] and COL.accent or COL.dim
    local card = S.npcCards[button]
    if card then card.title.Size -= UDim2.fromOffset(26,0) end
    S.connectAction(star,function()
        S.morphFavorites[key] = not S.morphFavorites[key] or nil
        local ok = pcall(function()
            assert(type(writefile)=="function", "File saving unavailable")
            if type(makefolder)=="function" then pcall(makefolder,"LuminProfiles") end
            writefile(S.morphFavoriteFile, HttpService:JSONEncode(S.morphFavorites))
        end)
        if not ok then selectedAnimLabel.Text = "Favorites: session only; file saving unavailable" end
        star.Text = S.morphFavorites[key] and "★" or "☆"
        star.TextColor3 = S.morphFavorites[key] and COL.accent or COL.dim
        if S.onlyFavoriteMorphs then task.defer(function() if gui.Parent then rebuildMorphList(true) end end) end
    end)
end
S.animatedMorphFilter = makeButton(morphListSection,"Animations: ALL",UDim2.fromOffset(138,26),UDim2.new(1,-282,0,5),COL.button)
S.favoriteMorphFilter = makeButton(morphListSection,"Favorites: ALL",UDim2.fromOffset(126,26),UDim2.new(1,-138,0,5),COL.button)
S.animatedMorphFilter.TextSize = 10
S.favoriteMorphFilter.TextSize = 10
S.morphSourceFilter = "All"
S.settingsButton = makeButton(titlebar,"⚙",UDim2.fromOffset(32,28),UDim2.new(1,-80,0,8),COL.button)
S.settingsButton.Name = "PanelSettings"
S.settingsButton.TextSize = 20
S.settingsOverlay = Instance.new("TextButton")
S.settingsOverlay.Name = "PanelSettingsOverlay"
S.settingsOverlay.Size = UDim2.fromScale(1,1)
S.settingsOverlay.BackgroundColor3 = Color3.new(0,0,0)
S.settingsOverlay.BackgroundTransparency = 0.35
S.settingsOverlay.Text = ""
S.settingsOverlay.AutoButtonColor = false
S.settingsOverlay.Visible = false
S.settingsOverlay.ZIndex = 100
S.settingsOverlay.Parent = main
corner(S.settingsOverlay,14)
S.settingsPopup = Instance.new("TextButton")
S.settingsPopup.Name = "PanelSettingsPopup"
S.settingsPopup.Text = ""
S.settingsPopup.AutoButtonColor = false
S.settingsPopup.AnchorPoint = Vector2.new(1,0)
S.settingsPopup.Position = UDim2.new(1,-16,0,52)
S.settingsPopup.Size = UDim2.fromOffset(340,380)
S.settingsPopup.BackgroundColor3 = COL.panel
S.settingsPopup.BorderSizePixel = 0
S.settingsPopup.ZIndex = 101
S.settingsPopup.Parent = S.settingsOverlay
corner(S.settingsPopup,12)
stroke(S.settingsPopup,COL.accent,0.4,1)
makeLabel(S.settingsPopup,"DISPLAY & PERFORMANCE",UDim2.new(1,-60,0,28),UDim2.fromOffset(16,10),12,COL.text,Enum.Font.GothamBold)
S.settingsClose = makeButton(S.settingsPopup,"×",UDim2.fromOffset(28,28),UDim2.new(1,-40,0,10),COL.button)
S.previewSettingButton = makeButton(S.settingsPopup,"",UDim2.new(1,-32,0,38),UDim2.fromOffset(16,50),COL.button)
S.previewLimitButton = makeButton(S.settingsPopup,"",UDim2.new(1,-32,0,38),UDim2.fromOffset(16,96),COL.button)
S.uiAnimationSettingButton = makeButton(S.settingsPopup,"",UDim2.new(1,-32,0,38),UDim2.fromOffset(16,142),COL.button)
S.settingsSaveNote = makeLabel(S.settingsPopup,"",UDim2.new(1,-32,0,62),UDim2.fromOffset(16,294),11,COL.subtext,Enum.Font.Gotham)
S.settingsSaveNote.TextWrapped = true
S.economyButton=makeButton(S.settingsPopup,"",UDim2.new(1,-32,0,38),UDim2.fromOffset(16,188),COL.button)
S.economyRefresh=makeButton(S.settingsPopup,"Refresh model lists",UDim2.new(1,-32,0,38),UDim2.fromOffset(16,234),COL.button)
S.connectAction(S.economyButton,function()
    if S.economyRefreshing then return end
    S.economyMode=not S.economyMode
    for _,tween in pairs(S.uiTweens) do tween:Cancel() end
    S.updateNpcPreviews()
    rebuildMorphList(true)
    ugRebuildCameraNpcList(true)
    S.refreshNpcMorphList(false)
    S.commitPanelSettings()
end)
S.connectAction(S.economyRefresh,function()
    if S.economyRefreshing then return end
    S.economyRefreshing=true;S.economyRefresh.Text="Scanning..."
    task.defer(function()
        local ok,err=pcall(function()
            ugScanMorphs(true);ugScanCameraNpcs(true)
            rebuildMorphList(true);ugRebuildCameraNpcList(true);S.refreshNpcMorphList(false)
        end)
        S.economyRefreshing=false;S.economyRefresh.Text="Refresh model lists"
        if not ok then S.settingsSaveNote.Text=tostring(err) end
    end)
end)

for _, object in ipairs(S.settingsPopup:GetDescendants()) do if object:IsA("GuiObject") then object.ZIndex=102 end end
function S.refreshPanelSettings()
    S.economyButton.Text="Economy mode: "..(S.economyMode and "ON" or "OFF")
    S.previewSettingButton.Text = "3D model previews: " .. (not S.economyMode and S.modelPreviewsEnabled and "ON" or "OFF")
    S.previewLimitButton.Text = "Simultaneous previews: " .. S.modelPreviewLimit .. "  ›"
    S.uiAnimationSettingButton.Text = "Interface animations: " .. (not S.economyMode and S.uiAnimationsEnabled and "ON" or "OFF")
    S.settingsSaveNote.Text = S.economyMode and "Manual refresh. Up to 80 search results. Animations: selected morph only. 3D previews and UI animation disabled." or "Fewer previews reduce graphics and memory usage. Settings apply to all model lists."
end
function S.commitPanelSettings()
    S.refreshPanelSettings()
    S.updateNpcPreviews()
    if not S.saveUserSettings() then S.settingsSaveNote.Text = "Applied for this session. Settings could not be saved to disk." end
end
S.connectAction(S.previewSettingButton,function()
    S.modelPreviewsEnabled = not S.modelPreviewsEnabled
    S.commitPanelSettings()
end)
S.connectAction(S.previewLimitButton,function()
    S.modelPreviewLimit = S.modelPreviewLimit==8 and 2 or S.modelPreviewLimit==2 and 4 or 8
    S.commitPanelSettings()
end)
S.connectAction(S.uiAnimationSettingButton,function()
    S.uiAnimationsEnabled = not S.uiAnimationsEnabled
    S.commitPanelSettings()
end)
S.connectAction(S.settingsButton,function() S.refreshPanelSettings(); S.settingsOverlay.Visible=true end)
S.connectAction(S.settingsClose,function() S.settingsOverlay.Visible=false end)
S.connectAction(S.settingsOverlay,function() S.settingsOverlay.Visible=false end)
S.connectAction(S.animatedMorphFilter,function()
    S.onlyAnimatedMorphs = not S.onlyAnimatedMorphs
    S.animatedMorphFilter.Text = S.onlyAnimatedMorphs and "Animations: ONLY" or "Animations: ALL"
    S.animatedMorphFilter.BackgroundColor3 = S.onlyAnimatedMorphs and COL.buttonSelected or COL.button
    rebuildMorphList(true)
end)
S.connectAction(S.favoriteMorphFilter,function()
    S.onlyFavoriteMorphs = not S.onlyFavoriteMorphs
    S.favoriteMorphFilter.Text = S.onlyFavoriteMorphs and "Favorites: ONLY" or "Favorites: ALL"
    S.favoriteMorphFilter.BackgroundColor3 = S.onlyFavoriteMorphs and COL.buttonSelected or COL.button
    rebuildMorphList(true)
end)
morphPage.CanvasSize = UDim2.fromOffset(0, 1430)
morphListSection.Position = UDim2.fromOffset(24,88)
morphListSection.Size = UDim2.new(1,-48,0,390)
morphDetails.Position = UDim2.fromOffset(24,496)
morphDetails.Size = UDim2.new(1,-48,0,900)
v11TransformScroll.Size = UDim2.new(1,-24,0,680)
v11TransformScroll.ScrollingEnabled = false
for _, home in ipairs(S.npcMorphToolsHome) do
    if home.object==v11TransformScroll then home.size=v11TransformScroll.Size end
end
S.npcMorphPage.CanvasSize = UDim2.fromOffset(0, 2520)
S.npcCardsSection = makeSection(S.npcMorphPage, "NPC / PLAYERS", UDim2.fromOffset(24,24), UDim2.new(1,-48,0,380))
S.npcMorphScroll.Parent = S.npcCardsSection
S.npcMorphScroll.Position = UDim2.fromOffset(12,120)
S.npcMorphScroll.Size = UDim2.new(1,-24,1,-132)
S.npcTargetSearch = morphSearch:Clone()
S.npcTargetSearch.Name = "NpcTargetSearch"
S.npcTargetSearch.Text = ""
S.npcTargetSearch.PlaceholderText = "Search NPCs, players or models..."
S.npcTargetSearch.Position = UDim2.fromOffset(12,78)
S.npcTargetSearch.Parent = S.npcCardsSection
S.npcTargetSearch:GetPropertyChangedSignal("Text"):Connect(function()
    S.npcSearchRevision = (S.npcSearchRevision or 0)+1
    local revision = S.npcSearchRevision
    task.delay(0.18,function()
        if gui.Parent and revision==S.npcSearchRevision then S.refreshNpcMorphList() end
    end)
end)
S.playerMorphModeButton.Parent = S.npcCardsSection
S.playerMorphModeButton.Position = UDim2.fromOffset(12,38)
S.playerMorphWatch.Parent = S.npcCardsSection
S.playerMorphWatch.Position = UDim2.new(0.5,6,0,38)
S.npcMorphSection.Position = UDim2.fromOffset(24,422)
S.npcMorphSection.Size = UDim2.new(1,-48,0,450)
S.npcMorphTools.Position = UDim2.fromOffset(24,892)
S.npcMorphTools.Size = UDim2.new(1,-48,0,1600)
S.npcMorphTools.ScrollingEnabled = false
morphLayout:Destroy()
S.npcMorphLayout:Destroy()
function S.installCardGrid(scroll)
    scroll:SetAttribute("CompactCards", true)
    local layout = Instance.new("UIGridLayout")
    layout.CellPadding = UDim2.fromOffset(8,8)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = scroll
    local function update()
        local width = scroll.AbsoluteSize.X / S.windowScale.Scale - 10
        local columns = math.max(1, math.floor((width+8)/210))
        layout.CellSize = UDim2.new(1/columns,-(10+(columns-1)*8)/columns,0,94)
    end
    ugKeepRootConnection(scroll:GetPropertyChangedSignal("AbsoluteSize"):Connect(update))
    update()
end
S.installCardGrid(morphScroll)
S.installCardGrid(S.npcMorphScroll)
morphListSignature = ""
rebuildMorphList(true)
S.refreshNpcMorphList()

S.footstepsMuted = false
S.footstepSaved = {}
function S.isFootstepSound(sound)
    if not (sound:IsA("Sound") or sound:IsA("AudioPlayer")) then return false end
    local name = string.lower(sound.Name):gsub("[%s_%-]", "")
    local parent=sound.Parent
    local folder=parent and parent.Name:lower() or ""
    local id=S.soundId(sound):lower()
    if name:find("footstep",1,true) or folder:find("footstep",1,true) or id:find("footstep",1,true) then return true end
    return name=="running" or name=="walking" or name=="walk" or name=="run" or name=="footstep" or name=="footsteps" or name=="step" or name:match("^footstep%d+$")~=nil or name:match("^step%d+$")~=nil
end
function S.restoreFootsteps()
    for sound, item in pairs(S.footstepSaved) do
        item.connection:Disconnect()
        if sound.Parent then sound.Volume = item.volume end
    end
    S.footstepSaved = {}
end
function S.refreshFootsteps()
    if not S.footstepsMuted then return end
    local character = S.controlledCharacter()
    for sound, item in pairs(S.footstepSaved) do
        if not character or not (sound:IsDescendantOf(character) or sound:IsDescendantOf(player) or sound:IsDescendantOf(game:GetService("SoundService"))) then
            item.connection:Disconnect()
            if sound.Parent then sound.Volume=item.volume end
            S.footstepSaved[sound]=nil
        end
    end
    if not character then return end
    local candidates=character:GetDescendants()
    for sound in pairs(S.gameSoundCache) do
        if sound:IsDescendantOf(player) or sound:IsDescendantOf(game:GetService("SoundService")) then table.insert(candidates,sound) end
    end
    for _, sound in ipairs(candidates) do
        if S.isFootstepSound(sound) and not S.footstepSaved[sound] then
            local item = {volume=sound.Volume}
            S.footstepSaved[sound] = item
            item.connection = sound:GetPropertyChangedSignal("Volume"):Connect(function()
                if sound.Volume~=0 then item.volume=sound.Volume; sound.Volume=0 end
            end)
            sound.Volume = 0
        end
    end
end
ugKeepRootConnection(game.DescendantAdded:Connect(function(object)
    if S.footstepsMuted and S.isFootstepSound(object) then task.defer(S.refreshFootsteps) end
end))
S.footstepButton = makeButton(S.moveExtraSection, "Footsteps: ON", UDim2.fromOffset(180,30), UDim2.new(1,-192,0,8), COL.button)
S.connectAction(S.footstepButton,function()
    S.footstepsMuted = not S.footstepsMuted
    S.footstepButton.Text = S.footstepsMuted and "Footsteps: OFF" or "Footsteps: ON"
    if S.footstepsMuted then S.indexGameSounds();S.refreshFootsteps() else S.restoreFootsteps() end
end)
ugKeepRootConnection(player.CharacterAdded:Connect(function(character)
    S.restoreFootsteps()
    if S.footstepAdded then S.footstepAdded:Disconnect() end
    S.footstepAdded=character.DescendantAdded:Connect(function(object) if S.isFootstepSound(object) then S.refreshFootsteps() end end)
    S.refreshFootsteps()
end))
if player.Character then
    S.footstepAdded=player.Character.DescendantAdded:Connect(function(object) if S.isFootstepSound(object) then S.refreshFootsteps() end end)
end

S.shadowBindButton = makeButton(S.colorScroll, "Shadow key: " .. (S.shadowKey and S.shadowKey.Name or "—"), UDim2.new(1,-24,0,32), UDim2.fromOffset(12,516), COL.button)
S.colorScroll.CanvasSize = UDim2.fromOffset(0,570)
S.connectAction(S.shadowBindButton,function()
    S.waitingForPanelBind=false; S.cancelUiBind(); waitingForAnimationBind=nil
    S.recorder.rebind=nil; S.audio.rebind=nil
    S.shadowRebind=true
    S.shadowBindButton.Text="Press key · Delete clears · Esc cancels"
end)
function S.shadowInput(input, processed)
    if S.shadowRebind then
        if input.UserInputType~=Enum.UserInputType.Keyboard then return true end
        local key=input.KeyCode
        if key==Enum.KeyCode.Escape then S.shadowRebind=false
        elseif key==Enum.KeyCode.Delete or key==Enum.KeyCode.Backspace then S.shadowKey=nil; S.shadowRebind=false
        elseif key~=Enum.KeyCode.Unknown then
            local conflict=key==S.panelToggleKey or key==S.uiToggleKey
            for _, reserved in pairs(S.recorder.keys) do if reserved==key then conflict=true end end
            for _, binds in pairs(animationBinds) do for _, reserved in pairs(binds) do if reserved==key then conflict=true end end end
            for _, group in ipairs(S.audio.groups) do if group.key==key.Name then conflict=true end end
            if conflict then S.shadowBindButton.Text="Key already in use"; return true end
            S.shadowKey=key; S.shadowRebind=false
        end
        if not S.shadowRebind then S.shadowBindButton.Text="Shadow key: "..(S.shadowKey and S.shadowKey.Name or "—"); S.saveUserSettings() end
        return true
    end
    if S.waitingForPanelBind or S.waitingForUiBind or waitingForAnimationBind or S.recorder.rebind or S.audio.rebind then return false end
    if not processed and not UserInputService:GetFocusedTextBox() and S.shadowKey and input.KeyCode==S.shadowKey then S.toggleShadows(); return true end
    return false
end
if S.shluhaBuild then
    S.soul={active=false,bridge=false,hidden={},tracks={},prompts={},nextPrompt=0}
    title.Text="Tyomich Script💀"
    title.TextColor3=COL.accent
    subtitle.Text="SOUL STUDIO  /  0.4"
    subtitle.Position=UDim2.fromOffset(190,1)
    subtitle.Size=UDim2.fromOffset(220,40)
    gui:SetAttribute("LuminBuild","TyomichScript-0.4")
    sideTitle.Text="STUDIO / TOOLS"
    local old=(getgenv and getgenv() or _G).ShluhaScript
    if old and type(old.close)=="function" then pcall(old.close) end
    S.soulPage=createPage("Soul")
    S.soulPage.CanvasSize=UDim2.fromOffset(0,720)
    createTabButton("Soul","Soul",0)
    local navigation=Instance.new("ScrollingFrame")
    navigation.Name="StudioNavigation"
    navigation.BackgroundTransparency=1
    navigation.BorderSizePixel=0
    navigation.ScrollBarThickness=2
    navigation.ScrollBarImageColor3=COL.accent
    navigation.Position=UDim2.fromOffset(0,42)
    navigation.Size=UDim2.new(1,0,1,-180)
    navigation.CanvasSize=UDim2.fromOffset(0,12*42)
    navigation.Parent=sidebar
    for i,name in ipairs({"Soul","Morph","Animations","Custom","Camera","Movement","Recorder","NpcMorph","Sounds","NpcOverlay","Color","UI"}) do
        local b=tabButtons[name]
        if b then b.Parent=navigation;b.Position=UDim2.fromOffset(10,(i-1)*42);b.Size=UDim2.new(1,-20,0,36) end
    end
    local line=Instance.new("Frame")
    line.BorderSizePixel=0;line.BackgroundColor3=COL.accent
    line.Size=UDim2.new(1,0,0,2);line.Position=UDim2.new(0,0,1,-2);line.Parent=titlebar
    local hero=makeSection(S.soulPage,"SOUL / DIRECTOR MODE",UDim2.fromOffset(24,24),UDim2.new(1,-48,0,194))
    local gradient=Instance.new("UIGradient")
    gradient.Color=ColorSequence.new(Color3.fromRGB(255,220,209),Color3.fromRGB(139,179,191))
    gradient.Rotation=18;gradient.Parent=hero
    makeLabel(hero,"LEAVE THE BODY. KEEP THE PERFORMANCE.",UDim2.new(1,-32,0,32),UDim2.fromOffset(16,40),18,COL.accent,Enum.Font.GothamBold)
    makeLabel(hero,"All Lumin tools remain available. Morph, animate and record your local soul from the existing tabs.",UDim2.new(1,-32,0,48),UDim2.fromOffset(16,76),13,COL.subtext).TextWrapped=true
    S.soulStatus=makeLabel(hero,"BODY / CONNECTED",UDim2.new(1,-60,0,26),UDim2.fromOffset(40,146),13,COL.text,Enum.Font.GothamBold)
    local dot=Instance.new("Frame")
    dot.Size=UDim2.fromOffset(10,10);dot.Position=UDim2.fromOffset(18,154);dot.BackgroundColor3=COL.accent;dot.BorderSizePixel=0;dot.Parent=hero;corner(dot,5)
    local actions=makeSection(S.soulPage,"SESSION",UDim2.fromOffset(24,234),UDim2.new(1,-48,0,172))
    local enter=makeButton(actions,"ENTER SOUL",UDim2.new(0.5,-22,0,44),UDim2.fromOffset(16,42),COL.buttonSelected)
    local leave=makeButton(actions,"RETURN TO BODY",UDim2.new(0.5,-22,0,44),UDim2.new(0.5,6,0,42),COL.button)
    local fly=makeButton(actions,"FLIGHT + NOCLIP",UDim2.new(0.5,-22,0,38),UDim2.fromOffset(16,104),COL.button)
    local record=makeButton(actions,"OPEN RECORDER  /  Z · X",UDim2.new(0.5,-22,0,38),UDim2.new(0.5,6,0,104),COL.button)
    local hands=makeSection(S.soulPage,"REMOTE HANDS / EXPERIMENTAL",UDim2.fromOffset(24,422),UDim2.new(1,-48,0,216))
    makeLabel(hands,"Interaction approaches the target. Press the assigned key again to return early. NPC damage remains possible.",UDim2.new(1,-32,0,62),UDim2.fromOffset(16,40),13,COL.subtext).TextWrapped=true
    local bridge=makeButton(hands,"INTERACTION BRIDGE: OFF",UDim2.new(0.5,-22,0,40),UDim2.fromOffset(16,110),COL.button)
    local interact=makeButton(hands,"INTERACT / RETURN  ·  F",UDim2.new(0.5,-22,0,40),UDim2.new(0.5,6,0,110),COL.button)
    S.soulInteractButton=interact
    S.soulTarget=makeLabel(hands,"No item selected",UDim2.new(1,-32,0,34),UDim2.fromOffset(16,162),12,COL.dim)
    S.soul.shown={}
    local promptService=game:GetService("ProximityPromptService")
    ugKeepRootConnection(promptService.PromptShown:Connect(function(prompt) S.soul.shown[prompt]=true end))
    ugKeepRootConnection(promptService.PromptHidden:Connect(function(prompt) S.soul.shown[prompt]=nil end))
    local hint=makeButton(gui,"",UDim2.fromOffset(440,52),UDim2.new(1,-20,0,20),COL.buttonSelected)
    hint.AnchorPoint=Vector2.new(1,0)
    hint.Name="SoulInteractionHint"
    hint.Visible=false
    hint.ZIndex=50
    hint.TextWrapped=true
    function S.soulMessage(message)
        S.soulStatus.Text=message
        print("[SHLUHA SOUL] "..message)
    end
    function S.soulReturnTrip()
        local state=S.soul
        local trip=state.trip
        state.trip=nil
        if trip and trip.prompt and trip.prompt.Parent then pcall(function() trip.prompt:InputHoldEnd() end) end
        if trip and player.Character==trip.character and trip.root.Parent then
            pcall(function()
                trip.character:PivotTo(trip.origin)
                trip.root.AssemblyLinearVelocity=Vector3.zero
                trip.root.AssemblyAngularVelocity=Vector3.zero
                trip.root.Anchored=trip.anchored
            end)
        end
    end
    function S.stopSoul()
        local state=S.soul
        if not state.active then return end
        S.recorderStop()
        S.soulReturnTrip()
        ugStopFly();ugStopNoclip()
        if morphModel and not S.npcMorphTarget and not S.npcMorphBatch then removeMorph(false) end
        S.restoreDetachedVisibility()
        S.restoreFootsteps()
        game:GetService("ContextActionService"):UnbindAction("ShluhaSoulInput")
        state.active=false
        hint.Visible=false
        if state.controls then state.controls:Enable();state.controls=nil end
        if state.realRoot and state.realRoot.Parent then state.realRoot.Anchored=state.savedAnchored end
        for part,values in pairs(state.hidden) do
            if part.Parent then part.LocalTransparencyModifier=values.ltm;part.CastShadow=values.shadow end
        end
        state.hidden={}
        if Workspace.CurrentCamera.CameraSubject==state.humanoid then Workspace.CurrentCamera.CameraSubject=ugGetPlayerCameraSubject() end
        if state.actor then state.actor:Destroy();state.actor=nil end
        state.tracks={};state.currentTrack=nil;state.bridge=false
        bridge.Text="INTERACTION BRIDGE: OFF"
        S.moveSavedCharacter=nil
        S.soulMessage("BODY / CONNECTED")
    end
    function S.startSoul()
        local state=S.soul
        if state.active then return end
        local real=player.Character
        local root=real and real:FindFirstChild("HumanoidRootPart")
        local humanoid=real and real:FindFirstChildOfClass("Humanoid")
        if not root or not humanoid or humanoid.Health<=0 then S.soulMessage("Character not ready");return end
        S.recorderStop()
        ugStopFly();ugStopNoclip()
        if morphModel and not S.npcMorphTarget and not S.npcMorphBatch then removeMorph(false) end
        local saved={}
        local actor
        local ok,err=pcall(function()
            saved[real]=real.Archivable;real.Archivable=true
            for _,v in ipairs(real:GetDescendants()) do saved[v]=v.Archivable;v.Archivable=true end
            actor=real:Clone()
        end)
        for v,value in pairs(saved) do pcall(function() v.Archivable=value end) end
        if not ok or not actor then S.soulMessage(tostring(err or "Clone failed"));return end
        for _,v in ipairs(actor:GetDescendants()) do
            if v:IsA("LuaSourceContainer") or v:IsA("ProximityPrompt") or v:IsA("ClickDetector") or v:IsA("BillboardGui") then v:Destroy()
            elseif v:IsA("BasePart") then v.Anchored=false;v.CanTouch=false;v.LocalTransparencyModifier=0
            elseif v:IsA("Sound") then v:Stop() end
        end
        local h=actor:FindFirstChildOfClass("Humanoid")
        local r=actor:FindFirstChild("HumanoidRootPart")
        if not h or not r then actor:Destroy();S.soulMessage("Unsupported character rig");return end
        state.actor=actor;state.humanoid=h;state.root=r;state.real=real;state.realRoot=root
        state.savedAnchored=root.Anchored;state.tracks={};state.currentTrack=nil
        state.active=true
        actor.Name="__SHLUHA_SOUL";actor.Parent=Workspace;actor:PivotTo(real:GetPivot())
        h.DisplayDistanceType=Enum.HumanoidDisplayDistanceType.None
        h.AutoRotate=true
        local animator=h:FindFirstChildOfClass("Animator") or Instance.new("Animator",h)
        for _,v in ipairs(actor:GetDescendants()) do
            if v:IsA("Animation") and not state.tracks[v.Name:lower()] then
                local loaded,t=pcall(function() return animator:LoadAnimation(v) end)
                if loaded then state.tracks[v.Name:lower()]=t end
            end
        end
        local loaded,controls=pcall(function() return require(player.PlayerScripts:WaitForChild("PlayerModule",1)):GetControls() end)
        if loaded then state.controls=controls;controls:Disable() end
        game:GetService("ContextActionService"):BindActionAtPriority("ShluhaSoulInput",function() return Enum.ContextActionResult.Sink end,false,2500,Enum.PlayerActions.CharacterForward,Enum.PlayerActions.CharacterBackward,Enum.PlayerActions.CharacterLeft,Enum.PlayerActions.CharacterRight,Enum.PlayerActions.CharacterJump)
        state.active=true;root.Anchored=true
        S.moveSavedCharacter=nil
        ugApplyMovementStats()
        Workspace.CurrentCamera.CameraSubject=h
        S.soulMessage("SOUL / ACTIVE — WASD + Space. Morph through the Morph tab.")
    end
    function S.soulPromptPosition(prompt)
        local parent=prompt.Parent
        if parent and parent:IsA("Attachment") then return parent.WorldPosition end
        if parent and parent:IsA("BasePart") then return parent.Position end
        if parent and parent:IsA("Model") then return parent:GetPivot().Position end
    end
    function S.soulInteract()
        local state=S.soul
        local prompt=state.target
        if state.trip then S.soulReturnTrip();S.soulMessage("Body returned");return end
        if not state.active or not state.bridge then return end
        if not prompt or not prompt.Parent or not prompt.Enabled then S.soulMessage("No item in reach");return end
        if prompt.HoldDuration>10 then S.soulMessage("Long interactions not supported");return end
        local position=S.soulPromptPosition(prompt)
        if not position or (position-state.root.Position).Magnitude>prompt.MaxActivationDistance then return end
        local real=state.real
        local h=real:FindFirstChildOfClass("Humanoid")
        if player.Character~=real or not h or h.Health<=0 then return end
        local trip={character=real,root=state.realRoot,origin=real:GetPivot(),anchored=state.realRoot.Anchored,prompt=prompt,machine=prompt:FindFirstAncestor("Generators")~=nil}
        state.trip=trip
        task.spawn(function()
            local ok,err=xpcall(function()
                trip.root.Anchored=false
                real:PivotTo(state.actor:GetPivot())
                S.soulMessage("Approaching: waiting for game prompt")
                local readyUntil=os.clock()+2
                repeat task.wait(0.05) until state.shown[prompt] or os.clock()>=readyUntil or state.trip~=trip or not prompt.Parent or h.Health<=0
                if state.trip~=trip then return end
                if not prompt.Parent or h.Health<=0 then error("Interaction cancelled") end
                local currentPosition=S.soulPromptPosition(prompt)
                if not currentPosition or (trip.root.Position-currentPosition).Magnitude>prompt.MaxActivationDistance+1 then error("Move rejected by game") end
                if not state.shown[prompt] then error("Game prompt did not appear; body returned") end
                prompt:InputHoldBegin()
                local untilTime=os.clock()+prompt.HoldDuration+0.15
                repeat task.wait() until os.clock()>=untilTime or state.trip~=trip or not prompt.Parent or h.Health<=0
                if prompt.Parent then prompt:InputHoldEnd() end
                if state.trip==trip and trip.machine then
                    trip.deadline=os.clock()+30
                    S.soulMessage("Machine session: use game UI; F returns your body")
                    repeat task.wait(0.1) until state.trip~=trip or os.clock()>=trip.deadline or h.Health<=0 or not prompt.Parent
                elseif state.trip==trip then task.wait(0.35) end
            end,debug.traceback)
            if state.trip==trip then S.soulReturnTrip() end
            if not S.unloading then S.soulMessage(ok and "Interaction attempted; body returned" or tostring(err)) end
        end)
    end
    for _,v in ipairs(Workspace:GetDescendants()) do if v:IsA("ProximityPrompt") then S.soul.prompts[v]=true end end
    ugKeepRootConnection(Workspace.DescendantAdded:Connect(function(v) if v:IsA("ProximityPrompt") then S.soul.prompts[v]=true end end))
    ugKeepRootConnection(Workspace.DescendantRemoving:Connect(function(v) S.soul.prompts[v]=nil end))
    ugKeepRootConnection(player.CharacterAdded:Connect(function() S.stopSoul() end))
    S.connectAction(enter,function() local ok,err=pcall(S.startSoul);if not ok then S.stopSoul();S.soulMessage(tostring(err)) end end)
    S.connectAction(leave,S.stopSoul)
    S.connectAction(fly,function()
        if not S.soul.active then S.soulMessage("Enter Soul first");return end
        if S.moveFly then ugStopFly();ugStopNoclip() else ugStartFly();ugStartNoclip() end
    end)
    S.connectAction(record,function() selectTab("Recorder") end)
    S.connectAction(bridge,function() S.soul.bridge=not S.soul.bridge;if not S.soul.bridge then S.soulReturnTrip() end;bridge.Text=S.soul.bridge and "INTERACTION BRIDGE: ON" or "INTERACTION BRIDGE: OFF" end)
    S.connectAction(interact,S.soulInteract)
    S.connectAction(hint,S.soulInteract)
    ugKeepRootConnection(UserInputService.InputBegan:Connect(function(input,processed)
        if not processed and not UserInputService:GetFocusedTextBox() and input.KeyCode==(S.soulKey or Enum.KeyCode.F) and not S.bindingCapture and os.clock()-(S.soulKeyChangedAt or 0)>.2 then S.soulInteract() end
    end))
    ugKeepRootConnection(RunService.PreSimulation:Connect(function()
        local state=S.soul
        if not state.active or S.unloading then return end
        local rh=state.real:FindFirstChildOfClass("Humanoid")
        if player.Character~=state.real or not rh or rh.Health<=0 or not state.root.Parent or state.humanoid.Health<=0 then S.stopSoul();return end
        rh:Move(Vector3.zero);rh.Jump=false
        for _,v in ipairs(state.real:GetDescendants()) do
            if v:IsA("BasePart") then
                if not state.hidden[v] then state.hidden[v]={ltm=v.LocalTransparencyModifier,shadow=v.CastShadow} end
                v.LocalTransparencyModifier=1;v.CastShadow=false
            end
        end
        if state.trip or S.moveFly or S.freecamActive or S.spectateActive then state.humanoid:Move(Vector3.zero);return end
        local direction=Vector3.zero
        state.humanoid.Jump=false
        if not UserInputService:GetFocusedTextBox() then
            local cam=Workspace.CurrentCamera
            local f=Vector3.new(cam.CFrame.LookVector.X,0,cam.CFrame.LookVector.Z)
            if f.Magnitude>0.001 then f=f.Unit else f=Vector3.new(0,0,-1) end
            local right=Vector3.new(-f.Z,0,f.X)
            if UserInputService:IsKeyDown(Enum.KeyCode.W) then direction+=f end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then direction-=f end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then direction+=right end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then direction-=right end
            state.humanoid.Jump=UserInputService:IsKeyDown(Enum.KeyCode.Space)
        end
        if direction.Magnitude>1 then direction=direction.Unit end
        state.humanoid:Move(direction,false)
    end))
    ugKeepRootConnection(RunService.Heartbeat:Connect(function()
        local state=S.soul
        if not state.active or S.unloading then return end
        local speed=Vector3.new(state.root.AssemblyLinearVelocity.X,0,state.root.AssemblyLinearVelocity.Z).Magnitude
        local name=speed>20 and "run" or speed>0.5 and "walk" or "idle"
        local track=state.tracks[name]
        if track and track~=state.currentTrack then
            if state.currentTrack then state.currentTrack:Stop(0.18) end
            state.currentTrack=track;track.Looped=true;track:Play(0.18)
        end
        if os.clock()<state.nextPrompt then return end
        state.nextPrompt=os.clock()+0.25
        local best,dist=nil,32
        for prompt in pairs(state.prompts) do
            if prompt.Parent and prompt.Enabled and not prompt:IsDescendantOf(state.actor) and not prompt:IsDescendantOf(state.real) then
                local pos=S.soulPromptPosition(prompt)
                local distance=pos and (pos-state.root.Position).Magnitude or math.huge
                if distance<dist and distance<=prompt.MaxActivationDistance then best=prompt;dist=distance end
            end
        end
        state.target=best
        local caption=best and (best.ActionText~="" and best.ActionText or best.ObjectText~="" and best.ObjectText or best.Parent.Name) or "No interaction in reach"
        S.soulTarget.Text=caption..(best and "  /  "..string.format("%.1f studs",dist) or "")
        hint.Visible=false
        hint.Text=state.trip and ("F  /  RETURN TO BODY"..(state.trip.deadline and "  ·  "..math.ceil(math.max(0,state.trip.deadline-os.clock())).."s" or "  ·  approaching")) or state.bridge and ("F  /  "..caption) or (caption.."  /  enable Interaction Bridge in Soul")
        if not S.economyMode and S.uiAnimationsEnabled ~= false and S.soulPage.Visible and main.Visible and os.clock()>=(state.nextPulse or 0) then
            state.nextPulse=os.clock()+0.8
            S.animateUi(dot,{BackgroundTransparency=dot.BackgroundTransparency<0.3 and 0.65 or 0},0.7)
        end
    end))
    local entryScale=Instance.new("UIScale")
    entryScale.Name="StudioEntryScale"
    entryScale.Scale=1
    entryScale.Parent=content
    main:GetPropertyChangedSignal("Visible"):Connect(function()
        if main.Visible then entryScale.Scale=0.975;S.animateUi(entryScale,{Scale=1},0.28) end
    end)
    selectTab("Soul")
end
do
    local A={active=false,antiAfk=true,distance=18,auto=false}
    S.autoRecord=A
    local file="TyomichLiteCamera_"..tostring(game.PlaceId)..".json"
    pcall(function()
        if type(isfile)=="function" and isfile(file) then
            local raw=readfile(file);assert(#raw<4096)
            local data=HttpService:JSONDecode(raw)
            if data.version==1 then
                A.antiAfk=data.antiAfk~=false
                A.auto=data.auto==true
                if type(data.distance)=="number" and data.distance==data.distance then A.distance=math.clamp(data.distance,4,80) end
            end
        end
    end)
    local page=createPage("AutoRecord")
    page.CanvasSize=UDim2.fromOffset(0,540)
    createTabButton("AutoRecord","AUTO RECORD",580)
    local section=makeSection(page,"CAMERA FOLLOW",UDim2.fromOffset(24,24),UDim2.new(1,-48,0,490))
    local status=makeLabel(section,"Choose an NPC / player, then start following.",UDim2.new(1,-32,0,48),UDim2.fromOffset(16,38),12,COL.text)
    status.TextWrapped=true
    local chooseButton=makeButton(section,"CHOOSE NPC / PLAYER",UDim2.new(.5,-24,0,38),UDim2.fromOffset(16,100),COL.button)
    local use=makeButton(section,"USE SELECTED TARGET",UDim2.new(.5,-24,0,38),UDim2.new(.5,8,0,100),COL.button)
    local start=makeButton(section,"START FOLLOW",UDim2.new(.5,-24,0,42),UDim2.fromOffset(16,152),COL.accent)
    local stop=makeButton(section,"STOP",UDim2.new(.5,-24,0,42),UDim2.new(.5,8,0,152),COL.button)
    createSlider(section,"Camera distance",4,80,1,A.distance,210,function(value)
        A.distance=value
    end)
    local afk=makeButton(section,"",UDim2.new(.5,-24,0,36),UDim2.fromOffset(16,286),COL.button)
    local save=makeButton(section,"SAVE SETTINGS",UDim2.new(.5,-24,0,36),UDim2.new(.5,8,0,286),COL.button)
    local mode=makeButton(section,"",UDim2.new(1,-32,0,36),UDim2.fromOffset(16,336),COL.button)
    local hint=makeLabel(section,"Selected: follow one target. Monkey Chase: the existing automatic chase detector. Animations stay under game control. Start OBS separately.",UDim2.new(1,-32,0,72),UDim2.fromOffset(16,390),11,COL.dim)
    hint.TextWrapped=true
    local function refresh()
        afk.Text=A.antiAfk and "ANTI-AFK: ON" or "ANTI-AFK: OFF"
        mode.Text=A.auto and "TARGET: MONKEY CHASE" or "TARGET: SELECTED"
    end
    local models,motion,evidence={},{},{}
    local current,challenger,selectedAt,lostAt
    local alive,paused=true,true
    local cameraState={enabled=true,distance=A.distance,saved={},elapsed=0}
    local fade=Instance.new("Frame");fade.Name="AutoRecordCut";fade.Size=UDim2.fromScale(1,1);fade.BackgroundColor3=Color3.new(0,0,0);fade.BackgroundTransparency=1;fade.BorderSizePixel=0;fade.Active=false;fade.ZIndex=5;fade.Parent=gui
    local cameraBind="TyomichAutoRecordCamera"
    local function note(text) status.Text=text end
    local function root(model) return model and model.Parent and getSpectateRoot(model) end
local function discover()
	local found, seen = {}, {}
	for _, folder in ipairs(Workspace:GetChildren()) do
		local name = folder.Name:lower()
		if name:match("monster$") or name == "sandman/ashy" then
			for _, object in ipairs(folder:GetDescendants()) do
				if object:IsA("Humanoid") and object.Parent and object.Parent:IsA("Model") then
					local model = object.Parent
					if root(model) and not seen[model] then
						seen[model] = true
						table.insert(found, model)
					end
				end
			end
		end
	end
	models = found
	for model in pairs(evidence) do if not seen[model] then evidence[model] = nil end end
end
local function movement(model, part, now)
	local before = motion[model]
	local position = part.Position
	local velocity = Vector3.zero
	local ready = false
	if before then
		local dt = now - before.time
		if dt > 0 and dt < 1 then
			local raw = (position - before.position) / dt
			if raw.Magnitude < 150 then
				velocity = before.velocity:Lerp(raw, 1 - math.exp(-7 * dt))
				ready = true
			end
		end
	end
	motion[model] = {position = position, velocity = velocity, time = now}
	return Vector3.new(velocity.X, 0, velocity.Z), ready
end

local function restoreCamera()
	for camera, saved in pairs(cameraState.saved) do
		pcall(function()
			local subject = saved.subject
			if not subject or not subject.Parent then
				subject = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
			end
			camera.CameraSubject = subject
			camera.CameraType = saved.kind
			camera.CFrame = saved.cf
			camera.Focus = saved.focus
		end)
	end
	table.clear(cameraState.saved)
	cameraState.target = nil
	cameraState.pending = nil
	cameraState.position = nil
	cameraState.focus = nil
	cameraState.yaw = nil
	cameraState.transition = nil

	cameraState.anchor = nil
	cameraState.farTime = 0
	cameraState.turning = false
	cameraState.turnTime = 0
	cameraState.intensity = nil
	cameraState.lastRoot = nil
	cameraState.velocity = nil
	cameraState.boom = nil
	cameraState.clearTime = 0
	cameraState.aim = nil
	cameraState.offset = nil
	fade.BackgroundTransparency = 1
end

local function cameraStep(dt)
	if not alive or paused or not cameraState.enabled or not current then
		if next(cameraState.saved) then restoreCamera() end
		return
	end
	local wanted = current.model
	if not wanted:IsDescendantOf(Workspace) or not root(wanted) then restoreCamera(); return end
	dt = math.clamp(dt, 0, 0.1)
	if cameraState.target ~= wanted and cameraState.pending ~= wanted then
		cameraState.pending = wanted
		cameraState.transition = 0
	end
	if cameraState.transition then
		cameraState.transition += dt
		local elapsed = cameraState.transition
		if elapsed >= 0.16 and cameraState.pending then
			cameraState.target = cameraState.pending
			cameraState.pending = nil
			cameraState.position, cameraState.focus, cameraState.yaw = nil, nil, nil
	cameraState.anchor = nil
	cameraState.farTime = 0
	cameraState.turning = false
	cameraState.turnTime = 0
	cameraState.intensity = nil
	cameraState.lastRoot = nil
	cameraState.velocity = nil
	cameraState.boom = nil
	cameraState.clearTime = 0
	cameraState.aim = nil
	cameraState.offset = nil

		end
		fade.BackgroundTransparency = elapsed < 0.16 and 1 - elapsed / 0.16 or math.clamp((elapsed - 0.16)/0.2, 0, 1)
		if elapsed >= 0.36 then cameraState.transition = nil; fade.BackgroundTransparency = 1 end
	end
	local target = cameraState.target
	local r = target and target:IsDescendantOf(Workspace) and root(target)
	if not r then return end
	local camera = Workspace.CurrentCamera
	if not camera then return end
	if not cameraState.saved[camera] then
		cameraState.saved[camera] = {kind=camera.CameraType, subject=camera.CameraSubject, cf=camera.CFrame, focus=camera.Focus}
	end
	local previous = cameraState.lastRoot
	local delta = previous and r.Position - previous or Vector3.zero
	local snap = not previous
	cameraState.lastRoot = r.Position
	local measured = not snap and dt > 0 and delta / dt or Vector3.zero
	if measured.Magnitude > 150 then measured = cameraState.velocity or Vector3.zero end
	measured = Vector3.new(measured.X, 0, measured.Z)
	cameraState.velocity = snap and measured or (cameraState.velocity or measured):Lerp(measured, 1-math.exp(-9*dt))
	local velocity = cameraState.velocity
	local speed = velocity.Magnitude
	local rawAnchor = r.Position + Vector3.new(0, 1.8, 0)
	local anchor = cameraState.anchor or rawAnchor
	local error = rawAnchor - anchor
	cameraState.farTime = error.Magnitude > 65 and (cameraState.farTime or 0) + dt or 0
	if cameraState.farTime > 0.3 then snap = true end
	if snap then
		anchor = rawAnchor
		cameraState.farTime = 0
	else
		local basis = CFrame.Angles(0, cameraState.yaw or 0, 0)
		local localError = basis:VectorToObjectSpace(error)
		local room = math.clamp(cameraState.distance*0.045, 0.35, 1.4)
		local function outside(value, radius)
			return math.sign(value)*math.max(0, math.abs(value)-radius)
		end
		local correction = basis:VectorToWorldSpace(Vector3.new(outside(localError.X, room), outside(localError.Y, 0.35), outside(localError.Z, 0.45)))
		local step = correction * (1-math.exp(-10*dt))
		
		anchor += step
        local lag=rawAnchor-anchor
        if lag.Magnitude>1.5 then anchor=rawAnchor-lag.Unit*1.5 end
	end
	cameraState.anchor = anchor
	local forward = speed > 3 and velocity.Unit or Vector3.new(r.CFrame.LookVector.X, 0, r.CFrame.LookVector.Z)
	if forward.Magnitude < 0.01 then forward = Vector3.new(0, 0, -1) end
	local desiredYaw = math.atan2(-forward.X, -forward.Z)
	if cameraState.yaw == nil or snap then
		cameraState.yaw = desiredYaw
		cameraState.turning = false
		cameraState.turnTime = 0
	end
	local change = math.atan2(math.sin(desiredYaw-cameraState.yaw), math.cos(desiredYaw-cameraState.yaw))
	if speed > 4 then
		if math.abs(change) > math.rad(12) then
			cameraState.turnTime = (cameraState.turnTime or 0) + dt
		else
			cameraState.turnTime = 0
		end
		if cameraState.turnTime >= 0.12 or math.abs(change) > math.rad(45) then cameraState.turning = true end
		if math.abs(change) < math.rad(4) then cameraState.turning = false end
		if cameraState.turning then
			local response = 4 + math.min(6, math.abs(change)*4)
			cameraState.yaw += math.clamp(change*(1-math.exp(-response*dt)), -3.8*dt, 3.8*dt)
		end
	else
		cameraState.turning = false
		cameraState.turnTime = 0
	end
	local rotation = CFrame.Angles(0, cameraState.yaw, 0)
	local aim = Vector3.zero
	cameraState.aim = aim
	cameraState.focus = rawAnchor
	local distance = cameraState.distance
	local height = math.max(3, distance*0.19)
	local offset = -rotation.LookVector*distance + Vector3.new(0,height,0)
	cameraState.offset = snap and offset or (cameraState.offset or offset):Lerp(offset, 1-math.exp(-10*dt))
	cameraState.elapsed += dt
	if not cameraState.params or cameraState.elapsed >= 0.5 then
		cameraState.elapsed = 0
		local ignore = {}
		for _, model in ipairs(models) do table.insert(ignore, model) end
        if morphModel then table.insert(ignore,morphModel) end
        for _,record in pairs(S.multiMorphs) do table.insert(ignore,record.model) end
        if S.npcMorphBatch then for _,record in pairs(S.npcMorphBatch.records) do table.insert(ignore,record.model) end end
		for _, p in ipairs(Players:GetPlayers()) do if p.Character then table.insert(ignore, p.Character) end end
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = ignore
		params.RespectCanCollide = true
		params.IgnoreWater = true
		cameraState.params = params
	end
	local tether = anchor - rawAnchor
	if tether.Magnitude > 0.05 then
		local obstruction = Workspace:Spherecast(rawAnchor, 0.65, tether, cameraState.params)
		local line = Workspace:Raycast(rawAnchor, tether, cameraState.params)
		local safe = tether.Magnitude
		if obstruction then safe = math.min(safe, math.max(0, obstruction.Distance-0.3)) end
		if line then safe = math.min(safe, math.max(0, line.Distance-0.95)) end
		anchor = rawAnchor + tether.Unit*safe
		cameraState.anchor = anchor
	end
	local direction = cameraState.offset
	local length = direction.Magnitude
	local unit = direction.Unit
	local hit = Workspace:Spherecast(anchor, 0.65, direction, cameraState.params)
	local ray = Workspace:Raycast(anchor, direction, cameraState.params)
	local available = length
	if hit then available = math.min(available, math.max(0.15, hit.Distance-0.3)) end
	if ray then available = math.min(available, math.max(0.15, ray.Distance-0.95)) end
	local boom = cameraState.boom or available
	if snap or available < boom then
		boom = available
		cameraState.clearTime = 0
	elseif available > boom + 0.3 then
		cameraState.clearTime = (cameraState.clearTime or 0) + dt
		if cameraState.clearTime > 0.1 then
			boom += math.min(available-boom, (18 + (available-boom)*2)*dt)
		end
	else
		cameraState.clearTime = 0
	end
	cameraState.boom = math.min(boom, available)
	local position = anchor + unit * cameraState.boom
	local close = math.clamp(cameraState.boom/5, 0, 1)
	local look = rawAnchor
	cameraState.position = position
	if (position-look).Magnitude > 0.01 then
		camera.CameraType = Enum.CameraType.Scriptable
		camera.CFrame = CFrame.lookAt(position, look)
		camera.Focus = CFrame.new(look)
	end
end

local function choose(row, now)
	current = row
	selectedAt = now
	lostAt, challenger = nil, nil
	note("SELECT " .. row.model:GetFullName() .. " -> " .. row.player.Name .. string.format(" score=%.1f distance=%.1f", row.score, row.distance))
end
local function tick(now, dt)
	local people, present = {}, {}
	local ignore = {}
	for _, model in ipairs(models) do table.insert(ignore, model) end
	for _, p in ipairs(Players:GetPlayers()) do
		local character = p.Character
		local r = root(character)
		local h = character and character:FindFirstChildOfClass("Humanoid")
		if r and h and h.Health > 0 then
			local velocity, ready = movement(character, r, now)
			table.insert(people, {player=p, root=r, velocity=velocity, ready=ready})
			present[character] = true
			table.insert(ignore, character)
		end
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	params.IgnoreWater = true
	params.RespectCanCollide = true
	local rows = {}
	for _, model in ipairs(models) do
		local r = root(model)
		local h = model:FindFirstChildOfClass("Humanoid")
		if model:IsDescendantOf(Workspace) and r and h and h.Health > 0 then
			present[model] = true
			local velocity, ready = movement(model, r, now)
			local state = evidence[model] or {}
			evidence[model] = state
			local best
			local seen = {}
			for _, person in ipairs(people) do
				local difference = person.root.Position - r.Position
				local distance = difference.Magnitude
				local flat = Vector3.new(difference.X, 0, difference.Z)
				if distance <= 150 and math.abs(difference.Y) < 28 and flat.Magnitude > 0.1 then
					local direction = flat.Unit
					local speed = velocity.Magnitude
					local toward = velocity:Dot(direction)
					local alignment = speed > 0.1 and toward / speed or 0
					local origin = r.Position + Vector3.new(0, 2, 0)
					local visible = Workspace:Raycast(origin, person.root.Position + Vector3.new(0, 2, 0) - origin, params) == nil
					local confirmed = ready and person.ready and speed > 5 and toward > 3 and alignment > 0.35
					local age = state[person.player] or 0
					age = confirmed and math.min(4, age + dt) or math.max(0, age - dt * 2)
					state[person.player] = age
					seen[person.player] = true
					local score = 35 * (1 - distance/150) + 25 * math.max(0, alignment) + 15 * math.min(speed/40, 1) + (visible and 10 or 0) + 10 * age/4 + 5 * math.min(person.velocity.Magnitude/40, 1)
					if age < 1 or not ready or speed < 3 then score = 0 end
					local row = {model=model, player=person.player, score=score, distance=distance, visible=visible, age=age, speed=speed}
					if not best or row.score > best.score then best = row end
				end
			end
			for p in pairs(state) do if not seen[p] then state[p] = nil end end
			if best and best.score >= 45 then table.insert(rows, best) end
		end
	end
	for model in pairs(motion) do if not present[model] then motion[model] = nil end end
	table.sort(rows, function(a,b) return a.score > b.score end)
	local best, matching = rows[1], nil
	if current then
		for _, row in ipairs(rows) do if row.model == current.model then matching = row; break end end
		if matching then
			if matching.player ~= current.player then note("TARGET? " .. matching.model.Name .. " -> " .. matching.player.Name) end
			current = matching
			lostAt = nil
		else
			lostAt = lostAt or now
		end
	end
	local missing = current and (not current.model:IsDescendantOf(Workspace) or not root(current.model))
	if not current or missing or (lostAt and now-lostAt >= 15) then
		if best then choose(best, now)
		elseif missing then note("WAIT: model missing"); current = nil end
	end
end

    local function selected()
        if S.playerMorphMode and S.playerMorphSelection then return S.playerMorphSelection.Character end
        return S.npcMorphSelection or S.spectateTarget
    end
    local function setTarget()
        local target=selected()
        if not target or not target.Parent or not getSpectateRoot(target) then status.Text="Select an NPC / player in NPC / PLAYERS or CAMERA first.";return end
        if A.active then S.autoRecordStop() end
        A.target=target;status.Text="Selected: "..target.Name
    end
    function S.autoRecordStop()
        if not A.active then return end
        A.active=false;paused=true
        if A.step then A.step:Disconnect();A.step=nil end
        RunService:UnbindFromRenderStep(cameraBind)
        restoreCamera()
        if A.wasThird~=nil then thirdPerson=A.wasThird;A.wasThird=nil;ugEnsureCameraRender() end
        models={};motion={};evidence={};current=nil
        status.Text="Stopped. Camera released."
        start.Text="START FOLLOW"
    end
    S.connectAction(chooseButton,function() selectTab("NpcMorph") end)
    S.connectAction(use,setTarget)
    S.connectAction(start,function()
        if A.active then return end
        if not A.auto and (not A.target or not A.target.Parent) then setTarget() end
        local target=A.target
        if not A.auto and not root(target) then return end
        local old=rawget(_G,"MonkeyDirectorStop");if type(old)=="function" then pcall(old) end
        ugStopFreecam(false);ugStopSpectate()
        A.wasThird=thirdPerson;thirdPerson=false;ugEnsureCameraRender()
        models={};motion={};evidence={};current=nil;lostAt=nil
        if not A.auto then current={model=target} end
        A.active=true;paused=false;A.scan=0;A.elapsed=0
        cameraState.distance=A.distance
        RunService:BindToRenderStep(cameraBind,Enum.RenderPriority.Camera.Value+2,function(dt)
            local ok,err=pcall(cameraStep,dt)
            if not ok then S.autoRecordStop();note("Camera error: "..tostring(err)) end
        end)
        A.step=RunService.Heartbeat:Connect(function(dt)
            A.elapsed+=dt;if A.elapsed<.15 then return end
            local elapsed=math.min(A.elapsed,.75);A.elapsed=0
            local ok,err=pcall(function()
                local now=os.clock();cameraState.distance=A.distance
                if A.auto then
                    if now>=A.scan then discover();A.scan=now+2 end
                    tick(now,elapsed)
                elseif not root(target) then S.autoRecordStop();note("Target removed. Select another NPC.");return end
                if current and root(current.model) then status.Text="Following: "..current.model.Name.." / camera only"
                else status.Text="Waiting for a confirmed monkey chase..." end
            end)
            if not ok then S.autoRecordStop();note("Director error: "..tostring(err)) end
        end)
        status.Text=A.auto and "Waiting for a confirmed monkey chase..." or "Following: "..target.Name.." / camera only"
        start.Text="FOLLOWING"
    end)
    S.connectAction(stop,S.autoRecordStop)
    S.connectAction(mode,function() S.autoRecordStop();A.auto=not A.auto;refresh() end)
    S.connectAction(afk,function() A.antiAfk=not A.antiAfk;refresh() end)
    S.connectAction(save,function()
        local ok,err=pcall(function()
            assert(type(writefile)=="function","File saving unavailable")
            writefile(file,HttpService:JSONEncode({version=1,distance=A.distance,antiAfk=A.antiAfk,auto=A.auto}))
        end)
        status.Text=ok and "Camera preferences saved for this game." or "Save failed: "..tostring(err)
    end)
    local last=-math.huge
    ugKeepRootConnection(player.Idled:Connect(function()
        if not A.active or not A.antiAfk or S.unloading or os.clock()-last<60 then return end
        last=os.clock()
        local ok,err=pcall(function()
            local user=game:GetService("VirtualUser")
            user:CaptureController()
            user:ClickButton2(Vector2.zero,Workspace.CurrentCamera and Workspace.CurrentCamera.CFrame or CFrame.identity)
        end)
        if not ok then status.Text="Anti-AFK unavailable: "..tostring(err) end
    end))
    refresh()
end
function S.stopAvatarMirror()
    local mirror=S.avatarMirror
    S.avatarMirror=nil
    if not mirror then return end
    if mirror.connection then mirror.connection:Disconnect() end
    for _,pair in ipairs(mirror.pairs) do
        if pair.target.Parent then if pair.target:IsA("Motor6D") then pair.target.C0=pair.base end;pair.target.Transform=CFrame.identity end
    end
    for _,connection in ipairs(mirror.sourceConnections or {}) do connection:Disconnect() end
end
function S.startAvatarMirror(animator)
    S.stopAvatarMirror()
    S.avatarMirror={animator=animator,pairs={},sourceConnections={},dirty=true}
    S.avatarMirror.connection=RunService.PreSimulation:Connect(function()
        if S.unloading or not animator:IsDescendantOf(Workspace) then S.stopAvatarMirror();return end
        local ok,err=pcall(S.stepAvatarMirror)
        if not ok then S.avatarPoseError=tostring(err) end
    end)
end
function S.stepAvatarMirror()
    local mirror=S.avatarMirror
    if not mirror or mirror.animator~=morphAnimator then return end
    mirror.frames=(mirror.frames or 0)+1
    local character=S.npcMorphTarget or S.controlledCharacter()
    if mirror.character~=character then
        for _,connection in ipairs(mirror.sourceConnections) do connection:Disconnect() end
        mirror.sourceConnections={}
        mirror.character=character
        mirror.dirty=true
        if character then
            for _,signal in ipairs({character.DescendantAdded,character.DescendantRemoving}) do
                mirror.sourceConnections[#mirror.sourceConnections+1]=signal:Connect(function(object)
                    if (object:IsA("Motor6D") or object:IsA("AnimationConstraint") or object:IsA("Attachment")) then mirror.dirty=true end
                end)
            end
        end
    end
    if mirror.dirty then
        mirror.dirty=false
        for _,pair in ipairs(mirror.pairs) do
            if pair.target.Parent then if pair.target:IsA("Motor6D") then pair.target.C0=pair.base end;pair.target.Transform=CFrame.identity end
        end
        mirror.pairs={}
        local function key(joint)
            if joint.Part0 and joint.Part1 then return joint.Part0.Name.."/"..joint.Part1.Name end
        end
        local sources={}
        if character then
            for _,joint in ipairs(character:GetDescendants()) do
                if (joint:IsA("Motor6D") or joint:IsA("AnimationConstraint")) then local k=key(joint);if k then sources[k]=joint end end
            end
        end
        if morphModel then
            for _,joint in ipairs(morphModel:GetDescendants()) do
                if (joint:IsA("Motor6D") or joint:IsA("AnimationConstraint")) then
                    local k=key(joint)
                    local source=k and sources[k]
                    if joint:IsA("AnimationConstraint") then joint.IsKinematic=true end
                    if source then mirror.pairs[#mirror.pairs+1]={source=source,target=joint,base=joint.C0,sourceBase=source.C0,sourceEnd=source.C1}
                    else joint.Transform=CFrame.identity end
                end
            end
        end
        if character and #mirror.pairs==0 then warn("[AVATAR POSE] No compatible animation joints found") end
    end
    for _,pair in ipairs(mirror.pairs) do
        if pair.source.Parent and pair.target.Parent and pair.source.Part0 and pair.source.Part1 then
            local pose=pair.sourceBase:Inverse()*pair.source.Part0.CFrame:ToObjectSpace(pair.source.Part1.CFrame)*pair.sourceEnd
            if pair.target:IsA("AnimationConstraint") then
                pair.target.IsKinematic=true
                pair.target.Transform=pair.source.Transform
            else
                pair.target.Transform=CFrame.identity
                pair.target.C0=pair.base*pose
            end
        else mirror.dirty=true end
    end
end
function S.stopAvatarPhysics()
    S.stopAvatarMirror()
    if S.avatarPhysicsConnection then S.avatarPhysicsConnection:Disconnect();S.avatarPhysicsConnection=nil end
end
do
    local skins={serial=0,entries={},busy=false}
    S.avatarSkins=skins
    local service=game:GetService("Players")
    local json=game:GetService("HttpService")
    local properties={"Shirt","Pants","GraphicTShirt","Face","Head","Torso","LeftArm","RightArm","LeftLeg","RightLeg","BodyTypeScale","DepthScale","HeadScale","HeightScale","ProportionScale","WidthScale","ClimbAnimation","FallAnimation","IdleAnimation","JumpAnimation","RunAnimation","SwimAnimation","WalkAnimation"}
    local colors={"HeadColor","TorsoColor","LeftArmColor","RightArmColor","LeftLegColor","RightLegColor"}
    local avatarPage=createPage("Avatar");createTabButton("Avatar","AVATAR",0)
    avatarPage.CanvasSize=UDim2.fromOffset(0,900)
    makeLabel(avatarPage,"AVATAR",UDim2.new(1,-48,0,30),UDim2.fromOffset(24,20),22,COL.text,Enum.Font.GothamBold)
    makeLabel(avatarPage,"Load a look. Keep a snapshot. Use your own movement and animations.",UDim2.new(1,-48,0,24),UDim2.fromOffset(24,55),12,COL.subtext)
    local window=makeSection(avatarPage,"LOAD FROM ROBLOX",UDim2.fromOffset(24,94),UDim2.new(1,-48,0,180))
    window.Name="AvatarSkins"
    local manage=makeSection(avatarPage,"CURRENT LOOK / SAVE",UDim2.new(.55,6,0,294),UDim2.new(.45,-30,0,580))
    local details=makeLabel(manage,"No avatar loaded yet.",UDim2.new(1,-32,0,62),UDim2.fromOffset(16,40),12,COL.text);details.TextWrapped=true;details.TextYAlignment=Enum.TextYAlignment.Top
    local function textBox(parent,placeholder,y)
        local box=Instance.new("TextBox")
        box.Size=UDim2.new(1,-32,0,36);box.Position=UDim2.fromOffset(16,y);box.BackgroundColor3=COL.button;box.TextColor3=COL.text;box.PlaceholderColor3=COL.dim;box.PlaceholderText=placeholder;box.Text="";box.ClearTextOnFocus=false;box.TextSize=13;box.Font=Enum.Font.Gotham;box.TextXAlignment=Enum.TextXAlignment.Left;box.Parent=parent;corner(box,7)
        local padding=Instance.new("UIPadding");padding.PaddingLeft=UDim.new(0,10);padding.PaddingRight=UDim.new(0,10);padding.Parent=box
        return box
    end
    local username=textBox(window,"Username, not display name",40);username.Size=UDim2.new(.6,-24,0,38)
    local filename=textBox(manage,"Name for your saved look",124)
    makeLabel(manage,"SNAPSHOT NAME",UDim2.new(1,-32,0,20),UDim2.fromOffset(16,102),10,COL.subtext)
    local status=makeLabel(window,"Ready. Your original character remains unchanged on the server.",UDim2.new(1,-32,0,48),UDim2.fromOffset(16,122),12,COL.subtext);status.TextWrapped=true;status.TextYAlignment=Enum.TextYAlignment.Top
    local controls={};local refreshSkins
    local function btn(title,x,y,width,callback)
        local parent,position,size=manage,UDim2.fromOffset(16,174),UDim2.new(1,-32,0,36)
        if title=="LOAD USER + APPLY" then parent=window;position=UDim2.new(.6,8,0,40);size=UDim2.new(.4,-24,0,38)
        elseif title=="REMOVE SKIN" then position=UDim2.fromOffset(16,282)
        elseif title=="LOAD SAVED + APPLY" then position=UDim2.fromOffset(16,228)
        elseif title=="COPY POSE REPORT" then position=UDim2.fromOffset(16,524)
        elseif title=="Morphs" then position=UDim2.fromOffset(16,478) end
        local b=makeButton(parent,title,size,position,title=="LOAD USER + APPLY" and COL.buttonSelected or COL.button)
        b.TextSize=12;controls[title]=b;S.connectAction(b,callback);return b
    end
    local function current(ticket)
        return not S.unloading and skins.ticket==ticket and skins.busy
    end
    local function attempt(callback)
        if S.unloading then return end
        if skins.busy then
            skins.ticket=(skins.ticket or 0)+1
            skins.busy=false
            status.Text="Cancelled. Press LOAD again to retry."
            return
        end
        skins.ticket=(skins.ticket or 0)+1
        local ticket=skins.ticket
        skins.busy=true;status.Text="Loading... Click again to cancel."
        task.delay(45,function()
            if current(ticket) then
                skins.ticket+=1;skins.busy=false
                status.Text="Roblox request timed out. Press LOAD to retry."
            end
        end)
        task.spawn(function()
            local ok,err=pcall(callback,ticket)
            if not current(ticket) then return end
            skins.busy=false
            if not ok then status.Text="Error: "..tostring(err) end
        end)
    end
    local function encode(description,source)
        local data={version=1,username=source,properties={},colors={},accessories={}}
        for _,key in ipairs(properties) do data.properties[key]=description[key] end
        for _,key in ipairs(colors) do local c=description[key];data.colors[key]={c.R,c.G,c.B} end
        for _,entry in ipairs(description:GetAccessories(true)) do
            local copy={}
            for key,value in pairs(entry) do copy[key]=typeof(value)=="EnumItem" and value.Name or value end
            data.accessories[#data.accessories+1]=copy
        end
        return data
    end
    local function decode(data)
        assert(type(data)=="table" and data.version==1 and type(data.properties)=="table" and type(data.colors)=="table" and type(data.accessories)=="table","Invalid snapshot")
        local d=Instance.new("HumanoidDescription")
        local ok,err=pcall(function()
            for _,key in ipairs(properties) do if data.properties[key]~=nil then d[key]=data.properties[key] end end
            for _,key in ipairs(colors) do local c=data.colors[key];if c then d[key]=Color3.new(c[1],c[2],c[3]) end end
            local accessories={}
            for _,entry in ipairs(data.accessories) do
                local copy=table.clone(entry);copy.AccessoryType=Enum.AccessoryType[copy.AccessoryType];assert(copy.AccessoryType,"Unknown accessory type");accessories[#accessories+1]=copy
            end
            d:SetAccessories(accessories,true)
        end)
        if not ok then d:Destroy();error(err) end
        return d
    end
    local function install(data,ticket)
        if not current(ticket) then return end
        status.Text="Building avatar on Roblox... Click LOAD to cancel."
        local description=decode(data)
        local character=S.controlledCharacter()
        local humanoid=character and character:FindFirstChildOfClass("Humanoid")
        local rig=humanoid and humanoid.RigType or Enum.HumanoidRigType.R15
        local ok,model=pcall(function() return service:CreateHumanoidModelFromDescriptionAsync(description,rig) end)
        description:Destroy()
        if not current(ticket) then if ok and model then model:Destroy() end;return end
        assert(ok,tostring(model))
        status.Text="Applying avatar..."
        for _,object in ipairs(model:GetDescendants()) do if object:IsA("LuaSourceContainer") then object:Destroy() end end
        skins.serial+=1
        local name="[Skin] "..tostring(data.username or "Saved").." #"..skins.serial
        customMorphSources[name]=model
        customMorphMeta[name]={modelName=name,sourceType="Avatar snapshot",stats=getCustomModelStats(model)}
        skins.entries[name]=model
        skins.data=data
        details.Text=tostring(data.username or "Saved avatar").."\n"..#data.accessories.." accessories / "..rig.Name.."\nSnapshot ready to save"
        rebuildMorphList(true);rebuildAnimationNpcList(true);rebuildCustomList()
        S.npcMorphPending=nil
        selectMorph(name);applyMorph(name)
        if morphActiveName==name and morphModel then skins.active=name;status.Text="Applied. Respawn restore follows the setting below."
        else status.Text="Loaded into Morph list; apply when your character is ready." end
    end
    btn("COPY POSE REPORT",12,4,300,function()
        local lines={"=== AVATAR POSE REPORT ===","PlaceId="..game.PlaceId}
        local mirror=S.avatarMirror
        lines[#lines+1]="Active="..tostring(skins.active).." Mirror="..tostring(mirror~=nil).." Error="..tostring(S.avatarPoseError)
        lines[#lines+1]="Frames="..tostring(mirror and mirror.frames).." Pairs="..tostring(mirror and #mirror.pairs).." AnimatorMatches="..tostring(mirror and mirror.animator==morphAnimator)
        for _,entry in ipairs({{"SOURCE",S.npcMorphTarget or S.controlledCharacter()},{"TARGET",morphModel}}) do
            local model=entry[2]
            lines[#lines+1]=entry[1].."="..(model and model:GetFullName() or "nil")
            if model then
                local humanoid=model:FindFirstChildOfClass("Humanoid")
                lines[#lines+1]="Rig="..tostring(humanoid and humanoid.RigType)
                local count=0
                for _,joint in ipairs(model:GetDescendants()) do
                    if (joint:IsA("Motor6D") or joint:IsA("AnimationConstraint")) then
                        count+=1
                        if count<=22 then
                            local _,angle=joint.Transform:ToAxisAngle()
                            lines[#lines+1]=joint.ClassName.." "..joint.Name.." "..tostring(joint.Part0 and joint.Part0.Name).." -> "..tostring(joint.Part1 and joint.Part1.Name).." enabled="..tostring(joint.Enabled).." angle="..string.format("%.3f",angle)
                        end
                    end
                end
                lines[#lines+1]="AnimationJoints="..count
                local animator=humanoid and humanoid:FindFirstChildOfClass("Animator")
                if animator then
                    for _,track in ipairs(animator:GetPlayingAnimationTracks()) do lines[#lines+1]="Track="..track.Name.." time="..string.format("%.2f",track.TimePosition) end
                end
            end
        end
        local report=table.concat(lines,"\n")
        print(report)
        local ok=type(setclipboard)=="function" and pcall(setclipboard,report)
        status.Text=ok and "Pose report copied. Send it to chat." or "Pose report printed in console."
    end)
    btn("Morphs",340,4,98,function() selectTab("Morph") end)
    btn("LOAD USER + APPLY",12,80,426,function()
        attempt(function(ticket)
            local name=username.Text:match("^%s*(.-)%s*$"):gsub("^@","")
            assert(name~="","Enter username")
            status.Text="Finding username... Click LOAD to cancel."
            local userId=service:GetUserIdFromNameAsync(name)
            if not current(ticket) then return end
            status.Text="Loading clothing and accessories... Click LOAD to cancel."
            local d=service:GetHumanoidDescriptionFromUserIdAsync(userId)
            if not current(ticket) then d:Destroy();return end
            local ok,data=pcall(encode,d,name);d:Destroy();assert(ok,tostring(data))
            install(data,ticket)
        end)
    end)
    local function path()
        local name=filename.Text:match("^%s*(.-)%s*$")
        assert(#name>0 and #name<=64 and name:match("^[%w_-]+$"),"Use 1-64 letters, digits, - or _")
        return "LuminSkins/"..name..".json"
    end
    btn("SAVE SNAPSHOT",12,160,207,function()
        attempt(function(ticket)
            assert(skins.data,"Load a skin first")
            assert(type(writefile)=="function" and type(makefolder)=="function" and type(isfile)=="function","File saving unavailable")
            local destination=path();assert(not isfile(destination),"Name exists; choose another name")
            if type(isfolder)~="function" or not isfolder("LuminSkins") then pcall(makefolder,"LuminSkins") end
            writefile(destination,json:JSONEncode(skins.data))
            status.Text="Saved snapshot: "..destination
            if refreshSkins then refreshSkins() end
        end)
    end)
    btn("LOAD SAVED + APPLY",231,160,207,function()
        attempt(function(ticket)
            assert(type(readfile)=="function","File loading unavailable")
            install(json:JSONDecode(readfile(path())),ticket)
        end)
    end)
    btn("REMOVE SKIN",12,244,426,function()
        skins.ticket=(skins.ticket or 0)+1;skins.busy=false
        skins.active=nil
        removeMorph(true)
        status.Text="Skin removed; respawn restore disabled."
    end)
    local mine=makeButton(window,"USE MY USERNAME",UDim2.new(.5,-24,0,28),UDim2.fromOffset(16,86),COL.button);mine.TextSize=11
    S.connectAction(mine,function() username.Text=player.Name end)
    local cancel=makeButton(window,"CANCEL LOADING",UDim2.new(.5,-24,0,28),UDim2.new(.5,8,0,86),COL.button);cancel.TextSize=11
    S.connectAction(cancel,function() skins.ticket=(skins.ticket or 0)+1;skins.busy=false;status.Text="Loading cancelled. Current look kept." end)
    local reapply=makeButton(manage,"REAPPLY CURRENT LOOK",UDim2.new(1,-32,0,36),UDim2.fromOffset(16,328),COL.button);reapply.TextSize=12
    S.connectAction(reapply,function() attempt(function(ticket) assert(skins.data,"Load a look first");install(skins.data,ticket) end) end)
    controls["LOAD SAVED + APPLY"].Visible=false
    controls["COPY POSE REPORT"].Text="COPY DIAGNOSTIC REPORT"
    controls["Morphs"].Text="OPEN MORPH SETTINGS"
    local hint=makeLabel(manage,"Snapshots store clothes and accessories, not a live link to a username. Files: LuminSkins.",UDim2.new(1,-32,0,70),UDim2.fromOffset(16,400),11,COL.dim);hint.TextWrapped=true
    local savedSection=makeSection(avatarPage,"SAVED LOOKS",UDim2.fromOffset(24,294),UDim2.new(.55,-30,0,580))
    local skinSearch=textBox(savedSection,"Search your saved looks",40)
    local skinList=Instance.new("ScrollingFrame");skinList.Size=UDim2.new(1,-32,0,310);skinList.Position=UDim2.fromOffset(16,124);skinList.AutomaticCanvasSize=Enum.AutomaticSize.Y;skinList.CanvasSize=UDim2.new();skinList.ScrollBarThickness=4;skinList.BackgroundTransparency=1;skinList.BorderSizePixel=0;skinList.Parent=savedSection
    local layout=Instance.new("UIListLayout");layout.Padding=UDim.new(0,8);layout.Parent=skinList
    local selection=makeLabel(savedSection,"Select a saved look to apply, rename or delete.",UDim2.new(1,-32,0,38),UDim2.fromOffset(16,442),11,COL.subtext);selection.TextWrapped=true
    local favorites={};local favoriteOnly=false;local selectedFile;local deletePending;skins.restore=true
    pcall(function() if type(isfile)=="function" and isfile("LuminSkinPreferences.json") then local d=json:JSONDecode(readfile("LuminSkinPreferences.json"));favorites=d.favorites or {};skins.restore=d.restore~=false end end)
    local function saveSkinPrefs()
        if type(writefile)=="function" then pcall(function() if type(makefolder)=="function" then pcall(makefolder,"LuminSkins") end;writefile("LuminSkinPreferences.json",json:JSONEncode({favorites=favorites,restore=skins.restore})) end) end
    end
    refreshSkins=function()
        for _,child in ipairs(skinList:GetChildren()) do if child:IsA("GuiObject") then child:Destroy() end end
        if type(listfiles)~="function" then status.Text="File browsing unavailable";return end
        if type(makefolder)=="function" then pcall(makefolder,"LuminSkins") end
        local ok,files=pcall(listfiles,"LuminSkins");if not ok then status.Text=tostring(files);return end
        table.sort(files)
        local count=0
        for _,file in ipairs(files) do
            local short=file:match("([^/\\]+)%.json$")
            if short and short:lower():find(skinSearch.Text:lower(),1,true) and (not favoriteOnly or favorites[short]) and count<100 then
                count+=1
                local card=makeButton(skinList,(favorites[short] and "* " or "")..short,UDim2.new(1,-8,0,48),UDim2.new(),selectedFile==file and COL.buttonSelected or COL.button);card.TextSize=13;card.TextTruncate=Enum.TextTruncate.AtEnd;card:SetAttribute("Selected",selectedFile==file)
                S.connectAction(card,function() selectedFile=file;deletePending=nil;filename.Text=short;selection.Text="SELECTED: "..short;refreshSkins() end)
                card:SetAttribute("OwnContextMenu",true)
                card.MouseButton2Click:Connect(function() favorites[short]=not favorites[short];saveSkinPrefs();refreshSkins() end)
            end
        end
        if count==0 then
            local empty=makeLabel(skinList,"No saved looks here yet.\nLoad an avatar and save a snapshot, or change your search.",UDim2.new(1,-8,0,100),UDim2.new(),12,COL.dim);empty.TextWrapped=true
        end
    end
    local refresh=makeButton(savedSection,"REFRESH",UDim2.new(.5,-24,0,32),UDim2.fromOffset(16,85),COL.button)
    S.connectAction(refresh,refreshSkins)
    local fav=makeButton(savedSection,"ALL LOOKS",UDim2.new(.5,-24,0,32),UDim2.new(.5,8,0,85),COL.button)
    S.connectAction(fav,function() favoriteOnly=not favoriteOnly;fav.Text=favoriteOnly and "FAVORITES ONLY" or "ALL LOOKS";refreshSkins() end)
    local restore=makeButton(manage,"RESTORE ON RESPAWN: "..(skins.restore and "ON" or "OFF"),UDim2.new(1,-32,0,32),UDim2.fromOffset(16,374),COL.button)
    S.connectAction(restore,function() skins.restore=not skins.restore;saveSkinPrefs();restore.Text="RESTORE ON RESPAWN: "..(skins.restore and "ON" or "OFF") end)
    local rename=makeButton(savedSection,"RENAME",UDim2.new(.65,-24,0,32),UDim2.fromOffset(16,534),COL.button)
    S.connectAction(rename,function()
        local ok,err=pcall(function()
            assert(selectedFile and type(delfile)=="function","Select a saved skin; file deletion access required")
            local destination=path();assert(destination~=selectedFile and not isfile(destination),"New name is already taken")
            local raw=readfile(selectedFile);writefile(destination,raw)
            assert(readfile(destination)==raw,"Could not verify saved file")
            local oldName=selectedFile:match("([^/\\]+)%.json$")
            local newName=destination:match("([^/\\]+)%.json$")
            delfile(selectedFile);favorites[newName]=favorites[oldName];favorites[oldName]=nil;saveSkinPrefs()
            selectedFile=destination;selection.Text="SELECTED: "..newName;refreshSkins();status.Text="Renamed: "..destination
        end)
        if not ok then status.Text=tostring(err) end
    end)
    local delete=makeButton(savedSection,"DELETE",UDim2.new(.35,-24,0,32),UDim2.new(.65,8,0,534),COL.button)
    S.connectAction(delete,function()
        if not selectedFile then status.Text="Select a saved skin";return end
        if deletePending~=selectedFile then deletePending=selectedFile;status.Text="Delete "..selectedFile.."? Click Delete again to confirm.";return end
        local ok,err=pcall(function() assert(type(delfile)=="function","File deletion unavailable");delfile(selectedFile);favorites[selectedFile:match("([^/\\]+)%.json$")]=nil;saveSkinPrefs();selectedFile=nil;deletePending=nil;selection.Text="Select a saved look to apply, rename or delete.";refreshSkins() end)
        status.Text=ok and "File deleted" or tostring(err)
    end)
    local applySaved=makeButton(savedSection,"APPLY SELECTED",UDim2.new(.65,-24,0,36),UDim2.fromOffset(16,486),COL.buttonSelected);applySaved.TextSize=12
    S.connectAction(applySaved,function()
        attempt(function(ticket)
            assert(selectedFile,"Select a saved look first")
            local raw=readfile(selectedFile);assert(#raw<1000000,"Snapshot too large")
            install(json:JSONDecode(raw),ticket)
        end)
    end)
    local star=makeButton(savedSection,"FAVORITE",UDim2.new(.35,-24,0,36),UDim2.new(.65,8,0,486),COL.button);star.TextSize=10
    S.connectAction(star,function()
        if not selectedFile then status.Text="Select a saved look first";return end
        local short=selectedFile:match("([^/\\]+)%.json$")
        favorites[short]=not favorites[short];saveSkinPrefs();refreshSkins()
    end)
    local capture=makeButton(manage,"CAPTURE MY CHARACTER",UDim2.new(1,-32,0,36),UDim2.fromOffset(16,228),COL.button);capture.TextSize=12
    S.connectAction(capture,function()
        attempt(function(ticket)
            local character=player.Character
            local humanoid=character and character:FindFirstChildOfClass("Humanoid")
            assert(humanoid,"Your character is not ready")
            local description=humanoid:GetAppliedDescription()
            local ok,data=pcall(encode,description,player.Name);description:Destroy();assert(ok,tostring(data))
            if not current(ticket) then return end
            skins.data=data
            if filename.Text=="" then filename.Text=player.Name end
            details.Text=player.Name.."\n"..#data.accessories.." accessories\nCaptured from your real character"
            status.Text="Captured your character appearance. Enter a name and save the snapshot."
        end)
    end)
    skinSearch:GetPropertyChangedSignal("Text"):Connect(refreshSkins)
    avatarPage:GetPropertyChangedSignal("Visible"):Connect(function() if avatarPage.Visible then refreshSkins() end end)
    ugKeepRootConnection(player.CharacterAdded:Connect(function(character)
        local name=skins.active
        if not name or not skins.restore then return end
        task.spawn(function()
            local root=character:WaitForChild("HumanoidRootPart",15)
            local humanoid=character:WaitForChild("Humanoid",15)
            task.wait(1)
            if not root or not humanoid or humanoid.Health<=0 or S.unloading or player.Character~=character or skins.active~=name then return end
            S.npcMorphPending=nil
            applyMorph(name)
        end)
    end))
    function S.avatarSkinUnload()
        skins.ticket=(skins.ticket or 0)+1;skins.busy=false
        S.stopAvatarPhysics()
        skins.active=nil
        for name,model in pairs(skins.entries) do customMorphSources[name]=nil;customMorphMeta[name]=nil;model:Destroy() end
        skins.entries={};window:Destroy()
    end
end
S.catalogBridge={version=1}
function S.catalogBridge.list()
    assert(not S.unloading and gui.Parent,"Main panel is closed")
    return collectMorphNames()
end
function S.catalogBridge.clone(name)
    assert(not S.unloading and gui.Parent,"Main panel is closed")
    local clone
    if universalLibraryMorphs[name] then
        local runtime,err=v11BuildLibraryMorph(universalLibraryMorphs[name])
        assert(runtime,tostring(err));clone=runtime.model
    else
        local source=findMorphSourceModel(name)
        assert(source and source:IsA("Model"),"Morph model unavailable")
        local nodes=source:GetDescendants();table.insert(nodes,source)
        assert(#nodes<=10000,"Morph exceeds 10000 objects")
        local flags={}
        for _,object in ipairs(nodes) do flags[object]=object.Archivable;object.Archivable=true end
        local ok,result=pcall(function() return source:Clone() end)
        for object,value in pairs(flags) do pcall(function() object.Archivable=value end) end
        assert(ok and result,"Cannot clone morph");clone=result
    end
    if S.unloading or not gui.Parent then clone:Destroy();error("Main panel closed during loading") end
    clone.Parent=nil
    return clone
end
_G.TYOMICH_MORPH_CATALOG=S.catalogBridge
S.firstPersonSpectate={enabled=false,fov=85,forward=.35,height=0,hidden={}}
function S.setFirstPersonSpectate(enabled)
    S.clearFirstPersonSpectate()
    local p=S.firstPersonSpectate;p.enabled=enabled
    if p.modeButton then p.modeButton.Text=enabled and "View: FIRST PERSON" or "View: THIRD PERSON" end
    if S.spectateActive then S.spectateRenderStep(0) end
end
function S.clearFirstPersonSpectate()
    local p=S.firstPersonSpectate
    if not p then return end
    if p.added then p.added:Disconnect();p.added=nil end
    for part,value in pairs(p.hidden) do pcall(function() part.LocalTransparencyModifier=value end) end
    table.clear(p.hidden)
    if p.camera and p.camera.Parent and p.oldFov then p.camera.FieldOfView=p.oldFov end
    p.camera=nil;p.target=nil;p.head=nil;p.oldFov=nil
end
function S.firstPersonEye(target,root,camera)
    local p=S.firstPersonSpectate
    local visual=target
    if target==S.npcMorphTarget and morphModel and morphModel.Parent then visual=morphModel
    elseif S.multiMorphs and S.multiMorphs[target] and S.multiMorphs[target].model then visual=S.multiMorphs[target].model
    elseif target==S.controlledCharacter() and morphModel and morphModel.Parent and not S.npcMorphTarget and not S.npcMorphBatch then visual=morphModel end
    if p.target~=visual or p.camera~=camera or p.dirty or (p.head and not p.head.Parent) then
        S.clearFirstPersonSpectate();p.dirty=false;p.target=visual;p.camera=camera;p.oldFov=camera.FieldOfView
        local nodes=visual:GetDescendants()
        if visual:IsA("BasePart") then table.insert(nodes,1,visual) end
        for _,object in ipairs(nodes) do
            if object.Name:lower()=="head" and (object:IsA("BasePart") or object:IsA("Bone")) then p.head=object;break end
        end
        local function hide(part)
            if part:IsA("BasePart") and p.hidden[part]==nil then p.hidden[part]=part.LocalTransparencyModifier end
        end
        if p.head and p.head:IsA("BasePart") then
            hide(p.head)
            for _,part in ipairs(p.head:GetDescendants()) do hide(part) end
            for _,object in ipairs(nodes) do
                if object:IsA("Accessory") then
                    local attached=false
                    for _,joint in ipairs(object:GetDescendants()) do
                        if joint:IsA("JointInstance") and (joint.Part0==p.head or joint.Part1==p.head) then attached=true;break end
                        if joint:IsA("Attachment") and p.head:FindFirstChild(joint.Name) then attached=true;break end
                    end
                    if attached then for _,part in ipairs(object:GetDescendants()) do hide(part) end end
                end
            end
        end
        p.added=visual.DescendantAdded:Connect(function() p.dirty=true end)
    end
    for part in pairs(p.hidden) do if part.Parent then part.LocalTransparencyModifier=1 end end
    local eye=root.Position+Vector3.new(0,2,0)
    if p.head then eye=p.head:IsA("Bone") and p.head.TransformedWorldCFrame.Position or p.head.Position end
    local forward=Vector3.new(root.CFrame.LookVector.X,0,root.CFrame.LookVector.Z)
    if forward.Magnitude>.001 then forward=forward.Unit else forward=Vector3.new(0,0,-1) end
    camera.FieldOfView=p.fov
    return eye+forward*p.forward+Vector3.new(0,p.height,0)
end
do
    local p=S.firstPersonSpectate
    local toggle=makeButton(cameraPage,"POV settings",UDim2.fromOffset(146,30),UDim2.new(1,-350,0,24),COL.button)
    toggle.ZIndex=82
    local popup=Instance.new("Frame");popup.Size=UDim2.fromOffset(320,350);popup.Position=UDim2.new(1,-336,0,78);popup.BackgroundColor3=COL.panel;popup.Visible=false;popup.Active=true;popup.ZIndex=85;popup.Parent=cameraPage;corner(popup,10)
    local mode=makeButton(popup,"View: THIRD PERSON",UDim2.new(1,-24,0,34),UDim2.fromOffset(12,12),COL.button)
    p.modeButton=mode
    S.connectAction(mode,function() S.setFirstPersonSpectate(not p.enabled) end)
    createSlider(popup,"POV field of view",40,110,1,p.fov,60,function(v) p.fov=v end)
    createSlider(popup,"POV forward offset",-3,8,.05,p.forward,124,function(v) p.forward=v end)
    createSlider(popup,"POV height offset",-8,8,.05,p.height,188,function(v) p.height=v end)
    local note=makeLabel(popup,"Select an NPC, then press First person. Same mouse controls as third person; only camera position changes. Use View to switch back.",UDim2.new(1,-24,0,78),UDim2.fromOffset(12,258),11,COL.dim);note.TextWrapped=true
    for _,object in ipairs(popup:GetDescendants()) do if object:IsA("GuiObject") then object.ZIndex=86 end end
    S.connectAction(toggle,function() popup.Visible=not popup.Visible;if popup.Visible and S.setCameraOffsetPopup then S.setCameraOffsetPopup(false) end end)
end
function S.initializeWorkspacePages()
    S.uiScroll.Position=UDim2.fromOffset(12,100);S.uiScroll.Size=UDim2.new(1,-24,1,-108)
    local pick=makeButton(S.uiListSection,"Hide by click",UDim2.new(.34,-10,0,30),UDim2.fromOffset(12,60),COL.accent)
    local hidden=makeButton(S.uiListSection,"Hidden only",UDim2.new(.33,-10,0,30),UDim2.new(.34,4,0,60),COL.button)
    local undo=makeButton(S.uiListSection,"Undo hide",UDim2.new(.33,-16,0,30),UDim2.new(.67,4,0,60),COL.button)
    local overlay=Instance.new("TextButton");overlay.Name="UiPickerShield";overlay.Size=UDim2.fromScale(1,1);overlay.BackgroundTransparency=1;overlay.Text="";overlay.Modal=true;overlay.ZIndex=500;overlay.Visible=false;overlay.Parent=gui
    local box=Instance.new("Frame");box.BackgroundTransparency=1;box.BorderSizePixel=0;box.ZIndex=501;box.Parent=overlay;stroke(box,COL.accent,0,2)
    local caption=makeLabel(overlay,"Click: hide - RMB: parent - Esc: cancel",UDim2.fromOffset(620,45),UDim2.fromOffset(24,20),14,COL.text);caption.BackgroundTransparency=.1;caption.BackgroundColor3=COL.panel;caption.ZIndex=502;caption.TextWrapped=true
    local target,hovered;local depth=0;local history={};local mainVisible
    local function stop()
        overlay.Visible=false;S.uiPicking=false;target=nil;hovered=nil;depth=0
        if mainVisible~=nil then main.Visible=mainVisible;mainVisible=nil end
    end
    S.stopUiPicker=stop
    S.connectAction(pick,function()
        if S.cancelMorphChoose then S.cancelMorphChoose() end;if S.cancelCameraChoose then S.cancelCameraChoose() end
        mainVisible=main.Visible;main.Visible=false;overlay.Visible=true;S.uiPicking=true
    end)
    S.connectAction(hidden,function() S.uiHiddenOnly=not S.uiHiddenOnly;hidden.Text=S.uiHiddenOnly and "Hidden only: ON" or "Hidden only";ugRebuildUiList(true) end)
    S.connectAction(undo,function() local object=table.remove(history);if object and object.Parent then ugUiRestore(object);ugRebuildUiList(true) end end)
    S.connectAction(overlay,function()
        if target and target.Parent and not S.uiHidden[target] then ugUiHide(target);table.insert(history,target) end
        stop();ugRebuildUiList(true)
    end)
    overlay.MouseButton2Click:Connect(function() depth+=1 end)
    local highlight=Instance.new("Highlight");highlight.Name="WorldPickerOutline";highlight.FillTransparency=1;highlight.OutlineColor=COL.accent;highlight.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop;highlight.Enabled=false;highlight.Parent=gui
    ugKeepRootConnection(UserInputService.InputBegan:Connect(function(input) if input.KeyCode==Enum.KeyCode.Escape and overlay.Visible then stop() end end))
    local elapsed=0
    ugKeepRootConnection(RunService.RenderStepped:Connect(function(dt)
        elapsed+=dt;if elapsed<.05 then return end;elapsed=0
        if S.unloading then return end
        if overlay.Visible then
            local point=UserInputService:GetMouseLocation();local first
            for _,object in ipairs(playerGui:GetGuiObjectsAtPosition(point.X,point.Y)) do if ugUiIsManaged(object) and object.Visible then first=object;break end end
            if first~=hovered then hovered=first;depth=0 end
            target=first
            for _=1,depth do if target and target.Parent and target.Parent:IsA("GuiObject") then target=target.Parent end end
            box.Visible=target~=nil
            if target then
                box.Position=UDim2.fromOffset(target.AbsolutePosition.X-overlay.AbsolutePosition.X,target.AbsolutePosition.Y-overlay.AbsolutePosition.Y);box.Size=UDim2.fromOffset(target.AbsoluteSize.X,target.AbsoluteSize.Y)
                caption.Text=target.Name.." ["..target.ClassName.."] - click: hide - RMB: parent - Esc: cancel"
            end
        end
        local mode=S.morphChooseMode or S.cameraChooseMode
        highlight.Enabled=false
        if not mode or overlay.Visible then return end
        local point=UserInputService:GetMouseLocation()
        for _,object in ipairs(playerGui:GetGuiObjectsAtPosition(point.X,point.Y)) do if object.Active then return end end
        local ignore={};local actor=S.controlledCharacter and S.controlledCharacter() or player.Character
        if actor then table.insert(ignore,actor) end
        if S.morphChooseMode then if player.Character then table.insert(ignore,player.Character) end;if morphModel then table.insert(ignore,morphModel) end end
        local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Exclude;params.FilterDescendantsInstances=ignore
        local ray=player:GetMouse().UnitRay;local hit=Workspace:Raycast(ray.Origin,ray.Direction*2000,params)
        local object=hit and hit.Instance
        if object and mode=="Model" then
            object=object:FindFirstAncestorOfClass("Model")
            if S.morphChooseMode then
                local cursor=object
                while cursor and cursor~=Workspace do if cursor:IsA("Model") and (cursor:FindFirstChildOfClass("Humanoid") or cursor:FindFirstChildOfClass("AnimationController")) then object=cursor;break end;cursor=cursor.Parent end
            end
        end
        if object and (object:IsA("Model") or object:IsA("BasePart")) then highlight.Adornee=object;highlight.Enabled=true end
    end))
end
S.initializeWorkspacePages()
do
    title.Text="Tyomich Script [ LITE ]"
    title.TextColor3=COL.accent
    title.Size=UDim2.new(0,260,1,0)
    subtitle.Position=UDim2.fromOffset(280,1)
    subtitle.Size=UDim2.new(1,-380,1,0)
    gui:SetAttribute("TyomichEdition","Lite")
    if pages.Custom then pages.Custom:Destroy();pages.Custom=nil end
    if tabButtons.Custom then tabButtons.Custom:Destroy();tabButtons.Custom=nil end
    morphHeader.Text="GAME MORPHS"
    morphDesc.Text="Choose a game model. Use Avatar for saved player skins."
    morphSearch.Size=UDim2.new(1,-24,0,34)
    morphListSection.Position=UDim2.fromOffset(24,88)
    morphListSection.Size=UDim2.new(1,-48,0,430)
    morphScroll.Position=UDim2.fromOffset(12,78)
    morphScroll.Size=UDim2.new(1,-24,1,-86)
    morphDetails.Position=UDim2.fromOffset(24,536)
    morphPage.CanvasSize=UDim2.fromOffset(0,1460)
    S.moveHeader.Text="MOVEMENT"
    S.moveDesc.Text="Speed, jump, flight and noclip. Right-click Fly and Noclip to assign the same key."
    S.moveStatsSection.Size=UDim2.new(.5,-30,0,274)
    S.moveFlySection.Position=UDim2.new(.5,6,0,92)
    S.moveFlySection.Size=UDim2.new(.5,-30,0,274)
    S.moveStatsScroll.CanvasSize=UDim2.fromOffset(0,222)
    S.moveStatsScroll.ScrollingEnabled=false
    S.moveFlyHint.Text="WASD: move / Q,E: down,up / Shift: faster. RMB on Fly and Noclip allows one shared key."
end
function S.initializeWorkspaceNavigation()
    local prefs={favorites={},folders={},binds={},soulKey="F"}
    pcall(function()
        if type(isfile)=="function" and isfile("TyomichLiteWorkspace.json") then
            local raw=readfile("TyomichLiteWorkspace.json");assert(#raw<200000)
            local data=HttpService:JSONDecode(raw)
            if data.version==1 then
                prefs.favorites=type(data.favorites)=="table" and data.favorites or {}
                prefs.folders=type(data.folders)=="table" and data.folders or {}
                prefs.binds=type(data.binds)=="table" and data.binds or {}
                if type(data.soulKey)=="string" and Enum.KeyCode[data.soulKey] then prefs.soulKey=data.soulKey end
            end
        end
    end)
    for id,binding in pairs(prefs.binds) do
        if type(id)~="string" or type(binding)~="table" or type(binding.key)~="string" or not table.find({"press","toggle","hold"},binding.mode) or (binding.value~=nil and (type(binding.value)~="number" or binding.value~=binding.value or math.abs(binding.value)>1000000)) then prefs.binds[id]=nil end
    end
    if prefs.soulKey=="Unknown" or prefs.soulKey=="Escape" then prefs.soulKey="F" end
    S.soulKey=Enum.KeyCode[prefs.soulKey]
    if S.soulInteractButton then S.soulInteractButton.Text="INTERACT / RETURN · "..S.soulKey.Name end
    local function savePrefs()
        prefs.version=1
        if type(writefile)=="function" then local ok,err=pcall(function() writefile("TyomichLiteWorkspace.json",HttpService:JSONEncode(prefs)) end);if not ok then warn("Workspace settings: "..tostring(err)) end end
    end
    local navigation=sidebar:FindFirstChild("StudioNavigation")
    if not navigation then navigation=Instance.new("ScrollingFrame");navigation.Name="StudioNavigation";navigation.BackgroundTransparency=1;navigation.BorderSizePixel=0;navigation.Parent=sidebar end
    navigation.Position=UDim2.fromOffset(0,82);navigation.Size=UDim2.new(1,0,1,-262);navigation.ScrollBarThickness=3
    local search=Instance.new("TextBox");search.Size=UDim2.new(1,-16,0,30);search.Position=UDim2.fromOffset(8,44);search.BackgroundColor3=COL.button;search.TextColor3=COL.text;search.PlaceholderText="Search tools...";search.Text="";search.ClearTextOnFocus=false;search.TextSize=11;search.Parent=sidebar
    local labels={Soul="Soul",Morph="Morphs",Avatar="Avatar",Animations="Animations",Camera="Camera",Movement="Movement",NpcMorph="NPC / Players",Sounds="Sounds",NpcOverlay="NPC Labels",Color="Color",UI="Interface",Recorder="Role Recorder",AutoRecord="Auto Record",Btools="Custom Btools",Insert="Insert",BuildSave="Save",Kill="First Person",DeathScene="Third Person",Horror="Object Follow"}
    sidebar.Size=UDim2.new(0,196,1,-44)
    content.Position=UDim2.fromOffset(196,44);content.Size=UDim2.new(1,-196,1,-44)

    local groups={}
    local order={"Morph","Avatar","Animations","NpcMorph","Camera","Movement","Soul","Sounds","Recorder","AutoRecord","UI","Color","NpcOverlay"}
    local headers={}
    for _,group in ipairs({}) do
        local b=makeButton(navigation,"",UDim2.new(1,-16,0,40),UDim2.new(),COL.button);b.TextXAlignment=Enum.TextXAlignment.Left;b.TextSize=13;headers[group]=b
        S.connectAction(b,function() prefs.folders[group]=not prefs.folders[group];savePrefs();S.refreshNavigation() end)
    end
    local results=Instance.new("ScrollingFrame");results.Visible=false;results.BackgroundColor3=COL.panel;results.Size=UDim2.new(1,-16,1,-262);results.Position=UDim2.fromOffset(8,82);results.ScrollBarThickness=3;results.AutomaticCanvasSize=Enum.AutomaticSize.Y;results.CanvasSize=UDim2.new();results.Parent=sidebar
    local resultLayout=Instance.new("UIListLayout");resultLayout.Padding=UDim.new(0,5);resultLayout.Parent=results
    local function owner(object)
        local cursor=object
        while cursor and cursor~=gui do
            if cursor.Name=="BtoolsEditor" or cursor.Name=="BtoolsExplorer" then return "Btools" end
            if cursor==S.settingsPopup or cursor==S.settingsOverlay then return "Morph" end
            for key,page in pairs(pages) do if cursor==page then return key end end
            cursor=cursor.Parent
        end
    end
    local function actionId(object,title)
        local segments={title};local cursor=object.Parent
        while cursor and cursor~=gui do
            table.insert(segments,1,cursor:GetAttribute("SectionTitle") or cursor.Name)
            cursor=cursor.Parent
        end
        return table.concat(segments,"/")
    end
    local function actions()
        local list={};local seen={}
        for object,callbacks in pairs(S.actionCallbacks) do
            if object.Parent and owner(object) then
                local title=object:GetAttribute("ActionTitle") or object.Text
                local id=actionId(object,title)
                if not seen[id] then
                    seen[id]=true;table.insert(list,{id=id,object=object,title=title,page=owner(object),run=function() for _,entry in ipairs(callbacks) do if entry.connection.Connected then entry.callback() end end end})
                end
            end
        end
        for object,slider in pairs(S.sliderActions) do if object.Parent and owner(object) then
            table.insert(list,{id=actionId(object,slider.title),object=object,title=slider.title,page=owner(object),slider=slider})
        end end
        return list
    end
    local function decorateNavigation(button,selected,isFolder,expanded)
        local border=button:FindFirstChild("NavigationBorder")
        if not border then
            border=Instance.new("UIStroke");border.Name="NavigationBorder";border.Thickness=1;border.ApplyStrokeMode=Enum.ApplyStrokeMode.Border;border.Parent=button
            local accent=Instance.new("Frame");accent.Name="NavigationAccent";accent.BorderSizePixel=0;accent.BackgroundColor3=COL.accent;accent.Size=UDim2.new(0,3,1,-16);accent.Position=UDim2.fromOffset(0,8);accent.Parent=button;corner(accent,2)
        end
        border.Color=selected and COL.accent or COL.stroke;border.Transparency=selected and .5 or .8
        button.NavigationAccent.Visible=selected
        button.Font=selected and Enum.Font.GothamBold or Enum.Font.GothamMedium
        if isFolder then
            local arrow=button:FindFirstChild("FolderChevron")
            if not arrow then
                arrow=Instance.new("Frame");arrow.Name="FolderChevron";arrow.BackgroundTransparency=1;arrow.Size=UDim2.fromOffset(12,12);arrow.Position=UDim2.new(1,-24,.5,-6);arrow.Parent=button
                for i=1,2 do local line=Instance.new("Frame");line.BorderSizePixel=0;line.BackgroundColor3=COL.subtext;line.Size=UDim2.fromOffset(7,2);line.Position=UDim2.fromOffset(3,i==1 and 3 or 7);line.Rotation=i==1 and 45 or -45;line.Parent=arrow end
            end
            S.animateUi(arrow,{Rotation=expanded and 90 or 0},.12)
        end
    end
    function S.refreshNavigation(selected)
        if selected then
            local location=labels[selected] or selected
            for group,children in pairs(groups) do if table.find(children,selected) then location=group.." / "..location end end
            subtitle.Text=location
        end
        for key,b in pairs(tabButtons) do b.Visible=false;b.Parent=navigation end
        for _,b in pairs(headers) do b.Visible=false end
        local y=0
        local function show(key,indent)
            local b=tabButtons[key];if not b then return end
            b.Visible=true;b.Position=UDim2.fromOffset(8+(indent or 0),y);b.Size=UDim2.new(1,-16-(indent or 0),0,40)
            b.Text="   "..string.upper(labels[key] or key)..(prefs.favorites[key] and " *" or "");b.TextSize=13
            decorateNavigation(b,activeTab==key,false,false)
            y+=44
        end
        local favorites={};for key,value in pairs(prefs.favorites) do if value and labels[key] then table.insert(favorites,key) end end;table.sort(favorites)
        for _,key in ipairs(favorites) do show(key) end
        for _,key in ipairs(order) do
            local group=key:match("^(.-)/$")
            if group then
                if selected then for _,child in ipairs(groups[group]) do if child==selected then prefs.folders[group]=true end end end
                local b=headers[group];local chosen=table.find(groups[group],activeTab)~=nil;b:SetAttribute("Selected",chosen);b.BackgroundColor3=chosen and COL.buttonSelected or COL.button;b.Visible=true;b.Position=UDim2.fromOffset(8,y);y+=44
                b.Text="   "..string.upper(group)
                decorateNavigation(b,chosen,true,prefs.folders[group])
                if prefs.folders[group] then for _,child in ipairs(groups[group]) do if not prefs.favorites[child] then show(child,10) end end end
            elseif not prefs.favorites[key] then show(key) end
        end
        navigation.CanvasSize=UDim2.fromOffset(0,y+8)
    end
    for key,b in pairs(tabButtons) do
        ugKeepRootConnection(b.MouseButton2Click:Connect(function()
            prefs.favorites[key]=not prefs.favorites[key];savePrefs();S.refreshNavigation()
        end))
    end
    local function reveal(item)
        selectTab(item.page)
        if S.revealWorkspaceControl then S.revealWorkspaceControl(item.object) end
        local cursor=item.object.Parent
        while cursor and cursor~=content do
            if cursor:IsA("GuiObject") then cursor.Visible=true end
            if cursor:IsA("ScrollingFrame") then cursor.CanvasPosition=Vector2.new(0,math.max(0,cursor.CanvasPosition.Y+item.object.AbsolutePosition.Y-cursor.AbsolutePosition.Y-36)) end
            cursor=cursor.Parent
        end
        local border=Instance.new("UIStroke");border.Color=COL.accent;border.Thickness=2;border.Parent=item.object
        task.delay(1.5,function() border:Destroy() end)
        search.Text=""
    end
    local searchTicket=0
    ugKeepRootConnection(search:GetPropertyChangedSignal("Text"):Connect(function()
        searchTicket+=1;local ticket=searchTicket
        task.delay(.2,function()
            if S.unloading or ticket~=searchTicket then return end
            local query=search.Text:lower();results.Visible=query~="";navigation.Visible=query==""
            for _,child in ipairs(results:GetChildren()) do if child:IsA("GuiObject") then child:Destroy() end end
            if query=="" then return end
            local list=actions();table.sort(list,function(a,b) return a.title<b.title end)
            local aliases={Camera="camera spectate watch",Avatar="avatar skin",Sounds="footsteps sound",Morph="morph",BuildSave="map scene save",Insert="insert import",Kill="kill",DeathScene="kill death"}
            local count=0
            for _,item in ipairs(list) do
                local hay=(item.title.." "..(labels[item.page] or item.page).." "..(aliases[item.page] or "")):lower()
                if hay:find(query,1,true) and count<60 then
                    count+=1
                    local b=makeButton(results,(labels[item.page] or item.page).."\n"..item.title,UDim2.new(1,-5,0,52),UDim2.new(),COL.button);b.TextSize=10;b.TextWrapped=true
                    S.connectAction(b,function() reveal(item) end)
                end
            end
        end)
    end))
    local menu=Instance.new("Frame");menu.Size=UDim2.fromOffset(330,265);menu.BackgroundColor3=COL.panel;menu.Visible=false;menu.ZIndex=250;menu.Parent=gui;corner(menu,10);stroke(menu,COL.accent,.1,1)
    local heading=makeLabel(menu,"Keybind",UDim2.new(1,-24,0,38),UDim2.fromOffset(12,8),12,COL.text);heading.TextWrapped=true
    local function box(y,placeholder)
        local b=Instance.new("TextBox");b.Size=UDim2.new(1,-24,0,30);b.Position=UDim2.fromOffset(12,y);b.BackgroundColor3=COL.button;b.TextColor3=COL.text;b.Text="";b.PlaceholderText=placeholder;b.ClearTextOnFocus=false;b.Parent=menu;return b
    end
    local keyBox=box(50,"Key: K or Ctrl+K / Shift+K")
    local valueBox=box(88,"Slider value")
    local modeButton=makeButton(menu,"Mode: press",UDim2.new(1,-24,0,30),UDim2.fromOffset(12,126),COL.button)
    local apply=makeButton(menu,"Assign",UDim2.new(.5,-18,0,32),UDim2.fromOffset(12,164),COL.accent)
    local remove=makeButton(menu,"Remove bind",UDim2.new(.5,-18,0,32),UDim2.new(.5,6,0,164),COL.button)
    local close=makeButton(menu,"Close",UDim2.new(1,-24,0,30),UDim2.fromOffset(12,208),COL.button)
    for _,o in ipairs(menu:GetDescendants()) do if o:IsA("GuiObject") then o.ZIndex=251 end end
    local current,mode
    local function open(item)
        current=item;mode="press";heading.Text=item.title
        local previous=prefs.binds[item.id]
        keyBox.Text=previous and previous.key or "";valueBox.Text=previous and tostring(previous.value or "") or (item.slider and tostring(item.slider.get()) or "")
        mode=previous and previous.mode or "press";modeButton.Text="Mode: "..mode;valueBox.Visible=item.slider~=nil
        local point=UserInputService:GetMouseLocation()-game:GetService("GuiService"):GetGuiInset()
        local size=Workspace.CurrentCamera.ViewportSize
        menu.Position=UDim2.fromOffset(math.clamp(point.X,0,math.max(0,size.X-330)),math.clamp(point.Y,0,math.max(0,size.Y-265)));menu.Visible=true
    end
    S.connectAction(modeButton,function() mode=mode=="press" and "toggle" or mode=="toggle" and "hold" or "press";modeButton.Text="Mode: "..mode end)
    S.connectAction(close,function() menu.Visible=false end)
    S.connectAction(remove,function() if current then prefs.binds[current.id]=nil;savePrefs();S.workspaceActionsDirty=true;menu.Visible=false end end)
    local function sharedMovementBinding(first,second)
        local a,b
        for _,item in ipairs(actions()) do
            if item.id==first then a=item.object end
            if item.id==second then b=item.object end
        end
        return (a==S.moveFlyButton and b==S.moveNoclipButton) or (a==S.moveNoclipButton and b==S.moveFlyButton)
    end
    local function reserved(key)
        local base=key:match('([^+]+)$')
        for _,value in pairs({S.panelToggleKey,S.uiToggleKey,S.soulKey,S.shadowKey,S.recorder and S.recorder.keys.record,S.recorder and S.recorder.keys.play,S.recorder and S.recorder.keys.all}) do if value and value.Name==base then return true end end
        if base=="Escape" or base=="Unknown" then return true end
        for _,binds in pairs(animationBinds or {}) do for _,value in pairs(binds) do if typeof(value)=="EnumItem" and value.Name==base then return true end end end
        if S.speedSwap and S.speedSwap.key and S.speedSwap.key.Name==base then return true end
        if S.kill and S.kill.key==base then return true end
        if S.deathSceneSettings and S.deathSceneSettings.key==base then return true end
        if S.audio then for _,group in ipairs(S.audio.groups) do if group.key==base then return true end end end
        if table.find({"W","A","S","D","Q","E","Space","LeftControl","RightControl","LeftShift","RightShift","LeftAlt","RightAlt"},base) then return true end

        return false
    end
    S.connectAction(apply,function()
        if not current then return end
        local key=keyBox.Text:gsub('%s','')
        local base=key:match('([^+]+)$')
        for _,candidate in ipairs(Enum.KeyCode:GetEnumItems()) do if candidate.Name:lower()==(base or ""):lower() then base=candidate.Name;break end end
        local prefix=key:match('^(.-)%+')
        local modifiers={ctrl="Ctrl",control="Ctrl",shift="Shift",alt="Alt"}
        key=prefix and ((modifiers[prefix:lower()] or prefix).."+"..(base or "")) or (base or "")
        local ok,k=pcall(function() return Enum.KeyCode[base] end)
        if not ok or not k or reserved(key) then heading.Text="Invalid or reserved key";return end
        if key~=base and key~="Ctrl+"..base and key~="Shift+"..base and key~="Alt+"..base then heading.Text="Format: K, Ctrl+K, Shift+K, Alt+K";return end
        for id,binding in pairs(prefs.binds) do if id~=current.id and binding.key==key and not sharedMovementBinding(id,current.id) then heading.Text="This keybind is already in use";return end end
        local value=current.slider and tonumber(valueBox.Text) or nil
        if current.slider and (not value or value~=value or value<current.slider.min or value>current.slider.max) then heading.Text="Value is out of range";return end
        if not current.slider and mode~="press" then heading.Text="Buttons support press; toggle/hold are for sliders";return end
        prefs.binds[current.id]={key=key,mode=mode,value=value};savePrefs();S.workspaceActionsDirty=true;menu.Visible=false
    end)
    local held={};local toggled={};local attached=setmetatable({},{__mode="k"})
    local badges=setmetatable({},{__mode="k"})
    local function attach()
        for _,item in ipairs(actions()) do
            local binding=prefs.binds[item.id]
            local badge=badges[item.object]
            if binding and not badge then
                badge=makeLabel(item.object,"",UDim2.fromOffset(78,16),UDim2.new(1,-80,0,0),9,COL.accent);badge.ZIndex=item.object.ZIndex+1;badges[item.object]=badge
            end
            if badge then badge.Visible=binding~=nil;badge.Text=binding and ("["..binding.key.."]") or "" end
            if not attached[item.object] and not item.object:GetAttribute("OwnContextMenu") then
            attached[item.object]=true
            if item.object:IsA("GuiButton") then item.object.MouseButton2Click:Connect(function() open(item) end)
            else
                local nodes=item.object:GetDescendants();table.insert(nodes,item.object)
                for _,node in ipairs(nodes) do if node:IsA("GuiObject") then node.InputBegan:Connect(function(input) if input.UserInputType==Enum.UserInputType.MouseButton2 then open(item) end end) end end
            end
        end end
    end
    ugKeepRootConnection(UserInputService.InputBegan:Connect(function(input,processed)
        if processed or S.unloading or S.bindingCapture or S.uiPicking or UserInputService:GetFocusedTextBox() or menu.Visible then return end
        if input.UserInputType~=Enum.UserInputType.Keyboard then return end
        local key=input.KeyCode.Name
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.RightControl) then key="Ctrl+"..key
        elseif UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.RightShift) then key="Shift+"..key
        elseif UserInputService:IsKeyDown(Enum.KeyCode.LeftAlt) or UserInputService:IsKeyDown(Enum.KeyCode.RightAlt) then key="Alt+"..key end
        local hasBinding=false
        for _,binding in pairs(prefs.binds) do if binding.key==key then hasBinding=true;break end end
        if not hasBinding then return end
        for _,item in ipairs(actions()) do
            local binding=prefs.binds[item.id]
            if binding and binding.key==key and not reserved(key) then
                local ok,err=pcall(function()
                    if item.slider then
                        if binding.mode=="toggle" and toggled[item.id]~=nil then item.slider.set(toggled[item.id],true);toggled[item.id]=nil
                        else
                            local before=item.slider.get()
                            if binding.mode=="hold" then held[input.KeyCode]={slider=item.slider,value=before} elseif binding.mode=="toggle" then toggled[item.id]=before end
                            item.slider.set(binding.value,true)
                        end
                    else item.run() end
                end)
                if not ok then warn("Bind: "..tostring(err)) end
                if item.object~=S.moveFlyButton and item.object~=S.moveNoclipButton then return end
            end
        end
    end))
    ugKeepRootConnection(UserInputService.InputEnded:Connect(function(input)
        local item=held[input.KeyCode];if item then held[input.KeyCode]=nil;pcall(item.slider.set,item.value,true) end
    end))
    ugKeepRootConnection(UserInputService.WindowFocusReleased:Connect(function() for key,item in pairs(held) do held[key]=nil;pcall(item.slider.set,item.value,true) end end))
    S.workspaceInputCleanup=function()
        for key,item in pairs(held) do held[key]=nil;pcall(item.slider.set,item.value,true) end
        S.bindingCapture=false
    end
    local bindPage=createPage("Bindings")
    local bindList=Instance.new("ScrollingFrame");bindList.Size=UDim2.new(1,-48,1,-90);bindList.Position=UDim2.fromOffset(24,70);bindList.BackgroundTransparency=1;bindList.AutomaticCanvasSize=Enum.AutomaticSize.Y;bindList.CanvasSize=UDim2.new();bindList.ScrollBarThickness=4;bindList.Parent=bindPage
    local bindLayout=Instance.new("UIListLayout");bindLayout.Padding=UDim.new(0,6);bindLayout.Parent=bindList
    makeLabel(bindPage,"KEYBINDS - click a row to edit / remove",UDim2.new(1,-48,0,40),UDim2.fromOffset(24,20),15,COL.text)
    local function refreshBinds()
        for _,child in ipairs(bindList:GetChildren()) do if child:IsA("GuiObject") then child:Destroy() end end
        local available={};for _,item in ipairs(actions()) do available[item.id]=item end
        for id,binding in pairs(prefs.binds) do
            local item=available[id]
            local button=makeButton(bindList,binding.key.." • "..(item and item.title or "Unavailable action: "..id),UDim2.new(1,-8,0,40),UDim2.new(),COL.button);button.TextSize=11
            S.connectAction(button,function() if item then open(item) else prefs.binds[id]=nil;savePrefs();refreshBinds() end end)
        end
    end
    local bindings=makeButton(sidebar,"Keybinds",UDim2.new(1,-20,0,30),UDim2.new(0,10,1,-165),COL.button)
    S.connectAction(bindings,function() selectTab("Bindings");refreshBinds() end)
    if S.soulPage then
        local button=makeButton(S.soulPage,"Soul interaction key: "..S.soulKey.Name,UDim2.new(1,-48,0,36),UDim2.fromOffset(24,656),COL.button)
        S.connectAction(button,function() S.bindingCapture=true;button.Text="Press a key - Esc cancels" end)
        ugKeepRootConnection(UserInputService.InputBegan:Connect(function(input)
            if not S.bindingCapture or input.UserInputType~=Enum.UserInputType.Keyboard then return end
            if input.KeyCode~=Enum.KeyCode.Escape and not UserInputService:GetFocusedTextBox() then
                local old=S.soulKey;S.soulKey=nil
                if reserved(input.KeyCode.Name) then S.soulKey=old;button.Text="Key is in use; choose another";return end
                S.soulKey=input.KeyCode;S.soulKeyChangedAt=os.clock();prefs.soulKey=S.soulKey.Name;savePrefs()
            end
            S.bindingCapture=false;if S.soulInteractButton then S.soulInteractButton.Text="INTERACT / RETURN · "..S.soulKey.Name end;button.Text="Soul interaction key: "..S.soulKey.Name
        end))
    end
    S.refreshNavigation(activeTab)
    attach();S.workspaceActionsDirty=false
    task.spawn(function() while not S.unloading and gui.Parent do task.wait(1);if S.workspaceActionsDirty then S.workspaceActionsDirty=false;attach() end end end)
end
S.initializeWorkspaceNavigation()
function ugUnloadScript()
    if S.workspaceInputCleanup then S.workspaceInputCleanup() end
    if S.stopUiPicker then S.stopUiPicker() end
    if _G.TYOMICH_MORPH_CATALOG==S.catalogBridge then _G.TYOMICH_MORPH_CATALOG=nil end
    if S.horrorStop then S.horrorStop() end
    if S.cancelMorphChoose then S.cancelMorphChoose() end
    for name in pairs(S.pickedMorphNames or {}) do
        if customMorphSources[name] then customMorphSources[name]:Destroy();customMorphSources[name]=nil end
        customMorphMeta[name]=nil
    end
    if _G.TYOMICH_SCENE_SNAPSHOT==S.sceneLinkSnapshot then _G.TYOMICH_SCENE_SNAPSHOT=nil end
    if S.stopSpeedSwap then S.stopSpeedSwap() end
    if S.restoreKillVictims then S.restoreKillVictims() end
    RunService:UnbindFromRenderStep("TyomichDeadVictims")
    if S.stopOwnAnimationAudio then S.stopOwnAnimationAudio() end
    if S.stopKillScene then S.stopKillScene() end
    if S.autoRecordStop then S.autoRecordStop() end
    if S.btoolsUnload then S.btoolsUnload() end
    if S.stopSoul then S.stopSoul() end
    S.releaseFreecamControls()
    if S.footstepAdded then S.footstepAdded:Disconnect() end
    if S.restoreFootsteps then S.restoreFootsteps() end
    if S.visitorAnimationBank then S.visitorAnimationBank:Destroy(); S.visitorAnimationBank=nil end
    if S.profileFlush then S.profileFlush() end
    S.restoreShadowLighting()
	S.clearStoredMorphs()
	if S.unloading then
		return
	end

	S.unloading = true
    if S.avatarSkinUnload then S.avatarSkinUnload() end
    S.recorderUnload()
    S.overlayUnload()
	RunService:UnbindFromRenderStep(S.ACTOR_SCENE_BIND)
	S.restoreActorScene()
	S.restoreAllSounds()
	RunService:UnbindFromRenderStep(S.KILL_VISUAL_BIND)
	S.restoreKillVisuals()
	S.restoreNpcMorphVisibility()
	S.restoreDetachedVisibility()
	for _, tween in pairs(S.uiTweens) do tween:Cancel() end
	table.clear(S.npcCards)
	if S.cameraCardRecords then table.clear(S.cameraCardRecords) end
	S.stopSpectateGuard()
	S.releaseCameraLook()
	if S.restoreCaptureUi then S.restoreCaptureUi() end
	if S.viewportConnection then S.viewportConnection:Disconnect() end
	if S.colorEffect then S.colorEffect:Destroy() end
	S.resizing = nil

	print("[LUMIN] unloading...")

	pcall(function()
		ugResetMovementTools()
	end)

	pcall(function()
		ugDisconnectRootConnections()
	end)

	pcall(function()
		local manager = rawget(_G, "LuminDiagnostics")
		if type(manager) == "table"
			and type(manager.Off) == "function"
		then
			manager:Off()
		end
	end)

	thirdPerson = false
	S.freecamActive = false
	S.spectateActive = false
	S.spectateTarget = nil
	S.spectateRoot = nil
	S.thirdHardOverride = false

	pcall(function()
		UserInputService.MouseBehavior =
			Enum.MouseBehavior.Default
	end)

	pcall(function()
		RunService:UnbindFromRenderStep(
			CAMERA_BIND_NAME
		)
	end)

	pcall(function()
		RunService:UnbindFromRenderStep(
			S.FREECAM_BIND_NAME
		)
	end)

	pcall(function()
		RunService:UnbindFromRenderStep(
			S.SPECTATE_BIND_NAME
		)
	end)

	pcall(function()
		RunService:UnbindFromRenderStep(
			MORPH_BIND_NAME
		)
	end)

	pcall(function()
		RunService:UnbindFromRenderStep(
			V11_HIDE_BIND
		)
	end)

	S.cameraRenderBound = false

	pcall(function()
		if v11StopUniversalAnimation then
			v11StopUniversalAnimation(true)
		end
	end)

	pcall(function()
		removeMorph(false)
	end)

	pcall(function()
		restoreRealCharacter()
	end)

	pcall(function()
		ugUiRestoreAll()
	end)

	pcall(function()
		local camera =
			Workspace.CurrentCamera

		local subject =
			ugGetPlayerCameraSubject()

		if camera then
			camera.CameraType =
				Enum.CameraType.Custom

			if subject then
				camera.CameraSubject =
					subject
			end
		end

		S.restorePlayerCameraSettings()
	end)

	pcall(function()
		for _, object in ipairs(
			Workspace:GetChildren()
		) do
			if object:IsA("Model")
				and string.find(
					object.Name,
					"__LOCAL_MORPH_",
					1,
					true
				) == 1
			then
				object:Destroy()
			end
		end
	end)

	pcall(function()
		gui:Destroy()
	end)

	pcall(function()
		if _G.LUMIN_ADMIN_GUI == gui then
			_G.LUMIN_ADMIN_GUI = nil
		end

		if _G.LUMIN_ADMIN_UNLOAD == ugUnloadScript then
			_G.LUMIN_ADMIN_UNLOAD = nil
		end
	end)

	print("[LUMIN] unloaded")
end

_G.LUMIN_ADMIN_UNLOAD = ugUnloadScript

S.connectAction(S.unloadButton,function()
	ugUnloadScript()
end)

RunService:UnbindFromRenderStep(
	V11_HIDE_BIND
)

RunService:BindToRenderStep(
	V11_HIDE_BIND,
	Enum.RenderPriority.Last.Value,
	function()
		if S.unloading then
			return
		end

		if morphModel
			and morphModel.Parent
		then
			if S.npcMorphBatch then S.renderNpcBatch() end
			ugEnforceHiddenVisualsFast()
		end
	end
)

morphListSignature = ""
animationListSignature = ""

rebuildMorphList(true)
rebuildAnimationNpcList(true)
rebuildCustomList()

print("LUMIN ADMIN 14.7.16.12-SoulPrompts READY | third person OFF")
