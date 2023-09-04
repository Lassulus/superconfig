{ config, pkgs, ... }:

let
  mcExt = pkgs.writeText "mc.ext" ''
    # gitfs changeset
    regex/^\[git\]
      Open=%cd %p/changesetfs://
      View=%cd %p/patchsetfs://

    ### Archives ###

    # .tgz, .tpz, .tar.gz, .tar.z, .tar.Z, .ipk, .gem
    regex/\.t([gp]?z|ar\.g?[zZ])$|\.ipk$|\.gem$
      Open=%cd %p/utar://

    shell/.tar.bz
      # Open=%cd %p/utar://

    regex/\.t(ar\.bz2|bz2?|b2)$
      Open=%cd %p/utar://

    # .tar.lzma, .tlz
    regex/\.t(ar\.lzma|lz)$
      Open=%cd %p/utar://

    # .tar.xz, .txz
    regex/\.t(ar\.xz|xz)$
      Open=%cd %p/utar://

    # .tar.F - used in QNX
    shell/.tar.F
      # Open=%cd %p/utar://

    # .qpr/.qpk - QNX Neutrino package installer files
    regex/\.qp[rk]$
      Open=%cd %p/utar://

    # tar
    shell/i/.tar
      Open=%cd %p/utar://

    # lha
    type/^LHa\ .*archive
      Open=%cd %p/ulha://

    # arj
    regex/i/\.a(rj|[0-9][0-9])$
      Open=%cd %p/uarj://

    # cab
    shell/i/.cab
      Open=%cd %p/ucab://

    # ha
    shell/i/.ha
      Open=%cd %p/uha://

    # rar
    regex/i/\.r(ar|[0-9][0-9])$
      Open=%cd %p/urar://

    # ALZip
    shell/i/.alz
      Open=%cd %p/ualz://

    # cpio
    shell/.cpio.Z
      Open=%cd %p/ucpio://

    shell/.cpio.xz
      Open=%cd %p/ucpio://

    shell/.cpio.gz
      Open=%cd %p/ucpio://

    shell/i/.cpio
      Open=%cd %p/ucpio://

    # 7zip archives (they are not man pages)
    shell/i/.7z
      Open=%cd %p/u7z://

    # patch
    regex/\.(diff|patch)(\.bz2)$
      Open=%cd %p/patchfs://

    regex/\.(diff|patch)(\.(gz|Z))$
      Open=%cd %p/patchfs://

    # ls-lR
    regex/(^|\.)ls-?lR(\.gz|Z|bz2)$
      Open=%cd %p/lslR://

    # trpm
    shell/.trpm
      Open=%cd %p/trpm://

    # RPM packages (SuSE uses *.spm for source packages)
    regex/\.(src\.rpm|spm)$
      Open=%cd %p/rpm://

    shell/.rpm
      Open=%cd %p/rpm://

    # deb
    regex/\.u?deb$
      Open=%cd %p/deb://

    # dpkg
    shell/.debd
      Open=%cd %p/debd://

    # apt
    shell/.deba
      Open=%cd %p/deba://

    # ISO9660
    shell/i/.iso
      Open=%cd %p/iso9660://


    regex/\.(diff|patch)$
      Open=%cd %p/patchfs://

    # ar library
    regex/\.s?a$
      Open=%cd %p/uar://

    # gplib
    shell/i/.lib
      Open=%cd %p/ulib://


    # Mailboxes
    type/^ASCII\ mail\ text
      Open=%cd %p/mailfs://


    ### Sources ###

    # C/C++
    regex/i/\.(c|cc|cpp)$
      Include=editor

    # C/C++ header
    regex/i/\.(h|hh|hpp)$
      Include=editor

    # Fortran
    shell/i/.f
      Include=editor

    # Assembler
    regex/i/\.(s|asm)$
      Include=editor

    include/editor
      Open=%var{EDITOR:vim} %f

    ### Images ###

    shell/i/.gif
      Include=image

    regex/i/\.jpe?g$
      Include=image

    shell/i/.bmp
      Include=image

    shell/i/.png
      Include=image

    shell/i/.jng
      Include=image

    shell/i/.mng
      Include=image

    shell/i/.tiff
      Include=image

    shell/.ico
      Include=image

    include/image
      Open=sxiv %f
      View=sxiv %f

    ### Sound files ###

    regex/i/\.(wav|snd|voc|au|smp|aiff|snd|m4a|ape|aac|wv)$
      Include=audio

    regex/i/\.(mod|s3m|xm|it|mtm|669|stm|ult|far)$
      Include=audio

    shell/i/.waw22
      Include=audio

    shell/i/.mp3
      Include=audio

    regex/i/\.og[gax]$
      Include=audio

    regex/i/\.(spx|flac)$
      Include=audio

    regex/i/\.(midi?|rmid?)$
      Include=audio

    shell/i/.wma
      Include=audio

    include/audio
      Open=mpv %f
      View=mpv %f

    ### Video ###

    shell/i/.avi
      Include=video

    regex/i/\.as[fx]$
      Include=video

    shell/i/.divx
      Include=video

    shell/i/.rmvb
      Include=video

    shell/i/.mkv
      Include=video

    regex/i/\.(mov|qt)$
      Include=video

    regex/i/\.(mp4|m4v|mpe?g)$
      Include=video

    # MPEG-2 TS container + H.264 codec
    shell/i/.mts
      Include=video

    shell/i/.ts
      Include=video

    shell/i/.vob
      Include=video

    shell/i/.wmv
      Include=video

    regex/i/\.fl[icv]$
      Include=video

    shell/i/.ogv
      Include=video

    # WebM
    shell/i/.webm
        Include=video

    type/WebM
        Include=video

    include/video
      Open=mpv %f
      View=mpv %f


    ### Documents ###

    # PDF
    shell/i/.pdf
      Open=zathura %f
      View=zathura %f

    ### Miscellaneous ###

    # Makefile
    regex/[Mm]akefile$
      Open=make -f %f %{Enter parameters}


    ### Plain compressed files ###

    # ace
    shell/i/.ace
      Open=%cd %p/uace://
      Extract=unace x %f

    # arc
    shell/i/.arc
      Open=%cd %p/uarc://
      Extract=arc x %f '*'
      Extract (with flags)=I=%{Enter any Arc flags:}; if test -n "$I"; then arc x $I %f; fi

    # zip
    shell/i/.zip
      Open=%cd %p/uzip://

    # zip
    type/i/^zip\ archive
      Open=%cd %p/uzip://

    # jar(zip)
    type/i/^Java\ Jar\ file\ data\ \(zip\)
      Open=%cd %p/uzip://

    # zoo
    shell/i/.zoo
      Open=%cd %p/uzoo://

    ### Default ###

    # Default target for anything not described above
    default/*
      Open=vim %f
      View=vim %f

  '';

in {
  environment.systemPackages = [
    (pkgs.symlinkJoin {
      name = "mc";
      paths = [
        (pkgs.writeDashBin "mc" ''
          export MC_DATADIR=${pkgs.write "mc-ext" {
              "/mc.ext.ini".link = mcExt;
              "/sfs.ini".text = "";
          }};
          export TERM=xterm-256color
          exec ${pkgs.mc}/bin/mc -S yadt256 "$@"
        '')
        pkgs.mc
      ];
    })
  ];
}

