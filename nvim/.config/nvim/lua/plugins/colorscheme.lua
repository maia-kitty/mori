-- Neovim sets 'background' from the terminal's colors (Foot follows mori-theme);
-- pick the matching Everforest variant whenever it changes.
local function everforest()
  local name = vim.o.background == "light" and "base46-everforest_light" or "base46-everforest"
  if vim.g.colors_name ~= name then
    vim.cmd.colorscheme(name)
  end
end

vim.api.nvim_create_autocmd("OptionSet", { pattern = "background", callback = everforest })
-- OptionSet does not fire during startup, when the terminal reply may already be in.
vim.api.nvim_create_autocmd("VimEnter", { callback = everforest })

return {
  {
    "EdenEast/nightfox.nvim",
    lazy = false,
    priority = 1000,
  },
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = everforest,
    },
  },
}
