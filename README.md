# Everlast AI Backend

Standalone KI-Server für lokale LLM-Generierung (Ollama) und Audio-Transkription (faster-whisper).

## Features

- **LLM-Generierung** via Ollama (Llama, Mistral, Gemma, etc.)
- **Audio-Transkription** mit faster-whisper (GPU-beschleunigt)
- **GPU-Profile** mit automatischer Modell-Empfehlung
- **REST-API** mit OpenAPI-Dokumentation

## Schnellstart

```bash
# Server starten
./start.sh

# API-Dokumentation öffnen
xdg-open http://localhost:8080/docs
```

## Voraussetzungen

- Python 3.10+
- Ollama (für LLM)
- CUDA (optional, für GPU-Beschleunigung)

### Ollama installieren

```bash
# Installation
./scripts/install_ollama.sh

# Oder manuell
curl -fsSL https://ollama.com/install.sh | sh

# Modell laden
ollama pull llama3.2:8b
```

## API Endpoints

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
  -d '{"prompt": "Erkläre mir Quantencomputing in 3 Sätzen."}'
```

### Beispiel: Audio transkribieren

```bash
curl -X POST http://localhost:8080/api/v1/transcribe \
  -F "audio=@recording.webm" \
  -F "language=de"
```

## Konfiguration

Umgebungsvariablen (oder `.env`-Datei):

| Variable | Default | Beschreibung |
|----------|---------|--------------|
| `BACKEND_HOST` | `0.0.0.0` | Server-Host |
| `BACKEND_PORT` | `8080` | Server-Port |
| `OLLAMA_BASE_URL` | `http://localhost:11434` | Ollama URL |
| `OLLAMA_DEFAULT_MODEL` | (auto) | Standard LLM-Modell |
| `WHISPER_MODEL` | (auto) | Standard STT-Modell |
| `GPU_PROFILE` | `auto` | GPU-Profil (8gb/16gb/24gb/cpu) |
| `LOG_LEVEL` | `INFO` | Log-Level |

## GPU-Profile

Das System erkennt automatisch die verfügbare GPU und wählt passende Modelle:

| Profil | VRAM | LLM-Empfehlung | STT-Empfehlung |
|--------|------|----------------|----------------|
| `cpu` | 0 GB | llama3.2:1b | small |
| `8gb` | 8 GB | llama3.2:3b | medium |
| `16gb` | 16 GB | llama3.2:8b | large-v3 |
| `24gb` | 24+ GB | llama3.1:70b-q4 | large-v3 |

## Architektur

```
┌─────────────────────────────────────────────────────────────┐
│                    Everlast AI Backend                      │
│                      (FastAPI Server)                       │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│   ┌─────────────────┐        ┌─────────────────┐           │
│   │  OllamaService  │        │ WhisperService  │           │
│   │  (HTTP Client)  │        │(faster-whisper) │           │
│   └────────┬────────┘        └────────┬────────┘           │
│            │                          │                     │
└────────────┼──────────────────────────┼─────────────────────┘
             │                          │
             ▼                          ▼
      ┌──────────────┐           ┌──────────────┐
      │    Ollama    │           │     GPU      │
      │   (extern)   │           │   (CUDA)     │
      └──────────────┘           └──────────────┘
```

## Integration mit Everlast AI

In der Hauptapp Settings → KI-Backend:

1. Backend-Modus auf "Lokal/Privat" setzen
2. Server-Adresse eingeben (z.B. `http://localhost:8080`)
3. Verbindung testen

## Lizenz

MIT License
