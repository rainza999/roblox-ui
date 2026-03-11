local AutoNPC = {}

function AutoNPC.run(State)
	local Players = game:GetService("Players")
	local TweenService = game:GetService("TweenService")

	local player = Players.LocalPlayer
	local busy = false
	local activeTween = nil

	local FIXED_FLY_Y = 120

	local function getCharacterParts()
		local character = player.Character or player.CharacterAdded:Wait()
		local humanoid = character:WaitForChild("Humanoid")
		local hrp = character:WaitForChild("HumanoidRootPart")
		return character, humanoid, hrp
	end

	local function getProximityModel(name)
		local proximity = workspace:FindFirstChild("Proximity")
		if not proximity then
			warn("AutoNPC: Proximity folder not found")
			return nil
		end

		local model = proximity:FindFirstChild(name)
		if not model or not model:IsA("Model") then
			warn("AutoNPC: model not found ->", name)
			return nil
		end

		return model
	end

	local function getModelPosition(model)
		if not model then
			return nil
		end

		return model.WorldPivot.Position
	end

	local function stopTween()
		if activeTween then
			pcall(function()
				activeTween:Cancel()
			end)
			activeTween = nil
		end
	end

	local function tweenLookAt(hrp, facePos)
		local targetCF = CFrame.lookAt(
			hrp.Position,
			Vector3.new(facePos.X, hrp.Position.Y, facePos.Z)
		)

		local tween = TweenService:Create(
			hrp,
			TweenInfo.new(0.08, Enum.EasingStyle.Linear, Enum.EasingDirection.Out),
			{ CFrame = targetCF }
		)

		tween:Play()
		tween.Completed:Wait()
	end

	local function tweenToPosition(hrp, targetPos, facePos, speed)
		stopTween()

		local distance = (targetPos - hrp.Position).Magnitude
		if distance <= 1 then
			tweenLookAt(hrp, facePos or targetPos)
			return true
		end

		local tweenTime = math.max(distance / (speed or 80), 0.08)

		activeTween = TweenService:Create(
			hrp,
			TweenInfo.new(tweenTime, Enum.EasingStyle.Linear, Enum.EasingDirection.Out),
			{
				CFrame = CFrame.lookAt(
					targetPos,
					Vector3.new(
						(facePos and facePos.X or targetPos.X),
						targetPos.Y,
						(facePos and facePos.Z or targetPos.Z)
					)
				)
			}
		)

		activeTween:Play()
		activeTween.Completed:Wait()
		activeTween = nil
		return true
	end

	local function moveToModel(model, opts)
		opts = opts or {}

		local _, humanoid, hrp = getCharacterParts()
		if humanoid.Health <= 0 then
			return false
		end

		local modelPos = getModelPosition(model)
		if not modelPos then
			return false
		end

		local stopDistance = opts.stopDistance or 4
		local speed = opts.speed or 90
		local flyY = opts.flyY or FIXED_FLY_Y

		local flatDir = Vector3.new(
			modelPos.X - hrp.Position.X,
			0,
			modelPos.Z - hrp.Position.Z
		)

		if flatDir.Magnitude > 0 then
			flatDir = flatDir.Unit
		else
			flatDir = Vector3.new(0, 0, -1)
		end

		local targetPos = Vector3.new(
			modelPos.X - flatDir.X * stopDistance,
			flyY,
			modelPos.Z - flatDir.Z * stopDistance
		)

		print("AutoNPC: moveToModel ->", model.Name, "target:", targetPos)
		return tweenToPosition(hrp, targetPos, modelPos, speed)
	end

	local function goToLocationOtherSideThenMazeMerchant()
		if busy then
			return
		end

		busy = true
		State.autoNpcBusy = true

		local ok, err = pcall(function()
			local locationOtherSide = getProximityModel("LocationOtherSide")
			if not locationOtherSide then
				return
			end

			local mazeMerchant = getProximityModel("MazeMerchant")
			if not mazeMerchant then
				return
			end

			print("AutoNPC: moving to LocationOtherSide")
			moveToModel(locationOtherSide, {
				flyY = 120,
				stopDistance = 6,
				speed = 100,
			})

			task.wait(0.3)

			print("AutoNPC: moving to MazeMerchat")
			moveToModel(mazeMerchant, {
				flyY = 120,
				stopDistance = 6,
				speed = 100,
			})

			print("AutoNPC: finished")
		end)

		if not ok then
			warn("AutoNPC error:", err)
		end

		stopTween()
		State.autoNpcBusy = false
		busy = false
	end

	function State.goToMazeMerchant()
		task.spawn(goToLocationOtherSideThenMazeMerchant)
	end
end

return AutoNPC