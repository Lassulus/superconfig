{ config, lib, pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    atuin
    direnv
    fzf
  ];
  environment.variables.ATUIN_CONFIG_DIR = toString (pkgs.writeTextDir "/config.toml" ''
    auto_sync = true
    update_check = false
    sync_address = "http://green.r:8888"
    sync_frequency = 0
    style = "compact"
  '');
  programs.zsh = {
    enable = true;
    shellInit = ''
      #disable config wizard
      zsh-newuser-install() { :; }
    '';
    interactiveShellInit = ''
      unsetopt nomatch # no matches found urls
      setopt autocd extendedglob
      bindkey -e


      # # setopt inc_append_history
      # bindkey '^R' history-incremental-search-backward

      #C-x C-e open line in editor
      autoload -z edit-command-line
      zle -N edit-command-line
      bindkey "^X^E" edit-command-line

      #fzf inclusion
      source ${pkgs.fzf}/share/fzf/completion.zsh
      source ${pkgs.fzf}/share/fzf/key-bindings.zsh

      # atuin distributed shell history
      export ATUIN_NOBIND="true" # disable all keybdinings of atuin
      eval "$(atuin init zsh)"
      bindkey '^r' _atuin_search_widget # bind ctrl+r to atuin
      # use zsh only session history
      fc -p

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

      #beautiful colors
      eval $(dircolors -b ${pkgs.fetchFromGitHub {
        owner = "trapd00r";
        repo = "LS_COLORS";
        rev = "a75fca8545f91abb8a5f802981033ef54bf1eac0";
        sha256="1lzj0qnj89mzh76ha137mnz2hf86k278rh0y9x124ghxj9yqsnb4";
      }}/LS_COLORS)
      zstyle ':completion:*:default' list-colors ''${(s.:.)LS_COLORS}

      #emacs bindings
      bindkey "[7~" beginning-of-line
      bindkey "[8~" end-of-line
      bindkey "Oc" emacs-forward-word
      bindkey "Od" emacs-backward-word

      # direnv integration
      eval "$(${pkgs.direnv}/bin/direnv hook zsh)"
    '';
    promptInit = ''
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
    '';
  };
  environment.shellAliases.ns = "nix-shell --command zsh";

  users.defaultUserShell = "/run/current-system/sw/bin/zsh";
}
