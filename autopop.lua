-- God Menu Auto-Collect GUI with CarryVisuals + Set Teleport Point
local player = game.Players.LocalPlayer
local char = player.Character or player.CharacterAdded:Wait()
local hrp = char:WaitForChild("HumanoidRootPart")

-- GUI setup
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "GodMenu"
screenGui.ResetOnSpawn = false
screenGui.Parent = player:WaitForChild("PlayerGui")

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 250, 0, 450)
frame.Position = UDim2.new(0.7, -125, 0.5, -225)
frame.BackgroundColor3 = Color3.fromRGB(30,30,30)
frame.BorderSizePixel = 0
frame.Active = true
frame.Draggable = true
frame.Parent = screenGui

local uiCorner = Instance.new("UICorner")
uiCorner.CornerRadius = UDim.new(0,12)
uiCorner.Parent = frame

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1,0,0,40)
title.BackgroundTransparency = 1
title.Text = "God Menu"
title.TextColor3 = Color3.fromRGB(255,215,0)
title.Font = Enum.Font.SourceSansBold
title.TextSize = 20
title.Parent = frame

local status = Instance.new("TextLabel")
status.Size = UDim2.new(1,0,0,30)
status.Position = UDim2.new(0,0,0,40)
status.BackgroundTransparency = 1
status.Text = "Idle"
status.TextColor3 = Color3.fromRGB(200,200,200)
status.Font = Enum.Font.SourceSans
status.TextSize = 18
status.Parent = frame

local scrolling = Instance.new("ScrollingFrame")
scrolling.Size = UDim2.new(1,0,1,-80)
scrolling.Position = UDim2.new(0,0,0,80)
scrolling.CanvasSize = UDim2.new(0,0,0,700)
scrolling.ScrollBarThickness = 6
scrolling.BackgroundTransparency = 1
scrolling.Parent = frame

local uiList = Instance.new("UIListLayout")
uiList.Padding = UDim.new(0,6)
uiList.Parent = scrolling

-- Zones list
local zones = {
    {"Common", Color3.fromRGB(180,180,180)},
    {"Uncommon", Color3.fromRGB(100,200,100)},
    {"Rare", Color3.fromRGB(50,100,200)},
    {"Epic", Color3.fromRGB(150,50,200)},
    {"Legendary", Color3.fromRGB(255,215,0)},
    {"Mythical", Color3.fromRGB(200,150,50)},
    {"Secret", Color3.fromRGB(50,50,50)},
    {"Celestial", Color3.fromRGB(200,200,50)},
    {"Cosmic", Color3.fromRGB(50,200,200)},
}

-- Saved teleport point
local savedCFrame = nil

-- Helper: wait until CarryVisuals gets a child
local function waitForCarryVisual()
    local playerFolder = workspace:FindFirstChild(player.Name)
    if not playerFolder then return false end
    local carryVisuals = playerFolder:FindFirstChild("CarryVisuals")
    if not carryVisuals then return false end

    status.Text = "Waiting for pickup..."
    local picked = false
    local conn
    conn = carryVisuals.ChildAdded:Connect(function(child)
        status.Text = "Picked up: "..child.Name
        picked = true
        conn:Disconnect()
    end)

    while not picked do task.wait(0.1) end
    return true
end

-- Collect from one zone
local function collectFromZone(zoneName)
    status.Text = "Teleporting to "..zoneName.." zone..."
    local zonesFolder = workspace:WaitForChild("Zones")
    local zoneMarker = zonesFolder:FindFirstChild(zoneName)
    if zoneMarker and zoneMarker:IsA("BasePart") then
        hrp.CFrame = zoneMarker.CFrame + Vector3.new(0,5,0)
        task.wait(2)
    end

    local itemSpawners = workspace:WaitForChild("ItemSpawners")
    local zone = itemSpawners:WaitForChild(zoneName)
    local spawnedItems = {}
    for _, spawned in pairs(zone:GetChildren()) do
        if spawned.Name == "SpawnedItem" and spawned:IsA("Model") and spawned.PrimaryPart then
            table.insert(spawnedItems, spawned.PrimaryPart)
        end
    end

    for i = 1, math.min(6, #spawnedItems) do
        local target = spawnedItems[i]
        status.Text = "At "..zoneName.." item "..i.."/"..math.min(6,#spawnedItems)
        hrp.CFrame = target.CFrame + Vector3.new(0,5,0)
        waitForCarryVisual()
        task.wait(3)
    end
    status.Text = "Finished "..zoneName
end

-- Add Set Teleport Point button
local setButton = Instance.new("TextButton")
setButton.Size = UDim2.new(1,-10,0,40)
setButton.BackgroundColor3 = Color3.fromRGB(100,200,100)
setButton.Text = "Set Teleport Point"
setButton.TextColor3 = Color3.new(0,0,0)
setButton.Font = Enum.Font.SourceSansBold
setButton.TextSize = 18
setButton.Parent = scrolling
Instance.new("UICorner", setButton).CornerRadius = UDim.new(0,8)

setButton.MouseButton1Click:Connect(function()
    savedCFrame = hrp.CFrame
    status.Text = "Teleport point saved!"
end)

-- Add Teleport to Saved Point button
local tpButton = Instance.new("TextButton")
tpButton.Size = UDim2.new(1,-10,0,40)
tpButton.BackgroundColor3 = Color3.fromRGB(50,150,250)
tpButton.Text = "Teleport to Saved Point"
tpButton.TextColor3 = Color3.new(0,0,0)
tpButton.Font = Enum.Font.SourceSansBold
tpButton.TextSize = 18
tpButton.Parent = scrolling
Instance.new("UICorner", tpButton).CornerRadius = UDim.new(0,8)

tpButton.MouseButton1Click:Connect(function()
    if savedCFrame then
        hrp.CFrame = savedCFrame + Vector3.new(0,5,0)
        status.Text = "Teleported to saved point!"
    else
        status.Text = "No point set yet!"
    end
end)

-- Add zone buttons
for _, data in ipairs(zones) do
    local name, color = data[1], data[2]
    local button = Instance.new("TextButton")
    button.Size = UDim2.new(1,-10,0,40)
    button.BackgroundColor3 = color
    button.Text = "Collect "..name
    button.TextColor3 = Color3.new(0,0,0)
    button.Font = Enum.Font.SourceSansBold
    button.TextSize = 18
    button.Parent = scrolling

    Instance.new("UICorner", button).CornerRadius = UDim.new(0,8)

    button.MouseButton1Click:Connect(function()
        collectFromZone(name)
    end)
end
