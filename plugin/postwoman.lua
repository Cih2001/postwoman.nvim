vim.api.nvim_create_user_command("Postwoman", function()
	require("postwoman").postwoman()
end, {})
