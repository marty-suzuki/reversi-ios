import RxRelay
import RxSwift
import Unio
@testable import ReversiLogic

final class MockReversiPlaceDiskStream: ReversiPlaceDiskStreamType {
    let input: InputWrapper<ReversiPlaceDiskStream.Input>
    let _input = ReversiPlaceDiskStream.Input()

    lazy var output = OutputWrapper(_output)
    lazy var _output = ReversiPlaceDiskStream.Output(
        updateDisk: updateDisk,
        didUpdateDisk: didUpdateDisk,
        didRefreshAllDisk: didRefreshAllDisk
    )

    let updateDisk = PublishRelay<UpdateDisk>()

    @MockPublishWrapper
    var didUpdateDisk: Observable<Bool>
    @MockPublishWrapper
    var didRefreshAllDisk: Observable<Void>

    init() {
        self.input = InputWrapper(_input)
        self.output = OutputWrapper(_output)
    }
}
