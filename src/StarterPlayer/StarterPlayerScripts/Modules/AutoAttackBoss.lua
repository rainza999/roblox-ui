local AutoAttackBoss = {}

function AutoAttackBoss.run(State)
	print("AutoAttackBoss started222222")

	assert(State, "AutoAttackBoss.run(State) missing State")

	State.bossInProgress = State.bossInProgress or false
	State.bossPriorityActive = State.bossPriorityActive or false
	State.bossNextRunAt = State.bossNextRunAt or 0
	State.autoNpcBusy = State.autoNpcBusy or false
	State.bossImmediateRun = State.bossImmediateRun == nil and true or State.bossImmediateRun
	State.lastDetectedWorld = State.lastDetectedWorld or nil
	State.lastBossScheduleWorld = State.lastBossScheduleWorld or nil

	local TweenService = game:GetService("TweenService")
	local Players = game:GetService("Players")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local VirtualInputManager = game:GetService("VirtualInputManager")
	local player = Players.LocalPlayer

	local WORLD_BOSS_CONFIG = {
		world3 = {
			name = "world3",
			bossPattern = "^Golem%d+$", -- เปลี่ยนเป็นชื่อบอสจริง
			scheduleType = "halfHourOpen15",
			prepareBeforeBoss = 8,
		},
		world4 = {
			name = "world4",
			bossPattern = "^Asura's Incarnate%d+$",
			scheduleType = "every5",
			prepareBeforeBoss = 8,
		},
	}

	local function normalizeName(name)
		name = tostring(name or "")
		name = string.lower(name)
		name = name:gsub("%d+$", "")
		name = name:gsub("^%s+", "")
		name = name:gsub("%s+$", "")
		return name
	end

	local function hasAliveMonster(monsterName)
		local living = workspace:FindFirstChild("Living")
		if not living then
			return false
		end

		local target = normalizeName(monsterName)

		for _, mob in ipairs(living:GetChildren()) do
			if mob:IsA("Model") and normalizeName(mob.Name) == target then
				local hum = mob:FindFirstChildOfClass("Humanoid") or mob:FindFirstChildWhichIsA("Humanoid", true)
				if not hum or hum.Health > 0 then
					return true
				end
			end
		end

		return false
	end

	local function hasAliveMineral(mineralName)
		local rocks = workspace:FindFirstChild("Rocks")
		if not rocks then
			return false
		end

		local target = normalizeName(mineralName)

		for _, mapFolder in ipairs(rocks:GetChildren()) do
			for _, obj in ipairs(mapFolder:GetDescendants()) do
				if normalizeName(obj.Name) == target then
					local hpAttr = obj:GetAttribute("Health")
					if type(hpAttr) == "number" then
						if hpAttr > 0 then
							return true
						end
					else
						local hp = obj:FindFirstChild("Health")
						if hp and (hp:IsA("NumberValue") or hp:IsA("IntValue")) then
							if hp.Value > 0 then
								return true
							end
						else
							return true
						end
					end
				end
			end
		end

		return false
	end

	local function detectCurrentWorldName()
		local hasSmallIceCrystal = hasAliveMineral("Small Ice Crystal")
		local hasCrystalSpider = hasAliveMonster("Crystal Spider")

		if hasSmallIceCrystal and hasCrystalSpider then
			return "world3"
		end

		local hasGlowyRock = hasAliveMineral("Glowy Rock")
		local hasBruteOni = hasAliveMonster("Brute Oni")

		if hasGlowyRock and hasBruteOni then
			return "world4"
		end

		return "unknown"
	end

	local function getCurrentWorldConfig()
		local worldName = detectCurrentWorldName()

		if worldName ~= "unknown" then
			State.lastDetectedWorld = worldName
		end

		local finalWorld = worldName ~= "unknown" and worldName or State.lastDetectedWorld
		return WORLD_BOSS_CONFIG[finalWorld], finalWorld or "unknown"
	end

	local function getNext5MinuteTimestamp()
		local now = os.time()
		return now - (now % 300) + 300
	end

	local function isInHalfHourOpen15Window(now)
		now = now or os.time()
		local t = os.date("*t", now)
		return (t.min >= 0 and t.min < 15) or (t.min >= 30 and t.min < 45)
	end

	local function getHalfHourWindowStart(now)
		now = now or os.time()
		local t = os.date("*t", now)
		local hourStart = now - (t.min * 60) - t.sec

		if t.min < 15 then
			return hourStart -- xx:00
		elseif t.min < 30 then
			return hourStart + 1800 -- next is xx:30
		elseif t.min < 45 then
			return hourStart + 1800 -- xx:30
		else
			return hourStart + 3600 -- next is next hour :00
		end
	end

	local function getCurrentOrNextBossTimestampByWorld(worldCfg, now)
		now = now or os.time()

		if not worldCfg then
			return getNext5MinuteTimestamp()
		end

		if worldCfg.scheduleType == "every5" then
			return getNext5MinuteTimestamp()
		end

		if worldCfg.scheduleType == "halfHourOpen15" then
			return getCurrentOrNextHalfHourWindowTimestamp(now)
		end

		return getNext5MinuteTimestamp()
	end

	local function getNextBossTimestampAfterFinish(worldCfg, now)
		now = now or os.time()

		if not worldCfg then
			return getNext5MinuteTimestamp()
		end

		if worldCfg.scheduleType == "every5" then
			return getNext5MinuteTimestamp()
		end

		if worldCfg.scheduleType == "halfHourOpen15" then
			local t = os.date("*t", now)
			local hourStart = now - (t.min * 60) - t.sec

			if t.min < 15 then
				return hourStart + 1800 -- xx:30
			elseif t.min < 30 then
				return hourStart + 1800 -- xx:30
			elseif t.min < 45 then
				return hourStart + 3600 -- next hour :00
			else
				return hourStart + 3600 -- next hour :00
			end
		end

		return getNext5MinuteTimestamp()
	end

	local function getCharacter()
		return player.Character or player.CharacterAdded:Wait()
	end

	local function getCharacterParts()
		local character = player.Character or player.CharacterAdded:Wait()
		local humanoid = character:WaitForChild("Humanoid")
		local hrp = character:WaitForChild("HumanoidRootPart")
		return character, humanoid, hrp
	end

	local function clearBossFlags()
		State.autoNpcBusy = false
		State.bossInProgress = false
		State.bossPriorityActive = false
	end

	local function waitAfterBossFinish(seconds)
		seconds = seconds or 7

		local untilTime = tick() + seconds
		State.bossInProgress = false
		State.bossPriorityActive = true
		State.autoNpcBusy = true

		print(string.format("Waiting %.1fs after boss finish before releasing control...", seconds))

		while getgenv().RobloxUIRunning and tick() < untilTime do
			if not State.autoBoss then
				break
			end
			task.wait(0.2)
		end
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

	local function debugCreateParty()
		local createParty = workspace:FindFirstChild("CreateParty", true)
		if not createParty then
			warn("[AutoAttackBoss] CreateParty not found")
			return
		end

		print("===== CreateParty Descendants =====")
		for _, obj in ipairs(createParty:GetDescendants()) do
			if obj:IsA("BasePart") or obj:IsA("Model") or obj:IsA("Folder") then
				print(obj:GetFullName(), "|", obj.ClassName)
			end
		end
	end

	local function findCreatePartyStuff()
		-- world4 style
		local createParty = workspace:FindFirstChild("CreateParty", true)

		if createParty then
			local prompt = createParty:FindFirstChildWhichIsA("ProximityPrompt", true)
			local part = createParty:IsA("BasePart") and createParty or createParty:FindFirstChildWhichIsA("BasePart", true)

			print("[AutoAttackBoss] Using CreateParty path:", createParty:GetFullName())

			return createParty, nil, nil, part
		end


		-- world3 style
		local assets = workspace:FindFirstChild("Assets")
		if assets then
			local gate = assets:FindFirstChild("Gate")
			if gate then
				local bossDoor = gate:FindFirstChild("bossDoor")

				if bossDoor then
					local part = bossDoor:IsA("BasePart") and bossDoor or bossDoor:FindFirstChildWhichIsA("BasePart", true)

					print("[AutoAttackBoss] Using Assets.Gate.bossDoor path:", bossDoor:GetFullName())

					return bossDoor, gate, bossDoor, part
				end
			end
		end

		warn("[AutoAttackBoss] boss door not found")
		return nil, nil, nil, nil
	end

	local function waitForBoss(living, pattern, timeout)
		local start = tick()
		timeout = timeout or 30

		while getgenv().RobloxUIRunning and tick() - start < timeout do
			if State and not State.autoBoss then
				return nil
			end

			for _, model in ipairs(living:GetChildren()) do
				if model.Name:match(pattern) then
					local bossHumanoid = model:FindFirstChildOfClass("Humanoid")
					local bossHrp = model:FindFirstChild("HumanoidRootPart")
					if bossHumanoid and bossHrp and bossHumanoid.Health > 0 then
						return model
					end
				end
			end

			task.wait(0.2)
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
		
	local function ensureWeaponEquipped()
		local already = hasEquippedWeapon()
		if already then
			return true
		end

		-- ลอง invoke server ก่อน
		local ok, err = pcall(function()
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

		if not ok then
			warn("[AutoAttackBoss] Equip via ToolActivated failed:", err)
		end

		local equipped = waitForEquippedObject(hasEquippedWeapon, 2)
		if equipped then
			print("[AutoAttackBoss] Weapon equipped via ToolActivated:", equipped.Name)
			return true
		end

		-- ถ้ายังไม่ขึ้น ค่อย fallback ไปกดปุ่ม 2
		local pressed = pressKey(Enum.KeyCode.Two)
		if not pressed then
			warn("[AutoAttackBoss] Failed to press key 2")
			return false
		end

		equipped = waitForEquippedObject(hasEquippedWeapon, 2)
		if equipped then
			print("[AutoAttackBoss] Weapon equipped via key 2:", equipped.Name)
			return true
		end

		warn("[AutoAttackBoss] Weapon not found after ToolActivated and key 2")
		return false
	end

	local lastAttackAt = 0
	local ATTACK_COOLDOWN = 0.28

	local function attack()
		if tick() - lastAttackAt < ATTACK_COOLDOWN then
			return false
		end
		lastAttackAt = tick()

		local ok, err = pcall(function()
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

		if not ok then
			warn("[AutoAttackBoss] Attack failed:", err)
			return false
		end

		return true
	end

	local function followBoss(bossModel)
		local _, humanoid, hrp = getCharacterParts()
		noclip(true)

		ensureWeaponEquipped()

		while getgenv().RobloxUIRunning and bossModel and bossModel.Parent do
			if State and not State.autoBoss then
				noclip(false)
				return false
			end

			local bossHumanoid = bossModel:FindFirstChildOfClass("Humanoid")
			local bossHrp = bossModel:FindFirstChild("HumanoidRootPart")

			if not bossHumanoid or not bossHrp then
				warn("Boss missing parts")
				noclip(false)
				return false
			end

			if bossHumanoid.Health <= 0 then
				print("Boss defeated!")
				noclip(false)
				return true
			end

			local dist = (bossHrp.Position - hrp.Position).Magnitude
			if dist > 6 then
				humanoid:MoveTo(bossHrp.Position)
			end

			local look = Vector3.new(bossHrp.Position.X, hrp.Position.Y, bossHrp.Position.Z)
			hrp.CFrame = CFrame.lookAt(hrp.Position, look)

			if not hasEquippedWeapon() then
				local equipped = ensureWeaponEquipped()
				if not equipped then
					task.wait(0.2)
					continue
				end
			end

			attack()
			task.wait(0.2)

			local currentChar = player.Character
			if not currentChar or humanoid.Health <= 0 then
				_, humanoid, hrp = getCharacterParts()
			end
		end

		noclip(false)
		return false
	end

	local function runBossRound()
		State.bossInProgress = true
		State.bossPriorityActive = true
		State.autoNpcBusy = true

		local worldCfg, worldName = getCurrentWorldConfig()

		if not worldCfg then
			warn("[AutoAttackBoss] Unknown world, cannot start boss")
			clearBossFlags()
			State.bossNextRunAt = getNext5MinuteTimestamp()
			return false
		end

		print("[AutoAttackBoss] Detected world:", worldName)

		local startTime = os.time()
		print("เริ่มรอบบอส:", os.date("%H:%M:%S", startTime))

		local _, _, hrp = getCharacterParts()
		debugCreateParty()
		local createParty, _, _, doorPart = findCreatePartyStuff()

		if not createParty or not doorPart then
			warn("createParty or doorPart not found")
			clearBossFlags()
			State.bossNextRunAt = getCurrentOrNextBossTimestampByWorld(worldCfg, os.time())
			return false
		end

		-- local cf = doorPart.CFrame
		local movePos = doorPart.Position + Vector3.new(0,2,4)
		local cf = CFrame.new(movePos)
		local dist = (cf.Position - hrp.Position).Magnitude
		noclip(true)

		local tween = TweenService:Create(hrp, TweenInfo.new(math.max(dist / 60, 0.1)), {CFrame = cf})
		tween:Play()

		while tween.PlaybackState == Enum.PlaybackState.Playing do
			if not getgenv().RobloxUIRunning or not State.autoBoss then
				tween:Cancel()
				noclip(false)
				clearBossFlags()
				return false
			end
			task.wait()
		end

		noclip(false)
		task.wait(0.5)

		local prompt = createParty:FindFirstChildWhichIsA("ProximityPrompt", true)
		if prompt then
			pcall(function()
				fireproximityprompt(prompt)
			end)
		else
			warn("ProximityPrompt not found")
		end

		task.wait(1)

		pcall(function()
			ReplicatedStorage
				:WaitForChild("Shared")
				:WaitForChild("Packages")
				:WaitForChild("Knit")
				:WaitForChild("Services")
				:WaitForChild("PartyService")
				:WaitForChild("RF")
				:WaitForChild("Activate")
				:InvokeServer()
		end)

		local success = false
		local living = workspace:FindFirstChild("Living")

		if living then
			local bossModel = waitForBoss(living, worldCfg.bossPattern, 30)

			if bossModel then
				print("Found boss:", bossModel.Name)
				success = followBoss(bossModel)
			else
				warn("Boss not found within timeout")
			end
		else
			warn("Living folder not found")
		end

		local finishTime = os.time()
		print("จบรอบบอส:", os.date("%H:%M:%S", finishTime))

		-- รอให้ตัวละครกลับแมพ/โหลดฉากก่อน
		waitAfterBossFinish(7) -- ปรับเป็น 5, 7, 10 ได้
		-- สำคัญ: ปล่อย flag ทันทีหลังจบรอบ เพื่อให้ AutoMiner กลับไปทำงาน
		clearBossFlags()

		State.bossNextRunAt = getNextBossTimestampAfterFinish(worldCfg, os.time())
		print("[AutoAttackBoss] next boss for", worldName, "=", os.date("%H:%M:%S", State.bossNextRunAt))

		return success
	end


	while getgenv().RobloxUIRunning do
		if not State.autoBoss then
			clearBossFlags()
			State.bossNextRunAt = 0
			State.bossImmediateRun = true
			task.wait(0.2)
			continue
		end

		local now = os.time()

		-- รอบแรก เปิดแล้วไปเลย
		if State.bossImmediateRun then
			local worldCfg, worldName = getCurrentWorldConfig()
			State.bossImmediateRun = false

			if State.lastBossScheduleWorld ~= worldName then
				State.lastBossScheduleWorld = worldName
				State.bossNextRunAt = 0
			end


			if not worldCfg then
				warn("[AutoAttackBoss] Unknown world on immediate run")
				task.wait(0.2)
				continue
			end

			if worldCfg.scheduleType == "halfHourOpen15" then
				if isInHalfHourOpen15Window(os.time()) then
					print("Immediate first boss run:", worldName)
					runBossRound()
				else
					State.bossNextRunAt = getCurrentOrNextBossTimestampByWorld(worldCfg, os.time())
					print("[AutoAttackBoss] " .. worldName .. " not in open window, next run at:", os.date("%H:%M:%S", State.bossNextRunAt))
				end
			else
				print("Immediate first boss run:", worldName)
				runBossRound()
			end

			task.wait(0.2)
			continue
		end

		local worldCfg, worldName = getCurrentWorldConfig()

		if State.lastBossScheduleWorld ~= worldName then
			State.lastBossScheduleWorld = worldName
			State.bossNextRunAt = 0
		end

		if not worldCfg then
			State.bossPriorityActive = false
			task.wait(0.5)
			continue
		end

		local PREPARE_BEFORE_BOSS = worldCfg.prepareBeforeBoss or 8

		if State.bossNextRunAt == 0 then
			State.bossNextRunAt = getCurrentOrNextBossTimestampByWorld(worldCfg, os.time())
		end

		now = os.time()

		if now >= State.bossNextRunAt then
			if worldCfg.scheduleType == "halfHourOpen15" and not isInHalfHourOpen15Window(now) then
				State.bossNextRunAt = getCurrentOrNextBossTimestampByWorld(worldCfg, now)
				task.wait(0.2)
				continue
			end

			runBossRound()
			task.wait(0.2)
			continue
		end
		if now >= (State.bossNextRunAt - PREPARE_BEFORE_BOSS) then
			if not State.bossPriorityActive then
				print("Boss priority active:", os.date("%H:%M:%S", now), "next =", os.date("%H:%M:%S", State.bossNextRunAt), "world =", worldName)
			end
			State.bossPriorityActive = true
		else
			State.bossPriorityActive = false
		end

		task.wait(0.2)
	end

	clearBossFlags()
	print("AutoAttackBoss stopped")
	return State
end

return AutoAttackBoss