@propertyWrapper
public enum Lazy<T> {
    case initialized(T)
    case uninitialized

    public var wrappedValue: T {
        set {
            self = .initialized(newValue)
        }
        get {
            switch self {
            case let .initialized(value):
                return value
            case .uninitialized:
                fatalError("\(T.self) is not initialized yet")
            }
        }
    }

    public init() {
        self = .uninitialized
    }
}
