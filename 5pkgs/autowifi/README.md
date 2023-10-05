Very WIP
Automatically connect to WIFIs.
passwords can be stored in an easy db format

Requirements:
- NetworkManager
- python3

example wifi db:
```
myssid/mywifipassword
myssid2/mywifipassword2
```

will fallback to open wifis if no known wifi is found.
will try to ping the gateway on the wifi after connecting.

Available options:
(all directory options take multiple directories)
* `--scan-hooks, -s` - directories with hooks which are run after the scanning phase
* `--connection-hooks, -c` - directories with hooks which are run after connecting to a wifi
* `--wifi_dirs, -w` - directories with wifi dbs
* `--loglevel, -l` - loglevel to log to STDOUT, takes INFO and DEBUG as arguments
* `--pidfile, -p` - file to write the PID to
* `--no-open` - don't connect to open wifis in the end


## FLOW


