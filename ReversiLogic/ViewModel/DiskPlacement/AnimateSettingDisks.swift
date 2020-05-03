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
    func callAsFunction<T: Acceptable>(
        at coordinates: [Coordinate],
        to disk: Disk,
        updateDisk: T
    ) -> Single<Bool> where T.Element == UpdateDisk
}

struct AnimateSettingDisks: AnimateSettingDisksProtocol {

    let setDisk: SetDiskProtocol
    let store: GameStoreProtocol

    func callAsFunction<T: Acceptable>(
        at coordinates: [Coordinate],
        to disk: Disk,
        updateDisk: T
    ) -> Single<Bool> where T.Element == UpdateDisk {
        guard let coordinate = coordinates.first else {
            return .just(true)
        }

        guard let placeDiskCanceller = store.placeDiskCanceller.value else {
            return .error(Error.animationCancellerReleased)
        }

        return setDisk(disk,
                       at: coordinate,
                       animated: true,
                       updateDisk: updateDisk)
            .flatMap { [animateSettingDisks = self, setDisk] finished in
                if placeDiskCanceller.isCancelled {
                    return .error(Error.animationCancellerCancelled)
                }
                if finished {
                    return animateSettingDisks(at: Array(coordinates.dropFirst()),
                                               to: disk,
                                               updateDisk: updateDisk)
                } else {
                    let observables = coordinates.map {
                        setDisk(disk,
                                at: $0,
                                animated: false,
                                updateDisk: updateDisk)
                            .asObservable()
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
