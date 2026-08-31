# sigexec executor: signed remote command execution as root, for
# administration. The signature is the authorization — commands are signed
# with the CLI's local ed25519 key (or a passkey) and verified against the
# key list below; no shell parses them, argv runs literally.
#
# The executor itself has no TLS and listens on localhost; nginx terminates
# TLS on the public vhost:  sigexec run -x https://sigexec.lassul.us -- uptime
let
  domain = "sigexec.lassul.us";
  port = 7601;
in
{ self, ... }:
{
  imports = [ self.inputs.sigexec.nixosModules.executor ];

  services.sigexec-executor = {
    enable = true;
    # root deliberately: this executor's purpose is administration, and the
    # executor's privileges are the jobs' privileges.
    user = "root";
    group = "root";
    # ssh-style: login shell env, bare command names work.
    login = true;
    listen = "127.0.0.1:${toString port}";
    authorizedKeys = [
      "ed25519 RhYj8TzT8w3q50Oi3-q7U1KLRLrm66FltogC15ootJg read,write lass@ignavia"
    ];
  };

  services.nginx.virtualHosts.${domain} = {
    enableACME = true;
    forceSSL = true;
    locations."/" = {
      proxyPass = "http://127.0.0.1:${toString port}";
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
