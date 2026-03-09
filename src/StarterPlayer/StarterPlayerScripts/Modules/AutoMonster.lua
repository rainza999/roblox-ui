local AutoMonster = {}

function AutoMonster.run(State)
	print("AutoMonster started")

	local TweenService = game:GetService("TweenService")
	local Players = game:GetService("Players")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local VirtualInputManager = game:GetService("VirtualInputManager")

	local ControllerLock = getgenv().RobloxModules.ControllerLock
	local player = Players.LocalPlayer
	local currentMode = nil

	local function getCharacter()
		return player.Character or player.CharacterAdded:Wait()
	end

	local function getCharacterParts()
		local character = getCharacter()
		local humanoid = character:WaitForChild("Humanoid")
		local hrp = character:WaitForChild("HumanoidRootPart")
		return character, humanoid, hrp
	end

	local function hasEquippedWeapon()
		local character = getCharacter()
		return character:FindFirstChild("Weapon")
			or character:FindFirstChild("WeaponModel")
	end

	local function waitForEquippedObject(checkFn, timeout)
		local deadline = tick() + (timeout or 2)
		while tick() < deadline do
			local obj = checkFn()
			if obj then
				return obj
			end
			task.wait(0.05)
		end
		return nil
	end

	local function pressKey(keyCode)
		if not VirtualInputManager or not VirtualInputManager.SendKeyEvent then
			warn("[AutoMonster] VirtualInputManager.SendKeyEvent unavailable")
			return false
		end

		VirtualInputManager:SendKeyEvent(true, keyCode, false, game)
		task.wait(0.05)
		VirtualInputManager:SendKeyEvent(false, keyCode, false, game)
		task.wait(0.1)
		return true
	end

	local function setMode(mode)
		if currentMode == mode then
			return true
		end

		if mode == "combat" then
			local pressed = pressKey(Enum.KeyCode.Two)
			if not pressed then
				return false
			end

			local ok = waitForEquippedObject(hasEquippedWeapon, 2)
			if ok then
				currentMode = mode
				return true
			end
		end

		return false
	end

	local function attack()
		local ok = setMode("combat")
		if not ok then
			return
		end

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

	local function getSpawnLocationsByMap()
		local results = {}
		local rocks = workspace:FindFirstChild("Rocks")
		if not rocks then
			return results
		end

		for _, mapFolder in ipairs(rocks:GetChildren()) do
			if mapFolder:IsA("Folder") or mapFolder:IsA("Model") then
				local spawnLocations = {}
				for _, obj in ipairs(mapFolder:GetDescendants()) do
					if obj.Name == "SpawnLocation" and obj:IsA("BasePart") then
						table.insert(spawnLocations, obj)
					end
				end
				results[mapFolder.Name] = spawnLocations
			end
		end

		return results
	end

	local function getLocationPriorityList()
		return {
			"Island3CavePeakEnd",
			"Island3CavePeakBarrier",
			"Island3RedCave",
		}
	end

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
				or model:FindFirstChild("UpperTorso")
				or model:FindFirstChild("Torso")
				or model:FindFirstChildWhichIsA("BasePart")
		end

		return nil
	end

	local function isMonsterAlive(monster)
		if not monster or not monster.Parent then
			return false
		end

		local humanoid = monster:FindFirstChildOfClass("Humanoid")
		return humanoid and humanoid.Health > 0
	end

	local function isOwnCharacterModel(model)
		local character = player.Character
		return character and model == character
	end

	local function getBaseMonsterName(fullName)
		local base = tostring(fullName or "")
		base = base:gsub("%d+$", "")
		base = base:gsub("%s+$", "")
		return base
	end

	local function getNearestLocationNameFromPosition(position)
		local locationsByMap = getSpawnLocationsByMap()
		local bestLocationName = nil
		local bestDistance = math.huge

		for locationName, spawnLocations in pairs(locationsByMap) do
			for _, spawnLocation in ipairs(spawnLocations) do
				local dist = (spawnLocation.Position - position).Magnitude
				if dist < bestDistance then
					bestDistance = dist
					bestLocationName = locationName
				end
			end
		end

		return bestLocationName
	end

	local function getLocationPriorityIndex(locationName)
		for i, name in ipairs(getLocationPriorityList()) do
			if name == locationName then
				return i
			end
		end
		return math.huge
	end

	local function getMonsterPriorityIndex(monsterBaseName)
		for i, name in ipairs(State.monsterPriority or {}) do
			if name == monsterBaseName then
				return i
			end
		end
		return math.huge
	end

	local function findPriorityMonster(maxDistance)
		local living = workspace:FindFirstChild("Living")
		if not living then
			return nil
		end

		local _, _, hrp = getCharacterParts()
		local bestMonster = nil
		local bestLocPriority = math.huge
		local bestMonsterPriority = math.huge
		local bestDistance = math.huge

		for _, mob in ipairs(living:GetChildren()) do
			if mob:IsA("Model") and not isOwnCharacterModel(mob) and isMonsterAlive(mob) then
				local part = getMonsterPart(mob)
				if part then
					local dist = (part.Position - hrp.Position).Magnitude
					if dist <= (maxDistance or 35) then
						local baseName = getBaseMonsterName(mob.Name)

						if State.selectedMonsters and State.selectedMonsters[baseName] then
							local locationName = getNearestLocationNameFromPosition(part.Position)

							if locationName and State.selectedLocations and State.selectedLocations[locationName] then
								local locPriority = getLocationPriorityIndex(locationName)
								local mobPriority = getMonsterPriorityIndex(baseName)

								local better = false
								if locPriority < bestLocPriority then
									better = true
								elseif locPriority == bestLocPriority then
									if mobPriority < bestMonsterPriority then
										better = true
									elseif mobPriority == bestMonsterPriority and dist < bestDistance then
										better = true
									end
								end

								if better then
									bestMonster = mob
									bestLocPriority = locPriority
									bestMonsterPriority = mobPriority
									bestDistance = dist
								end
							end
						end
					end
				end
			end
		end

		return bestMonster
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

		while tween.PlaybackState == Enum.PlaybackState.Playing do
			if ControllerLock.isOwnedByOther(State, "AutoMonster") then
				tween:Cancel()
				return false
			end
			task.wait(0.05)
		end

		return true
	end

	local function faceTargetPart(targetPart)
		local _, _, hrp = getCharacterParts()
		if not targetPart then
			return false
		end

		local targetPos = targetPart.Position
		local myPos = hrp.Position
		local lookAt = Vector3.new(targetPos.X, myPos.Y, targetPos.Z)
		hrp.CFrame = CFrame.lookAt(myPos, lookAt)
		return true
	end

	local function attackMonster(monster)
		local timeout = tick() + 12

		while getgenv().RobloxUIRunning and monster and monster.Parent and tick() < timeout do
			if ControllerLock.isOwnedByOther(State, "AutoMonster") then
				return false
			end

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
                local moved = moveToTargetPart(part, 4)
                if not moved then
                    return false
                end
            end

            if not part or not part.Parent then
                return true
            end

            faceTargetPart(part)
            attack()
            task.wait(0.12)
		end

		return false
	end

	while getgenv().RobloxUIRunning do
		task.wait(0.1)

		if not State.autoMonsterFarm then
			continue
		end

		if not ControllerLock.tryAcquire(State, "AutoMonster", "monster") then
			continue
		end

		local target = findPriorityMonster(35)
		if not target then
			ControllerLock.release(State, "AutoMonster")
			task.wait(0.2)
			continue
		end

		print("[AutoMonster] Target:", target.Name)
		attackMonster(target)
		ControllerLock.release(State, "AutoMonster")
	end
end

return AutoMonster