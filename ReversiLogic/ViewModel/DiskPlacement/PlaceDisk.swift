import RxRelay
import RxSwift

public protocol PlaceDiskFactoryProtocol {
    func make(flippedDiskCoordinates: FlippedDiskCoordinatesProtocol,
              setDisk: SetDiskProtocol,
              animateSettingDisks: AnimateSettingDisksProtocol,
              actionCreator: GameActionCreatorProtocol,
              store: GameStoreProtocol,
              mainAsyncScheduler: SchedulerType) -> PlaceDiskProtocol
}

public struct PlaceDiskFactory: PlaceDiskFactoryProtocol {
    public func make(flippedDiskCoordinates: FlippedDiskCoordinatesProtocol,
                     setDisk: SetDiskProtocol,
                     animateSettingDisks: AnimateSettingDisksProtocol,
                     actionCreator: GameActionCreatorProtocol,
                     store: GameStoreProtocol,
                     mainAsyncScheduler: SchedulerType) -> PlaceDiskProtocol {
        PlaceDisk(flippedDiskCoordinates: flippedDiskCoordinates,
                  setDisk: setDisk,
                  animateSettingDisks: animateSettingDisks,
                  actionCreator: actionCreator,
                  store: store,
                  mainAsyncScheduler: mainAsyncScheduler)
    }
}

public protocol PlaceDiskProtocol {
    func callAsFunction<T: Acceptable>(
        _ disk: Disk,
        at coordinate: Coordinate,
        animated isAnimated: Bool,
        updateDisk: T
    ) -> Single<Bool> where T.Element == UpdateDisk
}

struct PlaceDisk: PlaceDiskProtocol {

    let flippedDiskCoordinates: FlippedDiskCoordinatesProtocol
    let setDisk: SetDiskProtocol
    let animateSettingDisks: AnimateSettingDisksProtocol
    let actionCreator: GameActionCreatorProtocol
    let store: GameStoreProtocol
    let mainAsyncScheduler: SchedulerType

    /// - Parameter completion: A closure to be executed when the animation sequence ends.
    ///     This closure has no return value and takes a single Boolean argument that indicates
    ///     whether or not the animations actually finished before the completion handler was called.
    ///     If `animated` is `false`,  this closure is performed at the beginning of the next run loop cycle. This parameter may be `nil`.
    /// - Throws: `DiskPlacementError` if the `disk` cannot be placed at (`x`, `y`).
    func callAsFunction<T: Acceptable>(
        _ disk: Disk,
        at coordinate: Coordinate,
        animated isAnimated: Bool,
        updateDisk: T
    ) -> Single<Bool> where T.Element == UpdateDisk {

        let diskCoordinates = flippedDiskCoordinates(by: disk, at: coordinate)
        if diskCoordinates.isEmpty {
            return .error(Error.diskPlacement(disk: disk, coordinate: coordinate))
        }

        if isAnimated {
            let cleanUp: () -> Void = { [actionCreator] in
                actionCreator.setPlaceDiskCanceller(nil)
            }
            actionCreator.setPlaceDiskCanceller(Canceller(cleanUp))
            return animateSettingDisks(at: [coordinate] + diskCoordinates,
                                       to: disk,
                                       updateDisk: updateDisk)
                .flatMap { [store] finished in
                    guard  let canceller = store.placeDiskCanceller.value else {
                        return .error(Error.animationCancellerReleased)
                    }

                    if canceller.isCancelled {
                        return .error(Error.animationCancellerCancelled)
                    }

                    return .just(finished)
                }
                .do(onSuccess: { _ in
                    cleanUp()
                })
        } else {
            let coordinates = [coordinate] + diskCoordinates
            let observables = coordinates.map {
                setDisk(disk,
                        at: $0,
                        animated: false,
                        updateDisk: updateDisk).asObservable()
            }
            return Observable.just(())
                .observeOn(mainAsyncScheduler)
                .flatMap { Observable.zip(observables) }
                .map { _ in true }
                .asSingle()
        }
    }

    enum Error: Swift.Error, Equatable {
        case diskPlacement(disk: Disk, coordinate: Coordinate)
        case animationCancellerReleased
        case animationCancellerCancelled
    }

    @available(*, unavailable)
    private enum MainScheduler {}
}
