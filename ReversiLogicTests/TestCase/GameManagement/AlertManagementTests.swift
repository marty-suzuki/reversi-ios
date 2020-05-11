import RxRelay
import XCTest
@testable import ReversiLogic

final class AlertManagementTests: XCTestCase {
    private var dependency: Dependency!

    override func setUp() {
        self.dependency = Dependency()
    }

    func test_callAsFunction_nextTurnResponseが発火() throws {
        let target = dependency.testTarget
        let nextTurnResponse = dependency.nextTurnResponse
        let response = target(
            nextTurnResponse: nextTurnResponse.asObservable(),
            prepareForReset: dependency.prepareForReset.asObservable(),
            nextTurn: dependency.nextTurn,
            reset: dependency.reset,
            waitForPlayer: dependency.waitForPlayer
        ).asObservable()
        let watcher = Watcher(response)

        nextTurnResponse.accept(.gameOver)
        XCTAssertEqual(watcher.calledCount, 0)
        XCTAssertTrue(watcher.parameters.isEmpty)

        nextTurnResponse.accept(.validMoves(.gameOver))
        XCTAssertEqual(watcher.calledCount, 0)
        XCTAssertTrue(watcher.parameters.isEmpty)

        nextTurnResponse.accept(.noValidMoves(.gameOver))
        XCTAssertEqual(watcher.calledCount, 1)

        let nextTurn = Watcher(dependency.nextTurn)
        let alert = try XCTUnwrap(watcher.parameters.last)
        alert.actions.forEach { $0.handler() }
        XCTAssertEqual(nextTurn.calledCount, 1)
        XCTAssertFalse(nextTurn.parameters.isEmpty)
    }

    func test_callAsFunction_prepareForResetが発火() throws {
        let target = dependency.testTarget
        let prepareForReset = dependency.prepareForReset
        let store = dependency.store
        let actionCreator = dependency.actionCreator
        let response = target(
            nextTurnResponse: dependency.nextTurnResponse.asObservable(),
            prepareForReset: prepareForReset.asObservable(),
            nextTurn: dependency.nextTurn,
            reset: dependency.reset,
            waitForPlayer: dependency.waitForPlayer
        ).asObservable()
        let canceller = Canceller({})
        store.$placeDiskCanceller.accept(canceller)
        let darkCanceller = Canceller({})
        let lightCanceller = Canceller({})
        store.$playerCancellers.accept([
            .dark: darkCanceller,
            .light: lightCanceller
        ])
        let reset = Watcher(dependency.reset)
        let waitForPlayer = Watcher(dependency.waitForPlayer)
        let watcher = Watcher(response)

        prepareForReset.accept(())
        let alert = try XCTUnwrap(watcher.parameters.last)
        alert.actions.forEach { $0.handler() }

        XCTAssertEqual(store.$placeDiskCanceller.calledCount, 1)
        XCTAssertTrue(canceller.isCancelled)

        XCTAssertEqual(actionCreator.$_setPlaceDiskCanceller.calledCount, 1)
        let setPlaceDiskCanceller = try XCTUnwrap(actionCreator.$_setPlaceDiskCanceller.parameters.last)
        XCTAssertNil(setPlaceDiskCanceller)

        XCTAssertTrue(darkCanceller.isCancelled)
        XCTAssertTrue(lightCanceller.isCancelled)
        XCTAssertEqual(actionCreator.$_setPlayerCanceller.calledCount, 2)
        let setDarkCanceller = try XCTUnwrap(actionCreator.$_setPlayerCanceller.parameters.first)
        XCTAssertNil(setDarkCanceller.0)
        XCTAssertEqual(setDarkCanceller.1, .dark)
        let setLightCanceller = try XCTUnwrap(actionCreator.$_setPlayerCanceller.parameters.last)
        XCTAssertNil(setLightCanceller.0)
        XCTAssertEqual(setLightCanceller.1, .light)

        XCTAssertEqual(reset.calledCount, 1)
        XCTAssertEqual(waitForPlayer.calledCount, 1)
    }
}

extension AlertManagementTests {
    private final class Dependency {
        let testTarget: AlertManagement

        let store = MockGameStore()
        let actionCreator = MockGameActionCreator()

        let nextTurnResponse = PublishRelay<NextTurn.Response>()
        let prepareForReset = PublishRelay<Void>()
        let nextTurn = PublishRelay<Void>()
        let reset = PublishRelay<Void>()
        let waitForPlayer = PublishRelay<Void>()

        init() {
            self.testTarget = AlertManagement(store: store, actionCreator: actionCreator)
        }
    }
}
