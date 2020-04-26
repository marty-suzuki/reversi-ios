import RxRelay
import RxSwift

protocol AnimateSettingDisksProtocol {
    func callAsFunction(at coordinates: [Coordinate],
                        to disk: Disk,
                        setDisk: SetDiskProtocol,
                        updateDisk: PublishRelay<UpdateDisk>,
                        actionCreator: GameActionCreatorProtocol,
                        store: GameStoreProtocol) -> Single<Bool>
}

struct AnimateSettingDisks: AnimateSettingDisksProtocol {

    func callAsFunction(at coordinates: [Coordinate],
                        to disk: Disk,
                        setDisk: SetDiskProtocol,
                        updateDisk: PublishRelay<UpdateDisk>,
                        actionCreator: GameActionCreatorProtocol,
                        store: GameStoreProtocol) -> Single<Bool> {
        guard let coordinate = coordinates.first else {
            return .just(true)
        }

        guard let placeDiskCanceller = store.placeDiskCanceller.value else {
            return .error(Error.animationCancellerReleased)
        }

        return setDisk(disk,
                       at: coordinate,
                       animated: true)
            .flatMap { [animateSettingDisks = self] finished in
                if placeDiskCanceller.isCancelled {
                    return .error(Error.animationCancellerCancelled)
                }
                if finished {
                    return animateSettingDisks(at: Array(coordinates.dropFirst()),
                                               to: disk,
                                               setDisk: setDisk,
                                               updateDisk: updateDisk,
                                               actionCreator: actionCreator,
                                               store: store)
                } else {
                    let observables = coordinates.map {
                        setDisk(disk,
                                at: $0,
                                animated: false).asObservable()
                    }
                    return Observable.zip(observables)
                        .map { _ in false }
                        .asSingle()
                }
            }
    }

    enum Error: Swift.Error, Equatable {
        case animationCancellerReleased
        case animationCancellerCancelled
    }
}
