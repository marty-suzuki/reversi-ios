import RxRelay
import RxSwift

protocol SetDiskProtocol {
    func callAsFunction(_ disk: Disk?,
                        at coordinate: Coordinate,
                        animated: Bool,
                        updateDisk: PublishRelay<UpdateDisk>,
                        actionCreator: GameActionCreatorProtocol) -> Single<Bool>
}

struct SetDisk: SetDiskProtocol {

    func callAsFunction(_ disk: Disk?,
                        at coordinate: Coordinate,
                        animated: Bool,
                        updateDisk: PublishRelay<UpdateDisk>,
                        actionCreator: GameActionCreatorProtocol) -> Single<Bool> {
        Single<Bool>.create { observer in
            actionCreator.setDisk(disk, at: coordinate)
            let update = UpdateDisk(disk: disk, coordinate: coordinate, animated: animated) {
                observer(.success($0))
            }
            updateDisk.accept(update)
            return Disposables.create()
        }
    }
}
