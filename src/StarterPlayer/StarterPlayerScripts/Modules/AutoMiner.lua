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

	local function isMinerAlive(mineral)
		if not mineral or not mineral.Parent then
			return false
		end

		-- เผื่อบางเกมใช้ Attribute / BoolValue / Health ของตัวเอง
		local hp = mineral:FindFirstChild("Health")
		if hp and hp:IsA("NumberValue") then
			return hp.Value > 0
		end

		return true
	end

	local function findMineral()
        local spawnLocations = getAllSpawnLocations()
        if #spawnLocations == 0 then
            warn("No SpawnLocation found under workspace.Rocks")
            return nil
        end

        local _, _, hrp = getCharacterParts()

        local priorityList = {
            "Floating Crystal",
            "Large Red Crystal",
            "Large Ice Crystal",
            "Medium Red Crystal",
            "Medium Ice Crystal",
            "Small Red Crystal",
        }

        for _, targetName in ipairs(priorityList) do
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

		while State.autoMiner and mineral and mineral.Parent and tick() < timeout do
			local _, _, hrp = getCharacterParts()
			local targetPart = getMinerPart(mineral)

			if not targetPart then
				break
			end

			local dist = (targetPart.Position - hrp.Position).Magnitude
			if dist > 12 then
				moveToMiner(mineral)
			end

			mining()
			task.wait(0.15)

			if not isMinerAlive(mineral) then
				break
			end
		end
	end

	while true do
		if not State.autoMiner then
			task.wait(0.2)
			continue
		end

        for _, mineralName in ipairs({
            
            "Large Red Crystal",
            "Large Ice Crystal",
            "Medium Red Crystal",
            "Medium Ice Crystal",
            "Small Red Crystal",
        }) do
            if State.selectedMinerals and State.selectedMinerals[mineralName] then
                print("selected:", mineralName)
            end
        end
        
		local mineral = findMineral()

		if mineral then
			print("Found mineral:", mineral.Name)
			moveToMiner(mineral)
			mineTarget(mineral)
		else
			warn("No selected mineral found")
			task.wait(0.5)
		end
	end
end

return AutoMiner