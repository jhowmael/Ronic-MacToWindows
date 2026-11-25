.PHONY: help build dev app universal icons install reset-permission clean

help:
	@echo "make build             - compile in release mode (swift build)"
	@echo "make dev               - run from the terminal (swift run) — permission goes to Terminal/your IDE"
	@echo "make app               - build dist/RonicMacToWindows.app and the .zip for GitHub Releases"
	@echo "make universal         - same as 'make app', universal binary (requires full Xcode)"
	@echo "make install           - build the app and copy it to /Applications"
	@echo "make icons             - regenerate the logo, branding/logo.png and Resources/AppIcon.icns"
	@echo "make reset-permission  - remove the app's Accessibility entry (use if the toggle is on but not applied)"
	@echo "make clean             - remove build artifacts"

build:
	swift build -c release

dev:
	swift run -c release RonicMacToWindows

app:
	./scripts/package-macos.sh

universal:
	UNIVERSAL=1 ./scripts/package-macos.sh

install: app
	-osascript -e 'quit app "RonicMacToWindows"' 2>/dev/null
	rm -rf /Applications/RonicMacToWindows.app
	cp -R dist/RonicMacToWindows.app /Applications/
	@echo "Installed at /Applications/RonicMacToWindows.app"

icons:
	./branding/make-icons.sh

reset-permission:
	tccutil reset Accessibility io.github.jhowmael.ronicmactowindows

clean:
	rm -rf .build build dist branding/out
