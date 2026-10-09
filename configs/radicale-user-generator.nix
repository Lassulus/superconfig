# clan vars generator for one radicale user: a random password plus its
# bcrypt htpasswd line. Imported by configs/radicale.nix for every user, and
# by the machines of users whose generator is shared (hermes on coaxmetal):
# a shared generator must be defined identically on every machine using it.
pkgs: user: {
  files."htpasswd-line" = { };
  files."password" = { };
  runtimeInputs = with pkgs; [
    apacheHttpd
    coreutils
  ];
  script = ''
    password=$(head -c 32 /dev/urandom | base64 | tr -dc 'a-zA-Z0-9' | head -c 24)
    echo "$password" > "$out/password"
    htpasswd -nbB ${user} "$password" > "$out/htpasswd-line"
  '';
}
