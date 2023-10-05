{
  environment.etc."ppp/options-mobile".text = ''
    ttyACM2
    921600
    lock
    crtscts
    modem
    passive
    novj
    defaultroute
    noipdefault
    usepeerdns
    noauth
    hide-password
    persist
    holdoff 10
    maxfail 0
    debug
  '';

  environment.etc."ppp/peers/provider".text

