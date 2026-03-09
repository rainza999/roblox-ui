local AutoMonster = {}

function AutoMonster.run(State)
	local Players = game:GetService("Players")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")

	local player = Players.LocalPlayer

	local function getCharacterParts()
		local character = player.Character or player.CharacterAdded:Wait()
		local humanoid = character:WaitForChild("Humanoid")
		local hrp = character:WaitForChild("HumanoidRootPart")
		return character, humanoid, hrp
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

	local function hasAnySelectedMonster()
		if not State.selectedMonsters then
			return false
		end

		for _, selected in pairs(State.selectedMonsters) do
			if selected then
				return true
			end
		end

		return false
	end

	local function findMonsterRoot(model)
		return model:FindFirstChild("HumanoidRootPart", true)
			or model:FindFirstChild("RootPart", true)
			or model:FindFirstChild("Torso", true)
			or model:FindFirstChild("UpperTorso", true)
			or model.PrimaryPart
	end

	local function getRealMonsterName(model)
		-- ลองหา StringValue/Configuration ที่เก็บชื่อจริง
		for _, obj in ipairs(model:GetDescendants()) do
			if obj:IsA("StringValue") then
				local n = string.lower(obj.Name)
				if n == "name" or n == "mobname" or n == "monstername" then
					if obj.Value and obj.Value ~= "" then
						return obj.Value
					end
				end
			end
		end

		-- ลองหา model ลูกที่ชื่อเป็นชื่อมอนจริง
		for _, child in ipairs(model:GetChildren()) do
			if child:IsA("Model") then
				local hum = child:FindFirstChildOfClass("Humanoid")
				if hum then
					return child.Name
				end
			end
		end

		-- fallback: ตัดเลขท้ายชื่อออก เช่น Common Orc17 -> Common Orc
		local cleaned = model.Name:gsub("%d+$", "")
		cleaned = cleaned:gsub("%s+$", "")
		return cleaned
	end

	local function isSelectedMonster(realName)
		if not State.selectedMonsters then
			return false
		end

		for monsterName, selected in pairs(State.selectedMonsters) do
			if selected and string.lower(monsterName) == string.lower(realName) then
				return true
			end
		end

		return false
	end

	local function findMonsterHumanoid(model)
		return model:FindFirstChildOfClass("Humanoid")
			or model:FindFirstChildWhichIsA("Humanoid", true)
	end

	local function findTargetMonster()
		local living = workspace:FindFirstChild("Living")
		if not living then
			warn("AutoMonster: Living folder not found")
			return nil
		end

		local _, _, hrp = getCharacterParts()
		local nearestMonster = nil
		local nearestDistance = math.huge

		for _, model in ipairs(living:GetChildren()) do
			if model:IsA("Model") then
				local realName = getRealMonsterName(model)
				print("Living model:", model.Name, "=> real:", realName)

				if isSelectedMonster(realName) then
					local monsterHumanoid = findMonsterHumanoid(model)
					local monsterRoot = findMonsterRoot(model)

					if monsterHumanoid and monsterRoot and monsterHumanoid.Health > 0 then
						local dist = (monsterRoot.Position - hrp.Position).Magnitude
						if dist < nearestDistance then
							nearestDistance = dist
							nearestMonster = model
						end
					end
				end
			end
		end

		if nearestMonster then
			print("Target chosen:", nearestMonster.Name, "real:", getRealMonsterName(nearestMonster))
		end

		return nearestMonster
	end

	local function followAndAttack(monster)
        local _, humanoid, hrp = getCharacterParts()

        local ATTACK_RANGE = 7
        local STOP_DISTANCE = 4
        local TELEPORT_IF_FAR = 22

        while getgenv().RobloxUIRunning and State.autoMonsterFarm and monster and monster.Parent do
            if State.autoMiner then
                return
            end

            local monsterHumanoid = findMonsterHumanoid(monster)
            local monsterRoot = findMonsterRoot(monster)

            if not monsterHumanoid or not monsterRoot then
                return
            end

            if monsterHumanoid.Health <= 0 then
                return
            end

            local offset = monsterRoot.Position - hrp.Position
            local dist = offset.Magnitude

            if dist > ATTACK_RANGE then
                local dir = offset.Unit
                local standPos = monsterRoot.Position - (dir * STOP_DISTANCE)

                if dist > TELEPORT_IF_FAR then
                    hrp.CFrame = CFrame.new(standPos, monsterRoot.Position)
                    task.wait(0.08)
                else
                    humanoid:MoveTo(standPos)
                    task.wait(0.12)
                end
            else
                local look = Vector3.new(monsterRoot.Position.X, hrp.Position.Y, monsterRoot.Position.Z)
                hrp.CFrame = CFrame.lookAt(hrp.Position, look)
                attack()
                task.wait(0.15)
            end

            local character = player.Character
            if not character or humanoid.Health <= 0 then
                _, humanoid, hrp = getCharacterParts()
            end
        end
    end

	task.spawn(function()
		while getgenv().RobloxUIRunning do
			if not State.autoMonsterFarm then
				task.wait(0.2)
				continue
			end

			if not hasAnySelectedMonster() then
				warn("AutoMonster: no selected monsters")
				task.wait(0.5)
				continue
			end

			local target = findTargetMonster()
			if target then
				followAndAttack(target)
			else
				warn("AutoMonster: no matching target found")
				task.wait(0.5)
			end
		end
	end)
end

return AutoMonster