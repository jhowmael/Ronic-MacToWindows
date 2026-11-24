import AppKit
import Carbon

/// Layouts de pontuação estilo Windows que acompanham o app (Resources/Layouts/*.keylayout,
/// gerados por scripts/make-layouts.swift).
enum WindowsLayout: String, CaseIterable {
    case abnt2 = "Ronic ABNT2 (Windows)"
    case usInternational = "Ronic US Internacional (Windows)"
    case us = "Ronic US (Windows)"

    /// Nome do arquivo e também o nome com que o macOS lista a fonte de entrada.
    var fileName: String { rawValue }

    var title: String {
        switch self {
        case .abnt2: return "ABNT2 (Windows)"
        case .usInternational: return "US Internacional (Windows)"
        case .us: return "US (Windows)"
        }
    }

    var hint: String {
        switch self {
        case .abnt2: return "Teclado brasileiro com Ç: ~ ´ ` ^ ¨ e AltGr iguais ao Windows"
        case .usInternational: return "Teclado americano: ' + c = ç, \" + u = ü, AltGr do Windows"
        case .us: return "Teclado americano sem acentos, igual ao Windows"
        }
    }
}

/// Instala e ativa os layouts. A troca vale para o sistema inteiro (é uma fonte de entrada do
/// macOS), então acentos e teclas mortas funcionam nativamente, sem passar pelo event tap.
/// Tudo aqui roda na thread principal (exigência das APIs TIS).
@MainActor
enum KeyboardLayoutManager {
    private static let previousSourceKey = "previousInputSourceID"

    private static var installDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Keyboard Layouts", isDirectory: true)
    }

    private static func bundledURL(_ layout: WindowsLayout) -> URL? {
        Bundle.main.url(forResource: layout.fileName, withExtension: "keylayout", subdirectory: "Layouts")
            ?? Bundle.main.url(forResource: layout.fileName, withExtension: "keylayout")
    }

    /// Nome da fonte de entrada (layout) em uso agora.
    static var currentSourceName: String? {
        guard let source = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue() else { return nil }
        return string(source, kTISPropertyLocalizedName)
    }

    static var currentWindowsLayout: WindowsLayout? {
        guard let name = currentSourceName else { return nil }
        return WindowsLayout(rawValue: name)
    }

    /// Layout que estava em uso antes de ativarmos um dos nossos (para o "Voltar para…").
    static var previousSourceName: String? {
        guard let id = UserDefaults.standard.string(forKey: previousSourceKey),
              let source = findSource(id: id) else { return nil }
        return string(source, kTISPropertyLocalizedName)
    }

    enum ActivationError: Error, LocalizedError {
        case missingResource, installFailed(Error), notRegistered
        var errorDescription: String? {
            switch self {
            case .missingResource: return "O arquivo do layout não foi encontrado dentro do app."
            case .installFailed(let e): return "Não foi possível instalar o layout: \(e.localizedDescription)"
            case .notRegistered: return "O macOS ainda não reconheceu o layout. Encerre a sessão e entre de novo, depois escolha o layout outra vez."
            }
        }
    }

    /// Copia o layout para ~/Library/Keyboard Layouts (se preciso), registra, habilita e seleciona.
    static func activate(_ layout: WindowsLayout) throws {
        guard let source = bundledURL(layout) else { throw ActivationError.missingResource }
        let destination = installDirectory.appendingPathComponent(layout.fileName + ".keylayout")
        do {
            try FileManager.default.createDirectory(at: installDirectory, withIntermediateDirectories: true)
            if FileManager.default.contentsEqual(atPath: source.path, andPath: destination.path) == false {
                try? FileManager.default.removeItem(at: destination)
                try FileManager.default.copyItem(at: source, to: destination)
            }
        } catch {
            throw ActivationError.installFailed(error)
        }

        // Guarda o layout atual para poder voltar (se ele não for um dos nossos).
        if currentWindowsLayout == nil,
           let current = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
           let id = string(current, kTISPropertyInputSourceID) {
            UserDefaults.standard.set(id, forKey: previousSourceKey)
        }

        TISRegisterInputSource(destination as CFURL)
        guard let input = findSource(name: layout.fileName) else { throw ActivationError.notRegistered }
        TISEnableInputSource(input)
        TISSelectInputSource(input)
    }

    /// Volta para o layout em uso antes do primeiro "ativar".
    static func restorePrevious() {
        guard let id = UserDefaults.standard.string(forKey: previousSourceKey),
              let source = findSource(id: id) else { return }
        TISSelectInputSource(source)
    }

    static func openInputSourceSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.Keyboard-Settings.extension") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - TIS helpers

    private static func allLayouts() -> [TISInputSource] {
        let filter = [kTISPropertyInputSourceType as String: kTISTypeKeyboardLayout as String] as CFDictionary
        return (TISCreateInputSourceList(filter, true)?.takeRetainedValue() as? [TISInputSource]) ?? []
    }

    private static func findSource(name: String) -> TISInputSource? {
        allLayouts().first { string($0, kTISPropertyLocalizedName) == name }
    }

    private static func findSource(id: String) -> TISInputSource? {
        let filter = [kTISPropertyInputSourceID as String: id] as CFDictionary
        return (TISCreateInputSourceList(filter, true)?.takeRetainedValue() as? [TISInputSource])?.first
    }

    private static func string(_ source: TISInputSource, _ key: CFString) -> String? {
        guard let ptr = TISGetInputSourceProperty(source, key) else { return nil }
        return Unmanaged<CFString>.fromOpaque(ptr).takeUnretainedValue() as String
    }
}
