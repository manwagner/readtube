"""Tests for LLM module."""

import pytest
from readtube.llm import get_backend, BACKENDS, OllamaBackend, ClaudeBackend, OpenAIBackend
from readtube.errors import LLMError


class TestBackendRegistry:
    def test_all_backends_registered(self):
        assert "ollama" in BACKENDS
        assert "claude" in BACKENDS
        assert "openai" in BACKENDS

    def test_unknown_backend_raises(self):
        with pytest.raises(LLMError, match="unknown backend"):
            get_backend("nonexistent")


class TestOllamaBackend:
    def test_default_config(self):
        backend = OllamaBackend()
        assert backend.url == "http://localhost:11434"
        assert backend.model == "llama3.2"

    def test_custom_config(self):
        backend = OllamaBackend(url="http://myserver:11434", model="mistral")
        assert backend.url == "http://myserver:11434"
        assert backend.model == "mistral"


class TestClaudeBackend:
    def test_no_key_not_available(self):
        backend = ClaudeBackend(api_key=None)
        # Clear env
        import os
        old = os.environ.pop("ANTHROPIC_API_KEY", None)
        try:
            backend = ClaudeBackend(api_key=None)
            assert not backend.is_available()
        finally:
            if old:
                os.environ["ANTHROPIC_API_KEY"] = old

    def test_with_key_needs_anthropic(self):
        backend = ClaudeBackend(api_key="test-key")
        # May or may not have anthropic installed
        # Just verify it doesn't crash
        backend.is_available()


class TestOpenAIBackend:
    def test_local_server_check(self):
        backend = OpenAIBackend(url="http://localhost:9999")
        # Won't be available since nothing is running there
        assert not backend.is_available()

    def test_remote_with_key(self):
        backend = OpenAIBackend(api_key="test-key")
        assert backend.is_available()
