import CoreGraphics

public final class ReversiViewModel {
    public typealias SetDisk = (Disk?, Int, Int, Bool, ((Bool) -> Void)?) -> Void
    public typealias PlaceDisk = (Disk, Int, Int, Bool, @escaping (Bool) -> Void) throws -> Void
    public typealias AsyncAfter = (DispatchTime, @escaping () -> Void) -> Void

    // `nil` if the current game is over
    public var turn: Disk? {
        switch cache.status {
        case .gameOver: return nil
        case let .turn(disk): return disk
        }
    }

    var cells: [[GameData.Board.Cell]] {
        cache.cells
    }

    public var animationCanceller: Canceller?
    public var isAnimating: Bool {
        animationCanceller != nil
    }

    public var playerCancellers: [Disk: Canceller] = [:]

    private var viewHasAppeared: Bool = false
    private let messageDiskSize: CGFloat

    private let placeDisk: PlaceDisk
    private let showAlert: (Alert) -> Void
    private let setPlayerDarkCount: (String) -> Void
    private let setPlayerLightCount: (String) -> Void
    private let setMessageDiskSizeConstant: (CGFloat) -> Void
    private let setMessageDisk: (Disk) -> Void
    private let setMessageText: (String) -> Void
    private let _setDisk: SetDisk
    private let setPlayerDarkSelectedIndex: (Int) -> Void
    private let setPlayerLightSelectedIndex: (Int) -> Void
    private let startPlayerDarkAnimation: () -> Void
    private let stopPlayerDarkAnimation: () -> Void
    private let startPlayerLightAnimation: () -> Void
    private let stopPlayerLightAnimation: () -> Void
    private let reset: () -> Void
    private let asyncAfter: AsyncAfter
    private let cache: GameDataCacheProtocol

    public init(messageDiskSize: CGFloat,
                placeDisk: @escaping PlaceDisk,
                showAlert: @escaping (Alert) -> Void,
                setPlayerDarkCount: @escaping (String) -> Void,
                setPlayerLightCount: @escaping (String) -> Void,
                setMessageDiskSizeConstant: @escaping (CGFloat) -> Void,
                setMessageDisk: @escaping (Disk) -> Void,
                setMessageText: @escaping (String) -> Void,
                setDisk: @escaping SetDisk,
                setPlayerDarkSelectedIndex: @escaping (Int) -> Void,
                setPlayerLightSelectedIndex: @escaping (Int) -> Void,
                startPlayerDarkAnimation: @escaping () -> Void,
                stopPlayerDarkAnimation: @escaping () -> Void,
                startPlayerLightAnimation: @escaping () -> Void,
                stopPlayerLightAnimation: @escaping () -> Void,
                reset: @escaping () -> Void,
                asyncAfter: @escaping AsyncAfter,
                cache: GameDataCacheProtocol) {
        self.placeDisk = placeDisk
        self.showAlert = showAlert
        self.setPlayerDarkCount = setPlayerDarkCount
        self.setPlayerLightCount = setPlayerLightCount
        self.setMessageDiskSizeConstant = setMessageDiskSizeConstant
        self.setMessageDisk = setMessageDisk
        self.setMessageText = setMessageText
        self._setDisk = setDisk
        self.setPlayerDarkSelectedIndex = setPlayerDarkSelectedIndex
        self.setPlayerLightSelectedIndex = setPlayerLightSelectedIndex
        self.startPlayerDarkAnimation = startPlayerDarkAnimation
        self.stopPlayerDarkAnimation = stopPlayerDarkAnimation
        self.startPlayerLightAnimation = startPlayerLightAnimation
        self.stopPlayerLightAnimation = stopPlayerLightAnimation
        self.reset = reset
        self.cache = cache
        self.asyncAfter = asyncAfter
        self.messageDiskSize = messageDiskSize
    }

    public func viewDidAppear() {
        if viewHasAppeared {
            return
        }
        viewHasAppeared = true
        waitForPlayer()
    }

    public func waitForPlayer() {
        let player: GameData.Player
        switch cache.status {
        case .gameOver:
            return
        case let .turn(disk):
            player = cache[disk]
        }

        switch player {
        case .manual:
            break
        case .computer:
            playTurnOfComputer()
        }
    }

    public func setDisk(_ disk: Disk?, atX x: Int, y: Int, animated: Bool, completion: ((Bool) -> Void)? = nil) {
        cache[Coordinate(x: x, y: y)] = disk
        _setDisk(disk, x, y, animated, completion)
    }

    public func newGame() {
        reset()
        cache.reset()

        setPlayerDarkSelectedIndex(GameData.Player.manual.rawValue)
        setPlayerLightSelectedIndex(GameData.Player.manual.rawValue)

        updateMessage()
        updateCount()

        try? saveGame()
    }

    public func loadGame() throws {
        try cache.load { [weak self] in
            guard let me = self else {
                return
            }

            self?.setPlayerDarkSelectedIndex(me.cache[.dark].rawValue)
            self?.setPlayerLightSelectedIndex(me.cache[.light].rawValue)

            me.cells.forEach { rows in
                rows.forEach { cell in
                    self?._setDisk(cell.disk, cell.x, cell.y, false, nil)
                }
            }

            self?.updateMessage()
            self?.updateCount()
        }
    }

    public func saveGame() throws {
        try cache.save()
    }

    public func setPlayer(for disk: Disk, with index: Int) {
        cache[disk] = GameData.Player(rawValue: index) ?? .manual

        try? saveGame()

        if let canceller = playerCancellers[disk] {
            canceller.cancel()
        }

        if !isAnimating, disk == turn, case .computer = cache[disk] {
            playTurnOfComputer()
        }
    }

    public func count(of disk: Disk) -> Int {
        GameLogic.count(of: disk, from: cells)
    }

    public func updateMessage() {
        switch turn {
        case let .some(side):
            setMessageDiskSizeConstant(messageDiskSize)
            setMessageDisk(side)
            setMessageText("'s turn")
        case .none:
            if let winner = GameLogic.sideWithMoreDisks(from: cells) {
                setMessageDiskSizeConstant(messageDiskSize)
                setMessageDisk(winner)
                setMessageText(" won")
            } else {
                setMessageDiskSizeConstant(0)
                setMessageText("Tied")
            }
        }
    }

    public func updateCount() {
        setPlayerDarkCount("\(count(of: .dark))")
        setPlayerLightCount("\(count(of: .light))")
    }

    public func flippedDiskCoordinatesByPlacingDisk(_ disk: Disk, atX x: Int, y: Int) -> [(Int, Int)] {
        GameLogic.flippedDiskCoordinates(from: cells, by: disk, at: .init(x: x, y: y))
            .map { ($0.x, $0.y) }
    }

    public func canPlaceDisk(_ disk: Disk, atX x: Int, y: Int) -> Bool {
        GameLogic.canPlace(disk: disk, from: cells, at: .init(x: x, y: y))
    }

    public func validMoves(for side: Disk) -> [(x: Int, y: Int)] {
        GameLogic.validMoves(for: side, from: cells).map { ($0.x, $0.y) }
    }

    public func nextTurn() {
        guard var turn = turn else { return }

        turn.flip()

        if validMoves(for: turn).isEmpty {
            if validMoves(for: turn.flipped).isEmpty {
                self.cache.status = .gameOver
                updateMessage()
            } else {
                self.cache.status = .turn(turn)
                updateMessage()

                let alert = Alert.pass { [weak self] in
                    self?.nextTurn()
                }
                showAlert(alert)
            }
        } else {
            self.cache.status = .turn(turn)
            updateMessage()
            waitForPlayer()
        }
    }

    func playTurnOfComputer() {
        guard case let .turn(turn) = cache.status else {
            preconditionFailure()
        }

        let (x, y) = validMoves(for: turn).randomElement()!

        switch turn {
        case .dark:
            startPlayerDarkAnimation()
        case .light:
            startPlayerLightAnimation()
        }

        let cleanUp: () -> Void = { [weak self] in
            guard let me = self else { return }
            switch turn {
            case .dark:
                me.stopPlayerDarkAnimation()
            case .light:
                me.stopPlayerLightAnimation()
            }
            me.playerCancellers[turn] = nil
        }
        let canceller = Canceller(cleanUp)
        asyncAfter(.now() + 2.0) { [weak self] in
            guard let self = self else { return }
            if canceller.isCancelled { return }
            cleanUp()

            try! self.placeDisk(turn, x, y, true) { [weak self] _ in
                self?.nextTurn()
            }
        }

        playerCancellers[turn] = canceller
    }

    public func handle(selectedCoordinate: Coordinate) {
        guard case let .turn(turn) = cache.status else {
            return
        }

        if isAnimating {
            return
        }

        guard case .manual = cache.playerOfCurrentTurn else {
            return
        }

        let x = selectedCoordinate.x
        let y = selectedCoordinate.y
        // try? because doing nothing when an error occurs
        try? placeDisk(turn, x, y, true) { [weak self] _ in
            self?.nextTurn()
        }
    }

    public func handleReset() {
        let alert = Alert.reset { [weak self] in
            guard let me = self else { return }

            me.animationCanceller?.cancel()
            me.animationCanceller = nil

            for side in Disk.allCases {
                me.playerCancellers[side]?.cancel()
                me.playerCancellers.removeValue(forKey: side)
            }

            me.newGame()
            me.waitForPlayer()
        }
        showAlert(alert)
    }
}
