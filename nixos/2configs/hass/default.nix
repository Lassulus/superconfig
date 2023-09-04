{ config, lib, pkgs, ... }:
with import ./lib.nix { inherit lib; };
let
  dwdwfsapi = pkgs.python3Packages.buildPythonPackage rec {
    pname = "dwdwfsapi";
    version = "1.0.3";

    src = pkgs.python3Packages.fetchPypi {
      inherit pname version;
      sha256 = "0fcv79xiq0qr4kivhd68iqpgrsjc7djxqs2h543pyr0sdgb5nz9x";
    };

    buildInputs = with pkgs.python3Packages; [
      requests ciso8601
    ];

    # LC_ALL = "en_US.UTF-8";
  };

in {
  imports = [
    ./pyscript
    ./zigbee.nix
    ./rooms/bett.nix
    ./rooms/essen.nix
    ./rooms/nass.nix
  ];

  krebs.iptables.tables.filter.INPUT.rules = [
    { predicate = "-i int0 -p tcp --dport 1883"; target = "ACCEPT"; } # mosquitto
    { predicate = "-i docker0 -p tcp --dport 1883"; target = "ACCEPT"; } # mosquitto
    { predicate = "-i int0 -p tcp --dport 8123"; target = "ACCEPT"; } # hass
    { predicate = "-i int0 -p tcp --dport 1337"; target = "ACCEPT"; } # zigbee2mqtt frontend
    { predicate = "-i retiolum -p tcp --dport 8123"; target = "ACCEPT"; } # hass
    { predicate = "-i retiolum -p tcp --dport 1337"; target = "ACCEPT"; } # zigbee2mqtt frontend
    { predicate = "-i wiregrill -p tcp --dport 8123"; target = "ACCEPT"; } # hass
  ];


  services.home-assistant = {
    enable = true;
    configWritable = true;
    lovelaceConfigWritable = true;
    config = let
      tasmota = name: topic: {
        inherit name;
        state_topic = "stat/${topic}/POWER";
        command_topic = "cmnd/${topic}/POWER";
        payload_on = "ON";
        payload_off = "OFF";
      };
    in {
      homeassistant = {
        name = "Home";
        time_zone = "Europe/Berlin";
        latitude = "52.46187";
        longitude = "13.41489";
        elevation = 90;
        unit_system = "metric";
        # customize = friendly_names;
      };
      config = {};
      sun.elevation = 66;
      shopping_list = {};
      discovery = {};
      frontend = {};
      http = {};
      # mqtt = {
      #   broker = "localhost";
      #   port = 1883;
      #   client_id = "home-assistant";
      #   username = "gg23";
      #   password = "gg23-mqtt";
      #   keepalive = 60;
      #   protocol = 3.1;

      #   discovery = true;
      #   birth_message = {
      #     topic = "/hass/status";
      #     payload = "online";
      #   };
      #   will_message = {
      #     topic = "/hass/status";
      #     payload = "offline";
      #   };
      # };
      sensor = [
        {
          platform = "dwd_weather_warnings";
          region_name = "Berlin";
        }
      ];
      mqtt.switch = [
        (tasmota "TV" "tv")
        (tasmota "Drucker Strom" "drucker")
        (tasmota "Waschmaschine" "wasch")
        (tasmota "Stereo Anlage" "stereo")
        (tasmota "Wohnzimmer Lampe" "wohn_lampe")
      ];
      mobile_app = {};
      weather = [
        {
          platform = "openweathermap";
          api_key = "XXX"; # TODO put into secrets
        }
      ];
      system_health = {};
      history = {};
      shopping_list = {};
      media_player = {
        platform = "snapcast";
        host = "127.0.0.1";
      };
    };
  };

  services.mosquitto = {
    enable = true;
    listeners = [{
      acl = [ ];
      users.gg23 = { acl = [ "readwrite #" ]; password = "gg23-mqtt"; };
    }];
  };

  environment.systemPackages = [ pkgs.mosquitto ];
}
