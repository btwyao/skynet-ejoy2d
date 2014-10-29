
local database = {
	explore = {},
	bag = {max_mount = 9999, cur_id = 0, items = {
--		{idx = 1000, amount = 1,},
--		{idx = 1005, amount = 1,},
--		{idx = 1006, amount = 1,},
--		{idx = 1027, amount = 1,},
--		{idx = 1028, amount = 1,},
--		{idx = 1029, amount = 1,},
--		{idx = 1030, amount = 1,},
--		{idx = 1601, amount = 1,},
--		{idx = 1602, amount = 1,},
--		{idx = 1603, amount = 1,},
--		{idx = 1604, amount = 1,},
--		{idx = 1605, amount = 1,},
	}}
}

local function query(db, key, ...)
	if key == nil then
		return db
	else
		return query(db[key], ...)
	end
end

local function update(db, key, value, ...)
	if select("#",...) == 0 then
		local ret = db[key]
		db[key] = value
		return ret
	else
		if db[key] == nil then
			db[key] = {}
		end
		return update(db[key], value, ...)
	end
end

function database.get(key, ...)
	local d = database[key]
	if d then
		return query(d, ...)
	end
end

function database.set(...)
	return update(database, ...)
end

return database

