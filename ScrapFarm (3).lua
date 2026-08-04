-- ╔══════════════════════════════════════════════╗
-- ║           SCRAP AUTOFARM                     ║
-- ║  Invis · FastInteract · AutoPickup · ESP     ║
-- ╚══════════════════════════════════════════════╝

local Players             = game:GetService("Players")
local RunService          = game:GetService("RunService")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local PathfindingService  = game:GetService("PathfindingService")
local TweenService        = game:GetService("TweenService")

local LP  = Players.LocalPlayer
local Cam = workspace.CurrentCamera

-- ── Obsidian UI ─────────────────────────────────────────────
local Library = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/deividcomsono/Obsidian/refs/heads/main/Library.lua"
))()

local Window  = Library:CreateWindow({ Title = "Scrap Farm", Center = true, AutoShow = true })
local Tab     = Window:AddTab("Farm",  "box")
local GB_L    = Tab:AddLeftGroupbox("Main")
local GB_R    = Tab:AddRightGroupbox("Settings")
local TabESP  = Window:AddTab("ESP",   "eye")
local GB_ESP  = TabESP:AddLeftGroupbox("World ESP")

-- ════════════════════════════════════════════════════════════
--  PATHFINDING
-- ════════════════════════════════════════════════════════════
local MoveSpeed = 22
local FarmActive = false

local function ComputePath(startPos, endPos)
    local configs = {
        { Radius = 1,   Height = 4,   Spacing = 2   },
        { Radius = 1.2, Height = 4.5, Spacing = 2.5 },
        { Radius = 1.5, Height = 5,   Spacing = 3   },
        { Radius = 2,   Height = 5.5, Spacing = 4   },
        { Radius = 2.5, Height = 6,   Spacing = 5   },
        { Radius = 3,   Height = 6.5, Spacing = 5   },
        { Radius = 3.5, Height = 7,   Spacing = 6   },
        { Radius = 4,   Height = 7.5, Spacing = 6   },
        { Radius = 1,   Height = 8,   Spacing = 3   },
        { Radius = 5,   Height = 5,   Spacing = 5   },
    }
    for _, cfg in ipairs(configs) do
        local p = PathfindingService:CreatePath({
            AgentRadius   = cfg.Radius,
            AgentHeight   = cfg.Height,
            AgentCanJump  = true,
            AgentCanClimb = true,
            WaypointSpacing = cfg.Spacing,
        })
        local ok = pcall(function() p:ComputeAsync(startPos, endPos) end)
        if ok and p.Status == Enum.PathStatus.Success then
            local wps = p:GetWaypoints()
            if wps and #wps >= 2 then return wps end
        end
        task.wait(0.05)
    end
    return nil
end

-- Идём по вейпоинтам через HRP Tween (как в примере — без телепорта)
local function WalkToPos(targetPos)
    local char     = LP.Character
    local hrp      = char and char:FindFirstChild("HumanoidRootPart")
    local humanoid = char and char:FindFirstChildOfClass("Humanoid")
    if not hrp or not humanoid then return false end

    local startPos = hrp.Position
    local dist0    = (startPos - targetPos).Magnitude
    if dist0 < 3 then return true end

    local waypoints = ComputePath(startPos, targetPos)
    if not waypoints then
        -- путь не найден — пробуем прямой MoveTo гуманоида
        humanoid:MoveTo(targetPos)
        local reached = false
        humanoid.MoveToFinished:Connect(function(r) reached = r end)
        local t = tick()
        while not reached and tick() - t < 8 and FarmActive do task.wait(0.1) end
        return reached
    end

    for _, wp in ipairs(waypoints) do
        if not FarmActive then return false end
        local char2 = LP.Character
        local hrp2  = char2 and char2:FindFirstChild("HumanoidRootPart")
        if not hrp2 then return false end

        local wpHRP = wp.Position + Vector3.new(0, 2.5, 0)
        local d     = (wpHRP - hrp2.Position).Magnitude
        if d > 0.3 then
            local rot  = hrp2.CFrame - hrp2.CFrame.Position
            local goal = CFrame.new(wpHRP) * rot
            local tw   = TweenService:Create(hrp2,
                TweenInfo.new(d / MoveSpeed, Enum.EasingStyle.Linear),
                { CFrame = goal })
            tw:Play()
            tw.Completed:Wait()
        end
        if wp.Action == Enum.PathWaypointAction.Jump then
            local hum2 = char2 and char2:FindFirstChildOfClass("Humanoid")
            if hum2 then hum2.Jump = true end
            task.wait(0.15)
        end
    end
    return true
end

-- ════════════════════════════════════════════════════════════
--  FAST INTERACT
-- ════════════════════════════════════════════════════════════
local FastInteractConn  = nil
local FastInteractConns = {}
local FastInteractOn    = false

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

-- ════════════════════════════════════════════════════════════
--  AUTO PICKUP JUNK
-- ════════════════════════════════════════════════════════════
local AutoPickupConn = nil

local function SetAutoPickup(v)
    if AutoPickupConn then AutoPickupConn:Disconnect(); AutoPickupConn = nil end
    if not v then return end
    AutoPickupConn = RunService.Heartbeat:Connect(function()
        local now = tick()
        if now - (AutoPickupConn.LastPickup or 0) < 0.8 then return end
        local char   = LP.Character
        local root   = char and char:FindFirstChild("HumanoidRootPart")
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
            if attr then pcall(function() remote:FireServer(string.reverse(tostring(attr))) end)
            else pcall(function() remote:FireServer(closest) end) end
        end
    end)
end

-- ════════════════════════════════════════════════════════════
--  SCRAP AUTOFARM
-- ════════════════════════════════════════════════════════════
local FarmThread  = nil
local FarmStatus  = "Idle"
local MaxRuns     = 5   -- количество скрапов за один запуск
local InteractTime = 5  -- секунд на взаимодействие и подбор

local function getScrapPiles()
    local filter = workspace:FindFirstChild("Filter")
    local folder = filter and filter:FindFirstChild("SpawnedPiles")
    if not folder then return {} end
    local result = {}
    for _, a in ipairs(folder:GetChildren()) do
        local mesh = a:FindFirstChildOfClass("MeshPart") or a:FindFirstChildOfClass("Part")
        if mesh then table.insert(result, { model = a, part = mesh }) end
    end
    return result
end

local function pickupScrap(model)
    local remote = ReplicatedStorage.Events:FindFirstChild("PIC_PU")
    if not remote then return end
    local attr = model:GetAttribute("jzu")
    if attr then pcall(function() remote:FireServer(string.reverse(tostring(attr))) end)
    else pcall(function() remote:FireServer(model) end) end
end

local function triggerPrompts(model)
    for _, desc in ipairs(model:GetDescendants()) do
        if desc:IsA("ProximityPrompt") then
            desc.HoldDuration = 0
            pcall(function() desc:InputHoldBegin() end)
            task.wait(0.2)
            pcall(function() desc:InputHoldEnd() end)
        end
    end
end

local function farmLoop()
    local count = 0
    while FarmActive and count < MaxRuns do
        local char = LP.Character
        local hrp  = char and char:FindFirstChild("HumanoidRootPart")
        local hum  = char and char:FindFirstChildOfClass("Humanoid")

        if not hrp or not hum or hum.Health <= 0 then
            FarmStatus = "Waiting for character..."
            task.wait(1)
            continue
        end

        local piles = getScrapPiles()
        if #piles == 0 then
            FarmStatus = "No scraps found, waiting..."
            task.wait(2)
            continue
        end

        -- ищем ближайший скрап
        local closest, bestDist = nil, math.huge
        for _, p in ipairs(piles) do
            local d = (hrp.Position - p.part.Position).Magnitude
            if d < bestDist then bestDist = d; closest = p end
        end
        if not closest then task.wait(0.5); continue end

        count = count + 1
        FarmStatus = string.format("Moving to scrap [%d/%d]...", count, MaxRuns)

        -- идём через pathfinding
        local targetPos = closest.part.Position
        local arrived = WalkToPos(targetPos)
        if not FarmActive then break end

        if arrived then
            FarmStatus = string.format("Interacting [%d/%d]...", count, MaxRuns)

            -- 5 секунд на взаимодействие и подбор
            local deadline = tick() + InteractTime
            repeat
                triggerPrompts(closest.model)
                pickupScrap(closest.model)
                task.wait(0.3)
            until tick() >= deadline or not FarmActive or not closest.model.Parent
        end
    end

    FarmStatus = "Done (" .. MaxRuns .. " scraps)"
    FarmActive = false

    -- выключаем тогл в UI
    if Toggles and Toggles["SF_Farm"] then
        Toggles["SF_Farm"]:SetValue(false)
    end
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

-- ════════════════════════════════════════════════════════════
--  ИНВИЗ (точная копия из сурса)
-- ════════════════════════════════════════════════════════════
local InvisActive    = false
local InvisPossible  = true
local InvisAnimTrack = nil
local InvisAnim      = Instance.new("Animation")
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
    local hum  = char and char:FindFirstChildOfClass("Humanoid")
    return hum and hum:IsDescendantOf(workspace) and hum.FloorMaterial ~= Enum.Material.Air
end

local function loadInvisAnim()
    if InvisAnimTrack then pcall(function() InvisAnimTrack:Stop() end); InvisAnimTrack = nil end
    local char = LP.Character
    local hum  = char and char:FindFirstChildOfClass("Humanoid")
    if hum then
        local ok, track = pcall(function() return hum:LoadAnimation(InvisAnim) end)
        if ok then InvisAnimTrack = track; InvisAnimTrack.Priority = Enum.AnimationPriority.Action4 end
    end
end

local function disableInvis()
    if not InvisActive then return end
    InvisActive = false
    if InvisAnimTrack then pcall(function() InvisAnimTrack:Stop() end) end
    local char = LP.Character
    local hum  = char and char:FindFirstChildOfClass("Humanoid")
    if hum then Cam.CameraSubject = hum end
    if char then
        for _, p in pairs(char:GetDescendants()) do
            if p:IsA("BasePart") and p.Transparency == 0.5 then p.Transparency = 0 end
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
            for _, p in pairs(LP.Character:GetDescendants()) do
                if p:IsA("BasePart") and p.Transparency == 0.5 then p.Transparency = 0 end
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
        local lv = Cam.CFrame.LookVector
        local fl = Vector3.new(lv.X, 0, lv.Z).Unit
        if fl.Magnitude > 0.1 then hrp.CFrame = CFrame.new(hrp.Position, hrp.Position + fl) end
    end
    if char then
        for _, p in pairs(char:GetDescendants()) do
            if p:IsA("BasePart") and p.Transparency ~= 1 then p.Transparency = 0.5 end
        end
    end
end)

-- ════════════════════════════════════════════════════════════
--  SCRAP ESP
-- ════════════════════════════════════════════════════════════
local ScrapESPOn   = false
local ScrapLabels  = {}
local ScrapESPConn = nil

local function clearScrapESP()
    for _, lbl in pairs(ScrapLabels) do pcall(function() lbl:Remove() end) end
    ScrapLabels = {}
end

local function SetScrapESP(v)
    ScrapESPOn = v
    if ScrapESPConn then ScrapESPConn:Disconnect(); ScrapESPConn = nil end
    if not v then clearScrapESP(); return end
    ScrapESPConn = RunService.RenderStepped:Connect(function()
        clearScrapESP()
        local char = LP.Character
        local hrp  = char and char:FindFirstChild("HumanoidRootPart")
        for _, p in ipairs(getScrapPiles()) do
            local screenPos, onScreen = Cam:WorldToViewportPoint(p.part.Position)
            if not onScreen then continue end
            local dist = hrp and math.floor((hrp.Position - p.part.Position).Magnitude) or 0
            local lbl = Drawing.new("Text")
            lbl.Text = string.format("Scrap [%d]", dist)
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

-- ════════════════════════════════════════════════════════════
--  UI
-- ════════════════════════════════════════════════════════════
local StatusLabel = GB_L:AddLabel("Status: Idle")
RunService.Heartbeat:Connect(function()
    pcall(function() StatusLabel:SetText("Status: " .. FarmStatus) end)
end)

GB_L:AddToggle("SF_Invis", {
    Text = "Invisibility", Default = false,
    Callback = function(v) if v then enableInvis() else disableInvis() end end,
})

GB_L:AddToggle("SF_Farm", {
    Text = "Start Farm", Default = false,
    Callback = function(v) if v then StartFarm() else StopFarm() end end,
})

GB_L:AddToggle("SF_AutoPickup", {
    Text = "Auto Pickup Junk", Default = false,
    Callback = function(v) SetAutoPickup(v) end,
})

GB_L:AddToggle("SF_FastInteract", {
    Text = "Fast Interact", Default = false,
    Callback = function(v) SetFastInteract(v) end,
})

GB_R:AddSlider("SF_MaxRuns", {
    Text = "Scraps per run", Min = 1, Max = 20, Default = 5, Rounding = 0,
    Callback = function(v) MaxRuns = v end,
})

GB_R:AddSlider("SF_InteractTime", {
    Text = "Interact time (sec)", Min = 2, Max = 15, Default = 5, Rounding = 0,
    Callback = function(v) InteractTime = v end,
})

GB_R:AddSlider("SF_MoveSpeed", {
    Text = "Move speed", Min = 10, Max = 60, Default = 22, Rounding = 0,
    Callback = function(v) MoveSpeed = v end,
})

GB_ESP:AddToggle("SF_ScrapESP", {
    Text = "Scrap ESP", Default = false,
    Callback = function(v) SetScrapESP(v) end,
})

Library.Unloaded:Connect(function()
    StopFarm()
    SetAutoPickup(false)
    SetFastInteract(false)
    SetScrapESP(false)
    disableInvis()
    InvisWarningGui:Destroy()
end)
