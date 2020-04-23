import RxCocoa
import RxSwift

public protocol GameLogicProtocol: AnyObject {
    var gameLoaded: Observable<Void> { get }
    var newGameBegan: Observable<Void> { get }
    var handleDiskWithCoordinate: Observable<(Disk, Coordinate)> { get }
    var willTurnDiskOfComputer: Observable<Disk> { get}
    var didTurnDiskOfComputer: Observable<Disk> { get }
    var handerAlert: Observable<Alert> { get }

    var status: ValueObservable<GameData.Status> { get }
    var sideWithMoreDisks: ValueObservable<Disk?> { get }
    var countOfDark: ValueObservable<Int> { get }
    var countOfLight: ValueObservable<Int> { get }
    var playerDark: ValueObservable<GameData.Player> { get }
    var playerLight: ValueObservable<GameData.Player> { get }

    func waitForPlayer()
    func setPlayer(for disk: Disk, with index: Int)
    func startGame()
    func newGame()
    func handle(selectedCoordinate: Coordinate)
    func save()
    func nextTurn()
    func prepareForReset()
}

final class GameLogic: GameLogicProtocol {

    @PublishWrapper
    private(set) var gameLoaded: Observable<Void>

    @PublishWrapper
    private(set) var newGameBegan: Observable<Void>

    @PublishWrapper
    private(set) var handleDiskWithCoordinate: Observable<(Disk, Coordinate)>

    @PublishWrapper
    private(set) var willTurnDiskOfComputer: Observable<Disk>

    @PublishWrapper
    private(set) var didTurnDiskOfComputer: Observable<Disk>

    @PublishWrapper
    private(set) var placeDiskWithCoordinate: Observable<(Disk, Coordinate)>

    @PublishWrapper
    private(set) var handerAlert: Observable<Alert>

    let status: ValueObservable<GameData.Status>
    let sideWithMoreDisks: ValueObservable<Disk?>
    let countOfDark: ValueObservable<Int>
    let countOfLight: ValueObservable<Int>
    let playerDark: ValueObservable<GameData.Player>
    let playerLight: ValueObservable<GameData.Player>

    private let store: GameStoreProtocol
    private let actionCreator: GameActionCreatorProtocol
    private let mainScheduler: SchedulerType
    private let disposeBag = DisposeBag()

    private let _startGame = PublishRelay<Void>()
    private let _newGame = PublishRelay<Void>()
    private let _readyComputerDisk = PublishRelay<(Disk, Coordinate, Canceller)>()

    init(actionCreator: GameActionCreatorProtocol,
         store: GameStoreProtocol,
         mainScheduler: SchedulerType) {
        self.store = store
        self.mainScheduler = mainScheduler
        self.actionCreator = actionCreator

        self.status = store.status
        self.sideWithMoreDisks = store.sideWithMoreDisks
        self.countOfDark = store.countOfDark
        self.countOfLight = store.countOfLight
        self.playerDark = store.playerDark
        self.playerLight = store.playerLight

        store.loaded
            .bind(to: _gameLoaded)
            .disposed(by: disposeBag)

        Observable.merge(_newGame.asObservable(),
                         store.faildToLoad)
            .subscribe(onNext: { [weak self] in
                actionCreator.reset()
                self?._newGameBegan.accept()
                actionCreator.save(cells: store.cells.value,
                                   status: store.status.value,
                                   playerDark: store.playerDark.value,
                                   playerLight: store.playerLight.value)
            })
            .disposed(by: disposeBag)

        _startGame
            .subscribe(onNext: {
                actionCreator.load()
            })
            .disposed(by: disposeBag)

        _readyComputerDisk
            .flatMap { [weak self] disk, coordinate, canceller -> Single<(Disk, Coordinate)> in
                guard let me = self else {
                    return .error(Error.selfReleased)
                }
                return Single.just(())
                    .delay(.seconds(2), scheduler: me.mainScheduler)
                    .flatMap { _ -> Single<(Disk, Coordinate)> in
                        if canceller.isCancelled {
                            return .error(Error.turnOfComputerCancelled)
                        }
                        return .just((disk, coordinate))
                    }
                    .do(onSuccess: { [weak canceller] _ in
                        canceller?.cancel()
                    })
            }
            .bind(to: _handleDiskWithCoordinate)
            .disposed(by: disposeBag)
    }

    func canPlace(disk: Disk, at coordinate: Coordinate) -> Bool {
        !FlippedDiskCoordinates()
            .execute(disk: disk, at: coordinate, cells: store.cells.value)
            .isEmpty
    }

    func validMoves(for disk: Disk) -> [Coordinate] {
        store.cells.value.reduce([Coordinate]()) { result, rows in
            rows.reduce(result) { result, cell in
                if canPlace(disk: disk, at: cell.coordinate) {
                    return result + [cell.coordinate]
                } else {
                    return result
                }
            }
        }
    }

    func waitForPlayer() {
        let player: GameData.Player
        switch store.status.value {
        case .gameOver:
            return
        case .turn(.dark):
            player = store.playerDark.value
        case .turn(.light):
            player = store.playerLight.value
        }

        switch player {
        case .manual:
            break
        case .computer:
            playTurnOfComputer()
        }
    }

    func setPlayer(for disk: Disk, with index: Int) {
        switch disk {
        case .dark:
            actionCreator.setPlayerOfDark(GameData.Player(rawValue: index) ?? .manual)
        case .light:
            actionCreator.setPlayerOfLight(GameData.Player(rawValue: index) ?? .manual)
        }

        save()

        if let canceller = store.playerCancellers.value[disk] {
            canceller.cancel()
        }

        let player: GameData.Player
        switch disk {
        case .dark:
            player = store.playerDark.value
        case .light:
            player = store.playerLight.value
        }

        if !store.isDiskPlacing.value, store.status.value == .turn(disk), case .computer = player {
            playTurnOfComputer()
        }
    }

    func startGame() {
        _startGame.accept(())
    }

    func newGame() {
        _newGame.accept(())
    }

    func handle(selectedCoordinate: Coordinate) {
        guard
            !store.isDiskPlacing.value,
            case let .turn(turn) = store.status.value,
            case .manual = store.playerOfCurrentTurn.value
        else {
            return
        }
        _handleDiskWithCoordinate.accept((turn, selectedCoordinate))
    }

    func playTurnOfComputer() {
        guard
            case let .turn(disk) = store.status.value,
            let coordinate = validMoves(for: disk).randomElement()
        else {
            preconditionFailure()
        }

        _willTurnDiskOfComputer.accept(disk)

        let cleanUp: () -> Void = { [weak self] in
            guard let me = self else { return }
            me._didTurnDiskOfComputer.accept(disk)
            me.actionCreator.setPlayerCanceller(nil, for: disk)
        }
        let canceller = Canceller(cleanUp)
        actionCreator.setPlayerCanceller(canceller, for: disk)

        _readyComputerDisk.accept((disk, coordinate, canceller))
    }

    func nextTurn() {
        var turn: Disk
        switch store.status.value {
        case let .turn(disk):
            turn = disk
        case .gameOver:
            return
        }

        turn.flip()

        if validMoves(for: turn).isEmpty {
            if validMoves(for: turn.flipped).isEmpty {
                actionCreator.setStatus(.gameOver)
            } else {
                actionCreator.setStatus(.turn(turn))

                let alert = Alert.pass { [weak self] in
                    self?.nextTurn()
                }
                self._handerAlert.accept(alert)
            }
        } else {
            actionCreator.setStatus(.turn(turn))
            waitForPlayer()
        }
    }

    func prepareForReset() {
        let alert = Alert.reset { [weak self, store, actionCreator] in
            store.placeDiskCanceller.value?.cancel()
            actionCreator.setPlaceDiskCanceller(nil)

            for side in Disk.allCases {
                store.playerCancellers.value[side]?.cancel()
                actionCreator.setPlayerCanceller(nil, for: side)
            }

            self?.newGame()
            self?.waitForPlayer()
        }
        _handerAlert.accept(alert)
    }

    func save() {
        actionCreator.save(cells: store.cells.value,
                           status: store.status.value,
                           playerDark: store.playerDark.value,
                           playerLight: store.playerLight.value)
    }
}

extension GameLogic {

    enum Error: Swift.Error {
        case turnOfComputerCancelled
        case selfReleased
    }

    @available(*, unavailable)
    private enum MainScheduler {}
}
