{ config, lib, pkgs, ... }:

let

  msmtprc = pkgs.writeText "msmtprc" ''
    defaults
      logfile ~/.msmtp.log
    account prism
      host prism.r
    account c-base
      from lassulus@c-base.org
      host c-mail.c-base.org
      port 465
      tls on
      tls_starttls off
      auth on
      user lassulus
      passwordeval pass show c-base/pass
    account default: prism
  '';

  notmuch-config = pkgs.writeText "notmuch-config" ''
    [database]
    path=/home/lass/Maildir
    mail_root=/home/lass/Maildir

    [user]
    name=lassulus
    primary_email=lassulus@lassul.us
    other_email=lass@mors.r;${lib.concatStringsSep ";" (lib.flatten (lib.attrValues mailboxes))}

    [new]
    tags=unread;inbox;
    ignore=

    [search]
    exclude_tags=deleted;spam;

    [maildir]
    synchronize_flags=true
  '';

  msmtp = pkgs.writeBashBin "msmtp" ''
    ${pkgs.coreutils}/bin/tee >(${pkgs.notmuch}/bin/notmuch insert +sent) | \
      ${pkgs.msmtp}/bin/msmtp -C ${msmtprc} "$@"
  '';

  mailcap = pkgs.writeText "mailcap" ''
    text/html; ${pkgs.elinks}/bin/elinks -dump ; copiousoutput;
  '';

  mailboxes = {
    afra = [ "to:afra@afra-berlin.de" ];
    c-base = [ "to:c-base.org" ];
    coins = [
      "to:btce@lassul.us"
      "to:coinbase@lassul.us"
      "to:polo@lassul.us"
      "to:bitwala@lassul.us"
      "to:payeer@lassul.us"
      "to:gatehub@lassul.us"
      "to:bitfinex@lassul.us"
      "to:binance@lassul.us"
      "to:bitcoin.de@lassul.us"
      "to:robinhood@lassul.us"
    ];
    dezentrale = [ "to:dezentrale.space" ];
    dhl = [ "to:dhl@lassul.us" ];
    dn42 = [ "to:dn42@lists.nox.tf" ];
    eloop = [ "to:eloop.org" ];
    github = [ "to:github@lassul.us" ];
    gmail = [ "to:gmail@lassul.us" "to:lassulus@gmail.com" "lassulus@googlemail.com" ];
    india = [ "to:hillhackers@lists.hillhacks.in" "to:hackbeach@lists.hackbeach.in" "to:hackbeach@mail.hackbeach.in" ];
    kaosstuff = [ "to:gearbest@lassul.us" "to:banggood@lassul.us" "to:tomtop@lassul.us" ];
    lugs = [ "to:lugs@lug-s.org" ];
    meetup = [ "to:meetup@lassul.us" ];
    nix = [ "to:nix-devel@googlegroups.com" "to:nix@lassul.us" ];
    patreon = [ "to:patreon@lassul.us" ];
    paypal = [ "to:paypal@lassul.us" ];
    ptl = [ "to:ptl@posttenebraslab.ch" ];
    retiolum = [ "to:lass@mors.r" ];
    security = [
      "to:seclists.org" "to:bugtraq" "to:securityfocus@lassul.us"
      "to:security-announce@lists.apple.com"
    ];
    shack = [ "to:shackspace.de" ];
    steam = [ "to:steam@lassul.us" ];
    tinc = [ "to:tinc@tinc-vpn.org" "to:tinc-devel@tinc-vpn.org" ];
    wireguard = [ "to:wireguard@lists.zx2c4" ];
    zzz = [ "to:pizza@lassul.us" "to:spam@krebsco.de" ];
  };

  tag-new-mails = pkgs.writeDashBin "nm-tag-init" ''
    ${pkgs.notmuch}/bin/notmuch new
    ${lib.concatMapStringsSep "\n" (i: ''
      mkdir -p "$HOME/Maildir/.${i.name}/cur"
      for mail in $(${pkgs.notmuch}/bin/notmuch search --output=files 'tag:inbox and (${lib.concatMapStringsSep " or " (f: "${f}") i.value})'); do
        if test -e "$mail"; then
          mv "$mail" "$HOME/Maildir/.${i.name}/cur/"
        else
          echo "$mail does not exist"
        fi
      done
      ${pkgs.notmuch}/bin/notmuch tag -inbox +${i.name} -- tag:inbox ${lib.concatMapStringsSep " or " (f: "${f}") i.value}
    '') (lib.mapAttrsToList lib.nameValuePair mailboxes)}
    ${pkgs.notmuch}/bin/notmuch new
    ${pkgs.notmuch}/bin/notmuch dump > "$HOME/Maildir/notmuch.backup"
  '';

  tag-old-mails = pkgs.writeDashBin "nm-tag-old" ''
    set -efux
    ${lib.concatMapStringsSep "\n" (i: ''
      ${pkgs.notmuch}/bin/notmuch tag -inbox -archive +${i.name} -- ${lib.concatMapStringsSep " or " (f: "${f}") i.value}
      mkdir -p "$HOME/Maildir/.${i.name}/cur"
      for mail in $(${pkgs.notmuch}/bin/notmuch search --output=files ${lib.concatMapStringsSep " or " (f: "${f}") i.value}); do
        if test -e "$mail"; then
          mv "$mail" "$HOME/Maildir/.${i.name}/cur/"
        else
          echo "$mail does not exist"
        fi
      done
    '') (lib.mapAttrsToList lib.nameValuePair mailboxes)}
    ${pkgs.notmuch}/bin/notmuch new --no-hooks
  '';

  muttrc = pkgs.writeText "muttrc" ''

    # read html mails
    auto_view text/html
    set mailcap_path = ${mailcap}

    # notmuch
    set folder="$HOME/Maildir"
    set nm_default_uri = "notmuch://$HOME/Maildir"
    set nm_record = yes
    set nm_record_tags = "-inbox me archive"
    set spoolfile = +Inbox
    set virtual_spoolfile = yes


    set sendmail="${msmtp}/bin/msmtp"            # enables parsing of outgoing mail
    set from="lassulus@lassul.us"
    alternates ^.*@lassul\.us$ ^.*@.*\.r$
    unset envelope_from_address
    set use_envelope_from
    set reverse_name

    set sort=threads

    set index_format="%4C %Z %?GI?%GI& ? %[%y-%m-%d] %-20.20a %?M?(%3M)& ? %s %> %r %g"

    virtual-mailboxes "Unread" "notmuch://?query=tag:unread"
    virtual-mailboxes "INBOX" "notmuch://?query=tag:inbox"
    ${lib.concatMapStringsSep "\n" (i: ''${"  "}virtual-mailboxes "${i.name}" "notmuch://?query=tag:${i.name}"'') (lib.mapAttrsToList lib.nameValuePair mailboxes)}
    virtual-mailboxes "TODO" "notmuch://?query=tag:TODO"
    virtual-mailboxes "Starred" "notmuch://?query=tag:*"
    virtual-mailboxes "Archive" "notmuch://?query=tag:archive"
    virtual-mailboxes "Sent" "notmuch://?query=tag:sent"
    virtual-mailboxes "Junk" "notmuch://?query=tag:junk"
    virtual-mailboxes "All" "notmuch://?query=*"

    tag-transforms "junk"     "k" \
                   "unread"   "u" \
                   "replied"  "↻" \
                   "TODO"     "T" \

    # notmuch bindings
    macro index \\\\ "<vfolder-from-query>"                   # looks up a hand made query
    macro index + "<modify-labels>+*\n<sync-mailbox>"         # tag as starred
    macro index - "<modify-labels>-*\n<sync-mailbox>"         # tag as unstarred

    # muchsync
    bind index \Cr noop
    macro index \Cr \
    "<enter-command>unset wait_key<enter> \
    <shell-escape>${pkgs.writeDash "muchsync" ''
      set -efu
      until ${pkgs.muchsync}/bin/muchsync -F lass@green.r; do
        sleep 1
      done
    ''}<enter>

    #killed
    bind index d noop
    bind pager d noop

    bind index S noop
    bind index s noop
    bind pager S noop
    bind pager s noop
    macro index S "<modify-labels-then-hide>-inbox -unread +junk\n" # tag as Junk mail
    macro index s "<modify-labels>-junk\n" # tag as Junk mail
    macro pager S "<modify-labels-then-hide>-inbox -unread +junk\n" # tag as Junk mail
    macro pager s "<modify-labels>-junk\n" # tag as Junk mail


    bind index A noop
    bind index a noop
    bind pager A noop
    bind pager a noop
    macro index A "<modify-labels>+archive -unread -inbox\n"  # tag as Archived
    macro index a "<modify-labels>-archive\n"  # tag as Archived
    macro pager A "<modify-labels>+archive -unread -inbox\n"  # tag as Archived
    macro pager a "<modify-labels>-archive\n"  # tag as Archived


    bind index U noop
    bind index u noop
    bind pager U noop
    bind pager u noop
    macro index U "<modify-labels>+unread\n"
    macro index u "<modify-labels>-unread\n"
    macro pager U "<modify-labels>+unread\n"
    macro pager u "<modify-labels>-unread\n"


    bind index t noop
    bind pager t noop
    macro index t "<modify-labels>"        # tag as Archived

    # top index bar in email view
    set pager_index_lines=7
    # top_index_bar toggle
    macro pager ,@1 "<enter-command> set pager_index_lines=0; macro pager ] ,@2 'Toggle indexbar<Enter>"
    macro pager ,@2 "<enter-command> set pager_index_lines=3; macro pager ] ,@3 'Toggle indexbar<Enter>"
    macro pager ,@3 "<enter-command> set pager_index_lines=7; macro pager ] ,@1 'Toggle indexbar<Enter>"
    macro pager ] ,@1 'Toggle indexbar

    # urlview
    macro pager \cb <pipe-entry>'${pkgs.urlview}/bin/urlview'<enter> 'Follow links with urlview'

    # sidebar
    set sidebar_divider_char = '│'
    set sidebar_delim_chars = "/"
    set sidebar_short_path
    set sidebar_folder_indent
    set sidebar_visible = yes
    set sidebar_format = '%D%?F? [%F]?%* %?N?%N/? %?S?%S?'
    set sidebar_width   = 20
    color sidebar_new yellow red

    # sidebar bindings
    bind index <left> sidebar-prev          # got to previous folder in sidebar
    bind index <right> sidebar-next         # got to next folder in sidebar
    bind index <space> sidebar-open         # open selected folder from sidebar
    # sidebar toggle
    macro index,pager ,@) "<enter-command> set sidebar_visible=no; macro index,pager [ ,@( 'Toggle sidebar'<Enter>"
    macro index,pager ,@( "<enter-command> set sidebar_visible=yes; macro index,pager [ ,@) 'Toggle sidebar'<Enter>"
    macro index,pager [ ,@( 'Toggle sidebar'      # toggle the sidebar
  '';

  mutt = pkgs.symlinkJoin {
    name = "mutt";
    paths = [
      (pkgs.writeDashBin "mutt" ''
        exec ${pkgs.neomutt}/bin/neomutt -F ${muttrc} "$@"
      '')
      pkgs.neomutt
    ];
  };

in {
  environment.variables.NOTMUCH_CONFIG = toString notmuch-config;
  environment.systemPackages = [
    msmtp
    mutt
    pkgs.notmuch
    pkgs.muchsync
    tag-new-mails
    tag-old-mails
  ];
}
