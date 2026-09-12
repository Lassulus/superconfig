{ self, pkgs, ... }:
{
  # herdr: agent multiplexer (https://herdr.dev). Keeps coding-agent terminals
  # running in a background server that survives a dropped ssh session, marks
  # every pane working/blocked/idle and joins saved ssh machines into one
  # window, so a herd of agents across hosts can be driven from one client.
  # Taken from llm-agents (tracks upstream releases; nixpkgs lags).
  environment.systemPackages = [ self.inputs.llm-agents.packages.${pkgs.system}.herdr ];
}
