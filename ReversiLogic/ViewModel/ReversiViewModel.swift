import CoreGraphics
import RxCocoa
import RxSwift
import Unio

public final class ReversiViewModel: UnioStream<ReversiViewModel> {

    public struct Input: InputType {
        public let startGame = PublishRelay<Void>()
        public let viewDidAppear = PublishRelay<Void>()
        public let handleReset = PublishRelay<Void>()
        public let handleSelectedCoordinate = PublishRelay<Coordinate>()
        public let setPlayerWithDiskAndIndex = PublishRelay<(Disk, Int)>()
    }

    public struct Output: OutputType {
        public let messageDisk: Observable<Disk>
        public let messageDiskSizeConstant: Observable<CGFloat>
        public let messageText: Observable<String>
        public let showAlert: Observable<Alert>
        public let isPlayerDarkAnimating: Observable<Bool>
        public let isPlayerLightAnimating: Observable<Bool>
        public let playerDarkCount: Observable<String>
        public let playerLightCount: Observable<String>
        public let playerDarkSelectedIndex: Observable<Int>
        public let playerLightSelectedIndex: Observable<Int>
        public let resetBoard: Observable<Void>
        public let updateBoard: Observable<UpdateDisk>
    }

    public struct State: StateType {
        let messageDisk = PublishRelay<Disk>()
        let messageDiskSizeConstant = PublishRelay<CGFloat>()
        let messageText = PublishRelay<String>()
        let showAlert = PublishRelay<Alert>()
        let isPlayerDarkAnimating = PublishRelay<Bool>()
        let isPlayerLightAnimating = PublishRelay<Bool>()
        let playerDarkCount = PublishRelay<String>()
        let playerLightCount = PublishRelay<String>()
        let resetBoard = PublishRelay<Void>()
        let updateBoard = PublishRelay<UpdateDisk>()
        let updateCount = PublishRelay<Void>()
        let nextTurn = PublishRelay<Void>()
    }

    public struct Extra: ExtraType {
        let messageDiskSize: CGFloat
        let mainAsyncScheduler: SchedulerType
        let mainScheduler: SchedulerType
        let logic: GameLogicProtocol
    }

    public convenience init(messageDiskSize: CGFloat,
                            mainAsyncScheduler: SchedulerType,
                            mainScheduler: SchedulerType,
                            logicFactory: GameLogicFactoryProtocol) {
        self.init(input: Input(),
                  state: State(),
                  extra: Extra(messageDiskSize: messageDiskSize,
                               mainAsyncScheduler: mainAsyncScheduler,
                               mainScheduler: mainScheduler,
                               logic: logicFactory.make()))
    }

    public static func bind(from dependency: Dependency<Input, State, Extra>, disposeBag: DisposeBag) -> Output {
        let input = dependency.inputObservables
        let extra = dependency.extra
        let state = dependency.state
        let logic = extra.logic
        let messageDiskSize = extra.messageDiskSize

        logic.status
            .subscribe(onNext: { status in
                switch status {
                case let .turn(side):
                    state.messageDiskSizeConstant.accept(messageDiskSize)
                    state.messageDisk.accept(side)
                    state.messageText.accept("'s turn")
                case .gameOver:
                    if let winner = logic.sideWithMoreDisks.value {
                        state.messageDiskSizeConstant.accept(messageDiskSize)
                        state.messageDisk.accept(winner)
                        state.messageText.accept(" won")
                    } else {
                        state.messageDiskSizeConstant.accept(0)
                        state.messageText.accept("Tied")
                    }
                }
            })
            .disposed(by: disposeBag)

        logic.gameLoaded
            .subscribe(onNext: {
                logic.cells.value.forEach { rows in
                    rows.forEach { cell in
                        let update = UpdateDisk(disk: cell.disk, coordinate: cell.coordinate, animated: false, completion: nil)
                        state.updateBoard.accept(update)
                    }
                }
                state.updateCount.accept(())
            })
            .disposed(by: disposeBag)

        logic.newGameBegan
            .subscribe(onNext: {
                state.resetBoard.accept(())
                state.updateCount.accept(())
            })
            .disposed(by: disposeBag)

        logic.handleDiskWithCoordinate
            .flatMap { disk, coordinate -> Observable<Bool> in
                return placeDisk(disk, at: coordinate, animated: true, logic: logic, state: state, extra: extra)
                    .asObservable()
                    .catchError { _ in .empty() }
            }
            .subscribe(onNext: { _ in
                state.nextTurn.accept(())
                logic.save()
                state.updateCount.accept(())
            })
            .disposed(by: disposeBag)

        Observable.merge(logic.willTurnDiskOfComputer.map { ($0, true) },
                         logic.didTurnDiskOfComputer.map { ($0, false) })
            .subscribe(onNext: { disk, isAnimating in
                switch disk {
                case .dark: state.isPlayerDarkAnimating.accept(isAnimating)
                case .light: state.isPlayerLightAnimating.accept(isAnimating)
                }
            })
            .disposed(by: disposeBag)

        input.handleReset
            .map { _ -> Alert in
                Alert.reset {
                    logic.placeDiskCanceller?.cancel()
                    logic.placeDiskCanceller = nil

                    for side in Disk.allCases {
                        logic.playerCancellers[side]?.cancel()
                        logic.setPlayerCanceller(nil, for: side)
                    }

                    logic.newGame()
                    logic.waitForPlayer()
                }
            }
            .bind(to: state.showAlert)
            .disposed(by: disposeBag)

        input.handleSelectedCoordinate
            .subscribe(onNext: { logic.handle(selectedCoordinate: $0) })
            .disposed(by: disposeBag)

        input.setPlayerWithDiskAndIndex
            .subscribe(onNext: { logic.setPlayer(for: $0, with: $1) })
            .disposed(by: disposeBag)

        input.startGame
            .subscribe(onNext: { logic.startGame() })
            .disposed(by: disposeBag)

        input.viewDidAppear.take(1)
            .subscribe(onNext: { logic.waitForPlayer() })
            .disposed(by: disposeBag)

        state.updateCount
            .subscribe(onNext: {
                state.playerDarkCount.accept("\(logic.countOfDark.value)")
                state.playerLightCount.accept("\(logic.countOfLight.value)")
            })
            .disposed(by: disposeBag)

        state.nextTurn
            .subscribe(onNext: {
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
                        logic.setStatus(.gameOver)
                    } else {
                        logic.setStatus(.turn(turn))

                        let alert = Alert.pass {
                            state.nextTurn.accept(())
                        }
                        state.showAlert.accept(alert)
                    }
                } else {
                    logic.setStatus(.turn(turn))
                    logic.waitForPlayer()
                }
            })
            .disposed(by: disposeBag)

        return Output(messageDisk: state.messageDisk.asObservable(),
                      messageDiskSizeConstant: state.messageDiskSizeConstant.asObservable(),
                      messageText: state.messageText.asObservable(),
                      showAlert: state.showAlert.asObservable(),
                      isPlayerDarkAnimating: state.isPlayerDarkAnimating.asObservable(),
                      isPlayerLightAnimating: state.isPlayerLightAnimating.asObservable(),
                      playerDarkCount: state.playerDarkCount.asObservable(),
                      playerLightCount: state.playerLightCount.asObservable(),
                      playerDarkSelectedIndex: logic.playerDark.distinctUntilChanged().map { $0.rawValue },
                      playerLightSelectedIndex: logic.playerLight.distinctUntilChanged().map { $0.rawValue },
                      resetBoard: state.resetBoard.asObservable(),
                      updateBoard: state.updateBoard.asObservable())
    }
}

extension ReversiViewModel {

    static func setDisk(_ disk: Disk?,
                        at coordinate: Coordinate,
                        animated: Bool,
                        logic: GameLogicProtocol,
                        state: State) -> Single<Bool> {
        Single<Bool>.create { observer in
            logic.setDisk(disk, at: coordinate)
            let update = UpdateDisk(disk: disk, coordinate: coordinate, animated: animated) {
                observer(.success($0))
            }
            state.updateBoard.accept(update)
            return Disposables.create()
        }
    }

    static func animateSettingDisks(at coordinates: [Coordinate],
                                    to disk: Disk,
                                    logic:  GameLogicProtocol,
                                    state: State) -> Single<Bool> {
        guard let coordinate = coordinates.first else {
            return .just(true)
        }

        guard let placeDiskCanceller = logic.placeDiskCanceller else {
            return .error(Error.animationCancellerReleased)
        }

        return setDisk(disk, at: coordinate, animated: true, logic: logic, state: state)
            .flatMap { finished in
                if placeDiskCanceller.isCancelled {
                    return .error(Error.animationCancellerCancelled)
                }
                if finished {
                    return animateSettingDisks(at: Array(coordinates.dropFirst()), to: disk, logic: logic, state: state)
                } else {
                    let observables = coordinates.map { setDisk(disk, at: $0, animated: false, logic: logic, state: state).asObservable() }
                    return Observable.zip(observables)
                        .map { _ in false }
                        .asSingle()
                }
            }
    }

    /// - Parameter completion: A closure to be executed when the animation sequence ends.
    ///     This closure has no return value and takes a single Boolean argument that indicates
    ///     whether or not the animations actually finished before the completion handler was called.
    ///     If `animated` is `false`,  this closure is performed at the beginning of the next run loop cycle. This parameter may be `nil`.
    /// - Throws: `DiskPlacementError` if the `disk` cannot be placed at (`x`, `y`).
    static func placeDisk(_ disk: Disk,
                          at coordinate: Coordinate,
                          animated isAnimated: Bool,
                          logic:  GameLogicProtocol,
                          state: State,
                          extra: Extra) -> Single<Bool> {
        let diskCoordinates = logic.flippedDiskCoordinates(by: disk, at: coordinate)
        if diskCoordinates.isEmpty {
            return .error(Error.diskPlacement(disk: disk, coordinate: coordinate))
        }

        if isAnimated {
            let cleanUp: () -> Void = {
                logic.placeDiskCanceller = nil
            }
            logic.placeDiskCanceller = Canceller(cleanUp)
            return animateSettingDisks(at: [coordinate] + diskCoordinates, to: disk, logic: logic, state: state)
                .flatMap { finished in
                    guard  let canceller = logic.placeDiskCanceller else {
                        return .error(Error.animationCancellerReleased)
                    }

                    if canceller.isCancelled {
                        return .error(Error.animationCancellerCancelled)
                    }

                    return .just(finished)
                }
                .do(onSuccess: { _ in
                    cleanUp()
                })
        } else {
            let coordinates = [coordinate] + diskCoordinates
            let observables = coordinates.map {
                setDisk(disk, at: $0, animated: false, logic: logic, state: state).asObservable()
            }
            return Observable.just(())
                .observeOn(extra.mainAsyncScheduler)
                .flatMap { Observable.zip(observables) }
                .map { _ in true }
                .asSingle()
        }
    }

    enum Error: Swift.Error, Equatable {
        case diskPlacement(disk: Disk, coordinate: Coordinate)
        case animationCancellerReleased
        case animationCancellerCancelled
    }

    public struct UpdateDisk {
        public let disk: Disk?
        public let coordinate: Coordinate
        public let animated: Bool
        public let completion: ((Bool) -> Void)?
    }

    @available(*, unavailable)
    private enum MainScheduler {}
}
