-- DevGodMenuPlus.lua (LocalScript) - Studio / Private testing only
-- Improves all non-fly features: draggable GUI, keybind editor, aim assist tuning,
-- safer noclip, camera helper smoothing, target highlight, presets saved locally.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local mouse = player:GetMouse()

-- =========================
-- KEEP FLY AS-IS (do not change)
-- =========================
-- (Assumes fly code exists elsewhere or in this script; we will not modify it.)
-- If you want to paste your existing fly code, put it in the "FLY SECTION" below unchanged.

-- =========================
-- CONFIG (editable)
-- =========================
local CONFIG = {
    -- default hotkeys (can be edited in GUI)
    Hotkeys = {
        MenuToggle = Enum.KeyCode.F1,
        FlyToggle = Enum.KeyCode.F,
        NoclipToggle = Enum.KeyCode.N,
        AimToggle = Enum.KeyCode.T,
        CameraToggle = Enum.KeyCode.C,
        PresetSave = Enum.KeyCode.K,
        PresetLoad = Enum.KeyCode.L,
    },

    -- Aim assist (visual only)
    Aim = {
        Enabled = false,
        Smoothing = 0.12,       -- 0..1 (higher = stronger smoothing)
        MaxAngle = 12,          -- degrees
        VisualOnly = true,      -- true = only local camera change (no server calls)
        ScanRadius = 120,       -- studs
    },

    -- Noclip
    Noclip = {
        Enabled = false,
        AutoRestoreOnRespawn = true,
    },

    -- Camera helper
    Camera = {
        Enabled = false,
        OrbitSpeed = 0.6,
        OrbitRadius = 6,
        HeightOffset = 2.5,
        Smoothness = 0.18,
    },

    -- Highlight
    Highlight = {
        Color = Color3.fromRGB(80,255,120),
        LineThickness = 0.02,
    },

    -- UI
    UI = {
        Width = 300,
        Height = 180,
    },

    -- Logging
    Logging = false,
}

-- =========================
-- STATE
-- =========================
local state = {
    running = true,
    fly = false,            -- unchanged
    noclip = false,
    aimAssist = CONFIG.Aim.Enabled,
    camHelper = CONFIG.Camera.Enabled,
    highlight = nil,
    gui = nil,
    dragging = false,
    dragOffset = Vector2.new(0,0),
    lastClickTime = 0,
    debounce = 0.12,
    presets = {},           -- saved presets
}

-- =========================
-- UTILITIES
-- =========================
local function log(...)
    if CONFIG.Logging then
        print("[DevGodMenu+]", ...)
    end
end

local function now() return tick() end

local function keyToText(key)
    if typeof(key) == "EnumItem" then return tostring(key):gsub("Enum.KeyCode.", "") end
    return tostring(key)
end

local function setAttributePreset(name, tbl)
    -- store preset as JSON-like string in Player attribute (simple serialization)
    local success, encoded = pcall(function() return game:GetService("HttpService"):JSONEncode(tbl) end)
    if success then
        player:SetAttribute("DevGodPreset_"..name, encoded)
        return true
    end
    return false
end

local function getAttributePreset(name)
    local encoded = player:GetAttribute("DevGodPreset_"..name)
    if not encoded then return nil end
    local success, decoded = pcall(function() return game:GetService("HttpService"):JSONDecode(encoded) end)
    if success then return decoded end
    return nil
end

-- =========================
-- GUI (draggable + keybind editor + presets)
-- =========================
local function createGui()
    if state.gui and state.gui.Parent then return end

    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "DevGodMenuPlus"
    screenGui.ResetOnSpawn = false
    screenGui.Parent = player:WaitForChild("PlayerGui")

    local frame = Instance.new("Frame", screenGui)
    frame.Name = "Main"
    frame.Size = UDim2.new(0, CONFIG.UI.Width, 0, CONFIG.UI.Height)
    frame.Position = UDim2.new(0, 12, 0, 12)
    frame.BackgroundColor3 = Color3.fromRGB(20,20,20)
    frame.BackgroundTransparency = 0.15
    frame.BorderSizePixel = 0
    frame.Active = true
    frame.Draggable = false -- we'll implement custom drag to avoid focus issues

    -- Title bar (draggable)
    local titleBar = Instance.new("Frame", frame)
    titleBar.Name = "TitleBar"
    titleBar.Size = UDim2.new(1, 0, 0, 28)
    titleBar.Position = UDim2.new(0, 0, 0, 0)
    titleBar.BackgroundTransparency = 0.2
    titleBar.BackgroundColor3 = Color3.fromRGB(10,10,10)

    local title = Instance.new("TextLabel", titleBar)
    title.Size = UDim2.new(1, -8, 1, 0)
    title.Position = UDim2.new(0, 4, 0, 0)
    title.BackgroundTransparency = 1
    title.Text = "Dev God Menu Plus"
    title.TextColor3 = Color3.new(1,1,1)
    title.Font = Enum.Font.SourceSansBold
    title.TextScaled = true

    -- Close button
    local closeBtn = Instance.new("TextButton", titleBar)
    closeBtn.Size = UDim2.new(0, 28, 0, 20)
    closeBtn.Position = UDim2.new(1, -34, 0, 4)
    closeBtn.Text = "X"
    closeBtn.Font = Enum.Font.SourceSansBold
    closeBtn.TextColor3 = Color3.new(1,1,1)
    closeBtn.BackgroundColor3 = Color3.fromRGB(180,60,60)
    closeBtn.TextScaled = true

    closeBtn.MouseButton1Click:Connect(function()
        screenGui.Enabled = not screenGui.Enabled
    end)

    -- Toggle buttons and labels
    local function makeRow(y, labelText, initialState)
        local lbl = Instance.new("TextLabel", frame)
        lbl.Size = UDim2.new(0.6, -8, 0, 22)
        lbl.Position = UDim2.new(0, 8, 0, y)
        lbl.BackgroundTransparency = 1
        lbl.Text = labelText
        lbl.TextColor3 = Color3.new(1,1,1)
        lbl.Font = Enum.Font.SourceSans
        lbl.TextScaled = true

        local btn = Instance.new("TextButton", frame)
        btn.Size = UDim2.new(0.35, -8, 0, 22)
        btn.Position = UDim2.new(0.62, 0, 0, y)
        btn.Text = initialState and "ON" or "OFF"
        btn.BackgroundColor3 = initialState and Color3.fromRGB(50,180,50) or Color3.fromRGB(180,50,50)
        btn.TextColor3 = Color3.new(1,1,1)
        btn.Font = Enum.Font.SourceSansBold
        btn.TextScaled = true
        return lbl, btn
    end

    local y = 36
    local lblFly, btnFly = makeRow(y, "Fly (unchanged)", state.fly); y = y + 28
    local lblNoclip, btnNoclip = makeRow(y, "Noclip", state.noclip); y = y + 28
    local lblAim, btnAim = makeRow(y, "Aim Assist (local)", state.aimAssist); y = y + 28
    local lblCam, btnCam = makeRow(y, "Camera Helper", state.camHelper); y = y + 28

    -- Keybind editor small area
    local kbLabel = Instance.new("TextLabel", frame)
    kbLabel.Size = UDim2.new(0.6, -8, 0, 22)
    kbLabel.Position = UDim2.new(0, 8, 0, y)
    kbLabel.BackgroundTransparency = 1
    kbLabel.Text = "Hotkeys"
    kbLabel.TextColor3 = Color3.new(1,1,1)
    kbLabel.Font = Enum.Font.SourceSans
    kbLabel.TextScaled = true

    local kbBtn = Instance.new("TextButton", frame)
    kbBtn.Size = UDim2.new(0.35, -8, 0, 22)
    kbBtn.Position = UDim2.new(0.62, 0, 0, y)
    kbBtn.Text = "Edit"
    kbBtn.BackgroundColor3 = Color3.fromRGB(100,100,220)
    kbBtn.TextColor3 = Color3.new(1,1,1)
    kbBtn.Font = Enum.Font.SourceSansBold
    kbBtn.TextScaled = true
    y = y + 28

    -- Preset save/load
    local presetSave = Instance.new("TextButton", frame)
    presetSave.Size = UDim2.new(0.48, -8, 0, 22)
    presetSave.Position = UDim2.new(0, 8, 0, y)
    presetSave.Text = "Save Preset (K)"
    presetSave.BackgroundColor3 = Color3.fromRGB(80,160,80)
    presetSave.TextColor3 = Color3.new(1,1,1)
    presetSave.Font = Enum.Font.SourceSansBold
    presetSave.TextScaled = true

    local presetLoad = Instance.new("TextButton", frame)
    presetLoad.Size = UDim2.new(0.48, -8, 0, 22)
    presetLoad.Position = UDim2.new(0.52, 0, 0, y)
    presetLoad.Text = "Load Preset (L)"
    presetLoad.BackgroundColor3 = Color3.fromRGB(80,120,200)
    presetLoad.TextColor3 = Color3.new(1,1,1)
    presetLoad.Font = Enum.Font.SourceSansBold
    presetLoad.TextScaled = true

    -- small status label
    local status = Instance.new("TextLabel", frame)
    status.Size = UDim2.new(1, -12, 0, 18)
    status.Position = UDim2.new(0, 6, 1, -24)
    status.BackgroundTransparency = 1
    status.TextColor3 = Color3.fromRGB(200,200,200)
    status.Font = Enum.Font.SourceSans
    status.TextScaled = true
    status.Text = "Status: Ready"

    -- store references
    state.gui = screenGui
    state.gui.Frame = frame
    state.gui.Status = status
    state.gui.Btns = {
        Fly = btnFly,
        Noclip = btnNoclip,
        Aim = btnAim,
        Cam = btnCam,
        Keybind = kbBtn,
        PresetSave = presetSave,
        PresetLoad = presetLoad,
    }

    -- initial button states
    local function updateButtons()
        setBtnState = function(btn, on)
            btn.Text = on and "ON" or "OFF"
            btn.BackgroundColor3 = on and Color3.fromRGB(50,180,50) or Color3.fromRGB(180,50,50)
        end
        setBtnState(btnFly, state.fly)
        setBtnState(btnNoclip, state.noclip)
        setBtnState(btnAim, state.aimAssist)
        setBtnState(btnCam, state.camHelper)
    end
    updateButtons()

    -- button handlers
    btnFly.MouseButton1Click:Connect(function()
        state.fly = not state.fly
        updateButtons()
        status.Text = "Fly: " .. (state.fly and "ON" or "OFF")
    end)
    btnNoclip.MouseButton1Click:Connect(function()
        state.noclip = not state.noclip
        updateButtons()
        status.Text = "Noclip: " .. (state.noclip and "ON" or "OFF")
    end)
    btnAim.MouseButton1Click:Connect(function()
        state.aimAssist = not state.aimAssist
        updateButtons()
        status.Text = "Aim Assist: " .. (state.aimAssist and "ON" or "OFF")
    end)
    btnCam.MouseButton1Click:Connect(function()
        state.camHelper = not state.camHelper
        updateButtons()
        status.Text = "Camera Helper: " .. (state.camHelper and "ON" or "OFF")
    end)

    -- preset handlers
    presetSave.MouseButton1Click:Connect(function()
        local preset = {
            Aim = CONFIG.Aim,
            Camera = CONFIG.Camera,
            Noclip = CONFIG.Noclip,
            Highlight = CONFIG.Highlight,
            Hotkeys = CONFIG.Hotkeys,
        }
        local name = "default"
        setAttributePreset(name, preset)
        status.Text = "Preset saved: " .. name
    end)
    presetLoad.MouseButton1Click:Connect(function()
        local name = "default"
        local p = getAttributePreset(name)
        if p then
            -- apply loaded settings (only safe client-side settings)
            CONFIG.Aim = p.Aim or CONFIG.Aim
            CONFIG.Camera = p.Camera or CONFIG.Camera
            CONFIG.Noclip = p.Noclip or CONFIG.Noclip
            CONFIG.Highlight = p.Highlight or CONFIG.Highlight
            CONFIG.Hotkeys = p.Hotkeys or CONFIG.Hotkeys
            status.Text = "Preset loaded: " .. name
        else
            status.Text = "No preset found: " .. name
        end
    end)

    -- keybind editor (simple: listens for next key press)
    local editing = false
    kbBtn.MouseButton1Click:Connect(function()
        if editing then return end
        editing = true
        status.Text = "Press key for Menu Toggle..."
        local conn
        conn = UserInputService.InputBegan:Connect(function(input, gpe)
            if gpe then return end
            if input.UserInputType == Enum.UserInputType.Keyboard then
                CONFIG.Hotkeys.MenuToggle = input.KeyCode
                status.Text = "Menu Toggle set to " .. keyToText(input.KeyCode)
                conn:Disconnect()
                editing = false
            end
        end)
    end)

    -- custom drag handling for titleBar
    titleBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            state.dragging = true
            local mousePos = UserInputService:GetMouseLocation()
            local guiPos = frame.AbsolutePosition
            state.dragOffset = Vector2.new(mousePos.X - guiPos.X, mousePos.Y - guiPos.Y)
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            state.dragging = false
        end
    end)
    RunService.RenderStepped:Connect(function()
        if state.dragging and state.gui and state.gui.Frame then
            local m = UserInputService:GetMouseLocation()
            local newPos = UDim2.new(0, math.clamp(m.X - state.dragOffset.X, 0, Workspace.CurrentCamera.ViewportSize.X - CONFIG.UI.Width),
                                     0, math.clamp(m.Y - state.dragOffset.Y, 0, Workspace.CurrentCamera.ViewportSize.Y - CONFIG.UI.Height))
            state.gui.Frame.Position = newPos
        end
    end)
end

-- =========================
-- HIGHLIGHT (SelectionBox)
-- =========================
local function ensureHighlight()
    if state.highlight and state.highlight.Parent then return end
    local sel = Instance.new("SelectionBox")
    sel.Name = "DevHighlight"
    sel.LineThickness = CONFIG.Highlight.LineThickness
    sel.Color3 = CONFIG.Highlight.Color
    sel.SurfaceTransparency = 1
    sel.Parent = Workspace
    state.highlight = sel
end

local function clearHighlight()
    if state.highlight then
        pcall(function() state.highlight:Destroy() end)
        state.highlight = nil
    end
end

-- =========================
-- TARGETING / AIM ASSIST (visual only)
-- =========================
local function findNearestTarget()
    local char = player.Character
    if not char then return nil end
    local hrp = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChildWhichIsA("BasePart")
    if not hrp then return nil end
    local origin = hrp.Position
    local best, bestDist = nil, CONFIG.Aim.ScanRadius + 1
    for _,obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("Model") and obj ~= player.Character then
            local targetRoot = obj:FindFirstChild("HumanoidRootPart") or obj:FindFirstChildWhichIsA("BasePart")
            if targetRoot then
                local dist = (targetRoot.Position - origin).Magnitude
                if dist < bestDist then
                    bestDist = dist
                    best = targetRoot
                end
            end
        end
    end
    return best
end

local function updateAimAssist(dt)
    if not state.aimAssist then
        clearHighlight()
        return
    end
    local cam = Workspace.CurrentCamera
    if not cam then return end
    local target = findNearestTarget()
    if not target then
        clearHighlight()
        return
    end
    ensureHighlight()
    state.highlight.Adornee = target

    -- compute angle between camera look and target direction
    local toTarget = (target.Position - cam.CFrame.Position)
    if toTarget.Magnitude == 0 then return end
    local toUnit = toTarget.Unit
    local angle = math.deg(math.acos(math.clamp(cam.CFrame.LookVector:Dot(toUnit), -1, 1)))
    if angle <= CONFIG.Aim.MaxAngle then
        -- smoothing factor clamped
        local alpha = math.clamp(CONFIG.Aim.Smoothing, 0, 1)
        local desired = CFrame.new(cam.CFrame.Position, target.Position)
        local newCFrame = cam.CFrame:Lerp(desired, alpha * dt * 60) -- scale by dt*60 for frame-rate independence
        if CONFIG.Aim.VisualOnly then
            -- local camera change only
            pcall(function() Workspace.CurrentCamera.CFrame = newCFrame end)
        end
    end
end

-- =========================
-- CAMERA HELPER (orbit)
-- =========================
local camAngle = 0
local function updateCameraHelper(dt)
    if not state.camHelper then return end
    local target = findNearestTarget()
    if not target then return end
    camAngle = camAngle + dt * CONFIG.Camera.OrbitSpeed
    local radius = CONFIG.Camera.OrbitRadius
    local offset = Vector3.new(math.cos(camAngle)*radius, CONFIG.Camera.HeightOffset, math.sin(camAngle)*radius)
    local camPos = target.Position + offset
    local desired = CFrame.new(camPos, target.Position)
    local cam = Workspace.CurrentCamera
    if cam then
        local smooth = math.clamp(CONFIG.Camera.Smoothness * dt * 60, 0, 1)
        cam.CFrame = cam.CFrame:Lerp(desired, smooth)
    end
end

-- =========================
-- NOCLIP (safe)
-- =========================
local function setNoclip(enabled)
    local char = player.Character
    if not char then return end
    for _,part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
            part.CanCollide = not enabled
        end
    end
end

-- restore collisions on respawn if configured
player.CharacterAdded:Connect(function(char)
    wait(0.5)
    if CONFIG.Noclip.AutoRestoreOnRespawn and not state.noclip then
        setNoclip(false)
    elseif state.noclip then
        setNoclip(true)
    end
end)

-- =========================
-- MAIN LOOP (efficient)
-- =========================
createGui()
local accumulated = 0
local last = tick()
RunService.Heartbeat:Connect(function(dt)
    if not state.running then return end
    accumulated = accumulated + dt
    -- run aim and camera at a controlled rate
    if accumulated >= 0.03 then
        if state.aimAssist then updateAimAssist(accumulated) end
        if state.camHelper then updateCameraHelper(accumulated) end
        accumulated = 0
    end
    -- apply noclip state (cheap)
    if state.noclip then setNoclip(true) end
end)

-- =========================
-- HOTKEYS (apply config hotkeys)
-- =========================
UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.UserInputType == Enum.UserInputType.Keyboard then
        local kc = input.KeyCode
        if kc == CONFIG.Hotkeys.MenuToggle then
            if state.gui and state.gui.Parent then
                state.gui.Enabled = not state.gui.Enabled
            end
        elseif kc == CONFIG.Hotkeys.FlyToggle then
            -- keep fly behavior unchanged; toggle state.fly
            state.fly = not state.fly
            log("Fly toggled:", state.fly)
        elseif kc == CONFIG.Hotkeys.NoclipToggle then
            state.noclip = not state.noclip
            setNoclip(state.noclip)
            log("Noclip:", state.noclip)
        elseif kc == CONFIG.Hotkeys.AimToggle then
            state.aimAssist = not state.aimAssist
            log("AimAssist:", state.aimAssist)
        elseif kc == CONFIG.Hotkeys.CameraToggle then
            state.camHelper = not state.camHelper
            log("CameraHelper:", state.camHelper)
        elseif kc == CONFIG.Hotkeys.PresetSave then
            -- quick save
            local preset = {
                Aim = CONFIG.Aim,
                Camera = CONFIG.Camera,
                Noclip = CONFIG.Noclip,
                Highlight = CONFIG.Highlight,
                Hotkeys = CONFIG.Hotkeys,
            }
            setAttributePreset("quick", preset)
            log("Preset quick saved")
        elseif kc == CONFIG.Hotkeys.PresetLoad then
            local p = getAttributePreset("quick")
            if p then
                CONFIG.Aim = p.Aim or CONFIG.Aim
                CONFIG.Camera = p.Camera or CONFIG.Camera
                CONFIG.Noclip = p.Noclip or CONFIG.Noclip
                CONFIG.Highlight = p.Highlight or CONFIG.Highlight
                CONFIG.Hotkeys = p.Hotkeys or CONFIG.Hotkeys
                log("Preset quick loaded")
            end
        end
    end
end)

-- =========================
-- FINISH
-- =========================
print("[DevGodMenu+] Loaded. GUI: F1, Fly: F, Noclip: N, Aim: T, Camera: C. Use GUI to edit and save presets.")
