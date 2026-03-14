--[[
Archivist - Data management service for WoW Addons
Written in 2019 by Allen Faure (emptyrivers) afaure6@gmail.com

To the extent possible under law, the author(s) have dedicated all copyright and related and neighboring rights to this software to the public domain worldwide.
This software is distributed without any warranty.
You should have received a copy of the CC0 Public Domain Dedication along with this software.
If not, see http://creativecommons.org/publicdomain/zero/1.0/.
]]

local embedder, namespace = ...
local addonName, Archivist = "Archivist", {}

do -- boilerplate, static values, automatic unloader
	Archivist.buildDate = "@build-time@"
	Archivist.version = "v2.0.2"
	Archivist.internalVersion = 1
	Archivist.archives = {}
	Archivist.migrations = {}
	Archivist.defaultStoreTypes = {}
	namespace.Archivist = Archivist
	local unloader = CreateFrame("FRAME")
	unloader:RegisterEvent("PLAYER_LOGOUT")
	unloader:SetScript("OnEvent", function()
		for _, archive in pairs(Archivist.archives) do
			Archivist:DeInitialize(archive)
		end
	end)
	if embedder == addonName then
		-- Archivist is installed as a standalone addon.
		-- The Archive is in the default location, ACHV_DB
		local loader = CreateFrame("FRAME")
		loader:RegisterEvent("ADDON_LOADED")
		loader:SetScript("OnEvent", function(self, _, addon)
			if addon == addonName then
				if type(ACHV_DB) ~= "table" then
					ACHV_DB = {}
				end
				_G.Archivist = Archivist(ACHV_DB)
				_G.ACV = Archivist -- so that standalone users can play with multi-archive mode
				self:UnregisterEvent("ADDON_LOADED")
			end
		end)
	end
end

setmetatable(Archivist, {__call = function(...) return Archivist:Initialize(...) end})
function Archivist:Assert(valid, pattern, ...)
	if not valid then
		if pattern then
		error(pattern:format(...), 2)
		else
		error("Archivist encountered an unknown error.", 2)
		end
	end
end

function Archivist:Warn(valid, pattern, ...) -- Like assert, but doesn't interrupt execution
	if not valid and self.debug then
		if pattern then
			print(pattern:format(...), 2)
		else
			print("Archivist encountered an unknown warning.")
		end
		return true
	end
end

local serializeConfig = {
	errorOnUnserializableType = false
}

-- prototype used to create archives
local proto = {}
Archivist.proto = proto

proto.Assert = Archivist.Assert
proto.Warn = Archivist.Warn

do -- function Archive:GenerateID()
	-- adapted from https://gist.github.com/jrus/3197011
	local function randomHex()
		return ('%x'):format(math.random(0, 0xf))
	end

	function proto:GenerateID()
		local template ='xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx'
		return (template:gsub('x', randomHex))
	end
end

function Archivist:IsInitialized(sv)
	return self.archives[sv] ~= nil
end

-- Create an archivist instance. Called automatically, unless Archivist has been embedded.
-- If called with an already initialized savedvariables table, then the previously initialized instance is returned.
function Archivist:Initialize(sv, prototypes)
	do -- arg validation
		self:Assert(type(sv) == "table", "Invalid argument #1 to Initialize, expected table but got %q.", type(sv))
		self:Assert(type(sv.internalVersion) ~= "number" or sv.internalVersion <= self.internalVersion, "Invalid argument #1 to Initialize, savedvariable is encoded using a newer version of Archivist. Please upgrade this installation if possible.")
		self:Assert(prototypes == nil or type(prototypes) == "table", "Invalid argument #2 to Initialize, expected table or nil but got %q", type(prototypes))
	end
	if self:IsInitialized(sv) then
		return self.archives[sv]
	end
	if type(sv.stores) ~= "table" then
		sv.stores = {}
	end
	local archive = setmetatable({
		prototypes = {},
		activeStores = {},
		storeMap = {},
		sv = sv,
		initialized = true,
	}, {
		__index = proto
	})
	if type(sv.internalVersion) ~= "number" or sv.internalVersion < self.internalVersion then
		self:DoMigration(archive)
	end
	self.archives[sv] = archive
	for _, prototype in pairs(self.defaultStoreTypes) do
		archive:RegisterStoreType(prototype)
	end
	if prototypes then
		for _, prototype in pairs(prototypes) do
			archive:RegisterStoreType(prototype)
		end
	end
	return archive
end

-- register a migration to upgrade archivist version
function Archivist:RegisterMigration(version, migration)
	do -- arg validation
		self:Assert(type(version) == "number" and version <= self.internalVersion and version % 1 == 0, "Migration version should be valid integer")
		self:Assert(self.migrations[version] == nil, "Migration %d already exists.", version)
		self:Assert(type(migration) == "function", "Migration should be a function")
	end
	self.migrations[version] = migration
end

function Archivist:DoMigration(archive)
	for i = (archive.sv.internalVersion or 0) + 1, self.internalVersion do
		if self.migrations[i] then
			self.migrations[i](archive)
		end
		archive.sv.internalVersion = i
	end
end

-- also make Initialize available via __call
setmetatable(Archivist, {
	__call = function(self, sv, prototypes) return self:Initialize(sv, prototypes) end
})

-- Shut Archivist instance down
function Archivist:DeInitialize(archive)
	if self.archives[archive.sv] == archive then
		archive.initialized = false
		archive:CloseAllStores()
		self.archives[archive.sv] = nil
		archive.sv = nil
	end
end

local function checkPrototype(prototype)
	Archivist:Assert(type(prototype) == "table", "Invalid argument #1 to RegisterStoreType: Expected table, got %q instead.", type(prototype))
	Archivist:Assert(type(prototype.id) == "string", "Invalid prototype field 'id': Expected string, got %q instead.", type(prototype.id))
	Archivist:Assert(type(prototype.version) == "number", "Invalid prototype field 'version': Expected number, got %q instead.", type(prototype.version))
	if Archivist:Warn(prototype.version > 0 and prototype.version == math.floor(prototype.version),
		"Prototype %q version expected to be a positive integer, but got %d instead.", prototype.id, prototype.version) then
		return
	end
	Archivist:Assert(prototype.Init == nil or type(prototype.Init) == "function", "Invalid prototype field 'Init': Expected function, got %q instead.", type(prototype.Init))
	Archivist:Assert(type(prototype.Create) == "function", "Invalid prototype field 'Create': Expected function, got %q instead.", type(prototype.Create))
	Archivist:Assert(type(prototype.Open) == "function", "Invalid prototype field 'Open': Expected function, got %q instead.", type(prototype.Open))
	Archivist:Assert(prototype.Update == nil or type(prototype.Update) == "function", "Invalid prototype field 'Update': Expected function, got %q instead.", type(prototype.Update))
	Archivist:Assert(type(prototype.Commit) == "function", "Invalid prototype field 'Commit': Expected function, got %q instead.", type(prototype.Commit))
	Archivist:Assert(type(prototype.Close) == "function", "Invalid prototype field 'Close': Expected function, got %q instead.", type(prototype.Close))
	Archivist:Assert(prototype.Delete == nil or type(prototype.Delete) == "function", "Invalid prototype field 'Delete': Expected function, got %q instead.", type(prototype.Delete))
	Archivist:Assert(prototype.Wind == nil or type(prototype.Wind) == "function", "Invalid prototype field 'Wind': Expected function, got %q instead.", type(prototype.Wind))
	Archivist:Assert(type(prototype.Wind) == type(prototype.Unwind), "Mismatched prototype fields 'Wind'/'Unwind': Expected nil/nil or function/function, got %q/%q instead.", type(prototype.Wind), type(prototype.Unwind))
end

-- Register a default store type, which is registered with all initialized archives simultaneously
-- prototype is required to be the same shape as with RegisterStoreType
-- Intended for internal use, but made available on the off chance that someone finds a use for this
function Archivist:RegisterDefaultStoreType(prototype)
	checkPrototype(prototype)

	local oldPrototype = self.defaultStoreTypes[prototype.id]
	local doRegister = not oldPrototype or prototype.version >= oldPrototype.version
	self:Assert(not oldPrototype or prototype.version >= oldPrototype.version, "Default store type %q already exists with a higher version", oldPrototype and oldPrototype.id)
	if not doRegister then return end

	self.defaultStoreTypes[prototype.id] = Mixin(prototype)
	for _, archive in pairs(self.archives) do
		archive:RegisterStoreType(prototype)
	end
end

-- register a store type with Archivist
-- prototype fields:
--  id - unique identifier. Preferably also a descriptive name e.g. "ReadOnly" or "RawData".
--  version - positive integer. Used for version control, in case any data migrations are needed. Registration will fail if the prototype is outdated.
--  Init - function (optional). If provided, executes exactly once per session, before any other methods are called.
--  Create - function (required). Create a brand new active store object.
--  Update - function (optional). Massage archived data into a format that Open can accept. Useful for data migrations.
--  Open - function (requried). Create from the provided data an active store object. Prototype may assume ownership of the provided data however it wishes.
--  Commit - function (required). Return an image of the data that should be archived.
--  Close - function (required). Release ownership of active store object. Optionally, return image of data to write into archive.
--  Delete - function (optional). If provided, called when a store is deleted. Useful for cleaning up sub stores.
--  Wind - function (optional). Winds an image into a format ready to be stored by Archivist. If provided, must also provide Unwind.
--  Unwind - function (optional). Unwinds data stored by Archivist into an image ready to be Opened. If provided, must also provide Wind.
-- Please note that Create, Open, Update, Commit, Close, Delete, Wind, Unwind may be called at any time if Archivist deems it necessary.
-- Thus, these methods should ideally be as close to purely functional as is practical, to minimize friction.
function proto:RegisterStoreType(prototype)
	checkPrototype(prototype)

	local oldPrototype = self.prototypes[prototype.id] -- need in case of closing active stores
	local doRegister = not oldPrototype or prototype.version >= oldPrototype.version
	self:Warn(doRegister, "Store type %q already exists with a higher version", oldPrototype and oldPrototype.id)
	if not doRegister then return end

	self.prototypes[prototype.id] = {
		id = prototype.id,
		version = prototype.version,
		Init = prototype.Init,
		Create = prototype.Create,
		Update = prototype.Update,
		Open = prototype.Open,
		Commit = prototype.Commit,
		Close = prototype.Close,
		Delete = prototype.Delete,
		Wind = prototype.Wind,
		Unwind = prototype.Unwind,
	}
	self.activeStores[prototype.id] = self.activeStores[prototype.id] or {}
	self.sv.stores[prototype.id] = self.sv.stores[prototype.id] or {}
	-- if prototype was previously registered, then there may be open stores of the old prototype.
	-- Close them, Update if necessary, then re-Open them with the new prototype.
	local toOpen = {}
	if oldPrototype then
		for storeId in pairs(self.activeStores[prototype.id]) do
			self:Close(prototype.id, storeId)
			toOpen[storeId] = true
		end
	end
	self.prototypes[prototype.id] = Mixin(prototype)
	if prototype.Init then
		prototype:Init()
	end
	for storeId in pairs(toOpen) do
		self:Open(prototype.id, storeId)
	end
end

-- produces storable data from image
function proto:Wind(storeType, image)
	do -- arg validation
		self:Assert(type(storeType) == "string" and self.prototypes[storeType], "Store type must be registered before winding data.")
	end

	if self.prototypes[storeType].Wind then
		return self.prototypes[storeType]:Wind(image)
	else
		return self:Archive(image)
	end
end

function proto:Unwind(storeType, woundImage)
	do -- arg validation
		self:Assert(type(storeType) == "string" and self.prototypes[storeType], "Store type must be registered before unwinding data.")
	end

	if self.prototypes[storeType].Unwind then
		return self.prototypes[storeType]:Unwind(woundImage)
	else
		return self:DeArchive(woundImage)
	end
end

-- creates and opens a new store of the given store type and with the given id (if given)
-- store objects are lightly managed by Archivist. On PLAYER_LOGOUT, all open stores are Closed,
-- and the resultant data is compressed into the archive.
function proto:Create(storeType, id, ...)
	do -- arg validation
		self:Assert(type(storeType) == "string" and self.prototypes[storeType], "Store type must be registered before loading data.")
		self:Assert(id == nil or type(id) == "string" and not self.sv.stores[storeType][id], "A store already exists with that id. Did you mean to call Archivist:Open?")
	end

	local store, image = self.prototypes[storeType]:Create(...)
	do -- ensure that store exists and is unique
		self:Assert(store ~= nil, "Failed to create a new store of type %q.", storeType)
		self:Assert(self.storeMap[store] == nil, "Store Type %q produced an store object already registered with Archivist instead of creating a new one.", storeType)
	end

	if id == nil then
		id = self:GenerateID()
	end

	self.activeStores[storeType][id] = store
	self.storeMap[store] = {
		id = id,
		prototype = self.prototypes[storeType],
		type = storeType
	}

	if image == nil then
		-- save initial image via Commit
		image = self.prototypes[storeType]:Commit(store)
	end
	self:Assert(image ~= nil, "Create Verb failed to generate initial image for archive.")
	self.sv.stores[storeType][id] = {
		timestamp = time(),
		version = self.prototypes[storeType].version,
		data = self:Wind(storeType, image)
	}

	return store, id
end

-- clones archived data and/or active store object to newId
-- if newId is not provided, then a random id will be generated
-- also provides an active store object of the cloned data if openStore is set
function proto:Clone(storeType, id, newId, openStore)
	do -- arg validation
		self:Assert(type(storeType) == "string" and self.prototypes[storeType], "Store type must be registered to clone a store.")
		self:Assert(type(id) == "string" and (self.sv.stores[storeType][id] or self.activeStores[storeType][id]), "Unable to clone store: store not found.")
	end

	if type(newId) ~= "string" then
		newId = self:GenerateID()
	end

	self:Assert(not self.sv.stores[storeType][newId], "Store with ID %q already exists. Choose a different ID.")
	if self.activeStores[storeType][id] then
		-- go ahead and commit active store
		self:Commit(storeType, id)
	end

	-- thankfully, strings are easy to copy
	self.sv.stores[storeType][newId] = {
		version = self.prototypes[storeType].version,
		timestamp = time(),
		data = self.sv.stores[storeType][id].data
	}
	if openStore then
		return self:Open(storeType, newId), newId
	else
		return nil, newId
	end
end

function proto:CloneStore(store, newId, openStore)
	self:Assert(self.storeMap[store], "Unrecognized store was provided.")
	local info = self.storeMap[store]
	return self:Clone(info.type, info.id, newId, openStore)
end

-- Closes store (if open), then deletes data from archive
-- Prototype is given opportunity to perform actions using image (usually, to delete other sub stores)
-- if store type is not registered, then force flag must be set in order to delete data,
-- to reduce the chance of accidents
function proto:Delete(storeType, id, force)
	do -- arg validation
		self:Warn(force or type(storeType == "string") and self.sv.stores[storeType], "There are no stores to delete.")
		self:Assert(force or self.prototypes[storeType], "Store type should be registered before deleting a store. Call Delete again with arg #3 == true to override this.")
	end

	if id and storeType and self.sv.stores[storeType] then
		if self.prototypes[storeType] and self.prototypes[storeType].Delete and self.sv.stores[storeType][id] then
			local image = self.activeStores[storeType][id]
						 and self:Close(self.activeStores[storeType][id])
						 or self:Unwind(storeType, self.sv.stores[storeType][id].data)
			self.prototypes[storeType]:Delete(image)
		end
		self.sv.stores[storeType][id] = nil
	end
end

function proto:DeleteStore(store)
	self:Assert(self.storeMap[store], "Unrecognized store was provided.")
	local info = self.storeMap[store]
	return self:Delete(info.type, info.id)
end

-- unpacks data in the archive into an active store object
-- if store is already active, then returns active store object
function proto:Open(storeType, id, ...)
	do -- arg validation
		self:Assert(type(storeType) == "string" and self.prototypes[storeType], "Store type must be registered before opening a store.")
		self:Assert(type(id) == "string" and (self.sv.stores[storeType][id] or self.activeStores[storeType][id]), "Could not find a store with that ID. Did you mean to call Archivist:Create?")
	end

	local store = self.activeStores[storeType][id]
	if not store then
		local saved = self.sv.stores[storeType][id]
		local data = self:Unwind(storeType, saved.data)
		local prototype = self.prototypes[storeType]
		-- migrate data...
		if prototype.Update and prototype.version > saved.version then
			local newData = prototype:Update(data, saved.version)
			if newData ~= nil then
				saved.data = self:Wind(storeType, newData)
				saved.timestamp = time()
			end
			saved.version = prototype.version
		end
		-- create store object...
		store = prototype:Open(data, ...)
		-- cache it so that we can close it later..
		self.activeStores[storeType][id] = store
		self.storeMap[store] = {
			id = id,
			prototype = self.prototypes[storeType],
			type = storeType
		}
	end
	return store
end

-- DANGEROUS FUNCTION
-- Your data will be lost. All of it. No going back.
-- Don't say I didn't warn you
function proto:DeleteAll(storeType)
	if storeType then
		self.sv.stores[storeType] = {}
		for id, store in pairs(self.activeStores[storeType]) do
			self.activeStores[storeType][id] = nil
			self.storeMap[store] = nil
		end
	else
		for id in pairs(self.sv.stores) do
			self.sv.stores[id] = {}
		end
		self.activeStores = {}
		self.storeMap = {}
	end
end

-- deactivates store, with one last opportunity to commit data if the prototype chooses to do so
function proto:Close(storeType, id)
	do -- arg validation
		self:Assert(type(storeType) == "string" and self.prototypes[storeType], "Closing a store of an unregistered store type doesn't make sense.")
		self:Warn(type(id) == "string" and self.activeStores[storeType][id], "No store with that ID can be found.")
	end

	local store = self.activeStores[storeType][id]
	local saved = self.sv.stores[storeType][id]
	if store then
		local image = self.prototypes[storeType]:Close(store)
		if image ~= nil then
			saved.data = self:Wind(storeType, image)
			saved.timestamp = time()
		end
		self.activeStores[storeType][id] = nil
		self.storeMap[store] = nil
	end
end

function proto:CloseStore(store)
	self:Assert(self.storeMap[store], "Unrecognized store was provided.")
	local info = self.storeMap[store]
	return self:Close(info.type, info.id)
end

function proto:CloseAllStores()
	for storeType, prototype in pairs(self.prototypes) do
		for id, store in pairs(self.activeStores[storeType]) do
			local image = prototype:Close(store)
			local saved = self.sv.stores[storeType][id]
			self.activeStores[storeType] = nil
			if image then
				saved.data = self:Wind(storeType,image)
				saved.timestamp = time()
			end
		end
	end
end

-- archives an image of the store object
function proto:Commit(storeType, id)
	do -- arg validation
		self:Assert(type(storeType) == "string" and self.prototypes[storeType], "Committing a store of an unregistered store type doesn't make sense.")
		self:Assert(type(id) == "string" and self.activeStores[storeType][id], "No store with that ID can be found.")
	end

	local store = self.activeStores[storeType][id]
	local image = self.prototypes[storeType]:Commit(store)
	local saved = self.sv.stores[storeType][id]
	if image ~= nil then
		saved.data = self:Wind(storeType, image)
		saved.timestamp = time()
	end
end

function proto:CommitStore(store)
	self:Assert(self.storeMap[store], "Unrecognized store was provided.")
	local info = self.storeMap[store]
	return self:Commit(info.type, info.id)
end

-- opens or creates a storeType, depending on what is appropriate
-- this is the main entry point for other addons who just want their saved data
function proto:Load(storeType, id, ...)
	do -- arg validation
		self:Assert(type(storeType) == "string" and self.prototypes[storeType], "Loading data from an unregistered store type doesn't make sense.")
		self:Assert(id == nil or type(id) == "string", "Store ID must be a string if provided.")
	end

	if id == nil or not self.sv.stores[storeType][id] then
		return self:Create(storeType, id, ...)
	elseif self.activeStores[storeType][id] then
		return self.activeStores[storeType][id]
	else
		return self:Open(storeType, id, ...)
	end
end

-- inspect archive to see if the requested store exists
-- guaranteed never to perform any prototype methods, or to (de)archive any data
-- useful when performance is important
function proto:Check(storeType, id)
	do -- arg validation
		self:Assert(type(storeType) == "string", "Expected string for storeType, got %q.", type(storeType))
		self:Assert(type(id) == "string", "Expected string for storeID, got %q.", type(id))
	end
	return self.sv.stores[storeType] and self.sv.stores[storeType][id]
end

do -- data compression
	local LibDeflate = LibStub("LibDeflate")
	local LibSerialize = LibStub("LibSerialize")

	function Archivist:Archive(data)
		local serialized = LibSerialize:SerializeEx(serializeConfig, data)
		local compressed = LibDeflate:CompressDeflate(serialized)
		local encoded = LibDeflate:EncodeForPrint(compressed)
		return encoded
	end
	proto.Archive = Archivist.Archive
	function Archivist:DeArchive(encoded)
		local compressed = LibDeflate:DecodeForPrint(encoded)
		local serialized = LibDeflate:DecompressDeflate(compressed)
		local success, data = LibSerialize:Deserialize(serialized)
		self:Assert(success, "Error when deserializing data: %q", data)
		return data
	end
	proto.DeArchive = Archivist.DeArchive
end
