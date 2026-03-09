local AutoMiner = {}

function AutoMiner.run(State)
	print("AutoMiner started")

	local TweenService = game:GetService("TweenService")
	local Players = game:GetService("Players")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")

	local player = Players.LocalPlayer

	local function getCharacterParts()
		local character = player.Character or player.CharacterAdded:Wait()
		local humanoid = character:WaitForChild("Humanoid")
		local hrp = character:WaitForChild("HumanoidRootPart")
		return character, humanoid, hrp
	end

	local function mining()
		pcall(function()
			ReplicatedStorage
				:WaitForChild("Shared")
				:WaitForChild("Packages")
				:WaitForChild("Knit")
				:WaitForChild("Services")
				:WaitForChild("ToolService")
				:WaitForChild("RF")
				:WaitForChild("ToolActivated")
				:InvokeServer("Pickaxe")
		end)
	end

	local function getAllSpawnLocations()
		local results = {}

		local rocks = workspace:FindFirstChild("Rocks")
		if not rocks then
			return results
		end

		for _, mapFolder in ipairs(rocks:GetChildren()) do
			for _, obj in ipairs(mapFolder:GetDescendants()) do
				if obj.Name == "SpawnLocation" then
					table.insert(results, obj)
				end
			end
		end

		return results
	end

	local function getMinerPart(model)
		if not model then
			return nil
		end

		if model:IsA("BasePart") then
			return model
		end

		if model:IsA("Model") then
			return model.PrimaryPart
				or model:FindFirstChild("HumanoidRootPart")
				or model:FindFirstChildWhichIsA("BasePart")
		end

		return nil
	end

	local function getMinerHealth(mineral)
		if not mineral or not mineral.Parent then
			return nil
		end

		-- 1) เช็คจาก Attribute ก่อน
		local attrHealth = mineral:GetAttribute("Health")
		if type(attrHealth) == "number" then
			return attrHealth
		end

		-- 2) เช็คจากลูกชื่อ Health
		local hp = mineral:FindFirstChild("Health")
		if hp then
			if hp:IsA("NumberValue") or hp:IsA("IntValue") then
				return hp.Value
			end
		end

		-- 3) บางเกมใส่ไว้ในลูกลึกลงไป
		for _, obj in ipairs(mineral:GetDescendants()) do
			if obj.Name == "Health" then
				if obj:IsA("NumberValue") or obj:IsA("IntValue") then
					return obj.Value
				end
			end
		end

		return nil
	end

	local function isMinerAlive(mineral)
		if not mineral or not mineral.Parent then
			return false
		end

		local part = getMinerPart(mineral)
		if not part or not part.Parent then
			return false
		end

		local hp = getMinerHealth(mineral)
		if hp ~= nil then
			return hp > 0
		end

		-- ถ้าไม่มี Health ให้ถือว่ายังอยู่ ถ้า model ยังไม่หาย
		return true
	end

	local function getPriorityList()
		return {
			"Floating Crystal",
			"Large Red Crystal",
			"Large Ice Crystal",
			"Medium Red Crystal",
			"Medium Ice Crystal",
			"Small Red Crystal",
		}
	end

	local function findMineral()
		local spawnLocations = getAllSpawnLocations()
		if #spawnLocations == 0 then
			warn("No SpawnLocation found under workspace.Rocks")
			return nil
		end

		local _, _, hrp = getCharacterParts()

		for _, targetName in ipairs(getPriorityList()) do
			if State.selectedMinerals and State.selectedMinerals[targetName] then
				local nearestMiner = nil
				local nearestDistance = math.huge

				for _, spawnLocation in ipairs(spawnLocations) do
					for _, child in ipairs(spawnLocation:GetChildren()) do
						if child.Name == targetName and isMinerAlive(child) then
							local part = getMinerPart(child)
							if part then
								local dist = (part.Position - hrp.Position).Magnitude
								if dist < nearestDistance then
									nearestDistance = dist
									nearestMiner = child
								end
							end
						end
					end
				end

				if nearestMiner then
					return nearestMiner
				end
			end
		end

		return nil
	end

	local function moveToMiner(mineral)
		local _, _, hrp = getCharacterParts()
		local targetPart = getMinerPart(mineral)

		if not targetPart then
			return false
		end

		local targetCF = targetPart.CFrame * CFrame.new(0, 0, 4)
		local dist = (targetCF.Position - hrp.Position).Magnitude

		local tween = TweenService:Create(
			hrp,
			TweenInfo.new(math.max(dist / 60, 0.05)),
			{ CFrame = targetCF }
		)

		tween:Play()
		tween.Completed:Wait()

		return true
	end

	local function mineTarget(mineral)
		local timeout = tick() + 20
		local lastHp = getMinerHealth(mineral)

		while State.autoMiner and mineral and mineral.Parent and tick() < timeout do
			if not isMinerAlive(mineral) then
				return true
			end

			local _, _, hrp = getCharacterParts()
			local targetPart = getMinerPart(mineral)

			if not targetPart then
				return true
			end

			local dist = (targetPart.Position - hrp.Position).Magnitude
			if dist > 12 then
				moveToMiner(mineral)
				targetPart = getMinerPart(mineral)
				if not targetPart then
					return true
				end
			end

			mining()
			task.wait(0.15)

			local currentHp = getMinerHealth(mineral)

			-- ถ้า hp มีค่าและลดจน <= 0 ให้จบเลย
			if currentHp ~= nil and currentHp <= 0 then
				return true
			end

			-- ถ้า hp จากเดิมมี แต่ตอนนี้ไม่มีแล้ว และ target เปลี่ยน/หาย ให้ถือว่าแตกแล้ว
			if lastHp ~= nil and currentHp == nil then
				local newPart = getMinerPart(mineral)
				if not newPart or not newPart.Parent then
					return true
				end
			end

			lastHp = currentHp

			if not isMinerAlive(mineral) then
				return true
			end
		end

		return false
	end

	while true do
		if not State.autoMiner then
			task.wait(0.2)
			continue
		end

		local mineral = findMineral()

		if mineral then
			print("Found mineral:", mineral.Name)
			moveToMiner(mineral)
			local finished = mineTarget(mineral)

			if finished then
				task.wait(0.2)
			else
				task.wait(0.1)
			end
		else
			warn("No selected mineral found")
			task.wait(0.5)
		end
	end
end

return AutoMiner