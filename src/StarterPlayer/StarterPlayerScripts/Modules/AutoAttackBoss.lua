local AutoAttackBoss = {}

function AutoAttackBoss.run(State)
	print("AutoAttackBoss started")

	assert(State, "AutoAttackBoss.run(State) missing State")

	State.bossInProgress = State.bossInProgress or false
	State.bossPriorityActive = State.bossPriorityActive or false
	State.bossNextRunAt = State.bossNextRunAt or 0
	State.autoNpcBusy = State.autoNpcBusy or false
	State.bossImmediateRun = State.bossImmediateRun == nil and true or State.bossImmediateRun

	local TweenService = game:GetService("TweenService")
	local Players = game:GetService("Players")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")

	local player = Players.LocalPlayer

	local function getCharacter()
		return player.Character or player.CharacterAdded:Wait()
	end

	local function getCharacterParts()
		local character = player.Character or player.CharacterAdded:Wait()
		local humanoid = character:WaitForChild("Humanoid")
		local hrp = character:WaitForChild("HumanoidRootPart")
		return character, humanoid, hrp
	end

	local function getNext5MinuteTimestamp()
		local now = os.time()
		return now - (now % 300) + 300
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

	local function findCreatePartyStuff()
		local createParty = workspace:FindFirstChild("CreateParty", true)
		if not createParty then
			return nil, nil, nil, nil
		end

		local gate = createParty:FindFirstChild("Gate")
		local bossDoor = gate and gate:FindFirstChild("bossDoor")
		local doorPart = bossDoor and bossDoor:FindFirstChildWhichIsA("BasePart")

		return createParty, gate, bossDoor, doorPart
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
	
	local function attack()
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

		local startTime = os.time()
		print("เริ่มรอบบอส:", os.date("%H:%M:%S", startTime))

		local _, _, hrp = getCharacterParts()
		local createParty, _, _, doorPart = findCreatePartyStuff()

		if not createParty or not doorPart then
			warn("createParty or doorPart not found")
			clearBossFlags()
			State.bossNextRunAt = getNext5MinuteTimestamp()
			return false
		end

		local cf = doorPart.CFrame
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
			local bossModel = waitForBoss(living, "^Asura's Incarnate%d+$", 30)

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

		-- รอบถัดไป = นาที %5 ถัดไป
		State.bossNextRunAt = getNext5MinuteTimestamp()
		print("รอบบอสถัดไป:", os.date("%H:%M:%S", State.bossNextRunAt))

		return success
	end

	local PREPARE_BEFORE_BOSS = 8

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
			print("Immediate first boss run")
			State.bossImmediateRun = false
			runBossRound()
			task.wait(0.2)
			continue
		end

		-- ถ้ายังไม่มีรอบ ให้ set รอบ %5 ถัดไป
		if State.bossNextRunAt == 0 then
			State.bossNextRunAt = getNext5MinuteTimestamp()
		end

		now = os.time()

		-- ถ้าเลยรอบไปแล้ว ให้เริ่มบอสเลย
		if now >= State.bossNextRunAt then
			runBossRound()
			task.wait(0.2)
			continue
		end

		-- ใกล้ถึงรอบ ค่อยบล็อก miner
		if now >= (State.bossNextRunAt - PREPARE_BEFORE_BOSS) then
			if not State.bossPriorityActive then
				print("Boss priority active:", os.date("%H:%M:%S", now), "next =", os.date("%H:%M:%S", State.bossNextRunAt))
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