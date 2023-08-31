{ inputs, ... }:
{
  perSystem = { system, ... }: {
    packages.nvim = inputs.nixvim.legacyPackages.${system}.makeNixvim {
      colorschemes.gruvbox.enable = true;
      options = {
        mouse = "a";
        pastetoggle = "<INS>";
        undofile = {};
        undolevels = 10000;
        undoreload = 10000;
      };
      extraConfigVim = ''
        set list listchars=tab:⇥\ ,extends:❯,precedes:❮,nbsp:␣,trail:· showbreak=¬
        set et
      '';
      maps.normalVisualOp = {
        "<C-c>" = ":q<cr>";
      };
      plugins.lsp = {
        enable = true;
      };
    };
  };
}
