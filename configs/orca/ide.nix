# Orca desktop app (https://onorca.dev); for the headless runtime see
# ./server.nix. Orca shells out to these tools for the logged-in user.
{
  self,
  pkgs,
  ...
}:
{
  environment.systemPackages = [
    self.packages.${pkgs.system}.orca
    # GitHub issues/PRs in the work item lists.
    pkgs.gh
  ];
}
