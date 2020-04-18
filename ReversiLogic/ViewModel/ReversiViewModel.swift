import CoreGraphics
import RxSwift

public final class ReversiViewModel {
    public typealias AsyncAfter = (DispatchTime, @escaping () -> Void) -> Void
    public typealias Async = (@escaping () -> Void) -> Void

    public var animationCanceller: Canceller?
    public var isAnimating: Bool {
        animationCanceller != nil
    }

    public var playerCancellers: [Disk: Canceller] = [:]

    private var viewHasAppeared: Bool = false
    private let messageDiskSize: CGFloat

    @PublishWrapper
    public private(set) var messageDisk: Observable<Disk>
    @PublishWrapper
    public private(set) var messageDiskSizeConstant: Observable<CGFloat>
    @PublishWrapper
    public private(set) var messageText: Observable<String>
    @PublishWrapper
    public private(set) var showAlert: Observable<Alert>
    @PublishWrapper
    public private(set) var isPlayerDarkAnimating: Observable<Bool>
    @PublishWrapper
    public private(set) var isPlayerLightAnimating: Observable<Bool>
    @PublishWrapper
    public private(set) var playerDarkCount: Observable<String>
    @PublishWrapper
    public private(set) var playerLightCount: Observable<String>
    @PublishWrapper
    public private(set) var playerDarkSelectedIndex: Observable<Int>
    @PublishWrapper
    public private(set) var playerLightSelectedIndex: Observable<Int>
    @PublishWrapper
    public private(set) var resetBoard: Observable<Void>
    @PublishWrapper
    public private(set) var updateBoard: Observable<UpdateDisk>

    private let asyncAfter: AsyncAfter
    private let async: Async
    private let logic: GameLogicProtocol
    private let cache: GameDataCacheProtocol

    public init(messageDiskSize: CGFloat,
                asyncAfter: @escaping AsyncAfter,
                async: @escaping Async,
                cache: GameDataCacheProtocol,
                logicFactory: GameLogicFactoryProtocol) {
        self.cache = cache
        self.asyncAfter = asyncAfter
        self.async = async
        self.messageDiskSize = messageDiskSize
        self.logic = logicFactory.make(cache: cache)
    }

    public func viewDidAppear() {
        if viewHasAppeared {
            return
        }
        viewHasAppeared = true
        waitForPlayer()
    }

    public func startGame() {
        do {
            try loadGame()
        } catch _ {
            newGame()
        }
    }

    public func setPlayer(for disk: Disk, with index: Int) {
        cache[disk] = GameData.Player(rawValue: index) ?? .manual

        try? cache.save()

        if let canceller = playerCancellers[disk] {
            canceller.cancel()
        }

        if !isAnimating, cache.status == .turn(disk), case .computer = cache[disk] {
            playTurnOfComputer()
        }
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

        // try? because doing nothing when an error occurs
        try? placeDisk(turn, at: selectedCoordinate, animated: true) { [weak self] _ in
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
        _showAlert.accept(alert)
    }
}

extension ReversiViewModel {

    func waitForPlayer() {
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

    func setDisk(_ disk: Disk?, at coordinate: Coordinate, animated: Bool, completion: ((Bool) -> Void)?) {
        cache[coordinate] = disk
        let update = UpdateDisk(disk: disk, coordinate: coordinate, animated: animated, completion: completion)
        _updateBoard.accept(update)
    }

    func newGame() {
        _resetBoard.accept()
        cache.reset()

        _playerDarkSelectedIndex.accept(cache[.dark].rawValue)
        _playerLightSelectedIndex.accept(cache[.light].rawValue)

        updateMessage()
        updateCount()

        try? cache.save()
    }

    func loadGame() throws {
        try cache.load { [weak self] in
            guard let me = self else {
                return
            }

            self?._playerDarkSelectedIndex.accept(me.cache[.dark].rawValue)
            self?._playerLightSelectedIndex.accept(me.cache[.light].rawValue)

            me.cache.cells.forEach { rows in
                rows.forEach { cell in
                    let update = UpdateDisk(disk: cell.disk, coordinate: cell.coordinate, animated: false, completion: nil)
                    self?._updateBoard.accept(update)
                }
            }

            self?.updateMessage()
            self?.updateCount()
        }
    }

    func updateMessage() {
        switch cache.status {
        case let .turn(side):
            _messageDiskSizeConstant.accept(messageDiskSize)
            _messageDisk.accept(side)
            _messageText.accept("'s turn")
        case .gameOver:
            if let winner = logic.sideWithMoreDisks() {
                _messageDiskSizeConstant.accept(messageDiskSize)
                _messageDisk.accept(winner)
                _messageText.accept(" won")
            } else {
                _messageDiskSizeConstant.accept(0)
                _messageText.accept("Tied")
            }
        }
    }

    func updateCount() {
        _playerDarkCount.accept("\(logic.count(of: .dark))")
        _playerLightCount.accept("\(logic.count(of: .light))")
    }

    func nextTurn() {
        var turn: Disk
        switch cache.status {
        case let .turn(disk):
            turn = disk
        case .gameOver:
            return
        }

        turn.flip()

        if logic.validMoves(for: turn).isEmpty {
            if logic.validMoves(for: turn.flipped).isEmpty {
                self.cache.status = .gameOver
                updateMessage()
            } else {
                self.cache.status = .turn(turn)
                updateMessage()

                let alert = Alert.pass { [weak self] in
                    self?.nextTurn()
                }
                _showAlert.accept(alert)
            }
        } else {
            self.cache.status = .turn(turn)
            updateMessage()
            waitForPlayer()
        }
    }

    func playTurnOfComputer() {
        guard
            case let .turn(turn) = cache.status,
            let coordinate = logic.validMoves(for: turn).randomElement()
        else {
            preconditionFailure()
        }

        switch turn {
        case .dark:
            _isPlayerDarkAnimating.accept(true)
        case .light:
            _isPlayerLightAnimating.accept(true)
        }

        let cleanUp: () -> Void = { [weak self] in
            guard let me = self else { return }
            switch turn {
            case .dark:
                me._isPlayerDarkAnimating.accept(false)
            case .light:
                me._isPlayerLightAnimating.accept(false)
            }
            me.playerCancellers[turn] = nil
        }
        let canceller = Canceller(cleanUp)
        asyncAfter(.now() + 2.0) { [weak self] in
            guard let self = self else { return }
            if canceller.isCancelled { return }
            cleanUp()

            try? self.placeDisk(turn, at: coordinate, animated: true) { [weak self] _ in
                self?.nextTurn()
            }
        }

        playerCancellers[turn] = canceller
    }
}

extension ReversiViewModel {

    func animateSettingDisks(at coordinates: [Coordinate],
                             to disk: Disk,
                             completion: @escaping (Bool) -> Void) {
        guard let coordinate = coordinates.first else {
            completion(true)
            return
        }

        guard let animationCanceller = self.animationCanceller else {
            return
        }
        setDisk(disk, at: coordinate, animated: true) { [weak self] finished in
            guard let self = self else { return }
            if animationCanceller.isCancelled { return }
            if finished {
                self.animateSettingDisks(at: Array(coordinates.dropFirst()), to: disk, completion: completion)
            } else {
                for coordinate in coordinates {
                    self.setDisk(disk, at: coordinate, animated: false, completion: nil)
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
                   at coordinate: Coordinate,
                   animated isAnimated: Bool,
                   completion: @escaping (Bool) -> Void) throws {
        let diskCoordinates = logic.flippedDiskCoordinates(by: disk, at: coordinate)
        if diskCoordinates.isEmpty {
            throw DiskPlacementError(disk: disk, x: coordinate.x, y: coordinate.y)
        }

        let finally: (ReversiViewModel, Bool) -> Void = { viewModel, finished in
            completion(finished)
            try? viewModel.cache.save()
            viewModel.updateCount()
        }

        if isAnimated {
            let cleanUp: () -> Void = { [weak self] in
                self?.animationCanceller = nil
            }
            animationCanceller = Canceller(cleanUp)
            animateSettingDisks(at: [coordinate] + diskCoordinates, to: disk) { [weak self] finished in
                guard let me = self else { return }
                guard let canceller = me.animationCanceller else { return }
                if canceller.isCancelled { return }
                cleanUp()

                finally(me, finished)
            }
        } else {
            async { [weak self] in
                guard let me = self else { return }
                me.setDisk(disk, at: coordinate, animated: false, completion: nil)
                for coordinate in diskCoordinates {
                    me.setDisk(disk, at: coordinate, animated: false, completion: nil)
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

    public struct UpdateDisk {
        public let disk: Disk?
        public let coordinate: Coordinate
        public let animated: Bool
        public let completion: ((Bool) -> Void)?
    }
}
