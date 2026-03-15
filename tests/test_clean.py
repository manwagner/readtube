"""Tests for transcript cleaning module."""

from readtube.clean import (
    clean_transcript,
    deduplicate_stutters,
    normalize_whitespace,
    remove_filler,
    strip_artifacts,
)


# --- strip_artifacts ---


class TestStripArtifacts:
    def test_removes_music(self):
        assert strip_artifacts("hello [music] world") == "hello  world"

    def test_removes_music_capitalized(self):
        assert strip_artifacts("hello [Music] world") == "hello  world"

    def test_removes_applause(self):
        assert strip_artifacts("[applause] thank you") == " thank you"

    def test_removes_applause_capitalized(self):
        assert strip_artifacts("[Applause] thanks") == " thanks"

    def test_removes_laughter(self):
        assert strip_artifacts("funny [laughter] right") == "funny  right"

    def test_removes_laughter_capitalized(self):
        assert strip_artifacts("ha [Laughter] ha") == "ha  ha"

    def test_removes_multiple_artifacts(self):
        text = "[Music] hello [applause] world [laughter]"
        assert strip_artifacts(text) == " hello  world "

    def test_no_artifacts(self):
        assert strip_artifacts("just normal text") == "just normal text"

    def test_empty_string(self):
        assert strip_artifacts("") == ""

    def test_removes_unknown_bracket_annotation(self):
        assert strip_artifacts("text [Foreign Language] more") == "text  more"


# --- remove_filler ---


class TestRemoveFiller:
    def test_removes_uh(self):
        assert "uh" not in remove_filler("so uh we went there").lower()

    def test_removes_um(self):
        assert "um" not in remove_filler("um I think so").lower()

    def test_removes_uh_capitalized(self):
        assert "Uh" not in remove_filler("Uh that was cool")

    def test_removes_um_capitalized(self):
        assert "Um" not in remove_filler("Um let me think")

    def test_removes_you_know(self):
        result = remove_filler("it's you know really hard")
        assert "you know" not in result.lower()

    def test_removes_you_know_capitalized(self):
        result = remove_filler("You know what I think")
        assert "You know" not in result

    def test_removes_i_mean(self):
        result = remove_filler("I mean it's fine")
        assert "I mean" not in result

    def test_removes_sort_of(self):
        result = remove_filler("it sort of works")
        assert "sort of" not in result.lower()

    def test_removes_kind_of(self):
        result = remove_filler("it's kind of tricky")
        assert "kind of" not in result.lower()

    def test_removes_basically(self):
        result = remove_filler("so basically we need to")
        assert "basically" not in result.lower()

    def test_basically_in_sentence(self):
        # "basically" is filler in most contexts, so it gets removed.
        result = remove_filler("this is basically a function that computes")
        assert "basically" not in result.lower()

    def test_preserves_like_in_meaningful_use(self):
        # "like" meaning "enjoy" or "similar to" should be preserved.
        assert "like" in remove_filler("I like pizza")
        assert "like" in remove_filler("it looks like rain")

    def test_removes_duplicate_like(self):
        result = remove_filler("it's like like really good")
        assert "like like" not in result

    def test_no_filler(self):
        text = "The algorithm processes each element in constant time."
        assert remove_filler(text) == text

    def test_empty_string(self):
        assert remove_filler("") == ""

    def test_multiple_fillers(self):
        text = "so uh you know I mean it's um kind of hard"
        result = remove_filler(text)
        assert "uh" not in result.lower()
        assert "um" not in result.lower()
        assert "you know" not in result.lower()
        assert "I mean" not in result
        assert "kind of" not in result.lower()


# --- deduplicate_stutters ---


class TestDeduplicateStutters:
    def test_double_word(self):
        assert deduplicate_stutters("the the cat") == "the cat"

    def test_contraction_stutter(self):
        assert deduplicate_stutters("we're we're going") == "we're going"

    def test_triple_word(self):
        result = deduplicate_stutters("go go go now")
        assert result == "go now"

    def test_case_insensitive(self):
        result = deduplicate_stutters("The the cat")
        assert result == "The cat"

    def test_no_stutters(self):
        text = "everything is fine here"
        assert deduplicate_stutters(text) == text

    def test_empty_string(self):
        assert deduplicate_stutters("") == ""

    def test_multiple_stutters(self):
        text = "the the big big cat"
        result = deduplicate_stutters(text)
        assert result == "the big cat"


# --- normalize_whitespace ---


class TestNormalizeWhitespace:
    def test_collapse_multiple_spaces(self):
        assert normalize_whitespace("hello    world") == "hello world"

    def test_no_space_before_period(self):
        assert normalize_whitespace("hello .") == "hello."

    def test_no_space_before_comma(self):
        assert normalize_whitespace("hello ,world") == "hello, world"

    def test_no_space_before_question_mark(self):
        assert normalize_whitespace("really ?") == "really?"

    def test_space_after_period(self):
        assert normalize_whitespace("hello.world") == "hello. world"

    def test_space_after_comma(self):
        assert normalize_whitespace("one,two") == "one, two"

    def test_strips_leading_trailing(self):
        assert normalize_whitespace("  hello  ") == "hello"

    def test_empty_string(self):
        assert normalize_whitespace("") == ""

    def test_already_clean(self):
        text = "Hello, world. How are you?"
        assert normalize_whitespace(text) == text

    def test_tabs_collapsed(self):
        assert normalize_whitespace("hello\tworld") == "hello world"

    def test_combined_issues(self):
        text = "so   we went  , and   then .it was  great"
        result = normalize_whitespace(text)
        assert result == "so we went, and then. it was great"


# --- clean_transcript (full pipeline) ---


class TestCleanTranscript:
    def test_raw_passthrough(self):
        messy = "[Music] uh um  the the  hello  ."
        assert clean_transcript(messy, raw=True) == messy

    def test_empty_string(self):
        assert clean_transcript("") == ""

    def test_already_clean(self):
        text = "This is a perfectly clean transcript."
        assert clean_transcript(text) == text

    def test_full_pipeline_realistic(self):
        raw = (
            "[Music] so uh you know we're we're going to talk about "
            "um the the algorithm [applause] and uh it's kind of "
            "interesting because basically it runs in linear time ."
        )
        result = clean_transcript(raw)

        # Artifacts removed
        assert "[Music]" not in result
        assert "[applause]" not in result

        # Fillers removed
        assert " uh " not in result
        assert " um " not in result
        assert "you know" not in result
        assert "kind of" not in result
        assert "basically" not in result

        # Stutters resolved
        assert "we're we're" not in result
        assert "the the" not in result

        # Whitespace normalized
        assert "  " not in result
        assert result == result.strip()

        # Core content preserved
        assert "going to talk about" in result
        assert "algorithm" in result
        assert "interesting" in result
        assert "runs in linear time" in result

    def test_preserves_like_in_real_usage(self):
        text = "I like this approach and it looks like it works"
        result = clean_transcript(text)
        assert "like this approach" in result
        assert "looks like it works" in result

    def test_removes_like_filler(self):
        text = "it was like like really good"
        result = clean_transcript(text)
        assert "like like" not in result
        assert "really good" in result

    def test_mixed_case_artifacts(self):
        text = "[music] hello [MUSIC] there [Music] friend"
        result = clean_transcript(text)
        # All bracket annotations are removed regardless of case
        assert "[" not in result
        assert "]" not in result
        assert "hello" in result
        assert "there" in result

    def test_punctuation_fixed_after_removal(self):
        text = "so uh , we went uh ."
        result = clean_transcript(text)
        # No space before punctuation, no double spaces
        assert " ," not in result
        assert " ." not in result
        assert "  " not in result
