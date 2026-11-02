#!/usr/bin/env python3
"""Exact editors for .env and the OJS config template, used by scripts/setup-*.sh.

  cfgedit.py env-get FILE KEY
  cfgedit.py env-set FILE KEY            value is read from stdin (keeps secrets off the command line)
  cfgedit.py env-changed OLD NEW         names of keys added / changed / removed (never values)
  cfgedit.py ini-get FILE SECTION KEY
  cfgedit.py ini-set FILE SECTION KEY VALUE   VALUE is written as-is (add quotes yourself)
  cfgedit.py allowed-hosts-add FILE HOST      add HOST to [general] allowed_hosts (JSON list)

Files are rewritten through a temp file + rename, keeping their permissions.
Do NOT use this on bind-mounted files (config.inc.php): use scripts/render-config.sh.
"""
import json
import os
import re
import sys


def read_lines(path):
    with open(path, encoding="utf-8") as f:
        return f.read().split("\n")


def write_lines(path, lines, mode=None):
    mode = mode if mode is not None else (os.stat(path).st_mode & 0o777)
    tmp = path + ".cfgedit.tmp"
    fd = os.open(tmp, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(fd, "w", encoding="utf-8") as f:
        f.write("\n".join(lines))
    os.chmod(tmp, mode)
    os.replace(tmp, path)


def parse_env(path):
    out = {}
    for line in read_lines(path):
        m = re.match(r"^([A-Za-z_][A-Za-z0-9_]*)=(.*)$", line)
        if m:
            v = m.group(2).strip()
            if len(v) >= 2 and v[0] == v[-1] and v[0] in "'\"":
                v = v[1:-1]
            out[m.group(1)] = v
    return out


def env_set(path, key, value):
    if "'" in value or "\n" in value:
        sys.exit(f"unsupported character (quote or newline) in the value for {key}")
    lines = read_lines(path)
    new = f"{key}='{value}'"
    for i, line in enumerate(lines):
        if re.match(rf"^{re.escape(key)}=", line):
            lines[i] = new
            break
    else:
        while lines and lines[-1] == "":
            lines.pop()
        lines += [new, ""]
    write_lines(path, lines, 0o600)


def section_bounds(lines, section):
    start = None
    for i, line in enumerate(lines):
        if line.strip() == f"[{section}]":
            start = i
        elif start is not None and line.startswith("["):
            return start, i
    if start is None:
        sys.exit(f"section [{section}] not found")
    return start, len(lines)


def ini_get(path, section, key):
    lines = read_lines(path)
    s, e = section_bounds(lines, section)
    for line in lines[s + 1:e]:
        m = re.match(rf"^\s*{re.escape(key)}\s*=\s*(.*)$", line)
        if m:
            return m.group(1).strip()
    return None


def ini_set(path, section, key, value):
    lines = read_lines(path)
    s, e = section_bounds(lines, section)
    new = f"{key} = {value}"
    active = re.compile(rf"^\s*{re.escape(key)}\s*=")
    commented = re.compile(rf"^\s*;\s*{re.escape(key)}\s*=")
    for pattern in (active, commented):
        for i in range(s + 1, e):
            if pattern.match(lines[i]):
                lines[i] = new
                write_lines(path, lines)
                return
    # not present at all: insert after the last non-empty line of the section
    j = e
    while j - 1 > s and lines[j - 1].strip() == "":
        j -= 1
    lines.insert(j, new)
    write_lines(path, lines)


def allowed_hosts_add(path, host):
    raw = ini_get(path, "general", "allowed_hosts") or '""'
    inner = raw[1:-1] if len(raw) >= 2 and raw[0] == raw[-1] and raw[0] in "'\"" else raw
    inner = inner.replace('\\"', '"')
    hosts = json.loads(inner) if inner.strip() else []
    if host not in hosts:
        hosts.append(host)
    encoded = json.dumps(hosts, separators=(",", ":")).replace('"', '\\"')
    ini_set(path, "general", "allowed_hosts", f'"{encoded}"')
    print(",".join(hosts))


def main(argv):
    if len(argv) < 2:
        sys.exit(__doc__)
    cmd, args = argv[1], argv[2:]
    if cmd == "env-get":
        print(parse_env(args[0]).get(args[1], ""))
    elif cmd == "env-set":
        env_set(args[0], args[1], sys.stdin.read().rstrip("\n"))
    elif cmd == "env-changed":
        old, new = parse_env(args[0]), parse_env(args[1])
        for k in sorted(set(old) | set(new)):
            if k not in old:
                print(f"{k} (added)")
            elif k not in new:
                print(f"{k} (removed)")
            elif old[k] != new[k]:
                print(f"{k} (changed)")
    elif cmd == "ini-get":
        v = ini_get(args[0], args[1], args[2])
        print("" if v is None else v)
    elif cmd == "ini-set":
        ini_set(args[0], args[1], args[2], args[3])
    elif cmd == "allowed-hosts-add":
        allowed_hosts_add(args[0], args[1])
    else:
        sys.exit(f"unknown command {cmd}\n{__doc__}")


if __name__ == "__main__":
    main(sys.argv)
