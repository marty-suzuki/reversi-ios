import RxRelay
import RxSwift
@testable import ReversiLogic

struct MockAnimateSettingDisks: AnimateSettingDisksProtocol {



    @MockPublishResponse<Parameters, Bool>
    var _callAsFunction: AnyObserver<Bool>

    func callAsFunction(at coordinates: [Coordinate],
                        to disk: Disk,
                        setDisk: SetDiskProtocol,
                        updateDisk: PublishRelay<UpdateDisk>,
                        actionCreator: GameActionCreatorProtocol,
                        store: GameStoreProtocol) -> Single<Bool> {
        let parameters = Parameters(disk: disk, coordinates: coordinates)
        return __callAsFunction.respond(parameters).take(1).asSingle()
    }
}

extension MockAnimateSettingDisks {

    struct Parameters: Equatable {
        let disk: Disk
        let coordinates: [Coordinate]
    }
}
