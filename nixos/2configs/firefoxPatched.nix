{ config, lib, pkgs, ... }:

let
  lpkgs = import ../5pkgs { inherit pkgs; };

  inherit (lib)
    concatMapStrings
  ;

  plugins = with lpkgs.firefoxPlugins; [
    noscript
    ublock
    vimperator
  ];

  copyXpi = plugin:
    "cp ${plugin}/*.xpi $out/usr/lib/firefox-*/browser/extensions/";

  preferences = pkgs.writeText "autoload.js" ''
    pref('general.config.filename', 'firefox.cfg');
    pref('general.config.obscure_value', 0);
  '';

  config = pkgs.writeText "firefox.cfg" ''
    //
    lockPref("app.update.enabled", false);
    lockPref("extensions.update.enabled", false);
    lockPref("autoadmin.global_config_url", "");
    lockPref("extensions.checkUpdateSecurity", false);
    lockPref("services.sync.enabled", false);
    lockPref("browser.shell.checkDefaultBrowser", false);
    lockPref("layout.spellcheckDefault", 0);
    lockPref("app.update.auto", false);
    lockPref("browser.newtabpage.enabled", false);
    lockPref("noscript.firstRunRedirection", false);
    lockPref("noscript.hoverUI", false);
    lockPref("noscript.notify", false);
    defaultPref("extensions.newAddons", false);
    defaultPref("extensions.autoDisableScopes", 0);
    defaultPref("plugin.scan.plid.all", false);
  '';

in {
  environment.systemPackages = [
    (pkgs.lib.overrideDerivation pkgs.firefox-bin (original : {
      installPhase = ''
        ${original.installPhase}
        find $out/usr/lib
        ${concatMapStrings copyXpi plugins}
        cd $out/usr/lib/firefox-*/
        mkdir -p browser/defaults/preferences
        cp ${preferences} browser/defaults/preferences/autoload.js
        cp ${config} ./firefox.cfg
      '';
    }))
  ];
}

