#!/bin/bash
#
# Offline installer for the Smart Vehicle Inspector web app on the Pi.
# Usage: svi_update.sh offline [zip-path]
# With no zip path, search removable USB disks for smart_vehicle_inspector_web*.zip.
#
# The archive root contains version.json plus the same api/ and frontend/
# directories that live under /var/www/apps/svi_web.

set -u

APP_ROOT=/var/www/apps/svi_web
WORK_ROOT=/var/www/apps/temp/update
BACKUP_ROOT=/var/www/apps/temp/backup
STATUS_FILE=$APP_ROOT/status.json
VERSION_FILE=$APP_ROOT/version.json
SELF=/usr/local/sbin/svi_update.sh

write_status() {
    local code=$1
    local text=$2
    mkdir -p "$(dirname "$STATUS_FILE")"
    python3 -c 'import json,sys; json.dump({"status_code": int(sys.argv[1]), "text": sys.argv[2]}, open(sys.argv[3], "w", encoding="utf-8"), indent=4, ensure_ascii=False); open(sys.argv[3], "a", encoding="utf-8").write("\n")' \
        "$code" "$text" "$STATUS_FILE"
    chmod 644 "$STATUS_FILE"
}

read_version() {
    python3 -c 'import json,sys; print(json.load(open(sys.argv[1], encoding="utf-8"))["version"])' "$1"
}

# Partitions inherit TRAN from the parent disk. lsblk leaves that column
# empty on the partition line, and a plain read then shifts the fields.
copy_from_usb() {
    local name mountpoint found mp mounted
    while IFS=$'\t' read -r name mountpoint; do
        [ -n "$name" ] || continue
        mounted=0
        if [ -n "$mountpoint" ]; then
            mp=$mountpoint
        else
            mp=$(mktemp -d /mnt/svi-update.XXXXXX)
            if ! mount -o ro "/dev/$name" "$mp"; then
                rmdir "$mp" || true
                continue
            fi
            mounted=1
        fi
        found=$(find "$mp" -maxdepth 4 -type f -name 'smart_vehicle_inspector_web*.zip' | head -n 1)
        if [ -n "$found" ]; then
            mkdir -p "$WORK_ROOT"
            cp -f "$found" "$WORK_ROOT/"
            archiv_file=$WORK_ROOT/$(basename "$found")
        fi
        if [ "$mounted" = 1 ]; then
            umount "$mp" || true
            rmdir "$mp" || true
        fi
        [ -n "${archiv_file:-}" ] && return 0
    done < <(python3 - <<'PY'
import json, subprocess
data = json.loads(subprocess.check_output(
    ["lsblk", "-J", "-o", "NAME,TRAN,RM,TYPE,MOUNTPOINT"], text=True))
for disk in data.get("blockdevices", []):
    nodes = [disk, *(disk.get("children") or [])]
    for node in nodes:
        if node.get("type") != "part":
            continue
        tran = node.get("tran") or disk.get("tran") or ""
        removable = str(node.get("rm") if node.get("rm") is not None else disk.get("rm") or "0")
        if tran != "usb" and removable != "1":
            continue
        print(f"{node['name']}\t{node.get('mountpoint') or ''}")
PY
)
    return 1
}

archiv_file=
case "${1:-}" in
    offline)
        if [ -n "${2:-}" ]; then
            archiv_file=$2
        else
            copy_from_usb || true
        fi
        ;;
    *)
        echo "Error: Falscher Parameter ${1:-} (für $0)" >&2
        exit 1
        ;;
esac

if [ -z "${archiv_file:-}" ]; then
    write_status 400 "Kein Update Archiv vorhanden"
    exit 1
fi

case "$archiv_file" in
    "$WORK_ROOT"/*.zip) ;;
    *)
        write_status 400 "Ungültiger Archivpfad"
        exit 1
        ;;
esac

if [ ! -f "$archiv_file" ]; then
    write_status 400 "Kein Update Archiv vorhanden"
    exit 1
fi

rm -rf "$WORK_ROOT/extracted"
mkdir -p "$WORK_ROOT/extracted"
if ! unzip -q "$archiv_file" -d "$WORK_ROOT/extracted"; then
    write_status 400 "Archiv konnte nicht entpackt werden"
    exit 1
fi

version_file=$(find "$WORK_ROOT/extracted" -name version.json -printf '%d %p\n' | sort -n | head -n 1 | cut -d' ' -f2-)
if [ -z "$version_file" ] || [ ! -f "$version_file" ]; then
    write_status 400 "version.json fehlt im Archiv"
    exit 1
fi

src=$(dirname "$version_file")
if ! neue_version=$(read_version "$version_file"); then
    write_status 400 "version.json im Archiv ist ungültig"
    exit 1
fi

installierte_version=
if [ -f "$VERSION_FILE" ]; then
    installierte_version=$(read_version "$VERSION_FILE" 2>/dev/null || true)
fi

if [ -n "$installierte_version" ] && [ "$installierte_version" = "$neue_version" ]; then
    write_status 400 "Version $neue_version bereits installiert"
    exit 1
fi

if [ -d "$APP_ROOT" ]; then
    stamp=$(date +%Y%m%d_%H%M%S)
    mkdir -p "$BACKUP_ROOT/svi_web_$stamp"
    rsync -a --exclude '.venv/' --exclude '__pycache__/' "$APP_ROOT"/ "$BACKUP_ROOT/svi_web_$stamp"/
fi

exclude_args=()
preserve=(
    api/config/config.json
    api/pdf_config/pdf_config.json
    api/license/licenses
    frontend/assets/vehicle_class_profiles
)
for relative in "${preserve[@]}"; do
    if [ -e "$APP_ROOT/$relative" ]; then
        exclude_args+=(--exclude "$relative")
    fi
done

mkdir -p "$APP_ROOT"
rsync -rlptD --no-owner --no-group \
    --exclude '.venv/' \
    --exclude '__pycache__/' \
    "${exclude_args[@]}" \
    "$src"/ "$APP_ROOT"/

if [ -d "$APP_ROOT/frontend" ]; then
    chown -R pi:pi "$APP_ROOT/frontend"
fi
if [ -d "$APP_ROOT/api" ]; then
    chown -R www-data:www-data "$APP_ROOT/api"
fi
if [ -f "$VERSION_FILE" ]; then
    chown root:root "$VERSION_FILE"
    chmod 644 "$VERSION_FILE"
fi

if [ -f "$src/api/update/update_skript.sh" ]; then
    install -m 755 -o root -g root "$src/api/update/update_skript.sh" "$SELF"
fi

write_status 200 "ok"

# Leave the HTTP response time to reach the browser before Apache stops.
( sleep 3; /bin/systemctl restart apache2 ) >/dev/null 2>&1 &
exit 0
