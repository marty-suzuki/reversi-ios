import RxRelay
import RxSwift
@testable import ReversiLogic

struct MockAnimateSettingDisks: AnimateSettingDisksProtocol {

    @MockPublishResponse<Parameters, Bool>
    var _callAsFunction: AnyObserver<Bool>

    func callAsFunction<T: Acceptable>(
        at coordinates: [Coordinate],
        to disk: Disk,
        updateDisk: T
    ) -> Single<Bool> where T.Element == UpdateDisk {
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
