#!/usr/bin/env bash

pkg_installed() {
  dpkg-query -W -f='${Status}' "$1" 2>/dev/null | grep -q "install ok installed"
}

pkg_any_installed() {
  local pkg
  for pkg in "$@"; do
    pkg_installed "$pkg" && return 0
  done
  return 1
}

service_enabled() {
  systemctl is-enabled --quiet "$1" 2>/dev/null
}

service_enabled_any() {
  local svc
  for svc in "$@"; do
    service_enabled "$svc" && return 0
  done
  return 1
}

service_active_any() {
  local svc
  for svc in "$@"; do
    systemctl is-active --quiet "$svc" 2>/dev/null && return 0
  done
  return 1
}

time_sync_active_count() {
  local count=0
  service_active_any chrony chronyd && count=$((count + 1))
  service_active_any ntp ntpd ntpsec && count=$((count + 1))
  service_active_any systemd-timesyncd && count=$((count + 1))
  echo "$count"
}

mount_has_opts() {
  local mountpoint="$1"
  shift
  local opts opt
  opts="$(findmnt -n -o OPTIONS --target "$mountpoint" 2>/dev/null)" || return 1
  for opt in "$@"; do
    grep -qw "$opt" <<< "$opts" || return 1
  done
}

fstab_path_has_opts() {
  local path_re="$1"
  shift
  local entry found opt
  local entries
  entries="$(grep -Ehv '^[[:space:]]*#|^[[:space:]]*$' /etc/fstab 2>/dev/null | awk -v p="$path_re" '$2 ~ p {print $4}')" || return 1
  [ -n "$entries" ] || return 1
  while read -r entry; do
    [ -n "$entry" ] || continue
    found=1
    for opt in "$@"; do
      grep -qw "$opt" <<< "$entry" || return 1
    done
  done <<< "$entries"
  [ "${found:-0}" -eq 1 ]
}

sshd_effective_config() {
  if command -v sshd >/dev/null 2>&1; then
    sshd -T -C user=root,host="$(hostname 2>/dev/null || echo localhost)",addr=127.0.0.1 2>/dev/null && return 0
  fi
  cat /etc/ssh/sshd_config /etc/ssh/sshd_config.d/*.conf 2>/dev/null
}

grub_cfg_path() {
  if [ -f /boot/grub/grub.cfg ]; then
    echo /boot/grub/grub.cfg
  elif [ -f /boot/grub2/grub.cfg ]; then
    echo /boot/grub2/grub.cfg
  else
    echo ""
  fi
}

GRUBCFG="$(grub_cfg_path)"

echo -e "\n[1] Verificar se módulo cramfs está bloqueado"
(modinfo cramfs &>/dev/null && modprobe --showconfig | grep -Pq '\b(install|blacklist)\h+cramfs\b' && ! lsmod | grep -q cramfs) || (! modinfo cramfs &>/dev/null) && echo "PASS" || echo "FAIL"

echo -e "\n[2] Verificar se módulo squashfs está bloqueado"
(modinfo squashfs &>/dev/null && modprobe --showconfig | grep -Pq '\b(install|blacklist)\h+squashfs\b' && ! lsmod | grep -q squashfs) || (! modinfo squashfs &>/dev/null) && echo "PASS" || echo "FAIL"

echo -e "\n[3] Verificar se módulo udf está bloqueado"
(modinfo udf &>/dev/null && modprobe --showconfig | grep -Pq '\b(install|blacklist)\h+udf\b' && ! lsmod | grep -q udf) || (! modinfo udf &>/dev/null) && echo "PASS" || echo "FAIL"

echo -e "\n[4] Verificar se módulo hfs está bloqueado"
(modinfo hfs &>/dev/null && modprobe --showconfig | grep -Pq '\b(install|blacklist)\h+hfs\b' && ! lsmod | grep -q hfs) || (! modinfo hfs &>/dev/null) && echo "PASS" || echo "FAIL"

echo -e "\n[5] Verificar se módulo hfsplus está bloqueado"
(modinfo hfsplus &>/dev/null && modprobe --showconfig | grep -Pq '\b(install|blacklist)\h+hfsplus\b' && ! lsmod | grep -q hfsplus) || (! modinfo hfsplus &>/dev/null) && echo "PASS" || echo "FAIL"

echo -e "\n[6] Verificar se módulo jffs2 está bloqueado"
(modinfo jffs2 &>/dev/null && modprobe --showconfig | grep -Pq '\b(install|blacklist)\h+jffs2\b' && ! lsmod | grep -q jffs2) || (! modinfo jffs2 &>/dev/null) && echo "PASS" || echo "FAIL"

echo -e "\n[7] Verificar se módulo freevxfs está bloqueado"
(modinfo freevxfs &>/dev/null && modprobe --showconfig | grep -Pq '\b(install|blacklist)\h+freevxfs\b' && ! lsmod | grep -q freevxfs) || (! modinfo freevxfs &>/dev/null) && echo "PASS" || echo "FAIL"

echo -e "\n[8] Checa se overlay nao esta carregado e se ha regra de bloqueio"
(modinfo overlay &>/dev/null && modprobe --showconfig | grep -Pq '\b(install|blacklist)\h+overlay\b' && ! lsmod | grep -q overlay) || (! modinfo overlay &>/dev/null) && echo "PASS" || echo "FAIL"

echo -e "\n[9] Verificar se usb_storage está bloqueado"
(modinfo usb-storage &>/dev/null && modprobe --showconfig | grep -Pq '\b(install|blacklist)\h+usb_storage\b' && ! lsmod | grep -q usb_storage) || (! modinfo usb-storage &>/dev/null) && echo "PASS" || echo "FAIL"

echo -e "\n[10] Confere se dccp nao esta carregado e se existe regra de bloqueio"
(modinfo dccp &>/dev/null && modprobe --showconfig | grep -Pq '\b(install|blacklist)\h+dccp\b' && ! lsmod | grep -q dccp) || (! modinfo dccp &>/dev/null) && echo "PASS" || echo "FAIL"

echo -e "\n[11] Checa se sctp nao esta carregado e se esta bloqueado em modprobe"
(modinfo sctp &>/dev/null && modprobe --showconfig | grep -Pq '\b(install|blacklist)\h+sctp\b' && ! lsmod | grep -q sctp) || (! modinfo sctp &>/dev/null) && echo "PASS" || echo "FAIL"

echo -e "\n[12] Valida que rds nao esta ativo e esta proibido em modprobe"
(modinfo rds &>/dev/null && modprobe --showconfig | grep -Pq '\b(install|blacklist)\h+rds\b' && ! lsmod | grep -q rds) || (! modinfo rds &>/dev/null) && echo "PASS" || echo "FAIL"

echo -e "\n[13] Checa se tipc nao esta carregado e se ha bloqueio configurado"
(modinfo tipc &>/dev/null && modprobe --showconfig | grep -Pq '\b(install|blacklist)\h+tipc\b' && ! lsmod | grep -q tipc) || (! modinfo tipc &>/dev/null) && echo "PASS" || echo "FAIL"

echo -e "\n[14] Verifica limite de core e valor de fs suid dumpable igual a zero"
([ "$(ulimit -c)" = "0" ] && sysctl -n fs.suid_dumpable | grep -q '^0$') && echo "PASS" || echo "FAIL"

echo -e "\n[15] Verificar valor de fs.suid_dumpable"
(sysctl -n fs.suid_dumpable | grep -q '^0$') && echo "PASS" || echo "FAIL"

echo -e "\n[16] Checa suporte a nx na cpu e mensagem de ativacao no dmesg"
(grep -q 'nx' /proc/cpuinfo && dmesg | grep -qi 'NX.*active') && echo "PASS" || echo "FAIL"

echo -e "\n[17] Verifica kernel randomize va space igual a dois"
(sysctl -n kernel.randomize_va_space | grep -q '^2$') && echo "PASS" || echo "FAIL"

echo -e "\n[18] Verificar randomize_va_space"
(sysctl -n kernel.randomize_va_space | grep -q '^2$') && echo "PASS" || echo "FAIL"

echo -e "\n[19] Verifica kernel perf event paranoid em nivel mais restritivo"
(sysctl -n kernel.perf_event_paranoid | grep -q '^[2-3]$') && echo "PASS" || echo "FAIL"

echo -e "\n[20] Verificar perf_event_paranoid"
(sysctl -n kernel.perf_event_paranoid | grep -q '^[2-3]$') && echo "PASS" || echo "FAIL"

echo -e "\n[21] Verificar dmesg_restrict"
(sysctl -n kernel.dmesg_restrict | grep -q '^1$') && echo "PASS" || echo "FAIL"

echo -e "\n[22] Checa fs protected symlinks igual a um"
(sysctl -n fs.protected_symlinks | grep -q '^1$') && echo "PASS" || echo "FAIL"

echo -e "\n[23] Verificar protected_symlinks"
(sysctl -n fs.protected_symlinks | grep -q '^1$') && echo "PASS" || echo "FAIL"

echo -e "\n[24] Verificar protected_hardlinks"
(sysctl -n fs.protected_hardlinks | grep -q '^1$') && echo "PASS" || echo "FAIL"

echo -e "\n[25] Verifica se existe montagem especifica para tmp via findmnt"
(findmnt -kn /tmp >/dev/null && echo "PASS" || echo "FAIL")

echo -e "\n[26] Checa montagem propria para dev shm"
(findmnt -kn /dev/shm >/dev/null && echo "PASS" || echo "FAIL")

echo -e "\n[27] Verifica montagem independente para var"
(findmnt -kn /var >/dev/null && echo "PASS" || echo "FAIL")

echo -e "\n[28] Checa se var tmp possui montagem propria"
(findmnt -kn /var/tmp >/dev/null && echo "PASS" || echo "FAIL")

echo -e "\n[29] Confere montagem especifica para var log"
(findmnt -kn /var/log >/dev/null && echo "PASS" || echo "FAIL")

echo -e "\n[30] Verifica se var log audit tem montagem independente"
(findmnt -kn /var/log/audit >/dev/null && echo "PASS" || echo "FAIL")

echo -e "\n[31] Checa montagem independente para home"
(findmnt -kn /home >/dev/null && echo "PASS" || echo "FAIL")

echo -e "\n[32] Verifica se existe montagem especifica para historico"
(findmnt -kn /historico >/dev/null && echo "PASS" || echo "FAIL")

echo -e "\n[33] Confere montagem dedicada para crash"
(findmnt -kn /crash >/dev/null && echo "PASS" || echo "FAIL")

echo -e "\n[34] Verifica se ha montagem propria para UNIX"
(findmnt -kn /UNIX >/dev/null && echo "PASS" || echo "FAIL")

echo -e "\n[35] Verificar opções de montagem para mídias removíveis"
(fstab_path_has_opts '^(/media|/run/media)' nodev nosuid noexec && echo "PASS" || echo "FAIL")

echo -e "\n[36] Verificar opções de montagem críticas"
(fstab_path_has_opts '^/(var|tmp|dev/shm|var/tmp|var/log|var/log/audit|home)$' nodev nosuid && echo "PASS" || echo "FAIL")

echo -e "\n[37] Checa se tmp possui opcoes nodev nosuid e noexec"
(mount_has_opts /tmp nodev nosuid noexec && echo "PASS" || echo "FAIL")

echo -e "\n[38] Verifica nodev nosuid noexec na montagem de dev shm"
(mount_has_opts /dev/shm nodev nosuid noexec && echo "PASS" || echo "FAIL")

echo -e "\n[39] Checa opcoes nodev nosuid ou noexec em var tmp"
(mount_has_opts /var/tmp nodev nosuid noexec && echo "PASS" || echo "FAIL")

echo -e "\n[40] Verificar opções de montagem de /var/log"
(mount_has_opts /var/log nodev nosuid && echo "PASS" || echo "FAIL")

echo -e "\n[41] Verificar opções de montagem de /var/log/audit"
(mount_has_opts /var/log/audit nodev nosuid && echo "PASS" || echo "FAIL")

echo -e "\n[42] Verificar opções de montagem de /home"
(findmnt -n /home | grep -qw nodev && echo "PASS" || echo "FAIL")

echo -e "\n[43] Verifica se midias removiveis estao definidas com opcoes seguras em fstab"
(fstab_path_has_opts '^(/media|/run/media)' nodev nosuid noexec && echo "PASS" || echo "FAIL")

echo -e "\n[44] Verificar sticky bit em diretórios world writable"
(find / -xdev -type d -perm -0002 ! -perm -1000 2>/dev/null | grep . && echo "FAIL" || echo "PASS")

echo -e "\n[45] Verificar sticky bit em /tmp"
(stat -c "%A" /tmp | grep -q 't' && echo "PASS" || echo "FAIL")

echo -e "\n[46] Verificar sticky bit em /var/tmp"
(stat -c "%A" /var/tmp | grep -q 't' && echo "PASS" || echo "FAIL")

echo -e "\n[47] Verificar sticky bit em /dev/shm"
(stat -c "%A" /dev/shm | grep -q 't' && echo "PASS" || echo "FAIL")

echo -e "\n[48] Verifica se o servico autofs esta desabilitado"
(systemctl is-enabled autofs &>/dev/null && echo "FAIL" || echo "PASS")

echo -e "\n[49] Verifica presenca de senha hash em grub cfg"
if [ -n "$GRUBCFG" ]; then
  (grep -q 'password_pbkdf2' "$GRUBCFG" 2>/dev/null && echo "PASS" || echo "FAIL")
else
  echo "FAIL"
fi

echo -e "\n[50] Verifica permissoes de leitura e propriedade do grub cfg"
if [ -n "$GRUBCFG" ]; then
  (stat -Lc '%a %U %G' "$GRUBCFG" 2>/dev/null | grep -Eq '^(400|600) root root$' && echo "PASS" || echo "FAIL")
else
  echo "FAIL"
fi

echo -e "\n[51] Confere configuracao de autenticacao no systemd e emergency service"
(grep -q '^ExecStart=-/bin/sh' /usr/lib/systemd/system/emergency.service && echo "FAIL" || echo "PASS")

#echo -e "\n[55] Sem serviços sem restrições MAC (Manual)"
#(ps -eZ | grep -q 'unconfined_t' && echo "FAIL" || echo "PASS")

echo -e "\n[56] Verificar se prelink está instalado"
(pkg_installed prelink && echo "FAIL" || echo "PASS")

echo -e "\n[57] Verificar presença de xinetd"
(pkg_installed xinetd && echo "FAIL" || echo "PASS")

echo -e "\n[58] Verificar serviço de tempo ativo"
( service_active_any chrony chronyd ntp ntpd ntpsec systemd-timesyncd ) && echo "PASS" || echo "FAIL"

echo -e "\n[59] Verificar servidores configurados"
( ! pkg_installed chrony || ( service_enabled_any chrony chronyd && grep -Eq '^[[:space:]]*(server|pool)[[:space:]]+' /etc/chrony/chrony.conf /etc/chrony.conf 2>/dev/null ) ) && echo "PASS" || echo "FAIL"

echo -e "\n[60] Verificar sincronização automática"
( ! pkg_any_installed ntp ntpsec || ( service_enabled_any ntp ntpd ntpsec && grep -Eq '^[[:space:]]*(server|pool)[[:space:]]+' /etc/ntp.conf /etc/ntpsec/ntp.conf 2>/dev/null ) ) && echo "PASS" || echo "FAIL"

echo -e "\n[61] Verificar presença de pacotes X11"
(pkg_any_installed xserver-xorg-core xorg xserver-common gdm3 lightdm ubuntu-desktop kubuntu-desktop xubuntu-desktop && echo "FAIL" || echo "PASS")

echo -e "\n[62] Verificar status do avahi"
(pkg_installed avahi-daemon && echo "FAIL" || echo "PASS")

echo -e "\n[63] Verificar status do CUPS"
(pkg_installed cups && echo "FAIL" || echo "PASS")

echo -e "\n[64] Checa se pacote dhcp server esta instalado"
(pkg_any_installed isc-dhcp-server kea-dhcp4-server && echo "FAIL" || echo "PASS")

echo -e "\n[65] Verifica se openldap servers esta instalado"
(pkg_installed slapd && echo "FAIL" || echo "PASS")

echo -e "\n[66] Checa se pacote bind esta instalado"
(pkg_installed bind9 && echo "FAIL" || echo "PASS")

echo -e "\n[67] Confere presenca do pacote vsftpd"
(pkg_installed vsftpd && echo "FAIL" || echo "PASS")

echo -e "\n[68] Verifica se httpd esta instalado"
(pkg_any_installed apache2 nginx lighttpd && echo "FAIL" || echo "PASS")

echo -e "\n[69] Verificar presença de serviços IMAP POP3"
(pkg_any_installed dovecot-imapd dovecot-pop3d && echo "FAIL" || echo "PASS")

echo -e "\n[70] Verificar presença de Samba"
(pkg_installed samba && echo "FAIL" || echo "PASS")

echo -e "\n[71] Verificar presença de proxy HTTP"
(pkg_installed squid && echo "FAIL" || echo "PASS")

echo -e "\n[72] Verificar status do SNMP"
(pkg_installed snmpd && echo "FAIL" || echo "PASS")

echo -e "\n[73] Verificar presença de NIS"
(pkg_installed nis && echo "FAIL" || echo "PASS")

echo -e "\n[74] Verificar presença de telnetd"
(pkg_any_installed telnetd inetutils-telnetd && echo "FAIL" || echo "PASS")

echo -e "\n[75] Verificar configuração do MTA"
( [ ! -f /etc/postfix/main.cf ] || grep -Eq '^[[:space:]]*inet_interfaces[[:space:]]*=[[:space:]]*(localhost|loopback-only)\b' /etc/postfix/main.cf 2>/dev/null ) && echo "PASS" || echo "FAIL"

echo -e "\n[76] Verificar presença de NFS server"
(systemctl is-enabled nfs-server &>/dev/null && echo "FAIL" || echo "PASS")

echo -e "\n[77] Verificar status do rpcbind"
(systemctl is-enabled rpcbind &>/dev/null && echo "FAIL" || echo "PASS")

echo -e "\n[78] Verificar presença do rsync daemon"
(systemctl is-enabled rsyncd &>/dev/null && echo "FAIL" || echo "PASS")

echo -e "\n[79] Verificar presença do cliente NIS"
(pkg_installed nis && echo "FAIL" || echo "PASS")

echo -e "\n[80] Verificar presença de rsh"
(pkg_any_installed rsh-client rsh-redone-client && echo "FAIL" || echo "PASS")

echo -e "\n[81] Verificar presença de talk"
(pkg_installed talk && echo "FAIL" || echo "PASS")

echo -e "\n[82] Verificar presença de cliente telnet"
(pkg_any_installed telnet inetutils-telnet && echo "FAIL" || echo "PASS")

echo -e "\n[83] Verificar presença de cliente LDAP"
(pkg_installed ldap-utils && echo "FAIL" || echo "PASS")

echo -e "\n[84] Verificar serviços ativos não autorizados"
(systemctl list-unit-files --state=enabled 2>/dev/null | grep -Eq '^(avahi-daemon|cups|vsftpd|xinetd|tftpd-hpa|nis|rpcbind|slapd)\.service' && echo "FAIL" || echo "PASS")

echo -e "\n[85] Verificar presença de TFTP"
(pkg_any_installed tftpd-hpa atftpd && echo "FAIL" || echo "PASS")

echo -e "\n[86] Verificar regras do polkit"
( grep -Ehv '^[[:space:]]*(//|#)' /etc/polkit-1/rules.d/*.rules 2>/dev/null | grep -Eq 'polkit\.Result\.YES|[^[:alnum:]_]allow[^[:alnum:]_]' ) && echo "FAIL" || echo "PASS"

echo -e "\n[87] Verificar ausência de trusted=yes e permissões APT inseguras"
(find /etc/apt/sources.list /etc/apt/sources.list.d -type f -print0 2>/dev/null | xargs -0r grep -Ehv '^[[:space:]]*(#|$)' 2>/dev/null | grep -Eiq '^[[:space:]]*deb[[:space:]]|^[[:space:]]*Types:[[:space:]]*.*\bdeb\b' && ! find /etc/apt/sources.list /etc/apt/sources.list.d -type f -print0 2>/dev/null | xargs -0r grep -Eiq '(^|[[:space:]\[])trusted[[:space:]]*=[[:space:]]*yes|^[[:space:]]*Trusted:[[:space:]]*yes' && ! apt-config dump 2>/dev/null | grep -Eq 'Acquire::AllowInsecureRepositories "true"|Acquire::AllowDowngradeToInsecureRepositories "true"|APT::Get::AllowUnauthenticated "true"' && echo "PASS" || echo "FAIL")

echo -e "\n[88] Verificar atualizações pendentes"
(apt list --upgradable 2>/dev/null | grep -Eiq 'security|ubuntu[[:alnum:].-]+-security|debian-security' && echo "FAIL" || echo "PASS")

echo -e "\n[89] Verificar serviços de tempo ativos"
([ "$(time_sync_active_count)" -eq 1 ] && echo "PASS" || echo "FAIL")

echo -e "\n[90] Verificar allow-list de usuários para cron e at"
(stat -Lc '%a %U %G' /etc/cron.allow 2>/dev/null | grep -Eq '^640 root (root|crontab)$' && [ ! -e /etc/cron.deny ] && { ! command -v at >/dev/null 2>&1 || { stat -Lc '%a %U %G' /etc/at.allow 2>/dev/null | grep -Eq '^640 root (root|daemon)$' && [ ! -e /etc/at.deny ]; }; } && echo "PASS" || echo "FAIL")

echo -e "\n[91] Confere sysctl de net ipv4 ip forward e net ipv6 conf all forwarding iguais a zero"
(sysctl -n net.ipv4.ip_forward 2>/dev/null | grep -q '^0$' && sysctl -n net.ipv6.conf.all.forwarding 2>/dev/null | grep -q '^0$' && echo "PASS" || echo "FAIL")

echo -e "\n[92] Verificar configuração de redirects"
(sysctl -n net.ipv4.conf.all.send_redirects 2>/dev/null | grep -q '^0$' && echo "PASS" || echo "FAIL")

echo -e "\n[93] Verificar parâmetros de source route"
(sysctl -n net.ipv4.conf.all.accept_source_route 2>/dev/null | grep -q '^0$' && echo "PASS" || echo "FAIL")

echo -e "\n[94] Verificar ICMP redirects"
(sysctl -n net.ipv4.conf.all.accept_redirects 2>/dev/null | grep -q '^0$' && sysctl -n net.ipv4.conf.all.secure_redirects 2>/dev/null | grep -q '^0$' && echo "PASS" || echo "FAIL")

echo -e "\n[95] Verificar rp_filter"
(sysctl -n net.ipv4.conf.all.rp_filter 2>/dev/null | grep -Eq '^[12]$' && echo "PASS" || echo "FAIL")

echo -e "\n[96] Verificar ignore_broadcasts"
(sysctl -n net.ipv4.icmp_echo_ignore_broadcasts 2>/dev/null | grep -q '^1$' && echo "PASS" || echo "FAIL")

echo -e "\n[97] Verificar ignore_bogus_error_responses"
(sysctl -n net.ipv4.icmp_ignore_bogus_error_responses 2>/dev/null | grep -q '^1$' && echo "PASS" || echo "FAIL")

echo -e "\n[98] Verificar tcp_syncookies"
(sysctl -n net.ipv4.tcp_syncookies 2>/dev/null | grep -q '^1$' && echo "PASS" || echo "FAIL")

echo -e "\n[99] Verifica sysctl net ipv6 conf all disable ipv6 igual a um"
(sysctl -n net.ipv6.conf.all.disable_ipv6 2>/dev/null | grep -q '^1$' && echo "PASS" || echo "FAIL")

echo -e "\n[102] Verificar interfaces wireless ou bluetooth ativas"
( { find /sys/class/net -mindepth 2 -maxdepth 2 -name wireless -exec dirname {} \; 2>/dev/null | while read -r d; do [ "$(cat "$d/operstate" 2>/dev/null)" = "up" ] && exit 0; done; exit 1; } || rfkill list 2>/dev/null | awk 'BEGIN{RS=""} /Bluetooth|Wireless|WLAN/ && /Soft blocked: no/ && /Hard blocked: no/{found=1} END{exit !found}' ) && echo "FAIL" || echo "PASS"

echo -e "\n[108] Verificar se políticas de criptografia bloqueiam TLS < 1."
(grep -REiq 'MinProtocol[[:space:]]*=[[:space:]]*TLSv1\.[23]|TLS.MinProtocol[[:space:]]*=[[:space:]]*TLSv1\.[23]' /etc/ssl/openssl.cnf /etc/ssl/openssl.cnf.d /etc/ssl/openssl.cnf.d/* 2>/dev/null) && echo "PASS" || echo "FAIL"

echo -e "\n[109] Verificar permissões de arquivos e diretório SSH"
( stat -c %a /etc/ssh/sshd_config | grep -Eq '^(600|400)$' && [ "$(stat -c %U:%G /etc/ssh)" = "root:root" ] ) && echo "PASS" || echo "FAIL"
#Em POSIX, permissões não são ordenáveis semanticamente por número

echo -e "\n[110] Procura diretivas AllowUsers AllowGroups DenyUsers ou DenyGroups no sshd config"
(sshd_effective_config | grep -Eiq '^(allowusers|allowgroups|denyusers|denygroups)[[:space:]]+' && echo "PASS" || echo "FAIL")

echo -e "\n[111] Verificar parâmetro SyslogFacility"
(sshd_effective_config | grep -Eiq '^syslogfacility[[:space:]]+AUTHPRIV\b' && echo "PASS" || echo "FAIL")

echo -e "\n[112] Verificar parâmetro X11Forwarding"
(sshd_effective_config | grep -Eiq '^x11forwarding[[:space:]]+no\b' && echo "PASS" || echo "FAIL")

echo -e "\n[113] Verificar valor de MaxAuthTries"
(sshd_effective_config | grep -Eiq '^maxauthtries[[:space:]]+[1-4]$' && echo "PASS" || echo "FAIL")

echo -e "\n[114] Verificar parâmetro IgnoreRhosts"
(sshd_effective_config | grep -Eiq '^ignorerhosts[[:space:]]+yes\b' && echo "PASS" || echo "FAIL")

echo -e "\n[115] Verificar parâmetro HostbasedAuthentication"
(sshd_effective_config | grep -Eiq '^hostbasedauthentication[[:space:]]+no\b' && echo "PASS" || echo "FAIL")

#echo -e "\n[116] PermitRootLogin restrito/desabilitado"
#(grep -Eq '^[[:space:]]*PermitRootLogin[[:space:]]+(no|prohibit-password)' /etc/ssh/sshd_config) && echo "PASS" || echo "FAIL"

echo -e "\n[117] Verificar parâmetro PermitEmptyPasswords"
(sshd_effective_config | grep -Eiq '^permitemptypasswords[[:space:]]+no\b' && echo "PASS" || echo "FAIL")

echo -e "\n[118] Verificar parâmetro PermitUserEnvironment"
(sshd_effective_config | grep -Eiq '^permituserenvironment[[:space:]]+no\b' && echo "PASS" || echo "FAIL")

echo -e "\n[119] Verificar parâmetro UsePAM"
(sshd_effective_config | grep -Eiq '^usepam[[:space:]]+yes\b' && echo "PASS" || echo "FAIL")

echo -e "\n[120] Verificar parâmetros ClientAlive"
(sshd_effective_config | grep -Eiq '^clientaliveinterval[[:space:]]+([1-9][0-9]|[1-2][0-9]{2}|300)$' && sshd_effective_config | grep -Eiq '^clientalivecountmax[[:space:]]+[1-3]$') && echo "PASS" || echo "FAIL"

echo -e "\n[121] Verificar parâmetro LoginGraceTime"
(sshd_effective_config | grep -Eiq '^logingracetime[[:space:]]+([1-9][0-9]|[1-5][0-9]{2})s?$' && echo "PASS" || echo "FAIL")

echo -e "\n[122] Verificar parâmetros MaxStartups e MaxSessions"
(sshd_effective_config | grep -Eiq '^maxstartups[[:space:]]+.+$' && sshd_effective_config | grep -Eiq '^maxsessions[[:space:]]+[1-9]+' ) && echo "PASS" || echo "FAIL"

echo -e "\n[123] Confere se AllowTcpForwarding esta definido como no ou restrito"
(sshd_effective_config | grep -Eiq '^allowtcpforwarding[[:space:]]+no\b' && echo "PASS" || echo "FAIL")

echo -e "\n[124] Verificar parâmetro Banner"
( sshd_effective_config | grep -Eiq '^banner[[:space:]]+\S+' ) && echo "PASS" || echo "FAIL"

echo -e "\n[125] Verifica se diretiva Ciphers contem algoritmo forte"
(sshd_effective_config | grep -Eiq '^ciphers[[:space:]]+.*(chacha20|aes256).*' && echo "PASS" || echo "FAIL")

echo -e "\n[126] Checa se diretiva MACs contem algoritmo seguro"
(sshd_effective_config | grep -Eiq '^macs[[:space:]]+.*(hmac-sha2|umac).*' && echo "PASS" || echo "FAIL")

echo -e "\n[127] Verifica se KexAlgorithms inclui metodo forte"
(sshd_effective_config | grep -Eiq '^kexalgorithms[[:space:]]+.*(curve25519|diffie-hellman-group-exchange-sha256).*' && echo "PASS" || echo "FAIL")

echo -e "\n[128] Checa se Ciphers ou KexAlgorithms contem suite moderna"
(sshd_effective_config | grep -Eiq '^(ciphers|kexalgorithms)[[:space:]]+.*(chacha20|curve25519).*' && echo "PASS" || echo "FAIL")

echo -e "\n[129] Verifica se ha diretivas ForceCommand ou ChrootDirectory configuradas para contas especificas"
(sshd_effective_config | grep -Eiq '^(forcecommand|chrootdirectory)[[:space:]]+' && echo "PASS" || echo "FAIL")

echo -e "\n[130] Verificar presença do módulo de complexidade na stack PAM"
grep -Eq 'pam_pwquality\.so' /etc/pam.d/*auth /etc/pam.d/common-password 2>/dev/null && echo "PASS" || echo "FAIL"

echo -e "\n[131] Verificar parâmetros do pam_pwquality"
( grep -Eq 'pam_pwquality\.so' /etc/pam.d/common-password 2>/dev/null && grep -Psiq '^\s*minlen\s*=\s*(1[4-9]|[2-9][0-9]+)\b' /etc/security/pwquality.conf /etc/security/pwquality.conf.d/*.conf 2>/dev/null && grep -Psiq '^\s*minclass\s*=\s*[4-9]\b' /etc/security/pwquality.conf /etc/security/pwquality.conf.d/*.conf 2>/dev/null ) && echo "PASS" || echo "FAIL"

echo -e "\n[132] Verifica uso de pam faillock nas pilhas de autenticacao"
(grep -Eq 'pam_faillock\.so' /etc/pam.d/common-auth /etc/pam.d/common-account 2>/dev/null) && echo "PASS" || echo "FAIL"

echo -e "\n[133] Checa referencias a pam tally2 nas pilhas de autenticacao"
! grep -Eq 'pam_tally2\.so' /etc/pam.d/*auth && echo "PASS" || echo "FAIL"

echo -e "\n[134] Verificar configuração de pwhistory"
(grep -Eq 'pam_pwhistory\.so' /etc/pam.d/common-password 2>/dev/null) && echo "PASS" || echo "FAIL"

echo -e "\n[135] Verificar parâmetro de tamanho mínimo"
grep -Psiq '^\s*minlen\s*=\s*(1[4-9]|[2-9][0-9]+)' /etc/security/pwquality.conf* && echo "PASS" || echo "FAIL"

echo -e "\n[136] Verificar requisitos de complexidade"
grep -Psiq '^\s*minclass\s*=\s*[4-9]' /etc/security/pwquality.conf* && echo "PASS" || echo "FAIL"

echo -e "\n[137] Verificar parâmetros de repetição e sequência"
grep -Psiq '^\s*maxrepeat\s*=\s*3\b'   /etc/security/pwquality.conf* && grep -Psiq '^\s*maxsequence\s*=\s*3\b' /etc/security/pwquality.conf* && echo "PASS" || echo "FAIL"

echo -e "\n[138] Verificar parâmetro de verificação de dicionário"
! grep -Psiq '^\s*dictcheck\s*=\s*0\b' /etc/security/pwquality.conf* && echo "PASS" || echo "FAIL"

echo -e "\n[139] Verificar algoritmo configurado"
grep -Eq 'pam_unix\.so.*(sha512|yescrypt)' /etc/pam.d/*auth /etc/pam.d/common-password 2>/dev/null && echo "PASS" || echo "FAIL"

echo -e "\n[140] Verificar parâmetro de histórico"
(grep -Eq 'pam_pwhistory\.so.*remember=([5-9]|[1-9][0-9]+)' /etc/pam.d/common-password 2>/dev/null) && echo "PASS" || echo "FAIL"

echo -e "\n[141] Verifica parametro deny em faillock conf"
grep -Piq '^\s*deny\s*=\s*[1-5]\s*$' /etc/security/faillock.conf 2>/dev/null && echo "PASS" || echo "FAIL"

echo -e "\n[142] Verificar tempo de desbloqueio"
grep -Pi '^\s*unlock_time\s*=\s*(9[0-9]{2}|[1-9][0-9]{3,})\b' /etc/security/faillock.conf && echo "PASS" || echo "FAIL"

echo -e "\n[143] Verificar PASS_MAX_DAYS"
val=$(awk '$1=="PASS_MAX_DAYS"{print $2; exit}' /etc/login.defs); [[ "$val" =~ ^[0-9]+$ ]] && [[ "$val" -le 365 ]] && echo "PASS" || echo "FAIL"

echo -e "\n[144] Verificar PASS_MIN_DAYS"
grep -Eq '^\s*PASS_MIN_DAYS\s+[1-9][0-9]*' /etc/login.defs && echo "PASS" || echo "FAIL"

echo -e "\n[145] Verificar PASS_WARN_AGE"
grep -Eq '^\s*PASS_WARN_AGE\s+([7-9]|[1-9][0-9]+)' /etc/login.defs && echo "PASS" || echo "FAIL"

echo -e "\n[146] Verificar parâmetro INACTIVE"
awk -F: '$2~/^\$/ && ($7=="" || $7<30){exit 1}' /etc/shadow && echo "PASS" || echo "FAIL"

echo -e "\n[147] Verificar inconsistências de data"
awk -F: '$2~/^\$/{if($3==""||$3==0) exit 1} END{exit 0}' /etc/shadow && echo "PASS" || echo "FAIL"

echo -e "\n[148] Verificar contas com UID 0"
awk -F: '($3==0 && $1!="root"){exit 1}' /etc/passwd && echo "PASS" || echo "FAIL"

echo -e "\n[149] Verificar grupos com GID 0"
awk -F: '($3==0 && $1!="root"){exit 1}' /etc/group && echo "PASS" || echo "FAIL"

echo -e "\n[150] Verificar shells de contas de sistema"
awk -F: '($3<1000 && $1!="root" && $7 ~ /(bash|sh|zsh)$/){exit 1}' /etc/passwd && echo "PASS" || echo "FAIL"

echo -e "\n[151] Verificar conteúdo de /etc/shells"
grep -qE '^(\/usr)?\/sbin\/nologin$' /etc/shells && echo "PASS" || echo "FAIL"

echo -e "\n[152] Verificar variável PATH do root"
(grep -Rqs 'PATH=.*\/usr/local/sbin.*\/usr/sbin.*\/sbin' /root/.profile /root/.bashrc /etc/profile /etc/profile.d 2>/dev/null) && echo "PASS" || echo "FAIL"

echo -e "\n[153] Verificar valor de umask padrão"
grep -Rqs 'umask 027' /etc/profile /etc/bash.bashrc /etc/profile.d 2>/dev/null && echo "PASS" || echo "FAIL"

echo -e "\n[154] Verificar variável de timeout"
grep -Rqs 'TMOUT=900' /etc/profile /etc/bash.bashrc /etc/profile.d 2>/dev/null && echo "PASS" || echo "FAIL"

echo -e "\n[155] Verificar configuração do sudoers"
grep -RqsE '^%.*ALL=\(ALL\)' /etc/sudoers /etc/sudoers.d 2>/dev/null && echo "FAIL" || echo "PASS"

echo -e "\n[156] Verificar parâmetro requiretty ou equivalente"
grep -Rqs 'use_pty' /etc/sudoers /etc/sudoers.d && echo "PASS" || echo "FAIL"

echo -e "\n[157] Verificar configuração de log do sudo"
grep -Rqs 'logfile=' /etc/sudoers /etc/sudoers.d && echo "PASS" || echo "FAIL"

echo -e "\n[158] Verifica ausencia de Defaults authenticate desabilitado em sudoers"
grep -Rqs '!authenticate' /etc/sudoers /etc/sudoers.d && echo "FAIL" || echo "PASS"

echo -e "\n[159] Verificar configuração de timeout"
grep -Rqs 'timestamp_timeout=5' /etc/sudoers /etc/sudoers.d && echo "PASS" || echo "FAIL"

echo -e "\n[160] Verificar configuração do su e grupo permitido"
grep -Eq 'pam_wheel\.so.*group=(sudo|wheel)' /etc/pam.d/su && echo "PASS" || echo "FAIL"

echo -e "\n[161] Verificar se há ao menos um mecanismo de log ativo"
( service_active_any rsyslog systemd-journald && echo "PASS" || echo "FAIL" )

echo -e "\n[162] Verificar persistência do systemd-journald"
(grep -REiq '^[[:space:]]*Storage[[:space:]]*=[[:space:]]*persistent\b' /etc/systemd/journald.conf /etc/systemd/journald.conf.d/*.conf 2>/dev/null && echo "PASS" || echo "FAIL")

echo -e "\n[163] Verificar presença e status do rsyslog"
( pkg_installed rsyslog && systemctl is-active rsyslog &>/dev/null ) && echo "PASS" || echo "FAIL"

echo -e "\n[164] Verificar configuração de rotação"
( grep -Eq 'rsyslog' /etc/logrotate.d/* 2>/dev/null ) && echo "PASS" || echo "FAIL"

echo -e "\n[165] Verificar presença e status do auditd"
( ( pkg_installed audit || pkg_installed auditd ) && systemctl is-active auditd &>/dev/null ) && echo "PASS" || echo "FAIL"

echo -e "\n[166] Verificar ordem de inicialização"
grep -q 'audit=1' /proc/cmdline && echo "PASS" || echo "FAIL"

echo -e "\n[167] Verificar parâmetro max_log_file"
( grep -Eq '^\s*max_log_file\s*=\s*[1-9]' /etc/audit/auditd.conf ) && echo "PASS" || echo "FAIL"

echo -e "\n[168] Verifica max log file action em auditd conf para garantir keep logs ou rotate"
( grep -Eq '^\s*max_log_file_action\s*=\s*(keep_logs|rotate)' /etc/audit/auditd.conf ) && echo "PASS" || echo "FAIL"

echo -e "\n[169] Verificar regras de auditoria de time change"
( auditctl -l 2>/dev/null | grep -Eq 'adjtimex|settimeofday|clock_settime' ) && echo "PASS" || echo "FAIL"

echo -e "\n[170] Verificar regras de auditoria relacionadas a contas"
( auditctl -l 2>/dev/null | grep -Eq '/etc/(passwd|shadow|group|gshadow)' ) && echo "PASS" || echo "FAIL"

echo -e "\n[171] Verificar regras de auditoria de rede"
( auditctl -l 2>/dev/null | grep -Eq 'sethostname|setdomainname|/etc/hosts|/etc/hostname' ) && echo "PASS" || echo "FAIL"

echo -e "\n[173] Verificar regras de auditoria de login"
( auditctl -l 2>/dev/null | grep -Eq '/var/log/faillog|/var/log/lastlog|/var/run/utmp' ) && echo "PASS" || echo "FAIL"

echo -e "\n[174] Verificar regras de auditoria DAC"
( auditctl -l 2>/dev/null | grep -Eq 'chmod|chown|fchmod|fchown' ) && echo "PASS" || echo "FAIL"

echo -e "\n[175] Verificar regras de acesso negado"
( auditctl -l 2>/dev/null | grep -Eq 'EACCES|EPERM' ) && echo "PASS" || echo "FAIL"

echo -e "\n[176] Verificar regras de execve privilegiado"
( find / -xdev -perm -4000 -type f 2>/dev/null | while read -r f; do auditctl -l 2>/dev/null | grep -q "$f" || exit 1; done ) && echo "PASS" || echo "FAIL"

echo -e "\n[177] Verificar regras relacionadas a mount"
( auditctl -l 2>/dev/null | grep -Eq 'mount|umount' ) && echo "PASS" || echo "FAIL"

echo -e "\n[178] Verificar regras de deleção"
( auditctl -l 2>/dev/null | grep -Eq 'unlink|rename|rmdir|unlinkat|renameat' ) && echo "PASS" || echo "FAIL"

echo -e "\n[179] Verificar regras relacionadas a módulos"
( auditctl -l 2>/dev/null | grep -Eq 'init_module|finit_module|delete_module' ) && echo "PASS" || echo "FAIL"

echo -e "\n[180] Verificar regras de auditoria de sudo"
( auditctl -l 2>/dev/null | grep -Eq '/etc/sudoers|/etc/sudoers.d' ) && echo "PASS" || echo "FAIL"

echo -e "\n[181] Verifica se parametro e2 esta ativo em auditctl"
( auditctl -s 2>/dev/null | grep -Eq '^[[:space:]]*enabled[[:space:]]+2\b' ) && echo "PASS" || echo "FAIL"

echo -e "\n[182] Verifica instalacao do pacote AIDE e existencia de banco de dados inicial"
( pkg_installed aide && [ -f /var/lib/aide/aide.db.gz ] ) && echo "PASS" || echo "FAIL"

echo -e "\n[183] Verificar agendamento configurado"
( grep -Ersq 'aide(\.wrapper)? .*(--check|--update|\$AIDEARGS)' /etc/cron.* /etc/crontab /var/spool/cron 2>/dev/null || systemctl list-timers --all 2>/dev/null | grep -qi aide ) && echo "PASS" || echo "FAIL"

echo -e "\n[184] Verifica permissoes e proprietario de binarios como auditctl aureport ausearch auditd"
( for b in auditctl aureport ausearch autrace auditd augenrules; do p="$(command -v "$b")" || exit 1; stat -Lc "%U %G" "$p" | awk '{if($1!="root" || $2!="root") exit 1}' || exit 1; done ) && echo "PASS" || echo "FAIL"

echo -e "\n[185] Verificar permissões de /etc/passwd"
( [ -f /etc/passwd ] && stat -Lc '%a %u %g' /etc/passwd | awk '{m=$1+0; exit !($2==0 && $3==0 && m<=644 && int(m/10)%10<5 && m%10<5)}' ) && echo "PASS" || echo "FAIL"

echo -e "\n[186] Verificar permissões de /etc/passwd-"
( [ -f /etc/passwd- ] && stat -Lc '%a %u %g' /etc/passwd- | awk '{m=$1+0; exit !($2==0 && $3==0 && m<=644 && int(m/10)%10<5 && m%10<5)}' ) && echo "PASS" || echo "FAIL"

echo -e "\n[187] Verificar permissões de /etc/shadow"
( [ -f /etc/shadow ] && stat -Lc "%a %u %g" /etc/shadow | grep -Eq '^0+ 0 0$' ) && echo "PASS" || echo "FAIL"

echo -e "\n[188] Verificar permissões de /etc/shadow-"
( [ -f /etc/shadow- ] && stat -Lc "%a %u %g" /etc/shadow- | grep -Eq '^0+ 0 0$' ) && echo "PASS" || echo "FAIL"

echo -e "\n[189] Verificar permissões de /etc/gshadow-"
( [ -f /etc/gshadow- ] && stat -Lc "%a %u %g" /etc/gshadow- | grep -Eq '^(600|60[0-9]|[0-5][0-9]{2}) 0 0$' ) && echo "PASS" || echo "FAIL"

echo -e "\n[190] Verificar permissões de /etc/gshadow"
( [ -f /etc/gshadow ] && stat -Lc "%a %u %g" /etc/gshadow | grep -Eq '^(600|60[0-9]|[0-5][0-9]{2}) 0 0$' ) && echo "PASS" || echo "FAIL"

echo -e "\n[191] Verificar permissões de /etc/group"
( [ -f /etc/group ] && stat -Lc '%a %u %g' /etc/group | awk '{m=$1+0; exit !($2==0 && $3==0 && m<=644 && int(m/10)%10<5 && m%10<5)}' ) && echo "PASS" || echo "FAIL"

echo -e "\n[192] Verificar permissões de /etc/group-"
( [ -f /etc/group- ] && stat -Lc '%a %u %g' /etc/group- | awk '{m=$1+0; exit !($2==0 && $3==0 && m<=644 && int(m/10)%10<5 && m%10<5)}' ) && echo "PASS" || echo "FAIL"

echo -e "\n[193] Verifica se nologin aparece listado em etc shells"
grep -qE '^(\/usr)?\/sbin\/nologin$' /etc/shells && echo "PASS" || echo "FAIL"

echo -e "\n[194] Verificar permissões de opasswd"
( [ -f /etc/security/opasswd ] && stat -Lc "%a %u %g" /etc/security/opasswd | grep -Eq '^600 0 0$' ) && echo "PASS" || echo "FAIL"

echo -e "\n[195] Identificar arquivos sem owner válido"
( find / -xdev -nouser 2>/dev/null | grep -q . ) && echo "FAIL" || echo "PASS"

echo -e "\n[196] Verificar sticky bit em diretórios world writable"
(find / -xdev -type d -perm -0002 ! -perm -1000 2>/dev/null | grep . && echo "FAIL" || echo "PASS")

echo -e "\n[197] Identificar arquivos sem grupo válido"
( find / -xdev -nogroup 2>/dev/null | grep -q . ) && echo "FAIL" || echo "PASS"

echo -e "\n[198] Lista arquivos com bits SUID ou SGID definidos"
( find / -xdev \( -perm -4000 -o -perm -2000 \) 2>/dev/null | grep -Ev '^(/usr/bin/sudo|/usr/bin/su|/bin/su|/usr/bin/passwd|/usr/bin/chage|/usr/bin/chsh|/usr/bin/chfn|/usr/bin/newgrp|/usr/bin/gpasswd|/usr/sbin/unix_chkpwd|/usr/sbin/pam_timestamp_check|/usr/bin/mount|/usr/bin/umount|/usr/bin/fusermount|/usr/bin/pkexec|/usr/bin/crontab|/usr/bin/ssh-agent|/usr/bin/ksu|/usr/libexec/openssh/ssh-keysign|/usr/bin/ping|/usr/bin/ping6|/usr/bin/traceroute|/usr/bin/traceroute6)$' | grep -q . ) && echo "FAIL" || echo "PASS"

echo -e "\n[199] Verificar usuários sem diretório home"
( awk -F: '$3>=1000 && $1!="nobody"{print $6}' /etc/passwd | while read -r h; do [ -d "$h" ] || exit 1; done ) && echo "PASS" || echo "FAIL"

echo -e "\n[200] Verificar ownership dos diretórios home"
( awk -F: '$3>=1000 && $1!="nobody"{print $1,$6}' /etc/passwd | while read -r u h; do [ -d "$h" ] && [ "$(stat -Lc %U "$h")" = "$u" ] || exit 1; done ) && echo "PASS" || echo "FAIL"

echo -e "\n[201] Verificar permissões dos diretórios home"
( awk -F: '$3>=1000 && $1!="nobody"{print $6}' /etc/passwd | while read -r h; do [ -d "$h" ] && [ "$(stat -Lc %a "$h")" -le 750 ] || exit 1; done ) && echo "PASS" || echo "FAIL"

echo -e "\n[202] Verificar permissões de dotfiles"
( while read -r h; do [ -d "$h" ] || continue; find "$h" -maxdepth 1 -type f -name ".*" -perm /022 2>/dev/null; done < <(awk -F: '$3>=1000 && $1!="nobody"{print $6}' /etc/passwd) | grep -q . ) && echo "FAIL" || echo "PASS"

echo -e "\n[203] Verificar presença desses arquivos"
( while read -r h; do [ -d "$h" ] || continue; for f in "$h/.forward" "$h/.netrc" "$h/.rhosts"; do [ -e "$f" ] && echo "$f"; done; done < <(awk -F: '$3>=1000 && $1!="nobody"{print $6}' /etc/passwd) | grep -q . ) && echo "FAIL" || echo "PASS"
