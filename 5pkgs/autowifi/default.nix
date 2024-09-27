{ pkgs }: pkgs.writers.writePython3Bin "autowifi" { flakeIgnore = [ "E501" ]; } ./autowifi.py
