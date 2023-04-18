vim.api.nvim_create_user_command("postwoman", function()
	require("postwoman").openyaml()
end, {})
