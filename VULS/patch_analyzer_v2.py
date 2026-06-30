#!/usr/bin/env python3
"""
hardening_intelligence_v2.py
Uso: python3 hardening_intelligence_v2.py <arquivo.csv>

Versão para export padrão Tenable (colunas: Plugin ID, CVE, CVSS, Risk, Host,
Patch Available, Vulnerability Priority Rating (VPR), Exploit Available, etc).
Separador: tab (\t).

Descarta tudo que tem "Patch Available" = true (resolve com apt/dnf update) e
produz:

  no_patch_TOP_PRIORITY.csv   — crítico/alto + exploitável + VPR alto
  no_patch_high_critical.csv  — crítico/alto sem patch (ordenado por score)
  no_patch_medium_low.csv     — médio/baixo sem patch
  no_patch_outline.txt        — esboço de hardening por OS

Score de prioridade composto (0–100):
  - severity_num  × 10   (Critical=5, High=4, Medium=3, Low=2, Info=1)
  - vpr_score     × 5
  - exploit_avail × 15
  - age_bonus     × 0.05 (dias desde First Found, cap 365)
"""

import csv
import sys
import os
from datetime import datetime, timezone
from collections import Counter, defaultdict

OUTPUT_COLUMNS = [
    "priority_score",
    "age_in_days",
    "Host",
    "FQDN",
    "IP Address",
    "OS",
    "CVE",
    "CVSS",
    "CVSS3 Base Score",
    "CVSS3 Temporal Score",
    "Vulnerability Priority Rating (VPR)",
    "Exploit Available",
    "Name",
    "Risk",
    "Solution",
    "Severity",
    "Vulnerability State",
]

SEVERITY_MAP = {
    "critical": 5,
    "high": 4,
    "medium": 3,
    "low": 2,
    "info": 1,
    "informational": 1,
}


def parse_score(value):
    try:
        return float(value)
    except (TypeError, ValueError):
        return None


def parse_severity(value):
    if not value:
        return None
    return SEVERITY_MAP.get(value.strip().lower())


def patch_available(row):
    value = (row.get("Patch Available", "") or "").strip().lower()
    return value in ("true", "yes", "1")


def is_exploitable(row):
    value = (row.get("Exploit Available", "") or "").strip().lower()
    return value in ("true", "yes", "1")


def normalize_os(os_value):
    if not os_value:
        return "unknown"
    t = os_value.lower()
    if "debian" in t or "ubuntu" in t:
        return "debian"
    if "rhel" in t or "red hat" in t or "centos" in t or "fedora" in t or "rocky" in t or "alma" in t:
        return "rhel"
    if "windows" in t:
        return "windows"
    return "other"


def age_in_days(row):
    raw = row.get("First Found", "")
    if not raw:
        return 0.0
    try:
        dt = datetime.fromisoformat(raw.replace("Z", "+00:00"))
        return max((datetime.now(timezone.utc) - dt).total_seconds() / 86400.0, 0.0)
    except ValueError:
        return 0.0


def priority_score(row):
    sev = parse_severity(row.get("Severity", "")) or 0
    vpr = parse_score(row.get("Vulnerability Priority Rating (VPR)", "")) or 0.0
    age = min(row.get("age_in_days", 0.0), 365.0)
    exploit_bonus = 15 if is_exploitable(row) else 0

    score = (sev * 10) + (vpr * 5) + exploit_bonus + (age * 0.05)
    return round(score, 2)


def category_for_row(row):
    sev = parse_severity(row.get("Severity", ""))
    cvss3 = parse_score(row.get("CVSS3 Base Score", ""))

    if sev is not None:
        if sev >= 4:
            return "high_critical"
        if sev >= 3:
            return "medium"
        return "low"

    if cvss3 is not None:
        if cvss3 >= 7.0:
            return "high_critical"
        if cvss3 >= 4.0:
            return "medium"
        return "low"

    return "unknown"


def is_top_priority(row):
    sev = parse_severity(row.get("Severity", ""))
    cvss3 = parse_score(row.get("CVSS3 Base Score", ""))
    vpr = parse_score(row.get("Vulnerability Priority Rating (VPR)", ""))

    high_enough = (sev is not None and sev >= 4) or (cvss3 is not None and cvss3 >= 7.0)
    vpr_ok = (vpr is None) or (vpr >= 7.0)

    return high_enough and is_exploitable(row) and vpr_ok


def write_csv(path, rows, columns):
    with open(path, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=columns, delimiter=";", extrasaction="ignore")
        writer.writeheader()
        writer.writerows(rows)
    print(f"  -> {path}  ({len(rows)} linhas)")


def sorted_by_score(rows):
    return sorted(rows, key=lambda r: r.get("priority_score", 0), reverse=True)


def print_summary(title, rows):
    print(f"\n{'='*60}")
    print(f"  {title}")
    print(f"{'='*60}")
    print(f"  Total itens   : {len(rows)}")
    if not rows:
        return

    hosts = len({r.get("Host", "") for r in rows})
    cves  = len({r.get("CVE", "") for r in rows if r.get("CVE", "")})
    expl  = sum(1 for r in rows if is_exploitable(r))

    print(f"  Hosts distintos   : {hosts}")
    print(f"  CVEs distintos    : {cves}")
    print(f"  Exploitáveis      : {expl}  ({expl*100//len(rows) if rows else 0}%)")

    os_count = Counter(normalize_os(r.get("OS", "")) for r in rows)
    print("  OS profile:")
    for os_name, count in os_count.most_common():
        print(f"    {os_name}: {count}")

    print("  Top 20 CVEs (por ocorrência):")
    cve_count = Counter(r.get("CVE", "<none>") for r in rows)
    for cve, count in cve_count.most_common(20):
        print(f"    {cve}: {count}")

    top5 = sorted_by_score(rows)[:5]
    print("  Top 5 por score de prioridade:")
    for r in top5:
        print(f"    [{r['priority_score']:5.1f}] {r.get('CVE','?'):20s}  "
              f"sev={r.get('Severity','?'):8s}  "
              f"vpr={r.get('Vulnerability Priority Rating (VPR)','?'):4s}  "
              f"exploit={'SIM' if is_exploitable(r) else 'nao':3s}  "
              f"host={r.get('Host','?')}")


def build_hardening_outline(rows):
    by_os = defaultdict(list)
    for row in rows:
        by_os[normalize_os(row.get("OS", ""))].append(row)

    sections = []
    for os_label in ["debian", "rhel", "windows", "other", "unknown"]:
        os_rows = by_os.get(os_label)
        if not os_rows:
            continue

        header = (
            f"\n{'#'*70}\n"
            f"# HARDENING — {os_label.upper()}  ({len(os_rows)} itens, "
            f"{len({r.get('Host','') for r in os_rows})} hosts)\n"
            f"{'#'*70}"
        )

        unique: dict = {}
        for row in os_rows:
            key = (row.get("CVE", ""), row.get("Name", ""))
            if key not in unique or row["priority_score"] > unique[key]["priority_score"]:
                unique[key] = row

        lines = [header]
        for row in sorted_by_score(list(unique.values())):
            exploit_tag = "[EXPLOIT]" if is_exploitable(row) else "         "
            lines.append(
                f"\n{exploit_tag} score={row['priority_score']:5.1f} | "
                f"{row.get('CVE','N/A'):20s} | "
                f"sev={row.get('Severity','?'):8s} | "
                f"cvss3={row.get('CVSS3 Base Score','?'):4s} | "
                f"vpr={row.get('Vulnerability Priority Rating (VPR)','?'):4s} | "
                f"age={row.get('age_in_days',0):.0f}d"
            )
            lines.append(f"  vuln    : {row.get('Name','')}")
            if row.get("Solution", "").strip():
                lines.append(f"  solução : {row['Solution'].strip()}")

        sections.append("\n".join(lines))

    return "\n\n".join(sections)


def main():
    if len(sys.argv) != 2:
        print("Uso: python3 hardening_intelligence_v2.py <arquivo.csv>")
        sys.exit(1)

    input_file = sys.argv[1]
    base = os.path.splitext(os.path.basename(input_file))[0]

    out_top      = f"{base}_TOP_PRIORITY.csv"
    out_high     = f"{base}_high_critical.csv"
    out_med_low  = f"{base}_medium_low.csv"
    out_outline  = f"{base}_hardening_outline.txt"

    print(f"\nLendo: {input_file}")

    with open(input_file, newline="", encoding="utf-8", errors="replace") as f:
        sample = f.read(4096)
        f.seek(0)
        delimiter = "\t" if sample.count("\t") > sample.count(";") and sample.count("\t") > sample.count(",") else (";" if sample.count(";") > sample.count(",") else ",")
        reader = csv.DictReader(f, delimiter=delimiter)
        all_rows = list(reader)

    print(f"  Total bruto: {len(all_rows)} linhas")

    no_patch = [r for r in all_rows if not patch_available(r)]
    print(f"  Sem patch disponível: {len(no_patch)} ({len(all_rows)-len(no_patch)} descartados com patch)")

    for row in no_patch:
        row["age_in_days"] = age_in_days(row)
        row["priority_score"] = priority_score(row)

    high_rows    = [r for r in no_patch if category_for_row(r) == "high_critical"]
    med_low_rows = [r for r in no_patch if category_for_row(r) != "high_critical"]
    top_rows     = [r for r in high_rows if is_top_priority(r)]

    high_rows    = sorted_by_score(high_rows)
    med_low_rows = sorted_by_score(med_low_rows)
    top_rows     = sorted_by_score(top_rows)

    print_summary("TOP PRIORITY  (alto/crítico + exploitável + VPR>=7)", top_rows)
    print_summary("Sem patch — Altas / Críticas", high_rows)
    print_summary("Sem patch — Médias / Baixas", med_low_rows)

    print("\nGravando arquivos:")
    write_csv(out_top,     top_rows,     OUTPUT_COLUMNS)
    write_csv(out_high,    high_rows,    OUTPUT_COLUMNS)
    write_csv(out_med_low, med_low_rows, OUTPUT_COLUMNS)

    outline = build_hardening_outline(high_rows)
    with open(out_outline, "w", encoding="utf-8") as f:
        f.write(outline)
    print(f"  -> {out_outline}  (outline de hardening)")

    print(f"\nPronto. {len(top_rows)} itens TOP PRIORITY pra atacar primeiro.\n")


if __name__ == "__main__":
    main()