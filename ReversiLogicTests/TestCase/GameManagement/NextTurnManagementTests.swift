import RxRelay
import TestModule
import XCTest
@testable import ReversiLogic

final class NextTurnManagementTests: XCTestCase {
    private var dependency: Dependency!

    override func setUp() {
        self.dependency = Dependency()
    }

    func test_callAsFunction_statusがgameOver() {
        let management = dependency.testTarget
        let nextTurn = dependency.nextTurn
        let store = dependency.store

        store.$status.accept(.gameOver)

        let result = Watcher(management.callAsFunction(nextTurn: nextTurn.asObservable()))

        nextTurn.accept(())

        XCTAssertEqual(result.calledCount, 0)
    }

    func test_callAsFunction_statusがturnで_validMovesがどちらも空() {
        let management = dependency.testTarget
        let nextTurn = dependency.nextTurn
        let store = dependency.store
        let actionCreator = dependency.actionCreator
        let validMoves = dependency.validMoves

        let disk = Disk.dark
        store.$status.accept(.turn(disk))

        let result = Watcher(management.callAsFunction(nextTurn: nextTurn.share()))

        nextTurn.accept(())
        validMoves._callAsFunction.onNext([])
        validMoves._callAsFunction.onNext([])

        XCTAssertEqual(result.calledCount, 1)
        XCTAssertEqual(result.parameters, [.gameOver])
        XCTAssertEqual(actionCreator.$_setStatus.calledCount, 1)
        XCTAssertEqual(actionCreator.$_setStatus.parameters, [.gameOver])
    }

    func test_callAsFunction_statusがturnで_最初のvalidMovesが空じゃない() {
        let management = dependency.testTarget
        let nextTurn = dependency.nextTurn
        let store = dependency.store
        let actionCreator = dependency.actionCreator
        let validMoves = dependency.validMoves

        let disk = Disk.dark
        store.$status.accept(.turn(disk))

        let result = Watcher(management.callAsFunction(nextTurn: nextTurn.share()))

        nextTurn.accept(())
        validMoves._callAsFunction.onNext([Coordinate(x: 0, y: 0)])
        validMoves._callAsFunction.onNext([])

        XCTAssertEqual(result.calledCount, 1)
        XCTAssertEqual(result.parameters, [.validMoves(.turn(disk.flipped))])
        XCTAssertEqual(actionCreator.$_setStatus.calledCount, 1)
        XCTAssertEqual(actionCreator.$_setStatus.parameters, [.turn(disk.flipped)])
    }

    func test_callAsFunction_statusがturnで_最初のvalidMovesが空() {
        let management = dependency.testTarget
        let nextTurn = dependency.nextTurn
        let store = dependency.store
        let actionCreator = dependency.actionCreator
        let validMoves = dependency.validMoves

        let disk = Disk.dark
        store.$status.accept(.turn(disk))

        let result = Watcher(management.callAsFunction(nextTurn: nextTurn.share()))

        nextTurn.accept(())
        validMoves._callAsFunction.onNext([])
        validMoves._callAsFunction.onNext([Coordinate(x: 0, y: 0)])

        XCTAssertEqual(result.calledCount, 1)
        XCTAssertEqual(result.parameters, [.noValidMoves(.turn(disk.flipped))])
        XCTAssertEqual(actionCreator.$_setStatus.calledCount, 1)
        XCTAssertEqual(actionCreator.$_setStatus.parameters, [.turn(disk.flipped)])
    }
}

extension NextTurnManagementTests {
    private final class Dependency {
        let testTarget: NextTurn.Management

        let store = MockGameStore()
        let actionCreator = MockGameActionCreator()
        let validMoves = MockValidMoves()

        let nextTurn = PublishRelay<Void>()

        init() {
            self.testTarget = NextTurn.Management(store: store,
                                                  actionCreator: actionCreator,
                                                  validMoves: validMoves)
        }
    }
}
