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
        let nextTurnManagement: NextTurnManagementProtocol
        let playerTurnManagement: PlayerTurnManagementProtocol
        let alertManagement: AlertManagementProtocol
    }

    public static func bind(from dependency: Dependency<Input, State, Extra>, disposeBag: DisposeBag) -> Output {
        let input = dependency.inputObservables
        let state = dependency.state
        let extra = dependency.extra
        let store = extra.store
        let actionCreator = extra.actionCreator
        let nextTurnManagement = extra.nextTurnManagement
        let playerTurnManagement = extra.playerTurnManagement
        let alertManagement = extra.alertManagement

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

        let nextTurnResponse = nextTurnManagement(nextTurn: state.nextTurn.asObservable())
            .share()

        nextTurnResponse
            .flatMap { result -> Observable<Void> in
                guard case .validMoves = result else {
                    return .empty()
                }
                return .just(())
            }
            .bind(to: state.waitForPlayer)
            .disposed(by: disposeBag)

        let handleAlert = alertManagement(
                nextTurnResponse: nextTurnResponse,
                prepareForReset: input.prepareForReset,
                nextTurn: state.nextTurn,
                reset: state.reset,
                waitForPlayer: state.waitForPlayer
            )
            .share()

        let didRefreshAllDisk: Observable<Void> = store.loaded
            .withLatestFrom(store.cells)
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

        let didUpdateDisk = playerTurnManagement(
                waitForPlayer: Observable.merge(
                    input.waitForPlayer,
                    state.waitForPlayer.asObservable()
                ),
                setPlayerForDiskWithIndex: input.setPlayerForDiskWithIndex,
                handleSelectedCoordinate: input.handleSelectedCoordinate,
                save: state.save,
                willTurnDiskOfComputer: state.willTurnDiskOfComputer,
                didTurnDiskOfComputer: state.didTurnDiskOfComputer
            )
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
