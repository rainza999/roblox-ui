local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local hrp = character:WaitForChild("HumanoidRootPart")

local SPEED = 70

-- checkpoints
local checkpoint1 = Vector3.new(200,15,-1780)
local checkpoint2 = Vector3.new(465,-129,-1840)

-- NPC
local npc = workspace:WaitForChild("Proximity"):WaitForChild("MazeMerchant")
local npcPos = npc:GetPivot().Position

local function tweenTo(pos)

	local distance = (hrp.Position - pos).Magnitude
	local time = distance / SPEED

	local tween = TweenService:Create(
		hrp,
		TweenInfo.new(time, Enum.EasingStyle.Linear),
		{CFrame = CFrame.new(pos)}
	)

	tween:Play()

	repeat
		task.wait()
	until (hrp.Position - pos).Magnitude < 4

	task.wait(0.5)

end

local function setCollision(state)
	local character = game.Players.LocalPlayer.Character
	
	for _,v in ipairs(character:GetDescendants()) do
		if v:IsA("BasePart") then
			v.CanCollide = state
		end
	end
end
-- STEP 1 ลอยก่อน
hrp.CFrame = CFrame.new(hrp.Position.X,100,hrp.Position.Z)
task.wait(0.5)

setCollision(false) -- ทะลุได้

tweenTo(Vector3.new(checkpoint1.X,100,checkpoint1.Z))
tweenTo(checkpoint1)
tweenTo(checkpoint2)
tweenTo(npcPos)

setCollision(true) -- กลับมาปกติ