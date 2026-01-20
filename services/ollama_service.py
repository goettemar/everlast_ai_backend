"""
Everlast AI Backend - Ollama Service

HTTP-Wrapper für die Ollama API zur LLM-Generierung.
"""

import logging
from typing import Optional

import httpx

from config import settings
from models.schemas import GenerateResponse, ModelInfo

logger = logging.getLogger(__name__)


class OllamaService:
    """Service für Ollama LLM-Interaktion."""

    def __init__(
        self,
        base_url: str | None = None,
        timeout: float | None = None,
        default_model: str | None = None,
    ):
        self.base_url = base_url or settings.ollama_base_url
        self.timeout = timeout or settings.ollama_timeout
        self._default_model = default_model
        self._client: httpx.AsyncClient | None = None

    @property
    def default_model(self) -> str:
        """Gibt das Standard-Modell zurück."""
        return self._default_model or settings.get_default_llm_model()

    def _get_client(self) -> httpx.AsyncClient:
        """Lazy-initialisiere den HTTP-Client."""
        if self._client is None:
            self._client = httpx.AsyncClient(
                base_url=self.base_url,
                timeout=self.timeout,
            )
        return self._client

    async def is_available(self) -> bool:
        """Prüft, ob Ollama erreichbar ist."""
        try:
            client = self._get_client()
            response = await client.get("/api/tags")
            return response.status_code == 200
        except Exception as e:
            logger.warning(f"Ollama nicht erreichbar: {e}")
            return False

    async def list_models(self) -> list[ModelInfo]:
        """Liste aller installierten Modelle."""
        try:
            client = self._get_client()
            response = await client.get("/api/tags")
            response.raise_for_status()
            data = response.json()

            models = []
            for m in data.get("models", []):
                # Modellgröße aus Name extrahieren (z.B. "llama3.2:8b" -> "8B")
                name = m.get("name", "")
                size = None
                if ":" in name:
                    size_part = name.split(":")[-1].upper()
                    if any(c.isdigit() for c in size_part):
                        size = size_part

                models.append(
                    ModelInfo(
                        name=name,
                        size=size,
                        modified_at=m.get("modified_at"),
                        digest=m.get("digest"),
                    )
                )

            return models
        except Exception as e:
            logger.error(f"Fehler beim Abrufen der Modelle: {e}")
            return []

    async def list_model_names(self) -> list[str]:
        """Liste aller Modellnamen (nur Namen)."""
        models = await self.list_models()
        return [m.name for m in models]

    async def generate(
        self,
        prompt: str,
        system_prompt: Optional[str] = None,
        model: Optional[str] = None,
        max_tokens: int = 2048,
        temperature: float = 0.7,
    ) -> GenerateResponse:
        """
        Generiere Text mit Ollama.

        Args:
            prompt: User-Prompt
            system_prompt: Optionaler System-Prompt
            model: Modell-ID (Default aus Config)
            max_tokens: Maximale Token-Anzahl
            temperature: Sampling-Temperatur

        Returns:
            GenerateResponse mit generiertem Text
        """
        model = model or self.default_model
        client = self._get_client()

        logger.info(f"Generiere mit Modell: {model}")

        # Request-Payload aufbauen
        payload = {
            "model": model,
            "prompt": prompt,
            "stream": False,
            "options": {
                "num_predict": max_tokens,
                "temperature": temperature,
            },
        }

        if system_prompt:
            payload["system"] = system_prompt

        # API-Aufruf
        response = await client.post("/api/generate", json=payload)
        response.raise_for_status()
        data = response.json()

        # Response parsen
        text = data.get("response", "")
        actual_model = data.get("model", model)
        eval_count = data.get("eval_count")
        eval_duration = data.get("eval_duration")

        # Dauer in ms konvertieren (Ollama gibt ns zurück)
        eval_duration_ms = None
        if eval_duration:
            eval_duration_ms = eval_duration // 1_000_000

        logger.info(
            f"Generierung abgeschlossen: {len(text)} Zeichen, "
            f"{eval_count or '?'} Tokens, {eval_duration_ms or '?'}ms"
        )

        return GenerateResponse(
            text=text,
            model=actual_model,
            tokens_used=eval_count,
            eval_duration_ms=eval_duration_ms,
        )

    async def generate_chat(
        self,
        messages: list[dict],
        model: Optional[str] = None,
        max_tokens: int = 2048,
        temperature: float = 0.7,
    ) -> GenerateResponse:
        """
        Chat-Completion mit Ollama (OpenAI-kompatibles Format).

        Args:
            messages: Liste von {"role": "...", "content": "..."} Dicts
            model: Modell-ID
            max_tokens: Maximale Token-Anzahl
            temperature: Sampling-Temperatur

        Returns:
            GenerateResponse
        """
        model = model or self.default_model
        client = self._get_client()

        logger.info(f"Chat mit Modell: {model}, {len(messages)} Messages")

        response = await client.post(
            "/api/chat",
            json={
                "model": model,
                "messages": messages,
                "stream": False,
                "options": {
                    "num_predict": max_tokens,
                    "temperature": temperature,
                },
            },
        )
        response.raise_for_status()
        data = response.json()

        # Response parsen
        message = data.get("message", {})
        text = message.get("content", "")
        actual_model = data.get("model", model)
        eval_count = data.get("eval_count")
        eval_duration = data.get("eval_duration")

        eval_duration_ms = None
        if eval_duration:
            eval_duration_ms = eval_duration // 1_000_000

        return GenerateResponse(
            text=text,
            model=actual_model,
            tokens_used=eval_count,
            eval_duration_ms=eval_duration_ms,
        )

    async def close(self):
        """Schließe den HTTP-Client."""
        if self._client:
            await self._client.aclose()
            self._client = None


# Global service instance
ollama_service = OllamaService()
