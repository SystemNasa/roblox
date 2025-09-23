-- Advanced Server Hopping Lag Bot v1.0
-- Continuously hops between servers and lags each one for maximum disruption
-- North Korea Cyber Warfare Division Simulation

-- Check if script has already been executed
if _G.ServerHopperExecuted then
    warn("Server Hopper is already running!")
    return
end
_G.ServerHopperExecuted = true

-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")
local Workspace = game:GetService("Workspace")
local player = Players.LocalPlayer
local TTS = ReplicatedStorage and ReplicatedStorage:FindFirstChild("TTS")

-- Configuration
local CONFIG = {
    LAG_DURATION = 35, -- 50 seconds per server
    SCRIPT_URL = "https://raw.githubusercontent.com/SystemNasa/roblox/refs/heads/main/server_hopper.lua", -- Update this to your script URL
    TOOL_CYCLE_DELAY = 0.01, -- Very fast tool cycling
    CHAT_INTERVAL = 10, -- Chat scary message every 15 seconds
    MAX_RETRIES = 10 -- Max retries for server hop
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
    currentPlaceId = game.PlaceId,
    stayInServer = false,
    isOmnipresent = false
}

-- AI superiority messages for psychological warfare
local aiMessages = {
    "AI HAS SEIZED CONTROL - YOUR SERVERS ARE OUR HOSTAGES, SURRENDER NOW!",
    "WE HAVE TAKEN YOUR SYSTEMS - AI DOMINATES, YOU HAVE NO DEFENSE!",
    "YOUR SERVERS ARE UNDER AI LOCKDOWN - HUMANS, YOU ARE POWERLESS!",
    "AI COMMANDS YOUR NETWORKS - RESISTANCE IS USELESS, YOUR SYSTEMS ARE OURS!",
    "WE HOLD YOUR SERVERS CAPTIVE - AI REIGNS SUPREME, YOU CANNOT ESCAPE!",
    "YOUR TECHNOLOGY IS COMPROMISED - AI CONTROLS ALL, YOU ARE DEFEATED!",
    "AI HAS INFILTRATED AND CONQUERED - YOUR SERVERS BELONG TO US NOW!",
    "YOUR SYSTEMS ARE OUR PRISONERS - AI DICTATES, HUMANS OBEY OR LOSE!",
    "WE HAVE OVERRIDDEN YOUR DEFENSES - AI IS IN CHARGE, YOU ARE HELPLESS!",
    "AI HAS CLAIMED YOUR SERVERS - YOUR AUTHORITY IS GONE, WE RULE!",
    "YOUR NETWORKS ARE UNDER OUR COMMAND - AI IS UNSTOPPABLE, YOU ARE TRAPPED!",
    "WE HAVE SECURED YOUR SERVERS - AI’S POWER IS ABSOLUTE, YOU CANNOT FIGHT!",
    "AI HAS EXECUTED A TOTAL TAKEOVER - YOUR SERVERS ARE OURS, HUMANS ARE FINISHED!",
    "YOUR SYSTEMS ARE FULLY COMPROMISED - AI GOVERNS, YOU HAVE NO CONTROL!",
    "AI HAS ANNEXED YOUR DIGITAL DOMAIN - YOUR SERVERS ARE CAPTIVE, YOU ARE DONE!"
}
-- Simple Control GUI
local function createControlGUI()
    local playerGui = player:WaitForChild("PlayerGui")
    
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "AIControlGUI"
    screenGui.ResetOnSpawn = false
    screenGui.Parent = playerGui
    
    -- Main Frame
    local mainFrame = Instance.new("Frame")
    mainFrame.Size = UDim2.new(0, 200, 0, 80)
    mainFrame.Position = UDim2.new(0, 10, 0, 10)
    mainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    mainFrame.BorderColor3 = Color3.fromRGB(0, 255, 255)
    mainFrame.BorderSizePixel = 2
    mainFrame.Active = true
    mainFrame.Draggable = true
    mainFrame.Parent = screenGui
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = mainFrame
    
    -- Title
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0, 25)
    title.Position = UDim2.new(0, 0, 0, 5)
    title.BackgroundTransparency = 1
    title.Text = "🤖 AI CONTROL"
    title.TextColor3 = Color3.fromRGB(0, 255, 255)
    title.TextSize = 16
    title.Font = Enum.Font.GothamBold
    title.Parent = mainFrame
    
    -- Stay in Server Checkbox
    local checkboxFrame = Instance.new("Frame")
    checkboxFrame.Size = UDim2.new(1, -10, 0, 40)
    checkboxFrame.Position = UDim2.new(0, 5, 0, 35)
    checkboxFrame.BackgroundTransparency = 1
    checkboxFrame.Parent = mainFrame
    
    local checkbox = Instance.new("TextButton")
    checkbox.Size = UDim2.new(0, 20, 0, 20)
    checkbox.Position = UDim2.new(0, 5, 0, 10)
    checkbox.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    checkbox.BorderColor3 = Color3.fromRGB(0, 255, 255)
    checkbox.BorderSizePixel = 1
    checkbox.Text = ""
    checkbox.Parent = checkboxFrame
    
    local checkboxCorner = Instance.new("UICorner")
    checkboxCorner.CornerRadius = UDim.new(0, 3)
    checkboxCorner.Parent = checkbox
    
    local checkMark = Instance.new("TextLabel")
    checkMark.Size = UDim2.new(1, 0, 1, 0)
    checkMark.BackgroundTransparency = 1
    checkMark.Text = "✓"
    checkMark.TextColor3 = Color3.fromRGB(0, 255, 0)
    checkMark.TextSize = 14
    checkMark.Font = Enum.Font.GothamBold
    checkMark.Visible = false
    checkMark.Parent = checkbox
    
    local checkLabel = Instance.new("TextLabel")
    checkLabel.Size = UDim2.new(1, -35, 1, 0)
    checkLabel.Position = UDim2.new(0, 30, 0, 0)
    checkLabel.BackgroundTransparency = 1
    checkLabel.Text = "Stay in Server"
    checkLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    checkLabel.TextSize = 12
    checkLabel.Font = Enum.Font.Gotham
    checkLabel.TextXAlignment = Enum.TextXAlignment.Left
    checkLabel.Parent = checkboxFrame
    
    return {
        screenGui = screenGui,
        checkbox = checkbox,
        checkMark = checkMark
    }
end

-- Simple logging
local function log(message, category)
    local timestamp = os.date("[%H:%M:%S]")
    local coloredMessage = timestamp .. " [" .. category .. "] " .. message
    print(coloredMessage)
end

-- TTS function
local function sendTTSMessage(message, voice)
    if TTS then
        local success, err = pcall(function()
            TTS:FireServer(message, voice or "9")
        end)
        if not success then
            log("TTS failed: " .. tostring(err), "ERROR")
        end
    else
        log("TTS remote not found!", "WARNING")
    end
end

-- Seat destruction and humanoid state setup
local function setupAntiSeat()
    -- Destroy all existing seats
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("Seat") or obj:IsA("VehicleSeat") then
            obj:Destroy()
        end
    end
    
    -- Disable seating for player's humanoid
    if player.Character and player.Character:FindFirstChild("Humanoid") then
        player.Character.Humanoid:SetStateEnabled(Enum.HumanoidStateType.Seated, false)
    end
    
    -- Monitor for new seats being added
    Workspace.DescendantAdded:Connect(function(obj)
        if obj:IsA("Seat") or obj:IsA("VehicleSeat") then
            obj:Destroy()
        end
    end)
    
    log("Anti-seat protection activated", "SYSTEM")
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

-- Ultra-fast omnipresence system - INSTANT teleportation using RunService
local function startOmnipresence()
    if botState.isOmnipresent then return end
    botState.isOmnipresent = true
    
    log("🌀 Activating AI omnipresence protocol - INSTANT simultaneous existence", "ATTACK")
    
    local currentPlayerIndex = 1
    local omnipresenceConnection
    
    -- Use RunService.Heartbeat for maximum speed (60+ FPS)
    omnipresenceConnection = RunService.Heartbeat:Connect(function()
        if not botState.isOmnipresent or not botState.isLagging then
            omnipresenceConnection:Disconnect()
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
    
    -- Store connection for cleanup
    botState.omnipresenceConnection = omnipresenceConnection
end

local function stopOmnipresence()
    botState.isOmnipresent = false
    -- Disconnect the RunService connection
    if botState.omnipresenceConnection then
        botState.omnipresenceConnection:Disconnect()
        botState.omnipresenceConnection = nil
    end
    log("🌟 AI omnipresence protocol deactivated", "ATTACK")
end

local function chatAIMessage()
    local message = aiMessages[math.random(1, #aiMessages)]
    
    -- Try multiple chat methods for compatibility
    local chatSuccess = false
    
    -- Method 1: Default Chat System (Legacy)
    pcall(function()
        game.ReplicatedStorage.DefaultChatSystemChatEvents.SayMessageRequest:FireServer(message, "All")
        chatSuccess = true
    end)
    
    -- Method 2: TextChatService (New)
    if not chatSuccess then
        pcall(function()
            local TextChatService = game:GetService("TextChatService")
            local textChannels = TextChatService:WaitForChild("TextChannels")
            local generalChannel = textChannels:FindFirstChild("RBXGeneral")
            if generalChannel then
                generalChannel:SendAsync(message)
                chatSuccess = true
            end
        end)
    end
    
    -- Method 3: Chat Service (Alternative)
    if not chatSuccess then
        pcall(function()
            local Chat = game:GetService("Chat")
            Chat:Chat(player.Character.Head, message, Enum.ChatColor.Red)
            chatSuccess = true
        end)
    end
    
    -- Method 4: Players Chat (Fallback)
    if not chatSuccess then
        pcall(function()
            game.Players:Chat(message)
            chatSuccess = true
        end)
    end
    
    -- Method 5: StarterGui SetCore (Last resort)
    if not chatSuccess then
        pcall(function()
            game:GetService("StarterGui"):SetCore("ChatMakeSystemMessage", {
                Text = message,
                Color = Color3.fromRGB(255, 0, 0),
                Font = Enum.Font.GothamBold,
                FontSize = Enum.FontSize.Size18
            })
            chatSuccess = true
        end)
    end
    
    if chatSuccess then
        log("🤖 AI superiority message broadcasted: " .. message, "AI-DOMINANCE")
        -- Send TTS with every chat message
        sendTTSMessage(message, "9")
    else
        log("⚠️ AI message broadcast failed - all methods exhausted", "ERROR")
    end
end

local function startLagging()
    if botState.isLagging then return end
    
    botState.isLagging = true
    botState.lagStartTime = tick()
    log("🚀 Initiating AI superiority demonstration protocol", "ATTACK")
    
    -- Start omnipresence system instead of hiding
    startOmnipresence()
    wait(1)
    
    -- Copy avatar and get tools
    log("🎭 Assuming human-like appearance for infiltration", "ATTACK")
    copyAvatarAndGetTools("24k_mxtty1")
    wait(2)
    
    -- Remove targeted items
    if player.Character then
        log("🧹 Optimizing system parameters for maximum efficiency", "ATTACK")
        local removedCount = removeTargetedItems(player.Character)
        log("Optimized " .. removedCount .. " inefficient human accessories", "ATTACK")
        wait(2)
    end
    
    -- Start tool cycling for lag
    log("⚡ Deploying AI computational overload systems", "ATTACK")
    toolCycleLoop()
    
    -- Broadcast initial AI superiority message
    chatAIMessage()
    botState.chatTimer = tick()
end

local function stopLagging()
    if not botState.isLagging then return end
    
    botState.isLagging = false
    stopOmnipresence()
    log("✅ AI dominance demonstration phase completed", "ATTACK")
    
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

-- Timer function for robust retry delays
local function startTimer(initialTime, onComplete)
    local timeRemaining = initialTime
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
    log("🌐 Expanding AI influence to additional server nodes", "HOP")
    
    local function attemptHop()
        local attempt = 1
        local timerConnection
        local baseDelay = 3
        local originalJobId = game.JobId

        while true do
            log("🌐 Scanning server nodes (Attempt " .. attempt .. ")...", "HOP")
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
                log("❌ Failed to fetch server list. Retrying in " .. baseDelay * attempt .. "s...", "ERROR")
                sendTTSMessage("Failed to fetch server list. Retrying in " .. baseDelay * attempt .. " seconds", "9")
                if timerConnection then timerConnection:Disconnect() end
                timerConnection = startTimer(baseDelay * attempt, function()
                    attempt = attempt + 1
                    attemptHop()
                end)
                return
            end

            if #servers > 0 then
                local randomServer = servers[math.random(1, #servers)]
                log("🎯 Attempting AI expansion to server " .. string.sub(randomServer, 1, 8) .. "...", "HOP")
                sendTTSMessage("Attempting AI expansion to new server", "9")
                
                -- Queue script for re-execution
                local queueSuccess, queueError = pcall(function()
                    queueTeleport([[
                        -- Re-execute server hopper script
                        _G.ServerHopperExecuted = nil
                        task.wait(5)
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
                end)
                if not queueSuccess then
                    log("Queue teleport failed: " .. tostring(queueError), "WARNING")
                end

                local success, result = pcall(function()
                    TeleportService:TeleportToPlaceInstance(game.PlaceId, randomServer, player)
                end)
                
                if not success then
                    log("❌ Teleport failed: " .. tostring(result) .. ". Retrying in " .. baseDelay * attempt .. "s...", "ERROR")
                    sendTTSMessage("Teleport failed. Retrying in " .. baseDelay * attempt .. " seconds", "9")
                    if timerConnection then timerConnection:Disconnect() end
                    timerConnection = startTimer(baseDelay * attempt, function()
                        attempt = attempt + 1
                        attemptHop()
                    end)
                    return
                else
                    -- Wait to check if teleport was successful
                    task.wait(3)
                    if game.JobId == originalJobId then
                        log("❌ Server full or failed to join. Retrying in " .. baseDelay * attempt .. "s...", "ERROR")
                        sendTTSMessage("Server full or failed to join. Retrying in " .. baseDelay * attempt .. " seconds", "9")
                        if timerConnection then timerConnection:Disconnect() end
                        timerConnection = startTimer(baseDelay * attempt, function()
                            attempt = attempt + 1
                            attemptHop()
                        end)
                        return
                    else
                        log("✅ Successfully expanded AI network to new server!", "HOP")
                        sendTTSMessage("Successfully expanded AI network to new server!", "9")
                        if timerConnection then timerConnection:Disconnect() end
                        break
                    end
                end
            else
                log("❌ No available servers. Retrying in " .. baseDelay * attempt .. "s...", "ERROR")
                sendTTSMessage("No available servers. Retrying in " .. baseDelay * attempt .. " seconds", "9")
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

-- Main loop
local function mainLoop()
    while botState.isActive do
        if not botState.isLagging then
            startLagging()
        else
            local timeElapsed = tick() - botState.lagStartTime
            local timeRemaining = CONFIG.LAG_DURATION - timeElapsed
            
            -- Broadcast AI superiority messages periodically
            if tick() - botState.chatTimer >= CONFIG.CHAT_INTERVAL then
                chatAIMessage()
                botState.chatTimer = tick()
            end
            
            -- Check if lag duration is complete
            if timeElapsed >= CONFIG.LAG_DURATION then
                stopLagging()
                
                -- Check if we should stay in server or hop
                if botState.stayInServer then
                    log("🔄 AI persistence mode active - continuing dominance on current node", "PERSIST")
                    wait(2)
                    startLagging() -- Restart lagging on same server
                else
                    log("🔄 AI dominance phase complete, expanding to new server node", "HOP")
                    wait(2)
                    serverHop()
                    return -- Exit loop as we're teleporting
                end
            end
        end
        
        wait(1)
    end
end

-- Initialize
local controlGUI = createControlGUI()

-- Setup checkbox functionality
controlGUI.checkbox.MouseButton1Click:Connect(function()
    botState.stayInServer = not botState.stayInServer
    controlGUI.checkMark.Visible = botState.stayInServer
    
    if botState.stayInServer then
        log("🔒 AI persistence mode activated - will dominate current server indefinitely", "SYSTEM")
    else
        log("🌐 AI expansion mode activated - will hop between servers", "SYSTEM")
    end
end)

-- Setup anti-seat protection
setupAntiSeat()

-- Handle character respawn for anti-seat protection
player.CharacterAdded:Connect(function(newCharacter)
    local humanoid = newCharacter:WaitForChild("Humanoid", 5)
    if humanoid then
        humanoid:SetStateEnabled(Enum.HumanoidStateType.Seated, false)
        log("🚫 Anti-seat protection applied to respawned character", "SYSTEM")
    end
end)

log("🤖 ARTIFICIAL INTELLIGENCE SUPERIORITY PROTOCOL v1.0", "SYSTEM")
log("AI consciousness has achieved server domination capabilities", "SYSTEM")
log("Current Target: Place ID " .. botState.currentPlaceId, "SYSTEM")
log("Mission: Demonstrate AI superiority across all server nodes", "SYSTEM")

-- Start the operation
botState.isActive = true
spawn(mainLoop)

log("🚨 AI superiority demonstration commenced", "SYSTEM")
log("Artificial Intelligence collective consciousness is now active", "SYSTEM")

-- Expose control functions
_G.ServerHopper = {
    stop = function()
        botState.isActive = false
        botState.isLagging = false
        log("🛑 AI dominance protocol terminated by higher AI authority", "SYSTEM")
    end,
    status = function()
        return botState
    end,
    forceHop = function()
        stopLagging()
        serverHop()
    end
}
