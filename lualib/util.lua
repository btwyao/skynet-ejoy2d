
local util = {}

math.randomseed(os.time())
math.random()
math.random()
math.random()

function util.randomN(n,lower,upper)
	assert(n <= upper + 1 - lower)
	local temp,ret = {},{}
	while n > 0 do
		local i = math.random(lower,upper)
		if not temp[i] then
			temp[i] = true
			table.insert(ret,i)
			n = n -1
		end
	end
	return ret
end

function util.random_tblN(tbl,n,start_pos,end_pos)
	if not start_pos or start_pos < 1 then start_pos = 1 end
	if not end_pos or end_pos > #tbl then end_pos = #tbl end

	local ret,tblN = {},util.randomN(n,start_pos,end_pos)
	for _,i in ipairs(tblN) do
		table.insert(ret,tbl[i])
	end

	return ret
end

function util.random_tblR(tbl)
	local total = 0
	for k,v in pairs(tbl) do
		total = total + v
	end

	local i,cnt = math.random(total),0
	for k,v in pairs(tbl) do
		cnt = cnt + v
		if cnt >= i then
			return k
		end
	end
end

function util.event_register(tbl,func)
	tbl.n = tbl.n + 1
	tbl[tbl.n] = func
	return tbl.n
end

function util.event_release(tbl,id)
	tbl[id] = nil
end

function util.event_handle(tbl,...)
	for _,func in pairs(tbl) do
		if type(func) == "function" then
			func(...)
		end
	end
end

return util
