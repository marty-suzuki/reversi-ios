import RxCocoa
import RxSwift
import RxTest
import XCTest
@testable import ReversiLogic

final class GameLogicTests: XCTestCase {

    private var dependency: Dependency!

    override func setUp() {
        self.dependency = Dependency()
    }
}

// - MARK: flippedDiskCoordinatesByPlacingDisk

extension GameLogicTests {

    func test_flippedDiskCoordinatesByPlacingDisk_diskが有効な位置の場合() throws {
        let board: [[Disk?]] = [
            [nil, nil,    nil,   nil,   nil],
            [nil, .light, .dark, nil,   nil],
            [nil, .light, .dark, .dark, nil],
            [nil, .light, nil,   nil,   nil]
        ]
        dependency.store.$cells.accept(board.enumerated().map { y, rows in
            rows.enumerated().map { x, disk in
                GameData.Cell(coordinate: .init(x: x, y: y), disk: disk)
            }
        })
        let logic = dependency.testTarget

        // case1
        do {
            let coordinates = logic.flippedDiskCoordinates(
                by: .light,
                at: Coordinate(x: 3, y: 1)
            )

            let expected = [
                Coordinate(x: 2, y: 1),
                Coordinate(x: 2, y: 2)
            ]
            XCTAssertEqual(coordinates, expected)
        }

        // case2
        do {
            let coordinates = logic.flippedDiskCoordinates(
                by: .light,
                at: Coordinate(x: 4, y: 2)
            )

            let expected = [
                Coordinate(x: 3, y: 2),
                Coordinate(x: 2, y: 2)
            ]
            XCTAssertEqual(coordinates, expected)
        }
    }

    func test_flippedDiskCoordinatesByPlacingDisk_diskが無効な位置の場合() {
        let board: [[Disk?]] = [
            [nil, nil,    nil,   nil,   nil],
            [nil, .light, .dark, nil,   nil],
            [nil, .light, .dark, .dark, nil],
            [nil, .light, nil,   nil,   nil]
        ]
        dependency.store.$cells.accept(board.enumerated().map { y, rows in
            rows.enumerated().map { x, disk in
                GameData.Cell(coordinate: .init(x: x, y: y), disk: disk)
            }
        })
        let logic = dependency.testTarget

        // case1
        do {
            let coordinates = logic.flippedDiskCoordinates(
                by: .dark,
                at: Coordinate(x: 3, y: 1)
            )

            XCTAssertTrue(coordinates.isEmpty)
        }

        // case2
        do {
            let coordinates = logic.flippedDiskCoordinates(
                by: .light,
                at: Coordinate(x: 2, y: 0)
            )

            XCTAssertTrue(coordinates.isEmpty)
        }
    }
}

// - MARK: validMoves

extension GameLogicTests {

    func test_validMoves() throws {
        let board: [[Disk?]] = [
            [nil, nil,    nil,   nil,   nil],
            [nil, .light, .dark, nil,   nil],
            [nil, .light, .dark, .dark, nil],
            [nil, .light, nil,   nil,   nil]
        ]
        dependency.store.$cells.accept(board.enumerated().map { y, rows in
            rows.enumerated().map { x, disk in
                GameData.Cell(coordinate: .init(x: x, y: y), disk: disk)
            }
        })

        let coordinates = dependency.testTarget.validMoves(for: .dark)

        let expected = [
            Coordinate(x: 0, y: 0),
            Coordinate(x: 0, y: 1),
            Coordinate(x: 0, y: 2),
            Coordinate(x: 0, y: 3)
        ]
        XCTAssertEqual(coordinates, expected)
    }
}

// - MARK: waitForPlayer

extension GameLogicTests {

    func test_waitForPlayer_turnがdarkで_playerDarkがmanualの場合() {
        let viewModel = dependency.testTarget
        let store = dependency.store
        let turn = Disk.dark
        store.$status.accept(.turn(turn))
        store.$playerDark.accept(.manual)

        viewModel.waitForPlayer()

        let handleDiskWithCoordinate = dependency.$handleDiskWithCoordinate
        XCTAssertEqual(handleDiskWithCoordinate.calledCount, 0)
    }

    func test_waitForPlayer_turnがlightで_playerLightがcomputerの場合() {
        let logic = dependency.testTarget
        let store = dependency.store
        let turn = Disk.light
        store.$status.accept(.turn(turn))
        store.$playerLight.accept(.computer)
        let disk = Disk.light
        store.$status.accept(.turn(disk))
        store.$cells.accept([
            [
                GameData.Cell(coordinate: .init(x: 0, y: 0), disk: nil),
                GameData.Cell(coordinate: .init(x: 1, y: 0), disk: .dark),
                GameData.Cell(coordinate: .init(x: 2, y: 0), disk: .light)
            ]
        ])

        logic.waitForPlayer()

        let scheduler = dependency.testScheduler
        scheduler.advanceTo(scheduler.clock + 200)

        let handleDiskWithCoordinate = dependency.$handleDiskWithCoordinate
        XCTAssertEqual(handleDiskWithCoordinate.calledCount, 1)
    }

    func test_waitForPlayer_statusがgameOverの場合() {
        let viewModel = dependency.testTarget
        let store = dependency.store
        store.$status.accept(.gameOver)
        store.$playerDark.accept(.computer)
        store.$playerLight.accept(.computer)

        viewModel.waitForPlayer()

        let handleDiskWithCoordinate = dependency.$handleDiskWithCoordinate
        XCTAssertEqual(handleDiskWithCoordinate.calledCount, 0)
    }
}

// - MARK: setPlayer

extension GameLogicTests {

    func test_setPlayer_playerDarkに値が反映される() {
        let logic = dependency.testTarget
        let actionCreator = dependency.actionCreator
        let disk = Disk.dark

        logic.setPlayer(for: disk, with: 1)
        XCTAssertEqual(actionCreator.$_setPlayerOfDark.parameters, [.computer])

        logic.setPlayer(for: disk, with: 0)
        XCTAssertEqual(actionCreator.$_setPlayerOfDark.parameters, [.computer, .manual])
    }

    func test_setPlayer_playerLightに値が反映される() {
        let logic = dependency.testTarget
        let actionCreator = dependency.actionCreator
        let disk = Disk.light

        logic.setPlayer(for: disk, with: 1)
        XCTAssertEqual(actionCreator.$_setPlayerOfLight.parameters, [.computer])

        logic.setPlayer(for: disk, with: 0)
        XCTAssertEqual(actionCreator.$_setPlayerOfLight.parameters, [.computer, .manual])
    }

    func test_setPlayer_diskと現在のplayerが一致していて_playerがcomputerの場合() {
        let logic = dependency.testTarget
        let store = dependency.store
        let disk = Disk.light
        store.$status.accept(.turn(disk))
        store.$playerLight.accept(.computer)
        store.$cells.accept([
            [
                GameData.Cell(coordinate: .init(x: 0, y: 0), disk: nil),
                GameData.Cell(coordinate: .init(x: 1, y: 0), disk: .dark),
                GameData.Cell(coordinate: .init(x: 2, y: 0), disk: .light)
            ]
        ])

        logic.setPlayer(for: disk, with: 1)

        let scheduler = dependency.testScheduler
        scheduler.advanceTo(scheduler.clock + 200)

        let handleDiskWithCoordinate = dependency.$handleDiskWithCoordinate
        XCTAssertEqual(handleDiskWithCoordinate.calledCount, 1)
    }

    func test_setPlayer_diskと現在のplayerが不一致で_playerがcomputerの場合() {
        let logic = dependency.testTarget
        let store = dependency.store
        store.$status.accept(.turn(.light))
        store.$playerLight.accept(.computer)

        logic.setPlayer(for: .dark, with: 1)

        let handleDiskWithCoordinate = dependency.$handleDiskWithCoordinate
        XCTAssertEqual(handleDiskWithCoordinate.calledCount, 0)
    }

    func test_setPlayer_diskと現在のplayerが一致していて_playerがmanualの場合() {
        let logic = dependency.testTarget
        let store = dependency.store
        let disk = Disk.light
        store.$status.accept(.turn(disk))
        store.$playerLight.accept(.manual)

        logic.setPlayer(for: disk, with: 0)

        let handleDiskWithCoordinate = dependency.$handleDiskWithCoordinate
        XCTAssertEqual(handleDiskWithCoordinate.calledCount, 0)
    }
}

// - MARK: startGame

extension GameLogicTests {

    func test_newGame() {
        let logic = dependency.testTarget
        let store = dependency.store
        let actionCreator = dependency.actionCreator

        let newGameBegan = BehaviorRelay<Void?>(value: nil)
        let disposable = logic.newGameBegan
            .bind(to: newGameBegan)
        defer { disposable.dispose() }

        logic.newGame()

        let reset = actionCreator.$_reset
        XCTAssertEqual(reset.calledCount, 1)

        let save = actionCreator.$_save
        XCTAssertEqual(save.calledCount, 1)

        XCTAssertNotNil(newGameBegan.value)
    }

    func test_startGame() throws {
        let logic = dependency.testTarget
        logic.startGame()

        let load = dependency.actionCreator.$_load
        XCTAssertEqual(load.calledCount, 1)
    }

    func test_handleSelectedCoordinate_statusがturnで_playerがmanualの場合() {
        let logic = dependency.testTarget
        let store = dependency.store

        let disk = Disk.dark
        store.$status.accept(.turn(disk))
        store.$playerOfCurrentTurn.accept(.manual)
        logic.placeDiskCanceller = nil

        let diskWithCoordinate = BehaviorRelay<(Disk, Coordinate)?>(value: nil)
        let disposable = logic.handleDiskWithCoordinate
            .bind(to: diskWithCoordinate)
        defer { disposable.dispose() }

        let coordinate = Coordinate(x: 0, y: 0)
        logic.handle(selectedCoordinate: coordinate)

        XCTAssertEqual(diskWithCoordinate.value?.0, disk)
        XCTAssertEqual(diskWithCoordinate.value?.1, coordinate)
    }

    func test_handleSelectedCoordinate_statusがgameOverの場合() {
        let logic = dependency.testTarget
        let store = dependency.store

        store.$status.accept(.gameOver)

        let diskWithCoordinate = BehaviorRelay<(Disk, Coordinate)?>(value: nil)
        let disposable = logic.handleDiskWithCoordinate
            .bind(to: diskWithCoordinate)
        defer { disposable.dispose() }

        let coordinate = Coordinate(x: 0, y: 0)
        logic.handle(selectedCoordinate: coordinate)

        XCTAssertNil(diskWithCoordinate.value)
    }

    func test_handleSelectedCoordinate_statusがturnで_playerがcomputerの場合() {
        let logic = dependency.testTarget
        let store = dependency.store

        let disk = Disk.dark
        store.$status.accept(.turn(disk))
        store.$playerDark.accept(.computer)

        let diskWithCoordinate = BehaviorRelay<(Disk, Coordinate)?>(value: nil)
        let disposable = logic.handleDiskWithCoordinate
            .bind(to: diskWithCoordinate)
        defer { disposable.dispose() }

        let coordinate = Coordinate(x: 0, y: 0)
        logic.handle(selectedCoordinate: coordinate)

        XCTAssertNil(diskWithCoordinate.value)
    }
}

// - MARK:

extension GameLogicTests {

    func test_playTurnOfComputer() throws {
        let logic = dependency.testTarget
        let store = dependency.store
        let scheduler = dependency.testScheduler
        let disk = Disk.light
        store.$status.accept(.turn(disk))
        store.$cells.accept([
            [
                GameData.Cell(coordinate: .init(x: 0, y: 0), disk: nil),
                GameData.Cell(coordinate: .init(x: 1, y: 0), disk: .dark),
                GameData.Cell(coordinate: .init(x: 2, y: 0), disk: .light)
            ]
        ])

        let willTurnDiskOfComputer = BehaviorRelay<Disk?>(value: nil)
        let disposable = logic.willTurnDiskOfComputer
            .bind(to: willTurnDiskOfComputer)
        defer { disposable.dispose() }

        let didTurnDiskOfComputer = BehaviorRelay<Disk?>(value: nil)
        let disposable2 = logic.didTurnDiskOfComputer
            .bind(to: didTurnDiskOfComputer)
        defer { disposable2.dispose() }

        logic.playTurnOfComputer()

        XCTAssertNotNil(logic.playerCancellers[disk])

        scheduler.advanceTo(scheduler.clock + 200)

        XCTAssertEqual(willTurnDiskOfComputer.value, disk)
        XCTAssertEqual(didTurnDiskOfComputer.value, disk)

        XCTAssertNil(logic.playerCancellers[disk])

        let handleDiskWithCoordinate = dependency.$handleDiskWithCoordinate
        XCTAssertEqual(handleDiskWithCoordinate.parameters,
                       [Dependency.DiskCoordinate(disk: disk, coordinate: .init(x: 0, y: 0))])
    }
}

extension GameLogicTests {

    private final class Dependency {

        @MockResponse<DiskCoordinate, Void>()
        var handleDiskWithCoordinate: Void

        private(set) lazy var testTarget = GameLogic(
            actionCreator: actionCreator,
            store: store,
            mainScheduler: testScheduler
        )

        let actionCreator = MockGameActionCreator()
        let store = MockGameStore()
        let testScheduler = TestScheduler(initialClock: 0)

        private let disposeBag = DisposeBag()

        init() {
            testTarget.handleDiskWithCoordinate
                .subscribe(onNext: { [weak self] in
                    self?._handleDiskWithCoordinate.respond(.init(disk: $0, coordinate: $1))
                })
                .disposed(by: disposeBag)
        }

        struct DiskCoordinate: Equatable {
            let disk: Disk
            let coordinate: Coordinate
        }
    }
}
