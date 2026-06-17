{ pkgs, lib, ... }:
let
  pkg = pkgs.matrix-zulip-bridge;
  bin = lib.getExe pkg;

  address = "127.0.0.1";
  port = 28464;
  homeserver = "http://[::1]:8008";
  owner = "@lassulus:lassul.us";

  registrationFile = "/var/lib/matrix-zulip-bridge/registration.yml";

  # JSON is a proper subset of YAML. We render our desired registration and
  # merge in the tokens from the bridge-generated file in preStart, mirroring
  # the upstream heisenbridge module (this bridge shares its architecture).
  bridgeConfig = builtins.toFile "matrix-zulip-bridge-registration.yml" (
    builtins.toJSON {
      id = "zulipbridge";
      url = "http://${address}:${toString port}";
      rate_limited = false;
      sender_localpart = "zulipbridge";
      namespaces = {
        users = [
          {
            regex = "@zulip_.*:lassul\\.us";
            exclusive = true;
          }
          {
            regex = "@zulipbridge:lassul\\.us";
            exclusive = true;
          }
        ];
        aliases = [ ];
        rooms = [ ];
      };
    }
  );
in
{
  systemd.services.matrix-zulip-bridge = {
    description = "Matrix<->Zulip bridge";
    before = [ "matrix-synapse.service" ]; # So the registration file can be used by Synapse
    wantedBy = [ "multi-user.target" ];

    preStart = ''
      umask 077
      set -e -u -o pipefail

      if ! [ -f "${registrationFile}" ]; then
        # Generate registration file if not present (we only care about the tokens in it)
        ${bin} --generate --config ${registrationFile}
      fi

      # Overwrite the registration file with our generated one (the config may have
      # changed since then), but keep the tokens. Two step procedure to be failure safe.
      ${pkgs.yq}/bin/yq --slurp \
        '.[0] + (.[1] | {as_token, hs_token})' \
        ${bridgeConfig} \
        ${registrationFile} \
        > ${registrationFile}.new
      mv -f ${registrationFile}.new ${registrationFile}

      # Grant Synapse access to the registration
      if ${pkgs.getent}/bin/getent group matrix-synapse > /dev/null; then
        chgrp -v matrix-synapse ${registrationFile}
        chmod -v g+r ${registrationFile}
      fi
    '';

    serviceConfig = {
      Type = "simple";
      ExecStart = lib.concatStringsSep " " [
        bin
        "-v"
        "--config"
        registrationFile
        "--listen-address"
        (lib.escapeShellArg address)
        "--listen-port"
        (toString port)
        "--owner"
        (lib.escapeShellArg owner)
        (lib.escapeShellArg homeserver)
      ];

      # Hardening options (mirrors upstream heisenbridge module)
      User = "matrix-zulip-bridge";
      Group = "matrix-zulip-bridge";
      RuntimeDirectory = "matrix-zulip-bridge";
      RuntimeDirectoryMode = "0700";
      StateDirectory = "matrix-zulip-bridge";
      StateDirectoryMode = "0755";

      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateTmp = true;
      PrivateDevices = true;
      ProtectKernelTunables = true;
      ProtectControlGroups = true;
      RestrictSUIDSGID = true;
      PrivateMounts = true;
      ProtectKernelModules = true;
      ProtectKernelLogs = true;
      ProtectHostname = true;
      ProtectClock = true;
      ProtectProc = "invisible";
      ProcSubset = "pid";
      RestrictNamespaces = true;
      RemoveIPC = true;
      UMask = "0077";

      CapabilityBoundingSet = [ "CAP_CHOWN" ];
      AmbientCapabilities = [ "CAP_CHOWN" ];
      NoNewPrivileges = true;
      LockPersonality = true;
      RestrictRealtime = true;
      SystemCallFilter = [
        "@system-service"
        "~@privileged"
        "@chown"
      ];
      SystemCallArchitectures = "native";
      RestrictAddressFamilies = "AF_INET AF_INET6";
    };
  };

  # Wire the registration into Synapse (merges with the other bridges' lists).
  services.matrix-synapse.settings.app_service_config_files = [
    registrationFile
  ];

  users.groups.matrix-zulip-bridge = { };
  users.users.matrix-zulip-bridge = {
    description = "Service user for the Matrix Zulip bridge";
    group = "matrix-zulip-bridge";
    isSystemUser = true;
  };
}
