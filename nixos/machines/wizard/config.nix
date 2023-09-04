{ config, lib, pkgs, ... }:

let

  icon = pkgs.writeText "icon" ''
                    //
                    //
                  _ //
               .' . // '.
              '_ '_\/_'  `_
              .  . \\  .  .
             .==. ` \\' .'
      .\|   //bd\\   \,
      \_'`._\\__//_.'`.;
        `.__      __,' \\
            |    |      \\
            |    |       `
            |    |
            |    |
            |____|
    l42    =='  '==
  '';

  messenger = pkgs.writeText "message" ''
                                 .
                              | \/|
      (\   _                  ) )|/|
          (/            _----. /.'.'
    .-._________..      .' @ _\  .'
    '.._______.   '.   /    (_| .')
      '._____.  /   '-/      | _.'
       '.______ (         ) ) \
         '..____ '._       )  )
            .' __.--\  , ,  // ((
            '.'  mrf|  \/   (_.'(
                    '   \ .'
                     \   (
                      \   '.
                       \ \ '.)
                        '-'-'
  '';

  waiting = pkgs.writeText "waiting" ''
                             Z
                       Z
                    z
                  z
              * '
             / \
            /___\
           ( - - )
           )  L  (           .--------------.
         __()(-)()__      | \              |
      .~~  )()()()  ~.    |  .             :
     /      )()()     `   |   `-.__________)
    |        )()  ~       |  :             :
    |         )           |  :  |
    |    _                |     |   [ ##   :
     \    ~~-.            |  ,   oo_______.'
      `_   ( \) _____/~~~~ `--___
      | ~`-)  ) `-.   `---   ( - a:f -
      |   '///`  | `-.
      |     | |  |    `-.
      |     | |  |       `-.
      |     | |\ |
      |     | | \|
       `-.  | |  |
          `-| '
  '';

  wizard = pkgs.writers.writeDash "wizard" ''
    cat ${icon}

    echo -n '${''
      welcome to the computer wizard
      first we will check for internet connectivity

    ''}'

    read -p '(press enter to continue...)' key
    until ping -c1 8.8.8.8; do
      ${pkgs.nm-dmenu}/bin/nm-dmenu
    done

    mode=$(echo -n '${''
      1. Help of the wizard
      2. Install NixOS
      3. I know what I need to do
    ''}' | ${pkgs.fzf}/bin/fzf --reverse)
    case "$mode" in
      1*)
        echo 'mode_1' > /tmp/mode
        clear
        echo 'waiting for the messenger to reach the wizard'
        cat ${messenger}

        # get pubkeys
        mkdir -p /root/.ssh/
        touch /root/.ssh/authorized_keys
        curl -Ss 'https://lassul.us/mors.pub' >> /root/.ssh/authorized_keys
        curl -Ss 'https://lassul.us/blue.pub' >> /root/.ssh/authorized_keys
        curl -Ss 'https://lassul.us/yubi.pub' >> /root/.ssh/authorized_keys

        # write via irc
        systemctl start hidden-ssh-announce.service
        tmux new-session -s help ${pkgs.writers.writeDash "waiting" ''
          cat ${waiting}
          read -p 'waiting for the wizard to wake up' key
          ${pkgs.bashInteractive}/bin/bash
        ''}
        ;;
      2*)
        echo 'mode_2' > /tmp/mode
        ${pkgs.nixos-installer}/bin/nixos-installer
        ;;
      3*)
        echo 'mode_3' > /tmp/mode
        ;;
      *)
        echo 'no mode selected'
        ;;
    esac
  '';

in {
  imports = [
    <stockholm/krebs>
    <stockholm/lass/3modules>
    <stockholm/lass/2configs/vim.nix>
    # <nixpkgs/nixos/modules/installer/cd-dvd/installation-cd-base.nix>
    {
      nixpkgs.config.packageOverrides = import <stockholm/lass/5pkgs> pkgs;
      krebs.enable = true;
      krebs.build.user = config.krebs.users.lass;
      krebs.build.host = {};
    }
    # {
    #   systemd.services.wizard = {
    #     description = "Computer Wizard";
    #     wantedBy = [ "multi-user.target" ];
    #     serviceConfig = {
    #       ExecStart = pkgs.writers.writeDash "wizard" ''
    #         set -efu
    #         cat <<EOF
    #         welcome to the computer wizard
    #         you can choose between the following modes
    #         echo -n '1\n2\n3' | ${pkgs.fzf}/bin/fzf
    #         EOF
    #       '';
    #       StandardInput = "tty";
    #       StandardOutput = "tty";
    #       # TTYPath = "/dev/tty1";
    #       TTYPath = "/dev/ttyS0";
    #       TTYReset = true;
    #       TTYVTDisallocate = true;
    #       Restart = "always";
    #     };
    #   };
    # }
  ];

  networking.hostName = "wizard";
  nixpkgs.config.allowUnfree = true;

  # users.extraUsers = {
  #   root = {
  #     openssh.authorizedKeys.keys = [
  #       config.krebs.users.lass.pubkey
  #       config.krebs.users.lass-mors.pubkey
  #     ];
  #   };
  # };

  environment.systemPackages = with pkgs; [
  #stockholm
    git
    gnumake
    jq
    parallel
    proot
    populate

  #style
    most
    rxvt-unicode-unwrapped.terminfo

  #monitoring tools
    htop
    iotop

  #network
    iptables
    iftop
    nm-dmenu

  #stuff for dl
    aria2

  #neat utils
    chntpw
    hashPassword
    krebspaste
    pciutils
    psmisc
    tmux
    usbutils

  #unpack stuff
    p7zip
    unzip
    unrar

  #data recovery
    ddrescue
    ntfs3g
    dosfstools

    nixos-installer
  ];

  environment.extraInit = ''
    EDITOR=vim
  '';

  programs.bash = {
    enableCompletion = true;
    interactiveShellInit = ''
      HISTCONTROL='erasedups:ignorespace'
      HISTSIZE=65536
      HISTFILESIZE=$HISTSIZE

      shopt -s checkhash
      shopt -s histappend histreedit histverify
      shopt -s no_empty_cmd_completion
      complete -d cd
    '';
    promptInit = ''
      if test $UID = 0; then
        PS1='\[\033[1;31m\]\w\[\033[0m\] '
        PROMPT_COMMAND='echo -ne "\033]0;$$ $USER@$PWD\007"'
      elif test $UID = 1337; then
        PS1='\[\033[1;32m\]\w\[\033[0m\] '
        PROMPT_COMMAND='echo -ne "\033]0;$$ $PWD\007"'
      else
        PS1='\[\033[1;33m\]\u@\w\[\033[0m\] '
        PROMPT_COMMAND='echo -ne "\033]0;$$ $USER@$PWD\007"'
      fi
      if test -n "$SSH_CLIENT"; then
        PS1='\[\033[35m\]\h'" $PS1"
        PROMPT_COMMAND='echo -ne "\033]0;$$ $HOSTNAME $USER@$PWD\007"'
      fi
      if ! test -e /tmp/mode; then
        ${wizard}
      fi
    '';
  };

  services.openssh.enable = true;
  systemd.services.sshd.wantedBy = mkForce [ "multi-user.target" ];

  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 22 ];
  };
  networking.networkmanager.enable = true;
  networking.wireless.enable = mkForce false;

  krebs.hidden-ssh = {
    enable = true;
    channel = "##lassulus-wizard";
    message = "lassulus: torify sshn root@";
  };
  systemd.services.hidden-ssh-announce.wantedBy = mkForce [];
  services.getty.autologinUser = lib.mkForce "root";

  nixpkgs.config.packageOverrides = super: {
    dmenu = pkgs.writeDashBin "dmenu" ''
      ${pkgs.fzf}/bin/fzf \
        --history=/dev/null \
        --print-query \
        --prompt=\"$PROMPT\"
    '';
  };

  boot.tmpOnTmpfs = true;
}
