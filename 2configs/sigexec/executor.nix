# sigexec executor: signed remote command execution as root, for
# administration. The signature is the authorization — commands are signed in
# the browser (passkey) or by the CLI's local ed25519 key, verified against
# the key list below; no shell parses them, argv runs literally.
#
# There is no TLS here: the port is opened on retiolum only, and the dashboard
# on neoprism (./dashboard.nix) proxies browser/CLI traffic to it. Machines
# not reachable over retiolum (starkstrom) additionally put their own nginx in
# front; see machines/starkstrom/config.nix.
let
  # Must match the executor URLs registered in ./dashboard.nix.
  executorPort = 7601;
  domain = "sigexec.lassul.us";
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
    # Wildcard dual-stack bind; reachability is the firewall's job below.
    listen = "[::]:${toString executorPort}";
    # Browser passkeys sign against the dashboard's origin.
    rpId = domain;
    origins = [ "https://${domain}" ];
    authorizedKeys = [
      "ed25519 RhYj8TzT8w3q50Oi3-q7U1KLRLrm66FltogC15ootJg read,request lass@ignavia"
      "webauthn-es256 MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAEZPkoTMJKVdsC-_m8wPrKrJiCKVcZLdJarMTzF8JQFJUKmYlqY_34oQr1u9wCMTQZFU541Jmje1ri9z20XmsXpQ 6KpUo9EZQrmOCQ0vVwgnbw read,write lass@ignavia"
    ];
  };

  # Reachable from the mesh only; the dashboard proxies for the outside world.
  networking.firewall.interfaces.retiolum.allowedTCPPorts = [ executorPort ];
}
