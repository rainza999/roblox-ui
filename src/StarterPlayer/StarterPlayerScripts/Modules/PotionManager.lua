local PotionManager = {}

function PotionManager.run(State)
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Players = game:GetService("Players")
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

	local POTIONS = {
		LuckPotion1 = {
			name = "LuckPotion1",
			maxStacks = 12,
			durationPerUse = 300,
			targetStock = 10,
		},
		MinerPotion1 = {
			name = "MinerPotion1",
			maxStacks = 3,
			durationPerUse = 300,
			targetStock = 10,
		},
	}

	local potionState = {
		LuckPotion1 = {
			expiresAt = 0,
			lastUseAt = 0,
			lastBuyAt = 0,
		},
		MinerPotion1 = {
			expiresAt = 0,
			lastUseAt = 0,
			lastBuyAt = 0,
		},
	}

	local function getBackpack()
		return player:FindFirstChildOfClass("Backpack")
	end

	local function getCharacter()
		return player.Character or player.CharacterAdded:Wait()
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

		-- บางเกมเก็บเป็น Attribute
		local attr = item:GetAttribute("Count")
		if typeof(attr) == "number" then
			return attr
		end

		-- ถ้าเจอ item แต่ไม่มี Count อย่างน้อยให้ถือว่ามี 1
		return 1
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

	local function getRemainingSeconds(toolName)
		local st = potionState[toolName]
		if not st then
			return 0
		end

		return math.max(0, st.expiresAt - tick())
	end

	local function getRemainingStacks(toolName)
		local cfg = POTIONS[toolName]
		local remain = getRemainingSeconds(toolName)

		if remain <= 0 then
			return 0
		end

		return math.floor((remain + 1) / cfg.durationPerUse)
	end

	local function canUseMore(toolName)
		local cfg = POTIONS[toolName]
		local stacks = getRemainingStacks(toolName)
		return stacks < cfg.maxStacks
	end

	local function registerUse(toolName)
		local cfg = POTIONS[toolName]
		local st = potionState[toolName]
		local now = tick()

		if st.expiresAt < now then
			st.expiresAt = now + cfg.durationPerUse
		else
			st.expiresAt += cfg.durationPerUse
		end

		local maxExpire = now + (cfg.maxStacks * cfg.durationPerUse)
		if st.expiresAt > maxExpire then
			st.expiresAt = maxExpire
		end

		st.lastUseAt = now
	end

	local function ensurePotionStock(toolName)
		local cfg = POTIONS[toolName]
		local st = potionState[toolName]

		local count = findToolCount(toolName)
		local need = cfg.targetStock - count

		print("[PotionStock]", toolName, "count=", count, "need=", need)

		if need <= 0 then
			return
		end

		if tick() - st.lastBuyAt < 2 then
			return
		end

		st.lastBuyAt = tick()

		local bought = buyPotion(toolName, need)
		if bought then
			task.wait(1)
		end
	end

	local function ensurePotionBuff(toolName)
		print("[PotionBuff] enter:", toolName)

		local st = potionState[toolName]
		if not st then
			warn("[PotionBuff] no potionState for", toolName)
			return
		end

		local count = findToolCount(toolName)
		local stacks = getRemainingStacks(toolName)
		local remain = math.floor(getRemainingSeconds(toolName))
		local canUse = canUseMore(toolName)

		print("[PotionBuff]", toolName, "count=", count, "stacks=", stacks, "remain=", remain, "canUse=", canUse)

		if not canUse then
			print("[PotionBuff] blocked: max stack reached", toolName)
			return
		end

		if count <= 0 then
			print("[PotionBuff] blocked: no potion in bag", toolName)
			return
		end

		if tick() - st.lastUseAt < 4 then
			print("[PotionBuff] blocked: cooldown", toolName, "diff=", tick() - st.lastUseAt)
			return
		end

		local used = usePotion(toolName)
		if used then
			registerUse(toolName)

			print(
				"[PotionBuff] used",
				toolName,
				"stacks=", getRemainingStacks(toolName),
				"remain=", math.floor(getRemainingSeconds(toolName)),
				"bag=", findToolCount(toolName)
			)

			task.wait(4)
		else
			warn("[PotionBuff] usePotion returned false:", toolName)
		end
	end

	task.spawn(function()
		print("[PotionManager] loop started")

		while getgenv().RobloxUIRunning do
			local ok, err = pcall(function()
				print(
					"[PotionLoop]",
					"autoUseLuck=", State.autoUseLuckPotion,
					"autoBuyLuck=", State.autoBuyLuckPotion,
					"autoUseMiner=", State.autoUseMinerPotion,
					"autoBuyMiner=", State.autoBuyMinerPotion
				)

				if State.autoBuyLuckPotion then
					ensurePotionStock("LuckPotion1")
				end

				if State.autoBuyMinerPotion then
					ensurePotionStock("MinerPotion1")
				end

				if State.autoUseLuckPotion then
					ensurePotionBuff("LuckPotion1")
				end

				if State.autoUseMinerPotion then
					ensurePotionBuff("MinerPotion1")
				end
			end)

			if not ok then
				warn("[PotionLoop ERROR]", err)
			end

			task.wait(1)
		end

		print("[PotionManager] loop ended")
	end)

	PotionManager.buyPotion = function(toolName, amount)
		return buyPotion(toolName, amount)
	end

	PotionManager.usePotion = function(toolName)
		if POTIONS[toolName] and not canUseMore(toolName) then
			print("[PotionManager] Potion already full:", toolName)
			return false
		end

		local used = usePotion(toolName)
		if used and POTIONS[toolName] then
			registerUse(toolName)
		end
		return used
	end

	PotionManager.getRemainingSeconds = getRemainingSeconds
	PotionManager.getRemainingStacks = getRemainingStacks
	PotionManager.findToolCount = findToolCount

	return PotionManager
end

return PotionManager