# SMART VEHICLE INSPECTOR WEB - UPDATE TOOL
Smart Vehicle Inspector Web ist standardmäßig auf den SD-Karten der AHS Raspberry Box installiert. Um zukünftige Updates und Anpassungen zu installieren, wird dieses Update Tool verwendet.

## Überlegungen
- Frontend & Backend werden gemeinsam geupdatet
- Versionsvergleich notwendig
- Offline Update Möglichkeit:
  - Update Archiv über USB Stick einlesen
  - Update Archiv über Frontend übetragen
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
    - Module (z.B. Flask, Flas-Restful, wsgi)
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

> `get api/update/releases/current`

- Status Update Vorgang ausgeben

> `get api/update/status`

### Offline
- installiere Offline von Archiv 
  - benötigt Archiv

> `post api/update/install/offline`

- installiere Offline von Stick
  - benötigt Stick mit Archiv

> `get api/update/install/offline`

### Online
- neueste Versionsnummer ausgeben
  - optional Vorabversionen berücksichtigen

> `get api/update/releases/latest`\
> `get api/update/releases/latest?prerelease=true`

- alle Versionsnummern ausgeben
  - optional Vorabversionen berücksichtigen

> `get api/update/releases/all`\
> `get api/update/releases/all?prerelease=true`

- downloaden und installieren der Version
  - benötigt Versionsnummer

> `get api/update/install/online?release=<RELEASE ID>`

## Skript
- Status ändern zu **aktiv**
- je nach Installationsmodus:
  - Online:
    - prüfen ob [Version] abweichend zu Installation
      - Ja: [Version] herunterladen
      - Nein: 
        - Status ändern zu **bereits installiert**
        - Skript beenden
  - Offline von Stick:
    - prüfen ob Archiv vorhanden
      - Ja: [Archiv] nach lokal kopieren
      - Nein: 
        - Status ändern zu **kein Update gefunden**
        - Skript beenden
  - Offline von Archiv:
    - *nichts weiter zu tun*
- [Archiv] entpacken
- prüfen ob [Version] abweichend zu Installation
  - Nein: 
    - Status ändern zu **bereits installiert**
    - Skript beenden
- Backup (Kopie) von gesamten Projekt (svi_web) erstellen
- entpackte Archiv Daten in Projektordner kopieren
- Apache2 Dienst neustarten
- Status ändern zu **ok**