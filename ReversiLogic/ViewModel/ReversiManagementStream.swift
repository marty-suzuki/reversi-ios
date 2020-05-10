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

    public static func bind(from dependency: Dependency<Input, State, Extra>, disposeBag: DisposeBag) -> Output {
        let input = dependency.inputObservables
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

        input.startGame
            .subscribe(onNext: { actionCreator.load() })
            .disposed(by: disposeBag)

        input.newGame
            .bind(to: state.reset)
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

        let nextTurnResult = nextTurnResultTrigger(dependency: dependency)

        nextTurnResult
            .flatMap { result -> Observable<Void> in
                guard case .validMoves = result else {
                    return .empty()
                }
                return .just(())
            }
            .bind(to: state.waitForPlayer)
            .disposed(by: disposeBag)

        let handleAlert = handleAlertTrigger(dependency: dependency,
                                             nextTurnResult: nextTurnResult)

        let didRefreshAllDisk: Observable<Void> = store.loaded
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

        let didUpdateDisk = placeDiskTrigger(dependency: dependency)
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
}

extension ReversiManagementStream {
    @available(*, unavailable)
    private enum MainScheduler {}

    private enum NextTurnResult {
        case gameOver
        case validMoves(GameData.Status)
        case noValidMoves(GameData.Status)
    }

    private static func handleAlertTrigger(dependency: Dependency<Input, State, Extra>,
                                           nextTurnResult: Observable<NextTurnResult>) -> Observable<Alert> {
        let input = dependency.inputObservables
        let state = dependency.state
        let extra = dependency.extra
        let actionCreator = extra.actionCreator
        let store = extra.store

        let noValidMovesAlert: Observable<Alert> = nextTurnResult
            .flatMap { result -> Observable<Alert> in
                guard case .noValidMoves = result else {
                    return .empty()
                }
                let alert = Alert.pass {
                    state.nextTurn.accept(())
                }
                return .just(alert)
            }

        let resetAlert: Observable<Alert> = input
            .prepareForReset
            .map { _ -> Alert in
                Alert.reset {
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

        return Observable.merge(noValidMovesAlert, resetAlert)
    }

    private static func nextTurnResultTrigger(dependency:  Dependency<Input, State, Extra>) -> Observable<NextTurnResult> {
        let state = dependency.state
        let extra = dependency.extra
        let store = extra.store
        let actionCreator = extra.actionCreator
        let validMoves = extra.validMoves

        return state.nextTurn
            .withLatestFrom(store.status)
            .flatMap { status -> Observable<NextTurnResult> in
                var turn: Disk
                switch status {
                case let .turn(disk):
                    turn = disk
                case .gameOver:
                    return .empty()
                }

                turn.flip()

                return validMoves(for: turn)
                    .flatMap { coordinates -> Single<NextTurnResult> in
                        if coordinates.isEmpty {
                            return validMoves(for: turn.flipped)
                                .flatMap { coordinates -> Single<NextTurnResult> in
                                    if coordinates.isEmpty {
                                        return .just(.gameOver)
                                    } else {
                                        return .just(.noValidMoves(.turn(turn)))
                                    }
                                }
                        } else {
                            return .just(.validMoves(.turn(turn)))
                        }
                    }
                    .asObservable()
            }
            .do(onNext: { result in
                switch result {
                case .gameOver:
                    actionCreator.setStatus(.gameOver)
                case let .validMoves(status),
                     let .noValidMoves(status):
                    actionCreator.setStatus(status)
                }
            })
            .share()
    }

    private static func placeDiskTrigger(dependency:  Dependency<Input, State, Extra>) -> Observable<(Disk, Coordinate)> {
        let input = dependency.inputObservables
        let extra = dependency.extra
        let state = dependency.state
        let store = extra.store
        let actionCreator = extra.actionCreator
        let validMoves = extra.validMoves
        let mainScheduler = extra.mainScheduler

        let playTurnOfComputerTrigger1: Observable<Void> = Observable.merge(
                input.waitForPlayer,
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

        let playTurnOfComputerTrigger2: Observable<Void> = {
            let sideEffectBeforeIsDiskPlacingCheck: (Disk, Int) -> Void = { disk, index in
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
            }

            let passIsDiskPlacingCheck: Observable<Disk> = input.setPlayerForDiskWithIndex
                .do(onNext: sideEffectBeforeIsDiskPlacingCheck)
                .withLatestFrom(store.isDiskPlacing) { ($0.0, $1) }
                .flatMap { disk, isDiskPlacing -> Observable<Disk> in
                    if isDiskPlacing {
                        return .empty()
                    } else {
                        return .just(disk)
                    }
                }

            let passComputerCheck: Observable<Disk> = passIsDiskPlacingCheck
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

            return passComputerCheck
                .withLatestFrom(store.status) { ($0, $1) }
                .flatMap { disk, status -> Observable<Void> in
                    guard case .turn(disk) = status else {
                        return .empty()
                    }
                    return .just(())
                }
        }()

        let computerPlaceDiskTrigger: Observable<(Disk, Coordinate)> = Observable.merge(
                playTurnOfComputerTrigger1,
                playTurnOfComputerTrigger2
            )
            .withLatestFrom(store.status)
            .flatMap { status -> Observable<(Disk, Coordinate)> in
                guard case let .turn(disk) = status else {
                    preconditionFailure()
                }
                return validMoves(for: disk)
                    .map { coordinates -> (Disk, Coordinate) in
                        guard let coordinate = coordinates.randomElement() else {
                            preconditionFailure()
                        }
                        return (disk, coordinate)
                    }
                    .asObservable()
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
                    .delay(.seconds(2), scheduler: mainScheduler)
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

        let manualPlaceDiskTrigger: Observable<(Disk, Coordinate)> = input
            .handleSelectedCoordinate
            .flatMap { coordinate -> Observable<(Disk, Coordinate)> in
                guard
                    !store.isDiskPlacing.value,
                    case let .turn(turn) = store.status.value,
                    case .manual = store.playerOfCurrentTurn.value
                else {
                    return .empty()
                }
                return .just((turn, coordinate))
            }

        return Observable.merge(computerPlaceDiskTrigger, manualPlaceDiskTrigger)
    }
}
