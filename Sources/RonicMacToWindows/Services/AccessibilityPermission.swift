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
