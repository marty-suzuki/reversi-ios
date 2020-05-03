import RxRelay
import RxSwift
import Unio
@testable import ReversiLogic

final class MockReversiManagementStream: ReversiManagementStreamType {
    let input: InputWrapper<ReversiManagementStream.Input>
    let _input = ReversiManagementStream.Input()

    lazy var output = OutputWrapper(_output)
    lazy var _output = ReversiManagementStream.Output(
        status: status,
        sideWithMoreDisks: sideWithMoreDisks,
        countOfDark: countOfDark,
        countOfLight: countOfLight,
        playerDark: playerDark,
        playerLight: playerLight,
        newGameBegan: newGameBegan,
        willTurnDiskOfComputer: willTurnDiskOfComputer,
        didTurnDiskOfComputer: didTurnDiskOfComputer,
        handleAlert: handerAlert,
        updateDisk: updateDisk,
        didUpdateDisk: didUpdateDisk,
        didRefreshAllDisk: didRefreshAllDisk
    )

    @MockPublishWrapper
    var  newGameBegan: Observable<Void>
    @MockPublishWrapper
    var  handleDiskWithCoordinate: Observable<(Disk, Coordinate)>
    @MockPublishWrapper
    var  willTurnDiskOfComputer: Observable<Disk>
    @MockPublishWrapper
    var  didTurnDiskOfComputer: Observable<Disk>
    @MockPublishWrapper
    var  handerAlert: Observable<Alert>

    @MockBehaviorWrapeer(value: .turn(.dark))
    var status: ValueObservable<GameData.Status>
    @MockBehaviorWrapeer(value: nil)
    var sideWithMoreDisks: ValueObservable<Disk?>
    @MockBehaviorWrapeer(value: 0)
    var countOfDark: ValueObservable<Int>
    @MockBehaviorWrapeer(value: 0)
    var countOfLight: ValueObservable<Int>
    @MockBehaviorWrapeer(value: .manual)
    var playerDark: ValueObservable<GameData.Player>
    @MockBehaviorWrapeer(value: .manual)
    var playerLight: ValueObservable<GameData.Player>

    @MockPublishWrapper
    var updateDisk: Observable<UpdateDisk>
    @MockPublishWrapper
    var didUpdateDisk: Observable<Bool>
    @MockPublishWrapper
    var didRefreshAllDisk: Observable<Void>

    init() {
        self.input = InputWrapper(_input)
    }
}
