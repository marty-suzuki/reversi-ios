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

        let setDisk = SetDisk(actionCreator: actionCreator)

        let animateSettingDisks = AnimateSettingDisks(
            setDisk: setDisk,
            store: store
        )

        let flippedDiskCoordinates = FlippedDiskCoordinates(store: store)

        let placeDisk = PlaceDisk(
            flippedDiskCoordinates: flippedDiskCoordinates,
            setDisk: setDisk,
            animateSettingDisks: animateSettingDisks,
            actionCreator: actionCreator,
            store: store,
            mainAsyncScheduler: mainAsyncScheduler
        )

        let validMoves = ValidMoves(
            flippedDiskCoordinates: flippedDiskCoordinates,
            store: store
        )

        let nextTurnManagement = NextTurn.Management(
            store: store,
            actionCreator: actionCreator,
            validMoves: validMoves
        )

        let managementStream = ReversiManagementStream(
            input: .init(),
            state: .init(),
            extra: .init(store: store,
                         actionCreator: actionCreator,
                         mainScheduler: mainScheduler,
                         validMoves: validMoves,
                         setDisk: setDisk,
                         placeDisk: placeDisk,
                         nextTurnManagement: nextTurnManagement)
        )

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
