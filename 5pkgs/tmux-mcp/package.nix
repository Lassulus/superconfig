{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
  tmux,
  nodejs,
}:

buildNpmPackage rec {
  pname = "tmux-mcp";
  version = "0.1.0";

  src = fetchFromGitHub {
    owner = "nickgnd";
    repo = "tmux-mcp";
    rev = "96db73220b449487e2be4427d1e86b8ccefc29ef";
    hash = "sha256-lMgRXfzPclPqFO85zi7jvAe/aX1HL2LNk0cf3CkY7tM=";
  };

  npmDepsHash = "sha256-D/kOVT7BmJJ/g5h9b0LZp5VFnRGtw7qmyIv4Pea+yXE=";

  buildInputs = [
    tmux
    nodejs
  ];

  meta = with lib; {
    description = "MCP server for tmux integration with Claude";
    homepage = "https://github.com/nickgnd/tmux-mcp";
    license = licenses.mit;
    maintainers = [ ];
    platforms = platforms.all;
  };
}
