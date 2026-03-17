local ControllerLock = getgenv().RobloxModules.ControllerLock
local AutoMiner = {}

function AutoMiner.run(State)
	print("AutoMiner started")

	local TweenService = game:GetService("TweenService")
	local Players = game:GetService("Players")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")

	local player = Players.LocalPlayer

    local VirtualInputManager = game:GetService("VirtualInputManager")

	local currentMode = nil

    local getCharacter
    local hasEquippedMiningTool
    local hasEquippedWeapon
    local waitForEquippedObject

    getCharacter = function()
		return player.Character or player.CharacterAdded:Wait()
	end

    -- hasEquippedMiningTool = function()
    --     local character = getCharacter()

    --     return character:FindFirstChild("PickAxe")
    --         or character:FindFirstChild("PickaxeModel")
    -- end

	hasEquippedMiningTool = function()
		return true
	end
    hasEquippedWeapon = function()
        local character = getCharacter()

        return character:FindFirstChild("Weapon")
            or character:FindFirstChild("WeaponModel")
    end

    waitForEquippedObject = function(checkFn, timeout)
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
            warn("[AutoMiner] VirtualInputManager.SendKeyEvent unavailable")
            return false
        end

        VirtualInputManager:SendKeyEvent(true, keyCode, false, game)
        task.wait(0.05)
        VirtualInputManager:SendKeyEvent(false, keyCode, false, game)
        task.wait(0.1)
        return true
    end

    -------------------------------------------------
    -- Noclip
    -------------------------------------------------

    local function noclip(state)
        local char = player.Character
        if not char then return end

        for _, v in pairs(char:GetDescendants()) do
            if v:IsA("BasePart") then
                v.CanCollide = not state
            end
        end
    end


    local function setMode(mode)
        if currentMode == mode then
            return true
        end

        -- if mode == "mining" then
        --     print("[AutoMiner] Switch mode -> mining")

        --     local pressed = pressKey(Enum.KeyCode.One)
        --     if not pressed then
        --         warn("[AutoMiner] Failed to press key 1")
        --         return false
        --     end

        --     local ok = waitForEquippedObject(hasEquippedMiningTool, 2)
        --     if ok then
        --         currentMode = mode
        --         print("[AutoMiner] Mining tool equipped:", ok.Name)
        --         return true
        --     else
        --         warn("[AutoMiner] Mining tool not found after pressing 1")
        --         return false
        --     end

		if mode == "mining" then
			print("[AutoMiner] Switch mode -> mining")

			local pressed = pressKey(Enum.KeyCode.One)
			if not pressed then
				warn("[AutoMiner] Failed to press key 1")
				return false
			end

			currentMode = mode
			task.wait(0.2) -- เผื่อเวลา equip นิดนึง
			return true
        elseif mode == "combat" then
            print("[AutoMiner] Switch mode -> combat")

            local pressed = pressKey(Enum.KeyCode.Two)
            if not pressed then
                warn("[AutoMiner] Failed to press key 2")
                return false
            end
			currentMode = mode
			task.wait(0.2) -- เผื่อเวลา equip นิดนึง
			return true
            -- local ok = waitForEquippedObject(hasEquippedWeapon, 2)
            -- if ok then
            --     currentMode = mode
            --     print("[AutoMiner] Weapon equipped:", ok.Name)
            --     return true
            -- else
            --     warn("[AutoMiner] Weapon not found after pressing 2")
            --     return false
            -- end
        end

        return false
    end

	local skippedMinerals = {}
    local printedOreMinerals = {}

	local function getCharacterParts()
		local character = player.Character or player.CharacterAdded:Wait()
		local humanoid = character:WaitForChild("Humanoid")
		local hrp = character:WaitForChild("HumanoidRootPart")
		return character, humanoid, hrp
	end

    local function getGroundYNear(position, ignoreList)
        local rayParams = RaycastParams.new()
        rayParams.FilterType = Enum.RaycastFilterType.Blacklist
        rayParams.FilterDescendantsInstances = ignoreList or {}
        rayParams.IgnoreWater = true

        local origin = position + Vector3.new(0, 25, 0)
        local direction = Vector3.new(0, -200, 0)

        local result = workspace:Raycast(origin, direction, rayParams)
        if result then
            return result.Position.Y
        end

        return nil
    end

    local function getSafeStandPositionNearTarget(targetPart, stopDistance)
		local character, _, hrp = getCharacterParts()
		if not targetPart or not targetPart.Parent then
			return nil
		end

		local targetPos = targetPart.Position
		local myPos = hrp.Position

		local flatDir = Vector3.new(
			targetPos.X - myPos.X,
			0,
			targetPos.Z - myPos.Z
		)

		if flatDir.Magnitude <= 0.05 then
			flatDir = Vector3.new(0, 0, -1)
		else
			flatDir = flatDir.Unit
		end

		local desiredXZ = Vector3.new(
			targetPos.X - flatDir.X * (stopDistance or 4),
			0,
			targetPos.Z - flatDir.Z * (stopDistance or 4)
		)

		local groundY = getGroundYNear(
			Vector3.new(desiredXZ.X, math.max(targetPos.Y, myPos.Y) + 8, desiredXZ.Z),
			{character, targetPart.Parent}
		)

		local finalY = myPos.Y

		-- ยอม snap ลงพื้นเฉพาะกรณีต่างจากระดับเราไม่มาก
		if groundY and math.abs(groundY - myPos.Y) <= 4 then
			finalY = groundY + 3
		end

		-- ห้ามต่ำกว่าระดับเราเยอะเกิน
		if finalY < myPos.Y - 2 then
			finalY = myPos.Y
		end

		-- ห้ามสูง/ต่ำตาม target มากเกินไป
		if math.abs(finalY - myPos.Y) > 4 then
			finalY = myPos.Y
		end

		return Vector3.new(desiredXZ.X, finalY, desiredXZ.Z)
	end

    local function isPausedForAutoMiner()
        return ControllerLock.isOwnedByOther(State, "AutoMiner")
    end

	local function tryAcquireMove(reason)
		return ControllerLock.tryAcquire(State, "AutoMiner", reason)
	end

	local function releaseMove()
		ControllerLock.release(State, "AutoMiner")
	end

    local function isBossPriorityActive()
		if not State.autoBoss then
			return false
		end

		if State.bossInProgress then
			return true
		end

		if State.bossPriorityActive then
			return true
		end

		return false
	end

	local function mining()
		local ok = setMode("mining")
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
				:InvokeServer("Pickaxe")
		end)
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
					if obj.Name == "SpawnLocation" then
						table.insert(spawnLocations, obj)
					end
				end

				results[mapFolder.Name] = spawnLocations
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
            if model.PrimaryPart then
                return model.PrimaryPart
            end

            local preferredNames = {
                "HumanoidRootPart",
                "RootPart",
                "Main",
                "Hitbox",
                "Core"
            }

            for _, name in ipairs(preferredNames) do
                local found = model:FindFirstChild(name, true)
                if found and found:IsA("BasePart") then
                    return found
                end
            end

            local biggestPart = nil
            local biggestSize = 0
            for _, obj in ipairs(model:GetDescendants()) do
                if obj:IsA("BasePart") then
                    local sizeScore = obj.Size.X * obj.Size.Y * obj.Size.Z
                    if sizeScore > biggestSize then
                        biggestSize = sizeScore
                        biggestPart = obj
                    end
                end
            end

            return biggestPart
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

    local function getLocationPriorityList()
		return {
            "2s",
            "I4_HolyCave_03_1",
            "I4_HolyCave_03_2",
			"Island3CavePeakEnd",
			"Island3CavePeakBarrier",
			"Island3RedCave",
		}
	end

	local function getPriorityList()
		return {
            "Blossom Boulder",
		    "Glowy Rock",
			"Floating Crystal",
            "Heart Of The Island",
			"Large Red Crystal",
			"Large Ice Crystal",
			"Medium Red Crystal",
			"Medium Ice Crystal",
			"Small Red Crystal",
		}
	end

    local function getAllMineralTypes()
		return {
            "Blossom Boulder",
		    "Glowy Rock",
			"Floating Crystal",
            "Heart Of The Island",
			"Large Red Crystal",
			"Large Ice Crystal",
			"Medium Red Crystal",
			"Medium Ice Crystal",
			"Small Red Crystal",
		}
	end

	local function isTrashMineralType(mineralName)
		if State.selectedMinerals and State.selectedMinerals[mineralName] then
			return false
		end
		return true
	end

	local function getClearLimit(mineralName)
		if State.clearLimits and type(State.clearLimits[mineralName]) == "number" then
			return State.clearLimits[mineralName]
		end
		return 0
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
        for _, obj in ipairs(mineral:GetDescendants()) do
            if obj:IsA("Model") and obj.Name == "Ore" then
                local oreName = obj:GetAttribute("Ore")

                if oreName then
                    -- print("[AutoMiner] Ore spawned:", oreName)

                    if State.selectedOres and State.selectedOres[oreName] then
                        -- print("[AutoMiner] Ore matched:", oreName)
                        return true, oreName
                    else
                        -- print("[AutoMiner] Ore not selected:", oreName)
                    end
                end
            end
        end

        return false, nil
    end

    local function getOreSummary(mineral)
		local oreNames = {}
		local matchedNames = {}
		local total = 0

		if not mineral or not mineral.Parent then
			return 0, oreNames, false, matchedNames
		end

		for _, obj in ipairs(mineral:GetDescendants()) do
			if obj:IsA("Model") and obj.Name == "Ore" then
				local oreName = obj:GetAttribute("Ore")
				if oreName and oreName ~= "" then
					total += 1
					table.insert(oreNames, oreName)

					if State.selectedOres and State.selectedOres[oreName] then
						table.insert(matchedNames, oreName)
					end
				end
			end
		end

		local hasMatch = #matchedNames > 0
		return total, oreNames, hasMatch, matchedNames
	end

	local function printOreSummary(mineral)
        if printedOreMinerals[mineral] then
            return
        end

        printedOreMinerals[mineral] = true

        local total, oreNames, hasMatch, matchedNames = getOreSummary(mineral)

        if total <= 0 then
            print("[AutoMiner] 0 Ore")
            return
        end

        local oreText = table.concat(oreNames, ", ")
        local matchText = hasMatch and "YES" or "NO"

        print(string.format(
            "[AutoMiner] %d Ore (%s) | Match: %s",
            total,
            oreText,
            matchText
        ))
    end

    local lastOreSummaryText = ""

	local function printOreSummaryIfChanged(mineral)
		local total, oreNames, hasMatch = getOreSummary(mineral)

		local oreText = total > 0 and table.concat(oreNames, ", ") or ""
		local matchText = hasMatch and "YES" or "NO"
		local summary = string.format("%d|%s|%s", total, oreText, matchText)

		if summary == lastOreSummaryText then
			return
		end

		lastOreSummaryText = summary

		if total <= 0 then
			print("[AutoMiner] 0 Ore")
			return
		end

		print(string.format(
			"[AutoMiner] %d Ore (%s) | Match: %s",
			total,
			oreText,
			matchText
		))
	end

    local function shouldSkipMineralBeforeMove(mineral)
		if not hasAnySelectedOre() then
			return false
		end

		if not mineral or not mineral.Parent then
			return true
		end

		local oreModels = getOreModels(mineral)

		if #oreModels == 0 then
			-- print("[AutoMiner] Mineral has no ore yet -> allowed:", mineral.Name)
			return false
		end

		for _, oreModel in ipairs(oreModels) do
			local oreName = oreModel:GetAttribute("Ore")
			if oreName then
				-- print("[AutoMiner] Mineral has ore:", mineral.Name, "->", oreName)
			end

			if oreName and State.selectedOres and State.selectedOres[oreName] then
				-- print("[AutoMiner] Ore matched before move:", oreName)
				return false
			end
		end

		print("[AutoMiner] Skip mineral before move (wrong existing ore):", mineral.Name)
		return true
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

    local function moveToTargetPart(targetPart, stopDistance)
		if isPausedForAutoMiner() or isBossPriorityActive() then
			return false
		end

		if not targetPart or not targetPart.Parent then
			return false
		end

		if not tryAcquireMove("mining_move") then
			return false
		end

		local success = false
		local tween = nil

		local ok, err = pcall(function()
			local _, _, hrp = getCharacterParts()

			local targetPos = targetPart.Position
			local myPos = hrp.Position

			local flatDir = Vector3.new(
				targetPos.X - myPos.X,
				0,
				targetPos.Z - myPos.Z
			)

			if flatDir.Magnitude <= 0.05 then
				flatDir = Vector3.new(0, 0, -1)
			else
				flatDir = flatDir.Unit
			end

			local finalPos = Vector3.new(
				targetPos.X - flatDir.X * (stopDistance or 4),
				targetPos.Y,
				targetPos.Z - flatDir.Z * (stopDistance or 4)
			)

			noclip(true)

			local dist = (finalPos - hrp.Position).Magnitude
			local tweenTime = math.max(dist / 45, 0.15)

			tween = TweenService:Create(
				hrp,
				TweenInfo.new(tweenTime, Enum.EasingStyle.Linear),
				{CFrame = CFrame.new(finalPos)}
			)

			tween:Play()

			while tween.PlaybackState == Enum.PlaybackState.Playing do
				if isPausedForAutoMiner() or isBossPriorityActive() then
					tween:Cancel()
					return
				end

				if not targetPart or not targetPart.Parent then
					tween:Cancel()
					return
				end

				task.wait()
			end

			local _, _, hrp2 = getCharacterParts()
			success = (hrp2.Position - finalPos).Magnitude <= 6
		end)

		noclip(false)
		releaseMove()

		if not ok then
			warn("[AutoMiner] moveToTargetPart error:", err)
			return false
		end

		return success
	end

    local function faceTargetPart(targetPart)
        local character, humanoid, hrp = getCharacterParts()
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

    local function stickToTargetPart(targetPart, stickDistance)
		local _, _, hrp = getCharacterParts()
		if not targetPart or not targetPart.Parent then
			return false
		end

		local targetPos = targetPart.Position
		local myPos = hrp.Position
		local desiredDistance = stickDistance or 2.2

		local flatDir = Vector3.new(
			targetPos.X - myPos.X,
			0,
			targetPos.Z - myPos.Z
		)

		if flatDir.Magnitude <= 0.05 then
			faceTargetPart(targetPart)
			return true
		end

		flatDir = flatDir.Unit

		local desiredXZ = Vector3.new(
			targetPos.X - flatDir.X * desiredDistance,
			0,
			targetPos.Z - flatDir.Z * desiredDistance
		)

		-- สำคัญ: อย่าเด้ง Y ไปตามหัวแร่
		-- ให้ใช้ระดับเดิมของตัวเราเป็นหลัก
		local desiredPos = Vector3.new(
			desiredXZ.X,
			myPos.Y,
			desiredXZ.Z
		)

		-- ถ้าต่างกันเยอะเกิน ไม่ต้อง snap
		if math.abs(desiredPos.Y - myPos.Y) > 2 then
			faceTargetPart(targetPart)
			return false
		end

		-- ขยับเฉพาะกรณีใกล้ ๆ และขยับไม่มาก
		local moveDelta = (desiredPos - myPos).Magnitude
		if moveDelta > 3 then
			faceTargetPart(targetPart)
			return false
		end

		noclip(true)
		hrp.CFrame = CFrame.lookAt(
			desiredPos,
			Vector3.new(targetPos.X, desiredPos.Y, targetPos.Z)
		)
		noclip(false)

		return true
	end

    -------------------------------------------------
	-- Mineral Highlight
	-------------------------------------------------

	local previewHighlight = nil
	local activeHighlight = nil
	local currentPreviewMineral = nil
	local currentActiveMineral = nil

	local function clearHighlightInstance(h)
		if h then
			pcall(function()
				h:Destroy()
			end)
		end
	end

	local function makeHighlight(target, fillColor, outlineColor, name)
		if not target or not target.Parent then
			return nil
		end

		local h = Instance.new("Highlight")
		h.Name = name or "AutoMinerHighlight"
		h.Adornee = target
		h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		h.FillTransparency = 0.8
		h.OutlineTransparency = 0
		h.FillColor = fillColor
		h.OutlineColor = outlineColor
		h.Parent = game:GetService("CoreGui")
		return h
	end

	local function setPreviewMineral(mineral)
		if currentPreviewMineral == mineral and previewHighlight then
			return
		end

		clearHighlightInstance(previewHighlight)
		previewHighlight = nil
		currentPreviewMineral = nil

		if mineral and mineral.Parent then
			previewHighlight = makeHighlight(
				mineral,
				Color3.fromRGB(30, 144, 255),   -- fill ฟ้า
				Color3.fromRGB(0, 102, 255),    -- outline น้ำเงิน
				"AutoMinerPreviewHighlight"
			)
			currentPreviewMineral = mineral
		end
	end

	local function setActiveMineral(mineral)
		if currentActiveMineral == mineral and activeHighlight then
			return
		end

		clearHighlightInstance(activeHighlight)
		activeHighlight = nil
		currentActiveMineral = nil

		if mineral and mineral.Parent then
			activeHighlight = makeHighlight(
				mineral,
				Color3.fromRGB(0, 255, 120),    -- fill เขียว
				Color3.fromRGB(0, 200, 0),      -- outline เขียวเข้ม
				"AutoMinerActiveHighlight"
			)
			currentActiveMineral = mineral
		end
	end

	local function clearPreviewMineral()
		clearHighlightInstance(previewHighlight)
		previewHighlight = nil
		currentPreviewMineral = nil
	end

	local function clearActiveMineral()
		clearHighlightInstance(activeHighlight)
		activeHighlight = nil
		currentActiveMineral = nil
	end

	local function attackMonster(monster)
        local timeout = tick() + 12

        while getgenv().RobloxUIRunning and State.autoMiner and monster and monster.Parent and tick() < timeout do
            if isPausedForAutoMiner() then
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

                -- move เสร็จแล้วดึง part ใหม่ เผื่อมอนขยับ
                part = getMonsterPart(monster)
                if not part then
                    return true
                end
            end

            if isPausedForAutoMiner() then
                return false
            end

            -- บังคับหันหน้าก่อนตีทุกครั้ง
            faceTargetPart(part)

            -- เผื่อเน็ต/physics แกว่งนิดนึง
            task.wait(0.03)

            -- หันซ้ำอีกที กันมอนเดินระหว่างเฟรม
            part = getMonsterPart(monster)
            if not part then
                return true
            end
            faceTargetPart(part)

            attack()
            task.wait(0.12)

            if not isMonsterAlive(monster) then
                return true
            end

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
        if isPausedForAutoMiner() then
            return false
        end

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

    local function countMineralsInLocation(locationName)
		local locationsByMap = getSpawnLocationsByMap()
		local spawnLocations = locationsByMap[locationName]
		local counts = {}

		for _, mineralName in ipairs(getAllMineralTypes()) do
			counts[mineralName] = 0
		end

		if not spawnLocations then
			return counts
		end

		for _, spawnLocation in ipairs(spawnLocations) do
			for _, child in ipairs(spawnLocation:GetChildren()) do
				if counts[child.Name] ~= nil and isMinerAlive(child) and not isMineralSkipped(child) then
					counts[child.Name] += 1
				end
			end
		end

		return counts
	end

    local function findClearTarget()
		if not State.autoClearTrash then
			return nil, nil, nil
		end

		local locationsByMap = getSpawnLocationsByMap()
		local _, _, hrp = getCharacterParts()

		for _, locationName in ipairs(getLocationPriorityList()) do
			if State.selectedLocations and State.selectedLocations[locationName] then
				local spawnLocations = locationsByMap[locationName]
				if spawnLocations and #spawnLocations > 0 then
					local counts = countMineralsInLocation(locationName)

					for _, mineralName in ipairs(getAllMineralTypes()) do
						if isTrashMineralType(mineralName) then
							local currentCount = counts[mineralName] or 0
							local limit = getClearLimit(mineralName)

							if currentCount > limit then
								local nearestMiner = nil
								local nearestDistance = math.huge

								for _, spawnLocation in ipairs(spawnLocations) do
									for _, child in ipairs(spawnLocation:GetChildren()) do
										if child.Name == mineralName
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
									return nearestMiner, locationName, mineralName
								end
							end
						end
					end
				end
			end
		end

		return nil, nil, nil
	end

    local function findMineral()
		local locationsByMap = getSpawnLocationsByMap()
		local _, _, hrp = getCharacterParts()

		local hasAnySelectedLocation = false
		if State.selectedLocations then
			for _, selected in pairs(State.selectedLocations) do
				if selected then
					hasAnySelectedLocation = true
					break
				end
			end
		end

		if not hasAnySelectedLocation then
			warn("No selected location")
			return nil
		end

		for _, locationName in ipairs(getLocationPriorityList()) do
			if State.selectedLocations and State.selectedLocations[locationName] then
				local spawnLocations = locationsByMap[locationName]

				if spawnLocations and #spawnLocations > 0 then
					for _, targetName in ipairs(getPriorityList()) do
						if State.selectedMinerals and State.selectedMinerals[targetName] then
							local nearestMiner = nil
							local nearestDistance = math.huge

							for _, spawnLocation in ipairs(spawnLocations) do
								for _, child in ipairs(spawnLocation:GetChildren()) do
                                    if child.Name == targetName
										and isMinerAlive(child)
										and not isMineralSkipped(child)
										and not shouldSkipMineralBeforeMove(child) then
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
								return nearestMiner, locationName
							end
						end
					end
				end
			end
		end

		return nil, nil
	end

	local function moveToMiner(mineral)
		local targetPart = getMinerPart(mineral)
		if not targetPart then
			return false
		end

		local _, _, hrp = getCharacterParts()
		local dist = (targetPart.Position - hrp.Position).Magnitude

		if dist <= 6 then
			faceTargetPart(targetPart)
			return true
		end

		local moved = moveToTargetPart(targetPart, 4)
		if moved then
			faceTargetPart(targetPart)
		end
		return moved
	end

	local function mineTarget(mineral)
		local timeout = tick() + 60
		local oreMode = hasAnySelectedOre()
		local foundOreOnce = false
		local lastHp = getMinerHealth(mineral)

		while getgenv().RobloxUIRunning and State.autoMiner and mineral and mineral.Parent and tick() < timeout do
            if isPausedForAutoMiner() or isBossPriorityActive() then
                return false
            end
            -- ถ้ามีมอนเข้ามาใกล้ ให้ไปจัดมอนก่อน แล้วค่อยกลับมา
			handleNearbyMonster()

			if not isMinerAlive(mineral) then
                noclip(false)
				return true
			end

			local _, _, hrp = getCharacterParts()
			local targetPart = getMinerPart(mineral)

			if not targetPart then
				return true
			end

            local dist = (targetPart.Position - hrp.Position).Magnitude

			-- ถ้าไกลมากค่อย tween เข้าไปก่อน
			if dist > 6 then
                local moved = moveToMiner(mineral)
                if not moved then
                    noclip(false)
                    return false
                end

                targetPart = getMinerPart(mineral)
                if not targetPart then
                    noclip(false)
                    return true
                end
            end

			-- ระหว่างทุบให้เกาะแร่ตลอด
            -- stickToTargetPart(targetPart, 2.2)
            faceTargetPart(targetPart)
            mining()
            task.wait(0.12)
            if oreMode then
				local oreSpawned = hasAnyOreSpawned(mineral)

				if oreSpawned then
					foundOreOnce = true

					printOreSummary(mineral)

					local matched = hasMatchingSelectedOre(mineral)
					if not matched then
						return false
					end
				end
			end

            if isPausedForAutoMiner() then
				return false
			end

            local realDist = (targetPart.Position - hrp.Position).Magnitude

			if realDist > 8 then
				local moved = moveToMiner(mineral)
				if not moved then
					noclip(false)
					return false
				end
				task.wait(0.05)
				continue
			elseif realDist > 4.5 then
				faceTargetPart(targetPart)
			end

			mining()
			task.wait(0.12)

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
                noclip(false)
				return true
			end

			if oreMode and foundOreOnce then
				printOreSummary(mineral)

				local matched = hasMatchingSelectedOre(mineral)
				if not matched then
					return false
				end
			end
		end
        noclip(false)
		return false
	end

    local function clearTrashMineral(mineral, locationName, mineralName)
		if not mineral then
			return false
		end

		State.isClearing = true
		State.clearStatusText = string.format("Clearing %s @ %s", mineralName or mineral.Name, locationName or "?")

		print("[AutoMiner] Clear target:", mineralName or mineral.Name, "| Location:", locationName)

		moveToMiner(mineral)

        clearPreviewMineral()
		setActiveMineral(mineral)

		local timeout = tick() + 20
		while getgenv().RobloxUIRunning and State.autoClearTrash and mineral and mineral.Parent and tick() < timeout do
			
            if isPausedForAutoMiner() or isBossPriorityActive() then
                State.isClearing = false
                State.clearStatusText = ""
                return false
            end
            handleNearbyMonster()

			if not isMinerAlive(mineral) then
				print("[AutoMiner] Clear finished:", mineralName or mineral.Name)
				State.isClearing = false
				State.clearStatusText = ""
                noclip(false)
				return true
			end

			local targetPart = getMinerPart(mineral)
			if not targetPart then
				State.isClearing = false
				State.clearStatusText = ""
				return true
			end

			local _, _, hrp = getCharacterParts()
			local dist = (targetPart.Position - hrp.Position).Magnitude

			if dist > 12 then
				moveToMiner(mineral)
				targetPart = getMinerPart(mineral)
				if not targetPart then
					State.isClearing = false
					State.clearStatusText = ""
					return true
				end
			else
				faceTargetPart(targetPart)
			end

            if isPausedForAutoMiner() then
				State.isClearing = false
				State.clearStatusText = ""
				return false
			end

            stickToTargetPart(targetPart, 2.2)
			faceTargetPart(targetPart)
			mining()
			task.wait(0.15)
		end

		State.isClearing = false
		State.clearStatusText = ""
		return false
	end

	while getgenv().RobloxUIRunning do

        if isPausedForAutoMiner() then
            task.wait(0.1)
            continue
        end

        if isBossPriorityActive() then
            clearPreviewMineral()
            clearActiveMineral()
            noclip(false)
            task.wait(0.1)
            continue
        end

		if not State.autoMiner then
			task.wait(0.2)
			continue
		end

        local currentOwner = ControllerLock.getOwner(State)
		if currentOwner and currentOwner ~= "AutoMiner" then
			task.wait(0.1)
			continue
		end

		cleanupSkippedMinerals()

		-- ก่อนหาแร่ใหม่ เช็คมอนรอบตัวก่อน
		if handleNearbyMonster() then
			task.wait(0.1)
		end

        local clearMineral, clearLocationName, clearMineralName = findClearTarget()
		if clearMineral then
			clearTrashMineral(clearMineral, clearLocationName, clearMineralName)
            
			task.wait(0.1)
			continue
		end

		local mineral, locationName = findMineral()

        if mineral then
			print("[AutoMiner] Found mineral:", mineral.Name, "| Location:", locationName)

			setPreviewMineral(mineral)

			print("[AutoMiner] Start mining:", mineral.Name)
            printedOreMinerals[mineral] = nil

            local moved = moveToMiner(mineral)
            if not moved then
                print("[AutoMiner] Failed to move to mineral:", mineral.Name)
                markMineralSkipped(mineral, 5)
                
                clearPreviewMineral()
                clearActiveMineral()
                task.wait(0.2)
                continue
            end

            clearPreviewMineral()
            setActiveMineral(mineral)

            lastOreSummaryText = ""
            local finished = mineTarget(mineral)

            

            clearActiveMineral()
			clearPreviewMineral()

            if isPausedForAutoMiner() then
                task.wait(0.1)
            elseif finished == false then
                print("[AutoMiner] Skip mineral (wrong ore or timeout):", mineral.Name)
                markMineralSkipped(mineral, 8)
                task.wait(0.2)
            else
                print("[AutoMiner] Finished mining:", mineral.Name)
                task.wait(0.2)
            end
		else
			warn("No selected mineral found v.1")
			task.wait(0.5)
		end
	end
end

return AutoMiner