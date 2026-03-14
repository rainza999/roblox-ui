local ControllerLock = getgenv().RobloxModules.ControllerLock
local PotionManager = {}

function PotionManager.run(State)
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Players = game:GetService("Players")
	local TweenService = game:GetService("TweenService")
	local RunService = game:GetService("RunService")

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

	local OWNER = "PotionManager"
	local MOVE_SPEED = 55
	local ARRIVE_DISTANCE = 6
	local BUY_DISTANCE = 12
	local STUCK_CHECK_INTERVAL = 0.35
	local STUCK_MIN_PROGRESS = 1.5
	local STUCK_RETRY_LIMIT = 2

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

	local function getHumanoid()
		local character = getCharacter()
		return character and character:FindFirstChildOfClass("Humanoid")
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

	local function acquireMove(reason, allowSteal)
		if allowSteal then
			return ControllerLock.trySteal(State, OWNER, reason)
		end
		return ControllerLock.tryAcquire(State, OWNER, reason)
	end

	local function releaseMove()
		ControllerLock.release(State, OWNER)
	end

	local function isMoveBlocked()
		return ControllerLock.isOwnedByOther(State, OWNER)
	end

	local function setNoClip(enabled)
		local character = getCharacter()
		if not character then
			return
		end

		for _, v in ipairs(character:GetDescendants()) do
			if v:IsA("BasePart") then
				v.CanCollide = not enabled
			end
		end
	end

	local function stopMovement()
		local hrp = getHRP()
		if hrp then
			hrp.AssemblyLinearVelocity = Vector3.zero
			hrp.AssemblyAngularVelocity = Vector3.zero
		end
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

		return remain <= cfg.rebuffWhenRemainAtOrBelow and missing > 0
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
		return st.refillMode
	end

	local function tweenToPosition(targetPos, speed, timeoutExtra)
		if not acquireMove("move_to_potion_shop", true) then
			return false
		end

		local success = false
		local tween = nil
		local conn = nil

		local ok, err = pcall(function()
			local hrp = getHRP()
			local humanoid = getHumanoid()
			if not hrp or not humanoid then
				return
			end

			speed = math.clamp(speed or MOVE_SPEED, 50, 60)
			local distance = (hrp.Position - targetPos).Magnitude
			local duration = math.max(distance / speed, 0.2)

			stopMovement()
			setNoClip(true)

			tween = TweenService:Create(
				hrp,
				TweenInfo.new(duration, Enum.EasingStyle.Linear),
				{ CFrame = CFrame.new(targetPos) }
			)

			local finished = false
			conn = tween.Completed:Connect(function()
				finished = true
				if conn then
					conn:Disconnect()
					conn = nil
				end
			end)

			tween:Play()

			local timeoutAt = now() + duration + (timeoutExtra or 2)
			local lastCheckAt = now()
			local lastPos = hrp.Position
			local stuckCount = 0

			while now() < timeoutAt do
				hrp = getHRP()
				humanoid = getHumanoid()

				if not hrp or not humanoid or humanoid.Health <= 0 then
					if conn then conn:Disconnect() end
					if tween then tween:Cancel() end
					return
				end

				if ControllerLock.isOwnedByOther(State, OWNER) then
					if conn then conn:Disconnect() end
					if tween then tween:Cancel() end
					return
				end

				local dist = (hrp.Position - targetPos).Magnitude
				if dist <= ARRIVE_DISTANCE then
					if conn then conn:Disconnect() end
					if tween then tween:Cancel() end
					success = true
					return
				end

				if now() - lastCheckAt >= STUCK_CHECK_INTERVAL then
					local progressed = (hrp.Position - lastPos).Magnitude
					if progressed < STUCK_MIN_PROGRESS then
						stuckCount = stuckCount + 1
					else
						stuckCount = 0
					end

					lastCheckAt = now()
					lastPos = hrp.Position

					if stuckCount >= STUCK_RETRY_LIMIT then
						if conn then conn:Disconnect() end
						if tween then tween:Cancel() end
						return
					end
				end

				if finished then
					break
				end

				RunService.Heartbeat:Wait()
			end

			if conn then
				conn:Disconnect()
				conn = nil
			end

			if tween then
				tween:Cancel()
				tween = nil
			end

			hrp = getHRP()
			if hrp then
				success = (hrp.Position - targetPos).Magnitude <= BUY_DISTANCE
			end
		end)

		stopMovement()
		setNoClip(false)
		releaseMove()

		if not ok then
			warn("[PotionManager] tweenToPosition error:", err)
			return false
		end

		return success
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

		local standOff = 7
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

		if (hrp.Position - movePos).Magnitude <= BUY_DISTANCE then
			return true
		end

		return tweenToPosition(movePos, MOVE_SPEED, 2)
	end

	local function doBuy(toolName, amount)
		local owner = OWNER

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

			task.wait(0.15)
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
		local owner = OWNER

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
		if not cfg then
			return false
		end

		updateRefillMode(toolName)

		if autoUseFlag and needUse(toolName) then
			return doUse(toolName)
		end

		if autoBuyFlag then
			local shouldBuy, amount = needBuy(toolName)
			if shouldBuy then
				return doBuy(toolName, amount)
			end
		end

		return false
	end

	local function runPotionStep()
		if isPausedByOther(OWNER) then
			return
		end

		if isMoveBlocked() then
			local currentOwner = ControllerLock.getOwner(State)
			if currentOwner and currentOwner ~= OWNER then
				-- จะยังไม่ทำอะไร จนกว่าจะถึงจังหวะขอ steal ตอน tween จริง
			end
		end

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
				releasePause(OWNER)
				releaseMove()
				setNoClip(false)
				stopMovement()
			end

			task.wait(0.25)
		end

		releasePause(OWNER)
		releaseMove()
		setNoClip(false)
		stopMovement()
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