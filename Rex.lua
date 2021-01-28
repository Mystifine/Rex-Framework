--[[

Rex is a framework created by Mystifine.

	[MODULE]: Modules are created on either server or client, they will always return a value to the client if
	a function is called from the client.
	
	[DATABASES]: Databases are created on either server or client. Databases are simply tables that automatically
	replicate to the CLIENT. Functions and methods will not replicates. You are free to create methods and functions
	on the Client.

]]

local Rex = {};

--|| RBX Services
local RunService = game:GetService("RunService");
local ReplicatedStorage = game.ReplicatedStorage;

--|| Variables
local Assets = script.Assets;
local Remotes = script.Remotes;
local Library = script.Library;
local Connections = script.Connections;
local PreinstalledAssets = script.PreinstalledAssets;
local ServerLoaded = Assets.ServerLoaded;
local ClientLoaded = Assets.ClientLoaded;
local Get = Remotes.Get;
local Send = Remotes.Send;

--[[
	These empty functions are so that the code editor for Roblox picks up these functions. 
	They will be overwritten automatically.
]]

--|| Local Functions
local function UnpackGlobals()
	local Children = PreinstalledAssets.Functions:GetChildren();
	for i = 1, #Children do
		local Child = Children[i];
		Rex[Child.Name] = require(Child);
	end
end

local function Unpack(Module)
	local Module = require(Module);
	for Index, Function in next, Module do
		Rex[Index] = Function;
	end
end

--|| Modules
function Rex:GetModule() end;
function Rex:GetAllModules() end;
function Rex:CreateModule() end;

--|| Databases
function Rex:GetDatabase() end;
function Rex:CreateDatabase() end;
function Rex:GetAllDatabases() end;
function Rex:Write() end;

function Rex:Start() 
	local Loaded = RunService:IsServer() and ServerLoaded or ClientLoaded
	Loaded.Value = true;
end;

UnpackGlobals();
Unpack(Library.Modules);
Unpack(Library.Databases);

local function RecursiveUpdate(Tbl1, Tbl2)
	-- Tbl1 is the one we want to update into;
	for Index, Value in next, Tbl2 do
		if Tbl1[Index] == nil then -- If the index doesn't exist we just make it
			Tbl1[Index] = Value;
		elseif type(Tbl1[Index]) == "table" and type(Value) == "table" then -- If it already exist and both values are tables we want to recursive update it
			RecursiveUpdate(Tbl1[Index], Value);
		else
			Tbl1[Index] = Value
		end
	end
	
	for Index, Value in next, Tbl1 do
		if Tbl2[Index] == nil then
			Tbl1[Index] = nil; -- Remove it
		end
	end
end

local function GetDataFrom(Table, Index, Timeout)
	if Table[Index] == nil then
		local Stamp = os.clock();
		while os.clock() - Stamp < Timeout do
			RunService.Stepped:Wait();
			if Table[Index] ~= nil then
				break
			end
		end
	end
	return Table[Index];
end

--|| Main
if RunService:IsClient() then
	local ClientFunctions = {}
	
	ClientFunctions.NewModule = function(ModuleId, CompactedData)
		local LocalFunctions = {};
		for FunctionIndex, RemoteFunction in next, CompactedData do
			LocalFunctions[FunctionIndex] = function(...)
				return RemoteFunction:InvokeServer(...)
			end
		end
		Rex:CreateModule(ModuleId, LocalFunctions)
	end;
	
	ClientFunctions.NewDatabase = function(Database, Data)
		Rex:CreateDatabase(Database, Data);
	end;
	
	ClientFunctions.UpdateDatabase = function(DB, List, Value)
		local ParentDirectory, Directory, LastIndex = nil, Rex:GetDatabase(DB), nil
		
		for i = 1, #List do
			ParentDirectory = Directory;
			Directory = Directory[List[i]] --GetDataFrom(Directory, List[i], 5);
			LastIndex = List[i];
		end
		local PreviousValue = Directory;
		
		--| Simulate Table.Remove
		if Value == nil and type(LastIndex) == "number" then
			table.remove(ParentDirectory, LastIndex);
		elseif type(Value) == "table" and type(Directory) == "table" then
			--| Add Into Table;
			RecursiveUpdate(Directory, Value);
		else
			ParentDirectory[LastIndex] = Value;
		end
		
		local Connections = RunService:IsServer() and Connections.ServerConnections or Connections.ClientConnections;
		local ListToStringIdentifier = tostring(List[1]);
		for i = 2, #List do
			local Value = List[i];
			ListToStringIdentifier = ListToStringIdentifier.."."..tostring(Value);
		end
		local Signal = Connections:FindFirstChild(ListToStringIdentifier)
		if Signal 
		and (type(PreviousValue) ~= "table"
		and type(Value) ~= "table" and PreviousValue ~= Value or type(PreviousValue) == "table" or type(Value) == "table") then
			Signal:Fire(PreviousValue, Value);
		end
	end;
	
	--| If Rex is required on the client;
	Send.OnClientEvent:Connect(function(Task, ...)
		if ClientFunctions[Task] then
			ClientFunctions[Task](...);
		end
	end);
	
	local ExistingModules, ExistingDatabases = Get:InvokeServer();
	for Service, Functions in next, ExistingModules do
		local LocalFunctions = {};
		for FunctionIndex, RemoteFunction in next, Functions do
			LocalFunctions[FunctionIndex] = function(...)
				return RemoteFunction:InvokeServer(...)
			end
		end
		Rex:CreateModule(Service, LocalFunctions)
	end;
	
	for Database, Data in next, ExistingDatabases do
		Rex:CreateDatabase(Database, Data);
	end;
elseif RunService:IsServer() then
	Get.OnServerInvoke = function(Player)
		local _, ModulesClientCallbacks = Rex:GetAllModules();
		local Databases = Rex:GetAllDatabases();
		return ModulesClientCallbacks, Databases 
	end
end

return Rex
