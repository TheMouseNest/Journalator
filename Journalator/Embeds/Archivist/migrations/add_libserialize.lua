local Archivist = select(2, ...).Archivist

-- old deserialization code, here to extract data that we'll reserialize with LibSerialize
local escape2unused = {
	["\\"] = "\001",
	["&"] = "\002",
	[","] = "\003",
	["^"] = "\004",
	["@"] = "\005",
	["$"] = "\006",
	["#"] = "\007",
	[":"] = "\008",
}
local unused2Escape = tInvert(escape2unused)
local unused = "[\001-\008]"
local function unusify(c)
	return escape2unused[c] or c
end
local function escapify(c)
	return unused2Escape[c] or c
end
local function parse(value, objectList)
	local firstChar = value:sub(1,1)
	local remainder = value:sub(2)
	if firstChar == "@" then
		return true, "BOOL", remainder
	elseif firstChar == "$" then
		return false, "BOOL", remainder
	elseif firstChar == "#" then
		local num, rest = remainder:match("([^\\&,^@$#:]*)(.*)")
		return tonumber(num), "NUMBER", rest
	elseif firstChar == "^" then
		local str, rest = remainder:match("([^:^,]*)(.*)")
		local key = parse(str, objectList)
		return key, "KEY", rest
	elseif firstChar == ":" then
		local str, rest = remainder:match("([^:^,]*)(.*)")
		local val = parse(str, objectList)
		return val, "VALUE", rest
	elseif firstChar == "&" then
		local num, rest = remainder:match("([^\\&,^@$#:]*)(.*)")
		return objectList[tonumber(num)], "OBJECT", rest
	else
		local str, rest = value:match("([^\\&,^@$#:]*)(.*)")
		return str:gsub(unused, escapify), "STRING", rest
	end
end
local function deserialize(value)
	-- first, convert escaped magic characters to chars that we'll likely never find naturally
	value = value:gsub("\\([\\&,^@$#:])", unusify)
	-- then, split by comma to get a list of objects
	local serializedObjects = {}
	for piece in value:gmatch("([^,]*),") do
		table.insert(serializedObjects, piece)
	end
	local objects = {}
	-- create one empty object for each object in the list
	for i = 1, #serializedObjects - 1 do
		objects[i] = {}
	end
	for index = 1, #serializedObjects - 1 do
		local str = serializedObjects[index]
		local object = objects[index]
		local mode = "KEY"
		local key
		local newValue, valueType
		while #str > 0 do
			newValue, valueType, str = parse(str, objects)
			Archivist:Assert(valueType == mode, "Encountered unexpected token type while parsing object. Expected %q but got %q.", mode, valueType)
			if valueType == "KEY" then
				key = newValue
				mode = "VALUE"
			else
				mode = "KEY"
				object[key] = newValue
			end
		end
		Archivist:Assert(mode == "KEY", "Encountered end of serialized token unexpectedly.")
	end
	local deserialized, _, remainder = parse(serializedObjects[#serializedObjects], objects)
	Archivist:Assert(#remainder == 0, "Unexpected token at end of serialized string. Expected EOF, got %q.", remainder:sub(1,10))
	return deserialized
end

local LibDeflate = LibStub("LibDeflate")
Archivist:RegisterMigration(1, function(archive)
	-- move data one level down,
	-- so that we can add more data to the sv
	local data = {}
	for k, v in pairs(archive.sv) do
		if type(v) == "table" and k ~= "stores" and k ~= "internalVersion" then
			data[k] = v
			archive.sv[k] = nil
		end
	end
	archive.sv.stores = data
	-- and also re-encode data with LibSerialize
	for _, storeType in pairs(archive.sv.stores) do
		for _, saved in pairs(storeType) do
			local compressed = LibDeflate:DecodeForPrint(saved.data)
			local serialized = LibDeflate:DecompressDeflate(compressed)
			local image = deserialize(serialized)
			saved.data = Archivist:Archive(image)
			saved.timestamp = time()
		end
	end
end)
