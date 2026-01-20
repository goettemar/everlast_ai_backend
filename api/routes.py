"""
Everlast AI Backend - API Routes

REST-API Endpoints für LLM-Generierung und STT-Transkription.
"""

import logging
from typing import Optional

from fastapi import APIRouter, UploadFile, File, Form, HTTPException

from config import settings, GPU_PROFILES
from models.schemas import (
    GenerateRequest,
    GenerateResponse,
    TranscribeResponse,
    HealthResponse,
    ModelInfo,
    GPUProfile,
)
from services.ollama_service import ollama_service
from services.whisper_service import whisper_service

logger = logging.getLogger(__name__)

router = APIRouter()


# ============================================================================
# Health & Info Endpoints
# ============================================================================


@router.get("/health", response_model=HealthResponse, tags=["Health"])
async def health_check():
    """
    Health-Check mit Status aller Komponenten.

    Gibt Informationen über:
    - Server-Status
    - Aktives GPU-Profil
    - Ollama-Verfügbarkeit und Modelle
    - Whisper-Status
    """
    profile = settings.get_gpu_profile()
    ollama_available = await ollama_service.is_available()
    ollama_models = []

    if ollama_available:
        ollama_models = await ollama_service.list_model_names()

    return HealthResponse(
        status="ok",
        version="1.0.0",
        gpu_profile=profile["name"],
        ollama_available=ollama_available,
        ollama_models=ollama_models,
        whisper_available=whisper_service.is_loaded,
        whisper_model=whisper_service._loaded_model_size,
    )


@router.get("/api/v1/gpu-profiles", response_model=list[GPUProfile], tags=["Config"])
async def list_gpu_profiles():
    """Liste aller verfügbaren GPU-Profile mit Modell-Empfehlungen."""
    profiles = []
    for name, data in GPU_PROFILES.items():
        profiles.append(
            GPUProfile(
                name=name,
                vram_gb=data["vram_gb"],
                recommended_llm=data["recommended_llm"],
                recommended_stt=data["recommended_stt"],
                available_llm_models=data["llm_models"],
                available_stt_models=data["stt_models"],
            )
        )
    return profiles


@router.get("/api/v1/models", response_model=list[ModelInfo], tags=["Models"])
async def list_models():
    """Liste aller installierten Ollama-Modelle."""
    if not await ollama_service.is_available():
        raise HTTPException(
            status_code=503, detail="Ollama nicht erreichbar. Ist Ollama gestartet?"
        )

    return await ollama_service.list_models()


# ============================================================================
# LLM Generation Endpoints
# ============================================================================


@router.post("/api/v1/generate", response_model=GenerateResponse, tags=["LLM"])
async def generate_text(request: GenerateRequest):
    """
    Text-Generierung mit Ollama LLM.

    Verwendet das konfigurierte Standard-Modell oder ein explizit angegebenes.
    """
    if not await ollama_service.is_available():
        raise HTTPException(
            status_code=503, detail="Ollama nicht erreichbar. Ist Ollama gestartet?"
        )

    try:
        result = await ollama_service.generate(
            prompt=request.prompt,
            system_prompt=request.system_prompt,
            model=request.model,
            max_tokens=request.max_tokens,
            temperature=request.temperature,
        )
        return result

    except Exception as e:
        logger.error(f"Generierungsfehler: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/api/v1/chat", response_model=GenerateResponse, tags=["LLM"])
async def chat_completion(
    messages: list[dict],
    model: Optional[str] = None,
    max_tokens: int = 2048,
    temperature: float = 0.7,
):
    """
    Chat-Completion im OpenAI-kompatiblen Format.

    Erwartet eine Liste von Messages mit "role" und "content".
    """
    if not await ollama_service.is_available():
        raise HTTPException(
            status_code=503, detail="Ollama nicht erreichbar. Ist Ollama gestartet?"
        )

    try:
        result = await ollama_service.generate_chat(
            messages=messages,
            model=model,
            max_tokens=max_tokens,
            temperature=temperature,
        )
        return result

    except Exception as e:
        logger.error(f"Chat-Fehler: {e}")
        raise HTTPException(status_code=500, detail=str(e))


# ============================================================================
# STT Transcription Endpoints
# ============================================================================


@router.post("/api/v1/transcribe", response_model=TranscribeResponse, tags=["STT"])
async def transcribe_audio(
    audio: UploadFile = File(..., description="Audio-Datei zur Transkription"),
    language: str = Form(default="de", description="Sprache (ISO 639-1)"),
    model: Optional[str] = Form(default=None, description="Whisper-Modell"),
):
    """
    Audio-Transkription mit faster-whisper.

    Unterstützte Formate: webm, wav, mp3, ogg, flac, m4a
    """
    # Modell bei Bedarf wechseln
    if model and model != whisper_service.model_size:
        whisper_service._model_size = model
        whisper_service.unload_model()

    try:
        # Audio-Daten lesen
        audio_data = await audio.read()
        mime_type = audio.content_type or "audio/webm"

        logger.info(
            f"Transkribiere: {audio.filename}, "
            f"{len(audio_data)} bytes, {mime_type}"
        )

        # Transkription durchführen
        result = await whisper_service.transcribe(
            audio_data=audio_data,
            language=language,
            mime_type=mime_type,
        )

        return result

    except Exception as e:
        logger.error(f"Transkriptionsfehler: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/api/v1/whisper/load", tags=["STT"])
async def load_whisper_model(
    model: str = Form(default=None, description="Modell-Größe (tiny, base, small, medium, large-v3)"),
):
    """
    Whisper-Modell vorladen.

    Nützlich um das Modell beim Start zu laden, damit die erste Transkription
    schneller ist.
    """
    if model:
        whisper_service._model_size = model

    try:
        await whisper_service.load_model()
        return {
            "status": "ok",
            "model": whisper_service._loaded_model_size,
            "device": whisper_service.device,
            "compute_type": whisper_service.compute_type,
        }
    except Exception as e:
        logger.error(f"Fehler beim Laden des Modells: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/api/v1/whisper/unload", tags=["STT"])
async def unload_whisper_model():
    """Whisper-Modell entladen (GPU-Speicher freigeben)."""
    whisper_service.unload_model()
    return {"status": "ok", "message": "Modell entladen"}
