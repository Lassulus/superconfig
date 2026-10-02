{
  libretro,
}:

libretro.dolphin.overrideAttrs (old: {
  patches = (old.patches or [ ]) ++ [
    ./disable-background-shaders.patch
  ];
})
