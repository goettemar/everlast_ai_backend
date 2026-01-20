"""
Everlast AI Backend - Konfiguration

Zentrale Konfiguration für lokales KI-Backend mit GPU-Profilen.
"""

from typing import Optional
from pydantic_settings import BaseSettings
from pydantic import Field


# GPU-Profile mit Modell-Empfehlungen
GPU_PROFILES = {
    "8gb": {
        "name": "8gb",
        "vram_gb": 8,
        "llm_models": ["llama3.2:3b", "phi3:mini", "gemma2:2b", "qwen2.5:3b"],
        "stt_models": ["small", "medium"],
        "recommended_llm": "llama3.2:3b",
        "recommended_stt": "medium",
    },
    "16gb": {
        "name": "16gb",
        "vram_gb": 16,
        "llm_models": ["llama3.2:8b", "mistral:7b", "gemma2:9b", "qwen2.5:7b", "phi3:medium"],
        "stt_models": ["medium", "large-v3"],
        "recommended_llm": "llama3.2:8b",
        "recommended_stt": "large-v3",
    },
    "24gb": {
        "name": "24gb",
        "vram_gb": 24,
        "llm_models": [
            "llama3.1:70b-q4",
            "mixtral:8x7b",
            "qwen2.5:32b",
            "codellama:34b",
            "deepseek-coder:33b",
        ],
        "stt_models": ["large-v3"],
        "recommended_llm": "llama3.1:70b-q4",
        "recommended_stt": "large-v3",
    },
    "cpu": {
        "name": "cpu",
        "vram_gb": 0,
        "llm_models": ["llama3.2:1b", "phi3:mini", "gemma2:2b"],
        "stt_models": ["tiny", "base", "small"],
        "recommended_llm": "llama3.2:1b",
        "recommended_stt": "small",
    },
}


def detect_gpu_profile() -> str:
    """Automatische GPU-Erkennung und Profil-Auswahl."""
    try:
        import pynvml

        pynvml.nvmlInit()
        handle = pynvml.nvmlDeviceGetHandleByIndex(0)
        info = pynvml.nvmlDeviceGetMemoryInfo(handle)
        vram_gb = info.total // (1024**3)
        pynvml.nvmlShutdown()

        if vram_gb >= 24:
            return "24gb"
        elif vram_gb >= 16:
            return "16gb"
        elif vram_gb >= 8:
            return "8gb"
        else:
            return "cpu"
    except Exception:
        return "cpu"


class Settings(BaseSettings):
    """Backend-Konfiguration mit Environment-Variable Support."""

    # Server
    # 0.0.0.0 ist bewusst gewählt für Zugriff von anderen Geräten im lokalen Netzwerk
    host: str = Field(default="0.0.0.0", alias="BACKEND_HOST")  # nosec B104
    port: int = Field(default=8080, alias="BACKEND_PORT")

    # Ollama
    ollama_base_url: str = Field(
        default="http://localhost:11434", alias="OLLAMA_BASE_URL"
    )
    ollama_timeout: float = Field(default=120.0, alias="OLLAMA_TIMEOUT")
    ollama_default_model: Optional[str] = Field(
        default=None, alias="OLLAMA_DEFAULT_MODEL"
    )

    # Whisper
    whisper_model: Optional[str] = Field(default=None, alias="WHISPER_MODEL")
    whisper_device: str = Field(default="auto", alias="WHISPER_DEVICE")
    whisper_compute_type: str = Field(default="auto", alias="WHISPER_COMPUTE_TYPE")

    # GPU
    gpu_profile: str = Field(default="auto", alias="GPU_PROFILE")

    # Logging
    log_level: str = Field(default="INFO", alias="LOG_LEVEL")

    # CORS
    cors_origins: str = Field(default="*", alias="CORS_ORIGINS")

    class Config:
        env_file = ".env"
        env_file_encoding = "utf-8"
        extra = "ignore"

    def get_gpu_profile(self) -> dict:
        """Gibt das aktive GPU-Profil zurück."""
        profile_name = self.gpu_profile
        if profile_name == "auto":
            profile_name = detect_gpu_profile()
        return GPU_PROFILES.get(profile_name, GPU_PROFILES["cpu"])

    def get_default_llm_model(self) -> str:
        """Gibt das empfohlene LLM-Modell für das aktive Profil zurück."""
        if self.ollama_default_model:
            return self.ollama_default_model
        return self.get_gpu_profile()["recommended_llm"]

    def get_default_stt_model(self) -> str:
        """Gibt das empfohlene STT-Modell für das aktive Profil zurück."""
        if self.whisper_model:
            return self.whisper_model
        return self.get_gpu_profile()["recommended_stt"]

    def get_whisper_device(self) -> str:
        """Bestimmt das Device für Whisper."""
        if self.whisper_device != "auto":
            return self.whisper_device

        profile = self.get_gpu_profile()
        return "cuda" if profile["vram_gb"] > 0 else "cpu"

    def get_whisper_compute_type(self) -> str:
        """Bestimmt den Compute-Type für Whisper.

        Hinweis: int8_float16 wird von vielen GPUs nicht unterstützt,
        daher verwenden wir float16 als sicherere Alternative.
        """
        if self.whisper_compute_type != "auto":
            return self.whisper_compute_type

        profile = self.get_gpu_profile()
        if profile["vram_gb"] >= 8:
            # float16 ist sicherer und wird von allen CUDA-GPUs unterstützt
            return "float16"
        else:
            # CPU: int8 für bessere Performance
            return "int8"


# Global settings instance
settings = Settings()


def get_settings() -> Settings:
    """Get the current settings instance."""
    return settings
