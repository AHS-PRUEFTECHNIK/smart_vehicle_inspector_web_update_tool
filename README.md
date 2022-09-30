# SMART VEHICLE INSPECTOR WEB - UPDATE TOOL
Smart Vehicle Inspector Web ist standardmäßig auf den SD-Karten der AHS Raspberry Box installiert. Um zukünftige Updates und Anpassungen zu installieren, wird dieses Update Tool verwendet.

## Überlegungen
- Frontend & Backend werden gemeinsam geupdatet
- Versionsvergleich notwendig
- Offline Update Möglichkeit:
  - Update Archiv über USB Stick einlesen
  - Update Archiv über Frontend übertragen
- optional Online Update Möglichkeit:
  - automatisch auf Update prüfen
  - Update Archiv direkt auf Raspberry herunterladen
- Sicherung vor Update von:
  - Profilen (Fahrzeugklassen Profil)
  - Konfigurationen (config.json, pdf_config.json)
  - bisherigen Front- & Backend Dateien
- Projekt Release enthält:
  - Versionsdatei
  - Update Skript
  - Datei mit Abhängigkeiten:
    - Programme & Programmversionen (z.B. Apache2, Python 3.9)
    - Module (z.B. Flask, Flask-Restful, wsgi)
  - Frontend Archiv
    - Versionsdatei
    - Flutter Web Projekt Release Dateien
    - Anhänge (Schriften, Bilder, Profile)
  - Backend Archiv
    - Versionsdatei
    - Python Dateien
- Pre-Releases optional berücksichtigen

## API
Für die Verwendung des Update Tools über eine Weboberfläche (Smart Vehicle Inspector Frontend), muss die API entsprechende Funktionen zur Verfügung stellen.

- installierte Versionsnummer ausgeben

`get api/update/releases/current`

- Status Update Vorgang ausgeben

`get api/update/status`

- Backups auflisten

`get api/backup/all`

- Backup erstellen

`get api/backup/create`

- Backup wiederherstellen

`get api/backup/restore?backup=<BACKUP NAME>`

- Backup entfernen

`get api/backup/clean?backup=<BACKUP NAME>`

### Offline
- installiere Offline von Archiv 
  - benötigt Archiv

`post api/update/install/offline`

> `curl -X POST -H "Content-Type: multipart/form-data" -F "file=@<ARCHIV DATEINAME>.zip" http://<RASPBERRY IP>:5000/api/update/install/offline>`

- installiere Offline von Stick
  - benötigt Stick mit Archiv

`get api/update/install/offline`

### Online
- neueste Versionsnummer ausgeben
  - optional Vorabversionen berücksichtigen

`get api/update/releases/latest`\
`get api/update/releases/latest?prerelease=true`

- alle Versionsnummern ausgeben
  - optional Vorabversionen berücksichtigen

`get api/update/releases/all`\
`get api/update/releases/all?prerelease=true`

- downloaden und installieren der Version
  - benötigt Versionsnummer

`get api/update/install/online?release=<RELEASE ID>`

## Skript
- Status ändern zu **aktiv**
- je nach Installationsmodus:
  - Online:
      - [Archiv] herunterladen
  - Offline von Stick:
    - prüfen ob Archiv vorhanden
      - Ja: [Archiv] nach lokal kopieren
  - Offline von Archiv:
    - [Archiv] setzen
- prüfen ob [Archiv] vorhanden
      - Nein: 
        - Status ändern zu **kein Update gefunden**
        - Skript beenden
- [Archiv] entpacken
- prüfen ob [Version] abweichend zu Installation
  - Nein: 
    - Status ändern zu **bereits installiert**
    - Skript beenden
- Backup (Kopie) von gesamten Projekt (svi_web) erstellen
- entpackte Archiv Daten in Projektordner kopieren
- Status ändern zu **ok**
- Apache2 Dienst neustarten

## Archiv erstellen
- Ordner releases erstellen (falls nicht vorhanden)
- Ordner erstellen **smart_vehicle_inspector_web-\<Versionsnumemr\>-<Buildnummer\>**
>  z.B.: für Version 0.0.1+2 -> smart_vehicle_inspector_web-0.0.1-2
- version.json an Version und Buildnummer anpassen (`{"version":"0.0.1+2"}`)
- angepasste Dateien kopieren
> **Achtung!** Ordnerstruktur muss Struktur auf Webserver reflektieren \
> z.B.: für Anpassung an update_install_offline_resource.py:\
> - smart_vehicle_inspector_web_0.0.1+2
>   - version.json
>   - api
>     - update
>       - update_install_offline_resource.py
- Rechts Klick auf Ordner -> Senden an -> ZIP-komprimierter Ordner

## Notizen
- Github Releases nur begrenzte Anzahl an Zugriffen erlaubt
  -> vorerst nur Offline Installation ohne Auflistung
- Versionsdatei vereinfacht

## TODOS
- Offline Installation über Python implementieren statt Bash-Skript
- Offline Installation Konfiguration und Profile nicht überschreiben
- Backup API implementieren
- Online API implementieren