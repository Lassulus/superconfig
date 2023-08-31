return {
 -- Add the community repository of plugin specifications
 "AstroNvim/astrocommunity",
 -- example of imporing a plugin, comment out to use it or add your own
 -- available plugins can be found at https://github.com/AstroNvim/astrocommunity
 { import = "astrocommunity.colorscheme.gruvbox-nvim" },
 { import = "astrocommunity.completion.copilot-lua" },
 { import = "astrocommunity.completion.copilot-lua-cmp" },
 { import = "astrocommunity.project.project-nvim" },
 { import = "astrocommunity.pack.go" },
 { import = "astrocommunity.pack.bash" },
 { import = "astrocommunity.pack.python" },
 { import = "astrocommunity.pack.lua" },
 { import = "astrocommunity.pack.toml" },
 { import = "astrocommunity.pack.markdown" },
 { import = "astrocommunity.pack.rust" },
 { import = "astrocommunity.pack.yaml" },
 { import = "astrocommunity.pack.nix" },
 { import = "astrocommunity.terminal-integration.vim-tpipeline" },
 { import = "astrocommunity.editing-support.rainbow-delimiters-nvim" },
 { import = "astrocommunity.editing-support.auto-save-nvim" },
 { import = "astrocommunity.editing-support.chatgpt-nvim" },
 {
  "jackMort/ChatGPT.nvim",
  opts = {
   api_key_cmd = "rbw get openai-api-key",
  },
 },
}
