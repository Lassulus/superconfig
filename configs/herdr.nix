{ self, pkgs, ... }:
{
  # herdr: agent multiplexer (https://herdr.dev). Keeps coding-agent terminals
  # running in a background server that survives a dropped ssh session, marks
  # every pane working/blocked/idle and joins saved ssh machines into one
  # window, so a herd of agents across hosts can be driven from one client.
  # Taken from llm-agents (tracks upstream releases; nixpkgs lags).
  environment.systemPackages = [ self.inputs.llm-agents.packages.${pkgs.system}.herdr ];

  # Multi-machine: `herdr machine add <host>.r --label <host>` on the client
  # host saves an ssh profile in ~/.local/state/herdr/client/endpoints.json and
  # starts the remote server. No bootstrap download is needed because
  # systemPackages puts herdr in the non-interactive ssh PATH
  # (/run/current-system/sw/bin), and every machine here shares the llm-agents
  # pin, so client and server versions match as long as they are deployed
  # together. A machine lagging behind shows "Attention" until it is updated.

  # The whip app on massulus (herdr's mobile client) drives the agents over
  # ssh as lass, so it gets in wherever herdr runs.
  users.users.mainUser.openssh.authorizedKeys.keys = [ self.keys.ssh.whip_massulus.public ];
}
