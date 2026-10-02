{ pkgs, ... }:
{
  services.printing = {
    enable = true;
    browsing = true;
    browsedConf = ''
      BrowseDNSSDSubTypes _cups,_print
      BrowseLocalProtocols all
      BrowseRemoteProtocols all
      CreateIPPPrinterQueues All

      BrowseProtocols all
    '';
  };
  systemd.services.cups.serviceConfig.ExecStartPost = pkgs.writers.writeDash "init-gg23" ''
    lpadmin -x gg23 || :
    lpadmin -i ${./gg23.ppd} -p gg23 -E -v ipp://10.42.0.4
  '';
}
