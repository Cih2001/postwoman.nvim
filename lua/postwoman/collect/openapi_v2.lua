local function load_definitions(collect, nodes)
	local defs = {}
	for k, v in pairs(nodes) do
		table.insert(defs, {
			path = tostring(k),
		})
	end

	collect.definitions = defs
end

local M = {
	setup = function(opts)
		if not opts.path then
			vim.api.nvim_err_writeln("path not provided")
			return nil
		end
		if not opts.collect then
			vim.api.nvim_err_writeln("collect class is not set")
			return nil
		end

		local yaml = require("lyaml")
		local file = io.open(opts.path, "r")
		if not file then
			vim.api.nvim_err_writeln("Failed to open file: " .. opts.path)
			return nil
		end

		local data = yaml.load(file:read("*all"))
		file:close()

		for k, v in pairs(data) do
			if k == "definitions" then
				load_definitions(opts.collect, v)
			end
		end
	end,
}

-- local function yaml_to_tree()
-- 	local NuiTree = require("nui.tree")
-- 	local data = read_yaml_file()
--
-- 	local function recurse(node)
-- 		local nodes = {}
-- 		for k, v in pairs(node) do
-- 			local n
-- 			if type(v) ~= "table" then
-- 				local s = tostring(v)
-- 				s = string.gsub(s, "\n.*", "...")
-- 				n = NuiTree.Node({ text = tostring(k) .. ": " .. s })
-- 			else
-- 				n = NuiTree.Node({ text = tostring(k) }, recurse(v))
-- 			end
--
-- 			local inserted = false
-- 			for i, cur in ipairs(nodes) do
-- 				if n.text < cur.text then
-- 					table.insert(nodes, i, n)
-- 					inserted = true
-- 					break
-- 				end
-- 			end
-- 			if not inserted then
-- 				table.insert(nodes, n)
-- 			end
-- 		end
--
-- 		return nodes
-- 	end
--
-- 	return recurse(data)
-- end
--
return M
