#!/usr/bin/env bash
set -u

ID=167
TITLE='Tamanho máximo audit'

echo "[$ID] $TITLE"

need_root() {
  if [ "$(id -u)" -ne 0 ]; then
    echo "FAIL | execute como root"
    exit 1
  fi
}

backup_file() {
  [ -f "$1" ] && cp -p "$1" "$1.bkp_$(date +%Y%m%d_%H%M%S)"
}


set_kv_file() {
  need_root
  file="$1"; key="$2"; value="$3"
  touch "$file"
  backup_file "$file"
  if grep -Eq "^[[:space:]]*#?[[:space:]]*$key[[:space:]]*=" "$file"; then
    sed -i -E "s|^[[:space:]]*#?[[:space:]]*$key[[:space:]]*=.*|$key = $value|" "$file"
  else
    printf '%s = %s
' "$key" "$value" >> "$file"
  fi
}

set_sysctl() {
  need_root
  key="$1"; value="$2"; file="/etc/sysctl.d/99-hitss-hardening.conf"
  touch "$file"
  backup_file "$file"
  if grep -Eq "^[[:space:]]*$key[[:space:]]*=" "$file"; then
    sed -i -E "s|^[[:space:]]*$key[[:space:]]*=.*|$key = $value|" "$file"
  else
    printf '%s = %s
' "$key" "$value" >> "$file"
  fi
  sysctl -w "$key=$value" >/dev/null 2>&1 || true
}

manual() {
  echo "MANUAL | $*"
  exit 0
}

file=/etc/audit/auditd.conf
set_kv_file "$file" max_log_file 64
echo "OK"
