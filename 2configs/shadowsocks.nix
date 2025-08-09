{ config, pkgs, ... }:
{
  services.shadowsocks = {
    enable = true;
    passwordFile = config.clan.core.vars.generators.shadowsocks.files.shadowsocks_password.path;
  };
  networking.firewall.allowedTCPPorts = [ 8388 ];
  clan.core.vars.generators.shadowsocks = {
    files."shadowsocks_password" = { };
    migrateFact = "shadowsocks";
    prompts.password = {
      description = "please enter your shadowsocks password";
      type = "hidden";
    };
    runtimeInputs = with pkgs; [
      coreutils
    ];
    script = ''
      cp "$prompts"/password "$out"/shadowsocks_password
    '';
  };
}
