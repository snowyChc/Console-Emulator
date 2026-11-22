-- ASYM | VIRTUAL XBOX CONTROLLER V4
-- Delta Executor | Configurable Edition

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local player = Players.LocalPlayer
local DEVICE = 1

local SPAM_INTERVAL = 0.1
local RENDER_BIND = "ASYM_VIRTUAL_XBOX_SPAM"
local SETTINGS_FILE = "ASYM_VirtualXbox_Settings.json"

-- CLEAN PREVIOUS UI / RENDER BIND
RunService:UnbindFromRenderStep(RENDER_BIND)

local playerGui = player:WaitForChild("PlayerGui")
local oldGui = playerGui:FindFirstChild("ASYM_VirtualXbox")
if oldGui then oldGui:Destroy() end

local previousTouchControls = GuiService.TouchControlsEnabled

pcall(function()
    GuiService.TouchControlsEnabled = false
end)

local connections = {}

local function track(connection)
    table.insert(connections, connection)
    return connection
end

-- GUI ROOT
local gui = Instance.new("ScreenGui")
gui.Name = "ASYM_VirtualXbox"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 99999
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

local panel = Instance.new("Frame")
panel.Size = UDim2.new(1,-16,0,360)
panel.Position = UDim2.new(0,8,1,-368)
panel.BackgroundTransparency = 1
panel.BorderSizePixel = 0
panel.Parent = gui

-- STATUS
local status = Instance.new("TextLabel")
status.Size = UDim2.new(1,-100,0,25)
status.Position = UDim2.fromOffset(5,5)
status.BackgroundTransparency = 1
status.TextColor3 = Color3.fromRGB(100,220,140)
status.TextSize = 11
status.Font = Enum.Font.GothamBold
status.TextXAlignment = Enum.TextXAlignment.Left
status.Text = "ASYM | Initializing..."
status.Parent = panel

-- GAMEPAD API
local VIM
local apiReady = false

local ok,result = pcall(function()
    return game:GetService("VirtualInputManager")
end)

if ok then
    VIM = result

    local success,err = pcall(function()
        VIM:HandleGamepadConnect(DEVICE)
    end)

    apiReady = success
    status.Text = success
        and "VIRTUAL XBOX | CONNECT REQUESTED"
        or "API BLOCKED: "..tostring(err):sub(1,45)
else
    status.Text = "VIRTUAL INPUT UNAVAILABLE"
end

-- INPUT MANAGEMENT
local shuttingDown = false
local forceInputKey = Enum.KeyCode.ButtonCenter

local manualHeld = {}
local sentState = {}

local spamHeld = false
local spamAccumulator = 0

local function rawButtonInput(key,pressed)
    if not apiReady then return end

    local success,err = pcall(function()
        VIM:HandleGamepadButtonInput(
            DEVICE,
            key,
            pressed and 1 or 0
        )
    end)

    if not success then
        status.Text = "INPUT ERROR: "..tostring(err):sub(1,45)
        apiReady = false
    end
end

local function syncKey(key)
    local desired =
        manualHeld[key] == true
        or (spamHeld and key == forceInputKey)

    local previous = sentState[key] or false

    if previous ~= desired then
        sentState[key] = desired
        rawButtonInput(key,desired)
    end
end

local function setManualButton(key,pressed)
    manualHeld[key] = pressed and true or nil
    syncKey(key)
end

local function setForceInputKey(key)
    if not key then return end

    local oldKey = forceInputKey

    spamHeld = false
    syncKey(oldKey)

    forceInputKey = key
    spamAccumulator = 0

    syncKey(forceInputKey)

    status.Text = "FORCE INPUT: "..key.Name
end

local function buttonInput(key,pressed)
    setManualButton(key,pressed)
end

local function axisInput(key,x,y)
    if not apiReady then return end

    local success,err = pcall(function()
        VIM:HandleGamepadAxisInput(
            DEVICE,
            key,
            x,
            y,
            0
        )
    end)

    if not success then
        status.Text = "AXIS ERROR: "..tostring(err):sub(1,45)
        apiReady = false
    end
end

-- EDITOR STATE
local controls = {}
local editMode = false
local selectedControlId
local editDrag

-- UI HELPERS
local function makeLabel(parent,text,pos,size,fontSize)
    local obj = Instance.new("TextLabel")
    obj.BackgroundTransparency = 1
    obj.Text = text
    obj.TextColor3 = Color3.new(1,1,1)
    obj.TextSize = fontSize or 12
    obj.Font = Enum.Font.Gotham
    obj.TextXAlignment = Enum.TextXAlignment.Left
    obj.Position = pos
    obj.Size = size
    obj.ZIndex = 22
    obj.Parent = parent
    return obj
end

local function makeUiButton(parent,text,pos,size,callback,z)
    local obj = Instance.new("TextButton")
    obj.Position = pos
    obj.Size = size
    obj.BackgroundColor3 = Color3.fromRGB(48,55,70)
    obj.TextColor3 = Color3.new(1,1,1)
    obj.Text = text
    obj.TextSize = 12
    obj.Font = Enum.Font.GothamBold
    obj.AutoButtonColor = true
    obj.ZIndex = z or 22
    obj.Parent = parent

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0,7)
    corner.Parent = obj

    if callback then
        obj.Activated:Connect(callback)
    end

    return obj
end

local function makeTextBox(parent,placeholder,pos,size,z)
    local obj = Instance.new("TextBox")
    obj.Position = pos
    obj.Size = size
    obj.BackgroundColor3 = Color3.fromRGB(38,43,55)
    obj.TextColor3 = Color3.new(1,1,1)
    obj.PlaceholderColor3 = Color3.fromRGB(155,160,175)
    obj.PlaceholderText = placeholder
    obj.Text = ""
    obj.TextSize = 12
    obj.Font = Enum.Font.Gotham
    obj.ClearTextOnFocus = false
    obj.ZIndex = z or 22
    obj.Parent = parent

    Instance.new("UICorner",obj).CornerRadius = UDim.new(0,7)

    return obj
end

-- EDIT CONTROLS PANEL
local editPanel = Instance.new("Frame")
editPanel.Size = UDim2.fromOffset(340,112)
editPanel.AnchorPoint = Vector2.new(.5,0)
editPanel.Position = UDim2.new(.5,0,0,10)
editPanel.BackgroundColor3 = Color3.fromRGB(20,23,31)
editPanel.BackgroundTransparency = 0.04
editPanel.Visible = false
editPanel.ZIndex = 100
editPanel.Parent = gui

Instance.new("UICorner",editPanel).CornerRadius = UDim.new(0,10)

local editStroke = Instance.new("UIStroke")
editStroke.Color = Color3.fromRGB(100,130,190)
editStroke.Parent = editPanel

local editHint = makeLabel(
    editPanel,
    "EDIT CONTROLS | Tap and drag a control",
    UDim2.fromOffset(9,5),
    UDim2.new(1,-18,0,22),
    12
)
editHint.ZIndex = 101

local editNameBox = makeTextBox(
    editPanel,
    "Selected button name",
    UDim2.fromOffset(9,56),
    UDim2.fromOffset(180,29),
    101
)

local applyNameButton = makeUiButton(
    editPanel,
    "Apply",
    UDim2.fromOffset(195,56),
    UDim2.fromOffset(62,29),
    nil,
    101
)

local doneEditButton = makeUiButton(
    editPanel,
    "Done",
    UDim2.fromOffset(263,56),
    UDim2.fromOffset(68,29),
    nil,
    101
)

local function selectControl(id,input)
    local data = controls[id]
    if not data then return end

    selectedControlId = id

    for _,control in pairs(controls) do
        if control.stroke then
            control.stroke.Color = Color3.fromRGB(110,125,150)
            control.stroke.Thickness = 1
        end
    end

    if data.stroke then
        data.stroke.Color = Color3.fromRGB(70,170,255)
        data.stroke.Thickness = 3
    end

    editHint.Text = "Editing: "..id.." | Drag to move"

    if data.isButton then
        editNameBox.Text = data.object.Text
    else
        editNameBox.Text = ""
    end

    local object = data.object
    local absolute = object.AbsolutePosition

    editDrag = {
        object = object,
        input = input,
        startPointer = input.Position,
        startX = absolute.X-panel.AbsolutePosition.X,
        startY = absolute.Y-panel.AbsolutePosition.Y
    }
end

local function beginEdit()
    editMode = true
    editDrag = nil
    selectedControlId = nil
    editNameBox.Text = ""
    editHint.Text = "EDIT CONTROLS | Tap and drag a control"
    editPanel.Visible = true
end

local function endEdit()
    editMode = false
    editDrag = nil

    for _,control in pairs(controls) do
        if control.stroke then
            control.stroke.Color = Color3.fromRGB(110,125,150)
            control.stroke.Thickness = 1
        end
    end

    editPanel.Visible = false
end

applyNameButton.Activated:Connect(function()
    if not editMode then return end

    local data = controls[selectedControlId]

    if not data or not data.isButton then
        editHint.Text = "Select a button first!"
        return
    end

    local newName = editNameBox.Text

    if newName:gsub("%s","") == "" then
        editHint.Text = "Name cannot be empty!"
        return
    end

    data.object.Text = newName
    editHint.Text = "Renamed: "..selectedControlId
end)

doneEditButton.Activated:Connect(endEdit)

-- DRAG CONTROLS
track(UIS.InputChanged:Connect(function(input)
    if not editMode or not editDrag then return end

    local drag = editDrag

    local sameTouch = input == drag.input

    local sameMouse =
        drag.input.UserInputType == Enum.UserInputType.MouseButton1
        and input.UserInputType == Enum.UserInputType.MouseMovement

    if not sameTouch and not sameMouse then return end

    local delta = input.Position-drag.startPointer
    local object = drag.object

    local maxX = math.max(
        0,
        panel.AbsoluteSize.X-object.AbsoluteSize.X
    )

    local maxY = math.max(
        0,
        panel.AbsoluteSize.Y-object.AbsoluteSize.Y
    )

    local x = math.clamp(drag.startX+delta.X,0,maxX)
    local y = math.clamp(drag.startY+delta.Y,0,maxY)

    object.Position = UDim2.fromOffset(x,y)
end))

-- BUTTON SYSTEM
local heldButtons = {}

local function makeButton(id,text,key,pos,size)
    local b = Instance.new("TextButton")

    b.Name = id
    b.Size = size or UDim2.fromOffset(38,38)
    b.Position = pos
    b.BackgroundColor3 = Color3.fromRGB(42,48,61)
    b.BackgroundTransparency = 0.1
    b.TextColor3 = Color3.new(1,1,1)
    b.Text = text
    b.TextSize = 12
    b.Font = Enum.Font.GothamBold
    b.AutoButtonColor = false
    b.Active = true
    b.Selectable = false
    b.ZIndex = 5
    b.Parent = panel

    Instance.new("UICorner",b).CornerRadius = UDim.new(1,0)

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(110,125,150)
    stroke.Transparency = 0.4
    stroke.Parent = b

    controls[id] = {
        object = b,
        key = key,
        stroke = stroke,
        isButton = true
    }

    b.InputBegan:Connect(function(input)
        if shuttingDown then return end

        local validInput =
            input.UserInputType == Enum.UserInputType.Touch
            or input.UserInputType == Enum.UserInputType.MouseButton1

        if not validInput then return end

        if editMode then
            selectControl(id,input)
            return
        end

        if heldButtons[b] then return end

        heldButtons[b] = {
            input = input,
            key = key
        }

        buttonInput(key,true)
        b.BackgroundColor3 = Color3.fromRGB(55,125,220)
    end)

    return b
end

-- GLOBAL INPUT RELEASE
track(UIS.InputEnded:Connect(function(input)
    if editDrag then
        local sameTouch = input == editDrag.input

        local sameMouse =
            editDrag.input.UserInputType == Enum.UserInputType.MouseButton1
            and input.UserInputType == Enum.UserInputType.MouseButton1

        if sameTouch or sameMouse then
            editDrag = nil
        end
    end

    for b,data in pairs(heldButtons) do
        local sameTouch = input == data.input

        local sameMouse =
            data.input.UserInputType == Enum.UserInputType.MouseButton1
            and input.UserInputType == Enum.UserInputType.MouseButton1

        if sameTouch or sameMouse then
            heldButtons[b] = nil
            buttonInput(data.key,false)

            if b.Parent then
                b.BackgroundColor3 = Color3.fromRGB(42,48,61)
            end
        end
    end
end))

-- SHOULDERS AND TRIGGERS
makeButton("LB","LB",Enum.KeyCode.ButtonL1,
    UDim2.fromOffset(2,40),UDim2.fromOffset(55,28))

makeButton("LT","LT",Enum.KeyCode.ButtonL2,
    UDim2.fromOffset(2,72),UDim2.fromOffset(55,28))

makeButton("RB","RB",Enum.KeyCode.ButtonR1,
    UDim2.new(1,-57,0,40),UDim2.fromOffset(55,28))

makeButton("RT","RT",Enum.KeyCode.ButtonR2,
    UDim2.new(1,-57,0,72),UDim2.fromOffset(55,28))

-- SYSTEM BUTTONS
makeButton("VIEW","VIEW",Enum.KeyCode.ButtonSelect,
    UDim2.new(.5,-75,0,42),UDim2.fromOffset(65,29))

makeButton("MENU","MENU",Enum.KeyCode.ButtonStart,
    UDim2.new(.5,10,0,42),UDim2.fromOffset(65,29))

-- ABXY
makeButton("Y","Y",Enum.KeyCode.ButtonY,
    UDim2.new(1,-100,0,108))

makeButton("X","X",Enum.KeyCode.ButtonX,
    UDim2.new(1,-140,0,146))

makeButton("B","B",Enum.KeyCode.ButtonB,
    UDim2.new(1,-60,0,146))

makeButton("A","A",Enum.KeyCode.ButtonA,
    UDim2.new(1,-100,0,184))

-- D-PAD
makeButton("DPadUp","▲",Enum.KeyCode.DPadUp,
    UDim2.fromOffset(152,112),UDim2.fromOffset(32,32))

makeButton("DPadDown","▼",Enum.KeyCode.DPadDown,
    UDim2.fromOffset(152,176),UDim2.fromOffset(32,32))

makeButton("DPadLeft","◀",Enum.KeyCode.DPadLeft,
    UDim2.fromOffset(120,144),UDim2.fromOffset(32,32))

makeButton("DPadRight","▶",Enum.KeyCode.DPadRight,
    UDim2.fromOffset(184,144),UDim2.fromOffset(32,32))

-- ANALOG STICKS
local function makeStick(id,key,pos)
    local area = Instance.new("TextButton")

    area.Name = id
    area.Size = UDim2.fromOffset(104,104)
    area.Position = pos
    area.BackgroundColor3 = Color3.fromRGB(35,40,51)
    area.BackgroundTransparency = 0.08
    area.Text = ""
    area.AutoButtonColor = false
    area.Active = true
    area.ZIndex = 2
    area.Parent = panel

    Instance.new("UICorner",area).CornerRadius = UDim.new(1,0)

    local outline = Instance.new("UIStroke")
    outline.Color = Color3.fromRGB(110,125,150)
    outline.Transparency = 0.4
    outline.Parent = area

    local knob = Instance.new("Frame")
    knob.Size = UDim2.fromOffset(43,43)
    knob.AnchorPoint = Vector2.new(.5,.5)
    knob.Position = UDim2.fromScale(.5,.5)
    knob.BackgroundColor3 = Color3.fromRGB(115,135,165)
    knob.ZIndex = 3
    knob.Parent = area

    Instance.new("UICorner",knob).CornerRadius = UDim.new(1,0)

    local knobStroke = Instance.new("UIStroke")
    knobStroke.Color = Color3.fromRGB(190,205,230)
    knobStroke.Parent = knob

    controls[id] = {
        object = area,
        key = key,
        stroke = outline,
        isButton = false
    }

    local activeInput
    local radius = 34

    local function update(position)
        local center = area.AbsolutePosition+
            area.AbsoluteSize/2

        local delta = Vector2.new(
            position.X-center.X,
            position.Y-center.Y
        )

        if delta.Magnitude > radius then
            delta = delta.Unit*radius
        end

        knob.Position = UDim2.new(
            .5,delta.X,
            .5,delta.Y
        )

        axisInput(
            key,
            delta.X/radius,
            -delta.Y/radius
        )
    end

    area.InputBegan:Connect(function(input)
        if shuttingDown then return end

        if input.UserInputType == Enum.UserInputType.Touch
        or input.UserInputType == Enum.UserInputType.MouseButton1 then

            if editMode then
                selectControl(id,input)
                return
            end

            if activeInput then return end

            activeInput = input
            update(input.Position)
        end
    end)

    track(UIS.InputChanged:Connect(function(input)
        if shuttingDown or not activeInput then return end

        local sameTouch = input == activeInput

        local sameMouse =
            activeInput.UserInputType == Enum.UserInputType.MouseButton1
            and input.UserInputType == Enum.UserInputType.MouseMovement

        if sameTouch or sameMouse then
            update(input.Position)
        end
    end))

    track(UIS.InputEnded:Connect(function(input)
        if not activeInput then return end

        local sameTouch = input == activeInput

        local sameMouse =
            activeInput.UserInputType == Enum.UserInputType.MouseButton1
            and input.UserInputType == Enum.UserInputType.MouseButton1

        if sameTouch or sameMouse then
            activeInput = nil

            if not shuttingDown then
                knob.Position = UDim2.fromScale(.5,.5)
                axisInput(key,0,0)
            end
        end
    end))
end

makeStick(
    "LeftStick",
    Enum.KeyCode.Thumbstick1,
    UDim2.new(0,12,1,-132)
)

makeStick(
    "RightStick",
    Enum.KeyCode.Thumbstick2,
    UDim2.new(1,-116,1,-132)
)

-- ANALOG CLICK BUTTONS
makeButton("L3","L3",Enum.KeyCode.ButtonL3,
    UDim2.new(0,42,1,-29),UDim2.fromOffset(42,25))

makeButton("R3","R3",Enum.KeyCode.ButtonR3,
    UDim2.new(1,-84,1,-29),UDim2.fromOffset(42,25))

-- SETTINGS DATA
local savedSettings = {}
local selectedSetting

local function loadSettingsFromDisk()
    if type(readfile) ~= "function" then
        return
    end

    local success,content = pcall(function()
        return readfile(SETTINGS_FILE)
    end)

    if not success or type(content) ~= "string" then
        return
    end

    local decodedOK,decoded = pcall(function()
        return HttpService:JSONDecode(content)
    end)

    if decodedOK and type(decoded) == "table" then
        savedSettings = decoded
    end
end

local function persistSettings()
    if type(writefile) ~= "function" then
        return false
    end

    local success = pcall(function()
        local json = HttpService:JSONEncode(savedSettings)
        writefile(SETTINGS_FILE,json)
    end)

    return success
end

loadSettingsFromDisk()

local function captureSettings()
    local data = {
        ForceInputKey = forceInputKey.Name,
        Controls = {}
    }

    for id,control in pairs(controls) do
        local pos = control.object.Position

        data.Controls[id] = {
            XScale = pos.X.Scale,
            XOffset = pos.X.Offset,
            YScale = pos.Y.Scale,
            YOffset = pos.Y.Offset,
            Name = control.isButton
                and control.object.Text
                or nil
        }
    end

    return data
end

local function applySettings(data)
    if type(data) ~= "table" then return end

    if type(data.ForceInputKey) == "string" then
        local key = Enum.KeyCode[data.ForceInputKey]

        if key then
            setForceInputKey(key)
        end
    end

    if type(data.Controls) == "table" then
        for id,values in pairs(data.Controls) do
            local control = controls[id]

            if control and type(values) == "table" then
                local xs = tonumber(values.XScale) or 0
                local xo = tonumber(values.XOffset) or 0
                local ys = tonumber(values.YScale) or 0
                local yo = tonumber(values.YOffset) or 0

                control.object.Position = UDim2.new(
                    xs,xo,ys,yo
                )

                if control.isButton
                and type(values.Name) == "string" then
                    control.object.Text = values.Name
                end
            end
        end
    end
end

local function sortedSettingNames()
    local names = {}

    for name,data in pairs(savedSettings) do
        if type(name) == "string" and type(data) == "table" then
            table.insert(names,name)
        end
    end

    table.sort(names)
    return names
end

-- CONFIGURATION MENU
local configPanel = Instance.new("Frame")
configPanel.Name = "ConfigurationMenu"
configPanel.Size = UDim2.fromOffset(330,410)
configPanel.AnchorPoint = Vector2.new(.5,.5)
configPanel.Position = UDim2.fromScale(.5,.5)
configPanel.BackgroundColor3 = Color3.fromRGB(20,23,31)
configPanel.BackgroundTransparency = 0.04
configPanel.Visible = false
configPanel.ZIndex = 20
configPanel.Parent = gui

Instance.new("UICorner",configPanel).CornerRadius = UDim.new(0,12)

local configStroke = Instance.new("UIStroke")
configStroke.Color = Color3.fromRGB(75,100,145)
configStroke.Parent = configPanel

makeLabel(
    configPanel,
    "ASYM | CONTROLLER SETTINGS",
    UDim2.fromOffset(12,8),
    UDim2.new(1,-50,0,25),
    14
)

local configClose = makeUiButton(
    configPanel,
    "X",
    UDim2.new(1,-38,0,7),
    UDim2.fromOffset(28,25),
    function()
        configPanel.Visible = false
    end
)

-- FORCE INPUT KEY
makeLabel(
    configPanel,
    "ForceInputKey",
    UDim2.fromOffset(12,39),
    UDim2.fromOffset(300,18),
    11
)

local forceDropdown = makeUiButton(
    configPanel,
    "DPadDown ▼",
    UDim2.fromOffset(12,59),
    UDim2.new(1,-24,0,30)
)

-- EDIT CONTROLS
local editControlsButton = makeUiButton(
    configPanel,
    "EDIT CONTROLS",
    UDim2.fromOffset(12,98),
    UDim2.new(1,-24,0,32),
    function()
        configPanel.Visible = false
        beginEdit()
    end
)

-- SAVE SETTINGS
makeLabel(
    configPanel,
    "Save Settings | Configuration name",
    UDim2.fromOffset(12,139),
    UDim2.new(1,-24,0,18),
    11
)

local saveNameBox = makeTextBox(
    configPanel,
    "Example: Mobile Layout",
    UDim2.fromOffset(12,160),
    UDim2.new(1,-24,0,30)
)

local configStatus = makeLabel(
    configPanel,
    "Ready.",
    UDim2.fromOffset(12,337),
    UDim2.new(1,-24,0,48),
    10
)
configStatus.TextColor3 = Color3.fromRGB(150,205,160)
configStatus.TextWrapped = true

-- SETTING DROPDOWN
makeLabel(
    configPanel,
    "Setting",
    UDim2.fromOffset(12,236),
    UDim2.new(1,-24,0,18),
    11
)

local settingDropdown = makeUiButton(
    configPanel,
    "Select saved setting ▼",
    UDim2.fromOffset(12,257),
    UDim2.new(1,-24,0,30)
)

-- POPUPS
local function createPopup(y,height)
    local popup = Instance.new("ScrollingFrame")
    popup.Size = UDim2.new(1,-24,0,height)
    popup.Position = UDim2.fromOffset(12,y)
    popup.BackgroundColor3 = Color3.fromRGB(30,35,46)
    popup.BorderSizePixel = 0
    popup.ScrollBarThickness = 4
    popup.CanvasSize = UDim2.new(0,0,0,0)
    popup.Visible = false
    popup.ZIndex = 50
    popup.Parent = configPanel

    Instance.new("UICorner",popup).CornerRadius = UDim.new(0,7)

    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0,3)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = popup

    return popup
end

local forcePopup = createPopup(93,145)
local settingsPopup = createPopup(291,100)

local function populatePopup(popup,items,callback)
    for _,child in ipairs(popup:GetChildren()) do
        if child:IsA("TextButton") then
            child:Destroy()
        end
    end

    for index,item in ipairs(items) do
        local option = makeUiButton(
            popup,
            item,
            UDim2.new(0,3,0,0),
            UDim2.new(1,-10,0,28),
            function()
                callback(item)
                popup.Visible = false
            end,
            51
        )

        option.LayoutOrder = index
    end

    popup.CanvasSize = UDim2.fromOffset(
        0,
        #items*31+3
    )
end

local forceOptions = {
    "DPadDown",
    "DPadUp",
    "DPadLeft",
    "DPadRight",
    "ButtonSelect",
    "ButtonStart",
    "ButtonA",
    "ButtonB",
    "ButtonX",
    "ButtonY",
    "ButtonL1",
    "ButtonL2",
    "ButtonR1",
    "ButtonR2",
    "ButtonL3",
    "ButtonR3"
}

populatePopup(forcePopup,forceOptions,function(name)
    local key = Enum.KeyCode[name]

    if key then
        setForceInputKey(key)
        forceDropdown.Text = name.." ▼"
    end
end)

forceDropdown.Activated:Connect(function()
    settingsPopup.Visible = false
    forcePopup.Visible = not forcePopup.Visible
end)

-- SAVE CONFIGURATION
local saveButton = makeUiButton(
    configPanel,
    "SAVE SETTINGS",
    UDim2.fromOffset(12,196),
    UDim2.new(1,-24,0,31),
    function()
        local name = saveNameBox.Text:gsub("^%s*(.-)%s*$","%1")

        if name == "" then
            configStatus.Text = "Enter a configuration name first."
            return
        end

        savedSettings[name] = captureSettings()
        selectedSetting = name

        local diskSaved = persistSettings()

        configStatus.Text = diskSaved
            and "Saved successfully to executor storage!"
            or "Saved for this session. File storage unavailable."

        settingDropdown.Text = name.." ▼"

        local names = sortedSettingNames()

        populatePopup(settingsPopup,names,function(selected)
            selectedSetting = selected
            settingDropdown.Text = selected.." ▼"
        end)
    end
)

-- REFRESH SETTING LIST
local function refreshSettings()
    local names = sortedSettingNames()

    if selectedSetting and not savedSettings[selectedSetting] then
        selectedSetting = nil
    end

    settingDropdown.Text = selectedSetting
        and selectedSetting.." ▼"
        or "Select saved setting ▼"

    populatePopup(settingsPopup,names,function(name)
        selectedSetting = name
        settingDropdown.Text = name.." ▼"
    end)
end

refreshSettings()

settingDropdown.Activated:Connect(function()
    forcePopup.Visible = false
    refreshSettings()
    settingsPopup.Visible = not settingsPopup.Visible
end)

-- LOAD SETTING
local loadButton = makeUiButton(
    configPanel,
    "LOAD SETTINGS",
    UDim2.fromOffset(12,296),
    UDim2.fromOffset(148,32),
    function()
        if not selectedSetting or not savedSettings[selectedSetting] then
            configStatus.Text = "Select a setting first."
            return
        end

        applySettings(savedSettings[selectedSetting])
        forceDropdown.Text = forceInputKey.Name.." ▼"

        configStatus.Text = "Loaded: "..selectedSetting
        configPanel.Visible = false
    end
)

-- DELETE SETTING
local deleteButton = makeUiButton(
    configPanel,
    "DELETE SETTING",
    UDim2.fromOffset(170,296),
    UDim2.fromOffset(148,32),
    function()
        if not selectedSetting or not savedSettings[selectedSetting] then
            configStatus.Text = "Select a setting first."
            return
        end

        local deletedName = selectedSetting

        savedSettings[deletedName] = nil
        selectedSetting = nil

        local diskSaved = persistSettings()

        refreshSettings()

        configStatus.Text = diskSaved
            and "Deleted: "..deletedName
            or "Deleted from current session: "..deletedName
    end
)

-- CONFIG BUTTON
local configToggle = makeUiButton(
    panel,
    "⚙",
    UDim2.new(.5,-16,0,3),
    UDim2.fromOffset(32,28),
    function()
        if editMode or shuttingDown then return end

        configPanel.Visible = not configPanel.Visible
        forcePopup.Visible = false
        settingsPopup.Visible = false
    end,
    10
)

configToggle.TextSize = 19
configToggle.BackgroundColor3 = Color3.fromRGB(42,48,61)

-- RENDERSTEP FORCE INPUT SPAM
RunService:BindToRenderStep(
    RENDER_BIND,
    Enum.RenderPriority.Last.Value,
    function(dt)
        if shuttingDown or not apiReady then return end

        -- Release the previous pulse
        if spamHeld then
            spamHeld = false
            syncKey(forceInputKey)
        end

        spamAccumulator = spamAccumulator+dt

        if spamAccumulator >= SPAM_INTERVAL then
            spamAccumulator = spamAccumulator%SPAM_INTERVAL

            spamHeld = true
            syncKey(forceInputKey)
        end
    end
)

-- CLOSE / CLEANUP
local close = makeUiButton(
    panel,
    "X",
    UDim2.new(1,-30,0,3),
    UDim2.fromOffset(28,25),
    nil,
    10
)

close.BackgroundColor3 = Color3.fromRGB(170,45,45)

close.Activated:Connect(function()
    if shuttingDown then return end
    shuttingDown = true

    -- STOP SPAM
    RunService:UnbindFromRenderStep(RENDER_BIND)

    spamHeld = false
    spamAccumulator = 0

    -- RELEASE ALL BUTTONS
    for key in pairs(manualHeld) do
        manualHeld[key] = nil
    end

    for key,pressed in pairs(sentState) do
        if pressed then
            rawButtonInput(key,false)
        end
    end

    rawButtonInput(forceInputKey,false)

    heldButtons = {}
    manualHeld = {}
    sentState = {}

    -- RESET STICKS
    axisInput(Enum.KeyCode.Thumbstick1,0,0)
    axisInput(Enum.KeyCode.Thumbstick2,0,0)

    -- DISCONNECT GAMEPAD
    if VIM then
        pcall(function()
            VIM:HandleGamepadDisconnect(DEVICE)
        end)
    end

    -- RESTORE TOUCH CONTROLS
    pcall(function()
        GuiService.TouchControlsEnabled = previousTouchControls
    end)

    -- DISCONNECT GLOBAL CONNECTIONS
    for _,connection in ipairs(connections) do
        pcall(function()
            connection:Disconnect()
        end)
    end

    gui:Destroy()
end)

print("ASYM VIRTUAL XBOX V4 LOADED")
print("CONFIG MENU: READY")
print("FORCE INPUT: "..forceInputKey.Name)
print("SPAM INTERVAL: "..SPAM_INTERVAL)
print("SETTINGS FILE: "..SETTINGS_FILE)
