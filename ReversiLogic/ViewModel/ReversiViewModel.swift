import CoreGraphics

public final class ReversiViewModel {
    public typealias SetDisk = (Disk?, Int, Int, Bool, ((Bool) -> Void)?) -> Void
    public typealias AsyncAfter = (DispatchTime, @escaping () -> Void) -> Void
    public typealias Async = (@escaping () -> Void) -> Void

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
    private let async: Async
    private let cache: GameDataCacheProtocol

    public init(messageDiskSize: CGFloat,
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
                async: @escaping Async,
                cache: GameDataCacheProtocol) {
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
        self.async = async
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

    func saveGame() throws {
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

    func count(of disk: Disk) -> Int {
        GameLogic.count(of: disk, from: cells)
    }

    func updateMessage() {
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

    func updateCount() {
        setPlayerDarkCount("\(count(of: .dark))")
        setPlayerLightCount("\(count(of: .light))")
    }

    func flippedDiskCoordinatesByPlacingDisk(_ disk: Disk, atX x: Int, y: Int) -> [(Int, Int)] {
        GameLogic.flippedDiskCoordinates(from: cells, by: disk, at: .init(x: x, y: y))
            .map { ($0.x, $0.y) }
    }

    func canPlaceDisk(_ disk: Disk, atX x: Int, y: Int) -> Bool {
        GameLogic.canPlace(disk: disk, from: cells, at: .init(x: x, y: y))
    }

    func validMoves(for side: Disk) -> [(x: Int, y: Int)] {
        GameLogic.validMoves(for: side, from: cells).map { ($0.x, $0.y) }
    }

    func nextTurn() {
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

            try! self.placeDisk(turn, atX: x, y: y, animated: true) { [weak self] _ in
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
        try? placeDisk(turn, atX: x, y: y, animated: true) { [weak self] _ in
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

extension ReversiViewModel {

    func animateSettingDisks<C: Collection>(
        at coordinates: C,
        to disk: Disk,
        completion: @escaping (Bool) -> Void
    ) where C.Element == (Int, Int) {
        guard let (x, y) = coordinates.first else {
            completion(true)
            return
        }

        guard let animationCanceller = self.animationCanceller else {
            return
        }
        setDisk(disk, atX: x, y: y, animated: true) { [weak self] finished in
            guard let self = self else { return }
            if animationCanceller.isCancelled { return }
            if finished {
                self.animateSettingDisks(at: coordinates.dropFirst(), to: disk, completion: completion)
            } else {
                for (x, y) in coordinates {
                    self.setDisk(disk, atX: x, y: y, animated: false)
                }
                completion(false)
            }
        }
    }

    /// - Parameter completion: A closure to be executed when the animation sequence ends.
    ///     This closure has no return value and takes a single Boolean argument that indicates
    ///     whether or not the animations actually finished before the completion handler was called.
    ///     If `animated` is `false`,  this closure is performed at the beginning of the next run loop cycle. This parameter may be `nil`.
    /// - Throws: `DiskPlacementError` if the `disk` cannot be placed at (`x`, `y`).
    func placeDisk(_ disk: Disk,
                   atX x: Int, y: Int,
                   animated isAnimated: Bool,
                   completion: @escaping (Bool) -> Void) throws {
        let diskCoordinates = flippedDiskCoordinatesByPlacingDisk(disk, atX: x, y: y)
        if diskCoordinates.isEmpty {
            throw DiskPlacementError(disk: disk, x: x, y: y)
        }

        let finally: (ReversiViewModel, Bool) -> Void = { viewModel, finished in
            completion(finished)
            try? viewModel.saveGame()
            viewModel.updateCount()
        }

        if isAnimated {
            let cleanUp: () -> Void = { [weak self] in
                self?.animationCanceller = nil
            }
            animationCanceller = Canceller(cleanUp)
            animateSettingDisks(at: [(x, y)] + diskCoordinates, to: disk) { [weak self] finished in
                guard let me = self else { return }
                guard let canceller = me.animationCanceller else { return }
                if canceller.isCancelled { return }
                cleanUp()

                finally(me, finished)
            }
        } else {
            async { [weak self] in
                guard let me = self else { return }
                me.setDisk(disk, atX: x, y: y, animated: false)
                for (x, y) in diskCoordinates {
                    me.setDisk(disk, atX: x, y: y, animated: false)
                }

                finally(me, true)
            }
        }
    }

    struct DiskPlacementError: Error {
        let disk: Disk
        let x: Int
        let y: Int
    }
}
