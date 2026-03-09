local AutoMonster = {}

function AutoMonster.run(State)
	local Players = game:GetService("Players")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")

	local player = Players.LocalPlayer

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

	local function isSelectedMonster(name)
		return State.selectedMonsters and State.selectedMonsters[name] == true
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
			if model:IsA("Model") and isSelectedMonster(model.Name) then
				local monsterHumanoid = model:FindFirstChildOfClass("Humanoid")
				local monsterHrp = model:FindFirstChild("HumanoidRootPart")

				if monsterHumanoid and monsterHrp and monsterHumanoid.Health > 0 then
					local dist = (monsterHrp.Position - hrp.Position).Magnitude
					if dist < nearestDistance then
						nearestDistance = dist
						nearestMonster = model
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

			local monsterHumanoid = monster:FindFirstChildOfClass("Humanoid")
			local monsterHrp = monster:FindFirstChild("HumanoidRootPart")

			if not monsterHumanoid or not monsterHrp then
				return
			end

			if monsterHumanoid.Health <= 0 then
				return
			end

			local dist = (monsterHrp.Position - hrp.Position).Magnitude

			if dist > 6 then
				humanoid:MoveTo(monsterHrp.Position)
			end

			local look = Vector3.new(monsterHrp.Position.X, hrp.Position.Y, monsterHrp.Position.Z)
			hrp.CFrame = CFrame.lookAt(hrp.Position, look)

			attack()
			task.wait(0.15)

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
				warn("AutoMonster: no selected monsters")
				task.wait(0.5)
				continue
			end

			local target = findTargetMonster()
			if target then
				followAndAttack(target)
			else
				task.wait(0.2)
			end
		end
	end)
end

return AutoMonster