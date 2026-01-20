"""
Everlast AI Backend - Services
"""

from services.ollama_service import OllamaService, ollama_service
from services.whisper_service import WhisperService, whisper_service

__all__ = [
    "OllamaService",
    "ollama_service",
    "WhisperService",
    "whisper_service",
]
