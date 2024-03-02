{ config, pkgs, ... }: {
  services.shadowsocks = {
    enable = true;
    passwordFile = config.clanCore.secrets.shadowsocks.secrets.shadowsocks_password.path;
  };
  networking.firewall.allowedTCPPorts = [ 8388 ];
  clanCore.secrets.shadowsocks = {
    secrets."shadowsocks_password" = { };
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
