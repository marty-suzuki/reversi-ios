import RxCocoa
import RxSwift
import Unio

public protocol ReversiPlaceDiskStreamType: AnyObject {
    var input: InputWrapper<ReversiPlaceDiskStream.Input> { get }
    var output: OutputWrapper<ReversiPlaceDiskStream.Output> { get }
}

public final class ReversiPlaceDiskStream: UnioStream<ReversiPlaceDiskStream>, ReversiPlaceDiskStreamType {

    convenience init(actionCreator: GameActionCreatorProtocol,
                     store: GameStoreProtocol,
                     mainAsyncScheduler: SchedulerType,
                     flippedDiskCoordinates: FlippedDiskCoordinatesProtocol,
                     setDiskFactory: SetDiskFactoryProtocol,
                     animateSettingDisks: AnimateSettingDisksProtocol,
                     placeDiskFactory: PlaceDiskFactoryProtocol) {
        let state = State()
        let setDisk = setDiskFactory.make(
            updateDisk: state.updateDisk,
            actionCreator: actionCreator
        )

        let placeDisk = placeDiskFactory.make(
            flippedDiskCoordinates: flippedDiskCoordinates,
            setDisk: setDisk,
            animateSettingDisks: animateSettingDisks,
            updateDisk: state.updateDisk,
            actionCreator: actionCreator,
            store: store,
            mainAsyncScheduler: mainAsyncScheduler
        )
        self.init(input: Input(),
                  state: state,
                  extra: Extra(actionCreator: actionCreator,
                               store: store,
                               mainAsyncScheduler: mainAsyncScheduler,
                               flippedDiskCoordinates: flippedDiskCoordinates,
                               setDisk: setDisk,
                               placeDisk: placeDisk))
    }
}

extension ReversiPlaceDiskStream {

    public struct Input: InputType {
        let handleDiskWithCoordinate = PublishRelay<(Disk, Coordinate)>()
        let refreshAllDisk = PublishRelay<Void>()
    }

    public struct Output: OutputType {
        let updateDisk: PublishRelay<UpdateDisk>
        let didUpdateDisk: Observable<Bool>
        let didRefreshAllDisk: Observable<Void>
    }

    public struct State: StateType {
        let updateDisk = PublishRelay<UpdateDisk>()
    }

    public struct Extra: ExtraType {
        let actionCreator: GameActionCreatorProtocol
        let store: GameStoreProtocol
        let mainAsyncScheduler: SchedulerType
        let flippedDiskCoordinates: FlippedDiskCoordinatesProtocol
        let setDisk: SetDiskProtocol
        let placeDisk: PlaceDiskProtocol
    }

    public static func bind(from dependency: Dependency<Input, State, Extra>, disposeBag: DisposeBag) -> Output {
        let state = dependency.state
        let extra = dependency.extra
        let setDisk = extra.setDisk
        let placeDisk = extra.placeDisk

        let didRefreshAllDisk = dependency.inputObservables.refreshAllDisk
            .withLatestFrom(extra.store.cells)
            .flatMap { cells -> Observable<Void> in
                let updates = cells.flatMap { rows in
                    rows.map { cell in
                        setDisk(cell.disk,
                                at: cell.coordinate,
                                animated: false).asObservable()
                    }
                }
                return Observable.zip(updates).map { _ in }
            }
            .share()

        let didUpdateDisk = dependency.inputObservables.handleDiskWithCoordinate
            .flatMap { disk, coordinate -> Observable<Bool> in
                placeDisk(disk, at: coordinate, animated: true)
                    .asObservable()
                    .catchError { _ in .empty() }
            }
            .share()

        return Output(updateDisk: state.updateDisk,
                      didUpdateDisk: didUpdateDisk,
                      didRefreshAllDisk: didRefreshAllDisk)
    }
}
