local AutoMonster = {}

function AutoMonster.run(State)
	print("AutoMonster Run on file moveTo 555678")

	local Players = game:GetService("Players")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")

	local player = Players.LocalPlayer

	local ATTACK_RANGE = 10
	local STOP_DISTANCE = 6
	local REPOSITION_DISTANCE = 4
	local MOVE_TIMEOUT = 2.5

	local function getCharacterParts()
		local character = player.Character or player.CharacterAdded:Wait()
		local humanoid = character:WaitForChild("Humanoid")
		local hrp = character:WaitForChild("HumanoidRootPart")
		return character, humanoid, hrp
	end

	local function getCharacterGroundOffset(character)
		local hrp = character:FindFirstChild("HumanoidRootPart")
		if not hrp then
			return 3
		end

		local _, size = character:GetBoundingBox()
		return math.max((size.Y / 2) + 0.5, 3)
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

	local function getGroundY(x, z, ignoreList)
		local rayParams = RaycastParams.new()
		rayParams.FilterType = Enum.RaycastFilterType.Blacklist
		rayParams.FilterDescendantsInstances = ignoreList or {}
		rayParams.IgnoreWater = false

		local origin = Vector3.new(x, 500, z)
		local direction = Vector3.new(0, -1000, 0)

		local result = workspace:Raycast(origin, direction, rayParams)
		if result then
			return result.Position.Y, result
		end

		return nil, nil
	end

	local function getStandPosition(currentPos, monsterPos, monster)
		local character = player.Character or player.CharacterAdded:Wait()

		local flatDir = Vector3.new(
			monsterPos.X - currentPos.X,
			0,
			monsterPos.Z - currentPos.Z
		)

		if flatDir.Magnitude > 0 then
			flatDir = flatDir.Unit
		else
			flatDir = Vector3.new(0, 0, -1)
		end

		local targetX = monsterPos.X - flatDir.X * STOP_DISTANCE
		local targetZ = monsterPos.Z - flatDir.Z * STOP_DISTANCE

		local groundY = getGroundY(targetX, targetZ, { character, monster })

		local y
		if groundY then
			local offset = getCharacterGroundOffset(character)
			y = groundY + offset
		else
			y = currentPos.Y
		end

		return Vector3.new(targetX, y, targetZ)
	end

	local function findMonsterRoot(model)
		return model:FindFirstChild("HumanoidRootPart", true)
			or model:FindFirstChild("RootPart", true)
			or model:FindFirstChild("Torso", true)
			or model:FindFirstChild("UpperTorso", true)
			or model.PrimaryPart
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

	local function findMonsterHumanoid(model)
		return model:FindFirstChildOfClass("Humanoid")
			or model:FindFirstChildWhichIsA("Humanoid", true)
	end

	local function getHorizontalDistance(a, b)
		local dx = a.X - b.X
		local dz = a.Z - b.Z
		return math.sqrt(dx * dx + dz * dz)
	end

	local function lookAtTarget(hrp, facePos)
		hrp.CFrame = CFrame.lookAt(
			hrp.Position,
			Vector3.new(facePos.X, hrp.Position.Y, facePos.Z)
		)
	end

	local function moveToPosition(targetPos, facePos)
		local character, humanoid, hrp = getCharacterParts()

		local distance = (targetPos - hrp.Position).Magnitude
		if distance < 1 then
			lookAtTarget(hrp, facePos)
			return true
		end

		humanoid:MoveTo(targetPos)

		local reached = false
		local done = false
		local conn

		conn = humanoid.MoveToFinished:Connect(function(ok)
			reached = ok
			done = true
		end)

		local startTime = tick()

		while getgenv().RobloxUIRunning and not done do
			if not State.autoMonsterFarm or State.autoMiner then
				break
			end

			if not character.Parent or humanoid.Health <= 0 then
				break
			end

			local distNow = (targetPos - hrp.Position).Magnitude
			if distNow <= 3 then
				reached = true
				done = true
				break
			end

			if tick() - startTime >= MOVE_TIMEOUT then
				break
			end

			task.wait(0.05)
		end

		if conn then
			conn:Disconnect()
		end

		lookAtTarget(hrp, facePos)
		return reached
	end

	local function findTargetMonster()
		local living = workspace:FindFirstChild("Living")
		if not living then
			return nil
		end

		local _, _, hrp = getCharacterParts()
		local nearestMonster = nil
		local nearestDistance = math.huge

		for _, model in ipairs(living:GetChildren()) do
			if model:IsA("Model") then
				local realName = getRealMonsterName(model)
				if isSelectedMonster(realName) then
					local monsterHumanoid = findMonsterHumanoid(model)
					local monsterRoot = findMonsterRoot(model)

					if monsterHumanoid and monsterRoot and monsterHumanoid.Health > 0 then
						local dist = getHorizontalDistance(monsterRoot.Position, hrp.Position)
						if dist < nearestDistance then
							nearestDistance = dist
							nearestMonster = model
						end
					end
				end
			end
		end

		return nearestMonster
	end

	local function snapToGroundNearCurrentPosition()
		local character, humanoid, hrp = getCharacterParts()

		local groundY = getGroundY(hrp.Position.X, hrp.Position.Z, { character })
		if not groundY then
			return
		end

		local offset = getCharacterGroundOffset(character)
		local fixedPos = Vector3.new(hrp.Position.X, groundY + offset, hrp.Position.Z)

		hrp.CFrame = CFrame.lookAt(
			fixedPos,
			fixedPos + hrp.CFrame.LookVector
		)
	end

	local function followAndAttack(monster)
		local _, humanoid, hrp = getCharacterParts()

		while getgenv().RobloxUIRunning and State.autoMonsterFarm and monster and monster.Parent do
			if State.autoMiner then
				return
			end

			local monsterHumanoid = findMonsterHumanoid(monster)
			local monsterRoot = findMonsterRoot(monster)

			if not monsterHumanoid or not monsterRoot then
				return
			end

			if monsterHumanoid.Health <= 0 then
				return
			end

			local currentPos = hrp.Position
			local monsterPos = monsterRoot.Position
			local horizontalDist = getHorizontalDistance(currentPos, monsterPos)

			local standPos = getStandPosition(currentPos, monsterPos, monster)

			if horizontalDist > ATTACK_RANGE then
				if (standPos - currentPos).Magnitude > REPOSITION_DISTANCE then
					moveToPosition(standPos, monsterPos)
				else
					lookAtTarget(hrp, monsterPos)
					task.wait(0.05)
				end
			else
				-- snapToGroundNearCurrentPosition()
				lookAtTarget(hrp, monsterPos)
				attack()
				task.wait(0.15)
			end

			local character = player.Character
			if not character or humanoid.Health <= 0 then
				_, humanoid, hrp = getCharacterParts()
			end
		end
	end

	task.spawn(function()
		while getgenv().RobloxUIRunning do
			if not State.autoMonsterFarm then
				task.wait(0.2)
				continue
			end

			if not hasAnySelectedMonster() then
				task.wait(0.5)
				continue
			end

			local target = findTargetMonster()
			if target then
				followAndAttack(target)
			else
				task.wait(0.5)
			end
		end
	end)
end

return AutoMonster