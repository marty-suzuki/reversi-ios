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

        let managementStream = ReversiManagementStream(
            store: store,
            actionCreator: actionCreator,
            mainScheduler: mainScheduler,
            mainAsyncScheduler: mainAsyncScheduler,
            flippedDiskCoordinatesFactory: flippedDiskCoordinatesFactory,
            setDiskFactory: setDiskFactory,
            animateSettingDisksFactory: animateSettingDisksFactory,
            placeDiskFactory: placeDiskFactory,
            validMovesFactory: validMovesFactory
        )

        return ReversiViewModel(messageDiskSize: messageDiskSize,
                                mainAsyncScheduler: mainAsyncScheduler,
                                mainScheduler: mainScheduler,
                                managementStream: managementStream)
    }
}
