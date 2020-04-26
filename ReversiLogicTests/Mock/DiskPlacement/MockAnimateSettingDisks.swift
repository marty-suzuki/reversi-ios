import RxRelay
import RxSwift
@testable import ReversiLogic

struct MockAnimateSettingDisksFactory: AnimateSettingDisksFactoryProtocol {

    let animateSettingDisks: MockAnimateSettingDisks

    func make(setDisk: SetDiskProtocol,
              store: GameStoreProtocol) -> AnimateSettingDisksProtocol {
        animateSettingDisks
    }
}

struct MockAnimateSettingDisks: AnimateSettingDisksProtocol {

    @MockPublishResponse<Parameters, Bool>
    var _callAsFunction: AnyObserver<Bool>

    func callAsFunction(at coordinates: [Coordinate], to disk: Disk) -> Single<Bool> {
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
