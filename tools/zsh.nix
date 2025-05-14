{ ... }:
{
  perSystem =
    { pkgs, ... }:
    let
      zshrc = ''
        autoload -U compinit && compinit

        # Setup custom interactive shell init stuff.
        # Bind gpg-agent to this TTY if gpg commands are used.
        export GPG_TTY=$(tty)

        # show how long a command takes
        ZSH_COMMAND_TIME_MIN_SECONDS=3
        ZSH_COMMAND_TIME_EXCLUDE=(vim)
        ZSH_COMMAND_TIME_MSG="took: %s sec"
        source ${
          pkgs.fetchFromGitHub {
            owner = "popstas";
            repo = "zsh-command-time";
            rev = "803d26eef526bff1494d1a584e46a6e08d25d918";
            hash = "sha256-ndHVFcz+XmUW0zwFq7pBXygdRKyPLjDZNmTelhd5bv8=";
          }
        }/command-time.plugin.zsh

        unsetopt nomatch # no matches found urls
        setopt autocd extendedglob
        bindkey -e

        #C-x C-e open line in editor
        autoload -z edit-command-line
        zle -N edit-command-line
        bindkey "^X^E" edit-command-line

        #fzf inclusion
        source ${pkgs.fzf}/share/fzf/completion.zsh
        source ${pkgs.fzf}/share/fzf/key-bindings.zsh

        # atuin distributed shell history
        if type -p atuin >/dev/null; then
          export ATUIN_CONFIG_DIR=${pkgs.writeTextDir "/config.toml" ''
            auto_sync = true
            update_check = false
            sync_address = "http://green.r:8888"
            sync_frequency = 0
            style = "compact"
          ''};
          export ATUIN_NOBIND="true" # disable all keybdinings of atuin
          eval "$(${pkgs.atuin}/bin/atuin init zsh)" # TODO make this optional?
          bindkey '^r' _atuin_search_widget # bind ctrl+r to atuin
          # use zsh only session history
          fc -p
        fi

        #completion magic
        autoload -Uz compinit
        compinit
        zstyle ':completion:*' menu select

        #enable automatic rehashing of $PATH
        zstyle ':completion:*' rehash true

        # fancy mv which interactively gets the second argument if not given
        function mv() {
          if [[ "$#" -ne 1 ]] || [[ ! -e "$1" ]]; then
            command mv -v "$@"
            return
          fi

          newfilename="$1"
          vared newfilename
          command mv -v -- "$1" "$newfilename"
        }

        #emacs bindings
        bindkey "[7~" beginning-of-line
        bindkey "[8~" end-of-line
        bindkey "Oc" emacs-forward-word
        bindkey "Od" emacs-backward-word

        # direnv integration
        eval "$(${pkgs.direnv}/bin/direnv hook zsh)"

        # This function is called whenever a command is not found.
        command_not_found_handler() {
          local p='${pkgs.nix-index}/etc/profile.d/command-not-found.sh'
          if [ -x "$p" ] && [ -f '/nix/var/nix/profiles/per-user/root/channels/nixos/programs.sqlite' ]; then
            # Run the helper program.
            "$p" "$@"

            # Retry the command if we just installed it.
            if [ $? = 126 ]; then
              "$@"
            else
              return 127
            fi
          else
            # Indicate than there was an error so ZSH falls back to its default handler
            echo "$1: command not found" >&2
            return 127
          fi
        }

        download_nixpkgs_cache_index () {
          filename="index-$(uname -m | sed 's/^arm64$/aarch64/')-$(uname | tr A-Z a-z)"
          mkdir -p ~/.cache/nix-index && cd ~/.cache/nix-index
          # -N will only download a new version if there is an update.
          wget -q -N https://github.com/nix-community/nix-index-database/releases/latest/download/$filename
          ln -f $filename files
        }

        # Setup aliases.
        alias -- grep='grep --color=auto'
        alias -- ip='ip -color=auto'
        alias -- l='ls -alh'
        alias -- la='ls -la'
        alias -- ll='ls -l'
        alias -- ls='ls --color'
        alias -- ns='nix-shell --command zsh'
        alias -- nb='nix build --no-link --print-out-paths -L'
        alias -- ne='nix eval --json'
        alias -- nloc='nix-locate --top-level --whole-name'

        # Setup prompt.
        autoload -U promptinit
        promptinit

        p_error='%(?..%F{red}%?%f )'
        t_error='%(?..%? )'

        case $UID in
          0)
            p_username='%F{red}root%f'
            t_username='root'
            ;;
          1337)
            p_username=""
            t_username=""
            ;;
          *)
            p_username='%F{blue}%n%f'
            t_username='%n'
            ;;
        esac

        if test -n "$SSH_CLIENT"; then
          p_hostname='@%F{magenta}%M%f '
          t_hostname='@%M '
        else
          p_hostname=""
          t_hostname=""
        fi

        #check if in nix shell
        if test -n "$IN_NIX_SHELL"; then
          p_nixshell='%F{green}[s]%f '
          t_nixshell='[s] '
        else
          p_nixshell=""
          t_nixshell=""
        fi

        PROMPT="$p_error$p_username$p_hostname$p_nixshell%~ "
        TITLE="$t_error$t_username$t_hostname$t_nixshell%~"
        case $TERM in
          (*xterm* | *rxvt*)
            function precmd {
              PROMPT_EVALED=$(print -P "$TITLE")
              echo -ne "\033]0;$$ $PROMPT_EVALED\007"
            }
            # This seems broken for some reason
            # # This is seen while the shell waits for a command to complete.
            # function preexec {
            #   PROMPT_EVALED=$(print -P "$TITLE")
            #   echo -ne "\033]0;$$ $PROMPT_EVALED $1\007"
            # }
          ;;
        esac


        # Disable some features to support TRAMP.
        if [ "$TERM" = dumb ]; then
            unsetopt zle prompt_cr prompt_subst
            unset RPS1 RPROMPT
            PS1='$ '
            PROMPT='$ '
        fi
      '';
    in
    {
      packages.shell = pkgs.writeScriptBin "shell" ''
        #!/bin/sh
        export ZDOTDIR=${pkgs.writeTextDir "/.zshrc" zshrc}
        exec ${pkgs.zsh}/bin/zsh "$@"
      '';
      packages.zsh = pkgs.writeScriptBin "zsh" ''
        #!/bin/sh
        export ZDOTDIR=${pkgs.writeTextDir "/.zshrc" zshrc}
        exec ${pkgs.zsh}/bin/zsh "$@"
      '';
    };
}
