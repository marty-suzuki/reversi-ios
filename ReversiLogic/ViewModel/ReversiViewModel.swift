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
    private let setPlayerDarkSelectedIndex: (Int) -> Void
    private let setPlayerLightSelectedIndex: (Int) -> Void
    private let updateCountLabels: () -> Void
    private let updateMessageViews: () -> Void
    private let _loadGame: GameDataIO.LoadGame

    public init(playTurnOfComputer: @escaping () -> Void,
                selectedSegmentIndexFor: @escaping (Int) -> Int?,
                setDisk: @escaping SetDisk,
                setPlayerDarkSelectedIndex: @escaping (Int) -> Void,
                setPlayerLightSelectedIndex: @escaping (Int) -> Void,
                updateCountLabels: @escaping () -> Void,
                updateMessageViews: @escaping () -> Void,
                loadGame: @escaping GameDataIO.LoadGame) {
        self.playTurnOfComputer = playTurnOfComputer
        self.selectedSegmentIndexFor = selectedSegmentIndexFor
        self._setDisk = setDisk
        self.setPlayerDarkSelectedIndex = setPlayerDarkSelectedIndex
        self.setPlayerLightSelectedIndex = setPlayerLightSelectedIndex
        self.updateCountLabels = updateCountLabels
        self.updateMessageViews = updateMessageViews
        self._loadGame = loadGame
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

    public func loadGame() throws {
        try _loadGame({ try String(contentsOfFile: $0, encoding: .utf8) }) { [weak self] data in
            switch data.status {
            case .gameOver:
                self?.turn = nil
            case let .turn(disk):
                self?.turn = disk
            }

            self?.setPlayerDarkSelectedIndex(data.playerDark.rawValue)
            self?.setPlayerLightSelectedIndex(data.playerLight.rawValue)

            data.board.cells.forEach { rows in
                rows.forEach { cell in
                    self?._setDisk(cell.disk, cell.x, cell.y, false, nil)
                }
            }

            self?.updateMessageViews()
            self?.updateCountLabels()
        }
    }
}
