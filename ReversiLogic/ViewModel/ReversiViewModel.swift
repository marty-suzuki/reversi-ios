import CoreGraphics
import RxCocoa
import RxSwift
import Unio

public protocol ReversiViewModelType: AnyObject {
    var input: InputWrapper<ReversiViewModel.Input> { get }
    var output: OutputWrapper<ReversiViewModel.Output> { get }
}

public final class ReversiViewModel: UnioStream<ReversiViewModel>, ReversiViewModelType {

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
        let isPlayerDarkAnimating = PublishRelay<Bool>()
        let isPlayerLightAnimating = PublishRelay<Bool>()
        let playerDarkCount = PublishRelay<String>()
        let playerLightCount = PublishRelay<String>()
        let resetBoard = PublishRelay<Void>()
    }

    public struct Extra: ExtraType {
        let messageDiskSize: CGFloat
        let mainAsyncScheduler: SchedulerType
        let mainScheduler: SchedulerType
        let managementStream: ReversiManagementStreamType
    }

    convenience init(messageDiskSize: CGFloat,
                     mainAsyncScheduler: SchedulerType,
                     mainScheduler: SchedulerType,
                     managementStream: ReversiManagementStreamType) {
        self.init(input: Input(),
                  state: State(),
                  extra: Extra(messageDiskSize: messageDiskSize,
                               mainAsyncScheduler: mainAsyncScheduler,
                               mainScheduler: mainScheduler,
                               managementStream: managementStream))
    }

    public static func bind(from dependency: Dependency<Input, State, Extra>, disposeBag: DisposeBag) -> Output {
        let input = dependency.inputObservables
        let extra = dependency.extra
        let state = dependency.state
        let managementStream = extra.managementStream
        let messageDiskSize = extra.messageDiskSize

        managementStream.output.status
            .subscribe(onNext: { status in
                switch status {
                case let .turn(side):
                    state.messageDiskSizeConstant.accept(messageDiskSize)
                    state.messageDisk.accept(side)
                    state.messageText.accept("'s turn")
                case .gameOver:
                    if let winner = managementStream.output.sideWithMoreDisks.value {
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

        Observable.merge(managementStream.output.willTurnDiskOfComputer.map { ($0, true) },
                         managementStream.output.didTurnDiskOfComputer.map { ($0, false) })
            .subscribe(onNext: { disk, isAnimating in
                switch disk {
                case .dark: state.isPlayerDarkAnimating.accept(isAnimating)
                case .light: state.isPlayerLightAnimating.accept(isAnimating)
                }
            })
            .disposed(by: disposeBag)

        input.handleReset
            .bind(to: managementStream.input.prepareForReset)
            .disposed(by: disposeBag)

        input.handleSelectedCoordinate
            .bind(to: managementStream.input.handleSelectedCoordinate)
            .disposed(by: disposeBag)

        input.setPlayerWithDiskAndIndex
            .bind(to: managementStream.input.setPlayerForDiskWithIndex)
            .disposed(by: disposeBag)

        input.startGame
            .bind(to: managementStream.input.startGame)
            .disposed(by: disposeBag)

        input.viewDidAppear.take(1)
            .bind(to: managementStream.input.waitForPlayer)
            .disposed(by: disposeBag)

        do {
            let updateCount1 = managementStream.output.newGameBegan
                .do(onNext: {
                    state.resetBoard.accept(())
                })

            let updateCount2 = managementStream.output.didUpdateDisk
                .map { _ in }
                .do(onNext: {
                    managementStream.input.nextTurn(())
                })

            Observable.merge(updateCount1,
                             updateCount2,
                             managementStream.output.didRefreshAllDisk)
                .subscribe(onNext: {
                    state.playerDarkCount.accept("\(managementStream.output.countOfDark.value)")
                    state.playerLightCount.accept("\(managementStream.output.countOfLight.value)")
                })
                .disposed(by: disposeBag)
        }

        return Output(
            messageDisk: state.messageDisk.asObservable(),
            messageDiskSizeConstant: state.messageDiskSizeConstant.asObservable(),
            messageText: state.messageText.asObservable(),
            showAlert: managementStream.output.handerAlert.asObservable(),
            isPlayerDarkAnimating: state.isPlayerDarkAnimating.asObservable(),
            isPlayerLightAnimating: state.isPlayerLightAnimating.asObservable(),
            playerDarkCount: state.playerDarkCount.asObservable(),
            playerLightCount: state.playerLightCount.asObservable(),
            playerDarkSelectedIndex: managementStream.output.playerDark.distinctUntilChanged().map { $0.rawValue },
            playerLightSelectedIndex: managementStream.output.playerLight.distinctUntilChanged().map { $0.rawValue },
            resetBoard: state.resetBoard.asObservable(),
            updateBoard: managementStream.output.updateDisk
        )
    }
}

extension ReversiViewModel {

    @available(*, unavailable)
    private enum MainScheduler {}
}
