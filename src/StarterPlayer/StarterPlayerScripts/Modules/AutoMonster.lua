local ControllerLock = getgenv().RobloxModules.ControllerLock
local AutoMonster = {}

function AutoMonster.run(State)
	print("AutoMonster started")

	local TweenService = game:GetService("TweenService")
	local Players = game:GetService("Players")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local RunService = game:GetService("RunService")

	local player = Players.LocalPlayer

	local activeTween = nil
	local noclipConn = nil

	local blueHighlights = {}
	local redHighlight = nil
	local currentRedTarget = nil

	local ATTACK_RANGE = 8
	local STOP_DISTANCE = 4
	local SEARCH_DISTANCE = math.huge
	local MOVE_SPEED = 85
	local SAFE_FLY_HEIGHT = 160
	local REPATH_DISTANCE = 18

	local STAGING_POINT = Vector3.new(389, 138, 93)
	local STAGING_RADIUS = 8

	local function getMonsterPriorityBuckets()
		return {
			"hellflame oni",
			"warlord oni",
			"frostburn oni",
			"brute oni",
			"common orc",
			"elite orc",
			"monk panda",
			"samurai ape",
			"savage ape",
			"mountain ape",
			"chuthlu",
			"skeleton pirate",
			"yeti",
			"crystal spider",
			"diamond spider",
			"prismarine spider",
		}
	end

	local function getMonsterPriorityIndex(monsterName)
		local normalized = normalizeName(monsterName)
		local buckets = getMonsterPriorityBuckets()

		for i, name in ipairs(buckets) do
			if normalized == name then
				return i
			end
		end

		return math.huge
	end
	-------------------------------------------------
	-- Character
	-------------------------------------------------
	local function getCharacterParts()
		local character = player.Character or player.CharacterAdded:Wait()
		local humanoid = character:WaitForChild("Humanoid")
		local hrp = character:WaitForChild("HumanoidRootPart")
		return character, humanoid, hrp
	end

	-------------------------------------------------
	-- Controller / Priority
	-------------------------------------------------
	local function isPausedForAutoMonster()
		return ControllerLock.isOwnedByOther(State, "AutoMonster")
	end

	local function isBossPriorityActive()
		if not State.autoBoss then
			return false
		end

		if State.bossInProgress then
			return true
		end

		if State.bossPriorityActive then
			return true
		end

		return false
	end

	-------------------------------------------------
	-- Attack
	-------------------------------------------------
	local function attack()
		pcall(function()
			ReplicatedStorage
				:WaitForChild("Shared")
				:WaitForChild("Packages")
				:WaitForChild("Knit")
				:WaitForChild("Services")
				:WaitForChild("ToolService")
				:WaitForChild("RF")
				:WaitForChild("ToolActivated")
				:InvokeServer("Weapon")
		end)
	end

	-------------------------------------------------
	-- Name helpers
	-------------------------------------------------
	local function normalizeName(name)
		name = tostring(name or "")
		name = name:gsub("%d+$", "")
		name = name:gsub("^%s+", "")
		name = name:gsub("%s+$", "")
		return string.lower(name)
	end

	local function isSelectedMonster(monsterName)
		if not State.selectedMonsters then
			return false
		end

		local n = normalizeName(monsterName)

		for selectedName, enabled in pairs(State.selectedMonsters) do
			if enabled and normalizeName(selectedName) == n then
				return true
			end
		end

		return false
	end

	local function requiresStaging(monsterName)
		local n = normalizeName(monsterName)
		return n:find("common orc", 1, true)
			or n:find("elite orc", 1, true)
	end

	-------------------------------------------------
	-- Monster helpers
	-------------------------------------------------
	local function findMonsterRoot(model)
		if not model then
			return nil
		end

		return model:FindFirstChild("HumanoidRootPart", true)
			or model:FindFirstChild("RootPart", true)
			or model:FindFirstChild("Torso", true)
			or model.PrimaryPart
			or model:FindFirstChildWhichIsA("BasePart", true)
	end

	local function findMonsterHumanoid(model)
		if not model then
			return nil
		end

		return model:FindFirstChildOfClass("Humanoid")
			or model:FindFirstChildWhichIsA("Humanoid", true)
	end

	local function isMonsterAlive(monster)
		if not monster or not monster.Parent then
			return false
		end

		local hum = findMonsterHumanoid(monster)
		if hum then
			return hum.Health > 0
		end

		local attrHealth = monster:GetAttribute("Health")
		if type(attrHealth) == "number" then
			return attrHealth > 0
		end

		return true
	end

	-------------------------------------------------
	-- Highlight
	-------------------------------------------------
	local function destroyHighlight(h)
		if h then
			pcall(function()
				h:Destroy()
			end)
		end
	end

	local function makeHighlight(target, color)
		local h = Instance.new("Highlight")
		h.FillTransparency = 1
		h.OutlineTransparency = 0
		h.OutlineColor = color
		h.Adornee = target
		h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		h.Parent = game:GetService("CoreGui")
		return h
	end

	local function clearBlueHighlights()
		for monster, h in pairs(blueHighlights) do
			if h then
				destroyHighlight(h)
			end
			blueHighlights[monster] = nil
		end
	end

	local function cleanupBlueHighlights()
		for monster, h in pairs(blueHighlights) do
			if not monster or not monster.Parent or not isMonsterAlive(monster) then
				destroyHighlight(h)
				blueHighlights[monster] = nil
			end
		end
	end

	local function setBlueTargets(monsters)
		local keep = {}

		for _, monster in ipairs(monsters) do
			keep[monster] = true
			if not blueHighlights[monster] then
				blueHighlights[monster] = makeHighlight(monster, Color3.fromRGB(0, 150, 255))
			end
		end

		for monster, h in pairs(blueHighlights) do
			if not keep[monster] then
				destroyHighlight(h)
				blueHighlights[monster] = nil
			end
		end
	end

	local function setRedTarget(monster)
		if currentRedTarget == monster and redHighlight then
			return
		end

		destroyHighlight(redHighlight)
		redHighlight = nil
		currentRedTarget = nil

		if monster and monster.Parent then
			redHighlight = makeHighlight(monster, Color3.fromRGB(255, 0, 0))
			currentRedTarget = monster
		end
	end

	local function clearRedTarget()
		destroyHighlight(redHighlight)
		redHighlight = nil
		currentRedTarget = nil
	end

	-------------------------------------------------
	-- Noclip
	-------------------------------------------------
	local function setCollision(state)
		local character = player.Character
		if not character then return end

		for _, v in ipairs(character:GetDescendants()) do
			if v:IsA("BasePart") then
				v.CanCollide = state
			end
		end
	end

	local function startNoclip()
		if noclipConn then
			noclipConn:Disconnect()
			noclipConn = nil
		end

		noclipConn = RunService.Heartbeat:Connect(function()
			setCollision(false)
		end)
	end

	local function stopNoclip()
		if noclipConn then
			noclipConn:Disconnect()
			noclipConn = nil
		end
		setCollision(true)
	end

	-------------------------------------------------
	-- Tween helpers
	-------------------------------------------------
	local function cancelTween()
		if activeTween then
			pcall(function()
				activeTween:Cancel()
			end)
			activeTween = nil
		end
		stopNoclip()
	end

	local function faceTarget(targetPos)
		local _, _, hrp = getCharacterParts()
		local lookAt = Vector3.new(targetPos.X, hrp.Position.Y, targetPos.Z)
		if (lookAt - hrp.Position).Magnitude > 0.05 then
			hrp.CFrame = CFrame.lookAt(hrp.Position, lookAt)
		end
	end

	local function tweenTo(pos, speed)
		local _, _, hrp = getCharacterParts()
		speed = speed or MOVE_SPEED

		cancelTween()
		startNoclip()

		local dist = (pos - hrp.Position).Magnitude
		local time = math.max(dist / speed, 0.05)

		local tween = TweenService:Create(
			hrp,
			TweenInfo.new(time, Enum.EasingStyle.Linear),
			{CFrame = CFrame.new(pos)}
		)

		activeTween = tween
		tween:Play()

		local startedAt = tick()

		while tween.PlaybackState == Enum.PlaybackState.Playing do
			if not getgenv().RobloxUIRunning or not State.autoMonsterFarm then
				tween:Cancel()
				stopNoclip()
				return false
			end

			if isPausedForAutoMonster() or isBossPriorityActive() then
				tween:Cancel()
				stopNoclip()
				return false
			end

			if tick() - startedAt > time + 2 then
				tween:Cancel()
				break
			end

			task.wait()
		end

		activeTween = nil
		stopNoclip()
		return true
	end

	local function flyTo(targetPos)
		local _, _, hrp = getCharacterParts()
		local currentPos = hrp.Position

		local riseY = math.max(currentPos.Y + 25, SAFE_FLY_HEIGHT)
		local midY = math.max(targetPos.Y + 25, SAFE_FLY_HEIGHT - 20)

		local risePos = Vector3.new(currentPos.X, riseY, currentPos.Z)
		local flyPos = Vector3.new(targetPos.X, midY, targetPos.Z)
		local dropPos = targetPos

		if not tweenTo(risePos, 95) then
			return false
		end

		if not tweenTo(flyPos, 100) then
			return false
		end

		if not tweenTo(dropPos, 75) then
			return false
		end

		return true
	end

	-------------------------------------------------
	-- Ground / safe stand
	-------------------------------------------------
	local function getGroundYNear(position, ignoreList)
		local rayParams = RaycastParams.new()
		rayParams.FilterType = Enum.RaycastFilterType.Blacklist
		rayParams.FilterDescendantsInstances = ignoreList or {}
		rayParams.IgnoreWater = true

		local origin = position + Vector3.new(0, 25, 0)
		local direction = Vector3.new(0, -300, 0)

		local result = workspace:Raycast(origin, direction, rayParams)
		if result then
			return result.Position.Y
		end

		return nil
	end

	local function getSafeStandPositionNearTarget(targetPart, stopDistance)
		local character, _, hrp = getCharacterParts()
		if not targetPart or not targetPart.Parent then
			return nil
		end

		local targetPos = targetPart.Position
		local myPos = hrp.Position

		local flatDir = Vector3.new(
			targetPos.X - myPos.X,
			0,
			targetPos.Z - myPos.Z
		)

		if flatDir.Magnitude <= 0.05 then
			flatDir = Vector3.new(0, 0, -1)
		else
			flatDir = flatDir.Unit
		end

		local desiredXZ = Vector3.new(
			targetPos.X - flatDir.X * (stopDistance or STOP_DISTANCE),
			0,
			targetPos.Z - flatDir.Z * (stopDistance or STOP_DISTANCE)
		)

		local groundY = getGroundYNear(
			Vector3.new(desiredXZ.X, targetPos.Y + 8, desiredXZ.Z),
			{character, targetPart.Parent}
		)

		local finalY = groundY and (groundY + 3) or (targetPos.Y + 2)
		return Vector3.new(desiredXZ.X, finalY, desiredXZ.Z)
	end

	local function moveToTargetPart(targetPart, stopDistance)
		if isPausedForAutoMonster() or isBossPriorityActive() then
			return false
		end

		if not targetPart or not targetPart.Parent then
			return false
		end

		local _, _, hrp = getCharacterParts()
		local standPos = getSafeStandPositionNearTarget(targetPart, stopDistance or STOP_DISTANCE)
		if not standPos then
			return false
		end

		local dist = (standPos - hrp.Position).Magnitude

		if dist > REPATH_DISTANCE then
			return flyTo(standPos)
		else
			return tweenTo(standPos, 80)
		end
	end

	local function stickToTargetPart(targetPart, stickDistance)
		local character, _, hrp = getCharacterParts()
		if not targetPart or not targetPart.Parent then
			return false
		end

		local targetPos = targetPart.Position
		local myPos = hrp.Position
		local desiredDistance = stickDistance or 2.5

		local flatDir = Vector3.new(
			targetPos.X - myPos.X,
			0,
			targetPos.Z - myPos.Z
		)

		if flatDir.Magnitude <= 0.05 then
			faceTarget(targetPos)
			return true
		end

		flatDir = flatDir.Unit

		local desiredXZ = Vector3.new(
			targetPos.X - flatDir.X * desiredDistance,
			0,
			targetPos.Z - flatDir.Z * desiredDistance
		)

		local groundY = getGroundYNear(
			Vector3.new(desiredXZ.X, targetPos.Y + 5, desiredXZ.Z),
			{character, targetPart.Parent}
		)

		local finalY = groundY and (groundY + 1.25) or math.max(myPos.Y, targetPos.Y)
		local desiredPos = Vector3.new(desiredXZ.X, finalY, desiredXZ.Z)

		startNoclip()
		hrp.CFrame = CFrame.lookAt(
			desiredPos,
			Vector3.new(targetPos.X, desiredPos.Y, targetPos.Z)
		)
		stopNoclip()
		return true
	end

	-------------------------------------------------
	-- Staging
	-------------------------------------------------
	local function isAtStaging()
		local _, _, hrp = getCharacterParts()
		return (hrp.Position - STAGING_POINT).Magnitude <= STAGING_RADIUS
	end

	local function moveToStaging()
		if isAtStaging() then
			return true
		end

		print("[AutoMonster] Move to staging")
		return flyTo(STAGING_POINT)
	end

	-------------------------------------------------
	-- Find targets
	-------------------------------------------------
	local function getTargetMonsters()
		local living = workspace:FindFirstChild("Living")
		if not living then
			return {}
		end

		local _, _, hrp = getCharacterParts()
		local monsters = {}

		for _, mob in ipairs(living:GetChildren()) do
			if mob:IsA("Model") and isMonsterAlive(mob) then
				local part = findMonsterRoot(mob)
				if part and isSelectedMonster(mob.Name) then
					local dist = (part.Position - hrp.Position).Magnitude
					if dist <= SEARCH_DISTANCE then
						table.insert(monsters, {
							model = mob,
							part = part,
							dist = dist,
							name = normalizeName(mob.Name),
						})
					end
				end
			end
		end

		table.sort(monsters, function(a, b)
			return a.dist < b.dist
		end)

		return monsters
	end

	local function findNearestTargetMonster()
		local living = workspace:FindFirstChild("Living")
		if not living then
			return nil, {}
		end

		local _, _, hrp = getCharacterParts()

		local grouped = {}
		local allTargets = {}

		for _, mob in ipairs(living:GetChildren()) do
			if mob:IsA("Model") and isMonsterAlive(mob) and isSelectedMonster(mob.Name) then
				local part = findMonsterRoot(mob)
				if part then
					local dist = (part.Position - hrp.Position).Magnitude
					if dist <= SEARCH_DISTANCE then
						local priority = getMonsterPriorityIndex(mob.Name)

						local item = {
							model = mob,
							part = part,
							dist = dist,
							name = normalizeName(mob.Name),
							priority = priority,
						}

						table.insert(allTargets, item)

						if not grouped[priority] then
							grouped[priority] = {}
						end
						table.insert(grouped[priority], item)
					end
				end
			end
		end

		-- เอาไว้ทำ blue highlight ทุกตัวที่หาเจอ
		table.sort(allTargets, function(a, b)
			if a.priority == b.priority then
				return a.dist < b.dist
			end
			return a.priority < b.priority
		end)

		-- หา priority แรกที่มี target
		local priorities = {}
		for priority, _ in pairs(grouped) do
			table.insert(priorities, priority)
		end
		table.sort(priorities)

		for _, priority in ipairs(priorities) do
			local bucket = grouped[priority]
			if bucket and #bucket > 0 then
				table.sort(bucket, function(a, b)
					return a.dist < b.dist
				end)

				return bucket[1].model, allTargets
			end
		end

		return nil, allTargets
	end

	-------------------------------------------------
	-- Attack monster
	-------------------------------------------------
	local function attackMonster(monster)
		if not monster or not monster.Parent then
			return false
		end

		local monsterName = monster.Name
		if requiresStaging(monsterName) and not isAtStaging() then
			print("[AutoMonster] target requires staging:", monsterName)
			local ok = moveToStaging()
			if not ok then
				return false
			end
		end

		local timeout = tick() + 20

		while getgenv().RobloxUIRunning and State.autoMonsterFarm and monster and monster.Parent and tick() < timeout do
			if isPausedForAutoMonster() or isBossPriorityActive() then
				cancelTween()
				return false
			end

			if not isMonsterAlive(monster) then
				cancelTween()
				return true
			end

			local part = findMonsterRoot(monster)
			if not part then
				cancelTween()
				return true
			end

			local _, _, hrp = getCharacterParts()
			local dist = (part.Position - hrp.Position).Magnitude

			if dist > ATTACK_RANGE then
				local moved = moveToTargetPart(part, STOP_DISTANCE)
				if not moved then
					cancelTween()
					return false
				end

				part = findMonsterRoot(monster)
				if not part then
					cancelTween()
					return true
				end
			end

			stickToTargetPart(part, 2.5)
			faceTarget(part.Position)
			attack()
			task.wait(0.12)

			if not isMonsterAlive(monster) then
				cancelTween()
				return true
			end
		end

		cancelTween()
		return false
	end

	-------------------------------------------------
	-- Main loop
	-------------------------------------------------
	while getgenv().RobloxUIRunning do
		cleanupBlueHighlights()

		if isPausedForAutoMonster() then
			cancelTween()
			clearRedTarget()
			task.wait(0.1)
			continue
		end

		if isBossPriorityActive() then
			ControllerLock.release(State, "AutoMonster")
			cancelTween()
			clearRedTarget()
			task.wait(0.1)
			continue
		end

		if not State.autoMonsterFarm then
			ControllerLock.release(State, "AutoMonster")
			cancelTween()
			clearRedTarget()
			clearBlueHighlights()
			task.wait(0.2)
			continue
		end

		if not ControllerLock.tryAcquire(State, "AutoMonster", "monster") then
			task.wait(0.1)
			continue
		end

		local monster, allTargets = findNearestTargetMonster()
		local models = {}

		for _, item in ipairs(allTargets or {}) do
			table.insert(models, item.model)
		end
		setBlueTargets(models)

		if monster then
			setRedTarget(monster)
			print("[AutoMonster] Found target:", monster.Name)

			local finished = attackMonster(monster)

			ControllerLock.release(State, "AutoMonster")

			if finished then
				task.wait(0.1)
			else
				task.wait(0.15)
			end
		else
			clearRedTarget()
			ControllerLock.release(State, "AutoMonster")
			task.wait(0.3)
		end
	end

	ControllerLock.release(State, "AutoMonster")
	cancelTween()
	clearRedTarget()
	clearBlueHighlights()

	print("AutoMonster stopped")
end

return AutoMonster