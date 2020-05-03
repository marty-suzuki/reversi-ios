import RxRelay

public protocol Acceptable {
    associatedtype Element
    func accept(_ value: Element)
}

extension PublishRelay: Acceptable {}
