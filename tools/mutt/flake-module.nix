{ self, ... }:
{
  perSystem =
    {
      pkgs,
      lib,
      system,
      ...
    }:
    {
      packages.mutt =
        let
          # Mailboxes configuration from mail.nix
          mailboxes = self.packages.${system}.notmuch.mailboxes;
          notmuchConfig = self.packages.${system}.notmuch.passthru.config.configFile.path;

          mailcap = pkgs.writeText "mailcap" ''
            text/html; ${pkgs.elinks}/bin/elinks -dump ; copiousoutput;
          '';

          msmtprc = pkgs.writeText "msmtprc" ''
            defaults
              logfile ~/.msmtp.log
            account prism
              host neoprism.r
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

          msmtp = pkgs.writeShellScriptBin "msmtp" ''
            # Check if using c-base account (either explicit -a c-base or via From: header)
            using_cbase=0
            for arg in "$@"; do
              if [[ "$arg" == "c-base" ]] || [[ "$arg" =~ @c-base\.org ]]; then
                using_cbase=1
                break
              fi
            done

            # For c-base account, always send directly
            if [ "$using_cbase" -eq 1 ]; then
              ${pkgs.coreutils}/bin/tee >(${pkgs.notmuch}/bin/notmuch insert +sent) | \
                ${pkgs.msmtp}/bin/msmtp -C ${msmtprc} "$@"
            # For default account, try neoprism.r first, then SSH
            elif ping -W2 -c1 neoprism.r >/dev/null 2>&1; then
              ${pkgs.coreutils}/bin/tee >(${pkgs.notmuch}/bin/notmuch insert +sent) | \
                ${pkgs.msmtp}/bin/msmtp -C ${msmtprc} "$@"
            else
              # Fall back to SSH tunnel to neoprism, submit via SMTP to local daemon
              echo "neoprism.r not reachable, sending via SSH..." >&2
              ${pkgs.coreutils}/bin/tee >(${pkgs.notmuch}/bin/notmuch insert +sent) | \
                ${pkgs.openssh}/bin/ssh -p 45621 neoprism.lassul.us 'msmtp -C /dev/null --host=localhost --port=25 --read-envelope-from --read-recipients'
            fi
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

            set sendmail="${msmtp}/bin/msmtp"
            set from="lassulus@lassul.us"
            alternates ^.*@lassul\.us$ ^.*@.*\.r$
            unset envelope_from_address
            set use_envelope_from
            set reverse_name
            set markers=no

            set sort=threads

            set index_format="%4C %Z %?GI?%GI& ? %[%y-%m-%d] %-20.20a %?M?(%3M)& ? %s %> %r %g"

            virtual-mailboxes "Unread" "notmuch://?query=tag:unread"
            virtual-mailboxes "INBOX" "notmuch://?query=tag:inbox"
            ${lib.concatMapStringsSep "\n" (
              i: ''${"  "}virtual-mailboxes "${i.name}" "notmuch://?query=tag:${i.name}"''
            ) (lib.mapAttrsToList lib.nameValuePair mailboxes)}
            virtual-mailboxes "TODO" "notmuch://?query=tag:TODO"
            virtual-mailboxes "Starred" "notmuch://?query=tag:*"
            virtual-mailboxes "Archive" "notmuch://?query=tag:archive"
            virtual-mailboxes "Sent" "notmuch://?query=tag:sent"
            virtual-mailboxes "Junk" "notmuch://?query=tag:junk"
            virtual-mailboxes "All" "notmuch://?query=*"

            # clan.lol IMAP - no mailboxes declaration to prevent any startup connection
            # Select the separator entry in sidebar, folder-hook will redirect to the IMAP server
            virtual-mailboxes "clan-infra" "notmuch://?query=tag:nonexistent-separator-tag"
            account-hook imaps://mail.clan.lol "set imap_user = 'infra@clan.lol'; set imap_pass = \"\`SOPS_AGE_KEY=\$(rbw get --folder clan.lol clan-infra --field age-key) nix develop git+https://git.clan.lol/clan/clan-infra -c clan vars get --flake git+https://git.clan.lol/clan/clan-infra web01 infra-mail/infra-password\`\""
            folder-hook "notmuch://\\?query=tag:nonexistent-separator-tag" "push '<change-folder>imaps://mail.clan.lol<enter>'"

            tag-transforms "junk"     "k" \
                           "unread"   "u" \
                           "replied"  "↻" \
                           "TODO"     "T" \

            # notmuch bindings
            macro index \\\\ "<vfolder-from-query>"
            macro index + "<modify-labels>+*\n<sync-mailbox>"
            macro index - "<modify-labels>-*\n<sync-mailbox>"

            # muchsync
            bind index \Cr noop
            macro index \Cr \
            "<enter-command>unset wait_key<enter> \
            <sync-mailbox> \
            <shell-escape>${self.packages.${pkgs.system}.muchsync}/bin/muchsync -vv<enter> \
            <sync-mailbox>

            #killed
            bind index d noop
            bind pager d noop

            bind index S noop
            bind index s noop
            bind pager S noop
            bind pager s noop
            macro index S "<modify-labels-then-hide>-inbox -unread +junk\n"
            macro index s "<modify-labels>-junk\n"
            macro pager S "<modify-labels-then-hide>-inbox -unread +junk\n"
            macro pager s "<modify-labels>-junk\n"

            bind index A noop
            bind index a noop
            bind pager A noop
            bind pager a noop
            macro index A "<modify-labels>+archive -unread -inbox\n"
            macro index a "<modify-labels>-archive\n"
            macro pager A "<modify-labels>+archive -unread -inbox\n"
            macro pager a "<modify-labels>-archive\n"

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
            macro index t "<modify-labels>"

            # top index bar in email view
            set pager_index_lines=7
            # top_index_bar toggle
            macro pager ,@1 "<enter-command> set pager_index_lines=0; macro pager ] ,@2 'Toggle indexbar<Enter>"
            macro pager ,@2 "<enter-command> set pager_index_lines=3; macro pager ] ,@3 'Toggle indexbar<Enter>"
            macro pager ,@3 "<enter-command> set pager_index_lines=7; macro pager ] ,@1 'Toggle indexbar<Enter>"
            macro pager ] ,@1 'Toggle indexbar

            # scan urls from emails
            macro index,pager \cb "<pipe-message> ${lib.getExe pkgs.urlscan}<Enter>"
            macro attach,compose \cb "<pipe-entry> ${lib.getExe pkgs.urlscan}<Enter>"

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
            bind index <left> sidebar-prev
            bind index <right> sidebar-next
            bind index <space> sidebar-open
            # sidebar toggle
            macro index,pager ,@) "<enter-command> set sidebar_visible=no; macro index,pager [ ,@( 'Toggle sidebar'<Enter>"
            macro index,pager ,@( "<enter-command> set sidebar_visible=yes; macro index,pager [ ,@) 'Toggle sidebar'<Enter>"
            macro index,pager [ ,@( 'Toggle sidebar'

            # forward with attachment
            set mime_forward = no
            set forward_attachments = yes

            # better handling of long URLs
            set wrap = 0  # don't wrap lines in the pager
            set markers = no  # don't show + markers for wrapped lines
            set smart_wrap = yes  # wrap at word boundaries when displaying
            set pager_stop = yes  # don't jump to next message at end of pager
          '';

        in
        (self.wrapLib.makeWrapper {
          pkgs = pkgs;
          package = pkgs.neomutt;
          aliases = [ "mutt" ];
          runtimeInputs = [
            pkgs.elinks
            pkgs.msmtp
            pkgs.notmuch
            pkgs.openssh
            pkgs.urlscan
          ]
          ++ lib.optionals pkgs.stdenv.isLinux [
            pkgs.iputils
          ];
          env = {
            NOTMUCH_CONFIG = notmuchConfig;
          };
          flags = {
            "-F" = "${muttrc}";
          };
        }).overrideAttrs (old: {
          passthru = (old.passthru or { }) // {
            inherit msmtp;
          };
        });
    };
}
