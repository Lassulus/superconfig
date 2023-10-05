{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    (texLiveAggregationFun { paths = [
      texLive
      texLiveExtra
      texLiveCMSuper
      texLiveModerncv
    ];})
  ];
}
