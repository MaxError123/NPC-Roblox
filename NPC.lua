```lua
local Players = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")

local npc = script.Parent
local humanoid = npc:WaitForChild("Humanoid")
local root = npc:WaitForChild("HumanoidRootPart")

local detectionRange = 60
local attackRange = 4
local attackDamage = 15
local attackCooldown = 1
local patrolRadius = 35
local walkSpeed = 10
local chaseSpeed = 16
local fieldOfView = 100

local lastAttack = 0
local target = nil
local lastSeenPosition = nil
local alive = true

local function getRoot(character)
	return character and character:FindFirstChild("HumanoidRootPart")
end

local function getHumanoid(character)
	return character and character:FindFirstChildOfClass("Humanoid")
end

local function isAlive(character)
	local h = getHumanoid(character)
	return h and h.Health > 0
end

local function distanceFrom(position)
	return (root.Position - position).Magnitude
end

local function canSee(character)
	local targetRoot = getRoot(character)

	if not targetRoot then
		return false
	end

	local direction = targetRoot.Position - root.Position
	local distance = direction.Magnitude

	if distance > detectionRange then
		return false
	end

	local angle = math.deg(math.acos(math.clamp(
		root.CFrame.LookVector:Dot(direction.Unit),
		-1,
		1
	)))

	if angle > fieldOfView / 2 then
		return false
	end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = {npc}

	local result = workspace:Raycast(
		root.Position,
		direction,
		params
	)

	if result and not result.Instance:IsDescendantOf(character) then
		return false
	end

	return true
end

local function findTarget()
	local closest = nil
	local closestDistance = detectionRange

	for _, player in Players:GetPlayers() do
		local character = player.Character

		if character and isAlive(character) then
			local targetRoot = getRoot(character)

			if targetRoot then
				local distance = distanceFrom(targetRoot.Position)

				if distance < closestDistance and canSee(character) then
					closest = player
					closestDistance = distance
				end
			end
		end
	end

	return closest
end

local function createPath(destination)
	local path = PathfindingService:CreatePath({
		AgentRadius = 2,
		AgentHeight = 5,
		AgentCanJump = true,
		AgentCanClimb = true,
		WaypointSpacing = 4
	})

	local success = pcall(function()
		path:ComputeAsync(root.Position, destination)
	end)

	if not success or path.Status ~= Enum.PathStatus.Success then
		return nil
	end

	return path
end

local function moveTo(destination)
	local path = createPath(destination)

	if not path then
		humanoid:MoveTo(destination)
		humanoid.MoveToFinished:Wait()
		return
	end

	for _, waypoint in path:GetWaypoints() do
		if not alive then
			return
		end

		if waypoint.Action == Enum.PathWaypointAction.Jump then
			humanoid.Jump = true
		end

		humanoid:MoveTo(waypoint.Position)

		local reached = humanoid.MoveToFinished:Wait()

		if not reached then
			return
		end
	end
end

local function getPatrolPosition()
	local offset = Vector3.new(
		math.random(-patrolRadius, patrolRadius),
		0,
		math.random(-patrolRadius, patrolRadius)
	)

	return root.Position + offset
end

local function attack(player)
	if os.clock() - lastAttack < attackCooldown then
		return
	end

	local character = player.Character
	local targetHumanoid = getHumanoid(character)
	local targetRoot = getRoot(character)

	if not targetHumanoid or not targetRoot then
		return
	end

	if distanceFrom(targetRoot.Position) > attackRange then
		return
	end

	lastAttack = os.clock()

	local lookAt = Vector3.new(
		targetRoot.Position.X,
		root.Position.Y,
		targetRoot.Position.Z
	)

	root.CFrame = CFrame.lookAt(root.Position, lookAt)
	targetHumanoid:TakeDamage(attackDamage)
end

local function patrol()
	humanoid.WalkSpeed = walkSpeed

	local destination = getPatrolPosition()

	moveTo(destination)

	task.wait(math.random(1, 3))
end

local function chase(player)
	humanoid.WalkSpeed = chaseSpeed

	local character = player.Character

	if not character or not isAlive(character) then
		return false
	end

	local targetRoot = getRoot(character)

	if not targetRoot then
		return false
	end

	if canSee(character) then
		lastSeenPosition = targetRoot.Position
	end

	if distanceFrom(targetRoot.Position) <= attackRange then
		return true
	end

	moveTo(targetRoot.Position)

	return true
end

local function search()
	if not lastSeenPosition then
		return
	end

	humanoid.WalkSpeed = walkSpeed

	moveTo(lastSeenPosition)

	local searchEnd = os.clock() + 5

	while os.clock() < searchEnd and alive do
		local newTarget = findTarget()

		if newTarget then
			target = newTarget
			return
		end

		local randomDirection = Vector3.new(
			math.random(-8, 8),
			0,
			math.random(-8, 8)
		)

		humanoid:MoveTo(root.Position + randomDirection)

		task.wait(0.8)
	end

	lastSeenPosition = nil
	target = nil
end

humanoid.WalkSpeed = walkSpeed

while alive do
	if not target then
		target = findTarget()
	end

	if target then
		local character = target.Character

		if not character or not isAlive(character) then
			target = nil
		else
			local targetRoot = getRoot(character)

			if not targetRoot then
				target = nil
			else
				local distance = distanceFrom(targetRoot.Position)

				if distance <= attackRange then
					attack(target)
					task.wait(0.15)
				elseif canSee(character) then
					lastSeenPosition = targetRoot.Position
					chase(target)
				else
					search()
				end
			end
		end
	else
		patrol()
	end

	task.wait(0.1)
end

humanoid.Died:Connect(function()
	alive = false
	target = nil
	lastSeenPosition = nil
end)
```
