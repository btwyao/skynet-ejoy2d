local skynet = require "skynet"

skynet.start(function()
	print("Server start")
	skynet.monitor "simplemonitor"
--	local console = skynet.newservice("console")
--	skynet.newservice("renderer")
--	skynet.newservice("input_proc")
	skynet.newservice("window")
--	skynet.newservice("ejoy_test","1")

	local hall = skynet.newservice("design_interfclt","1")
	skynet.name("HALL", hall)

--	local mem = skynet.call(".launcher","lua","MEM")
--	for k,v in pairs(mem) do
--		print(k,v)
--	end
	skynet.exit()
end)
