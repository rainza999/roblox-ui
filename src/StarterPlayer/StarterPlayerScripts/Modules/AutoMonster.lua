local AutoMonster = {}

function AutoMonster.run(State)
    print("START AUTOMONSTER")
	local Players = game:GetService("Players")
	local TweenService = game:GetService("TweenService")

	local player = Players.LocalPlayer
	local activeTween = nil

	local MOVE_SPEED = 70
	local STOP_DISTANCE = 4

	local function getCharacter()
		local char = player.Character or player.CharacterAdded:Wait()
		local hrp = char:WaitForChild("HumanoidRootPart")
		return char, hrp
	end

	local function findCommonOrc()
		local living = workspace:FindFirstChild("Living")
		if not living then return nil end

		local _, hrp = getCharacter()

		local nearest
		local nearestDist = math.huge

		for _, mob in ipairs(living:GetChildren()) do
			if mob:IsA("Model") and string.match(mob.Name, "^Common Orc") then

				local root = mob:FindFirstChild("HumanoidRootPart", true)
				local hum = mob:FindFirstChildOfClass("Humanoid")

				if root and hum and hum.Health > 0 then

					local dist = (root.Position - hrp.Position).Magnitude

					if dist < nearestDist then
						nearestDist = dist
						nearest = mob
					end

				end
			end
		end

		return nearest
	end

	local function tweenToPosition(targetPos)

		local _, hrp = getCharacter()

		if activeTween then
			activeTween:Cancel()
		end

		local dist = (targetPos - hrp.Position).Magnitude
		local time = dist / MOVE_SPEED

		activeTween = TweenService:Create(
			hrp,
			TweenInfo.new(time, Enum.EasingStyle.Linear),
			{
				CFrame = CFrame.new(targetPos)
			}
		)

		activeTween:Play()
		activeTween.Completed:Wait()

		activeTween = nil
	end


	task.spawn(function()

		while getgenv().RobloxUIRunning do

			if not State.autoMonsterFarm then
				task.wait(0.3)
				continue
			end

			local monster = findCommonOrc()

			if monster then

				local root = monster:FindFirstChild("HumanoidRootPart", true)

				if root then

					local char, hrp = getCharacter()

					local dir = (hrp.Position - root.Position).Unit

					local targetPos = root.Position + dir * STOP_DISTANCE

					tweenToPosition(targetPos)

				end
			else
				task.wait(0.5)
			end

		end

	end)

end

return AutoMonster