# sigexec: signed remote command execution as root, for administration.
# The signature is the authorization — commands are signed in the browser
# (passkey) or by the CLI's local ed25519 key, verified against the key list
# below; no shell parses them, argv runs literally.
#
# nginx terminates TLS and serves the dashboard (page + reverse proxy, no key
# material, no job data); the executor is localhost-only behind it.
#   browser: https://sigexec.lassul.us          (register passkeys at /register)
#   CLI:     sigexec run -x https://sigexec.lassul.us/x/neoprism -- uptime
#     (statements sign the path relative to the base URL, so the executor
#      verifies /jobs after the proxy strips /x/neoprism)
let
  domain = "sigexec.lassul.us";
  executorPort = 7601;
  dashboardPort = 7501;
in
{ self, ... }:
{
  imports = [ self.inputs.sigexec.nixosModules.default ];

  services.sigexec-executor = {
    enable = true;
    # root deliberately: this executor's purpose is administration, and the
    # executor's privileges are the jobs' privileges.
    user = "root";
    group = "root";
    # ssh-style: login shell env, bare command names work.
    login = true;
    listen = "127.0.0.1:${toString executorPort}";
    # Browser passkeys sign against the dashboard's origin.
    rpId = domain;
    origins = [ "https://${domain}" ];
    authorizedKeys = [
      "ed25519 RhYj8TzT8w3q50Oi3-q7U1KLRLrm66FltogC15ootJg read,write lass@ignavia"
    ];
  };

  services.sigexec-dashboard = {
    enable = true;
    rpId = domain;
    port = dashboardPort;
    executors.neoprism = "http://127.0.0.1:${toString executorPort}";
  };

  services.nginx.virtualHosts.${domain} = {
    enableACME = true;
    forceSSL = true;
    locations."/" = {
      proxyPass = "http://127.0.0.1:${toString dashboardPort}";
      extraConfig = ''
        # Job streams are long-lived chunked responses: unbuffered so output
        # arrives live, and a generous read timeout because `logs` on a
        # pending job legitimately blocks until someone approves it.
        proxy_buffering off;
        proxy_read_timeout 1d;
        proxy_send_timeout 1d;
      '';
    };
  };
}
