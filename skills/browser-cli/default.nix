{
  buildPythonApplication,
  hatchling,
}:

buildPythonApplication {
  pname = "browser-cli";
  version = "0.2.0";
  src = ./.;
  pyproject = true;

  build-system = [ hatchling ];

  dependencies = [ ];

  meta = {
    description = "Control Firefox browser from the command line";
    mainProgram = "browser-cli";
  };
}
