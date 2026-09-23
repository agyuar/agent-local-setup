#!/usr/bin/env python3
"""Muestreo CPU% + RAM a partir de cgroups v2 (preciso, sin regex).
CPU% = uso acumulado (usec) delta/dt → fracción de 1 núcleo, *100.
RAM = memory.current (bytes) en MB.
Uso:
 python3 sample_cgroups.py \
   --spec 'DB:system.slice/system-postgresql.slice;RT:system.slice/docker.service' \
   --out /tmp/foot.csv --dur 60 --step 2
"""
import argparse, csv, time

CG = '/sys/fs/cgroup'

def cpu_use(path):
    try:
        line = open(f'{CG}/{path}/cpu.stat').read().splitlines()[0]  # usage_usec N
        return int(line.split()[1])
    except Exception:
        return None

def mem_bytes(path):
    try:
        return int(open(f'{CG}/{path}/memory.current').read().strip())
    except Exception:
        return 0

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--spec', required=True, help="'NAME:cgroup-relpath;NAME2:...'" )
    ap.add_argument('--out', required=True)
    ap.add_argument('--dur', type=int, default=60)
    ap.add_argument('--step', type=float, default=2.0)
    a = ap.parse_args()

    groups = []
    for part in a.spec.split(';'):
        name, rel = part.split(':', 1)
        groups.append((name, rel.strip().lstrip('/')))

    # initial snapshot
    prev = {n: (cpu_use(r) if cpu_use(r) is not None else 0) for n, r in groups}
    t0 = t_prev = time.monotonic()
    t_end = t0 + a.dur
    header = ['t_s']
    for n, _ in groups:
        header += [f'{n}_cpu_pct', f'{n}_mem_mb']
    rows = []

    while time.monotonic() < t_end:
        time.sleep(a.step)
        now = time.monotonic()
        dt = now - t_prev
        row = [round(now - t0, 1)]
        cur = {}
        for n, r in groups:
            u = cpu_use(r)
            u = u if u is not None else prev.get(n, 0)
            cpu_pct = max(0.0, (u - prev.get(n, 0)) / 1e6 / dt) * 100.0
            mem_mb = mem_bytes(r) / 1e6
            cur[n] = u
            row += [round(cpu_pct, 1), round(mem_mb, 1)]
        rows.append(row)
        prev = cur
        t_prev = now

    with open(a.out, 'w', newline='') as f:
        w = csv.writer(f)
        w.writerow(header)
        w.writerows(rows)

    for i, (n, _) in enumerate(groups):
        ci, mi = 1 + 2 * i, 2 + 2 * i
        cpu = [r[ci] for r in rows[1:]]
        mem = [r[mi] for r in rows]
        if cpu:
            print(f"{n}: cpu avg {sum(cpu)/len(cpu):.1f}% max {max(cpu):.1f}% | mem avg {sum(mem)/len(mem):.1f}MB max {max(mem):.1f}MB")
        else:
            print(f"{n}: (sin muestras)")
    print(f"CSV: {a.out} ({len(rows)} muestras)")

if __name__ == '__main__':
    main()
