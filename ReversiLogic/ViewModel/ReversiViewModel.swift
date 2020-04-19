import CoreGraphics
import RxCocoa
import RxSwift

public final class ReversiViewModel {
    public typealias AsyncAfter = (DispatchTime, @escaping () -> Void) -> Void
    public typealias Async = (@escaping () -> Void) -> Void

    public var animationCanceller: Canceller?
    public var isAnimating: Bool {
        animationCanceller != nil
    }

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
    private let disposeBag = DisposeBag()

    private let _startGame = PublishRelay<Void>()

    public init(messageDiskSize: CGFloat,
                asyncAfter: @escaping AsyncAfter,
                async: @escaping Async,
                logicFactory: GameLogicFactoryProtocol) {
        self.asyncAfter = asyncAfter
        self.async = async
        self.messageDiskSize = messageDiskSize
        self.logic = logicFactory.make()

        logic.playerDark
            .distinctUntilChanged()
            .map { $0.rawValue }
            .bind(to: _playerDarkSelectedIndex)
            .disposed(by: disposeBag)

        logic.playerLight
            .distinctUntilChanged()
            .map { $0.rawValue }
            .bind(to: _playerLightSelectedIndex)
            .disposed(by: disposeBag)

        logic.status
            .subscribe(onNext: { [weak self] status in
                guard let me = self else {
                    return
                }
                switch status {
                case let .turn(side):
                    me._messageDiskSizeConstant.accept(messageDiskSize)
                    me._messageDisk.accept(side)
                    me._messageText.accept("'s turn")
                case .gameOver:
                    if let winner = me.logic.sideWithMoreDisks.value {
                        me._messageDiskSizeConstant.accept(messageDiskSize)
                        me._messageDisk.accept(winner)
                        me._messageText.accept(" won")
                    } else {
                        me._messageDiskSizeConstant.accept(0)
                        me._messageText.accept("Tied")
                    }
                }
            })
            .disposed(by: disposeBag)

        logic.playTurnOfComputer
            .subscribe(onNext: { [weak self] in
                guard let me = self, !me.isAnimating else {
                    return
                }
                self?.playTurnOfComputer()
            })
            .disposed(by: disposeBag)

        logic.gameLoaded
            .subscribe(onNext: { [weak self] in
                self?.logic.cells.value.forEach { rows in
                    rows.forEach { cell in
                        let update = UpdateDisk(disk: cell.disk, coordinate: cell.coordinate, animated: false, completion: nil)
                        self?._updateBoard.accept(update)
                    }
                }
                self?.updateCount()
            })
            .disposed(by: disposeBag)

        logic.newGameBegan
            .subscribe(onNext: { [weak self] in
                self?._resetBoard.accept()
                self?.updateCount()
            })
            .disposed(by: disposeBag)
    }

    private lazy var callOnceViewDidAppear: Void = {
        logic.waitForPlayer()
    }()

    public func viewDidAppear() {
        _ = callOnceViewDidAppear
    }

    public func startGame() {
        logic.startGame()
    }

    public func setPlayer(for disk: Disk, with index: Int) {
        logic.setPlayer(for: disk, with: index)
    }

    public func handle(selectedCoordinate: Coordinate) {
        guard case let .turn(turn) = logic.status.value else {
            return
        }

        if isAnimating {
            return
        }

        guard case .manual = logic.playerOfCurrentTurn.value else {
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
                me.logic.playerCancellers[side]?.cancel()
                me.logic.playerCancellers.removeValue(forKey: side)
            }

            me.logic.newGame()
            me.logic.waitForPlayer()
        }
        _showAlert.accept(alert)
    }
}

extension ReversiViewModel {

    func setDisk(_ disk: Disk?, at coordinate: Coordinate, animated: Bool, completion: ((Bool) -> Void)?) {
        logic.setDisk(disk, at: coordinate)
        let update = UpdateDisk(disk: disk, coordinate: coordinate, animated: animated, completion: completion)
        _updateBoard.accept(update)
    }

    func updateCount() {
        _playerDarkCount.accept("\(logic.countOfDark.value)")
        _playerLightCount.accept("\(logic.countOfLight.value)")
    }

    func nextTurn() {
        var turn: Disk
        switch logic.status.value {
        case let .turn(disk):
            turn = disk
        case .gameOver:
            return
        }

        turn.flip()

        if logic.validMoves(for: turn).isEmpty {
            if logic.validMoves(for: turn.flipped).isEmpty {
                self.logic.setStatus(.gameOver)
            } else {
                self.logic.setStatus(.turn(turn))

                let alert = Alert.pass { [weak self] in
                    self?.nextTurn()
                }
                _showAlert.accept(alert)
            }
        } else {
            logic.setStatus(.turn(turn))
            logic.waitForPlayer()
        }
    }

    func playTurnOfComputer() {
        guard
            case let .turn(turn) = logic.status.value,
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
            me.logic.playerCancellers[turn] = nil
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

        logic.playerCancellers[turn] = canceller
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
            try? viewModel.logic.save()
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
