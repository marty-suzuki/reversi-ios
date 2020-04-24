public final class Canceller {
    public private(set) var isCancelled = false
    private let body: () -> Void

    public init(_ body: @escaping () -> Void) {
        self.body = body
    }

    public func cancel() {
        if isCancelled {
            return
        }
        isCancelled = true
        body()
    }
}
