import RxRelay
import RxSwift
import RxTest
import TestModule
import XCTest
@testable import ReversiLogic

final class ReversiViewModelTests: XCTestCase {

    private var dependency: Dependency!

    override func setUp() {
        self.dependency = Dependency(messageDiskSize: 0)
    }
}

extension ReversiViewModelTests {
    func test_input_viewDidAppear_waitForPlayerが2回呼ばれることはない() {
        let viewModel = dependency.testTarget
        let managementStream = dependency.managementStream

        let watcher = Watcher(managementStream._input.waitForPlayer)

        viewModel.input.viewDidAppear(())
        XCTAssertEqual(watcher.calledCount, 1)

        viewModel.input.viewDidAppear(())
        XCTAssertEqual(watcher.calledCount, 1)
    }
}

extension ReversiViewModelTests {
    func test_output_messageXXX_statusがgameOverじゃない場合() {
        let expectedSize = CGFloat(arc4random() % 100)
        self.dependency = Dependency(messageDiskSize: expectedSize)
        let managementStream = dependency.managementStream
        let viewModel = dependency.testTarget

        let messageDiskSizeConstant = Watcher(viewModel.output.messageDiskSizeConstant)
        let messageDisk = Watcher(viewModel.output.messageDisk)
        let mwssageText = Watcher(viewModel.output.messageText)

        let expectedTurn = Disk.light
        managementStream.$status.accept(.turn(expectedTurn))

        XCTAssertEqual(messageDiskSizeConstant.calledCount, 1)
        XCTAssertEqual(messageDiskSizeConstant.parameters, [expectedSize])

        XCTAssertEqual(messageDisk.calledCount, 1)
        XCTAssertEqual(messageDisk.parameters, [expectedTurn])

        XCTAssertEqual(mwssageText.calledCount, 1)
        XCTAssertEqual(mwssageText.parameters, ["'s turn"])
    }

    func test_output_messageXXX_statusがgameOverで勝者がいる場合() {
        let expectedDisk = Disk.dark
        let expectedSize = CGFloat(arc4random() % 100)
        self.dependency = Dependency(messageDiskSize: expectedSize)
        let managementStream = dependency.managementStream
        let viewModel = dependency.testTarget

        let messageDiskSizeConstant = Watcher(viewModel.output.messageDiskSizeConstant)
        let messageDisk = Watcher(viewModel.output.messageDisk)
        let messageText = Watcher(viewModel.output.messageText)

        managementStream.$sideWithMoreDisks.accept(expectedDisk)
        managementStream.$status.accept(.gameOver)

        XCTAssertEqual(messageDiskSizeConstant.calledCount, 1)
        XCTAssertEqual(messageDiskSizeConstant.parameters, [expectedSize])

        XCTAssertEqual(messageDisk.calledCount, 1)
        XCTAssertEqual(messageDisk.parameters, [expectedDisk])

        XCTAssertEqual(messageText.calledCount, 1)
        XCTAssertEqual(messageText.parameters, [" won"])
    }

    func test_output_messageXXX_statusがgameOverで勝者がいない場合() {
        let managementStream = dependency.managementStream
        let viewModel = dependency.testTarget
        self.dependency = Dependency(messageDiskSize: 0)

        let messageDiskSizeConstant = Watcher(viewModel.output.messageDiskSizeConstant)
        let messageDisk = Watcher(viewModel.output.messageDisk)
        let mwssageText = Watcher(viewModel.output.messageText)

        managementStream.$sideWithMoreDisks.accept(nil)
        managementStream.$status.accept(.gameOver)

        XCTAssertEqual(messageDiskSizeConstant.calledCount, 1)
        XCTAssertEqual(messageDiskSizeConstant.parameters, [0])

        XCTAssertEqual(messageDisk.calledCount, 0)

        XCTAssertEqual(mwssageText.calledCount, 1)
        XCTAssertEqual(mwssageText.parameters, ["Tied"])
    }
}

extension ReversiViewModelTests {
    func test_output_playerXXXCount_didRefreshAllDiskが発火する() {
        let darkCount = Int(arc4random() % 100)
        let lightCount = Int(arc4random() % 100)
        let managementStream = dependency.managementStream
        let viewModel = dependency.testTarget

        managementStream.$countOfDark.accept(darkCount)
        managementStream.$countOfLight.accept(lightCount)

        let playerDarkCount = Watcher(viewModel.output.playerDarkCount)
        let playerLightCount = Watcher(viewModel.output.playerLightCount)

        managementStream.$didRefreshAllDisk.accept(())

        XCTAssertEqual(playerDarkCount.calledCount, 1)
        XCTAssertEqual(playerDarkCount.parameters, ["\(darkCount)"])

        XCTAssertEqual(playerLightCount.calledCount, 1)
        XCTAssertEqual(playerLightCount.parameters, ["\(lightCount)"])
    }

    func test_output_playerXXXCount_didUpdateDiskが発火する() {
        let darkCount = Int(arc4random() % 100)
        let lightCount = Int(arc4random() % 100)
        let managementStream = dependency.managementStream
        let viewModel = dependency.testTarget

        managementStream.$countOfDark.accept(darkCount)
        managementStream.$countOfLight.accept(lightCount)

        let playerDarkCount = Watcher(viewModel.output.playerDarkCount)
        let playerLightCount = Watcher(viewModel.output.playerLightCount)

        managementStream.$didUpdateDisk.accept(true)

        XCTAssertEqual(playerDarkCount.calledCount, 1)
        XCTAssertEqual(playerDarkCount.parameters, ["\(darkCount)"])

        XCTAssertEqual(playerLightCount.calledCount, 1)
        XCTAssertEqual(playerLightCount.parameters, ["\(lightCount)"])
    }

    func test_output_playerXXXCount_and_resetBoard_didUpdateDiskが発火する() {
        let darkCount = Int(arc4random() % 100)
        let lightCount = Int(arc4random() % 100)
        let managementStream = dependency.managementStream
        let viewModel = dependency.testTarget

        managementStream.$countOfDark.accept(darkCount)
        managementStream.$countOfLight.accept(lightCount)

        let playerDarkCount = Watcher(viewModel.output.playerDarkCount)
        let playerLightCount = Watcher(viewModel.output.playerLightCount)
        let resetBoard = Watcher(viewModel.output.resetBoard)

        managementStream.$newGameBegan.accept(())

        XCTAssertEqual(playerDarkCount.calledCount, 1)
        XCTAssertEqual(playerDarkCount.parameters, ["\(darkCount)"])

        XCTAssertEqual(playerLightCount.calledCount, 1)
        XCTAssertEqual(playerLightCount.parameters, ["\(lightCount)"])

        XCTAssertEqual(resetBoard.calledCount, 1)
        XCTAssertEqual(resetBoard.parameters.count, 1)
    }
}

extension ReversiViewModelTests {
    func test_output_isPlayerXXXAnimating() {
        let managementStream = dependency.managementStream
        let viewModel = dependency.testTarget

        let isPlayerDarkAnimating = Watcher(viewModel.output.isPlayerDarkAnimating)
        let isPlayerLightAnimating = Watcher(viewModel.output.isPlayerLightAnimating)

        managementStream.$willTurnDiskOfComputer.accept(.dark)

        XCTAssertEqual(isPlayerDarkAnimating.calledCount, 1)
        XCTAssertEqual(isPlayerDarkAnimating.parameters, [true])
        XCTAssertEqual(isPlayerLightAnimating.calledCount, 0)

        managementStream.$didTurnDiskOfComputer.accept(.light)

        XCTAssertEqual(isPlayerDarkAnimating.calledCount, 1)
        XCTAssertEqual(isPlayerDarkAnimating.parameters, [true])
        XCTAssertEqual(isPlayerLightAnimating.calledCount, 1)
        XCTAssertEqual(isPlayerLightAnimating.parameters, [false])
    }
}

extension ReversiViewModelTests {
    func test_output_playerXXXSelectedIndex_同じ値では複数回発火しない() {
        let managementStream = dependency.managementStream
        let viewModel = dependency.testTarget

        do {
            let playerDarkSelectedIndex = Watcher(viewModel.output.playerDarkSelectedIndex.skip(1))

            managementStream.$playerDark.accept(.computer)
            managementStream.$playerDark.accept(.computer)
            managementStream.$playerDark.accept(.computer)
            managementStream.$playerDark.accept(.manual)
            managementStream.$playerDark.accept(.manual)

            let expected = [
                GameData.Player.computer.rawValue,
                GameData.Player.manual.rawValue
            ]
            XCTAssertEqual(playerDarkSelectedIndex.calledCount, 2)
            XCTAssertEqual(playerDarkSelectedIndex.parameters, expected)
        }

        do {
            let playerLightSelectedIndex = Watcher(viewModel.output.playerLightSelectedIndex.skip(1))

            managementStream.$playerLight.accept(.computer)
            managementStream.$playerLight.accept(.computer)
            managementStream.$playerLight.accept(.computer)
            managementStream.$playerLight.accept(.manual)
            managementStream.$playerLight.accept(.manual)

            let expected = [
                GameData.Player.computer.rawValue,
                GameData.Player.manual.rawValue
            ]
            XCTAssertEqual(playerLightSelectedIndex.calledCount, 2)
            XCTAssertEqual(playerLightSelectedIndex.parameters, expected)
        }
    }
}

extension ReversiViewModelTests {
    fileprivate final class Dependency {

        let state = ReversiViewModel.State()
        let testScheduler = TestScheduler(initialClock: 0)
        let managementStream = MockReversiManagementStream()
        private(set) lazy var extra = ReversiViewModel.Extra(
            messageDiskSize: messageDiskSize,
            mainAsyncScheduler: testScheduler,
            mainScheduler: testScheduler,
            managementStream: managementStream
        )

        private let messageDiskSize: CGFloat
        private let disposeBag = DisposeBag()

        private(set) lazy var testTarget = ReversiViewModel(
            input: ReversiViewModel.Input(),
            state: state,
            extra: extra
        )

        init(messageDiskSize: CGFloat) {
            self.messageDiskSize = messageDiskSize
        }
    }
}
