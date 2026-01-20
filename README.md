# Everlast AI Backend

**Version 1.0** | Lokaler KI-Server für Offline-Verarbeitung

> Companion-Projekt zu [Everlast AI](https://github.com/goettemar/everlast-ai)

---

## Was ist das?

Ein standalone KI-Server für **lokale LLM-Generierung** (Ollama) und **Audio-Transkription** (faster-whisper). Ermöglicht vollständig private Verarbeitung ohne Cloud-APIs.

```
🎤 Audio  →  📝 Transkription (Whisper)  →  🤖 KI-Verarbeitung (Ollama)
              (lokal, GPU-beschleunigt)       (lokal, privat)
```

### Highlights

- **Privacy-Mode** – Alle Daten bleiben auf deinem Rechner
- **Keine API-Kosten** – Einmalige Modell-Downloads, dann kostenlos
- **Automatisches Setup** – start.sh installiert und konfiguriert alles
- **GPU-Optimiert** – Automatische Modell-Empfehlung für deine Hardware

---

## Schnellstart

### Linux / macOS

```bash
# Repository klonen
git clone https://github.com/goettemar/everlast_ai_backend.git
cd everlast_ai_backend

# Server starten (interaktives Setup beim ersten Mal)
./start.sh
```

### Windows (Beta)

> **Hinweis:** Die Windows-Version wurde nicht ausführlich getestet und gilt als Beta. Feedback und Bug-Reports sind willkommen!

```powershell
# Repository klonen
git clone https://github.com/goettemar/everlast_ai_backend.git
cd everlast_ai_backend

# Server starten (interaktives Setup beim ersten Mal)
start.bat
```

Das Start-Skript:
1. Prüft Python und Ollama Installation
2. Bietet automatische Ollama-Installation an
3. Lädt empfohlene Modelle herunter (Whisper medium, DeepSeek-R1)
4. Konfiguriert Everlast AI für lokale Provider
5. Startet den Server auf Port 8080

**API-Dokumentation:** http://localhost:8080/docs

---

## Voraussetzungen

| Komponente | Minimum | Empfohlen |
|------------|---------|-----------|
| Python | 3.10+ | 3.11+ |
| RAM | 8 GB | 16 GB |
| GPU VRAM | - (CPU möglich) | 8+ GB |
| Speicher | 10 GB | 20 GB |

### Ollama (für LLM)

**Linux/macOS:** Wird automatisch vom Start-Skript installiert, oder manuell:

```bash
curl -fsSL https://ollama.com/install.sh | sh
ollama pull deepseek-r1:8b
```

**Windows:** Installer von [ollama.com/download/windows](https://ollama.com/download/windows) herunterladen und installieren, dann:

```powershell
ollama pull deepseek-r1:8b
```

---

## GPU-Profile

Das System erkennt automatisch deine GPU und wählt passende Modelle:

| Profil | VRAM | LLM-Empfehlung | STT-Empfehlung | Qualität |
|--------|------|----------------|----------------|----------|
| **cpu** | - | llama3.2:1b | small | ★★☆☆☆ |
| **8gb** | 8 GB | deepseek-r1:8b | medium | ★★★★☆ |
| **16gb** | 16 GB | llama3.2:8b | large-v3 | ★★★★★ |
| **24gb** | 24+ GB | llama3.1:70b-q4 | large-v3 | ★★★★★ |

---

## API-Endpunkte

| Endpoint | Methode | Beschreibung |
|----------|---------|--------------|
| `/health` | GET | Status + verfügbare Modelle |
| `/api/v1/generate` | POST | LLM Text-Generierung |
| `/api/v1/transcribe` | POST | Audio-Transkription |
| `/api/v1/models` | GET | Liste der Ollama-Modelle |
| `/api/v1/gpu-profiles` | GET | GPU-Profile mit Empfehlungen |

### Beispiel: Text generieren

```bash
curl -X POST http://localhost:8080/api/v1/generate \
  -H "Content-Type: application/json" \
  -d '{"prompt": "Fasse diesen Text zusammen: ..."}'
```

### Beispiel: Audio transkribieren

```bash
curl -X POST http://localhost:8080/api/v1/transcribe \
  -F "audio=@meeting.webm" \
  -F "language=de"
```

---

## Konfiguration

Umgebungsvariablen (oder `.env`-Datei):

| Variable | Default | Beschreibung |
|----------|---------|--------------|
| `BACKEND_PORT` | `8080` | Server-Port |
| `OLLAMA_BASE_URL` | `http://localhost:11434` | Ollama-Server URL |
| `WHISPER_MODEL` | `auto` | STT-Modell (tiny/base/small/medium/large-v3) |
| `GPU_PROFILE` | `auto` | Profil (8gb/16gb/24gb/cpu) |

### Kommandozeilen-Optionen

**Linux/macOS:**
```bash
./start.sh              # Normaler Start
./start.sh --setup      # Setup erneut ausführen
./start.sh --reset      # Setup zurücksetzen
./start.sh --help       # Hilfe anzeigen
```

**Windows:**
```powershell
start.bat               # Normaler Start
start.bat --setup       # Setup erneut ausführen
start.bat --reset       # Setup zurücksetzen
start.bat --help        # Hilfe anzeigen
```

---

## Architektur

```
┌─────────────────────────────────────────────────────────────┐
│                    Everlast AI Backend                       │
│                      (FastAPI Server)                        │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│   ┌─────────────────┐        ┌─────────────────┐            │
│   │  OllamaService  │        │ WhisperService  │            │
│   │  (HTTP Client)  │        │(faster-whisper) │            │
│   └────────┬────────┘        └────────┬────────┘            │
│            │                          │                      │
└────────────┼──────────────────────────┼──────────────────────┘
             │                          │
             ▼                          ▼
      ┌──────────────┐           ┌──────────────┐
      │    Ollama    │           │  GPU (CUDA)  │
      │   Server     │           │  oder CPU    │
      │ :11434       │           │              │
      └──────────────┘           └──────────────┘
```

---

## Integration mit Everlast AI

Das Start-Skript konfiguriert Everlast AI automatisch. Manuelle Konfiguration:

1. In Everlast AI: Settings → Tab "KI-Backend"
2. **Ollama aktivieren**: URL `http://localhost:11434`
3. **Local Whisper aktivieren**: URL `http://localhost:8080`
4. "Verbindung testen" klicken
5. "Speichern"

---

## Projektstruktur

```
everlast_ai_backend/
├── main.py              # FastAPI Entry
├── config.py            # Settings + GPU-Profile
├── start.sh             # Start-Skript mit Setup
│
├── api/
│   └── routes.py        # API-Endpunkte
│
├── services/
│   ├── ollama_service.py    # LLM-Client
│   └── whisper_service.py   # STT-Engine
│
├── models/
│   └── schemas.py       # Pydantic Models
│
└── requirements.txt     # Python Dependencies
```

---

## Fehlerbehebung

| Problem | Lösung |
|---------|--------|
| Ollama nicht gefunden | `curl -fsSL https://ollama.com/install.sh \| sh` |
| Modell nicht geladen | `ollama pull deepseek-r1:8b` |
| Port belegt | `BACKEND_PORT=8081 ./start.sh` |
| GPU nicht erkannt | CUDA-Treiber prüfen, `nvidia-smi` |
| Whisper langsam | GPU-Profil auf `cpu` setzen oder CUDA installieren |

---

## Lizenz

MIT License

---

*Everlast AI Backend – Lokale KI für [Everlast AI](https://github.com/goettemar/everlast-ai)*
