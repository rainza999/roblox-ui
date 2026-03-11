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

	local STAGING_POINT = Vector3.new(389,138,93)

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
	-- CANCEL TWEEN
	--------------------------------------------------

	local function cancelTween()

		if activeTween then
			pcall(function()
				activeTween:Cancel()
			end)
			activeTween = nil
		end

		setCharacterNoclip(false)

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
	-- MONSTER TYPE
	--------------------------------------------------

	local function isOrcMonster(name)

		local n = string.lower(name)

		return n == "common orc" or n == "elite orc"

	end

	--------------------------------------------------
	-- CHECK STAGING
	--------------------------------------------------

	local function isAtStaging()

		local _,_,hrp = getCharacterParts()

		return (hrp.Position - STAGING_POINT).Magnitude < 8

	end

	--------------------------------------------------
	-- MOVE TO STAGING
	--------------------------------------------------

	local function moveToStaging()

		local character, humanoid, hrp = getCharacterParts()

		cancelTween()

		setCharacterNoclip(true)

		pcall(function()
			humanoid:ChangeState(Enum.HumanoidStateType.Physics)
		end)

		local dist = (STAGING_POINT - hrp.Position).Magnitude
		local time = math.max(dist / 70,0.1)

		local tween = TweenService:Create(
			hrp,
			TweenInfo.new(time, Enum.EasingStyle.Linear),
			{Position = STAGING_POINT}
		)

		activeTween = tween
		tween:Play()

		while tween.PlaybackState == Enum.PlaybackState.Playing do

			if not getgenv().RobloxUIRunning then
				tween:Cancel()
				break
			end

			setCharacterNoclip(true)

			task.wait(0.03)

		end

		setCharacterNoclip(false)

		pcall(function()
			humanoid:ChangeState(Enum.HumanoidStateType.Running)
		end)

		activeTween = nil

	end

	--------------------------------------------------
	-- FIND MONSTER ROOT
	--------------------------------------------------

	local function findMonsterRoot(model)

		return model:FindFirstChild("HumanoidRootPart", true)
			or model:FindFirstChild("RootPart", true)
			or model:FindFirstChild("Torso", true)
			or model.PrimaryPart

	end

	--------------------------------------------------
	-- MONSTER HUMANOID
	--------------------------------------------------

	local function findMonsterHumanoid(model)

		return model:FindFirstChildOfClass("Humanoid")
			or model:FindFirstChildWhichIsA("Humanoid", true)

	end

	--------------------------------------------------
	-- MONSTER NAME
	--------------------------------------------------

	local function getRealMonsterName(model)

		local cleaned = model.Name:gsub("%d+$", "")
		cleaned = cleaned:gsub("%s+$", "")

		return cleaned

	end

	--------------------------------------------------
	-- SELECTED MONSTER
	--------------------------------------------------

	local function isSelectedMonster(realName)

		if not State.selectedMonsters then
			return false
		end

		for monsterName, selected in pairs(State.selectedMonsters) do
			if selected and string.lower(monsterName) == string.lower(realName) then
				return true
			end
		end

		return false

	end

	--------------------------------------------------
	-- MONSTER ALIVE
	--------------------------------------------------

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

		local _, humanoid, hrp = getCharacterParts()

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
			targetPos.X - flatDir.X * (stopDistance or 4),
			myPos.Y,
			targetPos.Z - flatDir.Z * (stopDistance or 4)
		)

		local dist = (desiredPos - myPos).Magnitude

		cancelTween()
		setCharacterNoclip(true)

		pcall(function()
			humanoid:ChangeState(Enum.HumanoidStateType.Physics)
		end)

		local tween = TweenService:Create(
			hrp,
			TweenInfo.new(math.max(dist / 60,0.05), Enum.EasingStyle.Linear),
			{Position = desiredPos}
		)

		activeTween = tween
		tween:Play()

		while tween.PlaybackState == Enum.PlaybackState.Playing do

			if not getgenv().RobloxUIRunning or not State.autoMonsterFarm then
				tween:Cancel()
				return false
			end

			setCharacterNoclip(true)

			task.wait(0.03)

		end

		setCharacterNoclip(false)

		pcall(function()
			humanoid:ChangeState(Enum.HumanoidStateType.Running)
		end)

		activeTween = nil

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

		local _,_,hrp = getCharacterParts()

		local nearestMonster = nil
		local nearestDistance = SEARCH_DISTANCE
		local needOrcStaging = false

		for _, mob in ipairs(living:GetChildren()) do

			if mob:IsA("Model") then

				local realName = getRealMonsterName(mob)

				if isSelectedMonster(realName) and isMonsterAlive(mob) then

					if isOrcMonster(realName) then
						needOrcStaging = true
					end

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

		if needOrcStaging and not isAtStaging() then
			moveToStaging()
		end

		return nearestMonster

	end

	--------------------------------------------------
	-- ATTACK LOOP
	--------------------------------------------------

	local function attackMonster(monster)

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