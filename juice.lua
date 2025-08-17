-- Configuration
local TELEPORT_DELAY = 0.05 -- Time between teleports to each player
local TTS_MESSAGE = "jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew "
local ANNOY_TTS_MESSAGE = "jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew " -- Custom TTS for !annoy
local TOOL_CYCLE_DELAY = 0.1 -- Time between equipping/unequipping tools
local SERVER_HOP_DELAY = 90 -- Time before inactivity server hop
local LAG_DURATION = 15 -- Duration for !lag command in seconds
local COMMAND_REMINDER_INTERVAL = 35 -- Time between command reminders
local WEBHOOK_URL = "https://discord.com/api/webhooks/1406310015152689225/ixVarUpenxotKJLC6rv48dvL0id6rL4AvE90gp-t0PF8zbv8toDYG_u4YomJ4-r9MoLs"
local ANIMATION_ID = "rbxassetid://113820516315642" -- Animation ID for !annoy
local FOLLOW_SPEED = 30 -- Speed for following in studs per second

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
_G.AnimationTrack = nil -- To store the animation track
_G.ActiveTasks = {} -- To store active tasks for cancellation

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
local HttpService = define(gs("HttpService"))
local TeleportService = define(gs("TeleportService"))
local TextChatService = define(gs("TextChatService"))
local player = define(Players.LocalPlayer)
local TTS = ReplicatedStorage and ReplicatedStorage:FindFirstChild("TTS")
local proximityPrompt = Workspace and Workspace:FindFirstChild("Map") and Workspace.Map:FindFirstChild("RoomExtra") and Workspace.Map.RoomExtra:FindFirstChild("Model") and Workspace.Map.RoomExtra.Model:FindFirstChild("Activate") and Workspace.Map.RoomExtra.Model.Activate:FindFirstChild("ProximityPrompt")

-- Player setup
local character = player.Character or player.CharacterAdded:Wait()
local humanoidRootPart = character:WaitForChild("HumanoidRootPart")
local humanoid = character:WaitForChild("Humanoid")

-- Animation setup
local animation = Instance.new("Animation")
animation.AnimationId = ANIMATION_ID

-- Handle character respawn
player.CharacterAdded:Connect(function(newChar)
    character = newChar
    humanoidRootPart = newChar:WaitForChild("HumanoidRootPart")
    humanoid = newChar:WaitForChild("Humanoid")
    -- Reload animation on character respawn
    if _G.AnnoyMode and _G.AnnoyTarget then
        local success, err = pcall(function()
            local animator = humanoid:FindFirstChildOfClass("Animator")
            if animator then
                _G.AnimationTrack = animator:LoadAnimation(animation)
                _G.AnimationTrack:Play()
            end
        end)
        if not success then
            warn("Failed to load animation on respawn: " .. tostring(err))
        end
    end
end)

-- Disable seats
for _, obj in ipairs(Workspace:GetDescendants()) do
    if obj:IsA("Seat") or obj:IsA("VehicleSeat") then
        obj:Destroy()
    end
end
humanoid:SetStateEnabled(Enum.HumanoidStateType.Seated, false)

-- Proximity prompt safety
local function findProximityPrompt()
    local prompt
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("ProximityPrompt") then
            prompt = obj
            break
        end
    end
    return prompt
end
proximityPrompt = proximityPrompt or findProximityPrompt()

-- Activate proximity prompt
if proximityPrompt then
    local promptPos = proximityPrompt.Parent.Position
    humanoidRootPart.CFrame = CFrame.new(promptPos + Vector3.new(2, 0, 0))
    task.wait(0.5)
    proximityPrompt:InputHoldBegin()
    task.wait(0.1)
    proximityPrompt:InputHoldEnd()
end

-- HTTP retry utility
local function httpGetWithRetry(url, maxAttempts, delay)
    local attempts = 0
    while attempts < maxAttempts do
        local success, result = pcall(function()
            return game:HttpGet(url)
        end)
        if success then
            return success, result
        end
        attempts = attempts + 1
        task.wait(delay * attempts)
    end
    return false, "Max HTTP attempts reached"
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
    end
end

-- TTS function
local function sendTTSMessage(message, voice)
    if TTS then
        local success, err = pcall(function()
            TTS:FireServer(message, voice or "9")
        end)
        if not success then
            warn("TTS failed: " .. tostring(err))
        end
    else
        warn("TTS remote not found!")
    end
end

-- Discord webhook function
local function getPlayerPfpUrl(userId)
    local success, result = httpGetWithRetry("https://thumbnails.roblox.com/v1/users/avatar?userIds=" .. userId .. "&size=420x420&format=Png&isCircular=false", 3, 1)
    if success and result then
        local thumbnailData = HttpService:JSONDecode(result)
        if thumbnailData and thumbnailData.data and thumbnailData.data[1] and thumbnailData.data[1].imageUrl then
            return thumbnailData.data[1].imageUrl
        end
    end
    return "https://www.roblox.com/asset/?id=403652994"
end

local function sendWebhookNotification(username, displayName, userId, command)
    local playerPfpUrl = getPlayerPfpUrl(userId)
    local date = os.date("%m/%d/%Y")
    local time = os.date("%X")
    local playerLink = "https://www.roblox.com/users/" .. userId

    local data = {
        content = "@everyone",
        embeds = {{
            author = {
                name = "Command Used in Roblox",
                url = playerLink
            },
            description = string.format(
                "**Username**: %s\n**Display Name**: %s\n**Command**: `%s`",
                username, displayName, command
            ),
            color = tonumber("0xFF0000"), -- Red color
            thumbnail = { url = playerPfpUrl },
            footer = { text = string.format("Date: %s | Time: %s", date, time) }
        }}
    }

    local headers = {["Content-Type"] = "application/json"}
    local request = http_request or request or HttpPost or syn.request
    if not request then
        warn("No compatible HTTP request function found!")
        return
    end

    local requestData = {
        Url = WEBHOOK_URL,
        Body = HttpService:JSONEncode(data),
        Method = "POST",
        Headers = headers
    }

    local success, response = pcall(function()
        return request(requestData)
    end)

    if not success then
        warn("Webhook request failed: " .. tostring(response))
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
            end)
            if not success then
                warn("Failed to destroy " .. item.Name .. ": " .. tostring(err))
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

-- Avatar and tools
local function copyAvatarAndGetTools(username)
    local success, err = pcall(function()
        local Event = ReplicatedStorage:FindFirstChild("EventInputModify")
        if Event then
            Event:FireServer(username)
        else
            error("EventInputModify not found")
        end
    end)
    if not success then
        warn("Failed to copy avatar: " .. tostring(err))
    end

    -- Remove targeted items from player's character if copying 24k_mxtty1
    if username == "24k_mxtty1" and player.Character then
        local success, err = pcall(removeTargetedItems, player.Character)
        if not success then
            warn("Failed to remove items after avatar copy: " .. tostring(err))
        end
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
            else
                error("Tool event not found")
            end
        end)
        if not success then
            warn("Failed to acquire " .. toolName .. ": " .. tostring(err))
        end
        task.wait(0.1)
    end
end

-- Stop current mode silently
local function stopCurrentMode()
    _G.TrollingActive = false
    _G.AnnoyMode = false
    _G.LagMode = false
    _G.AnnoyTarget = nil
    if _G.AnimationTrack then
        _G.AnimationTrack:Stop()
        _G.AnimationTrack = nil
    end
    for _, taskId in ipairs(_G.ActiveTasks) do
        pcall(task.cancel, taskId)
    end
    _G.ActiveTasks = {}
    -- Unequip all tools
    if humanoid then
        local success, err = pcall(function()
            humanoid:UnequipTools()
        end)
        if not success then
            warn("Failed to unequip tools: " .. tostring(err))
        end
    end
end

-- Tool cycling loop
local function toolLoop()
    local taskId = task.spawn(function()
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
    end)
    table.insert(_G.ActiveTasks, taskId)
end

-- Teleport loop for trolling
local function teleportLoop()
    local taskId = task.spawn(function()
        while _G.TrollingActive do
            local players = Players:GetPlayers()
            for _, other in ipairs(players) do
                if other ~= player and other.Character and other.Character:FindFirstChild("HumanoidRootPart") then
                    humanoidRootPart.CFrame = CFrame.new(other.Character.HumanoidRootPart.Position + Vector3.new(2, 0, 0))
                    task.wait(TELEPORT_DELAY)
                end
            end
            sendTTSMessage(TTS_MESSAGE, "9")
        end
    end)
    table.insert(_G.ActiveTasks, taskId)
end

-- Animation loading function
local function loadAnimation(humanoid)
    local animator = humanoid:FindFirstChildOfClass("Animator")
    if animator then
        _G.AnimationTrack = animator:LoadAnimation(animation)
        _G.AnimationTrack:Play()
    else
        warn("Animator not found!")
    end
end

-- Teleport and follow loop for annoy mode with animation
local function annoyTeleportLoop()
    local taskId = task.spawn(function()
        -- Validate target and character
        if not _G.AnnoyTarget or not _G.AnnoyTarget.Character or not _G.AnnoyTarget.Character:FindFirstChild("HumanoidRootPart") then
            sendChatMessage("❌ Invalid target for annoy mode!")
            stopCurrentMode()
            return
        end

        -- Initial teleport to target
        local success, err = pcall(function()
            local targetPos = _G.AnnoyTarget.Character.HumanoidRootPart.Position
            local newPos = targetPos + (targetPos - humanoidRootPart.Position).Unit * 2
            humanoidRootPart.CFrame = CFrame.lookAt(newPos, targetPos)
        end)
        if not success then
            sendChatMessage("❌ Initial teleport failed: " .. tostring(err))
            stopCurrentMode()
            return
        end

        -- Load and play animation
        success, err = pcall(function()
            loadAnimation(humanoid)
        end)
        if not success then
            sendChatMessage("❌ Failed to load animation: " .. tostring(err))
            stopCurrentMode()
            return
        end

        -- Follow target by interpolating position
        local lastUpdate = tick()
        while _G.AnnoyMode do
            if _G.AnnoyTarget and _G.AnnoyTarget.Character and _G.AnnoyTarget.Character:FindFirstChild("HumanoidRootPart") and humanoid and humanoid.Health > 0 and humanoid:GetState() ~= Enum.HumanoidStateType.FallingDown then
                local targetPos = _G.AnnoyTarget.Character.HumanoidRootPart.Position
                local myPos = humanoidRootPart.Position
                local distance = (targetPos - myPos).Magnitude
                local deltaTime = tick() - lastUpdate
                lastUpdate = tick()

                -- Calculate target position 2 studs away
                local direction = (targetPos - myPos).Unit
                local desiredPos = targetPos - direction * 2

                -- Move toward desired position at FOLLOW_SPEED
                if distance > 2 then
                    local maxDistance = FOLLOW_SPEED * deltaTime
                    local moveVector = (desiredPos - myPos)
                    local moveDistance = moveVector.Magnitude
                    local newPos = myPos
                    if moveDistance > maxDistance then
                        newPos = myPos + moveVector.Unit * maxDistance
                    else
                        newPos = desiredPos
                    end

                    success, err = pcall(function()
                        humanoidRootPart.CFrame = CFrame.lookAt(newPos, Vector3.new(targetPos.X, newPos.Y, targetPos.Z))
                    end)
                    if not success then
                        sendChatMessage("❌ Failed to update position: " .. tostring(err))
                        break
                    end
                end

                -- Ensure animation is playing
                if _G.AnimationTrack and not _G.AnimationTrack.IsPlaying then
                    _G.AnimationTrack:Play()
                end
            else
                -- Stop if target becomes invalid or character is dead/falling
                sendChatMessage("❌ Target lost, invalid, or character dead!")
                break
            end
            task.wait() -- Run every frame for smooth movement
        end

        -- Clean up when annoy mode ends
        if _G.AnimationTrack then
            _G.AnimationTrack:Stop()
            _G.AnimationTrack = nil
        end
        stopCurrentMode()
    end)
    table.insert(_G.ActiveTasks, taskId)
end

-- TTS loop for annoy mode
local function annoyTTSLoop()
    local taskId = task.spawn(function()
        while _G.AnnoyMode do
            sendTTSMessage(ANNOY_TTS_MESSAGE, "9")
            task.wait(11)
        end
    end)
    table.insert(_G.ActiveTasks, taskId)
end

-- Lag server function
local function lagServer()
    stopCurrentMode() -- Stop any active mode silently
    _G.LagMode = true
    copyAvatarAndGetTools("24k_mxtty1") -- Copy 24k_mxtty1 avatar and remove items
    sendChatMessage("🔥 Lagging server for " .. LAG_DURATION .. " seconds!")
    sendTTSMessage("Lagging server for " .. LAG_DURATION .. " seconds!", "9")

    -- Start teleport and tool loops
    local teleportTask = task.spawn(teleportLoop)
    local toolTask = task.spawn(toolLoop)

    -- Run for LAG_DURATION, then stop
    local lagTask = task.spawn(function()
        task.wait(LAG_DURATION)
        stopCurrentMode()
    end)
    table.insert(_G.ActiveTasks, lagTask)
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
    local function attemptHop()
        local attempt = 1
        local timerConnection
        local baseDelay = 3
        local originalJobId = game.JobId

        while true do
            sendChatMessage("🌐 Fetching servers (Attempt " .. attempt .. ")...")
            local servers = {}
            local success, response = pcall(function()
                local httpSuccess, httpResult = httpGetWithRetry("https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100", 3, 1)
                if httpSuccess then
                    return HttpService:JSONDecode(httpResult)
                else
                    error(httpResult)
                end
            end)
            if success and response and response.data then
                for _, v in pairs(response.data) do
                    if v.playing < v.maxPlayers and v.id ~= game.JobId then
                        table.insert(servers, v.id)
                    end
                end
            else
                sendChatMessage("❌ Failed to fetch servers. Retrying in " .. baseDelay * attempt .. "s...")
                if timerConnection then timerConnection:Disconnect() end
                timerConnection = startTimer(baseDelay * attempt, function()
                    attempt = attempt + 1
                    attemptHop()
                end)
                return
            end

            if #servers > 0 then
                local randomServer = servers[math.random(1, #servers)]
                sendChatMessage("🌐 Attempting to join server " .. randomServer .. "...")
                
                local queueSuccess, queueError = pcall(function()
                    local httpSuccess, scriptContent = httpGetWithRetry(scriptUrl, 3, 1)
                    if httpSuccess and scriptContent and #scriptContent > 0 then
                        queueTeleport(scriptContent)
                    else
                        error(httpSuccess and "Empty or invalid script content" or scriptContent)
                    end
                end)
                if not queueSuccess then
                    warn("Queue teleport failed: " .. tostring(queueError))
                end

                local success, result = pcall(function()
                    TeleportService:TeleportToPlaceInstance(game.PlaceId, randomServer, player)
                end)
                if not success then
                    sendChatMessage("❌ Teleport failed: " .. tostring(result) .. ". Retrying in " .. baseDelay * attempt .. "s...")
                    if timerConnection then timerConnection:Disconnect() end
                    timerConnection = startTimer(baseDelay * attempt, function()
                        attempt = attempt + 1
                        attemptHop()
                    end)
                    return
                else
                    task.wait(3)
                    if game.JobId == originalJobId then
                        sendChatMessage("❌ Server full or failed to join. Retrying in " .. baseDelay * attempt .. "s...")
                        if timerConnection then timerConnection:Disconnect() end
                        timerConnection = startTimer(baseDelay * attempt, function()
                            attempt = attempt + 1
                            attemptHop()
                        end)
                        return
                    else
                        sendChatMessage("✅ Successfully joined new server!")
                        if timerConnection then timerConnection:Disconnect() end
                        if _G.TrollingActive then
                            sendTTSMessage(TTS_MESSAGE, "9")
                        end
                        break
                    end
                end
            else
                sendChatMessage("❌ No available servers. Retrying in " .. baseDelay * attempt .. "s...")
                if timerConnection then timerConnection:Disconnect() end
                timerConnection = startTimer(baseDelay * attempt, function()
                    attempt = attempt + 1
                    attemptHop()
                end)
                return
            end
        end
    end

    attemptHop()
end

-- Find player by partial name
local function findPlayerByPartialName(namePart)
    local namePart = namePart:lower():gsub("%s+", "")
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= player and (plr.Name:lower():find(namePart) or plr.DisplayName:lower():gsub("%s+", ""):find(namePart)) then
            return plr
        end
    end
    return nil
end

-- Command handler
local function handleCommand(sender, text)
    local textLower = text:lower()
    local targetPlayer = Players:GetPlayerByUserId(sender.UserId) or Players:FindFirstChild(sender.Name)
    if not targetPlayer then return end

    if textLower:find("!stop") then
        _G.LastInteractionTime = tick()
        sendWebhookNotification(targetPlayer.Name, targetPlayer.DisplayName, targetPlayer.UserId, text)
        local success, err = pcall(function()
            stopCurrentMode() -- Stop all modes and tasks first
            humanoidRootPart.CFrame = targetPlayer.Character.HumanoidRootPart.CFrame + Vector3.new(2, 0, 0)
        end)
        if not success then
            sendChatMessage("❌ Teleport failed in stop: " .. tostring(err))
        end
        sendChatMessage("✅ Stopped for " .. targetPlayer.Name .. "!")
        sendTTSMessage("Stopped for " .. targetPlayer.Name .. "!", "9")
    elseif textLower:find("!hop") then
        _G.LastInteractionTime = tick()
        sendWebhookNotification(targetPlayer.Name, targetPlayer.DisplayName, targetPlayer.UserId, text)
        sendChatMessage("🌐 Hopping servers now!")
        sendTTSMessage("Hopping servers now!", "9")
        task.wait(3)
        serverHop()
    elseif textLower:find("!annoy") then
        _G.LastInteractionTime = tick()
        sendWebhookNotification(targetPlayer.Name, targetPlayer.DisplayName, targetPlayer.UserId, text)
        local annoyName = textLower:match("!annoy%s*(.+)")
        if annoyName then
            local annoyPlayer = findPlayerByPartialName(annoyName)
            if annoyPlayer then
                stopCurrentMode() -- Stop any active mode silently
                copyAvatarAndGetTools("Giantkenneth101")
                sendChatMessage("🎯 Annoying " .. annoyPlayer.Name .. " now!")
                sendTTSMessage("Annoying " .. annoyPlayer.Name .. " now!", "9")
                _G.AnnoyMode = true
                _G.AnnoyTarget = annoyPlayer
                task.spawn(annoyTeleportLoop)
                task.spawn(annoyTTSLoop)
            else
                sendChatMessage("❌ No player found matching '" .. annoyName .. "'.")
            end
        else
            sendChatMessage("⚠️ Usage: !annoy user/display doesnt need to be fully typed")
        end
    elseif textLower:find("!lag") then
        if _G.LagMode then
            sendChatMessage("❌ Lag mode is already active! Wait " .. LAG_DURATION .. " seconds.")
            return
        end
        _G.LastInteractionTime = tick()
        sendWebhookNotification(targetPlayer.Name, targetPlayer.DisplayName, targetPlayer.UserId, text)
        lagServer()
    end
end

-- Command reminder loop
task.spawn(function()
    task.wait(COMMAND_REMINDER_INTERVAL)
    while true do
        sendChatMessage("🤖 CLANKER JOINED | Use these Commands, !stop | !hop | !annoy user | !lag")
        task.wait(COMMAND_REMINDER_INTERVAL)
    end
end)

-- Initialize loops and TTS on join
task.spawn(function()
    task.wait(2)
    copyAvatarAndGetTools("24k_mxtty1") -- Copy 24k_mxtty1 avatar and remove items
    warn("Sending join message at " .. os.date("%H:%M:%S"))
    sendChatMessage("🤖 CLANKER JOINED | Use these Commands, !stop | !hop | !annoy <player> | !lag")
    if _G.TrollingActive then
        sendTTSMessage(TTS_MESSAGE, "9")
    end
    task.wait(1)
    task.spawn(toolLoop)
    task.spawn(teleportLoop)
end)

-- Inactivity check loop
task.spawn(function()
    while true do
        task.wait(1)
        if tick() - _G.LastInteractionTime >= SERVER_HOP_DELAY then
            sendChatMessage("⏰ No interactions for " .. SERVER_HOP_DELAY .. " seconds, hopping servers!")
            sendTTSMessage("No interactions for " .. SERVER_HOP_DELAY .. " seconds, hopping servers!", "9")
            serverHop()
            break
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
                handleCommand(sender, message.Text)
            end)
        end
    else
        local chatEvents = ReplicatedStorage:WaitForChild("DefaultChatSystemChatEvents")
        chatEvents.OnMessageDoneFiltering:Connect(function(message)
            if message.IsFiltered then
                local sender = Players:FindFirstChild(message.FromSpeaker)
                if not sender or sender == player then return end
                handleCommand(sender, message.Message)
            end
        end)
    end
end)

-- Teleport handler
player.OnTeleport:Connect(function(state)
    if state == Enum.TeleportState.Started then
        local success, err = pcall(function()
            local httpSuccess, scriptContent = httpGetWithRetry(scriptUrl, 3, 1)
            if httpSuccess and scriptContent and #scriptContent > 0 then
                queueTeleport(scriptContent)
            else
                error(httpSuccess and "Empty or invalid script content" or scriptContent)
            end
        end)
        if not success then
            warn("Teleport queue failed: " .. tostring(err))
        end
    end
end)
