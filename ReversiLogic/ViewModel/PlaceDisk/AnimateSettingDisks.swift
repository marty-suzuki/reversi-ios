import RxRelay
import RxSwift

public protocol AnimateSettingDisksFactoryProtocol {
    func make(setDisk: SetDiskProtocol,
              store: GameStoreProtocol) -> AnimateSettingDisksProtocol
}

public struct AnimateSettingDisksFactory: AnimateSettingDisksFactoryProtocol {
    public func make(setDisk: SetDiskProtocol,
                     store: GameStoreProtocol) -> AnimateSettingDisksProtocol {
        AnimateSettingDisks(setDisk: setDisk,
                            store: store)
    }
}

public protocol AnimateSettingDisksProtocol {
    func callAsFunction(at coordinates: [Coordinate],
                        to disk: Disk) -> Single<Bool>
}

struct AnimateSettingDisks: AnimateSettingDisksProtocol {

    let setDisk: SetDiskProtocol
    let store: GameStoreProtocol

    func callAsFunction(at coordinates: [Coordinate],
                        to disk: Disk) -> Single<Bool> {
        guard let coordinate = coordinates.first else {
            return .just(true)
        }

        guard let placeDiskCanceller = store.placeDiskCanceller.value else {
            return .error(Error.animationCancellerReleased)
        }

        return setDisk(disk,
                       at: coordinate,
                       animated: true)
            .flatMap { [animateSettingDisks = self, setDisk] finished in
                if placeDiskCanceller.isCancelled {
                    return .error(Error.animationCancellerCancelled)
                }
                if finished {
                    return animateSettingDisks(at: Array(coordinates.dropFirst()), to: disk)
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
