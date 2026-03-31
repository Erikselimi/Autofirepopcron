-- AutoPop Harness with GUI
-- Paste this into autopop.lua in your GitHub repo

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local networking = ReplicatedStorage
    :WaitForChild("Shared")
    :WaitForChild("Remotes")
    :WaitForChild("Networking")

local actionRemote = networking:WaitForChild("RE/Minigame/MinigameGameAction")

local state = {
    enabled = false,
    targetScale = 0.35,
    tolerance = 0.01,
    lastFired = 0,
    lastScale = 0,
}

local ringFrame = nil

-- Auto-hook: scan PlayerGui until ring appears
task.spawn(function()
    while true do
        local gui = playerGui:FindFirstChild("SoloPopcornBurstGui")
        if gui then
            local holder = gui:FindFirstChild("CircleHolder")
            if holder then
                local candidate = holder:FindFirstChild("Frame_3", true)
                if candidate and candidate:IsA("Frame") then
                    ringFrame = candidate
                end
            end
        end
        task.wait(0.2)
    end
end)

-- Fire AttemptPop
local function fireAttempt()
    actionRemote:FireServer("AttemptPop", workspace:GetServerTimeNow())
    state.lastFired = tick()
    print("[AutoPop] Fired at scale:", state.lastScale)
end

-- Scanner
RunService.Heartbeat:Connect(function()
    if state.enabled and ringFrame and ringFrame.Parent then
        local scale = ringFrame.Size.X.Scale
        state.lastScale = scale
        if math.abs(scale - state.targetScale) <= state.tolerance then
            if tick() - state.lastFired > 0.2 then
                fireAttempt()
            end
        end
    end
end)

-- GUI Overlay
local gui = Instance.new("ScreenGui")
gui.Name = "AutoPopGui"
gui.ResetOnSpawn = false
gui.Parent = playerGui

local frame = Instance.new("Frame")
frame.Parent = gui
frame.Position = UDim2.fromOffset(20, 20)
frame.Size = UDim2.fromOffset(300, 160)
frame.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
frame.BorderSizePixel = 0
Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 12)

local title = Instance.new("TextLabel")
title.Parent = frame
title.BackgroundTransparency = 1
title.Position = UDim2.fromOffset(12, 10)
title.Size = UDim2.new(1, -24, 0, 22)
title.Font = Enum.Font.GothamBold
title.Text = "AutoPop Controller"
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.TextSize = 18
title.TextXAlignment = Enum.TextXAlignment.Left

local status = Instance.new("TextLabel")
status.Parent = frame
status.BackgroundTransparency = 1
status.Position = UDim2.fromOffset(12, 40)
status.Size = UDim2.new(1, -24, 0, 18)
status.Font = Enum.Font.Gotham
status.TextColor3 = Color3.fromRGB(200, 200, 220)
status.TextSize = 14
status.TextXAlignment = Enum.TextXAlignment.Left

local function refreshStatus()
    status.Text = string.format(
        "Enabled: %s | Target: %.2f | Tol: %.2f | LastScale: %.2f",
        tostring(state.enabled),
        state.targetScale,
        state.tolerance,
        state.lastScale
    )
end

local toggle = Instance.new("TextButton")
toggle.Parent = frame
toggle.Position = UDim2.fromOffset(12, 70)
toggle.Size = UDim2.new(1, -24, 0, 30)
toggle.BackgroundColor3 = Color3.fromRGB(60, 60, 90)
toggle.Font = Enum.Font.GothamBold
toggle.TextColor3 = Color3.fromRGB(255, 255, 255)
toggle.TextSize = 14
Instance.new("UICorner", toggle).CornerRadius = UDim.new(0, 8)

toggle.MouseButton1Click:Connect(function()
    state.enabled = not state.enabled
    toggle.Text = state.enabled and "Disable AutoPop" or "Enable AutoPop"
    refreshStatus()
end)

local tolBox = Instance.new("TextBox")
tolBox.Parent = frame
tolBox.Position = UDim2.fromOffset(12, 110)
tolBox.Size = UDim2.fromOffset(140, 26)
tolBox.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
tolBox.Font = Enum.Font.Gotham
tolBox.Text = tostring(state.tolerance)
tolBox.TextColor3 = Color3.fromRGB(255, 255, 255)
tolBox.TextSize = 13
Instance.new("UICorner", tolBox).CornerRadius = UDim.new(0, 8)

tolBox.FocusLost:Connect(function()
    local n = tonumber(tolBox.Text)
    if n then state.tolerance = math.max(0, n) end
    tolBox.Text = tostring(state.tolerance)
    refreshStatus()
end)

refreshStatus()
