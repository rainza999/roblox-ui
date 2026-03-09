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
			maxStacks = 12,       -- 60 min / 5 min
			durationPerUse = 300, -- 5 min
			targetStock = 10,     -- อยากให้เหลือ/เติมให้เต็ม 10
		},
		MinerPotion1 = {
			name = "MinerPotion1",
			maxStacks = 3,        -- 15 min / 5 min
			durationPerUse = 300, -- 5 min
			targetStock = 10,     -- อยากให้เหลือ/เติมให้เต็ม 10
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

	local function findToolCount(toolName)
		local backpack = player:FindFirstChildOfClass("Backpack")
		if not backpack then
			return 0
		end

		local item = backpack:FindFirstChild(toolName)
		if not item then
			return 0
		end

		local countValue = item:FindFirstChild("Count")
		if countValue and countValue:IsA("IntValue") then
			return countValue.Value
		end

		return 0
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

		if need <= 0 then
			return
		end

		if tick() - st.lastBuyAt < 2 then
			return
		end

		st.lastBuyAt = tick()

		print("[PotionManager] Need buy:", toolName, need, "| current =", count, "| target =", cfg.targetStock)

		local bought = buyPotion(toolName, need)
		if bought then
			task.wait(1)
		end
	end

	local function ensurePotionBuff(toolName)
        print("[PotionBuff] enter:", toolName)

        local st = potionState[toolName]
        local count = findToolCount(toolName)

        print(
            "[PotionBuff]",
            toolName,
            "count=", count,
            "stacks=", getRemainingStacks(toolName),
            "remain=", math.floor(getRemainingSeconds(toolName)),
            "lastUseDiff=", tick() - st.lastUseAt
        )

		if not canUseMore(toolName) then
			return
		end

		if count <= 0 then
			return
		end

		if tick() - st.lastUseAt < 4 then
			return
		end

		local used = usePotion(toolName)
		if used then
			registerUse(toolName)

			print(
				"[Potion]",
				toolName,
				"stacks=", getRemainingStacks(toolName),
				"remain=", math.floor(getRemainingSeconds(toolName)),
				"bag=", findToolCount(toolName)
			)

			task.wait(4)
		end
	end

	task.spawn(function()
		while getgenv().RobloxUIRunning do
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

			task.wait(1)
		end
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