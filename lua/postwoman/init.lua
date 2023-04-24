local NuiTree = require("nui.tree")
local NuiText = require("nui.text")
local NuiLine = require("nui.line")
local NuiSplit = require("nui.split")

local M = {}

-- get_item_properties retreives properties for items. Definitions are
-- made up of items. This will return tree nodes to be displayed
-- in the explorer.
local function get_item_properties(collect, item)
	if not item.type then
		return nil
	end

	if item.type ~= collect.types.OBJECT then
		return nil
	end

	if item.ref then
		for name, def in pairs(collect.definitions) do
			if item.ref == name then
				return get_item_properties(collect, def)
			end
		end

		vim.api.nvim_err_writeln("invalid reference: " .. item.name)
		return nil
	end

	if not item.properties then
		vim.api.nvim_err_writeln("item does not have properties: " .. item.name)
		return nil
	end

	local properties = {}
	for property_name, _ in pairs(item.properties) do
		table.insert(properties, NuiTree.Node({ text = "- " .. property_name }))
	end

	return properties
end

local function get_definitions(collect)
	local nodes = {}
	for _, def in pairs(collect.definitions) do
		local subs = {}
		table.insert(subs, NuiTree.Node({ text = "type: " .. def.type }))
		if def.type == collect.types.OBJECT then
			local properties = get_item_properties(collect, def)
			if not properties then
				vim.api.nvim_err_writeln("error getting item properties: " .. def.name)
				return nil
			end
			table.insert(subs, NuiTree.Node({ text = "properties" }, properties))
		end

		-- optionals
		if def.desc then
			table.insert(subs, NuiTree.Node({ text = "description: " .. def.desc }))
		end
		local n = NuiTree.Node({ text = def.name }, subs)

		local inserted = false
		for i, cur in ipairs(nodes) do
			if def.name < cur.text then
				table.insert(nodes, i, n)
				inserted = true
				break
			end
		end
		if not inserted then
			table.insert(nodes, n)
		end
	end

	return nodes
end

local function get_parameters(collect)
	local nodes = {}
	for _, parameter in pairs(collect.parameters) do
		local subs = {}
		table.insert(subs, NuiTree.Node({ text = "type: " .. parameter.item.type }))
		table.insert(subs, NuiTree.Node({ text = "in: " .. parameter["in"] }))

		if parameter.item.type == collect.types.OBJECT then
			local properties = get_item_properties(collect, parameter.item)
			if not properties then
				vim.api.nvim_err_writeln("error getting item properties: " .. parameter.item.name)
				return nil
			end
			table.insert(subs, NuiTree.Node({ text = "properties" }, properties))
		end

		local n = NuiTree.Node({ text = parameter.item.name }, subs)

		local inserted = false
		for i, cur in ipairs(nodes) do
			if parameter.item.name < cur.text then
				table.insert(nodes, i, n)
				inserted = true
				break
			end
		end
		if not inserted then
			table.insert(nodes, n)
		end
	end

	return nodes
end

local function get_method_highlight(method)
	if method == "get" then
		return "DiagnosticOk"
	elseif method == "post" then
		return "DiagnosticHint"
	elseif method == "put" or method == "patch" then
		return "DiagnosticWarn"
	elseif method == "delete" then
		return "DiagnosticError"
	end

	return "Normal"
end

local function get_paths(collect)
	local nodes = {}
	for _, path in pairs(collect.paths) do
		local subs = {}
		if path.summary then
			table.insert(subs, NuiTree.Node({ text = path.summary }))
		end

		local method = NuiText(string.format("%-6s ", path.method), get_method_highlight(path.method))
		local n = NuiTree.Node({
			text = NuiLine({
				method,
				NuiText(path.name),
			}),
			data = {
				name = path.name,
				method = path.method,
			},
		}, subs)

		local inserted = false
		for i, cur in ipairs(nodes) do
			if path.name < cur.data.name then
				table.insert(nodes, i, n)
				inserted = true
				break
			end
		end
		if not inserted then
			table.insert(nodes, n)
		end
	end

	return nodes
end

local function get_nodes()
	local collect = require("postwoman.collect").setup({
		importer = require("postwoman.collect.openapi2"),
		path = os.getenv("HOME") .. "/example.yaml",
	})
	if not collect then
		vim.api.nvim_err_writeln("could not initialize collect")
		return nil
	end

	return {
		NuiTree.Node({ text = "paths" }, get_paths(collect)),
		NuiTree.Node({ text = "definitions" }, get_definitions(collect)),
		NuiTree.Node({ text = "parameters" }, get_parameters(collect)),
	}
end

function M.postwoman()
	local explorer = NuiSplit({
		relative = "win",
		position = "left",
		size = 40,
	})
	local details = NuiSplit({
		relative = "win",
		position = "right",
		size = 40,
	})

	details:mount()
	local details_win = vim.api.nvim_get_current_win()
	explorer:mount()
	-- quit
	explorer:map("n", "<C-q>", function()
		explorer:unmount()
		layout:unmount()
	end, { noremap = true })

	local tree = NuiTree({
		winid = explorer.winid,
		nodes = get_nodes(),
		prepare_node = function(node)
			local line = NuiLine()
			line:append(string.rep("  ", node:get_depth() - 1))

			if node:has_children() then
				line:append(node:is_expanded() and " " or " ", "SpecialChar")
			else
				line:append("  ")
			end

			line:append(node.text)
			return line
		end,
	})

	explorer:map("n", "<Enter>", function()
		local node = tree:get_node()
		vim.api.nvim_set_current_win(details_win)

		local line = NuiLine()
		line:append(node.text, "@attribute")
		local bufnr, ns_id, linenr_start = 0, -1, 1
		line:render(bufnr, ns_id, linenr_start)
	end, { noremap = true })

	local map_options = { noremap = true, nowait = true }

	-- collapse current node
	explorer:map("n", "h", function()
		local node = tree:get_node()

		if node:collapse() then
			tree:render()
		end
	end, map_options)

	-- collapse all nodes
	explorer:map("n", "H", function()
		local updated = false

		for _, node in pairs(tree.nodes.by_id) do
			updated = node:collapse() or updated
		end

		if updated then
			tree:render()
		end
	end, map_options)

	-- expand current node
	explorer:map("n", "l", function()
		local node = tree:get_node()

		if node:expand() then
			tree:render()
		end
	end, map_options)

	-- expand all nodes
	explorer:map("n", "L", function()
		local updated = false

		for _, node in pairs(tree.nodes.by_id) do
			updated = node:expand() or updated
		end

		if updated then
			tree:render()
		end
	end, map_options)

	tree:render()
end

return M
