-- Troll script for Roblox: Handles !stop, !hop, !annoy, and !lag commands.
-- Commands announced once on start, no spectating functionality.

-- Configuration
local TELEPORT_DELAY = 0.1 -- Time between teleports to each player
local TTS_MESSAGE = "jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew "
local TOOL_CYCLE_DELAY = 0.1 -- Time between equipping/unequipping tools
local SERVER_HOP_DELAY = 70 -- Time before inactivity server hop
local LAG_DURATION = 30 -- Duration for !lag command in seconds
local TTS_ON_JOIN_MESSAGE = "Bot has joined the game! Ready to troll!" -- New TTS message on join

-- Prevent multiple executions
if _G.TrollScriptExecuted then
    warn("Troll script already executed!")
    return
end
_G.TrollScriptExecuted = true

-- Global flags
_G.TrollingActive = true
_G.AnnoyMode = false
_G.LagMode = false
_G.AnnoyTarget = nil
_G.LastInteractionTime = tick()

-- Utility functions
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
local scriptUrl = "https://raw.githubusercontent.com/SystemNasa/roblox/refs/heads/main/juice.lua" -- Ensure this URL is correct

-- Executor compatibility
local queueTeleport = (syn and syn.queue_on_teleport) or
                     (fluxus and fluxus.queue_on_teleport) or
                     queue_on_teleport or
                     function() warn("queue_on_teleport not supported by this executor!") end

local rawgs = clonefunction and clonefunction(game.GetService) or game.GetService
local function gs(service)
    local ok, result = pcall(rawgs, game, service)
    return ok and result or nil
end

local function define(instance)
    if cloneref then
        local ok, protected = pcall(cloneref, instance)
        if ok and protected then return protected end
    end
    return instance
end

-- Services
local ReplicatedStorage = define(gs("ReplicatedStorage"))
local Players = define(gs("Players"))
local Workspace = define(gs("Workspace"))
local RunService = define(gs("RunService"))
local TweenService = define(gs("TweenService"))
local HttpService = define(gs("HttpService"))
local TeleportService = define(gs("TeleportService"))
local TextChatService = define(gs("TextChatService"))
local player = define(Players.LocalPlayer)
local TTS = ReplicatedStorage and ReplicatedStorage:FindFirstChild("TTS")
local proximityPrompt = Workspace and Workspace:FindFirstChild("Map") and Workspace.Map:FindFirstChild("RoomExtra") and Workspace.Map.RoomExtra:FindFirstChild("Model") and Workspace.Map.RoomExtra.Model:FindFirstChild("Activate") and Workspace.Map.RoomExtra.Model.Activate:FindFirstChild("ProximityPrompt")

-- Colors for UI
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

-- Player setup
local character = player.Character or player.CharacterAdded:Wait()
local humanoidRootPart = character:WaitForChild("HumanoidRootPart")
local humanoid = character:WaitForChild("Humanoid")

-- Handle character respawn
player.CharacterAdded:Connect(function(newChar)
    character = newChar
    humanoidRootPart = newChar:WaitForChild("HumanoidRootPart")
    humanoid = newChar:WaitForChild("Humanoid")
end)

-- Disable seats
for _, obj in ipairs(Workspace:GetDescendants()) do
    if obj:IsA("Seat") or obj:IsA("VehicleSeat") then
        obj:Destroy()
    end
end
humanoid:SetStateEnabled(Enum.HumanoidStateType.Seated, false)

-- Activate proximity prompt
if proximityPrompt then
    local promptPos = proximityPrompt.Parent.Position
    humanoidRootPart.CFrame = CFrame.new(promptPos + Vector3.new(2, 0, 0))
    task.wait(0.5)
    proximityPrompt:InputHoldBegin()
    task.wait(0.1)
    proximityPrompt:InputHoldEnd()
else
    createNotification("ProximityPrompt not found!", COLORS.NOTIFICATION_ERROR)
end

-- Notification UI
local function createNotification(text, color)
    local notifyContainer = Instance.new("Frame")
    notifyContainer.Size = UDim2.new(0, 200, 0, 300)
    notifyContainer.Position = UDim2.new(1, -210, 1, -310)
    notifyContainer.BackgroundTransparency = 1
    notifyContainer.Parent = gethui and gethui() or game.CoreGui

    local notifyLayout = Instance.new("UIListLayout")
    notifyLayout.SortOrder = Enum.SortOrder.LayoutOrder
    notifyLayout.Padding = UDim.new(0, 5)
    notifyLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
    notifyLayout.Parent = notifyContainer

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

-- Chat functions
local function sendChatMessage(message)
    local success, err = pcall(function()
        if TextChatService then
            local textChannels = TextChatService:WaitForChild("TextChannels")
            local channel = textChannels:FindFirstChild("RBXGeneral") or textChannels:GetChildren()[1]
            if channel then
                channel:SendAsync(message)
            else
                warn("No text channel found for sending message")
            end
        else
            ReplicatedStorage.DefaultChatSystemChatEvents.SayMessageRequest:FireServer(message, "All")
        end
    end)
    if not success then
        warn("Failed to send chat message: " .. tostring(err))
        createNotification("Chat message failed: " .. tostring(err), COLORS.NOTIFICATION_ERROR)
    end
end

-- TTS function
local function sendTTSMessage(message, voice)
    if TTS then
        local success, err = pcall(function()
            TTS:FireServer(message, voice or "9")
        end)
        if not success then
            createNotification("TTS failed: " .. tostring(err), COLORS.NOTIFICATION_ERROR)
        end
    else
        createNotification("TTS remote not found!", COLORS.NOTIFICATION_ERROR)
    end
end

-- Item removal
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
    while _G.TrollingActive do
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr and plr.Character then
                pcall(removeTargetedItems, plr.Character)
            end
        end
        task.wait(1)
    end
end
task.spawn(continuouslyCheckItems)

-- Avatar and tools
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

-- Tool cycling loop
local function toolLoop()
    while _G.TrollingActive or _G.AnnoyMode or _G.LagMode do
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

-- Teleport loop for trolling
local function teleportLoop()
    while _G.TrollingActive do
        local players = Players:GetPlayers()
        for _, other in ipairs(players) do
            if other ~= player and other.Character and other.Character:FindFirstChild("HumanoidRootPart") then
                humanoidRootPart.CFrame = CFrame.new(other.Character.HumanoidRootPart.Position + Vector3.new(2, 0, 0))
                task.wait(TELEPORT_DELAY)
            end
        end
        -- Send TTS during trolling
        sendTTSMessage(TTS_MESSAGE, "9")
    end
end

-- Teleport loop for annoy mode
local function annoyTeleportLoop()
    while _G.AnnoyMode do
        if _G.AnnoyTarget and _G.AnnoyTarget.Character and _G.AnnoyTarget.Character:FindFirstChild("HumanoidRootPart") then
            humanoidRootPart.CFrame = CFrame.new(_G.AnnoyTarget.Character.HumanoidRootPart.Position + Vector3.new(2, 0, 0))
        end
        task.wait(TELEPORT_DELAY)
    end
end

-- TTS loop for annoy mode
local function annoyTTSLoop()
    while _G.AnnoyMode do
        sendTTSMessage(TTS_MESSAGE, "9")
        task.wait(15)
    end
end

-- Lag server function
local function lagServer()
    if _G.LagMode or _G.TrollingActive or _G.AnnoyMode then
        sendChatMessage("⚠️ Cannot lag server while trolling, annoying, or lagging!")
        createNotification("Cannot lag: Another mode is active", COLORS.NOTIFICATION_ERROR)
        return
    end
    _G.LagMode = true
    sendChatMessage("🔥 Lagging server for " .. LAG_DURATION .. " seconds!")
    createNotification("Lagging server for " .. LAG_DURATION .. " seconds", COLORS.NOTIFICATION_WARNING)
    sendTTSMessage("Lagging server for " .. LAG_DURATION .. " seconds!", "9")

    local startTime = tick()
    task.spawn(function()
        while _G.LagMode and tick() - startTime < LAG_DURATION do
            local character = player.Character
            local humanoid = character and character:FindFirstChild("Humanoid")
            local humanoidRootPart = character and character:FindFirstChild("HumanoidRootPart")
            if not character or not humanoid or not humanoidRootPart then
                createNotification("Character not loaded, skipping lag cycle", COLORS.NOTIFICATION_ERROR)
                task.wait(0.1)
                continue
            end

            local success, err = pcall(function()
                for _, other in ipairs(Players:GetPlayers()) do
                    if other ~= player and other.Character and other.Character:FindFirstChild("HumanoidRootPart") then
                        humanoidRootPart.CFrame = CFrame.new(other.Character.HumanoidRootPart.Position + Vector3.new(2, 0, 0))
                    end
                end
            end)
            if not success then
                createNotification("Teleport failed in lag: " .. tostring(err), COLORS.NOTIFICATION_ERROR)
            end
            task.wait(TELEPORT_DELAY)

            success, err = pcall(function()
                local backpack = player.Backpack
                if humanoid and backpack then
                    for _, tool in pairs(backpack:GetChildren()) do
                        if tool:IsA("Tool") then
                            humanoid:EquipTool(tool)
                            task.wait(TOOL_CYCLE_DELAY)
                            humanoid:UnequipTools()
                            task.wait(TOOL_CYCLE_DELAY)
                        end
                    end
                end
            end)
            if not success then
                createNotification("Tool cycle failed in lag: " .. tostring(err), COLORS.NOTIFICATION_ERROR)
            end

            sendTTSMessage(TTS_MESSAGE, "9")
            task.wait(0.1)
        end
        _G.LagMode = false
        sendChatMessage("✅ Stopped lagging server!")
        createNotification("Stopped lagging server", COLORS.NOTIFICATION_SUCCESS)
        sendTTSMessage("Stopped lagging server!", "9")
    end)
end

-- Server hop functions
local function startTimer(initialTime, onComplete)
    local timeRemaining = initialTime or SERVER_HOP_DELAY
    local connection
    connection = RunService.Heartbeat:Connect(function()
        timeRemaining = timeRemaining - RunService.Heartbeat:Wait()
        if timeRemaining <= 0 then
            connection:Disconnect()
            if onComplete then
                onComplete()
            end
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
                local scriptContent = game:HttpGet(scriptUrl)
                if scriptContent and #scriptContent > 0 then
                    queueTeleport(scriptContent)
                else
                    error("Empty or invalid script content")
                end
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

-- Find player by partial name
local function findPlayerByPartialName(namePart)
    namePart = namePart:lower():gsub("%s+", "")
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= player and (plr.Name:lower():find(namePart) or plr.DisplayName:lower():gsub("%s+", ""):find(namePart)) then
            return plr
        end
    end
    return nil
end

-- Initialize loops and TTS on join
task.spawn(function()
    task.wait(2) -- Wait for character to load
    copyAvatarAndGetTools()
    sendChatMessage("🤖 Bot Active! Commands: !stop: Halts bot | !hop: Switch servers | !annoy <player>: Targets player | !lag: Lags server")
    sendTTSMessage(TTS_ON_JOIN_MESSAGE, "9") -- TTS on join
    task.wait(1)
    task.spawn(toolLoop)
    task.spawn(teleportLoop)
end)

-- Inactivity check loop
task.spawn(function()
    while true do -- Changed to always run
        task.wait(1)
        if tick() - _G.LastInteractionTime >= SERVER_HOP_DELAY then
            sendChatMessage("⏰ No interactions for 70 seconds, hopping servers!")
            sendTTSMessage("No interactions for 70 seconds, hopping servers!", "9")
            serverHop()
            break -- Exit loop after initiating server hop
        end
    end
end)

-- Chat listener
task.spawn(function()
    if TextChatService then
        local channel = TextChatService.TextChannels:FindFirstChild("RBXGeneral")
        if channel then
            channel.MessageReceived:Connect(function(message)
                local sender = message.TextSource
                if not sender or sender.UserId == player.UserId then return end
                local text = message.Text:lower()
                local targetPlayer = Players:GetPlayerByUserId(sender.UserId)
                if not targetPlayer then return end

                _G.LastInteractionTime = tick()

                if text:find("!stop") then
                    local success, err = pcall(function()
                        humanoidRootPart.CFrame = targetPlayer.Character.HumanoidRootPart.CFrame + Vector3.new(2, 0, 0)
                    end)
                    if not success then
                        createNotification("Teleport failed in stop: " .. tostring(err), COLORS.NOTIFICATION_ERROR)
                    end
                    sendChatMessage("✅ Stopped for " .. targetPlayer.Name .. "!")
                    sendTTSMessage("Stopped for " .. targetPlayer.Name .. "!", "9")
                    _G.TrollingActive = false
                    _G.AnnoyMode = false
                    _G.LagMode = false
                elseif text:find("!hop") then
                    sendChatMessage("🌐 Hopping servers now!")
                    sendTTSMessage("Hopping servers now!", "9")
                    serverHop()
                elseif text:find("!annoy") then
                    local annoyName = text:match("!annoy%s*(.+)")
                    if annoyName then
                        local annoyPlayer = findPlayerByPartialName(annoyName)
                        if annoyPlayer then
                            sendChatMessage("🎯 Annoying " .. annoyPlayer.Name .. " now!")
                            sendTTSMessage("Annoying " .. annoyPlayer.Name .. " now!", "9")
                            _G.TrollingActive = false
                            _G.AnnoyMode = true
                            _G.LagMode = false
                            _G.AnnoyTarget = annoyPlayer
                            task.spawn(annoyTeleportLoop)
                            task.spawn(annoyTTSLoop)
                        else
                            sendChatMessage("❌ No player found matching '" .. annoyName .. "'.")
                        end
                    else
                        sendChatMessage("⚠️ Usage: !annoy <player>")
                    end
                elseif text:find("!lag") then
                    lagServer()
                end
            end)
        end
    else
        local chatEvents = ReplicatedStorage:WaitForChild("DefaultChatSystemChatEvents")
        chatEvents.OnMessageDoneFiltering:Connect(function(message)
            if message.IsFiltered then
                local sender = Players:FindFirstChild(message.FromSpeaker)
                if not sender or sender == player then return end
                local text = message.Message:lower()

                _G.LastInteractionTime = tick()

                if text:find("!stop") then
                    local success, err = pcall(function()
                        humanoidRootPart.CFrame = sender.Character.HumanoidRootPart.CFrame + Vector3.new(2, 0, 0)
                    end)
                    if not success then
                        createNotification("Teleport failed in stop: " .. tostring(err), COLORS.NOTIFICATION_ERROR)
                    end
                    sendChatMessage("✅ Stopped for " .. sender.Name .. "!")
                    sendTTSMessage("Stopped for " .. sender.Name .. "!", "9")
                    _G.TrollingActive = false
                    _G.AnnoyMode = false
                    _G.LagMode = false
                elseif text:find("!hop") then
                    sendChatMessage("🌐 Hopping servers now!")
                    sendTTSMessage("Hopping servers now!", "9")
                    serverHop()
                elseif text:find("!annoy") then
                    local annoyName = text:match("!annoy%s*(.+)")
                    if annoyName then
                        local annoyPlayer = findPlayerByPartialName(annoyName)
                        if annoyPlayer then
                            sendChatMessage("🎯 Annoying " .. annoyPlayer.Name .. " now!")
                            sendTTSMessage("Annoying " .. annoyPlayer.Name .. " now!", "9")
                            _G.TrollingActive = false
                            _G.AnnoyMode = true
                            _G.LagMode = false
                            _G.AnnoyTarget = annoyPlayer
                            task.spawn(annoyTeleportLoop)
                            task.spawn(annoyTTSLoop)
                        else
                            sendChatMessage("❌ No player found matching '" .. annoyName .. "'.")
                        end
                    else
                        sendChatMessage("⚠️ Usage: !annoy <player>")
                    end
                elseif text:find("!lag") then
                    lagServer()
                end
            end
        end)
    end
end)

-- Teleport handler
player.OnTeleport:Connect(function(state)
    if state == Enum.TeleportState.Started then
        local success, err = pcall(function()
            local scriptContent = game:HttpGet(scriptUrl)
            if scriptContent and #scriptContent > 0 then
                queueTeleport(scriptContent)
            else
                error("Empty or invalid script content")
            end
        end)
        if success then
            createNotification("Script queued for teleport!", COLORS.NOTIFICATION_SUCCESS)
        else
            createNotification("Failed to queue script for teleport: " .. tostring(err), COLORS.NOTIFICATION_ERROR)
            warn("Teleport queue failed: " .. tostring(err))
        end
    end
end)
