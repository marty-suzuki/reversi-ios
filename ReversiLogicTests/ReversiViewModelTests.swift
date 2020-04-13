import XCTest
@testable import ReversiLogic

final class ReversiViewModelTests: XCTestCase {

    private var dependency: Dependency!

    override func setUp() {
        self.dependency = Dependency()
    }

    func test_waitForPlayer_turnがdarkで_selectedSegmentIndexが0の場合() {
        let viewModel = dependency.testTarget
        let turn = Disk.dark

        viewModel.turn = turn
        dependency.selectedSegmentIndexForResponse = 0

        viewModel.waitForPlayer()

        XCTAssertEqual(dependency.selectedSegmentIndexForCalledCount, 1)
        XCTAssertEqual(dependency.selectedSegmentIndexForParameters, [turn.index])
        XCTAssertEqual(dependency.playTurnOfComputerCalledCount, 0)
    }

    func test_waitForPlayer_turnがlightで_selectedSegmentIndexが1の場合() {
        let viewModel = dependency.testTarget
        let turn = Disk.light

        viewModel.turn = turn
        dependency.selectedSegmentIndexForResponse = 1

        viewModel.waitForPlayer()

        XCTAssertEqual(dependency.selectedSegmentIndexForCalledCount, 1)
        XCTAssertEqual(dependency.selectedSegmentIndexForParameters, [turn.index])
        XCTAssertEqual(dependency.playTurnOfComputerCalledCount, 1)
    }

    func test_waitForPlayer_turnがnilの場合() {
        let viewModel = dependency.testTarget

        viewModel.turn = nil
        viewModel.waitForPlayer()

        XCTAssertEqual(dependency.selectedSegmentIndexForCalledCount, 0)
        XCTAssertEqual(dependency.selectedSegmentIndexForParameters, [])
        XCTAssertEqual(dependency.playTurnOfComputerCalledCount, 0)
    }
}

extension ReversiViewModelTests {

    final class Dependency {
        private(set) var playTurnOfComputerCalledCount = 0

        private(set) var selectedSegmentIndexForCalledCount = 0
        private(set) var selectedSegmentIndexForParameters: [Int] = []
        var selectedSegmentIndexForResponse = 0

        private(set) lazy var testTarget = ReversiViewModel(
            playTurnOfComputer: { [weak self] in self?.playTurnOfComputer() },
            selectedSegmentIndexFor: { [weak self] in self?.selectedSegmentIndexFor($0) })

        func playTurnOfComputer() {
            playTurnOfComputerCalledCount += 1
        }

        func selectedSegmentIndexFor(_ index: Int) -> Int {
            selectedSegmentIndexForCalledCount += 1
            selectedSegmentIndexForParameters += [index]
            return selectedSegmentIndexForResponse
        }
    }
}
