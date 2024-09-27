{ config, pkgs, ... }:
{
  services.shadowsocks = {
    enable = true;
    passwordFile = config.clanCore.facts.services.shadowsocks.secret.shadowsocks_password.path;
  };
  networking.firewall.allowedTCPPorts = [ 8388 ];
  clanCore.facts.services.shadowsocks = {
    secret."shadowsocks_password" = { };
    generator = {
      prompt = "please enter your shadowsocks password";
      path = with pkgs; [
        coreutils
      ];
      script = ''
        echo "$prompt_value" > "$secrets"/shadowsocks_password
      '';
    };
  };
}
