import CoreGraphics

public final class ReversiViewModel {
    public typealias SetDisk = (Disk?, Int, Int, Bool, ((Bool) -> Void)?) -> Void

    public var turn: Disk? = .dark // `nil` if the current game is over

    private(set) var cells: [[GameData.Board.Cell]]

    public var animationCanceller: Canceller?
    public var isAnimating: Bool {
        animationCanceller != nil
    }

    public var playerCancellers: [Disk: Canceller] = [:]

    private var viewHasAppeared: Bool = false
    private let messageDiskSize: CGFloat

    private let setMessageDiskSizeConstant: (CGFloat) -> Void
    private let setMessageDisk: (Disk) -> Void
    private let setMessageText: (String) -> Void
    private let _setDisk: SetDisk
    private let playTurnOfComputer: () -> Void
    private let selectedSegmentIndexFor: (Int) -> Int?
    private let setPlayerDarkSelectedIndex: (Int) -> Void
    private let getPlayerDarkSelectedIndex: () -> Int?
    private let setPlayerLightSelectedIndex: (Int) -> Void
    private let getPlayerLightSelectedIndex: () -> Int?
    private let updateCountLabels: () -> Void
    private let reset: () -> Void
    private let _loadGame: GameDataIO.LoadGame
    private let _saveGame: GameDataIO.SaveGame

    public init(messageDiskSize: CGFloat,
                setMessageDiskSizeConstant: @escaping (CGFloat) -> Void,
                setMessageDisk: @escaping (Disk) -> Void,
                setMessageText: @escaping (String) -> Void,
                playTurnOfComputer: @escaping () -> Void,
                selectedSegmentIndexFor: @escaping (Int) -> Int?,
                setDisk: @escaping SetDisk,
                setPlayerDarkSelectedIndex: @escaping (Int) -> Void,
                getPlayerDarkSelectedIndex: @escaping () -> Int?,
                setPlayerLightSelectedIndex: @escaping (Int) -> Void,
                getPlayerLightSelectedIndex: @escaping () -> Int?,
                updateCountLabels: @escaping () -> Void,
                reset: @escaping () -> Void,
                loadGame: @escaping GameDataIO.LoadGame,
                saveGame: @escaping GameDataIO.SaveGame,
                board: GameData.Board = .initial()) {
        self.setMessageDiskSizeConstant = setMessageDiskSizeConstant
        self.setMessageDisk = setMessageDisk
        self.setMessageText = setMessageText
        self.playTurnOfComputer = playTurnOfComputer
        self.selectedSegmentIndexFor = selectedSegmentIndexFor
        self._setDisk = setDisk
        self.setPlayerDarkSelectedIndex = setPlayerDarkSelectedIndex
        self.getPlayerDarkSelectedIndex = getPlayerDarkSelectedIndex
        self.setPlayerLightSelectedIndex = setPlayerLightSelectedIndex
        self.getPlayerLightSelectedIndex = getPlayerLightSelectedIndex
        self.updateCountLabels = updateCountLabels
        self.reset = reset
        self._loadGame = loadGame
        self._saveGame = saveGame
        self.cells = board.cells
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
        let cell = cells[y][x]
        if cell.x == x && cell.y == y {
            cells[y][x].disk = disk
        }
        _setDisk(disk, x, y, animated, completion)
    }

    public func newGame() {
        reset()
        cells = GameData.Board.initial().cells
        turn = .dark

        setPlayerDarkSelectedIndex(GameData.Player.manual.rawValue)
        setPlayerLightSelectedIndex(GameData.Player.manual.rawValue)

        updateMessage()
        updateCountLabels()

        try? saveGame()
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

            self?.cells = data.board.cells
            data.board.cells.forEach { rows in
                rows.forEach { cell in
                    self?._setDisk(cell.disk, cell.x, cell.y, false, nil)
                }
            }

            self?.updateMessage()
            self?.updateCountLabels()
        }
    }

    public func saveGame() throws {
        let playerDark = getPlayerDarkSelectedIndex()
            .flatMap(GameData.Player.init) ?? .manual
        let playerLight = getPlayerLightSelectedIndex()
            .flatMap(GameData.Player.init) ?? .manual

        let data = GameData(
            status: turn.map(GameData.Status.turn) ?? .gameOver,
            playerDark: playerDark,
            playerLight: playerLight,
            board: GameData.Board(cells: cells)
        )

        try _saveGame(
            data,
            { try $0.write(toFile: $1, atomically: true, encoding: .utf8) }
        )
    }

    public func count(of disk: Disk) -> Int {
        return cells.reduce(0) { result, rows in
            rows.reduce(result) { result, cell in
                if cell.disk == disk {
                    return result + 1
                } else {
                    return result
                }
            }
        }
    }

    func sideWithMoreDisks() -> Disk? {
        let darkCount = count(of: .dark)
        let lightCount = count(of: .light)
        if darkCount == lightCount {
            return nil
        } else {
            return darkCount > lightCount ? .dark : .light
        }
    }

    public func updateMessage() {
        switch turn {
        case let .some(side):
            setMessageDiskSizeConstant(messageDiskSize)
            setMessageDisk(side)
            setMessageText("'s turn")
        case .none:
            if let winner = sideWithMoreDisks() {
                setMessageDiskSizeConstant(messageDiskSize)
                setMessageDisk(winner)
                setMessageText(" won")
            } else {
                setMessageDiskSizeConstant(0)
                setMessageText("Tied")
            }
        }
    }
}
