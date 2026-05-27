vim.cmd("colorscheme matugen")
vim.api.nvim_create_autocmd("Signal", {
    pattern = "SIGUSR1",
    command = "colorscheme matugen",
})
vim.api.nvim_set_hl( 0, "Normal", { bg = "none" })
