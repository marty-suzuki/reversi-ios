import RxRelay
import RxSwift
@testable import ReversiLogic

struct MockPlaceDisk: PlaceDiskProtocol {

    @MockPublishResponse<Parameters, Bool>
    var _callAsFunction: AnyObserver<Bool>

    func callAsFunction<T: Acceptable>(
        _ disk: Disk,
        at coordinate: Coordinate,
        animated isAnimated: Bool,
        updateDisk: T
    ) -> Single<Bool> where T.Element == UpdateDisk {
        let parameters = Parameters(disk: disk, coordinate: coordinate, animated: isAnimated)
        return __callAsFunction.respond(parameters).take(1).asSingle()
    }
}

extension MockPlaceDisk {

    struct Parameters: Equatable {
        let disk: Disk
        let coordinate: Coordinate
        let animated: Bool
    }
}
