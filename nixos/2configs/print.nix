{ pkgs, ... }:
{
  services.printing = {
    enable = true;
    drivers = [
      pkgs.foomatic-filters
      pkgs.gutenprint
    ];
    browsing = true;
    browsedConf = ''
      BrowseDNSSDSubTypes _cups,_print
      BrowseLocalProtocols all
      BrowseRemoteProtocols all
      CreateIPPPrinterQueues All

      BrowseProtocols all
    '';
  };
}
