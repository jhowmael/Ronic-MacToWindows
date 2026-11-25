import CoreGraphics

/// Virtual key codes (physical position, same as Carbon's `kVK_*`).
/// They are literals so the compiler treats them as constants on the event tap's hot path.
/// Valid for ANSI and ABNT2 layouts (letters sit in the same positions).
enum Key {
    static let a: UInt16 = 0x00
    static let s: UInt16 = 0x01
    static let d: UInt16 = 0x02
    static let f: UInt16 = 0x03
    static let z: UInt16 = 0x06
    static let x: UInt16 = 0x07
    static let c: UInt16 = 0x08
    static let v: UInt16 = 0x09
    static let b: UInt16 = 0x0B
    static let q: UInt16 = 0x0C
    static let w: UInt16 = 0x0D
    static let e: UInt16 = 0x0E
    static let r: UInt16 = 0x0F
    static let y: UInt16 = 0x10
    static let t: UInt16 = 0x11
    static let three: UInt16 = 0x14
    static let four: UInt16 = 0x15
    static let five: UInt16 = 0x17
    static let equal: UInt16 = 0x18
    static let minus: UInt16 = 0x1B
    static let zero: UInt16 = 0x1D
    static let o: UInt16 = 0x1F
    static let u: UInt16 = 0x20
    static let i: UInt16 = 0x22
    static let p: UInt16 = 0x23
    static let returnKey: UInt16 = 0x24
    static let l: UInt16 = 0x25
    static let k: UInt16 = 0x28
    static let n: UInt16 = 0x2D
    static let tab: UInt16 = 0x30
    static let backspace: UInt16 = 0x33
    static let escape: UInt16 = 0x35
    static let f13: UInt16 = 0x69   // "Print Screen" on PC keyboards connected to a Mac
    static let home: UInt16 = 0x73
    static let forwardDelete: UInt16 = 0x75
    static let f4: UInt16 = 0x76
    static let end: UInt16 = 0x77
    static let left: UInt16 = 0x7B
    static let right: UInt16 = 0x7C
    static let down: UInt16 = 0x7D
    static let up: UInt16 = 0x7E
}

/// `CGEventFlags` bits, including the "device-dependent" bits (left/right side, from
/// IOLLEvent.h). When swapping a modifier we clear those bits too; otherwise some apps keep
/// seeing a "ghost" Control key.
enum Mask {
    static let control: UInt64 = 0x0004_0000
    static let shift: UInt64 = 0x0002_0000
    static let option: UInt64 = 0x0008_0000
    static let command: UInt64 = 0x0010_0000
    static let numericPad: UInt64 = 0x0020_0000
    static let secondaryFn: UInt64 = 0x0080_0000

    // Device bits (NX_DEVICE*KEYMASK)
    static let devLeftCtrl: UInt64 = 0x0000_0001
    static let devLeftShift: UInt64 = 0x0000_0002
    static let devLeftCmd: UInt64 = 0x0000_0008
    static let devRightCmd: UInt64 = 0x0000_0010
    static let devLeftOpt: UInt64 = 0x0000_0020
    static let devRightOpt: UInt64 = 0x0000_0040
    static let devRightCtrl: UInt64 = 0x0000_2000

    /// Everything that identifies each modifier (generic + left + right).
    static let anyControl = control | devLeftCtrl | devRightCtrl
    static let anyCommand = command | devLeftCmd | devRightCmd
    static let anyOption = option | devLeftOpt | devRightOpt

    /// Arrows, Home/End and Delete carry these bits; letters don't.
    static let fnPad = numericPad | secondaryFn

    /// Emitted modifiers (always as the "left side" key).
    static let outControl = control | devLeftCtrl
    static let outCommand = command | devLeftCmd
    static let outOption = option | devLeftOpt
    static let outShift = shift | devLeftShift
}

/// Characters used when the keyCode changes (AppKit recomputes them from keyCode+flags,
/// but non-AppKit apps read the CGEvent's string).
enum KeyChar {
    static let ctrlA: UniChar = 0x61   // "a" (AppKit uses it as charactersIgnoringModifiers)
    static let ctrlE: UniChar = 0x65   // "e"
    static let q: UniChar = 0x71
    static let z: UniChar = 0x7A
    static let upArrow: UniChar = 0xF700
    static let downArrow: UniChar = 0xF701
}
