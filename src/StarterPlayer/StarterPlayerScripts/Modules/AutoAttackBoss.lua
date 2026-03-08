local AutoAttackBoss = {}

function AutoAttackBoss.run(State)
	print("AutoAttackBoss started")

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

		while tick() - start < timeout do
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

	local function followBoss(bossModel)
		local _, humanoid, hrp = getCharacterParts()

		while bossModel and bossModel.Parent do
			if State and not State.autoBoss then
				return false
			end

			local bossHumanoid = bossModel:FindFirstChildOfClass("Humanoid")
			local bossHrp = bossModel:FindFirstChild("HumanoidRootPart")

			if not bossHumanoid or not bossHrp then
				warn("Boss missing parts")
				return false
			end

			if bossHumanoid.Health <= 0 then
				print("Boss defeated!")
				return true
			end

			local dist = (bossHrp.Position - hrp.Position).Magnitude
			if dist > 6 then
				humanoid:MoveTo(bossHrp.Position)
			end

			local look = Vector3.new(bossHrp.Position.X, hrp.Position.Y, bossHrp.Position.Z)
			hrp.CFrame = CFrame.lookAt(hrp.Position, look)

			attack()
			task.wait(0.2)

			local currentChar = player.Character
			if not currentChar or humanoid.Health <= 0 then
				_, humanoid, hrp = getCharacterParts()
			end
		end

		return false
	end

	local function getNext5MinuteTimestamp()
		local now = os.time()
		return now - (now % 300) + 300
	end

	local function waitUntil(ts)
		while os.time() < ts do
			if State and not State.autoBoss then
				return
			end
			task.wait(0.5)
		end
	end

	local function pressT()
		local ok, vim = pcall(function()
			return game:GetService("VirtualInputManager")
		end)

		if ok and vim then
			vim:SendKeyEvent(true, Enum.KeyCode.T, false, game)
			task.wait(0.05)
			vim:SendKeyEvent(false, Enum.KeyCode.T, false, game)
		else
			warn("VirtualInputManager unavailable")
		end
	end

	while true do
		if not State.autoBoss then
			task.wait(0.2)
			continue
		end

		local startTime = os.time()
		local nextRunTime = getNext5MinuteTimestamp()

		print("เริ่มรอบ:", os.date("%H:%M:%S", startTime))
		print("รอบถัดไปเริ่มได้ตอน:", os.date("%H:%M:%S", nextRunTime))

		local _, _, hrp = getCharacterParts()
		local createParty, _, _, doorPart = findCreatePartyStuff()

		if createParty and doorPart then
			local cf = doorPart.CFrame
			local dist = (cf.Position - hrp.Position).Magnitude
			local tween = TweenService:Create(hrp, TweenInfo.new(dist / 60), {CFrame = cf})
			tween:Play()
			tween.Completed:Wait()

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

			local living = workspace:FindFirstChild("Living")
			if living then
				local bossModel = waitForBoss(living, "^Asura's Incarnate%d+$", 30)

				if bossModel then
					print("Found boss:", bossModel.Name)
					followBoss(bossModel)
				else
					warn("Boss not found within timeout")
				end
			else
				warn("Living folder not found")
			end
		else
			warn("createParty or doorPart not found")
		end

		task.wait(3)

		local finishTime = os.time()
		print("จบรอบ:", os.date("%H:%M:%S", finishTime))

		task.wait(5)

		if State.autoPressT then
			pressT()
		end

		if finishTime < nextRunTime then
			print("ยังไม่ถึงเวลา รอถึง:", os.date("%H:%M:%S", nextRunTime))
			waitUntil(nextRunTime)
		else
			print("ครบเวลาแล้ว ลงต่อได้ทันที")
		end

		task.wait(0.2)
	end

	print("AutoAttackBoss stopped")
end

return AutoAttackBoss