-- ╔══════════════════════════════════════════════╗
-- ║           SCRAP AUTOFARM                     ║
-- ╚══════════════════════════════════════════════╝

local Players            = game:GetService("Players")
local RunService         = game:GetService("RunService")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")
local PathfindingService = game:GetService("PathfindingService")
local TweenService       = game:GetService("TweenService")

local LP  = Players.LocalPlayer
local Cam = workspace.CurrentCamera

local MIN_Y = 4.8  -- скрапы ниже этой высоты игнорируются

-- ── Obsidian UI ──────────────────────────────────────────────
local Library = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/deividcomsono/Obsidian/refs/heads/main/Library.lua"
))()

local Window = Library:CreateWindow({ Title = "Scrap Farm", Center = true, AutoShow = true })
local Tab    = Window:AddTab("Farm", "box")
local GB_L   = Tab:AddLeftGroupbox("Main")
local GB_R   = Tab:AddRightGroupbox("Settings")
local TabESP = Window:AddTab("ESP",  "eye")
local GB_ESP = TabESP:AddLeftGroupbox("World ESP")

-- ════════════════════════════════════════════════════════════
--  PATHFINDING  (только Tween по вейпоинтам, без Humanoid:MoveTo)
-- ════════════════════════════════════════════════════════════
local MoveSpeed  = 22
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
        { Radius = 1.8, Height = 4.2, Spacing = 2.2 },
        { Radius = 2.2, Height = 5.8, Spacing = 4.5 },
        { Radius = 2.8, Height = 6.2, Spacing = 5.5 },
        { Radius = 3.2, Height = 6.8, Spacing = 5.8 },
        { Radius = 3.8, Height = 7.2, Spacing = 6.2 },
    }
    for _, cfg in ipairs(configs) do
        local p = PathfindingService:CreatePath({
            AgentRadius     = cfg.Radius,
            AgentHeight     = cfg.Height,
            AgentCanJump    = true,
            AgentCanClimb   = true,
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

-- FIX 1: убрали fallback на Humanoid:MoveTo — только Tween по вейпоинтам
-- FIX 2: если путь не найден — возвращаем false, фарм пропускает этот скрап
local function WalkToPos(targetPos)
    local char = LP.Character
    local hrp  = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end

    local dist0 = (hrp.Position - targetPos).Magnitude
    if dist0 < 3 then return true end

    local waypoints = ComputePath(hrp.Position, targetPos)
    if not waypoints then
        warn("[ScrapFarm] Path not found to", targetPos)
        return false
    end

    for _, wp in ipairs(waypoints) do
        if not FarmActive then return false end
        local c2   = LP.Character
        local hrp2 = c2 and c2:FindFirstChild("HumanoidRootPart")
        if not hrp2 then return false end

        local wpHRP = wp.Position + Vector3.new(0, 2.5, 0)
        local d     = (wpHRP - hrp2.Position).Magnitude
        if d > 0.3 then
            local rot  = hrp2.CFrame - hrp2.CFrame.Position
            local tw   = TweenService:Create(hrp2,
                TweenInfo.new(d / MoveSpeed, Enum.EasingStyle.Linear),
                { CFrame = CFrame.new(wpHRP) * rot })
            tw:Play()
            tw.Completed:Wait()
        end
        if wp.Action == Enum.PathWaypointAction.Jump then
            local hum2 = c2 and c2:FindFirstChildOfClass("Humanoid")
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
--  FIX 3: LastPickup теперь отдельная переменная, не поле connection
-- ════════════════════════════════════════════════════════════
local AutoPickupConn    = nil
local AutoPickupLastT   = 0   -- <-- отдельная переменная вместо conn.LastPickup

local function SetAutoPickup(v)
    if AutoPickupConn then AutoPickupConn:Disconnect(); AutoPickupConn = nil end
    if not v then return end
    AutoPickupConn = RunService.Heartbeat:Connect(function()
        local now = tick()
        if now - AutoPickupLastT < 0.8 then return end
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
            -- FIX 4: фильтруем по высоте MIN_Y
            if mesh and mesh.Position.Y >= MIN_Y then
                local d = (root.Position - mesh.Position).Magnitude
                if d < bestDist then bestDist = d; closest = a end
            end
        end
        if closest then
            AutoPickupLastT = now
            local attr = closest:GetAttribute("jzu")
            if attr then
                pcall(function() remote:FireServer(string.reverse(tostring(attr))) end)
            else
                pcall(function() remote:FireServer(closest) end)
            end
        end
    end)
end

-- ════════════════════════════════════════════════════════════
--  SCRAP AUTOFARM
-- ════════════════════════════════════════════════════════════
local FarmThread   = nil
local FarmStatus   = "Idle"
local MaxRuns      = 5
local InteractTime = 5

-- FIX 4: фильтр по высоте MIN_Y
local function getScrapPiles()
    local filter = workspace:FindFirstChild("Filter")
    local folder = filter and filter:FindFirstChild("SpawnedPiles")
    if not folder then return {} end
    local result = {}
    for _, a in ipairs(folder:GetChildren()) do
        local mesh = a:FindFirstChildOfClass("MeshPart") or a:FindFirstChildOfClass("Part")
        if mesh and mesh.Position.Y >= MIN_Y then
            table.insert(result, { model = a, part = mesh })
        end
    end
    return result
end

local function pickupScrap(model)
    local remote = ReplicatedStorage.Events:FindFirstChild("PIC_PU")
    if not remote or not model.Parent then return end
    local attr = model:GetAttribute("jzu")
    if attr then
        pcall(function() remote:FireServer(string.reverse(tostring(attr))) end)
    else
        pcall(function() remote:FireServer(model) end)
    end
end

-- FIX 2: открываем ProximityPrompt через InputHoldBegin/End правильно
local function triggerPrompts(model)
    if not model.Parent then return end
    for _, desc in ipairs(model:GetDescendants()) do
        if desc:IsA("ProximityPrompt") then
            pcall(function()
                desc.HoldDuration = 0
                desc:InputHoldBegin()
                task.wait(0.15)
                desc:InputHoldEnd()
            end)
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

        -- ближайший скрап
        local closest, bestDist = nil, math.huge
        for _, p in ipairs(piles) do
            local d = (hrp.Position - p.part.Position).Magnitude
            if d < bestDist then bestDist = d; closest = p end
        end
        if not closest then task.wait(0.5); continue end

        count = count + 1
        FarmStatus = string.format("Moving to scrap [%d/%d]...", count, MaxRuns)

        local arrived = WalkToPos(closest.part.Position)
        if not FarmActive then break end

        if not arrived then
            -- путь не найден — пропускаем этот скрап
            FarmStatus = string.format("Can't reach scrap [%d/%d], skipping...", count, MaxRuns)
            task.wait(0.5)
            count = count - 1  -- не считаем пропущенный
            continue
        end

        FarmStatus = string.format("Interacting [%d/%d]...", count, MaxRuns)

        -- 5 секунд: открываем промпты + подбираем ремоутом
        local deadline = tick() + InteractTime
        repeat
            triggerPrompts(closest.model)
            pickupScrap(closest.model)
            task.wait(0.3)
        until tick() >= deadline or not FarmActive or not closest.model.Parent

        task.wait(0.2)
    end

    FarmStatus = FarmActive and ("Done! " .. MaxRuns .. " scraps collected") or "Stopped"
    FarmActive = false
    -- выключаем тогл
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
--  ИНВИЗ
-- ════════════════════════════════════════════════════════════
local InvisActive    = false
local InvisPossible  = true
local InvisAnimTrack = nil
local InvisAnim      = Instance.new("Animation")
InvisAnim.AnimationId = "rbxassetid://215384594"

local InvisGui = Instance.new("ScreenGui")
InvisGui.Name = "ScrapFarm_InvisWarn"
InvisGui.ResetOnSpawn = false
pcall(function() InvisGui.Parent = game:GetService("CoreGui") end)
if not InvisGui.Parent then InvisGui.Parent = LP:WaitForChild("PlayerGui") end
local InvisLabel = Instance.new("TextLabel", InvisGui)
InvisLabel.Text = "⚠️ YOU ARE VISIBLE ⚠️"
InvisLabel.Visible = false
InvisLabel.Size = UDim2.new(0, 300, 0, 30)
InvisLabel.Position = UDim2.new(0.5, -150, 0.85, 0)
InvisLabel.BackgroundTransparency = 1
InvisLabel.Font = Enum.Font.GothamSemibold
InvisLabel.TextSize = 24
InvisLabel.TextColor3 = Color3.fromRGB(255, 255, 0)
InvisLabel.TextStrokeTransparency = 0.5
InvisLabel.ZIndex = 10

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
    InvisLabel.Visible = false
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
        InvisLabel.Visible = false
        return
    end
    local char = LP.Character
    local hum  = char and char:FindFirstChildOfClass("Humanoid")
    local hrp  = char and char:FindFirstChild("HumanoidRootPart")
    if not char or not hum or not hrp or not hum:IsDescendantOf(workspace) or hum.Health <= 0 then
        InvisLabel.Visible = false
        return
    end
    InvisLabel.Visible = not isGrounded()
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
            lbl.Text = string.format("Scrap [%dm]", dist)
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
GB_R:AddSlider("SF_MinY", {
    Text = "Min height (Y)", Min = -50, Max = 50, Default = 5, Rounding = 1,
    Callback = function(v) MIN_Y = v end,
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
    InvisGui:Destroy()
end)
