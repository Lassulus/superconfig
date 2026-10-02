{ pkgs, ... }:

let
  mcExt = pkgs.writeText "mc.ext" ''
    # Midnight Commander 4.0 extension file
    #
    # Warning: The structure of this file has been completely changed with the version 4.0!
    #
    # All lines starting with # or empty lines are ignored.
    #
    # IMPORTANT: mc scans this file only upon first use or after editing it using the
    # mc "Edit extension file" command (F9-c-e). If you edit this file in any other way
    # while mc is running, you will need to press F9-c-e and exit the editor for your
    # changes to take effect, or exit mc and start it again.
    #
    # Section name can be anything with following exceptions:
    #    there are two reserved section names:
    #        mc.ext.ini
    #        Default
    #    special name pattern:
    #        Include/xxxxx
    # See below for more details.
    #
    # Section [mc.ext.ini] is mandatory. It contains file metadata.
    # "Version" parameter is mandatory. It contains the file format version.
    #
    # Section [Default] is optional. It is applied only if no other match was found.
    #
    # Sections like [Include/xxxx] can be referenced as "Include=xxxx" from other sections.
    # Section [Include/xxxx] can be located as before as after sections that point to it.
    #
    # Sections are processed from top to bottom, thus the order is important.
    # If there are more than one sections with the same name in this file, the first
    # section will be used.
    #
    # [Default] should be a catch-all action and come last.
    #
    # A section describing a file can contain following keys:
    #
    #    File descriptions:
    #
    #        Directory
    #            Matches any directory matching regular expression.
    #            Always case sensitive.
    #            This key has the highest priority over other keys. If this key is in a section,
    #            other keys are ignored.
    #
    #        Type
    #            Matches files if `file %f` matches regular expression
    #            (the "filename:" part is removed from `file %f` output).
    #            Ignored if the "file" utility isn't used (not found during the configure step
    #            or disabled in the ini-file).
    #
    #        TypeIgnoreCase [true|false]
    #            Defines whether the Type value is case sensitive or not.
    #            If absent, Type is case sensitive.
    #
    #        Regex
    #            An extended regular expression
    #            Please note that we are using the PCRE library and thus \| matches
    #            the literal | and | has a special meaning (or), and () have a special meaning
    #            and \( \) stand for literal ( ).
    #
    #            Example:
    #                Regex=\.t(ar\.lzma|lz)$
    #            matches *.tar.lzma or *.tlz.
    #
    #        RegexIgnoreCase [true|false]
    #            Defines whether the Regex value is case sensitive or not.
    #            If absent, Regex is case sensitive.
    #
    #        Shell
    #            Describes an extension when starting with a dot (no wildcards).
    #
    #            Example:
    #                Shell=.tar
    #            matches *.tar.
    #
    #            If it doesn't start with a dot, it matches only a file of that name.
    #
    #            If both keys Regex and Shell are in the same section, Regex is used
    #            and Shell is ignored.
    #
    #        ShellIgnoreCase [true|false]
    #            Defines whether the Shell value is case sensitive or not.
    #            If absent, Shell is case sensitive.
    #
    #        Include
    #            Reference to another section.
    #
    #            Example:
    #                Include=video
    #            points to the [Include/video] section.
    #
    #    Commands:
    #
    #        Open
    #            Execute the command if the user presses Enter or doubleclicks it.
    #
    #        View
    #            Execute the command if the user presses F3.
    #
    #        Edit
    #            Execute the command if the user presses F4.
    #
    #    All commands are ignored if the section contains the Include key.
    #
    #    Command is any one-line shell command, with the following substitutions:
    #
    #        %%
    #            The % character
    #
    #        %p
    #            Name of the current file without the path.
    #            Also provided to the external application as MC_EXT_BASENAME environment variable.
    #
    #        %f
    #            Name of the current file. Unlike %p, if the file is located on a non-local
    #            virtual filesystem, that is either tarfs or ftpfs, then the file will be
    #            temporarily copied into a local directory and %f will be the full path
    #            to this local temporary file.
    #            If you don't want to get a local copy and want to get the virtual fs path
    #            (like /ftp://ftp.cvut.cz/pub/hungry/xword), then use %d/%p instead of %f.
    #            Also provided to the external application as MC_EXT_FILENAME environment variable.
    #
    #        %d
    #            Name of the current directory without the trailing slash (`pwd`).
    #            Also provided to the external application as MC_EXT_CURRENTDIR environment variable.
    #
    #        %s
    #            "Selected files", that is space separated list of tagged files if any or the name
    #            of the current file.
    #            Also provided to the external application as MC_EXT_SELECTED environment variable.
    #
    #        %t
    #            List of the tagged files.
    #            Also provided to the external application as MC_EXT_ONLYTAGGED environment variable.
    #
    #        %u
    #            List of the tagged files (they will be untaged after the command is executed).
    #
    #        (If the letter following the % is uppercase, then it refers to the opposite panel.
    #        But you shouldn't have to use it in this file.)
    #
    #        %cd
    #            The rest is a path mc should change into (cd won't work, since it's a child process).
    #            %cd handles even vfs names.
    #
    #        %view
    #            The command output will be piped into mc's internal file viewer. If you use
    #            only %view and no command, the viewer will load %f file instead (that is no piping,
    #            which is the difference to %view cat %f).
    #
    #            %view may be directly followed by {} with one or more of the following
    #            separated by commas:
    #                ascii (ascii mode)
    #                hex (hex mode),
    #                nroff (color highlighting for text using escape sequences),
    #                unform (no highlighting for nroff sequences)
    #
    #        %var{VAR:default}
    #            This macro will expand to the value of the VAR variable in the environment if it's
    #            set, otherwise the default value will be used. This is similar to the Bourne shell
    #            ''${VAR-default} construct.
    #
    #    Section can contain both Type and Regex or Type and Shell keys. In this case
    #    they are handled as an AND condition.
    #
    #    Example:
    #        Shell=.3gp
    #        Type=^ISO Media.*3GPP
    #
    #    matches *.3gp files for which `file` output is a line starting with "ISO Media"
    #    and containing "3GPP".
    #
    #    If there are more than one keys with the same name in a section, the last key will be used.
    #
    #
    # Any new entries you want to add are always welcome if they are useful on more than one
    # system. You can post your modifications as tickets at www.midnight-commander.org.


    ### Changes ###
    #
    # Reorganization: 2012-03-07 Slava Zanko <slavazanko@gmail.com>
    #                 2021-03-28 Andrew Borodin <aborodin@vmail.ru>
    #                 2021-08-24 Tomas Szepe <szepe@pinerecords.com>
    #                 2022-09-11 Andrew Borodin <aborodin@vmail.ru>: port to INI format.

    [mc.ext.ini]
    Version=4.0

    ## do all through xdg-open ##
    [all]
    Regex=\.*
    Open=/run/current-system/sw/bin/xdg-open %f
    View=/run/current-system/sw/bin/xdg-open %f
    Edit=/run/current-system/sw/bin/xdg-open %f

    ######### Default #########

    # Default target for anything not described above
    [Default]
    Open=/run/current-system/sw/bin/xdg-open %f
    View=/run/current-system/sw/bin/xdg-open %f
  '';

in
{
  environment.systemPackages = [
    (pkgs.symlinkJoin {
      name = "mc";
      paths = [
        (pkgs.writeDashBin "mc" ''
          export MC_DATADIR=${
            pkgs.write "mc-ext" {
              "/mc.ext.ini".link = mcExt;
              "/sfs.ini".text = "";
            }
          };
          export TERM=xterm-256color
          exec ${pkgs.mc}/bin/mc -S nicedark "$@"
        '')
        pkgs.mc
      ];
    })
  ];
}
