"""
Everlast AI Backend - Request/Response Schemas
"""

from pydantic import BaseModel, Field
from typing import Optional


class GenerateRequest(BaseModel):
    """Request für LLM Text-Generierung."""

    prompt: str = Field(..., description="User-Prompt für die Generierung")
    system_prompt: Optional[str] = Field(None, description="Optionaler System-Prompt")
    model: Optional[str] = Field(None, description="Modell-ID (Default aus Config)")
    max_tokens: int = Field(2048, ge=1, le=8192, description="Max Tokens in Antwort")
    temperature: float = Field(0.7, ge=0.0, le=2.0, description="Sampling Temperature")


class GenerateResponse(BaseModel):
    """Response von LLM Text-Generierung."""

    text: str = Field(..., description="Generierter Text")
    model: str = Field(..., description="Verwendetes Modell")
    tokens_used: Optional[int] = Field(None, description="Verbrauchte Tokens")
    eval_duration_ms: Optional[int] = Field(None, description="Generierungszeit in ms")


class TranscribeResponse(BaseModel):
    """Response von Audio-Transkription."""

    text: str = Field(..., description="Transkribierter Text")
    duration: Optional[float] = Field(None, description="Audio-Dauer in Sekunden")
    language: Optional[str] = Field(None, description="Erkannte Sprache")
    model: str = Field(..., description="Verwendetes Whisper-Modell")


class ModelInfo(BaseModel):
    """Informationen über ein verfügbares Modell."""

    name: str = Field(..., description="Modell-Name")
    size: Optional[str] = Field(None, description="Modell-Größe (z.B. '3B', '8B')")
    modified_at: Optional[str] = Field(None, description="Letzte Änderung")
    digest: Optional[str] = Field(None, description="Modell-Digest/Hash")


class GPUProfile(BaseModel):
    """GPU-Profil mit Modell-Empfehlungen."""

    name: str = Field(..., description="Profil-Name (z.B. '8gb', '16gb')")
    vram_gb: int = Field(..., description="VRAM in GB")
    recommended_llm: str = Field(..., description="Empfohlenes LLM-Modell")
    recommended_stt: str = Field(..., description="Empfohlenes STT-Modell")
    available_llm_models: list[str] = Field(..., description="Kompatible LLM-Modelle")
    available_stt_models: list[str] = Field(..., description="Kompatible STT-Modelle")


class HealthResponse(BaseModel):
    """Health-Check Response."""

    status: str = Field(..., description="Server-Status")
    version: str = Field(..., description="API-Version")
    gpu_profile: str = Field(..., description="Aktives GPU-Profil")
    ollama_available: bool = Field(..., description="Ollama erreichbar")
    ollama_models: list[str] = Field(default_factory=list, description="Verfügbare LLM-Modelle")
    whisper_available: bool = Field(..., description="Whisper geladen")
    whisper_model: Optional[str] = Field(None, description="Aktives Whisper-Modell")
