-- ╔══════════════════════════════════════════════╗
-- ║           SCRAP AUTOFARM                     ║
-- ║  Invis · FastInteract · AutoPickup · ESP     ║
-- ╚══════════════════════════════════════════════╝

local Players        = game:GetService("Players")
local RunService     = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService   = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local LP   = Players.LocalPlayer
local Cam  = workspace.CurrentCamera

-- ── Obsidian UI ─────────────────────────────────────────────
local Library = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/deividcomsono/Obsidian/refs/heads/main/Library.lua"
))()

local Window = Library:CreateWindow({
    Title    = "Scrap Farm",
    Center   = true,
    AutoShow = true,
})

local Tab      = Window:AddTab("Farm", "box")
local GB_L     = Tab:AddLeftGroupbox("Main")
local GB_R     = Tab:AddRightGroupbox("Settings")
local TabESP   = Window:AddTab("ESP", "eye")
local GB_ESP   = TabESP:AddLeftGroupbox("World ESP")

-- ═══════════════════════════════════════════════════════════
--  INVISIBILITY
-- ═══════════════════════════════════════════════════════════
local InvisActive   = false
local InvisPossible = true
local InvisAnimTrack = nil
local InvisAnim = Instance.new("Animation")
InvisAnim.AnimationId = "rbxassetid://215384594"

local InvisWarningGui = Instance.new("ScreenGui")
InvisWarningGui.Name = "ScrapFarm_InvisWarn"
InvisWarningGui.ResetOnSpawn = false
pcall(function() InvisWarningGui.Parent = game:GetService("CoreGui") end)
if not InvisWarningGui.Parent then InvisWarningGui.Parent = LP:WaitForChild("PlayerGui") end

local InvisWarningLabel = Instance.new("TextLabel", InvisWarningGui)
InvisWarningLabel.Text = "⚠️ YOU ARE VISIBLE ⚠️"
InvisWarningLabel.Visible = false
InvisWarningLabel.Size = UDim2.new(0, 300, 0, 30)
InvisWarningLabel.Position = UDim2.new(0.5, -150, 0.85, 0)
InvisWarningLabel.BackgroundTransparency = 1
InvisWarningLabel.Font = Enum.Font.GothamSemibold
InvisWarningLabel.TextSize = 24
InvisWarningLabel.TextColor3 = Color3.fromRGB(255, 255, 0)
InvisWarningLabel.TextStrokeTransparency = 0.5
InvisWarningLabel.ZIndex = 10

local function isGrounded()
    local char = LP.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    return hum and hum:IsDescendantOf(workspace) and hum.FloorMaterial ~= Enum.Material.Air
end

local function loadInvisAnim()
    if InvisAnimTrack then pcall(function() InvisAnimTrack:Stop() end); InvisAnimTrack = nil end
    local char = LP.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if hum then
        local ok, track = pcall(function() return hum:LoadAnimation(InvisAnim) end)
        if ok then
            InvisAnimTrack = track
            InvisAnimTrack.Priority = Enum.AnimationPriority.Action4
        end
    end
end

local function disableInvis()
    if not InvisActive then return end
    InvisActive = false
    if InvisAnimTrack then pcall(function() InvisAnimTrack:Stop() end) end
    local char = LP.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if hum then Cam.CameraSubject = hum end
    if char then
        for _, part in pairs(char:GetDescendants()) do
            if part:IsA("BasePart") and part.Transparency == 0.5 then
                part.Transparency = 0
            end
        end
    end
    InvisWarningLabel.Visible = false
end

local function enableInvis()
    if InvisActive or not InvisPossible then return end
    local char = LP.Character
    local hum  = char and char:FindFirstChildOfClass("Humanoid")
    local hrp  = char and char:FindFirstChild("HumanoidRootPart")
    if not char or not hum or not hrp then return end
    if not char:FindFirstChild("Torso") then InvisPossible = false; return end
    InvisActive = true
    Cam.CameraSubject = hrp
    loadInvisAnim()
end

LP.CharacterAdded:Connect(function(newChar)
    if InvisAnimTrack then pcall(function() InvisAnimTrack:Stop() end); InvisAnimTrack = nil end
    task.wait()
    local hum = newChar:WaitForChild("Humanoid", 5)
    if hum and hum.RigType == Enum.HumanoidRigType.R6 then
        InvisPossible = true
        if InvisActive then
            local hrp = newChar:FindFirstChild("HumanoidRootPart")
            if hrp then Cam.CameraSubject = hrp end
            loadInvisAnim()
        end
    else
        InvisPossible = false
        if InvisActive then disableInvis() end
    end
end)

RunService.Heartbeat:Connect(function(dt)
    if not InvisActive or not InvisPossible then
        if not InvisActive and LP.Character then
            for _, part in pairs(LP.Character:GetDescendants()) do
                if part:IsA("BasePart") and part.Transparency == 0.5 then
                    part.Transparency = 0
                end
            end
        end
        InvisWarningLabel.Visible = false
        return
    end
    local char = LP.Character
    local hum  = char and char:FindFirstChildOfClass("Humanoid")
    local hrp  = char and char:FindFirstChild("HumanoidRootPart")
    if not char or not hum or not hrp or not hum:IsDescendantOf(workspace) or hum.Health <= 0 then
        InvisWarningLabel.Visible = false
        return
    end
    InvisWarningLabel.Visible = not isGrounded()
    local speed = 12
    if hum.MoveDirection.Magnitude > 0 then
        hrp.CFrame = hrp.CFrame + hum.MoveDirection * speed * dt
    end
    local origCF  = hrp.CFrame
    local origCam = hum.CameraOffset
    local _, yaw  = Cam.CFrame:ToOrientation()
    hrp.CFrame = CFrame.new(hrp.Position) * CFrame.fromOrientation(0, yaw, 0)
    hrp.CFrame = hrp.CFrame * CFrame.Angles(math.rad(90), 0, 0)
    hum.CameraOffset = Vector3.new(0, 1.44, 0)
    if InvisAnimTrack then
        local ok = pcall(function()
            if not InvisAnimTrack.IsPlaying then InvisAnimTrack:Play() end
            InvisAnimTrack:AdjustSpeed(0)
            InvisAnimTrack.TimePosition = 0.3
        end)
        if not ok then loadInvisAnim() end
    elseif hum and hum.Health > 0 then loadInvisAnim() end
    RunService.RenderStepped:Wait()
    if hum and hum:IsDescendantOf(workspace) then hum.CameraOffset = origCam end
    if hrp and hrp:IsDescendantOf(workspace) then hrp.CFrame = origCF end
    if InvisAnimTrack then pcall(function() InvisAnimTrack:Stop() end) end
    if hrp and hrp:IsDescendantOf(workspace) then
        local lv  = Cam.CFrame.LookVector
        local fl  = Vector3.new(lv.X, 0, lv.Z).Unit
        if fl.Magnitude > 0.1 then hrp.CFrame = CFrame.new(hrp.Position, hrp.Position + fl) end
    end
    if char then
        for _, part in pairs(char:GetDescendants()) do
            if part:IsA("BasePart") and part.Transparency ~= 1 then
                part.Transparency = 0.5
            end
        end
    end
end)

-- ═══════════════════════════════════════════════════════════
--  FAST INTERACT
-- ═══════════════════════════════════════════════════════════
local FastInteractConn   = nil
local FastInteractConns  = {}
local FastInteractOn     = false

local function applyFastInteract(obj)
    if not obj:IsA("ProximityPrompt") then return end
    if not obj:GetAttribute("OriginalHoldDuration") then
        obj:SetAttribute("OriginalHoldDuration", obj.HoldDuration)
    end
    obj.HoldDuration = 0
    local c = obj.Triggered:Connect(function()
        if FastInteractOn then task.wait(0.05); obj.HoldDuration = 0 end
    end)
    table.insert(FastInteractConns, c)
end

local function SetFastInteract(v)
    FastInteractOn = v
    for _, c in pairs(FastInteractConns) do pcall(function() c:Disconnect() end) end
    FastInteractConns = {}
    if FastInteractConn then FastInteractConn:Disconnect(); FastInteractConn = nil end
    if not v then
        for _, obj in pairs(workspace:GetDescendants()) do
            if obj:IsA("ProximityPrompt") then
                local orig = obj:GetAttribute("OriginalHoldDuration")
                if orig then obj.HoldDuration = orig end
            end
        end
        return
    end
    for _, obj in pairs(workspace:GetDescendants()) do applyFastInteract(obj) end
    FastInteractConn = workspace.DescendantAdded:Connect(function(obj)
        if FastInteractOn then task.wait(0.1); applyFastInteract(obj) end
    end)
end

-- ═══════════════════════════════════════════════════════════
--  AUTO PICKUP JUNK (SCRAPS)
-- ═══════════════════════════════════════════════════════════
local AutoPickupConn = nil

local function SetAutoPickup(v)
    if AutoPickupConn then AutoPickupConn:Disconnect(); AutoPickupConn = nil end
    if not v then return end
    AutoPickupConn = RunService.Heartbeat:Connect(function()
        local now = tick()
        if now - (AutoPickupConn.LastPickup or 0) < 0.8 then return end
        local char = LP.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if not root then return end
        local remote = ReplicatedStorage.Events:FindFirstChild("PIC_PU")
        local filter = workspace:FindFirstChild("Filter")
        local folder = filter and filter:FindFirstChild("SpawnedPiles")
        if not remote or not folder then return end
        local closest, bestDist = nil, math.huge
        for _, a in ipairs(folder:GetChildren()) do
            local mesh = a:FindFirstChildOfClass("MeshPart") or a:FindFirstChildOfClass("Part")
            if mesh then
                local d = (root.Position - mesh.Position).Magnitude
                if d < bestDist then bestDist = d; closest = a end
            end
        end
        if closest then
            AutoPickupConn.LastPickup = now
            local attr = closest:GetAttribute("jzu")
            if attr then
                pcall(function() remote:FireServer(string.reverse(tostring(attr))) end)
            else
                pcall(function() remote:FireServer(closest) end)
            end
        end
    end)
end

-- ═══════════════════════════════════════════════════════════
--  SCRAP AUTOFARM (идёт к скрапу, открывает, подбирает)
-- ═══════════════════════════════════════════════════════════
local FarmActive    = false
local FarmThread    = nil
local FarmStatus    = "Idle"
local FarmRadius    = 60  -- радиус поиска скрапа

local function getScrapPiles()
    local filter = workspace:FindFirstChild("Filter")
    local folder = filter and filter:FindFirstChild("SpawnedPiles")
    if not folder then return {} end
    local result = {}
    for _, a in ipairs(folder:GetChildren()) do
        local mesh = a:FindFirstChildOfClass("MeshPart") or a:FindFirstChildOfClass("Part")
        if mesh then table.insert(result, {model = a, part = mesh}) end
    end
    return result
end

local function tweenTo(hrp, targetPos)
    local dist = (hrp.Position - targetPos).Magnitude
    if dist < 3 then return end
    local duration = dist / 28
    local tween = TweenService:Create(hrp, TweenInfo.new(duration, Enum.EasingStyle.Linear), {
        CFrame = CFrame.new(targetPos + Vector3.new(0, 3, 0), targetPos)
    })
    tween:Play()
    tween.Completed:Wait()
end

local function farmLoop()
    local remote = ReplicatedStorage.Events:FindFirstChild("PIC_PU")
    while FarmActive do
        local char = LP.Character
        local hrp  = char and char:FindFirstChild("HumanoidRootPart")
        local hum  = char and char:FindFirstChildOfClass("Humanoid")
        if not hrp or not hum or hum.Health <= 0 then task.wait(1); continue end

        local piles = getScrapPiles()
        if #piles == 0 then
            FarmStatus = "Waiting for scraps..."
            task.wait(1)
            continue
        end

        -- ищем ближайший скрап
        local closest, bestDist = nil, math.huge
        for _, p in ipairs(piles) do
            local d = (hrp.Position - p.part.Position).Magnitude
            if d < bestDist then bestDist = d; closest = p end
        end

        if not closest then task.wait(0.5); continue end

        FarmStatus = "Moving to scrap..."

        -- идём к скрапу
        local targetPos = closest.part.Position
        local dist = (hrp.Position - targetPos).Magnitude

        if dist > 4 then
            -- телепортируем через tween
            hrp.CFrame = CFrame.new(targetPos + Vector3.new(0, 3, 0))
            task.wait(0.2)
        end

        FarmStatus = "Picking up..."

        -- подбираем
        if remote then
            local model = closest.model
            local attr  = model:GetAttribute("jzu")
            if attr then
                pcall(function() remote:FireServer(string.reverse(tostring(attr))) end)
            else
                pcall(function() remote:FireServer(model) end)
            end
        end

        -- открываем ProximityPrompt если есть
        for _, desc in ipairs(closest.model:GetDescendants()) do
            if desc:IsA("ProximityPrompt") then
                pcall(function()
                    local args = {desc}
                    game:GetService("ProximityPromptService"):PromptTriggered(desc, LP)
                end)
                pcall(function()
                    fireclickdetector(desc)
                end)
                pcall(function()
                    desc.HoldDuration = 0
                    desc:InputHoldBegin()
                    task.wait(0.1)
                    desc:InputHoldEnd()
                end)
                break
            end
        end

        task.wait(0.5)
    end
    FarmStatus = "Idle"
end

local function StartFarm()
    if FarmActive then return end
    FarmActive = true
    FarmThread = task.spawn(farmLoop)
end

local function StopFarm()
    FarmActive = false
    FarmStatus = "Idle"
    if FarmThread then task.cancel(FarmThread); FarmThread = nil end
end

-- ═══════════════════════════════════════════════════════════
--  SCRAP ESP (Drawing)
-- ═══════════════════════════════════════════════════════════
local ScrapESPOn    = false
local ScrapESPConns = {}
local ScrapLabels   = {}

local function clearScrapESP()
    for _, lbl in pairs(ScrapLabels) do
        pcall(function() lbl:Remove() end)
    end
    ScrapLabels = {}
end

local ScrapESPConn = nil
local function SetScrapESP(v)
    ScrapESPOn = v
    if ScrapESPConn then ScrapESPConn:Disconnect(); ScrapESPConn = nil end
    if not v then clearScrapESP(); return end

    ScrapESPConn = RunService.RenderStepped:Connect(function()
        clearScrapESP()
        if not ScrapESPOn then return end
        local piles = getScrapPiles()
        for _, p in ipairs(piles) do
            local part = p.part
            if not part or not part:IsDescendantOf(workspace) then continue end
            local screenPos, onScreen = Cam:WorldToViewportPoint(part.Position)
            if not onScreen then continue end
            local dist = (LP.Character and LP.Character:FindFirstChild("HumanoidRootPart") and
                (LP.Character.HumanoidRootPart.Position - part.Position).Magnitude) or 0

            local lbl = Drawing.new("Text")
            lbl.Text = string.format("Scrap [%.0f]", dist)
            lbl.Size = 14
            lbl.Color = Color3.fromRGB(255, 220, 0)
            lbl.Outline = true
            lbl.OutlineColor = Color3.fromRGB(0, 0, 0)
            lbl.Center = true
            lbl.Position = Vector2.new(screenPos.X, screenPos.Y)
            lbl.Visible = true
            table.insert(ScrapLabels, lbl)
        end
    end)
end

-- ═══════════════════════════════════════════════════════════
--  UI
-- ═══════════════════════════════════════════════════════════

-- Status label
local StatusLabel = GB_L:AddLabel("Status: Idle")

RunService.Heartbeat:Connect(function()
    if StatusLabel then
        pcall(function() StatusLabel:SetText("Status: " .. FarmStatus) end)
    end
end)

-- Farm controls
GB_L:AddToggle("SF_Invis", {
    Text     = "Invisibility",
    Default  = false,
    Callback = function(v)
        if v then enableInvis() else disableInvis() end
    end,
})

GB_L:AddToggle("SF_Farm", {
    Text     = "Start Farm",
    Default  = false,
    Callback = function(v)
        if v then StartFarm() else StopFarm() end
    end,
})

GB_L:AddToggle("SF_AutoPickup", {
    Text     = "Auto Pickup Junk",
    Default  = false,
    Callback = function(v) SetAutoPickup(v) end,
})

GB_L:AddToggle("SF_FastInteract", {
    Text     = "Fast Interact",
    Default  = false,
    Callback = function(v) SetFastInteract(v) end,
})

-- ESP tab
GB_ESP:AddToggle("SF_ScrapESP", {
    Text     = "Scrap ESP",
    Default  = false,
    Callback = function(v) SetScrapESP(v) end,
})

-- Cleanup on unload
Library.Unloaded:Connect(function()
    StopFarm()
    SetAutoPickup(false)
    SetFastInteract(false)
    SetScrapESP(false)
    disableInvis()
    InvisWarningGui:Destroy()
end)
