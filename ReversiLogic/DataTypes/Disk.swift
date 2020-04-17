public enum Disk: Hashable, CaseIterable {
    case dark
    case light
}

extension Disk {    
    /// 自身の値を反転させた値（ `.dark` なら `.light` 、 `.light` なら `.dark` ）を返します。
    public var flipped: Disk {
        switch self {
        case .dark: return .light
        case .light: return .dark
        }
    }
    
    /// 自身の値を、現在の値が `.dark` なら `.light` に、 `.light` なら `.dark` に反転させます。
    public mutating func flip() {
        self = flipped
    }
}
