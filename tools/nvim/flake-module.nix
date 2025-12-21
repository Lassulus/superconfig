{ inputs, ... }:
{
  perSystem =
    { system, pkgs, ... }:
    {
      packages.nvim = inputs.nixvim.legacyPackages.${system}.makeNixvim {
        vimAlias = true;
        colorschemes = {
          ayu = {
            enable = true;
            settings = {
              mirage = false;
              dark = true;
            };
            settings.overrides = {
              EoLSpace = {
                bg = "#883333";
              };
            };
          };
          everforest = {
            enable = true;
            settings.overrides = {
              EoLSpace = {
                bg = "#FF2222"; # doesn't work
              };
            };
          };
        };
        extraConfigLua = ''
          -- Cross-platform background detection and colorscheme switching
          local last_theme = nil

          local function detect_and_set_theme()
            local is_dark = false

            if vim.fn.has("mac") == 1 then
              -- macOS: check system appearance
              local result = vim.fn.system("defaults read -g AppleInterfaceStyle 2>/dev/null")
              is_dark = result:match("Dark") ~= nil
            elseif vim.fn.has("unix") == 1 then
              -- Linux: check if running under a dark theme
              -- Check NixOS theme system first (always check this fresh)
              local f = io.open("/var/theme/current_theme", "r")
              if f then
                local content = f:read("*all"):gsub("^%s+", ""):gsub("%s+$", "")
                f:close()
                is_dark = (content == "dark")
              else
                -- Fallback to other methods if theme file doesn't exist
                local methods = {
                  -- GNOME/GTK
                  "gsettings get org.gnome.desktop.interface gtk-theme 2>/dev/null",
                  "gsettings get org.gnome.desktop.interface color-scheme 2>/dev/null",
                  -- KDE
                  "kreadconfig5 --file kdeglobals --group General --key ColorScheme 2>/dev/null",
                  -- Check if COLORFGBG suggests dark background
                  function()
                    local colorfgbg = vim.env.COLORFGBG
                    if colorfgbg then
                      local fg, bg = colorfgbg:match("(%d+);(%d+)")
                      if fg and bg then
                        -- If foreground is lighter than background, likely dark theme
                        return tonumber(fg) > tonumber(bg)
                      end
                    end
                    return false
                  end
                }

                for _, method in ipairs(methods) do
                  if type(method) == "function" then
                    is_dark = method()
                    if is_dark then break end
                  else
                    local result = vim.fn.system(method)
                    if result:match("[Dd]ark") or result:match("prefer%-dark") then
                      is_dark = true
                      break
                    end
                  end
                end
              end
            end

            local new_theme = is_dark and "dark" or "light"

            if new_theme ~= last_theme then
              last_theme = new_theme
              vim.o.background = new_theme

              if is_dark then
                vim.cmd("colorscheme ayu")
              else
                vim.cmd("colorscheme everforest")
              end
            end
          end

          -- Set initial theme
          vim.defer_fn(detect_and_set_theme, 100)

          -- Check for theme changes every 3 seconds (less frequent to be less resource intensive)
          local timer = vim.loop.new_timer()
          timer:start(3000, 3000, vim.schedule_wrap(detect_and_set_theme))

          -- Create a command to manually refresh theme
          vim.api.nvim_create_user_command("RefreshTheme", detect_and_set_theme, {})

          -- Configure lsp_lines to always show and disable default virtual_text
          vim.diagnostic.config({
            virtual_text = false,
            virtual_lines = true,
          })
        '';
        globals = {
          mapleader = " ";
        };
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
        extraPlugins = [
          pkgs.vimPlugins.vim-fetch
        ];
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
          {
            mode = "n";
            key = "<leader>ll";
            action = ":lua require('lsp_lines').toggle()<CR>";
            options.desc = "Toggle lsp_lines";
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
          sources.formatting.nix_flake_fmt.enable = true;
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
        plugins.copilot-lua.settings.panel.enabled = false;
        plugins.copilot-lua.settings.suggestion.enabled = false;
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
        plugins.gitsigns.enable = true;
      };
    };
}
