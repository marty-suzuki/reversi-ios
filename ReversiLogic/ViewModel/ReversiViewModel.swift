import CoreGraphics

public final class ReversiViewModel {
    public typealias SetDisk = (Disk?, Int, Int, Bool, ((Bool) -> Void)?) -> Void

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

    private let showCanNotPlaceAlert: () -> Void
    private let setPlayerDarkCount: (String) -> Void
    private let setPlayerLightCount: (String) -> Void
    private let setMessageDiskSizeConstant: (CGFloat) -> Void
    private let setMessageDisk: (Disk) -> Void
    private let setMessageText: (String) -> Void
    private let _setDisk: SetDisk
    private let playTurnOfComputer: () -> Void
    private let setPlayerDarkSelectedIndex: (Int) -> Void
    private let setPlayerLightSelectedIndex: (Int) -> Void
    private let reset: () -> Void
    private let cache: GameDataCacheProtocol

    public init(messageDiskSize: CGFloat,
                showCanNotPlaceAlert: @escaping () -> Void,
                setPlayerDarkCount: @escaping (String) -> Void,
                setPlayerLightCount: @escaping (String) -> Void,
                setMessageDiskSizeConstant: @escaping (CGFloat) -> Void,
                setMessageDisk: @escaping (Disk) -> Void,
                setMessageText: @escaping (String) -> Void,
                playTurnOfComputer: @escaping () -> Void,
                setDisk: @escaping SetDisk,
                setPlayerDarkSelectedIndex: @escaping (Int) -> Void,
                setPlayerLightSelectedIndex: @escaping (Int) -> Void,
                reset: @escaping () -> Void,
                cache: GameDataCacheProtocol) {
        self.showCanNotPlaceAlert = showCanNotPlaceAlert
        self.setPlayerDarkCount = setPlayerDarkCount
        self.setPlayerLightCount = setPlayerLightCount
        self.setMessageDiskSizeConstant = setMessageDiskSizeConstant
        self.setMessageDisk = setMessageDisk
        self.setMessageText = setMessageText
        self.playTurnOfComputer = playTurnOfComputer
        self._setDisk = setDisk
        self.setPlayerDarkSelectedIndex = setPlayerDarkSelectedIndex
        self.setPlayerLightSelectedIndex = setPlayerLightSelectedIndex
        self.reset = reset
        self.cache = cache
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

        case .turn(.dark):
            player = cache.playerDark

        case .turn(.light):
            player = cache.playerLight
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

            self?.setPlayerDarkSelectedIndex(me.cache.playerDark.rawValue)
            self?.setPlayerLightSelectedIndex(me.cache.playerLight.rawValue)

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

    public func setSelectedIndex(_ index: Int, for disk: Disk) {
        switch disk {
        case .dark:
            cache.playerDark = GameData.Player(rawValue: index) ?? .manual
        case .light:
            cache.playerLight = GameData.Player(rawValue: index) ?? .manual
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
                showCanNotPlaceAlert()
            }
        } else {
            self.cache.status = .turn(turn)
            updateMessage()
            waitForPlayer()
        }
    }
}
