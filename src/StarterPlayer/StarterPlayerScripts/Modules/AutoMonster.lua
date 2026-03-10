local AutoMonster = {}

function AutoMonster.run(State)
	local Players = game:GetService("Players")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local TweenService = game:GetService("TweenService")

	local player = Players.LocalPlayer
	local activeTween = nil

	local FLY_Y = 120
	local ATTACK_RANGE = 10
	local STOP_DISTANCE = 6
	local TWEEN_REPOSITION_DISTANCE = 4
	local MOVE_SPEED = 90

	local function getCharacterParts()
		local character = player.Character or player.CharacterAdded:Wait()
		local humanoid = character:WaitForChild("Humanoid")
		local hrp = character:WaitForChild("HumanoidRootPart")
		return character, humanoid, hrp
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

    local function getStandPosition(currentPos, monsterPos)
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

		return Vector3.new(
			monsterPos.X - flatDir.X * STOP_DISTANCE,
			currentPos.Y,
			monsterPos.Z - flatDir.Z * STOP_DISTANCE
		)
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
	local function setTweenLock(character, humanoid, hrp, locked)
		if humanoid then
			humanoid.AutoRotate = not locked
		end
	end
	local function tweenLookAt(hrp, facePos)
		hrp.CFrame = CFrame.lookAt(
			hrp.Position,
			Vector3.new(facePos.X, hrp.Position.Y, facePos.Z)
		)
	end

	local function tweenToPosition(hrp, targetPos, facePos, speed)
		local character, humanoid = getCharacterParts()

		if activeTween then
			activeTween:Cancel()
			activeTween = nil
		end

		local distance = (targetPos - hrp.Position).Magnitude
		if distance < 0.5 then
			tweenLookAt(hrp, facePos)
			return
		end

		local tweenTime = math.max(distance / (speed or 55), 0.08)

		setTweenLock(character, humanoid, hrp, true)

		activeTween = TweenService:Create(
			hrp,
			TweenInfo.new(tweenTime, Enum.EasingStyle.Linear, Enum.EasingDirection.Out),
			{
				CFrame = CFrame.lookAt(
					targetPos,
					Vector3.new(facePos.X, targetPos.Y, facePos.Z)
				)
			}
		)

		activeTween:Play()
		activeTween.Completed:Wait()
		activeTween = nil

		setTweenLock(character, humanoid, hrp, false)
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

			local standPos = getStandPosition(currentPos, monsterPos)

			if horizontalDist > ATTACK_RANGE then
				if (Vector3.new(standPos.X, currentPos.Y, standPos.Z) - currentPos).Magnitude > TWEEN_REPOSITION_DISTANCE then
					tweenToPosition(hrp, standPos, monsterPos, MOVE_SPEED)
				else
					tweenLookAt(hrp, monsterPos)
					task.wait(0.05)
				end
			else
				tweenLookAt(hrp, monsterPos)
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