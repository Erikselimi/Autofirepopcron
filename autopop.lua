-- AutoPop Harness that waits for ring
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local networking = ReplicatedStorage
    :WaitForChild("Shared")
    :WaitForChild("Remotes")
    :WaitForChild("Networking")

local actionRemote = networking:WaitForChild("RE/Minigame/MinigameGameAction")

local state = {
    enabled = true,
    targetScale = 0.35,
    tolerance = 0.01,
    lastFired = 0,
}

local ringFrame = nil

-- Watch PlayerGui for the ring
task.spawn(function()
    while true do
        -- look for the SoloPopcornBurstGui and its CircleHolder
        local gui = player:WaitForChild("PlayerGui"):FindFirstChild("SoloPopcornBurstGui")
        if gui then
            local holder = gui:FindFirstChild("CircleHolder")
            if holder then
                -- look for Frame_3 (the shrinking ring)
                local candidate = holder:FindFirstChild("Frame_3", true)
                if candidate and candidate:IsA("Frame") then
                    ringFrame = candidate
                    print("[AutoPop] Found ring:", ringFrame)
                end
            end
        end
        task.wait(0.2)
    end
end)

-- Fire AttemptPop with correct server time
local function fireAttempt()
    actionRemote:FireServer("AttemptPop", workspace:GetServerTimeNow())
    state.lastFired = tick()
    print("[AutoPop] Fired at scale:", state.lastScale)
end

-- Live scanner
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
