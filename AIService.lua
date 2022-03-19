--[[

 // AIService
 	SigmaRager, 18/03/2022
 	
 	Handles based on CollectionService:GetInstanceAddedSignal.
 	Avoid directly calling methods inside of AIService, if you
 	are looking to create SCP 049_2, use NPCService method:
 	
 	NPCService:SpawnPlagueDoctorZombie(player : Player, spawnLocation : CFrame, storageLocation : Instance)
 	
 	or otherwise:
 	
 	CollectionService:AddTag(character : Model, "049_2"); 

]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local PathfindingService = game:GetService("PathfindingService")
local RunService = game:GetService("RunService")

local Knit = require(ReplicatedStorage.Knit)

local AIService = Knit.CreateService{
	Name = "AIService",
	Client = {},
	Agents = {}
}


function AIService:PathfindToPosition(agent, endHRP)
	
	if agent.activeTask then return end
	agent.activeTask = true
	print("Running pathfind")
	
	local selected_agent = agent
	local start_position = selected_agent.npc.PrimaryPart.Position
	local agent_humanoid = selected_agent.npc:FindFirstChild("Humanoid")
	
	
	
	local path = PathfindingService:CreatePath({
		AgentCanJump = true,
		AgentHeight = 5,
		AgentRadius = 2,
		Costs = {
		}
	})
	
	for _, part in ipairs (agent.npc:GetChildren()) do
		if part:IsA("BasePart") then
			part:SetNetworkOwner(nil)
		end
	end
	
	local function reCompute()
		local success, error_message = xpcall(function()
			path:ComputeAsync(start_position, endHRP.Position + Vector3.new(3, 0, 0))
		end, function()
			warn("Path not computed")
			return false
		end)
	end
	
	local success, error_message = xpcall(function()
		path:ComputeAsync(start_position, endHRP.Position + Vector3.new(3, 0, 0))
	end, function()
		warn("Path not computed")
		return false
	end)
	
	local path_waypoints
	local reached_connection
	local blocked_connection
	local next_index
	
	if success and path.Status == Enum.PathStatus.Success then
		
		path_waypoints = path:GetWaypoints()
		
		
		-- // Visualize nodes
		--[[for _, waypoint in ipairs (path_waypoints) do
			local part = Instance.new("Part")
			part.Size = Vector3.new(1,1,1)
			part.Anchored = true
			part.CanCollide = false
			part.Parent = workspace
			part.Position = waypoint.Position
			part.Material = Enum.Material.Neon
		end]]
		
		blocked_connection = path.Blocked:Connect(function(blocked_index)
			if blocked_index >= next_index then
				blocked_connection:Disconnect()
				agent.activeTask = false
			end
		end)
		
		if not reached_connection then
			reached_connection = agent_humanoid.MoveToFinished:Connect(function(reached_bool)
				local last_waypoint = path_waypoints[#path_waypoints]
				if reached_bool and next_index < #path_waypoints then
					--Recompute the path's waypoints
					next_index += 1
					if path_waypoints[next_index].Action == Enum.PathWaypointAction.Jump then
						agent_humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
					end
					agent_humanoid:MoveTo(path_waypoints[next_index].Position)
				else
					reached_connection:Disconnect()
					blocked_connection:Disconnect()
					agent.activeTask = false
				end
			end)
		end
		
		next_index = 2
		agent_humanoid:MoveTo(path_waypoints[next_index].Position)
		
	end

end


function AIService:KnitStart()
	
	local RoundService = Knit.GetService("RoundService")
	
	-- // Agent manager
	
	local Agent = {}
	Agent.__index = Agent
	function Agent.new(character, summoner)
		
		local self = {}
		self.npc = character
		self.summoner = summoner
		self.status = nil
		self.path = nil
		self.activeTask = false
		
		setmetatable(self, Agent)
		
		return self
	end
	
	function Agent.IdleFunction(self)
		--print("Idle")
		AIService:PathfindToPosition(self, self.summoner.PrimaryPart)
	end
	
	function Agent.ChaseFunction(self)
		--print("Chasing")
	end
	
	function Agent:Update()
		
		--[[
		
		// Refer agent state to an update function to be called every heartbeat
		STATE: FUNCTION
		
		]]
		
		local stateToFunction = {
			["Idle"] = self.IdleFunction,
			["Chase"] = self.ChaseFunction
		}
		
		local currentFunction = stateToFunction[self.status]
		currentFunction(self)
		
		--[[
		
		// Determine agent state based on current circumstances
		raycastToAllPlayers()
		findNearestPlayer()
		
		]]
		
		local function raycastToAllPlayers()
			local state = RoundService:GetState()
			local start_position = self.npc.HumanoidRootPart.Position
			local players = state.playersInRound

			local raycast_params = RaycastParams.new()
			raycast_params.FilterDescendantsInstances = {self.summoner, self.npc, workspace.IgnoreTemp}

			local viable_players = {}
			
			local function visualizeRay(startPos, endPos)
				local distance = (startPos - endPos).magnitude
				
				local part = Instance.new("Part")
				part.Size = Vector3.new(0.1, 0.1, distance)
				part.Material = Enum.Material.Neon
				part.CanCollide = false
				part.Anchored = true
				part.Parent = workspace.IgnoreTemp
				part.CFrame = CFrame.lookAt(startPos, endPos) * CFrame.new(0, 0, -distance / 2)
				game:GetService("Debris"):AddItem(part, 0.05)
				
			end
		
			
			for _, player_object in ipairs(players) do
				local character = player_object.Character or player_object.CharacterAdded:Wait()
				if character and character:FindFirstChild("HumanoidRootPart") then
					local hrp = character:FindFirstChild("HumanoidRootPart")
					local end_position = hrp.Position
					local normalized_direction = (end_position - start_position).Unit

					local ray_result = workspace:Raycast(start_position, normalized_direction * 999, raycast_params)
					
					if ray_result and ray_result.Instance and ray_result.Instance.Parent and ray_result.Position then
						--visualizeRay(start_position, ray_result.Position)
						local parent = ray_result.Instance.Parent
						if parent:FindFirstChild("Humanoid") or parent.Parent:FindFirstChild("Humanoid") then
							table.insert(viable_players, player_object)
						end
					else
						--visualizeRay(start_position, (start_position + normalized_direction).Unit * 999)
					end
				end
			end
			
			--print(viable_players)

			return viable_players

		end

		local function findNearestPlayer(players)
			
			-- {PLAYER, DISTANCE}
			local last = {nil, 999}

			for _, player_object in ipairs(players) do
				local character = player_object.Character or player_object.CharacterAdded:Wait()
				local hrp = character:WaitForChild("HumanoidRootPart")
				local origin = self.summoner.PrimaryPart.Position

				local distance = (hrp.Position - origin).magnitude
				print(distance)
				if distance < last[2] then
					last[1] = player_object
					last[2] = distance
				end
			end

			return last

		end

		local viablePlayers = raycastToAllPlayers()
		local nearestPlayer = findNearestPlayer(viablePlayers)
		
		if nearestPlayer[1] ~= nil then
			print("We got to this")
			self.status = "Chase"
		end
		
	end
	
	-- // AIService setup
	
	function AIService:RegisterAI(npc_character)
		local roundservice_state = RoundService:GetState()
		local summoner = roundservice_state.currentSCP.Character
		if summoner then
			local new_agent = Agent.new(npc_character, summoner)
			new_agent.status = "Idle"
			table.insert(self.Agents, new_agent)
		else
			warn("Could not create agent '049_2' as currentSCP.Character does not exist")
		end
	end
	
	local function onTick(delta_time)
		for _, _agent in ipairs (AIService.Agents) do
			_agent:Update()
		end
	end
	
	local function instanceAdded(npc_character)
		AIService:RegisterAI(npc_character)
	end
	
	RunService.Heartbeat:Connect(onTick)
	CollectionService:GetInstanceAddedSignal("049_2"):Connect(instanceAdded)
	
end


return AIService