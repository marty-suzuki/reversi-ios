import ReversiLogic
import RxCocoa
import RxSwift
import UIKit

class ViewController: UIViewController {
    @IBOutlet private var boardView: BoardView! {
        didSet { boardView.delegate = self }
    }
    
    @IBOutlet private var resetButton: UIButton!
    @IBOutlet private var messageDiskView: DiskView!
    @IBOutlet private var messageLabel: UILabel!
    @IBOutlet private var messageDiskSizeConstraint: NSLayoutConstraint!
    
    @IBOutlet private var playerDarkControl: UISegmentedControl!
    @IBOutlet private var playerLightControl: UISegmentedControl!

    @IBOutlet private var playerDarkCountLabel: UILabel!
    @IBOutlet private var playerLightCountLabel: UILabel!

    @IBOutlet private var playerDarkActivityIndicator: UIActivityIndicatorView!
    @IBOutlet private var playerLightActivityIndicator: UIActivityIndicatorView!

    private let disposeBag = DisposeBag()

    private lazy var viewModel = ReversiViewModel(
        messageDiskSize: messageDiskSizeConstraint.constant,
        asyncAfter: { DispatchQueue.main.asyncAfter(deadline: $0, execute: $1) },
        async: { DispatchQueue.main.async(execute: $0) },
        logicFactory: GameLogicFactory()
    )

    override func viewDidLoad() {
        super.viewDidLoad()

        defer { viewModel.startGame() }

        let scheduler = ConcurrentMainScheduler.instance

        viewModel.showAlert
            .bind(to: Binder(self, scheduler: scheduler) { me, alert in
                let alertController = UIAlertController.make(alert: alert)
                me.present(alertController, animated: true)
            })
            .disposed(by: disposeBag)

        viewModel.messageDisk
            .bind(to: Binder(self, scheduler: scheduler) { me, disk in
                me.messageDiskView.disk = disk
            })
            .disposed(by: disposeBag)

        viewModel.messageDiskSizeConstant
            .bind(to: Binder(self, scheduler: scheduler) { me, constant in
                me.messageDiskSizeConstraint.constant = constant
            })
            .disposed(by: disposeBag)

        viewModel.resetBoard
            .bind(to: Binder(self, scheduler: scheduler) { me, _ in
                me.boardView.reset()
            })
            .disposed(by: disposeBag)

        viewModel.updateBoard
            .bind(to: Binder(self, scheduler: scheduler) { me, update in
                me.boardView.setDisk(update.disk,
                                     atX: update.coordinate.x,
                                     y: update.coordinate.y,
                                     animated: update.animated,
                                     completion: update.completion)
            })
            .disposed(by: disposeBag)

        viewModel.messageText
            .bind(to: messageLabel.rx.text)
            .disposed(by: disposeBag)

        viewModel.isPlayerDarkAnimating
            .bind(to: playerDarkActivityIndicator.rx.isAnimating)
            .disposed(by: disposeBag)

        viewModel.isPlayerLightAnimating
            .bind(to: playerLightActivityIndicator.rx.isAnimating)
            .disposed(by: disposeBag)

        viewModel.playerDarkCount
            .bind(to: playerDarkCountLabel.rx.text)
            .disposed(by: disposeBag)

        viewModel.playerLightCount
            .bind(to: playerLightCountLabel.rx.text)
            .disposed(by: disposeBag)

        viewModel.playerDarkSelectedIndex
            .bind(to: playerDarkControl.rx.selectedSegmentIndex)
            .disposed(by: disposeBag)

        viewModel.playerLightSelectedIndex
            .bind(to: playerLightControl.rx.selectedSegmentIndex)
            .disposed(by: disposeBag)

        playerDarkControl.rx.selectedSegmentIndex
            .changed
            .bind(to: Binder(self, scheduler: scheduler) { me, index in
                me.viewModel.setPlayer(for: .dark, with: index)
            })
            .disposed(by: disposeBag)

        playerLightControl.rx.selectedSegmentIndex
            .changed
            .bind(to: Binder(self, scheduler: scheduler) { me, index in
                me.viewModel.setPlayer(for: .light, with: index)
            })
            .disposed(by: disposeBag)

        resetButton.rx.tap
            .bind(to: Binder(self, scheduler: scheduler) { me, _ in
                me.viewModel.handleReset()
            })
            .disposed(by: disposeBag)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        viewModel.viewDidAppear()
    }
}

extension ViewController: BoardViewDelegate {
    func boardView(_ boardView: BoardView, didSelectCellAtX x: Int, y: Int) {
        viewModel.handle(selectedCoordinate: .init(x: x, y: y))
    }
}
