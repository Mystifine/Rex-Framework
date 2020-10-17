--[[

Created By: Mystifine and EDmaster24

]]

--|| Localise
local Ipairs = ipairs
local Script = script
local Require = require
local Setmetatable = setmetatable
local Pcall = pcall
local Next = next
local Type = typeof
local Clock = os.clock
local Split = string.split
local Unpack = unpack

--|| Services ||--
local RunService = game:GetService("RunService")
local Players = game.Players
local ServerStorage = game.ServerStorage

--|| Variables ||--
local Server = RunService:IsServer()
local Client = RunService:IsClient()

local ReplicatorFunction = Script.RemoteFunctions.ReplicatorFunction
local ReplicatorEvent = Script.RemoteEvents.ReplicatorEvent

--|| Modules ||--
local Rex = {}
local CachedLibraries = {}
local Configurations = Require(Script.Data.Configurations)

--| Functions For Autofill from other scripts .-. they will get over written by unpack
-- SERVICES
function Rex:CreateService() end
function Rex:GetService() end
function Rex:AddFunctionToService() end
function Rex:GetServicesClientCallbacks() end
function Rex:GetAllServices() end

-- CLASSES
function Rex:CreateClass() end
function Rex:GetClass() end
function Rex:GetClassesClientCallbacks() end
function Rex:GetAllClasses() end

-- DATABAASES
function Rex:CreateDatabase() end
function Rex:GetDatabase() end
function Rex:GetAllDatabases() end
function Rex:DisconnectDatabaseTablePropertyChanged() end
function Rex:GetDatabaseTablePropertyChanged() end
function Rex:DetectChange() end
function Rex:ReplicateDatabase() end

--|| Private Functions
local function UnpackLibrary(Library)
	CachedLibraries[Library.Name] = Require(Library)	
	for Index, Function in Next, CachedLibraries[Library.Name] do
		if Type(Function) == "function" then
			Rex[Index] = Function
		end
	end
end

local function UnpackGlobals()
	for _, Module in Ipairs(Script.Globals:GetChildren()) do
		Rex[Module.Name] = Require(Module)
	end
end

local function WaitUntilLoaded()
	local Loaded = Server and Script.Data.ServerLoaded or Script.Data.ClientLoaded
	-- This will wait until Loaded is true
	while not Loaded.Value do
		RunService.Stepped:Wait()
	end
end

UnpackGlobals()
--| Unpack them libraries!
for _, Library in Ipairs(Script.Libraries:GetChildren()) do
	UnpackLibrary(Library)
	Rex.Print(Library.Name.." has been successfully loaded!")	
end

--| Other Functions 
function Rex:CreateShortcut(ShortcutId, Function)
	Rex[ShortcutId] = Function
end

function Rex:Start()
	if Server then
		--Rex:ReplicateDatabase()
		Script.Data.ServerLoaded.Value = true
		Rex.Print("Rex has been started :3 on the server UWU")
	elseif Client then
		Script.Data.ClientLoaded.Value = true
		Rex.Print("Rex has been started UWU on the client :3")
	end
end

-- RexUpdater Hooker
if Server then
	ReplicatorFunction.OnServerInvoke = function(Player)
		WaitUntilLoaded() -- We need to wait until everything is created 
		
		-- We need to compact the functions and services 
		local CompactedData = {
			Services = {},
			Classes = {},
			Databases = {},
		}
		
		local function CompactFunctions(Id, Data)
			local Functions = {}
			for FunctionName, _ in Next, Data do
				local Remote = Script.RemoteFunctions:FindFirstChild(Id.."."..FunctionName)
				Functions[FunctionName] = Remote
			end
			return Functions
		end
		
		--| Compact Services
		local Services = Rex:GetServicesClientCallbacks()
		for ServiceId, Functions in Next, Services do
			if not Script.Services:FindFirstChild(ServiceId) then
				CompactedData.Services[ServiceId] = CompactFunctions(ServiceId, Functions)
			end
		end
		
		--| Compact Databases
		local Databases = Rex:GetAllDatabases()
		for Database, Data in Next, Databases do
			if not Script.Databases:FindFirstChild(Database) then
				CompactedData.Databases[Database] = Data
			end
		end
		
		--| Compact Classes
		local Classes = Rex:GetClassesClientCallbacks()
		for Class, Functions in Next, Classes do
			if not Script.Classes:FindFirstChild(Class) then
				CompactedData.Classes[Class] = CompactFunctions(Class, Functions)
			end
		end
		return CompactedData
	end
	
	coroutine.resume(coroutine.create(function()
		while Configurations.AutoReplicateDatabase do
			RunService.Stepped:Wait()
			Rex:ReplicateDatabase()
		end
	end))
	
	coroutine.resume(coroutine.create(function()
		wait(30)
		if not Script.Data.ServerLoaded.Value then
			Rex.Warn("\nDid you forget to call Rex:Start() on the SERVER? It's been 30 seconds.\nDid you forget to call Rex:Start()? It's been 30 seconds\nDid you forget to call Rex:Start()? It's been 30 seconds.\nDid you forget to call Rex:Start()? It's been 30 seconds.\nDid you forget to call Rex:Start()? It's been 30 seconds.\nDid you forget to call Rex:Start()? It's been 30 seconds.")
		end
	end))
elseif Client then
	-- If we're on the client we're going to request for updates
	local Data = ReplicatorFunction:InvokeServer()
	
	local function CompactFunctions(Data)
		local Functions = {}
		for FunctionIndex, Remote in Next, Data do
			Functions[FunctionIndex] = function(...)
				return Remote:InvokeServer(...)
			end
		end
		return Functions
	end
	
	-- Accept data from the server 
	local TaskHandler = {
		--| Services
		NewService = function(ServiceId, Data)
			Rex:CreateService(ServiceId, CompactFunctions(Data))
		end,
		AddServiceFunction = function(ServiceId, FunctionIndex, Remote)
			Rex:AddFunctionToService(ServiceId, FunctionIndex, function(...)
				return Remote:InvokeServer(...)
			end)
		end,

		--| Classes 
		NewClass = function(ClassId, Data)
			Rex:CreateClass(ClassId, CompactFunctions(Data))
		end,
		AddClassFunction = function(ClassId, FunctionIndex, Remote)
			Rex:AddFunctionToClass(ClassId, FunctionIndex, function(...)
				return Remote:InvokeServer(...)
			end)
		end,

		--| Database 
		NewDatabase = function(DatabaseId, Data)
			Rex:CreateDatabase(DatabaseId, Data[1], false)
		end,
		UpdateDatabase = function(UpdatedData)
			local Databases = Rex:GetAllDatabases()
			Rex:DetectChange(Databases, UpdatedData)
			print(Databases, UpdatedData)
			for Index, Value in Next, UpdatedData do
				CachedLibraries.Databases[Index] = Value
			end
		end,
	}
	
	--| Unpack Services And Classes And Databases
	for ServiceId, Functions in Next, Data.Services do
		TaskHandler.NewService(ServiceId, Functions)
	end
	
	for ClassId, Functions in Next, Data.Classes do
		TaskHandler.NewClass(ClassId, Functions)
	end
	
	for Database, Data in Next, Data.Databases do
		TaskHandler.NewDatabase(Database, Data)
	end
	
	ReplicatorEvent.OnClientEvent:Connect(function(Task, ...)
		TaskHandler[Task](...)
	end)
	
	coroutine.resume(coroutine.create(function()
		wait(30)
		if not Script.Data.ClientLoaded.Value then
			Rex.Warn("\nDid you forget to call Rex:Start() on the CLIENT? It's been 30 seconds.\nDid you forget to call Rex:Start()? It's been 30 seconds\nDid you forget to call Rex:Start()? It's been 30 seconds.\nDid you forget to call Rex:Start()? It's been 30 seconds.\nDid you forget to call Rex:Start()? It's been 30 seconds.\nDid you forget to call Rex:Start()? It's been 30 seconds.")
		end
	end))
end

return Rex
