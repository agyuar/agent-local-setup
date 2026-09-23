#!/usr/bin/env python3
"""Muestreo de CPU% + RAM por grupo de procesos durante un benchmark.
Uso: python3 measure_footprint.py --groups 'DB:postgres: 18/main|postgresql/18;RT:dockerd|containerd' --out x.csv --dur 64
Los grupos van separados por ';', nombre:regex.
"""
import argparse, csv, re, time, os

HZ = os.sysconf('SC_CLK_TCK')
PAGE = 4096
SKIP_SUBSTR = ('measure_footprint', '/bin/bash', '/usr/bin/bash', 'nohup')

def parse_groups(spec):
    out = []
    for part in spec.split(';'):
        name, rgx = part.split(':', 1)
        out.append((name, re.compile(rgx)))
    return out

def snapshot(rgx):
    res = {}
    for pid in os.listdir('/proc'):
        if not pid.isdigit():
            continue
        try:
            with open(f'/proc/{pid}/cmdline', 'rb') as f:
                raw = f.read()
            cmd = raw.replace(b'\0', b' ').decode('utf-8', 'replace').strip()
        except (FileNotFoundError, PermissionError):
            continue
        if not cmd or any(s in cmd for s in SKIP_SUBSTR):
            continue
        if not rgx.search(cmd):
            continue
        try:
            st = open(f'/proc/{pid}/stat').read()
            rest = st.split(') ', 1)[1].split()
            jiffies = int(rest[11]) + int(rest[12])
        except (FileNotFoundError, PermissionError, IndexError, ValueError):
            continue
        try:
            rss = int(open(f'/proc/{pid}/statm').read().split()[1]) * PAGE
        except (FileNotFoundError, PermissionError, ValueError):
            rss = 0
        res[int(pid)] = (jiffies, rss)
    return res

def sysinfo():
    avail_kb = 0
    with open('/proc/meminfo') as f:
        for line in f:
            if line.startswith('MemAvailable:'):
                avail_kb = int(line.split()[1])
    load1 = float(open('/proc/loadavg').read().split()[0])
    return avail_kb * 1024, load1

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--groups', required=True)
    ap.add_argument('--out', required=True)
    ap.add_argument('--dur', type=int, default=64)
    ap.add_argument('--step', type=float, default=2.0)
    a = ap.parse_args()

    groups = parse_groups(a.groups)
    prev = {name: snapshot(rx) for name, rx in groups}
    prev_t = time.monotonic()
    t_start = prev_t
    t_end = t_start + a.dur
    header = ['t_s']
    for name, _ in groups:
        header += [f'{name.lower()}_cpu_pct', f'{name.lower()}_rss_mb']
    header += ['mem_avail_mb', 'load1']

    rows = []
    while time.monotonic() < t_end:
        time.sleep(a.step)
        now = time.monotonic()
        dt = now - prev_t
        row = [round(now - t_start, 1)]
        cur = {}
        for name, rx in groups:
            snap = snapshot(rx)
            cur[name] = snap
            delta_j = sum(snap[p][0] - prev[name][p][0] for p in snap if p in prev[name])
            cpu_pct = max(0.0, delta_j / HZ / dt) * 100
            rss_mb = sum(v[1] for v in snap.values()) / 1e6
            row += [round(cpu_pct, 1), round(rss_mb, 1)]
        avail, load = sysinfo()
        row += [round(avail / 1e6, 1), load]
        rows.append(row)
        prev, prev_t = cur, now

    with open(a.out, 'w', newline='') as f:
        w = csv.writer(f)
        w.writerow(header)
        w.writerows(rows)

    cols = {name: (2 + 2 * i, 3 + 2 * i) for i, (name, _) in enumerate(groups)}
    print(f"CSV written: {a.out} ({len(rows)} samples)")
    for name, (ci, ri) in cols.items():
        cpu = [r[ci] for r in rows[1:]]
        rss = [r[ri] for r in rows]
        print(f"{name}: cpu avg {sum(cpu)/len(cpu):.1f}% max {max(cpu):.1f}% | rss avg {sum(rss)/len(rss):.1f}MB max {max(rss):.1f}MB")

if __name__ == '__main__':
    main()
