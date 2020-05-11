import XCTest
import ReversiLogic
import RxRelay
import RxSwift
import TestModule
import UIKit
import Unio
@testable import Reversi

final class ViewControllerTests: XCTestCase {
    private var dependency: Dependency!

    override func setUp() {
        self.dependency = Dependency()
    }
}

// MARK: - Input tests

extension ViewControllerTests {
    func test_input_playerDarkControlのselectedSegmentIndexが変わる() throws {
        let vc = dependency.testTarget
        let input = dependency.viewModel._input
        vc.loadViewIfNeeded()

        let index = 0
        let setPlayerWithDiskAndIndex = Watcher(input.setPlayerWithDiskAndIndex)
        vc.playerDarkControl.selectedSegmentIndex = index
        vc.playerDarkControl.sendActions(for: .valueChanged)

        XCTAssertEqual(setPlayerWithDiskAndIndex.calledCount, 1)
        let parameter = try XCTUnwrap(setPlayerWithDiskAndIndex.parameters.last)
        XCTAssertEqual(parameter.0, .dark)
        XCTAssertEqual(parameter.1, index)
    }

    func test_input_playerLightControlのselectedSegmentIndexが変わる() throws {
        let vc = dependency.testTarget
        let input = dependency.viewModel._input
        vc.loadViewIfNeeded()

        let index = 0
        let setPlayerWithDiskAndIndex = Watcher(input.setPlayerWithDiskAndIndex)
        vc.playerLightControl.selectedSegmentIndex = index
        vc.playerLightControl.sendActions(for: .valueChanged)

        XCTAssertEqual(setPlayerWithDiskAndIndex.calledCount, 1)
        let parameter = try XCTUnwrap(setPlayerWithDiskAndIndex.parameters.last)
        XCTAssertEqual(parameter.0, .light)
        XCTAssertEqual(parameter.1, index)
    }

    func test_input_resetButtonが発火する() {
        let vc = dependency.testTarget
        let input = dependency.viewModel._input
        vc.loadViewIfNeeded()

        let handleReset = Watcher(input.handleReset)
        vc.resetButton.sendActions(for: .touchUpInside)

        XCTAssertEqual(handleReset.calledCount, 1)
    }

    func test_input_BoardViewDelegateが発火する() {
        let vc = dependency.testTarget
        let input = dependency.viewModel._input
        vc.loadViewIfNeeded()

        let coordinate = Coordinate(x: 0, y: 0)
        let handleSelectedCoordinate = Watcher(input.handleSelectedCoordinate)
        vc.boardView(vc.boardView, didSelectCellAtX: coordinate.x, y: coordinate.y)

        XCTAssertEqual(handleSelectedCoordinate.calledCount, 1)
        XCTAssertEqual(handleSelectedCoordinate.parameters, [coordinate])
    }

    func test_input_viewDidAppearが発火する() {
        let vc = dependency.testTarget
        let input = dependency.viewModel._input
        vc.loadViewIfNeeded()

        let viewDidAppear = Watcher(input.viewDidAppear)
        vc.viewDidAppear(true)

        XCTAssertEqual(viewDidAppear.calledCount, 1)
    }
}

// MARK: - Output tests

extension ViewControllerTests {
    func test_output_showAlert() throws {
        let window = UIWindow(frame: .zero)
        let vc = dependency.testTarget
        window.rootViewController = vc
        window.makeKeyAndVisible()
        let vm = dependency.viewModel
        let alert = Alert(title: "title", message: "message", actions: [])
        vm.showAlert.accept(alert)

        let avc = try XCTUnwrap(vc.presentedViewController as? UIAlertController)
        XCTAssertEqual(avc.title, alert.title)
        XCTAssertEqual(avc.message, alert.message)
    }

    func test_output_messageDisk() {
        let vc = dependency.testTarget
        let vm = dependency.viewModel
        vc.loadViewIfNeeded()

        vm.messageDisk.accept(.light)
        XCTAssertEqual(vc.messageDiskView.disk, .light)

        vm.messageDisk.accept(.dark)
        XCTAssertEqual(vc.messageDiskView.disk, .dark)
    }

    func test_output_messageDiskSizeConstant() {
        let vc = dependency.testTarget
        let vm = dependency.viewModel
        vc.loadViewIfNeeded()

        let constant: CGFloat = 10
        vm.messageDiskSizeConstant.accept(constant)
        vc.view.layoutIfNeeded()
        XCTAssertEqual(vc.messageDiskSizeConstraint.constant, constant)
    }

    func test_output_messageText() {
        let vc = dependency.testTarget
        let vm = dependency.viewModel
        vc.loadViewIfNeeded()

        let message = "message"
        vm.messageText.accept(message)
        XCTAssertEqual(vc.messageLabel.text, message)
    }

    func test_output_isPlayerDarkAnimating() {
        let vc = dependency.testTarget
        let vm = dependency.viewModel
        vc.loadViewIfNeeded()

        vm.isPlayerDarkAnimating.accept(true)
        XCTAssertEqual(vc.playerDarkActivityIndicator.isAnimating, true)

        vm.isPlayerDarkAnimating.accept(false)
        XCTAssertEqual(vc.playerDarkActivityIndicator.isAnimating, false)
    }

    func test_output_isPlayerLightAnimating() {
        let vc = dependency.testTarget
        let vm = dependency.viewModel
        vc.loadViewIfNeeded()

        vm.isPlayerLightAnimating.accept(true)
        XCTAssertEqual(vc.playerLightActivityIndicator.isAnimating, true)

        vm.isPlayerLightAnimating.accept(false)
        XCTAssertEqual(vc.playerLightActivityIndicator.isAnimating, false)
    }

    func test_output_playerDarkCount() {
        let vc = dependency.testTarget
        let vm = dependency.viewModel
        vc.loadViewIfNeeded()

        let count = "count"
        vm.playerDarkCount.accept(count)
        XCTAssertEqual(vc.playerDarkCountLabel.text, count)
    }

    func test_output_playerLightCount() {
        let vc = dependency.testTarget
        let vm = dependency.viewModel
        vc.loadViewIfNeeded()

        let count = "count"
        vm.playerLightCount.accept(count)
        XCTAssertEqual(vc.playerLightCountLabel.text, count)
    }

    func test_output_playerDarkSelectedIndex() {
        let vc = dependency.testTarget
        let vm = dependency.viewModel
        vc.loadViewIfNeeded()

        vm.playerDarkSelectedIndex.accept(1)
        XCTAssertEqual(vc.playerDarkControl.selectedSegmentIndex, 1)

        vm.playerDarkSelectedIndex.accept(0)
        XCTAssertEqual(vc.playerDarkControl.selectedSegmentIndex, 0)
    }

    func test_output_playerLightSelectedIndex() {
        let vc = dependency.testTarget
        let vm = dependency.viewModel
        vc.loadViewIfNeeded()

        vm.playerLightSelectedIndex.accept(1)
        XCTAssertEqual(vc.playerLightControl.selectedSegmentIndex, 1)

        vm.playerLightSelectedIndex.accept(0)
        XCTAssertEqual(vc.playerLightControl.selectedSegmentIndex, 0)
    }
}

extension ViewControllerTests {
    private final class Dependency {
        let testTarget: ViewController

        var viewModel: MockReversiViewModel {
            factory.viewModel
        }
        private let factory = MockReversiViewModelFactory()

        init() {
            self.testTarget = ViewController.make(factory: factory)
        }
    }

    private final class MockReversiViewModel: ReversiViewModelType {
        let input: InputWrapper<ReversiViewModel.Input>
        let _input = ReversiViewModel.Input.make()

        let output: OutputWrapper<ReversiViewModel.Output>
        let _output: ReversiViewModel.Output

        let messageDisk = PublishRelay<Disk>()
        let messageDiskSizeConstant = PublishRelay<CGFloat>()
        let messageText = PublishRelay<String>()
        let showAlert = PublishRelay<Alert>()
        let isPlayerDarkAnimating = PublishRelay<Bool>()
        let isPlayerLightAnimating = PublishRelay<Bool>()
        let playerDarkCount = PublishRelay<String>()
        let playerLightCount = PublishRelay<String>()
        let playerDarkSelectedIndex = PublishRelay<Int>()
        let playerLightSelectedIndex = PublishRelay<Int>()
        let resetBoard = PublishRelay<Void>()
        let updateBoard = PublishRelay<UpdateDisk>()

        init() {
            self.input = InputWrapper(_input)
            self._output = .make(
                messageDisk: messageDisk.asObservable(),
                messageDiskSizeConstant: messageDiskSizeConstant.asObservable(),
                messageText: messageText.asObservable(),
                showAlert: showAlert.asObservable(),
                isPlayerDarkAnimating: isPlayerDarkAnimating.asObservable(),
                isPlayerLightAnimating: isPlayerLightAnimating.asObservable(),
                playerDarkCount: playerDarkCount.asObservable(),
                playerLightCount: playerLightCount.asObservable(),
                playerDarkSelectedIndex: playerDarkSelectedIndex.asObservable(),
                playerLightSelectedIndex: playerLightSelectedIndex.asObservable(),
                resetBoard: resetBoard.asObservable(),
                updateBoard: updateBoard.asObservable()
            )
            self.output = OutputWrapper(_output)
        }
    }

    private struct MockReversiViewModelFactory: ReversiViewModelFactoryType {
        let viewModel = MockReversiViewModel()

        func make(messageDiskSize: CGFloat,
                  mainAsyncScheduler: SchedulerType,
                  mainScheduler: SchedulerType) -> ReversiViewModelType {
            viewModel
        }
    }
}
