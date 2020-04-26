import RxCocoa
import RxSwift
import Unio

public protocol ReversiManagementStreamType: AnyObject {
    var input: InputWrapper<ReversiManagementStream.Input> { get }
    var output: OutputWrapper<ReversiManagementStream.Output> { get }
}

public final class ReversiManagementStream: UnioStream<ReversiManagementStream>, ReversiManagementStreamType {

    convenience init(store: GameStoreProtocol,
                     actionCreator: GameActionCreatorProtocol,
                     mainScheduler: SchedulerType,
                     flippedDiskCoordinates: FlippedDiskCoordinatesProtocol) {
        self.init(input: Input(),
                  state: State(),
                  extra: Extra(store: store,
                               actionCreator: actionCreator,
                               mainScheduler: mainScheduler,
                               flippedDiskCoordinates: flippedDiskCoordinates))
    }
}

extension ReversiManagementStream {

    public struct Input: InputType {
        let waitForPlayer = PublishRelay<Void>()
        let setPlayerForDiskWithIndex = PublishRelay<(Disk, Int)>()
        let startGame = PublishRelay<Void>()
        let newGame = PublishRelay<Void>()
        let handleSelectedCoordinate = PublishRelay<Coordinate>()
        let save = PublishRelay<Void>()
        let nextTurn = PublishRelay<Void>()
        let prepareForReset = PublishRelay<Void>()
    }

    public struct Output: OutputType {
        let gameLoaded: Observable<Void>
        let newGameBegan: Observable<Void>
        let handleDiskWithCoordinate: Observable<(Disk, Coordinate)>
        let willTurnDiskOfComputer: Observable<Disk>
        let didTurnDiskOfComputer: Observable<Disk>
        let handerAlert: Observable<Alert>

        let status: ValueObservable<GameData.Status>
        let sideWithMoreDisks: ValueObservable<Disk?>
        let countOfDark: ValueObservable<Int>
        let countOfLight: ValueObservable<Int>
        let playerDark: ValueObservable<GameData.Player>
        let playerLight: ValueObservable<GameData.Player>
    }

    public struct State: StateType {
        let newGame = PublishRelay<Void>()
        let readyComputerDisk = PublishRelay<(Disk, Coordinate, Canceller)>()

        let newGameBegan = PublishRelay<Void>()
        let willTurnDiskOfComputer = PublishRelay<Disk>()
        let didTurnDiskOfComputer = PublishRelay<Disk>()
        let handleDiskWithCoordinate = PublishRelay<(Disk, Coordinate)>()
        let handerAlert = PublishRelay<Alert>()
    }

    public struct Extra: ExtraType {
        let store: GameStoreProtocol
        let actionCreator: GameActionCreatorProtocol
        let mainScheduler: SchedulerType
        let flippedDiskCoordinates: FlippedDiskCoordinatesProtocol
    }

    public static func bind(from dependency: Dependency<Input, State, Extra>, disposeBag: DisposeBag) -> Output {

        let state = dependency.state
        let extra = dependency.extra
        let store = extra.store
        let actionCreator = extra.actionCreator

        Observable.merge(state.newGame.asObservable(),
                         store.faildToLoad)
            .subscribe(onNext: {
                actionCreator.reset()
                state.newGameBegan.accept(())
                save(extra: extra)
            })
            .disposed(by: disposeBag)

        dependency.inputObservables.startGame
            .subscribe(onNext: { actionCreator.load() })
            .disposed(by: disposeBag)

        state.readyComputerDisk
            .flatMap { disk, coordinate, canceller -> Maybe<(Disk, Coordinate)> in
                weak var canceller = canceller
                return Maybe.just(())
                    .delay(.seconds(2), scheduler: extra.mainScheduler)
                    .flatMap { _ -> Maybe<(Disk, Coordinate)> in
                        if let canceller = canceller, canceller.isCancelled {
                            return .empty()
                        }
                        return .just((disk, coordinate))
                    }
                    .do(onNext: { _ in
                        canceller?.cancel()
                    })
            }
            .bind(to: state.handleDiskWithCoordinate)
            .disposed(by: disposeBag)

        dependency.inputObservables.waitForPlayer
            .subscribe(onNext: { waitForPlayer(extra: extra, state: state) })
            .disposed(by: disposeBag)

        dependency.inputObservables.setPlayerForDiskWithIndex
            .subscribe(onNext: { setPlayer(for: $0, with: $1, extra: extra, state: state) })
            .disposed(by: disposeBag)

        dependency.inputObservables.newGame
            .bind(to: state.newGame)
            .disposed(by: disposeBag)

        dependency.inputObservables.handleSelectedCoordinate
            .subscribe(onNext: { handle(selectedCoordinate: $0, extra: extra, state: state) })
            .disposed(by: disposeBag)

        dependency.inputObservables.save
            .subscribe(onNext: { save(extra: extra) })
            .disposed(by: disposeBag)

        dependency.inputObservables.nextTurn
            .subscribe(onNext: { nextTurn(extra: extra, state: state) })
            .disposed(by: disposeBag)

        dependency.inputObservables.prepareForReset
            .subscribe(onNext: { prepareForReset(extra: extra, state: state) })
            .disposed(by: disposeBag)

        return Output(
            gameLoaded: store.loaded,
            newGameBegan: state.newGameBegan.asObservable(),
            handleDiskWithCoordinate: state.handleDiskWithCoordinate.asObservable(),
            willTurnDiskOfComputer: state.willTurnDiskOfComputer.asObservable(),
            didTurnDiskOfComputer: state.didTurnDiskOfComputer.asObservable(),
            handerAlert: state.handerAlert.asObservable(),
            status: store.status,
            sideWithMoreDisks: store.sideWithMoreDisks,
            countOfDark: store.countOfDark,
            countOfLight: store.countOfLight,
            playerDark: store.playerDark,
            playerLight: store.playerLight
        )
    }
}

extension ReversiManagementStream {

    static func save(extra: Extra) {
        let store = extra.store
        extra.actionCreator.save(cells: store.cells.value,
                                 status: store.status.value,
                                 playerDark: store.playerDark.value,
                                 playerLight: store.playerLight.value)
    }

    static func canPlace(disk: Disk, at coordinate: Coordinate, extra: Extra) -> Bool {
        return !extra.flippedDiskCoordinates(by: disk, at: coordinate, cells: extra.store.cells.value)
            .isEmpty
    }

    static func validMoves(for disk: Disk, extra: Extra) -> [Coordinate] {
        extra.store.cells.value.reduce([Coordinate]()) { result, rows in
            rows.reduce(result) { result, cell in
                if canPlace(disk: disk, at: cell.coordinate, extra: extra) {
                    return result + [cell.coordinate]
                } else {
                    return result
                }
            }
        }
    }

    static func playTurnOfComputer(extra: Extra, state: State) {
        let store = extra.store
        let actionCreator = extra.actionCreator
        guard
            case let .turn(disk) = store.status.value,
            let coordinate = validMoves(for: disk, extra: extra).randomElement()
        else {
            preconditionFailure()
        }

        state.willTurnDiskOfComputer.accept(disk)

        let cleanUp: () -> Void = {
            state.didTurnDiskOfComputer.accept(disk)
            actionCreator.setPlayerCanceller(nil, for: disk)
        }
        let canceller = Canceller(cleanUp)
        actionCreator.setPlayerCanceller(canceller, for: disk)

        state.readyComputerDisk.accept((disk, coordinate, canceller))
    }

    static func waitForPlayer(extra: Extra, state: State) {
        let store = extra.store
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
            playTurnOfComputer(extra: extra, state: state)
        }
    }

    static func setPlayer(for disk: Disk, with index: Int, extra: Extra, state: State) {
        let actionCreator = extra.actionCreator
        let store = extra.store
        switch disk {
        case .dark:
            actionCreator.setPlayerOfDark(GameData.Player(rawValue: index) ?? .manual)
        case .light:
            actionCreator.setPlayerOfLight(GameData.Player(rawValue: index) ?? .manual)
        }

        save(extra: extra)

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
            playTurnOfComputer(extra: extra, state: state)
        }
    }

    static func handle(selectedCoordinate: Coordinate, extra: Extra, state: State) {
        let store = extra.store
        guard
            !store.isDiskPlacing.value,
            case let .turn(turn) = store.status.value,
            case .manual = store.playerOfCurrentTurn.value
        else {
            return
        }
        state.handleDiskWithCoordinate.accept((turn, selectedCoordinate))
    }

    static func nextTurn(extra: Extra, state: State) {
        let store = extra.store
        let actionCreator = extra.actionCreator

        var turn: Disk
        switch store.status.value {
        case let .turn(disk):
            turn = disk
        case .gameOver:
            return
        }

        turn.flip()

        if validMoves(for: turn, extra: extra).isEmpty {
            if validMoves(for: turn.flipped, extra: extra).isEmpty {
                actionCreator.setStatus(.gameOver)
            } else {
                actionCreator.setStatus(.turn(turn))

                let alert = Alert.pass {
                    nextTurn(extra: extra, state: state)
                }
                state.handerAlert.accept(alert)
            }
        } else {
            actionCreator.setStatus(.turn(turn))
            waitForPlayer(extra: extra, state: state)
        }
    }

    static func prepareForReset(extra: Extra, state: State) {
        let actionCreator = extra.actionCreator
        let store = extra.store

        let alert = Alert.reset {
            store.placeDiskCanceller.value?.cancel()
            actionCreator.setPlaceDiskCanceller(nil)

            for side in Disk.allCases {
                store.playerCancellers.value[side]?.cancel()
                actionCreator.setPlayerCanceller(nil, for: side)
            }

            state.newGame.accept(())
            waitForPlayer(extra: extra, state: state)
        }
        state.handerAlert.accept(alert)
    }

    @available(*, unavailable)
    private enum MainScheduler {}
}
