import ReversiLogic
import RxCocoa
import RxSwift
import UIKit

class ViewController: UIViewController {
    @IBOutlet private(set) var boardView: BoardView! {
        didSet { boardView.delegate = self }
    }
    
    @IBOutlet private(set) var resetButton: UIButton!
    @IBOutlet private(set) var messageDiskView: DiskView!
    @IBOutlet private(set) var messageLabel: UILabel!
    @IBOutlet private(set) var messageDiskSizeConstraint: NSLayoutConstraint!
    
    @IBOutlet private(set) var playerDarkControl: UISegmentedControl!
    @IBOutlet private(set) var playerLightControl: UISegmentedControl!

    @IBOutlet private(set) var playerDarkCountLabel: UILabel!
    @IBOutlet private(set) var playerLightCountLabel: UILabel!

    @IBOutlet private(set) var playerDarkActivityIndicator: UIActivityIndicatorView!
    @IBOutlet private(set) var playerLightActivityIndicator: UIActivityIndicatorView!

    private let disposeBag = DisposeBag()
    @Lazy() private var viewModelFactory: ReversiViewModelFactoryType
    private lazy var viewModel = viewModelFactory.make(
        messageDiskSize: messageDiskSizeConstraint.constant,
        mainAsyncScheduler: MainScheduler.asyncInstance,
        mainScheduler: MainScheduler.instance
    )

    override func viewDidLoad() {
        super.viewDidLoad()

        do {
            let output = viewModel.output
            let scheduler = ConcurrentMainScheduler.instance

            output.showAlert
                .bind(to: Binder(self, scheduler: scheduler) { me, alert in
                    let alertController = UIAlertController.make(alert: alert)
                    me.present(alertController, animated: true)
                })
                .disposed(by: disposeBag)

            output.messageDisk
                .bind(to: Binder(self, scheduler: scheduler) { me, disk in
                    me.messageDiskView.disk = disk
                })
                .disposed(by: disposeBag)

            output.messageDiskSizeConstant
                .bind(to: Binder(self, scheduler: scheduler) { me, constant in
                    me.messageDiskSizeConstraint.constant = constant
                })
                .disposed(by: disposeBag)

            output.resetBoard
                .bind(to: Binder(self, scheduler: scheduler) { me, _ in
                    me.boardView.reset()
                })
                .disposed(by: disposeBag)

            output.updateBoard
                .bind(to: Binder(self, scheduler: scheduler) { me, update in
                    me.boardView.setDisk(update.disk,
                                         atX: update.coordinate.x,
                                         y: update.coordinate.y,
                                         animated: update.animated,
                                         completion: update.completion)
                })
                .disposed(by: disposeBag)

            output.messageText
                .bind(to: messageLabel.rx.text)
                .disposed(by: disposeBag)

            output.isPlayerDarkAnimating
                .bind(to: playerDarkActivityIndicator.rx.isAnimating)
                .disposed(by: disposeBag)

            output.isPlayerLightAnimating
                .bind(to: playerLightActivityIndicator.rx.isAnimating)
                .disposed(by: disposeBag)

            output.playerDarkCount
                .bind(to: playerDarkCountLabel.rx.text)
                .disposed(by: disposeBag)

            output.playerLightCount
                .bind(to: playerLightCountLabel.rx.text)
                .disposed(by: disposeBag)

            output.playerDarkSelectedIndex
                .bind(to: playerDarkControl.rx.selectedSegmentIndex)
                .disposed(by: disposeBag)

            output.playerLightSelectedIndex
                .bind(to: playerLightControl.rx.selectedSegmentIndex)
                .disposed(by: disposeBag)
        }

        do {
            let input = viewModel.input
            defer { input.startGame(()) }

            playerDarkControl.rx.selectedSegmentIndex.changed
                .map { (.dark, $0) }
                .bind(to: input.setPlayerWithDiskAndIndex)
                .disposed(by: disposeBag)

            playerLightControl.rx.selectedSegmentIndex.changed
                .map { (.light, $0) }
                .bind(to: input.setPlayerWithDiskAndIndex)
                .disposed(by: disposeBag)

            resetButton.rx.tap
                .bind(to: input.handleReset)
                .disposed(by: disposeBag)
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        viewModel.input.viewDidAppear(())
    }
}

extension ViewController: BoardViewDelegate {
    func boardView(_ boardView: BoardView, didSelectCellAtX x: Int, y: Int) {
        viewModel.input.handleSelectedCoordinate(.init(x: x, y: y))
    }
}

extension ViewController {
    static func make(factory: ReversiViewModelFactoryType) -> ViewController {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let vc: ViewController = storyboard.instantiateInitialViewController()!
        vc.viewModelFactory = factory
        return vc
    }
}
