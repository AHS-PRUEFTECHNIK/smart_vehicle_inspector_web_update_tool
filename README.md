# SMART VEHICLE INSPECTOR WEB - UPDATE TOOL

Smart Vehicle Inspector Web ist auf dem Raspberry installiert. Dieses Update Tool tauscht daraus Frontend und API aus, ohne die SD-Karte neu zu beschreiben. Ein Zip-Archiv wird auf den Pi gebracht, mit der installierten Version verglichen und nach `/var/www/apps/svi_web` kopiert. State Config (`/var/www/apps/state_config_app`) gehört nicht dazu.

`update_skript.sh` in diesem Repository ist dieselbe Fassung wie `smart_vehicle_inspector_web_api/update/update_skript.sh`. Auf dem Pi heißt die Datei `/usr/local/sbin/svi_update.sh`, gehört `root:root` und hat den Modus `0755`. Die SVI-API startet sie mit `sudo`. Sie liegt absichtlich außerhalb von `/var/www`, weil `www-data` dieses Verzeichnis besitzt und die Datei sonst austauschen könnte.

`version.json` und `status.json` hier im Repository sind Beispiele. Die installierte Version steht auf dem Pi in `/var/www/apps/svi_web/version.json`.

## Überlegungen

### vorhanden

Läuft auf dem Pi.

- Frontend und Backend werden gemeinsam aus einem Archiv aktualisiert. Das Archiv darf auch nur den Teil enthalten, der sich geändert hat. Dateien, die nicht im Archiv liegen, bleiben stehen.
- Versionsvergleich. Gleiche Version wird nicht noch einmal installiert. Fehlt `version.json` auf dem Pi, gilt das als erste Installation. Verglichen wird der Text, zum Beispiel `0.0.2` oder `0.0.1+3`, nicht eine Zahl.
- Offline-Update:
  - Archiv über einen USB-Stick. Der Dateiname beginnt mit `smart_vehicle_inspector_web` und endet auf `.zip`. Die Partition übernimmt den USB-Eintrag vom Laufwerk. Ein bereits eingehängter Stick wird benutzt.
  - Archiv über das Frontend. `POST /api/update/install/offline` mit dem Feld `file`.
- Sicherung vor dem Kopieren:
  - Fahrzeugklassen-Profile unter `frontend/assets/vehicle_class_profiles` werden nicht überschrieben.
  - `api/config/config.json` und `api/pdf_config/pdf_config.json` werden nicht überschrieben.
  - Lizenzen unter `api/license/licenses` werden nicht überschrieben.
  - Die bisherige Installation wird ohne `.venv` nach `/var/www/apps/temp/backup/` kopiert.
- Inhalt eines Releases:
  - `version.json` an der Wurzel.
  - Gebautes Flutter-Web unter `frontend/` (Seiten, Schriften, Bilder). Profile, die schon auf dem Pi liegen, bleiben.
  - Python-Dateien unter `api/`.

### optional

Für den Betrieb nicht nötig.

- `api/update/update_skript.sh` im Archiv. Liegt es dort, ersetzt es `/usr/local/sbin/svi_update.sh`.

### Vorschlag

Im ersten Entwurf beschrieben, nicht gebaut.

- Online-Update. GitHub Releases erlauben nur eine begrenzte Zahl von Abrufen, deshalb blieb die Auslieferung offline.
  - Automatisch auf ein Update prüfen.
  - Das Archiv direkt auf den Raspberry herunterladen.
- Eine eigene Datei mit den benötigten Programmen und Modulen (Apache, Python, Flask, WSGI). Der erste Entwurf nannte Python 3.9. Der Pi 5 nutzt Python 3.13. Die virtuelle Umgebung `.venv` bleibt die vorhandene und gehört nicht ins Archiv.
- Pre-Releases bei einer Online-Abfrage mit ausgeben. Ohne die Online-API gibt es dafür keinen Schalter.

## API

Die HTTP-Aufrufe liegen im Backend `smart_vehicle_inspector_web_api`, nicht in diesem Repository.

### vorhanden

| Aufruf | Bedeutung |
| --- | --- |
| `GET /api/update/releases/current` | Installierte Version. |
| `GET /api/update/status` | Status des letzten Laufs. Ohne Statusdatei antwortet die API mit HTTP 400 und `Kein Update Archiv vorhanden`. |
| `GET /api/update/install/offline` | Offline vom Stick. Die Antwort wartet, bis das Skript fertig ist. HTTP 200 und der Text `ok` bedeuten, dass kopiert wurde. HTTP 400 trägt den Statustext, zum Beispiel `Version … bereits installiert`. |
| `POST /api/update/install/offline` | Offline vom hochgeladenen Archiv. |

```bash
curl -F "file=@smart_vehicle_inspector_web-0.0.2.zip" \
  http://<RASPBERRY>:5000/api/update/install/offline
```

### Vorschlag

Nicht gebaut.

- Backups auflisten: `GET /api/backup/all`
- Backup erstellen: `GET /api/backup/create`
- Backup wiederherstellen: `GET /api/backup/restore?backup=<NAME>`
- Backup entfernen: `GET /api/backup/clean?backup=<NAME>`
- Neueste Online-Version: `GET /api/update/releases/latest`
- Neueste Version inklusive Vorabversionen: `GET /api/update/releases/latest?prerelease=true`
- Alle Versionen: `GET /api/update/releases/all` und `GET /api/update/releases/all?prerelease=true`
- Eine Online-Version herunterladen und installieren: `GET /api/update/install/online?release=<RELEASE ID>`

## Skript

`update_skript.sh offline` sucht den Stick. `update_skript.sh offline <pfad>` nimmt das bereits hochgeladene Zip, und nur wenn es unter `/var/www/apps/temp/update` liegt.

1. Der Status bleibt unverändert, bis das Skript ein Ergebnis hat.
2. Das Archiv wird vom Stick oder aus dem übergebenen Pfad bestimmt.
3. Fehlt es, schreibt das Skript den Status `Kein Update Archiv vorhanden` und endet.
4. Das Archiv wird entpackt und die oberste `version.json` gelesen.
5. Ist die Version gleich der installierten, schreibt das Skript `Version … bereits installiert` und endet. Es wird nichts kopiert.
6. Die bisherigen `svi_web`-Dateien werden ohne `.venv` gesichert.
7. Der Archivinhalt wird nach `/var/www/apps/svi_web` kopiert. Konfiguration, PDF-Konfiguration, Lizenzen und Fahrzeugklassen-Profile bleiben, wenn sie schon da sind. `.venv` und `__pycache__` werden ignoriert.
8. `frontend` wird auf `pi:pi` gesetzt, `api` auf `www-data:www-data`.
9. Der Status wird `ok`.
10. Drei Sekunden später startet Apache neu, damit die HTTP-Antwort den Browser noch erreicht.

## Archiv erstellen

1. Den Ordner `releases` anlegen, falls er noch nicht existiert. Er steht in `.gitignore` und wird nicht mit eingecheckt.
2. Darin einen Ordner `smart_vehicle_inspector_web-<Version>` anlegen. Aus `0.0.1+2` wird zum Beispiel `smart_vehicle_inspector_web-0.0.1-2`. Der Dateiname des Zip muss mit `smart_vehicle_inspector_web` beginnen, sonst findet die Stick-Suche ihn nicht.
3. `version.json` an diese Version anpassen:

```json
{"version": "0.0.1+2"}
```

4. Die geänderten Dateien so hineinkopieren, dass die Ordner dem Webserver entsprechen. Für eine Änderung nur an `update_install_offline_resource.py`:

```text
smart_vehicle_inspector_web-0.0.1-2/
  version.json
  api/
    update/
      update_install_offline_resource.py
```

Ein komplettes Frontend ist der Inhalt von `build/web` unter `frontend/`. Ein komplettes Backend sind die Python-Dateien unter `api/`, ohne `.venv`.

5. Den Ordner packen. Unter Windows: Rechtsklick auf den Ordner, **Senden an**, **ZIP-komprimierter Ordner**. Oder:

```bash
zip -r smart_vehicle_inspector_web-0.0.1-2.zip smart_vehicle_inspector_web-0.0.1-2
```

## Notizen

- GitHub Releases erlauben nur eine begrenzte Zahl von Abrufen. Deshalb gibt es vorerst nur die Offline-Installation, ohne Liste der verfügbaren Versionen.
- Die Versionsdatei ist absichtlich nur `{"version": "..."}`.
- `version.json` und `status.json` in diesem Repository sind Muster, nicht der Stand auf einem bestimmten Pi.

## TODOS

### vorhanden

- Konfiguration und Profile beim Offline-Update nicht überschreiben.

### Vorschlag

- Offline-Installation in Python statt im Bash-Skript. Das Skript bleibt Bash, weil der Ablauf damit auf dem Pi ohne weitere Abhängigkeit läuft.
- Backup-API.
- Online-API.
