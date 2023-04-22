local function get_type(collect, node)
	local type = node.type or nil -- collect.valid_type(node.type)
	if not type then
		if node.properties then
			type = collect.types.OBJECT
		elseif node.items then
			type = collect.types.ARRAY
		elseif node["$ref"] then
			-- TODO: make sure that we only reference objects not other types.
			type = collect.types.OBJECT
		else
			return nil
		end
	end

	if type == "integer" then
		type = collect.types.NUMBER
	end

	return collect.valid_type(type)
end

local function get_item(collect, name, node)
	local type = get_type(collect, node)
	if not type then
		vim.api.nvim_err_writeln("undefined type for " .. name)
		return nil
	end

	local item = {
		name = name,
		type = type,
	}

	-- optionals
	local desc = node.description or nil
	if desc then
		desc = string.gsub(desc, "\n.*", "...")
		item.desc = desc
	end

	if type == collect.types.OBJECT and node.properties then
		local properties = {}
		for property_name, property in pairs(node.properties) do
			local sub_item = get_item(collect, property_name, property)
			if not sub_item then
				vim.api.nvim_err_writeln("error parsing property" .. property_name)
				return nil
			end
			sub_item.name = property_name
			properties[property_name] = sub_item
		end
		item.properties = properties
	end

	local ref = node["$ref"] or nil
	if ref then
		local match = string.match(ref, "#/definitions/(%w+)")
		item.ref = match
	end

	return item
end

local function load_definitions(collect, nodes)
	local defs = {}
	for k, v in pairs(nodes) do
		local name = tostring(k)
		local item = get_item(collect, name, v)
		if not item then
			vim.api.nvim_err_writeln("error parsing item" .. name)
			return nil
		end
		if defs[name] then
			vim.api.nvim_err_writeln("duplicate definition: " .. name)
			vim.print(defs.name)
			return nil
		end
		defs[name] = item
	end

	collect.definitions = defs
end

local function load_paths(collect, nodes) end

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
			elseif k == "paths" then
				load_paths(opts.collect, v)
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
