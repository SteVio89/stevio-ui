local _, ns = ...

-- "Share settings" on the profile page: your own overrides (options, and on
-- request keys and game settings) as one line of text to pass on, and the
-- checks before such a text is taken over. The text is "!SUI1!" and the
-- Base64 of a small serialized table. Imported text is parsed, never run.
-- Kept free of WoW API calls (C_EncodingUtil is used when the client has
-- it) so it can be tested outside the game (tests/settings_share_test.lua).

local Overrides = ns.Overrides

local Share = {}
ns.SettingsShare = Share

Share.PREFIX = "!SUI1!"
Share.VERSION = 1

-- Serializing ------------------------------------------------------------------

-- Tables, strings, numbers and booleans as text: t ... e for a table (key,
-- value pairs in key order), s<length>:<bytes>, n<number>;, T and F.
local function Write(value, parts)
	local kind = type(value)
	if kind == "table" then
		parts[#parts + 1] = "t"
		local keys = {}
		for key in pairs(value) do
			keys[#keys + 1] = key
		end
		table.sort(keys, function(a, b)
			if type(a) ~= type(b) then
				return type(a) < type(b)
			end
			return a < b
		end)
		for _, key in ipairs(keys) do
			Write(key, parts)
			Write(value[key], parts)
		end
		parts[#parts + 1] = "e"
	elseif kind == "string" then
		parts[#parts + 1] = ("s%d:%s"):format(#value, value)
	elseif kind == "number" then
		parts[#parts + 1] = ("n%s;"):format(("%.17g"):format(value))
	elseif kind == "boolean" then
		parts[#parts + 1] = value and "T" or "F"
	else
		error("can't serialize a " .. kind)
	end
end

function Share.Serialize(value)
	local parts = {}
	Write(value, parts)
	return table.concat(parts)
end

-- Returns the value and the position after it, or nil and an error.
local Read
local MAX_DEPTH = 20

local function ReadTable(text, position, depth)
	if depth > MAX_DEPTH then
		return nil, "too deep"
	end
	local result = {}
	while true do
		local mark = text:sub(position, position)
		if mark == "e" then
			return result, position + 1
		elseif mark == "" then
			return nil, "unfinished table"
		end
		local key, value
		key, position = Read(text, position, depth)
		if key == nil then
			return nil, position
		end
		if type(key) ~= "string" and type(key) ~= "number" then
			return nil, "bad key"
		end
		value, position = Read(text, position, depth)
		if value == nil then
			return nil, position
		end
		result[key] = value
	end
end

function Read(text, position, depth)
	local mark = text:sub(position, position)
	if mark == "t" then
		return ReadTable(text, position + 1, depth + 1)
	elseif mark == "s" then
		local length, start = text:match("^(%d+):()", position + 1)
		length = tonumber(length)
		if not length or start + length - 1 > #text then
			return nil, "bad string"
		end
		return text:sub(start, start + length - 1), start + length
	elseif mark == "n" then
		local number, after = text:match("^([^;]+);()", position + 1)
		number = tonumber(number)
		if not number or number ~= number or number == math.huge or number == -math.huge then
			return nil, "bad number"
		end
		return number, after
	elseif mark == "T" then
		return true, position + 1
	elseif mark == "F" then
		return false, position + 1
	end
	return nil, "unknown mark"
end

-- The value of `text`, or nil and an error.
function Share.Deserialize(text)
	local value, position = Read(text, 1, 0)
	if value == nil then
		return nil, position
	end
	if position <= #text then
		return nil, "text after the value"
	end
	return value
end

-- Base64 ------------------------------------------------------------------------

local ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local INDEX = {}
for i = 1, #ALPHABET do
	INDEX[ALPHABET:sub(i, i)] = i - 1
end

local function EncodeBase64(data)
	local parts = {}
	for i = 1, #data, 3 do
		local a, b, c = data:byte(i, i + 2)
		local n = a * 65536 + (b or 0) * 256 + (c or 0)
		local chars = {}
		for shift = 3, 0, -1 do
			local index = math.floor(n / 64 ^ shift) % 64
			chars[#chars + 1] = ALPHABET:sub(index + 1, index + 1)
		end
		if not b then
			chars[3], chars[4] = "=", "="
		elseif not c then
			chars[4] = "="
		end
		parts[#parts + 1] = table.concat(chars)
	end
	return table.concat(parts)
end

local function DecodeBase64(text)
	text = text:gsub("%s", "")
	if #text % 4 ~= 0 or text:find("[^%w%+/=]") then
		return nil
	end
	local parts = {}
	for i = 1, #text, 4 do
		local chunk = text:sub(i, i + 3)
		local n, pad = 0, 0
		for j = 1, 4 do
			local char = chunk:sub(j, j)
			if char == "=" then
				pad = pad + 1
				n = n * 64
			else
				if pad > 0 then
					return nil
				end
				n = n * 64 + INDEX[char]
			end
		end
		local bytes = string.char(math.floor(n / 65536) % 256, math.floor(n / 256) % 256, n % 256)
		parts[#parts + 1] = bytes:sub(1, 3 - pad)
	end
	return table.concat(parts)
end

-- The client's Base64 when it has one (C_EncodingUtil), else the one above;
-- both write standard Base64, so either reads the other's text.
local function Encoder()
	local util = rawget(_G, "C_EncodingUtil")
	if util and util.EncodeBase64 and util.DecodeBase64 then
		return util.EncodeBase64,
			function(text)
				local ok, result = pcall(util.DecodeBase64, (text:gsub("%s", "")))
				return ok and result or nil
			end
	end
	return EncodeBase64, DecodeBase64
end

Share.EncodeBase64, Share.DecodeBase64 = EncodeBase64, DecodeBase64

-- Export ------------------------------------------------------------------------------

-- The text for `values` (encoded path -> value), and `bindings` and `cvars`
-- when given (nil leaves them out).
function Share.Export(values, bindings, cvars)
	local encode = Encoder()
	local payload = { v = Share.VERSION, values = values or {}, bindings = bindings, cvars = cvars }
	return Share.PREFIX .. encode(Share.Serialize(payload))
end

local function Count(map)
	local count = 0
	for _ in pairs(map or {}) do
		count = count + 1
	end
	return count
end

-- How many settings, keys and game settings a payload holds.
function Share.Counts(payload)
	return Count(payload.values), Count(payload.bindings), Count(payload.cvars)
end

-- "contains 4 settings, 1 key, 2 game settings"
function Share.Summary(values, bindings, cvars)
	local T = ns.T
	local parts = {}
	parts[#parts + 1] = values == 1 and T("1 setting", "1 Einstellung")
		or T("%d settings", "%d Einstellungen"):format(values)
	if bindings > 0 then
		parts[#parts + 1] = bindings == 1 and T("1 key", "1 Taste") or T("%d keys", "%d Tasten"):format(bindings)
	end
	if cvars > 0 then
		parts[#parts + 1] = cvars == 1 and T("1 game setting", "1 Spieleinstellung")
			or T("%d game settings", "%d Spieleinstellungen"):format(cvars)
	end
	return T("Contains %s", "Enthält %s"):format(table.concat(parts, ", "))
end

-- Import ------------------------------------------------------------------------------

local function IsColorLike(value)
	return ns.EditorModel.IsColor("color", value)
end

-- Whether `value` may replace `default`: the same kind of value, colours with
-- components between 0 and 1, lists as lists.
local function Fits(default, value)
	if type(default) ~= type(value) then
		return false
	end
	if type(default) ~= "table" then
		return true
	end
	if IsColorLike(default) then
		return IsColorLike(value) and #value == #default
	end
	if Overrides.IsList(default) ~= Overrides.IsList(value) then
		return false
	end
	if not Overrides.IsList(default) then
		-- A table saved as a whole: every key it has must fit.
		for key, inner in pairs(value) do
			if default[key] == nil or not Fits(default[key], inner) then
				return false
			end
		end
		return true
	end
	-- List entries take the kind of the default's entries.
	local sample = default[1]
	for _, entry in ipairs(value) do
		if sample ~= nil and not Fits(sample, entry) then
			return false
		end
		if type(entry) == "table" and sample == nil then
			return false
		end
	end
	return true
end

-- Checks an imported text. `ctx`: defaults (the code's roots), isIgnored(name)
-- for CVars, cvarExists(name) (optional). Returns nil and an error text, or
-- { values = { { path, encoded, value } }, bindings = { key = command|false },
-- cvars = { name = value }, skipped = { reasons } }.
function Share.Import(text, ctx)
	local T = ns.T
	text = (text or ""):gsub("^%s+", ""):gsub("%s+$", "")
	if text:sub(1, #Share.PREFIX) ~= Share.PREFIX then
		if text:find("^!SUI%d+!") then
			return nil, T("This text comes from a newer stevio-ui.", "Dieser Text stammt von einem neueren stevio-ui.")
		end
		return nil, T("This is not a stevio-ui settings text.", "Das ist kein stevio-ui-Einstellungstext.")
	end
	local _, decode = Encoder()
	local data = decode(text:sub(#Share.PREFIX + 1))
	local payload = data and Share.Deserialize(data)
	if type(payload) ~= "table" then
		return nil, T("The text is damaged or incomplete.", "Der Text ist beschädigt oder unvollständig.")
	end
	if payload.v ~= Share.VERSION then
		return nil,
			T(
				"This text comes from another stevio-ui version.",
				"Dieser Text stammt von einer anderen stevio-ui-Version."
			)
	end
	local result = { values = {}, bindings = {}, cvars = {}, skipped = {} }
	local function Skip(name, reason)
		result.skipped[#result.skipped + 1] = ("%s (%s)"):format(name, reason)
	end

	local encodedKeys = {}
	for encoded in pairs(type(payload.values) == "table" and payload.values or {}) do
		encodedKeys[#encodedKeys + 1] = tostring(encoded)
	end
	table.sort(encodedKeys)
	for _, encoded in ipairs(encodedKeys) do
		local value = payload.values[encoded]
		local path = Overrides.Decode(encoded)
		local default = (#path >= 2) and Overrides.Get(ctx.defaults, path) or nil
		if path[1] ~= "config" and path[1] ~= "layout" or default == nil then
			Skip(encoded, T("unknown", "unbekannt"))
		elseif ns.EditorModel.HIDDEN[Overrides.Encode(Overrides.Prefix(path, math.min(3, #path)))] then
			Skip(encoded, T("not shareable", "nicht teilbar"))
		elseif not Fits(default, value) then
			Skip(encoded, T("wrong kind of value", "falsche Art von Wert"))
		else
			result.values[#result.values + 1] = { path = path, encoded = encoded, value = value }
		end
	end

	for key, command in pairs(type(payload.bindings) == "table" and payload.bindings or {}) do
		if type(key) ~= "string" or not (type(command) == "string" or command == false) then
			Skip(tostring(key), T("bad key", "fehlerhafte Taste"))
		else
			result.bindings[key] = command
		end
	end

	for name, value in pairs(type(payload.cvars) == "table" and payload.cvars or {}) do
		if type(name) ~= "string" or type(value) ~= "string" or not name:match("^[%w_]+$") then
			Skip(tostring(name), T("bad game setting", "fehlerhafte Spieleinstellung"))
		elseif ctx.isIgnored(name) then
			Skip(name, T("not shareable", "nicht teilbar"))
		elseif ctx.cvarExists and not ctx.cvarExists(name) then
			Skip(name, T("unknown", "unbekannt"))
		else
			result.cvars[name] = value
		end
	end
	table.sort(result.skipped)
	return result
end
