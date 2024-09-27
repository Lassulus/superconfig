{ inputs, ... }:
{
  perSystem =
    { system, ... }:
    {
      packages.nvim = inputs.nixvim.legacyPackages.${system}.makeNixvim {
        vimAlias = true;
        colorschemes.ayu = {
          enable = true;
          settings.overrides = {
            EoLSpace = {
              bg = "#883333";
            };
          };
        };
        globals.mapleader = " ";
        opts = {
          mouse = "a";
          number = true;
          shiftwidth = 2;
          clipboard = "unnamedplus";
          # undo stuff
          undofile = { };
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
          {
            mode = "i";
            key = "<C-p>";
            action = "<Nop>";
          }
          {
            mode = "i";
            key = "<C-n>";
            action = "<Nop>";
          }
          {
            mode = "n";
            key = "<C-c>";
            action = ":q<cr>";
          }
          {
            mode = "n";
            key = "<Space>";
            action = "<Nop>";
          }
          {
            mode = "n";
            key = "<leader>u";
            action = ":UndotreeToggle<cr>";
          }
          {
            mode = "n";
            key = "<leader>sd";
            action = ":colorscheme ayu-dark<cr>";
          }
          {
            mode = "n";
            key = "<leader>sw";
            action = ":colorscheme ayu-light<cr>";
          }
          {
            mode = [
              "n"
              "v"
            ];
            key = "<leader>cc";
            action = ":CopilotChatOpen<cr>";
          }
          {
            mode = [
              "n"
              "v"
            ];
            key = "<leader>ce";
            action = ":CopilotChatExplain<cr>";
          }
          {
            mode = [
              "n"
              "v"
            ];
            key = "<leader>cr";
            action = ":CopilotChatReview<cr>";
          }
          {
            mode = [
              "n"
              "v"
            ];
            key = "<leader>cf";
            action = ":CopilotChatFix<cr>";
          }
          {
            mode = [
              "n"
              "v"
            ];
            key = "<leader>cd";
            action = ":CopilotChatDocs<cr>";
          }
          {
            mode = [
              "n"
              "x"
            ];
            key = "p";
            action = "<Plug>(YankyPutAfter)";
          }
          {
            mode = [
              "n"
              "x"
            ];
            key = "P";
            action = "<Plug>(YankyPutBefore)";
          }
        ];
        plugins.web-devicons.enable = true;
        plugins.telescope = {
          enable = true;
          keymaps = {
            "<leader>b" = "buffers";
            "<leader>ff" = "find_files";
            "<leader>fg" = "live_grep";
            "<leader>fh" = "help_tags";
            "<leader>fp" = "yank_history";
          };
        };
        plugins.lsp-format.enable = true;
        plugins.lsp = {
          enable = true;
          servers = {
            bashls.enable = true; # bash
            nixd.enable = true; # nix
            ruff-lsp.enable = true; # python
            harper-ls.enable = true; # comments
            jsonls.enable = true; # json
          };
        };
        plugins.undotree = {
          enable = true;
          settings.SetFocusWhenToggle = true;
        };
        plugins.treesitter.enable = true;
        plugins.copilot-cmp.enable = true;
        plugins.copilot-lua.panel.enabled = false;
        plugins.copilot-lua.suggestion.enabled = false;
        plugins.cmp_yanky.enable = true;
        plugins.cmp = {
          enable = true;
          autoEnableSources = true;
          settings = {
            experimental = {
              ghost_text = true;
            };
            sources = [
              { name = "nvim_lsp"; }
              { name = "emoji"; }
              {
                name = "buffer"; # text within current buffer
                option.get_bufnrs.__raw = "vim.api.nvim_list_bufs";
                keywordLength = 2;
              }
              {
                name = "copilot"; # enable copilot
              }
              {
                name = "path"; # file system paths
                keywordLength = 3;
              }
              { name = "cmp_yanky"; }
            ];

            mapping = {
              "<Tab>" = "cmp.mapping.select_next_item()";
              "<S-Tab>" = "cmp.mapping.select_prev_item()";
              "<C-n>" = "cmp.mapping.select_next_item()";
              "<C-p>" = "cmp.mapping.select_prev_item()";
              "<C-e>" = "cmp.mapping.abort()";
              "<C-b>" = "cmp.mapping.scroll_docs(-4)";
              "<C-f>" = "cmp.mapping.scroll_docs(4)";
              "<C-Space>" = "cmp.mapping.complete()";
              "<CR>" = "cmp.mapping.confirm({ select = true })";
              "<S-CR>" = "cmp.mapping.confirm({ behavior = cmp.ConfirmBehavior.Replace, select = true })";
            };
          };
        };
        plugins.none-ls = {
          enable = true;
          sources.formatting.treefmt.enable = true;
        };
        plugins.bufferline.enable = true;
        plugins.which-key.enable = true;
        plugins.yanky = {
          enable = true;
          enableTelescope = true;
        };
        plugins.comment.enable = true;
        plugins.copilot-chat.enable = true;
      };
    };
}
