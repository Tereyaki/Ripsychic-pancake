local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local PathfindingService = game:GetService("PathfindingService")
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local UserInputService = game:GetService("UserInputService")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")

-- VirtualInputManager недоступен на части эксплойтов — берём безопасно
local VirtualInputManager = nil
pcall(function() VirtualInputManager = game:GetService("VirtualInputManager") end)

local Settings = {
    Enabled = false,
    IsDead = false,
    IgnoredList = {},
    ProcessedList = {},
    TempIgnored = {},
    IgnoreDuration = 60,
    DebugPrintEnabled = true,
    TargetY = 4.8,
    MoveSpeed = 22,
    SomeFlag = true,
    WaypointSpacing = 3,
    SomeOtherParam = 3,
    PickupDistance = 8,
    MaxSomething = 999999,
    BreakMethod = "Crowbar", -- "Crowbar" or "Lockpick"
    AutoDeposit = false,
    AutoDepositThreshold = 5000,
    AutoAllowance = false,
    NeedsStartupToolCheck = false,
}

local StatsInfo = {
    CashAmount = 0,
    AllowanceAmount = 0,
    AllowanceText = "",
    AllowanceSecondsLeft = nil,
    BankAmount = 0,
    DepositInProgress = false,
    DepositCooldownUntil = 0,
    DepositLastAttemptAt = 0,
    LastAllowanceClaimAttempt = 0,
}

local PickupLock = {Lock = {Busy = false}}

-- Export Settings globally so a separate GUI script can change
-- Settings.BreakMethod (or any other setting) directly from another script:
--   _G.FarmSettings.BreakMethod = "Lockpick"
_G.FarmSettings = Settings
local LastTick = tick()
local CurrentTargetPart = nil
local IsMovingToTarget = false
local SomeFlag2 = false
local SomeNil = nil
local StatusText = "Idle"
local AvailableSafesCount = 0
local AvailableRegistersCount = 0
local Unused1 = 0
local Unused2 = 0
local TotalSafesCount = 0
local TotalRegistersCount = 0
local AvailableSafes = {}
local AvailableRegisters = {}
local TotalAvailableTargets = 0
local SuggestionText = ""
local SomeNil2 = nil
local BrokenStatusMap = {}
local RetryCount = 0
local LastShopMainPart = nil
local IsRising = false
local SortedTargets = {}
local HasReachedTargetY = false

local function Log(msg)
    if Settings.DebugPrintEnabled then
        print("[AutoFarm]", msg)
    end
end

local VirtualUser = nil
pcall(function() VirtualUser = game:GetService("VirtualUser") end)
local AntiAfkEnabled = true
local AntiAfkConnection = nil

local NoFallDamageEnabled = false

local function ApplyNoFallForceField(character)
    if not character or not NoFallDamageEnabled then return end
    local hasFF = false
    for _, child in pairs(character:GetChildren()) do
        if child:IsA("ForceField") and child.Visible == false then
            hasFF = true
            break
        end
    end
    if not hasFF then
        local ff = Instance.new("ForceField")
        ff.Visible = false
        ff.Parent = character
    end
end

local function StartNoFallDamage()
    NoFallDamageEnabled = true
    if LocalPlayer.Character then
        ApplyNoFallForceField(LocalPlayer.Character)
    end
    Log("No Fall Damage enabled")
end

local function StopNoFallDamage()
    NoFallDamageEnabled = false
    local char = LocalPlayer.Character
    if char then
        for _, child in pairs(char:GetChildren()) do
            if child:IsA("ForceField") and child.Visible == false then
                child:Destroy()
            end
        end
    end
    Log("No Fall Damage disabled")
end

-- Survives respawn - character is recreated, forcefield is re-applied.
-- Applied immediately (no artificial delay): waiting before adding the
-- ForceField left a window right after spawn where fall/spawn damage could
-- still land before protection was in place.
LocalPlayer.CharacterAdded:Connect(function(char)
    if NoFallDamageEnabled then
        ApplyNoFallForceField(char)
        -- Retry once more shortly after in case the character wasn't fully
        -- ready to parent instances to on the very first frame.
        task.spawn(function()
            task.wait(0.5)
            ApplyNoFallForceField(char)
        end)
    end
end)

local AntiAfkHeartbeatConnection = nil
local LastAntiAfkNudge = 0
local ANTI_AFK_NUDGE_INTERVAL = 90 -- seconds; well under Roblox's ~20min idle kick

local function nudgeAntiAfkInput()
    local ok = pcall(function()
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new())
    end)
    if ok then
        Log("Anti-AFK triggered")
    end
end

local function EnableAntiAfk()
    if AntiAfkConnection then return end

    -- Primary trigger: the game's own Idled event.
    AntiAfkConnection = LocalPlayer.Idled:Connect(function()
        if AntiAfkEnabled then
            nudgeAntiAfkInput()
            LastAntiAfkNudge = tick()
        end
    end)

    -- Backup trigger: Idled does not reliably re-arm after a simulated
    -- (VirtualUser) input on every client, so it can fire once and then
    -- stop firing again even though the player is still idle. This
    -- independent timer nudges input periodically regardless, so anti-AFK
    -- keeps working for the whole session instead of only the first idle.
    if not AntiAfkHeartbeatConnection then
        AntiAfkHeartbeatConnection = RunService.Heartbeat:Connect(function()
            if AntiAfkEnabled and tick() - LastAntiAfkNudge >= ANTI_AFK_NUDGE_INTERVAL then
                LastAntiAfkNudge = tick()
                nudgeAntiAfkInput()
            end
        end)
    end

    Log("Anti-AFK started")
end

local function DisableAntiAfk()
    if AntiAfkConnection then
        AntiAfkConnection:Disconnect()
        AntiAfkConnection = nil
    end
    if AntiAfkHeartbeatConnection then
        AntiAfkHeartbeatConnection:Disconnect()
        AntiAfkHeartbeatConnection = nil
    end
    Log("Anti-AFK stopped")
end

-- AntiAfk is controlled by the toggle, not auto-started

--========================== Admin Check ========================--
local AdminCheck_Enabled = false
local AdminCheck_Connection
local AdminCheck_Coroutine

local FarmStaffPlayers = {
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
        }
    }
}

local function IsStaff(plr)
    for groupId, roles in pairs(FarmStaffPlayers.groups) do
        local ok, roleName = pcall(function()
            return plr:GetRoleInGroup(groupId)
        end)
        if ok and roleName and roles[roleName] then
            return true
        end
    end
    return false
end

local function CheckAdmins()
    for _, plr in ipairs(Players:GetPlayers()) do
        if IsStaff(plr) then
            Log("Admin Check: staff detected (" .. plr.Name .. "), leaving")
            LocalPlayer:Kick("Admin Detected")
            task.wait(1)
            game:Shutdown()
            return
        end
    end
end

local function AdminCheck_Enable()
    if AdminCheck_Enabled then return end
    AdminCheck_Enabled = true

    CheckAdmins()

    AdminCheck_Connection = Players.PlayerAdded:Connect(function(plr)
        if not AdminCheck_Enabled then return end
        if IsStaff(plr) then
            Log("Admin Check: staff joined (" .. plr.Name .. "), leaving")
            LocalPlayer:Kick("Admin Detected")
            task.wait(1)
            game:Shutdown()
        end
    end)

    AdminCheck_Coroutine = coroutine.create(function()
        while AdminCheck_Enabled do
            CheckAdmins()
            task.wait(3)
        end
    end)
    coroutine.resume(AdminCheck_Coroutine)
    Log("Admin Check enabled")
end

local function AdminCheck_Disable()
    if not AdminCheck_Enabled then return end
    AdminCheck_Enabled = false

    if AdminCheck_Connection then
        AdminCheck_Connection:Disconnect()
        AdminCheck_Connection = nil
    end
    AdminCheck_Coroutine = nil
    Log("Admin Check disabled")
end

local AutoPickupRunning = false
local AutoPickupConnection = nil

local function StartAutoPickup()
    if AutoPickupRunning then return end
    AutoPickupRunning = true
    if AutoPickupConnection then
        AutoPickupConnection:Disconnect()
        AutoPickupConnection = nil
    end
    AutoPickupConnection = RunService.RenderStepped:Connect(function()
        if not AutoPickupRunning or Settings.IsDead then return end
        local spawnedBreadFolder = Workspace:FindFirstChild("Filter") and Workspace.Filter:FindFirstChild("SpawnedBread")
        local pickupEvent = ReplicatedStorage:FindFirstChild("Events") and ReplicatedStorage.Events:FindFirstChild("CZDPZUS")
        if not spawnedBreadFolder or not pickupEvent then return end
        local character = LocalPlayer.Character
        local hrp = character and character:FindFirstChild("HumanoidRootPart")
        if not hrp then return end
        if PickupLock.Lock.Busy then return end
        local charPos = hrp.Position
        for _, breadPart in ipairs(spawnedBreadFolder:GetChildren()) do
            if (charPos - breadPart.Position).Magnitude <= Settings.PickupDistance then
                if not PickupLock.Lock.Busy then
                    PickupLock.Lock.Busy = true
                    pcall(function() pickupEvent:FireServer(breadPart) end)
                    task.wait(1.1)
                    PickupLock.Lock.Busy = false
                    break
                end
            end
        end
    end)
end

local function StopAutoPickup()
    if not AutoPickupRunning then return end
    AutoPickupRunning = false
    if AutoPickupConnection then
        AutoPickupConnection:Disconnect()
        AutoPickupConnection = nil
    end
    if PickupLock and PickupLock.Lock then
        PickupLock.Lock.Busy = false
    end
end

-- AutoPickup is controlled by the toggle, not auto-started

do
    repeat task.wait() until game:IsLoaded()
    local clonerefSafe = cloneref or function(...) return ... end
    local services = setmetatable({}, { __index = function(_, k) return clonerefSafe(game:GetService(k)) end })
    local localPlayer = services.Players.LocalPlayer
    local character, humanoid, hrp

    local function updateChar()
        character = localPlayer.Character
        if character then
            hrp = character:FindFirstChild("HumanoidRootPart")
            humanoid = character:FindFirstChildOfClass("Humanoid")
        else
            hrp = nil
            humanoid = nil
        end
    end
    updateChar()

    local heartbeat = RunService.Heartbeat
    local renderStepped = RunService.RenderStepped
    local coreGui = game:GetService("CoreGui")
    local starterGui = game:GetService("StarterGui")

    local InvisPossible = true
    if character and not character:FindFirstChild("Torso") then
        pcall(function() starterGui:SetCore("SendNotification", { Title = "Invisibility NOT WORKING", Text = "R6 avatar required", Duration = 5 }) end)
        InvisPossible = false
    end

    local warningGui = Instance.new("ScreenGui")
    warningGui.Name = "InvisWarningGUI"
    warningGui.Parent = coreGui
    warningGui.ResetOnSpawn = false
    warningGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

    local InvisWarningLabel = Instance.new("TextLabel", warningGui)
    InvisWarningLabel.Text = "⚠️YOU ARE VISIBLE⚠️"
    InvisWarningLabel.Visible = false
    InvisWarningLabel.Size = UDim2.new(0, 200, 0, 30)
    InvisWarningLabel.Position = UDim2.new(0.5, -100, 0.85, 0)
    InvisWarningLabel.BackgroundTransparency = 1
    InvisWarningLabel.Font = Enum.Font.GothamSemibold
    InvisWarningLabel.TextSize = 24
    InvisWarningLabel.TextColor3 = Color3.fromRGB(255, 255, 0)
    InvisWarningLabel.TextStrokeTransparency = 0.5
    InvisWarningLabel.ZIndex = 10

    local InvisActive = false
    local InvisAnim = Instance.new("Animation")
    InvisAnim.AnimationId = "rbxassetid://215384594"
    local InvisAnimTrack = nil

    local function isGrounded()
        return humanoid and humanoid:IsDescendantOf(workspace) and humanoid.FloorMaterial ~= Enum.Material.Air
    end

    local function loadInvisAnim()
        if InvisAnimTrack then
            pcall(function() InvisAnimTrack:Stop() end)
            InvisAnimTrack = nil
        end
        if humanoid then
            local success, track = pcall(function() return humanoid:LoadAnimation(InvisAnim) end)
            if success then
                InvisAnimTrack = track
                InvisAnimTrack.Priority = Enum.AnimationPriority.Action4
            else
                InvisAnimTrack = nil
            end
        else
            InvisAnimTrack = nil
        end
    end

    local function disableInvis()
        if not InvisActive then return end
        InvisActive = false
        if InvisAnimTrack then
            pcall(function() InvisAnimTrack:Stop() end)
        end
        if humanoid then
            workspace.CurrentCamera.CameraSubject = humanoid
        end
        if character then
            for _, part in pairs(character:GetDescendants()) do
                if part:IsA("BasePart") and part.Transparency == 0.5 then
                    part.Transparency = 0
                end
            end
        end
        if InvisWarningLabel then
            InvisWarningLabel.Visible = false
        end
    end

    local function enableInvis()
        if InvisActive or not InvisPossible then return end
        updateChar()
        if not character or not humanoid or not hrp then return end
        if not character:FindFirstChild("Torso") then
            pcall(function() starterGui:SetCore("SendNotification", { Title = "Invisibility NOT WORKING", Text = "R6 avatar required", Duration = 5 }) end)
            return
        end
        InvisActive = true
        workspace.CurrentCamera.CameraSubject = hrp
        loadInvisAnim()
    end

    local function toggleInvis()
        if InvisActive then
            disableInvis()
        else
            enableInvis()
        end
        return InvisActive
    end

    _G.Invis_Enable = enableInvis
    _G.Invis_Disable = disableInvis
    _G.Invis_Toggle = toggleInvis
    _G.IsInvisEnabled = function() return InvisActive end

    localPlayer.CharacterAdded:Connect(function(newChar)
        if InvisAnimTrack then
            pcall(function() InvisAnimTrack:Stop() end)
            InvisAnimTrack = nil
        end
        task.wait()
        updateChar()
        if not humanoid then
            task.wait(0.5)
            updateChar()
            if not humanoid then
                InvisPossible = false
                if InvisActive then disableInvis() end
                pcall(function() starterGui:SetCore("SendNotification", { Title = "Invisibility error", Text = "Could not determine character type", Duration = 5 }) end)
                return
            end
        end
        if humanoid.RigType ~= Enum.HumanoidRigType.R6 then
            InvisPossible = false
            if InvisActive then disableInvis() end
            pcall(function() starterGui:SetCore("SendNotification", { Title = "Warning", Text = "Non-R6 avatar detected. Invisibility disabled", Duration = 5 }) end)
            return
        else
            InvisPossible = true
        end
        if InvisActive then
            if hrp then workspace.CurrentCamera.CameraSubject = hrp end
            loadInvisAnim()
        end
    end)

    localPlayer.CharacterRemoving:Connect(function()
        if InvisAnimTrack then
            pcall(function() InvisAnimTrack:Stop() end)
            InvisAnimTrack = nil
        end
        if InvisWarningLabel then
            InvisWarningLabel.Visible = false
        end
    end)

    heartbeat:Connect(function(dt)
        if not InvisActive or not InvisPossible then
            if not InvisActive and character then
                for _, part in pairs(character:GetDescendants()) do
                    if part:IsA("BasePart") and part.Transparency == 0.5 then
                        part.Transparency = 0
                    end
                end
            end
            if InvisWarningLabel then
                InvisWarningLabel.Visible = false
            end
            return
        end
        if not character or not humanoid or not hrp or not humanoid:IsDescendantOf(workspace) or humanoid.Health <= 0 then
            if InvisWarningLabel then InvisWarningLabel.Visible = false end
            return
        end
        if InvisWarningLabel then
            InvisWarningLabel.Visible = not isGrounded()
        end

        local speed = 12
        if humanoid.MoveDirection.Magnitude > 0 then
            local move = humanoid.MoveDirection * speed * dt
            hrp.CFrame = hrp.CFrame + move
        end

        local originalCF = hrp.CFrame
        local originalCamOffset = humanoid.CameraOffset
        local _, cameraYaw = workspace.CurrentCamera.CFrame:ToOrientation()

        hrp.CFrame = CFrame.new(hrp.CFrame.Position) * CFrame.fromOrientation(0, cameraYaw, 0)
        hrp.CFrame = hrp.CFrame * CFrame.Angles(math.rad(90), 0, 0)
        humanoid.CameraOffset = Vector3.new(0, 1.44, 0)

        if InvisAnimTrack then
            local success = pcall(function()
                if not InvisAnimTrack.IsPlaying then
                    InvisAnimTrack:Play()
                end
                InvisAnimTrack:AdjustSpeed(0)
                InvisAnimTrack.TimePosition = 0.3
            end)
            if not success then
                loadInvisAnim()
            end
        elseif humanoid and humanoid.Health > 0 then
            loadInvisAnim()
        end

        renderStepped:Wait()

        if humanoid and humanoid:IsDescendantOf(workspace) then
            humanoid.CameraOffset = originalCamOffset
        end
        if hrp and hrp:IsDescendantOf(workspace) then
            hrp.CFrame = originalCF
        end
        if InvisAnimTrack then
            pcall(function() InvisAnimTrack:Stop() end)
        end
        if hrp and hrp:IsDescendantOf(workspace) then
            local lookVec = workspace.CurrentCamera.CFrame.LookVector
            local flatLook = Vector3.new(lookVec.X, 0, lookVec.Z).Unit
            if flatLook.Magnitude > 0.1 then
                hrp.CFrame = CFrame.new(hrp.Position, hrp.Position + flatLook)
            end
        end
        if character then
            for _, part in pairs(character:GetDescendants()) do
                if part:IsA("BasePart") and part.Transparency ~= 1 then
                    part.Transparency = 0.5
                end
            end
        end
    end)
end

RunService.Stepped:Connect(function()
    if Settings.Enabled and LocalPlayer.Character then
        pcall(function()
            for _, part in pairs(LocalPlayer.Character:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.CanCollide = false
                end
            end
        end)
    end
end)

local function DisableDoorsCollisionOnce(doors)
    for _, door in ipairs(doors:GetDescendants()) do
        pcall(function() if door:IsA("BasePart") then door.CanCollide = false end end)
    end
end

-- Permanent, not one-shot: the old version only ran a single pass right at
-- script load, so if the Map/Doors folder hadn't streamed in yet at that
-- exact moment it silently did nothing forever after. This waits for it
-- (even if it loads late), keeps disabling collision on any door added
-- later, and re-asserts every few seconds as a safety net in case the
-- server ever resets CanCollide back to true.
task.spawn(function()
    local map = Workspace:FindFirstChild("Map") or Workspace:WaitForChild("Map", 60)
    local doors = map and (map:FindFirstChild("Doors") or map:WaitForChild("Doors", 60))
    if not doors then
        Log("Doors folder not found, could not disable door collision")
        return
    end

    DisableDoorsCollisionOnce(doors)
    Log("Door collision disabled")

    doors.DescendantAdded:Connect(function(inst)
        if inst:IsA("BasePart") then
            pcall(function() inst.CanCollide = false end)
        end
    end)

    while true do
        task.wait(5)
        DisableDoorsCollisionOnce(doors)
    end
end)

local function RiseToTargetY()
    if HasReachedTargetY then return end
    local character = LocalPlayer.Character
    local hrp = character and character:FindFirstChild("HumanoidRootPart")
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if hrp and humanoid and humanoid.Health > 0 and hrp.Position.Y < 4.7 and not IsRising then
        Log("Character below 4.7, raising step by step to 4.8...")
        StatusText = "Rising to 4.8"
        IsRising = true

        local startPos = hrp.Position
        local targetY = 4.8
        local startY = startPos.Y
        local deltaY = targetY - startY
        if deltaY <= 0 then
            IsRising = false
            StatusText = "Idle"
            return
        end

        local steps = math.max(3, math.floor(deltaY * 2))
        local waypoints = {}
        for i = 1, steps do
            local alpha = i / steps
            local y = startY + deltaY * alpha
            table.insert(waypoints, Vector3.new(startPos.X, y, startPos.Z))
        end

        for _, wp in ipairs(waypoints) do
            if not Settings.Enabled then break end
            local currentRot = hrp.CFrame - hrp.CFrame.Position
            local targetCF = CFrame.new(wp) * currentRot
            local dist = (wp - hrp.Position).Magnitude
            local duration = math.min(0.5, dist / 10)

            local tween = TweenService:Create(hrp, TweenInfo.new(duration, Enum.EasingStyle.Linear), { CFrame = targetCF })
            tween:Play()
            tween.Completed:Wait()
        end

        hrp.CFrame = CFrame.new(startPos.X, targetY, startPos.Z) * (hrp.CFrame - hrp.CFrame.Position)
        hrp.AssemblyLinearVelocity = Vector3.zero
        hrp.AssemblyAngularVelocity = Vector3.zero

        Log("Reached 4.8, holding still for 3 seconds...")
        task.wait(3)
        Log("Hold complete, continuing")

        IsRising = false
        HasReachedTargetY = true
        StatusText = "Idle"
    end
end

local PathVisualsFolder = Instance.new("Folder")
PathVisualsFolder.Name = "PathVisuals"
PathVisualsFolder.Parent = Workspace

local currentTargetHighlight = nil

local HIGHLIGHT_COLORS = {
    dealer = Color3.fromRGB(255, 40, 40),
    atm = Color3.fromRGB(40, 130, 255),
    target = Color3.fromRGB(40, 255, 90),
}

local function ClearPathVisuals()
    if currentTargetHighlight then
        pcall(function() currentTargetHighlight:Destroy() end)
        currentTargetHighlight = nil
    end
end

local function SetTargetHighlight(part, kind)
    ClearPathVisuals()
    if not part then return end

    local color = HIGHLIGHT_COLORS[kind] or HIGHLIGHT_COLORS.target
    local adornee = part.Parent and part.Parent:IsA("Model") and part.Parent or part

    local highlight = Instance.new("Highlight")
    highlight.Name = "FarmTargetHighlight"
    highlight.FillColor = color
    highlight.FillTransparency = 0.55
    highlight.OutlineColor = color
    highlight.OutlineTransparency = 0
    highlight.Adornee = adornee
    highlight.Parent = PathVisualsFolder

    currentTargetHighlight = highlight
end

local function VisualizePath(waypoints, startPos, destinationPart, kind)
    if destinationPart then
        SetTargetHighlight(destinationPart, kind)
    end
end

local function ComputePath(startPos, endPos)
    local pathParamsList = {
        { Radius = 1, Height = 4, Spacing = 2 },
        { Radius = 1.2, Height = 4.5, Spacing = 2.5 },
        { Radius = 1.5, Height = 5, Spacing = 3 },
        { Radius = 2, Height = 5.5, Spacing = 4 },
        { Radius = 2.5, Height = 6, Spacing = 5 },
        { Radius = 3, Height = 6.5, Spacing = 5 },
        { Radius = 3.5, Height = 7, Spacing = 6 },
        { Radius = 4, Height = 7.5, Spacing = 6 },
        { Radius = 1, Height = 8, Spacing = 3 },
        { Radius = 5, Height = 5, Spacing = 5 },
        { Radius = 1.8, Height = 4.2, Spacing = 2.2 },
        { Radius = 2.2, Height = 5.8, Spacing = 4.5 },
        { Radius = 2.8, Height = 6.2, Spacing = 5.5 },
        { Radius = 3.2, Height = 6.8, Spacing = 5.8 },
        { Radius = 3.8, Height = 7.2, Spacing = 6.2 }
    }
    for _, params in ipairs(pathParamsList) do
        local pathParams = {
            AgentRadius = params.Radius,
            AgentHeight = params.Height,
            AgentCanJump = true,
            AgentCanClimb = true,
            WaypointSpacing = params.Spacing,
            CostCalibration = true
        }
        local path = PathfindingService:CreatePath(pathParams)
        local success, _ = pcall(function() path:ComputeAsync(startPos, endPos) end)
        if success and path.Status == Enum.PathStatus.Success then
            local rawWaypoints = path:GetWaypoints()
            if not rawWaypoints or #rawWaypoints < 2 then return rawWaypoints end
            local refinedWaypoints = {}
            local spacing = Settings.WaypointSpacing
            table.insert(refinedWaypoints, rawWaypoints[1])
            for i = 2, #rawWaypoints do
                local prev = rawWaypoints[i - 1].Position
                local curr = rawWaypoints[i].Position
                local dist = (curr - prev).Magnitude
                if dist <= spacing then
                    table.insert(refinedWaypoints, rawWaypoints[i])
                else
                    local steps = math.ceil(dist / spacing)
                    for j = 1, steps do
                        local alpha = j / steps
                        local pos = prev:Lerp(curr, alpha)
                        local action = (j == steps and rawWaypoints[i].Action) or Enum.PathWaypointAction.Walk
                        table.insert(refinedWaypoints, { Position = pos, Action = action })
                    end
                end
            end
            return refinedWaypoints
        end
        task.wait(0.05)
    end
    return nil
end

local function GetPositionInFrontOfTarget(targetPart, fromPos)
    if not targetPart then return nil end
    local success, cf = pcall(function() return targetPart.CFrame end)
    if not success then return nil end
    local lookVec = cf.LookVector
    lookVec = Vector3.new(lookVec.X, 0, lookVec.Z).Unit
    if lookVec.Magnitude < 0.1 then
        lookVec = (fromPos - cf.Position).Unit
        lookVec = Vector3.new(lookVec.X, 0, lookVec.Z).Unit
        if lookVec.Magnitude < 0.1 then lookVec = Vector3.new(1, 0, 0) end
    end
    return cf.Position + lookVec * 4
end

local function GetFootPosition()
    local character = LocalPlayer.Character
    if not character then return nil end
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end
    return hrp.Position - Vector3.new(0, 2.5, 0)
end

local function MoveToTarget(targetPart, targetObj, kind)
    RiseToTargetY()
    local character = LocalPlayer.Character
    if not character then
        Log("No character")
        return false
    end
    local hrp = character:FindFirstChild("HumanoidRootPart")
    local humanoid = character:FindFirstChild("Humanoid")
    if not hrp or not humanoid then
        Log("No HRP or Humanoid")
        return false
    end
    if not targetPart or not targetPart:IsA("BasePart") then
        Log("Invalid target")
        return false
    end

    local function isTargetBroken()
        if not targetObj or not targetObj.Parent then
            return false
        end
        local values = targetObj:FindFirstChild("Values")
        local broken = values and values:FindFirstChild("Broken")
        return broken and broken.Value == true
    end

    if isTargetBroken() then
        Log("Target already broken, switching target")
        return false, "target_broken"
    end

    CurrentTargetPart = targetPart
    IsMovingToTarget = true
    SomeFlag2 = false
    StatusText = "Pathing to target"
    local startPos = hrp.Position
    local targetFrontPos = GetPositionInFrontOfTarget(targetPart, startPos)
    if not targetFrontPos then
        Log("Could not compute position in front of object")
        IsMovingToTarget = false
        StatusText = "Idle"
        return false
    end
    local endPos = targetFrontPos
    Log("Finding path to target, distance " .. math.floor((endPos - startPos).Magnitude))
    local path = ComputePath(startPos, endPos)
    if not path then
        Log("Path not found, temporarily ignoring target")
        IsMovingToTarget = false
        StatusText = "Idle"
        return false
    end
    Log("Path found, waypoints: " .. #path)
    VisualizePath(path, startPos, targetPart, kind)
    for _, waypoint in ipairs(path) do
        if not Settings.Enabled then
            ClearPathVisuals()
            IsMovingToTarget = false
            StatusText = "Idle"
            return false
        end
        if isTargetBroken() then
            Log("Target broken while pathing, switching target")
            ClearPathVisuals()
            IsMovingToTarget = false
            StatusText = "Idle"
            return false, "target_broken"
        end
        local footPos = GetFootPosition()
        if not footPos then continue end
        local targetPos = waypoint.Position
        local targetHRP = targetPos + Vector3.new(0, 2.5, 0)
        local currentRot = hrp.CFrame - hrp.CFrame.Position
        local targetCF = CFrame.new(targetHRP) * currentRot
        local dist = (targetHRP - hrp.Position).Magnitude
        if dist > 0.2 then
            local tween = TweenService:Create(hrp, TweenInfo.new(dist / Settings.MoveSpeed, Enum.EasingStyle.Linear), { CFrame = targetCF })
            tween:Play()
            tween.Completed:Wait()
            LastTick = tick()
        end
        if waypoint.Action == Enum.PathWaypointAction.Jump then
            humanoid.Jump = true
            task.wait(0.1)
        end
    end
    if isTargetBroken() then
        Log("Target broken on arrival, switching target")
        ClearPathVisuals()
        IsMovingToTarget = false
        StatusText = "Idle"
        return false, "target_broken"
    end
    ClearPathVisuals()
    local finalPos = endPos
    local finalHRP = finalPos + Vector3.new(0, 2.5, 0)
    hrp.CFrame = CFrame.new(finalHRP) * CFrame.Angles(0, math.rad(90), 0)
    hrp.AssemblyLinearVelocity = Vector3.zero
    hrp.AssemblyAngularVelocity = Vector3.zero
    Log("Target reached")
    IsMovingToTarget = false
    StatusText = "Idle"
    return true
end

local function HasTool(toolName)
    local backpack = LocalPlayer:FindFirstChild("Backpack")
    local character = LocalPlayer.Character
    return (backpack and backpack:FindFirstChild(toolName)) or (character and character:FindFirstChild(toolName))
end

-- ==================== Buffer zones ====================
-- Some safes/registers are physically located in separate "pockets" of the map
-- (subway, basements, etc.) that normal pathfinding to the exact target does not
-- reach directly. For these we define 2 waypoints: first take the normal smart path
-- to waypoint 1 (zone entrance), then teleport to waypoint 2 (already
-- inside the zone), and from there take the normal smart path to the real target.
-- A zone is matched by a separate word-token in the target name (e.g. "HO" in
-- "Medium Safe HO 39" / "Register HO 23").
-- Hardcoded, not affected by the GUI at all.
local PERMANENT_SKIP_LIST = {
    ["SmallSafe_HO_37"] = true,
    ["MediumSafe_HO_24"] = true,
    ["MediumSafe_SEW_2"] = true,
    ["MediumSafe_SEW_8"] = true,
    ["MediumSafe_VC_21"] = true,
    ["MediumSafe_VC_30"] = true,
    ["MediumSafe_VC_38"] = true,
}

-- Optional list - controlled via the Skip List tab in the GUI.
local SkipList = {}

local function isTargetSkipped(targetName)
    local name = tostring(targetName)
    return PERMANENT_SKIP_LIST[name] == true or SkipList[name] == true
end

local BufferZones = {
    {
        name = "Burmalda",
        -- Exact object names that physically belong to this
        -- buffer zone (reachable via its 2 waypoints). NOT a generic token -
        -- otherwise any safe/register with "HO" in the name anywhere on the map would match,
        -- even if it is located somewhere else entirely.
        names = {
            ["MediumSafe_HO_39"] = true,
            ["Register_HO_23"] = true,
        },
        waypoint1 = Vector3.new(-4447.46, 3.90, -56.37),
        waypoint2 = Vector3.new(-4442.79, 25.48, -57.33),
        radius = 10,
    },
    {
        name = "TSSSS",
        names = {
            ["Register_TS_27"] = true,
            ["Register_TS_4"] = true,
            ["MediumSafe_TS_20"] = true,
        },
        waypoint1 = Vector3.new(-4602.95, 3.80, -152.89),
        waypoint2 = Vector3.new(-4607.30, 4.00, -152.00),
        radius = 20,
    },
    {
        name = "TOWER",
        names = {
            ["MediumSafe_T_45"] = true,
            ["MediumSafe_T_46"] = true,
        },
        waypoint1 = Vector3.new(-4520.39, 126.55, -774.80),
        waypoint2 = Vector3.new(-4523.65, 149.35, -775.08),
        radius = 20,
    },
}

local function getBufferZoneForTarget(targetName)
    local name = tostring(targetName or "")
    for _, zone in ipairs(BufferZones) do
        if zone.names[name] then
            return zone
        end
    end
    return nil
end

-- Path to a "bare" point in space (without the concept of "a target with an interact
-- prompt in front", unlike MoveToTarget) - used to walk to waypoints.
local function WalkToPosition(destination)
    local character = LocalPlayer.Character
    if not character then return false end
    local hrp = character:FindFirstChild("HumanoidRootPart")
    local humanoid = character:FindFirstChild("Humanoid")
    if not hrp or not humanoid then return false end

    local startPos = hrp.Position
    local path = ComputePath(startPos, destination)
    if not path then return false end

    for _, waypoint in ipairs(path) do
        if not Settings.Enabled then return false end
        local footPos = GetFootPosition()
        if not footPos then continue end
        local targetPos = waypoint.Position
        local targetHRP = targetPos + Vector3.new(0, 2.5, 0)
        local currentRot = hrp.CFrame - hrp.CFrame.Position
        local targetCF = CFrame.new(targetHRP) * currentRot
        local dist = (targetHRP - hrp.Position).Magnitude
        if dist > 0.2 then
            local tween = TweenService:Create(hrp, TweenInfo.new(dist / Settings.MoveSpeed, Enum.EasingStyle.Linear), { CFrame = targetCF })
            tween:Play()
            tween.Completed:Wait()
            LastTick = tick()
        end
        if waypoint.Action == Enum.PathWaypointAction.Jump then
            humanoid.Jump = true
            task.wait(0.1)
        end
    end
    return true
end

local function TeleportToPosition(position)
    local character = LocalPlayer.Character
    local hrp = character and character:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end
    hrp.CFrame = CFrame.new(position) * (hrp.CFrame - hrp.CFrame.Position)
    hrp.AssemblyLinearVelocity = Vector3.zero
    hrp.AssemblyAngularVelocity = Vector3.zero
    return true
end

-- Wrapper around MoveToTarget: if the target belongs to a buffer zone, first
-- go through its waypoints, otherwise fall back to normal MoveToTarget behavior.
local function MoveToTargetSmart(targetPart, targetObj, kind)
    local zone = getBufferZoneForTarget(targetObj and targetObj.Name)
    if not zone or not targetPart then
        return MoveToTarget(targetPart, targetObj, kind)
    end

    local function isTargetAlreadyBroken()
        if not targetObj or not targetObj.Parent then return false end
        local values = targetObj:FindFirstChild("Values")
        local broken = values and values:FindFirstChild("Broken")
        return broken and broken.Value == true
    end

    if isTargetAlreadyBroken() then
        Log("Zone target " .. zone.name .. " already broken, not entering zone")
        return false, "target_broken"
    end

    -- If the character is already physically near the TARGET itself (not necessarily
    -- near waypoint 2 - in a large zone the target can be far from the entrance
    -- point but close to the previously processed target) - do not repeat the path
    -- through waypoints, go directly. Each zone has its own radius.
    local character = LocalPlayer.Character
    local hrp = character and character:FindFirstChild("HumanoidRootPart")
    local zoneRadius = zone.radius or 10

    if hrp and (hrp.Position - targetPart.Position).Magnitude <= zoneRadius then
        Log("Already near target in zone " .. zone.name .. " (radius " .. zoneRadius .. "), going directly without waypoints")
        SetTargetHighlight(targetPart, kind)
        return MoveToTarget(targetPart, targetObj, kind)
    end

    SetTargetHighlight(targetPart, kind)
    Log("Buffer zone " .. zone.name .. ": heading to waypoint 1, target - " .. tostring(targetObj and targetObj.Name))
    StatusText = "Buffer zone: waypoint 1"
    local reachedWp1 = WalkToPosition(zone.waypoint1)
    if not reachedWp1 then
        Log("Failed to reach waypoint 1 of zone " .. zone.name)
        ClearPathVisuals()
        StatusText = "Idle"
        return false, "buffer_zone_wp1_failed"
    end

    if isTargetAlreadyBroken() then
        Log("Zone target " .. zone.name .. " broken already on the way to waypoint 1")
        ClearPathVisuals()
        StatusText = "Idle"
        return false, "target_broken"
    end

    Log("Teleporting to waypoint 2 of zone " .. zone.name)
    TeleportToPosition(zone.waypoint2)

    -- Wait for the character to physically settle (stop falling/sliding) -
    -- right after a teleport PathfindingService sometimes cannot build
    -- a path from a still "unstable" point, which causes the character to get stuck.
    do
        local character = LocalPlayer.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        local settleStart = tick()
        while humanoid and tick() - settleStart < 1.0 do
            local state = humanoid:GetState()
            if state == Enum.HumanoidStateType.Running
                or state == Enum.HumanoidStateType.Landed
                or state == Enum.HumanoidStateType.Standing
            then
                break
            end
            task.wait(0.1)
        end
        task.wait(0.15)
    end

    if isTargetAlreadyBroken() then
        Log("Zone target " .. zone.name .. " broken already after teleporting to waypoint 2")
        ClearPathVisuals()
        StatusText = "Idle"
        return false, "target_broken"
    end

    Log("From waypoint 2 heading to the real target (" .. tostring(targetObj and targetObj.Name) .. ")")
    local moved, reason = MoveToTarget(targetPart, targetObj, kind)

    if not moved and reason ~= "target_broken" then
        -- First attempt failed (pathfinding may not have had time
        -- to orient itself right after the teleport) - give it a bit more
        -- time to settle and try once more before giving up.
        Log("Path from waypoint 2 failed on the first try, retrying")
        task.wait(0.5)
        if not isTargetAlreadyBroken() then
            moved, reason = MoveToTarget(targetPart, targetObj, kind)
        end
    end

    return moved, reason
end

local function EquipTool(toolName)
    local tool = LocalPlayer:FindFirstChild("Backpack") and LocalPlayer.Backpack:FindFirstChild(toolName)
    if tool and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
        pcall(function() LocalPlayer.Character.Humanoid:EquipTool(tool) end)
        task.wait(1)
        return true
    end
    return false
end

local function CountTools(toolName)
    local count = 0
    local backpack = LocalPlayer:FindFirstChild("Backpack")
    local character = LocalPlayer.Character
    if backpack then
        for _, item in ipairs(backpack:GetChildren()) do
            if item.Name == toolName then count = count + 1 end
        end
    end
    if character then
        for _, item in ipairs(character:GetChildren()) do
            if item.Name == toolName then count = count + 1 end
        end
    end
    return count
end

local function getShopMainPart(name)
    local map = Workspace:FindFirstChild("Map")
    local shopz = map and map:FindFirstChild("Shopz")
    local shop = shopz and shopz:FindFirstChild(name)
    return shop and shop:FindFirstChild("MainPart") or nil
end

local function findCrowbarDealer()
    local map = Workspace:FindFirstChild("Map")
    local shopz = map and map:FindFirstChild("Shopz")
    if not shopz then return nil end

    local character = LocalPlayer.Character
    local hrp = character and character:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end

    local closestShop, closestDist = nil, math.huge
    for _, shop in ipairs(shopz:GetChildren()) do
        local stocks = shop:FindFirstChild("CurrentStocks")
        local hasCrowbar = true
        if stocks then
            local crowbarStock = stocks:FindFirstChild("Crowbar")
            hasCrowbar = (not crowbarStock) or crowbarStock.Value > 0
        end
        if hasCrowbar then
            local mainPart = shop:FindFirstChild("MainPart")
            if mainPart then
                local dist = (hrp.Position - mainPart.Position).Magnitude
                if dist < closestDist then
                    closestDist = dist
                    closestShop = shop
                end
            end
        end
    end
    return closestShop and closestShop:FindFirstChild("MainPart") or nil
end

local function BuyCrowbar()
    local existing = CountTools("Crowbar") > 0
    if existing then
        EquipTool("Crowbar")
        return true
    end

    local events = ReplicatedStorage:FindFirstChild("Events")
    local dealerPart = findCrowbarDealer() or getShopMainPart("Dealer")
    local protectionRemote = events and events:FindFirstChild("BYZERSPROTEC")
    local purchaseRemote = events and events:FindFirstChild("SSHPRMTE1")

    if not dealerPart or not protectionRemote or not purchaseRemote then
        return false
    end

    local moved = MoveToTarget(dealerPart, nil, "dealer")
    if not moved then return false end

    task.wait(1.5)
    pcall(protectionRemote.FireServer, protectionRemote, true, "shop", dealerPart, "IllegalStore")
    task.wait(1.0)
    pcall(purchaseRemote.InvokeServer, purchaseRemote, "IllegalStore", "Melees", "Crowbar", dealerPart, nil, true)
    task.wait(1.0)
    pcall(protectionRemote.FireServer, protectionRemote, false)
    task.wait(2.0)

    if CountTools("Crowbar") > 0 then
        EquipTool("Crowbar")
        return true
    end
    return false
end

local function FindLockpickDealer()
    local map = Workspace:FindFirstChild("Map")
    local shopz = map and map:FindFirstChild("Shopz")
    if not shopz then
        Log("Shops not found")
        return nil
    end
    local character = LocalPlayer.Character
    local hrp = character and character:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end

    local closestDealer, closestDist = nil, math.huge
    for _, shop in ipairs(shopz:GetChildren()) do
        local stocks = shop:FindFirstChild("CurrentStocks")
        local hasLockpick = true
        if stocks then
            local lockpickStock = stocks:FindFirstChild("Lockpick")
            hasLockpick = (not lockpickStock) or lockpickStock.Value > 0
        end
        if hasLockpick then
            local mainPart = shop:FindFirstChild("MainPart")
            if mainPart then
                local dist = (hrp.Position - mainPart.Position).Magnitude
                if dist < closestDist then
                    closestDist = dist
                    closestDealer = shop
                end
            end
        end
    end
    return closestDealer
end

local function PurchaseLockpickAt(shopPart)
    local events = ReplicatedStorage:FindFirstChild("Events")
    if not shopPart or not events then return false end
    local purchaseRemote = events:FindFirstChild("SSHPRMTE1")
    if not purchaseRemote then return false end

    local illegalOk, illegalAccepted, illegalMessage = pcall(function()
        return purchaseRemote:InvokeServer("IllegalStore", "Misc", "Lockpick", shopPart, nil, true, nil)
    end)
    task.wait(0.25)
    local legalOk, legalAccepted, legalMessage = pcall(function()
        return purchaseRemote:InvokeServer("LegalStore", "Misc", "Lockpick", shopPart, nil, true)
    end)

    return (illegalOk and (illegalAccepted == true or illegalMessage == "PURCHASE COMPLETE"))
        or (legalOk and (legalAccepted == true or legalMessage == "PURCHASE COMPLETE"))
end

local function BuyLockpickBatch()
    local dealer = FindLockpickDealer()
    if not dealer then return false end
    local mainPart = dealer:FindFirstChild("MainPart")
    if not mainPart then
        Log("Dealer has no MainPart")
        return false
    end

    StatusText = "Heading to dealer for a lockpick"
    Log("Heading to dealer for a lockpick")

    local moveSuccess = MoveToTarget(mainPart, nil, "dealer")
    if not moveSuccess then
        Log("Path to dealer not found, skipping for now")
        StatusText = "Idle"
        return false
    end

    StatusText = "Buying a lockpick"
    task.wait(1)

    local startingCount = CountTools("Lockpick")
    local successfulPurchases = 0
    local consecutiveFailures = 0
    local stocks = dealer:FindFirstChild("CurrentStocks")
    local lockpickStock = stocks and stocks:FindFirstChild("Lockpick")

    Log("Buying out the dealer's whole lockpick stock" .. (lockpickStock and (" (" .. lockpickStock.Value .. " pcs)") or ""))

    while Settings.Enabled do
        if lockpickStock and lockpickStock.Value <= 0 then
            Log("Dealer ran out of lockpick stock")
            break
        end
        if PurchaseLockpickAt(mainPart) then
            successfulPurchases = successfulPurchases + 1
            consecutiveFailures = 0
        else
            consecutiveFailures = consecutiveFailures + 1
            if consecutiveFailures >= 5 then
                Log("5 failed purchases in a row, stopping")
                break
            end
        end
        task.wait(0.20)
    end

    task.wait(0.75)
    StatusText = "Idle"

    local bought = CountTools("Lockpick") > startingCount or successfulPurchases > 0
    if bought then
        Log("Lockpicks purchased (" .. successfulPurchases .. " pcs)")
    else
        Log("Failed to buy lockpicks")
    end
    return bought
end

-- Lockpick minigame GUI: LockpickGUI.MF.LP_Frame.Frames.{B1,B2,B3}.Bar.UIScale
-- (hit-zone scale) and MF.LP_Frame.Line (the moving bar). A persistent
-- watcher enlarges the hit zones as soon as the GUI appears, wherever it
-- came from - ported over 1:1 from v16.
local function ApplyLockpickGUI()
    local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
    if not playerGui then return end
    local lockpickGui = playerGui:FindFirstChild("LockpickGUI")
    if not lockpickGui then return end
    local mf = lockpickGui:FindFirstChild("MF")
    if not mf then return end
    local lpFrame = mf:FindFirstChild("LP_Frame")
    if not lpFrame then return end
    local frames = lpFrame:FindFirstChild("Frames")
    if not frames then return end

    for _, bName in ipairs({"B1", "B2", "B3"}) do
        local b = frames:FindFirstChild(bName)
        if b and b:FindFirstChild("Bar") and b.Bar:FindFirstChild("UIScale") then
            b.Bar.UIScale.Scale = 20
        end
    end
end

local LockpickGuiConnection = nil
local function StartLockpickGUIWatcher()
    if LockpickGuiConnection then return end
    local playerGui = LocalPlayer:WaitForChild("PlayerGui")
    LockpickGuiConnection = playerGui.ChildAdded:Connect(function(child)
        if child.Name == "LockpickGUI" then
            task.wait(0.05)
            ApplyLockpickGUI()
        end
    end)
    if playerGui:FindFirstChild("LockpickGUI") then
        ApplyLockpickGUI()
    end
end
StartLockpickGUIWatcher()

-- Lock the camera on the safe while breaking it - combined with the GUI scale-up (x20):
-- the camera keeps looking at the target, the cursor stays aimed at its
-- on-screen point, no matter where the player tries to turn.
local LockpickCameraConnection = nil
local LockpickCameraPreviousType = nil

local function StartLockpickCameraLock(part)
    local camera = Workspace.CurrentCamera
    if not camera or not part then return end

    if not LockpickCameraConnection then
        LockpickCameraPreviousType = camera.CameraType
    end
    camera.CameraType = Enum.CameraType.Scriptable

    if LockpickCameraConnection then
        LockpickCameraConnection:Disconnect()
    end

    LockpickCameraConnection = RunService.RenderStepped:Connect(function()
        if not part.Parent then return end
        local cam = Workspace.CurrentCamera
        if not cam then return end
        local character = LocalPlayer.Character
        local hrp = character and character:FindFirstChild("HumanoidRootPart")
        if not hrp then return end

        local toTarget = part.Position - hrp.Position
        local flatDir = Vector3.new(toTarget.X, 0, toTarget.Z)
        if flatDir.Magnitude < 0.01 then
            flatDir = Vector3.new(0, 0, 1)
        end
        flatDir = flatDir.Unit

        local camPos = hrp.Position - flatDir * 10 + Vector3.new(0, 4, 0)
        cam.CFrame = CFrame.new(camPos, part.Position)

        local screenPos, onScreen = cam:WorldToScreenPoint(part.Position)
        if onScreen then
            pcall(VirtualInputManager.SendMouseMoveEvent, VirtualInputManager, screenPos.X, screenPos.Y, game)
        end
    end)
end

local function StopLockpickCameraLock()
    if LockpickCameraConnection then
        LockpickCameraConnection:Disconnect()
        LockpickCameraConnection = nil
    end
    local camera = Workspace.CurrentCamera
    if camera and LockpickCameraPreviousType then
        camera.CameraType = LockpickCameraPreviousType
    end
    LockpickCameraPreviousType = nil
end

local function HackSafeWithLockpick(safeObj)
    if CountTools("Lockpick") == 0 then
        if not BuyLockpickBatch() then return false end
        Log("Lockpick bought, returning to the safe")
        local mainPartForReturn = safeObj:FindFirstChild("PosPart") or safeObj:FindFirstChild("MainPart") or safeObj.PrimaryPart
        if mainPartForReturn and safeObj.Parent then
            MoveToTargetSmart(mainPartForReturn, safeObj, "target")
        end
    end
    if not (LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Lockpick")) then
        EquipTool("Lockpick")
        task.wait(1)
    end

    local aimPart = safeObj:FindFirstChild("PosPart") or safeObj:FindFirstChild("MainPart") or safeObj.PrimaryPart
    if aimPart then
        StartLockpickCameraLock(aimPart)
    end

    local function openMinigame()
        local posPart = safeObj:FindFirstChild("PosPart") or safeObj:FindFirstChild("MainPart") or safeObj.PrimaryPart
        if not posPart then return false end
        local cam = Workspace.CurrentCamera
        local screenPos, onScreen = cam:WorldToScreenPoint(posPart.Position)
        if not onScreen then return false end
        pcall(function() VirtualInputManager:SendMouseMoveEvent(screenPos.X, screenPos.Y, game) end)
        task.wait(0.05)
        pcall(function() VirtualInputManager:SendMouseButtonEvent(screenPos.X, screenPos.Y, 0, true, game, 1) end)
        task.wait(0.03)
        pcall(function() VirtualInputManager:SendMouseButtonEvent(screenPos.X, screenPos.Y, 0, false, game, 1) end)
        return true
    end

    Log("Starting lockpick break-in")
    StatusText = "Breaking with lockpick"
    local startTime = tick()
    local rejectedLockpicks = {}

    local function pickLockpickExcluding()
        local character = LocalPlayer.Character
        local backpack = LocalPlayer:FindFirstChild("Backpack")

        local equipped = character and character:FindFirstChild("Lockpick")
        if equipped and not rejectedLockpicks[equipped] then
            return equipped, equipped:FindFirstChild("Uses"), equipped:FindFirstChild("Remote")
        end

        if backpack then
            for _, item in ipairs(backpack:GetChildren()) do
                if item.Name == "Lockpick" and not rejectedLockpicks[item] then
                    EquipTool("Lockpick")
                    task.wait(0.5)
                    local fresh = character and character:FindFirstChild("Lockpick")
                    return fresh, fresh and fresh:FindFirstChild("Uses"), fresh and fresh:FindFirstChild("Remote")
                end
            end
        end

        return nil, nil, nil
    end

    while Settings.Enabled and safeObj and safeObj.Parent do
        local values = safeObj:FindFirstChild("Values")
        if not values then break end
        local broken = values:FindFirstChild("Broken")
        if broken and broken.Value then
            Log("Safe already broken")
            break
        end
        if tick() - startTime > 60 then
            Log("Lockpick break-in timed out (60 sec), switching target")
            break
        end

        local lp, usesVal, remote = pickLockpickExcluding()
        if not lp or not remote then
            if not BuyLockpickBatch() then break end
            Log("Lockpick bought, returning to the safe")
            local mainPartForReturn = safeObj:FindFirstChild("PosPart") or safeObj:FindFirstChild("MainPart") or safeObj.PrimaryPart
            if mainPartForReturn and safeObj.Parent then
                MoveToTargetSmart(mainPartForReturn, safeObj, "target")
            end
            rejectedLockpicks = {}
            EquipTool("Lockpick")
            task.wait(1)
            lp, usesVal, remote = pickLockpickExcluding()
            if not lp or not remote then break end
        end

        local opened = openMinigame()
        if not opened then
            task.wait(0.3)
            continue
        end

        -- Wait for the LockpickGUI to appear AND for the actual "cubes" (bars B1/B2/B3) -
        -- the LockpickGUI appearing alone does not mean the minigame actually
        -- started - the cubes are a reliable signal. If they are not there within 2 sec -
        -- switch to another lockpick from the inventory, marking this one
        -- as skipped (not removed, just not picked next).
        local pg = LocalPlayer:FindFirstChild("PlayerGui")
        local lockpickGui, frames = nil, nil
        local waited = 0
        repeat
            lockpickGui = pg and pg:FindFirstChild("LockpickGUI")
            local mf = lockpickGui and lockpickGui:FindFirstChild("MF")
            local lpFrame = mf and mf:FindFirstChild("LP_Frame")
            frames = lpFrame and lpFrame:FindFirstChild("Frames")
            local cubesExist = frames
                and frames:FindFirstChild("B1")
                and frames.B1:FindFirstChild("Bar")

            if not cubesExist then
                task.wait(0.1)
                waited = waited + 0.1
            end
        until (frames and frames:FindFirstChild("B1") and frames.B1:FindFirstChild("Bar")) or waited >= 2

        if not frames or not frames:FindFirstChild("B1") or not frames.B1:FindFirstChild("Bar") then
            Log("Minigame did not start within 2 sec (no cubes appeared), switching lockpick")
            rejectedLockpicks[lp] = true
            task.wait(0.2)
            continue
        end

        if lockpickGui then
            local mf = lockpickGui:FindFirstChild("MF")
            local lpFrame = mf and mf:FindFirstChild("LP_Frame")
            local line = lpFrame and lpFrame:FindFirstChild("Line")

            if frames then
                for _, bName in ipairs({"B1", "B2", "B3"}) do
                    local b = frames:FindFirstChild(bName)
                    local bar = b and b:FindFirstChild("Bar")
                    local uiScale = bar and bar:FindFirstChild("UIScale")
                    if uiScale then uiScale.Scale = 20 end
                end
            end

            if line and frames then
                local prevUses = usesVal and usesVal.Value or 0
                local autoStart = tick()
                while Settings.Enabled and tick() - autoStart < 10 do
                    if not lockpickGui or not lockpickGui.Parent then break end
                    if not line or not line.Parent then break end
                    if not frames or not frames.Parent then break end

                    pcall(function()
                        for _, bName in ipairs({"B1", "B2", "B3"}) do
                            local b = frames:FindFirstChild(bName)
                            local bar = b and b:FindFirstChild("Bar")
                            local uiScale = bar and bar:FindFirstChild("UIScale")
                            if uiScale then uiScale.Scale = 20 end
                        end
                    end)

                    local inZone = false
                    pcall(function()
                        local lineX = line.AbsolutePosition.X + line.AbsoluteSize.X / 2
                        for _, bName in ipairs({"B1", "B2", "B3"}) do
                            if inZone then break end
                            local b = frames:FindFirstChild(bName)
                            local bar = b and b:FindFirstChild("Bar")
                            if bar and bar.Parent then
                                local barLeft = bar.AbsolutePosition.X
                                local barRight = barLeft + bar.AbsoluteSize.X
                                if lineX >= barLeft and lineX <= barRight then
                                    inZone = true
                                end
                            end
                        end
                    end)

                    if inZone then
                        -- Spam clicks while the line is in the hit zone instead of a single click -
                        -- this increases the chance of the hit actually registering.
                        for _ = 1, 4 do
                            pcall(function() VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 1) end)
                            task.wait(0.02)
                            pcall(function() VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 1) end)
                            task.wait(0.02)
                        end
                    end

                    pcall(function()
                        local newUses = usesVal and usesVal.Value or 0
                        if newUses > prevUses then
                            prevUses = newUses
                            StatusText = "Lockpick: " .. newUses .. "/" .. (usesVal and usesVal.MaxValue or 3)
                        end
                    end)

                    task.wait(0.008)
                end
            end
        end

        task.wait(0.1)
        LastTick = tick()
    end

    -- Explicitly wait a bit longer for the Broken confirmation before the final check -
    -- the server may set the flag with a small delay after
    -- the minigame visually finished.
    do
        local confirmStart = tick()
        while safeObj and safeObj.Parent and tick() - confirmStart < 3 do
            local values = safeObj:FindFirstChild("Values")
            local broken = values and values:FindFirstChild("Broken")
            if broken and broken.Value then break end
            task.wait(0.1)
        end
    end

    StopLockpickCameraLock()
    StatusText = "Idle"
    local finalValues = safeObj and safeObj.Parent and safeObj:FindFirstChild("Values")
    local finalBroken = finalValues and finalValues:FindFirstChild("Broken")
    local ok = finalBroken and finalBroken.Value == true

    if not ok then
        Log("Safe never opened with the lockpick, switching target")
    end

    return ok
end


local function HackWithFists(safeObj)
    local fistsInBackpack = LocalPlayer.Backpack and LocalPlayer.Backpack:FindFirstChild("Fists")
    if fistsInBackpack then
        EquipTool("Fists")
        task.wait(0.5)
    end

    local events = ReplicatedStorage:FindFirstChild("Events")
    if not events then return false end
    local remote1 = events:FindFirstChild("XMHH.2")
    local remote2 = events:FindFirstChild("XMHH2.2")
    local mainPart = safeObj:FindFirstChild("MainPart") or safeObj.PrimaryPart
    if not remote1 or not remote2 or not mainPart then return false end

    Log("Opening register with fists")
    StatusText = "Breaking register (fists)"
    local startTime = tick()
    local hits = 0

    while Settings.Enabled and safeObj and safeObj.Parent do
        local values = safeObj:FindFirstChild("Values")
        if not values then break end
        local broken = values:FindFirstChild("Broken")
        if broken and broken.Value then
            Log("Register already broken")
            break
        end
        if tick() - startTime > 8 then
            Log("Fist break-in timed out")
            break
        end
        task.wait(0.25)

        local char = LocalPlayer.Character
        if not char then break end
        local fists = char:FindFirstChild("Fists")
        if not fists then
            local bp = LocalPlayer.Backpack and LocalPlayer.Backpack:FindFirstChild("Fists")
            if bp then
                EquipTool("Fists")
                task.wait(0.3)
                fists = char:FindFirstChild("Fists")
            end
        end

        local arm = char:FindFirstChild("Right Arm") or char:FindFirstChild("RightHand")
        if not arm then break end

        local ok, result = pcall(function()
            return remote1:InvokeServer("🍞", tick(), fists, "DZDRRRKI", safeObj, "Register")
        end)
        if ok and result then
            pcall(function()
                remote2:FireServer("🍞", tick(), fists, "2389ZFX34", result, false, arm, mainPart, safeObj, mainPart.Position, mainPart.Position)
            end)
            hits = hits + 1
        end
        LastTick = tick()
    end

    task.wait(0.3)
    Log("Register handled with fists, hits: " .. hits)
    StatusText = "Idle"
    return true
end

local function parseCashTextToNumber(value)
    if type(value) == "number" then
        return value
    end
    local text = tostring(value or "")
    text = text:gsub(",", "")
    text = text:gsub("%$", "")
    text = text:gsub("%s+", "")
    local number = tonumber(text:match("%-?%d+%.?%d*"))
    return number or 0
end

-- Cache of found objects so we do not run GetDescendants() over the whole PlayerGui
-- on every iteration of the main loop (expensive, especially on mobile).
local statLabelCache = {}

local function findStatValueNearLabel(keyword)
    keyword = tostring(keyword):lower()

    local cached = statLabelCache[keyword]
    if cached and cached.Parent then
        local ok, text = pcall(function() return cached.Text end)
        if ok and tostring(text):match("%d") then
            return tostring(text)
        end
    end

    local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
    if not playerGui then return nil end

    for _, obj in ipairs(playerGui:GetDescendants()) do
        if obj:IsA("TextLabel") or obj:IsA("TextButton") then
            local text = tostring(obj.Text or ""):lower()
            local name = tostring(obj.Name or ""):lower()
            if text == keyword or name == keyword or name:find(keyword, 1, true) then
                local parent = obj.Parent
                if parent then
                    for _, sibling in ipairs(parent:GetChildren()) do
                        if sibling ~= obj and (sibling:IsA("TextLabel") or sibling:IsA("TextButton")) then
                            local sText = tostring(sibling.Text or "")
                            if sText:match("%d") then
                                statLabelCache[keyword] = sibling
                                return sText
                            end
                        end
                    end
                end
            end
        end
    end
    return nil
end

local function readCashAmountValue()
    local text = findStatValueNearLabel("cash")
    if text then
        StatsInfo.CashAmount = parseCashTextToNumber(text)
    end
    return StatsInfo.CashAmount
end

local function readStatsGui()
    local bankText = findStatValueNearLabel("bank")
    if bankText then
        StatsInfo.BankAmount = parseCashTextToNumber(bankText)
    end

    -- Allowance in this game is a countdown timer ("12:32"), not a cash
    -- amount, so we keep both the raw text and a numeric approximation separately.
    local allowanceText = findStatValueNearLabel("allowance")
    if allowanceText then
        StatsInfo.AllowanceText = allowanceText
        local minutes, seconds = allowanceText:match("(%d+):(%d+)")
        if minutes and seconds then
            StatsInfo.AllowanceSecondsLeft = tonumber(minutes) * 60 + tonumber(seconds)
        else
            StatsInfo.AllowanceAmount = parseCashTextToNumber(allowanceText)
        end
    end
end

local function findATMMainPart()
    local map = Workspace:FindFirstChild("Map")
    local atmz = map and map:FindFirstChild("ATMz")
    if not atmz then return nil end

    local character = LocalPlayer.Character
    local hrp = character and character:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end

    local closestPart, closestDist = nil, math.huge
    for _, atm in ipairs(atmz:GetChildren()) do
        local mainPart = atm:FindFirstChild("MainPart")
        if mainPart and mainPart:IsA("BasePart") then
            local dist = (hrp.Position - mainPart.Position).Magnitude
            if dist < closestDist then
                closestDist = dist
                closestPart = mainPart
            end
        end
    end
    return closestPart
end

-- Dedicated ATM-approach routine (deposit and allowance both use this).
-- Unlike MoveToTarget (built for safes/registers), this computes the
-- stand-in-front position from the ATM's own flattened facing direction and
-- retries pathing a few times; if no path is found it just retries rather
-- than falling back to humanoid:MoveTo. The end-of-walk step only turns the
-- character to face the ATM - it never snaps/teleports position - which is
-- what avoids tripping the anti-exploit movement check.
local function walkToATM(atmMainPart)
    local character = LocalPlayer.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local hrp = character and character:FindFirstChild("HumanoidRootPart")
    if not humanoid or not hrp then return false end

    SetTargetHighlight(atmMainPart, "atm")

    local atmCF = atmMainPart.CFrame
    local lookVec = Vector3.new(atmCF.LookVector.X, 0, atmCF.LookVector.Z)
    if lookVec.Magnitude > 0.1 then
        lookVec = lookVec.Unit
    else
        lookVec = Vector3.new((hrp.Position - atmCF.Position).X, 0, (hrp.Position - atmCF.Position).Z)
        lookVec = (lookVec.Magnitude > 0.1) and lookVec.Unit or Vector3.new(1, 0, 0)
    end
    local targetPos = atmCF.Position + lookVec * 3.5

    local reached = false
    for attempt = 1, 3 do
        hrp = character:FindFirstChild("HumanoidRootPart")
        if not hrp then break end

        StatusText = "Heading to ATM (attempt " .. attempt .. ")"
        local waypoints = ComputePath(hrp.Position, targetPos)

        if waypoints and #waypoints >= 2 then
            for _, waypoint in ipairs(waypoints) do
                hrp = character:FindFirstChild("HumanoidRootPart")
                if not hrp then break end
                local wpPos = waypoint.Position + Vector3.new(0, 2.5, 0)
                local dist = (wpPos - hrp.Position).Magnitude
                if dist > 0.3 then
                    local tween = TweenService:Create(hrp,
                        TweenInfo.new(dist / Settings.MoveSpeed, Enum.EasingStyle.Linear),
                        { CFrame = CFrame.new(wpPos) * (hrp.CFrame - hrp.CFrame.Position) }
                    )
                    tween:Play()
                    tween.Completed:Wait()
                end
                if waypoint.Action == Enum.PathWaypointAction.Jump then
                    humanoid.Jump = true
                    task.wait(0.1)
                end
                hrp = character:FindFirstChild("HumanoidRootPart")
                if hrp and (hrp.Position - atmMainPart.Position).Magnitude <= 5 then
                    reached = true
                    break
                end
            end
        else
            StatusText = "No path to ATM, retrying..."
        end

        if reached then break end
        task.wait(0.5)
    end

    if reached then
        hrp = character:FindFirstChild("HumanoidRootPart")
        if hrp then
            hrp.CFrame = CFrame.new(hrp.Position, Vector3.new(atmMainPart.Position.X, hrp.Position.Y, atmMainPart.Position.Z))
            hrp.AssemblyLinearVelocity = Vector3.zero
        end
        task.wait(0.3)
    end

    ClearPathVisuals()
    return reached
end

local function performDepositRequest(events, cash)
    local remote = events and events:FindFirstChild("ATM")
    local atmMainPart = findATMMainPart()
    if not remote or not remote:IsA("RemoteFunction") or not atmMainPart then
        Log("Deposit: remote or nearest ATM not found")
        return false
    end
    local wasFarming = Settings.Enabled
    Settings.Enabled = false
    local moved = walkToATM(atmMainPart)
    Settings.Enabled = wasFarming
    if not moved then
        Log("Deposit: failed to reach ATM")
        return false
    end
    pcall(function() VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.E, false, game) end)
    task.wait(0.3)
    pcall(function() VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game) end)
    task.wait(0.3)
    local ok, accepted = pcall(remote.InvokeServer, remote, "DP", cash, atmMainPart)
    Log("Deposit: InvokeServer ok=" .. tostring(ok) .. " accepted=" .. tostring(accepted))
    return ok and accepted == true
end

local function tryDeposit()
    if not Settings.AutoDeposit then return false end
    if StatsInfo.DepositInProgress then return true end

    local currentTime = tick()
    if currentTime < StatsInfo.DepositCooldownUntil then return false end
    if currentTime - StatsInfo.DepositLastAttemptAt < 1.5 then return false end

    local cash = readCashAmountValue()
    local threshold = Settings.AutoDepositThreshold or 5000
    if threshold <= 0 or cash < threshold then return false end

    local events = ReplicatedStorage:FindFirstChild("Events")
    if not events then return false end

    StatsInfo.DepositLastAttemptAt = tick()
    StatsInfo.DepositInProgress = true
    Log("Auto deposit: taking $" .. math.floor(cash) .. " to the bank")
    StatusText = "Depositing to bank"

    local ok, success = pcall(function()
        local result = performDepositRequest(events, cash)
        task.wait(0.2)
        return result and readCashAmountValue() <= 0
    end)

    StatsInfo.DepositInProgress = false
    StatsInfo.DepositCooldownUntil = tick() + 2.5
    StatusText = "Idle"

    if ok and success then
        Log("Auto deposit completed")
    end

    return ok and success == true
end

local function maybeAutoDeposit()
    if not Settings.AutoDeposit then return false end
    return tryDeposit()
end

local function claimAllowance()
    local events = ReplicatedStorage:FindFirstChild("Events")
    local remote = events and events:FindFirstChild("CLMZALOW")
    local atm = findATMMainPart()
    if not remote or not atm then
        return false, "allowance_unavailable"
    end

    local wasFarming = Settings.Enabled
    Settings.Enabled = false
    local moved = walkToATM(atm)
    Settings.Enabled = wasFarming
    if not moved then
        Log("Allowance: failed to reach ATM")
        return false, "atm_unreachable"
    end

    pcall(function() VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.E, false, game) end)
    task.wait(0.3)
    pcall(function() VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game) end)
    task.wait(0.3)

    local ok, accepted, message, blocked, amount = pcall(remote.InvokeServer, remote, atm)
    Log("Allowance: InvokeServer ok=" .. tostring(ok) .. " accepted=" .. tostring(accepted))
    if not ok then return false, accepted end
    if type(amount) == "number" then
        StatsInfo.AllowanceAmount = amount
    end
    return accepted == true, message, blocked, amount
end

local function CleanupTempIgnored()
    local now = tick()
    for obj, expiry in pairs(Settings.TempIgnored) do
        if now > expiry then
            Settings.TempIgnored[obj] = nil
            for i, v in ipairs(Settings.IgnoredList) do
                if v == obj then
                    table.remove(Settings.IgnoredList, i)
                    break
                end
            end
            Log("Ignored object unlocked")
        end
    end
end

-- Cached so the folder is only searched for once instead of on every call.
-- The full Workspace:GetDescendants() fallback below is expensive (it walks
-- every instance in the game); doing that every farm-loop tick - or worse,
-- every single frame from ESP - was the main reason the farm felt like it
-- was "searching forever". Re-validated only if the cached reference dies.
local CachedBredFolder = nil

local function findBredFolder()
    if CachedBredFolder and CachedBredFolder:IsDescendantOf(Workspace) then
        return CachedBredFolder
    end
    local bredFolder = nil
    local map = Workspace:FindFirstChild("Map")
    if map then
        bredFolder = map:FindFirstChild("BredMakurz")
    end
    if not bredFolder then
        local filter = Workspace:FindFirstChild("Filter")
        if filter then
            bredFolder = filter:FindFirstChild("BredMakurz")
        end
    end
    if not bredFolder then
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj.Name == "BredMakurz" and obj:IsA("Folder") then
                bredFolder = obj
                break
            end
        end
    end
    CachedBredFolder = bredFolder
    return bredFolder
end

local function UpdateTargetsList()
    CleanupTempIgnored()
    local bredFolder = findBredFolder()
    if not bredFolder then
        Log("BredMakurz folder not found")
        return 0, 0
    end
    local character = LocalPlayer.Character
    if not character then return 0, 0 end
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return 0, 0 end
    local safes = {}
    local registers = {}
    TotalSafesCount = 0
    TotalRegistersCount = 0
    SortedTargets = {}
    for _, obj in ipairs(bredFolder:GetChildren()) do
        local nameLower = obj.Name:lower()
        if nameLower:find("safe") or nameLower:find("register") then
            if nameLower:find("safe") then
                TotalSafesCount = TotalSafesCount + 1
            else
                TotalRegistersCount = TotalRegistersCount + 1
            end
            if isTargetSkipped(obj.Name) then continue end
            if Settings.ProcessedList[obj] then continue end
            if Settings.TempIgnored[obj] then continue end
            local values = obj:FindFirstChild("Values")
            if values then
                local broken = values:FindFirstChild("Broken")
                if broken and not broken.Value then
                    local mainPart = obj:FindFirstChild("MainPart") or obj.PrimaryPart
                    local isSubwayZone = nameLower:find("%f[%a]sw%f[%A]") ~= nil
                    local isBufferZoneTarget = getBufferZoneForTarget(obj.Name) ~= nil
                    if mainPart and (mainPart.Position.Y >= 4.8 or isSubwayZone or isBufferZoneTarget) then
                        local targetInfo = { obj = obj, part = mainPart, pos = mainPart.Position }
                        if nameLower:find("safe") then
                            table.insert(safes, targetInfo)
                        else
                            table.insert(registers, targetInfo)
                        end
                        table.insert(SortedTargets, targetInfo)
                    end
                end
            end
        end
    end
    AvailableSafes = safes
    AvailableRegisters = registers
    table.sort(SortedTargets, function(a, b)
        return (a.pos - hrp.Position).Magnitude < (b.pos - hrp.Position).Magnitude
    end)
    AvailableSafesCount = #safes
    AvailableRegistersCount = #registers
    return AvailableSafesCount + AvailableRegistersCount, TotalSafesCount + TotalRegistersCount
end

local function AnalyzeTargetsCount()
    local available, total = UpdateTargetsList()
    TotalAvailableTargets = available
    Log("Total available: " .. available .. "/" .. total .. " targets")
    if available < 20 then
        SuggestionText = "Few targets left (" .. available .. "), lots of competition. Switch servers."
        Log("⚠️ " .. SuggestionText)
        pcall(function()
            HttpService:SetCore("SendNotification", {
                Title = "Suggestion",
                Text = SuggestionText,
                Duration = 10
            })
        end)
    else
        SuggestionText = "Enough targets (" .. available .. "), safe to farm."
    end
end
AnalyzeTargetsCount()

local function FindMoneyNearTarget(targetObj)
    local mainPart = targetObj:FindFirstChild("MainPart") or targetObj.PrimaryPart
    if not mainPart then return {} end
    local spawnedBread = Workspace:FindFirstChild("Filter") and Workspace.Filter:FindFirstChild("SpawnedBread")
    if not spawnedBread then return {} end
    local moneyParts = {}
    for _, bread in ipairs(spawnedBread:GetChildren()) do
        pcall(function()
            if bread:IsA("Part") and bread.Transparency < 1 then
                if (bread.Position - mainPart.Position).Magnitude <= 25 then
                    table.insert(moneyParts, bread)
                end
            end
        end)
    end
    return moneyParts
end

local function CollectMoneyNearTarget(targetObj)
    local moneyParts = FindMoneyNearTarget(targetObj)
    if #moneyParts == 0 then return false end
    Log("Collecting " .. #moneyParts .. " cash stacks near the safe")
    StatusText = "Collecting cash"
    for _, money in ipairs(moneyParts) do
        if not Settings.Enabled then break end
        pcall(function()
            if money and money.Parent and money.Transparency < 1 then
                MoveToTarget(money)
                local pickupEvent = ReplicatedStorage:FindFirstChild("Events") and ReplicatedStorage.Events:FindFirstChild("CZDPZUS")
                if pickupEvent then
                    pcall(function() pickupEvent:FireServer(money) end)
                end
                task.wait(0.3)
            end
        end)
    end
    StatusText = "Idle"
    return #FindMoneyNearTarget(targetObj) > 0
end

local function HackSafe(safeObj)
    if not HasTool("Crowbar") then
        Log("No crowbar to open the safe, trying to buy one...")
        local bought = BuyCrowbar()
        if not bought then
            Log("Failed to buy a crowbar, skipping the safe")
            return false
        end
        Log("Crowbar bought, returning to the safe")
        local mainPartForReturn = safeObj:FindFirstChild("MainPart") or safeObj.PrimaryPart
        if mainPartForReturn then
            MoveToTargetSmart(mainPartForReturn, safeObj, "target")
        end
    end
    if not LocalPlayer.Character:FindFirstChild("Crowbar") then
        Log("Crowbar in backpack, equipping...")
        EquipTool("Crowbar")
        task.wait(1)
    end
    if not HasTool("Crowbar") then
        Log("Crowbar never appeared, skipping")
        return false
    end
    task.wait(1.5)
    local events = ReplicatedStorage:FindFirstChild("Events")
    if not events then
        Log("Events folder not found")
        return false
    end
    local remote1 = events:FindFirstChild("XMHH.2")
    local remote2 = events:FindFirstChild("XMHH2.2")
    local mainPart = safeObj:FindFirstChild("MainPart") or safeObj.PrimaryPart
    if not remote1 or not remote2 then
        Log("Break-in remote events not found")
        return false
    end
    if not mainPart then
        Log("Safe has no main part")
        return false
    end
    Log("Starting safe break-in")
    StatusText = "Breaking safe"
    local startTime = tick()
    local hits = 0
    while Settings.Enabled and safeObj and safeObj.Parent do
        local values = safeObj:FindFirstChild("Values")
        if not values then break end
        local broken = values:FindFirstChild("Broken")
        if broken and broken.Value then
            Log("Safe already broken")
            break
        end
        if tick() - startTime > 25 then
            Log("Break-in timed out")
            break
        end
        task.wait(0.4)
        local crowbar = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Crowbar")
        if not crowbar then
            crowbar = LocalPlayer.Backpack and LocalPlayer.Backpack:FindFirstChild("Crowbar")
            if crowbar then EquipTool("Crowbar") end
        end
        if not crowbar then break end
        local arm = LocalPlayer.Character:FindFirstChild("Right Arm") or LocalPlayer.Character:FindFirstChild("RightHand")
        if not arm then break end
        local success, result = pcall(function() return remote1:InvokeServer("🍞", tick(), crowbar, "DZDRRRKI", safeObj, "Register") end)
        if success and result then
            pcall(function() remote2:FireServer("🍞", tick(), crowbar, "2389ZFX34", result, false, arm, mainPart, safeObj, mainPart.Position, mainPart.Position) end)
            hits = hits + 1
        end
        if hits % 4 == 0 then task.wait(0.8) end
        LastTick = tick()
    end
    task.wait(2)
    Log("Break-in complete, hits: " .. hits)
    StatusText = "Idle"
    return true
end

local IsRespawning = false
local RespawnConnection = nil

local function PressE()
    pcall(function() VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.E, false, game) end)
    task.wait(0.1)
    pcall(function() VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game) end)
end

local function StopRespawnHandler()
    if IsRespawning then
        IsRespawning = false
        if RespawnConnection then
            RespawnConnection:Disconnect()
            RespawnConnection = nil
        end
    end
end

local function StartRespawnHandler()
    if IsRespawning then return end
    IsRespawning = true
    Log("Death detected - pressing E to respawn")
    StatusText = "Dead"
    RespawnConnection = RunService.Heartbeat:Connect(function()
        if not IsRespawning then
            if RespawnConnection then
                RespawnConnection:Disconnect()
                RespawnConnection = nil
            end
            return
        end
        local character = LocalPlayer.Character
        local humanoid = character and character:FindFirstChild("Humanoid")
        if character and humanoid and humanoid.Health > 0 then
            StopRespawnHandler()
            StatusText = "Idle"
            return
        end
        pcall(PressE)
    end)
end

local function OnCharacterAdded(newChar)
    StopRespawnHandler()
    if Settings.Enabled then
        Settings.NeedsStartupToolCheck = true
    end
    task.wait(3)
    IsRising = false
    HasReachedTargetY = false
    if Settings.Enabled then
        Settings.IsDead = false
        LastTick = tick()
        RiseToTargetY()
        Log("Character respawned, continuing")
        StatusText = "Idle"
    end
    local humanoid = newChar:WaitForChild("Humanoid", 5)
    if humanoid then
        humanoid.Died:Connect(StartRespawnHandler)
    end
end

LocalPlayer.CharacterAdded:Connect(OnCharacterAdded)
if LocalPlayer.Character then
    OnCharacterAdded(LocalPlayer.Character)
end

local EspEnabled = false
local EspHeartbeatConnection = nil
local EspElements = {}
local EspTextSize = 20

local function FormatName(rawName)
    rawName = string.gsub(rawName, "([a-z])([A-Z])", "%1 %2")
    rawName = string.gsub(rawName, "_", " ")
    if rawName:lower():find("safe") then
        return "🔒 " .. rawName
    elseif rawName:lower():find("register") then
        return "💰 " .. rawName
    end
    return rawName
end

local function CreateHighlight(part, color)
    local highlight = Instance.new("Highlight")
    highlight.Name = "ESP_Highlight"
    highlight.Adornee = part
    highlight.FillColor = color
    highlight.FillTransparency = 0.5
    highlight.OutlineColor = Color3.new(1, 1, 1)
    highlight.OutlineTransparency = 0
    highlight.Parent = part
    return highlight
end

local function UpdateESP()
    if not EspEnabled then return end
    local bredFolder = findBredFolder()
    if not bredFolder then return end
    local character = LocalPlayer.Character
    local hrp = character and character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    for _, obj in ipairs(bredFolder:GetChildren()) do
        local nameLower = obj.Name:lower()
        if nameLower:find("safe") or nameLower:find("register") then
            local mainPart = obj.PrimaryPart or obj:FindFirstChildOfClass("BasePart")
            if not mainPart then continue end
            local values = obj:FindFirstChild("Values")
            local brokenVal = values and values:FindFirstChild("Broken")
            local isBroken = brokenVal and brokenVal.Value
            local color = isBroken and Color3.new(1, 0, 0) or Color3.new(0, 1, 0)
            local esp = EspElements[obj]
            if not esp then
                local billboard = Instance.new("BillboardGui")
                billboard.Name = "ESP_Billboard"
                billboard.Adornee = mainPart
                billboard.Size = UDim2.new(0, 200, 0, 50)
                billboard.StudsOffset = Vector3.new(0, 4, 0)
                billboard.AlwaysOnTop = true
                billboard.MaxDistance = 1000
                billboard.Parent = obj
                local label = Instance.new("TextLabel")
                label.Size = UDim2.new(1, 0, 1, 0)
                label.BackgroundTransparency = 1
                label.Font = Enum.Font.SourceSansBold
                label.TextScaled = false
                label.Text = FormatName(obj.Name)
                label.TextColor3 = color
                label.TextStrokeTransparency = 0
                label.TextStrokeColor3 = Color3.new(0, 0, 0)
                label.TextSize = EspTextSize
                label.Parent = billboard
                local highlight = CreateHighlight(obj, color)
                EspElements[obj] = {
                    billboard = billboard,
                    highlight = highlight,
                    label = label
                }
                if brokenVal then
                    brokenVal:GetPropertyChangedSignal("Value"):Connect(function()
                        if not EspEnabled or not EspElements[obj] then return end
                        local e = EspElements[obj]
                        if brokenVal.Value then
                            e.label.TextColor3 = Color3.new(1, 0, 0)
                            if e.highlight then
                                e.highlight.FillColor = Color3.new(1, 0, 0)
                            end
                        else
                            e.label.TextColor3 = Color3.new(0, 1, 0)
                            if e.highlight then
                                e.highlight.FillColor = Color3.new(0, 1, 0)
                            end
                        end
                    end)
                end
            else
                if brokenVal then
                    esp.label.TextColor3 = isBroken and Color3.new(1, 0, 0) or Color3.new(0, 1, 0)
                    if esp.highlight then
                        esp.highlight.FillColor = isBroken and Color3.new(1, 0, 0) or Color3.new(0, 1, 0)
                    end
                end
                if esp.label then
                    esp.label.TextSize = EspTextSize
                end
            end
        end
    end
    for obj, data in pairs(EspElements) do
        if not obj or not obj.Parent then
            pcall(function()
                if data.billboard then data.billboard:Destroy() end
                if data.highlight then data.highlight:Destroy() end
            end)
            EspElements[obj] = nil
        end
    end
end

local function EnableESP()
    if EspEnabled then return end
    EspEnabled = true
    EspHeartbeatConnection = RunService.Heartbeat:Connect(UpdateESP)
    Log("ESP for all safes/registers ENABLED")
end

local function DisableESP()
    if not EspEnabled then return end
    EspEnabled = false
    if EspHeartbeatConnection then
        EspHeartbeatConnection:Disconnect()
        EspHeartbeatConnection = nil
    end
    for obj, data in pairs(EspElements) do
        pcall(function()
            if data.billboard then data.billboard:Destroy() end
            if data.highlight then data.highlight:Destroy() end
        end)
    end
    EspElements = {}
    Log("ESP for all safes/registers DISABLED")
end

local function SetupBrokenTracking()
    Log("Running target analysis...")
    BrokenStatusMap = {}
    local bredFolder = findBredFolder()
    if bredFolder then
        for _, obj in ipairs(bredFolder:GetChildren()) do
            local values = obj:FindFirstChild("Values")
            if values then
                local broken = values:FindFirstChild("Broken")
                if broken then
                    BrokenStatusMap[obj] = broken.Value
                    broken:GetPropertyChangedSignal("Value"):Connect(function()
                        if Settings.Enabled then
                            BrokenStatusMap[obj] = broken.Value
                            UpdateTargetsList()
                            AnalyzeTargetsCount()
                            Log("Target status changed: " .. obj.Name .. " is now " .. tostring(broken.Value))
                        end
                    end)
                end
            end
        end
        Log("Target analysis complete, tracking " .. #BrokenStatusMap .. " objects")
    end
end
SetupBrokenTracking()

local function getPostBreakWaitSeconds(targetName)
    local nameLower = tostring(targetName):lower()
    if nameLower:find("register") then
        return 3
    elseif nameLower:find("small") then
        return 4
    elseif nameLower:find("medium") or nameLower:find("big") or nameLower:find("large") then
        return 6
    end
    return 4
end

local function BreakTargetAndCollect(targetObj)
    local hackSuccess
    local isRegister = targetObj.Name:lower():find("register") ~= nil

    if isRegister then
        hackSuccess = HackWithFists(targetObj)
    elseif Settings.BreakMethod == "Lockpick" then
        hackSuccess = HackSafeWithLockpick(targetObj)
    else
        if not LocalPlayer.Character:FindFirstChild("Crowbar") then
            EquipTool("Crowbar")
        end
        Log("Opening safe")
        hackSuccess = HackSafe(targetObj)
    end

    if hackSuccess then
        Log("Safe opened, collecting cash")
        local stillMoney = CollectMoneyNearTarget(targetObj)
        local attempts = 5
        while stillMoney and attempts > 0 do
            task.wait(2)
            stillMoney = CollectMoneyNearTarget(targetObj)
            attempts = attempts - 1
        end
        Settings.ProcessedList[targetObj] = true
        Log("Safe fully processed")

        local waitTime = getPostBreakWaitSeconds(targetObj.Name)
        Log("Standing still for " .. waitTime .. " sec after break-in (" .. targetObj.Name .. ")")
        task.wait(waitTime)
        return true
    else
        Log("Failed to open safe, temporarily ignoring")
        Settings.TempIgnored[targetObj] = tick() + Settings.IgnoreDuration
        table.insert(Settings.IgnoredList, targetObj)
        return false
    end
end

-- Look for ANY other not-yet-processed/not-broken object from the SAME
-- buffer zone within 1000 studs of the character's current position. Not
-- limited to 2 objects - works as a chain as long as targets remain in the zone.
local function findNearbyZoneSibling(zone, excludeObj)
    local character = LocalPlayer.Character
    local hrp = character and character:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end

    local closest, closestDist = nil, math.huge
    for _, info in ipairs(SortedTargets) do
        if info.obj ~= excludeObj and zone.names[info.obj.Name] and not Settings.TempIgnored[info.obj] then
            local dist = (info.pos - hrp.Position).Magnitude
            if dist <= 1000 and dist < closestDist then
                closestDist = dist
                closest = info
            end
        end
    end
    return closest
end

local function MainFarmLoop()
    Log("Auto-farm loop started")
    RiseToTargetY()
    while true do
        task.wait(0.3)
        if not Settings.Enabled then
            task.wait(0.5)
            continue
        end
        Log("=== Farm cycle ===")
        local character = LocalPlayer.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        Settings.IsDead = (not humanoid) or (humanoid.Health <= 0)
        if Settings.IsDead then
            Log("Character is dead, waiting")
            task.wait(3)
            continue
        end
        RiseToTargetY()

        if Settings.NeedsStartupToolCheck then
            Settings.NeedsStartupToolCheck = false
            local needed = Settings.BreakMethod
            local have = (needed == "Lockpick" and CountTools("Lockpick") > 0)
                or (needed == "Crowbar" and HasTool("Crowbar"))

            if have then
                Log("Before starting: " .. needed .. " already in inventory, going to farm")
            else
                Log("Before starting: no " .. needed .. " in inventory, heading to dealer first")
                StatusText = "Heading to dealer for a tool"
                local bought
                if needed == "Lockpick" then
                    bought = BuyLockpickBatch()
                else
                    bought = BuyCrowbar()
                end
                if bought then
                    Log("Tool purchased, going to farm")
                else
                    Log("Failed to buy the tool before starting, will retry during farming")
                end
            end
        end

        pcall(readStatsGui)
        pcall(readCashAmountValue)
        if Settings.AutoDeposit then
            pcall(maybeAutoDeposit)
        end
        local available, total = UpdateTargetsList()
        TotalAvailableTargets = available
        if available < 5 then
            Log("Few targets left (" .. available .. "), recommend switching servers")
        end
        if available == 0 then
            Log("No targets available, waiting 5 sec")
            task.wait(5)
            continue
        end
        local nextTarget = nil
        local minDist = math.huge
        for _, targetInfo in ipairs(SortedTargets) do
            if not Settings.TempIgnored[targetInfo.obj] then
                local dist = (targetInfo.pos - LocalPlayer.Character.HumanoidRootPart.Position).Magnitude
                if dist < minDist then
                    minDist = dist
                    nextTarget = targetInfo.obj
                end
            end
        end
        if not nextTarget then
            Log("No targets available, waiting 5 sec")
            task.wait(5)
            continue
        end
        local mainPart = nextTarget:FindFirstChild("MainPart") or nextTarget.PrimaryPart
        if not mainPart then
            Log("Target has no MainPart, skipping")
            Settings.ProcessedList[nextTarget] = true
            continue
        end
        Log("Moving to target: " .. nextTarget.Name .. ", distance " .. math.floor((mainPart.Position - LocalPlayer.Character.HumanoidRootPart.Position).Magnitude))
        local moveSuccess, moveReason = MoveToTargetSmart(mainPart, nextTarget, "target")
        if moveReason == "target_broken" then
            Log("Someone else broke the target first, taking the next one")
            Settings.ProcessedList[nextTarget] = true
            continue
        end
        if moveSuccess then
            local success = BreakTargetAndCollect(nextTarget)

            if success then
                local zone = getBufferZoneForTarget(nextTarget.Name)
                if zone then
                    while Settings.Enabled do
                        UpdateTargetsList()
                        local sibling = findNearbyZoneSibling(zone, nextTarget)
                        if not sibling then break end

                        Log("Zone " .. zone.name .. " has another nearby target (" .. sibling.obj.Name .. "), going directly without waypoints")
                        SetTargetHighlight(sibling.part, "target")
                        local siblingMove = MoveToTarget(sibling.part, sibling.obj, "target")
                        if not siblingMove then
                            Settings.TempIgnored[sibling.obj] = tick() + Settings.IgnoreDuration
                            break
                        end

                        BreakTargetAndCollect(sibling.obj)
                        nextTarget = sibling.obj
                    end
                end
            end
        else
            Log("Failed to reach target, temporarily ignoring")
            Settings.TempIgnored[nextTarget] = tick() + Settings.IgnoreDuration
            table.insert(Settings.IgnoredList, nextTarget)
        end
        task.wait(2)
    end
end

-- ── Безопасная загрузка Obsidian ─────────────────────────────
local repo = "https://raw.githubusercontent.com/deividcomsono/Obsidian/main/"

local function safeLoad(url, name)
    print("[TereyakiOS] Загружаю " .. name .. "...")
    local ok, src = pcall(function() return game:HttpGet(url) end)
    if not ok or not src or src == "" then
        error("[TereyakiOS] ОШИБКА: не удалось скачать " .. name .. " (" .. tostring(src) .. ")", 2)
    end
    local fn, err = loadstring(src)
    if not fn then
        error("[TereyakiOS] ОШИБКА: loadstring " .. name .. " → " .. tostring(err), 2)
    end
    local ok2, result = pcall(fn)
    if not ok2 then
        error("[TereyakiOS] ОШИБКА: выполнение " .. name .. " → " .. tostring(result), 2)
    end
    print("[TereyakiOS] ✓ " .. name .. " загружен")
    return result
end

local Library     = safeLoad(repo .. "Library.lua",              "Library")
local ThemeManager = safeLoad(repo .. "addons/ThemeManager.lua", "ThemeManager")
local SaveManager  = safeLoad(repo .. "addons/SaveManager.lua",  "SaveManager")

local Options = Library.Options
local Toggles = Library.Toggles

local Window = Library:CreateWindow({
    Title         = "TereyakiOS",
    Footer        = "v5",
    ShowCustomCursor = false,
    NotifySide    = "Right",
})

-- Совместимость: Rayfield.Flags → Toggles / Options
local Rayfield = {
    Flags = setmetatable({}, {
        __index = function(_, k)
            return Toggles[k] or Options[k]
        end
    }),
    Notify = function(_, t)
        Library:Notify({ Title = t.Title or "", Description = t.Content or "", Time = t.Duration or 3 })
    end
}

-- Вкладки Obsidian
local TabAimlock   = Window:AddTab("Aimlock",     "crosshair")
local TabSilentAim = Window:AddTab("Silent Aim",  "eye-off")
local TabAltFarm   = Window:AddTab("AltFarm",     "zap")
local TabMain      = Window:AddTab("Farm",        "home")
local TabStats     = Window:AddTab("Info",        "bar-chart")
local TabSkip      = Window:AddTab("Skip List",   "list")
local TabESP       = Window:AddTab("ESP",         "eye")
local TabUISet     = Window:AddTab("UI",          "sliders")

-- Groupbox'ы напрямую
local GB_Main      = TabMain:AddLeftGroupbox("Farm")
local GB_MainR     = TabMain:AddRightGroupbox("Settings")
local GB_Stats     = TabStats:AddLeftGroupbox("Info")
local GB_Skip      = TabSkip:AddLeftGroupbox("Skip List")
local GB_AltFarm   = TabAltFarm:AddLeftGroupbox("AltFarm")
local GB_Aimlock   = TabAimlock:AddLeftGroupbox("Aimlock")
local GB_SilentAim = TabSilentAim:AddLeftGroupbox("Silent Aim")
local GB_SilentAimR= TabSilentAim:AddRightGroupbox("Hit Chances")
local GB_ESP       = TabESP:AddLeftGroupbox("ESP")
local GB_ESPR      = TabESP:AddRightGroupbox("ESP Options")
local GB_UISet     = TabUISet:AddLeftGroupbox("Menu", "wrench")
local GB_UITheme   = TabUISet:AddRightGroupbox("Theme")
local SKIP_LIST_ALL_NAMES = {
    "MediumSafe_HO_39", "MediumSafe_HO_41",
    "MediumSafe_SU_32", "MediumSafe_SW_9", "MediumSafe_TS_20",
    "MediumSafe_T_45", "MediumSafe_T_46",
    "Register_BS_47", "Register_B_10", "Register_B_19", "Register_B_33",
    "Register_B_40", "Register_B_7", "Register_C_1", "Register_GS_16",
    "Register_HO_23", "Register_M_25", "Register_M_31", "Register_M_5",
    "Register_M_6", "Register_P_13", "Register_P_14", "Register_TS_27",
    "Register_TS_4", "Register_VI_29",
    "SmallSafe_BD_12", "SmallSafe_BD_18", "SmallSafe_C_3", "SmallSafe_FA_34",
    "SmallSafe_FA_35", "SmallSafe_FA_36", "SmallSafe_M_17",
    "SmallSafe_SU_15", "SmallSafe_SU_22", "SmallSafe_SW_11", "SmallSafe_SW_26",
    "SmallSafe_TO_42", "SmallSafe_TO_43", "SmallSafe_TO_44", "SmallSafe_WH_28",
}

local function applySkipSelection(selected)
    local newSkipList = {}
    if type(selected) == "table" then
        for key, value in pairs(selected) do
            if type(key) == "number" and type(value) == "string" then
                newSkipList[value] = true
            elseif value == true and type(key) == "string" then
                newSkipList[key] = true
            end
        end
    end
    SkipList = newSkipList
    local names = {}
    for name in pairs(SkipList) do table.insert(names, name) end
    Log("Skip List updated: " .. table.concat(names, ", "))
end

GB_Skip:AddDropdown("SkipListDropdown", {
    Text   = "Skip these objects",
    Values = SKIP_LIST_ALL_NAMES,
    Default = 1,
    Multi  = true,
    Callback = applySkipSelection,
})

GB_Main:AddToggle("AutoFarmToggle", {
    Text = "Start Farm", Default = false,
    Callback = function(value)
        Settings.Enabled = value
        if value then
            Settings.IgnoredList = {}
            Settings.ProcessedList = {}
            Settings.TempIgnored = {}
            Settings.NeedsStartupToolCheck = true
            UpdateTargetsList()
            AnalyzeTargetsCount()
            RiseToTargetY()
            Log("Auto-farm ENABLED")
            Library:Notify({ Title = "TereyakiOS", Description = "Started", Time = 2 })
        else
            ClearPathVisuals()
            SomeFlag2 = false
            StatusText = "Idle"
            Log("Auto-farm DISABLED")
            Library:Notify({ Title = "TereyakiOS", Description = "Stopped", Time = 2 })
        end
    end
})

GB_Main:AddToggle("AutoPickupMoneyToggle", {
    Text = "Auto Money", Default = false,
    Callback = function(value)
        if value then StartAutoPickup() else StopAutoPickup() end
    end
})

GB_Main:AddToggle("InvisibilityToggle", {
    Text = "Invis (R6)", Default = false,
    Callback = function(value)
        if value then _G.Invis_Enable() else _G.Invis_Disable() end
    end
})

GB_Main:AddToggle("AntiAfkToggle", {
    Text = "Anti-AFK", Default = false,
    Callback = function(value)
        AntiAfkEnabled = value
        if value then EnableAntiAfk() else DisableAntiAfk() end
    end
})

GB_Main:AddToggle("NoFallDamageToggle", {
    Text = "No Fall Damage", Default = false,
    Callback = function(value)
        if value then StartNoFallDamage() else StopNoFallDamage() end
    end
})

GB_Main:AddToggle("AdminCheckToggle", {
    Text = "Admin Check", Default = false,
    Callback = function(value)
        if value then AdminCheck_Enable() else AdminCheck_Disable() end
    end
})

GB_MainR:AddDropdown("BreakMethodDropdown", {
    Text = "Safe Break Method",
    Values = { "Crowbar", "Lockpick" },
    Default = Settings.BreakMethod,
    Multi = false,
    Callback = function(value)
        if not value then return end
        Settings.BreakMethod = value
        Log("Safe break method: " .. value)
        Library:Notify({ Title = "Break Method", Description = value, Time = 2 })
        if value == "Lockpick" then
            task.spawn(function()
                if CountTools("Lockpick") > 0 then
                    Log("Lockpicks already in inventory, continuing to farm")
                else
                    Log("No lockpicks in inventory, heading to dealer to buy more")
                    Library:Notify({ Title = "Break Method", Description = "No lockpicks, heading to dealer", Time = 2 })
                    BuyLockpickBatch()
                end
            end)
        end
    end
})

GB_MainR:AddSlider("SpeedSlider", {
    Text = "Speed", Default = 22, Min = 10, Max = 45, Rounding = 0,
    Callback = function(value) Settings.MoveSpeed = value end
})

GB_MainR:AddToggle("AutoDepositToggle", {
    Text = "Auto Deposit", Default = false,
    Callback = function(value) Settings.AutoDeposit = value end
})

GB_MainR:AddSlider("DepositThresholdSlider", {
    Text = "Deposit At ($)", Default = 5000, Min = 500, Max = 50000, Rounding = 0, Suffix = "$",
    Callback = function(value) Settings.AutoDepositThreshold = value end
})

GB_MainR:AddToggle("AutoAllowanceToggle", {
    Text = "Auto Claim Allowance", Default = false,
    Callback = function(value) Settings.AutoAllowance = value end
})

local statusLbl    = GB_Stats:AddLabel("Status: Idle",       false)
local safesLbl     = GB_Stats:AddLabel("Safes: 0/0",         false)
local registersLbl = GB_Stats:AddLabel("Registers: 0/0",     false)
local remainingLbl = GB_Stats:AddLabel("Remaining: 0/0",     false)
local suggestionLbl= GB_Stats:AddLabel("Tip: Start the farm",false)
local cashLbl      = GB_Stats:AddLabel("Cash: $0",           false)
local bankLbl      = GB_Stats:AddLabel("Bank: $0",           false)
local allowanceLbl = GB_Stats:AddLabel("Allowance: $0",      false)

local function setLabel(lbl, title, content)
    pcall(function() lbl:SetText(title .. ": " .. content) end)
end

task.spawn(function()
    while true do
        if Settings.Enabled then
            setLabel(statusLbl,    "Status",    StatusText)
            setLabel(safesLbl,     "Safes",     AvailableSafesCount .. "/" .. TotalSafesCount)
            setLabel(registersLbl, "Registers", AvailableRegistersCount .. "/" .. TotalRegistersCount)
            setLabel(remainingLbl, "Remaining", (AvailableSafesCount + AvailableRegistersCount) .. "/" .. (TotalSafesCount + TotalRegistersCount))
            setLabel(suggestionLbl,"Tip",       SuggestionText)
        else
            setLabel(statusLbl,    "Status",    "Idle")
            setLabel(safesLbl,     "Safes",     "0/0")
            setLabel(registersLbl, "Registers", "0/0")
            setLabel(remainingLbl, "Remaining", "0/0")
            setLabel(suggestionLbl,"Tip",       "Start the farm")
        end
        pcall(readStatsGui)
        pcall(readCashAmountValue)
        setLabel(cashLbl,      "Cash",      "$" .. math.floor(StatsInfo.CashAmount))
        setLabel(bankLbl,      "Bank",      "$" .. math.floor(StatsInfo.BankAmount))
        setLabel(allowanceLbl, "Allowance", StatsInfo.AllowanceText ~= "" and StatsInfo.AllowanceText or ("$" .. math.floor(StatsInfo.AllowanceAmount)))
        task.wait(0.5)
    end
end)

-------------------------------------------------------------------------------
--    ALTFARM TAB – Teleport Farm + Save Locations + AutoClicker
-------------------------------------------------------------------------------
do
    local AltTab = GB_AltFarm
    local RS  = game:GetService("RunService")
    local Plrs = game:GetService("Players")
    local LP  = Plrs.LocalPlayer
    local DeathRespawnEv = game:GetService("ReplicatedStorage"):WaitForChild("Events"):WaitForChild("DeathRespawn")

    ------------------------------------------------------------
    -- TELEPORT FARM
    ------------------------------------------------------------
    local AF_TPFarm_Enabled  = false
    local AF_TPFarm_Target   = "Sausage"
    local AF_TPFarm_StepConn = nil
    local AF_TPFarm_RndConn  = nil
    local AF_TPFarm_CharConn = nil

    local function AF_TPFarm_OnChar(char)
        if AF_TPFarm_StepConn then AF_TPFarm_StepConn:Disconnect() AF_TPFarm_StepConn = nil end
        task.wait(0.3)
        local hrp = char:FindFirstChild("HumanoidRootPart")
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not (hrp and hum) then return end
        AF_TPFarm_StepConn = RS.Stepped:Connect(function()
            if not AF_TPFarm_Enabled then return end
            local mp = Plrs:FindFirstChild(AF_TPFarm_Target)
            local mc = mp and mp.Character
            local mh = mc and mc:FindFirstChild("HumanoidRootPart")
            if mh then
                hrp.CFrame = mh.CFrame + mh.CFrame.LookVector * 3
                hum:GetPropertyChangedSignal("Health"):Connect(function() hum.Health = 0 end)
            end
        end)
    end

    local function AF_TPFarm_Enable()
        if AF_TPFarm_Enabled then return end
        AF_TPFarm_Enabled = true
        if LP.Character then AF_TPFarm_OnChar(LP.Character) end
        AF_TPFarm_CharConn = LP.CharacterAdded:Connect(function(c)
            if not AF_TPFarm_Enabled then return end
            AF_TPFarm_OnChar(c)
            local tool = LP.Backpack:FindFirstChildOfClass("Tool")
            if tool then tool.Parent = c end
        end)
        AF_TPFarm_RndConn = RS.RenderStepped:Connect(function()
            if not AF_TPFarm_Enabled then return end
            local c = LP.Character
            if c then
                local h = c:FindFirstChildOfClass("Humanoid")
                if h and h.Health <= 0 then DeathRespawnEv:InvokeServer("KMG4R904") end
            end
        end)
    end

    local function AF_TPFarm_Disable()
        if not AF_TPFarm_Enabled then return end
        AF_TPFarm_Enabled = false
        if AF_TPFarm_StepConn then AF_TPFarm_StepConn:Disconnect() AF_TPFarm_StepConn = nil end
        if AF_TPFarm_RndConn  then AF_TPFarm_RndConn:Disconnect()  AF_TPFarm_RndConn  = nil end
        if AF_TPFarm_CharConn then AF_TPFarm_CharConn:Disconnect() AF_TPFarm_CharConn = nil end
    end

    -- UI: input for target name
    AltTab:AddInput("AF_TPFarm_Target", {
        Text = "Target Username", Default = "Sausage",
        Placeholder = "Enter player username...",
        Finished = false,
        Callback = function(val) AF_TPFarm_Target = val end,
    })

    AltTab:AddToggle("AF_TPFarm", {
        Text = "Teleport Farm", Default = false,
        Callback = function(val)
            if val then AF_TPFarm_Enable() else AF_TPFarm_Disable() end
        end,
    })

    ------------------------------------------------------------
    -- SAVE LOCATIONS
    ------------------------------------------------------------
    local AF_Locations = {
        { name = "Save Cube",       pos = Vector3.new(-4184.4, 102.7, 276.9)  },
        { name = "Save Vibecheck",  pos = Vector3.new(-4857.5, -161.5, -918.3)},
        { name = "Save Mountain",   pos = Vector3.new(-5169.8, 102.6, -515.5) },
        { name = "Save Infection",  pos = Vector3.new(-4598, 89, -232)         },
        { name = "Save Brawl1",     pos = Vector3.new(-48, 43, 36)            },
        { name = "Save Brawl2",     pos = Vector3.new(260, 69, 79)            },
        { name = "Save Void",       pos = Vector3.new(-5071, -259, -301)      },
    }

    local AF_ActiveSave   = nil
    local AF_SaveConn     = nil

    local function AF_SaveStart(pos)
        if AF_SaveConn then AF_SaveConn:Disconnect() AF_SaveConn = nil end
        AF_ActiveSave = pos
        AF_SaveConn = RS.RenderStepped:Connect(function()
            local c = LP.Character
            if not c then return end
            local hrp = c:FindFirstChild("HumanoidRootPart")
            local hum = c:FindFirstChildOfClass("Humanoid")
            if hrp then hrp.CFrame = CFrame.new(AF_ActiveSave) end
            if hum and hum.Health <= 0 then DeathRespawnEv:InvokeServer("KMG4R904") end
        end)
    end

    local function AF_SaveStop()
        if AF_SaveConn then AF_SaveConn:Disconnect() AF_SaveConn = nil end
        AF_ActiveSave = nil
    end

    -- Build one toggle per location
    local AF_LocToggles = {}
    for _, loc in ipairs(AF_Locations) do
        local locName = loc.name
        local locPos  = loc.pos
        AltTab:AddToggle("AF_Loc_" .. locName, {
            Text = locName, Default = false,
            Callback = function(val)
                if val then
                    for otherName, otherToggle in pairs(AF_LocToggles) do
                        if otherName ~= locName then
                            pcall(function() otherToggle:SetValue(false) end)
                        end
                    end
                    AF_SaveStart(locPos)
                else
                    AF_SaveStop()
                end
            end,
        })
        AF_LocToggles[locName] = Toggles["AF_Loc_" .. locName]
    end

    ------------------------------------------------------------
    -- AUTOCLICKER (с настройками расстояния и кулдауна)
    ------------------------------------------------------------
    local AF_AC_Enabled   = false
    local AF_AC_Conn      = nil
    local AF_AC_Distance  = 15   -- default studs
    local AF_AC_Cooldown  = 0.7  -- default seconds
    local AF_AC_LastHit   = 0

    local function AF_AC_Attack()
        local char = LP.Character
        if not char then return end
        local hrp  = char:FindFirstChild("HumanoidRootPart")
        local hum  = char:FindFirstChildOfClass("Humanoid")
        if not (hrp and hum and hum.Health > 0) then return end
        if (tick() - AF_AC_LastHit) < AF_AC_Cooldown then return end

        local remote1 = game:GetService("ReplicatedStorage"):WaitForChild("Events"):WaitForChild("XMHH.2")
        local remote2 = game:GetService("ReplicatedStorage"):WaitForChild("Events"):WaitForChild("XMHH2.2")

        for _, plr in ipairs(Plrs:GetPlayers()) do
            if plr == LP then continue end
            local tc  = plr.Character
            local th  = tc and tc:FindFirstChild("HumanoidRootPart")
            local thm = tc and tc:FindFirstChildOfClass("Humanoid")
            if not (th and thm and thm.Health > 0) then continue end
            if (hrp.Position - th.Position).Magnitude > AF_AC_Distance then continue end

            local arg1 = {[1]="🍞",[2]=tick(),[3]=char:FindFirstChildOfClass("Tool"),[4]="43TRFWX",[5]="Normal",[6]=tick(),[7]=true}
            local ok, result = pcall(function() return remote1:InvokeServer(unpack(arg1)) end)
            if ok then
                task.wait(0.1)
                local tool = char:FindFirstChildOfClass("Tool")
                if tool then
                    local handle = tool:FindFirstChild("WeaponHandle") or tool:FindFirstChild("Handle") or char:FindFirstChild("Right Arm")
                    if handle and tc:FindFirstChild("Head") then
                        local arg2 = {[1]="🍞",[2]=tick(),[3]=tool,[4]="2389ZFX34",[5]=result,[6]=false,[7]=handle,[8]=tc:FindFirstChild("Head"),[9]=tc,[10]=hrp.Position,[11]=tc:FindFirstChild("Head").Position}
                        remote2:FireServer(unpack(arg2))
                    end
                end
            end
            AF_AC_LastHit = tick()
            break
        end
    end

    local function AF_AC_Enable()
        if AF_AC_Enabled then return end
        AF_AC_Enabled = true
        AF_AC_Conn = RS.RenderStepped:Connect(function()
            if AF_AC_Enabled then AF_AC_Attack() end
        end)
    end

    local function AF_AC_Disable()
        if not AF_AC_Enabled then return end
        AF_AC_Enabled = false
        if AF_AC_Conn then AF_AC_Conn:Disconnect() AF_AC_Conn = nil end
    end

    AltTab:AddToggle("AF_AutoClicker", {
        Text = "AutoClicker", Default = false,
        Callback = function(val)
            if val then AF_AC_Enable() else AF_AC_Disable() end
        end,
    })

    AltTab:AddSlider("AF_AC_Distance", {
        Text = "Attack Distance (studs)", Default = 15, Min = 5, Max = 25, Rounding = 0, Suffix = " st",
        Callback = function(val) AF_AC_Distance = val end,
    })

    AltTab:AddSlider("AF_AC_Cooldown", {
        Text = "Attack Cooldown (×0.1s)", Default = 7, Min = 4, Max = 15, Rounding = 0, Suffix = "×0.1s",
        Callback = function(val) AF_AC_Cooldown = val / 10 end,
    })
end

Library:Notify({ Title = "TereyakiOS", Description = "Loaded", Time = 2 })

-- Runs on its own 1-second cadence instead of piggybacking on the farm
-- loop, whose iterations can take 10-30+ seconds while walking to a target
-- or breaking it. Checking only at the top of that loop meant the
-- allowance countdown could pass through its claim window unseen and reset
-- before the loop ever looked again. Independent of Settings.Enabled so it
-- still works even if auto-farm itself is paused.
--
-- Trigger window is exact (== 0), not "close to 0": the countdown is
-- synced with the server, so the allowance genuinely cannot be claimed
-- a second early - walking to the ATM before 00:00 would just be a
-- wasted trip. A busy-flag (not a fixed time cooldown) guards against
-- overlapping attempts: if a claim attempt is rejected for any other
-- reason (ATM unreachable, remote hiccup), the flag clears as soon as it
-- returns and the very next 1-second poll tries again immediately.
local AllowanceClaimBusy = false
task.spawn(function()
    while true do
        task.wait(1)
        if not Settings.AutoAllowance then continue end
        if AllowanceClaimBusy then continue end
        pcall(readStatsGui)
        if StatsInfo.AllowanceSecondsLeft == 0 then
            AllowanceClaimBusy = true
            task.spawn(function()
                Log("Allowance timer hit 0, going to claim it")
                local claimed = claimAllowance()
                if claimed then
                    Log("Allowance claimed")
                end
                AllowanceClaimBusy = false
            end)
        end
    end
end)

-------------------------------------------------------------------------------
--    AIMLOCK TAB  (ported from Tereyakiware / HyperEscape)
-------------------------------------------------------------------------------
do
    local AL_Tab = GB_Aimlock

    -- ── state ──────────────────────────────────────────────────────────────
    local AL = {
        Enabled        = false,
        TeamCheck      = false,
        WallCheck      = false,
        StickyAim      = false,
        Prediction     = false,
        PredictionAmt  = 1,
        UseMouse       = true,
        MouseBind      = "MouseButton2",
        Keybind        = Enum.KeyCode.E,
        ShowFov        = false,
        Fov            = 150,
        Smoothing      = 0.3,
        AimPart        = "Head",
        IsAimKeyDown   = false,
        Target         = nil,
        CameraTween    = nil,
    }

    local AL_UIS         = game:GetService("UserInputService")
    local AL_TweenSvc    = game:GetService("TweenService")
    local AL_Players     = game:GetService("Players")
    local AL_LP          = AL_Players.LocalPlayer
    local AL_Camera      = workspace.CurrentCamera
    local AL_RunSvc      = game:GetService("RunService")
    local AL_CoreGui     = game:FindFirstChild("CoreGui")

    -- ── FOV circle ─────────────────────────────────────────────────────────
    local AL_FovGui = Instance.new("ScreenGui")
    AL_FovGui.Name            = "AL_FovGui"
    AL_FovGui.ResetOnSpawn    = false
    AL_FovGui.ZIndexBehavior  = Enum.ZIndexBehavior.Sibling
    AL_FovGui.Parent          = AL_CoreGui or AL_LP.PlayerGui

    local AL_FovFrame = Instance.new("Frame")
    AL_FovFrame.Name               = "FovCircle"
    AL_FovFrame.BackgroundTransparency = 1
    AL_FovFrame.AnchorPoint        = Vector2.new(0.5, 0.5)
    AL_FovFrame.BorderSizePixel    = 0
    AL_FovFrame.Parent             = AL_FovGui

    local AL_FovCorner = Instance.new("UICorner")
    AL_FovCorner.CornerRadius = UDim.new(1, 0)
    AL_FovCorner.Parent       = AL_FovFrame

    local AL_FovStroke = Instance.new("UIStroke")
    AL_FovStroke.Color     = Color3.fromRGB(255, 60, 60)
    AL_FovStroke.Thickness = 1.5
    AL_FovStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    AL_FovStroke.Parent   = AL_FovFrame

    -- ── helpers ────────────────────────────────────────────────────────────
    local function AL_IsAlive(plr)
        return plr
            and plr.Character
            and plr.Character:FindFirstChild("HumanoidRootPart")
            and plr.Character:FindFirstChildOfClass("Humanoid")
            and plr.Character:FindFirstChildOfClass("Humanoid").Health > 0
    end

    local function AL_SameTeam(a, b)
        if a.Neutral or b.Neutral then return false end
        return a.Team == b.Team
    end

    local function AL_IsVisible(pos)
        if not AL.WallCheck then return true end
        return #AL_Camera:GetPartsObscuringTarget({ pos }, { AL_Camera, AL_LP.Character }) == 0
    end

    local function AL_GetAimPos(character)
        local targetPart
        if AL.AimPart ~= "Random" then
            targetPart = character:FindFirstChild(AL.AimPart)
        else
            local mouse2D  = AL_UIS:GetMouseLocation()
            local bestDist = math.huge
            for _, part in ipairs(character:GetChildren()) do
                if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                    local sp, onScreen = AL_Camera:WorldToViewportPoint(part.Position)
                    if onScreen then
                        local d = (Vector2.new(sp.X, sp.Y) - mouse2D).Magnitude
                        if d < bestDist then targetPart, bestDist = part, d end
                    end
                end
            end
        end
        if not targetPart then return nil end

        local pos = targetPart.Position

        -- Prediction: смещаем цель на вектор скорости персонажа
        if AL.Prediction then
            local hrp = character:FindFirstChild("HumanoidRootPart")
            if hrp then
                local velocity = hrp.AssemblyLinearVelocity
                pos = pos + velocity * AL.PredictionAmt
            end
        end

        return pos
    end

    local function AL_FovPart(character)
        if AL.AimPart == "Random" then
            return character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("Head")
        end
        return character:FindFirstChild(AL.AimPart)
    end

    local function AL_ClosestToMouse()
        local mouse2D   = AL_UIS:GetMouseLocation()
        local bestFov   = AL.Fov
        local bestPlayer = nil
        for _, plr in ipairs(AL_Players:GetPlayers()) do
            if plr == AL_LP then continue end
            if AL.TeamCheck and AL_SameTeam(plr, AL_LP) then continue end
            if not AL_IsAlive(plr) then continue end
            local fp = AL_FovPart(plr.Character)
            if not fp then continue end
            local sp, onScreen = AL_Camera:WorldToViewportPoint(fp.Position)
            if not onScreen then continue end
            local d = (Vector2.new(sp.X, sp.Y) - mouse2D).Magnitude
            if d < bestFov and AL_IsVisible(fp.Position) then
                bestFov    = d
                bestPlayer = plr
            end
        end
        return bestPlayer
    end

    local function AL_DoTween(aimPos)
        if AL.CameraTween then AL.CameraTween:Cancel() end
        AL.CameraTween = AL_TweenSvc:Create(
            AL_Camera,
            TweenInfo.new(AL.Smoothing, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
            { CFrame = CFrame.new(AL_Camera.CFrame.Position, aimPos) }
        )
        AL.CameraTween:Play()
    end

    -- ── input: keyboard ────────────────────────────────────────────────────
    AL_UIS.InputBegan:Connect(function(key, gameProcessed)
        if gameProcessed then return end
        if key.KeyCode == AL.Keybind and not AL.UseMouse then
            AL.Target         = AL_ClosestToMouse()
            AL.IsAimKeyDown   = true
        end
    end)
    AL_UIS.InputEnded:Connect(function(key)
        if key.KeyCode == AL.Keybind and not AL.UseMouse then
            AL.IsAimKeyDown = false
            if AL.CameraTween then AL.CameraTween:Cancel() end
        end
    end)

    -- ── input: mouse ───────────────────────────────────────────────────────
    local mouse = AL_LP:GetMouse()

    mouse.Button1Down:Connect(function()
        if AL.UseMouse and AL.MouseBind == "MouseButton1" then
            if AL.IsAimKeyDown then
                AL.IsAimKeyDown = false
                if AL.CameraTween then AL.CameraTween:Cancel() end
            else
                AL.Target       = AL_ClosestToMouse()
                AL.IsAimKeyDown = true
            end
        end
    end)
    mouse.Button1Up:Connect(function()
        if AL.UseMouse and AL.MouseBind == "MouseButton1" then
            AL.IsAimKeyDown = false
            if AL.CameraTween then AL.CameraTween:Cancel() end
        end
    end)
    mouse.Button2Down:Connect(function()
        if AL.UseMouse and AL.MouseBind == "MouseButton2" then
            AL.Target       = AL_ClosestToMouse()
            AL.IsAimKeyDown = true
        end
    end)
    mouse.Button2Up:Connect(function()
        if AL.UseMouse and AL.MouseBind == "MouseButton2" then
            AL.IsAimKeyDown = false
            if AL.CameraTween then AL.CameraTween:Cancel() end
        end
    end)

    -- ── heartbeat loop ─────────────────────────────────────────────────────
    AL_RunSvc.Heartbeat:Connect(function()
        -- FOV circle
        if AL.Enabled and AL.ShowFov then
            AL_FovStroke.Enabled = true
            local mp = AL_UIS:GetMouseLocation()
            local sz  = AL.Fov * 2
            AL_FovFrame.Position = UDim2.new(0, mp.X, 0, mp.Y - 36)
            AL_FovFrame.Size     = UDim2.fromOffset(sz, sz)
        else
            AL_FovStroke.Enabled = false
        end

        -- Aimlock
        if not (AL.Enabled and AL.IsAimKeyDown) then return end

        if AL.StickyAim then
            if AL.Target and AL_IsAlive(AL.Target) then
                local pos = AL_GetAimPos(AL.Target.Character)
                if pos then AL_DoTween(pos) end
            else
                AL.Target = AL_ClosestToMouse()
                if AL.Target then
                    local pos = AL_GetAimPos(AL.Target.Character)
                    if pos then AL_DoTween(pos) end
                end
            end
        else
            local t = AL_ClosestToMouse()
            if t then
                local pos = AL_GetAimPos(t.Character)
                if pos then AL_DoTween(pos) end
            elseif AL.CameraTween then
                AL.CameraTween:Cancel()
            end
        end
    end)

    -- ── Obsidian UI ────────────────────────────────────────────────────────
    AL_Tab:AddToggle("AL_Enabled",   { Text = "Aimlock",          Default = false, Callback = function(v) AL.Enabled   = v end })
    AL_Tab:AddToggle("AL_StickyAim", { Text = "Sticky Aim",       Default = false, Callback = function(v) AL.StickyAim = v end })
    AL_Tab:AddToggle("AL_TeamCheck", { Text = "Team Check",       Default = false, Callback = function(v) AL.TeamCheck = v end })
    AL_Tab:AddToggle("AL_WallCheck", { Text = "Wall Check",       Default = false, Callback = function(v) AL.WallCheck = v end })
    AL_Tab:AddToggle("AL_ShowFov",   { Text = "Show FOV Circle",  Default = false, Callback = function(v) AL.ShowFov   = v end })
    AL_Tab:AddToggle("AL_UseMouse",  { Text = "Use Mouse Button", Default = true,  Callback = function(v) AL.UseMouse  = v end })
    AL_Tab:AddToggle("AL_Prediction",{ Text = "Prediction",       Default = false, Callback = function(v) AL.Prediction= v end })

    AL_Tab:AddSlider("AL_FovRadius", {
        Text = "FOV Radius", Default = AL.Fov, Min = 10, Max = 600, Rounding = 0, Suffix = " px",
        Callback = function(v) AL.Fov = v end,
    })
    AL_Tab:AddSlider("AL_Smoothing", {
        Text = "Smoothing", Default = 6, Min = 1, Max = 30, Rounding = 0, Suffix = " ×0.05s",
        Callback = function(v) AL.Smoothing = v * 0.05 end,
    })
    AL_Tab:AddSlider("AL_PredictionAmt", {
        Text = "Prediction Amount", Default = 100, Min = 1, Max = 500, Rounding = 0, Suffix = " ×0.01",
        Callback = function(v) AL.PredictionAmt = v * 0.01 end,
    })

    AL_Tab:AddDropdown("AL_AimPart", {
        Text = "Aim Part",
        Values = { "Head","HumanoidRootPart","Torso","UpperTorso","LowerTorso","Right Arm","Left Arm","RightUpperArm","LeftUpperArm","Right Leg","Left Leg","Random" },
        Default = "Head", Multi = false,
        Callback = function(v) AL.AimPart = v or "Head" end,
    })
    AL_Tab:AddDropdown("AL_MouseBind", {
        Text = "Mouse Bind",
        Values = { "MouseButton1", "MouseButton2" },
        Default = "MouseButton2", Multi = false,
        Callback = function(v) AL.MouseBind = v or "MouseButton2" end,
    })

    AL_Tab:AddLabel("Key Bind (when not mouse)"):AddKeyPicker("AL_Keybind", {
        Default = "E", Mode = "Hold", NoUI = false, Text = "Aimlock Key",
        Callback = function(v) AL.Keybind = Enum.KeyCode[v] or Enum.KeyCode.E end,
    })
end

-- ============================================================
--  SILENT AIM
-- ============================================================

local SA = {
    On           = false,
    DrawCircle   = false,
    DrawSize     = 150,
    VisCheck     = true,
    MaxDist      = 500,
    UseFOV       = true,
    IgnoreDowned = true,
    FOVCol       = Color3.fromRGB(70, 130, 255),
    PartChance = {
        Head       = 85,
        UpperTorso = 70,
        LowerTorso = 60,
        RightArm   = 40,
        LeftArm    = 40,
        RightLeg   = 30,
        LeftLeg    = 30,
    },
    PartAliases = {
        Head       = {"Head"},
        UpperTorso = {"UpperTorso", "Torso"},
        LowerTorso = {"LowerTorso", "HumanoidRootPart"},
        RightArm   = {"RightUpperArm", "Right Arm"},
        LeftArm    = {"LeftUpperArm", "Left Arm"},
        RightLeg   = {"RightUpperLeg", "Right Leg"},
        LeftLeg    = {"LeftUpperLeg", "Left Leg"},
    },
    PartOrder = {"Head","UpperTorso","LowerTorso","RightArm","LeftArm","RightLeg","LeftLeg"},
}

local SAFovCircle = Drawing.new("Circle")
SAFovCircle.Visible      = false
SAFovCircle.Filled       = false
SAFovCircle.Thickness    = 2
SAFovCircle.NumSides     = 64
SAFovCircle.Radius       = 150
SAFovCircle.Color        = Color3.fromRGB(70, 130, 255)
SAFovCircle.Transparency = 1

local SAConns    = {}
local SALoopConn = nil

local function SA_GetTargetPart(char)
    local pool = {}
    for _, key in ipairs(SA.PartOrder) do
        local chance = SA.PartChance[key] or 0
        if chance > 0 and math.random(1, 100) <= chance then
            for _, alias in ipairs(SA.PartAliases[key]) do
                local part = char:FindFirstChild(alias)
                if part then table.insert(pool, part); break end
            end
        end
    end
    if #pool == 0 then
        return char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart")
    end
    return pool[math.random(1, #pool)]
end

local function SA_IsValidChar(char)
    if not char then return false end
    local hum = char:FindFirstChildOfClass("Humanoid")
    return hum and hum.Health > 0
end

local function SA_IsDowned(char)
    local d = char:FindFirstChild("Downed")
    return d and d.Value
end

local function SA_GetValidTarget()
    if not SA.On then return nil end
    local Camera   = Workspace.CurrentCamera
    local target   = nil
    local minDist  = math.huge
    local mousePos = UserInputService:GetMouseLocation()

    for _, player in ipairs(Players:GetPlayers()) do
        if player == LocalPlayer then continue end
        local char = player.Character
        if not char or not SA_IsValidChar(char) then continue end
        if SA.IgnoreDowned and SA_IsDowned(char) then continue end

        local refPart = char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart")
        if not refPart then continue end
        local partPos = refPart.Position

        local myHRP = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if myHRP and (myHRP.Position - partPos).Magnitude > SA.MaxDist then continue end

        if SA.VisCheck then
            local ray = Ray.new(Camera.CFrame.Position, (partPos - Camera.CFrame.Position).Unit * 1000)
            local hit = workspace:FindPartOnRayWithIgnoreList(ray, {LocalPlayer.Character, Camera})
            if hit and not hit:IsDescendantOf(char) and hit.Transparency < 1 then continue end
        end

        local screenPos, onScreen = Camera:WorldToViewportPoint(partPos)
        if not onScreen then continue end

        if SA.UseFOV then
            local closestLimbDist = math.huge
            for _, limb in pairs(char:GetChildren()) do
                if limb:IsA("BasePart") then
                    local lsPos, lsOn = Camera:WorldToViewportPoint(limb.Position)
                    if lsOn then
                        local ld = (mousePos - Vector2.new(lsPos.X, lsPos.Y)).Magnitude
                        if ld < closestLimbDist then closestLimbDist = ld end
                    end
                end
            end
            if closestLimbDist > SA.DrawSize + 35 then continue end
            if closestLimbDist < minDist then minDist = closestLimbDist; target = player end
        else
            if myHRP then
                local wd = (myHRP.Position - partPos).Magnitude
                if wd < minDist then minDist = wd; target = player end
            end
        end
    end
    return target
end

local function SA_HookShoot()
    for _, conn in pairs(SAConns) do if conn then conn:Disconnect() end end
    SAConns = {}
    local ev2_bindable = ReplicatedStorage:FindFirstChild("Events2")
    local GNX_remote   = ReplicatedStorage:FindFirstChild("Events") and ReplicatedStorage.Events:FindFirstChild("GNX_S")
    local ZFK_remote   = ReplicatedStorage:FindFirstChild("Events") and ReplicatedStorage.Events:FindFirstChild("ZFKLF__H")

    local function processShot(gun, sPos, shots)
        if not SA.On then return nil, nil, nil end
        local t = SA_GetValidTarget()
        if not t or not t.Character then return nil, nil, nil end
        local targetChar = t.Character
        local targetPart = SA_GetTargetPart(targetChar)
        if not targetPart then return nil, nil, nil end
        local myGun = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Tool")
        if not myGun or myGun ~= gun then return nil, nil, nil end
        local hum = targetChar:FindFirstChildOfClass("Humanoid")
        if not hum or hum.Health <= 0 then return nil, nil, nil end
        local hitPos = targetPart.Position + Vector3.new(
            (math.random()-0.5)*0.3, (math.random()-0.5)*0.3, (math.random()-0.5)*0.3)
        local newDirs = {}
        for i = 1, #shots do
            local dir = (hitPos - sPos).Unit
            local sp  = Vector3.new((math.random()-0.5)*0.01,(math.random()-0.5)*0.01,(math.random()-0.5)*0.01)
            table.insert(newDirs, dir + sp)
        end
        return targetPart, hitPos, newDirs
    end

    if ev2_bindable and ZFK_remote then
        local viz = ev2_bindable:FindFirstChild("Visualize")
        if viz then
            local conn = viz.Event:Connect(function(_, sc, _, gun, _, sPos, bps)
                local tp, hp, nd = processShot(gun, sPos, bps)
                if not nd then return end
                task.spawn(function()
                    for i = 1, #nd do task.wait(0.01); pcall(function() ZFK_remote:FireServer("\xF0\x9F\xA7\x88", gun, sc, i, tp, hp, nd[i]) end) end
                end)
                if gun:FindFirstChild("Hitmarker") then pcall(function() gun.Hitmarker:Fire(tp) end) end
            end)
            table.insert(SAConns, conn)
        end
    end

    if GNX_remote and ZFK_remote then
        local conn = GNX_remote.OnClientEvent:Connect(function(st, sc, gun, ft, sPos, dirs, silenced)
            local tp, hp, nd = processShot(gun, sPos, dirs)
            if not nd then return end
            task.spawn(function()
                for i = 1, #nd do task.wait(0.01); pcall(function() ZFK_remote:FireServer("\xF0\x9F\xA7\x88", gun, sc, i, tp, hp, nd[i]) end) end
            end)
            if gun:FindFirstChild("Hitmarker") then pcall(function() gun.Hitmarker:Fire(tp) end) end
        end)
        table.insert(SAConns, conn)
    end
end

local function SA_Enable()
    if SA.On then return end
    SA.On = true
    if SALoopConn then SALoopConn:Disconnect() end
    SALoopConn = RunService.Heartbeat:Connect(function()
        if SA.DrawCircle then
            SAFovCircle.Position = UserInputService:GetMouseLocation()
            SAFovCircle.Radius   = SA.DrawSize
            SAFovCircle.Color    = SA.FOVCol
            SAFovCircle.Visible  = true
        else
            SAFovCircle.Visible = false
        end
    end)
    SA_HookShoot()
end

local function SA_Disable()
    if not SA.On then return end
    SA.On = false
    if SALoopConn then SALoopConn:Disconnect(); SALoopConn = nil end
    SAFovCircle.Visible = false
    for _, conn in pairs(SAConns) do if conn then conn:Disconnect() end end
    SAConns = {}
end

do
    local SA_Tab = GB_SilentAim

    SA_Tab:AddToggle("SA_On",         { Text = "Silent Aim",                  Default = false, Callback = function(v) if v then SA_Enable() else SA_Disable() end end })
    SA_Tab:AddToggle("SA_DrawFOV",    { Text = "Show FOV Circle",             Default = false, Callback = function(v) SA.DrawCircle = v end })
    SA_Tab:AddToggle("SA_UseFOV",     { Text = "Use FOV",                     Default = true,  Callback = function(v) SA.UseFOV = v end })
    SA_Tab:AddToggle("SA_VisCheck",   { Text = "Visibility Check (Wall Check)",Default = true, Callback = function(v) SA.VisCheck = v end })
    SA_Tab:AddToggle("SA_IgnoreDowned",{ Text = "Ignore Downed Players",      Default = true,  Callback = function(v) SA.IgnoreDowned = v end })

    SA_Tab:AddSlider("SA_FOVSize", { Text = "FOV Radius",    Default = 150, Min = 50,  Max = 500,  Rounding = 0, Suffix = "px",    Callback = function(v) SA.DrawSize = v end })
    SA_Tab:AddSlider("SA_MaxDist", { Text = "Max Distance",  Default = 500, Min = 50,  Max = 2000, Rounding = 0, Suffix = " studs",Callback = function(v) SA.MaxDist  = v end })

    local partDefs = {
        { key = "Head",       label = "Head",        default = 85 },
        { key = "UpperTorso", label = "Upper Torso", default = 70 },
        { key = "LowerTorso", label = "Lower Torso", default = 60 },
        { key = "RightArm",   label = "Right Arm",   default = 40 },
        { key = "LeftArm",    label = "Left Arm",    default = 40 },
        { key = "RightLeg",   label = "Right Leg",   default = 30 },
        { key = "LeftLeg",    label = "Left Leg",    default = 30 },
    }
    local SA_HitGB = GB_SilentAimR
    for _, entry in ipairs(partDefs) do
        SA_HitGB:AddSlider("SA_HC_" .. entry.key, {
            Text = entry.label .. " Hit Chance", Default = entry.default,
            Min = 0, Max = 100, Rounding = 0, Suffix = "%",
            Callback = function(v) SA.PartChance[entry.key] = v end
        })
    end
end

-- ============================================================
--  ESP  (из Tereyakiware)
-- ============================================================

local ESP_Settings = {
    Enabled     = false,
    TeamCheck   = false,
    MaxDistance = 4000,
    CharacterSize = Vector2.new(5, 6),
    Box = {
        Box         = false,
        Name        = false,
        Distance    = false,
        Health      = false,
        HealthBar   = false,
        Color       = Color3.fromRGB(255, 255, 255),
        Outline     = false,
        OutlineColor = Color3.fromRGB(0, 0, 0),
    },
    Tracer = {
        Tracer       = false,
        Color        = Color3.fromRGB(255, 255, 255),
        Outline      = false,
        OutlineColor = Color3.fromRGB(0, 0, 0),
    },
    Hilights = {
        Hilights            = false,
        AllWaysVisible      = false,
        OutlineTransparency = 0.5,
        FillTransparency    = 0.5,
        OutlineColor        = Color3.fromRGB(255, 0, 0),
        FillColor           = Color3.fromRGB(255, 255, 255),
    },
}

local ESPHolder = Instance.new("Folder")
ESPHolder.Name   = "TereyakiESP"
ESPHolder.Parent = (game:FindFirstChild("CoreGui") or LocalPlayer.PlayerGui)

local function ESP_IsAlive(player)
    return player
        and player.Character
        and player.Character:FindFirstChild("HumanoidRootPart")
        and player.Character:FindFirstChild("Humanoid")
        and player.Character.Humanoid.Health > 0
end

local function LoadESP(player)
    if player == LocalPlayer then return end

    local PlayerESP = Instance.new("Folder", ESPHolder)
    PlayerESP.Name  = player.Name .. "ESP"

    local BoxHolder    = Instance.new("ScreenGui", PlayerESP); BoxHolder.Name = "Box"; BoxHolder.DisplayOrder = 2; BoxHolder.ResetOnSpawn = false
    local TracerHolder = Instance.new("ScreenGui", PlayerESP); TracerHolder.Name = "Tracer"; TracerHolder.ResetOnSpawn = false
    local HilightHolder = Instance.new("Folder",   PlayerESP); HilightHolder.Name = "Hilight"

    -- Box frames
    local function makeFrame(parent, color)
        local f = Instance.new("Frame", parent)
        f.BackgroundColor3 = color; f.Visible = false; f.BorderSizePixel = 1
        return f
    end
    local LeftOutline   = makeFrame(BoxHolder, ESP_Settings.Box.OutlineColor)
    local RightOutline  = makeFrame(BoxHolder, ESP_Settings.Box.OutlineColor)
    local TopOutline    = makeFrame(BoxHolder, ESP_Settings.Box.OutlineColor)
    local BottomOutline = makeFrame(BoxHolder, ESP_Settings.Box.OutlineColor)
    local Left          = makeFrame(BoxHolder, ESP_Settings.Box.Color); Left.BorderSizePixel   = 0
    local Right         = makeFrame(BoxHolder, ESP_Settings.Box.Color); Right.BorderSizePixel  = 0
    local Top           = makeFrame(BoxHolder, ESP_Settings.Box.Color); Top.BorderSizePixel    = 0
    local Bottom        = makeFrame(BoxHolder, ESP_Settings.Box.Color); Bottom.BorderSizePixel = 0

    -- Labels
    local function makeLabel(parent)
        local l = Instance.new("TextLabel", parent)
        l.BackgroundTransparency = 1; l.Visible = false
        l.AnchorPoint = Vector2.new(0.5, 0.5); l.TextSize = 12; l.Font = Enum.Font.GothamBold
        l.TextColor3 = Color3.fromRGB(255,255,255); l.TextStrokeTransparency = 0
        l.Size = UDim2.new(0, 200, 0, 20)
        return l
    end
    local NameLabel     = makeLabel(BoxHolder); NameLabel.Text = player.Name
    local DistLabel     = makeLabel(BoxHolder)
    local HealthLabel   = makeLabel(BoxHolder)

    -- Health bar
    local HealthBG  = Instance.new("Frame", BoxHolder); HealthBG.Visible = false; HealthBG.BorderSizePixel = 1; HealthBG.BorderColor3 = ESP_Settings.Box.OutlineColor
    local HealthBar = Instance.new("Frame", BoxHolder); HealthBar.Visible = false; HealthBar.BorderSizePixel = 0; HealthBar.BackgroundColor3 = Color3.fromRGB(0,255,0)

    -- Tracer
    local TracerOutline = Instance.new("Frame", TracerHolder); TracerOutline.Visible = false; TracerOutline.BorderSizePixel = 1; TracerOutline.AnchorPoint = Vector2.new(0.5,0.5); TracerOutline.BackgroundColor3 = ESP_Settings.Tracer.OutlineColor
    local TracerLine    = Instance.new("Frame", TracerHolder); TracerLine.Visible = false; TracerLine.BorderSizePixel = 0; TracerLine.AnchorPoint = Vector2.new(0.5,0.5); TracerLine.BackgroundColor3 = ESP_Settings.Tracer.Color

    -- Highlight
    local Hilight = Instance.new("Highlight", HilightHolder); Hilight.Enabled = false

    local Camera = Workspace.CurrentCamera

    local co = coroutine.create(function()
        RunService.RenderStepped:Connect(function()
            if not ESP_IsAlive(player) then
                -- скрываем всё
                for _, f in ipairs({LeftOutline,RightOutline,TopOutline,BottomOutline,Left,Right,Top,Bottom,HealthBG,HealthBar,TracerOutline,TracerLine,NameLabel,DistLabel,HealthLabel}) do f.Visible = false end
                Hilight.Enabled = false; Hilight.Adornee = nil
                return
            end

            local hrp = player.Character.HumanoidRootPart
            local screen, onScreen = Camera:WorldToScreenPoint(hrp.Position)
            local frustumHeight = math.tan(math.rad(Camera.FieldOfView * 0.5)) * 2 * screen.Z
            local size     = Camera.ViewportSize.Y / frustumHeight * ESP_Settings.CharacterSize
            local position = Vector2.new(screen.X, screen.Y) - (size / 2 - Vector2.new(0, size.Y) / 20)
            local distNum  = math.floor(0.5 + (Camera.CFrame.Position - hrp.Position).Magnitude)

            local function hideAll()
                for _, f in ipairs({LeftOutline,RightOutline,TopOutline,BottomOutline,Left,Right,Top,Bottom,HealthBG,HealthBar,TracerOutline,TracerLine,NameLabel,DistLabel,HealthLabel}) do f.Visible = false end
                Hilight.Enabled = false; Hilight.Adornee = nil
            end

            if not onScreen or not ESP_Settings.Enabled or distNum > ESP_Settings.MaxDistance then
                hideAll(); return
            end

            -- Box
            if ESP_Settings.Box.Box then
                local function setBox(f, pos, sz) f.Position = UDim2.fromOffset(pos.X, pos.Y); f.Size = UDim2.fromOffset(sz.X, sz.Y) end
                setBox(Left,   Vector2.new(position.X, position.Y),             Vector2.new(size.X, 1))
                setBox(Right,  Vector2.new(position.X, position.Y+size.Y-1),    Vector2.new(size.X, 1))
                setBox(Top,    Vector2.new(position.X, position.Y),             Vector2.new(1, size.Y))
                setBox(Bottom, Vector2.new(position.X+size.X-1, position.Y),    Vector2.new(1, size.Y))
                LeftOutline.Position = Left.Position;   LeftOutline.Size = Left.Size
                RightOutline.Position = Right.Position; RightOutline.Size = Right.Size
                TopOutline.Position = Top.Position;     TopOutline.Size = Top.Size
                BottomOutline.Position = Bottom.Position; BottomOutline.Size = Bottom.Size
                for _, f in ipairs({Left,Right,Top,Bottom}) do f.Visible = true; f.BackgroundColor3 = ESP_Settings.Box.Color end
                for _, f in ipairs({LeftOutline,RightOutline,TopOutline,BottomOutline}) do
                    f.Visible = ESP_Settings.Box.Outline
                    f.BackgroundColor3 = ESP_Settings.Box.OutlineColor
                    f.BorderColor3     = ESP_Settings.Box.OutlineColor
                end
            else
                for _, f in ipairs({Left,Right,Top,Bottom,LeftOutline,RightOutline,TopOutline,BottomOutline}) do f.Visible = false end
            end

            -- Health bar
            if ESP_Settings.Box.HealthBar then
                local hum = player.Character:FindFirstChildOfClass("Humanoid")
                local health = hum and hum.Health or 0
                local maxH   = hum and hum.MaxHealth or 100
                local scale  = math.clamp(health / maxH, 0, 1)
                local barH   = size.Y * scale
                HealthBG.Visible  = true; HealthBar.Visible = true
                HealthBG.Size     = UDim2.fromOffset(4, size.Y)
                HealthBar.Size    = UDim2.fromOffset(2, barH)
                HealthBG.Position = UDim2.fromOffset(position.X - 8, position.Y)
                HealthBar.Position= UDim2.fromOffset(position.X - 7, position.Y + size.Y - barH)
                HealthBG.BackgroundColor3  = ESP_Settings.Box.OutlineColor
                HealthBG.BorderColor3      = ESP_Settings.Box.OutlineColor
                HealthBar.BackgroundColor3 = Color3.fromRGB(math.floor(255*(1-scale)), math.floor(255*scale), 0)
            else
                HealthBG.Visible = false; HealthBar.Visible = false
            end

            -- Health text
            if ESP_Settings.Box.Health then
                local hum = player.Character:FindFirstChildOfClass("Humanoid")
                HealthLabel.Visible  = true
                HealthLabel.Text     = hum and math.floor(hum.Health) or "?"
                HealthLabel.Position = UDim2.fromOffset(position.X - 25, position.Y + size.Y + 2)
            else
                HealthLabel.Visible = false
            end

            -- Name / Distance
            if ESP_Settings.Box.Name or ESP_Settings.Box.Distance then
                NameLabel.Visible = ESP_Settings.Box.Name
                DistLabel.Visible = ESP_Settings.Box.Distance and not ESP_Settings.Box.Name
                local labelY = screen.Y - (size.Y + 14) / 2
                NameLabel.Position = UDim2.fromOffset(screen.X, labelY)
                DistLabel.Position = UDim2.fromOffset(screen.X, labelY)
                DistLabel.Text = distNum .. "m"
                NameLabel.Text = ESP_Settings.Box.Distance
                    and (player.Name .. " [" .. distNum .. "m]")
                    or player.Name
            else
                NameLabel.Visible = false; DistLabel.Visible = false
            end

            -- Tracer
            if ESP_Settings.Tracer.Tracer then
                local targetV2 = Vector2.new(screen.X, screen.Y + size.Y / 2)
                local origin   = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y - 1)
                local mid      = (origin + targetV2) / 2
                local rot      = math.deg(math.atan2(targetV2.Y - origin.Y, targetV2.X - origin.X))
                local len      = (origin - targetV2).Magnitude
                TracerLine.Visible    = true
                TracerLine.Position   = UDim2.new(0, mid.X, 0, mid.Y)
                TracerLine.Size       = UDim2.fromOffset(len, 1)
                TracerLine.Rotation   = rot
                TracerLine.BackgroundColor3 = ESP_Settings.Tracer.Color
                TracerOutline.Visible   = ESP_Settings.Tracer.Outline
                TracerOutline.Position  = TracerLine.Position
                TracerOutline.Size      = TracerLine.Size
                TracerOutline.Rotation  = rot
                TracerOutline.BorderColor3 = ESP_Settings.Tracer.OutlineColor
            else
                TracerLine.Visible = false; TracerOutline.Visible = false
            end

            -- Highlight
            if ESP_Settings.Hilights.Hilights then
                Hilight.Enabled             = true
                Hilight.Adornee             = player.Character
                Hilight.OutlineColor        = ESP_Settings.Hilights.OutlineColor
                Hilight.FillColor           = ESP_Settings.Hilights.FillColor
                Hilight.FillTransparency    = ESP_Settings.Hilights.FillTransparency
                Hilight.OutlineTransparency = ESP_Settings.Hilights.OutlineTransparency
                Hilight.DepthMode           = ESP_Settings.Hilights.AllWaysVisible and "AlwaysOnTop" or "Occluded"
            else
                Hilight.Enabled = false; Hilight.Adornee = nil
            end
        end)

        -- Чистим папку когда игрок ушёл
        if not Players:FindFirstChild(player.Name) then
            PlayerESP:Destroy(); coroutine.yield()
        end
    end)
    coroutine.resume(co)
end

-- Грузим ESP для всех существующих и новых игроков
for _, plr in ipairs(Players:GetPlayers()) do
    if plr ~= LocalPlayer then LoadESP(plr) end
end
Players.PlayerAdded:Connect(function(plr)
    if plr ~= LocalPlayer then
        plr.CharacterAdded:Connect(function() task.wait(0.5); LoadESP(plr) end)
        LoadESP(plr)
    end
end)

-- ============================================================
--  UI: ВКЛАДКА ESP
-- ============================================================
do
    local ESP_Tab = GB_ESP
    local ESP_R   = GB_ESPR

    ESP_Tab:AddToggle("ESP_Enable",   { Text = "Enable ESP",  Default = false, Callback = function(v) ESP_Settings.Enabled   = v end })
    ESP_Tab:AddToggle("ESP_TeamCheck",{ Text = "Team Check",  Default = false, Callback = function(v) ESP_Settings.TeamCheck = v end })
    ESP_Tab:AddSlider("ESP_MaxDist",  { Text = "Max Distance",Default = 4000, Min = 100, Max = 4000, Rounding = 0, Suffix = " studs", Callback = function(v) ESP_Settings.MaxDistance = v end })

    ESP_Tab:AddToggle("ESP_Box",        { Text = "Box",          Default = false, Callback = function(v) ESP_Settings.Box.Box     = v end })
    ESP_Tab:AddToggle("ESP_BoxOutline", { Text = "Box Outline",  Default = false, Callback = function(v) ESP_Settings.Box.Outline = v end })
    ESP_Tab:AddToggle("ESP_Name",       { Text = "Name",         Default = false, Callback = function(v) ESP_Settings.Box.Name    = v end })
    ESP_Tab:AddToggle("ESP_Distance",   { Text = "Distance",     Default = false, Callback = function(v) ESP_Settings.Box.Distance= v end })
    ESP_Tab:AddToggle("ESP_HealthText", { Text = "Health Text",  Default = false, Callback = function(v) ESP_Settings.Box.Health  = v end })
    ESP_Tab:AddToggle("ESP_HealthBar",  { Text = "Health Bar",   Default = false, Callback = function(v) ESP_Settings.Box.HealthBar=v end })

    ESP_Tab:AddLabel("Box Color"):AddColorPicker("ESP_BoxColor", {
        Default = Color3.fromRGB(255,255,255),
        Callback = function(v) ESP_Settings.Box.Color = v end,
    })
    ESP_Tab:AddLabel("Outline Color"):AddColorPicker("ESP_OutlineColor", {
        Default = Color3.fromRGB(0,0,0),
        Callback = function(v) ESP_Settings.Box.OutlineColor = v; ESP_Settings.Tracer.OutlineColor = v end,
    })

    ESP_R:AddToggle("ESP_Tracer",       { Text = "Tracer",                  Default = false, Callback = function(v) ESP_Settings.Tracer.Tracer   = v end })
    ESP_R:AddToggle("ESP_TracerOutline",{ Text = "Tracer Outline",          Default = false, Callback = function(v) ESP_Settings.Tracer.Outline  = v end })
    ESP_R:AddLabel("Tracer Color"):AddColorPicker("ESP_TracerColor", {
        Default = Color3.fromRGB(255,255,255),
        Callback = function(v) ESP_Settings.Tracer.Color = v end,
    })

    ESP_R:AddToggle("ESP_Hilight",     { Text = "Highlight",               Default = false, Callback = function(v) ESP_Settings.Hilights.Hilights       = v end })
    ESP_R:AddToggle("ESP_HilightWalls",{ Text = "Highlight Through Walls", Default = false, Callback = function(v) ESP_Settings.Hilights.AllWaysVisible  = v end })
    ESP_R:AddLabel("Highlight Outline Color"):AddColorPicker("ESP_HilightOutlineColor", {
        Default = Color3.fromRGB(255,0,0),
        Callback = function(v) ESP_Settings.Hilights.OutlineColor = v end,
    })
    ESP_R:AddLabel("Highlight Fill Color"):AddColorPicker("ESP_HilightFillColor", {
        Default = Color3.fromRGB(255,255,255),
        Callback = function(v) ESP_Settings.Hilights.FillColor = v end,
    })
    ESP_R:AddSlider("ESP_HilightOutlineTransp", { Text = "Highlight Outline Transparency", Default = 50, Min = 0, Max = 100, Rounding = 0, Suffix = "%", Callback = function(v) ESP_Settings.Hilights.OutlineTransparency = v/100 end })
    ESP_R:AddSlider("ESP_HilightFillTransp",    { Text = "Highlight Fill Transparency",    Default = 50, Min = 0, Max = 100, Rounding = 0, Suffix = "%", Callback = function(v) ESP_Settings.Hilights.FillTransparency    = v/100 end })
end

-- ============================================================
--  UI SETTINGS (Obsidian ThemeManager + SaveManager)
-- ============================================================
--  UI SETTINGS (Obsidian ThemeManager + SaveManager)
-- ============================================================
do
    local MenuGroup = GB_UISet

    MenuGroup:AddToggle("KeybindMenuOpen", {
        Text = "Open Keybind Menu",
        Default = false,
        Callback = function(v) Library.KeybindFrame.Visible = v end,
    })

    MenuGroup:AddToggle("ShowCustomCursor", {
        Text = "Custom Cursor",
        Default = false,
        Callback = function(v) Library.ShowCustomCursor = v end,
    })

    MenuGroup:AddDropdown("NotificationSide", {
        Values  = { "Left", "Right" },
        Default = "Right",
        Text    = "Notification Side",
        Callback = function(v) Library:SetNotifySide(v) end,
    })

    MenuGroup:AddDivider()
    MenuGroup:AddLabel("Menu Keybind"):AddKeyPicker("MenuKeybind", {
        Default = "RightShift", NoUI = true, Text = "Menu keybind"
    })
    MenuGroup:AddButton({ Text = "Unload", Func = function() Library:Unload() end })

    Library.ToggleKeybind = Options.MenuKeybind

    ThemeManager:SetLibrary(Library)
    SaveManager:SetLibrary(Library)
    SaveManager:IgnoreThemeSettings()
    SaveManager:SetIgnoreIndexes({ "MenuKeybind" })
    ThemeManager:SetFolder("TereyakiOS")
    SaveManager:SetFolder("TereyakiOS/configs")
    ThemeManager:ApplyToGroupbox(GB_UITheme)
    SaveManager:BuildConfigSection(TabUISet)
    SaveManager:LoadAutoloadConfig()
end

task.spawn(MainFarmLoop)
