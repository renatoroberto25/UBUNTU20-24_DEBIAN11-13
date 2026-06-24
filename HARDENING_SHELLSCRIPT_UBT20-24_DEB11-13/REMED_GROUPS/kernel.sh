#!/usr/bin/env bash
set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/lib.sh"

run_id() {
    local id="$1"

    case "$id" in
        001) block_module_item "$id" "cramfs" ;;
        002) block_module_item "$id" "squashfs" ;;
        003) block_module_item "$id" "udf" ;;
        004) block_module_item "$id" "hfs" ;;
        005) block_module_item "$id" "hfsplus" ;;
        006) block_module_item "$id" "jffs2" ;;
        007) block_module_item "$id" "freevxfs" ;;
        008) sem_auto "$id" "overlayfs depende de requisito de uso, containers e arquitetura" ;;
        009) block_module_item "$id" "usb_storage" ;;
        010) block_module_item "$id" "dccp" ;;
        011) sem_auto "$id" "SCTP depende de requisito de rede/aplicacao" ;;
        012) block_module_item "$id" "rds" ;;
        013) block_module_item "$id" "tipc" ;;
        014) set_sysctl_item "$id" "fs.suid_dumpable" "0" ;;
        015) set_sysctl_item "$id" "fs.suid_dumpable" "0" ;;
        016) sem_auto "$id" "NX/XD depende de suporte em hardware, firmware e kernel" ;;
        017) set_sysctl_item "$id" "kernel.randomize_va_space" "2" ;;
        018) set_sysctl_item "$id" "kernel.randomize_va_space" "2" ;;
        019) set_sysctl_item "$id" "kernel.perf_event_paranoid" "3" ;;
        020) set_sysctl_item "$id" "kernel.perf_event_paranoid" "3" ;;
        021) set_sysctl_item "$id" "kernel.dmesg_restrict" "1" ;;
        022) set_sysctl_item "$id" "fs.protected_symlinks" "1" ;;
        023) set_sysctl_item "$id" "fs.protected_symlinks" "1" ;;
        024) set_sysctl_item "$id" "fs.protected_hardlinks" "1" ;;
        *) sem_auto "$id" "item fora do grupo Kernel" ;;
    esac
}

if (( $# == 0 )); then
    set -- 001 002 003 004 005 006 007 009 010 012 013 014 015 017 018 019 020 021 022 023 024
fi

for id in "$@"; do
    run_id "$id"
done
