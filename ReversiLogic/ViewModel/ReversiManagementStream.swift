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
                     mainAsyncScheduler: SchedulerType,
                     flippedDiskCoordinatesFactory: FlippedDiskCoordinatesFactoryProtocol,
                     setDiskFactory: SetDiskFactoryProtocol,
                     animateSettingDisksFactory: AnimateSettingDisksFactoryProtocol,
                     placeDiskFactory: PlaceDiskFactoryProtocol,
                     validMovesFactory: ValidMovesFactoryProtocol) {
        let state = State()

        let setDisk = setDiskFactory.make(
            updateDisk: state.updateDisk,
            actionCreator: actionCreator
        )

        let animateSettingDisks = animateSettingDisksFactory.make(
            setDisk: setDisk,
            store: store
        )

        let flippedDiskCoordinates = flippedDiskCoordinatesFactory.make(store: store)

        let placeDisk = placeDiskFactory.make(
            flippedDiskCoordinates: flippedDiskCoordinates,
            setDisk: setDisk,
            animateSettingDisks: animateSettingDisks,
            actionCreator: actionCreator,
            store: store,
            mainAsyncScheduler: mainAsyncScheduler
        )

        let validMoves = validMovesFactory.make(
            flippedDiskCoordinates: flippedDiskCoordinates,
            store: store
        )
        self.init(input: Input(),
                  state: state,
                  extra: Extra(store: store,
                               actionCreator: actionCreator,
                               mainScheduler: mainScheduler,
                               validMoves: validMoves,
                               setDisk: setDisk,
                               placeDisk: placeDisk))
    }
}

extension ReversiManagementStream {

    public struct Input: InputType {
        let waitForPlayer = PublishRelay<Void>()
        let setPlayerForDiskWithIndex = PublishRelay<(Disk, Int)>()
        let startGame = PublishRelay<Void>()
        let newGame = PublishRelay<Void>()
        let handleSelectedCoordinate = PublishRelay<Coordinate>()
        let nextTurn = PublishRelay<Void>()
        let prepareForReset = PublishRelay<Void>()
    }

    public struct Output: OutputType {
        let newGameBegan: Observable<Void>
        let willTurnDiskOfComputer: Observable<Disk>
        let didTurnDiskOfComputer: Observable<Disk>
        let handerAlert: Observable<Alert>

        let status: ValueObservable<GameData.Status>
        let sideWithMoreDisks: ValueObservable<Disk?>
        let countOfDark: ValueObservable<Int>
        let countOfLight: ValueObservable<Int>
        let playerDark: ValueObservable<GameData.Player>
        let playerLight: ValueObservable<GameData.Player>

        let updateDisk: Observable<UpdateDisk>
        let didUpdateDisk: Observable<Bool>
        let didRefreshAllDisk: Observable<Void>
    }

    public struct State: StateType {
        let newGame = PublishRelay<Void>()
        let readyComputerDisk = PublishRelay<(Disk, Coordinate, Canceller)>()

        let newGameBegan = PublishRelay<Void>()
        let willTurnDiskOfComputer = PublishRelay<Disk>()
        let didTurnDiskOfComputer = PublishRelay<Disk>()
        let handerAlert = PublishRelay<Alert>()

        let updateDisk = PublishRelay<UpdateDisk>()
    }

    public struct Extra: ExtraType {
        let store: GameStoreProtocol
        let actionCreator: GameActionCreatorProtocol
        let mainScheduler: SchedulerType
        let validMoves: ValidMovesProtocol
        let setDisk: SetDiskProtocol
        let placeDisk: PlaceDiskProtocol
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

        dependency.inputObservables.waitForPlayer
            .subscribe(onNext: { waitForPlayer(extra: extra, state: state) })
            .disposed(by: disposeBag)

        dependency.inputObservables.setPlayerForDiskWithIndex
            .subscribe(onNext: { setPlayer(for: $0, with: $1, extra: extra, state: state) })
            .disposed(by: disposeBag)

        dependency.inputObservables.newGame
            .bind(to: state.newGame)
            .disposed(by: disposeBag)

        let nextTurn = PublishRelay<Void>()
        Observable.merge(dependency.inputObservables.nextTurn,
                         nextTurn.asObservable())
            .subscribe(onNext: {
                let store = extra.store
                let actionCreator = extra.actionCreator
                let validMoves = extra.validMoves

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

                        let alert = Alert.pass {
                            nextTurn.accept(())
                        }
                        state.handerAlert.accept(alert)
                    }
                } else {
                    actionCreator.setStatus(.turn(turn))
                    waitForPlayer(extra: extra, state: state)
                }
            })
            .disposed(by: disposeBag)

        dependency.inputObservables.prepareForReset
            .map { _ -> Alert in
                Alert.reset {
                    let actionCreator = extra.actionCreator
                    let store = extra.store

                    store.placeDiskCanceller.value?.cancel()
                    actionCreator.setPlaceDiskCanceller(nil)

                    for side in Disk.allCases {
                        store.playerCancellers.value[side]?.cancel()
                        actionCreator.setPlayerCanceller(nil, for: side)
                    }

                    state.newGame.accept(())
                    waitForPlayer(extra: extra, state: state)
                }
            }
            .bind(to: state.handerAlert)
            .disposed(by: disposeBag)

        let didRefreshAllDisk = store.loaded
            .withLatestFrom(extra.store.cells)
            .flatMap { cells -> Observable<Void> in
                let updates = cells.flatMap { rows in
                    rows.map { cell in
                        extra.setDisk(cell.disk,
                                      at: cell.coordinate,
                                      animated: false).asObservable()
                    }
                }
                return Observable.zip(updates).map { _ in }
            }
            .share()

        let handleDiskWithCoordinate: Observable<(Disk, Coordinate)> = {
            let o1 = dependency.inputObservables.handleSelectedCoordinate
                .flatMap { coordinate -> Observable<(Disk, Coordinate)> in
                    let store = extra.store
                    guard
                        !store.isDiskPlacing.value,
                        case let .turn(turn) = store.status.value,
                        case .manual = store.playerOfCurrentTurn.value
                    else {
                        return .empty()
                    }
                    return .just((turn, coordinate))
                }

            let o2 = state.readyComputerDisk
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
                .asObservable()

            return Observable.merge(o1, o2)
        }()

        let didUpdateDisk = handleDiskWithCoordinate
            .flatMap { disk, coordinate -> Observable<Bool> in
                extra.placeDisk(disk, at: coordinate, animated: true)
                    .asObservable()
                    .catchError { _ in .empty() }
            }
            .do(onNext: { _ in
                save(extra: extra)
            })
            .share()

        return Output(
            newGameBegan: state.newGameBegan.asObservable(),
            willTurnDiskOfComputer: state.willTurnDiskOfComputer.asObservable(),
            didTurnDiskOfComputer: state.didTurnDiskOfComputer.asObservable(),
            handerAlert: state.handerAlert.asObservable(),
            status: store.status,
            sideWithMoreDisks: store.sideWithMoreDisks,
            countOfDark: store.countOfDark,
            countOfLight: store.countOfLight,
            playerDark: store.playerDark,
            playerLight: store.playerLight,
            updateDisk: state.updateDisk.asObservable(),
            didUpdateDisk: didUpdateDisk,
            didRefreshAllDisk: didRefreshAllDisk
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

    static func playTurnOfComputer(extra: Extra, state: State) {
        let store = extra.store
        let actionCreator = extra.actionCreator
        let validMoves = extra.validMoves
        guard
            case let .turn(disk) = store.status.value,
            let coordinate = validMoves(for: disk).randomElement()
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

    @available(*, unavailable)
    private enum MainScheduler {}
}
