-- AutoPop Harness with Ring Hook
-- Safe for your own minigame testing

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local networking = ReplicatedStorage
    :WaitForChild("Shared")
    :WaitForChild("Remotes")
    :WaitForChild("Networking")

local actionRemote = networking:WaitForChild("RE/Minigame/MinigameGameAction")

-- State
local state = {
    enabled = true,
    targetScale = 0.35, -- sweet spot
    tolerance = 0.01,
    lastScale = 0,
    lastFired = 0,
}

-- Ring reference
local ringFrame = nil

-- Hook function: game calls this when a new ring is created
_G.AutoPopHarness = {
    setRing = function(frame)
        ringFrame = frame
        print("[AutoPop] Hooked new ring:", frame)
    end
}

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
