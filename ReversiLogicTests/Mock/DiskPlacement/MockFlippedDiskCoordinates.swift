import RxRelay
import RxSwift
@testable import ReversiLogic

final class MockFlippedDiskCoordinates: FlippedDiskCoordinatesProtocol {

    @MockPublishResponse<Parameters, [Coordinate]>
    var _callAsFunction: AnyObserver<[Coordinate]>

    func callAsFunction(by disk: Disk, at coordinate: Coordinate) -> Single<[Coordinate]> {
        __callAsFunction.respond(.init(disk: disk, coordinate: coordinate))
            .take(1).asSingle()
    }

    struct Parameters: Equatable {
        let disk: Disk
        let coordinate: Coordinate
    }
}
