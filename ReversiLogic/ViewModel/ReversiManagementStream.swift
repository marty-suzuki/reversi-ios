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
        let playTurnOfComputer = PublishRelay<Void>()

        let newGameBegan = PublishRelay<Void>()
        let willTurnDiskOfComputer = PublishRelay<Disk>()
        let didTurnDiskOfComputer = PublishRelay<Disk>()
        let handerAlert = PublishRelay<Alert>()

        let updateDisk = PublishRelay<UpdateDisk>()

        let save = PublishRelay<Void>()
        let waitForPlayer = PublishRelay<Void>()
        let nextTurn = PublishRelay<Void>()
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
                state.save.accept(())
            })
            .disposed(by: disposeBag)

        dependency.inputObservables.startGame
            .subscribe(onNext: { actionCreator.load() })
            .disposed(by: disposeBag)

        Observable.merge(dependency.inputObservables.waitForPlayer,
                         state.waitForPlayer.asObservable())
            .withLatestFrom(store.status)
            .withLatestFrom(store.playerDark) { ($0, $1) }
            .withLatestFrom(store.playerLight) { ($0.0, $0.1, $1) }
            .flatMap { status, playerDark, playerLight -> Observable<Void> in
                let player: GameData.Player
                switch status {
                case .gameOver:
                    return .empty()
                case .turn(.dark):
                    player = playerDark
                case .turn(.light):
                    player = playerLight
                }

                switch player {
                case .manual:
                    return .empty()
                case .computer:
                    return .just(())
                }
            }
            .bind(to: state.playTurnOfComputer)
            .disposed(by: disposeBag)

        dependency.inputObservables.setPlayerForDiskWithIndex
            .do(onNext: { disk, index in
                let actionCreator = extra.actionCreator
                let store = extra.store
                switch disk {
                case .dark:
                    actionCreator.setPlayerOfDark(GameData.Player(rawValue: index) ?? .manual)
                case .light:
                    actionCreator.setPlayerOfLight(GameData.Player(rawValue: index) ?? .manual)
                }

                state.save.accept(())

                if let canceller = store.playerCancellers.value[disk] {
                    canceller.cancel()
                }
            })
            .withLatestFrom(store.isDiskPlacing) { ($0.0, $1) }
            .flatMap { disk, isDiskPlacing -> Observable<Disk> in
                if isDiskPlacing {
                    return .empty()
                } else {
                    return .just(disk)
                }
            }
            .withLatestFrom(store.playerDark) { ($0, $1) }
            .withLatestFrom(store.playerLight) { ($0.0, $0.1, $1) }
            .flatMap { disk, playerDark, playerLight -> Observable<Disk> in
                let player: GameData.Player
                switch disk {
                case .dark:
                    player = playerDark
                case .light:
                    player = playerLight
                }
                guard case .computer = player else {
                    return .empty()
                }
                return .just(disk)
            }
            .withLatestFrom(store.status) { ($0, $1) }
            .flatMap { disk, status -> Observable<Void> in
                guard case .turn(disk) = status else {
                    return .empty()
                }
                return .just(())
            }
            .bind(to: state.playTurnOfComputer)
            .disposed(by: disposeBag)

        dependency.inputObservables.newGame
            .bind(to: state.newGame)
            .disposed(by: disposeBag)

        state.nextTurn
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
                            state.nextTurn.accept(())
                        }
                        state.handerAlert.accept(alert)
                    }
                } else {
                    actionCreator.setStatus(.turn(turn))
                    state.waitForPlayer.accept(())
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
                    state.waitForPlayer.accept(())
                }
            }
            .bind(to: state.handerAlert)
            .disposed(by: disposeBag)

        state.save
            .subscribe(onNext: {
                #if DEBUG
                print("""
                status: \(store.status.value)
                dark: \(store.playerDark.value)
                light: \(store.playerLight.value)

                """)
                #endif
                actionCreator.save(cells: store.cells.value,
                                   status: store.status.value,
                                   playerDark: store.playerDark.value,
                                   playerLight: store.playerLight.value)
            })
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

            let o2 = state.playTurnOfComputer
                .map { _ -> (Disk, Coordinate) in
                    let validMoves = extra.validMoves
                    guard
                        case let .turn(disk) = store.status.value,
                        let coordinate = validMoves(for: disk).randomElement()
                    else {
                        preconditionFailure()
                    }
                    return (disk, coordinate)
                }
                .do(onNext: { disk, _ in
                    state.willTurnDiskOfComputer.accept(disk)
                })
                .map { disk, coordinate -> (Disk, Coordinate, Canceller) in
                    let cleanUp: () -> Void = {
                        state.didTurnDiskOfComputer.accept(disk)
                        actionCreator.setPlayerCanceller(nil, for: disk)
                    }
                    return (disk, coordinate, Canceller(cleanUp))
                }
                .do(onNext: { disk, _, canceller in
                    actionCreator.setPlayerCanceller(canceller, for: disk)
                })
                .flatMap { disk, coordinate, canceller -> Maybe<(Disk, Coordinate)> in
                    weak var canceller = canceller
                    return Maybe.just(())
                        .delay(.seconds(2), scheduler: extra.mainScheduler)
                        .flatMap { _ -> Maybe<(Disk, Coordinate)> in
                            guard
                                let canceller = canceller,
                                !canceller.isCancelled
                            else {
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
                state.nextTurn.accept(())
                state.save.accept(())
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

    @available(*, unavailable)
    private enum MainScheduler {}
}
