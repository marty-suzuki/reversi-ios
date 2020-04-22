import RxCocoa
import RxSwift

@dynamicMemberLookup
public protocol GameLogicProtocol: AnyObject {
    var isDiskPlacing: Bool { get }
    var placeDiskCanceller: Canceller? { get set }

    var playerCancellers: [Disk: Canceller] { get set }
    var gameLoaded: Observable<Void> { get }
    var newGameBegan: Observable<Void> { get }
    var handleDiskWithCoordinate: Observable<(Disk, Coordinate)> { get }
    var willTurnDiskOfComputer: Observable<Disk> { get}
    var didTurnDiskOfComputer: Observable<Disk> { get }

    func flippedDiskCoordinates(by disk: Disk,
                                at coordinate: Coordinate) -> [Coordinate]
    func validMoves(for disk: Disk) -> [Coordinate]
    func waitForPlayer()
    func setPlayer(for disk: Disk, with index: Int)
    func startGame()
    func newGame()
    func setDisk(_ disk: Disk?, at coordinate: Coordinate)
    func setStatus(_ status: GameData.Status)
    func handle(selectedCoordinate: Coordinate)
    func save()

    subscript<T>(dynamicMember keyPath: KeyPath<GameStoreProtocol, ValueObservable<T>>) -> ValueObservable<T> { get }
}

extension GameLogicProtocol {

    var isDiskPlacing: Bool {
        placeDiskCanceller != nil
    }
}

final class GameLogic: GameLogicProtocol {

    var playerCancellers: [Disk: Canceller] = [:]

    var placeDiskCanceller: Canceller?

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

    subscript<T>(dynamicMember keyPath: KeyPath<GameStoreProtocol, ValueObservable<T>>) -> ValueObservable<T> {
        store[keyPath: keyPath]
    }

    func flippedDiskCoordinates(by disk: Disk,
                                at coordinate: Coordinate) -> [Coordinate] {
        let directions = [
            (x: -1, y: -1),
            (x:  0, y: -1),
            (x:  1, y: -1),
            (x:  1, y:  0),
            (x:  1, y:  1),
            (x:  0, y:  1),
            (x: -1, y:  0),
            (x: -1, y:  1),
        ]

        guard store.disk(at: coordinate) == nil else {
            return []
        }

        var diskCoordinates: [Coordinate] = []

        for direction in directions {
            var x = coordinate.x
            var y = coordinate.y

            var diskCoordinatesInLine: [Coordinate] = []
            flipping: while true {
                x += direction.x
                y += direction.y

                let coordinate = Coordinate(x: x, y: y)
                switch (disk, store.disk(at: coordinate)) { // Uses tuples to make patterns exhaustive
                case (.dark, .dark?), (.light, .light?):
                    diskCoordinates.append(contentsOf: diskCoordinatesInLine)
                    break flipping
                case (.dark, .light?), (.light, .dark?):
                    diskCoordinatesInLine.append(coordinate)
                case (_, .none):
                    break flipping
                }
            }
        }

        return diskCoordinates
    }

    func canPlace(disk: Disk, at coordinate: Coordinate) -> Bool {
        !flippedDiskCoordinates(by: disk, at: coordinate).isEmpty
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

        if let canceller = playerCancellers[disk] {
            canceller.cancel()
        }

        let player: GameData.Player
        switch disk {
        case .dark:
            player = store.playerDark.value
        case .light:
            player = store.playerLight.value
        }

        if !isDiskPlacing, store.status.value == .turn(disk), case .computer = player {
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
            !isDiskPlacing,
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
            me.playerCancellers[disk] = nil
        }
        let canceller = Canceller(cleanUp)
        playerCancellers[disk] = canceller

        _readyComputerDisk.accept((disk, coordinate, canceller))
    }
}

extension GameLogic {

    enum Error: Swift.Error {
        case turnOfComputerCancelled
        case selfReleased
    }

    func save() {
        actionCreator.save(cells: store.cells.value,
                           status: store.status.value,
                           playerDark: store.playerDark.value,
                           playerLight: store.playerLight.value)
    }

    func setStatus(_ status: GameData.Status) {
        actionCreator.setStatus(status)
    }

    func setDisk(_ disk: Disk?, at coordinate: Coordinate) {
        actionCreator.setDisk(disk, at: coordinate)
    }
}
