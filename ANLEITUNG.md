# GymLate – Anleitung / Tutorial

## Was du brauchst

- **Node.js** (Version 18 oder neuer)  
  Download: https://nodejs.org → „LTS" wählen, installieren, fertig.

Prüfen ob es funktioniert hat (Terminal öffnen):
```
node --version
```
Sollte etwas wie `v20.x.x` ausgeben.

---

## Lokal starten (auf deinem Mac/PC)

**1. Terminal öffnen** und in den Projektordner wechseln:
```bash
cd ~/Documents/Dokumente/Programmieren/Gym\ Tracker
```

**2. Abhängigkeiten installieren** (nur einmal nötig):
```bash
npm install
```

**3. Server starten:**
```bash
npm start
```

Du siehst:
```
🏋️  GymLate läuft auf http://localhost:3000
📂 Datenbank: /…/data.db
```

**4. Browser öffnen:** http://localhost:3000

Der Server läuft solange das Terminal offen ist. Mit `Ctrl+C` stoppen.

> **Entwicklermodus** (Server startet bei Änderungen automatisch neu):
> ```bash
> npm run dev
> ```

---

## Wie es funktioniert

### Gruppe erstellen
1. → „Gruppe erstellen"
2. Gruppenname eingeben (z.B. „Montag Crew")
3. **6-stelligen Code** notieren und an deine Gym-Buddies schicken
4. → „Weiter zur App"

### Gruppe beitreten
1. → „Code eingeben"
2. Den 6-stelligen Code eintippen
3. → „Beitreten"

Alle, die denselben Code verwenden, sehen dieselben Daten in Echtzeit (Aktualisierung alle 8 Sekunden).

---

## Im Internet bereitstellen (Deployment)

Damit alle ohne deinen PC darauf zugreifen können, brauchst du einen Server.

> ⚠️ **Wichtig – Datenbank beim Deployment**
>
> Railway und Render nutzen **ephemere Container**: Bei jedem neuen Deploy startet ein frischer Container – ohne die alte `data.db`. Die Daten wären weg.
>
> **Lösung:** Ein **Persistent Volume** (dauerhafter Datei-Speicher) einrichten und die Umgebungsvariable `DB_PATH` auf die Datei darin setzen. Anleitung für jede Plattform weiter unten.

---

### Option A – Railway (empfohlen, kostenlos)

**1. Projekt erstellen**
1. Konto erstellen: https://railway.app
2. „New Project" → „Deploy from GitHub Repo" → dein `gym-late` Repo wählen
3. Railway erkennt Node.js automatisch und deployt sofort

**2. Persistent Volume hinzufügen** ← damit die Datenbank überlebt
1. Im Railway-Projekt: linke Seitenleiste → **„+ New"** → **„Volume"**
2. Volume auf deinen Service ziehen (oder im Service unter „Volumes" hinzufügen)
3. **Mount Path:** `/data`
4. Speichern

**3. Umgebungsvariable setzen**
1. Service → **„Variables"** → **„New Variable"**
2. Key: `DB_PATH`  
   Value: `/data/data.db`
3. Speichern → Railway startet neu → fertig ✓

Deine App läuft jetzt auf `*.up.railway.app` und die Daten bleiben bei jedem Deploy erhalten.

---

### Option B – Render (kostenlos, mit Schlafmodus)

**1. Web Service erstellen**
1. Konto erstellen: https://render.com
2. „New Web Service" → GitHub Repo verbinden
3. Build Command: `npm install`
4. Start Command: `npm start`

**2. Persistent Disk hinzufügen** ← damit die Datenbank überlebt
1. Service → **„Disks"** → **„Add Disk"**
2. Name: `data`
3. Mount Path: `/data`
4. Size: `1 GB` (kostenlos)
5. Speichern

**3. Umgebungsvariable setzen**
1. Service → **„Environment"** → **„Add Environment Variable"**
2. Key: `DB_PATH`  
   Value: `/data/data.db`
3. Speichern → Render startet neu → fertig ✓

> Free Tier: App schläft nach 15 Min. Inaktivität ein (erste Anfrage danach dauert ~30s).

---

### Option C – VPS (Hetzner, z.B. €4/Monat, immer online)

Auf einem VPS liegt die `data.db` dauerhaft auf dem Server — kein Volume nötig.

```bash
# Node.js installieren
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt install -y nodejs

# Code holen
git clone https://github.com/dergepjunte/gym-late gymLate
cd gymLate
npm install

# Mit PM2 dauerhaft laufen lassen (startet auch nach Reboot neu)
npm install -g pm2
pm2 start server.js --name gymLate
pm2 save && pm2 startup

# Updates einspielen (ohne Datenverlust)
git pull && npm install && pm2 restart gymLate
```

> Nginx als Reverse Proxy empfohlen wenn du eine eigene Domain nutzt (Port 80/443 statt :3000).

---

## Daten sichern

Die Datenbank ist eine einzelne Datei (`data.db`). Backup erstellen:

```bash
# Lokal / VPS
cp data.db data.db.backup-$(date +%Y%m%d)

# Von Railway/Render herunterladen (Railway CLI)
railway run cp /data/data.db /tmp/backup.db
railway run cat /tmp/backup.db > backup.db
```

---

## Tipps

- Der **Code** läuft nicht ab — du kannst jederzeit wieder beitreten.
- „Gruppe verlassen" entfernt nur die Verbindung auf diesem Gerät. Die Daten bleiben.
- Die App erkennt automatisch **Dark/Light Mode** und die **Systemsprache** (Deutsch/Englisch).
- Auf dem **iPhone**: Im Safari-Browser unten „Teilen → Zum Home-Bildschirm" → sieht aus wie eine echte App.
- **Admin-Modus:** 5× auf das 🏋️-Icon tippen → Passwort `gymadmin`
