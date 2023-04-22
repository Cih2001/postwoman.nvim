local M = {
	-- list of other possible types and formats
	-- https://swagger.io/docs/specification/data-models/data-types/
	types = {
		STRING = "string",
		NUMBER = "number",
		BOOLEAN = "boolean",
		ARRAY = "array",
		OBJECT = "object",
	},
	-- item {
	--  ref  = "DEFINITION_NAME"  -- optional
	--
	--  or
	--
	--  name = "name"
	--  type = "Type"
	--  desc = "Description"            -- optional
	--  properties = { Name = {item} }  -- only for objects
	--  required = bool                 -- optional
	--  items = { {item} }              -- only for arrays
	-- }
	definitions = {
		-- Name = { item }
	},
	methods = {
		GET = "get",
		POST = "post",
		PUT = "put",
		PATCH = "patch",
		DELETE = "delete",
	},
	paths = {
		-- Path = {
		--  {
		--    path = "Path",
		--    method = "Method"
		--  }
		-- }
	},
}

function M.valid_type(type)
	if not type then
		return nil
	end

	for _, t in pairs(M.types) do
		if t == type then
			return t
		end
	end

	return nil
end

function M.setup(opts)
	if not opts.importer then
		vim.api.nvim_err_writeln("importer not set")
		return nil
	end

	local path = opts.path or nil
	opts.importer.setup({
		collect = M,
		path = path,
	})

	return M
end

return M
