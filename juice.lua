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

local function lagServer()
    if _G.LagMode or _G.TrollingActive or _G.AnnoyMode then
        sendChatMessage("⚠️ Cannot lag server while trolling, annoying, or lagging!")
        createNotification("Cannot lag: Another mode is active", COLORS.NOTIFICATION_ERROR)
        return
    end
    _G.LagMode = true
    sendChatMessage("🔥 Lagging server for " .. LAG_DURATION .. " seconds!")
    createNotification("Lagging server for " .. LAG_DURATION .. " seconds", COLORS.NOTIFICATION_WARNING)

    if TTS then
        local success, err = pcall(function()
            TTS:FireServer("Lagging server for " .. LAG_DURATION .. " seconds!", "9")
        end)
        if not success then
            createNotification("TTS failed: " .. tostring(err), COLORS.NOTIFICATION_ERROR)
        end
    else
        createNotification("TTS remote not found!", COLORS.NOTIFICATION_ERROR)
    end

    local startTime = tick()
    task.spawn(function()
        while _G.LagMode and tick() - startTime < LAG_DURATION do
            -- Refresh character references
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

            if TTS then
                success, err = pcall(function()
                    TTS:FireServer(TTS_MESSAGE, "9")
                end)
                if not success then
                    createNotification("TTS failed in lag: " .. tostring(err), COLORS.NOTIFICATION_ERROR)
                end
            end
            task.wait(0.1)
        end
        _G.LagMode = false
        sendChatMessage("✅ Stopped lagging server!")
        createNotification("Stopped lagging server", COLORS.NOTIFICATION_SUCCESS)
    end)
end

-- Initialize loops
task.spawn(function()
    copyAvatarAndGetTools()
    task.wait(1)
    task.spawn(toolLoop)
end)
task.spawn(teleportLoop)

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

-- Announce commands on start
task.spawn(function()
    task.wait(2) -- Wait for character to load
    sendChatMessage("🤖 Bot Active! Commands: !stop: Halts bot | !hop: Switch servers | !annoy <player>: Targets player | !lag: Lags server")
end)

-- Reminder loop
task.spawn(function()
    while _G.TrollingActive or _G.AnnoyMode or _G.LagMode do
        task.wait(30)
        sendChatMessage("📢 Commands: !stop: Halts bot | !hop: Switch servers | !annoy <player>: Targets player | !lag: Lags server")
    end
end)

-- Inactivity check loop
task.spawn(function()
    while _G.TrollingActive or _G.AnnoyMode or _G.LagMode do
        task.wait(1)
        if tick() - _G.LastInteractionTime >= SERVER_HOP_DELAY then
            sendChatMessage("⏰ No interactions for 70 seconds, hopping servers!")
            if TTS then
                local success, err = pcall(function()
                    TTS:FireServer("No interactions for 70 seconds, hopping servers!", "9")
                end)
                if not success then
                    createNotification("TTS failed in inactivity check: " .. tostring(err), COLORS.NOTIFICATION_ERROR)
                end
            end
            serverHop()
        end
    end
end)

-- Find player by partial name
local function findPlayerByPartialName(namePart)
    namePart = namePart:lower():gsub("%s+", "") -- Remove spaces for matching
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= player and (plr.Name:lower():find(namePart) or plr.DisplayName:lower():gsub("%s+", ""):find(namePart)) then
            return plr
        end
    end
    return nil
end

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
                    if TTS then
                        local ttsSuccess, ttsErr = pcall(function()
                            TTS:FireServer("Stopped for " .. targetPlayer.Name .. "!", "9")
                        end)
                        if not ttsSuccess then
                            createNotification("TTS failed in stop: " .. tostring(ttsErr), COLORS.NOTIFICATION_ERROR)
                        end
                    end
                    _G.TrollingActive = false
                    _G.AnnoyMode = false
                    _G.LagMode = false
                elseif text:find("!hop") then
                    sendChatMessage("🌐 Hopping servers now!")
                    if TTS then
                        local success, err = pcall(function()
                            TTS:FireServer("Hopping servers now!", "9")
                        end)
                        if not success then
                            createNotification("TTS failed in hop: " .. tostring(err), COLORS.NOTIFICATION_ERROR)
                        end
                    end
                    serverHop()
                elseif text:find("!annoy") then
                    local annoyName = text:match("!annoy%s*(.+)")
                    if annoyName then
                        local annoyPlayer = findPlayerByPartialName(annoyName)
                        if annoyPlayer then
                            sendChatMessage("🎯 Annoying " .. annoyPlayer.Name .. " now!")
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
                    if TTS then
                        local ttsSuccess, ttsErr = pcall(function()
                            TTS:FireServer("Stopped for " .. sender.Name .. "!", "9")
                        end)
                        if not ttsSuccess then
                            createNotification("TTS failed in stop: " .. tostring(ttsErr), COLORS.NOTIFICATION_ERROR)
                        end
                    end
                    _G.TrollingActive = false
                    _G.AnnoyMode = false
                    _G.LagMode = false
                elseif text:find("!hop") then
                    sendChatMessage("🌐 Hopping servers now!")
                    if TTS then
                        local success, err = pcall(function()
                            TTS:FireServer("Hopping servers now!", "9")
                        end)
                        if not success then
                            createNotification("TTS failed in hop: " .. tostring(err), COLORS.NOTIFICATION_ERROR)
                        end
                    end
                    serverHop()
                elseif text:find("!annoy") then
                    local annoyName = text:match("!annoy%s*(.+)")
                    if annoyName then
                        local annoyPlayer = findPlayerByPartialName(annoyName)
                        if annoyPlayer then
                            sendChatMessage("🎯 Annoying " .. annoyPlayer.Name .. " now!")
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
