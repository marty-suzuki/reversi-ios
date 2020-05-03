import RxCocoa
import RxSwift
import Unio

public protocol ReversiManagementStreamType: AnyObject {
    var input: InputWrapper<ReversiManagementStream.Input> { get }
    var output: OutputWrapper<ReversiManagementStream.Output> { get }
}

public final class ReversiManagementStream: UnioStream<ReversiManagementStream>, ReversiManagementStreamType {

    public struct Input: InputType {
        let waitForPlayer = PublishRelay<Void>()
        let setPlayerForDiskWithIndex = PublishRelay<(Disk, Int)>()
        let startGame = PublishRelay<Void>()
        let newGame = PublishRelay<Void>()
        let handleSelectedCoordinate = PublishRelay<Coordinate>()
        let prepareForReset = PublishRelay<Void>()
    }

    public struct Output: OutputType {
        let status: ValueObservable<GameData.Status>
        let sideWithMoreDisks: ValueObservable<Disk?>
        let countOfDark: ValueObservable<Int>
        let countOfLight: ValueObservable<Int>
        let playerDark: ValueObservable<GameData.Player>
        let playerLight: ValueObservable<GameData.Player>
        let newGameBegan: Observable<Void>
        let willTurnDiskOfComputer: Observable<Disk>
        let didTurnDiskOfComputer: Observable<Disk>
        let handleAlert: Observable<Alert>
        let updateDisk: Observable<UpdateDisk>
        let didUpdateDisk: Observable<Bool>
        let didRefreshAllDisk: Observable<Void>
    }

    public struct State: StateType {
        let reset = PublishRelay<Void>()
        let newGameBegan = PublishRelay<Void>()
        let willTurnDiskOfComputer = PublishRelay<Disk>()
        let didTurnDiskOfComputer = PublishRelay<Disk>()
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

    private enum NextTurnResult {
        case gameOver
        case validMoves(GameData.Status)
        case noValidMoves(GameData.Status)
    }

    public static func bind(from dependency: Dependency<Input, State, Extra>, disposeBag: DisposeBag) -> Output {

        let state = dependency.state
        let extra = dependency.extra
        let store = extra.store
        let actionCreator = extra.actionCreator

        Observable.merge(state.reset.asObservable(),
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

        dependency.inputObservables.newGame
            .bind(to: state.reset)
            .disposed(by: disposeBag)

        let nextTurnResult = state.nextTurn
            .withLatestFrom(extra.store.status)
            .flatMap { status -> Observable<NextTurnResult> in
                let validMoves = extra.validMoves
                var turn: Disk
                switch store.status.value {
                case let .turn(disk):
                    turn = disk
                case .gameOver:
                    return .empty()
                }

                turn.flip()

                if validMoves(for: turn).isEmpty {
                    if validMoves(for: turn.flipped).isEmpty {
                        return .just(.gameOver)
                    } else {
                        return .just(.noValidMoves(.turn(turn)))
                    }
                } else {
                    return .just(.validMoves(.turn(turn)))
                }
            }
            .do(onNext: { result in
                let actionCreator = extra.actionCreator
                switch result {
                case .gameOver:
                    actionCreator.setStatus(.gameOver)
                case let .validMoves(status),
                     let .noValidMoves(status):
                    actionCreator.setStatus(status)
                }
            })
            .share()

        nextTurnResult
            .flatMap { result -> Observable<Void> in
                guard case .validMoves = result else {
                    return .empty()
                }
                return .just(())
            }
            .bind(to: state.waitForPlayer)
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

        let handleAlert: Observable<Alert> = {
            let o1 = nextTurnResult
                .flatMap { result -> Observable<Alert> in
                    guard case .noValidMoves = result else {
                        return .empty()
                    }
                    let alert = Alert.pass {
                        state.nextTurn.accept(())
                    }
                    return .just(alert)
                }
                .share()

            let o2 = dependency.inputObservables.prepareForReset
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

                        state.reset.accept(())
                        state.waitForPlayer.accept(())
                    }
                }
                .share()

            return Observable.merge(o1, o2)
        }()

        let didRefreshAllDisk = store.loaded
            .withLatestFrom(extra.store.cells)
            .flatMap { cells -> Observable<Void> in
                let updates = cells.flatMap { rows in
                    rows.map { cell in
                        extra.setDisk(cell.disk,
                                      at: cell.coordinate,
                                      animated: false,
                                      updateDisk: state.updateDisk)
                            .asObservable()
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

            let playTurnOfComputer1 = Observable.merge(
                    dependency.inputObservables.waitForPlayer,
                    state.waitForPlayer.asObservable()
                )
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

            let playTurnOfComputer2 = dependency.inputObservables.setPlayerForDiskWithIndex
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

            let o2 = Observable.merge(
                    playTurnOfComputer1,
                    playTurnOfComputer2
                )
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
                extra.placeDisk(disk,
                                at: coordinate,
                                animated: true,
                                updateDisk: state.updateDisk)
                    .asObservable()
                    .catchError { _ in .empty() }
            }
            .do(onNext: { _ in
                state.nextTurn.accept(())
                state.save.accept(())
            })
            .share()

        return Output(
            status: store.status,
            sideWithMoreDisks: store.sideWithMoreDisks,
            countOfDark: store.countOfDark,
            countOfLight: store.countOfLight,
            playerDark: store.playerDark,
            playerLight: store.playerLight,
            newGameBegan: state.newGameBegan.asObservable(),
            willTurnDiskOfComputer: state.willTurnDiskOfComputer.asObservable(),
            didTurnDiskOfComputer: state.didTurnDiskOfComputer.asObservable(),
            handleAlert: handleAlert,
            updateDisk: state.updateDisk.asObservable(),
            didUpdateDisk: didUpdateDisk,
            didRefreshAllDisk: didRefreshAllDisk
        )
    }

    @available(*, unavailable)
    private enum MainScheduler {}
}
