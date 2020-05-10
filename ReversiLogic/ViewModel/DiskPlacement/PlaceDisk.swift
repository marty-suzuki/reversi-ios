import RxRelay
import RxSwift

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
        let coordinatesAndIsAnimated = flippedDiskCoordinates(by: disk, at: coordinate)
            .flatMap { coordinates -> Single<([Coordinate], Bool)> in
                if coordinates.isEmpty {
                    return .error(Error.diskPlacement(disk: disk, coordinate: coordinate))
                }
                return .just((coordinates, isAnimated))
            }
            .asObservable()
            .share()

        let animated = coordinatesAndIsAnimated
            .flatMap { [actionCreator] coordinates, isAnimated -> Observable<([Coordinate], Canceller)> in
                guard isAnimated else {
                    return .empty()
                }
                let cleanUp: () -> Void = {
                    actionCreator.setPlaceDiskCanceller(nil)
                }
                return .just((coordinates, Canceller(cleanUp)))
            }
            .do(onNext: { [actionCreator] _, canceller in
                actionCreator.setPlaceDiskCanceller(canceller)
            })
            .flatMap { [store, animateSettingDisks] coordinates, canceller -> Observable<Bool> in
                weak var canceller = canceller
                return animateSettingDisks(at: [coordinate] + coordinates,
                                           to: disk,
                                           updateDisk: updateDisk)
                    .asObservable()
                    .withLatestFrom(store.placeDiskCanceller) { ($0, $1) }
                    .flatMap { finished, placeDiskCanceller -> Observable<Bool> in
                        guard let canceller = placeDiskCanceller else {
                            return .error(Error.animationCancellerReleased)
                        }

                        if canceller.isCancelled {
                            return .error(Error.animationCancellerCancelled)
                        }

                        return .just(finished)
                    }
                    .do(onNext: { _ in
                        canceller?.cancel()
                    })
            }

        let nonAnimated = coordinatesAndIsAnimated
            .flatMap { [setDisk, mainAsyncScheduler] coordinates, isAnimated -> Observable<Bool> in
                if isAnimated {
                    return .empty()
                }

                let coordinates = [coordinate] + coordinates
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
            }

        return Observable.merge(animated, nonAnimated)
            .asSingle()
    }

    enum Error: Swift.Error, Equatable {
        case diskPlacement(disk: Disk, coordinate: Coordinate)
        case animationCancellerReleased
        case animationCancellerCancelled
    }
}
