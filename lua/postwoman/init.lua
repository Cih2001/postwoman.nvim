local NuiTree = require("nui.tree")
local Split = require("nui.split")
local NuiLine = require("nui.line")

local M = {}
function M.setup(opts) end

local function get_item_properties(collect, item)
	if not item.type then
		return nil
	end

	if item.type ~= collect.types.Object then
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

local function get_definition_items(collect)
	local nodes = {}
	for _, def in pairs(collect.definitions) do
		local subs = {}
		table.insert(subs, NuiTree.Node({ text = "type: " .. def.type }))
		if def.type == collect.types.Object then
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
		NuiTree.Node({ text = "definitions" }, get_definition_items(collect)),
	}
end

function M.postwoman()
	local split = Split({
		relative = "win",
		position = "left",
		size = 70,
	})

	split:mount()

	-- quit
	split:map("n", "q", function()
		split:unmount()
	end, { noremap = true })

	local tree = NuiTree({
		winid = split.winid,
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

	local map_options = { noremap = true, nowait = true }

	-- print current node
	split:map("n", "<CR>", function()
		local node = tree:get_node()
		print(vim.inspect(node))
	end, map_options)

	-- collapse current node
	split:map("n", "h", function()
		local node = tree:get_node()

		if node:collapse() then
			tree:render()
		end
	end, map_options)

	-- collapse all nodes
	split:map("n", "H", function()
		local updated = false

		for _, node in pairs(tree.nodes.by_id) do
			updated = node:collapse() or updated
		end

		if updated then
			tree:render()
		end
	end, map_options)

	-- expand current node
	split:map("n", "l", function()
		local node = tree:get_node()

		if node:expand() then
			tree:render()
		end
	end, map_options)

	-- expand all nodes
	split:map("n", "L", function()
		local updated = false

		for _, node in pairs(tree.nodes.by_id) do
			updated = node:expand() or updated
		end

		if updated then
			tree:render()
		end
	end, map_options)

	-- add new node under current node
	split:map("n", "a", function()
		local node = tree:get_node()
		tree:add_node(
			NuiTree.Node({ text = "d" }, {
				NuiTree.Node({ text = "d-1" }),
			}),
			node:get_id()
		)
		tree:render()
	end, map_options)

	-- delete current node
	split:map("n", "d", function()
		local node = tree:get_node()
		tree:remove_node(node:get_id())
		tree:render()
	end, map_options)

	tree:render()
end

return M
