{ inputs, ... }:
{
  perSystem = { system, ... }: {
    packages.nvim = inputs.nixvim.legacyPackages.${system}.makeNixvim {
      vimAlias = true;
      colorschemes.ayu = {
        enable = true;
        settings.overrides = {
          EoLSpace = { bg = "#883333"; };
        };
      };
      globals.mapleader = " ";
      opts = {
        mouse = "a";
        number = true;
        shiftwidth = 2;
        # undo stuff
        undofile = {};
        undolevels = 10000;
        undoreload = 10000;
        listchars = "tab:⇥ ,extends:❯,precedes:❮,nbsp:␣,trail:·,eol:↲";
      };
      extraConfigVim = ''
        set et

        " show special characters
        set list

        " match trailing whitespace
        match EoLSpace /\s\+$/

        " need to use lua to expand $HOME
        lua vim.o.undodir = vim.fs.normalize('$HOME/.vim/undodir')
      '';
      keymaps = [
        { mode = "n"; key = "<C-c>"; action = ":q<cr>"; }
        { mode = "n"; key = "<Space>"; action = "<Nop>"; }
        { mode = "n"; key = "<leader>u"; action = ":UndotreeToggle<cr>"; }
        { mode = "n"; key = "<leader>cd"; action = ":colorscheme ayu-dark<cr>"; }
        { mode = "n"; key = "<leader>cw"; action = ":colorscheme ayu-light<cr>"; }
      ];
      plugins.web-devicons.enable = true;
      plugins.telescope = {
        enable = true;
        keymaps = {
          "<leader>f" = "find_files";
          "<leader>g" = "live_grep";
          "<leader>b" = "buffers";
          "<leader>h" = "help_tags";
        };
      };
      plugins.lsp = {
        enable = true;
        servers = {
          bashls.enable = true; # bash
          nixd.enable = true; # nix
          ruff-lsp.enable = true; # python
        };
      };
      plugins.undotree.enable = true;
      plugins.treesitter.enable = true;
      plugins.copilot-cmp.enable = true;
      plugins.copilot-lua.panel.enabled = false;
      plugins.copilot-lua.suggestion.enabled = false;
      plugins.luasnip.enable = true;
      plugins.cmp = {
        enable = true;
        autoEnableSources = true;
        settings = {
          autoEnableSources = true;
          experimental = { ghost_text = true; };
          performance = {
            debounce = 60;
            fetchingTimeout = 200;
            maxViewEntries = 30;
          };
          snippet = { expand = "luasnip"; };
          formatting = { fields = [ "kind" "abbr" "menu" ]; };
          sources = [
            { name = "nvim_lsp"; }
            { name = "emoji"; }
            {
              name = "buffer"; # text within current buffer
              option.get_bufnrs.__raw = "vim.api.nvim_list_bufs";
              keywordLength = 3;
            }
            {
              name = "copilot"; # enable/disable copilot
            }
            {
              name = "path"; # file system paths
              keywordLength = 3;
            }
            {
              name = "luasnip"; # snippets
              keywordLength = 3;
            }
          ];

          window = {
            completion = { border = "solid"; };
            documentation = { border = "solid"; };
          };

          mapping = {
            "<Tab>" = "cmp.mapping.select_next_item()";
            "<S-Tab>" = "cmp.mapping.select_prev_item()";
            "<C-e>" = "cmp.mapping.abort()";
            "<C-b>" = "cmp.mapping.scroll_docs(-4)";
            "<C-f>" = "cmp.mapping.scroll_docs(4)";
            "<C-Space>" = "cmp.mapping.complete()";
            "<CR>" = "cmp.mapping.confirm({ select = true })";
            "<S-CR>" = "cmp.mapping.confirm({ behavior = cmp.ConfirmBehavior.Replace, select = true })";
          };
        };
      };
      plugins.bufferline.enable = true;
      plugins.which-key.enable = true;
    };
  };
}
