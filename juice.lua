-- Configuration
local ALLOW_SELF_COMMANDS = false
local PREMIUM_LIST_URL = "https://raw.githubusercontent.com/SystemNasa/roblox/refs/heads/main/premium.lua"
local TELEPORT_DELAY = 0.05
local TTS_MESSAGE = "jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew "
local ANNOY_TTS_MESSAGE = "jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew jew "
local TOOL_CYCLE_DELAY = 0.1
local SERVER_HOP_DELAY = 100
local LAG_DURATION = 15
local COMMAND_REMINDER_INTERVAL = 40
local WEBHOOK_URL = "https://discord.com/api/webhooks/1406310015152689225/ixVarUpenxotKJLC6rv48dvL0id6rL4AvE90gp-t0PF8zbv8toDYG_u4YomJ4-r9MoLs"
local PREMIUM_COMMAND_WEBHOOK_URL = "https://discord.com/api/webhooks/1406685652086554726/Kk53I8kVYmuP82iAHQ3ZN6xE60RI1mx2fUx2W477ndtajUAECz-jNG2bgSdWA5vm8fg_"
local ANIMATION_ID = "rbxassetid://113820516315642"
local ROAST_ANIMATION_ID = "rbxassetid://82965632072615"
local FOLLOW_SPEED = 30
local PREMIUM_RESPONSE_TIMEOUT = 20

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
_G.RoastMode = false
_G.AnnoyTarget = nil
_G.RoastTarget = nil
_G.LastInteractionTime = tick()
_G.AnimationTrack = nil
_G.ActiveTasks = {}
_G.PremiumUserFound = false
_G.PremiumPlayer = nil
_G.WaitingForPremiumResponse = false

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

local function generateRoastMessage(target)
    local roastMessages = {
        "Imagine wearing %s, did you pay LOL? 🤡",
        "ew what is %s, are we seriously still wearing this in big 2025? 🤡",
        "Wearing %s? Bruh wasting money at this point 🤡",
        "Is %s supposed to be tuff or a cry for help? 🤡",
        "%s looks like it was the reason they replaced you 🤡"
    }
    local accessories = {}
    if target.Character then
        for _, item in ipairs(target.Character:GetChildren()) do
            if item:IsA("Accessory") then
                local accessoryName = item.Name
                -- Clean up accessory name
                if accessoryName:find("Accessory") then
                    accessoryName = accessoryName:gsub("Accessory%s*%(?([^%)]+)%)?", "%1") -- Remove "Accessory" and parentheses
                    accessoryName = accessoryName:gsub("^%s*(.-)%s*$", "%1") -- Trim whitespace
                end
                if accessoryName == "MeshPartAccessory" then
                    accessoryName = "That"
                end
                table.insert(accessories, accessoryName)
            end
        end
    end
    local accessoryName = #accessories > 0 and accessories[math.random(1, #accessories)] or "outfit"
    local message = roastMessages[math.random(1, #roastMessages)]
    return string.format(message, accessoryName)
end

local GUI_ID = randstr()
local scriptUrl = "https://raw.githubusercontent.com/SystemNasa/roblox/refs/heads/main/juice.lua"

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
local roastAnimation = Instance.new("Animation")
roastAnimation.AnimationId = ROAST_ANIMATION_ID

-- Handle character respawn
player.CharacterAdded:Connect(function(newChar)
    character = newChar
    humanoidRootPart = newChar:WaitForChild("HumanoidRootPart")
    humanoid = newChar:WaitForChild("Humanoid")
    if _G.AnnoyMode and _G.AnnoyTarget then
        local success, err = pcall(function()
            local animator = humanoid:FindFirstChildOfClass("Animator")
            if animator then
                _G.AnimationTrack = animator:LoadAnimation(animation)
                _G.AnimationTrack:Play()
            end
        end)
        if not success then
            warn("Failed to load annoy animation on respawn: " .. tostring(err))
        end
    elseif _G.RoastMode and _G.RoastTarget then
        local success, err = pcall(function()
            local animator = humanoid:FindFirstChildOfClass("Animator")
            if animator then
                _G.AnimationTrack = animator:LoadAnimation(roastAnimation)
                _G.AnimationTrack:Play()
            end
        end)
        if not success then
            warn("Failed to load roast animation on respawn: " .. tostring(err))
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

local function sendWebhookNotification(username, displayName, userId, command, webhookUrl)
    local playerPfpUrl = getPlayerPfpUrl(userId)
    local date = os.date("%m/%d/%Y")
    local time = os.date("%X")
    local playerLink = "https://www.roblox.com/users/" .. userId

    local data = {
        content = "@everyone",
        embeds = {{
            author = {
                name = command == "PremiumUserFound" and "Premium User Detected" or "Command Used in Roblox",
                url = playerLink
            },
            description = command == "PremiumUserFound" and
                string.format("**Username**: %s\n**Display Name**: %s", username, displayName) or
                string.format("**Username**: %s\n**Display Name**: %s\n**Command**: `%s`", username, displayName, command),
            color = tonumber("0xFF0000"),
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
        Url = webhookUrl or WEBHOOK_URL,
        Body = HttpService:JSONEncode(data),
        Method = "POST",
        Headers = headers
    }

    local success, response = pcall(function()
        return request(requestData)
    end)

    if not success then
        warn("Webhook request failed for " .. (webhookUrl or WEBHOOK_URL) .. ": " .. tostring(response))
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
    _G.RoastMode = false
    _G.AnnoyTarget = nil
    _G.RoastTarget = nil
    if _G.AnimationTrack then
        _G.AnimationTrack:Stop()
        _G.AnimationTrack = nil
    end
    for _, taskId in ipairs(_G.ActiveTasks) do
        pcall(task.cancel, taskId)
    end
    _G.ActiveTasks = {}
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
local function loadAnimation(humanoid, anim)
    local animator = humanoid:FindFirstChildOfClass("Animator")
    if animator then
        _G.AnimationTrack = animator:LoadAnimation(anim)
        _G.AnimationTrack:Play()
    else
        warn("Animator not found!")
    end
end

-- Teleport and follow loop for annoy mode with animation and size change
local function annoyTeleportLoop()
    local taskId = task.spawn(function()
        if not _G.AnnoyTarget or not _G.AnnoyTarget.Character or not _G.AnnoyTarget.Character:FindFirstChild("HumanoidRootPart") then
            sendChatMessage("❌ Invalid target for annoy mode!")
            stopCurrentMode()
            return
        end

        local success, err = pcall(function()
            local args = { [1] = "Huge" }
            game:GetService("ReplicatedStorage"):WaitForChild("SizePreset"):FireServer(unpack(args))
        end)
        if not success then
            sendChatMessage("❌ Failed to set character size to Huge: " .. tostring(err))
        end

        success, err = pcall(function()
            local targetPos = _G.AnnoyTarget.Character.HumanoidRootPart.Position
            local newPos = targetPos + (targetPos - humanoidRootPart.Position).Unit * 2
            humanoidRootPart.CFrame = CFrame.lookAt(newPos, targetPos)
        end)
        if not success then
            sendChatMessage("❌ Initial teleport failed: " .. tostring(err))
            stopCurrentMode()
            return
        end

        success, err = pcall(function()
            loadAnimation(humanoid, animation)
        end)
        if not success then
            sendChatMessage("❌ Failed to load animation: " .. tostring(err))
            stopCurrentMode()
            return
        end

        local lastUpdate = tick()
        while _G.AnnoyMode do
            if _G.AnnoyTarget and _G.AnnoyTarget.Character and _G.AnnoyTarget.Character:FindFirstChild("HumanoidRootPart") and humanoid and humanoid.Health > 0 and humanoid:GetState() ~= Enum.HumanoidStateType.FallingDown then
                local targetPos = _G.AnnoyTarget.Character.HumanoidRootPart.Position
                local myPos = humanoidRootPart.Position
                local distance = (targetPos - myPos).Magnitude
                local deltaTime = tick() - lastUpdate
                lastUpdate = tick()

                local direction = (targetPos - myPos).Unit
                local desiredPos = targetPos - direction * 2

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

                if _G.AnimationTrack and not _G.AnimationTrack.IsPlaying then
                    _G.AnimationTrack:Play()
                end
            else
                sendChatMessage("❌ Target lost, invalid, or character dead!")
                break
            end
            task.wait()
        end

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

-- Teleport and follow loop for roast mode
local function roastTeleportLoop()
    local taskId = task.spawn(function()
        if not _G.RoastTarget or not _G.RoastTarget.Character or not _G.RoastTarget.Character:FindFirstChild("HumanoidRootPart") then
            sendChatMessage("❌ Invalid target for roast mode!")
            stopCurrentMode()
            return
        end

        local success, err = pcall(function()
            local targetPos = _G.RoastTarget.Character.HumanoidRootPart.Position
            local newPos = targetPos + (targetPos - humanoidRootPart.Position).Unit * 2
            humanoidRootPart.CFrame = CFrame.lookAt(newPos, targetPos)
        end)
        if not success then
            sendChatMessage("❌ Initial teleport failed: " .. tostring(err))
            stopCurrentMode()
            return
        end

        success, err = pcall(function()
            loadAnimation(humanoid, roastAnimation)
        end)
        if not success then
            sendChatMessage("❌ Failed to load roast animation: " .. tostring(err))
            stopCurrentMode()
            return
        end

        local startTime = tick()
        local lastUpdate = tick()
        while _G.RoastMode and (tick() - startTime < 10) do
            if _G.RoastTarget and _G.RoastTarget.Character and _G.RoastTarget.Character:FindFirstChild("HumanoidRootPart") and humanoid and humanoid.Health > 0 and humanoid:GetState() ~= Enum.HumanoidStateType.FallingDown then
                local targetPos = _G.RoastTarget.Character.HumanoidRootPart.Position
                local myPos = humanoidRootPart.Position
                local distance = (targetPos - myPos).Magnitude
                local deltaTime = tick() - lastUpdate
                lastUpdate = tick()

                local direction = (targetPos - myPos).Unit
                local desiredPos = targetPos - direction * 2

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

                if _G.AnimationTrack and not _G.AnimationTrack.IsPlaying then
                    _G.AnimationTrack:Play()
                end
            else
                sendChatMessage("❌ Target lost, invalid, or character dead!")
                break
            end
            task.wait()
        end

        if _G.AnimationTrack then
            _G.AnimationTrack:Stop()
            _G.AnimationTrack = nil
        end
        stopCurrentMode()
    end)
    table.insert(_G.ActiveTasks, taskId)
end

-- Roast message function (single message)
local function roastMessageLoop()
    local taskId = task.spawn(function()
        if _G.RoastTarget then
            local roastMessage = generateRoastMessage(_G.RoastTarget)
            sendChatMessage(roastMessage)
            sendTTSMessage(roastMessage, "9")
        end
    end)
    table.insert(_G.ActiveTasks, taskId)
end

-- Lag server function
local function lagServer()
    stopCurrentMode()
    _G.LagMode = true
    copyAvatarAndGetTools("24k_mxtty1")
    sendChatMessage("🔥 Lagging server for " .. LAG_DURATION .. " seconds!")
    sendTTSMessage("Lagging server for " .. LAG_DURATION .. " seconds!", "9")

    local teleportTask = task.spawn(teleportLoop)
    local toolTask = task.spawn(toolLoop)

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

-- Check for premium users
local function checkPremiumUsers()
    local premiumUsers = {}
    local success, result = pcall(function()
        local httpSuccess, luaContent = httpGetWithRetry(PREMIUM_LIST_URL, 3, 1)
        if httpSuccess and luaContent and #luaContent > 0 then
            local func = loadstring(luaContent)
            if func then
                return func()
            else
                error("Failed to parse Lua content from premium list")
            end
        else
            error(httpSuccess and "Empty or invalid Lua content" or luaContent)
        end
    end)
    if success and type(result) == "table" then
        premiumUsers = result
    else
        warn("Failed to fetch or parse premium user list: " .. tostring(result))
        return nil
    end

    for _, plr in ipairs(Players:GetPlayers()) do
        for _, premiumName in ipairs(premiumUsers) do
            if plr.Name:lower() == premiumName:lower() then
                sendWebhookNotification(plr.Name, plr.DisplayName, plr.UserId, "PremiumUserFound", PREMIUM_COMMAND_WEBHOOK_URL)
                return plr
            end
        end
    end
    return nil
end

-- Find player by partial name
local function findPlayerByPartialName(namePart)
    local namePart = namePart:lower():gsub("%s+", "")
    for _, plr in ipairs(Players:GetPlayers()) do
        if (ALLOW_SELF_COMMANDS or plr ~= player) and (plr.Name:lower():find(namePart) or plr.DisplayName:lower():gsub("%s+", ""):find(namePart)) then
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

    if not textLower:find("^!") then return end

    if _G.WaitingForPremiumResponse then
        sendChatMessage("⏳ Please wait, I'm awaiting a response from the premium user.")
        return
    end

    if textLower:find("!stop") then
        _G.LastInteractionTime = tick()
        sendWebhookNotification(targetPlayer.Name, targetPlayer.DisplayName, targetPlayer.UserId, text)
        if _G.PremiumPlayer and targetPlayer == _G.PremiumPlayer then
            sendWebhookNotification(targetPlayer.Name, targetPlayer.DisplayName, targetPlayer.UserId, text, PREMIUM_COMMAND_WEBHOOK_URL)
        end
        local success, err = pcall(function()
            stopCurrentMode()
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
        if _G.PremiumPlayer and targetPlayer == _G.PremiumPlayer then
            sendWebhookNotification(targetPlayer.Name, targetPlayer.DisplayName, targetPlayer.UserId, text, PREMIUM_COMMAND_WEBHOOK_URL)
        end
        if _G.PremiumUserFound and targetPlayer ~= _G.PremiumPlayer then
            local success, err = pcall(function()
                humanoidRootPart.CFrame = _G.PremiumPlayer.Character.HumanoidRootPart.CFrame + Vector3.new(2, 0, 0)
            end)
            if not success then
                sendChatMessage("❌ Failed to teleport to premium user " .. _G.PremiumPlayer.Name .. ": " .. tostring(err))
                return
            end
            _G.WaitingForPremiumResponse = true
            sendChatMessage("❓ " .. _G.PremiumPlayer.Name .. ", " .. targetPlayer.Name .. " wants to server hop. Should I hop? Answer with 'yes' or 'no'.")
            sendTTSMessage(_G.PremiumPlayer.Name .. ", " .. targetPlayer.Name .. " wants to server hop. Should I hop? Answer with yes or no.", "9")

            local responseReceived = false
            local connection
            local startTime = tick()
            if TextChatService then
                local channel = TextChatService.TextChannels:FindFirstChild("RBXGeneral")
                if channel then
                    connection = channel.MessageReceived:Connect(function(message)
                        local sender = message.TextSource
                        if sender and sender.UserId == _G.PremiumPlayer.UserId and not responseReceived then
                            local textLower = message.Text:lower()
                            if textLower == "yes" then
                                responseReceived = true
                                connection:Disconnect()
                                _G.WaitingForPremiumResponse = false
                                sendChatMessage("🌐 " .. _G.PremiumPlayer.Name .. " said yes, hopping servers!")
                                sendTTSMessage(_G.PremiumPlayer.Name .. " said yes, hopping servers!", "9")
                                serverHop()
                            elseif textLower == "no" then
                                responseReceived = true
                                connection:Disconnect()
                                _G.WaitingForPremiumResponse = false
                                sendChatMessage("✅ " .. _G.PremiumPlayer.Name .. " said no, staying in server!")
                                sendTTSMessage(_G.PremiumPlayer.Name .. " said no, staying in server!", "9")
                            end
                        end
                    end)
                end
            else
                local chatEvents = ReplicatedStorage:WaitForChild("DefaultChatSystemChatEvents")
                connection = chatEvents.OnMessageDoneFiltering:Connect(function(message)
                    if message.IsFiltered then
                        local sender = Players:FindFirstChild(message.FromSpeaker)
                        if sender and sender == _G.PremiumPlayer and not responseReceived then
                            local textLower = message.Message:lower()
                            if textLower == "yes" then
                                responseReceived = true
                                connection:Disconnect()
                                _G.WaitingForPremiumResponse = false
                                sendChatMessage("🌐 " .. _G.PremiumPlayer.Name .. " said yes, hopping servers!")
                                sendTTSMessage(_G.PremiumPlayer.Name .. " said yes, hopping servers!", "9")
                                serverHop()
                            elseif textLower == "no" then
                                responseReceived = true
                                connection:Disconnect()
                                _G.WaitingForPremiumResponse = false
                                sendChatMessage("✅ " .. _G.PremiumPlayer.Name .. " said no, staying in server!")
                                sendTTSMessage(_G.PremiumPlayer.Name .. " said no, staying in server!", "9")
                            end
                        end
                    end
                end)
            end

            task.spawn(function()
                while tick() - startTime < PREMIUM_RESPONSE_TIMEOUT and not responseReceived do
                    if not _G.PremiumPlayer.Parent then
                        responseReceived = true
                        if connection then connection:Disconnect() end
                        sendChatMessage("❌ Premium user " .. _G.PremiumPlayer.Name .. " left, hopping servers!")
                        sendTTSMessage("Premium user " .. _G.PremiumPlayer.Name .. " left, hopping servers!", "9")
                        _G.PremiumUserFound = false
                        _G.PremiumPlayer = nil
                        _G.WaitingForPremiumResponse = false
                        serverHop()
                        return
                    end
                    task.wait(0.1)
                end
                if not responseReceived then
                    if connection then connection:Disconnect() end
                    sendChatMessage("⏰ No response from " .. _G.PremiumPlayer.Name .. ", hopping servers!")
                    sendTTSMessage("No response from " .. _G.PremiumPlayer.Name .. ", hopping servers!", "9")
                    _G.WaitingForPremiumResponse = false
                    serverHop()
                end
            end)
        else
            sendChatMessage("🌐 Hopping servers now!")
            sendTTSMessage("Hopping servers now!", "9")
            task.wait(3)
            serverHop()
        end
    elseif textLower:find("!annoy") then
        _G.LastInteractionTime = tick()
        sendWebhookNotification(targetPlayer.Name, targetPlayer.DisplayName, targetPlayer.UserId, text)
        if _G.PremiumPlayer and targetPlayer == _G.PremiumPlayer then
            sendWebhookNotification(targetPlayer.Name, targetPlayer.DisplayName, targetPlayer.UserId, text, PREMIUM_COMMAND_WEBHOOK_URL)
        end
        local annoyName = textLower:match("!annoy%s*(.+)")
        if annoyName then
            local annoyPlayer = findPlayerByPartialName(annoyName)
            if annoyPlayer then
                stopCurrentMode()
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
        if _G.PremiumPlayer and targetPlayer == _G.PremiumPlayer then
            sendWebhookNotification(targetPlayer.Name, targetPlayer.DisplayName, targetPlayer.UserId, text, PREMIUM_COMMAND_WEBHOOK_URL)
        end
        lagServer()
    elseif textLower:find("!premium") then
        _G.LastInteractionTime = tick()
        sendWebhookNotification(targetPlayer.Name, targetPlayer.DisplayName, targetPlayer.UserId, text)
        if _G.PremiumPlayer and targetPlayer == _G.PremiumPlayer then
            sendWebhookNotification(targetPlayer.Name, targetPlayer.DisplayName, targetPlayer.UserId, text, PREMIUM_COMMAND_WEBHOOK_URL)
        end
        local success, err = pcall(function()
            humanoidRootPart.CFrame = targetPlayer.Character.HumanoidRootPart.CFrame + Vector3.new(2, 0, 0)
        end)
        if not success then
            sendChatMessage("❌ Teleport failed in premium: " .. tostring(err))
        else
            sendChatMessage("🌟 Premium users get special treatment! They prevent the server from lagging, friend me to be whitelisted!")
            sendTTSMessage("Premium users get special treatment! They prevent the server from lagging, friend me to be whitelisted!", "9")
        end
    elseif textLower:find("!roast") then
        _G.LastInteractionTime = tick()
        sendWebhookNotification(targetPlayer.Name, targetPlayer.DisplayName, targetPlayer.UserId, text)
        if _G.PremiumPlayer and targetPlayer == _G.PremiumPlayer then
            sendWebhookNotification(targetPlayer.Name, targetPlayer.DisplayName, targetPlayer.UserId, text, PREMIUM_COMMAND_WEBHOOK_URL)
        end
        local roastName = textLower:match("!roast%s*(.+)")
        if roastName then
            local roastPlayer = findPlayerByPartialName(roastName)
            if roastPlayer then
                stopCurrentMode()
                copyAvatarAndGetTools("Aquilesfgj_YT")
                _G.RoastMode = true
                _G.RoastTarget = roastPlayer
                task.spawn(roastTeleportLoop)
                task.spawn(roastMessageLoop)
            else
                sendChatMessage("❌ No player found matching '" .. roastName .. "'.")
            end
        else
            sendChatMessage("⚠️ Usage: !roast user/display doesnt need to be fully typed")
        end
    end
end

-- Command reminder loop
task.spawn(function()
    task.wait(COMMAND_REMINDER_INTERVAL)
    while true do
        sendChatMessage("🤖 CLANKER JOINED | Use these Commands, !stop | !hop | !annoy user | !lag | !premium | !roast user")
        task.wait(COMMAND_REMINDER_INTERVAL)
    end
end)

-- Initialize loops and TTS on join
task.spawn(function()
    task.wait(2)
    copyAvatarAndGetTools("24k_mxtty1")

    local premiumPlayer = checkPremiumUsers()
    if premiumPlayer and premiumPlayer.Character and premiumPlayer.Character:FindFirstChild("HumanoidRootPart") then
        _G.PremiumUserFound = true
        _G.PremiumPlayer = premiumPlayer
        _G.TrollingActive = false
        local success, err = pcall(function()
            humanoidRootPart.CFrame = premiumPlayer.Character.HumanoidRootPart.CFrame + Vector3.new(2, 0, 0)
        end)
        if success then
            sendChatMessage("🌟 Hello premium user " .. premiumPlayer.Name .. ", I won't lag this server thanks to you!")
            sendTTSMessage("Hello premium user " .. premiumPlayer.Name .. ", I won't lag this server thanks to you!", "9")
        else
            warn("Failed to teleport to premium user: " .. tostring(err))
            sendChatMessage("❌ Failed to teleport to premium user " .. premiumPlayer.Name .. ".")
        end

        task.wait(2)
        _G.WaitingForPremiumResponse = true
        sendChatMessage("❓ " .. premiumPlayer.Name .. ", do you want me to server hop? Answer with 'yes' or 'no'.")
        sendTTSMessage(premiumPlayer.Name .. ", do you want me to server hop? Answer with yes or no.", "9")

        local responseReceived = false
        local connection
        local startTime = tick()
        if TextChatService then
            local channel = TextChatService.TextChannels:FindFirstChild("RBXGeneral")
            if channel then
                connection = channel.MessageReceived:Connect(function(message)
                    local sender = message.TextSource
                    if sender and sender.UserId == premiumPlayer.UserId and not responseReceived then
                        local textLower = message.Text:lower()
                        if textLower == "yes" then
                            responseReceived = true
                            connection:Disconnect()
                            _G.WaitingForPremiumResponse = false
                            sendChatMessage("🌐 " .. premiumPlayer.Name .. " said yes, hopping servers!")
                            sendTTSMessage(premiumPlayer.Name .. " said yes, hopping servers!", "9")
                            serverHop()
                        elseif textLower == "no" then
                            responseReceived = true
                            connection:Disconnect()
                            _G.WaitingForPremiumResponse = false
                            sendChatMessage("✅ " .. premiumPlayer.Name .. " said no, staying in server!")
                            sendTTSMessage(premiumPlayer.Name .. " said no, staying in server!", "9")
                        end
                    end
                end)
            end
        else
            local chatEvents = ReplicatedStorage:WaitForChild("DefaultChatSystemChatEvents")
            connection = chatEvents.OnMessageDoneFiltering:Connect(function(message)
                if message.IsFiltered then
                    local sender = Players:FindFirstChild(message.FromSpeaker)
                    if sender and sender == premiumPlayer and not responseReceived then
                        local textLower = message.Message:lower()
                        if textLower == "yes" then
                            responseReceived = true
                            connection:Disconnect()
                            _G.WaitingForPremiumResponse = false
                            sendChatMessage("🌐 " .. premiumPlayer.Name .. " said yes, hopping servers!")
                            sendTTSMessage(premiumPlayer.Name .. " said yes, hopping servers!", "9")
                            serverHop()
                        elseif textLower == "no" then
                            responseReceived = true
                            connection:Disconnect()
                            _G.WaitingForPremiumResponse = false
                            sendChatMessage("✅ " .. premiumPlayer.Name .. " said no, staying in server!")
                            sendTTSMessage(premiumPlayer.Name .. " said no, staying in server!", "9")
                        end
                    end
                end
            end)
        end

        task.spawn(function()
            while tick() - startTime < PREMIUM_RESPONSE_TIMEOUT and not responseReceived do
                if not premiumPlayer.Parent then
                    responseReceived = true
                    if connection then connection:Disconnect() end
                    sendChatMessage("❌ Premium user " .. premiumPlayer.Name .. " left, hopping servers!")
                    sendTTSMessage("Premium user " .. premiumPlayer.Name .. " left, hopping servers!", "9")
                    _G.PremiumUserFound = false
                    _G.PremiumPlayer = nil
                    _G.WaitingForPremiumResponse = false
                    serverHop()
                    return
                end
                task.wait(0.1)
            end
            if not responseReceived then
                if connection then connection:Disconnect() end
                sendChatMessage("⏰ No response from " .. premiumPlayer.Name .. ", hopping servers!")
                sendTTSMessage("No response from " .. premiumPlayer.Name .. ", hopping servers!", "9")
                _G.WaitingForPremiumResponse = false
                serverHop()
            end
        end)
    else
        warn("No premium users found, proceeding with normal trolling.")
        sendChatMessage("🤖 CLANKER JOINED | Use these Commands, !stop | !hop | !annoy user | !lag | !premium | !roast user")
        if _G.TrollingActive then
            sendTTSMessage(TTS_MESSAGE, "9")
        end
        task.wait(1)
        task.spawn(toolLoop)
        task.spawn(teleportLoop)
    end
end)

-- Inactivity check loop
task.spawn(function()
    while true do
        task.wait(1)
        if _G.PremiumUserFound and _G.PremiumPlayer then
            if not _G.PremiumPlayer.Parent then
                _G.PremiumUserFound = false
                _G.PremiumPlayer = nil
                sendChatMessage("❌ Premium user left, resuming normal behavior!")
                sendTTSMessage("Premium user left, resuming normal behavior!", "9")
                if _G.TrollingActive then
                    sendTTSMessage(TTS_MESSAGE, "9")
                end
                task.spawn(toolLoop)
                task.spawn(teleportLoop)
            end
        end
        if tick() - _G.LastInteractionTime >= SERVER_HOP_DELAY and not _G.PremiumUserFound then
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
                if not sender or (not ALLOW_SELF_COMMANDS and sender.UserId == player.UserId) then return end
                handleCommand(sender, message.Text)
            end)
        end
    else
        local chatEvents = ReplicatedStorage:WaitForChild("DefaultChatSystemChatEvents")
        chatEvents.OnMessageDoneFiltering:Connect(function(message)
            if message.IsFiltered then
                local sender = Players:FindFirstChild(message.FromSpeaker)
                if not sender or (not ALLOW_SELF_COMMANDS and sender == player) then return end
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
