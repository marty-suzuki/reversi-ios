import RxRelay
import RxSwift

public protocol SetDiskFactoryProtocol {
    func make(actionCreator: GameActionCreatorProtocol) -> SetDiskProtocol
}

public struct SetDiskFactory: SetDiskFactoryProtocol {
    public func make(actionCreator: GameActionCreatorProtocol) -> SetDiskProtocol {
        SetDisk(actionCreator: actionCreator)
    }
}

public protocol SetDiskProtocol {
    func callAsFunction<T: Acceptable>(
        _ disk: Disk?,
        at coordinate: Coordinate,
        animated: Bool,
        updateDisk: T
    ) -> Single<Bool> where T.Element == UpdateDisk
}

struct SetDisk: SetDiskProtocol {

    let actionCreator: GameActionCreatorProtocol

    func callAsFunction<T: Acceptable>(
        _ disk: Disk?,
        at coordinate: Coordinate,
        animated: Bool,
        updateDisk: T
    ) -> Single<Bool> where T.Element == UpdateDisk {
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
