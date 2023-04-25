local M = {
	setup = function(self, opts)
		if not opts.path then
			vim.api.nvim_err_writeln("path not provided")
			return nil
		end
		if not opts.collect then
			vim.api.nvim_err_writeln("collect class is not set")
			return nil
		end

		self.collect = opts.collect

		local yaml = require("lyaml")
		local file = io.open(opts.path, "r")
		if not file then
			vim.api.nvim_err_writeln("Failed to open file: " .. opts.path)
			return nil
		end

		local data = yaml.load(file:read("*all"))
		file:close()

		-- order matters. parameters can ref to definitions
		-- and paths ref to parameters and definitions.
		self.load_definitions(data.definitions)
		self.load_parameters(data.parameters)
		self.load_paths(data.paths)
	end,
}

-- get_parameters reads a array of parameters, parse them
-- and returns them. Array of parameters are usually
-- found in the path.
-- Example:
--   - name: search
--     description: The search string.
--     type: string
--     in: query
function M.get_parameters(nodes)
	if not nodes then
		return nil
	end

	local parameters = {}
	for _, p in ipairs(nodes) do
		local item = M.get_item(nil, p)
		if not item then
			vim.api.nvim_err_writeln("error parsing parameter")
			return nil
		end
		if item.parameter_ref then
			item = M.collect.parameters[item.parameter_ref]
		end

		table.insert(parameters, item)
	end

	if parameters == {} then
		return nil
	end

	return parameters
end

function M.load_parameters(nodes)
	local parameters = {}
	for k, v in pairs(nodes) do
		local id = tostring(k)
		local parameter = M.get_parameter(id, v)
		if not parameter then
			vim.api.nvim_err_writeln("error parsing parameter" .. id)
			return nil
		end
		if parameters[id] then
			vim.api.nvim_err_writeln("duplicate parameter: " .. id)
			return nil
		end
		parameters[id] = parameter
	end

	M.collect.parameters = parameters
end

function M.load_paths(nodes)
	local paths = {}
	for k, v in pairs(nodes) do
		local id = tostring(k)
		local sub_paths = M.get_paths(id, v)
		if not sub_paths then
			vim.api.nvim_err_writeln("error parsing path" .. id)
			return nil
		end

		for _, path in ipairs(sub_paths) do
			local key = { path.name, path.method }
			if paths[key] then
				vim.api.nvim_err_writeln("duplicate path: " .. path.method .. " " .. path.name)
				return nil
			end

			paths[key] = path
		end
	end

	M.collect.paths = paths
end

function M.get_paths(id, node)
	local paths = {}
	for k, v in pairs(node) do
		local method = M.collect.valid_method(tostring(k))
		if not method then
			goto continue
		end
		local path = M.get_path(id, method, v)
		if not path then
			vim.api.nvim_err_writeln("error parsing path " .. method .. " " .. id)
			return nil
		end
		table.insert(paths, path)
		::continue::
	end

	-- TODO: for each path, add global parameters
	return paths
end

function M.get_item(id, node)
	local type = M.get_type(node)
	if not type then
		vim.api.nvim_err_writeln("undefined type for " .. tostring(id))
		return nil
	end

	local item = {
		id = id,
		name = node.name,
		type = type,
	}

	-- optionals
	local desc = node.description or nil
	if desc then
		desc = string.gsub(desc, "\n.*", "...")
		item.desc = desc
	end

	if type == M.collect.types.OBJECT and node.properties then
		local properties = {}
		for property_id, property in pairs(node.properties) do
			local sub_item = M.get_item(property_id, property)
			if not sub_item then
				vim.api.nvim_err_writeln("error parsing property" .. property_id)
				return nil
			end
			sub_item.name = property_id
			properties[property_id] = sub_item
		end
		item.properties = properties
	end

	local ref = node["$ref"] or nil
	if ref then
		local dmatch = string.match(ref, "#/definitions/(%w+)")
		item.definition_ref = dmatch

		local pmatch = string.match(ref, "#/parameters/(%w+)")
		item.parameter_ref = pmatch
	end

	item["in"] = node["in"]

	return item
end

function M.get_type(node)
	local type = node.type or nil -- collect.valid_type(node.type)
	if not type then
		if node.properties then
			type = M.collect.types.OBJECT
		elseif node.items then
			type = M.collect.types.ARRAY
		elseif node["$ref"] or node.schema then
			-- TODO: make sure that we only reference objects not other types.
			type = M.collect.types.OBJECT
		else
			return nil
		end
	end

	if type == "integer" then
		type = M.collect.types.NUMBER
	end

	return M.collect.valid_type(type)
end

function M.load_definitions(nodes)
	local defs = {}
	for k, v in pairs(nodes) do
		local id = tostring(k)
		local item = M.get_item(id, v)
		if not item then
			vim.api.nvim_err_writeln("error parsing item" .. id)
			return nil
		end
		if defs[id] then
			vim.api.nvim_err_writeln("duplicate definition: " .. id)
			return nil
		end
		defs[id] = item
	end

	M.collect.definitions = defs
end

function M.get_parameter(id, node)
	local item
	if node.schema then
		item = M.get_item(id, node.schema)
	else
		item = M.get_item(id, node)
	end
	item["in"] = node["in"]

	return item
end

function M.get_path(id, method, node)
	local path = {
		id = id,
		method = method,
		summary = node.summary,
	}

	if node.parameters then
		local parameters = M.get_parameters(node.parameters)
		if not parameters then
			vim.api.nvim_err_writeln("unable to get parameters for: " .. id)
			return nil
		end
		path.parameters = parameters
	end

	return path
end

return M
