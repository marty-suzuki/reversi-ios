public final class ReversiViewModel {

    public var turn: Disk? = .dark // `nil` if the current game is over

    public var animationCanceller: Canceller?
    public var isAnimating: Bool {
        animationCanceller != nil
    }

    public var playerCancellers: [Disk: Canceller] = [:]

    public private(set) var viewHasAppeared: Bool = false

    private let playTurnOfComputer: () -> Void
    private let selectedSegmentIndexFor: (Int) -> Int?

    public init(playTurnOfComputer: @escaping () -> Void,
                selectedSegmentIndexFor: @escaping (Int) -> Int?) {
        self.playTurnOfComputer = playTurnOfComputer
        self.selectedSegmentIndexFor = selectedSegmentIndexFor
    }

    public func viewDidAppear() {
        viewHasAppeared = true
    }

    public func waitForPlayer() {
        guard
            let player = turn
                .flatMap({ selectedSegmentIndexFor($0.index) })
                .flatMap(GameData.Player.init)
        else {
            return
        }

        switch player {
        case .manual:
            break
        case .computer:
            playTurnOfComputer()
        }
    }
}
