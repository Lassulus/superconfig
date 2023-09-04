{ config, pkgs, ... }:

## TODO sort and split up
{
  environment.systemPackages = with pkgs; [
    aria2
    generate-secrets
    gnupg1compat
    htop
    i3lock
    l-gen-secrets
    mosh
    pass
    pavucontrol
    pv
    pwgen
    remmina
    ripgrep
    silver-searcher
    transmission
    wget
    xsel
    yt-dlp
    (pkgs.writeDashBin "youtube-dl" ''
      exec ${pkgs.yt-dlp}/bin/yt-dlp "$@"
    '')
    (pkgs.writeDashBin "tether-on" ''
      adb shell svc usb setFunctions rndis
    '')
    (pkgs.writeDashBin "tether-off" ''
      adb shell svc usb setFunctions
    '')
    (pkgs.writeDashBin "deploy" ''
      set -eu
      export SYSTEM="$1"
      $(nix-build $HOME/sync/stockholm/lass/krops.nix --no-out-link --argstr name "$SYSTEM" -A deploy)
    '')
    (pkgs.writeDashBin "lassul.us" ''
      TMPDIR=$(${pkgs.coreutils}/bin/mktemp -d)
      ${pkgs.pass}/bin/pass show admin/ovh/api.config > "$TMPDIR"/ovh-secrets.json
      OVH_ZONE_CONFIG="$TMPDIR"/ovh-secrets.json ${pkgs.ovh-zone}/bin/ovh-zone import /etc/zones/lassul.us lassul.us
      ${pkgs.coreutils}/bin/rm -rf "$TMPDIR"
    '')
    (pkgs.writeDashBin "btc-coinbase" ''
      ${pkgs.curl}/bin/curl -Ss 'https://api.coinbase.com/v2/prices/spot?currency=EUR' | ${pkgs.jq}/bin/jq '.data.amount'
    '')
    (pkgs.writeDashBin "btc-wex" ''
      ${pkgs.curl}/bin/curl -Ss 'https://wex.nz/api/3/ticker/btc_eur' | ${pkgs.jq}/bin/jq '.btc_eur.avg'
    '')
    (pkgs.writeDashBin "btc-kraken" ''
      ${pkgs.curl}/bin/curl -Ss  'https://api.kraken.com/0/public/Ticker?pair=BTCEUR' | ${pkgs.jq}/bin/jq '.result.XXBTZEUR.a[0]'
    '')
  ];
}
