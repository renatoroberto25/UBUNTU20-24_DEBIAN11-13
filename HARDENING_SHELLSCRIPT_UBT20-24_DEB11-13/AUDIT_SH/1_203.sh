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

echo -e "\n[1] Verifique se o módulo do kernel do CRAMFS não está disponível"
(modinfo cramfs &>/dev/null && modprobe --showconfig | grep -Pq '\b(install|blacklist)\h+cramfs\b' && ! lsmod | grep -q cramfs) || (! modinfo cramfs &>/dev/null) && echo "PASS" || echo "FAIL"

echo -e "\n[2] Verifique se o módulo do kernel do SQUASHFS não está disponível"
(modinfo squashfs &>/dev/null && modprobe --showconfig | grep -Pq '\b(install|blacklist)\h+squashfs\b' && ! lsmod | grep -q squashfs) || (! modinfo squashfs &>/dev/null) && echo "PASS" || echo "FAIL"

echo -e "\n[3] Verifique se o módulo do kernel do UDF não está disponível"
(modinfo udf &>/dev/null && modprobe --showconfig | grep -Pq '\b(install|blacklist)\h+udf\b' && ! lsmod | grep -q udf) || (! modinfo udf &>/dev/null) && echo "PASS" || echo "FAIL"

echo -e "\n[4] Verifique se o módulo do kernel do HFS não está disponível"
(modinfo hfs &>/dev/null && modprobe --showconfig | grep -Pq '\b(install|blacklist)\h+hfs\b' && ! lsmod | grep -q hfs) || (! modinfo hfs &>/dev/null) && echo "PASS" || echo "FAIL"

echo -e "\n[5] Verifique se o módulo do kernel do HFSPLUS não está disponível"
(modinfo hfsplus &>/dev/null && modprobe --showconfig | grep -Pq '\b(install|blacklist)\h+hfsplus\b' && ! lsmod | grep -q hfsplus) || (! modinfo hfsplus &>/dev/null) && echo "PASS" || echo "FAIL"

echo -e "\n[6] Verifique se o módulo do kernel do JFFS2 não está disponível"
(modinfo jffs2 &>/dev/null && modprobe --showconfig | grep -Pq '\b(install|blacklist)\h+jffs2\b' && ! lsmod | grep -q jffs2) || (! modinfo jffs2 &>/dev/null) && echo "PASS" || echo "FAIL"

echo -e "\n[7] Verifique se o módulo do kernel do FREEVXFS não está disponível"
(modinfo freevxfs &>/dev/null && modprobe --showconfig | grep -Pq '\b(install|blacklist)\h+freevxfs\b' && ! lsmod | grep -q freevxfs) || (! modinfo freevxfs &>/dev/null) && echo "PASS" || echo "FAIL"

echo -e "\n[8] Verifique se o módulo do kernel do OVERLAY não está disponível"
(modinfo overlay &>/dev/null && modprobe --showconfig | grep -Pq '\b(install|blacklist)\h+overlay\b' && ! lsmod | grep -q overlay) || (! modinfo overlay &>/dev/null) && echo "PASS" || echo "FAIL"

echo -e "\n[9] Verifique se o módulo do kernel do USB-STORAGE não está disponível"
(modinfo usb-storage &>/dev/null && modprobe --showconfig | grep -Pq '\b(install|blacklist)\h+usb_storage\b' && ! lsmod | grep -q usb_storage) || (! modinfo usb-storage &>/dev/null) && echo "PASS" || echo "FAIL"

echo -e "\n[10] Verifique se o módulo do kernel do DCCP não está disponível"
(modinfo dccp &>/dev/null && modprobe --showconfig | grep -Pq '\b(install|blacklist)\h+dccp\b' && ! lsmod | grep -q dccp) || (! modinfo dccp &>/dev/null) && echo "PASS" || echo "FAIL"

echo -e "\n[11] Verifique se o módulo do kernel do SCTP não está disponível"
(modinfo sctp &>/dev/null && modprobe --showconfig | grep -Pq '\b(install|blacklist)\h+sctp\b' && ! lsmod | grep -q sctp) || (! modinfo sctp &>/dev/null) && echo "PASS" || echo "FAIL"

echo -e "\n[12] Verifique se o módulo do kernel do RDS não está disponível"
(modinfo rds &>/dev/null && modprobe --showconfig | grep -Pq '\b(install|blacklist)\h+rds\b' && ! lsmod | grep -q rds) || (! modinfo rds &>/dev/null) && echo "PASS" || echo "FAIL"

echo -e "\n[13] Verifique se o módulo do kernel do TIPC não está disponível"
(modinfo tipc &>/dev/null && modprobe --showconfig | grep -Pq '\b(install|blacklist)\h+tipc\b' && ! lsmod | grep -q tipc) || (! modinfo tipc &>/dev/null) && echo "PASS" || echo "FAIL"

echo -e "\n[14] Verifique se core dumps estão restritos"
(ulimit -c 0 && sysctl -n fs.suid_dumpable | grep -q '^0$') && echo "PASS" || echo "FAIL"

echo -e "\n[15] Verifique se ptrace_scope está restrito"
(sysctl -n kernel.yama.ptrace_scope | grep -q '^[1-3]$') && echo "PASS" || echo "FAIL"

echo -e "\n[16] Verifique se NX/XD está ativo"
(grep -q 'nx' /proc/cpuinfo && dmesg | grep -qi 'NX.*active') && echo "PASS" || echo "FAIL"
echo -e "Possível ausência no hardware"

echo -e "\n[17] Verifique se ASLR está habilitado"
(sysctl -n kernel.randomize_va_space | grep -q '^2$') && echo "PASS" || echo "FAIL"

echo -e "\n[18] Verifique se IOMMU está ativo"
(grep -q 'iommu=on' /proc/cmdline) && echo "PASS" || echo "FAIL"

echo -e "\n[19] Verifique se perf_event está restrito"
(sysctl -n kernel.perf_event_paranoid | grep -q '^[2-3]$') && echo "PASS" || echo "FAIL"

echo -e "\n[20] Verifique se dmesg está restrito"
(sysctl -n kernel.dmesg_restrict | grep -q '^1$') && echo "PASS" || echo "FAIL"

echo -e "\n[21] Verifique se user namespace está desabilitado"
( [ ! -e /proc/sys/kernel/unprivileged_userns_clone ] || sysctl -n kernel.unprivileged_userns_clone 2>/dev/null | grep -q '^0$' ) && echo "PASS" || echo "FAIL"

echo -e "\n[22] Verifique se protected_symlinks está habilitado"
(sysctl -n fs.protected_symlinks | grep -q '^1$') && echo "PASS" || echo "FAIL"

echo -e "\n[23] Verifique se protected_hardlinks está habilitado"
(sysctl -n fs.protected_hardlinks | grep -q '^1$') && echo "PASS" || echo "FAIL"

echo -e "\n[24] Verifique se suid_dumpable=0"
(sysctl -n fs.suid_dumpable | grep -q '^0$') && echo "PASS" || echo "FAIL"

echo -e "\n[25] Partição dedicada para /tmp"
(findmnt -kn /tmp >/dev/null && echo "PASS" || echo "FAIL")

echo -e "\n[26] Partição dedicada para /dev/shm"
(findmnt -kn /dev/shm >/dev/null && echo "PASS" || echo "FAIL")

echo -e "\n[27] Partição dedicada para /var"
(findmnt -kn /var >/dev/null && echo "PASS" || echo "FAIL")

echo -e "\n[28] Partição dedicada para /var/tmp"
(findmnt -kn /var/tmp >/dev/null && echo "PASS" || echo "FAIL")

echo -e "\n[29] Partição dedicada para /var/log"
(findmnt -kn /var/log >/dev/null && echo "PASS" || echo "FAIL")

echo -e "\n[30] Partição dedicada para /var/log/audit"
(findmnt -kn /var/log/audit >/dev/null && echo "PASS" || echo "FAIL")

echo -e "\n[31] Partição dedicada para /home"
(findmnt -kn /home >/dev/null && echo "PASS" || echo "FAIL")

echo -e "\n[32] Partição dedicada para /historico"
(findmnt -kn /historico >/dev/null && echo "PASS" || echo "FAIL")

echo -e "\n[33] Partição dedicada para /crash"
(findmnt -kn /crash >/dev/null && echo "PASS" || echo "FAIL")

echo -e "\n[34] Partição dedicada para /UNIX"
(findmnt -kn /UNIX >/dev/null && echo "PASS" || echo "FAIL")

echo -e "\n[35] Montagem segura de partições e mídia removível"
(grep -E 'nodev|nosuid|noexec' /etc/fstab >/dev/null && echo "PASS" || echo "FAIL")

echo -e "\n[36] Opções de montagem seguras em partições críticas"
(findmnt -n /var | grep -Eq 'nodev|nosuid|noexec' && echo "PASS" || echo "FAIL")

echo -e "\n[37] Opções de montagem seguras em /tmp"
(findmnt -n /tmp | grep -Eq 'nodev|nosuid|noexec' && echo "PASS" || echo "FAIL")

echo -e "\n[38] Opções de montagem seguras em /dev/shm"
(findmnt -n /dev/shm | grep -Eq 'nodev|nosuid|noexec' && echo "PASS" || echo "FAIL")

echo -e "\n[39] Opções de montagem seguras em /var/tmp"
(findmnt -n /var/tmp | grep -Eq 'nodev|nosuid|noexec' && echo "PASS" || echo "FAIL")

echo -e "\n[40] Opções de montagem seguras em /var/log"
(findmnt -n /var/log | grep -Eq 'nodev|nosuid|noexec' && echo "PASS" || echo "FAIL")

echo -e "\n[41] Opções de montagem seguras em /var/log/audit"
(findmnt -n /var/log/audit | grep -Eq 'nodev|nosuid|noexec' && echo "PASS" || echo "FAIL")

echo -e "\n[42] Opções de montagem seguras em /home"
(findmnt -n /home | grep -qw nodev && echo "PASS" || echo "FAIL")

echo -e "\n[43] Opções de montagem seguras em mídias removíveis"
(grep -E 'nodev|nosuid|noexec' /etc/fstab | grep -E '/media|/run/media' >/dev/null && echo "PASS" || echo "FAIL")

echo -e "\n[44] Sticky bit em diretórios world-writable"
(find / -xdev -type d -perm -0002 ! -perm -1000 2>/dev/null | grep . && echo "FAIL" || echo "PASS")

echo -e "\n[45] Sticky bit em /tmp"
(stat -c "%A" /tmp | grep -q 't' && echo "PASS" || echo "FAIL")

echo -e "\n[46] Sticky bit em /var/tmp"
(stat -c "%A" /var/tmp | grep -q 't' && echo "PASS" || echo "FAIL")

echo -e "\n[47] Sticky bit em /dev/shm"
(stat -c "%A" /dev/shm | grep -q 't' && echo "PASS" || echo "FAIL")

echo -e "\n[48] Autofs desabilitado"
(systemctl is-enabled autofs &>/dev/null && echo "FAIL" || echo "PASS")

echo -e "\n[49] Senha de bootloader configurada"
if [ -n "$GRUBCFG" ]; then
  (grep -q 'password_pbkdf2' "$GRUBCFG" 2>/dev/null && echo "PASS" || echo "FAIL")
else
  echo "FAIL"
fi

echo -e "\n[50] Permissões seguras no arquivo do bootloader"
if [ -n "$GRUBCFG" ]; then
  (stat -Lc '%a %U %G' "$GRUBCFG" 2>/dev/null | grep -Eq '^(400|600) root root$' && echo "PASS" || echo "FAIL")
else
  echo "FAIL"
fi

echo -e "\n[51] Single user mode com autenticação"
(grep -q '^ExecStart=-/bin/sh' /usr/lib/systemd/system/emergency.service && echo "FAIL" || echo "PASS")

#echo -e "\n[55] Sem serviços sem restrições MAC (Manual)"
#(ps -eZ | grep -q 'unconfined_t' && echo "FAIL" || echo "PASS")

echo -e "\n[56] Prelink removido"
(pkg_installed prelink && echo "FAIL" || echo "PASS")

echo -e "\n[57] xinetd removido"
(pkg_installed xinetd && echo "FAIL" || echo "PASS")

echo -e "\n[58] Sincronização de tempo em uso"
( systemctl is-active --quiet chronyd &>/dev/null || systemctl is-active --quiet ntpd &>/dev/null || systemctl is-active --quiet systemd-timesyncd &>/dev/null ) && echo "PASS" || echo "FAIL"

echo -e "\n[59] Chrony configurado"
( ! pkg_installed chrony || ( service_enabled chronyd && grep -q '^server' /etc/chrony.conf 2>/dev/null ) ) && echo "PASS" || echo "FAIL"

echo -e "\n[60] NTP configurado"
( ! pkg_installed ntp || ( service_enabled ntpd && grep -q '^server' /etc/ntp.conf 2>/dev/null ) ) && echo "PASS" || echo "FAIL"

echo -e "\n[61] X11 ausente"
(pkg_any_installed xserver-xorg-core xorg xserver-common gdm3 lightdm ubuntu-desktop kubuntu-desktop xubuntu-desktop && echo "FAIL" || echo "PASS")

echo -e "\n[62] Avahi ausente"
(pkg_installed avahi-daemon && echo "FAIL" || echo "PASS")

echo -e "\n[63] CUPS ausente"
(pkg_installed cups && echo "FAIL" || echo "PASS")

echo -e "\n[64] DHCP server ausente"
(pkg_any_installed isc-dhcp-server kea-dhcp4-server && echo "FAIL" || echo "PASS")

echo -e "\n[65] LDAP server ausente"
(pkg_installed slapd && echo "FAIL" || echo "PASS")

echo -e "\n[66] DNS server ausente"
(pkg_installed bind9 && echo "FAIL" || echo "PASS")

echo -e "\n[67] FTP server ausente"
(pkg_installed vsftpd && echo "FAIL" || echo "PASS")

echo -e "\n[68] HTTP server ausente"
(pkg_any_installed apache2 nginx lighttpd && echo "FAIL" || echo "PASS")

echo -e "\n[69] IMAP/POP3 server ausente"
(pkg_any_installed dovecot-imapd dovecot-pop3d && echo "FAIL" || echo "PASS")

echo -e "\n[70] Samba ausente"
(pkg_installed samba && echo "FAIL" || echo "PASS")

echo -e "\n[71] Proxy HTTP ausente"
(pkg_installed squid && echo "FAIL" || echo "PASS")

echo -e "\n[72] SNMP ausente"
(pkg_installed snmpd && echo "FAIL" || echo "PASS")

echo -e "\n[73] NIS server ausente"
(pkg_installed nis && echo "FAIL" || echo "PASS")

echo -e "\n[74] Telnet server ausente"
(pkg_any_installed telnetd inetutils-telnetd && echo "FAIL" || echo "PASS")

echo -e "\n[75] MTA em modo local-only"
( [ ! -f /etc/postfix/main.cf ] || grep -Eq '^[[:space:]]*inet_interfaces[[:space:]]*=[[:space:]]*(localhost|loopback-only)\b' /etc/postfix/main.cf 2>/dev/null ) && echo "PASS" || echo "FAIL"

echo -e "\n[76] NFS server controlado"
(systemctl is-enabled nfs-server &>/dev/null && echo "FAIL" || echo "PASS")

echo -e "\n[77] rpcbind controlado"
(systemctl is-enabled rpcbind &>/dev/null && echo "FAIL" || echo "PASS")

echo -e "\n[78] rsync daemon controlado"
(systemctl is-enabled rsyncd &>/dev/null && echo "FAIL" || echo "PASS")

echo -e "\n[79] Cliente NIS ausente"
(pkg_installed nis && echo "FAIL" || echo "PASS")

echo -e "\n[80] Cliente rsh ausente"
(pkg_any_installed rsh-client rsh-redone-client && echo "FAIL" || echo "PASS")

echo -e "\n[81] Cliente talk ausente"
(pkg_installed talk && echo "FAIL" || echo "PASS")

echo -e "\n[82] Cliente telnet ausente"
(pkg_any_installed telnet inetutils-telnet && echo "FAIL" || echo "PASS")

echo -e "\n[83] Cliente LDAP ausente"
(pkg_installed ldap-utils && echo "FAIL" || echo "PASS")

echo -e "\n[84] Serviços não essenciais removidos/mascarados"
(systemctl list-unit-files --state=enabled 2>/dev/null | grep -Eq '^(avahi-daemon|cups|vsftpd|xinetd|tftpd-hpa|nis|rpcbind|slapd)\.service' && echo "FAIL" || echo "PASS")

echo -e "\n[85] TFTP server removido"
(pkg_any_installed tftpd-hpa atftpd && echo "FAIL" || echo "PASS")

echo -e "\n[86] PolicyKit endurecido"
( grep -Ehv '^[[:space:]]*(//|#)' /etc/polkit-1/rules.d/*.rules 2>/dev/null | grep -Eq 'polkit\.Result\.YES|[^[:alnum:]_]allow[^[:alnum:]_]' ) && echo "FAIL" || echo "PASS"

echo -e "\n[87] Assinaturas de pacotes habilitadas"
(find /etc/apt/sources.list /etc/apt/sources.list.d -type f -print0 2>/dev/null | xargs -0r grep -Ehv '^[[:space:]]*#' 2>/dev/null | grep -Eq '^[[:space:]]*deb[[:space:]]' && ! apt-config dump 2>/dev/null | grep -Eq 'Acquire::AllowInsecureRepositories "true"|APT::Get::AllowUnauthenticated "true"' && echo "PASS" || echo "FAIL")

echo -e "\n[88] Patches de segurança aplicados - USO APENAS EM TEMPLATES"
(apt list --upgradable 2>/dev/null | grep -Eiq 'security|ubuntu[[:alnum:].-]+-security|debian-security' && echo "FAIL" || echo "PASS")

echo -e "\n[89] Apenas um daemon de time sync"
( ( systemctl is-active --quiet chronyd &>/dev/null && ! systemctl is-active --quiet ntpd &>/dev/null && ! systemctl is-active --quiet systemd-timesyncd &>/dev/null ) || ( ! systemctl is-active --quiet chronyd &>/dev/null && systemctl is-active --quiet ntpd &>/dev/null && ! systemctl is-active --quiet systemd-timesyncd &>/dev/null ) || ( ! systemctl is-active --quiet chronyd &>/dev/null && ! systemctl is-active --quiet ntpd &>/dev/null && systemctl is-active --quiet systemd-timesyncd &>/dev/null ) ) && echo "PASS" || echo "FAIL"

echo -e "\n[90] Cron/at seguros e restritos"
(stat -Lc '%a %U %G' /etc/cron.allow 2>/dev/null | grep -Eq '^640 root (root|crontab)$' && echo "PASS" || echo "FAIL")

echo -e "\n[91] IP forwarding desabilitado"
(sysctl -n net.ipv4.ip_forward 2>/dev/null | grep -q '^0$' && sysctl -n net.ipv6.conf.all.forwarding 2>/dev/null | grep -q '^0$' && echo "PASS" || echo "FAIL")

echo -e "\n[92] Redirecionamentos de pacotes desabilitados"
(sysctl -n net.ipv4.conf.all.send_redirects 2>/dev/null | grep -q '^0$' && echo "PASS" || echo "FAIL")

echo -e "\n[93] Source-routed packets bloqueados"
(sysctl -n net.ipv4.conf.all.accept_source_route 2>/dev/null | grep -q '^0$' && echo "PASS" || echo "FAIL")

echo -e "\n[94] ICMP redirects bloqueados"
(sysctl -n net.ipv4.conf.all.accept_redirects 2>/dev/null | grep -q '^0$' && sysctl -n net.ipv4.conf.all.secure_redirects 2>/dev/null | grep -q '^0$' && echo "PASS" || echo "FAIL")

echo -e "\n[95] Reverse path filtering habilitado"
(sysctl -n net.ipv4.conf.all.rp_filter 2>/dev/null | grep -Eq '^[12]$' && echo "PASS" || echo "FAIL")

echo -e "\n[96] ICMP broadcast ignorado"
(sysctl -n net.ipv4.icmp_echo_ignore_broadcasts 2>/dev/null | grep -q '^1$' && echo "PASS" || echo "FAIL")

echo -e "\n[97] Respostas ICMP inválidas ignoradas"
(sysctl -n net.ipv4.icmp_ignore_bogus_error_responses 2>/dev/null | grep -q '^1$' && echo "PASS" || echo "FAIL")

echo -e "\n[98] TCP SYN cookies habilitados"
(sysctl -n net.ipv4.tcp_syncookies 2>/dev/null | grep -q '^1$' && echo "PASS" || echo "FAIL")

echo -e "\n[99] IPv6 desabilitado ou endurecido"
(sysctl -n net.ipv6.conf.all.disable_ipv6 2>/dev/null | grep -q '^1$' && echo "PASS" || echo "FAIL")

echo -e "\n[102] Wireless/Bluetooth desabilitados"
(lsmod | grep -Eq 'bluetooth|iwlwifi' && echo "FAIL" || echo "PASS")

echo -e "\n[108] TLS mínimo 1.2/1.3"
(grep -REiq 'MinProtocol[[:space:]]*=[[:space:]]*TLSv1\.[23]|TLS.MinProtocol[[:space:]]*=[[:space:]]*TLSv1\.[23]' /etc/ssl/openssl.cnf /etc/ssl/openssl.cnf.d /etc/ssl/openssl.cnf.d/* 2>/dev/null) && echo "PASS" || echo "FAIL"

echo -e "\n[109] Permissões seguras em sshd_config e chaves"
( stat -c %a /etc/ssh/sshd_config | grep -Eq '^(600|400)$' && [ "$(stat -c %U:%G /etc/ssh)" = "root:root" ] ) && echo "PASS" || echo "FAIL"
#Em POSIX, permissões não são ordenáveis semanticamente por número

echo -e "\n[110] Controle de acesso via Allow/Deny"
(grep -Eq '^[[:space:]]*(AllowUsers|AllowGroups|DenyUsers|DenyGroups)[[:space:]]+' /etc/ssh/sshd_config 2>/dev/null) && echo "PASS" || echo "FAIL"

echo -e "\n[111] LogLevel adequado"
(grep -Eq '^[[:space:]]*LogLevel[[:space:]]+(INFO|VERBOSE)' /etc/ssh/sshd_config) && echo "PASS" || echo "FAIL"

echo -e "\n[112] X11Forwarding desabilitado"
(grep -Eq '^[[:space:]]*X11Forwarding[[:space:]]+no' /etc/ssh/sshd_config) && echo "PASS" || echo "FAIL"

echo -e "\n[113] MaxAuthTries limitado"
(grep -Eq '^[[:space:]]*MaxAuthTries[[:space:]]+[1-4]$' /etc/ssh/sshd_config) && echo "PASS" || echo "FAIL"

echo -e "\n[114] IgnoreRhosts habilitado"
(grep -Eq '^[[:space:]]*IgnoreRhosts[[:space:]]+yes' /etc/ssh/sshd_config) && echo "PASS" || echo "FAIL"

echo -e "\n[115] HostbasedAuthentication desabilitado"
(grep -Eq '^[[:space:]]*HostbasedAuthentication[[:space:]]+no' /etc/ssh/sshd_config) && echo "PASS" || echo "FAIL"

#echo -e "\n[116] PermitRootLogin restrito/desabilitado"
#(grep -Eq '^[[:space:]]*PermitRootLogin[[:space:]]+(no|prohibit-password)' /etc/ssh/sshd_config) && echo "PASS" || echo "FAIL"

echo -e "\n[117] PermitEmptyPasswords desabilitado"
(grep -Eq '^[[:space:]]*PermitEmptyPasswords[[:space:]]+no' /etc/ssh/sshd_config) && echo "PASS" || echo "FAIL"

echo -e "\n[118] PermitUserEnvironment desabilitado"
(grep -Eq '^[[:space:]]*PermitUserEnvironment[[:space:]]+no' /etc/ssh/sshd_config) && echo "PASS" || echo "FAIL"

echo -e "\n[119] UsePAM habilitado"
(grep -Eq '^[[:space:]]*UsePAM[[:space:]]+yes' /etc/ssh/sshd_config) && echo "PASS" || echo "FAIL"

echo -e "\n[120] Idle timeout configurado"
(grep -Eq '^[[:space:]]*ClientAliveInterval[[:space:]]+([1-9][0-9]|[1-2][0-9]{2}|300)$' /etc/ssh/sshd_config  && grep -Eq '^[[:space:]]*ClientAliveCountMax[[:space:]]+[1-3]$' /etc/ssh/sshd_config) && echo "PASS" || echo "FAIL"

echo -e "\n[121] LoginGraceTime curto"
(grep -Eq '^[[:space:]]*LoginGraceTime[[:space:]]+([1-9][0-9]|[1-5][0-9]{2})s?$' /etc/ssh/sshd_config) && echo "PASS" || echo "FAIL"

echo -e "\n[122] MaxStartups/MaxSessions limitados"
(grep -Eq '^[[:space:]]*MaxStartups[[:space:]]+.+$' /etc/ssh/sshd_config  && grep -Eq '^[[:space:]]*MaxSessions[[:space:]]+[1-9]+' /etc/ssh/sshd_config) && echo "PASS" || echo "FAIL"

echo -e "\n[123] AllowTcpForwarding restrito"
(grep -Eq '^[[:space:]]*AllowTcpForwarding[[:space:]]+no' /etc/ssh/sshd_config) && echo "PASS" || echo "FAIL"

echo -e "\n[124] Banner legal configurado"
( grep -Eq '^[[:space:]]*Banner[[:space:]]+\S+' /etc/ssh/sshd_config ) && echo "PASS" || echo "FAIL"

echo -e "\n[125] Ciphers fortes"
(grep -Eq '^[[:space:]]*Ciphers[[:space:]]+.*(chacha20|aes256).*' /etc/ssh/sshd_config) && echo "PASS" || echo "FAIL"

echo -e "\n[126] MACs fortes"
(grep -Eq '^[[:space:]]*MACs[[:space:]]+.*(hmac-sha2|umac).*' /etc/ssh/sshd_config) && echo "PASS" || echo "FAIL"

echo -e "\n[127] KexAlgorithms fortes"
(grep -Eq '^[[:space:]]*KexAlgorithms[[:space:]]+.*(curve25519|diffie-hellman-group-exchange-sha256).*' /etc/ssh/sshd_config) && echo "PASS" || echo "FAIL"

echo -e "\n[128] Preferência moderna - double check"
(grep -Eq '^[[:space:]]*(Ciphers|KexAlgorithms)[[:space:]]+.*(chacha20|curve25519).*' /etc/ssh/sshd_config) && echo "PASS" || echo "FAIL"

echo -e "\n[129] ForceCommand/Chroot"
(grep -Eq '^[[:space:]]*(ForceCommand|ChrootDirectory)[[:space:]]+' /etc/ssh/sshd_config) && echo "PASS" || echo "FAIL"

echo -e "\n[130] pwquality habilitado"
grep -Eq 'pam_pwquality\.so' /etc/pam.d/*auth && echo "PASS" || echo "FAIL"

echo -e "\n[131] Verificar parâmetros do pam_pwquality"
( grep -Eq 'pam_pwquality\.so' /etc/pam.d/common-password 2>/dev/null && grep -Psiq '^\s*minlen\s*=\s*(1[4-9]|[2-9][0-9]+)\b' /etc/security/pwquality.conf /etc/security/pwquality.conf.d/*.conf 2>/dev/null && grep -Psiq '^\s*minclass\s*=\s*[4-9]\b' /etc/security/pwquality.conf /etc/security/pwquality.conf.d/*.conf 2>/dev/null ) && echo "PASS" || echo "FAIL"

echo -e "\n[132] pam_faillock habilitado"
(grep -Eq 'pam_faillock\.so' /etc/pam.d/common-auth /etc/pam.d/common-account 2>/dev/null) && echo "PASS" || echo "FAIL"

echo -e "\n[133] pam_tally2 não deve existir"
! grep -Eq 'pam_tally2\.so' /etc/pam.d/*auth && echo "PASS" || echo "FAIL"

echo -e "\n[134] pam_pwhistory habilitado"
(grep -Eq 'pam_pwhistory\.so' /etc/pam.d/common-password 2>/dev/null) && echo "PASS" || echo "FAIL"

echo -e "\n[135] minlen ≥ 14"
grep -Psiq '^\s*minlen\s*=\s*(1[4-9]|[2-9][0-9]+)' /etc/security/pwquality.conf* && echo "PASS" || echo "FAIL"

echo -e "\n[136] minclass ≥ 4"
grep -Psiq '^\s*minclass\s*=\s*[4-9]' /etc/security/pwquality.conf* && echo "PASS" || echo "FAIL"

echo -e "\n[137] maxrepeat & maxsequence = 3"
grep -Psiq '^\s*maxrepeat\s*=\s*3\b'   /etc/security/pwquality.conf* && grep -Psiq '^\s*maxsequence\s*=\s*3\b' /etc/security/pwquality.conf* && echo "PASS" || echo "FAIL"

echo -e "\n[138] dictcheck != 0"
! grep -Psiq '^\s*dictcheck\s*=\s*0\b' /etc/security/pwquality.conf* && echo "PASS" || echo "FAIL"

echo -e "\n[139] Hashing sha512/yescrypt"
grep -Eq 'pam_unix\.so.*(sha512|yescrypt)' /etc/pam.d/*auth && echo "PASS" || echo "FAIL"

echo -e "\n[140] pwhistory remember ≥ 5"
(grep -Eq 'pam_pwhistory\.so.*remember=([5-9]|[1-9][0-9]+)' /etc/pam.d/common-password 2>/dev/null) && echo "PASS" || echo "FAIL"

echo -e "\n[141] deny maior igual a 5 (faillock)"
grep -Pi '^\s*deny\s*=\s*([5-9]|[1-9][0-9]+)' /etc/security/faillock.conf && echo "PASS" || echo "FAIL"

echo -e "\n[142] unlock_time maior igual a 900"
grep -Pi '^\s*unlock_time\s*=\s*(9[0-9]{2}|[1-9][0-9]{3,})\b' /etc/security/faillock.conf && echo "PASS" || echo "FAIL"

echo -e "\n[143] PASS_MAX_DAYS ≤ 365"
val=$(awk '$1=="PASS_MAX_DAYS"{print $2; exit}' /etc/login.defs); [[ "$val" =~ ^[0-9]+$ ]] && [[ "$val" -le 365 ]] && echo "PASS" || echo "FAIL"

echo -e "\n[144] PASS_MIN_DAYS maior igual a 1"
grep -Eq '^\s*PASS_MIN_DAYS\s+[1-9][0-9]*' /etc/login.defs && echo "PASS" || echo "FAIL"

echo -e "\n[145] PASS_WARN_AGE maior igual a 7"
grep -Eq '^\s*PASS_WARN_AGE\s+([7-9]|[1-9][0-9]+)' /etc/login.defs && echo "PASS" || echo "FAIL"

echo -e "\n[146] inactive maior igual a 30 (para contas válidas)"
awk -F: '$2~/^\$/ && ($7=="" || $7<30){exit 1}' /etc/shadow && echo "PASS" || echo "FAIL"

echo -e "\n[147] campo 3 diferente 0"
awk -F: '$2~/^\$/{if($3==""||$3==0) exit 1} END{exit 0}' /etc/shadow && echo "PASS" || echo "FAIL"

echo -e "\n[148] Root é o único UID 0"
awk -F: '($3==0 && $1!="root"){exit 1}' /etc/passwd && echo "PASS" || echo "FAIL"

echo -e "\n[149] Root é o único GID 0"
[ "$(awk -F: '/^root:/ {print $4}' /etc/passwd)" = "0" ] && echo "PASS" || echo "FAIL"

echo -e "\n[150] Contas de sistema com shell interativo"
awk -F: '($3<1000 && $1!="root" && $7 ~ /(bash|sh|zsh)$/){exit 1}' /etc/passwd && echo "PASS" || echo "FAIL"

echo -e "\n[151] /sbin/nologin presente em /etc/shells"
grep -qE '^(\/usr)?\/sbin\/nologin$' /etc/shells && echo "PASS" || echo "FAIL"

echo -e "\n[152] PATH do root configurado"
(grep -Rqs 'PATH=.*\/usr/local/sbin.*\/usr/sbin.*\/sbin' /root/.profile /root/.bashrc /etc/profile /etc/profile.d 2>/dev/null) && echo "PASS" || echo "FAIL"

echo -e "\n[153] umask 027"
grep -Rqs 'umask 027' /etc/profile /etc/bash.bashrc /etc/profile.d 2>/dev/null && echo "PASS" || echo "FAIL"

echo -e "\n[154] TMOUT 900"
grep -Rqs 'TMOUT=900' /etc/profile /etc/bash.bashrc /etc/profile.d 2>/dev/null && echo "PASS" || echo "FAIL"

echo -e "\n[155] Ausência de regras amplas sudo"
grep -RqsE '^%.*ALL=\(ALL\)' /etc/sudoers /etc/sudoers.d 2>/dev/null && echo "FAIL" || echo "PASS"

echo -e "\n[156] sudo usa pty"
grep -Rqs 'use_pty' /etc/sudoers /etc/sudoers.d && echo "PASS" || echo "FAIL"

echo -e "\n[157] sudo logfile"
grep -Rqs 'logfile=' /etc/sudoers /etc/sudoers.d && echo "PASS" || echo "FAIL"

echo -e "\n[158] !authenticate ausente"
grep -Rqs '!authenticate' /etc/sudoers /etc/sudoers.d && echo "FAIL" || echo "PASS"

echo -e "\n[159] timestamp_timeout=5"
grep -Rqs 'timestamp_timeout=5' /etc/sudoers /etc/sudoers.d && echo "PASS" || echo "FAIL"

echo -e "\n[160] su restrito a grupo autorizado"
grep -Eq 'pam_wheel\.so.*group=(sudo|wheel)' /etc/pam.d/su && echo "PASS" || echo "FAIL"

echo -e "\n[161] Stack de logs racionalizado"
( systemctl is-active rsyslog &>/dev/null || systemctl is-active systemd-journald &>/dev/null ) && echo "PASS" || echo "FAIL"

echo -e "\n[162] Journald configurado persistente"
grep -q '^Storage=persistent' /etc/systemd/journald.conf && echo "PASS" || echo "FAIL"

echo -e "\n[163] Rsyslog instalado e ativo"
( pkg_installed rsyslog && systemctl is-active rsyslog &>/dev/null ) && echo "PASS" || echo "FAIL"

echo -e "\n[164] Logrotate para rsyslog"
( grep -Eq 'rsyslog' /etc/logrotate.d/* 2>/dev/null ) && echo "PASS" || echo "FAIL"

echo -e "\n[165] auditd instalado e rodando"
( ( pkg_installed audit || pkg_installed auditd ) && systemctl is-active auditd &>/dev/null ) && echo "PASS" || echo "FAIL"

echo -e "\n[166] Auditoria antes do auditd"
grep -q 'audit=1' /proc/cmdline && echo "PASS" || echo "FAIL"

echo -e "\n[167] Tamanho de armazenamento de audit log"
( grep -Eq '^\s*max_log_file\s*=\s*[1-9]' /etc/audit/auditd.conf ) && echo "PASS" || echo "FAIL"

echo -e "\n[168] Logs de auditoria não excluídos automaticamente"
( grep -Eq '^\s*max_log_file_action\s*=\s*(keep_logs|rotate)' /etc/audit/auditd.conf ) && echo "PASS" || echo "FAIL"

echo -e "\n[169] Auditoria de alterações em data/hora"
( auditctl -l 2>/dev/null | grep -Eq 'adjtimex|settimeofday|clock_settime' ) && echo "PASS" || echo "FAIL"

echo -e "\n[170] Auditoria de alterações em contas/grupos"
( auditctl -l 2>/dev/null | grep -Eq '/etc/(passwd|shadow|group|gshadow)' ) && echo "PASS" || echo "FAIL"

echo -e "\n[171] Auditoria de alterações no ambiente de rede"
( auditctl -l 2>/dev/null | grep -Eq 'sethostname|setdomainname|/etc/hosts|/etc/hostname' ) && echo "PASS" || echo "FAIL"

echo -e "\n[173] Auditoria de login/logout"
( auditctl -l 2>/dev/null | grep -Eq '/var/log/faillog|/var/log/lastlog|/var/run/utmp' ) && echo "PASS" || echo "FAIL"

echo -e "\n[174] Auditoria de permissões DAC"
( auditctl -l 2>/dev/null | grep -Eq 'chmod|chown|fchmod|fchown' ) && echo "PASS" || echo "FAIL"

echo -e "\n[175] Auditoria de acessos não autorizados"
( auditctl -l 2>/dev/null | grep -Eq 'EACCES|EPERM' ) && echo "PASS" || echo "FAIL"

echo -e "\n[176] Auditoria de comandos privilegiados"
( find / -xdev -perm -4000 -type f 2>/dev/null | while read -r f; do auditctl -l 2>/dev/null | grep -q "$f" || exit 1; done ) && echo "PASS" || echo "FAIL"

echo -e "\n[177] Auditoria de mount/unmount"
( auditctl -l 2>/dev/null | grep -Eq 'mount|umount' ) && echo "PASS" || echo "FAIL"

echo -e "\n[178] Auditoria de deleção de arquivos"
( auditctl -l 2>/dev/null | grep -Eq 'unlink|rename|rmdir|unlinkat|renameat' ) && echo "PASS" || echo "FAIL"

echo -e "\n[179] Auditoria de kernel modules"
( auditctl -l 2>/dev/null | grep -Eq 'init_module|finit_module|delete_module' ) && echo "PASS" || echo "FAIL"

echo -e "\n[180] Auditoria de sudoers/logs de sudo"
( auditctl -l 2>/dev/null | grep -Eq '/etc/sudoers|/etc/sudoers.d' ) && echo "PASS" || echo "FAIL"

echo -e "\n[181] Configuração de auditoria imutável"
( auditctl -s 2>/dev/null | grep -Eq '^[[:space:]]*enabled[[:space:]]+2\b' ) && echo "PASS" || echo "FAIL"

echo -e "\n[182] AIDE instalado e inicializado"
( pkg_installed aide && [ -f /var/lib/aide/aide.db.gz ] ) && echo "PASS" || echo "FAIL"

echo -e "\n[183] Verificação de integridade agendada"
( grep -Ersq 'aide(\.wrapper)? .*(--check|--update|\$AIDEARGS)' /etc/cron.* /etc/crontab /var/spool/cron 2>/dev/null || systemctl list-timers --all 2>/dev/null | grep -qi aime ) && echo "PASS" || echo "FAIL"

echo -e "\n[184] Proteção dos binários de auditoria"
( for b in auditctl aureport ausearch autrace auditd augenrules; do p="$(command -v "$b")" || exit 1; stat -Lc "%U %G" "$p" | awk '{if($1!="root" || $2!="root") exit 1}' || exit 1; done ) && echo "PASS" || echo "FAIL"

echo -e "\n[185] Verificar permissões de /etc/passwd"
( [ -f /etc/passwd ] && stat -Lc "%a %u %g" /etc/passwd | grep -Eq '^64[0-9] 0 0$' ) && echo "PASS" || echo "FAIL"

echo -e "\n[186] Verificar permissões de /etc/passwd-"
( [ -f /etc/passwd- ] && stat -Lc "%a %u %g" /etc/passwd- | grep -Eq '^64[0-9] 0 0$' ) && echo "PASS" || echo "FAIL"

echo -e "\n[187] Verificar permissões de /etc/shadow"
( [ -f /etc/shadow ] && stat -Lc "%a %u %g" /etc/shadow | grep -Eq '^0+ 0 0$' ) && echo "PASS" || echo "FAIL"

echo -e "\n[188] Verificar permissões de /etc/shadow-"
( [ -f /etc/shadow- ] && stat -Lc "%a %u %g" /etc/shadow- | grep -Eq '^0+ 0 0$' ) && echo "PASS" || echo "FAIL"

echo -e "\n[189] Verificar permissões de /etc/gshadow-"
( [ -f /etc/gshadow- ] && stat -Lc "%a %u %g" /etc/gshadow- | grep -Eq '^(600|60[0-9]|[0-5][0-9]{2}) 0 0$' ) && echo "PASS" || echo "FAIL"

echo -e "\n[190] Verificar permissões de /etc/gshadow"
( [ -f /etc/gshadow ] && stat -Lc "%a %u %g" /etc/gshadow | grep -Eq '^(600|60[0-9]|[0-5][0-9]{2}) 0 0$' ) && echo "PASS" || echo "FAIL"

echo -e "\n[191] Verificar permissões de /etc/group"
( [ -f /etc/group ] && stat -Lc "%a %u %g" /etc/group | grep -Eq '^64[0-9] 0 0$' ) && echo "PASS" || echo "FAIL"

echo -e "\n[192] Verificar permissões de /etc/group-"
( [ -f /etc/group- ] && stat -Lc "%a %u %g" /etc/group- | grep -Eq '^64[0-9] 0 0$' ) && echo "PASS" || echo "FAIL"

echo -e "\n[193] Verificar se contas usam shell nologin"
( awk -F: '$7 ~ /(\/usr)?\/sbin\/nologin$/ {found=1} END{exit !found}' /etc/passwd ) && echo "PASS" || echo "FAIL"

echo -e "\n[194] Verificar permissões de /etc/security/opasswd"
( [ -f /etc/security/opasswd ] && stat -Lc "%a %u %g" /etc/security/opasswd | grep -Eq '^600 0 0$' ) && echo "PASS" || echo "FAIL"

echo -e "\n[195] Verificar existência de arquivos órfãos (UID/GID sem dono)"
( find / -xdev \( -nouser -o -nogroup \) 2>/dev/null | grep -q . ) && echo "FAIL" || echo "PASS"

echo -e "\n[196] Verificar world-writable fora de áreas permitidas"
( find / -xdev \( -type f -o -type d \) -not -path "/tmp/*" -not -path "/var/tmp/*" -not -path "/dev/shm/*" -perm -0002 2>/dev/null | grep -q . ) && echo "FAIL" || echo "PASS"

echo -e "\n[197] Verificar arquivos/diretórios sem owner ou group"
( find / -xdev \( -nouser -o -nogroup \) 2>/dev/null | grep -q . ) && echo "FAIL" || echo "PASS"

echo -e "\n[198] Verificar binários SUID/SGID indevidos"
( find / -xdev \( -perm -4000 -o -perm -2000 \) 2>/dev/null | grep -Ev '^(/usr/bin/sudo|/usr/bin/su|/bin/su|/usr/bin/passwd|/usr/bin/chage|/usr/bin/chsh|/usr/bin/chfn|/usr/bin/newgrp|/usr/bin/gpasswd|/usr/sbin/unix_chkpwd|/usr/sbin/pam_timestamp_check|/usr/bin/mount|/usr/bin/umount|/usr/bin/fusermount|/usr/bin/pkexec|/usr/bin/crontab|/usr/bin/ssh-agent|/usr/bin/ksu|/usr/libexec/openssh/ssh-keysign|/usr/bin/ping|/usr/bin/ping6|/usr/bin/traceroute|/usr/bin/traceroute6)$' | grep -q . ) && echo "FAIL" || echo "PASS"

echo -e "\n[199] Verificar se usuários possuem diretório home válido)"
( awk -F: '$3>=1000 && $1!="nobody"{print $6}' /etc/passwd | while read -r h; do [ -d "$h" ] || exit 1; done ) && echo "PASS" || echo "FAIL"

echo -e "\n[200] Verificar ownership das homes dos usuários"
( awk -F: '$3>=1000 && $1!="nobody"{print $1,$6}' /etc/passwd | while read -r u h; do [ -d "$h" ] && [ "$(stat -Lc %U "$h")" = "$u" ] || exit 1; done ) && echo "PASS" || echo "FAIL"

echo -e "\n[201] Verificar permissões das homes (<=750)"
( awk -F: '$3>=1000 && $1!="nobody"{print $6}' /etc/passwd | while read -r h; do [ -d "$h" ] && [ "$(stat -Lc %a "$h")" -le 750 ] || exit 1; done ) && echo "PASS" || echo "FAIL"

echo -e "\n[202] Verificar dotfiles inseguros nas homes"
( while read -r h; do [ -d "$h" ] || continue; find "$h" -maxdepth 1 -type f -name ".*" -perm /022 2>/dev/null; done < <(awk -F: '$3>=1000 && $1!="nobody"{print $6}' /etc/passwd) | grep -q . ) && echo "FAIL" || echo "PASS"

echo -e "\n[203] Verificar arquivos .forward/.netrc/.rhosts nas homes"
( while read -r h; do [ -d "$h" ] || continue; for f in "$h/.forward" "$h/.netrc" "$h/.rhosts"; do [ -e "$f" ] && echo "$f"; done; done < <(awk -F: '$3>=1000 && $1!="nobody"{print $6}' /etc/passwd) | grep -q . ) && echo "FAIL" || echo "PASS"
