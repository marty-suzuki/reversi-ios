public final class ReversiViewModel {

    public var turn: Disk? = .dark // `nil` if the current game is over

    public var animationCanceller: Canceller?
    public var isAnimating: Bool {
        animationCanceller != nil
    }

    public var playerCancellers: [Disk: Canceller] = [:]

    public private(set) var viewHasAppeared: Bool = false

    public init() {}

    public func viewDidAppear() {
        viewHasAppeared = true
    }
}
