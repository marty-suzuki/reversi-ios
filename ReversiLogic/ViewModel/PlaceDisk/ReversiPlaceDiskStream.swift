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
                     flippedDiskCoordinatesFactory: FlippedDiskCoordinatesFactoryProtocol,
                     setDiskFactory: SetDiskFactoryProtocol,
                     animateSettingDisksFactory: AnimateSettingDisksFactoryProtocol,
                     placeDiskFactory: PlaceDiskFactoryProtocol) {
        let state = State()
        let setDisk = setDiskFactory.make(
            updateDisk: state.updateDisk,
            actionCreator: actionCreator
        )

        let animateSettingDisks = animateSettingDisksFactory.make(
            setDisk: setDisk,
            store: store
        )

        let flippedDiskCoordinates = flippedDiskCoordinatesFactory.make(store: store)

        let placeDisk = placeDiskFactory.make(
            flippedDiskCoordinates: flippedDiskCoordinates,
            setDisk: setDisk,
            animateSettingDisks: animateSettingDisks,
            actionCreator: actionCreator,
            store: store,
            mainAsyncScheduler: mainAsyncScheduler
        )
        self.init(input: Input(),
                  state: state,
                  extra: Extra(store: store,
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
        let store: GameStoreProtocol
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
