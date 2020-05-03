import RxSwift
import UIKit
import Unio

public protocol ReversiViewModelFactoryType {
    func make(messageDiskSize: CGFloat,
              mainAsyncScheduler: SchedulerType,
              mainScheduler: SchedulerType) -> ReversiViewModelType
}

public struct ReversiViewModelFactory: ReversiViewModelFactoryType {

    public init() {}

    public func make(messageDiskSize: CGFloat,
                     mainAsyncScheduler: SchedulerType,
                     mainScheduler: SchedulerType) -> ReversiViewModelType {
        let cache = GameDataCache(loadGame: GameDataIO.loadGame,
                                  saveGame: GameDataIO.save)
        let dispatcher = GameDispatcher()
        let store = GameStore(dispatcher: dispatcher)
        let actionCreator = GameActionCreator(dispatcher: dispatcher, cache: cache)

        let flippedDiskCoordinatesFactory = FlippedDiskCoordinatesFactory()
        let setDiskFactory = SetDiskFactory()
        let animateSettingDisksFactory = AnimateSettingDisksFactory()
        let placeDiskFactory = PlaceDiskFactory()
        let validMovesFactory = ValidMovesFactory()
        let setDisk = setDiskFactory.make(actionCreator: actionCreator)

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

        let validMoves = validMovesFactory.make(
            flippedDiskCoordinates: flippedDiskCoordinates,
            store: store
        )

        let managementStream = ReversiManagementStream(
            input: .init(),
            state: .init(),
            extra: .init(store: store,
                         actionCreator: actionCreator,
                         mainScheduler: mainScheduler,
                         validMoves: validMoves,
                         setDisk: setDisk,
                         placeDisk: placeDisk))

        return ReversiViewModel(
            input: .init(),
            state: .init(),
            extra: .init(messageDiskSize: messageDiskSize,
                         mainAsyncScheduler: mainAsyncScheduler,
                         mainScheduler: mainScheduler,
                         managementStream: managementStream)
        )
    }
}
