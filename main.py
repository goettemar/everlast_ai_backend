"""
Everlast AI Backend - FastAPI Server

Standalone KI-Server für lokale LLM (Ollama) und STT (faster-whisper).
"""

import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
import uvicorn

from config import settings
from api.routes import router
from services.whisper_service import whisper_service

# Logging konfigurieren
logging.basicConfig(
    level=getattr(logging, settings.log_level.upper()),
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
)
logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application lifespan handler."""
    # Startup
    logger.info("=" * 60)
    logger.info("Everlast AI Backend startet...")
    logger.info(f"GPU-Profil: {settings.get_gpu_profile()['name']}")
    logger.info(f"Ollama URL: {settings.ollama_base_url}")
    logger.info(f"Whisper-Modell: {settings.get_default_stt_model()}")
    logger.info(f"Whisper-Device: {settings.get_whisper_device()}")
    logger.info("=" * 60)

    # Optional: Whisper-Modell vorladen
    # await whisper_service.load_model()

    yield

    # Shutdown
    logger.info("Everlast AI Backend wird beendet...")
    whisper_service.unload_model()


# FastAPI App erstellen
app = FastAPI(
    title="Everlast AI Backend",
    description="Lokaler KI-Server für LLM-Generierung und Audio-Transkription",
    version="1.0.0",
    lifespan=lifespan,
)

# CORS konfigurieren - Standard: nur localhost für Sicherheit
# Für Zugriff von anderen Geräten: CORS_ORIGINS="http://192.168.1.100:3000"
cors_origins = (
    settings.cors_origins.split(",")
    if settings.cors_origins != "*"
    else ["http://localhost:3000", "http://127.0.0.1:3000", "http://localhost:8080"]
)
app.add_middleware(
    CORSMiddleware,
    allow_origins=cors_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# API-Router einbinden
app.include_router(router)


# Root-Endpoint
@app.get("/", tags=["Info"])
async def root():
    """API-Informationen."""
    return {
        "name": "Everlast AI Backend",
        "version": "1.0.0",
        "docs": "/docs",
        "health": "/health",
    }


def main():
    """Server starten."""
    logger.info(f"Starte Server auf {settings.host}:{settings.port}")
    uvicorn.run(
        "main:app",
        host=settings.host,
        port=settings.port,
        reload=False,
        log_level=settings.log_level.lower(),
    )


if __name__ == "__main__":
    main()
