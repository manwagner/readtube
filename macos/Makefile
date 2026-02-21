.PHONY: generate build run clean download-ytdlp

# Generate Xcode project from project.yml (requires xcodegen)
generate:
	xcodegen generate

# Download yt-dlp binary for bundling
download-ytdlp:
	@if [ ! -f Readtube/Resources/yt-dlp ]; then \
		echo "Downloading yt-dlp..."; \
		curl -L https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp_macos -o Readtube/Resources/yt-dlp; \
		chmod +x Readtube/Resources/yt-dlp; \
	else \
		echo "yt-dlp already downloaded"; \
	fi

# Build the app (requires Xcode)
build: download-ytdlp
	xcodebuild -project Readtube.xcodeproj -scheme Readtube -configuration Release -destination 'platform=macOS' build

# Open in Xcode
open:
	open Readtube.xcodeproj

# Clean build artifacts
clean:
	xcodebuild -project Readtube.xcodeproj -scheme Readtube clean 2>/dev/null || true
	rm -rf build/
