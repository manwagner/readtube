"""Tests for config module."""

import os
import tempfile
from pathlib import Path

import pytest
from readtube.config import (
    Config,
    LLMConfig,
    OutputConfig,
    CacheConfig,
    init_config,
    print_config,
    resolve_llm_config,
    DEFAULT_CONFIG_TOML,
)


class TestConfigDefaults:
    def test_default_config(self):
        config = Config()
        assert config.llm.backend is None
        assert config.output.default_format == "md"
        assert config.output.default_mode == "article"
        assert config.output.timestamps is False
        assert config.output.chapters is True
        assert config.cache.ttl_days == 30

    def test_cache_dir_has_default(self):
        config = Config()
        assert config.cache.dir != ""
        assert "readtube" in config.cache.dir


class TestConfigLoad:
    def test_load_missing_file(self):
        config = Config.load(Path("/nonexistent/config.toml"))
        assert config.llm.backend is None  # defaults

    def test_load_valid_toml(self):
        with tempfile.NamedTemporaryFile(mode="w", suffix=".toml", delete=False) as f:
            f.write("""
[llm]
backend = "claude"
model = "claude-sonnet-4-20250514"
api_key_env = "ANTHROPIC_API_KEY"

[output]
default_format = "epub"
default_mode = "tldr"
timestamps = true
chapters = false

[cache]
ttl_days = 7
""")
            f.flush()
            config = Config.load(Path(f.name))
            os.unlink(f.name)

        assert config.llm.backend == "claude"
        assert config.llm.model == "claude-sonnet-4-20250514"
        assert config.output.default_format == "epub"
        assert config.output.default_mode == "tldr"
        assert config.output.timestamps is True
        assert config.output.chapters is False
        assert config.cache.ttl_days == 7

    def test_load_partial_toml(self):
        with tempfile.NamedTemporaryFile(mode="w", suffix=".toml", delete=False) as f:
            f.write('[llm]\nbackend = "ollama"\n')
            f.flush()
            config = Config.load(Path(f.name))
            os.unlink(f.name)

        assert config.llm.backend == "ollama"
        assert config.output.default_format == "md"  # default preserved


class TestResolveLLMConfig:
    def test_cli_flags_take_precedence(self):
        config = Config()
        config.llm.backend = "ollama"
        config.llm.model = "llama3"

        backend, model, _ = resolve_llm_config(config, cli_backend="claude", cli_model="claude-opus-4-20250514")
        assert backend == "claude"
        assert model == "claude-opus-4-20250514"

    def test_config_file_used_when_no_flags(self):
        config = Config()
        config.llm.backend = "ollama"
        config.llm.model = "mistral"

        backend, model, _ = resolve_llm_config(config)
        assert backend == "ollama"
        assert model == "mistral"

    def test_env_var_override(self, monkeypatch):
        monkeypatch.setenv("READTUBE_BACKEND", "openai")
        monkeypatch.setenv("OPENAI_API_KEY", "test-key")
        config = Config()

        backend, model, _ = resolve_llm_config(config)
        assert backend == "openai"

    def test_api_key_from_env_name(self, monkeypatch):
        monkeypatch.setenv("MY_KEY", "sk-test")
        config = Config()
        config.llm.backend = "claude"
        config.llm.api_key_env = "MY_KEY"

        _, _, api_key = resolve_llm_config(config)
        assert api_key == "sk-test"

    def test_no_backend_raises(self, monkeypatch):
        # Clear all env vars that could auto-detect
        monkeypatch.delenv("ANTHROPIC_API_KEY", raising=False)
        monkeypatch.delenv("OPENAI_API_KEY", raising=False)
        monkeypatch.delenv("READTUBE_BACKEND", raising=False)
        # Mock auto-detect to return None (no Ollama running)
        import readtube.config as cfg
        monkeypatch.setattr(cfg, "_auto_detect_backend", lambda: None)
        config = Config()

        from readtube.errors import LLMError
        with pytest.raises(LLMError):
            resolve_llm_config(config)

    def test_default_models_per_backend(self):
        config = Config()
        config.llm.backend = "ollama"

        _, model, _ = resolve_llm_config(config)
        assert model == "llama3.2"

        config.llm.backend = "claude"
        _, model, _ = resolve_llm_config(config)
        assert model == "claude-sonnet-4-20250514"


class TestInitConfig:
    def test_creates_config_file(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            import readtube.config as cfg
            old_dir = cfg.CONFIG_DIR
            old_file = cfg.CONFIG_FILE
            try:
                cfg.CONFIG_DIR = Path(tmpdir) / "readtube"
                cfg.CONFIG_FILE = cfg.CONFIG_DIR / "config.toml"

                path = init_config()
                assert path.exists()
                content = path.read_text()
                assert "[llm]" in content
                assert "[output]" in content
                assert "[cache]" in content
            finally:
                cfg.CONFIG_DIR = old_dir
                cfg.CONFIG_FILE = old_file
