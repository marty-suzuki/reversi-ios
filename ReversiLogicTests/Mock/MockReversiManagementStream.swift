import RxRelay
import RxSwift
import Unio
@testable import ReversiLogic

final class MockReversiManagementStream: ReversiManagementStreamType {
    let input: InputWrapper<ReversiManagementStream.Input>
    let _input = ReversiManagementStream.Input()

    private(set) lazy var output = OutputWrapper(_output)
    private(set) lazy var _output = ReversiManagementStream.Output(
        gameLoaded: gameLoaded,
        newGameBegan: newGameBegan,
        handleDiskWithCoordinate: handleDiskWithCoordinate,
        willTurnDiskOfComputer: willTurnDiskOfComputer,
        didTurnDiskOfComputer: didTurnDiskOfComputer,
        handerAlert: handerAlert,
        status: status,
        sideWithMoreDisks: sideWithMoreDisks,
        countOfDark: countOfDark,
        countOfLight: countOfLight,
        playerDark: playerDark,
        playerLight: playerLight
    )

    @MockPublishWrapper
    private(set) var  gameLoaded: Observable<Void>
    @MockPublishWrapper
    private(set) var  newGameBegan: Observable<Void>
    @MockPublishWrapper
    private(set) var  handleDiskWithCoordinate: Observable<(Disk, Coordinate)>
    @MockPublishWrapper
    private(set) var  willTurnDiskOfComputer: Observable<Disk>
    @MockPublishWrapper
    private(set) var  didTurnDiskOfComputer: Observable<Disk>
    @MockPublishWrapper
    private(set) var  handerAlert: Observable<Alert>

    @MockBehaviorWrapeer(value: .turn(.dark))
    private(set) var status: ValueObservable<GameData.Status>
    @MockBehaviorWrapeer(value: nil)
    private(set) var sideWithMoreDisks: ValueObservable<Disk?>
    @MockBehaviorWrapeer(value: 0)
    private(set) var countOfDark: ValueObservable<Int>
    @MockBehaviorWrapeer(value: 0)
    private(set) var countOfLight: ValueObservable<Int>
    @MockBehaviorWrapeer(value: .manual)
    private(set) var playerDark: ValueObservable<GameData.Player>
    @MockBehaviorWrapeer(value: .manual)
    private(set) var playerLight: ValueObservable<GameData.Player>

    init() {
        self.input = InputWrapper(_input)
    }
}
