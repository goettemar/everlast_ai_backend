"""
Everlast AI Backend - Whisper Service

faster-whisper basierter STT-Service für lokale Audio-Transkription.
"""

import logging
import tempfile
import asyncio
from pathlib import Path
from typing import Optional
from concurrent.futures import ThreadPoolExecutor

from config import settings
from models.schemas import TranscribeResponse

logger = logging.getLogger(__name__)

# Thread-Pool für CPU-intensive Whisper-Operationen
_executor = ThreadPoolExecutor(max_workers=2)


class WhisperService:
    """Service für lokale Whisper-Transkription mit faster-whisper."""

    # Verfügbare Modelle
    AVAILABLE_MODELS = ["tiny", "base", "small", "medium", "large-v2", "large-v3"]

    def __init__(
        self,
        model_size: str | None = None,
        device: str | None = None,
        compute_type: str | None = None,
    ):
        self._model_size = model_size
        self._device = device
        self._compute_type = compute_type
        self._model = None
        self._loaded_model_size: str | None = None

    @property
    def model_size(self) -> str:
        """Aktive Modellgröße."""
        return self._model_size or settings.get_default_stt_model()

    @property
    def device(self) -> str:
        """Zielgerät (cuda/cpu)."""
        return self._device or settings.get_whisper_device()

    @property
    def compute_type(self) -> str:
        """Compute-Type für Inferenz."""
        return self._compute_type or settings.get_whisper_compute_type()

    @property
    def is_loaded(self) -> bool:
        """Prüft ob ein Modell geladen ist."""
        return self._model is not None

    def _load_model(self):
        """Lädt das Whisper-Modell (synchron, für Thread-Pool)."""
        if self._model is not None and self._loaded_model_size == self.model_size:
            return

        try:
            from faster_whisper import WhisperModel

            logger.info(
                f"Lade Whisper-Modell: {self.model_size} "
                f"(device={self.device}, compute_type={self.compute_type})"
            )

            self._model = WhisperModel(
                self.model_size,
                device=self.device,
                compute_type=self.compute_type,
            )
            self._loaded_model_size = self.model_size

            logger.info(f"Whisper-Modell '{self.model_size}' erfolgreich geladen")

        except Exception as e:
            logger.error(f"Fehler beim Laden des Whisper-Modells: {e}")
            raise

    async def load_model(self):
        """Lädt das Modell asynchron."""
        loop = asyncio.get_event_loop()
        await loop.run_in_executor(_executor, self._load_model)

    def _transcribe_sync(
        self,
        audio_path: str,
        language: str = "de",
    ) -> TranscribeResponse:
        """Synchrone Transkription (für Thread-Pool)."""
        self._load_model()

        logger.info(f"Transkribiere: {audio_path}, Sprache: {language}")

        # Transkription durchführen
        segments, info = self._model.transcribe(
            audio_path,
            language=language,
            beam_size=5,
            vad_filter=True,  # Voice Activity Detection
        )

        # Segmente zusammenführen
        text_parts = []
        for segment in segments:
            text_parts.append(segment.text.strip())

        text = " ".join(text_parts)

        logger.info(
            f"Transkription abgeschlossen: {len(text)} Zeichen, "
            f"Dauer: {info.duration:.1f}s, Sprache: {info.language}"
        )

        return TranscribeResponse(
            text=text,
            duration=info.duration,
            language=info.language,
            model=self._loaded_model_size or self.model_size,
        )

    async def transcribe(
        self,
        audio_data: bytes,
        language: str = "de",
        mime_type: str = "audio/webm",
    ) -> TranscribeResponse:
        """
        Transkribiere Audio-Daten.

        Args:
            audio_data: Raw Audio-Bytes
            language: Zielsprache (ISO 639-1)
            mime_type: MIME-Type der Audio-Daten

        Returns:
            TranscribeResponse mit transkribiertem Text
        """
        # Dateiendung aus MIME-Type ableiten
        ext_map = {
            "audio/webm": ".webm",
            "audio/wav": ".wav",
            "audio/wave": ".wav",
            "audio/mp3": ".mp3",
            "audio/mpeg": ".mp3",
            "audio/ogg": ".ogg",
            "audio/flac": ".flac",
            "audio/m4a": ".m4a",
            "audio/mp4": ".m4a",
        }
        extension = ext_map.get(mime_type, ".webm")

        # Temporäre Datei erstellen
        with tempfile.NamedTemporaryFile(suffix=extension, delete=False) as tmp:
            tmp.write(audio_data)
            tmp_path = Path(tmp.name)

        try:
            # Transkription im Thread-Pool ausführen
            loop = asyncio.get_event_loop()
            result = await loop.run_in_executor(
                _executor,
                self._transcribe_sync,
                str(tmp_path),
                language,
            )
            return result

        finally:
            # Temporäre Datei aufräumen
            tmp_path.unlink(missing_ok=True)

    async def transcribe_file(
        self,
        file_path: str,
        language: str = "de",
    ) -> TranscribeResponse:
        """Transkribiere eine Audio-Datei direkt."""
        loop = asyncio.get_event_loop()
        return await loop.run_in_executor(
            _executor,
            self._transcribe_sync,
            file_path,
            language,
        )

    def unload_model(self):
        """Gibt das Modell frei (Speicher freigeben)."""
        if self._model is not None:
            logger.info(f"Entlade Whisper-Modell: {self._loaded_model_size}")
            del self._model
            self._model = None
            self._loaded_model_size = None

            # GPU-Speicher freigeben
            try:
                import torch

                if torch.cuda.is_available():
                    torch.cuda.empty_cache()
            except ImportError:
                pass


# Global service instance
whisper_service = WhisperService()
