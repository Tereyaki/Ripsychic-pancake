local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local PathfindingService = game:GetService("PathfindingService")
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local VirtualInputManager = game:GetService("VirtualInputManager")
local UserInputService = game:GetService("UserInputService")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")

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

local VirtualUser = game:GetService("VirtualUser")
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
        VirtualInputManager:SendMouseMoveEvent(screenPos.X, screenPos.Y, game)
        task.wait(0.05)
        VirtualInputManager:SendMouseButtonEvent(screenPos.X, screenPos.Y, 0, true, game, 1)
        task.wait(0.03)
        VirtualInputManager:SendMouseButtonEvent(screenPos.X, screenPos.Y, 0, false, game, 1)
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
                            VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 1)
                            task.wait(0.02)
                            VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 1)
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
    VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.E, false, game)
    task.wait(0.3)
    VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game)
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

    VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.E, false, game)
    task.wait(0.3)
    VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game)
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
    VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.E, false, game)
    task.wait(0.1)
    VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game)
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

local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Window = Rayfield:CreateWindow({
    Name = "TereyakiOS",
    LoadingTitle = "TereyakiOS",
    LoadingSubtitle = "",
    ConfigurationSaving = { Enabled = false },
    Discord = { Enabled = false },
    KeySystem = false,
})

local Tabs = {
    Main = Window:CreateTab("Farm"),
    Stats = Window:CreateTab("Info"),
    Skip = Window:CreateTab("Skip List"),
    AltFarm = Window:CreateTab("AltFarm"),
    AimLock = Window:CreateTab("AimLock"),
    Control = Window:CreateTab("Control"),
}

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

Tabs.Skip:CreateDropdown({
    Name = "Skip these objects",
    Options = SKIP_LIST_ALL_NAMES,
    CurrentOption = {},
    MultipleOptions = true,
    Flag = "SkipListDropdown",
    Callback = applySkipSelection,
})

Tabs.Main:CreateToggle({
    Name = "Start Farm",
    CurrentValue = false,
    Flag = "AutoFarmToggle",
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
            Rayfield:Notify({ Title = "TereyakiOS", Content = "Started", Duration = 2 })
        else
            ClearPathVisuals()
            SomeFlag2 = false
            StatusText = "Idle"
            Log("Auto-farm DISABLED")
            Rayfield:Notify({ Title = "TereyakiOS", Content = "Stopped", Duration = 2 })
        end
    end
})

Tabs.Main:CreateToggle({
    Name = "Auto Money",
    CurrentValue = false,
    Flag = "AutoPickupMoneyToggle",
    Callback = function(value)
        if value then
            StartAutoPickup()
            Log("Auto money pickup ENABLED")
        else
            StopAutoPickup()
            Log("Auto money pickup DISABLED")
        end
    end
})

Tabs.Main:CreateToggle({
    Name = "Invis (R6)",
    CurrentValue = false,
    Flag = "InvisibilityToggle",
    Callback = function(value)
        if value then
            _G.Invis_Enable()
            Log("Invisibility ENABLED")
        else
            _G.Invis_Disable()
            Log("Invisibility DISABLED")
        end
    end
})

Tabs.Main:CreateToggle({
    Name = "Anti-AFK",
    CurrentValue = false,
    Flag = "AntiAfkToggle",
    Callback = function(value)
        AntiAfkEnabled = value
        if value then
            EnableAntiAfk()
            Log("Anti-AFK ENABLED")
        else
            DisableAntiAfk()
            Log("Anti-AFK DISABLED")
        end
    end
})

Tabs.Main:CreateToggle({
    Name = "No Fall Damage",
    CurrentValue = false,
    Flag = "NoFallDamageToggle",
    Callback = function(value)
        if value then
            StartNoFallDamage()
            Log("No Fall Damage ENABLED")
        else
            StopNoFallDamage()
            Log("No Fall Damage DISABLED")
        end
    end
})

Tabs.Main:CreateToggle({
    Name = "Admin Check",
    CurrentValue = false,
    Flag = "AdminCheckToggle",
    Callback = function(value)
        if value then
            AdminCheck_Enable()
        else
            AdminCheck_Disable()
        end
    end
})

Tabs.Main:CreateDropdown({
    Name = "Safe Break Method",
    Options = { "Crowbar", "Lockpick" },
    CurrentOption = { Settings.BreakMethod },
    MultipleOptions = false,
    Flag = "BreakMethodDropdown",
    Callback = function(selected)
        local value = selected
        if type(selected) == "table" then value = selected[1] end
        if not value then return end
        Settings.BreakMethod = value
        Log("Safe break method: " .. value)
        Rayfield:Notify({ Title = "Break Method", Content = value, Duration = 2 })

        if value == "Lockpick" then
            task.spawn(function()
                if CountTools("Lockpick") > 0 then
                    Log("Lockpicks already in inventory, continuing to farm")
                else
                    Log("No lockpicks in inventory, heading to dealer to buy more")
                    Rayfield:Notify({ Title = "Break Method", Content = "No lockpicks, heading to dealer", Duration = 2 })
                    BuyLockpickBatch()
                end
            end)
        end
    end
})

Tabs.Main:CreateSlider({
    Name = "Speed",
    Range = { 10, 45 },
    Increment = 1,
    Suffix = "",
    CurrentValue = 22,
    Flag = "SpeedSlider",
    Callback = function(value)
        Settings.MoveSpeed = value
        Log("Speed " .. value)
    end
})

Tabs.Main:CreateToggle({
    Name = "Auto Deposit",
    CurrentValue = false,
    Flag = "AutoDepositToggle",
    Callback = function(value)
        Settings.AutoDeposit = value
        Log("Auto deposit: " .. tostring(value))
    end
})

Tabs.Main:CreateSlider({
    Name = "Deposit At ($)",
    Range = { 500, 50000 },
    Increment = 100,
    Suffix = "$",
    CurrentValue = 5000,
    Flag = "DepositThresholdSlider",
    Callback = function(value)
        Settings.AutoDepositThreshold = value
    end
})

Tabs.Main:CreateToggle({
    Name = "Auto Claim Allowance",
    CurrentValue = false,
    Flag = "AutoAllowanceToggle",
    Callback = function(value)
        Settings.AutoAllowance = value
        Log("Auto allowance: " .. tostring(value))
    end
})

local statusPara = Tabs.Stats:CreateParagraph({ Title = "Status", Content = "Loading..." })
local safesPara = Tabs.Stats:CreateParagraph({ Title = "Safes", Content = "0/0" })
local registersPara = Tabs.Stats:CreateParagraph({ Title = "Registers", Content = "0/0" })
local remainingPara = Tabs.Stats:CreateParagraph({ Title = "Remaining", Content = "0/0" })
local suggestionPara = Tabs.Stats:CreateParagraph({ Title = "Tip", Content = "Loading..." })
local cashPara = Tabs.Stats:CreateParagraph({ Title = "Cash", Content = "$0" })
local bankPara = Tabs.Stats:CreateParagraph({ Title = "Bank", Content = "$0" })
local allowancePara = Tabs.Stats:CreateParagraph({ Title = "Allowance", Content = "$0" })

local function setParagraph(para, title, content)
    pcall(function() para:Set({ Title = title, Content = content }) end)
end

task.spawn(function()
    while true do
        if Settings.Enabled then
            setParagraph(statusPara, "Status", StatusText)
            setParagraph(safesPara, "Safes", AvailableSafesCount .. "/" .. TotalSafesCount)
            setParagraph(registersPara, "Registers", AvailableRegistersCount .. "/" .. TotalRegistersCount)
            setParagraph(remainingPara, "Remaining", (AvailableSafesCount + AvailableRegistersCount) .. "/" .. (TotalSafesCount + TotalRegistersCount))
            setParagraph(suggestionPara, "Tip", SuggestionText)
        else
            setParagraph(statusPara, "Status", "Idle")
            setParagraph(safesPara, "Safes", "0/0")
            setParagraph(registersPara, "Registers", "0/0")
            setParagraph(remainingPara, "Remaining", "0/0")
            setParagraph(suggestionPara, "Tip", "Start the farm")
        end
        pcall(readStatsGui)
        pcall(readCashAmountValue)
        setParagraph(cashPara, "Cash", "$" .. math.floor(StatsInfo.CashAmount))
        setParagraph(bankPara, "Bank", "$" .. math.floor(StatsInfo.BankAmount))
        setParagraph(allowancePara, "Allowance", StatsInfo.AllowanceText ~= "" and StatsInfo.AllowanceText or ("$" .. math.floor(StatsInfo.AllowanceAmount)))
        task.wait(0.5)
    end
end)

-------------------------------------------------------------------------------
--    ALTFARM TAB – Teleport Farm + Save Locations + AutoClicker
-------------------------------------------------------------------------------
do
    local AltTab = Tabs.AltFarm
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
    AltTab:CreateInput({
        Name        = "Target Username",
        CurrentValue = "Sausage",
        PlaceholderText = "Enter player username...",
        RemoveTextAfterFocusLost = false,
        Callback = function(val) AF_TPFarm_Target = val end,
    })

    -- UI: toggle for Teleport Farm
    AltTab:CreateToggle({
        Name         = "Teleport Farm",
        CurrentValue = false,
        Flag         = "AF_TPFarm",
        Callback     = function(val)
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

    local function AF_EquipFists()
        local char = LP.Character
        if not char then return end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then hum:UnequipTools() end
    end

    local function AF_SaveStart(pos)
        if AF_SaveConn then AF_SaveConn:Disconnect() AF_SaveConn = nil end
        AF_ActiveSave = pos
        AF_EquipFists()
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
        AltTab:CreateToggle({
            Name         = locName,
            CurrentValue = false,
            Flag         = "AF_Loc_" .. locName,
            Callback     = function(val)
                if val then
                    -- Turn off all other location toggles
                    for otherName, otherToggle in pairs(AF_LocToggles) do
                        if otherName ~= locName then
                            otherToggle:Set(false)
                        end
                    end
                    AF_SaveStart(locPos)
                else
                    AF_SaveStop()
                end
            end,
        })
        AF_LocToggles[locName] = Rayfield.Flags["AF_Loc_" .. locName]
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

    AltTab:CreateToggle({
        Name         = "AutoClicker",
        CurrentValue = false,
        Flag         = "AF_AutoClicker",
        Callback     = function(val)
            if val then AF_AC_Enable() else AF_AC_Disable() end
        end,
    })

    AltTab:CreateSlider({
        Name         = "Attack Distance (studs)",
        Range        = {5, 25},
        Increment    = 1,
        Suffix       = " st",
        CurrentValue = AF_AC_Distance,
        Flag         = "AF_AC_Distance",
        Callback     = function(val) AF_AC_Distance = val end,
    })

    AltTab:CreateSlider({
        Name         = "Attack Cooldown (sec)",
        Range        = {4, 15},   -- внутри делим на 10 → 0.4–1.5
        Increment    = 1,
        Suffix       = " ×0.1s",
        CurrentValue = 7,         -- = 0.7 sec
        Flag         = "AF_AC_Cooldown",
        Callback     = function(val) AF_AC_Cooldown = val / 10 end,
    })
end

Rayfield:Notify({ Title = "TereyakiOS", Content = "Loaded", Duration = 2 })

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

task.spawn(MainFarmLoop)

-------------------------------------------------------------------------------
--    AIMLOCK TAB  (ported from Tereyakiware / HyperEscape)
-------------------------------------------------------------------------------
do
    local AL = {
        Enabled           = false,
        TeamCheck         = false,
        WallCheck         = false,
        StickyAim         = false,
        Prediction        = false,
        PredictionAmmount = 1,
        UseMouse          = true,
        MouseBind         = "MouseButton2",
        Keybind           = Enum.KeyCode.E,
        ShowFov           = false,
        Fov               = 360,
        Smoothing         = 0.3,
        AimPart           = "Head",
        IsAimKeyDown      = false,
        Target            = nil,
        CameraTween       = nil,
    }

    local AL_UIS        = game:GetService("UserInputService")
    local AL_TweenSvc   = game:GetService("TweenService")
    local AL_Camera     = workspace.CurrentCamera
    local AL_LP         = game:GetService("Players").LocalPlayer

    -- FOV circle
    local AL_FovGui   = Instance.new("ScreenGui")
    AL_FovGui.Name          = "AL_FovGui"
    AL_FovGui.ResetOnSpawn  = false
    AL_FovGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    local _ok, _cg = pcall(function() return game:GetService("CoreGui") end)
    AL_FovGui.Parent = _ok and _cg or AL_LP.PlayerGui

    local AL_FovFrame = Instance.new("Frame")
    AL_FovFrame.BackgroundTransparency = 1
    AL_FovFrame.AnchorPoint = Vector2.new(0.5, 0.5)
    AL_FovFrame.Position    = UDim2.new(0.5, 0, 0.5, 0)
    AL_FovFrame.Size        = UDim2.fromOffset(AL.Fov, AL.Fov)
    AL_FovFrame.Parent      = AL_FovGui

    local _uc = Instance.new("UICorner")
    _uc.CornerRadius = UDim.new(1, 0)
    _uc.Parent = AL_FovFrame

    local AL_UIStroke = Instance.new("UIStroke")
    AL_UIStroke.Color           = Color3.fromRGB(100, 0, 100)
    AL_UIStroke.Thickness       = 1
    AL_UIStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    AL_UIStroke.Enabled         = false
    AL_UIStroke.Parent          = AL_FovFrame

    -- Helpers
    local function AL_IsAlive(p)
        return p and p.Character
            and p.Character:FindFirstChild("HumanoidRootPart")
            and p.Character:FindFirstChild("Humanoid")
            and p.Character.Humanoid.Health > 0
    end

    local function AL_GetTeam(p)
        if not AL_LP.Neutral then
            return game.Teams[p.Team.Name]
        end
        return true
    end

    local function AL_Visible(pos, ...)
        if not AL.WallCheck then return true end
        return #AL_Camera:GetPartsObscuringTarget({pos}, {AL_Camera, AL_LP.Character, ...}) == 0
    end

    local function AL_AimPos(char)
        if AL.AimPart ~= "Random" then
            local p = char:FindFirstChild(AL.AimPart)
            return p and p.Position
        end
        local m2d = AL_UIS:GetMouseLocation()
        local best, bd = nil, math.huge
        for _, p in ipairs(char:GetChildren()) do
            if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" then
                local sp, on = AL_Camera:WorldToViewportPoint(p.Position)
                if on then
                    local d = (Vector2.new(sp.X, sp.Y) - m2d).Magnitude
                    if d < bd then best, bd = p, d end
                end
            end
        end
        return best and best.Position
    end

    local function AL_FovPart(char)
        if AL.AimPart == "Random" then
            return char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Head")
        end
        return char:FindFirstChild(AL.AimPart)
    end

    local function AL_GetClosest()
        local bestFov, bestT = AL.Fov, nil
        local m2d = AL_UIS:GetMouseLocation()
        for _, v in ipairs(game:GetService("Players"):GetPlayers()) do
            if v == AL_LP then continue end
            if AL.TeamCheck and AL_GetTeam(v) == AL_GetTeam(AL_LP) then continue end
            if not AL_IsAlive(v) then continue end
            local fp = AL_FovPart(v.Character)
            if not fp then continue end
            local sp, on = AL_Camera:WorldToViewportPoint(fp.Position)
            if on then
                local d = (Vector2.new(sp.X, sp.Y) - m2d).Magnitude
                if d < bestFov and AL_Visible(fp.Position, v.Character.Head.Parent) then
                    bestFov, bestT = d, v
                end
            end
        end
        return bestT
    end

    local function AL_Tween(pos)
        if AL.Prediction then
            local hrp = AL.Target and AL.Target.Character and AL.Target.Character:FindFirstChild("HumanoidRootPart")
            if hrp then pos = pos + hrp.AssemblyLinearVelocity * AL.PredictionAmmount end
        end
        AL.CameraTween = AL_TweenSvc:Create(
            AL_Camera,
            TweenInfo.new(AL.Smoothing, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
            {CFrame = CFrame.new(AL_Camera.CFrame.Position, pos)}
        )
        AL.CameraTween:Play()
    end

    -- Input handling
    AL_UIS.InputBegan:Connect(function(key)
        if key.KeyCode == AL.Keybind and not AL.UseMouse then
            AL.Target = AL_GetClosest(); AL.IsAimKeyDown = true
        end
    end)
    AL_UIS.InputEnded:Connect(function(key)
        if key.KeyCode == AL.Keybind and not AL.UseMouse then
            AL.Target = AL_GetClosest(); AL.IsAimKeyDown = false
            if AL.CameraTween then AL.CameraTween:Cancel() end
        end
    end)

    local AL_Mouse = AL_LP:GetMouse()
    AL_Mouse.Button1Down:Connect(function()
        if AL.MouseBind ~= "MouseButton1" or not AL.UseMouse then return end
        if AL.IsAimKeyDown then
            AL.IsAimKeyDown = false
            if AL.CameraTween then AL.CameraTween:Cancel() end
        else
            AL.Target = AL_GetClosest(); AL.IsAimKeyDown = true
        end
    end)
    AL_Mouse.Button1Up:Connect(function()
        if AL.MouseBind ~= "MouseButton1" or not AL.UseMouse then return end
        AL.IsAimKeyDown = false
        if AL.CameraTween then AL.CameraTween:Cancel() end
    end)
    AL_Mouse.Button2Down:Connect(function()
        if AL.MouseBind ~= "MouseButton2" or not AL.UseMouse then return end
        AL.Target = AL_GetClosest(); AL.IsAimKeyDown = true
    end)
    AL_Mouse.Button2Up:Connect(function()
        if AL.MouseBind ~= "MouseButton2" or not AL.UseMouse then return end
        AL.IsAimKeyDown = false
        if AL.CameraTween then AL.CameraTween:Cancel() end
    end)

    -- Main loop
    game:GetService("RunService").Heartbeat:Connect(function()
        if AL.Enabled and AL.ShowFov then
            AL_UIStroke.Enabled = true
            local mp = AL_UIS:GetMouseLocation()
            AL_FovFrame.Position = UDim2.new(0, mp.X, 0, mp.Y - 36)
            AL_FovFrame.Size = UDim2.fromOffset(AL.Fov * 1.5, AL.Fov * 1.5)
        else
            AL_UIStroke.Enabled = false
        end

        if not (AL.Enabled and AL.IsAimKeyDown) then return end

        if AL.StickyAim then
            if AL.Target and not AL_IsAlive(AL.Target) then
                AL.Target = AL_GetClosest()
            end
            if AL.Target then
                local pos = AL_AimPos(AL.Target.Character)
                if pos then AL_Tween(pos) end
            end
        else
            local t = AL_GetClosest()
            if t then
                AL.Target = t
                local pos = AL_AimPos(t.Character)
                if pos then AL_Tween(pos) end
            elseif AL.CameraTween then
                AL.CameraTween:Cancel()
            end
        end
    end)

    -- UI
    local AimTab = Tabs.AimLock

    AimTab:CreateToggle({
        Name = "Enable AimLock", CurrentValue = false, Flag = "AL_Enable",
        Callback = function(v) AL.Enabled = v end,
    })
    AimTab:CreateToggle({
        Name = "Team Check", CurrentValue = false, Flag = "AL_TeamCheck",
        Callback = function(v) AL.TeamCheck = v end,
    })
    AimTab:CreateToggle({
        Name = "Wall Check", CurrentValue = false, Flag = "AL_WallCheck",
        Callback = function(v) AL.WallCheck = v end,
    })
    AimTab:CreateDropdown({
        Name = "Aim Part",
        Options = {"Head","HumanoidRootPart","Torso","UpperTorso","LowerTorso","Right Arm","Left Arm","RightUpperArm","LeftUpperArm","Right Leg","Left Leg","Random"},
        CurrentOption = {"Head"},
        Flag = "AL_AimPart",
        Callback = function(v) AL.AimPart = type(v) == "table" and v[1] or v end,
    })
    AimTab:CreateSection("FOV Circle")
    AimTab:CreateToggle({
        Name = "Show FOV", CurrentValue = false, Flag = "AL_ShowFov",
        Callback = function(v) AL.ShowFov = v end,
    })
    AimTab:CreateSlider({
        Name = "FOV Radius", Range = {50, 1500}, Increment = 10,
        Suffix = " px", CurrentValue = 360, Flag = "AL_Fov",
        Callback = function(v) AL.Fov = v end,
    })
    AimTab:CreateSection("Other")
    AimTab:CreateToggle({
        Name = "Sticky Aim", CurrentValue = false, Flag = "AL_StickyAim",
        Callback = function(v) AL.StickyAim = v end,
    })
    AimTab:CreateToggle({
        Name = "Prediction", CurrentValue = false, Flag = "AL_Prediction",
        Callback = function(v) AL.Prediction = v end,
    })
    AimTab:CreateSlider({
        Name = "Prediction Amount", Range = {10, 500}, Increment = 5,
        Suffix = " x0.01", CurrentValue = 100, Flag = "AL_PredAmt",
        Callback = function(v) AL.PredictionAmmount = v / 100 end,
    })
    AimTab:CreateSlider({
        Name = "Smoothing", Range = {1, 50}, Increment = 1,
        Suffix = " x0.01s", CurrentValue = 30, Flag = "AL_Smoothing",
        Callback = function(v) AL.Smoothing = v / 100 end,
    })
    AimTab:CreateToggle({
        Name = "Use Mouse", CurrentValue = true, Flag = "AL_UseMouse",
        Callback = function(v) AL.UseMouse = v end,
    })
    AimTab:CreateDropdown({
        Name = "Mouse Bind",
        Options = {"MouseButton1", "MouseButton2"},
        CurrentOption = {"MouseButton2"},
        Flag = "AL_MouseBind",
        Callback = function(v) AL.MouseBind = type(v) == "table" and v[1] or v end,
    })
    AimTab:CreateKeybind({
        Name = "Key Bind (keyboard mode)",
        CurrentKeybind = "E",
        HoldToInteract = false,
        Flag = "AL_Keybind",
        Callback = function(v) AL.Keybind = Enum.KeyCode[v] or Enum.KeyCode.E end,
    })
end

-------------------------------------------------------------------------------
--    CONTROL TAB  (Projectile Control)
-------------------------------------------------------------------------------
do
    local PC_Players       = game:GetService("Players")
    local PC_Workspace     = game:GetService("Workspace")
    local PC_RunService    = game:GetService("RunService")
    local PC_UIS           = game:GetService("UserInputService")
    local PC_TweenService  = game:GetService("TweenService")
    local PC_DebrisService = game:GetService("Debris")
    local PC_SoundService  = game:GetService("SoundService")

    local projectilesControlEnabled = false
    local projectilesControlSpeed   = 200

    local pc_me     = PC_Players.LocalPlayer
    local pc_camera = PC_Workspace.CurrentCamera
    local pc_Debris = PC_Workspace:WaitForChild("Debris")
    local pc_VParts = pc_Debris:WaitForChild("VParts")

    local pc_forward, pc_sideways = 0, 0
    local wallbangRefreshTick   = 0
    local wallbangOriginalParents = {}
    local wallbangApplied       = false
    local currentObject, currentBodyVelocity, currentBodyGyro = nil, nil, nil
    local cameraWasOverridden   = false
    local cameraLookDir, cameraFollowPos, cameraYaw, cameraPitch = nil, nil, nil, nil
    local savedCameraType, savedCameraSubject, savedCameraCFrame = nil, nil, nil
    local savedMouseBehavior, savedMouseIconEnabled = nil, nil
    local recentShots           = {}
    local shotToolConns         = {}
    local charChildConn, charAddedConn, c4ToolConn = nil, nil, nil
    local c4EventRemote         = nil
    local c4FlySound            = nil
    local c4VisualModel         = nil
    local c4Hidden, c4HiddenLookup = {}, {}
    local breakControl          = false
    local pendingC4ExplosionUntil = 0
    local lastC4ExplosionSoundAt  = 0

    local function isProjectileControlToolName(name)
        return name == "C4" or name == "RPG-7" or name == "RPG-29"
            or name == "M320-1" or name == "SCAR-H-X" or name == "SBL-MK3"
            or name == "HL-MK3" or name == "A-HL-MK3" or name == "A-HL-MK4"
            or name == "HL-MK2" or name == "FireworkLauncher" or name == "A-FW-L"
            or name == "HallowsLauncher" or name == "AT4" or name == "AT4_"
            or name == "Panzerfaust-3" or name == "AUTO-PANZER" or name == "RPG-18"
            or name == "FlareGun" or name == "Plasma-Rocket-Launcher"
    end

    local function hasProjectileControlItem()
        local char = pc_me and pc_me.Character
        if char then
            for _, c in ipairs(char:GetChildren()) do
                if c:IsA("Tool") and isProjectileControlToolName(c.Name) then return true end
            end
        end
        local bp = pc_me and pc_me:FindFirstChildOfClass("Backpack")
        if bp then
            for _, c in ipairs(bp:GetChildren()) do
                if c:IsA("Tool") and isProjectileControlToolName(c.Name) then return true end
            end
        end
        return false
    end

    local function shouldEnableProjectileWallbang()
        return projectilesControlEnabled and hasProjectileControlItem()
    end

    local function syncWallbangState(enabled)
        local characters = PC_Workspace:FindFirstChild("Characters")
        if enabled then
            if not characters then return end
            local targets = {}
            local filter = PC_Workspace:FindFirstChild("Filter")
            if filter then
                targets[#targets+1] = filter:FindFirstChild("Snow")
                targets[#targets+1] = filter:FindFirstChild("WaterCurrents")
                local fp = filter:FindFirstChild("Parts")
                if fp then
                    for _, item in ipairs(fp:GetChildren()) do
                        if item and item.Name ~= "AA_COPYRIGHT" then targets[#targets+1] = item end
                    end
                end
            end
            local map = PC_Workspace:FindFirstChild("Map")
            if map then
                for _, n in ipairs({"ATMz","BredMakurz","Doors","MysteryBoxes","StreetLights","ProximityShops","SpawnedSupplyPlanes","VendingMachines"}) do
                    targets[#targets+1] = map:FindFirstChild(n)
                end
                local mp = map:FindFirstChild("Parts")
                if mp then
                    for _, item in ipairs(mp:GetChildren()) do
                        if item and item.Name ~= "AA_COPYRIGHT" then targets[#targets+1] = item end
                    end
                end
            end
            for _, target in ipairs(targets) do
                if target and target.Parent then
                    if wallbangOriginalParents[target] == nil then
                        wallbangOriginalParents[target] = target.Parent
                    end
                    if target.Parent ~= characters then
                        pcall(function() target.Parent = characters end)
                    end
                end
            end
            wallbangApplied = true
            return
        end
        for target, orig in pairs(wallbangOriginalParents) do
            if target and target.Parent and orig and orig.Parent and target.Parent ~= orig then
                pcall(function() target.Parent = orig end)
            end
        end
        table.clear(wallbangOriginalParents)
        wallbangApplied = false
    end

    local function ensureControlCamera()
        pc_camera = PC_Workspace.CurrentCamera or pc_camera
        if not pc_camera then return false end
        if not cameraWasOverridden then
            savedCameraType        = pc_camera.CameraType
            savedCameraSubject     = pc_camera.CameraSubject
            savedCameraCFrame      = pc_camera.CFrame
            cameraWasOverridden    = true
            savedMouseBehavior     = PC_UIS.MouseBehavior
            savedMouseIconEnabled  = PC_UIS.MouseIconEnabled
        end
        pc_camera.CameraType          = Enum.CameraType.Scriptable
        PC_UIS.MouseBehavior       = Enum.MouseBehavior.LockCenter
        PC_UIS.MouseIconEnabled    = false
        return true
    end

    local function applyControlCameraFrame()
        if not currentObject or not cameraLookDir then return end
        pc_camera = PC_Workspace.CurrentCamera or pc_camera
        if not pc_camera then return end
        pc_camera.CameraType = Enum.CameraType.Scriptable
        local projectileCFrame
        if not pcall(function() projectileCFrame = currentObject.CFrame end) or not projectileCFrame then return end
        local desiredCamPos = projectileCFrame.Position - cameraLookDir * 7 + Vector3.new(0, 2.4, 0)
        if not cameraFollowPos then
            cameraFollowPos = desiredCamPos
        else
            cameraFollowPos = cameraFollowPos:Lerp(desiredCamPos, 0.25)
        end
        local lookPos = projectileCFrame.Position + cameraLookDir * 18 + Vector3.new(0, 0.8, 0)
        pc_camera.CFrame = CFrame.lookAt(cameraFollowPos, lookPos)
    end

    local function markShot(name) recentShots[name] = os.clock() end

    local function isControllableProjectileName(n)
        return n=="TransIgnore" or n=="RPG_Rocket" or n=="GrenadeLauncherGrenade"
            or n=="SBL_Rocket" or n=="Hallows_Rocket3" or n=="A_Hallows_Rocket3"
            or n=="Hallows_Rocket2" or n=="FireworkLauncher_Rocket" or n=="Hallows_Rocket"
            or n=="AT4_Rocket" or n=="Flare_Rocket" or n=="Rpg18"
            or n=="_B__RPG_Rocket" or n=="_B__RPG_Rocket2"
    end

    local function isRecentShot(name)
        local t = recentShots[name]
        local window = 1.3
        if name == "TransIgnore" then window = 1.6
        elseif name == "GrenadeLauncherGrenade" then window = 1.4 end
        if t and (os.clock() - t) <= window then return true end
        if not isControllableProjectileName(name) then return false end
        local anyShot = recentShots["__any"]
        return anyShot and (os.clock() - anyShot) <= 1.2
    end

    local function markToolShot(toolName)
        markShot("__any")
        if toolName == "RPG-7" or toolName == "RPG-29" then
            markShot("RPG_Rocket") markShot("_B__RPG_Rocket") markShot("_B__RPG_Rocket2")
        elseif toolName == "M320-1" or toolName == "SCAR-H-X" then markShot("GrenadeLauncherGrenade")
        elseif toolName == "SBL-MK3" then markShot("SBL_Rocket")
        elseif toolName == "HL-MK3" or toolName == "A-HL-MK4" then markShot("Hallows_Rocket3")
        elseif toolName == "A-HL-MK3" then markShot("A_Hallows_Rocket3") markShot("Hallows_Rocket3")
        elseif toolName == "HL-MK2" then markShot("Hallows_Rocket2")
        elseif toolName == "FireworkLauncher" or toolName == "A-FW-L" then markShot("FireworkLauncher_Rocket")
        elseif toolName == "HallowsLauncher" then markShot("Hallows_Rocket")
        elseif toolName == "AT4" or toolName == "AT4_" or toolName == "Panzerfaust-3" or toolName == "AUTO-PANZER" then markShot("AT4_Rocket")
        elseif toolName == "FlareGun" then markShot("Flare_Rocket")
        elseif toolName == "RPG-18" then markShot("Rpg18")
        elseif toolName == "Plasma-Rocket-Launcher" then
            markShot("_B__RPG_Rocket") markShot("_B__RPG_Rocket2") markShot("RPG_Rocket")
        end
    end

    local function clearShotToolConns()
        for _, c in ipairs(shotToolConns) do pcall(function() c:Disconnect() end) end
        table.clear(shotToolConns)
    end

    local function bindShotTool(tool)
        if not tool or not tool:IsA("Tool") then return end
        local n = tool.Name
        if isProjectileControlToolName(n) and n ~= "C4" then
            shotToolConns[#shotToolConns+1] = tool.Activated:Connect(function() markToolShot(n) end)
        end
    end

    local function bindCharacterShotTools(char)
        clearShotToolConns()
        if not char then return end
        for _, c in ipairs(char:GetChildren()) do bindShotTool(c) end
    end

    local function startC4FlySound(projectile)
        if c4FlySound then pcall(function() c4FlySound:Stop() c4FlySound:Destroy() end) c4FlySound = nil end
        if not projectile or projectile.Name ~= "TransIgnore" then return end
        local s = Instance.new("Sound")
        s.SoundId = "rbxassetid://114037851906101"
        s.Looped = true s.Volume = 1.35 s.RollOffMaxDistance = 140 s.RollOffMinDistance = 8
        s.Parent = projectile
        pcall(function() s:Play() end)
        c4FlySound = s
    end

    local function stopC4FlySound()
        if c4FlySound then pcall(function() c4FlySound:Stop() c4FlySound:Destroy() end) c4FlySound = nil end
    end

    local function playC4ExplosionSound()
        local now = os.clock()
        if (now - lastC4ExplosionSoundAt) < 0.2 then return end
        lastC4ExplosionSoundAt = now
        local ids = {"rbxassetid://9114086405","rbxassetid://9114086455","rbxassetid://9114086744"}
        local s = Instance.new("Sound")
        s.SoundId = ids[math.random(1,#ids)] s.Volume = 1.75 s.Parent = PC_SoundService
        pcall(function() s:Play() end)
        PC_DebrisService:AddItem(s, 4)
    end

    local function hideC4Part(inst)
        if not inst or c4HiddenLookup[inst] then return end
        if c4VisualModel and inst:IsDescendantOf(c4VisualModel) then return end
        if inst:IsA("BasePart") then
            c4Hidden[#c4Hidden+1] = {inst, inst.Transparency, inst.LocalTransparencyModifier}
            c4HiddenLookup[inst] = true
            pcall(function() inst.Transparency = 1 inst.LocalTransparencyModifier = 1 end)
        elseif inst:IsA("Decal") or inst:IsA("Texture") then
            c4Hidden[#c4Hidden+1] = {inst, inst.Transparency}
            c4HiddenLookup[inst] = true
            pcall(function() inst.Transparency = 1 end)
        end
    end

    local function hideC4Assembly(part)
        if not part or not part.Parent then return end
        local connected = {}
        if not pcall(function() connected = part:GetConnectedParts(true) end) or #connected == 0 then connected = {part} end
        for _, base in ipairs(connected) do
            if base and base:IsA("BasePart") then
                hideC4Part(base)
                for _, d in ipairs(base:GetDescendants()) do
                    if d:IsA("Decal") or d:IsA("Texture") then hideC4Part(d) end
                end
            end
        end
    end

    local function showC4Assembly()
        for _, item in ipairs(c4Hidden) do
            local inst = item[1]
            if inst and inst.Parent then
                if inst:IsA("BasePart") then pcall(function() inst.Transparency = item[2] inst.LocalTransparencyModifier = item[3] end)
                elseif inst:IsA("Decal") or inst:IsA("Texture") then pcall(function() inst.Transparency = item[2] end) end
            end
        end
        table.clear(c4Hidden)
        table.clear(c4HiddenLookup)
    end

    local DRONE1_BLUEPRINT = {
        {class="Part",name="Axis",size=Vector3.new(0.1,0.101587,0.101587),color=Color3.new(0.388235,0.372549,0.384314),material=Enum.Material.Metal,shape=Enum.PartType.Cylinder,transparency=0,offset=CFrame.new(-1.268616,0.299652,-0.809448,0,-0.342014,0.939695,1,0,0,0,0.939695,0.342014)},
        {class="Part",name="Axis",size=Vector3.new(0.1,0.101587,0.101587),color=Color3.new(0.388235,0.372549,0.384314),material=Enum.Material.Metal,shape=Enum.PartType.Cylinder,transparency=0,offset=CFrame.new(-1.294495,-0.000336,0.946899,0,0.342009,0.939697,1,0,0,0,0.939697,-0.342009)},
        {class="Part",name="Axis",size=Vector3.new(0.1,0.07619,0.076191),color=Color3.new(0.388235,0.372549,0.384314),material=Enum.Material.Metal,shape=Enum.PartType.Cylinder,transparency=0,offset=CFrame.new(1.243103,-0.000336,0.946899,0,-0.342009,0.939697,1,0,0,0,0.939697,0.342009)},
        {class="Part",name="Axis",size=Vector3.new(0.1,0.101587,0.101587),color=Color3.new(0.388235,0.372549,0.384314),material=Enum.Material.Metal,shape=Enum.PartType.Cylinder,transparency=0,offset=CFrame.new(1.269104,0.299652,-0.809448,0,0.342009,0.939697,1,0,0,0,0.939697,-0.342008)},
        {class="Part",name="Part",size=Vector3.new(1.750031,0.500012,0.700195),color=Color3.new(0.388235,0.372549,0.384314),material=Enum.Material.Metal,transparency=0,offset=CFrame.new(0.000305,0.000031,-0.000122,0,0,1,0,1,0,-1,0,0)},
        {class="Part",name="Union",size=Vector3.new(0.300000,0.228777,1.264832),color=Color3.new(0.388235,0.372549,0.384314),material=Enum.Material.Metal,transparency=0,offset=CFrame.new(0.756531,-0.100342,0.769653,0,-0.342009,0.939697,1,0,0,0,0.939697,0.342009)},
        {class="Part",name="Union",size=Vector3.new(0.299999,0.228824,1.264949),color=Color3.new(0.388235,0.372549,0.384314),material=Enum.Material.Metal,transparency=0,offset=CFrame.new(-0.78186,0.199646,-0.632446,0,-0.342014,0.939695,1,0,0,0,0.939695,0.342014)},
        {class="Part",name="Union",size=Vector3.new(0.299998,0.231187,1.264694),color=Color3.new(0.388235,0.372549,0.384314),material=Enum.Material.Metal,transparency=0,offset=CFrame.new(0.782654,0.199646,-0.631287,0,0.342009,0.939697,1,0,0,0,0.939697,-0.342008)},
        {class="Part",name="Union",size=Vector3.new(0.3,0.228774,1.26445),color=Color3.new(0.388235,0.372549,0.384314),material=Enum.Material.Metal,transparency=0,offset=CFrame.new(-0.808105,-0.100342,0.769653,0,0.342009,0.939697,1,0,0,0,0.939697,-0.342009)},
    }

    local function createC4DroneVisual(part)
        if not part or not part.Parent then return end
        if c4VisualModel then pcall(function() c4VisualModel:Destroy() end) c4VisualModel = nil end
        local model = Instance.new("Model") model.Name = "Drone1" model.Parent = part.Parent
        for _, d in ipairs(DRONE1_BLUEPRINT) do
            local p = Instance.new("Part")
            p.Name = d.name p.Size = d.size p.CFrame = part.CFrame * d.offset
            p.Color = d.color p.Material = d.material p.Transparency = d.transparency
            p.TopSurface = Enum.SurfaceType.Smooth p.BottomSurface = Enum.SurfaceType.Smooth
            p.Anchored = false p.CanCollide = false p.CanTouch = false p.CanQuery = false p.Massless = true
            if d.shape then p.Shape = d.shape end
            p.Parent = model
            local weld = Instance.new("WeldConstraint")
            weld.Part0 = p weld.Part1 = part weld.Parent = p
        end
        c4VisualModel = model
    end

    local function releaseControl()
        pc_forward = 0 pc_sideways = 0 breakControl = false
        if currentBodyVelocity then pcall(function() currentBodyVelocity:Destroy() end) end
        if currentBodyGyro then pcall(function() currentBodyGyro:Destroy() end) end
        currentBodyVelocity = nil currentBodyGyro = nil currentObject = nil
        if c4VisualModel then pcall(function() c4VisualModel:Destroy() end) c4VisualModel = nil end
        stopC4FlySound()
        showC4Assembly()
        if pc_me.Character and pc_me.Character:FindFirstChild("HumanoidRootPart") then
            pc_me.Character.HumanoidRootPart.Anchored = false
        end
        pc_camera = PC_Workspace.CurrentCamera or pc_camera
        if pc_camera and cameraWasOverridden then
            local hum = pc_me.Character and pc_me.Character:FindFirstChildOfClass("Humanoid")
            pc_camera.CameraType = Enum.CameraType.Custom
            if hum then pc_camera.CameraSubject = hum
            elseif savedCameraSubject and savedCameraSubject.Parent then pc_camera.CameraSubject = savedCameraSubject end
            if savedCameraCFrame then pc_camera.CFrame = savedCameraCFrame end
        end
        cameraWasOverridden = false
        savedCameraType = nil savedCameraSubject = nil savedCameraCFrame = nil
        cameraLookDir = nil cameraFollowPos = nil cameraYaw = nil cameraPitch = nil
        PC_UIS.MouseBehavior = Enum.MouseBehavior.Default
        PC_UIS.MouseIconEnabled = true
        if savedMouseBehavior ~= nil then PC_UIS.MouseBehavior = savedMouseBehavior end
        if savedMouseIconEnabled ~= nil then PC_UIS.MouseIconEnabled = savedMouseIconEnabled end
        task.defer(function() pcall(function() PC_UIS.MouseBehavior = Enum.MouseBehavior.Default PC_UIS.MouseIconEnabled = true end) end)
        task.delay(0.2, function() pcall(function() PC_UIS.MouseBehavior = Enum.MouseBehavior.Default PC_UIS.MouseIconEnabled = true end) end)
        savedMouseBehavior = nil savedMouseIconEnabled = nil
    end

    local function getMapPart()
        local map = PC_Workspace:FindFirstChild("Map")
        if not map then return nil end
        for _, inst in ipairs(map:GetDescendants()) do
            if inst:IsA("BasePart") then return inst end
        end
    end

    local function airDetonateC4()
        if not currentObject or currentObject.Name ~= "TransIgnore" then return end
        local detonatingObject = currentObject
        if not c4EventRemote or not c4EventRemote:IsA("RemoteEvent") then return end
        local mapPart = getMapPart()
        pendingC4ExplosionUntil = os.clock() + 1.25
        if mapPart then pcall(function() c4EventRemote:FireServer("Do", mapPart, currentObject.CFrame) end) end
        pcall(function() c4EventRemote:FireServer("Detonate") end)
        task.delay(0.55, function()
            if currentObject and currentObject == detonatingObject then releaseControl() end
        end)
    end

    local function bindC4Tool(char)
        if c4ToolConn then pcall(function() c4ToolConn:Disconnect() end) c4ToolConn = nil end
        c4EventRemote = nil
        if not char then return end
        local c4Tool = char:FindFirstChild("C4")
        if c4Tool and c4Tool:IsA("Tool") then
            local ev = c4Tool:FindFirstChild("Event")
            if ev and ev:IsA("RemoteEvent") then c4EventRemote = ev end
            c4ToolConn = c4Tool.Activated:Connect(function()
                if currentObject and currentObject.Name == "TransIgnore" then airDetonateC4()
                else markShot("TransIgnore") end
            end)
        end
    end

    local function registerProjectile(projectile)
        if not projectilesControlEnabled then return end
        if currentObject then return end
        task.wait()
        if not pc_me.Character or not projectile then return end
        if not isRecentShot(projectile.Name) then return end
        local myRoot = pc_me.Character:FindFirstChild("HumanoidRootPart") or pc_me.Character:FindFirstChild("Head")
        if myRoot then
            local pp
            if pcall(function() pp = projectile.Position end) and pp then
                if (pp - myRoot.Position).Magnitude > 30 then return end
            else return end
        end
        if projectile.Name == "TransIgnore" then
            hideC4Assembly(projectile)
            createC4DroneVisual(projectile)
            startC4FlySound(projectile)
        else
            local char = pc_me.Character
            local checks = {
                RPG_Rocket = function() return char:FindFirstChild("RPG-7") or char:FindFirstChild("RPG-29") end,
                ["_B__RPG_Rocket"] = function() return char:FindFirstChild("Plasma-Rocket-Launcher") or char:FindFirstChild("RPG-29") end,
                ["_B__RPG_Rocket2"] = function() return char:FindFirstChild("Plasma-Rocket-Launcher") or char:FindFirstChild("RPG-29") end,
                GrenadeLauncherGrenade = function() return char:FindFirstChild("M320-1") or char:FindFirstChild("SCAR-H-X") end,
                SBL_Rocket = function() return char:FindFirstChild("SBL-MK3") end,
                Hallows_Rocket3 = function() return char:FindFirstChild("HL-MK3") or char:FindFirstChild("A-HL-MK4") or char:FindFirstChild("A-HL-MK3") end,
                A_Hallows_Rocket3 = function() return char:FindFirstChild("A-HL-MK3") or char:FindFirstChild("A-HL-MK4") end,
                Hallows_Rocket2 = function() return char:FindFirstChild("HL-MK2") end,
                FireworkLauncher_Rocket = function() return char:FindFirstChild("FireworkLauncher") or char:FindFirstChild("A-FW-L") end,
                Hallows_Rocket = function() return char:FindFirstChild("HallowsLauncher") end,
                AT4_Rocket = function() return char:FindFirstChild("AT4") or char:FindFirstChild("AT4_") or char:FindFirstChild("Panzerfaust-3") or char:FindFirstChild("AUTO-PANZER") end,
                Flare_Rocket = function() return char:FindFirstChild("FlareGun") end,
                Rpg18 = function() return char:FindFirstChild("RPG-18") end,
            }
            local check = checks[projectile.Name]
            if not check or not check() then return end
        end
        if not ensureControlCamera() then return end
        if pc_me.Character and pc_me.Character:FindFirstChild("HumanoidRootPart") then
            pc_me.Character.HumanoidRootPart.Anchored = true
        end
        local startCf
        if pcall(function() startCf = projectile.CFrame end) and startCf then
            local baseLook = pc_camera and pc_camera.CFrame.LookVector or startCf.LookVector
            cameraLookDir = baseLook.Magnitude > 0.001 and baseLook.Unit or Vector3.new(0,0,-1)
            cameraPitch = math.asin(math.clamp(cameraLookDir.Y,-1,1))
            cameraYaw = math.atan2(-cameraLookDir.X,-cameraLookDir.Z)
            cameraFollowPos = startCf.Position - cameraLookDir * 7 + Vector3.new(0,2.4,0)
            if pc_camera then
                pc_camera.CFrame = CFrame.lookAt(cameraFollowPos, startCf.Position + cameraLookDir * 18 + Vector3.new(0,0.8,0))
            end
        else
            cameraLookDir = Vector3.new(0,0,-1) cameraPitch = 0 cameraYaw = 0 cameraFollowPos = nil
        end
        pcall(function()
            if projectile:FindFirstChild("BodyForce") then projectile.BodyForce:Destroy() end
            if projectile:FindFirstChild("BodyAngularVelocity") then projectile.BodyAngularVelocity:Destroy() end
            if projectile:FindFirstChild("Sound") then projectile.Sound:Destroy() end
        end)
        currentBodyVelocity = Instance.new("BodyVelocity")
        currentBodyVelocity.MaxForce = Vector3.new(1e9,1e9,1e9)
        currentBodyVelocity.Velocity = Vector3.new()
        currentBodyVelocity.Parent = projectile
        currentBodyGyro = Instance.new("BodyGyro")
        currentBodyGyro.P = 9e4
        currentBodyGyro.MaxTorque = Vector3.new(1e9,1e9,1e9)
        currentBodyGyro.Parent = projectile
        currentObject = projectile
        recentShots[projectile.Name] = nil
    end

    -- Event connections
    pc_VParts.ChildAdded:Connect(registerProjectile)
    for _, p in ipairs(pc_VParts:GetChildren()) do task.spawn(registerProjectile, p) end

    pc_Debris.ChildAdded:Connect(function(result)
        task.wait()
        if not pc_me.Character then return end
        pcall(function()
            if result.Name == "C4Explosion" and os.clock() <= pendingC4ExplosionUntil then
                pendingC4ExplosionUntil = 0
                playC4ExplosionSound()
                if currentObject and currentObject.Name == "TransIgnore" then
                    breakControl = true task.delay(0.05, releaseControl)
                end
                return
            end
            if not currentObject then return end
            local char = pc_me.Character
            if (char:FindFirstChild("RPG-7") and (result.Name=="RPG_Explosion_Long" or result.Name=="RPG_Explosion_Short")) or
               ((char:FindFirstChild("M320-1") or char:FindFirstChild("SCAR-H-X")) and (result.Name=="GL_Explosion_Long" or result.Name=="GL_Explosion_Short")) or
               (char:FindFirstChild("SBL-MK3") and result.Name=="SBL_Explosion") or
               (char:FindFirstChild("AT4") and (result.Name=="Panzer_Explosion_Long" or result.Name=="Panzer_Explosion_Short")) or
               (char:FindFirstChild("RPG-18") and result.Name=="BigExplosion2") then
                breakControl = true task.delay(0.05, releaseControl)
            end
        end)
    end)

    PC_UIS.InputBegan:Connect(function(key, gp)
        if gp then return end
        if key.KeyCode == Enum.KeyCode.W then pc_forward = 1
        elseif key.KeyCode == Enum.KeyCode.S then pc_forward = -1
        elseif key.KeyCode == Enum.KeyCode.D then pc_sideways = 1
        elseif key.KeyCode == Enum.KeyCode.A then pc_sideways = -1 end
    end)
    PC_UIS.InputEnded:Connect(function(key)
        if key.KeyCode == Enum.KeyCode.W or key.KeyCode == Enum.KeyCode.S then pc_forward = 0
        elseif key.KeyCode == Enum.KeyCode.D or key.KeyCode == Enum.KeyCode.A then pc_sideways = 0 end
    end)

    pc_me.CharacterRemoving:Connect(function() releaseControl() end)

    if pc_me.Character then
        bindC4Tool(pc_me.Character)
        bindCharacterShotTools(pc_me.Character)
        charChildConn = pc_me.Character.ChildAdded:Connect(function(child)
            if child:IsA("Tool") and child.Name == "C4" then bindC4Tool(pc_me.Character) end
            if child:IsA("Tool") then bindShotTool(child) end
        end)
    end
    charAddedConn = pc_me.CharacterAdded:Connect(function(char)
        releaseControl()
        bindC4Tool(char)
        bindCharacterShotTools(char)
        if charChildConn then pcall(function() charChildConn:Disconnect() end) end
        charChildConn = char.ChildAdded:Connect(function(child)
            if child:IsA("Tool") and child.Name == "C4" then bindC4Tool(char) end
            if child:IsA("Tool") then bindShotTool(child) end
        end)
    end)

    PC_Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
        pc_camera = PC_Workspace.CurrentCamera
        if pc_camera and currentObject and currentObject.Parent then
            ensureControlCamera()
            applyControlCameraFrame()
        end
    end)

    PC_RunService.RenderStepped:Connect(function()
        if not projectilesControlEnabled or not currentObject or not currentObject.Parent then return end
        if ensureControlCamera() then applyControlCameraFrame() end
    end)

    PC_RunService.Heartbeat:Connect(function()
        if shouldEnableProjectileWallbang() then
            wallbangRefreshTick = wallbangRefreshTick + 1
            if wallbangRefreshTick >= 45 then wallbangRefreshTick = 0 syncWallbangState(true) end
        else
            wallbangRefreshTick = 0
            if wallbangApplied then syncWallbangState(false) end
        end
        if currentObject and (not currentBodyVelocity or not currentBodyGyro) then releaseControl() return end
        if not currentObject or not projectilesControlEnabled then return end
        if not currentObject.Parent then releaseControl() return end
        if not ensureControlCamera() then return end
        local projectileCFrame
        if not pcall(function() projectileCFrame = currentObject.CFrame end) then releaseControl() return end
        if currentObject.Name == "TransIgnore" then pcall(function() hideC4Assembly(currentObject) end) end
        local mouseDelta = PC_UIS:GetMouseDelta()
        local sens = 0.0024
        cameraYaw = (cameraYaw or 0) - mouseDelta.X * sens
        cameraPitch = math.clamp((cameraPitch or 0) - mouseDelta.Y * sens, -1.22, 1.1)
        local desiredDir = Vector3.new(
            -math.sin(cameraYaw) * math.cos(cameraPitch),
            math.sin(cameraPitch),
            -math.cos(cameraYaw) * math.cos(cameraPitch)
        )
        desiredDir = desiredDir.Magnitude > 0.001 and desiredDir.Unit or Vector3.new(0,0,-1)
        cameraLookDir = cameraLookDir and cameraLookDir:Lerp(desiredDir, 0.35) or desiredDir
        cameraLookDir = cameraLookDir.Magnitude > 0.001 and cameraLookDir.Unit or desiredDir
        local rightDir = cameraLookDir:Cross(Vector3.new(0,1,0))
        rightDir = rightDir.Magnitude > 0.001 and rightDir.Unit or Vector3.new(1,0,0)
        local moveDir = cameraLookDir * pc_forward + rightDir * pc_sideways
        if moveDir.Magnitude > 1 then moveDir = moveDir.Unit end
        PC_TweenService:Create(currentBodyVelocity, TweenInfo.new(0), {Velocity = moveDir * projectilesControlSpeed}):Play()
        currentBodyGyro.CFrame = CFrame.lookAt(projectileCFrame.Position, projectileCFrame.Position + cameraLookDir)
        applyControlCameraFrame()
        if breakControl then releaseControl() end
    end)

    syncWallbangState(shouldEnableProjectileWallbang())

    -- UI
    local CtrlTab = Tabs.Control

    CtrlTab:CreateToggle({
        Name = "Enable Projectile Control",
        CurrentValue = false,
        Flag = "PC_Enable",
        Callback = function(v)
            projectilesControlEnabled = v
            syncWallbangState(shouldEnableProjectileWallbang())
            if not v then releaseControl() end
        end,
    })
    CtrlTab:CreateSlider({
        Name = "Projectile Speed",
        Range = {50, 600},
        Increment = 10,
        Suffix = " studs/s",
        CurrentValue = 200,
        Flag = "PC_Speed",
        Callback = function(v) projectilesControlSpeed = v end,
    })
    CtrlTab:CreateSection("Supported weapons")
    CtrlTab:CreateParagraph({
        Title = "Rockets & Launchers",
        Content = "RPG-7, RPG-29, RPG-18, AT4, AT4_, Panzerfaust-3, AUTO-PANZER, Plasma-Rocket-Launcher, SBL-MK3, HL-MK2, HL-MK3, A-HL-MK3, A-HL-MK4, HallowsLauncher, FireworkLauncher, A-FW-L, FlareGun",
    })
    CtrlTab:CreateParagraph({
        Title = "Other",
        Content = "C4 (drone mode — click C4 again mid-air to detonate), M320-1, SCAR-H-X (grenade launcher)",
    })
    CtrlTab:CreateParagraph({
        Title = "Controls",
        Content = "W/A/S/D — steer projectile\nMouse — aim camera\nEnable toggle — turns control on/off",
    })
end
