-- DevGodMenu.lua (LocalScript) - For Roblox Studio / Private testing only
-- DO NOT use this to cheat in live multiplayer games.
-- Features: GUI menu, Fly, Noclip, Camera helper, Target highlight, Local aim-sim

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")

local player = Players.LocalPlayer
local mouse = player:GetMouse()
local character = player.Character or player.CharacterAdded:Wait()

-- =========================
-- CONFIG
-- =========================
local CONFIG = {
    FlySpeed = 80,            -- studs/sec
    FlyAccel = 8,             -- acceleration smoothing
    AimAssistSmoothing = 0.12,-- 0..1 (higher = stronger smoothing)
    AimAssistMaxAngle = 12,   -- degrees: max angle to consider for assist
    HighlightColor = Color3.fromRGB(80,255,120),
    ScanRadius = 120,         -- studs for target scanning
    MenuToggleKey = Enum.KeyCode.F1,
    FlyToggleKey = Enum.KeyCode.F,
    NoclipToggleKey = Enum.KeyCode.N,
    AimToggleKey = Enum.KeyCode.T,
    CameraToggleKey = Enum.KeyCode.C,
}

-- =========================
-- STATE
-- =========================
local state = {
    running = true,
    fly = false,
    noclip = false,
    aimAssist = false,
    camHelper = false,
    highlightEnabled = true,
    flyVelocity = Vector3.new(0,0,0),
}

-- =========================
-- UI
-- =========================
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "DevGodMenu"
screenGui.ResetOnSpawn = false
screenGui.Parent = player:WaitForChild("PlayerGui")

local frame = Instance.new("Frame", screenGui)
frame.Size = UDim2.new(0, 260, 0, 160)
frame.Position = UDim2.new(0, 12, 0, 12)
frame.BackgroundTransparency = 0.25
frame.BackgroundColor3 = Color3.fromRGB(20,20,20)
frame.BorderSizePixel = 0

local title = Instance.new("TextLabel", frame)
title.Size = UDim2.new(1, -8, 0, 28)
title.Position = UDim2.new(0, 4, 0, 4)
title.BackgroundTransparency = 1
title.TextColor3 = Color3.new(1,1,1)
title.Text = "Dev God Menu (Studio only)"
title.Font = Enum.Font.SourceSansBold
title.TextScaled = true

local function makeToggle(y, text, initial)
    local lbl = Instance.new("TextLabel", frame)
    lbl.Size = UDim2.new(0.6, -8, 0, 22)
    lbl.Position = UDim2.new(0, 8, 0, y)
    lbl.BackgroundTransparency = 1
    lbl.TextColor3 = Color3.new(1,1,1)
    lbl.Text = text
    lbl.Font = Enum.Font.SourceSans
    lbl.TextScaled = true

    local btn = Instance.new("TextButton", frame)
    btn.Size = UDim2.new(0.35, -8, 0, 22)
    btn.Position = UDim2.new(0.62, 0, 0, y)
    btn.Text = initial and "ON" or "OFF"
    btn.BackgroundColor3 = initial and Color3.fromRGB(50,180,50) or Color3.fromRGB(180,50,50)
    btn.TextColor3 = Color3.new(1,1,1)
    btn.Font = Enum.Font.SourceSansBold
    btn.TextScaled = true
    return lbl, btn
end

local lblFly, btnFly = makeToggle(36, "Fly", false)
local lblNoclip, btnNoclip = makeToggle(64, "Noclip", false)
local lblAim, btnAim = makeToggle(92, "Aim Assist (local)", false)
local lblCam, btnCam = makeToggle(120, "Camera Helper", false)

local function setBtnState(btn, on)
    btn.Text = on and "ON" or "OFF"
    btn.BackgroundColor3 = on and Color3.fromRGB(50,180,50) or Color3.fromRGB(180,50,50)
end

-- button handlers
btnFly.MouseButton1Click:Connect(function()
    state.fly = not state.fly
    setBtnState(btnFly, state.fly)
end)
btnNoclip.MouseButton1Click:Connect(function()
    state.noclip = not state.noclip
    setBtnState(btnNoclip, state.noclip)
end)
btnAim.MouseButton1Click:Connect(function()
    state.aimAssist = not state.aimAssist
    setBtnState(btnAim, state.aimAssist)
end)
btnCam.MouseButton1Click:Connect(function()
    state.camHelper = not state.camHelper
    setBtnState(btnCam, state.camHelper)
end)

-- =========================
-- UTILITIES
-- =========================
local function getCharacter()
    if player.Character and player.Character.Parent then return player.Character end
    return player.CharacterAdded:Wait()
end

local function getHumRoot()
    local char = getCharacter()
    return char:FindFirstChild("HumanoidRootPart") or char:FindFirstChildWhichIsA("BasePart")
end

local function setNoclip(enabled)
    local char = getCharacter()
    for _,part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
            part.CanCollide = not enabled
        end
    end
end

-- =========================
-- FLY IMPLEMENTATION (local)
-- =========================
local flyVelocity = Vector3.new(0,0,0)
local flyTargetVel = Vector3.new(0,0,0)

local function updateFly(dt)
    if not state.fly then return end
    local hrp = getHumRoot()
    if not hrp then return end

    -- read WASD + space/ctrl
    local forward = 0
    local right = 0
    local up = 0
    if UserInputService:IsKeyDown(Enum.KeyCode.W) then forward = forward + 1 end
    if UserInputService:IsKeyDown(Enum.KeyCode.S) then forward = forward - 1 end
    if UserInputService:IsKeyDown(Enum.KeyCode.D) then right = right + 1 end
    if UserInputService:IsKeyDown(Enum.KeyCode.A) then right = right - 1 end
    if UserInputService:IsKeyDown(Enum.KeyCode.Space) then up = up + 1 end
    if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then up = up - 1 end

    local cam = workspace.CurrentCamera
    local camCFrame = cam.CFrame
    local dir = (camCFrame.LookVector * forward) + (camCFrame.RightVector * right) + Vector3.new(0, up, 0)
    if dir.Magnitude > 0 then dir = dir.Unit end

    flyTargetVel = dir * CONFIG.FlySpeed
    -- smooth velocity
    flyVelocity = flyVelocity:Lerp(flyTargetVel, math.clamp(CONFIG.FlyAccel * dt, 0, 1))
    -- apply movement locally
    hrp.Velocity = Vector3.new(flyVelocity.X, flyVelocity.Y, flyVelocity.Z)
end

-- =========================
-- AIM ASSIST (local visualization only)
-- =========================
local highlight = nil
local function ensureHighlight()
    if highlight and highlight.Parent then return end
    highlight = Instance.new("SelectionBox")
    highlight.Name = "DevTargetHighlight"
    highlight.LineThickness = 0.02
    highlight.SurfaceTransparency = 1
    highlight.Color3 = CONFIG.HighlightColor
    highlight.Parent = workspace
end

local function clearHighlight()
    if highlight then
        pcall(function() highlight:Destroy() end)
        highlight = nil
    end
end

local function findNearestTarget()
    local hrp = getHumRoot()
    if not hrp then return nil end
    local origin = hrp.Position
    local best = nil
    local bestDist = CONFIG.ScanRadius + 1
    for _,obj in ipairs(workspace:GetDescendants()) do
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
    ensureHighlight()
    local cam = workspace.CurrentCamera
    local hrp = getHumRoot()
    if not hrp or not cam then return end

    local target = findNearestTarget()
    if not target then
        clearHighlight()
        return
    end

    -- highlight target
    highlight.Adornee = target

    -- compute angle between camera look and target direction
    local toTarget = (target.Position - cam.CFrame.Position).Unit
    local angle = math.deg(math.acos(math.clamp(cam.CFrame.LookVector:Dot(toTarget), -1, 1)))
    if angle <= CONFIG.AimAssistMaxAngle then
        -- compute a smoothed camera CFrame that nudges toward target (local only)
        local desiredLook = CFrame.new(cam.CFrame.Position, target.Position)
        local current = cam.CFrame
        local lerpAlpha = math.clamp(CONFIG.AimAssistSmoothing, 0, 1)
        local newCFrame = current:Lerp(desiredLook, lerpAlpha)
        -- apply camera change locally (only in Studio or local testing)
        pcall(function()
            workspace.CurrentCamera.CFrame = newCFrame
        end)
    end
end

-- =========================
-- CAMERA HELPER
-- =========================
local camOrbitAngle = 0
local function updateCameraHelper(dt)
    if not state.camHelper then return end
    local target = findNearestTarget()
    if not target then return end
    camOrbitAngle = camOrbitAngle + dt * 0.6
    local radius = 6
    local offset = Vector3.new(math.cos(camOrbitAngle)*radius, 2.5, math.sin(camOrbitAngle)*radius)
    local camPos = target.Position + offset
    workspace.CurrentCamera.CFrame = CFrame.new(camPos, target.Position)
end

-- =========================
-- NOCLIP HANDLING
-- =========================
local function updateNoclip()
    if state.noclip then
        setNoclip(true)
    else
        setNoclip(false)
    end
end

-- =========================
-- MAIN LOOP
-- =========================
RunService.Heartbeat:Connect(function(dt)
    if not state.running then return end
    -- ensure character reference
    if not player.Character then return end

    updateNoclip()
    updateFly(dt)
    updateAimAssist(dt)
    updateCameraHelper(dt)
end)

-- =========================
-- HOTKEYS
-- =========================
UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.KeyCode == CONFIG.MenuToggleKey then
        screenGui.Enabled = not screenGui.Enabled
    elseif input.KeyCode == CONFIG.FlyToggleKey then
        state.fly = not state.fly
        setBtnState(btnFly, state.fly)
    elseif input.KeyCode == CONFIG.NoclipToggleKey then
        state.noclip = not state.noclip
        setBtnState(btnNoclip, state.noclip)
    elseif input.KeyCode == CONFIG.AimToggleKey then
        state.aimAssist = not state.aimAssist
        setBtnState(btnAim, state.aimAssist)
    elseif input.KeyCode == CONFIG.CameraToggleKey then
        state.camHelper = not state.camHelper
        setBtnState(btnCam, state.camHelper)
    end
end)

-- =========================
-- CLEANUP ON CHARACTER RESET
-- =========================
player.CharacterAdded:Connect(function(char)
    character = char
    wait(0.5)
    -- reapply noclip if needed
    updateNoclip()
end)

-- =========================
-- FINISH
-- =========================
print("[DevGodMenu] Loaded. Use GUI or hotkeys to toggle features. This is for Studio/testing only.")

