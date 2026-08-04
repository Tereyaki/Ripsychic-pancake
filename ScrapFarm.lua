--////////////////////////////////////////////////////////
--         SCRAP AUTO-FARM | Linoria UI
--         Criminality
--////////////////////////////////////////////////////////

repeat task.wait() until game:IsLoaded() and game:GetService("Players").LocalPlayer

local Players        = game:GetService("Players")
local RunService     = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService   = game:GetService("TweenService")
local PathfindingService = game:GetService("PathfindingService")
local UserInputService = game:GetService("UserInputService")
local VirtualUser    = game:GetService("VirtualUser")

local LocalPlayer = Players.LocalPlayer
local Workspace   = game:GetService("Workspace")

-- ========== НАСТРОЙКИ ==========
local Settings = {
    FarmEnabled   = false,
    PickupRadius  = 7,       -- радиус подбора
    MoveSpeed     = 24,
    PickupDelay   = 0.8,
    AutoPickupEnabled = false,
}

-- ========== ПЕРЕМЕННЫЕ ==========
local FarmThread      = nil
local AutoPickupConn  = nil
local ScrapESPConn    = nil
local AntiAfkConn     = nil
local InvisEnabled    = false
local StatusText      = "Ожидание"
local LastPickup      = 0

-- ========== ВСПОМОГАТЕЛЬНЫЕ ==========
local function getHRP()
    local c = LocalPlayer.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end

local function getScrapFolder()
    local filter = Workspace:FindFirstChild("Filter")
    return filter and filter:FindFirstChild("SpawnedPiles")
end

local function getPickupRemote()
    local ev = ReplicatedStorage:FindFirstChild("Events")
    return ev and ev:FindFirstChild("PIC_PU")
end

-- ========== ПОИСК БЛИЖАЙШЕГО СКРАПА ==========
local function findNearestScrap(maxDist)
    local hrp = getHRP(); if not hrp then return nil, 0 end
    local folder = getScrapFolder(); if not folder then return nil, 0 end
    local nearest, bestDist = nil, maxDist or math.huge
    for _, pile in ipairs(folder:GetChildren()) do
        local mesh = pile:FindFirstChildOfClass("MeshPart") or pile:FindFirstChildOfClass("Part")
        if mesh then
            local d = (hrp.Position - mesh.Position).Magnitude
            if d < bestDist then bestDist = d; nearest = pile end
        end
    end
    return nearest, bestDist
end

-- ========== ПОДБОР СКРАПА ==========
local function pickupScrap(pile)
    local remote = getPickupRemote(); if not remote then return end
    local attr = pile:GetAttribute("jzu")
    if attr then
        pcall(function() remote:FireServer(string.reverse(tostring(attr))) end)
    else
        pcall(function() remote:FireServer(pile) end)
    end
end

-- ========== AUTO PICKUP (радиус) ==========
local function startAutoPickup()
    if AutoPickupConn then AutoPickupConn:Disconnect() end
    AutoPickupConn = RunService.Heartbeat:Connect(function()
        local now = tick()
        if now - LastPickup < Settings.PickupDelay then return end
        local hrp = getHRP(); if not hrp then return end
        local remote = getPickupRemote(); if not remote then return end
        local folder = getScrapFolder(); if not folder then return end
        local closest, bestDist = nil, Settings.PickupRadius
        for _, pile in ipairs(folder:GetChildren()) do
            local mesh = pile:FindFirstChildOfClass("MeshPart") or pile:FindFirstChildOfClass("Part")
            if mesh then
                local d = (hrp.Position - mesh.Position).Magnitude
                if d < bestDist then bestDist = d; closest = pile end
            end
        end
        if closest then
            LastPickup = now
            pickupScrap(closest)
        end
    end)
end

local function stopAutoPickup()
    if AutoPickupConn then AutoPickupConn:Disconnect(); AutoPickupConn = nil end
end

-- ========== PATHFINDING ==========
local function computePath(startPos, endPos)
    local paramsList = {
        {Radius=1, Height=5, Spacing=3},
        {Radius=1.5, Height=5.5, Spacing=4},
        {Radius=2, Height=6, Spacing=5},
        {Radius=3, Height=7, Spacing=5},
        {Radius=1, Height=8, Spacing=3},
    }
    for _, p in ipairs(paramsList) do
        local path = PathfindingService:CreatePath({
            AgentRadius=p.Radius, AgentHeight=p.Height,
            AgentCanJump=true, AgentCanClimb=true, WaypointSpacing=p.Spacing
        })
        local ok = pcall(function() path:ComputeAsync(startPos, endPos) end)
        if ok and path.Status == Enum.PathStatus.Success then
            local wps = path:GetWaypoints()
            if wps and #wps >= 2 then return wps end
        end
        task.wait(0.03)
    end
    return nil
end

local function moveToPos(targetPos)
    local hrp = getHRP(); if not hrp then return false end
    local humanoid = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return false end

    local waypoints = computePath(hrp.Position, targetPos)
    if waypoints then
        for _, wp in ipairs(waypoints) do
            if not Settings.FarmEnabled then return false end
            hrp = getHRP(); if not hrp then return false end
            local wHRP = wp.Position + Vector3.new(0, 2.5, 0)
            local d = (wHRP - hrp.Position).Magnitude
            if d > 0.3 then
                local tw = TweenService:Create(hrp, TweenInfo.new(d / Settings.MoveSpeed, Enum.EasingStyle.Linear), {
                    CFrame = CFrame.new(wHRP) * (hrp.CFrame - hrp.CFrame.Position)
                })
                tw:Play(); tw.Completed:Wait()
            end
            if wp.Action == Enum.PathWaypointAction.Jump then
                humanoid.Jump = true; task.wait(0.1)
            end
        end
        return true
    else
        -- Нет пути — подходим ближе по шагам потом телепорт если ≤20 студов
        local totalDist = (targetPos - hrp.Position).Magnitude
        local steps = math.max(1, math.floor(totalDist / 3))
        local lastOk = hrp.Position
        for i = 1, steps do
            if not Settings.FarmEnabled then return false end
            hrp = getHRP(); if not hrp then return false end
            local dir = (targetPos - lastOk)
            if dir.Magnitude < 0.1 then break end
            local nextPos = lastOk + dir.Unit * math.min(3, dir.Magnitude)
            local sp = computePath(lastOk, nextPos)
            if sp then
                for _, wp in ipairs(sp) do
                    local wHRP = wp.Position + Vector3.new(0, 2.5, 0)
                    local d = (wHRP - hrp.Position).Magnitude
                    if d > 0.3 then
                        local tw = TweenService:Create(hrp, TweenInfo.new(d / Settings.MoveSpeed, Enum.EasingStyle.Linear), {
                            CFrame = CFrame.new(wHRP) * (hrp.CFrame - hrp.CFrame.Position)
                        })
                        tw:Play(); tw.Completed:Wait()
                    end
                end
                lastOk = nextPos
            else
                hrp = getHRP()
                if hrp and (targetPos - hrp.Position).Magnitude <= 20 then
                    hrp.CFrame = CFrame.new(targetPos + Vector3.new(0, 2.5, 0))
                    hrp.AssemblyLinearVelocity = Vector3.zero
                    task.wait(0.2)
                end
                break
            end
        end
        return true
    end
end

-- ========== ОСНОВНОЙ ФАРМ ЦИКЛ ==========
local function farmLoop()
    while Settings.FarmEnabled do
        task.wait(0.2)
        local hrp = getHRP()
        if not hrp then task.wait(1); continue end

        local folder = getScrapFolder()
        if not folder or #folder:GetChildren() == 0 then
            StatusText = "⏳ Нет скрапа..."
            task.wait(2)
            continue
        end

        -- Ищем ближайший скрап
        local nearest, dist = findNearestScrap()
        if not nearest then
            StatusText = "⏳ Нет скрапа..."
            task.wait(1)
            continue
        end

        local mesh = nearest:FindFirstChildOfClass("MeshPart") or nearest:FindFirstChildOfClass("Part")
        if not mesh then continue end

        -- Подсветка цели
        local highlight = nearest:FindFirstChild("_ScrapHL")
        if not highlight then
            highlight = Instance.new("Highlight")
            highlight.Name = "_ScrapHL"
            highlight.FillColor = Color3.fromRGB(255, 200, 0)
            highlight.OutlineColor = Color3.fromRGB(255, 200, 0)
            highlight.FillTransparency = 0.5
            highlight.OutlineTransparency = 0
            highlight.Adornee = nearest
            highlight.Parent = nearest
        end

        -- Идём к скрапу
        StatusText = "🚶 Иду к скрапу (" .. math.floor(dist) .. " st)"
        local targetPos = mesh.Position
        moveToPos(targetPos)

        -- Подбираем
        hrp = getHRP()
        if hrp and (hrp.Position - targetPos).Magnitude <= Settings.PickupRadius + 2 then
            StatusText = "📦 Подбираю скрап"
            pickupScrap(nearest)
            LastPickup = tick()
            task.wait(0.3)
        end

        -- Убираем подсветку
        pcall(function()
            local hl = nearest:FindFirstChild("_ScrapHL")
            if hl then hl:Destroy() end
        end)
    end
    StatusText = "Ожидание"
end

-- ========== SCRAP ESP ==========
local function startScrapESP()
    if ScrapESPConn then ScrapESPConn:Disconnect() end
    ScrapESPConn = RunService.Heartbeat:Connect(function()
        local folder = getScrapFolder(); if not folder then return end
        local hrp = getHRP()
        for _, pile in ipairs(folder:GetChildren()) do
            local mesh = pile:FindFirstChildOfClass("MeshPart") or pile:FindFirstChildOfClass("Part")
            if mesh and not pile:FindFirstChild("_ScrapESP") then
                local bb = Instance.new("BillboardGui")
                bb.Name = "_ScrapESP"
                bb.Size = UDim2.new(0, 100, 0, 30)
                bb.AlwaysOnTop = true
                bb.MaxDistance = 500
                bb.StudsOffset = Vector3.new(0, 3, 0)
                bb.Adornee = mesh
                local lbl = Instance.new("TextLabel", bb)
                lbl.Size = UDim2.new(1,0,1,0)
                lbl.BackgroundTransparency = 1
                lbl.Text = "📦 SCRAP"
                lbl.TextColor3 = Color3.fromRGB(255, 200, 0)
                lbl.TextStrokeTransparency = 0
                lbl.Font = Enum.Font.GothamBold
                lbl.TextSize = 13
                bb.Parent = pile
            end
        end
    end)
end

local function stopScrapESP()
    if ScrapESPConn then ScrapESPConn:Disconnect(); ScrapESPConn = nil end
    -- Убираем все ESP метки
    local folder = getScrapFolder()
    if folder then
        for _, pile in ipairs(folder:GetChildren()) do
            local bb = pile:FindFirstChild("_ScrapESP")
            if bb then bb:Destroy() end
        end
    end
end

-- ========== ANTI-AFK ==========
local function startAntiAfk()
    if AntiAfkConn then return end
    AntiAfkConn = LocalPlayer.Idled:Connect(function()
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new())
    end)
end
local function stopAntiAfk()
    if AntiAfkConn then AntiAfkConn:Disconnect(); AntiAfkConn = nil end
end
startAntiAfk() -- включаем сразу

-- ========== INVIS ==========
local InvisAnimTrack = nil
local function enableInvis()
    if InvisEnabled then return end
    InvisEnabled = true
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local humanoid = char and char:FindFirstChildOfClass("Humanoid")
    if not hrp or not humanoid then return end
    workspace.CurrentCamera.CameraSubject = hrp
    local anim = Instance.new("Animation")
    anim.AnimationId = "rbxassetid://215384594"
    local ok, track = pcall(function() return humanoid:LoadAnimation(anim) end)
    if ok then
        InvisAnimTrack = track
        InvisAnimTrack.Priority = Enum.AnimationPriority.Action4
    end
    RunService.Heartbeat:Connect(function(dt)
        if not InvisEnabled then return end
        char = LocalPlayer.Character
        hrp = char and char:FindFirstChild("HumanoidRootPart")
        humanoid = char and char:FindFirstChildOfClass("Humanoid")
        if not hrp or not humanoid or humanoid.Health <= 0 then return end
        if humanoid.MoveDirection.Magnitude > 0 then
            hrp.CFrame = hrp.CFrame + humanoid.MoveDirection * 12 * dt
        end
        local _, camYaw = workspace.CurrentCamera.CFrame:ToOrientation()
        hrp.CFrame = CFrame.new(hrp.CFrame.Position) * CFrame.fromOrientation(0, camYaw, 0) * CFrame.Angles(math.rad(90), 0, 0)
        humanoid.CameraOffset = Vector3.new(0, 1.44, 0)
        if InvisAnimTrack then
            pcall(function()
                if not InvisAnimTrack.IsPlaying then InvisAnimTrack:Play() end
                InvisAnimTrack:AdjustSpeed(0)
                InvisAnimTrack.TimePosition = 0.3
            end)
        end
        RunService.RenderStepped:Wait()
        humanoid.CameraOffset = Vector3.zero
        if char then
            for _, part in pairs(char:GetDescendants()) do
                if part:IsA("BasePart") and part.Transparency ~= 1 then
                    part.Transparency = 0.5
                end
            end
        end
    end)
end

local function disableInvis()
    if not InvisEnabled then return end
    InvisEnabled = false
    if InvisAnimTrack then pcall(function() InvisAnimTrack:Stop() end) end
    local char = LocalPlayer.Character
    local humanoid = char and char:FindFirstChildOfClass("Humanoid")
    if humanoid then workspace.CurrentCamera.CameraSubject = humanoid end
    if char then
        for _, part in pairs(char:GetDescendants()) do
            if part:IsA("BasePart") and part.Transparency == 0.5 then
                part.Transparency = 0
            end
        end
    end
end

-- ========== LINORIA UI ==========
local base = 'https://raw.githubusercontent.com/17kShotsss/UI-LIBRARY/main/'
local Library     = loadstring(game:HttpGet(base .. 'Library.lua'))()
local ThemeManager = loadstring(game:HttpGet(base .. 'addons/ThemeManager.lua'))()
local SaveManager  = loadstring(game:HttpGet(base .. 'addons/SaveManager.lua'))()

local Window = Library:CreateWindow({
    Title = 'Scrap Farm | Criminality',
    Center = true,
    AutoShow = true,
})

local Tabs = {
    Farm          = Window:AddTab('Farm'),
    ESP           = Window:AddTab('ESP'),
    ['UI Settings'] = Window:AddTab('UI Settings'),
}

-- ========== FARM TAB ==========
local FarmLeft = Tabs.Farm:AddLeftGroupbox('🔧 Scrap Farm')

FarmLeft:AddToggle('ScrapFarmToggle', {
    Text  = '▶ Start Scrap Farm',
    Default = false,
    Tooltip = 'Автоматически идёт к скрапу и подбирает его',
})
Toggles.ScrapFarmToggle:OnChanged(function()
    Settings.FarmEnabled = Toggles.ScrapFarmToggle.Value
    if Settings.FarmEnabled then
        FarmThread = task.spawn(farmLoop)
    else
        Settings.FarmEnabled = false
        if FarmThread then task.cancel(FarmThread); FarmThread = nil end
        StatusText = "Ожидание"
    end
end)

FarmLeft:AddToggle('AutoPickupToggle', {
    Text  = '🧲 Auto Pickup (радиус)',
    Default = false,
    Tooltip = 'Подбирает скрап в радиусе без движения',
})
Toggles.AutoPickupToggle:OnChanged(function()
    Settings.AutoPickupEnabled = Toggles.AutoPickupToggle.Value
    if Settings.AutoPickupEnabled then startAutoPickup() else stopAutoPickup() end
end)

FarmLeft:AddDivider()

FarmLeft:AddSlider('PickupRadius', {
    Text    = 'Pickup Radius',
    Default = 7,
    Min     = 3,
    Max     = 20,
    Rounding = 0,
    Suffix  = ' st',
})
Options.PickupRadius:OnChanged(function()
    Settings.PickupRadius = Options.PickupRadius.Value
end)

FarmLeft:AddSlider('FarmSpeed', {
    Text    = 'Farm Speed',
    Default = 24,
    Min     = 10,
    Max     = 50,
    Rounding = 0,
})
Options.FarmSpeed:OnChanged(function()
    Settings.MoveSpeed = Options.FarmSpeed.Value
end)

FarmLeft:AddDivider()

FarmLeft:AddToggle('AntiAfkToggle', {
    Text    = 'Anti-AFK',
    Default = true,
})
Toggles.AntiAfkToggle:OnChanged(function()
    if Toggles.AntiAfkToggle.Value then startAntiAfk() else stopAntiAfk() end
end)

-- ========== RIGHT: Invis + Info ==========
local FarmRight = Tabs.Farm:AddRightGroupbox('🫥 Invis & Info')

FarmRight:AddToggle('InvisToggle', {
    Text    = 'Invis (R6 only)',
    Default = false,
})
Toggles.InvisToggle:OnChanged(function()
    if Toggles.InvisToggle.Value then enableInvis() else disableInvis() end
end)

FarmRight:AddDivider()

local statusLabel = FarmRight:AddLabel('Статус: Ожидание')
local scrapCountLabel = FarmRight:AddLabel('Скрапов: 0')

-- Обновление Info
task.spawn(function()
    while true do
        task.wait(0.5)
        statusLabel:SetText('Статус: ' .. StatusText)
        local folder = getScrapFolder()
        local count = folder and #folder:GetChildren() or 0
        scrapCountLabel:SetText('Скрапов на карте: ' .. count)
    end
end)

-- ========== ESP TAB ==========
local ESPLeft = Tabs.ESP:AddLeftGroupbox('📦 Scrap ESP')

ESPLeft:AddToggle('ScrapESPToggle', {
    Text    = 'Scrap ESP',
    Default = false,
    Tooltip = 'Показывает метки над скрапами',
})
Toggles.ScrapESPToggle:OnChanged(function()
    if Toggles.ScrapESPToggle.Value then startScrapESP() else stopScrapESP() end
end)

-- ========== UI SETTINGS ==========
local MenuGroup = Tabs['UI Settings']:AddLeftGroupbox('Menu')
MenuGroup:AddButton('Unload', function() Library:Unload() end)
MenuGroup:AddLabel('Menu bind'):AddKeyPicker('MenuKeybind', {
    Default = 'End', NoUI = true, Text = 'Menu keybind'
})
Library.ToggleKeybind = Options.MenuKeybind

ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({'MenuKeybind'})
ThemeManager:SetFolder('ScrapFarm')
SaveManager:SetFolder('ScrapFarm/configs')
SaveManager:BuildConfigSection(Tabs['UI Settings'])
ThemeManager:ApplyToTab(Tabs['UI Settings'])

print("================================")
print("  Scrap Farm загружен!")
print("  Filter.SpawnedPiles → PIC_PU")
print("================================")
