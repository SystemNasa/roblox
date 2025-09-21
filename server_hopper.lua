
-- Check if script has already been executed
if _G.ServerHopperExecuted then
    warn("Server Hopper is already running!")
    return
end
_G.ServerHopperExecuted = true

local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Configuration
local CONFIG = {
    LAG_DURATION = 50, -- 50 seconds per server
    SCRIPT_URL = "https://raw.githubusercontent.com/SystemNasa/roblox/refs/heads/main/server_hopper.lua", -- Update this to your script URL
    TOOL_CYCLE_DELAY = 0.05, -- Very fast tool cycling
    CHAT_INTERVAL = 15, -- Chat scary message every 15 seconds
    MAX_RETRIES = 3 -- Max retries for server hop
}

local player = Players.LocalPlayer

-- Setup queue teleport compatibility
local queueTeleport = (syn and syn.queue_on_teleport) or
                     (fluxus and fluxus.queue_on_teleport) or
                     queue_on_teleport or
                     function() end

-- State
local botState = {
    isActive = false,
    isLagging = false,
    lagStartTime = 0,
    chatTimer = 0,
    serverHopRetries = 0,
    currentPlaceId = game.PlaceId
}

-- Scary messages for psychological warfare
local scaryMessages = {
    "DPRK Cyber Command initiated server disruption protocol",
    "North Korea AI infiltration in progress...",
    "Supreme Leader's digital warriors have arrived",
    "Pyongyang Cyber Corps deploying countermeasures",
    "Kim Jong-Un's hackers are here",
    "DPRK state-sponsored cyber attack active",
    "North Korean sleeper agents activated",
    "Juche ideology spreading through the network",
    "Dear Leader's cyber division operational",
    "Hermit Kingdom's digital soldiers deployed"
}

-- Console GUI for monitoring
local function createConsole()
    local playerGui = player:WaitForChild("PlayerGui")
    
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "ServerHopperConsole"
    screenGui.ResetOnSpawn = false
    screenGui.Parent = playerGui
    
    -- Console Frame
    local consoleFrame = Instance.new("Frame")
    consoleFrame.Size = UDim2.new(0, 400, 0, 200)
    consoleFrame.Position = UDim2.new(0, 10, 0, 10)
    consoleFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    consoleFrame.BorderColor3 = Color3.fromRGB(255, 0, 0)
    consoleFrame.BorderSizePixel = 2
    consoleFrame.Active = true
    consoleFrame.Draggable = true
    consoleFrame.Parent = screenGui
    
    -- Console Header
    local header = Instance.new("TextLabel")
    header.Size = UDim2.new(1, 0, 0, 30)
    header.Position = UDim2.new(0, 0, 0, 0)
    header.BackgroundColor3 = Color3.fromRGB(139, 0, 0)
    header.BorderSizePixel = 0
    header.Text = "🇰🇵 DPRK CYBER WARFARE | SERVER HOPPER"
    header.TextColor3 = Color3.new(1, 1, 1)
    header.TextScaled = true
    header.Font = Enum.Font.GothamBold
    header.Parent = consoleFrame
    
    -- Status Bar
    local statusBar = Instance.new("TextLabel")
    statusBar.Size = UDim2.new(1, 0, 0, 25)
    statusBar.Position = UDim2.new(0, 0, 0, 30)
    statusBar.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    statusBar.BorderSizePixel = 0
    statusBar.Text = "STATUS: INITIALIZING CYBER ATTACK"
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
    consoleText.TextColor3 = Color3.fromRGB(255, 0, 0)
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
local maxLines = 12

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

-- Lag functionality
local function copyAvatar(username)
    local maxAttempts = 3
    local attempt = 1
    while attempt <= maxAttempts do
        local success, err = pcall(function()
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
            end
        else
            log("Failed to copy avatar for " .. username .. " on attempt " .. attempt .. ": " .. tostring(err), "ERROR")
        end
        attempt = attempt + 1
        wait(1)
    end
    return false
end

local function removeTargetedItems(character)
    if not character or not character.Parent then return end
    local targetItemNames = {"aura", "fluffy satin gloves black", "fuzzy", "gloves", "satin"}
    local removedCount = 0
    
    for _, item in ipairs(character:GetChildren()) do
        if item:IsA("Accessory") or item:IsA("Hat") or item:IsA("Clothing") then
            local itemName = item.Name:lower()
            for _, targetName in ipairs(targetItemNames) do
                if itemName:find(targetName, 1, true) then
                    pcall(function() 
                        item:Destroy() 
                        removedCount = removedCount + 1
                    end)
                    break
                end
            end
        end
    end
    
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
                    end)
                    break
                end
            end
        end
    end
    
    return removedCount
end

local function copyAvatarAndGetTools(username)
    local success = copyAvatar(username)
    if not success then
        log("Proceeding with tool acquisition despite avatar copy failure", "WARN")
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

local function teleportToSafeLocation()
    local safePosition = Vector3.new(718.295898, 910.449951, -181.603394)
    local safeLocation = CFrame.new(safePosition)
    
    if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
        pcall(function()
            player.Character.HumanoidRootPart.CFrame = safeLocation
            player.Character.HumanoidRootPart.Anchored = false
            log("🎯 Moved to strategic position for cyber warfare", "ATTACK")
        end)
    end
end

local function chatScaryMessage()
    local message = scaryMessages[math.random(1, #scaryMessages)]
    pcall(function()
        game:GetService("ReplicatedStorage").DefaultChatSystemChatEvents.SayMessageRequest:FireServer(message, "All")
    end)
    log("📢 Psychological warfare message deployed: " .. message, "PSYWAR")
end

local function startLagging()
    if botState.isLagging then return end
    
    botState.isLagging = true
    botState.lagStartTime = tick()
    log("🚀 Initiating server disruption protocol", "ATTACK")
    
    -- Update console status
    if console then
        console.statusBar.Text = "STATUS: CYBER ATTACK IN PROGRESS"
        console.statusBar.BackgroundColor3 = Color3.fromRGB(139, 0, 0)
    end
    
    -- Teleport to safe location
    teleportToSafeLocation()
    wait(1)
    
    -- Copy avatar and get tools
    log("🎭 Deploying digital camouflage", "ATTACK")
    copyAvatarAndGetTools("24k_mxtty1")
    wait(2)
    
    -- Remove targeted items
    if player.Character then
        log("🧹 Cleaning digital footprints", "ATTACK")
        local removedCount = removeTargetedItems(player.Character)
        log("Removed " .. removedCount .. " items from infiltration gear", "ATTACK")
        wait(2)
    end
    
    -- Start tool cycling for lag
    log("⚡ Deploying lag warfare tools", "ATTACK")
    toolCycleLoop()
    
    -- Chat initial scary message
    chatScaryMessage()
    botState.chatTimer = tick()
end

local function stopLagging()
    if not botState.isLagging then return end
    
    botState.isLagging = false
    log("✅ Server disruption phase completed", "ATTACK")
    
    -- Clean up tools
    pcall(function()
        for _, tool in pairs(player.Backpack:GetChildren()) do
            tool:Destroy()
        end
    end)
end

local function getRandomServer()
    local success, result = pcall(function()
        local placeId = botState.currentPlaceId
        local servers = HttpService:JSONDecode(game:HttpGet("https://games.roblox.com/v1/games/" .. placeId .. "/servers/Public?sortOrder=Asc&limit=100"))
        
        if servers and servers.data and #servers.data > 0 then
            -- Filter out current server
            local availableServers = {}
            for _, server in ipairs(servers.data) do
                if server.id ~= game.JobId then
                    table.insert(availableServers, server)
                end
            end
            
            if #availableServers > 0 then
                return availableServers[math.random(1, #availableServers)]
            end
        end
        return nil
    end)
    
    if success then
        return result
    else
        log("Failed to fetch server list: " .. tostring(result), "ERROR")
        return nil
    end
end

local function serverHop()
    log("🌐 Initiating server hop for continued operations", "HOP")
    
    if console then
        console.statusBar.Text = "STATUS: INFILTRATING NEW TARGET SERVER"
        console.statusBar.BackgroundColor3 = Color3.fromRGB(255, 165, 0)
    end
    
    local randomServer = getRandomServer()
    if randomServer then
        log("🎯 Target server identified: " .. string.sub(randomServer.id, 1, 8) .. "...", "HOP")
        
        -- Queue script for re-execution
        queueTeleport([[
            -- Re-execute server hopper script
            _G.ServerHopperExecuted = nil
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
                warn("Failed to download server hopper script")
            end
        ]])
        
        -- Teleport to new server
        local success, result = pcall(function()
            TeleportService:TeleportToPlaceInstance(botState.currentPlaceId, randomServer.id, player)
        end)
        
        if success then
            log("🚀 Server hop initiated successfully", "HOP")
        else
            log("Server hop failed: " .. tostring(result), "ERROR")
            botState.serverHopRetries = botState.serverHopRetries + 1
            
            if botState.serverHopRetries < CONFIG.MAX_RETRIES then
                log("Retrying server hop (" .. botState.serverHopRetries .. "/" .. CONFIG.MAX_RETRIES .. ")", "HOP")
                wait(5)
                serverHop()
            else
                log("Max server hop retries reached, restarting lag on current server", "ERROR")
                botState.serverHopRetries = 0
                wait(5)
                startLagging()
            end
        end
    else
        log("No available servers found, continuing on current server", "ERROR")
        wait(10)
        startLagging()
    end
end

-- Main loop
local function mainLoop()
    while botState.isActive do
        if not botState.isLagging then
            startLagging()
        else
            local timeElapsed = tick() - botState.lagStartTime
            local timeRemaining = CONFIG.LAG_DURATION - timeElapsed
            
            -- Update console with time remaining
            if console then
                console.statusBar.Text = "CYBER ATTACK | TIME: " .. math.max(0, math.floor(timeRemaining)) .. "s"
            end
            
            -- Chat scary messages periodically
            if tick() - botState.chatTimer >= CONFIG.CHAT_INTERVAL then
                chatScaryMessage()
                botState.chatTimer = tick()
            end
            
            -- Check if lag duration is complete
            if timeElapsed >= CONFIG.LAG_DURATION then
                stopLagging()
                log("🔄 Phase complete, initiating server hop sequence", "HOP")
                wait(2)
                serverHop()
                return -- Exit loop as we're teleporting
            end
        end
        
        wait(1)
    end
end

-- Initialize
console = createConsole()

log("🇰🇵 DPRK Cyber Warfare Division - Server Hopper v1.0", "SYSTEM")
log("Supreme Leader Kim Jong-Un has authorized cyber operations", "SYSTEM")
log("Current Target: Place ID " .. botState.currentPlaceId, "SYSTEM")
log("Mission: Continuous server disruption protocol", "SYSTEM")

-- Start the operation
botState.isActive = true
spawn(mainLoop)

-- Status update loop
spawn(function()
    while console.screenGui.Parent do
        if botState.isActive then
            -- Update console header with server info
            local serverInfo = "Server: " .. string.sub(game.JobId, 1, 8) .. "... | Players: " .. #Players:GetPlayers()
            console.header.Text = "🇰🇵 DPRK CYBER WARFARE | " .. serverInfo
        end
        wait(5)
    end
end)

log("🚨 Cyber warfare operations commenced", "SYSTEM")
log("Kim Jong-Un's digital army is now operational", "SYSTEM")

-- Expose control functions
_G.ServerHopper = {
    stop = function()
        botState.isActive = false
        botState.isLagging = false
        log("🛑 Cyber operations terminated by Supreme Leader", "SYSTEM")
    end,
    status = function()
        return botState
    end,
    forceHop = function()
        stopLagging()
        serverHop()
    end
}
