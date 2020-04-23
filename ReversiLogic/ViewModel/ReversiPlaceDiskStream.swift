import RxCocoa
import RxSwift
import Unio

protocol ReversiPlaceDiskStreamType: AnyObject {
    var input: InputWrapper<ReversiPlaceDiskStream.Input> { get }
    var output: OutputWrapper<ReversiPlaceDiskStream.Output> { get }
}

final class ReversiPlaceDiskStream: UnioStream<ReversiPlaceDiskStream>, ReversiPlaceDiskStreamType {

    convenience init(actionCreator: GameActionCreatorProtocol,
                     store: GameStoreProtocol,
                     mainAsyncScheduler: SchedulerType,
                     flippedDiskCoordinates: FlippedDiskCoordinatesProtocol) {
        self.init(input: Input(),
                  state: State(),
                  extra: Extra(actionCreator: actionCreator,
                               store: store,
                               mainAsyncScheduler: mainAsyncScheduler,
                               flippedDiskCoordinates: flippedDiskCoordinates))
    }
}

extension ReversiPlaceDiskStream {

    struct Input: InputType {
        let handleDiskWithCoordinate = PublishRelay<(Disk, Coordinate)>()
        let refreshAllDisk = PublishRelay<Void>()
    }

    struct Output: OutputType {
        let updateDisk: PublishRelay<UpdateDisk>
        let didUpdateDisk: Observable<Bool>
        let didRefreshAllDisk: Observable<Void>
    }

    struct State: StateType {
        let updateDisk = PublishRelay<UpdateDisk>()
    }

    struct Extra: ExtraType {
        let actionCreator: GameActionCreatorProtocol
        let store: GameStoreProtocol
        let mainAsyncScheduler: SchedulerType
        let flippedDiskCoordinates: FlippedDiskCoordinatesProtocol
    }

    static func bind(from dependency: Dependency<Input, State, Extra>, disposeBag: DisposeBag) -> Output {
        let state = dependency.state
        let extra = dependency.extra

        let didRefreshAllDisk = dependency.inputObservables.refreshAllDisk
            .withLatestFrom(extra.store.cells)
            .flatMap { cells -> Observable<Void> in
                let updates = cells.flatMap { rows in
                    rows.map { cell in
                        setDisk(cell.disk,
                                at: cell.coordinate,
                                animated: false,
                                extra: extra,
                                state: state).asObservable()
                    }
                }
                return Observable.zip(updates).map { _ in }
            }

        let didUpdateDisk = dependency.inputObservables.handleDiskWithCoordinate
            .flatMap { disk, coordinate -> Observable<Bool> in
                placeDisk(disk, at: coordinate, animated: true, extra: extra, state: state)
                    .asObservable()
                    .catchError { _ in .empty() }
            }

        return Output(updateDisk: state.updateDisk,
                      didUpdateDisk: didUpdateDisk,
                      didRefreshAllDisk: didRefreshAllDisk)
    }
}

extension ReversiPlaceDiskStream {

    static func setDisk(_ disk: Disk?,
                        at coordinate: Coordinate,
                        animated: Bool,
                        extra: Extra,
                        state: State) -> Single<Bool> {
        Single<Bool>.create { observer in
            extra.actionCreator.setDisk(disk, at: coordinate)
            let update = UpdateDisk(disk: disk, coordinate: coordinate, animated: animated) {
                observer(.success($0))
            }
            state.updateDisk.accept(update)
            return Disposables.create()
        }
    }

    static func animateSettingDisks(at coordinates: [Coordinate],
                                    to disk: Disk,
                                    extra: Extra,
                                    state: State) -> Single<Bool> {
        guard let coordinate = coordinates.first else {
            return .just(true)
        }

        guard let placeDiskCanceller = extra.store.placeDiskCanceller.value else {
            return .error(Error.animationCancellerReleased)
        }

        return setDisk(disk, at: coordinate, animated: true, extra: extra, state: state)
            .flatMap { finished in
                if placeDiskCanceller.isCancelled {
                    return .error(Error.animationCancellerCancelled)
                }
                if finished {
                    return animateSettingDisks(at: Array(coordinates.dropFirst()), to: disk, extra: extra, state: state)
                } else {
                    let observables = coordinates.map { setDisk(disk, at: $0, animated: false, extra: extra, state: state).asObservable() }
                    return Observable.zip(observables)
                        .map { _ in false }
                        .asSingle()
                }
            }
    }

    /// - Parameter completion: A closure to be executed when the animation sequence ends.
    ///     This closure has no return value and takes a single Boolean argument that indicates
    ///     whether or not the animations actually finished before the completion handler was called.
    ///     If `animated` is `false`,  this closure is performed at the beginning of the next run loop cycle. This parameter may be `nil`.
    /// - Throws: `DiskPlacementError` if the `disk` cannot be placed at (`x`, `y`).
    static func placeDisk(_ disk: Disk,
                          at coordinate: Coordinate,
                          animated isAnimated: Bool,
                          extra: Extra,
                          state: State) -> Single<Bool> {
        let diskCoordinates = extra.flippedDiskCoordinates.execute(disk: disk, at: coordinate, cells: extra.store.cells.value)
        if diskCoordinates.isEmpty {
            return .error(Error.diskPlacement(disk: disk, coordinate: coordinate))
        }

        if isAnimated {
            let cleanUp: () -> Void = {
                extra.actionCreator.setPlaceDiskCanceller(nil)
            }
            extra.actionCreator.setPlaceDiskCanceller(Canceller(cleanUp))
            return animateSettingDisks(at: [coordinate] + diskCoordinates, to: disk, extra: extra, state: state)
                .flatMap { finished in
                    guard  let canceller = extra.store.placeDiskCanceller.value else {
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
                setDisk(disk, at: $0, animated: false, extra: extra, state: state).asObservable()
            }
            return Observable.just(())
                .observeOn(extra.mainAsyncScheduler)
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
