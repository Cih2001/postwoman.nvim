local M = {
	definitions = {},
}

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
