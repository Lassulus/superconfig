{ self, pkgs, ... }:
{
  # herdr: agent multiplexer (https://herdr.dev). Keeps coding-agent terminals
  # running in a background server that survives a dropped ssh session, marks
  # every pane working/blocked/idle and joins saved ssh machines into one
  # window, so a herd of agents across hosts can be driven from one client.
  # Taken from llm-agents (tracks upstream releases; nixpkgs lags).
  environment.systemPackages = [ self.inputs.llm-agents.packages.${pkgs.system}.herdr ];

  # The whip app on massulus (herdr's mobile client) drives the agents over
  # ssh as lass, so it gets in wherever herdr runs.
  users.users.mainUser.openssh.authorizedKeys.keys = [ self.keys.ssh.whip_massulus.public ];
}
