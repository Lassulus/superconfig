{ lib, ... }:
{
  flake.retiolum = import ./. { inherit lib; };
}
