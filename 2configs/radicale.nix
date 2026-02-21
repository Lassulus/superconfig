{ config, lib, pkgs, ... }:
let
  users = [ "opencrow" ];

  # Generate one var per user with random password
  userGenerators = lib.listToAttrs (map (user: {
    name = "radicale-${user}";
    value = {
      files."htpasswd-line" = { };
      files."password" = { };
      runtimeInputs = with pkgs; [ apacheHttpd coreutils ];
      script = ''
        password=$(head -c 32 /dev/urandom | base64 | tr -dc 'a-zA-Z0-9' | head -c 24)
        echo "$password" > "$out/password"
        htpasswd -nbB ${user} "$password" > "$out/htpasswd-line"
      '';
    };
  }) users);

  loadCredentials = map (user:
    "radicale-${user}-htpasswd:${config.clan.core.vars.generators."radicale-${user}".files."htpasswd-line".path}"
  ) users;

  assembleHtpasswd = pkgs.writeShellScript "radicale-htpasswd" (
    lib.concatMapStringsSep "\n" (user:
      "cat \${CREDENTIALS_DIRECTORY}/radicale-${user}-htpasswd"
    ) users
  );
in
{
  services.radicale = {
    enable = true;
    settings = {
      server = {
        hosts = [ "127.0.0.1:5232" ];
      };
      auth = {
        type = "htpasswd";
        htpasswd_filename = "/run/radicale/htpasswd";
        htpasswd_encryption = "bcrypt";
      };
      storage = {
        filesystem_folder = "/var/lib/radicale/collections";
      };
      web = {
        type = "internal";
      };
    };
  };

  systemd.services.radicale.serviceConfig = {
    RuntimeDirectory = "radicale";
    LoadCredential = loadCredentials;
  };
  systemd.services.radicale.preStart = lib.mkBefore ''
    ${assembleHtpasswd} > /run/radicale/htpasswd
  '';

  clan.core.vars.generators = userGenerators;

  services.nginx.virtualHosts."cal.lassul.us" = {
    forceSSL = true;
    enableACME = true;
    locations."/" = {
      proxyPass = "http://127.0.0.1:5232";
      extraConfig = ''
        proxy_set_header X-Script-Name /;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header Host $host;
      '';
    };
  };
}
