{ ... }:
{
  perSystem =
    { pkgs, ... }:
    let
      python = pkgs.python3;
    in
    {
      packages.tui-stream-server = pkgs.writeScriptBin "tui-stream-server" ''
        #!${python}/bin/python3
        ${builtins.readFile ./server.py}
      '';

      packages.tui-stream-client =
        let
          wrappedClient = pkgs.writeScriptBin "tui-stream-client-unwrapped" ''
            #!${python}/bin/python3
            ${builtins.readFile ./client.py}
          '';
        in
        pkgs.writeShellScriptBin "tui-stream-client" ''
          export PATH="${pkgs.lib.makeBinPath [ pkgs.ffmpeg ]}:$PATH"
          exec ${wrappedClient}/bin/tui-stream-client-unwrapped "$@"
        '';

      # Combined package with both server and client
      packages.tui-stream = pkgs.symlinkJoin {
        name = "tui-stream";
        paths =
          let
            server = pkgs.writeScriptBin "tui-stream-server" ''
              #!${python}/bin/python3
              ${builtins.readFile ./server.py}
            '';
            clientUnwrapped = pkgs.writeScriptBin "tui-stream-client-unwrapped" ''
              #!${python}/bin/python3
              ${builtins.readFile ./client.py}
            '';
            client = pkgs.writeShellScriptBin "tui-stream-client" ''
              export PATH="${pkgs.lib.makeBinPath [ pkgs.ffmpeg ]}:$PATH"
              exec ${clientUnwrapped}/bin/tui-stream-client-unwrapped "$@"
            '';
          in
          [
            server
            client
          ];
      };
    };
}
