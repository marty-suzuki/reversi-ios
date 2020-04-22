import RxCocoa
import RxRelay
import RxSwift
import XCTest
@testable import ReversiLogic

final class GameActionCreatorTests: XCTestCase {

    private var dependency: Dependency!

    override func setUp() {
        self.dependency = Dependency()
    }

    func test_load_正常系() {
        let cache = dependency.cache
        let actionCreator = dependency.testTarget
        let expected = GameData.initial

        actionCreator.load()
        cache._load.onNext(expected)
        cache._load.onCompleted()

        XCTAssertNotNil(dependency.loaded.value)
        XCTAssertEqual(dependency.cells.value, expected.cells)
        XCTAssertEqual(dependency.status.value, expected.status)
        XCTAssertEqual(dependency.playerDark.value, expected.playerDark)
        XCTAssertEqual(dependency.playerLight.value, expected.playerLight)
    }

    func test_load_異常系() {
        let cache = dependency.cache
        let actionCreator = dependency.testTarget

        actionCreator.load()
        cache._load.onError(MockError())

        XCTAssertNotNil(dependency.faildToLoad.value)
        XCTAssertEqual(dependency.cells.value, GameData.initial.cells)
        XCTAssertEqual(dependency.status.value, GameData.initial.status)
        XCTAssertEqual(dependency.playerDark.value, GameData.initial.playerDark)
        XCTAssertEqual(dependency.playerLight.value, GameData.initial.playerLight)
    }

    func test_rest() {
        let actionCreator = dependency.testTarget
        actionCreator.reset()

        XCTAssertNotNil(dependency.reset.value)
        XCTAssertEqual(dependency.cells.value, GameData.initial.cells)
        XCTAssertEqual(dependency.status.value, GameData.initial.status)
        XCTAssertEqual(dependency.playerDark.value, GameData.initial.playerDark)
        XCTAssertEqual(dependency.playerLight.value, GameData.initial.playerLight)
    }
}

extension GameActionCreatorTests {

    private final class Dependency {
        let testTarget: GameActionCreator
        let cache = MockGameDataCache()
        let dispatcher = GameDispatcher()

        let cells = BehaviorRelay<[[GameData.Cell]]?>(value: [])
        let status = BehaviorRelay<GameData.Status?>(value: nil)
        let playerDark = BehaviorRelay<GameData.Player?>(value: nil)
        let playerLight = BehaviorRelay<GameData.Player?>(value: nil)
        let reset = BehaviorRelay<Void?>(value: nil)
        let loaded = BehaviorRelay<Void?>(value: nil)
        let faildToLoad = BehaviorRelay<Void?>(value: nil)
        let setDiskAtCoordinate = BehaviorRelay<(Disk?, Coordinate)?>(value: nil)

        private let disposeBag = DisposeBag()

        init() {
            self.testTarget = GameActionCreator(
                dispatcher: dispatcher,
                cache: cache
            )

            dispatcher.setCells
                .bind(to: cells)
                .disposed(by: disposeBag)

            dispatcher.setStatus
                .bind(to: status)
                .disposed(by: disposeBag)

            dispatcher.setPlayerOfDark
                .bind(to: playerDark)
                .disposed(by: disposeBag)

            dispatcher.setPlayerOfLight
                .bind(to: playerLight)
                .disposed(by: disposeBag)

            dispatcher.reset
                .bind(to: reset)
                .disposed(by: disposeBag)

            dispatcher.loaded
                .bind(to: loaded)
                .disposed(by: disposeBag)

            dispatcher.faildToLoad
                .bind(to: faildToLoad)
                .disposed(by: disposeBag)

            dispatcher.setDiskAtCoordinate
                .bind(to: setDiskAtCoordinate)
                .disposed(by: disposeBag)
        }
    }

    private struct MockError: Error {}
}
