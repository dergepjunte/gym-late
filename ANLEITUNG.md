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

### Option A – Railway (einfachste Option, kostenlos)

1. Konto erstellen: https://railway.app
2. „New Project" → „Deploy from GitHub Repo"
3. Deinen Code auf GitHub pushen (oder ZIP hochladen via Dashboard)
4. Railway erkennt Node.js automatisch
5. Deine App bekommt eine URL wie `gymLate-production.up.railway.app`

**Umgebungsvariable setzen:**
- Key: `PORT`, Value: `3000` (Railway setzt das normalerweise automatisch)

### Option B – Render (auch kostenlos, mit Schlafmodus)

1. Konto erstellen: https://render.com
2. „New Web Service" → GitHub Repo verbinden
3. Build Command: `npm install`
4. Start Command: `npm start`
5. Free Tier: App schläft nach 15 Min. Inaktivität ein (erste Anfrage dauert ~30s)

### Option C – VPS (Hetzner, z.B. €4/Monat, immer online)

Auf dem Server (Ubuntu):
```bash
# Node.js installieren
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt install -y nodejs

# Code hochladen (z.B. per scp oder git clone)
git clone <dein-repo> gymLate && cd gymLate
npm install

# Mit PM2 dauerhaft laufen lassen
npm install -g pm2
pm2 start server.js --name gymLate
pm2 save && pm2 startup

# Nginx als Reverse Proxy (optional, für Port 80/443)
# dann läuft es auf deiner Domain ohne :3000
```

---

## Daten

Alle Gruppen, Personen und Einträge werden in `data.db` gespeichert (SQLite-Datei im Projektordner). Diese Datei automatisch sichern, falls du auf einem VPS bist.

---

## Tipps

- Der **Code** läuft nicht ab — du kannst jederzeit wieder beitreten.
- „Gruppe verlassen" entfernt nur die Verbindung auf diesem Gerät. Die Daten bleiben.
- Die App erkennt automatisch **Dark/Light Mode** und die **Systemsprache** (Deutsch/Englisch).
- Auf dem **iPhone**: Im Safari-Browser unten „Teilen → Zum Home-Bildschirm" → sieht aus wie eine echte App.
