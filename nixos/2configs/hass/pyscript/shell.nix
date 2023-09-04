{ pkgs ? import <nixpkgs> {} }: let

  hass_host = "styx.r";
  hass_token = builtins.readFile ./hass_token;

  mach-nix = import (builtins.fetchGit {
    url = "https://github.com/DavHau/mach-nix/";
    ref = "refs/tags/3.4.0";
  }) {
    pkgs = pkgs;
  };
  pyenv = mach-nix.mkPython {
    requirements = ''
      hass_pyscript_kernel
    '';
  };
  jupyter = import (builtins.fetchGit {
    url = https://github.com/tweag/jupyterWith;
    ref = "master";
  }) {};

  pyscriptKernel = {
    spec = pkgs.runCommand "pyscript" {} ''
      mkdir -p $out/kernels/pyscript
      cp ${kernel_json} $out/kernels/pyscript/kernel.json
      cp ${pyscript_conf} $out/kernels/pyscript/pyscript.conf
    '';
    runtimePackages = [ pyenv ];
  };

  kernel_json = pkgs.writeText "kernel.json" (builtins.toJSON {
    argv = [
      "${pyenv}/bin/python3" "-m" "hass_pyscript_kernel"
      "-f" "{connection_file}"
    ];
    display_name = "hass_pyscript";
    language = "python";
  });

  pyscript_conf = pkgs.writeText "pyscript.conf" ''
    [homeassistant]
    hass_host = ${hass_host}
    hass_url = http://''${hass_host}:8123
    hass_token = ${hass_token}
  '';

  jupyterEnvironment = jupyter.jupyterlabWith {
    kernels = [ pyscriptKernel ];
  };

in jupyterEnvironment.env
