--[[ Connected Discord-GitHub | Roblox:MaybeNotFish | discord:myd3

   CoreHitBox is a module that allows you to create hitboxes that can be used to detect
   collisions with other parts.
   
   Made by MaybeNotFish
]]

--|| Services ||
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

--|| Libraries ||
local Janitor = require(script.Janitor)
local GoodSignal = require(script.GoodSignal)

--|| Main ||
local Shared = {}
local Local = {}
local Connections = {}
Shared.__index = Shared

--|| Shape types || (for auto completion)
type Shapes = "Box" | "Sphere" | "Cylinder" | "Cone" | "Capsule"

--|| Types || (Hitbox properties)
export type CoreHitBox = {
	Shape: Shapes,
	Size: Vector3?,
	Visualize: boolean?,
	CFrame: CFrame?,
	LifeTime: number,
	HitMode: "Once" | "Multiple",
}

--|| Hitbox instance || Hitbox object
export type HitBoxInstance = typeof(setmetatable({} :: {
	Janitor: any,
	Config: CoreHitBox,
	LifeTime: number,
	OnHit: any,
	OnStart: any,
	OnEnd: any,
	Visualize: boolean,
	Visual: HandleAdornment?,
	Size: Vector3,
	CFrame: CFrame,
	MaxHits: number,
	Shape: Shapes,
	Params: OverlapParams,
}, Shared))

--|| Constants || (Default in case the property is not found in the configs)
Local.Constants = table.freeze({
	LifeTime = 10,
	Size = Vector3.new(3,5,3),
	Cframe = CFrame.new(0,5,0),
	Shape = "Box",
	HitMode = "Once",
	Cooldown = 0,
	Visualize = RunService:IsStudio(),
	MaxHits = 10
})

--|| Utility functions || This function draws a hitbox for debugging purposes
function Local.VisualizeHitBox(Config: CoreHitBox) : HandleAdornment
	local shape = Config.Shape or Local.Constants.Shape
	local size = Config.Size or Local.Constants.Size

	local HitBox: HandleAdornment
	if shape == "Sphere" then
		local sphere = Instance.new("SphereHandleAdornment")
		sphere.Radius = math.max(size.X, size.Y, size.Z) / 2
		HitBox = sphere
	elseif shape == "Cylinder" then
		local cylinder = Instance.new("CylinderHandleAdornment")
		cylinder.Height = size.Y
		cylinder.Radius = math.max(size.X, size.Z) / 2
		HitBox = cylinder
	else
		local box = Instance.new("BoxHandleAdornment")
		box.Size = size
		HitBox = box
	end

	HitBox.Parent = workspace.Terrain
	HitBox.Adornee = workspace.Terrain
	HitBox.Transparency = 0.5
	HitBox.Color3 = Color3.new(1, 0, 0)
	HitBox.CFrame = Config.CFrame or Local.Constants.Cframe
	HitBox.AlwaysOnTop = true

	return HitBox
end

--|| Setup events || setup hitbox events, similar to | .Touched | .Destroyed
function Local.SetupEvents(self: HitBoxInstance)
	self.Janitor:Add(self.OnStart, "DisconnectAll")
	self.Janitor:Add(self.OnEnd, "DisconnectAll")
	self.Janitor:Add(self.OnHit, "DisconnectAll")

	self.OnStart:Connect(function()
		print("Started")
	end)

	self.OnEnd:Connect(function()
		if self.Visual then
			self.Visual:Destroy()
			self.Visual = nil
		end
	end)

	self.OnHit:Connect(function()
		print("Hit")
	end)
end

--|| Detection || This function uses :GetpartsBoundsInBox And :GetPartBoundsInRadius
-- This prevents the hitbox from not detecting parts that deosnt move or barely move
function Local.GetTargets(self: HitBoxInstance)
	local rawParts = {}
	local Humanoids = {}

	if self.Shape == "Sphere" then
		local radius = math.max(self.Size.X, self.Size.Y, self.Size.Z) / 2
		rawParts = workspace:GetPartBoundsInRadius(self.CFrame.Position, radius, self.Params)

	elseif self.Shape == "Box" then
		rawParts = workspace:GetPartBoundsInBox(self.CFrame, self.Size, self.Params)

	else
		local queryPart = self.queryPart
		if not queryPart then
			queryPart = Instance.new("Part")
			queryPart.Anchored = true
			queryPart.CanCollide = false
			queryPart.CanQuery = false
			queryPart.CanTouch = false
			queryPart.Transparency = 1
			queryPart.Parent = workspace

			self.queryPart = queryPart
			self.Janitor:Add(queryPart, "Destroy")
		end

		queryPart.Size = self.Size
		queryPart.CFrame = self.CFrame

		if self.Shape == "Cylinder" then
			queryPart.Shape = Enum.PartType.Cylinder
		elseif self.Shape == "Capsule" or self.Shape == "Cone" then
			queryPart.Shape = Enum.PartType.Block
		end

		rawParts = workspace:GetPartsInPart(queryPart, self.Params)
	end

	for _, part in rawParts do
		local humanoid = part.Parent:FindFirstChildOfClass("Humanoid")
		if humanoid and not table.find(Humanoids, part) then
			table.insert(Humanoids, part)
		end
	end

	return Humanoids
end

--|| Start || This function is called to start the hitbox and create a hitbox instance
function Shared.new(Config: CoreHitBox): HitBoxInstance
	local self = setmetatable({}, Shared)

	self.Janitor = Janitor.new()
	self.Config = Config

	self.Size = Config.Size or Local.Constants.Size
	self.CFrame = Config.CFrame or Local.Constants.Cframe
	self.Shape = Config.Shape or Local.Constants.Shape
	self.Visualize = if Config.Visualize ~= nil then Config.Visualize else Local.Constants.Visualize
	self.LifeTime = Config.LifeTime or Local.Constants.LifeTime
	self.Params = OverlapParams.new()
	
	self.HitMode = Config.HitMode or Local.Constants.HitMode
	self.MaxHits = Local.Constants.MaxHits
	self.CurrentHitsAmount = 0

	self.OnHit = GoodSignal.new()
	self.OnStart = GoodSignal.new()
	self.OnEnd = GoodSignal.new()

	self.Visual = nil

	return self :: HitBoxInstance
end

--|| CFrame adjustment || This Function is called to adjust the CFrame of the hitbox
function Shared:AdjustCFrame(CFrame: CFrame)
	self.CFrame = CFrame
	if self.Visual then
		self.Visual.CFrame = CFrame
		self.CFrame = CFrame
	end
end

--|| Params || This function is called to take the ignore list or OverlapParams
function Shared:SetParams(Params: OverlapParams)
	self.Params = Params
end

--|| Size || This function is called to adjust the size of the hitbox
function Shared:AdjustSize(Size: Vector3)
	self.Size = Size
	if self.Visual then
		if self.Visual:IsA("BoxHandleAdornment") then
			self.Visual.Size = Size
		elseif self.Visual:IsA("SphereHandleAdornment") then
			self.Visual.Radius = math.max(Size.X, Size.Y, Size.Z) / 2
		elseif self.Visual:IsA("CylinderHandleAdornment") then
			self.Visual.Height = Size.Y
			self.Visual.Radius = math.max(Size.X, Size.Z) / 2
		end
	end
end

--|| Detection || This function is called to set a specific amount of hits before the hitbox stops
function Shared:SetMaxHits(Hits: number)
	self.MaxHits = Hits
end

--|| CFrame || This function is called to link the hitbox with another part that has 'CFrame' property
function Shared:LinkToObject(Object: BasePart, CFramee: CFrame?)
	if Object then
		self.Janitor:Add(RunService.Heartbeat:Connect(function()
			local newCFrame = if CFramee then Object.CFrame * CFramee else Object.CFrame
			self:AdjustCFrame(newCFrame)
		end))
	end
end

--|| AutoStop || This function is called to link Stop() Event to another part's Destroyed event
function Shared:LinkDestroyedTo(Instance: Instance)
	self.Janitor:Add(Instance.Destroying:Connect(function()
		self:Stop()
	end))
end

--|| Starting || Starting the hitbox and all the events
function Shared:Start()
	if self.Visualize then
		self.Visual = Local.VisualizeHitBox(self.Config)
	end
	Local.SetupEvents(self)
	self.OnStart:Fire()

	if self.LifeTime then
		self.Janitor:Add(task.delay(self.LifeTime, function()
			self:Stop()
		end))
	end
	
	-- Running the function multiple times and firing OnHit with the humanoids inside the box
	-- Shared:GetTargets() Can be used to get the humanoids inside the box 1 time
	self.Janitor:Add(RunService.Heartbeat:Connect(function()
		local Humanoids = self:GetTargets()
		if self.CurrentHitsAmount >= self.MaxHits then
			self:Stop()
			return
		end
		if self.HitMode == "Once" and Humanoids[1] then
			self.OnHit:Fire(Humanoids[1])
			self:Stop()
		elseif self.HitMode == "Multiple" and Humanoids[1] then
			self.CurrentHitsAmount += #Humanoids
			self.OnHit:Fire(Humanoids)
		end
	end))
end

--|| Stopping || Stopping the hitbox and disconnecting all events
function Shared:Stop()
	self.OnEnd:Fire()
	self.Janitor:Cleanup()
end
--|| GetTargets || Returns a table of humanoids inside the hitbox
function Shared:GetTargets()
	return Local.GetTargets(self)
end

return Shared
