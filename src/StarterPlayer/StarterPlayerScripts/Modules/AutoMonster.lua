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

	local function getCharacterParts()
		local character = player.Character or player.CharacterAdded:Wait()
		local humanoid = character:WaitForChild("Humanoid")
		local hrp = character:WaitForChild("HumanoidRootPart")
		return character, humanoid, hrp
	end

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

	local function cancelTween()
		if activeTween then
			pcall(function()
				activeTween:Cancel()
			end)
			activeTween = nil
		end
		setCharacterNoclip(false)
	end

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

	local function hasAnySelectedMonster()
		if not State.selectedMonsters then
			return false
		end

		for _, selected in pairs(State.selectedMonsters) do
			if selected then
				return true
			end
		end

		return false
	end

	local function findMonsterRoot(model)
		return model:FindFirstChild("HumanoidRootPart", true)
			or model:FindFirstChild("RootPart", true)
			or model:FindFirstChild("Torso", true)
			or model:FindFirstChild("UpperTorso", true)
			or model.PrimaryPart
	end

	local function findMonsterHumanoid(model)
		return model:FindFirstChildOfClass("Humanoid")
			or model:FindFirstChildWhichIsA("Humanoid", true)
	end

	local function getRealMonsterName(model)
		for _, obj in ipairs(model:GetDescendants()) do
			if obj:IsA("StringValue") then
				local n = string.lower(obj.Name)
				if n == "name" or n == "mobname" or n == "monstername" then
					if obj.Value and obj.Value ~= "" then
						return obj.Value
					end
				end
			end
		end

		for _, child in ipairs(model:GetChildren()) do
			if child:IsA("Model") then
				local hum = child:FindFirstChildOfClass("Humanoid")
				if hum then
					return child.Name
				end
			end
		end

		local cleaned = model.Name:gsub("%d+$", "")
		cleaned = cleaned:gsub("%s+$", "")
		return cleaned
	end

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

	local function isMonsterAlive(monster)
		if not monster or not monster.Parent then
			return false
		end

		local hum = findMonsterHumanoid(monster)
		if hum then
			return hum.Health > 0
		end

		local hpAttr = monster:GetAttribute("Health")
		if type(hpAttr) == "number" then
			return hpAttr > 0
		end

		local hpObj = monster:FindFirstChild("Health")
		if hpObj and (hpObj:IsA("NumberValue") or hpObj:IsA("IntValue")) then
			return hpObj.Value > 0
		end

		return true
	end

	local function faceTargetPart(targetPart)
		local _, _, hrp = getCharacterParts()
		if not targetPart or not targetPart.Parent then
			return false
		end

		local targetPos = targetPart.Position
		local myPos = hrp.Position
		local lookAt = Vector3.new(targetPos.X, myPos.Y, targetPos.Z)

		if (lookAt - myPos).Magnitude < 0.05 then
			return false
		end

		hrp.CFrame = CFrame.lookAt(myPos, lookAt)
		return true
	end

	local function moveToTargetPart(targetPart, stopDistance)
		local _, humanoid, hrp = getCharacterParts()

		if humanoid.Health <= 0 then
			return false
		end

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

		local desiredCF = CFrame.lookAt(
			desiredPos,
			Vector3.new(targetPos.X, desiredPos.Y, targetPos.Z)
		)

		local dist = (desiredPos - myPos).Magnitude

		cancelTween()
		setCharacterNoclip(true)

		pcall(function()
			humanoid:ChangeState(Enum.HumanoidStateType.Physics)
		end)

		local tween = TweenService:Create(
			hrp,
			TweenInfo.new(math.max(dist / 60, 0.05), Enum.EasingStyle.Linear),
			{ CFrame = desiredCF }
		)

		activeTween = tween
		tween:Play()

		while tween.PlaybackState == Enum.PlaybackState.Playing do
			if not getgenv().RobloxUIRunning or not State.autoMonsterFarm or State.autoMiner then
				tween:Cancel()
				setCharacterNoclip(false)
				return false
			end

			if not targetPart or not targetPart.Parent then
				tween:Cancel()
				setCharacterNoclip(false)
				return false
			end

			setCharacterNoclip(true)
			task.wait(0.03)
		end

		setCharacterNoclip(false)

		pcall(function()
			if humanoid and humanoid.Parent then
				humanoid:ChangeState(Enum.HumanoidStateType.Running)
			end
		end)

		activeTween = nil
		return true
	end

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

	local function attackMonster(monster)
		local timeout = tick() + 20

		while getgenv().RobloxUIRunning and State.autoMonsterFarm and monster and monster.Parent and tick() < timeout do
			if State.autoMiner then
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
					return false
				end

				part = findMonsterRoot(monster)
				if not part then
					return true
				end
			end

			faceTargetPart(part)
			task.wait(0.03)

			part = findMonsterRoot(monster)
			if not part then
				return true
			end

			faceTargetPart(part)
			attack()
			task.wait(0.12)

			if not isMonsterAlive(monster) then
				cancelTween()
				return true
			end

			local _, _, hrp2 = getCharacterParts()
			local part2 = findMonsterRoot(monster)
			if not part2 then
				return true
			end

			local dist2 = (part2.Position - hrp2.Position).Magnitude
			if dist2 > 35 then
				return false
			end
		end

		cancelTween()
		return false
	end

	task.spawn(function()
		while getgenv().RobloxUIRunning do
			if not State.autoMonsterFarm then
				cancelTween()
				task.wait(0.2)
				continue
			end

			if State.autoMiner then
				cancelTween()
				task.wait(0.2)
				continue
			end

			if not hasAnySelectedMonster() then
				cancelTween()
				task.wait(0.5)
				continue
			end

			local monster = findNearestTargetMonster()
			if monster then
				attackMonster(monster)
			else
				task.wait(0.3)
			end
		end

		cancelTween()
	end)
end

return AutoMonster