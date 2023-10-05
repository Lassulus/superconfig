import argparse
import json
import logging
import os
import re
import signal
import socket
import struct
import subprocess
import time
import urllib.request

logger = logging.getLogger()
got_signal = False


def signal_handler(_, __):
    global got_signal
    got_signal = True


def get_default_gateway() -> str:
    """Read the default gateway directly from /proc."""
    with open("/proc/net/route") as route_file:
        for line in route_file:
            fields = line.strip().split()
            if fields[1] != '00000000' or not int(fields[3], 16) & 2:
                continue

            return socket.inet_ntoa(struct.pack("<L", int(fields[2], 16)))


def connect(ssid, psk=None):
    subprocess.run(
        ["nmcli", "connection", "delete", "autowifi"],
        stdout=subprocess.PIPE,
    )
    logging.info('connecting to %s', ssid)
    if psk is None:
        subprocess.run(
            [
                "nmcli",
                "device",
                "wifi",
                "connect",
                ssid,
                "name",
                "autowifi",
            ],
            stdout=subprocess.PIPE,
        )
    else:
        subprocess.run(
            [
                "nmcli",
                "device",
                "wifi",
                "connect",
                ssid,
                "name",
                "autowifi",
                "password",
                psk,
            ],
            stdout=subprocess.PIPE,
        )
    time.sleep(5)


def scan():
    logging.debug('scanning wifis')
    wifis_raw = subprocess.check_output([
        "nmcli",
        "-e", "no",
        "-f", "ssid,signal,security,rsn-flags,bssid",
        "-t",
        "device", "wifi", "list",
        "--rescan", "auto",
    ])
    wifis_list = wifis_raw.split(b'\n')
    logging.debug('scanning wifis finished')
    wifis = []
    for line in wifis_list:
        logging.debug(line)
        ls = re.split(rb'(?<!\\):', line)
        if len(ls) == 10:
            wifis.append({
                "ssid": ls[0],
                "signal": int(ls[1]),
                "crypto": ls[2],
                "flags": ls[3],
                "bssid": b':'.join(ls[4:]),
            })
    return wifis


def get_known_wifis(wifi_dirs):
    wifis_lines = []
    for wdir in wifi_dirs:
        for wfile in os.listdir(wdir):
            with open(os.path.join(wdir, wfile)) as f:
                wifis_lines += f.read().splitlines()
    wifis = []
    for line in wifis_lines:
        ls = line.split('/')
        wifis.append({"ssid": ls[0].encode(), "psk": ls[1].encode()})
    return wifis


def check_network():
    logging.debug('checking network')

    gateway = get_default_gateway()
    if gateway:
        response = subprocess.run(
            [
                'ping',
                '-q',
                '-c',
                '1',
                gateway,
            ],
            stdout=subprocess.PIPE,
        )
        if response.returncode == 0:
            logging.debug('host %s is up', gateway)
            return True
        else:
            logging.debug('host %s is down', gateway)
            return False
    else:
        logging.debug('no gateway')
        return False


def check_internet():
    logging.debug('checking internet')

    try:
        beacon = urllib.request.urlopen('http://krebsco.de/secret')
    except Exception as e:  # noqa
        logging.debug(e)
        logging.info('no internet exc')
        return False
    if beacon.read() == b'1337\n':
        return True
    logging.info('no internet oh')
    return False


def is_wifi_open(wifi):
    if wifi['crypto'] == b'':
        return True
    else:
        return False


def is_wifi_seen(wifi, seen_wifis):
    for seen_wifi in seen_wifis:
        if seen_wifi["ssid"] == wifi["ssid"]:
            return True
    return False


def run_hooks(dirs, wifi):
    outputs = {}
    for directory in dirs:
        for hfile in os.listdir(directory):
            try:
                hook_output = subprocess.check_output([
                    str(os.path.join(directory, hfile)),
                    json.dumps(wifi)
                ])
                outputs[hfile] = hook_output
            except OSError as e:
                logging.debug(e)
                logging.info('running plugin: {} failed'.format(hfile))
    return outputs


def stay_connected_loop(allowed_fails=5):
    fails = 0
    if check_network():
        while True:
            global got_signal
            if got_signal:
                logging.info('got disconnect signal')
                got_signal = False
                break
            else:
                if check_network():
                    time.sleep(10)
                else:
                    fails += 1
                    if fails > allowed_fails:
                        logging.debug('network gone, giving up')
                        break
                    else:
                        logging.debug('hmm, missed ping, will try again shortly')
                        time.sleep(3)


def main():
    parser = argparse.ArgumentParser()

    parser.add_argument(
        '-x', '--scan-hooks',
        dest='scan_hooks',
        nargs='*',
        help='directories with scan hooks (executed after scan)',
        default=['/etc/autowifi/scan_hooks'],
    )

    parser.add_argument(
        '-c', '--connection-hooks',
        dest='connect_hooks',
        nargs='*',
        help='directories with connection hooks (executed after connection)',
        default=['/etc/autowifi/connect_hooks'],
    )

    parser.add_argument(
        '-w', '--wifi_dirs',
        dest='wifi_dirs',
        nargs='*',
        help='directories with wifi configs',
        default=['/etc/autowifi/wifis'],
    )

    parser.add_argument(
        '-l', '--loglevel',
        dest='loglevel',
        help='loglevel to use',
        default=logging.INFO,
    )

    parser.add_argument(
        '-p', '--pidfile',
        dest='pidfile',
        help='file to write the pid to',
        default=None,
    )

    parser.add_argument(
        '--no-open',
        dest='no_open_networks',
        help='dont connect to open networks',
        default=False,
        action='store_true',
    )

    args = parser.parse_args()

    wifi_dirs = args.wifi_dirs
    logger.setLevel(args.loglevel)

    signal.signal(signal.SIGUSR1, signal_handler)

    if args.pidfile:
        with open(args.pidfile, 'w+') as f:
            f.write(str(os.getpid()))

    while True:
        time.sleep(1)
        stay_connected_loop()
        wifis = scan()
        known_wifis = get_known_wifis(wifi_dirs)
        known_seen_wifis = [
            wifi for wifi in known_wifis if is_wifi_seen(wifi, wifis)
        ]
        for wifi in known_seen_wifis:
            connect(wifi['ssid'], wifi['psk'])
            if check_network():
                logging.debug('connected to secure wifi, going into busy loop')
                break
        if check_network():
            continue
        logging.debug('no known secure wifi, connecting to open ones')
        if not args.no_open_networks:
            logging.debug('connecting to open wifis')
            open_wifis = filter(is_wifi_open, wifis)
            for wifi in open_wifis:
                connect(wifi['ssid'])
                if check_network():
                    run_hooks(args.connect_hooks, wifi)
                    break


if __name__ == '__main__':
    main()
