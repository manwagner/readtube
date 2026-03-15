"""Tests for genre detection and genre-specific prompt templates."""

import pytest

from readtube.genre import GENRES, detect_genre, get_genre_system_prompt, list_genres


class TestDetectGenreFromTitle:
    """Title keywords should be the primary detection signal."""

    def test_interview_keyword(self):
        assert detect_genre("My Interview with Elon Musk", "SomeChannel") == "interview"

    def test_podcast_keyword(self):
        assert detect_genre("Podcast #42: AI Safety", "SomeChannel") == "interview"

    def test_tutorial_keyword(self):
        assert detect_genre("Python Tutorial for Beginners", "SomeChannel") == "tutorial"

    def test_how_to_keyword(self):
        assert detect_genre("How to Build a REST API", "SomeChannel") == "tutorial"

    def test_step_by_step_keyword(self):
        assert detect_genre("Step by Step React Setup", "SomeChannel") == "tutorial"

    def test_lecture_keyword(self):
        assert detect_genre("Lecture 5: Quantum Mechanics", "SomeChannel") == "lecture"

    def test_course_keyword(self):
        assert detect_genre("Machine Learning Course - Week 3", "SomeChannel") == "lecture"

    def test_documentary_keyword(self):
        assert detect_genre("The Great Documentary on Mars", "SomeChannel") == "documentary"

    def test_investigative_keyword(self):
        assert detect_genre("Investigating the 2008 Crash", "SomeChannel") == "documentary"

    def test_deep_dive_keyword(self):
        assert detect_genre("A Deep Dive into Rust Ownership", "SomeChannel") == "documentary"

    def test_debate_keyword(self):
        assert detect_genre("The Great Debate on AI Risk", "SomeChannel") == "debate"

    def test_panel_keyword(self):
        assert detect_genre("Expert Panel: Future of Energy", "SomeChannel") == "debate"

    def test_discussion_keyword(self):
        assert detect_genre("A Discussion on Ethics", "SomeChannel") == "debate"

    def test_keynote_keyword(self):
        assert detect_genre("WWDC Keynote 2025", "SomeChannel") == "conference"

    def test_conference_keyword(self):
        assert detect_genre("Conference Presentation: New Findings", "SomeChannel") == "conference"

    def test_talk_keyword(self):
        assert detect_genre("My Talk at PyCon", "SomeChannel") == "conference"


class TestDetectGenreFromChannel:
    """Channel name patterns are the secondary signal."""

    def test_podcast_channel(self):
        assert detect_genre("Episode 99", "The Joe Rogan Podcast") == "interview"

    def test_academy_channel(self):
        assert detect_genre("Intro to Biology", "Khan Academy") == "lecture"

    def test_university_channel(self):
        assert detect_genre("CS50 Week 1", "Harvard University") == "lecture"


class TestDetectGenreFromDescription:
    """Description patterns are the tertiary signal."""

    def test_in_this_episode(self):
        assert detect_genre(
            "Episode 99", "SomeChannel",
            description="In this episode we sit down with the author",
        ) == "interview"

    def test_my_guest(self):
        assert detect_genre(
            "A Conversation", "SomeChannel",
            description="Today my guest is a Nobel laureate",
        ) == "interview"

    def test_in_this_tutorial(self):
        assert detect_genre(
            "Getting Started", "SomeChannel",
            description="In this tutorial we will build a CLI tool",
        ) == "tutorial"


class TestCaseInsensitive:
    """All matching should be case-insensitive."""

    def test_uppercase_title(self):
        assert detect_genre("INTERVIEW WITH THE CEO", "Channel") == "interview"

    def test_mixed_case_title(self):
        assert detect_genre("tUtOrIaL on Docker", "Channel") == "tutorial"

    def test_uppercase_channel(self):
        assert detect_genre("Ep 1", "THE PODCAST NETWORK") == "interview"

    def test_mixed_case_description(self):
        assert detect_genre(
            "Ep 1", "Channel",
            description="IN THIS EPISODE we discuss AI",
        ) == "interview"


class TestDefaultFallback:
    """When no patterns match, default to lecture."""

    def test_generic_title(self):
        assert detect_genre("Exploring the Universe", "NatGeo") == "lecture"

    def test_empty_strings(self):
        assert detect_genre("", "") == "lecture"

    def test_no_keywords(self):
        assert detect_genre("Something Random", "Random Channel", "no clues here") == "lecture"


class TestTitleWinsOverChannel:
    """Title signals should take priority over channel signals."""

    def test_tutorial_title_podcast_channel(self):
        assert detect_genre("Python Tutorial", "The Podcast Show") == "tutorial"

    def test_debate_title_university_channel(self):
        assert detect_genre("The Great Debate", "MIT University") == "debate"


class TestGetGenreSystemPrompt:
    """Each genre must have a corresponding system prompt."""

    @pytest.mark.parametrize("genre", GENRES)
    def test_all_genres_have_prompts(self, genre):
        prompt = get_genre_system_prompt(genre)
        assert isinstance(prompt, str)
        assert len(prompt) > 20

    def test_interview_prompt_content(self):
        prompt = get_genre_system_prompt("interview")
        assert "interview" in prompt.lower() or "podcast" in prompt.lower()
        assert "Speaker Name" in prompt

    def test_tutorial_prompt_content(self):
        prompt = get_genre_system_prompt("tutorial")
        assert "step" in prompt.lower()

    def test_unknown_genre_raises(self):
        with pytest.raises(KeyError):
            get_genre_system_prompt("nonexistent")


class TestListGenres:
    def test_returns_all_genres(self):
        result = list_genres()
        assert result == ["interview", "tutorial", "lecture", "documentary", "debate", "conference"]

    def test_returns_new_list(self):
        """Mutating the returned list should not affect the module."""
        result = list_genres()
        result.append("fake")
        assert "fake" not in list_genres()
