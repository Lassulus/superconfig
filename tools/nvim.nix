{ inputs, ... }:
{
  perSystem =
    { system, pkgs, ... }:
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
          undofile = true;
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
        extraConfigLua = ''
          local function watch_theme_file()
              local path = '/var/theme/current_theme'
              local uv = vim.loop

              local watcher = uv.new_fs_event()
              watcher:start(path, {}, function(err, filename, events)
                  if err then
                      print('Error watching file:', err)
                      return
                  end

                  -- Use Lua's io.open to read the file content
                  local file = io.open(path, 'r')
                  if not file then
                      print('Failed to open file:', path)
                      return
                  end

                  local content = file:read('*a') -- Read the entire file
                  file:close()

                  content = content:gsub('%s+$', "")
                  content = content:gsub('"', '\\"')

                  -- Execute a Neovim command based on the content
                  vim.schedule(function()
                      cmd = 'set background=' .. content
                      vim.cmd(cmd)
                  end)
              end)
          end
          watch_theme_file()

        '';
        extraPlugins = [
          pkgs.vimPlugins.vim-fetch
        ];
        # not ready yet, we are waiting for none-ls to get updated
        # extraConfigLua = ''
        #   local null_ls = require("null-ls")
        #   null_ls.register(null_ls.builtins.formatting.nix_flake_fmt)
        # '';
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
          {
            mode = [
              "c"
              "i"
              "n"
              "x"
            ];
            key = "<M-CR>";
            action = ":lua vim.lsp.buf.code_action()<CR>";
          }
          {
            mode = [
              "n"
            ];
            key = "gd";
            action = ":lua vim.lsp.buf.definition()<CR>";
          }
          {
            mode = [
              "n"
            ];
            key = "gD";
            action = ":lua vim.lsp.buf.declaration()<CR>";
          }
        ];
        # autoCmd = [
        #   {
        #     event = "BufWritePost";
        #     desc = "run treefmt on save";
        #     # https://stackoverflow.com/questions/77466697/how-to-automatically-format-on-save
        #     callback.__raw = ''
        #       function()
        #         vim.cmd("silent !treefmt %")
        #         vim.cmd("edit")
        #       end
        #     '';
        #   }
        # ];
        plugins.none-ls = {
          enable = true;
          # sources.formatting.treefmt = {
          #   enable = true;
          #   package = pkgs.emptyDirectory;
          # };
          # package = pkgs.vimPlugins.none-ls-nvim.overrideAttrs (_old: {
          #   src = pkgs.fetchFromGitHub {
          #     owner = "lassulus";
          #     repo = "none-ls.nvim";
          #     rev = "292c2b5eadea0a097b9a01804aea70f5c8125200";
          #     sha256 = "sha256-nbzqXsxmYfxngdJH3NXMLmGgygh6reSEnruoc6l8t/s=";
          #   };
          # });
        };
        plugins.web-devicons.enable = true;
        plugins.telescope.extensions.undo.enable = true;
        plugins.telescope = {
          enable = true;
          keymaps = {
            "<leader>b" = "buffers";
            "<leader>u" = "undo";
            "<leader>ff" = "find_files";
            "<leader>fg" = "live_grep";
            "<leader>fh" = "help_tags";
            "<leader>fp" = "yank_history";
          };
        };
        plugins.lsp-format.enable = true;
        plugins.lsp-lines.enable = true;
        plugins.lsp = {
          enable = true;
          servers = {
            bashls.enable = true; # bash
            nixd = {
              enable = true; # nix
              extraOptions.offset_encoding = "utf-8"; # workaround https://github.com/nix-community/nixvim/issues/2390#issuecomment-2408101568
            };
            ruff.enable = true; # python
            pyright.enable = true; # python
            jsonls.enable = true; # json
          };
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
              "<CR>" = ''
                cmp.mapping({
                  i = function(fallback)
                    if cmp.visible() and cmp.get_active_entry() then
                      cmp.confirm({ behavior = cmp.ConfirmBehavior.Replace, select = false })
                    else
                      fallback()
                    end
                  end,
                  s = cmp.mapping.confirm({ select = true }),
                  c = cmp.mapping.confirm({ behavior = cmp.ConfirmBehavior.Replace, select = true }),
                })
              '';
            };
          };
        };
        plugins.bufferline.enable = true;
        plugins.which-key.enable = true;
        plugins.yanky = {
          enable = true;
          enableTelescope = true;
        };
        plugins.comment.enable = true;
        plugins.copilot-chat.enable = true;
        plugins.undotree.enable = true; # seems to be needed for undo history in telescope
        plugins.leap.enable = true;
      };
    };
}
