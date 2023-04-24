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

		for k, v in pairs(data) do
			if k == "definitions" then
				self.load_definitions(v)
			elseif k == "paths" then
				self.load_paths(v)
			elseif k == "parameters" then
				self.load_parameters(v)
			end
		end
	end,
}

function M.load_parameters(nodes)
	local parameters = {}
	for k, v in pairs(nodes) do
		local name = tostring(k)
		local parameter = M.get_parameter(name, v)
		if not parameter then
			vim.api.nvim_err_writeln("error parsing parameter" .. name)
			return nil
		end
		if parameters[name] then
			vim.api.nvim_err_writeln("duplicate parameter: " .. name)
			vim.print(parameters.name)
			return nil
		end
		parameters[name] = parameter
	end

	M.collect.parameters = parameters
end

function M.load_paths(nodes)
	local paths = {}
	for k, v in pairs(nodes) do
		local name = tostring(k)
		local sub_paths = M.get_paths(name, v)
		if not sub_paths then
			vim.api.nvim_err_writeln("error parsing path" .. name)
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

function M.get_paths(name, node)
	local paths = {}
	for k, v in pairs(node) do
		local method = M.collect.valid_method(tostring(k))
		if not method then
			goto continue
		end
		local path = M.get_path(name, method, v)
		if not path then
			vim.api.nvim_err_writeln("error parsing path " .. method .. " " .. name)
			return nil
		end
		table.insert(paths, path)
		::continue::
	end

	return paths
end

function M.get_item(name, node)
	local type = M.get_type(node)
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

	if type == M.collect.types.OBJECT and node.properties then
		local properties = {}
		for property_name, property in pairs(node.properties) do
			local sub_item = M.get_item(property_name, property)
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
		local name = tostring(k)
		local item = M.get_item(name, v)
		if not item then
			vim.api.nvim_err_writeln("error parsing item" .. name)
			return nil
		end
		if defs[name] then
			vim.api.nvim_err_writeln("duplicate definition: " .. name)
			return nil
		end
		defs[name] = item
	end

	M.collect.definitions = defs
end

function M.get_parameter(name, node)
	local parameter = {}
	parameter["in"] = node["in"]

	local item
	if node.schema then
		item = M.get_item(name, node.schema)
	else
		item = M.get_item(name, node)
	end

	parameter.item = item
	return parameter
end

function M.get_path(name, method, node)
	local path = {
		name = name,
		method = method,
		summary = node.summary,
	}

	return path
end

return M
