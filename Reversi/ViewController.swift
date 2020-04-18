import ReversiLogic
import UIKit

class ViewController: UIViewController {
    @IBOutlet private var boardView: BoardView! {
        didSet {
            boardView.delegate = self
        }
    }
    
    @IBOutlet private var messageDiskView: DiskView!
    @IBOutlet private var messageLabel: UILabel!
    @IBOutlet private var messageDiskSizeConstraint: NSLayoutConstraint!
    
    @IBOutlet private var playerDarkControl: UISegmentedControl!
    @IBOutlet private var playerLightControl: UISegmentedControl!

    @IBOutlet private var playerDarkCountLabel: UILabel!
    @IBOutlet private var playerLightCountLabel: UILabel!

    @IBOutlet private var playerDarkActivityIndicator: UIActivityIndicatorView!
    @IBOutlet private var playerLightActivityIndicator: UIActivityIndicatorView!

    private lazy var viewModel = ReversiViewModel(
        messageDiskSize: messageDiskSizeConstraint.constant,
        showAlert: { [weak self] in self?.showAlert($0) },
        setPlayerDarkCount: { [weak self] in self?.playerDarkCountLabel.text = $0 },
        setPlayerLightCount: { [weak self] in self?.playerLightCountLabel.text = $0 },
        setMessageDiskSizeConstant: { [weak self] in self?.messageDiskSizeConstraint.constant = $0 },
        setMessageDisk: { [weak self] in self?.messageDiskView.disk = $0 },
        setMessageText: { [weak self] in self?.messageLabel.text = $0 },
        setDisk: { [weak self] in self?.boardView.setDisk($0, atX: $1, y: $2, animated: $3, completion: $4) },
        setPlayerDarkSelectedIndex: { [weak self] in self?.playerDarkControl.selectedSegmentIndex = $0 },
        setPlayerLightSelectedIndex: { [weak self] in self?.playerLightControl.selectedSegmentIndex = $0 },
        startPlayerDarkAnimation: { [weak self] in self?.playerDarkActivityIndicator.startAnimating() },
        stopPlayerDarkAnimation: { [weak self] in self?.playerDarkActivityIndicator.stopAnimating() },
        startPlayerLightAnimation: { [weak self] in self?.playerLightActivityIndicator.startAnimating() },
        stopPlayerLightAnimation: { [weak self] in self?.playerLightActivityIndicator.stopAnimating() },
        reset: { [weak self] in self?.boardView.reset() },
        asyncAfter: { DispatchQueue.main.asyncAfter(deadline: $0, execute: $1) },
        async: { DispatchQueue.main.async(execute: $0) },
        cache: GameDataCacheFactory.make()
    )

    override func viewDidLoad() {
        super.viewDidLoad()
        viewModel.startGame()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        viewModel.viewDidAppear()
    }

    private func showAlert(_ alert: Alert) {
        let alertController = UIAlertController.make(alert: alert)
        present(alertController, animated: true)
    }
}

// MARK: Inputs

extension ViewController {
    @IBAction func pressResetButton(_ sender: UIButton) {
        viewModel.handleReset()
    }

    @IBAction func changePlayerDarkControl(_ sender: UISegmentedControl) {
        viewModel.setPlayer(for: .dark,
                            with: sender.selectedSegmentIndex)
    }

    @IBAction func changePlayerLightControl(_ sender: UISegmentedControl) {
        viewModel.setPlayer(for: .light,
                            with: sender.selectedSegmentIndex)
    }
}

extension ViewController: BoardViewDelegate {
    func boardView(_ boardView: BoardView, didSelectCellAtX x: Int, y: Int) {
        viewModel.handle(selectedCoordinate: .init(x: x, y: y))
    }
}
