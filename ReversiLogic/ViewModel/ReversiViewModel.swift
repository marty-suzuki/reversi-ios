public final class ReversiViewModel {
    public typealias SetDisk = (Disk?, Int, Int, Bool, ((Bool) -> Void)?) -> Void

    public var turn: Disk? = .dark // `nil` if the current game is over

    public var animationCanceller: Canceller?
    public var isAnimating: Bool {
        animationCanceller != nil
    }

    public var playerCancellers: [Disk: Canceller] = [:]

    private var viewHasAppeared: Bool = false

    private let _setDisk: SetDisk
    private let playTurnOfComputer: () -> Void
    private let selectedSegmentIndexFor: (Int) -> Int?

    public init(playTurnOfComputer: @escaping () -> Void,
                selectedSegmentIndexFor: @escaping (Int) -> Int?,
                setDisk: @escaping SetDisk) {
        self.playTurnOfComputer = playTurnOfComputer
        self.selectedSegmentIndexFor = selectedSegmentIndexFor
        self._setDisk = setDisk
    }

    public func viewDidAppear() {
        if viewHasAppeared {
            return
        }
        viewHasAppeared = true
        waitForPlayer()
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

    public func setDisk(_ disk: Disk?, atX x: Int, y: Int, animated: Bool, completion: ((Bool) -> Void)? = nil) {
        _setDisk(disk, x, y, animated, completion)
    }
}
