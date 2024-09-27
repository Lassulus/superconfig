{
  self,
  config,
  lib,
  pkgs,
  ...
}:

with lib;

{
  options.lass.nichtparasoup = {
    enable = mkEnableOption "nichtparasoup funny image page";
    config = mkOption {
      type = types.str;
      default = ''
        [General]
        Port: 5001
        IP: 0.0.0.0
        Useragent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_10) AppleWebKit/600.1.25 (KHTML, like Gecko) Version/8.0 Safari/600.1.25

        [Cache]
        Images_min_limit: 15

        [Logging]
        ;; possible destinations: file syslog
        Destination: syslog
        Verbosity: ERROR

        [Sites]
        SoupIO: everyone
        Pr0gramm: new,top
        Reddit: ${
          lib.concatStringsSep "," [
            "2healthbars"
            "abandonedporn"
            "animalsbeingderps"
            "ANormalDayInRussia"
            "assholedesign"
            "AwesomeOffBrands"
            "bizarrebuildings"
            "bonehurtingjuice"
            "boottoobig"
            "bossfight"
            "bravofotogeschichten"
            "breathinginformation"
            "buddhistmemes"
            "cablefail"
            "cableporn"
            "catastrophicfailure"
            "chairsunderwater"
            "clevercomebacks"
            "confusingperspective"
            "conni"
            "crappydesign"
            "cursedcomments"
            "desirepath"
            "doenerverbrechen"
            "dontdeadopeninside"
            "educationalgifs"
            "EngineeringPorn"
            "eyebleach"
            "forbiddensnacks"
            "funnyanimals"
            "gifs"
            "Gittertiere"
            "goodboomerhumor"
            "grssk"
            "halthoch"
            "hmm"
            "hmmm"
            "holdmybeer"
            "holup"
            "iamatotalpieceofshit"
            "ichbin40undlustig"
            "idiotsincars"
            "illegallysmolcats"
            "infokriegerkutschen"
            "instagramreality"
            "instant_regret"
            "itrunsdoom"
            "itsaunixsystem"
            "kamikazebywords"
            "keming"
            "kidsarefuckingstupid"
            "kitchenconfidential"
            "laughingbuddha"
            "LiminalSpace"
            "loadingicon"
            "MachinePorn"
            "mallninjashit"
            "michaelbaygifs"
            "mildlyinfuriating"
            "miscatculations"
            "natureisfuckinglit"
            "nononoyesno"
            "notinteresting"
            "notliketheothergirls"
            "oddlysatisfying"
            "ofcoursethatsathing"
            "okbuddylinux"
            "OSHA"
            "PeopleFuckingDying"
            "Perfectfit"
            "perfectloops"
            "PerfectTiming"
            "picsofunusualbirds"
            "PixelArt"
            "pizzacrimes"
            "prequelmemes"
            "Prisonwallet"
            "reactiongifs"
            "RealFakeDoors"
            "reallifedoodles"
            "RetroFuturism"
            "robotsbeingjerks"
            "SchizophreniaRides"
            "scriptedasiangifs"
            "shitposting"
            "shittyfoodporn"
            "shittyrobots"
            "softwaregore"
            "specializedtools"
            "spicypillows"
            "StallmanWasRight"
            "startledcats"
            "startrekstabilized"
            "stupidfood"
            "techsupportgore"
            "thathappened"
            "ThingsCutInHalfPorn"
            "totallynotrobots"
            "trippinthroughtime"
            "Unexpected"
            "urbanexploration"
            "wasletztepreis"
            "wellthatsucks"
            "wertekinder"
            "wewantplates"
            "whatcouldgowrong"
            "whatsthisbug"
            "whatsthisplant"
            "whatswrongwithyourdog"
            "whenthe"
            "yesyesyesyesno"
            "youseeingthisshit"
          ]
        }
        NineGag: geeky,wtf,hot,trending
        Instagram: nature,wtf
        Fourchan: sci
      '';
    };
  };

  config = mkIf config.lass.nichtparasoup.enable {
    systemd.services.nichtparasoup = {
      description = "nichtparasoup";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];

      restartIfChanged = true;
      serviceConfig = {
        Restart = "always";
        ExecStart = "${
          self.packages.${pkgs.system}.nichtparasoup
        }/bin/nichtparasoup -c ${pkgs.writeText "config.ini" config.lass.nichtparasoup.config}";
      };
    };
  };
}
