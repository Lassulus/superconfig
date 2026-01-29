{
  yt-dlp,
  fetchFromGitHub,
}:

yt-dlp.overrideAttrs (_old: {
  pname = "yt-dlp-master";
  version = "unstable-2026-01-29";

  src = fetchFromGitHub {
    owner = "yt-dlp";
    repo = "yt-dlp";
    rev = "309b03f2ad09fcfcf4ce81e757f8d3796bb56add";
    hash = "sha256-Lg/b3LWMeKwiU14GiH+oH2H/e9ysUgICOEzGLqyFFMU=";
  };

  # Remove patches that don't apply to master
  patches = [ ];

  # Reset postPatch since nixpkgs patches don't apply
  postPatch = ''
    sed -i 's/^__version__ = .*/__version__ = "2026.01.29"/' yt_dlp/version.py || true
  '';
})
