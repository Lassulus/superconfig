{
  users.extraUsers = {
    games = {
      name = "games";
      description = "user playing games";
      home = "/home/games";
      extraGroups = [
        "audio"
        "video"
        "input"
        "loot"
        "pipewire"
      ];
      createHome = true;
      useDefaultShell = true;
      isNormalUser = true;
    };
  };

  hardware.graphics.enable32Bit = true;
  services.pulseaudio.support32Bit = true;

}
