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

        let flippedDiskCoordinates = FlippedDiskCoordinates()
        let setDisk = SetDisk()
        let animateSettingDisks = AnimateSettingDisks()
        let placeDiskStream = ReversiPlaceDiskStream(
            actionCreator: actionCreator,
            store: store,
            mainAsyncScheduler: mainAsyncScheduler,
            flippedDiskCoordinates: flippedDiskCoordinates,
            setDisk: setDisk,
            animateSettingDisks: animateSettingDisks
        )
        let managementStream = ReversiManagementStream(
            store: store,
            actionCreator: actionCreator,
            mainScheduler: mainScheduler,
            flippedDiskCoordinates: flippedDiskCoordinates)

        return ReversiViewModel(messageDiskSize: messageDiskSize,
                                mainAsyncScheduler: mainAsyncScheduler,
                                mainScheduler: mainScheduler,
                                placeDiskStream: placeDiskStream,
                                managementStream: managementStream)
    }
}
