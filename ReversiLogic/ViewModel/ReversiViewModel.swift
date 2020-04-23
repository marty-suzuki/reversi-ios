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
        let placeDiskStream: ReversiPlaceDiskStreamType
    }

    public convenience init(messageDiskSize: CGFloat,
                            mainAsyncScheduler: SchedulerType,
                            mainScheduler: SchedulerType,
                            logicFactory: GameLogicFactoryProtocol) {
        let placeDiskStream = ReversiPlaceDiskStream(
            actionCreator: logicFactory.actionCreator,
            store: logicFactory.store,
            mainAsyncScheduler: mainAsyncScheduler,
            flippedDiskCoordinates: FlippedDiskCoordinates()
        )
        self.init(input: Input(),
                  state: State(),
                  extra: Extra(messageDiskSize: messageDiskSize,
                               mainAsyncScheduler: mainAsyncScheduler,
                               mainScheduler: mainScheduler,
                               logic: logicFactory.make(),
                               placeDiskStream: placeDiskStream))
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

        logic.newGameBegan
            .subscribe(onNext: {
                state.resetBoard.accept(())
                state.updateCount.accept(())
            })
            .disposed(by: disposeBag)

        do {
            let input = extra.placeDiskStream.input
            let output = extra.placeDiskStream.output

            logic.gameLoaded
                .bind(to: input.refreshAllDisk)
                .disposed(by: disposeBag)

            output.didRefreshAllDisk
                .bind(to: state.updateCount)
                .disposed(by: disposeBag)

            output.updateDisk
                .bind(to: state.updateBoard)
                .disposed(by: disposeBag)

            output.didUpdateDisk
                .subscribe(onNext: { _ in
                    state.nextTurn.accept(())
                    logic.save()
                    state.updateCount.accept(())
                })
                .disposed(by: disposeBag)

            logic.handleDiskWithCoordinate
                .bind(to: input.handleDiskWithCoordinate)
                .disposed(by: disposeBag)
        }

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

    @available(*, unavailable)
    private enum MainScheduler {}
}
