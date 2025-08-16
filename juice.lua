--!nolint BuiltinGlobalWrite
--!optimize 2
--!native

-- Edit TELEPORT_DELAY to change the time (in seconds) between teleports to each player
local TELEPORT_DELAY = 0.1

-- Edit TTS_MESSAGE to change the text spoken by the TTS system
local TTS_MESSAGE = "jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew "

-- Edit TOOL_CYCLE_DELAY to change the time (in seconds) between equipping/unequipping tools
local TOOL_CYCLE_DELAY = 0.1

-- Edit SERVER_HOP_DELAY to change the time (in seconds) before server hopping
local SERVER_HOP_DELAY = 40

-- Prevent multiple executions
if _G.TrollScriptExecuted then
    warn("Troll script already executed!")
    return
end
_G.TrollScriptExecuted = true

local function randomHex(len)
    local str = ""
    for i = 1, len do
        str = str .. string.format("%x", math.random(0, 15))
    end
    return str
end

local function randstr()
    local uuid = table.concat({
        randomHex(8),
        randomHex(4),
        randomHex(4),
        randomHex(4),
        randomHex(12)
    }, "-")
    return "Troll_" .. uuid
end

local GUI_ID = randstr()

local scriptUrl = "https://raw.githubusercontent.com/SystemNasa/roblox/refs/heads/main/juice.lua" -- Replace with your script's raw GitHub URL

local queueTeleport = (syn and syn.queue_on_teleport) or
                     (fluxus and fluxus.queue_on_teleport) or
                     queue_on_teleport or
                     function() warn("queue_on_teleport not supported by this executor!") end

local rawgs = clonefunction and clonefunction(game.GetService) or game.GetService
local function gs(service)
    local ok, result = pcall(function()
        return rawgs(game, service)
    end)
    return ok and result or nil
end

local function define(instance)
    if cloneref then
        local ok, protected = pcall(cloneref, instance)
        if ok and protected then
            return protected
        end
    end
    return instance
end

local ReplicatedStorage = define(gs("ReplicatedStorage"))
local Players = define(gs("Players"))
local Workspace = define(gs("Workspace"))
local RunService = define(gs("RunService"))
local TweenService = define(gs("TweenService"))
local HttpService = define(gs("HttpService"))
local TeleportService = define(gs("TeleportService"))
local player = define(Players.LocalPlayer)
local TTS = ReplicatedStorage:WaitForChild("TTS")
local proximityPrompt = Workspace.Map.RoomExtra.Model.Activate.ProximityPrompt

local COLORS = {
    BACKGROUND = Color3.fromRGB(25, 25, 30),
    BUTTON = Color3.fromRGB(57, 57, 57),
    BUTTON_HOVER = Color3.fromRGB(77, 77, 77),
    BUTTON_ACTIVE = Color3.fromRGB(0, 150, 0),
    BUTTON_INACTIVE = Color3.fromRGB(45, 45, 50),
    TEXT_PRIMARY = Color3.fromRGB(255, 255, 255),
    TEXT_SECONDARY = Color3.fromRGB(0, 0, 0),
    STROKE = Color3.fromRGB(50, 50, 60),
    NOTIFICATION_SUCCESS = Color3.fromRGB(100, 255, 100),
    NOTIFICATION_ERROR = Color3.fromRGB(255, 100, 100),
    NOTIFICATION_WARNING = Color3.fromRGB(255, 165, 0)
}

local character = player.Character or player.CharacterAdded:Wait()
local humanoidRootPart = character:WaitForChild("HumanoidRootPart")
local humanoid = character:WaitForChild("Humanoid")

for _, obj in ipairs(Workspace:GetDescendants()) do
    if obj:IsA("Seat") or obj:IsA("VehicleSeat") then
        obj:Destroy()
    end
end
humanoid:SetStateEnabled(Enum.HumanoidStateType.Seated, false)

local promptPos = proximityPrompt.Parent.Position
humanoidRootPart.CFrame = CFrame.new(promptPos + Vector3.new(2, 0, 0))
task.wait(0.5)
proximityPrompt:InputHoldBegin()
task.wait(0.1)
proximityPrompt:InputHoldEnd()

local targetItemNames = {"aura", "Fluffy Satin Gloves Black", "fuzzy"}
local function hasItemInName(accessory)
    if not accessory or not accessory.Name then return false end
    local accessoryName = accessory.Name:lower()
    for _, itemName in ipairs(targetItemNames) do
        if accessoryName:find(itemName:lower(), 1, true) then
            return true
        end
    end
    return false
end

local function isAccessoryOnHeadOrAbove(accessory)
    if not accessory or not accessory.Parent then return false end
    local handle = accessory:FindFirstChild("Handle")
    if handle and handle.Parent and handle.Parent.Name == "Head" then return true end
    local attachment = accessory:FindFirstChildWhichIsA("Attachment")
    if attachment and attachment.Parent and attachment.Parent.Name == "Head" then return true end
    if accessory.Parent and accessory.Parent:IsA("Model") then
        local head = accessory.Parent:FindFirstChild("Head")
        if head and handle and handle.Position.Y >= head.Position.Y then return true end
    end
    return false
end

local function removeTargetedItems(character)
    if not character or not character.Parent then return end
    for _, item in ipairs(character:GetChildren()) do
        if item:IsA("Accessory") and hasItemInName(item) and not isAccessoryOnHeadOrAbove(item) then
            local success, err = pcall(function()
                item:Destroy()
                createNotification("Destroyed " .. item.Name .. " on " .. character.Name, COLORS.NOTIFICATION_WARNING)
            end)
            if not success then
                createNotification("Failed to destroy " .. item.Name .. ": " .. tostring(err), COLORS.NOTIFICATION_ERROR)
            end
        end
    end
end

local function continuouslyCheckItems()
    while true do
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr and plr.Character then
                pcall(removeTargetedItems, plr.Character)
            end
        end
        task.wait(1)
    end
end
task.spawn(continuouslyCheckItems)

local function createNotification(text, color)
    local notifyFrame = Instance.new("Frame")
    notifyFrame.Size = UDim2.new(0, 200, 0, 50)
    notifyFrame.BackgroundColor3 = COLORS.BACKGROUND
    notifyFrame.BackgroundTransparency = 0.2
    notifyFrame.BorderSizePixel = 0
    notifyFrame.Parent = notifyContainer
    notifyFrame.LayoutOrder = -tick()

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = notifyFrame

    local stroke = Instance.new("UIStroke")
    stroke.Thickness = 1
    stroke.Color = COLORS.STROKE
    stroke.Transparency = 0.5
    stroke.Parent = notifyFrame

    local textLabel = Instance.new("TextLabel")
    textLabel.Size = UDim2.new(1, -10, 1, -10)
    textLabel.Position = UDim2.new(0, 5, 0, 5)
    textLabel.BackgroundTransparency = 1
    textLabel.Text = text
    textLabel.TextColor3 = color
    textLabel.Font = Enum.Font.Gotham
    textLabel.TextSize = 16
    textLabel.TextWrapped = true
    textLabel.TextXAlignment = Enum.TextXAlignment.Left
    textLabel.Parent = notifyFrame

    local tweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    TweenService:Create(notifyFrame, tweenInfo, {BackgroundTransparency = 0}):Play()
    task.spawn(function()
        task.wait(3)
        TweenService:Create(notifyFrame, tweenInfo, {BackgroundTransparency = 0.8}):Play()
        task.wait(0.3)
        notifyFrame:Destroy()
    end)
end

local function copyAvatarAndGetTools()
    local success, err = pcall(function()
        local Event = ReplicatedStorage:FindFirstChild("EventInputModify")
        if Event then
            Event:FireServer("24k_mxtty1")
            createNotification("Copied avatar of 24k_mxtty1", COLORS.NOTIFICATION_SUCCESS)
        else
            error("EventInputModify not found")
        end
    end)
    if not success then
        createNotification("Failed to copy avatar: " .. tostring(err), COLORS.NOTIFICATION_ERROR)
    end

    local tools = {
        "DangerCarot",
        "DangerBlowDryer",
        "DangerPistol",
        "FoodBloxi",
        "DangerSpray",
        "FoodPizza",
        "FoodChocolate"
    }
    for _, toolName in ipairs(tools) do
        local success, err = pcall(function()
            local Event = ReplicatedStorage:FindFirstChild("Tool")
            if Event then
                Event:FireServer(toolName)
                createNotification("Acquired tool: " .. toolName, COLORS.NOTIFICATION_SUCCESS)
            else
                error("Tool event not found")
            end
        end)
        if not success then
            createNotification("Failed to acquire " .. toolName .. ": " .. tostring(err), COLORS.NOTIFICATION_ERROR)
        end
        task.wait(0.1)
    end
end

local function toolLoop()
    while true do
        local backpack = player.Backpack
        local character = player.Character
        local humanoid = character and character:FindFirstChild("Humanoid")
        if humanoid and backpack then
            for _, tool in pairs(backpack:GetChildren()) do
                if tool:IsA("Tool") then
                    humanoid:EquipTool(tool)
                    task.wait(TOOL_CYCLE_DELAY)
                    humanoid:UnequipTools()
                    task.wait(TOOL_CYCLE_DELAY)
                end
            end
        else
            task.wait(0.1)
        end
    end
end

local function teleportLoop()
    while true do
        local players = Players:GetPlayers()
        for _, other in ipairs(players) do
            if other ~= player and other.Character and other.Character:FindFirstChild("HumanoidRootPart") then
                humanoidRootPart.CFrame = CFrame.new(other.Character.HumanoidRootPart.Position + Vector3.new(2, 0, 0))
                task.wait(TELEPORT_DELAY)
            end
        end
    end
end

task.spawn(function()
    copyAvatarAndGetTools()
    task.wait(1)
    task.spawn(toolLoop)
end)
task.spawn(teleportLoop)

task.spawn(function()
    while true do
        TTS:FireServer(TTS_MESSAGE, "9")
        task.wait(15)
    end
end)

local notifyContainer = Instance.new("Frame")
notifyContainer.Size = UDim2.new(0, 200, 0, 300)
notifyContainer.Position = UDim2.new(1, -210, 1, -310)
notifyContainer.BackgroundTransparency = 1
notifyContainer.Parent = spectateGui

local notifyLayout = Instance.new("UIListLayout")
notifyLayout.SortOrder = Enum.SortOrder.LayoutOrder
notifyLayout.Padding = UDim.new(0, 5)
notifyLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
notifyLayout.Parent = notifyContainer

local spectateGui = Instance.new("ScreenGui")
spectateGui.Name = GUI_ID
spectateGui.Parent = gethui()
spectateGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
spectateGui.ResetOnSpawn = false

local spectateFrame = Instance.new("Frame")
spectateFrame.Name = "SpectateFrame"
spectateFrame.Parent = spectateGui
spectateFrame.BackgroundColor3 = COLORS.BACKGROUND
spectateFrame.BackgroundTransparency = 1
spectateFrame.BorderSizePixel = 0
spectateFrame.Position = UDim2.new(0, 0, 0.8, 0)
spectateFrame.Size = UDim2.new(1, 0, 0.2, 0)

local leftBtn = Instance.new("TextButton")
leftBtn.Name = "Left"
leftBtn.Parent = spectateFrame
leftBtn.BackgroundColor3 = COLORS.BUTTON
leftBtn.BackgroundTransparency = 0.25
leftBtn.BorderSizePixel = 0
leftBtn.Position = UDim2.new(0.183150187, 0, 0.238433674, 0)
leftBtn.Size = UDim2.new(0.0688644722, 0, 0.514322877, 0)
leftBtn.Font = Enum.Font.FredokaOne
leftBtn.Text = "<"
leftBtn.TextColor3 = COLORS.TEXT_SECONDARY
leftBtn.TextScaled = true

local rightBtn = Instance.new("TextButton")
rightBtn.Name = "Right"
rightBtn.Parent = spectateFrame
rightBtn.BackgroundColor3 = COLORS.BUTTON
rightBtn.BackgroundTransparency = 0.25
rightBtn.BorderSizePixel = 0
rightBtn.Position = UDim2.new(0.747985363, 0, 0.238433674, 0)
rightBtn.Size = UDim2.new(0.0688644722, 0, 0.514322877, 0)
rightBtn.Font = Enum.Font.FredokaOne
rightBtn.Text = ">"
rightBtn.TextColor3 = COLORS.TEXT_SECONDARY
rightBtn.TextScaled = true

local playerDisplay = Instance.new("TextLabel")
playerDisplay.Name = "PlayerDisplay"
playerDisplay.Parent = spectateFrame
playerDisplay.BackgroundTransparency = 1
playerDisplay.Position = UDim2.new(0.252014756, 0, 0.238433674, 0)
playerDisplay.Size = UDim2.new(0.495970696, 0, 0.514322877, 0)
playerDisplay.Font = Enum.Font.FredokaOne
playerDisplay.Text = "No Players"
playerDisplay.TextColor3 = COLORS.TEXT_PRIMARY
playerDisplay.TextScaled = true

local playerIndex = Instance.new("NumberValue")
playerIndex.Name = "PlayerIndex"
playerIndex.Parent = spectateFrame
playerIndex.Value = 1

local stroke1 = Instance.new("UIStroke")
stroke1.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
stroke1.Thickness = 5
stroke1.Color = COLORS.STROKE
stroke1.Parent = leftBtn

local stroke2 = Instance.new("UIStroke")
stroke2.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
stroke2.Thickness = 5
stroke2.Color = COLORS.STROKE
stroke2.Parent = rightBtn

local stroke3 = Instance.new("UIStroke")
stroke3.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
stroke3.Thickness = 5
stroke3.Color = COLORS.STROKE
stroke3.Parent = playerDisplay

local allPlayers = {}
local spectateTarget = nil
local spectating = true
local cam = Workspace.CurrentCamera

local function updatePlayers(leavingPlayer)
    allPlayers = {}
    for _, plr in pairs(Players:GetPlayers()) do
        if plr ~= player then
            table.insert(allPlayers, plr)
            createNotification(plr.Name .. " joined", COLORS.NOTIFICATION_SUCCESS)
        end
    end
    if #allPlayers > 0 then
        if leavingPlayer and leavingPlayer == spectateTarget then
            createNotification(leavingPlayer.Name .. " left", COLORS.NOTIFICATION_ERROR)
            playerIndex.Value = math.clamp(playerIndex.Value, 1, #allPlayers)
            spectateTarget = allPlayers[playerIndex.Value]
        else
            local newIndex = table.find(allPlayers, spectateTarget) or 1
            playerIndex.Value = math.clamp(newIndex, 1, #allPlayers)
            spectateTarget = allPlayers[playerIndex.Value]
        end
        playerDisplay.Text = spectateTarget and spectateTarget.Name or "No Players"
    else
        playerIndex.Value = 1
        spectateTarget = nil
        playerDisplay.Text = "No Players"
        spectating = false
        cam.CameraSubject = player.Character and player.Character:FindFirstChild("Humanoid") or nil
    end
end
updatePlayers()

Players.PlayerAdded:Connect(function(plr)
    updatePlayers()
    if #allPlayers > 0 and not spectateTarget then
        spectating = true
        playerIndex.Value = 1
        spectateTarget = allPlayers[1]
        playerDisplay.Text = spectateTarget.Name
    end
end)

Players.PlayerRemoving:Connect(function(plr)
    updatePlayers(plr)
end)

local function onPress(skip)
    if #allPlayers == 0 then
        playerDisplay.Text = "No Players"
        spectating = false
        return
    end
    local newIndex = playerIndex.Value + skip
    if newIndex > #allPlayers then
        newIndex = 1
    elseif newIndex < 1 then
        newIndex = #allPlayers
    end
    playerIndex.Value = newIndex
    spectateTarget = allPlayers[playerIndex.Value]
    spectating = true
    playerDisplay.Text = spectateTarget and spectateTarget.Name or "No Players"
end

leftBtn.MouseButton1Click:Connect(function() onPress(-1) end)
rightBtn.MouseButton1Click:Connect(function() onPress(1) end)

RunService.RenderStepped:Connect(function()
    if spectating and #allPlayers > 0 and spectateTarget and spectateTarget.Character then
        local targetHumanoid = spectateTarget.Character:FindFirstChild("Humanoid")
        if targetHumanoid then
            cam.CameraSubject = targetHumanoid
            playerDisplay.Text = spectateTarget.Name
        else
            playerDisplay.Text = "No Character"
        end
    else
        spectating = false
        playerDisplay.Text = "No Players"
        cam.CameraSubject = player.Character and player.Character:FindFirstChild("Humanoid") or nil
    end
end)

local function updateStrokeThickness()
    local screenSize = Workspace.CurrentCamera.ViewportSize
    local scaleFactor = screenSize.X / 1920
    stroke1.Thickness = 5 * scaleFactor * 1.25
    stroke2.Thickness = 5 * scaleFactor * 1.25
    stroke3.Thickness = 5 * scaleFactor * 1.25
end
RunService.RenderStepped:Connect(updateStrokeThickness)

local timerLabel = Instance.new("TextLabel")
timerLabel.Size = UDim2.new(0, 200, 0, 30)
timerLabel.Position = UDim2.new(1, -210, 0, 10)
timerLabel.BackgroundTransparency = 1
timerLabel.Text = "Server Hop: " .. SERVER_HOP_DELAY .. "s"
timerLabel.TextColor3 = COLORS.NOTIFICATION_WARNING
timerLabel.Font = Enum.Font.Gotham
timerLabel.TextSize = 18
timerLabel.TextXAlignment = Enum.TextXAlignment.Right
timerLabel.Parent = spectateGui

local function startTimer(initialTime, onComplete)
    local timeRemaining = initialTime or SERVER_HOP_DELAY
    timerLabel.Text = "Server Hop: " .. math.ceil(timeRemaining) .. "s"
    
    local connection
    connection = RunService.Heartbeat:Connect(function()
        timeRemaining = timeRemaining - RunService.Heartbeat:Wait()
        if timeRemaining <= 0 then
            connection:Disconnect()
            timerLabel.Text = "Server Hop: Now"
            if onComplete then
                onComplete()
            end
        else
            timerLabel.Text = "Server Hop: " .. math.ceil(timeRemaining) .. "s"
        end
    end)
    
    return connection
end

local function serverHop()
    local attempt = 1
    local timerConnection
    local baseDelay = 3

    local function attemptHop()
        local originalJobId = game.JobId
        createNotification("Fetching servers (Attempt " .. attempt .. ")...", COLORS.NOTIFICATION_WARNING)
        local servers = {}
        local success, response = pcall(function()
            return HttpService:JSONDecode(game:HttpGet("https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100"))
        end)
        if success and response and response.data then
            for _, v in pairs(response.data) do
                if v.playing < v.maxPlayers and v.id ~= game.JobId then
                    table.insert(servers, v.id)
                end
            end
        else
            createNotification("Failed to fetch servers. Retrying in " .. baseDelay * attempt .. "s...", COLORS.NOTIFICATION_ERROR)
            if timerConnection then timerConnection:Disconnect() end
            timerConnection = startTimer(baseDelay * attempt, attemptHop)
            attempt = attempt + 1
            return
        end

        if #servers > 0 then
            local randomServer = servers[math.random(1, #servers)]
            createNotification("Attempting to join server " .. randomServer .. "...", COLORS.NOTIFICATION_WARNING)
            
            local queueSuccess, queueError = pcall(function()
                queueTeleport([[
                    loadstring(game:HttpGet("]] .. scriptUrl .. [["))()
                ]])
            end)
            if queueSuccess then
                createNotification("Script queued for re-execution!", COLORS.NOTIFICATION_SUCCESS)
            else
                createNotification("Failed to queue script: " .. tostring(queueError), COLORS.NOTIFICATION_ERROR)
                warn("Queue teleport failed: " .. tostring(queueError))
            end

            local success, result = pcall(function()
                TeleportService:TeleportToPlaceInstance(game.PlaceId, randomServer, player)
            end)
            if not success then
                createNotification("Teleport failed: " .. tostring(result) .. ". Retrying in " .. baseDelay * attempt .. "s...", COLORS.NOTIFICATION_ERROR)
                if timerConnection then timerConnection:Disconnect() end
                timerConnection = startTimer(baseDelay * attempt, attemptHop)
                attempt = attempt + 1
            else
                task.wait(3)
                if game.JobId == originalJobId then
                    createNotification("Server full or failed to join. Retrying in " .. baseDelay * attempt .. "s...", COLORS.NOTIFICATION_ERROR)
                    if timerConnection then timerConnection:Disconnect() end
                    timerConnection = startTimer(baseDelay * attempt, attemptHop)
                    attempt = attempt + 1
                else
                    createNotification("Successfully joined new server!", COLORS.NOTIFICATION_SUCCESS)
                    if timerConnection then timerConnection:Disconnect() end
                    timerLabel.Text = "Server Hop: Success"
                end
            end
        else
            createNotification("No available servers. Retrying in " .. baseDelay * attempt .. "s...", COLORS.NOTIFICATION_ERROR)
            if timerConnection then timerConnection:Disconnect() end
            timerConnection = startTimer(baseDelay * attempt, attemptHop)
            attempt = attempt + 1
        end
    end

    attemptHop()
end

startTimer(SERVER_HOP_DELAY, serverHop)

player.OnTeleport:Connect(function(state)
    if state == Enum.TeleportState.Started then
        local success, err = pcall(function()
            queueTeleport([[
                loadstring(game:HttpGet("]] .. scriptUrl .. [["))()
            ]])
        end)
        if success then
            createNotification("Script queued for teleport!", COLORS.NOTIFICATION_SUCCESS)
        else
            createNotification("Failed to queue script for teleport: " .. tostring(err), COLORS.NOTIFICATION_ERROR)
            warn("Teleport queue failed: " .. tostring(err))
        end
    end
end)
