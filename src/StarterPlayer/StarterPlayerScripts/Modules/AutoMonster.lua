local AutoMonster = {}

function AutoMonster.run(State)
	print("AutoMonster started")

	local TweenService = game:GetService("TweenService")
	local Players = game:GetService("Players")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")

	local player = Players.LocalPlayer
	local activeTween = nil
	local noclipParts = {}

	local ATTACK_RANGE = 10
	local STOP_DISTANCE = 4
	local SEARCH_DISTANCE = math.huge

	local STAGING_POINT = Vector3.new(389, 138, 93)
	local STAGING_RADIUS = 8
	local SAFE_FLY_HEIGHT = 160
	local MOVE_SPEED = 70

	--------------------------------------------------
	-- CHARACTER
	--------------------------------------------------

	local function getCharacterParts()
		local character = player.Character or player.CharacterAdded:Wait()
		local humanoid = character:WaitForChild("Humanoid")
		local hrp = character:WaitForChild("HumanoidRootPart")
		return character, humanoid, hrp
	end

	--------------------------------------------------
	-- NOCLIP
	--------------------------------------------------

	local function setCharacterNoclip(enabled)
		local character = player.Character or player.CharacterAdded:Wait()

		for _, obj in ipairs(character:GetDescendants()) do
			if obj:IsA("BasePart") then
				if enabled then
					if noclipParts[obj] == nil then
						noclipParts[obj] = obj.CanCollide
					end
					obj.CanCollide = false
				else
					if noclipParts[obj] ~= nil then
						obj.CanCollide = noclipParts[obj]
						noclipParts[obj] = nil
					else
						obj.CanCollide = true
					end
				end
			end
		end
	end

	--------------------------------------------------
	-- FREEZE MOTION
	--------------------------------------------------

	local function zeroVelocity(hrp)
		pcall(function()
			hrp.Velocity = Vector3.zero
		end)
		pcall(function()
			hrp.RotVelocity = Vector3.zero
		end)
		pcall(function()
			hrp.AssemblyLinearVelocity = Vector3.zero
		end)
		pcall(function()
			hrp.AssemblyAngularVelocity = Vector3.zero
		end)
	end

	--------------------------------------------------
	-- PREPARE CHARACTER FOR TWEEN
	--------------------------------------------------

	local function prepareCharacterForTween(humanoid, hrp)
		setCharacterNoclip(true)
		zeroVelocity(hrp)

		pcall(function()
			humanoid.AutoRotate = false
		end)

		pcall(function()
			humanoid:ChangeState(Enum.HumanoidStateType.Physics)
		end)

		pcall(function()
			humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
			humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
			humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
			humanoid:SetStateEnabled(Enum.HumanoidStateType.Freefall, false)
		end)
	end

	local function restoreCharacterAfterTween(humanoid, hrp)
		zeroVelocity(hrp)
		setCharacterNoclip(false)

		pcall(function()
			humanoid.AutoRotate = true
		end)

		pcall(function()
			humanoid:ChangeState(Enum.HumanoidStateType.Running)
		end)

		pcall(function()
			humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, true)
			humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, true)
			humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
			humanoid:SetStateEnabled(Enum.HumanoidStateType.Freefall, true)
		end)
	end

	--------------------------------------------------
	-- CANCEL TWEEN
	--------------------------------------------------

	local function cancelTween()
		if activeTween then
			pcall(function()
				activeTween:Cancel()
			end)
			activeTween = nil
		end

		local _, humanoid, hrp = getCharacterParts()
		restoreCharacterAfterTween(humanoid, hrp)
	end

	--------------------------------------------------
	-- ATTACK
	--------------------------------------------------

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

	--------------------------------------------------
	-- NAME HELPERS
	--------------------------------------------------

	local function normalizeName(name)
		name = tostring(name or "")
		name = name:gsub("%d+$", "")
		name = name:gsub("%s+$", "")
		name = name:gsub("^%s+", "")
		return string.lower(name)
	end

	local function getRealMonsterName(model)
		return normalizeName(model.Name)
	end

	local function isSelectedMonster(realName)
		if not State.selectedMonsters then
			return false
		end

		local n = normalizeName(realName)

		for monsterName, selected in pairs(State.selectedMonsters) do
			if selected and normalizeName(monsterName) == n then
				return true
			end
		end

		return false
	end

	local function isOrcMonster(name)
		local n = normalizeName(name)
		return string.find(n, "common orc", 1, true) ~= nil
			or string.find(n, "elite orc", 1, true) ~= nil
	end

	--------------------------------------------------
	-- STAGING
	--------------------------------------------------

	local function isAtStaging()
		local _, _, hrp = getCharacterParts()
		return (hrp.Position - STAGING_POINT).Magnitude < STAGING_RADIUS
	end

	--------------------------------------------------
	-- SAFE TWEEN USING CFRAME
	--------------------------------------------------

	local function tweenHRPTo(targetPos, speed)
		local _, humanoid, hrp = getCharacterParts()

		cancelTween()
		prepareCharacterForTween(humanoid, hrp)

		local startPos = hrp.Position
		local dist = (targetPos - startPos).Magnitude
		local duration = math.max(dist / (speed or MOVE_SPEED), 0.08)

		local lookAt = targetPos
		if (lookAt - startPos).Magnitude < 0.01 then
			lookAt = startPos + Vector3.new(0, 0, -1)
		end

		local tween = TweenService:Create(
			hrp,
			TweenInfo.new(duration, Enum.EasingStyle.Linear),
			{CFrame = CFrame.lookAt(targetPos, lookAt)}
		)

		activeTween = tween
		tween:Play()

		while tween.PlaybackState == Enum.PlaybackState.Playing do
			if not getgenv().RobloxUIRunning or not State.autoMonsterFarm then
				tween:Cancel()
				break
			end

			setCharacterNoclip(true)
			zeroVelocity(hrp)
			task.wait(0.03)
		end

		activeTween = nil
		restoreCharacterAfterTween(humanoid, hrp)
	end

	--------------------------------------------------
	-- MOVE TO STAGING
	-- ยกขึ้นก่อน แล้วค่อยบินไป
	--------------------------------------------------

	local function moveToStaging()
		local _, _, hrp = getCharacterParts()
		local currentPos = hrp.Position

		local riseY = math.max(currentPos.Y + 25, SAFE_FLY_HEIGHT)
		local risePos = Vector3.new(currentPos.X, riseY, currentPos.Z)
		local flyPos = Vector3.new(STAGING_POINT.X, riseY, STAGING_POINT.Z)
		local dropPos = STAGING_POINT

		print("MoveToStaging rise ->", risePos)
		tweenHRPTo(risePos, 85)

		if not getgenv().RobloxUIRunning or not State.autoMonsterFarm then
			return
		end

		print("MoveToStaging fly ->", flyPos)
		tweenHRPTo(flyPos, 95)

		if not getgenv().RobloxUIRunning or not State.autoMonsterFarm then
			return
		end

		print("MoveToStaging drop ->", dropPos)
		tweenHRPTo(dropPos, 70)
	end

	--------------------------------------------------
	-- MONSTER HELPERS
	--------------------------------------------------

	local function findMonsterRoot(model)
		return model:FindFirstChild("HumanoidRootPart", true)
			or model:FindFirstChild("RootPart", true)
			or model:FindFirstChild("Torso", true)
			or model.PrimaryPart
	end

	local function findMonsterHumanoid(model)
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

		return true
	end

	--------------------------------------------------
	-- MOVE TO TARGET
	--------------------------------------------------

	local function moveToTargetPart(targetPart, stopDistance)
		local _, _, hrp = getCharacterParts()

		if not targetPart or not targetPart.Parent then
			return false
		end

		local targetPos = targetPart.Position
		local myPos = hrp.Position

		local flatDir = Vector3.new(
			targetPos.X - myPos.X,
			0,
			targetPos.Z - myPos.Z
		)

		if flatDir.Magnitude <= 0.05 then
			return true
		end

		flatDir = flatDir.Unit

		local desiredPos = Vector3.new(
			targetPos.X - flatDir.X * (stopDistance or STOP_DISTANCE),
			myPos.Y,
			targetPos.Z - flatDir.Z * (stopDistance or STOP_DISTANCE)
		)

		tweenHRPTo(desiredPos, 65)
		return true
	end

	--------------------------------------------------
	-- FIND MONSTER
	--------------------------------------------------

	local function findNearestTargetMonster()
		local living = workspace:FindFirstChild("Living")
		if not living then
			return nil
		end

		local _, _, hrp = getCharacterParts()
		local nearestMonster = nil
		local nearestDistance = SEARCH_DISTANCE

		for _, mob in ipairs(living:GetChildren()) do
			if mob:IsA("Model") then
				local realName = getRealMonsterName(mob)

				if isSelectedMonster(realName) and isMonsterAlive(mob) then
					local part = findMonsterRoot(mob)
					if part then
						local dist = (part.Position - hrp.Position).Magnitude
						if dist < nearestDistance then
							nearestDistance = dist
							nearestMonster = mob
						end
					end
				end
			end
		end

		return nearestMonster
	end

	--------------------------------------------------
	-- ATTACK LOOP
	--------------------------------------------------

	local function attackMonster(monster)
		local monsterName = getRealMonsterName(monster)
		local requiresStaging = isOrcMonster(monsterName)

		if requiresStaging and not isAtStaging() then
			print("Orc target detected, going staging first:", monsterName)
			moveToStaging()
		end

		while getgenv().RobloxUIRunning and State.autoMonsterFarm and monster and monster.Parent do
			if not isMonsterAlive(monster) then
				cancelTween()
				return true
			end

			local part = findMonsterRoot(monster)
			if not part then
				return true
			end

			local _, _, hrp = getCharacterParts()
			local dist = (part.Position - hrp.Position).Magnitude

			if dist > ATTACK_RANGE then
				local moved = moveToTargetPart(part, STOP_DISTANCE)
				if not moved then
					return false
				end
			end

			attack()
			task.wait(0.12)
		end

		cancelTween()
		return false
	end

	--------------------------------------------------
	-- MAIN LOOP
	--------------------------------------------------

	task.spawn(function()
		while getgenv().RobloxUIRunning do
			if not State.autoMonsterFarm then
				cancelTween()
				task.wait(0.2)
				continue
			end

			local monster = findNearestTargetMonster()

			if monster then
				print("Found target:", monster.Name)
				attackMonster(monster)
			else
				if not isAtStaging() then
					moveToStaging()
				end
				task.wait(0.5)
			end
		end

		cancelTween()
	end)
end

return AutoMonster