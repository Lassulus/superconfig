{config, pkgs, lib, ...}: let

  unstable-pkgs = import <nixpkgs-unstable> {};

in {
  # symlink the zigbee controller
  services.udev.extraRules = ''
    SUBSYSTEM=="tty", ATTRS{idVendor}=="0451", ATTRS{idProduct}=="16a8", SYMLINK+="cc2531", MODE="0660", GROUP="dialout"
    SUBSYSTEM=="tty", ATTRS{idVendor}=="10c4", ATTRS{idProduct}=="ea60", SYMLINK+="cc2652", MODE="0660", GROUP="dialout"
  '';

  # needed to use unstable package
  systemd.services.zigbee2mqtt.environment.ZIGBEE2MQTT_DATA = "/var/lib/zigbee2mqtt";

  services.zigbee2mqtt = {
    enable = true;
    package = unstable-pkgs.zigbee2mqtt;
    settings = {
      homeassistant = true;
      frontend.port = 1337;
      experimental.new_api = true;
      permit_join = false;
      mqtt = {
        discovery = true;
        base_topic = "zigbee";
        server = "mqtt://10.42.0.1";
        user = "gg23";
        password = "gg23-mqtt";
      };
      serial = {
        port = "/dev/cc2652";
        # disable_led = true;
      };
      advanced = {
        pan_id = 4222;
      };
      devices = let
        set_device = id: name:
          lib.nameValuePair id {
          };
      in {
        # lights https://www.zigbee2mqtt.io/devices/9290022166.html#philips-9290022166
        "0x0017880106ed3bd8".friendly_name = "l_bett";
        "0x0017880108327622".friendly_name = "l_essen";
        "0x0017880106ee2865".friendly_name = "l_arbeit";
        "0x00178801082e9f2f".friendly_name = "l_nass";

        # switches https://www.zigbee2mqtt.io/devices/324131092621.html#philips-324131092621
        "0x00178801086ac38c".friendly_name = "i_bett";
        "0x00178801086ad1fb".friendly_name = "i_essen";
        "0x00178801086ac373".friendly_name = "i_nass";

        # sensors https://www.zigbee2mqtt.io/devices/9290012607.html#philips-9290012607
        "0x0017880106f772f2".friendly_name = "s_essen";
        "0x0017880106f77f30".friendly_name = "s_nass";

        # heat https://www.zigbee2mqtt.io/devices/701721.html#popp-701721
        "0x842e14fffe27109a".friendly_name = "t_bett";
        "0x842e14fffe269a73".friendly_name = "t_nass";
        "0x842e14fffe269a56".friendly_name = "t_arbeit";

        # rotation https://www.zigbee2mqtt.io/devices/E1744.html
        "0x8cf681fffe065493" = {
          friendly_name = "r_test";
          device_id = "r_test";
          simulated_brightness = {
            delta = 2;
            interval = 100;
          };
        };

      };
    };
  };
}

