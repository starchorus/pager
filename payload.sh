#!/bin/sh
#
# Title:        Starchorus (passive)
# Description:  STRICTLY PASSIVE Wi-Fi landscape visualiser. Starts the passive collector
#               (recon.db read / monitor-mode RX only -- never transmits) and serves the
#               visualisation on a high local port of the management address. Contains NO active/offensive feature.
# Author:       Starchorus
# Version:      0.2.5
# Category:     reconnaissance
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Drop this whole folder at /root/loot/starchorus on the device (starchorus-collect.sh, starchorus.html
# as index.html, and this payload.sh). Run it from the Payloads UI or by hand. Stop with
# `./payload.sh stop`.  Everything here is receive-only.
# The page server is given $STARCHORUS_DIR/www, a directory of its own that holds two symbolic links and nothing else
# (index.html and starchorus.json, both pointing one level up), never the whole of STARCHORUS_DIR: the settings, pid files,
# logs and the like stay out of reach of a browser. When www is not ours, no page server starts. A server of an earlier build
# (given the whole directory) is still found and stopped.

STARCHORUS_DIR=${STARCHORUS_DIR:-/root/loot/starchorus}      # persistent eMMC (== /mmc/root/loot/starchorus)
STARCHORUS_PORT=${STARCHORUS_PORT:-8199}                # NOT 1471 (mgmt UI) and NOT 80
# The page server listens on one address: auto (default) = the IPv4 address of br-lan (USB-C and management Wi-Fi), else
# 172.16.52.1 when an interface has it, else 127.0.0.1 (with a note); an explicit IPv4 address; or all = 0.0.0.0, every
# interface -- the page and starchorus.json (every captured MAC and SSID) then reach every network the device is on.
STARCHORUS_BIND=${STARCHORUS_BIND:-auto}
export STARCHORUS_OUTDIR="$STARCHORUS_DIR"
export STARCHORUS_INTERVAL="${STARCHORUS_INTERVAL:-5}"

cd "$STARCHORUS_DIR" 2>/dev/null || { echo "no $STARCHORUS_DIR" >&2; exit 1; }

# The collector and the page server run at the lowest CPU priority (nice 19; the collector's sqlite3 and awk children inherit
# it): on the single core the AP service must always win. Without `nice` they start as before.
NICE=""; command -v nice >/dev/null 2>&1 && NICE="nice -n 19"

# ipv4 TEXT -> 0 iff TEXT is a dotted-quad IPv4 address (four parts 0-255, no leading zero)
ipv4() {
    printf '%s\n' "$1" | awk -F. 'NR == 1 && NF == 4 { for (i = 1; i <= 4; i++) if ($i !~ /^(0|[1-9][0-9]?[0-9]?)$/ || $i + 0 > 255) exit 1; ok = 1 }
        END { exit !(ok && NR == 1) }'
}

# bind_addr -> the address the page server listens on, per STARCHORUS_BIND. auto reads `ip -4 -o addr` (read-only). An
# invalid value is treated as auto (with a note); every interface (0.0.0.0) only ever comes from `all`.
bind_addr() {
    case $STARCHORUS_BIND in
        all)  echo 0.0.0.0; return 0 ;;
        auto) ;;
        *)    if [ "$STARCHORUS_BIND" != 0.0.0.0 ] && ipv4 "$STARCHORUS_BIND"; then printf '%s\n' "$STARCHORUS_BIND"; return 0; fi
              echo "STARCHORUS_BIND=$STARCHORUS_BIND ignored (auto, all or an IPv4 address); using auto" >&2 ;;
    esac
    ips=$(ip -4 -o addr 2>/dev/null)
    a=$(printf '%s\n' "$ips" | awk '$2 == "br-lan" || $2 ~ /^br-lan@/ { for (i = 3; i < NF; i++) if ($i == "inet") { a = $(i + 1); sub(/\/.*/, "", a); print a; exit } }')
    if [ "$a" != 0.0.0.0 ] && ipv4 "$a"; then printf '%s\n' "$a"; return 0; fi
    if printf '%s\n' "$ips" | awk '{ for (i = 3; i < NF; i++) if ($i == "inet" && index($(i + 1), "172.16.52.1/") == 1) f = 1 } END { exit !f }'; then
        echo 172.16.52.1; return 0
    fi
    echo "no br-lan address: the page listens on 127.0.0.1 only (set STARCHORUS_BIND to an address, or to all)" >&2
    echo 127.0.0.1
}

# web_prepare -> 0 iff $STARCHORUS_DIR/www is a plain directory of ours (not a symbolic link) that holds nothing but two
# symbolic links, index.html -> ../index.html and starchorus.json -> ../starchorus.json, made here when they are missing.
# Returns 1 with one note on stderr when www is a symbolic link, is not a directory, holds any other entry (a file, a dot
# file, a directory), holds index.html or starchorus.json as anything but a link (or as a link to a directory), or when
# mkdir or ln fail. Nothing is written but below $STARCHORUS_DIR/www.
web_prepare() {
    wd=$STARCHORUS_DIR/www
    wok=1
    if [ -L "$wd" ] || { [ -e "$wd" ] && [ ! -d "$wd" ]; }; then wok=0
    elif mkdir -p "$wd" 2>/dev/null; then
        for we in "$wd"/* "$wd"/.[!.]* "$wd"/..?*; do
            [ -e "$we" ] || [ -L "$we" ] || continue
            case ${we##*/} in
                index.html|starchorus.json) { [ -L "$we" ] && [ ! -d "$we" ]; } || wok=0 ;;
                *) wok=0 ;;
            esac
        done
        if [ "$wok" = 1 ]; then
            ln -sf ../index.html "$wd/index.html" 2>/dev/null && ln -sf ../starchorus.json "$wd/starchorus.json" 2>/dev/null || wok=0
        fi
    else wok=0
    fi
    [ "$wok" = 1 ] && return 0
    echo "Starchorus: note: $wd is not a plain directory of ours that holds the two links alone (or the links cannot be made); no page server" >&2
    return 1
}

# ---- pick a static file server (passive; serves index.html + starchorus.json) -----------------
# Every server is started in the FOREGROUND mode of its program and backgrounded here, so $! is the server itself and
# httpd.pid holds exactly our own server's pid (busybox httpd daemonises unless it gets -f: the call would return at once,
# $! would be empty or the collector started just before, and `stop` would kill the wrong process or none).
# Each listens on ADDR (bind_addr) only: uhttpd and busybox httpd take -p ADDR:PORT, python3 --bind ADDR. NICE (above) goes
# in front; nice execs the server, so $! still is the server.
serve() {
    srv=
    web_prepare || return 1
    # shellcheck disable=SC2086   # NICE is "nice -n 19" or empty: split on purpose
    if command -v uhttpd >/dev/null 2>&1; then
        $NICE uhttpd -f -p "$ADDR:$STARCHORUS_PORT" -h "$STARCHORUS_DIR/www" & srv=$!
    elif busybox --list 2>/dev/null | grep -qx httpd; then
        $NICE busybox httpd -f -h "$STARCHORUS_DIR/www" -p "$ADDR:$STARCHORUS_PORT" & srv=$!
    elif command -v python3 >/dev/null 2>&1; then
        $NICE python3 -m http.server "$STARCHORUS_PORT" --bind "$ADDR" --directory "$STARCHORUS_DIR/www" >/dev/null 2>&1 & srv=$!
    else
        echo "no static file server (install: opkg install -d mmc uhttpd  or  python3-light)" >&2
        return 1
    fi
    sleep 1   # a server that cannot bind the port exits at once: no pid file for a process that is gone
    if kill -0 "$srv" 2>/dev/null; then echo "$srv" > "$STARCHORUS_DIR/httpd.pid" 2>/dev/null
    else echo "static file server did not start ($ADDR:$STARCHORUS_PORT busy or not configured?)" >&2; return 1; fi
}

# our_servers -> the pids of OUR page servers in BusyBox `ps w`: an httpd/uhttpd with -p [ADDR:]PORT, or a python
# http.server PORT, AND our directory (-h DIR or --directory DIR, DIR being $STARCHORUS_DIR/www or, for a server of an earlier
# build, $STARCHORUS_DIR) as a word pair of its own. The port is matched only as the listening argument, never anywhere on
# the line, and our directory is required, so the device's own uhttpd (:80, :1471, -h /www) never matches.
our_servers() {
    case $STARCHORUS_PORT in ''|*[!0-9]*) return 0 ;; esac   # the port goes into a pattern: digits only
    # shellcheck disable=SC2009  # busybox-safe; pgrep/pkill -f unavailable/unreliable here
    ps w 2>/dev/null | awk -v d="$STARCHORUS_DIR" -v w="$STARCHORUS_DIR/www" -v port="$STARCHORUS_PORT" '
        !/httpd|http\.server/ || /awk/ { next }
        {
            lp = 0; dir = 0
            for (i = 2; i <= NF; i++) {
                if (($i == "-h" || $i == "--directory") && ($(i + 1) == d || $(i + 1) == w)) dir = 1
                if ($i ~ ("^([0-9.]*:)?" port "$") && ($(i - 1) == "-p" || $(i - 1) ~ /http\.server$/)) lp = 1
            }
            if (lp && dir) print $1
        }'
}

# own_server PID -> 0 iff PID still runs one of the servers serve() starts, for this dir and port
own_server() {
    case "$1" in ''|*[!0-9]*) return 1 ;; esac
    for o in $(our_servers); do [ "$o" = "$1" ] && return 0; done
    return 1
}

case "$1" in
    stop)
        ./starchorus-collect.sh --stop
        sp=$(sed -n 1p "$STARCHORUS_DIR/httpd.pid" 2>/dev/null)
        own_server "$sp" && kill "$sp" 2>/dev/null
        rm -f "$STARCHORUS_DIR/httpd.pid"
        # Stop our servers by their command line (our_servers: this directory, this port, any address).
        for p in $(our_servers); do kill "$p" 2>/dev/null; done
        echo "starchorus stopped" >&2
        ;;
    *)
        # start the passive collector loop in the background, then serve the page
        # shellcheck disable=SC2086   # NICE is "nice -n 19" or empty: split on purpose
        $NICE ./starchorus-collect.sh >/dev/null 2>"$STARCHORUS_DIR/collect.log" &
        ADDR=$(bind_addr)
        serve
        if [ "$ADDR" = 0.0.0.0 ]; then url="http://<device-ip>:$STARCHORUS_PORT/  (all interfaces)"; else url="http://$ADDR:$STARCHORUS_PORT/"; fi
        echo "Starchorus (passive) on $url  (collector -> $STARCHORUS_DIR/starchorus.json)" >&2
        ;;
esac
