--[[ Original Anti-Idle & Services ]]--

local VirtualUser = game:GetService('VirtualUser')

if game:GetService('Players').LocalPlayer then
    game:GetService('Players').LocalPlayer.Idled:Connect(function()
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new())
    end)
end


--[[ Services ]]--

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")


--[[ Destroy Existing UI ]]--

local oldGui = PlayerGui:FindFirstChild("VenomHubScreenGui")
if oldGui then
    oldGui:Destroy()
end

local oldCategorizedGui = PlayerGui:FindFirstChild("VenomHubScreenGui_Categorized")
if oldCategorizedGui then
    oldCategorizedGui:Destroy()
end

local oldKeyGui = PlayerGui:FindFirstChild("KeyVerificationUI")
if oldKeyGui then
    oldKeyGui:Destroy()
end




-------------------------------------------------------------------------------
--  1. Tworzenie Głównego UI
-------------------------------------------------------------------------------

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "VenomHubScreenGui_Categorized"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = PlayerGui

local mainFrame = Instance.new("Frame")
mainFrame.Name = "VenomHubMainFrame"
mainFrame.Size = UDim2.new(0, 450, 0, 350)
mainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
mainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
mainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
mainFrame.BorderSizePixel = 0
mainFrame.ClipsDescendants = true
mainFrame.Visible = true
mainFrame.Active = true
mainFrame.Draggable = false
mainFrame.Parent = screenGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 12)
corner.Parent = mainFrame

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(60, 60, 75)
stroke.Thickness = 1
stroke.Transparency = 0.5
stroke.Parent = mainFrame

local titleLabel = Instance.new("TextLabel")
titleLabel.Name = "Title"
titleLabel.Size = UDim2.new(1, -40, 0, 40)
titleLabel.Position = UDim2.new(0, 20, 0, 5)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "EQR HUB v.1.28F"
titleLabel.Font = Enum.Font.GothamSemibold
titleLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
titleLabel.TextSize = 20
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Parent = mainFrame

local line = Instance.new("Frame")
line.Name = "Divider"
line.Size = UDim2.new(1, -40, 0, 1)
line.Position = UDim2.new(0, 20, 0, 40)
line.BackgroundColor3 = Color3.fromRGB(60, 60, 75)
line.BorderSizePixel = 0
line.Parent = mainFrame

local footerLabel = Instance.new("TextLabel")
footerLabel.Name = "Footer"
footerLabel.Size = UDim2.new(1, -20, 0, 20)
footerLabel.Position = UDim2.new(0, 10, 1, -25)
footerLabel.BackgroundTransparency = 1
footerLabel.Text = "By helloitsme#4243 | Press K to Toggle"
footerLabel.Font = Enum.Font.Gotham
footerLabel.TextSize = 10
footerLabel.TextColor3 = Color3.fromRGB(100, 100, 120)
footerLabel.TextXAlignment = Enum.TextXAlignment.Right
footerLabel.Parent = mainFrame

local sidebarFrame = Instance.new("Frame")
sidebarFrame.Name = "SidebarFrame"
sidebarFrame.Size = UDim2.new(0, 120, 1, -70)
sidebarFrame.Position = UDim2.new(0, 10, 0, 50)
sidebarFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
sidebarFrame.BorderSizePixel = 0
sidebarFrame.Parent = mainFrame

local sidebarCorner = Instance.new("UICorner")
sidebarCorner.CornerRadius = UDim.new(0, 8)
sidebarCorner.Parent = sidebarFrame

local sidebarLayout = Instance.new("UIListLayout")
sidebarLayout.Padding = UDim.new(0, 5)
sidebarLayout.SortOrder = Enum.SortOrder.LayoutOrder
sidebarLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
sidebarLayout.Parent = sidebarFrame

local contentFrame = Instance.new("ScrollingFrame")
contentFrame.Name = "ContentFrame"
contentFrame.Size = UDim2.new(1, -150, 1, -70)
contentFrame.Position = UDim2.new(0, 140, 0, 50)
contentFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
contentFrame.BorderSizePixel = 0
contentFrame.ScrollingDirection = Enum.ScrollingDirection.Y
contentFrame.ScrollBarThickness = 6
contentFrame.ScrollBarImageColor3 = Color3.fromRGB(60, 60, 75)
contentFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
contentFrame.Parent = mainFrame

local contentCorner = Instance.new("UICorner")
contentCorner.CornerRadius = UDim.new(0, 8)
contentCorner.Parent = contentFrame

local contentLayout = Instance.new("UIListLayout")
contentLayout.Padding = UDim.new(0, 8)
contentLayout.SortOrder = Enum.SortOrder.LayoutOrder
contentLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
contentLayout.Parent = contentFrame

contentLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    contentFrame.CanvasSize = UDim2.new(0, 0, 0, contentLayout.AbsoluteContentSize.Y + 120)
end)


local subTabContainer = Instance.new("Frame")
subTabContainer.Name = "SubTabContainer"
subTabContainer.Size = UDim2.new(1, -150, 0, 30)
subTabContainer.Position = UDim2.new(0, 140, 0, 45)
subTabContainer.BackgroundTransparency = 1
subTabContainer.Visible = false
subTabContainer.Parent = mainFrame
local subTabLayout = Instance.new("UIListLayout")
subTabLayout.FillDirection = Enum.FillDirection.Horizontal
subTabLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
subTabLayout.VerticalAlignment = Enum.VerticalAlignment.Center
subTabLayout.Padding = UDim.new(0, 5)
subTabLayout.SortOrder = Enum.SortOrder.LayoutOrder
subTabLayout.Parent = subTabContainer

-------------------------------------------------------------------------------
--  2. tragerea ferestrei
-------------------------------------------------------------------------------
do
    local dragging = false
    local dragInput = nil
    local dragStart = nil
    local startPos = nil

    local function update(input)
        local delta = input.Position - dragStart
        local newX = startPos.X.Offset + delta.X
        local newY = startPos.Y.Offset + delta.Y
        mainFrame.Position = UDim2.new(startPos.X.Scale, newX, startPos.Y.Scale, newY)
    end

    mainFrame.InputBegan:Connect(function(input)
        if (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
            local absPos = mainFrame.AbsolutePosition
            local absSize = mainFrame.AbsoluteSize
            local headerHeight = 45

            if input.Position.Y < absPos.Y + headerHeight and input.Position.Y > absPos.Y and input.Position.X > absPos.X and input.Position.X < absPos.X + absSize.X then
                dragging = true
                dragStart = input.Position
                startPos = mainFrame.Position

                input.Changed:Connect(function()
                    if input.UserInputState == Enum.UserInputState.End then
                        dragging = false
                    end
                end)
            end
        end
    end)

    mainFrame.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            update(input)
        end
    end)
end


-------------------------------------------------------------------------------
--  3. Tasta [K] pentru afișare/ascundere
-------------------------------------------------------------------------------
UserInputService.InputBegan:Connect(function(input, gameProcessedEvent)
    if not gameProcessedEvent then
        if input.KeyCode == Enum.KeyCode.K then
            mainFrame.Visible = not mainFrame.Visible
        end
    end
end)


-------------------------------------------------------------------------------
--  4. Declarăm toate variabilele și funcțiile
-------------------------------------------------------------------------------

--======================= NO FAIL LOCKPICK =========================--

local RunService = game:GetService("RunService")
local Player = game:GetService("Players").LocalPlayer

local NoFailLockpick_Enabled = false
local lockpickAddedConnection = nil

function NoFailLockpick_Enable()
    if NoFailLockpick_Enabled then return end
    NoFailLockpick_Enabled = true

    local PlayerGui = Player:FindFirstChild("PlayerGui")
    if not PlayerGui then return end
    
    lockpickAddedConnection = PlayerGui.ChildAdded:Connect(function(Item)
        if Item.Name == "LockpickGUI" then
            local mf = Item:WaitForChild("MF", 10)
            if not mf then return end
            
            local lpFrame = mf:WaitForChild("LP_Frame", 10)
            if not lpFrame then return end
            
            local frames = lpFrame:WaitForChild("Frames", 10)
            if not frames then return end
            
            local b1 = frames:WaitForChild("B1", 10)
            local b2 = frames:WaitForChild("B2", 10)
            local b3 = frames:WaitForChild("B3", 10)

            if b1 and b1.Bar and b1.Bar:FindFirstChild("UIScale") then
                b1.Bar.UIScale.Scale = 10
            end
            if b2 and b2.Bar and b2.Bar:FindFirstChild("UIScale") then
                b2.Bar.UIScale.Scale = 10
            end
            if b3 and b3.Bar and b3.Bar:FindFirstChild("UIScale") then
                b3.Bar.UIScale.Scale = 10
            end
        end
    end)
end

function NoFailLockpick_Disable()
    if not NoFailLockpick_Enabled then return end
    NoFailLockpick_Enabled = false
    
    local PlayerGui = Player:FindFirstChild("PlayerGui")
    if not PlayerGui then return end

    if lockpickAddedConnection then
        lockpickAddedConnection:Disconnect()
        lockpickAddedConnection = nil
    end

    local lockpickGui = PlayerGui:FindFirstChild("LockpickGUI")
    if lockpickGui then
        local frames = lockpickGui:FindFirstChild("MF")
        if frames then
            local lpFrame = frames:FindFirstChild("LP_Frame")
            if lpFrame then
                local bars = lpFrame:FindFirstChild("Frames")
                if bars then
                    if bars.B1 and bars.B1.Bar and bars.B1.Bar:FindFirstChild("UIScale") then bars.B1.Bar.UIScale.Scale = 1 end
                    if bars.B2 and bars.B2.Bar and bars.B2.Bar:FindFirstChild("UIScale") then bars.B2.Bar.UIScale.Scale = 1 end
                    if bars.B3 and bars.B3.Bar and bars.B3.Bar:FindFirstChild("UIScale") then bars.B3.Bar.UIScale.Scale = 1 end
                end
            end
        end
    end
end

--======================= SAFE/REGISTER ESP =========================--
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Player = game:GetService("Players").LocalPlayer

local BredMakurz_Enabled = false
local bredMakurzConnection = nil
local safeTimers = {} -- Tabel pentru cronometru

local function formatName(name)
    name = string.gsub(name, "([a-z])([A-Z])", "%1 %2")
    local underscoreIndex = string.find(name, "_")
    if underscoreIndex then
        name = string.sub(name, 1, underscoreIndex - 1)
    end
    return name
end

local function ApplyBredMakurzModification(delta)
    local bredMakurzFolder = Workspace.Map:FindFirstChild("BredMakurz")
    if not bredMakurzFolder then return end

    for _, v in pairs(bredMakurzFolder:GetChildren()) do
        local values = v:FindFirstChild("Values")
        local brokenValue = values and values:FindFirstChild("Broken")
        
        -- Detectăm starea seifului
        local isBroken = false
        if brokenValue then
            isBroken = brokenValue.Value
        elseif v:FindFirstChild("Interact") then
            isBroken = v.Interact:GetAttribute("Broken") == true
        end

        local existingGui = v:FindFirstChild("Ahh")

        -- Eliminăm orice Highlight (Chams) dacă a rămas din greșeală
        if v:FindFirstChild("EspHighlight") then
            v.EspHighlight:Destroy()
        end

        if isBroken then
            -- Pornim timer-ul de 12 minute (720 secunde)
            if not safeTimers[v.Name] then
                safeTimers[v.Name] = 720 
            end

            -- Scădem timpul real
            if safeTimers[v.Name] > 0 then
                safeTimers[v.Name] = safeTimers[v.Name] - delta
            end

            if existingGui then
                local label = existingGui:FindFirstChildOfClass("TextLabel")
                if label then
                    local p = safeTimers[v.Name]
                    local minutes = math.floor(p / 60)
                    local seconds = math.floor(p % 60)
                    -- Afișăm doar timer-ul când e spart
                    label.Text = string.format("%s\n[COOLDOWN]\n%02d:%02d", formatName(v.Name), minutes, seconds)
                    label.TextColor3 = Color3.fromRGB(255, 100, 0) -- Portocaliu
                end
            end
        else
            -- SEIFUL E READY
            safeTimers[v.Name] = nil 

            if not existingGui then
                existingGui = Instance.new('BillboardGui', v)
                existingGui.Name = "Ahh"
                existingGui.AlwaysOnTop = true
                existingGui.Size = UDim2.new(0, 100, 0, 50)
                existingGui.MaxDistance = math.huge -- DISTANȚĂ INFINITĂ
                existingGui.StudsOffset = Vector3.new(0, 4, 0)
                
                local textLabel = Instance.new('TextLabel', existingGui)
                textLabel.Size = UDim2.new(1,0,1,0)
                textLabel.BackgroundTransparency = 1
                textLabel.Font = Enum.Font.SourceSansBold
                textLabel.TextSize = 14
                textLabel.TextStrokeTransparency = 0
            end

            local label = existingGui:FindFirstChildOfClass("TextLabel")
            if label then
                label.Text = formatName(v.Name) .. "\n[READY]"
                label.TextColor3 = Color3.fromRGB(0, 255, 0) -- Verde
            end
        end
    end
end

function BredMakurz_Enable()
    if BredMakurz_Enabled then return end 
    BredMakurz_Enabled = true
    
    local lastTime = tick()
    bredMakurzConnection = RunService.Heartbeat:Connect(function()
        local currentTime = tick()
        local delta = currentTime - lastTime
        lastTime = currentTime
        
        ApplyBredMakurzModification(delta)
    end)
end

function BredMakurz_Disable()
    if not BredMakurz_Enabled then return end 
    BredMakurz_Enabled = false

    if bredMakurzConnection then
        bredMakurzConnection:Disconnect()
        bredMakurzConnection = nil
    end

    safeTimers = {}

    local bredMakurzFolder = Workspace.Map:FindFirstChild("BredMakurz")
    if bredMakurzFolder then
        for _, v in pairs(bredMakurzFolder:GetChildren()) do
            if v:FindFirstChild("Ahh") then v.Ahh:Destroy() end
            -- Curățăm și eventualele Highlight-uri rămase
            if v:FindFirstChild("EspHighlight") then v.EspHighlight:Destroy() end
        end
    end
end
--======================= OPEN/UNLOCK NEARBY DOORS =========================--

local OpenNearbyDoors_Enabled = false
local UnlockNearbyDoors_Enabled = false
local NearbyDoorInteraction_Coroutine = nil

local function NearbyDoorInteraction_Loop()
    while (OpenNearbyDoors_Enabled or UnlockNearbyDoors_Enabled) do
        local waitTime = 0.25
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        local hum = char and char:FindFirstChildOfClass("Humanoid")

        if not hrp or not hum or hum.Health <= 0 then
            task.wait(waitTime * 2)
            continue
        end

        local doorsFolder = Workspace.Map:FindFirstChild("Doors")
        if not doorsFolder then
            warn("NearbyDoorInteraction: Cannot find Workspace.Map.Doors folder.")
            if OpenNearbyDoors_Enabled then OpenNearbyDoors_Disable() end
            if UnlockNearbyDoors_Enabled then UnlockNearbyDoors_Disable() end
            break
        end

        local playerPos = hrp.Position
        local checkRadius = 6

        for _, doorInstance in ipairs(doorsFolder:GetChildren()) do
            local doorBase = doorInstance:FindFirstChild("DoorBase")
            local valuesFolder = doorInstance:FindFirstChild("Values")
            local eventsFolder = doorInstance:FindFirstChild("Events")

            if doorBase and valuesFolder and eventsFolder then
                if (playerPos - doorBase.Position).Magnitude <= checkRadius then
                    local toggleEvent = eventsFolder:FindFirstChild("Toggle")
                    if not toggleEvent then continue end

                    if UnlockNearbyDoors_Enabled then
                        local lockedValue = valuesFolder:FindFirstChild("Locked")
                        local lockArgument = doorInstance:FindFirstChild("Lock")

                        if lockedValue and lockArgument and typeof(lockedValue.Value) == "boolean" and lockedValue.Value == true then
                            local success, err = pcall(function() toggleEvent:FireServer("Unlock", lockArgument) end)
                            if not success then warn("UnlockNearbyDoors: Error firing event for", doorInstance.Name, ":", err) end
                        end
                    end

                    if OpenNearbyDoors_Enabled then
                        local openValue = valuesFolder:FindFirstChild("Open")
                        local knobArgument = doorInstance:FindFirstChild("Knob2") or doorInstance:FindFirstChild("Knob")

                        if openValue and knobArgument and typeof(openValue.Value) == "boolean" and openValue.Value == false then
                            local isLocked = valuesFolder:FindFirstChild("Locked")
                            if not isLocked or isLocked.Value == false or not UnlockNearbyDoors_Enabled then
                                local success, err = pcall(function() toggleEvent:FireServer("Open", knobArgument) end)
                                if not success then warn("OpenNearbyDoors: Error firing event for", doorInstance.Name, ":", err) end
                            end
                        end
                    end
                end
            end
        end
        task.wait(waitTime)
    end
    NearbyDoorInteraction_Coroutine = nil
end

local function StartStopDoorInteractionLoop()
    local shouldRun = OpenNearbyDoors_Enabled or UnlockNearbyDoors_Enabled

    if shouldRun and not NearbyDoorInteraction_Coroutine then
        NearbyDoorInteraction_Coroutine = task.spawn(NearbyDoorInteraction_Loop)
    end
end

function OpenNearbyDoors_Enable()
    if OpenNearbyDoors_Enabled then return end
    OpenNearbyDoors_Enabled = true
    StartStopDoorInteractionLoop()
end

function OpenNearbyDoors_Disable()
    if not OpenNearbyDoors_Enabled then return end
    OpenNearbyDoors_Enabled = false
    StartStopDoorInteractionLoop()
end

function UnlockNearbyDoors_Enable()
    if UnlockNearbyDoors_Enabled then return end
    UnlockNearbyDoors_Enabled = true
    StartStopDoorInteractionLoop()
end

function UnlockNearbyDoors_Disable()
    if not UnlockNearbyDoors_Enabled then return end
    UnlockNearbyDoors_Enabled = false
    StartStopDoorInteractionLoop()
end

--======================= AUTO PICKUP MONEY =========================--

local AutoPickupMoney_Enabled = false
local AutoPickupMoney_Connection = nil
local AutoPickupMoney_Coroutine = nil

local CoolDowns = { AutoPickUps = { MoneyCooldown = false } }
local Settings = { IsDead = false }

local function AutoPickupMoney_Logic()
    local RunService = game:GetService("RunService")
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local Players = game:GetService("Players")
    local Workspace = game:GetService("Workspace")

    local cashFolder = Workspace.Filter:FindFirstChild("SpawnedBread")
    local remoteEvent = ReplicatedStorage.Events:FindFirstChild("CZDPZUS")

    if not cashFolder then
        warn("AutoPickupMoney: Could not find Workspace.Filter.SpawnedBread folder.")
        AutoPickupMoney_Disable()
        return
    end
    if not remoteEvent then
        warn("AutoPickupMoney: Could not find ReplicatedStorage.Events.CZDPZUS RemoteEvent.")
        AutoPickupMoney_Disable()
        return
    end

    if not CoolDowns then CoolDowns = {} end
    if not CoolDowns.AutoPickUps then CoolDowns.AutoPickUps = {} end
    if CoolDowns.AutoPickUps.MoneyCooldown == nil then CoolDowns.AutoPickUps.MoneyCooldown = false end
    if not Settings then Settings = {} end
    if Settings.IsDead == nil then Settings.IsDead = false end

    AutoPickupMoney_Connection = RunService.RenderStepped:Connect(function()
        if not AutoPickupMoney_Enabled then return end
        if Settings.IsDead then return end

        local player = Players.LocalPlayer
        local character = player and player.Character
        local hrp = character and character:FindFirstChild("HumanoidRootPart")

        if not hrp then return end
        if CoolDowns.AutoPickUps.MoneyCooldown then return end

        local rootPosition = hrp.Position
        for i, v in ipairs(cashFolder:GetChildren()) do
            if (rootPosition - v.Position).Magnitude < 5 then
                if not CoolDowns.AutoPickUps.MoneyCooldown then
                    CoolDowns.AutoPickUps.MoneyCooldown = true
                    pcall(function()
                        remoteEvent:FireServer(v)
                    end)
                    task.wait(1)
                    CoolDowns.AutoPickUps.MoneyCooldown = false
                    break
                end
            end
        end
    end)
end

local function AutoPickupMoney_Enable()
    if AutoPickupMoney_Enabled then return end
    AutoPickupMoney_Enabled = true

    if AutoPickupMoney_Connection then
        AutoPickupMoney_Connection:Disconnect()
        AutoPickupMoney_Connection = nil
    end
    if AutoPickupMoney_Coroutine then
        coroutine.close(AutoPickupMoney_Coroutine)
        AutoPickupMoney_Coroutine = nil
    end

    AutoPickupMoney_Coroutine = coroutine.create(AutoPickupMoney_Logic)
    coroutine.resume(AutoPickupMoney_Coroutine)
end

local function AutoPickupMoney_Disable()
    if not AutoPickupMoney_Enabled then return end
    AutoPickupMoney_Enabled = false

    if AutoPickupMoney_Connection then
        AutoPickupMoney_Connection:Disconnect()
        AutoPickupMoney_Connection = nil
    end
    if AutoPickupMoney_Coroutine then
        coroutine.close(AutoPickupMoney_Coroutine)
        AutoPickupMoney_Coroutine = nil
    end

    if CoolDowns and CoolDowns.AutoPickUps then
        CoolDowns.AutoPickUps.MoneyCooldown = false
    end
end

--============================ Fly ============================--

local FlySettings = { On = false, Method = "Ragdoll" }
local flySpd = 60
local RUNS = { Rag = nil, Old = nil }
local hrp = nil
local evFolderFly = game:GetService("ReplicatedStorage"):FindFirstChild("Events")
local flyEv = evFolderFly and evFolderFly:FindFirstChild("RZDONL")
local ragEv = evFolderFly and evFolderFly:FindFirstChild("__RZDONL")

local function stopRagLoop() if RUNS.Rag then RUNS.Rag:Disconnect(); RUNS.Rag = nil end end
local function stopOldFly() if RUNS.Old then RUNS.Old:Disconnect(); RUNS.Old = nil end end
local function stopAllFly() stopRagLoop(); stopOldFly(); if hrp then hrp.Velocity = Vector3.new(0,0,0) end end

local function startRagLoop()
    if not ragEv or not hrp then return end
    stopRagLoop()
    RUNS.Rag = game:GetService("RunService").RenderStepped:Connect(function()
        if not hrp or not FlySettings.On or FlySettings.Method ~= "Ragdoll" then stopAllFly(); return end
        ragEv:FireServer("__---r", Vector3.new(0,0,0), hrp.CFrame, false)
    end)
end

local function enRagFly()
    local me = game.Players.LocalPlayer
    local c = me.Character or me.CharacterAdded:Wait()
    hrp = c:FindFirstChild("HumanoidRootPart"); if not hrp then return end
    stopAllFly(); startRagLoop()
    RUNS.Old = game:GetService("RunService").RenderStepped:Connect(function()
        if not hrp or not FlySettings.On or FlySettings.Method ~= "Ragdoll" then stopAllFly(); return end
        local cam = workspace.CurrentCamera; local mv = Vector3.new(0,0,0)
        local UIS = game:GetService("UserInputService")
        if UIS:IsKeyDown(Enum.KeyCode.W) then mv = mv + cam.CFrame.LookVector * flySpd end
        if UIS:IsKeyDown(Enum.KeyCode.S) then mv = mv - cam.CFrame.LookVector * flySpd end
        if UIS:IsKeyDown(Enum.KeyCode.A) then mv = mv - cam.CFrame.RightVector * flySpd end
        if UIS:IsKeyDown(Enum.KeyCode.D) then mv = mv + cam.CFrame.RightVector * flySpd end
        hrp.Velocity = mv
        if flyEv then flyEv:FireServer("---r", Vector3.new(0,0,0), hrp.CFrame, false) end
    end)
end

local function enOldFly()
    local me = game.Players.LocalPlayer
    stopAllFly()
    RUNS.Old = game:GetService("RunService").RenderStepped:Connect(function()
        if not FlySettings.On or FlySettings.Method ~= "Old" then stopAllFly(); return end
        local p = me; local c = p.Character or p.CharacterAdded:Wait(); local rp = c:FindFirstChild("HumanoidRootPart")
        if rp then
            local cam = workspace.CurrentCamera; local md = Vector3.zero
            local UIS = game:GetService("UserInputService")
            if UIS:IsKeyDown(Enum.KeyCode.W) then md = md + cam.CFrame.LookVector end
            if UIS:IsKeyDown(Enum.KeyCode.S) then md = md - cam.CFrame.LookVector end
            if UIS:IsKeyDown(Enum.KeyCode.A) then md = md - cam.CFrame.RightVector end
            if UIS:IsKeyDown(Enum.KeyCode.D) then md = md + cam.CFrame.RightVector end
            if UIS:IsKeyDown(Enum.KeyCode.Space) then md = md + Vector3.new(0,1,0) end
            if UIS:IsKeyDown(Enum.KeyCode.LeftControl) then md = md - Vector3.new(0,1,0) end
            rp.CFrame = rp.CFrame + (md * 50 * game:GetService("RunService").RenderStepped:Wait())
        end
    end)
end

local function applyFly()
    stopAllFly(); if not FlySettings.On then return end
    if FlySettings.Method == "Ragdoll" then enRagFly() else enOldFly() end
end

game.Players.LocalPlayer.CharacterAdded:Connect(function(c)
    if not FlySettings.On then return end; task.wait(0.5); c:WaitForChild("HumanoidRootPart"); task.wait(0.1)
    if FlySettings.On then applyFly() end
end)

local function Fly_Enable()
    if FlySettings.On then return end
    FlySettings.On = true
    if game.Players.LocalPlayer.Character then applyFly() end
end

local function Fly_Disable()
    if not FlySettings.On then return end
    FlySettings.On = false
    stopAllFly()
end

--============================ FullBright ============================--

local FullBright_Enabled = false
local Lighting = game:GetService("Lighting")

local OriginalValues = {
    ClockTime = Lighting.ClockTime,
    Brightness = Lighting.Brightness,
    Ambient = Lighting.Ambient,
    OutdoorAmbient = Lighting.OutdoorAmbient,
    ColorShift_Top = Lighting.ColorShift_Top,
    FogStart = Lighting.FogStart,
    FogEnd = Lighting.FogEnd,
}

local FullBright_Connection = nil

local function FullBright_Enable()
    if FullBright_Enabled then return end
    FullBright_Enabled = true
    
    Lighting.Brightness = 5
    Lighting.ClockTime = 14
    Lighting.Ambient = Color3.new(1, 1, 1)
    Lighting.OutdoorAmbient = Color3.new(1, 1, 1)
    Lighting.ColorShift_Top = Color3.new(0, 0, 0)
    Lighting.FogStart = 100000
    Lighting.FogEnd = 100000

    FullBright_Connection = RunService.RenderStepped:Connect(function()
        if not FullBright_Enabled then
            FullBright_Connection:Disconnect()
            return
        end
        if Lighting.Brightness ~= 5 then Lighting.Brightness = 5 end
        if Lighting.ClockTime ~= 14 then Lighting.ClockTime = 14 end
        if Lighting.Ambient ~= Color3.new(1, 1, 1) then Lighting.Ambient = Color3.new(1, 1, 1) end
        if Lighting.OutdoorAmbient ~= Color3.new(1, 1, 1) then Lighting.OutdoorAmbient = Color3.new(1, 1, 1) end
        if Lighting.ColorShift_Top ~= Color3.new(0, 0, 0) then Lighting.ColorShift_Top = Color3.new(0, 0, 0) end
        if Lighting.FogStart ~= 100000 then Lighting.FogStart = 100000 end
        if Lighting.FogEnd ~= 100000 then Lighting.FogEnd = 100000 end
    end)
end

local function FullBright_Disable()
    if not FullBright_Enabled then return end
    FullBright_Enabled = false
    
    if FullBright_Connection then
        FullBright_Connection:Disconnect()
        FullBright_Connection = nil
    end
    
    Lighting.Brightness = OriginalValues.Brightness
    Lighting.ClockTime = OriginalValues.ClockTime
    Lighting.Ambient = OriginalValues.Ambient
    Lighting.OutdoorAmbient = OriginalValues.OutdoorAmbient
    Lighting.ColorShift_Top = OriginalValues.ColorShift_Top
    Lighting.FogStart = OriginalValues.FogStart
    Lighting.FogEnd = OriginalValues.FogEnd
end

--============================ Camera FOV ============================--

local Fov_Enabled = false
local Fov_Value = 80
local Camera = game.Workspace.Camera
local Original_Fov = Camera.FieldOfView

local function Fov_Enable()
    Fov_Enabled = true
end

local function Fov_Disable()
    Fov_Enabled = false
    Camera.FieldOfView = Original_Fov
end

game:GetService("RunService").RenderStepped:Connect(function()
    if Fov_Enabled then
        Camera.FieldOfView = Fov_Value
    end
end)

--============================ Noclip ============================--

local Noclip_Connection = nil
local Noclip_Enabled = false
local originalCollisions = {}

local function Noclip_Enable()
    if Noclip_Enabled then return end

    Noclip_Enabled = true

    local char = LocalPlayer.Character
    if char then
        for _, part in pairs(char:GetDescendants()) do
            if part:IsA("BasePart") then
                if part.CanCollide then
                    originalCollisions[part] = true
                    part.CanCollide = false
                end
            end
        end
    end

    if not Noclip_Connection then
        Noclip_Connection = RunService.RenderStepped:Connect(function()
            if not Noclip_Enabled then return end
            
            local char = LocalPlayer.Character
            if char then
                for _, part in pairs(char:GetDescendants()) do
                    if part:IsA("BasePart") then
                        part.CanCollide = false
                    end
                end
            end
        end)
    end
end

local function Noclip_Disable()
    if not Noclip_Enabled then return end

    Noclip_Enabled = false

    if Noclip_Connection then
        Noclip_Connection:Disconnect()
        Noclip_Connection = nil
    end

    local char = LocalPlayer.Character
    if char then
        for _, part in pairs(char:GetDescendants()) do
            if part:IsA("BasePart") then
                if originalCollisions[part] then
                    part.CanCollide = true
                end
            end
        end
    end

    originalCollisions = {}
end

--========================== Admin Check ========================--

local AdminCheck_Enabled = false
local AdminCheck_Connection = nil

local staffPlayers = {
    groups = {
        [4165692] = {
            ["Tester"] = true, ["Contributor"] = true, ["Tester+"] = true, ["Developer"] = true,
            ["Developer+"] = true, ["Community Manager"] = true, ["Manager"] = true, ["Owner"] = true
        },
        [32406137] = {
            ["Junior"] = true, ["Moderator"] = true, ["Senior"] = true, ["Administrator"] = true,
            ["Manager"] = true, ["Holder"] = true
        },
        [8024440] = {
            ["zzzz"] = true, ["reshape enjoyer"] = true, ["i heart reshape"] = true, ["reshape superfan"] = true
        },
        [14927228] = {
            ["♞"] = true
        }
    },
    users = {
         3294804378, 93676120, 54087314, 81275825, 140837601, 1229486091, 46567801, 418086275, 29706395,
         3717066084, 1424338327, 5046662686, 5046661126, 5046659439, 418199326, 1024216621, 1810535041,
         63238912, 111250044, 63315426, 730176906, 141193516, 194512073, 193945439, 412741116, 195538733,
         102045519, 955294, 957835150, 25689921, 366613818, 281593651, 455275714, 208929505, 96783330,
         156152502, 93281166, 959606619, 142821118, 632886139, 175931803, 122209625, 278097946, 142989311,
         1517131734, 446849296, 87189764, 67180844, 9212846, 47352513, 48058122, 155413858, 10497435,
         513615792, 55893752, 55476024, 151691292, 136584758, 16983447, 3111449, 94693025, 271400893,
         5005262660, 295331237, 64489098, 244844600, 114332275, 25048901, 69262878, 50801509, 92504899,
         42066711, 50585425, 31365111, 166406495, 2457253857, 29761878, 21831137, 948293345, 439942262,
         38578487, 1163048, 7713309208, 3659305297, 15598614, 34616594, 626833004, 198610386, 153835477,
         3923114296, 3937697838, 102146039, 119861460, 371665775, 1206543842, 93428604, 1863173316, 90814576,
         374665997, 423005063, 140172831, 42662179, 9066859, 438805620, 14855669, 727189337, 1871290386,
         608073286
    }
}

local function hasTracker(player)
    if not player or not player:IsA("Player") then return false, nil end
    local children = player:GetChildren()
    for i = 1, #children do
        local child = children[i]
        if typeof(child.Name) == "string" and string.sub(child.Name, -8) == "Tracker$" then
            local trackedPlayerName = string.sub(child.Name, 1, -9)
             if Players:FindFirstChild(trackedPlayerName) then
                return true, trackedPlayerName
            end
        end
    end
    return false, nil
end

local function isStaff(player)
    if not player or not player:IsA("Player") then return false end

    if staffPlayers.groups then
        for groupID, roles in pairs(staffPlayers.groups) do
            local successRank, rank = pcall(function() return player:GetRankInGroup(groupID) end)
            if successRank and rank and rank > 0 then
                local successRole, roleName = pcall(function() return player:GetRoleInGroup(groupID) end)
                if successRole and roleName and roles[roleName] then
                    return true, roleName, groupID
                end
            end
        end
    end

    if staffPlayers.users then
        for i = 1, #staffPlayers.users do
            if player.UserId == staffPlayers.users[i] then
                return true, "UserID", player.UserId
            end
        end
    end

    return false
end

local function kickformat(staffInfo)
    if not staffInfo or not staffInfo.Staff then return "Staff detected." end
    local message = "Staff detected:\n"
    for i, staff in ipairs(staffInfo.Staff) do
        local idType = "Role"
        local idValue = staff.Role or "Unknown"
        if staff.Role == "UserID" then
            idType = "UserID"
            idValue = staff.GroupId or "Unknown"
        elseif staff.Role == "Tracker User" then
             idType = "Tracker"
             idValue = "Active"
        end

        message = message .. string.format(
            "- %s (%s: %s)%s",
            staff.Name or "Unknown",
            idType,
            idValue,
            staff.TrackedPlayer and " - Tracking: " .. staff.TrackedPlayer or ""
        )
        if i < #staffInfo.Staff then
            message = message .. "\n"
        end
    end
    return message
end

local function kickWithStaffInfo(staffInfo)
    local kickMsg = kickformat(staffInfo)
    if LocalPlayer then
        LocalPlayer:Kick("Staff joined\n\n" .. kickMsg)
    end
end

local function checkCurrentStaff()
    local staffFound = {}
    local currentPlayers = Players:GetPlayers()
    for i = 1, #currentPlayers do
        local player = currentPlayers[i]
        if player ~= LocalPlayer then
            local isPlayerStaff, role, groupID = isStaff(player)
            local hasTrackers, trackedPlayer = hasTracker(player)

            if isPlayerStaff or hasTrackers then
                table.insert(staffFound, {
                    Name = player.Name,
                    Role = hasTrackers and "Tracker User" or role,
                    GroupId = groupID,
                    TrackedPlayer = trackedPlayer
                })
            end
        end
    end

    if #staffFound > 0 then
        kickWithStaffInfo({Staff = staffFound})
        return true
    end
    return false
end

local function onPlayerJoining(player)
     if not AdminCheck_Enabled then return end

     local isPlayerStaff, role, groupID = isStaff(player)
     local hasTrackers, trackedPlayer = hasTracker(player)

     if isPlayerStaff or hasTrackers then
         local staffInfo = {
             Staff = {{
                 Name = player.Name,
                 Role = hasTrackers and "Tracker User" or role,
                 GroupId = groupID,
                 TrackedPlayer = trackedPlayer
             }}
         }
         kickWithStaffInfo(staffInfo)
     end
end

local function AdminCheck_Enable()
    if AdminCheck_Enabled then return end
    AdminCheck_Enabled = true

    print("Admin Check Enabling...")

    if AdminCheck_Connection then AdminCheck_Connection:Disconnect() end

    AdminCheck_Connection = Players.PlayerAdded:Connect(onPlayerJoining)
    print("Admin Check Monitoring started.")

    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = "Staff Detection", Text = "Monitoring active", Duration = 5,
            Icon = "rbxassetid://121588751997553"
        })
    end)

    task.spawn(function()
        print("Admin Check: Running initial check on current players...")
        local foundStaff = checkCurrentStaff()

        if foundStaff then
            AdminCheck_Enabled = false
            warn("Admin Check: Staff found by background check. Kicked.")
            if AdminCheck_Connection then
                 AdminCheck_Connection:Disconnect()
                 AdminCheck_Connection = nil
            end
        else
             print("Admin Check: Initial background check complete, no staff found.")
        end
    end)
end

local function AdminCheck_Disable()
    if not AdminCheck_Enabled then return end
    AdminCheck_Enabled = false

    if AdminCheck_Connection then
        AdminCheck_Connection:Disconnect()
        AdminCheck_Connection = nil
    end
    print("Admin Check Disabled.")
end

--=================== Melee Aura =====================--

local MeleeAura_Enabled = false
local MeleeAura_Connection

local runAttackLoop do
    local plrs = game:GetService("Players")
    local me = plrs.LocalPlayer
    local run = game:GetService("RunService")
    local replicatedStorage = game:GetService("ReplicatedStorage")
    local eventsFolder = replicatedStorage:WaitForChild("Events")

    local remoteFunctionPath = "XMHH.2"
    local remoteEventPath = "XMHH2.2"

    local remote1 = eventsFolder:WaitForChild(remoteFunctionPath)
    local remote2 = eventsFolder:WaitForChild(remoteEventPath)

    local maxdist = 5

    local function Attack(target)
        if not (target and target:FindFirstChild("Head")) then return end

        local char = me.Character
        local tool = char and char:FindFirstChildOfClass("Tool")
        local hrp = char and char:FindFirstChild("HumanoidRootPart")

        if not remote1 or not remote1:IsA("RemoteFunction") then
            warn("MeleeAura Error: Cannot find required RemoteFunction")
            MeleeAura_Disable()
            return
        end
        if not remote2 or not remote2:IsA("RemoteEvent") then
            warn("MeleeAura Error: Cannot find required RemoteEvent")
            MeleeAura_Disable()
            return
        end

        local arg1 = {
            [1] = "🍞",
            [2] = tick(),
            [3] = tool,
            [4] = "43TRFWX",
            [5] = "Normal",
            [6] = tick(),
            [7] = true
        }
        local success1, result = pcall(function()
            return remote1:InvokeServer(unpack(arg1))
        end)

        if not success1 then
            warn("MeleeAura Error: InvokeServer failed:", result)
            return
        end

        task.wait(0.1)

        local Handle = tool and (tool:FindFirstChild("WeaponHandle") or tool:FindFirstChild("Handle")) or (char and char:FindFirstChild("Right Arm"))
        local head = target:FindFirstChild("Head")

        if Handle and head and hrp then
            local arg2 = {
                [1] = "🍞",
                [2] = tick(),
                [3] = tool,
                [4] = "2389ZFX34",
                [5] = result,
                [6] = false,
                [7] = Handle,
                [8] = head,
                [9] = target,
                [10] = hrp.Position,
                [11] = head.Position
            }
            local success2, errorMsg2 = pcall(function()
                remote2:FireServer(unpack(arg2))
            end)
            if not success2 then
                warn("MeleeAura Error: FireServer failed:", errorMsg2)
            end
        end
    end

    runAttackLoop = function()
        return run.RenderStepped:Connect(function()
            if not MeleeAura_Enabled then return end
            local char = me.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            if hrp then
                for _, plr in ipairs(plrs:GetPlayers()) do
                    if plr ~= me then
                        local c = plr.Character
                        local hrp2 = c and c:FindFirstChild("HumanoidRootPart")
                        local hum = c and c:FindFirstChildOfClass("Humanoid")
                        if hrp2 and hum then
                            local dist = (hrp.Position - hrp2.Position).Magnitude
                            if dist < maxdist and hum.Health > 15 and not c:FindFirstChildOfClass("ForceField") then
                                Attack(c)
                            end
                        end
                    end
                end
            end
        end)
    end
end

local function MeleeAura_Enable()
    if MeleeAura_Enabled then return end
    MeleeAura_Enabled = true
    if MeleeAura_Connection and MeleeAura_Connection.Connected then
        MeleeAura_Connection:Disconnect()
    end
    MeleeAura_Connection = runAttackLoop()
end

local function MeleeAura_Disable()
    if not MeleeAura_Enabled then return end
    MeleeAura_Enabled = false
    if MeleeAura_Connection and MeleeAura_Connection.Connected then
        MeleeAura_Connection:Disconnect()
        MeleeAura_Connection = nil
    end
end

--======================= RAGEBOT =======================--

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local EventsFolder = ReplicatedStorage:WaitForChild("Events", 10)

local GNX_S_Remote = EventsFolder and EventsFolder:WaitForChild("GNX_S", 5)
local ZFKLF_H_Remote = EventsFolder and EventsFolder:WaitForChild("ZFKLF__H", 5)

local function RandomString(length)
    local res = ""
    for i = 1, length do
        res = res .. string.char(math.random(97, 122))
    end
    return res
end

local function GetClosestEnemy_Rage()
    local closestEnemy = nil
    local shortestDistance = 200

    local myChar = LocalPlayer.Character
    local myHRP = myChar and myChar:FindFirstChild("HumanoidRootPart")
    if not myHRP then return nil end

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            local enemyChar = player.Character
            local enemyHRP = enemyChar and enemyChar:FindFirstChild("HumanoidRootPart")
            local enemyHum = enemyChar and enemyChar:FindFirstChildOfClass("Humanoid")

            if enemyHRP and enemyHum and enemyHum.Health > 15 and not enemyChar:FindFirstChildOfClass("ForceField") then
                local distance = (myHRP.Position - enemyHRP.Position).Magnitude
                if distance < shortestDistance then
                    shortestDistance = distance
                    closestEnemy = player
                end
            end
        end
    end
    return closestEnemy
end

local function Shoot_Rage(targetPlayer)
    if not targetPlayer or not targetPlayer.Character then return end

    local targetPart = targetPlayer.Character:FindFirstChild("Head") or targetPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not targetPart then return end

    local myChar = LocalPlayer.Character
    local tool = myChar and myChar:FindFirstChildOfClass("Tool")
    if not tool then return end

    local currentCam = workspace.CurrentCamera
    local hitPosition = targetPart.Position
    local hitDirection = (hitPosition - currentCam.CFrame.Position).Unit
    local randomKey = RandomString(30) .. "0"

    if not GNX_S_Remote or not ZFKLF_H_Remote then
        warn("Ragebot Error: Required remote events not found.")
        if typeof(Ragebot_Disable) == "function" then
            Ragebot_Disable()
        end
        return
    end

    local success1, err1 = pcall(function()
        GNX_S_Remote:FireServer(
            tick(),
            randomKey,
            tool,
            "FDS9I83",
            currentCam.CFrame.Position,
            {hitDirection},
            false
        )
    end)
    if not success1 then warn("Ragebot: FireServer GNX_S failed:", err1) end

    local success2, err2 = pcall(function()
        ZFKLF_H_Remote:FireServer(
            "🧈",
            tool,
            randomKey,
            1,
            targetPart,
            hitPosition,
            hitDirection,
            nil,
            nil
        )
    end)
    if not success2 then warn("Ragebot: FireServer ZFKLF__H failed:", err2) end
end

local Ragebot_Enabled = false
local Ragebot_Coroutine = nil
local Ragebot_Target = nil

local function RagebotLoop()
    while Ragebot_Enabled do
        local target = GetClosestEnemy_Rage()
        Ragebot_Target = target
        if target then
            Shoot_Rage(target)
            task.wait(0.05)
        else
            task.wait(0.1)
        end
    end
    Ragebot_Target = nil
    Ragebot_Coroutine = nil
end

local function Ragebot_Enable()
    if not GNX_S_Remote or not ZFKLF_H_Remote then
         warn("Ragebot cannot enable: Required remote events not found.")
         pcall(function() game:GetService("StarterGui"):SetCore("SendNotification", { Title = "Ragebot Error", Text = "Required remotes missing.", Duration = 5}) end)
         return
    end
    if Ragebot_Enabled then return end
    Ragebot_Enabled = true
    if not Ragebot_Coroutine then
        Ragebot_Coroutine = coroutine.create(RagebotLoop)
        coroutine.resume(Ragebot_Coroutine)
    end
end

local function Ragebot_Disable()
    if not Ragebot_Enabled then return end
    Ragebot_Enabled = false
end

--============================ Autofarm & Main ============================--

local services = {
    ws = game:GetService("Workspace"),
    pl = game:GetService("Players"),
    rs_rep = game:GetService("ReplicatedStorage"),
    rs = game:GetService("RunService"),
    uis = game:GetService("UserInputService")
}

local localPlayer = services.pl.LocalPlayer
local task = task
local wait = task.wait

local autofarmEnabled = false
local autofarmCooldown = false
local ignoredSafes = {}

local pingThreshold = 180
local isPingHigh = false

local CoolDowns = { AutoPickUps = { MoneyCooldown = false } }
local Settings = { IsDead = false }

local function getPing()
    local ping = localPlayer:GetNetworkPing()
    return ping * 1000
end

task.spawn(function()
    while task.wait(5) do
        local ping = getPing()
        if ping > pingThreshold then
            isPingHigh = true
        else
            isPingHigh = false
        end
    end
end)

--======================= SHADOW MODE =========================--

local Shadow_Active = false
local Shadow_Usable = true

do
    repeat task.wait() until game:IsLoaded();

    local svc_ref = cloneref or function(...) return ... end;

    local GS = setmetatable({}, {
        __index = function(_, k)
            return svc_ref(game:GetService(k));
        end
    });

    local P = GS.Players.LocalPlayer;
    local Char = P.Character or P.CharacterAdded:Wait();
    local HMND
    local HRP

    local function RefreshCharRefs()
        Char = P.Character
        if Char then
            HRP = Char:FindFirstChild("HumanoidRootPart")
            HMND = Char:FindFirstChildOfClass("Humanoid")
        else
            HRP = nil
            HMND = nil
        end
    end

    RefreshCharRefs()

    local AnimTrack_Cache = nil
    local CamoAnim = Instance.new("Animation", nil);
    CamoAnim.AnimationId = "rbxassetid://215384594";

    local RS = GS.RunService;
    local UpdateFrame = RS.Heartbeat;
    local WaitRender = RS.RenderStepped;

    local CoreGS = GS.CoreGui;
    local StartGS = GS.StarterGui;

    local HUD = Instance.new("ScreenGui");
    HUD.Name = "ShadowWarningHUD";
    HUD.Parent = CoreGS;
    HUD.ResetOnSpawn = false;
    HUD.ZIndexBehavior = Enum.ZIndexBehavior.Sibling;

    local WarningText = Instance.new("TextLabel", HUD);
    WarningText.Text = "⚠️You are visible⚠️";
    WarningText.Visible = false;
    WarningText.Size = UDim2.new(0, 200, 0, 30);
    WarningText.Position = UDim2.new(0.5, -100, 0.85, 0);
    WarningText.BackgroundTransparency = 1;
    WarningText.Font = Enum.Font.GothamSemibold;
    WarningText.TextSize = 24;
    WarningText.TextColor3 = Color3.fromRGB(255, 255, 0);
    WarningText.TextStrokeTransparency = 0.5;
    WarningText.ZIndex = 10;

    if Char and not Char:FindFirstChild("Torso") then
        pcall(function()
            StartGS:SetCore("SendNotification", {
                Title = "Shadow Mode FAILED",
                Text = "Feature requires R6 Avatar.",
                Duration = 5,
            });
        end)
        Shadow_Usable = false
    end

    local function CheckGrounded()
        return HMND and HMND:IsDescendantOf(workspace) and HMND.FloorMaterial ~= Enum.Material.Air;
    end

    local function CacheAnimTrack()
        if AnimTrack_Cache then
            pcall(function() AnimTrack_Cache:Stop() end)
            AnimTrack_Cache = nil
        end
        if HMND then
            local success, result = pcall(function()
                return HMND:LoadAnimation(CamoAnim)
            end)
            if success then
                AnimTrack_Cache = result
                AnimTrack_Cache.Priority = Enum.AnimationPriority.Action4;
            else
                AnimTrack_Cache = nil
            end
        else
            AnimTrack_Cache = nil
        end
    end

    local function DeactivateShadow()
        if not Shadow_Active then return end
        Shadow_Active = false;

        if AnimTrack_Cache then
            pcall(function() AnimTrack_Cache:Stop() end)
        end

        if HMND then
            workspace.CurrentCamera.CameraSubject = HMND;
        end

        if Char then
            for _, v in pairs(Char:GetDescendants()) do
                if v:IsA("BasePart") and v.Transparency == 0.5 then
                    v.Transparency = 0;
                end
            end
        end
        
        WarningText.Visible = false;
    end

    local function ActivateShadow()
        if Shadow_Active or not Shadow_Usable then return end

        RefreshCharRefs()
        if not Char or not HMND or not HRP then return end
        if not Char:FindFirstChild("Torso") then
            pcall(function() StartGS:SetCore("SendNotification", {Title = "Shadow Mode FAILED", Text = "Feature requires R6 Avatar.", Duration = 5}) end)
            return
        end

        Shadow_Active = true;
        workspace.CurrentCamera.CameraSubject = HRP;

        CacheAnimTrack()
    end

    local function ShadowStep(deltaTime)
        if not Char or not HMND or not HRP or not HMND:IsDescendantOf(workspace) or HMND.Health <= 0 then
            WarningText.Visible = false;
            return
        end

        WarningText.Visible = not CheckGrounded();

        local walk_speed = 12
        if HMND.MoveDirection.Magnitude > 0 then
            local velocity_offset = HMND.MoveDirection * walk_speed * deltaTime
            HRP.CFrame = HRP.CFrame + velocity_offset
        end

        local InitialCFrame = HRP.CFrame;
        local InitialCamOffset = HMND.CameraOffset;

        local _, yaw_angle = workspace.CurrentCamera.CFrame:ToOrientation();
        HRP.CFrame = CFrame.new(HRP.CFrame.Position) * CFrame.fromOrientation(0, yaw_angle, 0);
        HRP.CFrame = HRP.CFrame * CFrame.Angles(math.rad(90), 0, 0);
        HMND.CameraOffset = Vector3.new(0, 1.44, 0);

        if AnimTrack_Cache then
            local successPlay = pcall(function()
                if not AnimTrack_Cache.IsPlaying then
                    AnimTrack_Cache:Play();
                end
                AnimTrack_Cache:AdjustSpeed(0);
                AnimTrack_Cache.TimePosition = 0.3;
            end)
            if not successPlay then
                CacheAnimTrack()
            end
        elseif HMND and HMND.Health > 0 then
            CacheAnimTrack()
        end

        WaitRender:Wait();

        if HMND and HMND:IsDescendantOf(workspace) then
            HMND.CameraOffset = InitialCamOffset;
        end
        if HRP and HRP:IsDescendantOf(workspace) then
            HRP.CFrame = InitialCFrame;
        end

        if AnimTrack_Cache then
            pcall(function() AnimTrack_Cache:Stop() end)
        end

        if HRP and HRP:IsDescendantOf(workspace) then
            local LookVec = workspace.CurrentCamera.CFrame.LookVector;
            local FlatLook = Vector3.new(LookVec.X, 0, LookVec.Z).Unit;
            if FlatLook.Magnitude > 0.1 then
                local FinalCFrame = CFrame.new(HRP.Position, HRP.Position + FlatLook);
                HRP.CFrame = FinalCFrame;
            end
        end

        if Char then
            for _, v in pairs(Char:GetDescendants()) do
                if (v:IsA("BasePart") and v.Transparency ~= 1) then
                    v.Transparency = 0.5;
                end
            end
        end
    end

    UpdateFrame:Connect(function(deltaTime)
        if not Shadow_Active or not Shadow_Usable then
            if not Shadow_Active and Char then
                for _, v in pairs(Char:GetDescendants()) do
                    if v:IsA("BasePart") and v.Transparency == 0.5 then v.Transparency = 0 end
                end
            end
            WarningText.Visible = false
            return;
        end
        
        ShadowStep(deltaTime)
    end)

    P.CharacterAdded:Connect(function(NewCharacter)
        if Shadow_Active then DeactivateShadow() end

        if AnimTrack_Cache then
            pcall(function() AnimTrack_Cache:Stop() end)
            AnimTrack_Cache = nil
        end

        task.wait()

        RefreshCharRefs()

        if not HMND then
            task.wait(0.5)
            RefreshCharRefs()
            if not HMND then
                Shadow_Usable = false
                if Shadow_Active then DeactivateShadow() end
                pcall(function() StartGS:SetCore("SendNotification", {Title = "Shadow Mode Error", Text = "Could not verify character type.", Duration = 5}) end)
                return
            end
        end

        if HMND.RigType ~= Enum.HumanoidRigType.R6 then
            Shadow_Usable = false
            if Shadow_Active then DeactivateShadow() end
            pcall(function() StartGS:SetCore("SendNotification", {Title = "Shadow Mode Warning", Text = "Non-R6 Avatar detected. Disabled.", Duration = 5}) end)
            return
        else
            Shadow_Usable = true
        end
        
        if autofarmEnabled and Shadow_Usable then
            ActivateShadow()
        end
    end)

    P.CharacterRemoving:Connect(function(OldCharacter)
        if AnimTrack_Cache then
            pcall(function() AnimTrack_Cache:Stop() end)
            AnimTrack_Cache = nil
        end
        WarningText.Visible = false
    end)

    _G.ActivateShadow = ActivateShadow
    _G.DeactivateShadow = DeactivateShadow
    _G.IsShadowActive = function() return Shadow_Active end

end

--======================= BREAD COLLECTOR =========================--

local Collector_Enabled = false
local Collector_Signal = nil
local Collector_Task = nil

local function Collector_CoreLogic()
    local RS_S = game:GetService("RunService")
    local RS_Rep = game:GetService("ReplicatedStorage")
    local WS = game:GetService("Workspace")

    local function RunCollectorLogic()
        if not Collector_Enabled or Settings.IsDead then return end

        local breadContainer = WS.Filter:FindFirstChild("SpawnedBread")
        local pickupRemote = RS_Rep.Events:FindFirstChild("CZDPZUS")

        if not breadContainer then return end
        if not pickupRemote then return end

        local p_char = localPlayer.Character
        local root_part = p_char and p_char:FindFirstChild("HumanoidRootPart")

        if not root_part or CoolDowns.AutoPickUps.MoneyCooldown then return end

        local current_pos = root_part.Position
        for _, item in ipairs(breadContainer:GetChildren()) do
            local dist_sq = (current_pos - item.Position).Magnitude^2
            if dist_sq < 25 and not CoolDowns.AutoPickUps.MoneyCooldown then
                CoolDowns.AutoPickUps.MoneyCooldown = true
                
                pcall(function()
                    pickupRemote:FireServer(item)
                end)
                
                task.wait(1.1)
                
                CoolDowns.AutoPickUps.MoneyCooldown = false
                break
            end
        end
    end

    Collector_Signal = RS_S.RenderStepped:Connect(RunCollectorLogic)
end

local function Collector_Activate()
    if Collector_Enabled then return end
    Collector_Enabled = true

    if Collector_Signal then
        Collector_Signal:Disconnect()
        Collector_Signal = nil
    end
    if Collector_Task then
        coroutine.close(Collector_Task)
        Collector_Task = nil
    end

    Collector_CoreLogic()
end

local function Collector_Deactivate()
    if not Collector_Enabled then return end
    Collector_Enabled = false

    if Collector_Signal then
        Collector_Signal:Disconnect()
        Collector_Signal = nil
    end

    if CoolDowns and CoolDowns.AutoPickUps then
        CoolDowns.AutoPickUps.MoneyCooldown = false
    end
end

local function Autofarm_Enable()
    if autofarmEnabled then return end
    autofarmEnabled = true
    
    _G.ActivateShadow()
    Collector_Activate()
end

local function Autofarm_Disable()
    if not autofarmEnabled then return end
    autofarmEnabled = false
    
    _G.DeactivateShadow()
    Collector_Deactivate()
end

task.spawn(function()
    local deathRespawnEvent = services.rs_rep:WaitForChild("Events"):WaitForChild("DeathRespawn")
    while task.wait() do
        local char = localPlayer.Character
        if char then
            local humanoid = char:FindFirstChildOfClass("Humanoid")
            if humanoid and humanoid.Health <= 0 and autofarmEnabled then
                deathRespawnEvent:InvokeServer("KMG4R904")
                task.wait(2)
            end
        end
    end
end)

localPlayer.CharacterAdded:Connect(function(character)
    if not autofarmEnabled then return end

    character:WaitForChild("HumanoidRootPart", 5)
    task.wait(1.5)

    autofarmCooldown = false
    ignoredSafes = {}
    
    Autofarm_Enable()
end)

-- =================================================================================
-- --- Funcția de teleportare ---
-- =================================================================================

local function teleportTo(targetPart)
    local char = localPlayer.Character or localPlayer.CharacterAdded:Wait()
    local hrp = char:WaitForChild("HumanoidRootPart", 10)
    if not hrp then return false end

    if not (targetPart and targetPart:IsA("BasePart")) then return false end

    local success = false
    local attempts = 0
    while not success and attempts < 4 do
        local targetCframe = targetPart.CFrame
        local targetPos = (targetCframe + targetCframe.LookVector * 2).Position

        hrp.CFrame = CFrame.new(targetPos) * CFrame.Angles(0, math.pi / 2, 0)
        wait(0.5)

        local isStable = true
        local stabilityChecks = 10
        local checkInterval = 0.2

        for i = 1, stabilityChecks do
            wait(checkInterval)
            if not hrp or not hrp.Parent then
                isStable = false
                break
            end
            
            local currentDistance = (hrp.Position - targetPos).Magnitude
            if currentDistance > 5 then
                isStable = false
                break
            end
        end

        if isStable then
            success = true
        else
            attempts = attempts + 1
            wait(1)
        end
    end

    return success
end

-- =================================================================================
-- --- Funcții pentru autofarm ---
-- =================================================================================

local function hasTool(toolName)
    local backpackTool = localPlayer.Backpack:FindFirstChild(toolName)
    local characterTool = localPlayer.Character and localPlayer.Character:FindFirstChild(toolName)
    return backpackTool or characterTool
end

local function findNearestTarget(targetsToIgnore)
    local bredMakurzFolder = services.ws.Map:FindFirstChild("BredMakurz") or services.ws.Filter:FindFirstChild("BredMakurz")
    local char = localPlayer.Character

    if not bredMakurzFolder then return nil end
    if not char then return nil end

    local nearestTarget = nil
    local shortestDistance = math.huge
    local playerPosition = char:FindFirstChild("HumanoidRootPart").Position

    for _, v in ipairs(bredMakurzFolder:GetChildren()) do
        if (string.find(v.Name, "Safe") or string.find(v.Name, "Register")) and not table.find(targetsToIgnore, v) then
            local values = v:FindFirstChild("Values")
            if values then
                local broken = values:FindFirstChild("Broken")
                if broken and broken:IsA("BoolValue") and not broken.Value then
                    local targetPart = v.PrimaryPart or v:FindFirstChild("MainPart") or v:FindFirstChild("PosPart")
                    if targetPart then
                        local distance = (targetPart.Position - playerPosition).Magnitude
                        if distance < shortestDistance then
                            shortestDistance = distance
                            nearestTarget = v
                        end
                    end
                end
            end
        end
    end
    return nearestTarget
end

local function findNearestDealer()
    local shopz = services.ws.Map:FindFirstChild("Shopz") or services.ws.Filter:FindFirstChild("Shopz")
    local char = localPlayer.Character

    if not shopz or not char then return nil end

    local nearestDealer = nil
    local shortestDistance = math.huge
    local playerPosition = char:FindFirstChild("HumanoidRootPart").Position

    for _, dealer in ipairs(shopz:GetChildren()) do
        local crowbarStock = dealer:FindFirstChild("CurrentStocks") and dealer.CurrentStocks:FindFirstChild("Crowbar")
        if crowbarStock and crowbarStock.Value > 0 and dealer:FindFirstChild("MainPart") then
            local distance = (dealer.MainPart.Position - playerPosition).Magnitude
            if distance < shortestDistance then
                shortestDistance = distance
                nearestDealer = dealer
            end
        end
    end
    return nearestDealer
end

-- =================================================================================
-- --- Funcția openSafe cu micro-pas la spargere ---
-- =================================================================================
local function openSafe(safeModel)
    local equippedCrowbar = hasTool("Crowbar")
    if not equippedCrowbar then return end
    
    local remoteXMHH = services.rs_rep:WaitForChild("Events"):WaitForChild("XMHH.2")
    local remoteXMHH2 = services.rs_rep:WaitForChild("Events"):WaitForChild("XMHH2.2")
    local safeMainPart = safeModel:WaitForChild("MainPart", 5)

    if not safeMainPart then return end

    local startTime = tick()
    local brokenValue = safeModel.Values and safeModel.Values:FindFirstChild("Broken")
    
    -- Salvăm starea inițială
    local wasBroken = brokenValue and brokenValue.Value or false
    
    -- Mic pas la început
    local char = localPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if hrp then
        hrp.CFrame = hrp.CFrame + hrp.CFrame.LookVector * 0.2
        task.wait(0.05)
    end
    
    -- Loop spargere
    while safeModel and safeModel.Parent and brokenValue and not brokenValue.Value and (tick() - startTime < 15) do
        local char = localPlayer.Character
        if not char then break end

        local safeOpenValue = remoteXMHH:InvokeServer("🍞", tick(), equippedCrowbar, "DZDRRRKI", safeModel, "Register")

        if safeOpenValue == nil then
            wait(1)
            continue
        end

        local currentTime = tick()
        remoteXMHH2:FireServer(
            "🍞", currentTime, equippedCrowbar, "2389ZFX34", safeOpenValue, false,
            char["Right Arm"], safeMainPart, safeModel, safeMainPart.Position, safeMainPart.Position
        )
        
        wait(0.2)
    end
    
    -- Verificăm dacă s-a spart
    local isNowBroken = brokenValue and brokenValue.Value or false
    
    -- 🔥 AICI SE FACE MIȘCAREA CONSTANTĂ PE 4 SECUNDE (W A S D)
    if isNowBroken and not wasBroken then
        task.wait(0.3)

        local char = localPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")

        if hrp then
            local moveEndTime = tick() + 4  -- Mișcarea se va opri după 4 secunde

            while tick() < moveEndTime do
                local direction = math.random(1, 4)

                if direction == 1 then
                    -- W (înainte)
                    hrp.CFrame = hrp.CFrame + hrp.CFrame.LookVector * 0.4
                elseif direction == 2 then
                    -- S (înapoi)
                    hrp.CFrame = hrp.CFrame - hrp.CFrame.LookVector * 0.3
                elseif direction == 3 then
                    -- A (stânga)
                    hrp.CFrame = hrp.CFrame - hrp.CFrame.RightVector * 0.3
                elseif direction == 4 then
                    -- D (dreapta)
                    hrp.CFrame = hrp.CFrame + hrp.CFrame.RightVector * 0.3
                end

                task.wait(0.15) -- mișcare constantă
            end
        end
    end
    
    wait(8)
end
-- =================================================================================
-- --- Funcție pentru o serie de micro-pași la spargerea seifului ---
-- =================================================================================

local function doMicroStep()
    if not autofarmEnabled then return end

    local char = localPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local direction = math.random(1, 4)
    local distance = 0.2 + math.random() * 0.2

    if direction == 1 then
        hrp.CFrame = hrp.CFrame + hrp.CFrame.LookVector * distance
    elseif direction == 2 then
        hrp.CFrame = hrp.CFrame - hrp.CFrame.LookVector * distance
    elseif direction == 3 then
        hrp.CFrame = hrp.CFrame - hrp.CFrame.RightVector * distance
    else
        hrp.CFrame = hrp.CFrame + hrp.CFrame.RightVector * distance
    end
end

local function onSafeBroken(safeModel)
    if not autofarmEnabled then return end
    
    -- Делаем СЕРИЮ из 5-8 микро-шагов с интервалом 0.5-1 секунда
    local steps = math.random(5, 8)
    
    for i = 1, steps do
        if not autofarmEnabled then break end
        
        doMicroStep()
        
        -- Ждем от 0.5 до 1.5 секунд между шагами
        local waitTime = 0.5 + math.random() * 1.0
        task.wait(waitTime)
        
        -- Каждый второй шаг делаем чуть больше
        if i % 2 == 0 then
            task.spawn(function()
                task.wait(0.2)
                if autofarmEnabled then
                    doMicroStep()
                end
            end)
        end
    end
    
    -- После серии шагов делаем еще пару шагов с большими интервалами
    task.spawn(function()
        task.wait(2)
        if autofarmEnabled then
            for i = 1, 3 do
                doMicroStep()
                task.wait(1)
            end
        end
    end)
end

-- =================================================================================
-- --- Detecție îmbunătățită a spargerii seifurilor cu mișcări suplimentare ---
-- =================================================================================

local safeBreakConnections = {}

local function setupSafeBreakDetection()
    local bredMakurzFolder = services.ws.Map:FindFirstChild("BredMakurz") or services.ws.Filter:FindFirstChild("BredMakurz")
    if not bredMakurzFolder then return end
    
    for _, v in ipairs(bredMakurzFolder:GetChildren()) do
        if (string.find(v.Name, "Safe") or string.find(v.Name, "Register")) then
            local values = v:FindFirstChild("Values")
            if values then
                local broken = values:FindFirstChild("Broken")
                if broken and broken:IsA("BoolValue") then
                    -- Удаляем старые соединения
                    local previousConnection = safeBreakConnections[broken]
                    if previousConnection then
                        previousConnection:Disconnect()
                    end
                    
                    -- Создаем новое соединение
                    local conn = broken:GetPropertyChangedSignal("Value"):Connect(function()
                        if broken.Value == true and autofarmEnabled then
                            -- Запускаем основную серию движений
                            onSafeBroken(v)
                            
                            -- Запускаем дополнительные движения в разных потоках
                            for j = 1, 3 do
                                task.spawn(function()
                                    task.wait(0.5 * j)
                                    if autofarmEnabled then
                                        doMicroStep()
                                        task.wait(0.3)
                                        doMicroStep()
                                    end
                                end)
                            end
                        end
                    end)
                    
                    -- Сохраняем соединение
                    safeBreakConnections[broken] = conn
                end
            end
        end
    end
end

-- Pornim detecția la fiecare 2 secunde
task.spawn(function()
    while task.wait(2) do
        if autofarmEnabled then
            setupSafeBreakDetection() -- verifică dacă trebuie oprită autofarma (siguranță)
        end
    end
end)

-- Micro-pași periodici la fiecare 1–3 secunde
task.spawn(function()
    while true do
        task.wait(1 + math.random() * 2) -- așteaptă între 1 și 3 secunde
        
        if autofarmEnabled then
            -- Facem 2–4 micro-pași consecutivi
            local stepCount = math.random(2, 4)
            for i = 1, stepCount do
                doMicroStep() -- execută un pas mic din autofarm
                task.wait(0.3 + math.random() * 0.5) -- pauză între 0.3 și 0.8 secunde
            end
        end
    end
end)

-- Task suplimentar pentru mișcări aleatorii
task.spawn(function()
    while true do
        task.wait(0.8 + math.random() * 1.5) -- așteaptă între 0.8 și 2.3 secunde
        
        if autofarmEnabled and math.random(1, 3) == 1 then -- 33% șansă
            -- Facem o mișcare neobișnuită (înainte+rotire sau dreapta+rotire)
            local char = localPlayer.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            
            if hrp then
                if math.random(1, 2) == 1 then
                    -- Mișcare înainte cu rotire
                    hrp.CFrame = hrp.CFrame + hrp.CFrame.LookVector * 0.35
                    task.wait(0.15)
                    hrp.CFrame = hrp.CFrame * CFrame.Angles(0, math.rad(math.random(-20, 20)), 0)
                else
                    -- Mișcare spre dreapta cu rotire
                    hrp.CFrame = hrp.CFrame + hrp.CFrame.RightVector * 0.35
                    task.wait(0.15)
                    hrp.CFrame = hrp.CFrame * CFrame.Angles(0, math.rad(math.random(-15, 15)), 0)
                end
            end
        end
    end
end)

-- =================================================================================
-- --- Logica principală a autofarmei ---
-- =================================================================================

local noTargetCounter = 0

task.spawn(function()
    while true do
        wait(1)
        local char = localPlayer.Character
        local humanoid = char and char:FindFirstChildOfClass("Humanoid")
        
        if humanoid then
            Settings.IsDead = humanoid.Health <= 0
        end
        
        if not autofarmEnabled or autofarmCooldown or not char or not humanoid or humanoid.Health <= 0 then
            continue
        end
        
        local crowbar = hasTool("Crowbar")
        if not crowbar then
            local dealer = findNearestDealer()
            if dealer then
                if teleportTo(dealer:WaitForChild("MainPart")) then
                    wait(1)
                    services.rs_rep.Events.BYZERSPROTEC:FireServer(true, "shop", dealer.MainPart, "IllegalStore")
                    wait(1)
                    local args = {"IllegalStore", "Melees", "Crowbar", dealer.MainPart, nil, true}
                    services.rs_rep.Events.SSHPRMTE1:InvokeServer(unpack(args))
                    wait(20)
                    services.rs_rep.Events.BYZERSPROTEC:FireServer(false)
                else
                    wait(5)
                end
            else
                wait(10)
            end
        else
            local target = findNearestTarget(ignoredSafes)
            if target then
                noTargetCounter = 0
                
                if teleportTo(target:WaitForChild("MainPart")) then
                    if localPlayer.Character:FindFirstChild("Crowbar") == nil then
                        local success, err = pcall(function()
                            localPlayer.Character.Humanoid:EquipTool(crowbar)
                        end)
                        if not success then
                            task.wait(1)
                            pcall(function() localPlayer.Character.Humanoid:EquipTool(crowbar) end)
                        end
                    end
                    
                    wait(1)
                    openSafe(target)
                else
                    table.insert(ignoredSafes, target)
                    wait(0.5)
                end
            else
                noTargetCounter = noTargetCounter + 1
                
                if noTargetCounter >= 4 then
                    ignoredSafes = {}
                    noTargetCounter = 0
                    wait(15)
                else
                    wait(5)
                end
            end
        end
    end
end)

--============================ Noclip ============================--

local Noclip_Connection = nil
local Noclip_Enabled = false
local originalCollisions = {}

local function Noclip_Enable()
    if Noclip_Enabled then return end

    Noclip_Enabled = true

    local char = LocalPlayer.Character
    if char then
        for _, part in pairs(char:GetDescendants()) do
            if part:IsA("BasePart") then
                if part.CanCollide then
                    originalCollisions[part] = true
                    part.CanCollide = false
                end
            end
        end
    end

    if not Noclip_Connection then
        Noclip_Connection = RunService.RenderStepped:Connect(function()
            if not Noclip_Enabled then return end
            
            local char = LocalPlayer.Character
            if char then
                for _, part in pairs(char:GetDescendants()) do
                    if part:IsA("BasePart") then
                        part.CanCollide = false
                    end
                end
            end
        end)
    end
end

local function Noclip_Disable()
    if not Noclip_Enabled then return end

    Noclip_Enabled = false

    if Noclip_Connection then
        Noclip_Connection:Disconnect()
        Noclip_Connection = nil
    end

    local char = LocalPlayer.Character
    if char then
        for _, part in pairs(char:GetDescendants()) do
            if part:IsA("BasePart") then
                if originalCollisions[part] then
                    part.CanCollide = true
                end
            end
        end
    end

    originalCollisions = {}
end

_G.Noclip_Enable = Noclip_Enable
_G.Noclip_Disable = Noclip_Disable
_G.IsNoclipActive = function() return Noclip_Enabled end

--======================= AIMBOT =========================--
if not getgenv().AimBotSettings then
    getgenv().AimBotSettings = {
        Enabled = false,
        ShowFOV = false,
        FOV = 100,
        Smoothing = 0.05,
        AimPart = "Head",
        
        WallCheck = false,
        DownedCheck = false
    }
end

-- 2. CREARE CERC FOV (Ca să nu dea eroare în buclă)
local FOVCircle = Drawing.new("Circle")
FOVCircle.Thickness = 0.5
FOVCircle.Color = Color3.fromRGB(130, 90, 255)
FOVCircle.Filled = false
FOVCircle.Transparency = 1
FOVCircle.Visible = false

-- 3. FUNCȚIA DE SCANARE (Găsește inamicul)
local function GetClosestTarget()
    local target = nil
    local mousePos = game:GetService("UserInputService"):GetMouseLocation()
    local cam = workspace.CurrentCamera
    local lp = game.Players.LocalPlayer
    local char = lp.Character
    
    local maxLimit = AimBotSettings.FOV or 100
    local bestScore = math.huge 

    local R6Parts = {"Head", "Torso", "HumanoidRootPart", "Left Arm", "Right Arm", "Left Leg", "Right Leg"}

    for _, p in pairs(game.Players:GetPlayers()) do
        if p ~= lp and p.Character and p.Character:FindFirstChild("Humanoid") and char and char:FindFirstChild("HumanoidRootPart") then
            if p.Character.Humanoid.Health > 0 then
                
                -- Calculăm distanța reală (Studs)
                local distInStuds = (p.Character.HumanoidRootPart.Position - char.HumanoidRootPart.Position).Magnitude
                
                -- Limită maximă de 600 studs (peste asta e greu să mai nimerești oricum)
                if distInStuds > 600 then continue end

                for _, partName in pairs(R6Parts) do
                    local part = p.Character:FindFirstChild(partName)
                    
                    if part and part:IsA("BasePart") then
                        local pos, onScreen = cam:WorldToViewportPoint(part.Position)
                        
                        if onScreen then
                            local screenPos = Vector2.new(pos.X, pos.Y)
                            local distFromMouse = (screenPos - mousePos).Magnitude
                            
                            -- DACĂ pixelul este în interiorul cercului FOV
                            if distFromMouse <= maxLimit then
                                
                                -- FORMULA DE PRIORITATE (Aici e magia):
                                -- Adăugăm o "penalizare" pentru distanță.
                                -- Cine e aproape are scor mic (bun), cine e departe are scor mare (rău).
                                local score = distFromMouse + (distInStuds * 2) 

                                if score < bestScore then
                                    bestScore = score
                                    target = p
                                end
                                break 
                            end
                        end
                    end
                end
            end
        end
    end
    return target
end

--======================= NO RECOIL =========================--

local NRSettings = {
    Enabled = false,
    WeaponCache = {},
    OriginalValues = {},
    Connections = {},
    GunMods = { NoRecoil = true, Spread = true, SpreadAmount = 0 }
}

function cacheWeapons_NR()
    NRSettings.WeaponCache = {}
    for _, v in pairs(getgc(true)) do
        if type(v) == 'table' and rawget(v, 'EquipTime') then
            table.insert(NRSettings.WeaponCache, v)
            if not NRSettings.OriginalValues[v] then
                NRSettings.OriginalValues[v] = {}
                if rawget(v, 'Recoil') ~= nil then NRSettings.OriginalValues[v].Recoil = v.Recoil end
                if rawget(v, 'CameraRecoilingEnabled') ~= nil then NRSettings.OriginalValues[v].CameraRecoilingEnabled = v.CameraRecoilingEnabled end
                if rawget(v, 'AngleX_Min') ~= nil then NRSettings.OriginalValues[v].AngleX_Min = v.AngleX_Min end
                if rawget(v, 'AngleX_Max') ~= nil then NRSettings.OriginalValues[v].AngleX_Max = v.AngleX_Max end
                if rawget(v, 'AngleY_Min') ~= nil then NRSettings.OriginalValues[v].AngleY_Min = v.AngleY_Min end
                if rawget(v, 'AngleY_Max') ~= nil then NRSettings.OriginalValues[v].AngleY_Max = v.AngleY_Max end
                if rawget(v, 'AngleZ_Min') ~= nil then NRSettings.OriginalValues[v].AngleZ_Min = v.AngleZ_Min end
                if rawget(v, 'AngleZ_Max') ~= nil then NRSettings.OriginalValues[v].AngleZ_Max = v.AngleZ_Max end
                if rawget(v, 'Spread') ~= nil then NRSettings.OriginalValues[v].Spread = v.Spread end
                if rawget(v, 'MaxSpread') ~= nil then NRSettings.OriginalValues[v].MaxSpread = v.MaxSpread end
            end
        end
    end
end

function applyGunMods_NR()
    for _, weapon in ipairs(NRSettings.WeaponCache) do
        if NRSettings.GunMods.NoRecoil then
            if rawget(weapon, 'Recoil') ~= nil then weapon.Recoil = 0 end
            if rawget(weapon, 'CameraRecoilingEnabled') ~= nil then weapon.CameraRecoilingEnabled = false end
            if rawget(weapon, 'AngleX_Min') ~= nil then weapon.AngleX_Min = 0 end
            if rawget(weapon, 'AngleX_Max') ~= nil then weapon.AngleX_Max = 0 end
            if rawget(weapon, 'AngleY_Min') ~= nil then weapon.AngleY_Min = 0 end
            if rawget(weapon, 'AngleY_Max') ~= nil then weapon.AngleY_Max = 0 end
            if rawget(weapon, 'AngleZ_Min') ~= nil then weapon.AngleZ_Min = 0 end
            if rawget(weapon, 'AngleZ_Max') ~= nil then weapon.AngleZ_Max = 0 end
        end
        if NRSettings.GunMods.Spread then
            if rawget(weapon, 'Spread') ~= nil then weapon.Spread = NRSettings.GunMods.SpreadAmount end
            if rawget(weapon, 'MaxSpread') ~= nil then weapon.MaxSpread = NRSettings.GunMods.SpreadAmount end
        end
    end
end

function resetGunMods_NR()
    for weapon, values in pairs(NRSettings.OriginalValues) do
        if weapon then
            pcall(function()
                if values.Recoil ~= nil then weapon.Recoil = values.Recoil end
                if values.CameraRecoilingEnabled ~= nil then weapon.CameraRecoilingEnabled = values.CameraRecoilingEnabled end
                if values.AngleX_Min ~= nil then weapon.AngleX_Min = values.AngleX_Min end
                if values.AngleX_Max ~= nil then weapon.AngleX_Max = values.AngleX_Max end
                if values.AngleY_Min ~= nil then weapon.AngleY_Min = values.AngleY_Min end
                if values.AngleY_Max ~= nil then weapon.AngleY_Max = values.AngleY_Max end
                if values.AngleZ_Min ~= nil then weapon.AngleZ_Min = values.AngleZ_Min end
                if values.AngleZ_Max ~= nil then weapon.AngleZ_Max = values.AngleZ_Max end
                if values.Spread ~= nil then weapon.Spread = values.Spread end
                if values.MaxSpread ~= nil then weapon.MaxSpread = values.MaxSpread end
            end)
        end
    end
end

function handleWeapon_NR(weapon)
    if NRSettings.Enabled then
        task.wait(0.1)
        cacheWeapons_NR()
        applyGunMods_NR()
    end
end

function onCharacterAdded_NR(character)
    for _, child in ipairs(character:GetChildren()) do
        if child:IsA("Tool") then
            handleWeapon_NR(child)
        end
    end
    
    local childConn = character.ChildAdded:Connect(function(child)
        if child:IsA("Tool") then
            handleWeapon_NR(child)
        end
    end)
    table.insert(NRSettings.Connections, childConn)
    
    local humanoid = character:WaitForChild("Humanoid", 2)
    if humanoid then
        local diedConn = humanoid.Died:Connect(function()
            if NRSettings.Enabled then
                task.wait(1.5)
                cacheWeapons_NR()
                applyGunMods_NR()
            end
        end)
        table.insert(NRSettings.Connections, diedConn)
    end
end

function enableNoRecoil()
    if NRSettings.Enabled then return end
    NRSettings.Enabled = true
    NRSettings.WeaponCache = {}
    NRSettings.OriginalValues = {}
    
    cacheWeapons_NR()
    applyGunMods_NR()
    
    local charConn = game.Players.LocalPlayer.CharacterAdded:Connect(onCharacterAdded_NR)
    table.insert(NRSettings.Connections, charConn)
    
    if game.Players.LocalPlayer.Character then
        onCharacterAdded_NR(game.Players.LocalPlayer.Character)
    end
end

function disableNoRecoil()
    if not NRSettings.Enabled then return end
    NRSettings.Enabled = false
    
    resetGunMods_NR()
    
    for _, conn in ipairs(NRSettings.Connections) do
        conn:Disconnect()
    end
    NRSettings.Connections = {}
end

--======================= SILENT AIM =========================--
local SA = {
    On = false, DrawCircle = false, DrawSize = 100, ChkDowned = true, ChkTeam = false, VisChk = false,
    MaxDist = 500, AutoWall = true, HitChance = 80, UseFOV = true, Debug = false,
    FOVCol = Color3.fromRGB(130, 90, 255), TMode = "Random",
    HeadChance = 80, BodyChance = 20,
    Parts = {
        ["Head"]={"Head"},
        ["Torso"]={"UpperTorso","LowerTorso","HumanoidRootPart"},
        ["Random"]={"Head","UpperTorso","LowerTorso"}
    }
}

local SACircle = nil
function crFOVCircle()
    if SACircle then SACircle:Remove(); SACircle = nil end
    if SA.DrawCircle and Drawing then
        SACircle = Drawing.new("Circle"); SACircle.Color = SA.FOVCol; SACircle.Filled = false
        SACircle.Thickness = 0.5; SACircle.Radius = SA.DrawSize; SACircle.Visible = true; SACircle.Transparency = 1
    end
end

function getValidT()
    if not SA.On then return nil end
    local Cam = workspace.CurrentCamera
    local t = nil; local minD = math.huge; local centerPos = game:GetService("UserInputService"):GetMouseLocation()
    local LP = game.Players.LocalPlayer
    for _, p in pairs(game.Players:GetPlayers()) do
        if p == LP then continue end; if not p.Character then continue end
        if SA.ChkTeam and p.Team == LP.Team then continue end
        local c = p.Character; local h = c:FindFirstChildOfClass("Humanoid")
        if not h or h.Health <= 0 then continue end
        if SA.ChkDowned and c:FindFirstChild("Downed") and c.Downed.Value then continue end

        local validP = SA.Parts[SA.TMode]; if not validP then validP = {"Head"} end
        local avail = {}; for _, pn in ipairs(validP) do local pt = c:FindFirstChild(pn); if pt then table.insert(avail, {Part=pt, Name=pn}) end end
        if #avail == 0 then continue end
        local sel = nil

        if SA.TMode == "Head" then 
            sel = avail[1]
        elseif SA.TMode == "Torso" then 
            sel = avail[math.random(1,#avail)]
        elseif SA.TMode == "Random" then 
            local rand = math.random(1, 100)
            if rand <= SA.HeadChance then sel = {Part = c:FindFirstChild("Head"), Name = "Head"}
            else sel = {Part = c:FindFirstChild("HumanoidRootPart") or c:FindFirstChild("UpperTorso") or c:FindFirstChild("Torso"), Name = "Torso"} end
        else 
            sel = avail[1] 
        end
        if not sel or not sel.Part then continue end
        local tp = sel.Part; local pPos = tp.Position
        local myC = LP.Character; local myR = myC and myC:FindFirstChild("HumanoidRootPart")
        if myR then local d = (myR.Position - pPos).Magnitude; if d > SA.MaxDist then continue end end
        
        -- WALL CHECK (Prevenim Hitmarkere False prin pereți)
        local ray = Ray.new(Cam.CFrame.Position, (pPos - Cam.CFrame.Position).Unit * 1000)
        local hit = workspace:FindPartOnRayWithIgnoreList(ray, {LP.Character, Cam})
        if hit and not hit:IsDescendantOf(c) and hit.Transparency < 1 then continue end
        local sPos, onSc = Cam:WorldToViewportPoint(pPos); if not onSc then continue end
        if SA.UseFOV then
            local closestLimbDist = math.huge
            for _, limb in pairs(c:GetChildren()) do
                if limb:IsA("BasePart") then
                    local lsP, lsOnSc = Cam:WorldToViewportPoint(limb.Position)
                    if lsOnSc then
                        local ld2m = (centerPos - Vector2.new(lsP.X, lsP.Y)).Magnitude
                        if ld2m < closestLimbDist then closestLimbDist = ld2m end
                    end
                end
            end
            
            -- Ofera o marja de "pixeli" (35) pentru a aproxima vizual membrele de la margine
            if closestLimbDist > SA.DrawSize + 35 then continue end
            if closestLimbDist < minD then minD = closestLimbDist; t = {Player=p, Char=c, Part=tp, PName=sel.Name, Pos=pPos, Dist=closestLimbDist, ScPos=sPos, WDist=(myR and (myR.Position-pPos).Magnitude) or 0} end
        else
            if myR then local wd = (myR.Position - pPos).Magnitude; if wd < minD then minD = wd; t = {Player=p, Char=c, Part=tp, PName=sel.Name, Pos=pPos, Dist=0, ScPos=sPos, WDist=wd} end end
        end
    end
    -- HitChance is applied per-tick when acquiring targets based on user's hub code.
    if t then local ch = math.random(1,100); if ch > SA.HitChance then return nil end end
    return t
end

function canFire(t) if not t then return false end; if SA.UseFOV and t.Dist > SA.DrawSize + 35 then return false end; return true end

local SALoopConn = nil
function updFOVCircle()
    local Cam = workspace.CurrentCamera
    if SACircle and SA.DrawCircle then
        SACircle.Position = game:GetService("UserInputService"):GetMouseLocation()
        SACircle.Radius = SA.DrawSize; SACircle.Visible = SA.On; SACircle.Color = SA.FOVCol
    end
end

function startSALoop()
    if SALoopConn then SALoopConn:Disconnect() end
    SALoopConn = game:GetService("RunService").Heartbeat:Connect(function() updFOVCircle(); _G.CurSATarget = getValidT() end)
end

local SAConns = {}; local lastT = nil; local lastDmg = false
local ev2_bindable = game:GetService("ReplicatedStorage"):FindFirstChild("Events2")
local GNX_remote = game:GetService("ReplicatedStorage"):FindFirstChild("Events") and game:GetService("ReplicatedStorage").Events:FindFirstChild("GNX_S")
local ZFK_remote = game:GetService("ReplicatedStorage"):FindFirstChild("Events") and game:GetService("ReplicatedStorage").Events:FindFirstChild("ZFKLF__H")

function hookShoot()
    for _, c in pairs(SAConns) do if c then c:Disconnect() end end; SAConns = {}
    local LP = game.Players.LocalPlayer
    
    if ev2_bindable and ZFK_remote then
        local viz = ev2_bindable:FindFirstChild("Visualize")
        if viz then
            local c = viz.Event:Connect(function(_, sc, _, gun, _, sPos, bps)
                if not SA.On then return end
                local t = getValidT(); if not t or not canFire(t) then lastT = nil; lastDmg = false; return end
                lastT = t; local c = LP.Character; if not c then return end
                local myG = c:FindFirstChildOfClass("Tool"); if not myG or myG ~= gun then return end
                local h = t.Char:FindFirstChildOfClass("Humanoid"); if not h or h.Health <= 0 then return end
                local tp = t.Part; local pPos = tp.Position
                local rOff = Vector3.new((math.random()-0.5)*0.5,(math.random()-0.5)*0.5,(math.random()-0.5)*0.5)
                local hitPos = pPos + rOff
                local newB = {}; for i=1,#bps do
                    local dir = (hitPos - sPos).Unit; local spAmt = (100 - SA.HitChance)/500
                    local sp = Vector3.new((math.random()-0.5)*spAmt,(math.random()-0.5)*spAmt,(math.random()-0.5)*spAmt)
                    table.insert(newB, dir+sp)
                end
                lastDmg = true
                task.spawn(function()
                    for i=1,#newB do task.wait(0.01); pcall(function() ZFK_remote:FireServer("🧈", gun, sc, i, tp, hitPos, newB[i]) end) end
                end)
                if gun:FindFirstChild("Hitmarker") and lastDmg then gun.Hitmarker:Fire(tp) end
                if lastDmg then return _, sc, _, gun, _, sPos, newB end
                return _, sc, _, gun, _, sPos, bps
            end)
            table.insert(SAConns, c)
        end
    end
    if GNX_remote and ZFK_remote then
        local c = GNX_remote.OnClientEvent:Connect(function(st, sc, gun, ft, sPos, dirs, silenced)
            if not SA.On then return end
            local t = getValidT(); if not t or not canFire(t) then lastT = nil; lastDmg = false; return end
            lastT = t; local c = LP.Character; if not c then return end
            local myG = c:FindFirstChildOfClass("Tool"); if not myG or myG ~= gun then return end
            local h = t.Char:FindFirstChildOfClass("Humanoid"); if not h or h.Health <= 0 then return end
            local tp = t.Part; local pPos = tp.Position
            local rOff = Vector3.new((math.random()-0.5)*0.5,(math.random()-0.5)*0.5,(math.random()-0.5)*0.5)
            local hitPos = pPos + rOff
            local newD = {}; for i=1,#dirs do
                local dir = (hitPos - sPos).Unit; local spAmt = (100 - SA.HitChance)/400
                local sp = Vector3.new((math.random()-0.5)*spAmt,(math.random()-0.5)*spAmt,(math.random()-0.5)*spAmt)
                table.insert(newD, dir+sp)
            end
            lastDmg = true
            task.spawn(function()
                for i=1,#newD do task.wait(0.01); pcall(function() ZFK_remote:FireServer("🧈", gun, sc, i, tp, hitPos, newD[i]) end) end
            end)
            if gun:FindFirstChild("Hitmarker") and lastDmg then gun.Hitmarker:Fire(tp) end
            if lastDmg then return st, sc, gun, ft, sPos, newD, silenced end
            return st, sc, gun, ft, sPos, dirs, silenced
        end)
        table.insert(SAConns, c)
    end
end

function SA_Enable()
    if SA.On then return end
    SA.On = true
    crFOVCircle(); startSALoop(); hookShoot()
end

function SA_Disable()
    if not SA.On then return end
    SA.On = false
    if SALoopConn then SALoopConn:Disconnect(); SALoopConn = nil end
    if SACircle then SACircle:Remove(); SACircle = nil end
    for _, c in pairs(SAConns) do if c then c:Disconnect() end end; SAConns = {}
    _G.CurSATarget = nil; lastT = nil; lastDmg = false
end

--========================== Infinite Stamina ========================--
local InfStamina_Enabled = false
local InfStamina_Connection = nil

local function InfStamina_Enable()
    if InfStamina_Enabled then return end
    InfStamina_Enabled = true
    
    -- Folosim RunService (RS) care e deja definit sus în scriptul tău
    InfStamina_Connection = RunService.RenderStepped:Connect(function()
        if not InfStamina_Enabled then return end
        
        local char = LocalPlayer.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        
        if hum then
            -- Setăm atributul doar dacă nu este deja setat, pentru eficiență
            if hum:GetAttribute("ZSPRN_M") ~= true then
                hum:SetAttribute("ZSPRN_M", true)
            end
        end
    end)
end

local function InfStamina_Disable()
    InfStamina_Enabled = false
    if InfStamina_Connection then
        InfStamina_Connection:Disconnect()
        InfStamina_Connection = nil
    end
    
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if hum then
        hum:SetAttribute("ZSPRN_M", nil)
    end
end
--======================= INVISIBILITY =========================--

local Invis_Fixed = true

do
    repeat task.wait() until game:IsLoaded();

    local cloneref = cloneref or function(...) return ... end;

    local Service = setmetatable({}, {
        __index = function(_, k)
            return cloneref(game:GetService(k));
        end
    });

    local Player = Service.Players.LocalPlayer;
    local Character = Player.Character or Player.CharacterAdded:Wait();
    local Humanoid
    local HumanoidRootPart

    local function UpdateCharacterReferences()
        Character = Player.Character
        if Character then
            HumanoidRootPart = Character:FindFirstChild("HumanoidRootPart")
            Humanoid = Character:FindFirstChildOfClass("Humanoid")
        else
            HumanoidRootPart = nil
            Humanoid = nil
        end
    end

    UpdateCharacterReferences()

    local InvisEnabled = false;
    local Track = nil
    local Animation = Instance.new("Animation");
    Animation.AnimationId = "rbxassetid://215384594";

    local RunService = Service.RunService;
    local Heartbeat = RunService.Heartbeat;
    local RenderStepped = RunService.RenderStepped;

    local UserInputService = Service.UserInputService;
    local CoreGui = Service.CoreGui;
    local StarterGui = Service.StarterGui;

    if Character and not Character:FindFirstChild("Torso") then
        pcall(function()
            StarterGui:SetCore("SendNotification", {
                Title = "Invisibility FAILED",
                Text = "Feature requires R6 Avatar.",
                Duration = 5,
            });
        end)
        Invis_Fixed = false
    end

    local GUI = Instance.new("ScreenGui");
    GUI.Name = "InvisWarningGUI";
    GUI.Parent = CoreGui;
    GUI.ResetOnSpawn = false;
    GUI.ZIndexBehavior = Enum.ZIndexBehavior.Sibling;

    local WarnLabel = Instance.new("TextLabel", GUI);
    WarnLabel.Text = "⚠️You are visible⚠️";
    WarnLabel.Visible = false;
    WarnLabel.Size = UDim2.new(0, 200, 0, 30);
    WarnLabel.Position = UDim2.new(0.5, -100, 0.85, 0);
    WarnLabel.BackgroundTransparency = 1;
    WarnLabel.Font = Enum.Font.GothamSemibold;
    WarnLabel.TextSize = 24;
    WarnLabel.TextColor3 = Color3.fromRGB(255, 255, 0);
    WarnLabel.TextStrokeTransparency = 0.5;
    WarnLabel.ZIndex = 10;

    local function Grounded()
        return Humanoid and Humanoid:IsDescendantOf(workspace) and Humanoid.FloorMaterial ~= Enum.Material.Air;
    end

    local function LoadAndPrepareTrack()
        if Track then
             pcall(function() Track:Stop() end)
             Track = nil
        end
        if Humanoid then
            local success, result = pcall(function()
                return Humanoid:LoadAnimation(Animation)
            end)
            if success then
                Track = result
                Track.Priority = Enum.AnimationPriority.Action4;
            else
                Track = nil
            end
        else
             Track = nil
        end
    end

    local function Invis_Disable()
        if not InvisEnabled then return end
        InvisEnabled = false;

        if Track then
             pcall(function() Track:Stop() end)
        end

        if Humanoid then
            workspace.CurrentCamera.CameraSubject = Humanoid;
        end

        if Character then
            for _, v in pairs(Character:GetDescendants()) do
                if v:IsA("BasePart") and v.Transparency == 0.5 then
                    v.Transparency = 0;
                end
            end
        end

        WarnLabel.Visible = false;
    end

    local function Invis_Enable()
        if InvisEnabled or not Invis_Fixed then return end

        UpdateCharacterReferences()
        if not Character or not Humanoid or not HumanoidRootPart then return end
        if not Character:FindFirstChild("Torso") then
            pcall(function() StarterGui:SetCore("SendNotification", {Title = "Invisibility FAILED", Text = "Feature requires R6 Avatar.", Duration = 5}) end)
            return
        end

        InvisEnabled = true;
        workspace.CurrentCamera.CameraSubject = HumanoidRootPart;

        LoadAndPrepareTrack()
    end

    Player.CharacterAdded:Connect(function(NewCharacter)
        if Track then
            pcall(function() Track:Stop() end)
            Track = nil
        end

        task.wait()

        UpdateCharacterReferences()

        if not Humanoid then
             task.wait(0.5)
             UpdateCharacterReferences()
             if not Humanoid then
                  Invis_Fixed = false
                  if InvisEnabled then Invis_Disable() end
                  pcall(function() StarterGui:SetCore("SendNotification", {Title = "Invisibility Error", Text = "Could not verify character type.", Duration = 5}) end)
                  return
             end
        end

        if Humanoid.RigType ~= Enum.HumanoidRigType.R6 then
            Invis_Fixed = false
            if InvisEnabled then Invis_Disable() end
            pcall(function() StarterGui:SetCore("SendNotification", {Title = "Invisibility Warning", Text = "Non-R6 Avatar detected. Invisibility disabled.", Duration = 5}) end)
            return
        else
            Invis_Fixed = true
        end

        if InvisEnabled then
            if HumanoidRootPart then
                 workspace.CurrentCamera.CameraSubject = HumanoidRootPart
            end
            LoadAndPrepareTrack()
        end
    end)

    Player.CharacterRemoving:Connect(function(OldCharacter)
         if Track then
             pcall(function() Track:Stop() end)
             Track = nil
         end
         WarnLabel.Visible = false
    end)

    Heartbeat:Connect(function(deltaTime)
        if not InvisEnabled or not Invis_Fixed then
            if not InvisEnabled and Character then
                 for _, v in pairs(Character:GetDescendants()) do
                      if v:IsA("BasePart") and v.Transparency == 0.5 then v.Transparency = 0 end
                 end
            end
            WarnLabel.Visible = false
            return;
        end

        if not Character or not Humanoid or not HumanoidRootPart or not Humanoid:IsDescendantOf(workspace) or Humanoid.Health <= 0 then
            WarnLabel.Visible = false;
            return
        end

        WarnLabel.Visible = not Grounded();

        local speed = 12
        if Humanoid.MoveDirection.Magnitude > 0 then
             local offset = Humanoid.MoveDirection * speed * deltaTime
             HumanoidRootPart.CFrame = HumanoidRootPart.CFrame + offset
        end

        local OldCFrame = HumanoidRootPart.CFrame;
        local OldCameraOffset = Humanoid.CameraOffset;

        local _, y = workspace.CurrentCamera.CFrame:ToOrientation();
        HumanoidRootPart.CFrame = CFrame.new(HumanoidRootPart.CFrame.Position) * CFrame.fromOrientation(0, y, 0);
        HumanoidRootPart.CFrame = HumanoidRootPart.CFrame * CFrame.Angles(math.rad(90), 0, 0);
        Humanoid.CameraOffset = Vector3.new(0, 1.44, 0);

        if Track then
            local successPlay, errPlay = pcall(function()
                if not Track.IsPlaying then
                     Track:Play();
                end
                 Track:AdjustSpeed(0);
                 Track.TimePosition = 0.3;
            end)
             if not successPlay then
                 LoadAndPrepareTrack()
             end
        elseif Humanoid and Humanoid.Health > 0 then
             LoadAndPrepareTrack()
        end

        RenderStepped:Wait();

        if Humanoid and Humanoid:IsDescendantOf(workspace) then
             Humanoid.CameraOffset = OldCameraOffset;
        end
        if HumanoidRootPart and HumanoidRootPart:IsDescendantOf(workspace) then
             HumanoidRootPart.CFrame = OldCFrame;
        end

        if Track then
            local successStop, errStop = pcall(function() Track:Stop() end)
        end

        if HumanoidRootPart and HumanoidRootPart:IsDescendantOf(workspace) then
             local LookVector = workspace.CurrentCamera.CFrame.LookVector;
             local Horizontal = Vector3.new(LookVector.X, 0, LookVector.Z).Unit;
             if Horizontal.Magnitude > 0.1 then
                 local TargetCFrame = CFrame.new(HumanoidRootPart.Position, HumanoidRootPart.Position + Horizontal);
                 HumanoidRootPart.CFrame = TargetCFrame;
             end
        end

        if Character then
             for _, v in pairs(Character:GetDescendants()) do
                 if (v:IsA("BasePart") and v.Transparency ~= 1) then
                     v.Transparency = 0.5;
                 end
             end
        end
    end)

    _G.Invis_Enable = Invis_Enable
    _G.Invis_Disable = Invis_Disable
    _G.IsInvisEnabled = function() return InvisEnabled end

end

--======================= WALLHACK (ESP) =========================--
local ESP_Enabled = false
local ESP_MaxDistance = 1000
local espConnection = nil

local function updESP()
    for _, p in pairs(game:GetService("Players"):GetPlayers()) do
        if p ~= game:GetService("Players").LocalPlayer then
            local char = p.Character
            if char then
                local hl = char:FindFirstChild("MyESP")
                local root = char:FindFirstChild("HumanoidRootPart")
                local myRoot = game:GetService("Players").LocalPlayer.Character and game:GetService("Players").LocalPlayer.Character:FindFirstChild("HumanoidRootPart")

                if ESP_Enabled and root and myRoot then
                    local distance = (root.Position - myRoot.Position).Magnitude
                    
                    if distance > ESP_MaxDistance then
                        if hl then hl:Destroy() end
                        continue
                    end
                    
                    if not hl then
                        hl = Instance.new("Highlight")
                        hl.Name = "MyESP"
                        hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                        hl.FillTransparency = 1 
                        hl.OutlineTransparency = 0 
                        hl.OutlineColor = Color3.fromRGB(115, 90, 250)
                        hl.Parent = char
                    end
                    
                    hl.Enabled = true
                else
                    if hl then hl:Destroy() end
                end
            end
        end
    end
end

-- Funcțiile pentru butoanele de meniu
local function ESP_Enable()
    ESP_Enabled = true
    if not espConnection then
        -- Folosim Heartbeat pentru o actualizare fluidă (fără lag)
        espConnection = game:GetService("RunService").Heartbeat:Connect(updESP)
    end
end

local function ESP_Disable()
    ESP_Enabled = false
    if espConnection then
        espConnection:Disconnect()
        espConnection = nil
    end
    -- Curățăm imediat tot movul de pe jucători
    for _, p in pairs(game:GetService("Players"):GetPlayers()) do
        if p.Character then
            local hl = p.Character:FindFirstChild("MyESP")
            if hl then hl:Destroy() end
        end
    end
end
-------------------------------------------------------------------------------
--  5. Funcție care creează un rând de butoane
-------------------------------------------------------------------------------

local buttonHoverColor = Color3.fromRGB(40, 40, 50)
local buttonColor = Color3.fromRGB(25, 25, 30)
local buttonStrokeColor = Color3.fromRGB(60, 60, 75)
local buttonTextColor = Color3.fromRGB(210, 210, 210)
local buttonOnColor = Color3.fromRGB(70, 180, 100)
local buttonOffColor = Color3.fromRGB(200, 80, 80)
local bindButtonColor = Color3.fromRGB(45, 45, 55)
local bindButtonHoverColor = Color3.fromRGB(60, 60, 75)

local activeBinds = {}
local currentRowWaitingForKey = nil
local bindButtonReferences = {}
local keyBindGetters = {}
local keyBindSetters = {}
local toggleButtonTweens = {}
local rowFunctionData = {}

local function createToggleRowFrame(scriptName, canToggle, isEnabledFn, onEnable, onDisable, getKeyBindFn, setKeyBindFn)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, -20, 0, 35)
    frame.BackgroundTransparency = 1
    frame.Name = scriptName:gsub("%s+", "")

    local horizontalLayout = Instance.new("UIListLayout")
    horizontalLayout.FillDirection = Enum.FillDirection.Horizontal
    horizontalLayout.VerticalAlignment = Enum.VerticalAlignment.Center
    horizontalLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
    horizontalLayout.SortOrder = Enum.SortOrder.LayoutOrder
    horizontalLayout.Padding = UDim.new(0, 5)
    horizontalLayout.Parent = frame

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0.45, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = " " .. scriptName
    label.TextColor3 = buttonTextColor
    label.Font = Enum.Font.GothamSemibold
    label.TextSize = 14
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.LayoutOrder = 1
    label.Parent = frame

    local toggleButton = Instance.new("TextButton")
    toggleButton.Size = UDim2.new(0.25, 0, 0.8, 0)
    toggleButton.Font = Enum.Font.GothamBold
    toggleButton.TextSize = 12
    toggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    toggleButton.BackgroundColor3 = buttonColor
    toggleButton.BorderSizePixel = 0
    toggleButton.AutoButtonColor = false
    toggleButton.LayoutOrder = 2
    toggleButton.Parent = frame

    local toggleCorner = Instance.new("UICorner")
    toggleCorner.CornerRadius = UDim.new(0, 6)
    toggleCorner.Parent = toggleButton
    local toggleStroke = Instance.new("UIStroke")
    toggleStroke.Color = buttonStrokeColor
    toggleStroke.Thickness = 1
    toggleStroke.Parent = toggleButton

    local bindButton = nil

    local updateToggleButtonVisuals

    local function getTargetToggleColor()
        local enabledState = false
        if type(isEnabledFn) == 'function' then
            local success, result = pcall(isEnabledFn)
            if success then enabledState = result end
        end
        if not canToggle then return Color3.fromRGB(80, 120, 220)
        elseif enabledState then return buttonOnColor
        else return buttonOffColor
        end
    end

    updateToggleButtonVisuals = function()
        local enabledState = false
        if type(isEnabledFn) == 'function' then
            local success, result = pcall(isEnabledFn)
            if success then enabledState = result end
        end

        local targetColor
        if not canToggle then toggleButton.Text = "RUN"; targetColor = Color3.fromRGB(80, 120, 220);
        elseif enabledState then toggleButton.Text = "ON"; targetColor = buttonOnColor
        else toggleButton.Text = "OFF"; targetColor = buttonOffColor
        end

        if toggleButtonTweens[toggleButton] then toggleButtonTweens[toggleButton]:Cancel(); toggleButtonTweens[toggleButton] = nil end
        toggleButton.BackgroundColor3 = targetColor
    end

    rowFunctionData[frame] = {
        isEnabledFn = isEnabledFn,
        onEnable = onEnable,
        onDisable = onDisable,
        canToggle = canToggle,
        updateFn = updateToggleButtonVisuals
    }

    if getKeyBindFn and setKeyBindFn then
        bindButton = Instance.new("TextButton")
        bindButton.Size = UDim2.new(0.25, 0, 0.8, 0)
        bindButton.Font = Enum.Font.GothamMedium
        bindButton.TextSize = 12
        bindButton.TextColor3 = buttonTextColor
        bindButton.BackgroundColor3 = bindButtonColor
        bindButton.BorderSizePixel = 0
        bindButton.AutoButtonColor = false
        bindButton.LayoutOrder = 3
        bindButton.Parent = frame

        local bindCorner = Instance.new("UICorner"); bindCorner.CornerRadius = UDim.new(0, 6); bindCorner.Parent = bindButton
        local bindStroke = Instance.new("UIStroke"); bindStroke.Color = buttonStrokeColor; bindStroke.Thickness = 1; bindStroke.Parent = bindButton

        bindButtonReferences[frame] = bindButton
        keyBindGetters[frame] = getKeyBindFn
        keyBindSetters[frame] = setKeyBindFn

        local initialKey = nil
        local success, result = pcall(getKeyBindFn)
        if success and result and typeof(result)=="EnumItem" then
            initialKey = result
            if rowFunctionData[frame] then
                activeBinds[initialKey] = {
                    frame = frame,
                    toggleButton = toggleButton,
                    isEnabledFn = rowFunctionData[frame].isEnabledFn,
                    onEnable = rowFunctionData[frame].onEnable,
                    onDisable = rowFunctionData[frame].onDisable,
                    canToggle = rowFunctionData[frame].canToggle,
                    updateFn = rowFunctionData[frame].updateFn
                }
            end
        end
    else
        toggleButton.Size = UDim2.new(0.5, 0, 0.8, 0)
        horizontalLayout.Padding = UDim.new(0, 10)
    end

    local function updateBindButtonText()
        if not bindButton then return end
        local kb = nil
        if type(getKeyBindFn) == 'function' then
            local success, result = pcall(getKeyBindFn)
            if success then kb = result end
        end
        bindButton.Text = kb and typeof(kb)=="EnumItem" and kb.Name~="Unknown" and "["..kb.Name.."]" or "Bind"
    end

    updateToggleButtonVisuals()
    updateBindButtonText()

    toggleButton.MouseEnter:Connect(function()
        if toggleButtonTweens[toggleButton] then toggleButtonTweens[toggleButton]:Cancel() end
        local targetColor = getTargetToggleColor()
        local hoverTargetColor = targetColor:Lerp(Color3.new(1, 1, 1), 0.2)
        local tween = TweenService:Create(toggleButton, TweenInfo.new(0.1), { BackgroundColor3 = hoverTargetColor })
        toggleButtonTweens[toggleButton] = tween
        tween:Play()
    end)
    toggleButton.MouseLeave:Connect(function()
        if toggleButtonTweens[toggleButton] then toggleButtonTweens[toggleButton]:Cancel() end
        local targetColor = getTargetToggleColor()
        local tween = TweenService:Create(toggleButton, TweenInfo.new(0.1), { BackgroundColor3 = targetColor })
        toggleButtonTweens[toggleButton] = tween
        tween:Play()
    end)

    if bindButton then
        bindButton.MouseEnter:Connect(function() TweenService:Create(bindButton, TweenInfo.new(0.1), { BackgroundColor3 = bindButtonHoverColor }):Play() end)
        bindButton.MouseLeave:Connect(function() TweenService:Create(bindButton, TweenInfo.new(0.1), { BackgroundColor3 = bindButtonColor }):Play() end)

        local capturingKey = false
        bindButton.MouseButton1Click:Connect(function()
            if currentRowWaitingForKey and currentRowWaitingForKey ~= frame then
                local prevBindButton=bindButtonReferences[currentRowWaitingForKey]
                if prevBindButton then
                    local getter=keyBindGetters[currentRowWaitingForKey]
                    local prevKeyText="Bind"; if getter then local s,r=pcall(getter); if s and r and typeof(r)=="EnumItem" then prevKeyText="["..r.Name.."]" end end
                    prevBindButton.Text=prevKeyText
                end
            end
            if capturingKey then
                capturingKey=false; updateBindButtonText(); currentRowWaitingForKey=nil
            else
                capturingKey=true; bindButton.Text="..."; currentRowWaitingForKey=frame
                task.delay(5, function() if capturingKey and currentRowWaitingForKey==frame then capturingKey=false; updateBindButtonText(); currentRowWaitingForKey=nil end end)
            end
        end)
    end

    toggleButton.MouseButton1Click:Connect(function()
        local enabledState = false; if type(isEnabledFn)=='function' then local s,r=pcall(isEnabledFn); if s then enabledState=r end end
        if not canToggle then if type(onEnable)=='function' then pcall(onEnable) end; toggleButton.Text="DONE"; toggleButton.BackgroundColor3=buttonOnColor:Lerp(Color3.fromRGB(15,15,20),0.3); toggleButton.Active=false; if bindButton then bindButton.Active=false end; return end
        if enabledState then if type(onDisable)=='function' then pcall(onDisable) end else if type(onEnable)=='function' then pcall(onEnable) end end
        updateToggleButtonVisuals()
    end)

    return frame
end

local function createActionButtonFrame(labelText, buttonText, actionFunction)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, -20, 0, 35)
    frame.BackgroundTransparency = 1
    frame.Name = labelText:gsub("%s+", "") .. "Action"

    local horizontalLayout = Instance.new("UIListLayout")
    horizontalLayout.FillDirection = Enum.FillDirection.Horizontal
    horizontalLayout.VerticalAlignment = Enum.VerticalAlignment.Center
    horizontalLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
    horizontalLayout.SortOrder = Enum.SortOrder.LayoutOrder
    horizontalLayout.Padding = UDim.new(0, 10)
    horizontalLayout.Parent = frame

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0.45, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = " " .. labelText
    label.TextColor3 = buttonTextColor
    label.Font = Enum.Font.GothamSemibold
    label.TextSize = 14
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.LayoutOrder = 1
    label.Parent = frame

    local actionButton = Instance.new("TextButton")
    actionButton.Size = UDim2.new(0.5, 0, 0.8, 0)
    actionButton.Font = Enum.Font.GothamBold
    actionButton.TextSize = 12
    actionButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    actionButton.Text = buttonText
    actionButton.BackgroundColor3 = buttonColor
    actionButton.BorderSizePixel = 0
    actionButton.AutoButtonColor = false
    actionButton.LayoutOrder = 2
    actionButton.Parent = frame

    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 6)
    btnCorner.Parent = actionButton
    local btnStroke = Instance.new("UIStroke")
    btnStroke.Color = buttonStrokeColor
    btnStroke.Thickness = 1
    btnStroke.Parent = actionButton

    actionButton.MouseEnter:Connect(function()
        TweenService:Create(actionButton, TweenInfo.new(0.1), { BackgroundColor3 = buttonHoverColor }):Play()
    end)
    actionButton.MouseLeave:Connect(function()
        TweenService:Create(actionButton, TweenInfo.new(0.1), { BackgroundColor3 = buttonColor }):Play()
    end)

    actionButton.MouseButton1Click:Connect(function()
        if actionFunction and typeof(actionFunction) == 'function' then
            local success, err = pcall(actionFunction)
            if not success then
                 warn("Error in action button function for '"..labelText.."':", err)
            end
            local originalColor = actionButton.BackgroundColor3
            actionButton.BackgroundColor3 = buttonOnColor
            task.wait(0.2)
            actionButton.BackgroundColor3 = originalColor
        end
    end)

    return frame
end

local function createSliderRowFrame(labelText, min, max, default, updateFn)
    local frame = Instance.new("Frame")
    frame.Name = labelText .. "_SliderRow"
    frame.Size = UDim2.new(1, -10, 0, 50)
    frame.BackgroundTransparency = 1
    
    local label = Instance.new("TextLabel")
    label.Parent = frame
    label.Size = UDim2.new(1, 0, 0, 20)
    label.Position = UDim2.new(0, 5, 0, 2)
    label.Text = labelText
    label.TextColor3 = Color3.fromRGB(200, 200, 200)
    label.Font = Enum.Font.GothamMedium
    label.TextSize = 13
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.BackgroundTransparency = 1

    local valueLabel = Instance.new("TextLabel")
    valueLabel.Parent = frame
    valueLabel.Size = UDim2.new(0, 40, 0, 20)
    valueLabel.Position = UDim2.new(1, -45, 0, 2)
    valueLabel.Text = tostring(default)
    valueLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    valueLabel.Font = Enum.Font.GothamBold
    valueLabel.TextSize = 12
    valueLabel.TextXAlignment = Enum.TextXAlignment.Right
    valueLabel.BackgroundTransparency = 1

    -- BARA DE FUNDAL (MICȘORATĂ la 8 pixeli)
    local sliderBack = Instance.new("Frame")
    sliderBack.Parent = frame
    sliderBack.Size = UDim2.new(1, -15, 0, 8) -- Grosime de 8px
    sliderBack.Position = UDim2.new(0, 5, 0, 31)
    sliderBack.BackgroundColor3 = Color3.fromRGB(25, 25, 30) 
    sliderBack.BorderSizePixel = 0
    
    local backCorner = Instance.new("UICorner")
    backCorner.CornerRadius = UDim.new(1, 0)
    backCorner.Parent = sliderBack

    -- BARA DE PROGRES (VIOLET MAT - Grosime 8px)
    local sliderFill = Instance.new("Frame")
    sliderFill.Parent = sliderBack
    sliderFill.BackgroundColor3 = Color3.fromRGB(90, 85, 160) -- Culoarea violet cerută
    sliderFill.BorderSizePixel = 0
    sliderFill.ZIndex = 2
    
    local fillCorner = Instance.new("UICorner")
    fillCorner.CornerRadius = UDim.new(1, 0)
    fillCorner.Parent = sliderFill

    -- PUNCTUL (MICȘORAT la 12 pixeli)
    local sliderKnob = Instance.new("ImageButton")
    sliderKnob.Parent = sliderBack
    sliderKnob.Size = UDim2.new(0, 12, 0, 12) -- Diametru de 12px
    sliderKnob.AnchorPoint = Vector2.new(0.5, 0.5)
    sliderKnob.ZIndex = 3
    sliderKnob.BackgroundColor3 = Color3.fromRGB(202, 203, 214) 
    sliderKnob.BorderSizePixel = 0
    
    local knobCorner = Instance.new("UICorner")
    knobCorner.CornerRadius = UDim.new(1, 0)
    knobCorner.Parent = sliderKnob

    local function updateVisuals(percent)
        sliderKnob.Position = UDim2.new(percent, 0, 0.5, 0)
        sliderFill.Size = UDim2.new(percent, 0, 1, 0) -- Umplere în spatele punctului
    end

    local initialPercent = (default - min) / (max - min)
    updateVisuals(initialPercent)

    local UserInputService = game:GetService("UserInputService")
    local dragging = false

    local function update(input)
        local pos = math.clamp((input.Position.X - sliderBack.AbsolutePosition.X) / sliderBack.AbsoluteSize.X, 0, 1)
        local val = math.floor(min + (max - min) * pos)
        updateVisuals(pos)
        valueLabel.Text = tostring(val)
        updateFn(val)
    end

    sliderKnob.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = true end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then update(input) end
    end)
    sliderBack.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then update(input) end
    end)

    return frame
end

local function createDropdownRowFrame(labelText, options, default, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, -20, 0, 35)
    frame.BackgroundTransparency = 1
    frame.ZIndex = 10 

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0.4, 0, 0, 35)
    label.Text = "  " .. labelText
    label.TextColor3 = Color3.fromRGB(220, 220, 220)
    label.Font = Enum.Font.GothamMedium
    label.TextSize = 13; label.TextXAlignment = Enum.TextXAlignment.Left
    label.BackgroundTransparency = 1; label.Parent = frame

    local dropBtn = Instance.new("TextButton")
    dropBtn.Size = UDim2.new(0.5, 0, 0, 28)
    dropBtn.Position = UDim2.new(0.5, 0, 0, 3)
    dropBtn.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
    dropBtn.Text = "  " .. default
    dropBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    dropBtn.Font = Enum.Font.GothamSemibold
    dropBtn.TextXAlignment = Enum.TextXAlignment.Left
    dropBtn.Parent = frame
    dropBtn.TextSize = 12
    dropBtn.AutoButtonColor = false
    Instance.new("UICorner", dropBtn).CornerRadius = UDim.new(0, 4)
    local stroke = Instance.new("UIStroke", dropBtn)
    stroke.Color = Color3.fromRGB(45, 45, 55)
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

    local arrowIcon = Instance.new("TextLabel")
    arrowIcon.Size = UDim2.new(0, 20, 1, 0)
    arrowIcon.Position = UDim2.new(1, -25, 0, 0)
    arrowIcon.BackgroundTransparency = 1
    arrowIcon.Text = "▼"
    arrowIcon.TextColor3 = Color3.fromRGB(150, 150, 150)
    arrowIcon.Font = Enum.Font.Gotham
    arrowIcon.TextSize = 10
    arrowIcon.Parent = dropBtn

    local targetHeight = math.clamp(#options * 28, 28, 140)
    local listHolder = Instance.new("ScrollingFrame")
    listHolder.Name = "ListHolder"
    listHolder.Parent = dropBtn
    listHolder.Visible = false
    listHolder.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
    listHolder.BorderSizePixel = 0
    listHolder.Position = UDim2.new(0, 0, 1, 4)
    listHolder.Size = UDim2.new(1, 0, 0, 0) -- Starts closed (0 height)
    listHolder.ZIndex = 15
    listHolder.ScrollBarThickness = 2
    listHolder.ScrollBarImageColor3 = Color3.fromRGB(115, 90, 250)
    listHolder.CanvasSize = UDim2.new(0, 0, 0, #options * 28)
    Instance.new("UICorner", listHolder).CornerRadius = UDim.new(0, 4)
    local listStroke = Instance.new("UIStroke", listHolder)
    listStroke.Color = Color3.fromRGB(45, 45, 55)

    local layout = Instance.new("UIListLayout", listHolder)
    layout.SortOrder = Enum.SortOrder.LayoutOrder

    local isOpen = false

    for _, option in ipairs(options) do
        local optBtn = Instance.new("TextButton")
        optBtn.Size = UDim2.new(1, 0, 0, 28)
        optBtn.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
        optBtn.BorderSizePixel = 0
        optBtn.Text = "  " .. option
        optBtn.TextXAlignment = Enum.TextXAlignment.Left
        optBtn.TextColor3 = Color3.fromRGB(180, 180, 180)
        optBtn.Font = Enum.Font.GothamMedium
        optBtn.TextSize = 12
        optBtn.Parent = listHolder
        optBtn.ZIndex = 16
        optBtn.AutoButtonColor = false

        optBtn.MouseEnter:Connect(function()
            TweenService:Create(optBtn, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(40, 40, 50), TextColor3 = Color3.fromRGB(255, 255, 255)}):Play()
        end)
        optBtn.MouseLeave:Connect(function()
            TweenService:Create(optBtn, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(20, 20, 25), TextColor3 = Color3.fromRGB(180, 180, 180)}):Play()
        end)

        optBtn.MouseButton1Click:Connect(function()
            dropBtn.Text = "  " .. option
            isOpen = false
            
            TweenService:Create(arrowIcon, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Rotation = 0, TextColor3 = Color3.fromRGB(150, 150, 150)}):Play()
            TweenService:Create(stroke, TweenInfo.new(0.2), {Color = Color3.fromRGB(45, 45, 55)}):Play()
            
            local closeTween = TweenService:Create(listHolder, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = UDim2.new(1, 0, 0, 0)})
            closeTween:Play()
            closeTween.Completed:Connect(function()
                if not isOpen then listHolder.Visible = false end
            end)
            
            callback(option)
        end)
    end

    dropBtn.MouseEnter:Connect(function()
        if not isOpen then
            TweenService:Create(stroke, TweenInfo.new(0.15), {Color = Color3.fromRGB(80, 80, 90)}):Play()
        end
    end)
    
    dropBtn.MouseLeave:Connect(function()
        if not isOpen then
            TweenService:Create(stroke, TweenInfo.new(0.15), {Color = Color3.fromRGB(45, 45, 55)}):Play()
        end
    end)

    dropBtn.MouseButton1Click:Connect(function()
        isOpen = not isOpen
        
        TweenService:Create(arrowIcon, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Rotation = isOpen and 180 or 0,
            TextColor3 = isOpen and Color3.fromRGB(115, 90, 250) or Color3.fromRGB(150, 150, 150)
        }):Play()
        
        TweenService:Create(stroke, TweenInfo.new(0.25), {
            Color = isOpen and Color3.fromRGB(115, 90, 250) or Color3.fromRGB(45, 45, 55)
        }):Play()

        if isOpen then
            listHolder.Visible = true
            TweenService:Create(listHolder, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Size = UDim2.new(1, 0, 0, targetHeight)}):Play()
        else
            local closeTween = TweenService:Create(listHolder, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = UDim2.new(1, 0, 0, 0)})
            closeTween:Play()
            closeTween.Completed:Connect(function()
                if not isOpen then listHolder.Visible = false end
            end)
        end
    end)

    return frame
end

local EQR_UI = {}

-------------------------------------------------------------------------------
-- 1. Proprietăți UI
-------------------------------------------------------------------------------

EQR_UI.Categories = { "Combat", "Movement", "Visuals", "Farming", "Misc" }
EQR_UI.SubCategories = {
    Combat = {"Aimbots", "Melee", "Rage"},
    Movement = {"Main"},
    Visuals = {"ESP", "World"},
    Farming = {"Farming"},
    Misc = {"Misc"}
}
EQR_UI.CategoryButtons = {}
EQR_UI.SubCategoryButtons = {}
EQR_UI.CategoryFrames = {}
EQR_UI.ActiveCategoryButton = nil
EQR_UI.ActiveSubCategoryButton = nil
EQR_UI.DefaultCategory = "Combat"

EQR_UI.KeyBinds = {
    fly = Fly_Bind,
    fov = Fov_Bind,
    noclip = Noclip_Bind,
    FullBright = FullBright_Bind,
    autofarm = Autofarm_Bind,
    autoPickupMoney = nil,
    adminCheck = nil,
    melee = nil,
    infiniteStamina = nil,
    esp = nil,
    aimbot = AimBotSettings.Keybind,
    invis = nil,
    antiAFK = nil,
    ragebot = nil,
    noFailLockpick = nil,
    safeESP = nil,
    openNearbyDoors = nil,
    unlockNearbyDoors = nil
}

-------------------------------------------------------------------------------
-- 2. METODE UI
-------------------------------------------------------------------------------

function EQR_UI:SwitchCategory(categoryName)
    local categoryButton = self.CategoryButtons[categoryName]
    if not categoryButton or categoryButton == self.ActiveCategoryButton then return end

    if self.ActiveCategoryButton then
        TweenService:Create(self.ActiveCategoryButton, TweenInfo.new(0.2), { BackgroundColor3 = Color3.fromRGB(20, 20, 25) }):Play()
        self.ActiveCategoryButton.TextLabel.TextColor3 = Color3.fromRGB(180, 180, 190)
    end

    TweenService:Create(categoryButton, TweenInfo.new(0.2), { BackgroundColor3 = Color3.fromRGB(40, 40, 50) }):Play()
    categoryButton.TextLabel.TextColor3 = Color3.fromRGB(230, 230, 230)
    self.ActiveCategoryButton = categoryButton

    for _, child in ipairs(subTabContainer:GetChildren()) do
        if child:IsA("TextButton") then child:Destroy() end
    end
    self.SubCategoryButtons = {}
    self.ActiveSubCategoryButton = nil

    if self.SubCategories[categoryName] then
        subTabContainer.Visible = true
        contentFrame.Position = UDim2.new(0, 140, 0, 85)
        contentFrame.Size = UDim2.new(1, -150, 1, -105)
        
        local tabCount = #self.SubCategories[categoryName]
        local effectiveTabCount = math.max(4, tabCount)
        local padValue = 5
        local offset = math.floor(((effectiveTabCount - 1) * padValue) / effectiveTabCount)
        
        for i, subName in ipairs(self.SubCategories[categoryName]) do
            local subBtn = Instance.new("TextButton")
            subBtn.Name = subName .. "Btn"
            subBtn.Size = UDim2.new(1/effectiveTabCount, -offset, 1, 0)
            subBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
            subBtn.BorderSizePixel = 0
            subBtn.Text = subName
            subBtn.TextColor3 = Color3.fromRGB(150, 150, 160)
            subBtn.Font = Enum.Font.GothamMedium
            subBtn.TextSize = 12
            subBtn.AutoButtonColor = false
            subBtn.LayoutOrder = i
            subBtn.Parent = subTabContainer
            Instance.new("UICorner", subBtn).CornerRadius = UDim.new(0, 6)
            
            self.SubCategoryButtons[subName] = subBtn
            subBtn.MouseButton1Click:Connect(function()
                self:SwitchSubCategory(categoryName, subName)
            end)
        end
        self:SwitchSubCategory(categoryName, self.SubCategories[categoryName][1])
    else
        subTabContainer.Visible = false
        contentFrame.Position = UDim2.new(0, 140, 0, 50)
        contentFrame.Size = UDim2.new(1, -150, 1, -70)
        self:LoadItems(categoryName)
    end
end

function EQR_UI:SwitchSubCategory(catName, subName)
    local subBtn = self.SubCategoryButtons[subName]
    if not subBtn then return end

    if self.ActiveSubCategoryButton then
        TweenService:Create(self.ActiveSubCategoryButton, TweenInfo.new(0.2), { BackgroundColor3 = Color3.fromRGB(30, 30, 35) }):Play()
        self.ActiveSubCategoryButton.TextColor3 = Color3.fromRGB(150, 150, 160)
    end

    TweenService:Create(subBtn, TweenInfo.new(0.2), { BackgroundColor3 = Color3.fromRGB(50, 50, 60) }):Play()
    subBtn.TextColor3 = Color3.fromRGB(240, 240, 240)
    self.ActiveSubCategoryButton = subBtn

    self:LoadItems(catName .. "_" .. subName)
end

function EQR_UI:LoadItems(storageKey)
    for _, child in ipairs(contentFrame:GetChildren()) do
        if child:IsA("Frame") and child.Name ~= "UIListLayout" and child.Name ~= "UICorner" then
            child.Parent = nil
        end
    end

    if self.CategoryFrames[storageKey] then
        for i, frame in ipairs(self.CategoryFrames[storageKey]) do
            frame.Parent = contentFrame
            frame.LayoutOrder = i
        end
    end
end

function EQR_UI:OnInputBegan(input, gameProcessedEvent)
    if gameProcessedEvent then return end

    local keyCode = input.KeyCode
    if keyCode == Enum.KeyCode.Unknown then return end

    if currentRowWaitingForKey then
        local frame = currentRowWaitingForKey
        local bindButton = bindButtonReferences[frame]
        local getKeyFn = keyBindGetters[frame]
        local setKeyFn = keyBindSetters[frame]
        local frameData = rowFunctionData[frame]

        if bindButton and getKeyFn and setKeyFn and frameData then
            local oldKey = nil
            local successGet, resultGet = pcall(getKeyFn)
            if successGet then oldKey = resultGet end

            if oldKey and activeBinds[oldKey] and activeBinds[oldKey].frame == frame then
                activeBinds[oldKey] = nil
            end

            if activeBinds[keyCode] and activeBinds[keyCode].frame ~= frame then
                local otherFrame = activeBinds[keyCode].frame
                local otherBindButton = bindButtonReferences[otherFrame]
                local otherSetKeyFn = keyBindSetters[otherFrame]
                if otherSetKeyFn then pcall(otherSetKeyFn, nil) end
                if otherBindButton then otherBindButton.Text = "Bind" end
                activeBinds[keyCode] = nil
            end

            pcall(setKeyFn, keyCode)

            local toggleButton
            for _, child in ipairs(frame:GetChildren()) do if child:IsA("TextButton") and child ~= bindButton then toggleButton = child; break end end

            if toggleButton then
                activeBinds[keyCode] = {
                    frame = frame,
                    toggleButton = toggleButton,
                    isEnabledFn = frameData.isEnabledFn,
                    onEnable = frameData.onEnable,
                    onDisable = frameData.onDisable,
                    canToggle = frameData.canToggle,
                    updateFn = frameData.updateFn
                }
            end

            bindButton.Text = "[" .. input.KeyCode.Name .. "]"
            currentRowWaitingForKey = nil
        else
            if bindButton then bindButton.Text = "Bind" end
            currentRowWaitingForKey = nil
        end

    elseif activeBinds[keyCode] then
        local bindInfo = activeBinds[keyCode]
        if bindInfo.frame and bindInfo.isEnabledFn and bindInfo.onEnable and bindInfo.onDisable and bindInfo.updateFn and bindInfo.canToggle ~= nil then
            if bindInfo.canToggle then
                local success, currentState = pcall(bindInfo.isEnabledFn)
                if success then
                    if currentState then
                        pcall(bindInfo.onDisable)
                    else
                        pcall(bindInfo.onEnable)
                    end
                    task.wait()
                    pcall(bindInfo.updateFn)
                end
            end
        end
    end
end

function EQR_UI:Initialize()
    for i, categoryName in ipairs(self.Categories) do
        if self.SubCategories[categoryName] then
            for _, subName in ipairs(self.SubCategories[categoryName]) do
                self.CategoryFrames[categoryName .. "_" .. subName] = {}
            end
        else
            self.CategoryFrames[categoryName] = {}
        end

        local catButton = Instance.new("TextButton")
        catButton.Name = categoryName .. "Button"
        catButton.Size = UDim2.new(1, -10, 0, 30)
        catButton.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
        catButton.BorderSizePixel = 0
        catButton.AutoButtonColor = false
        catButton.LayoutOrder = i
        catButton.Parent = sidebarFrame

        local catCorner = Instance.new("UICorner")
        catCorner.CornerRadius = UDim.new(0, 6)
        catCorner.Parent = catButton
local stroke = Instance.new("UIStroke")
        stroke.Thickness = 1.5
        stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        if categoryName == "Combat" then
            stroke.Color = Color3.fromRGB(115, 90, 250) -- Mov pentru Combat
        else
            stroke.Color = Color3.fromRGB(60, 60, 65) -- Gri pentru restul
        end
        stroke.Parent = catButton

        local catLabel = Instance.new("TextLabel")
        catLabel.Name = "TextLabel"
        catLabel.Size = UDim2.new(1, 0, 1, 0)
        catLabel.BackgroundTransparency = 1
        catLabel.Text = categoryName
        catLabel.Font = Enum.Font.GothamSemibold
        catLabel.TextSize = 14
        catLabel.TextColor3 = Color3.fromRGB(180, 180, 190)
        catLabel.Parent = catButton

        catButton.MouseEnter:Connect(function()
            if catButton ~= self.ActiveCategoryButton then
                TweenService:Create(catButton, TweenInfo.new(0.1), { BackgroundColor3 = Color3.fromRGB(30, 30, 35) }):Play()
            end
        end)
        catButton.MouseLeave:Connect(function()
            if catButton ~= self.ActiveCategoryButton then
                TweenService:Create(catButton, TweenInfo.new(0.1), { BackgroundColor3 = Color3.fromRGB(20, 20, 25) }):Play()
            end
        end)
        catButton.MouseButton1Click:Connect(function()
            -- Facem toate celelalte butoane gri înapoi
            for _, btn in pairs(self.CategoryButtons) do
                if btn:FindFirstChild("UIStroke") then
                    btn.UIStroke.Color = Color3.fromRGB(60, 60, 65)
                end
            end
            -- Facem butonul pe care ai apăsat MOV
            stroke.Color = Color3.fromRGB(115, 90, 250)
            self:SwitchCategory(categoryName)
        end)

        self.CategoryButtons[categoryName] = catButton
    end

    local k = self.KeyBinds

    -- Combat_Melee
    table.insert(self.CategoryFrames.Combat_Melee, createToggleRowFrame("Melee Aura", true, function() return MeleeAura_Enabled end, MeleeAura_Enable, MeleeAura_Disable, function() return k.melee end, function(val) k.melee=val end))
    -- Combat_Aimbots
table.insert(self.CategoryFrames.Combat_Aimbots, createToggleRowFrame("Camera Aimbot", true, 
    function() return AimBotSettings.Enabled end, 
    function() AimBotSettings.Enabled = true end, 
    function() AimBotSettings.Enabled = false end, 
    function() return k.aimbot end, 
    function(val) k.aimbot = val end
))

table.insert(self.CategoryFrames.Combat_Aimbots, createToggleRowFrame("Show FOV Circle", true, 
    function() return AimBotSettings.ShowFOV end, 
    function() AimBotSettings.ShowFOV = true end, 
    function() AimBotSettings.ShowFOV = false end, 
    function() return k.showfov end, 
    function(val) k.showfov = val end
))

table.insert(self.CategoryFrames.Combat_Aimbots, createSliderRowFrame("Aimbot FOV", 0, 500, 100, function(v) 
    AimBotSettings.FOV = v 
    if FOVCircle then FOVCircle.Radius = v end
end))

    AimBotSettings.AimPart = "Head"
    table.insert(self.CategoryFrames.Combat_Aimbots, createDropdownRowFrame("Target Part", 
    {"Head", "Torso", "HumanoidRootPart", "Right Arm", "Left Arm", "Right Leg", "Left Leg", "Random"}, 
    "Head", 
    function(v)
        AimBotSettings.AimPart = v 
        print("Aimbot va ținti: " .. v)
    end
))

table.insert(self.CategoryFrames.Combat_Aimbots, createSliderRowFrame("Aimbot Smoothing", 0, 100, 5, function(v)
    AimBotSettings.Smoothing = v / 100
end))

table.insert(self.CategoryFrames.Combat_Aimbots, createToggleRowFrame("Wall Check", true, 
    function() return AimBotSettings.WallCheck end, 
    function() AimBotSettings.WallCheck = true end, 
    function() AimBotSettings.WallCheck = false end, 
    function() return k.wallcheck end, 
    function(val) k.wallcheck = val end
))

table.insert(self.CategoryFrames.Combat_Aimbots, createToggleRowFrame("Downed Check", true, 
    function() return AimBotSettings.DownedCheck end, 
    function() AimBotSettings.DownedCheck = true; SA.ChkDowned = true end, 
    function() AimBotSettings.DownedCheck = false; SA.ChkDowned = false end, 
    function() return k.downedcheck end, 
    function(val) k.downedcheck = val end
))

local saDivider = Instance.new("Frame")
saDivider.Name = "SADivider"
saDivider.Size = UDim2.new(1, 0, 0, 2)
saDivider.BackgroundColor3 = Color3.fromRGB(45, 45, 50)
saDivider.BorderSizePixel = 0
table.insert(self.CategoryFrames.Combat_Aimbots, saDivider)

table.insert(self.CategoryFrames.Combat_Aimbots, createToggleRowFrame("Silent Aim", true, 
    function() return SA.On end, 
    function() SA_Enable() end, 
    function() SA_Disable() end, 
    function() return k.silentaim end, 
    function(val) k.silentaim = val end
))

table.insert(self.CategoryFrames.Combat_Aimbots, createToggleRowFrame("Silent Show FOV", true, 
    function() return SA.DrawCircle end, 
    function() SA.DrawCircle = true; if SA.On then crFOVCircle() end end, 
    function() SA.DrawCircle = false; if SACircle then SACircle:Remove(); SACircle = nil end end, 
    function() return k.silentshowfov end, 
    function(val) k.silentshowfov = val end
))

table.insert(self.CategoryFrames.Combat_Aimbots, createSliderRowFrame("Head Chance %", 0, 100, 80, function(v) 
    SA.HeadChance = v 
end))

table.insert(self.CategoryFrames.Combat_Aimbots, createSliderRowFrame("Body Chance %", 0, 100, 20, function(v) 
    SA.BodyChance = v 
end))

table.insert(self.CategoryFrames.Combat_Aimbots, createSliderRowFrame("Silent FOV", 10, 500, 100, function(v) 
    SA.DrawSize = v 
    if SACircle then SACircle.Radius = v end
end))

table.insert(self.CategoryFrames.Combat_Aimbots, createSliderRowFrame("Silent Max Dist", 0, 1000, 500, function(v) 
    SA.MaxDist = v 
end))



    table.insert(self.CategoryFrames.Movement_Main, createToggleRowFrame("Fly", true, function() return FlySettings.On end, Fly_Enable, Fly_Disable, function() return k.fly end, function(val) k.fly=val; Fly_Bind=val end))
    table.insert(self.CategoryFrames.Movement_Main, createToggleRowFrame("Noclip", true, function() return Noclip_Enabled end, Noclip_Enable, Noclip_Disable, function() return k.noclip end, function(val) k.noclip=val; Noclip_Bind=val end))
    table.insert(self.CategoryFrames.Movement_Main, createToggleRowFrame("Infinite Stamina", true, function() return InfStamina_Enabled end, InfStamina_Enable, InfStamina_Disable, function() return k.infiniteStamina end, function(val) k.infiniteStamina = val end))

    -- Visuals
    table.insert(self.CategoryFrames.Visuals_ESP, createToggleRowFrame("Player ESP", true, function() return ESP_Enabled end, ESP_Enable, ESP_Disable, function() return k.esp end, function(val) k.esp = val end))
    table.insert(self.CategoryFrames.Visuals_ESP, createSliderRowFrame("Max Distance", 100, 1000, 1000, function(v) 
        ESP_MaxDistance = v 
    end))
    table.insert(self.CategoryFrames.Visuals_ESP, createToggleRowFrame("Safe/Register ESP", true, function() return BredMakurz_Enabled end, BredMakurz_Enable, BredMakurz_Disable, function() return k.safeESP end, function(val) k.safeESP=val end))

    table.insert(self.CategoryFrames.Visuals_World, createToggleRowFrame("Invisibility", true, _G.IsInvisEnabled, _G.Invis_Enable, _G.Invis_Disable, function() return k.invis end, function(val) k.invis=val end))
    table.insert(self.CategoryFrames.Visuals_World, createToggleRowFrame("FullBright", true, function() return FullBright_Enabled end, FullBright_Enable, FullBright_Disable, function() return k.FullBright end, function(val) k.FullBright=val; FullBright_Bind=val end))
    table.insert(self.CategoryFrames.Visuals_World, createToggleRowFrame("FOV", true, function() return Fov_Enabled end, Fov_Enable, Fov_Disable, function() return k.fov end, function(val) k.fov=val; Fov_Bind=val end))
    table.insert(self.CategoryFrames.Visuals_World, createSliderRowFrame("Camera FOV", 50, 120, 80, function(v) 
        Fov_Value = v 
    end))

    -- Farming
    table.insert(self.CategoryFrames.Farming_Farming, createToggleRowFrame("Autofarm", true, function() return autofarmEnabled end, Autofarm_Enable, Autofarm_Disable, function() return k.autofarm end, function(val) k.autofarm=val; Autofarm_Bind=val end))
    
    -- Misc
    table.insert(self.CategoryFrames.Misc_Misc, createToggleRowFrame("Staff Detector", true, function() return AdminCheck_Enabled end, AdminCheck_Enable, AdminCheck_Disable, function() return k.adminCheck end, function(val) k.adminCheck=val end))
    table.insert(self.CategoryFrames.Misc_Misc, createToggleRowFrame("Auto Pickup Money", true, function() return AutoPickupMoney_Enabled end, AutoPickupMoney_Enable, AutoPickupMoney_Disable, function() return k.autoPickupMoney end, function(val) k.autoPickupMoney=val end))
    table.insert(self.CategoryFrames.Misc_Misc, createToggleRowFrame("No Fail Lockpick", true, function() return NoFailLockpick_Enabled end, NoFailLockpick_Enable, NoFailLockpick_Disable, function() return k.noFailLockpick end, function(val) k.noFailLockpick=val end))
    table.insert(self.CategoryFrames.Misc_Misc, createToggleRowFrame("Auto Unlock Doors", true, function() return UnlockNearbyDoors_Enabled end, UnlockNearbyDoors_Enable, UnlockNearbyDoors_Disable, function() return k.unlockNearbyDoors end, function(val) k.unlockNearbyDoors=val end))
    table.insert(self.CategoryFrames.Misc_Misc, createToggleRowFrame("Auto Open Doors", true, function() return OpenNearbyDoors_Enabled end, OpenNearbyDoors_Enable, OpenNearbyDoors_Disable, function() return k.openNearbyDoors end, function(val) k.openNearbyDoors=val end))

    -- Combat_Rage
    table.insert(self.CategoryFrames.Combat_Rage, createToggleRowFrame("Ragebot", true, function() return Ragebot_Enabled end, Ragebot_Enable, Ragebot_Disable, function() return k.ragebot end, function(val) k.ragebot=val end))
    
    UserInputService.InputBegan:Connect(function(...) self:OnInputBegan(...) end)
    PlayerGui.ChildAdded:Connect(function(Item)
        if Item.Name == "LockpickGUI" then
        end
    end)
    
    self:SwitchCategory(self.DefaultCategory)
    
    mainFrame.Size = UDim2.new(0, 0, 0, 0)
    local openTween = TweenService:Create(mainFrame, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = UDim2.new(0, 450, 0, 350) })
    task.wait(0.1)
    openTween:Play()
    
    print("EQR Hub Loaded.")
end

-------------------------------------------------------------------------------
-- 3. ЗАПУСК
-------------------------------------------------------------------------------
EQR_UI:Initialize()
-------------------------------------------------------------------------------
-- 4. LOGICA DE AIMBOT (MULTI-PART DETECTION & ULTRA-STICKY)
-------------------------------------------------------------------------------

local LockedTarget = nil 

local function isDowned(character)
    if not character then return false end
    local humanoid = character:FindFirstChild("Humanoid")
    if humanoid then
        local state = humanoid:GetState()
        if state == Enum.HumanoidStateType.Dead or state == Enum.HumanoidStateType.PlatformStanding or state == Enum.HumanoidStateType.Ragdoll or state == Enum.HumanoidStateType.FallingDown then
            return true
        end
        if humanoid.Health <= 0 then
            return true
        end
    end
    -- Da Hood specific K.O. check
    local bodyEffects = character:FindFirstChild("BodyEffects")
    if bodyEffects then
        local ko = bodyEffects:FindFirstChild("K.O") or bodyEffects:FindFirstChild("KO")
        if ko and (ko.Value == true or ko.Value == 1) then
            return true
        end
        local dead = bodyEffects:FindFirstChild("Dead")
        if dead and (dead.Value == true or dead.Value == 1) then
            return true
        end
    end
    return false
end

local function GetClosestTarget()
    local target = nil
    local mousePos = game:GetService("UserInputService"):GetMouseLocation()
    local cam = workspace.CurrentCamera
    local lp = game.Players.LocalPlayer
    local char = lp.Character
    
    local maxLimit = AimBotSettings.FOV or 100
    local bestScore = math.huge 

    local R6Parts = {"Head", "Torso", "HumanoidRootPart", "Left Arm", "Right Arm", "Left Leg", "Right Leg"}

    for _, p in pairs(game.Players:GetPlayers()) do
        if p ~= lp and p.Character then
            local humanoid = p.Character:FindFirstChild("Humanoid")
            local hrp = p.Character:FindFirstChild("HumanoidRootPart")
            if humanoid and hrp and humanoid.Health > 0 then
                
                if AimBotSettings.DownedCheck and isDowned(p.Character) then
                    continue
                end

                local charHrp = char and char:FindFirstChild("HumanoidRootPart")
                if not charHrp then continue end
                
                local distInStuds = (hrp.Position - charHrp.Position).Magnitude
                if distInStuds > 600 then continue end

                if AimBotSettings.WallCheck then
                    local head = p.Character:FindFirstChild("Head") or hrp
                    local ray = Ray.new(cam.CFrame.Position, (head.Position - cam.CFrame.Position).Unit * 1000)
                    local hit = workspace:FindPartOnRayWithIgnoreList(ray, {char, cam})
                    if hit and not hit:IsDescendantOf(p.Character) then
                        continue
                    end
                end

                for _, partName in pairs(R6Parts) do
                    local part = p.Character:FindFirstChild(partName)
                    
                    if part and part:IsA("BasePart") then
                        local pos, onScreen = cam:WorldToViewportPoint(part.Position)
                        
                        if onScreen then
                            local screenPos = Vector2.new(pos.X, pos.Y)
                            local distFromMouse = (screenPos - mousePos).Magnitude
                            
                            if distFromMouse <= maxLimit then
                                local score = distFromMouse + (distInStuds * 2) 

                                if score < bestScore then
                                    bestScore = score
                                    target = p
                                end
                                break 
                            end
                        end
                    end
                end
            end
        end
    end
    return target
end

game:GetService("RunService").RenderStepped:Connect(function()
    local UserInputService = game:GetService("UserInputService")
    local mouseLoc = UserInputService:GetMouseLocation()
    
    -- Cerc FOV Camera
    if AimBotSettings.Enabled and AimBotSettings.ShowFOV then
        FOVCircle.Visible = true
        FOVCircle.Radius = AimBotSettings.FOV or 100
        FOVCircle.Position = mouseLoc
    else
        FOVCircle.Visible = false
    end

    -- Logica Aimbot
    if AimBotSettings.Enabled and UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
        local isTargetValid = false
        
        if LockedTarget and LockedTarget.Character then
            local hum = LockedTarget.Character:FindFirstChild("Humanoid")
            local targetPart = nil
            if AimBotSettings.AimPart == "Random" then
                targetPart = LockedTarget.Character:FindFirstChild("HumanoidRootPart") or LockedTarget.Character:FindFirstChild("Head")
            else
                targetPart = LockedTarget.Character:FindFirstChild(AimBotSettings.AimPart or "Head")
            end
            
            if hum and hum.Health > 0 and targetPart then
                isTargetValid = true
                if AimBotSettings.DownedCheck and isDowned(LockedTarget.Character) then
                    isTargetValid = false
                end
                
                if isTargetValid and AimBotSettings.WallCheck then
                    local cam = workspace.CurrentCamera
                    local char = game.Players.LocalPlayer.Character
                    local head = LockedTarget.Character:FindFirstChild("Head") or LockedTarget.Character:FindFirstChild("HumanoidRootPart")
                    if head and char then
                        local ray = Ray.new(cam.CFrame.Position, (head.Position - cam.CFrame.Position).Unit * 1000)
                        local hit = workspace:FindPartOnRayWithIgnoreList(ray, {char, cam})
                        if hit and not hit:IsDescendantOf(LockedTarget.Character) then
                            isTargetValid = false
                        end
                    end
                end
            end
            
            if not isTargetValid then
                LockedTarget = nil
            end
        end

        if not isTargetValid then
            LockedTarget = GetClosestTarget()
        end

        if LockedTarget and LockedTarget.Character then
            local finalPart = nil
            
            if AimBotSettings.AimPart == "Random" then
                local closestPart = nil
                local shortestDist = math.huge
                local mousePos = UserInputService:GetMouseLocation()
                local cam = workspace.CurrentCamera
                
                for _, part in ipairs(LockedTarget.Character:GetChildren()) do
                    if part:IsA("BasePart") then
                        local pos, onScreen = cam:WorldToViewportPoint(part.Position)
                        if onScreen then
                            local dist = (Vector2.new(pos.X, pos.Y) - mousePos).Magnitude
                            if dist < shortestDist then
                                closestPart = part
                                shortestDist = dist
                            end
                        end
                    end
                end
                finalPart = closestPart
            else
                finalPart = LockedTarget.Character:FindFirstChild(AimBotSettings.AimPart or "Head")
            end
            
            if finalPart then
                local cam = workspace.CurrentCamera
                local hitPosition = finalPart.Position

                local lookAt = CFrame.lookAt(cam.CFrame.Position, hitPosition)
                local smoothVal = AimBotSettings.Smoothing or 0.05
                cam.CFrame = cam.CFrame:Lerp(lookAt, smoothVal)
            end
        end
    else
        LockedTarget = nil
    end
end)
