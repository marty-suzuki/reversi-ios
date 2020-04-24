import RxRelay
import RxSwift
import Unio
@testable import ReversiLogic

final class MockReversiPlaceDiskStream: ReversiPlaceDiskStreamType {
    let input: InputWrapper<ReversiPlaceDiskStream.Input>
    let _input = ReversiPlaceDiskStream.Input()

    private(set) lazy var output = OutputWrapper(_output)
    private(set) lazy var _output = ReversiPlaceDiskStream.Output(
        updateDisk: updateDisk,
        didUpdateDisk: didUpdateDisk,
        didRefreshAllDisk: didRefreshAllDisk
    )

    let updateDisk = PublishRelay<UpdateDisk>()

    @MockPublishWrapper
    private(set) var didUpdateDisk: Observable<Bool>
    @MockPublishWrapper
    private(set) var didRefreshAllDisk: Observable<Void>

    init() {
        self.input = InputWrapper(_input)
        self.output = OutputWrapper(_output)
    }
}
