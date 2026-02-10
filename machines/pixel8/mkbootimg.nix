{
  lib,
  stdenvNoCC,
  fetchgit,
  python3,
}:

stdenvNoCC.mkDerivation {
  pname = "mkbootimg";
  version = "2025-02-10";

  src = fetchgit {
    url = "https://android.googlesource.com/platform/system/tools/mkbootimg";
    rev = "d2bb0af5ba6d3198a3e99529c97eda1be0b5a093";
    hash = "sha256-z7KklKf0dTyt7ZoUiZrMYRzU3h+WuLnc355LRtFMs2s=";
  };

  nativeBuildInputs = [ python3 ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin $out/lib/mkbootimg

    # Copy Python scripts and modules
    cp mkbootimg.py unpack_bootimg.py repack_bootimg.py $out/lib/mkbootimg/
    cp -r gki $out/lib/mkbootimg/

    # Create wrapper scripts with PYTHONPATH set
    cat > $out/bin/mkbootimg << EOF
    #!/bin/sh
    export PYTHONPATH="$out/lib/mkbootimg:\$PYTHONPATH"
    exec ${python3}/bin/python3 $out/lib/mkbootimg/mkbootimg.py "\$@"
    EOF
    chmod +x $out/bin/mkbootimg

    cat > $out/bin/unpack_bootimg << EOF
    #!/bin/sh
    export PYTHONPATH="$out/lib/mkbootimg:\$PYTHONPATH"
    exec ${python3}/bin/python3 $out/lib/mkbootimg/unpack_bootimg.py "\$@"
    EOF
    chmod +x $out/bin/unpack_bootimg

    cat > $out/bin/repack_bootimg << EOF
    #!/bin/sh
    export PYTHONPATH="$out/lib/mkbootimg:\$PYTHONPATH"
    exec ${python3}/bin/python3 $out/lib/mkbootimg/repack_bootimg.py "\$@"
    EOF
    chmod +x $out/bin/repack_bootimg

    runHook postInstall
  '';

  meta = with lib; {
    description = "Android boot image creation tool from AOSP";
    homepage = "https://android.googlesource.com/platform/system/tools/mkbootimg";
    license = licenses.asl20;
    platforms = platforms.all;
  };
}
