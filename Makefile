.PHONY: help build dev app universal icons layouts install reset-permission clean

help:
	@echo "make build             - compila em modo release (swift build)"
	@echo "make dev               - roda direto pelo terminal (swift run) — a permissão vai para o Terminal/IDE"
	@echo "make app               - gera dist/RonicMacToWindows.app e o .zip para o GitHub Releases"
	@echo "make universal         - igual a 'make app', binário universal (requer Xcode completo)"
	@echo "make install           - gera o app e copia para /Applications"
	@echo "make icons             - regenera o logo, branding/logo.png e Resources/AppIcon.icns"
	@echo "make layouts           - regenera Resources/Layouts/*.keylayout (pontuação estilo Windows)"
	@echo "make reset-permission  - apaga a permissão de Acessibilidade do app (use após recompilar)"
	@echo "make clean             - remove artefatos de build"

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
	@echo "Instalado em /Applications/RonicMacToWindows.app"

icons:
	./branding/make-icons.sh

layouts:
	swift scripts/make-layouts.swift Resources/Layouts

reset-permission:
	tccutil reset Accessibility io.github.jhowmael.ronicmactowindows

clean:
	rm -rf .build build dist branding/out
