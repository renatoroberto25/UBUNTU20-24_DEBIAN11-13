#!/usr/bin/env bash
# break.sh — Degrada segurança da VM para demo de auditoria/remediação
# Requer root. Não mexe em partições, GRUB, NX, PAM, auditd, AIDE.

set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
  echo "ERRO: execute como root." >&2
  exit 1
fi

skip() { echo "[SKIP] $*"; }
info() { echo "[BREAK] $*"; }

###############################################################################
# MÓDULOS — remover blacklists e carregar
###############################################################################

MODULES="cramfs squashfs udf hfs hfsplus jffs2 freevxfs dccp sctp rds tipc usb_storage"

for mod in $MODULES; do
  # Remove qualquer regra de blacklist/install no /etc
  find /etc/modprobe.d/ -type f -exec sed -i "/\b${mod}\b/d" {} \; 2>/dev/null || true
  # Tenta carregar
  modprobe "$mod" 2>/dev/null && info "módulo $mod carregado" || skip "módulo $mod não disponível no kernel"
done

###############################################################################
# SYSCTL — valores inseguros
###############################################################################

info "aplicando sysctls inseguros"

declare -A SYSCTLS=(
  [kernel.randomize_va_space]=0
  [kernel.dmesg_restrict]=0
  [kernel.perf_event_paranoid]=0
  [fs.suid_dumpable]=1
  [fs.protected_symlinks]=0
  [fs.protected_hardlinks]=0
  [net.ipv4.ip_forward]=1
  [net.ipv6.conf.all.forwarding]=1
  [net.ipv4.conf.all.send_redirects]=1
  [net.ipv4.conf.all.accept_source_route]=1
  [net.ipv4.conf.all.accept_redirects]=1
  [net.ipv4.conf.all.secure_redirects]=1
  [net.ipv4.conf.all.rp_filter]=0
  [net.ipv4.icmp_echo_ignore_broadcasts]=0
  [net.ipv4.icmp_ignore_bogus_error_responses]=0
  [net.ipv4.tcp_syncookies]=0
  [net.ipv6.conf.all.disable_ipv6]=0
)

SYSCTL_CONF=/etc/sysctl.d/00-break-demo.conf
> "$SYSCTL_CONF"
for key in "${!SYSCTLS[@]}"; do
  echo "${key} = ${SYSCTLS[$key]}" >> "$SYSCTL_CONF"
done
sysctl -p "$SYSCTL_CONF" &>/dev/null

###############################################################################
# SSH — configurações inseguras
###############################################################################

info "degradando sshd_config"

SSH_DIRECTIVES="
X11Forwarding yes
PermitEmptyPasswords yes
MaxAuthTries 10
IgnoreRhosts no
HostbasedAuthentication yes
PermitUserEnvironment yes
AllowTcpForwarding yes
LoginGraceTime 600
Banner none
Ciphers aes128-cbc,3des-cbc,aes192-cbc,aes256-cbc
MACs hmac-md5,hmac-sha1,hmac-sha1-96
KexAlgorithms diffie-hellman-group1-sha1,diffie-hellman-group14-sha1
SyslogFacility DAEMON
UsePAM no
"

if [ -d /etc/ssh/sshd_config.d ]; then
  echo "$SSH_DIRECTIVES" > /etc/ssh/sshd_config.d/00-break-demo.conf
  info "sshd_config.d/00-break-demo.conf escrito"
else
  # Fallback para distros sem sshd_config.d (ex: Ubuntu 16.04)
  SSHD_MAIN=/etc/ssh/sshd_config
  cp -n "$SSHD_MAIN" "${SSHD_MAIN}.bak-break" 2>/dev/null || true
  # Remove diretivas existentes que vamos sobrescrever
  for key in X11Forwarding PermitEmptyPasswords MaxAuthTries IgnoreRhosts \
             HostbasedAuthentication PermitUserEnvironment AllowTcpForwarding \
             LoginGraceTime Banner Ciphers MACs KexAlgorithms SyslogFacility UsePAM; do
    sed -i "/^[[:space:]]*${key}[[:space:]]/Id" "$SSHD_MAIN"
  done
  echo "$SSH_DIRECTIVES" >> "$SSHD_MAIN"
  info "diretivas appended em $SSHD_MAIN (backup em ${SSHD_MAIN}.bak-break)"
fi

systemctl reload sshd 2>/dev/null || systemctl restart sshd 2>/dev/null || skip "sshd não encontrado/ativo"

###############################################################################
# TLS — permitir versões antigas
###############################################################################

OPENSSL_CNF=/etc/ssl/openssl.cnf

if [ -f "$OPENSSL_CNF" ]; then
  info "rebaixando MinProtocol TLS para TLSv1.0"
  # Remove qualquer MinProtocol existente e injeta TLSv1.0
  sed -i '/MinProtocol/d' "$OPENSSL_CNF"
  if grep -q '^\[system_default_sect\]' "$OPENSSL_CNF"; then
    sed -i '/^\[system_default_sect\]/a MinProtocol = TLSv1.0' "$OPENSSL_CNF"
  else
    printf '\n[system_default_sect]\nMinProtocol = TLSv1.0\n' >> "$OPENSSL_CNF"
  fi
else
  skip "openssl.cnf não encontrado"
fi

###############################################################################
# PERMISSÕES — arquivos sensíveis
###############################################################################

info "abrindo permissões de arquivos sensíveis"

chmod 777 /etc/passwd       2>/dev/null && info "chmod 777 /etc/passwd"        || skip "/etc/passwd"
chmod 777 /etc/shadow       2>/dev/null && info "chmod 777 /etc/shadow"        || skip "/etc/shadow"
chmod 777 /etc/group        2>/dev/null && info "chmod 777 /etc/group"         || skip "/etc/group"
chmod 777 /etc/gshadow      2>/dev/null && info "chmod 777 /etc/gshadow"       || skip "/etc/gshadow"
chmod 644 /etc/shadow-      2>/dev/null && info "chmod 644 /etc/shadow-"       || skip "/etc/shadow-"
chmod 644 /etc/gshadow-     2>/dev/null && info "chmod 644 /etc/gshadow-"      || skip "/etc/gshadow-"

# Dotfiles world-writable no home do vagrant
if [ -d /home/vagrant ]; then
  find /home/vagrant -maxdepth 1 -name ".*" -type f -exec chmod o+w {} \; 2>/dev/null
  info "dotfiles de /home/vagrant com o+w"
fi

###############################################################################
# SUDO — desabilitar autenticação e remover controles
###############################################################################

SUDOERS_DROP=/etc/sudoers.d/00-break-demo

info "degradando sudo"

cat > "$SUDOERS_DROP" <<'EOF'
Defaults !authenticate
Defaults !use_pty
EOF

chmod 440 "$SUDOERS_DROP"

###############################################################################
# SERVIÇOS INDESEJADOS — instalar e habilitar alguns se possível
###############################################################################

info "tentando instalar/habilitar serviços inseguros"

for pkg in avahi-daemon telnet snmpd; do
  if apt-get install -y --no-install-recommends "$pkg" &>/dev/null; then
    info "instalado: $pkg"
    systemctl enable "$pkg" 2>/dev/null || true
  else
    skip "não foi possível instalar $pkg"
  fi
done

###############################################################################
# ITENS NÃO APLICADOS
###############################################################################

skip "[16]  NX CPU bit — hardware, não aplicável"
skip "[25-34] Partições separadas — estrutural, não aplicável"
skip "[49-50] GRUB password/permissões — não aplicável"
skip "[130-142] PAM pwquality/faillock — default já sem hardening, não aplicável"
skip "[165-181] auditd/regras — skip se não instalado"
skip "[182-183] AIDE — skip se não instalado"
skip "[166] audit=1 cmdline — exige reboot, não aplicável"

echo ""
echo "=== break.sh concluído. Execute o audit.sh e confira os FAILs. ==="
