local AutoMiner = {}

function AutoMiner.run(State)
	print("AutoMiner started")

	local TweenService = game:GetService("TweenService")
	local Players = game:GetService("Players")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")

	local player = Players.LocalPlayer

	local skippedMinerals = {}

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

		local attrHealth = mineral:GetAttribute("Health")
		if type(attrHealth) == "number" then
			return attrHealth
		end

		local hp = mineral:FindFirstChild("Health")
		if hp and (hp:IsA("NumberValue") or hp:IsA("IntValue")) then
			return hp.Value
		end

		for _, obj in ipairs(mineral:GetDescendants()) do
			if obj.Name == "Health" and (obj:IsA("NumberValue") or obj:IsA("IntValue")) then
				return obj.Value
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

	local function cleanupSkippedMinerals()
		local now = tick()
		for mineral, expireAt in pairs(skippedMinerals) do
			if not mineral or not mineral.Parent or now >= expireAt then
				skippedMinerals[mineral] = nil
			end
		end
	end

	local function markMineralSkipped(mineral, seconds)
		if mineral then
			skippedMinerals[mineral] = tick() + (seconds or 8)
		end
	end

	local function isMineralSkipped(mineral)
		local expireAt = skippedMinerals[mineral]
		if not expireAt then
			return false
		end
		if tick() >= expireAt then
			skippedMinerals[mineral] = nil
			return false
		end
		return true
	end

	local function hasAnySelectedOre()
		if not State.selectedOres then
			return false
		end

		for _, selected in pairs(State.selectedOres) do
			if selected then
				return true
			end
		end

		return false
	end

	local function getOreModels(mineral)
		local results = {}
		if not mineral or not mineral.Parent then
			return results
		end

		for _, child in ipairs(mineral:GetDescendants()) do
			if child:IsA("Model") and child.Name == "Ore" then
				table.insert(results, child)
			end
		end

		return results
	end

	local function getOreNamesFromMineral(mineral)
		local names = {}
		local oreModels = getOreModels(mineral)

		for _, oreModel in ipairs(oreModels) do
			local oreName = oreModel:GetAttribute("Ore")
			if oreName and oreName ~= "" then
				table.insert(names, oreName)
			end
		end

		return names
	end

	local function hasAnyOreSpawned(mineral)
		return #getOreModels(mineral) > 0
	end

	local function hasMatchingSelectedOre(mineral)
		local oreNames = getOreNamesFromMineral(mineral)

		for _, oreName in ipairs(oreNames) do
			if State.selectedOres and State.selectedOres[oreName] then
				return true, oreName
			end
		end

		return false, nil
	end

	-- =========================
	-- MONSTER LOGIC
	-- =========================

	local function getMonsterPart(model)
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

	local function isMonsterAlive(monster)
		if not monster or not monster.Parent then
			return false
		end

		local humanoid = monster:FindFirstChildOfClass("Humanoid")
		if humanoid then
			return humanoid.Health > 0
		end

		local hpAttr = monster:GetAttribute("Health")
		if type(hpAttr) == "number" then
			return hpAttr > 0
		end

		local hpObj = monster:FindFirstChild("Health")
		if hpObj and (hpObj:IsA("NumberValue") or hpObj:IsA("IntValue")) then
			return hpObj.Value > 0
		end

		return monster.Parent ~= nil
	end

	local function isOwnCharacterModel(model)
		local character = player.Character
		return character and model == character
	end

	local function findNearbyMonster(maxDistance)
		local living = workspace:FindFirstChild("Living")
		if not living then
			return nil
		end

		local _, _, hrp = getCharacterParts()
		local nearestMonster = nil
		local nearestDistance = maxDistance or 20

		for _, mob in ipairs(living:GetChildren()) do
			if mob:IsA("Model") and not isOwnCharacterModel(mob) and isMonsterAlive(mob) then
				local part = getMonsterPart(mob)
				if part then
					local dist = (part.Position - hrp.Position).Magnitude
					if dist <= nearestDistance then
						nearestDistance = dist
						nearestMonster = mob
					end
				end
			end
		end

		return nearestMonster
	end

	local function moveToTargetPart(targetPart, offsetZ)
		local _, _, hrp = getCharacterParts()

		if not targetPart then
			return false
		end

		local targetCF = targetPart.CFrame * CFrame.new(0, 0, offsetZ or 4)
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

	local function attackMonster(monster)
		local timeout = tick() + 12

		while State.autoMiner and monster and monster.Parent and tick() < timeout do
			if not isMonsterAlive(monster) then
				return true
			end

			local part = getMonsterPart(monster)
			if not part then
				return true
			end

			local _, _, hrp = getCharacterParts()
			local dist = (part.Position - hrp.Position).Magnitude

			if dist > 10 then
				moveToTargetPart(part, 4)
			end

			-- ตอนนี้ใช้ mining() ไปก่อน เพราะบางเกมใช้ ToolActivated ตัวเดียวกัน
			attack()
			task.wait(0.12)

			if not isMonsterAlive(monster) then
				return true
			end

			-- ถ้ามอนหลุดไปไกลมาก ถือว่าพอแล้ว กลับไปตีหิน
			local _, _, hrp2 = getCharacterParts()
			local part2 = getMonsterPart(monster)
			if not part2 then
				return true
			end

			local dist2 = (part2.Position - hrp2.Position).Magnitude
			if dist2 > 35 then
				return false
			end
		end

		return false
	end

	local function handleNearbyMonster()
        if not State.autoDefend then
            return false
        end

        local monster = findNearbyMonster(18)
        if not monster then
            return false
        end

        print("Nearby monster detected:", monster.Name)
        attackMonster(monster)
        return true
    end

	-- =========================
	-- MINERAL FINDING
	-- =========================

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
						if child.Name == targetName
							and isMinerAlive(child)
							and not isMineralSkipped(child) then
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
		local targetPart = getMinerPart(mineral)
		if not targetPart then
			return false
		end
		return moveToTargetPart(targetPart, 4)
	end

	local function mineTarget(mineral)
		local timeout = tick() + 20
		local oreMode = hasAnySelectedOre()
		local foundOreOnce = false
		local lastHp = getMinerHealth(mineral)

		while State.autoMiner and mineral and mineral.Parent and tick() < timeout do
			-- ถ้ามีมอนเข้ามาใกล้ ให้ไปจัดมอนก่อน แล้วค่อยกลับมา
			handleNearbyMonster()

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

			if oreMode then
				local oreSpawned = hasAnyOreSpawned(mineral)

				if oreSpawned then
					foundOreOnce = true

					local matched = hasMatchingSelectedOre(mineral)
					if not matched then
						return false
					end
				end
			end

			mining()
			task.wait(0.15)

			local currentHp = getMinerHealth(mineral)

			if currentHp ~= nil and currentHp <= 0 then
				return true
			end

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

			if oreMode and foundOreOnce then
				local matched = hasMatchingSelectedOre(mineral)
				if not matched then
					return false
				end
			end
		end

		return false
	end

	while true do
		if not State.autoMiner then
			task.wait(0.2)
			continue
		end

		cleanupSkippedMinerals()

		-- ก่อนหาแร่ใหม่ เช็คมอนรอบตัวก่อน
		if handleNearbyMonster() then
			task.wait(0.1)
		end

		local mineral = findMineral()

		if mineral then
			print("Found mineral:", mineral.Name)
			moveToMiner(mineral)

			local finished = mineTarget(mineral)
			if finished == false then
				markMineralSkipped(mineral, 8)
				task.wait(0.2)
			else
				task.wait(0.2)
			end
		else
			warn("No selected mineral found")
			task.wait(0.5)
		end
	end
end

return AutoMiner