{ pkgs, ... }: {

  # usage: pppd call stick

  environment.etc."ppp/peers/stick".text = ''
    /dev/ttyUSB0
    460800
    crtscts
    defaultroute
    holdoff 10
    lock
    maxfail 0
    noauth
    nodetach
    noipdefault
    passive
    persist
    usepeerdns
    connect "${pkgs.ppp}/bin/chat -f ${pkgs.writeText "default.chat" ''
      ABORT "BUSY"
      ABORT "NO CARRIER"
      REPORT CONNECT
      "" "ATDT*99#"
      CONNECT
    ''}"
  '';

  environment.systemPackages = [
    pkgs.ppp
  ];

}

