import RxRelay
import RxSwift

public protocol SetDiskFactoryProtocol {
    func make(updateDisk: PublishRelay<UpdateDisk>,
              actionCreator: GameActionCreatorProtocol) -> SetDiskProtocol
}

public struct SetDiskFactory: SetDiskFactoryProtocol {
    public func make(updateDisk: PublishRelay<UpdateDisk>,
              actionCreator: GameActionCreatorProtocol) -> SetDiskProtocol {
        SetDisk(updateDisk: updateDisk, actionCreator: actionCreator)
    }
}

public protocol SetDiskProtocol {
    func callAsFunction(_ disk: Disk?,
                        at coordinate: Coordinate,
                        animated: Bool) -> Single<Bool>
}

struct SetDisk: SetDiskProtocol {

    let updateDisk: PublishRelay<UpdateDisk>
    let actionCreator: GameActionCreatorProtocol

    func callAsFunction(_ disk: Disk?,
                        at coordinate: Coordinate,
                        animated: Bool) -> Single<Bool> {
        Single<Bool>.create { [actionCreator, updateDisk] observer in
            actionCreator.setDisk(disk, at: coordinate)
            let update = UpdateDisk(disk: disk, coordinate: coordinate, animated: animated) {
                observer(.success($0))
            }
            updateDisk.accept(update)
            return Disposables.create()
        }
    }
}
