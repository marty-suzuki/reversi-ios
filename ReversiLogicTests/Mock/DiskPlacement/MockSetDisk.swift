import RxRelay
import RxSwift
@testable import ReversiLogic

struct MockSetDiskFactory: SetDiskFactoryProtocol {

    let setDisk: MockSetDisk

    func make(updateDisk: PublishRelay<UpdateDisk>,
              actionCreator: GameActionCreatorProtocol) -> SetDiskProtocol {
        setDisk
    }
}

struct MockSetDisk: SetDiskProtocol {

    @MockPublishResponse<Parameters, Bool>
    var _callAsFunction: AnyObserver<Bool>

    func callAsFunction(_ disk: Disk?,
                        at coordinate: Coordinate,
                        animated: Bool) -> Single<Bool> {
        let parameters = Parameters(disk: disk, coordinate: coordinate, animated: animated)
        return __callAsFunction.respond(parameters).take(1).asSingle()
    }
}

extension MockSetDisk {

    struct Parameters: Equatable {
        let disk: Disk?
        let coordinate: Coordinate
        let animated: Bool
    }
}