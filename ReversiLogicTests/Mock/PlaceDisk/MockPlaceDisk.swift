import RxRelay
import RxSwift
@testable import ReversiLogic

struct MockPlaceDiskFactory: PlaceDiskFactoryProtocol {

    let placeDisk: MockPlaceDisk

    func make(flippedDiskCoordinates: FlippedDiskCoordinatesProtocol,
              setDisk: SetDiskProtocol,
              animateSettingDisks: AnimateSettingDisksProtocol,
              updateDisk: PublishRelay<UpdateDisk>,
              actionCreator: GameActionCreatorProtocol,
              store: GameStoreProtocol,
              mainAsyncScheduler: SchedulerType) -> PlaceDiskProtocol {
        return placeDisk
    }
}

struct MockPlaceDisk: PlaceDiskProtocol {

    @MockPublishResponse<Parameters, Bool>
    var _callAsFunction: AnyObserver<Bool>

    func callAsFunction(_ disk: Disk,
                        at coordinate: Coordinate,
                        animated isAnimated: Bool) -> Single<Bool> {
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
