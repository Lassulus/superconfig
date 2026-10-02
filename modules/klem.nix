{
  self,
  config,
  lib,
  pkgs,
  ...
}:
with lib;
let
  cfg = config.lass.klem;
  slib = self.inputs.stockholm.lib;
in
{
  options.lass.klem = mkOption {
    default = { };
    type = types.attrsOf (
      types.submodule (
        { config, ... }:
        {
          options = {
            target = mkOption {
              default = ".*";
              description = ''
                regex of valid targets
                can be shown with xclip -selection clipboard -t TARGETS
                the first hit is taken as target argument
              '';
              type = types.str;
            };
            script = mkOption {
              description = ''
                file to run if entry is selected
              '';
              type = types.path;
            };
            label = mkOption {
              default = config._module.args.name;
              description = ''
                label to show in dmenu for this script
              '';
              type = types.str;
            };
          };
        }
      )
    );
  };
  config =
    let
      klem = pkgs.writers.writeDashBin "klem" ''
        set -x

        labels=""
        # match filetype against patterns
        ${concatMapStringsSep "\n" (script: ''
          ${pkgs.xclip}/bin/xclip -selection clipboard -target TARGETS -out \
            | ${pkgs.gnugrep}/bin/grep -q '${script.target}'
          if [ $? -eq 0 ]; then
            labels="$labels:${script.label}"
          fi
        '') (attrValues cfg)}

        #remove empty line, feed into dmenu
        script=$(echo "$labels" \
          | ${pkgs.gnused}/bin/sed 's/^://;s/:/\n/g' \
          | ${pkgs.dmenu}/bin/dmenu)

        #run the chosen script
        case $script in
          ${concatMapStringsSep "\n" (
            script:
            slib.indent ''
              ${script.label})
                target=$(${pkgs.xclip}/bin/xclip -selection clipboard -target TARGETS -out \
                  | ${pkgs.gnugrep}/bin/grep '${script.target}' \
                  | ${pkgs.gnugrep}/bin/grep -v TARGETS \
                  | ${pkgs.coreutils}/bin/head -1)
                ${pkgs.xclip}/bin/xclip -selection clipboard -target "$target" -out \
                | ${script.script} \
                | ${pkgs.xclip}/bin/xclip -selection clipboard -in
              ;;
            ''
          ) (attrValues cfg)}
        esac
      '';
    in
    mkIf (cfg != { }) {
      environment.systemPackages = [ klem ];
      nixpkgs.overlays = [
        (_self: _super: {
          klem = klem;
        })
      ];
    };
}
