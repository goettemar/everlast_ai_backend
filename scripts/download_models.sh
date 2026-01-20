#!/bin/bash
# Modell-Download nach GPU-Profil
#
# Lädt die empfohlenen Modelle für das angegebene GPU-Profil herunter.

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PROFILE="${1:-auto}"

echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}           Modell-Download für Everlast AI                 ${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"

# Auto-Detect Profil
if [ "$PROFILE" = "auto" ]; then
    VRAM_GB=0
    if command -v nvidia-smi &> /dev/null; then
        VRAM_MB=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits | head -n1)
        VRAM_GB=$((VRAM_MB / 1024))
    fi

    if [ $VRAM_GB -ge 24 ]; then
        PROFILE="24gb"
    elif [ $VRAM_GB -ge 16 ]; then
        PROFILE="16gb"
    elif [ $VRAM_GB -ge 8 ]; then
        PROFILE="8gb"
    else
        PROFILE="cpu"
    fi
fi

echo -e "${BLUE}Profil: ${YELLOW}$PROFILE${NC}"
echo ""

# Modelle nach Profil
case $PROFILE in
    "24gb")
        LLM_MODELS=("llama3.1:70b-q4" "mixtral:8x7b" "qwen2.5:32b")
        STT_MODELS=("large-v3")
        ;;
    "16gb")
        LLM_MODELS=("llama3.2:8b" "mistral:7b" "gemma2:9b")
        STT_MODELS=("large-v3" "medium")
        ;;
    "8gb")
        LLM_MODELS=("llama3.2:3b" "phi3:mini" "gemma2:2b")
        STT_MODELS=("medium" "small")
        ;;
    *)
        LLM_MODELS=("llama3.2:1b" "phi3:mini")
        STT_MODELS=("small" "base")
        ;;
esac

# LLM-Modelle herunterladen
echo -e "${BLUE}LLM-Modelle (Ollama):${NC}"
for model in "${LLM_MODELS[@]}"; do
    echo -e "  ${YELLOW}$model${NC}"
done

read -p "LLM-Modelle herunterladen? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    for model in "${LLM_MODELS[@]}"; do
        echo -e "${YELLOW}Lade $model...${NC}"
        ollama pull "$model" || echo -e "${RED}Fehler bei $model${NC}"
    done
fi

# Whisper-Modelle (werden bei Bedarf automatisch geladen)
echo ""
echo -e "${BLUE}STT-Modelle (faster-whisper):${NC}"
for model in "${STT_MODELS[@]}"; do
    echo -e "  ${YELLOW}$model${NC} (wird bei erster Nutzung geladen)"
done

echo ""
echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}Fertig! Starte den Server mit: ./start.sh${NC}"
echo ""
