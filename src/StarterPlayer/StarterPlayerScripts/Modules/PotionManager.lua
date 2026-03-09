local PotionManager = {}

function PotionManager.run(State)
	local ReplicatedStorage = game:GetService("ReplicatedStorage")

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

	local Players = game:GetService("Players")
	local player = Players.LocalPlayer

	local POTIONS = {
		LuckPotion1 = {
			name = "LuckPotion1",
			maxStacks = 12, -- 60 min / 5 min
			durationPerUse = 300, -- 5 min
			buyAmount = 10,
		},
		MinerPotion1 = {
			name = "MinerPotion1",
			maxStacks = 3, -- 15 min / 5 min
			durationPerUse = 300, -- 5 min
			buyAmount = 10,
		},
	}

	local potionState = {
		LuckPotion1 = {
			expiresAt = 0,
			pendingUses = 0,
			lastUseAt = 0,
			lastBuyAt = 0,
		},
		MinerPotion1 = {
			expiresAt = 0,
			pendingUses = 0,
			lastUseAt = 0,
			lastBuyAt = 0,
		},
	}

	local function getCharacter()
		return player.Character or player.CharacterAdded:Wait()
	end

	local function findToolCount(toolName)
		local character = getCharacter()
		local backpack = player:FindFirstChildOfClass("Backpack")

		local count = 0

		if backpack then
			for _, child in ipairs(backpack:GetChildren()) do
				if child.Name == toolName then
					count += 1
				end
			end
		end

		for _, child in ipairs(character:GetChildren()) do
			if child.Name == toolName then
				count += 1
			end
		end

		return count
	end

	local function buyPotion(toolName, amount)
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

	local function ensurePotion(toolName, autoBuyEnabled)
		local cfg = POTIONS[toolName]
		local st = potionState[toolName]

		if not canUseMore(toolName) then
			return
		end

		local count = findToolCount(toolName)

		if count <= 0 then
			if autoBuyEnabled and tick() - st.lastBuyAt > 2 then
				st.lastBuyAt = tick()
				local bought = buyPotion(toolName, cfg.buyAmount)
				if bought then
					task.wait(0.8)
				end
			end
			return
		end

		if tick() - st.lastUseAt < 0.8 then
			return
		end

		local used = usePotion(toolName)
		if used then
			registerUse(toolName)
			task.wait(0.5)
		end
	end

	task.spawn(function()
		while getgenv().RobloxUIRunning do
			if State.autoUseLuckPotion then
				ensurePotion("LuckPotion1", State.autoBuyLuckPotion)
			end

			if State.autoUseMinerPotion then
				ensurePotion("MinerPotion1", State.autoBuyMinerPotion)
			end

			task.wait(1)
		end
	end)

	PotionManager.buyPotion = buyPotion
	PotionManager.usePotion = function(toolName)
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