"""Tests for CLI argument parsing and routing."""

import pytest
from readtube.cli import main
from readtube.errors import EXIT_INVALID_ARGS


class TestCLIConfig:
    def test_config_prints(self, capsys):
        main(["config"])
        out = capsys.readouterr().out
        assert "[llm]" in out
        assert "[output]" in out
        assert "[cache]" in out

    def test_config_init(self, capsys, tmp_path, monkeypatch):
        import readtube.config as cfg
        monkeypatch.setattr(cfg, "CONFIG_DIR", tmp_path)
        monkeypatch.setattr(cfg, "CONFIG_FILE", tmp_path / "config.toml")

        main(["config", "--init"])
        assert (tmp_path / "config.toml").exists()


class TestCLICache:
    def test_cache_stats(self, capsys):
        main(["cache", "stats"])
        out = capsys.readouterr().out
        assert "cache dir" in out
        assert "entries" in out

    def test_cache_clear(self, capsys):
        main(["cache", "clear"])
        err = capsys.readouterr().err
        assert "cleared" in err


class TestCLIHelp:
    def test_no_args_shows_help(self, capsys):
        with pytest.raises(SystemExit) as exc_info:
            main([])
        assert exc_info.value.code == EXIT_INVALID_ARGS

    def test_help_flag(self, capsys):
        with pytest.raises(SystemExit) as exc_info:
            main(["--help"])
        assert exc_info.value.code == 0
        out = capsys.readouterr().out
        assert "readtube" in out
