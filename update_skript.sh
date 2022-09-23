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
        status_code=$1
    fi

    if [ -z "$2" ]                           # Is parameter #1 zero length?
    then
        status_text=$DEFAULT_STATUS_TEXT
    else
        status_text=$2
    fi

    tee /var/www/apps/svi_web/status.json << END
{
    "status_code":$status_code,
    "text":$status_text
}
END
}

archiv_downloaden(){
    if [ -z "$1" ]
    then
        # TODO: aktuellstes Archiv downloaden hinzufügen
    else 
        # TODO: Archiv für Release Version $1 downloaden hinzufügen
    fi
}



case "$1" in
    online) archiv_downloaden "$2" ;;
    offline) archiv_von_stick_kopieren "$2" ;;
    *) echo "Error: Falscher Parameter $1 (für $0)"; exit 1 ;;
esac

# TODO: Archiv entpacken hinzufügen
# TODO: Version prüfen hinzufügen
# TODO: Backup erstellen hinzufügen
# TODO: entpackte Archiv Daten in Projektordner kopieren
# TODO: Apache2 Dienst neustarten

status_datei_anpassen 200 "ok"
exit 0