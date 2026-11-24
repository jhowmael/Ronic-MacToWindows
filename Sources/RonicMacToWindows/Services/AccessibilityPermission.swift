import AppKit
import ApplicationServices

/// Permissão de Acessibilidade (necessária para um CGEventTap que modifica eventos).
enum AccessibilityPermission {
    static var isTrusted: Bool { AXIsProcessTrusted() }

    /// Mostra o alerta do sistema que leva aos Ajustes (só aparece se ainda não autorizado).
    static func requestPrompt() {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    /// Remove a entrada do app em Ajustes › Acessibilidade (`tccutil reset`, não precisa de admin).
    /// Necessário depois de atualizar: a chave antiga aparece ligada, mas o macOS a amarrou à
    /// assinatura do binário anterior e não a aplica ao novo.
    @discardableResult
    static func resetEntry() -> Bool {
        guard let id = Bundle.main.bundleIdentifier else { return false }
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/tccutil")
        task.arguments = ["reset", "Accessibility", id]
        task.standardOutput = FileHandle.nullDevice
        task.standardError = FileHandle.nullDevice
        do {
            try task.run()
            task.waitUntilExit()
            return task.terminationStatus == 0
        } catch {
            return false
        }
    }

    static func openSystemSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }

    /// O sistema publica esta notificação quando a lista de apps autorizados muda.
    /// Ela chega um pouco antes de a mudança valer, por isso o handler é chamado com atraso.
    static func observeChanges(_ handler: @escaping () -> Void) -> NSObjectProtocol {
        DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("com.apple.accessibility.api"),
            object: nil,
            queue: .main
        ) { _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: handler)
        }
    }
}
