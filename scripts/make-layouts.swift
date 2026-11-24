// Gera os layouts de teclado "Windows" da Ronic MacToWindows (.keylayout).
//
//   swift scripts/make-layouts.swift [pasta-de-saída]     (padrão: Resources/Layouts)
//
// Como funciona:
//  * Letras, números, teclas especiais, keypad e as camadas Ctrl/⌘ vêm do layout equivalente
//    da Apple (já idênticos ao Windows), lidos com UCKeyTranslate.
//  * Por cima, aplicamos as regras do Windows, a partir das tabelas KBDBR.DLL / KBDUSX.DLL / KBDUS.DLL:
//      - teclas mortas, composições e o caractere ao apertar espaço (ex.: ~ + espaço = "~", não "˜");
//      - camada AltGr (Option) somente com os caracteres que o Windows produz; o resto não digita nada;
//      - Caps Lock + Shift + letra = minúscula, como no Windows.
//
// Os arquivos gerados são versionados no repositório; rode de novo só para mudar as regras.
import Carbon
import Foundation

let outDir = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "Resources/Layouts")
try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

// MARK: - Especificação dos layouts

struct DeadKey {
    let name: String
    let terminator: String          // saída de "tecla morta + espaço"
    let compositions: [String: String]
}

func compose(_ pairs: String) -> [String: String] {
    // "aá eé" → ["a": "á", "e": "é"]
    var d: [String: String] = [:]
    for pair in pairs.split(separator: " ") {
        let chars = Array(pair)
        d[String(chars[0])] = String(chars[1])
    }
    return d
}

struct LayoutSpec {
    let name: String
    let fileName: String
    let id: Int
    let appleSource: String
    /// (keyCode, shift) → tecla morta. Caps Lock usa a mesma da camada sem Shift.
    let deadKeys: [Int: DeadKey]
    let altGr: [UInt16: String]
    let altGrShift: [UInt16: String]
    /// Sobrescritas da camada base/shift (keyCode → (base, shift)).
    let baseOverrides: [UInt16: (String, String)]
}

func deadKeyIndex(_ code: UInt16, shift: Bool) -> Int { Int(code) * 2 + (shift ? 1 : 0) }

// Teclas mortas do Windows — KBDBR (ABNT/ABNT2)
let brAcute = DeadKey(name: "agudo", terminator: "´", compositions: compose("aá eé ií oó uú yý AÁ EÉ IÍ OÓ UÚ YÝ"))
let brGrave = DeadKey(name: "grave", terminator: "`", compositions: compose("aà eè iì oò uù AÀ EÈ IÌ OÒ UÙ"))
let brTilde = DeadKey(name: "til", terminator: "~", compositions: compose("aã oõ nñ AÃ OÕ NÑ"))
let brCirc = DeadKey(name: "circunflexo", terminator: "^", compositions: compose("aâ eê iî oô uû AÂ EÊ IÎ OÔ UÛ"))
let brTrema = DeadKey(name: "trema", terminator: "¨", compositions: compose("aä eë iï oö uü yÿ AÄ EË IÏ OÖ UÜ"))

// Teclas mortas do Windows — KBDUSX (US-International)
let usAcute = DeadKey(name: "acute", terminator: "'", compositions: compose("aá eé ií oó uú yý cç AÁ EÉ IÍ OÓ UÚ YÝ CÇ"))
let usUmlaut = DeadKey(name: "umlaut", terminator: "\"", compositions: compose("aä eë iï oö uü yÿ AÄ EË IÏ OÖ UÜ"))
let usGrave = DeadKey(name: "grave", terminator: "`", compositions: compose("aà eè iì oò uù AÀ EÈ IÌ OÒ UÙ"))
let usTilde = DeadKey(name: "tilde", terminator: "~", compositions: compose("aã oõ nñ AÃ OÕ NÑ"))
let usCirc = DeadKey(name: "circumflex", terminator: "^", compositions: compose("aâ eê iî oô uû AÂ EÊ IÎ OÔ UÛ"))

let layouts: [LayoutSpec] = [
    LayoutSpec(
        name: "Ronic ABNT2 (Windows)",
        fileName: "Ronic ABNT2 (Windows)",
        id: -23781,
        appleSource: "com.apple.keylayout.Brazilian-ABNT2",
        deadKeys: [
            deadKeyIndex(0x21, shift: false): brAcute,   // tecla ´ `
            deadKeyIndex(0x21, shift: true): brGrave,
            deadKeyIndex(0x27, shift: false): brTilde,   // tecla ~ ^
            deadKeyIndex(0x27, shift: true): brCirc,
            deadKeyIndex(0x16, shift: true): brTrema,    // Shift+6
        ],
        altGr: [
            0x12: "¹", 0x13: "²", 0x14: "³", 0x15: "£", 0x17: "¢", 0x16: "¬", 0x18: "§",
            0x0C: "/", 0x0D: "?", 0x0E: "°", 0x08: "₢",
            0x1E: "ª", 0x2A: "º", 0x5E: "°",
        ],
        altGrShift: [:],
        baseOverrides: [:]
    ),
    LayoutSpec(
        name: "Ronic US Internacional (Windows)",
        fileName: "Ronic US Internacional (Windows)",
        id: -23782,
        appleSource: "com.apple.keylayout.USInternational-PC",
        deadKeys: [
            deadKeyIndex(0x27, shift: false): usAcute,   // ' → á, ç
            deadKeyIndex(0x27, shift: true): usUmlaut,   // " → ü
            deadKeyIndex(0x32, shift: false): usGrave,   // `
            deadKeyIndex(0x32, shift: true): usTilde,    // ~
            deadKeyIndex(0x16, shift: true): usCirc,     // Shift+6
        ],
        altGr: [
            0x12: "¡", 0x13: "²", 0x14: "³", 0x15: "¤", 0x17: "€", 0x16: "¼", 0x1A: "½", 0x1C: "¾",
            0x19: "‘", 0x1D: "’", 0x1B: "¥", 0x18: "×",
            0x0C: "ä", 0x0D: "å", 0x0E: "é", 0x0F: "®", 0x11: "þ", 0x10: "ü", 0x20: "ú", 0x22: "í",
            0x1F: "ó", 0x23: "ö", 0x21: "«", 0x1E: "»",
            0x00: "á", 0x01: "ß", 0x02: "ð", 0x25: "ø", 0x29: "¶", 0x27: "´", 0x2A: "¬",
            0x06: "æ", 0x08: "©", 0x2D: "ñ", 0x2E: "µ", 0x2B: "ç", 0x2C: "¿",
        ],
        altGrShift: [
            0x12: "¹", 0x15: "£", 0x18: "÷",
            0x0C: "Ä", 0x0D: "Å", 0x0E: "É", 0x11: "Þ", 0x10: "Ü", 0x20: "Ú", 0x22: "Í", 0x1F: "Ó", 0x23: "Ö",
            0x00: "Á", 0x01: "§", 0x02: "Ð", 0x25: "Ø", 0x29: "°", 0x27: "¨", 0x2A: "¦",
            0x06: "Æ", 0x08: "¢", 0x2D: "Ñ", 0x2B: "Ç",
        ],
        baseOverrides: [0x0A: ("\\", "|")]   // tecla extra ISO (à esquerda do Z) = \ | como no Windows
    ),
    LayoutSpec(
        name: "Ronic US (Windows)",
        fileName: "Ronic US (Windows)",
        id: -23783,
        appleSource: "com.apple.keylayout.US",
        deadKeys: [:],
        altGr: [:],
        altGrShift: [:],
        baseOverrides: [0x0A: ("\\", "|")]
    ),
]

// MARK: - Leitura do layout da Apple

final class AppleLayout {
    let data: Data
    init(id: String) {
        let props = [kTISPropertyInputSourceID as String: id] as CFDictionary
        guard let list = TISCreateInputSourceList(props, true)?.takeRetainedValue() as? [TISInputSource],
              let source = list.first,
              let ptr = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else {
            fatalError("Layout da Apple não encontrado: \(id)")
        }
        data = Unmanaged<CFData>.fromOpaque(ptr).takeUnretainedValue() as Data
    }

    /// Saída da tecla; nil = tecla morta (no layout da Apple).
    func output(_ code: UInt16, _ carbonMods: Int) -> String? {
        data.withUnsafeBytes { raw -> String? in
            let layout = raw.baseAddress!.assumingMemoryBound(to: UCKeyboardLayout.self)
            var dead: UInt32 = 0
            var length = 0
            var buffer = [UniChar](repeating: 0, count: 8)
            UCKeyTranslate(layout, code, UInt16(kUCKeyActionDown), UInt32((carbonMods >> 8) & 0xFF),
                           40, 0, &dead, 8, &length, &buffer)
            if dead != 0 {
                // Tecla morta na Apple: usamos o caractere "solto" (morta + espaço).
                var length2 = 0
                var buffer2 = [UniChar](repeating: 0, count: 8)
                UCKeyTranslate(layout, 0x31, UInt16(kUCKeyActionDown), 0, 40, 0, &dead, 8, &length2, &buffer2)
                return String(utf16CodeUnits: buffer2, count: length2)
            }
            return String(utf16CodeUnits: buffer, count: length)
        }
    }
}

// MARK: - Geração do XML

func xmlEscape(_ s: String) -> String {
    var out = ""
    for scalar in s.unicodeScalars {
        switch scalar {
        case "&": out += "&#x0026;"
        case "<": out += "&#x003C;"
        case ">": out += "&#x003E;"
        case "\"": out += "&#x0022;"
        case "'": out += "&#x0027;"
        default:
            if scalar.value < 0x20 || scalar.value == 0x7F {
                out += String(format: "&#x%04X;", scalar.value)
            } else {
                out.unicodeScalars.append(scalar)
            }
        }
    }
    return out
}

func actionID(for char: String) -> String {
    "c" + char.unicodeScalars.map { String(format: "%04X", $0.value) }.joined()
}

/// Teclas que não digitam texto (setas, Return, Tab, Delete, F1…, keypad): repetidas em todas
/// as camadas, para ⌥←, ⌥⌫ etc. continuarem funcionando.
let keypadCodes: Set<UInt16> = [0x41, 0x43, 0x45, 0x47, 0x4B, 0x4C, 0x4E, 0x51, 0x52, 0x53, 0x54, 0x55,
                                0x56, 0x57, 0x58, 0x59, 0x5B, 0x5C, 0x5F]

func generate(_ spec: LayoutSpec) -> String {
    let apple = AppleLayout(id: spec.appleSource)
    let shift = shiftKey, caps = alphaLock, option = optionKey, cmd = cmdKey, control = controlKey

    enum Entry { case output(String), dead(DeadKey), none }

    func isSpecial(_ code: UInt16) -> Bool {
        if keypadCodes.contains(code) { return true }
        guard let s = apple.output(code, 0), let v = s.unicodeScalars.first?.value else { return false }
        return s.unicodeScalars.count == 1 && (v < 0x20 || v == 0x7F)
    }

    func printable(_ code: UInt16, shifted: Bool, capsLock: Bool) -> Entry {
        if let dk = spec.deadKeys[deadKeyIndex(code, shift: shifted)] { return .dead(dk) }
        if let o = spec.baseOverrides[code] {
            let base = o.0, sh = o.1
            return .output(shifted ? sh : base)
        }
        var mods = 0
        if shifted { mods |= shift }
        if capsLock { mods |= caps }
        let s = apple.output(code, mods) ?? ""
        return s.isEmpty ? .none : .output(s)
    }

    // As camadas (índice → função que dá a saída de cada tecla).
    var maps: [[UInt16: Entry]] = Array(repeating: [:], count: 9)
    for code in UInt16(0)...127 {
        let special = isSpecial(code)
        let base = printable(code, shifted: false, capsLock: false)
        let shifted = printable(code, shifted: true, capsLock: false)
        let capsOnly = printable(code, shifted: false, capsLock: true)

        maps[0][code] = base
        maps[1][code] = shifted
        maps[2][code] = capsOnly
        // Caps Lock + Shift: se o Caps altera a tecla (letra), volta à minúscula — regra do Windows.
        if case .output(let c) = capsOnly, case .output(let b) = base, c != b {
            maps[3][code] = base
        } else {
            maps[3][code] = shifted
        }
        // AltGr (Option): só o que o Windows define; teclas especiais e espaço seguem normais.
        let plain: Entry = special ? .output(apple.output(code, 0) ?? "") : (code == 0x31 ? .output(" ") : .none)
        maps[4][code] = spec.altGr[code].map { .output($0) } ?? plain
        maps[5][code] = spec.altGrShift[code].map { .output($0) } ?? plain
        // ⌘, ⌘⇧ e Ctrl: iguais aos da Apple (atalhos dependem disso).
        maps[6][code] = .output(apple.output(code, cmd) ?? "")
        maps[7][code] = .output(apple.output(code, cmd | shift) ?? "")
        maps[8][code] = .output(apple.output(code, control) ?? "")
        _ = option
    }

    // Caracteres que participam de composições (+ espaço) viram "actions".
    let deadKeys = Array(Set(spec.deadKeys.values.map { $0.name })).sorted().compactMap { name in
        spec.deadKeys.values.first { $0.name == name }
    }
    var composable: [String: [(state: String, output: String)]] = [" ": deadKeys.map { ($0.name, $0.terminator) }]
    for dk in deadKeys {
        for (from, to) in dk.compositions { composable[from, default: []].append((dk.name, to)) }
    }

    var xml = """
    <?xml version="1.1" encoding="UTF-8"?>
    <!DOCTYPE keyboard SYSTEM "file://localhost/System/Library/DTDs/KeyboardLayout.dtd">
    <!-- Gerado por scripts/make-layouts.swift (Ronic MacToWindows). Não edite à mão. -->
    <keyboard group="126" id="\(spec.id)" name="\(xmlEscape(spec.name))" maxout="2">
      <layouts>
        <layout first="0" last="255" modifiers="Modifiers" mapSet="Windows"/>
      </layouts>
      <modifierMap id="Modifiers" defaultIndex="0">
        <keyMapSelect mapIndex="0"><modifier keys=""/></keyMapSelect>
        <keyMapSelect mapIndex="1"><modifier keys="anyShift"/></keyMapSelect>
        <keyMapSelect mapIndex="2"><modifier keys="caps"/></keyMapSelect>
        <keyMapSelect mapIndex="3"><modifier keys="anyShift caps"/></keyMapSelect>
        <keyMapSelect mapIndex="4"><modifier keys="anyOption caps?"/></keyMapSelect>
        <keyMapSelect mapIndex="5"><modifier keys="anyShift anyOption caps?"/></keyMapSelect>
        <keyMapSelect mapIndex="6"><modifier keys="command anyOption? caps?"/></keyMapSelect>
        <keyMapSelect mapIndex="7"><modifier keys="anyShift command anyOption? caps?"/></keyMapSelect>
        <keyMapSelect mapIndex="8"><modifier keys="anyShift? caps? anyOption? command? anyControl"/></keyMapSelect>
      </modifierMap>
      <keyMapSet id="Windows">

    """
    for (index, map) in maps.enumerated() {
        xml += "    <keyMap index=\"\(index)\">\n"
        for code in UInt16(0)...127 {
            guard let entry = map[code] else { continue }
            switch entry {
            case .none:
                continue
            case .dead(let dk):
                xml += "      <key code=\"\(code)\" action=\"dead_\(dk.name)\"/>\n"
            case .output(let s):
                if s.isEmpty { continue }
                if index <= 3 || index == 4 || index == 5, composable[s] != nil {
                    xml += "      <key code=\"\(code)\" action=\"\(actionID(for: s))\"/>\n"
                } else {
                    xml += "      <key code=\"\(code)\" output=\"\(xmlEscape(s))\"/>\n"
                }
            }
        }
        xml += "    </keyMap>\n"
    }
    xml += "  </keyMapSet>\n  <actions>\n"

    // Teclas mortas: morta + morta = as duas soltas (Windows não compõe).
    for dk in deadKeys {
        xml += "    <action id=\"dead_\(dk.name)\">\n"
        xml += "      <when state=\"none\" next=\"\(dk.name)\"/>\n"
        for other in deadKeys {
            xml += "      <when state=\"\(other.name)\" output=\"\(xmlEscape(other.terminator + dk.terminator))\"/>\n"
        }
        xml += "    </action>\n"
    }
    for (char, states) in composable.sorted(by: { $0.key < $1.key }) {
        xml += "    <action id=\"\(actionID(for: char))\">\n"
        xml += "      <when state=\"none\" output=\"\(xmlEscape(char))\"/>\n"
        for st in states.sorted(by: { $0.state < $1.state }) {
            xml += "      <when state=\"\(st.state)\" output=\"\(xmlEscape(st.output))\"/>\n"
        }
        xml += "    </action>\n"
    }
    xml += "  </actions>\n  <terminators>\n"
    for dk in deadKeys {
        xml += "    <when state=\"\(dk.name)\" output=\"\(xmlEscape(dk.terminator))\"/>\n"
    }
    xml += "  </terminators>\n</keyboard>\n"
    return xml
}

for spec in layouts {
    let url = outDir.appendingPathComponent(spec.fileName + ".keylayout")
    try generate(spec).write(to: url, atomically: true, encoding: .utf8)
    print("Gerado: \(url.lastPathComponent)")
}
