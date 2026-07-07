#!/usr/bin/env bash
# RyzenAdj system diagnostic - run as root: sudo ./examples/diagnose.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RYZENADJ="${ROOT}/build/ryzenadj"

echo "=== RyzenAdj diagnostic ==="
echo "Date: $(date)"
echo

echo "--- CPU ---"
lscpu | grep -E 'Model name|Vendor|CPU\(s\)|Family|Model:' || true
echo

echo "--- Permissions ---"
id
echo "root required: ryzen_smu sysfs writes and /dev/mem are restricted to root"
echo

echo "--- ryzen_smu kernel module ---"
if [[ -d /sys/kernel/ryzen_smu_drv ]]; then
    for f in drv_version version codename mp1_if_version pm_table_version pm_table_size; do
        path="/sys/kernel/ryzen_smu_drv/$f"
        if [[ -e "$path" ]]; then
            if [[ "$f" == pm_table_version ]]; then
                printf "%s: 0x%x\n" "$f" "$(od -An -tx4 -N4 "$path" | tr -d ' ')"
            elif [[ "$f" == pm_table_size ]]; then
                printf "%s: %u bytes\n" "$f" "$(od -An -tu4 -N4 "$path" | tr -d ' ')"
            else
                printf "%s: %s\n" "$f" "$(cat "$path")"
            fi
        else
            echo "$f: (missing - update ryzen_smu for PM table monitoring)"
        fi
    done
    ls -la /sys/kernel/ryzen_smu_drv/smn /sys/kernel/ryzen_smu_drv/pm_table 2>/dev/null || true
else
    echo "ryzen_smu_drv sysfs not found"
fi
echo

echo "--- /dev/mem ---"
ls -la /dev/mem 2>/dev/null || echo "/dev/mem not available"
echo

if [[ ! -x "$RYZENADJ" ]]; then
    echo "Building ryzenadj..."
    (cd "$ROOT/build" && cmake .. -DCMAKE_BUILD_TYPE=Release && make -j"$(nproc)")
fi

echo "--- ryzenadj --info ---"
"$RYZENADJ" --info || true
echo

echo "--- ryzenadj --dump-table (first 20 rows) ---"
"$RYZENADJ" --dump-table 2>/dev/null | head -25 || true
echo

echo "--- New monitoring (branch) ---"
echo "  GFX POWER, FreqEff, C0/CC1/C6% per core (Strix Point / desktop)"
echo "  --oc-clk-per-core for Renoir/Cezanne/Rembrandt"
echo

echo "--- Hidden presets ---"
echo "power-saving / max-performance map to ACPI ALIB CCLK boost setpoint:"
echo "  Strix Point: ALIB 0x12 (power-saving) / 0x11 (max-performance)"
echo "  Raven/Picasso: ALIB 0x19 / 0x18"
echo

echo "=== Done ==="