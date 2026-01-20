#!/bin/bash
# Ollama Installation und Setup
#
# Installiert Ollama und lädt empfohlene Modelle herunter.

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}             Ollama Installation                           ${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"

# Prüfe ob Ollama bereits installiert ist
if command -v ollama &> /dev/null; then
    echo -e "${GREEN}✓ Ollama ist bereits installiert${NC}"
    ollama --version
else
    echo -e "${YELLOW}Installiere Ollama...${NC}"
    curl -fsSL https://ollama.com/install.sh | sh
    echo -e "${GREEN}✓ Ollama installiert${NC}"
fi

# Starte Ollama Service falls nicht läuft
if ! curl -s "http://localhost:11434/api/tags" > /dev/null 2>&1; then
    echo -e "${YELLOW}Starte Ollama Service...${NC}"
    ollama serve &
    sleep 3
fi

# GPU erkennen und Modelle empfehlen
echo ""
echo -e "${BLUE}Erkenne GPU...${NC}"

VRAM_GB=0
if command -v nvidia-smi &> /dev/null; then
    VRAM_MB=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits | head -n1)
    VRAM_GB=$((VRAM_MB / 1024))
    GPU_NAME=$(nvidia-smi --query-gpu=name --format=csv,noheader | head -n1)
    echo -e "${GREEN}GPU: $GPU_NAME ($VRAM_GB GB VRAM)${NC}"
fi

# Modell basierend auf VRAM empfehlen
if [ $VRAM_GB -ge 24 ]; then
    RECOMMENDED="llama3.1:70b-q4"
    PROFILE="24gb"
elif [ $VRAM_GB -ge 16 ]; then
    RECOMMENDED="llama3.2:8b"
    PROFILE="16gb"
elif [ $VRAM_GB -ge 8 ]; then
    RECOMMENDED="llama3.2:3b"
    PROFILE="8gb"
else
    RECOMMENDED="llama3.2:1b"
    PROFILE="cpu"
fi

echo ""
echo -e "${BLUE}Empfohlenes Profil: ${YELLOW}$PROFILE${NC}"
echo -e "${BLUE}Empfohlenes Modell: ${YELLOW}$RECOMMENDED${NC}"
echo ""

read -p "Modell '$RECOMMENDED' herunterladen? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Lade Modell herunter...${NC}"
    ollama pull "$RECOMMENDED"
    echo -e "${GREEN}✓ Modell '$RECOMMENDED' heruntergeladen${NC}"
fi

echo ""
echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}Installation abgeschlossen!${NC}"
echo ""
echo -e "Ollama starten:  ${BLUE}ollama serve${NC}"
echo -e "Modelle zeigen:  ${BLUE}ollama list${NC}"
echo -e "Modell laden:    ${BLUE}ollama pull <modell>${NC}"
echo ""
