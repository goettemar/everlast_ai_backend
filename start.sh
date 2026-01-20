#!/bin/bash
# Everlast AI Backend - Startskript
#
# Startet den lokalen KI-Server für Everlast AI.
# Beim ersten Start werden Modelle automatisch heruntergeladen.
#
# Voraussetzungen: Python 3.10+, Ollama, CUDA (optional)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Farben
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Konfiguration
WHISPER_MODEL="${WHISPER_MODEL:-medium}"
OLLAMA_MODEL="${OLLAMA_MODEL:-deepseek-r1:8b}"
OLLAMA_URL="${OLLAMA_BASE_URL:-http://localhost:11434}"
EVERLAST_AI_DIR="${EVERLAST_AI_DIR:-$HOME/projekte/everlast_ai}"

# Marker-Datei für Ersteinrichtung
SETUP_MARKER="$SCRIPT_DIR/.setup_complete"

# Parameter verarbeiten
FORCE_SETUP=false
while [[ $# -gt 0 ]]; do
    case $1 in
        --setup|--reset)
            FORCE_SETUP=true
            rm -f "$SETUP_MARKER"
            shift
            ;;
        --help|-h)
            echo "Everlast AI Backend - Startskript"
            echo ""
            echo "Verwendung: ./start.sh [OPTIONEN]"
            echo ""
            echo "Optionen:"
            echo "  --setup, --reset    Ersteinrichtung erneut ausführen"
            echo "  --help, -h          Diese Hilfe anzeigen"
            echo ""
            echo "Umgebungsvariablen:"
            echo "  WHISPER_MODEL       Whisper-Modell (default: medium)"
            echo "  OLLAMA_MODEL        Ollama-Modell (default: deepseek-r1:8b)"
            echo "  BACKEND_PORT        Server-Port (default: 8080)"
            exit 0
            ;;
        *)
            echo "Unbekannte Option: $1"
            echo "Verwende --help für Hilfe"
            exit 1
            ;;
    esac
done

echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}       Everlast AI Backend - Lokaler KI-Server             ${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""

# === Hilfsfunktionen ===

ask_yes_no() {
    local prompt="$1"
    local default="${2:-y}"

    if [[ "$default" == "y" ]]; then
        prompt="$prompt [J/n] "
    else
        prompt="$prompt [j/N] "
    fi

    read -p "$prompt" response
    response=${response:-$default}

    [[ "$response" =~ ^[JjYy]$ ]]
}

check_whisper_model_cached() {
    # Prüfe ob das Whisper-Modell bereits im Cache ist
    local model="$1"
    local cache_dir="$HOME/.cache/huggingface/hub"

    # faster-whisper speichert Modelle unter verschiedenen Namen
    if [[ -d "$cache_dir" ]]; then
        if find "$cache_dir" -type d -name "*whisper*$model*" 2>/dev/null | grep -q .; then
            return 0
        fi
        # Alternativ: CTranslate2 Modelle
        if find "$cache_dir" -type d -name "*ctranslate2*$model*" 2>/dev/null | grep -q .; then
            return 0
        fi
    fi
    return 1
}

download_whisper_model() {
    local model="$1"
    echo -e "${CYAN}Lade Whisper-Modell '${model}'...${NC}"
    echo -e "${YELLOW}Dies kann einige Minuten dauern (ca. 1.5 GB für 'medium').${NC}"
    echo ""

    python3 -c "
from faster_whisper import WhisperModel
import sys

model_size = '$model'
print(f'Initialisiere {model_size}...')

try:
    # Modell laden (lädt automatisch von Hugging Face)
    model = WhisperModel(model_size, device='cpu', compute_type='int8')
    print(f'✓ Modell {model_size} erfolgreich heruntergeladen und gecacht!')
except Exception as e:
    print(f'✗ Fehler: {e}', file=sys.stderr)
    sys.exit(1)
"

    if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}✓ Whisper-Modell '${model}' bereit${NC}"
        return 0
    else
        echo -e "${RED}✗ Fehler beim Laden des Whisper-Modells${NC}"
        return 1
    fi
}

check_ollama_model() {
    local model="$1"
    local base_model="${model%%:*}"  # Entferne Tag (z.B. :8b)

    if curl -s "$OLLAMA_URL/api/tags" 2>/dev/null | grep -q "\"name\":\"$model\""; then
        return 0
    fi
    # Auch ohne Tag prüfen
    if curl -s "$OLLAMA_URL/api/tags" 2>/dev/null | grep -q "\"name\":\"$base_model"; then
        return 0
    fi
    return 1
}

pull_ollama_model() {
    local model="$1"
    echo -e "${CYAN}Lade Ollama-Modell '${model}'...${NC}"
    echo -e "${YELLOW}Dies kann einige Minuten dauern (ca. 4-5 GB).${NC}"
    echo ""

    ollama pull "$model"

    if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}✓ Ollama-Modell '${model}' bereit${NC}"
        return 0
    else
        echo -e "${RED}✗ Fehler beim Laden des Ollama-Modells${NC}"
        return 1
    fi
}

configure_everlast_ai() {
    local whisper_model="$1"
    local ollama_model="$2"
    local env_file="$EVERLAST_AI_DIR/backend/.env"

    echo -e "${CYAN}Konfiguriere Everlast AI...${NC}"

    if [[ ! -d "$EVERLAST_AI_DIR" ]]; then
        echo -e "${YELLOW}⚠ Everlast AI Verzeichnis nicht gefunden: $EVERLAST_AI_DIR${NC}"
        return 1
    fi

    # Bestehende .env laden oder neue erstellen
    declare -A env_vars

    if [[ -f "$env_file" ]]; then
        while IFS='=' read -r key value; do
            [[ -z "$key" || "$key" =~ ^# ]] && continue
            env_vars["$key"]="$value"
        done < "$env_file"
    fi

    # Lokale Provider aktivieren
    env_vars["LOCAL_WHISPER_ENABLED"]="true"
    env_vars["LOCAL_WHISPER_BASE_URL"]="http://localhost:8080"
    env_vars["LOCAL_WHISPER_MODEL"]="$whisper_model"

    env_vars["OLLAMA_ENABLED"]="true"
    env_vars["OLLAMA_BASE_URL"]="http://localhost:11434"
    env_vars["OLLAMA_MODEL"]="$ollama_model"

    # Defaults auf lokal setzen
    env_vars["DEFAULT_STT_PROVIDER"]="local_whisper"
    env_vars["DEFAULT_LLM_PROVIDER"]="ollama"

    # .env schreiben
    {
        echo "# Everlast AI - Environment Configuration"
        echo "# Automatisch konfiguriert durch everlast_ai_backend/start.sh"
        echo "# $(date)"
        echo ""
        echo "# === Lokale Provider (Offline) ==="
        echo "LOCAL_WHISPER_ENABLED=${env_vars[LOCAL_WHISPER_ENABLED]}"
        echo "LOCAL_WHISPER_BASE_URL=${env_vars[LOCAL_WHISPER_BASE_URL]}"
        echo "LOCAL_WHISPER_MODEL=${env_vars[LOCAL_WHISPER_MODEL]}"
        echo ""
        echo "OLLAMA_ENABLED=${env_vars[OLLAMA_ENABLED]}"
        echo "OLLAMA_BASE_URL=${env_vars[OLLAMA_BASE_URL]}"
        echo "OLLAMA_MODEL=${env_vars[OLLAMA_MODEL]}"
        echo ""
        echo "# === Aktive Provider ==="
        echo "DEFAULT_STT_PROVIDER=${env_vars[DEFAULT_STT_PROVIDER]}"
        echo "DEFAULT_LLM_PROVIDER=${env_vars[DEFAULT_LLM_PROVIDER]}"
        echo ""
        echo "# === Online Provider (optional) ==="
        for key in "${!env_vars[@]}"; do
            case "$key" in
                LOCAL_WHISPER_*|OLLAMA_*|DEFAULT_*) continue ;;
                *) echo "$key=${env_vars[$key]}" ;;
            esac
        done
    } > "$env_file"

    echo -e "${GREEN}✓ Everlast AI konfiguriert für lokale Provider${NC}"
    echo -e "  STT: local_whisper (${whisper_model})"
    echo -e "  LLM: ollama (${ollama_model})"
}

# === Voraussetzungen prüfen ===

echo -e "${BLUE}Prüfe Voraussetzungen...${NC}"
echo ""

# Prüfe Python
if ! command -v python3 &> /dev/null; then
    echo -e "${RED}✗ Python3 nicht gefunden!${NC}"
    echo -e "  Bitte installiere Python 3.10+:"
    echo -e "  ${CYAN}sudo apt install python3 python3-venv python3-pip${NC}"
    exit 1
fi
echo -e "  Python: ${GREEN}✓ $(python3 --version)${NC}"

# Prüfe Ollama
if ! command -v ollama &> /dev/null; then
    echo ""
    echo -e "${RED}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║                  OLLAMA NICHT INSTALLIERT                  ║${NC}"
    echo -e "${RED}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "Ollama wird für die lokale LLM-Generierung benötigt."
    echo ""
    echo -e "Installation:"
    echo -e "  ${CYAN}curl -fsSL https://ollama.com/install.sh | sh${NC}"
    echo ""
    echo -e "Nach der Installation dieses Skript erneut ausführen."
    echo ""

    if ask_yes_no "Soll Ollama jetzt automatisch installiert werden?" "y"; then
        echo ""
        echo -e "${CYAN}Installiere Ollama...${NC}"
        curl -fsSL https://ollama.com/install.sh | sh

        if command -v ollama &> /dev/null; then
            echo -e "${GREEN}✓ Ollama erfolgreich installiert${NC}"
            # Kurz warten und Ollama starten
            sleep 2
            echo -e "${CYAN}Starte Ollama-Service...${NC}"
            nohup ollama serve &>/dev/null &
            sleep 3
        else
            echo -e "${RED}✗ Ollama Installation fehlgeschlagen${NC}"
            exit 1
        fi
    else
        echo -e "${YELLOW}Abgebrochen. Bitte Ollama manuell installieren.${NC}"
        exit 1
    fi
fi
echo -e "  Ollama: ${GREEN}✓ Installiert${NC}"

# Prüfe ob Ollama läuft
if ! curl -s "$OLLAMA_URL/api/tags" &>/dev/null; then
    echo -e "  Ollama-Service: ${YELLOW}Nicht gestartet${NC}"
    echo ""
    if ask_yes_no "  Soll Ollama jetzt gestartet werden?" "y"; then
        echo -e "  ${CYAN}Starte Ollama...${NC}"
        nohup ollama serve &>/dev/null &
        sleep 3
        if curl -s "$OLLAMA_URL/api/tags" &>/dev/null; then
            echo -e "  Ollama-Service: ${GREEN}✓ Gestartet${NC}"
        else
            echo -e "  ${YELLOW}⚠ Ollama konnte nicht gestartet werden${NC}"
            echo -e "  Versuche manuell: ${CYAN}ollama serve${NC}"
        fi
    fi
else
    echo -e "  Ollama-Service: ${GREEN}✓ Läuft${NC}"
fi

echo ""

# Virtuelle Umgebung erstellen/aktivieren
if [ ! -d "venv" ]; then
    echo -e "${YELLOW}Erstelle virtuelle Umgebung...${NC}"
    python3 -m venv venv
fi

source venv/bin/activate

# Dependencies installieren falls nötig
if [ ! -f "venv/.installed" ]; then
    echo -e "${YELLOW}Installiere Dependencies...${NC}"
    pip install --upgrade pip
    pip install -r requirements.txt
    touch venv/.installed
fi

echo ""

# === Ersteinrichtung ===

if [[ ! -f "$SETUP_MARKER" ]]; then
    echo -e "${BOLD}${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${CYAN}║              ERSTEINRICHTUNG - Modelle laden               ║${NC}"
    echo -e "${BOLD}${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "Für die lokale KI-Verarbeitung werden folgende Modelle benötigt:"
    echo ""
    echo -e "  ${BOLD}1. Whisper (STT)${NC}: ${WHISPER_MODEL}"
    echo -e "     Größe: ~1.5 GB | VRAM: ~5 GB | Qualität: ★★★★☆"
    echo ""
    echo -e "  ${BOLD}2. DeepSeek (LLM)${NC}: ${OLLAMA_MODEL}"
    echo -e "     Größe: ~4.5 GB | VRAM: ~6 GB | Qualität: ★★★★★"
    echo ""

    SETUP_WHISPER=false
    SETUP_OLLAMA=false

    # Whisper prüfen
    echo -e "${BLUE}Prüfe Whisper-Modell...${NC}"
    if check_whisper_model_cached "$WHISPER_MODEL"; then
        echo -e "${GREEN}✓ Whisper '${WHISPER_MODEL}' bereits im Cache${NC}"
    else
        echo -e "${YELLOW}⚠ Whisper '${WHISPER_MODEL}' nicht gefunden${NC}"
        echo ""
        if ask_yes_no "  Soll das Whisper-Modell '${WHISPER_MODEL}' jetzt heruntergeladen werden?" "y"; then
            SETUP_WHISPER=true
        fi
    fi

    echo ""

    # Ollama-Modell prüfen (Ollama selbst wurde bereits oben geprüft)
    echo -e "${BLUE}Prüfe Ollama-Modell...${NC}"
    if curl -s "$OLLAMA_URL/api/tags" &>/dev/null; then
        if check_ollama_model "$OLLAMA_MODEL"; then
            echo -e "${GREEN}✓ Ollama-Modell '${OLLAMA_MODEL}' bereits vorhanden${NC}"
        else
            echo -e "${YELLOW}⚠ Ollama-Modell '${OLLAMA_MODEL}' nicht gefunden${NC}"
            echo ""
            if ask_yes_no "  Soll das Ollama-Modell '${OLLAMA_MODEL}' jetzt heruntergeladen werden?" "y"; then
                SETUP_OLLAMA=true
            fi
        fi
    else
        echo -e "${YELLOW}⚠ Ollama-Service nicht erreichbar - Modell-Check übersprungen${NC}"
    fi

    echo ""

    # Downloads durchführen
    if $SETUP_WHISPER; then
        echo ""
        download_whisper_model "$WHISPER_MODEL"
        echo ""
    fi

    if $SETUP_OLLAMA; then
        echo ""
        pull_ollama_model "$OLLAMA_MODEL"
        echo ""
    fi

    # Everlast AI konfigurieren
    echo ""
    if ask_yes_no "Soll Everlast AI für lokale Provider konfiguriert werden?" "y"; then
        configure_everlast_ai "$WHISPER_MODEL" "$OLLAMA_MODEL"
    fi

    # Setup-Marker erstellen
    touch "$SETUP_MARKER"

    echo ""
    echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}              Ersteinrichtung abgeschlossen!               ${NC}"
    echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
    echo ""
fi

# === Status anzeigen ===

echo -e "${BLUE}System-Status:${NC}"
echo ""

# GPU-Info
if command -v nvidia-smi &> /dev/null; then
    GPU_INFO=$(nvidia-smi --query-gpu=name,memory.total,memory.free --format=csv,noheader 2>/dev/null | head -n1)
    echo -e "  GPU: ${GREEN}$GPU_INFO${NC}"
else
    echo -e "  GPU: ${YELLOW}Keine NVIDIA GPU - CPU-Modus${NC}"
fi

# Ollama Status
if curl -s "$OLLAMA_URL/api/tags" &>/dev/null; then
    MODELS=$(curl -s "$OLLAMA_URL/api/tags" | python3 -c "import sys, json; d=json.load(sys.stdin); print(', '.join([m['name'] for m in d.get('models', [])][:5]))" 2>/dev/null || echo "?")
    echo -e "  Ollama: ${GREEN}✓ Erreichbar${NC} - Modelle: $MODELS"
else
    echo -e "  Ollama: ${YELLOW}✗ Nicht erreichbar${NC} (starte mit: ollama serve)"
fi

# Whisper Status
if check_whisper_model_cached "$WHISPER_MODEL"; then
    echo -e "  Whisper: ${GREEN}✓ Modell '${WHISPER_MODEL}' gecacht${NC}"
else
    echo -e "  Whisper: ${YELLOW}✗ Modell '${WHISPER_MODEL}' nicht im Cache${NC}"
fi

echo ""
echo -e "${BLUE}Konfiguration:${NC}"
echo -e "  Whisper-Modell: ${CYAN}${WHISPER_MODEL}${NC}"
echo -e "  Ollama-Modell:  ${CYAN}${OLLAMA_MODEL}${NC}"
echo -e "  Server-Port:    ${CYAN}${BACKEND_PORT:-8080}${NC}"

echo ""
echo -e "${GREEN}Starte Server...${NC}"
echo -e "API-Dokumentation: ${CYAN}http://localhost:${BACKEND_PORT:-8080}/docs${NC}"
echo ""

# Server starten
python3 main.py
