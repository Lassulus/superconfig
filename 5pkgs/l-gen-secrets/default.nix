{ pkgs }:
pkgs.writers.writeDashBin "l-gen-secrets" ''
  set -efu
  HOSTNAME=$1
  TMPDIR=$(${pkgs.coreutils}/bin/mktemp -d)
  if [ "''${DRYRUN-n}" = "n" ]; then
    trap 'rm -rf $TMPDIR' EXIT
  else
    echo "$TMPDIR"
    set -x
  fi
  mkdir -p $TMPDIR/out

  PASSWORD=$(${pkgs.pwgen}/bin/pwgen 25 1)
  HASHED_PASSWORD=$(echo $PASSWORD | ${pkgs.hashPassword}/bin/hashPassword -s) > /dev/null

  # ssh
  ${pkgs.openssh}/bin/ssh-keygen -t ed25519 -f $TMPDIR/ssh.id_ed25519 -P "" -C "" >/dev/null
  ${pkgs.coreutils}/bin/mv $TMPDIR/ssh.id_ed25519 $TMPDIR/out/

  # tor
  ${pkgs.coreutils}/bin/timeout 1 ${pkgs.tor}/bin/tor --HiddenServiceDir $TMPDIR/tor --HiddenServicePort 1 --SocksPort 0 >/dev/null || :
  ${pkgs.coreutils}/bin/mv $TMPDIR/tor/hs_ed25519_secret_key $TMPDIR/out/ssh-tor.priv

  # tinc
  ${pkgs.coreutils}/bin/mkdir -p $TMPDIR/tinc
  ${pkgs.tinc_pre}/bin/tinc --config $TMPDIR/tinc generate-keys 4096 </dev/null
  ${pkgs.coreutils}/bin/mv $TMPDIR/tinc/ed25519_key.priv $TMPDIR/out/retiolum.ed25519_key.priv
  ${pkgs.coreutils}/bin/mv $TMPDIR/tinc/rsa_key.priv $TMPDIR/out/retiolum.rsa_key.priv

  # wireguard
  ${pkgs.wireguard-tools}/bin/wg genkey > $TMPDIR/out/wiregrill.key
  ${pkgs.coreutils}/bin/cat $TMPDIR/out/wiregrill.key | ${pkgs.wireguard-tools}/bin/wg pubkey > $TMPDIR/wiregrill.pub

  # system passwords
  cat <<EOF > $TMPDIR/out/hashedPasswords.nix
  {
    root = "$HASHED_PASSWORD";
    mainUser = "$HASHED_PASSWORD";
  }
  EOF

  set +f
  if [ "''${DRYRUN-n}" = "n" ]; then
    cd $TMPDIR/out
    for x in *; do
      ${pkgs.coreutils}/bin/cat $x | ${pkgs.pass}/bin/pass insert -m hosts/$HOSTNAME/$x > /dev/null
    done
    echo $PASSWORD | ${pkgs.pass}/bin/pass insert -m admin/$HOSTNAME/pass > /dev/null
    ${pkgs.coreutils}/bin/cat $TMPDIR/tor/hostname | ${pkgs.pass}/bin/pass insert -m admin/$HOSTNAME/torname > /dev/null
  fi
  set -f

  cat <<EOF
  { r6, w6, ... }:
  {
    nets = {
      retiolum = {
        ip4.addr = "10.243.0.changeme";
        ip6.addr = r6 "changeme";
        aliases = [
          "$HOSTNAME.r"
        ];
        tinc.pubkey = ${"''"}
  $(cat $TMPDIR/tinc/rsa_key.pub | sed 's/^/        /')
        ${"''"};
        tinc.pubkey_ed25519 = "$(cat $TMPDIR/tinc/ed25519_key.pub | ${pkgs.gnused}/bin/sed 's/.* = //')";
      };
      wiregrill = {
        ip6.addr = w6 "changeme";
        aliases = [
          "$HOSTNAME.w"
        ];
        wireguard.pubkey = ${"''"}
          $(cat $TMPDIR/wiregrill.pub)
        ${"''"};
      };
    };
    ssh.pubkey = "$(cat $TMPDIR/ssh.id_ed25519.pub)";
  }
  EOF
''
