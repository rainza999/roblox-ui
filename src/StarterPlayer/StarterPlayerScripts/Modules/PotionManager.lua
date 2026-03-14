local PotionManager = {}

function PotionManager.run(State)
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Players = game:GetService("Players")
	local TweenService = game:GetService("TweenService")

	local player = Players.LocalPlayer

	local ToolActivated = ReplicatedStorage
		:WaitForChild("Shared")
		:WaitForChild("Packages")
		:WaitForChild("Knit")
		:WaitForChild("Services")
		:WaitForChild("ToolService")
		:WaitForChild("RF")
		:WaitForChild("ToolActivated")

	local PurchaseRF = ReplicatedStorage
		:WaitForChild("Shared")
		:WaitForChild("Packages")
		:WaitForChild("Knit")
		:WaitForChild("Services")
		:WaitForChild("ProximityService")
		:WaitForChild("RF")
		:WaitForChild("Purchase")

	State.pauseReason = State.pauseReason or nil
	State.pauseOwner = State.pauseOwner or nil
	State.isPotionBusy = State.isPotionBusy or false

	local POTIONS = {
		LuckPotion1 = {
			name = "LuckPotion1",
			durationPerUse = 300,
			maxStacks = 12,
			targetStock = 10,
			buyCooldown = 2,
			useCooldown = 0.8,
			rebuffWhenRemainAtOrBelow = 240,
			buyPolicy = "maintain",
		},
		MinerPotion1 = {
			name = "MinerPotion1",
			durationPerUse = 300,
			maxStacks = 3,
			targetStock = 10,
			buyCooldown = 2,
			useCooldown = 0.8,
			rebuffWhenRemainAtOrBelow = 240,
			buyPolicy = "empty",
		},
	}

	local potionState = {
		LuckPotion1 = {
			lastUseAt = 0,
			lastBuyAt = 0,
			lastActionAt = 0,
			refillMode = false,
		},
		MinerPotion1 = {
			lastUseAt = 0,
			lastBuyAt = 0,
			lastActionAt = 0,
			refillMode = false,
		},
	}

	local function now()
		return tick()
	end

	local function getCharacter()
		return player.Character or player.CharacterAdded:Wait()
	end

    local function setCollision(state)
        local character = getCharacter()
        if not character then return end

        for _, v in ipairs(character:GetDescendants()) do
            if v:IsA("BasePart") then
                v.CanCollide = state
            end
        end
    end

	local function getHRP()
		local character = getCharacter()
		return character and character:FindFirstChild("HumanoidRootPart")
	end

	local function getBackpack()
		return player:FindFirstChildOfClass("Backpack")
	end

	local function acquirePause(owner, reason)
		if State.pauseOwner and State.pauseOwner ~= owner then
			return false
		end

		State.pauseOwner = owner
		State.pauseReason = reason
		State.isPotionBusy = true
		return true
	end

	local function releasePause(owner)
		if State.pauseOwner == owner then
			State.pauseOwner = nil
			State.pauseReason = nil
			State.isPotionBusy = false
		end
	end

	local function isPausedByOther(owner)
		return State.pauseOwner ~= nil and State.pauseOwner ~= owner
	end

	local function debugPotionTargets()
		local proximity = workspace:FindFirstChild("Proximity")
		if not proximity then
			warn("[PotionShop] Proximity not found")
			return
		end

		print("=== Proximity Descendants ===")
		for _, obj in ipairs(proximity:GetDescendants()) do
			if obj.Name == "LuckPotion1" or obj.Name == "MinerPotion1" then
				print(obj:GetFullName(), "| class =", obj.ClassName)
			end
		end
	end

	local function tweenToPosition(targetPos, speed)
		local hrp = getHRP()
		local character = getCharacter()
		if not hrp or not character then
			return false
		end

		local humanoid = character:FindFirstChildOfClass("Humanoid")
		speed = speed or 60

		local distance = (hrp.Position - targetPos).Magnitude
		local duration = math.max(distance / speed, 0.15)

		setCollision(false)

		if humanoid then
			humanoid:ChangeState(Enum.HumanoidStateType.Physics)
		end

		hrp.AssemblyLinearVelocity = Vector3.zero
		hrp.AssemblyAngularVelocity = Vector3.zero

		local tween = TweenService:Create(
			hrp,
			TweenInfo.new(duration, Enum.EasingStyle.Linear),
			{ CFrame = CFrame.new(targetPos) }
		)

		local finished = false
		local conn

		conn = tween.Completed:Connect(function()
			finished = true
			if conn then
				conn:Disconnect()
				conn = nil
			end
		end)

		tween:Play()

		local timeoutAt = now() + duration + 2
		while now() < timeoutAt do
			hrp = getHRP()
			if not hrp or not hrp.Parent then
				if conn then conn:Disconnect() end
				tween:Cancel()
				setCollision(true)
				return false
			end

			local dist = (hrp.Position - targetPos).Magnitude
			if dist <= 6 then
				if conn then conn:Disconnect() end
				tween:Cancel()
				setCollision(true)
				return true
			end

			if finished then
				break
			end

			task.wait(0.05)
		end

		if conn then
			conn:Disconnect()
		end

		tween:Cancel()
		task.wait(0.1)

		hrp = getHRP()
		setCollision(true)

		if not hrp then
			return false
		end

		return (hrp.Position - targetPos).Magnitude <= 8
	end

	local function getPotionBuyPosition(toolName)
		local proximity = workspace:FindFirstChild("Proximity")
		if not proximity then
			warn("[PotionShop] workspace.Proximity not found")
			return nil
		end

		local target = proximity:FindFirstChild(toolName)
		if not target then
			warn("[PotionShop] Proximity target not found:", toolName)
			return nil
		end
		print("[PotionShop]", toolName, "class =", target.ClassName, "full =", target:GetFullName())
		local ok, pivot = pcall(function()
			return target.WorldPivot
		end)

		if ok and pivot then
			return pivot.Position
		end

		local ok2, cf = pcall(function()
			return target:GetPivot()
		end)

		if ok2 and cf then
			return cf.Position
		end

		local part = target:IsA("BasePart") and target or target:FindFirstChildWhichIsA("BasePart", true)
		if part then
			return part.Position
		end

		warn("[PotionShop] Could not resolve buy position for:", toolName)
		return nil
	end

	local function ensureNearPotionShop(toolName)
		local hrp = getHRP()
		local targetPos = getPotionBuyPosition(toolName)

		if not hrp or not targetPos then
			debugPotionTargets()
			warn("[PotionShop] missing targetPos or hrp for", toolName)
			return false
		end

		local currentPos = hrp.Position
		local flatDir = Vector3.new(targetPos.X - currentPos.X, 0, targetPos.Z - currentPos.Z)

		if flatDir.Magnitude < 0.001 then
			flatDir = Vector3.new(0, 0, -1)
		else
			flatDir = flatDir.Unit
		end

		-- อย่าไปทับ object ตรงๆ ให้ยืนหน้าเป้าแทน
		local standOff = 5
		local movePos = Vector3.new(
			targetPos.X - flatDir.X * standOff,
			targetPos.Y + 2,
			targetPos.Z - flatDir.Z * standOff
		)

		print(
			"[PotionShop] exact target for",
			toolName,
			"=>",
			math.floor(targetPos.X),
			math.floor(targetPos.Y),
			math.floor(targetPos.Z),
			"| move to =>",
			math.floor(movePos.X),
			math.floor(movePos.Y),
			math.floor(movePos.Z)
		)

		local distToMove = (hrp.Position - movePos).Magnitude
		if distToMove <= 4 then
			return true
		end

		local ok = tweenToPosition(movePos, 60)
		if not ok then
			warn("[PotionShop] tween failed for", toolName)

			-- fallback: วาร์ปสั้นๆ ไปใกล้อีกนิด
			local hrp2 = getHRP()
			if hrp2 then
				hrp2.CFrame = CFrame.new(movePos)
				task.wait(0.15)

				if (hrp2.Position - movePos).Magnitude <= 8 then
					return true
				end
			end

			return false
		end

		task.wait(0.15)
		return true
	end

	local function findToolInstance(toolName)
		local backpack = getBackpack()
		if backpack then
			local item = backpack:FindFirstChild(toolName)
			if item then
				return item
			end
		end

		local character = getCharacter()
		if character then
			local item = character:FindFirstChild(toolName)
			if item then
				return item
			end
		end

		return nil
	end

	local function findToolCount(toolName)
		local item = findToolInstance(toolName)
		if not item then
			return 0
		end

		local countValue = item:FindFirstChild("Count")
		if countValue and (countValue:IsA("IntValue") or countValue:IsA("NumberValue")) then
			return countValue.Value
		end

		local attr = item:GetAttribute("Count")
		if typeof(attr) == "number" then
			return attr
		end

		return 1
	end

	local function parseDurationText(text)
		if not text or text == "" then
			return 0
		end

		text = tostring(text):gsub("%s+", "")

		local h, m, s = string.match(text, "^(%d+):(%d+):(%d+)$")
		if h and m and s then
			return tonumber(h) * 3600 + tonumber(m) * 60 + tonumber(s)
		end

		local mm, ss = string.match(text, "^(%d+):(%d+)$")
		if mm and ss then
			return tonumber(mm) * 60 + tonumber(ss)
		end

		local onlyNumber = tonumber(text)
		if onlyNumber then
			return math.max(0, onlyNumber)
		end

		return 0
	end

	local function getPotionBuffSeconds(toolName)
		local playerGui = player:FindFirstChild("PlayerGui")
		if not playerGui then
			return 0
		end

		local hotbar = playerGui:FindFirstChild("Hotbar")
		if not hotbar then
			return 0
		end

		local perks = hotbar:FindFirstChild("Perks")
		if not perks then
			return 0
		end

		local potionGui = perks:FindFirstChild(toolName)
		if not potionGui then
			return 0
		end

		local duration = potionGui:FindFirstChild("Duration")
		if not duration then
			return 0
		end

		local ok, value = pcall(function()
			return duration.Text
		end)

		if not ok then
			return 0
		end

		return parseDurationText(value)
	end

	local function getRemainingSeconds(toolName)
		return math.max(0, getPotionBuffSeconds(toolName))
	end

	local function getRemainingStacks(toolName)
		local cfg = POTIONS[toolName]
		if not cfg then
			return 0
		end

		local remain = getRemainingSeconds(toolName)
		if remain <= 0 then
			return 0
		end

		local stacks = math.ceil(remain / cfg.durationPerUse)
		if stacks > cfg.maxStacks then
			stacks = cfg.maxStacks
		end

		return stacks
	end

	local function getMissingStacks(toolName)
		local cfg = POTIONS[toolName]
		if not cfg then
			return 0
		end

		local missing = cfg.maxStacks - getRemainingStacks(toolName)
		if missing < 0 then
			missing = 0
		end
		return missing
	end

	local function buyPotion(toolName, amount)
		if amount <= 0 then
			return false
		end

		local ok, result = pcall(function()
			return PurchaseRF:InvokeServer(toolName, amount)
		end)

		if ok then
			print("[PotionManager] Buy success:", toolName, amount, result)
			return true
		else
			warn("[PotionManager] Buy failed:", toolName, result)
			return false
		end
	end

	local function usePotion(toolName)
		local ok, result = pcall(function()
			return ToolActivated:InvokeServer(toolName)
		end)

		if ok then
			print("[PotionManager] Use success:", toolName, result)
			return true
		else
			warn("[PotionManager] Use failed:", toolName, result)
			return false
		end
	end

	local function shouldEnterRefillMode(toolName)
		local cfg = POTIONS[toolName]
		if not cfg then
			return false
		end

		local remain = getRemainingSeconds(toolName)
		local missing = getMissingStacks(toolName)

		if remain <= cfg.rebuffWhenRemainAtOrBelow and missing > 0 then
			return true
		end

		return false
	end

	local function updateRefillMode(toolName)
		local st = potionState[toolName]
		local count = findToolCount(toolName)
		local missing = getMissingStacks(toolName)

		if shouldEnterRefillMode(toolName) then
			st.refillMode = true
		end

		if missing <= 0 then
			st.refillMode = false
			return
		end

		if count <= 0 and not shouldEnterRefillMode(toolName) then
			st.refillMode = false
		end
	end

	local function needBuy(toolName)
		local cfg = POTIONS[toolName]
		local st = potionState[toolName]
		local count = findToolCount(toolName)

		if now() - st.lastBuyAt < cfg.buyCooldown then
			return false, 0
		end

		if cfg.buyPolicy == "maintain" then
			local need = cfg.targetStock - count
			if need > 0 then
				return true, need
			end
			return false, 0
		end

		if cfg.buyPolicy == "empty" then
			if count <= 0 then
				return true, cfg.targetStock
			end
			return false, 0
		end

		return false, 0
	end

	local function needUse(toolName)
		local cfg = POTIONS[toolName]
		local st = potionState[toolName]
		local count = findToolCount(toolName)
		local missing = getMissingStacks(toolName)

		if count <= 0 then
			return false
		end

		if missing <= 0 then
			st.refillMode = false
			return false
		end

		if now() - st.lastUseAt < cfg.useCooldown then
			return false
		end

		updateRefillMode(toolName)

		if st.refillMode then
			return true
		end

		return false
	end

	local function doBuy(toolName, amount)
		local owner = "PotionManager"

		if not acquirePause(owner, "buy_potion") then
			return false
		end

		local success = false

		local ok, err = pcall(function()
			local st = potionState[toolName]
			st.lastBuyAt = now()
			st.lastActionAt = now()

			if not ensureNearPotionShop(toolName) then
				return
			end

			success = buyPotion(toolName, amount)
		end)

		releasePause(owner)

		if not ok then
			warn("[PotionManager] doBuy error:", err)
			return false
		end

		return success
	end

	local function doUse(toolName)
		local owner = "PotionManager"

		if not acquirePause(owner, "use_potion") then
			return false
		end

		local success = false

		local ok, err = pcall(function()
			local st = potionState[toolName]
			local before = getRemainingSeconds(toolName)
			local beforeStacks = getRemainingStacks(toolName)
			local beforeBag = findToolCount(toolName)

			local used = usePotion(toolName)
			if used then
				st.lastUseAt = now()
				st.lastActionAt = now()

				task.wait(0.2)

				local after = getRemainingSeconds(toolName)
				local afterStacks = getRemainingStacks(toolName)
				local afterBag = findToolCount(toolName)
				local missing = getMissingStacks(toolName)

				if missing <= 0 then
					st.refillMode = false
				else
					st.refillMode = true
				end

				print(
					"[PotionBuff] used",
					toolName,
					"before=", math.floor(before),
					"after=", math.floor(after),
					"stacksBefore=", beforeStacks,
					"stacksAfter=", afterStacks,
					"bagBefore=", beforeBag,
					"bagAfter=", afterBag,
					"missing=", missing
				)

				success = true
			end
		end)

		releasePause(owner)

		if not ok then
			warn("[PotionManager] doUse error:", err)
			return false
		end

		return success
	end

	local function processPotion(toolName, autoBuyFlag, autoUseFlag)
		local cfg = POTIONS[toolName]
		local st = potionState[toolName]

		if not cfg then
			return false
		end

		updateRefillMode(toolName)

		local remain = getRemainingSeconds(toolName)
		local stacks = getRemainingStacks(toolName)
		local bag = findToolCount(toolName)
		local missing = getMissingStacks(toolName)

		-- if st.refillMode then
		-- 	print(
		-- 		"[PotionRefill1]",
		-- 		toolName,
		-- 		"remain=", math.floor(remain),
		-- 		"stacks=", stacks,
		-- 		"bag=", bag,
		-- 		"missing=", missing
		-- 	)
		-- end

		-- 1) ถ้ากำลัง refill และมียาอยู่ ให้กดใช้ก่อน
		if autoUseFlag and needUse(toolName) then
			return doUse(toolName)
		end

		-- 2) ถ้าต้องซื้อค่อยซื้อ
		if autoBuyFlag then
			local shouldBuy, amount = needBuy(toolName)
			if shouldBuy then
				return doBuy(toolName, amount)
			end
		end

		return false
	end

	local function runPotionStep()
		if isPausedByOther("PotionManager") then
			return
		end

		-- Luck มาก่อน เพราะเป็นตัวที่ต้อง maintain stock ต่อเนื่อง
		if processPotion("LuckPotion1", State.autoBuyLuckPotion, State.autoUseLuckPotion) then
			return
		end

		if processPotion("MinerPotion1", State.autoBuyMinerPotion, State.autoUseMinerPotion) then
			return
		end
	end

	task.spawn(function()
		print("[PotionManager] loop started")

		while getgenv().RobloxUIRunning do
			local ok, err = pcall(function()
				runPotionStep()
			end)

			if not ok then
				warn("[PotionLoop ERROR]", err)
				releasePause("PotionManager")
			end

			task.wait(0.25)
		end

		releasePause("PotionManager")
		print("[PotionManager] loop ended")
	end)

	PotionManager.buyPotion = function(toolName, amount)
		return doBuy(toolName, amount)
	end

	PotionManager.usePotion = function(toolName)
		local cfg = POTIONS[toolName]
		if not cfg then
			return false
		end

		local missing = getMissingStacks(toolName)
		if missing <= 0 then
			print("[PotionManager] Already full:", toolName)
			return false
		end

		return doUse(toolName)
	end

	PotionManager.getRemainingSeconds = getRemainingSeconds
	PotionManager.getRemainingStacks = getRemainingStacks
	PotionManager.getMissingStacks = getMissingStacks
	PotionManager.findToolCount = findToolCount
	PotionManager.getPotionBuffSeconds = getPotionBuffSeconds

	return PotionManager
end

return PotionManager