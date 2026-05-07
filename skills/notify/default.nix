{ stdenv, ... }:

stdenv.mkDerivation {
  pname = "notify-skill";
  version = "0.1.0";
  src = ./.;

  installPhase = ''
    mkdir -p $out/share/notify
    cp SKILL.md $out/share/notify/SKILL.md
  '';

  meta = {
    description = "Get the user's attention via TTS and desktop notification";
  };
}
