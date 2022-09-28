#!/bin/bash

# Parameter 1 für Status Code (200)
# Parameter 2 für Status Text ("ok")
status_datei_anpassen(){
    DEFAULT_STATUS_CODE=200
    DEFAULT_STATUS_TEXT="ok"

    if [ -z "$1" ]                           # Is parameter #1 zero length?
    then
        status_code=$DEFAULT_STATUS_CODE
    else
        status_code="$1"
    fi

    if [ -z "$2" ]                           # Is parameter #1 zero length?
    then
        status_text=$DEFAULT_STATUS_TEXT
    else
        status_text="$2"
    fi

    tee /var/www/apps/svi_web/status.json << END
{
    "status_code":$status_code,
    "text":"$status_text"
}
END
}

archiv_downloaden(){
    if [ -z "$1" ]
    then
        # TODO: aktuellstes Archiv downloaden hinzufügen
        :
    else
        # TODO: Archiv für Release Version $1 downloaden hinzufügen
        :
    fi
}

archiv_von_stick_kopieren(){
    usb_devices=($(ls  /dev/sd* | grep '[0-9]'))

    for usb_device in $(echo ${usb_devices[@]}); do
        # USB Gerät mounten
        mount $usb_device /media$usb_device
        usb_device_mount=/media$usb_device
        # nach Update Datei suchen
        update_file=$(find $usb_device_mount -name 'smart_vehicle_inspector_web*.zip')
        echo $archiv_file
        if [ -z "$update_file" ]; then
            umount $usb_device
        else
            # Datei kopieren
            mkdir -p /var/www/apps/temp
            cp -u $update_file /var/www/apps/temp
            archiv_file=/var/www/apps/temp/$(basename $update_file)
            umount $usb_device
            break
        fi
    done
}


case "$1" in
    online) archiv_downloaden "$2" ;;
    offline) if [ -z "$2" ] ; then archiv_von_stick_kopieren ; else archiv_file="$2" ; fi ;;
    *) echo "Error: Falscher Parameter $1 (für $0)"; exit 1 ;;
esac

if [ -z "$archiv_file" ] ; then
    # Error: Kein Update Archiv vorhanden
    status_datei_anpassen 400 "Kein Update Archiv vorhanden"
    exit -1
fi

# Archiv entpacken
unzip -ud /var/www/apps/temp $archiv_file

# Versionen prüfen
echo "installierte Version":
installierte_version= python -c "import sys, json; version_file = open(sys.argv[1]); print(json.load(version_file)['tag_name']); version_file.close();" "/var/www/apps/svi_web/version.json"
echo "neue Version":
neue_version= python -c "import sys, json; version_file = open(sys.argv[1]); print(json.load(version_file)['tag_name']); version_file.close();" "/var/www/apps/temp/$(basename $archiv_file .zip)/version.json"

if [ $installierte_version -ne $neue_version ]; then
    # Backup erstellen
    timestamp=$(date +%Y%m%d_%H%M%S)
    cp -r /var/www/apps/svi_web /var/www/apps/temp/svi_web_$timestamp.bak

    # entpackte Archiv Daten in Projektordner kopieren
    cp -ru /var/www/apps/temp/$(basename $archiv_file .zip)/. /var/www/apps/svi_web

    # Erfolgreich abgeschlossen
    status_datei_anpassen 200 "ok"

    # Apache2 Dienst neustarten
    systemctl restart apache2

    exit 0
else
    # Error: Versionen sind gleich => Fehlermeldung ausgeben
    status_datei_anpassen 400 "Version $neue_version bereits installiert"
    exit -1
fi
