{ config, ... }:

{
  config.services.redis = {
    enable = true;
    bind = "127.0.0.1";
  };
}
