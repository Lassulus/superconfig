{
  lib,
  fetchPypi,
  python313Packages,
}:
let
  py = python313Packages;

  # omnigent-client declares `omnigent` as a dependency, and omnigent declares
  # omnigent-client: the two are released in lockstep from the same repo. Break
  # the cycle by dropping the back-reference here; the final application below
  # provides `omnigent` itself.
  omnigent-client = py.buildPythonPackage rec {
    pname = "omnigent_client";
    version = "0.9.0";
    format = "wheel";

    src = fetchPypi {
      inherit pname version format;
      dist = "py3";
      python = "py3";
      hash = "sha256-NUF16ZzZkVzohOKznfAPVTT1LI09dXP6gZxlWZzmyrM=";
    };

    pythonRemoveDeps = [ "omnigent" ];

    dependencies = [
      py.httpx
      py.pydantic
    ];

    # No pythonImportsCheck: every module imports `omnigent`, which only exists
    # in the application closure below.
    doCheck = false;

    meta = {
      description = "Python client library for the Omnigent server API";
      homepage = "https://omnigent.ai";
      license = lib.licenses.asl20;
    };
  };

  omnigent-ui-sdk = py.buildPythonPackage rec {
    pname = "omnigent_ui_sdk";
    version = "0.9.0";
    format = "wheel";

    src = fetchPypi {
      inherit pname version format;
      dist = "py3";
      python = "py3";
      hash = "sha256-xr5rtx2Ac/q8GShkeQudzbKDoLGe5d+Jp7XCiXzU7lQ=";
    };

    dependencies = [
      omnigent-client
      py.prompt-toolkit
      py.pyyaml
      py.rich
    ];

    doCheck = false;

    meta = {
      description = "Terminal UI SDK for Omnigent";
      homepage = "https://omnigent.ai";
      license = lib.licenses.asl20;
    };
  };
in
py.buildPythonApplication rec {
  pname = "omnigent";
  version = "0.9.0";
  format = "wheel";

  # The published wheel ships the prebuilt web SPA under
  # omnigent/server/static/web-ui; the sdist does not.
  src = fetchPypi {
    inherit pname version format;
    dist = "py3";
    python = "py3";
    hash = "sha256-deNx9SHyaf1ZNkq5+88c1fUieFZastIo8N27Ixy0F1Q=";
  };

  # Upper bounds that nixpkgs has already moved past. All of these are
  # conservative caps in omnigent's pyproject, not known incompatibilities.
  pythonRelaxDeps = [
    "argon2-cffi" # nixpkgs 25.1.0 vs <24
    "cachetools" # nixpkgs 7.1.4 vs <7
    "packaging" # nixpkgs 26.2 vs <26
    "protobuf" # nixpkgs 7.35.1 vs <7
    "rich" # nixpkgs 15.0.0 vs <15
    "websockets" # nixpkgs 16.1 vs <15
  ];

  dependencies = [
    omnigent-client
    omnigent-ui-sdk
  ]
  ++ (with py; [
    alembic
    anyio
    argon2-cffi
    cachetools
    cel-python
    certifi
    claude-agent-sdk
    click
    fastapi
    ftfy
    httpx
    json5
    keyring
    mcp
    openai
    openai-agents
    opentelemetry-exporter-otlp-proto-grpc
    opentelemetry-exporter-otlp-proto-http
    opentelemetry-instrumentation-fastapi
    opentelemetry-instrumentation-httpx
    opentelemetry-instrumentation-sqlalchemy
    packaging
    pexpect
    prompt-toolkit
    protobuf
    psutil
    pydantic
    pyjwt
    pyte
    python-dateutil
    pyyaml
    rich
    sqlalchemy
    starlette
    tiktoken
    tomlkit
    uvicorn
    websockets
    zstandard
  ])
  ++ py.pyjwt.optional-dependencies.crypto
  ++ py.uvicorn.optional-dependencies.standard;

  pythonImportsCheck = [
    "omnigent"
    "omnigent_client"
    "omnigent_ui_sdk"
  ];

  meta = {
    description = "Open-source meta-harness giving a common orchestration layer over AI coding agents";
    homepage = "https://omnigent.ai";
    license = lib.licenses.asl20;
    mainProgram = "omnigent";
    platforms = lib.platforms.unix;
  };
}
