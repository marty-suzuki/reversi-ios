import ReversiLogic
import UIKit

class ViewController: UIViewController {
    @IBOutlet private var boardView: BoardView!
    
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
        placeDisk: { [weak self] in try self?.placeDisk($0, atX: $1, y: $2, animated: $3, completion: $4) },
        showCanNotPlaceAlert: { [weak self] in self?.showCanNotPlaceAlert() },
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
        cache: GameDataCacheFactory.make()
    )

    override func viewDidLoad() {
        super.viewDidLoad()
        
        boardView.delegate = self
        
        do {
            try viewModel.loadGame()
        } catch _ {
            viewModel.newGame()
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        viewModel.viewDidAppear()
    }

    func showCanNotPlaceAlert() {
        let alertController = UIAlertController(
            title: "Pass",
            message: "Cannot place a disk.",
            preferredStyle: .alert
        )
        alertController.addAction(UIAlertAction(title: "Dismiss", style: .default) { [weak self] _ in
            self?.viewModel.nextTurn()
        })
        present(alertController, animated: true)
    }
}

// MARK: Reversi logics

extension ViewController {

    /// - Parameter completion: A closure to be executed when the animation sequence ends.
    ///     This closure has no return value and takes a single Boolean argument that indicates
    ///     whether or not the animations actually finished before the completion handler was called.
    ///     If `animated` is `false`,  this closure is performed at the beginning of the next run loop cycle. This parameter may be `nil`.
    /// - Throws: `DiskPlacementError` if the `disk` cannot be placed at (`x`, `y`).
    func placeDisk(_ disk: Disk,
                   atX x: Int, y: Int,
                   animated isAnimated: Bool,
                   completion: @escaping (Bool) -> Void) throws {
        let diskCoordinates = viewModel.flippedDiskCoordinatesByPlacingDisk(disk, atX: x, y: y)
        if diskCoordinates.isEmpty {
            throw DiskPlacementError(disk: disk, x: x, y: y)
        }

        let finally: (ReversiViewModel, Bool) -> Void = { viewModel, finished in
            completion(finished)
            try? viewModel.saveGame()
            viewModel.updateCount()
        }

        if isAnimated {
            let cleanUp: () -> Void = { [weak self] in
                self?.viewModel.animationCanceller = nil
            }
            viewModel.animationCanceller = Canceller(cleanUp)
            animateSettingDisks(at: [(x, y)] + diskCoordinates, to: disk) { [weak self] finished in
                guard let viewModel = self?.viewModel else { return }
                guard let canceller = viewModel.animationCanceller else { return }
                if canceller.isCancelled { return }
                cleanUp()

                finally(viewModel, finished)
            }
        } else {
            DispatchQueue.main.async { [weak self] in
                guard let viewModel = self?.viewModel else { return }
                viewModel.setDisk(disk, atX: x, y: y, animated: false)
                for (x, y) in diskCoordinates {
                    viewModel.setDisk(disk, atX: x, y: y, animated: false)
                }

                finally(viewModel, true)
            }
        }
    }
    
    private func animateSettingDisks<C: Collection>(at coordinates: C, to disk: Disk, completion: @escaping (Bool) -> Void)
        where C.Element == (Int, Int)
    {
        guard let (x, y) = coordinates.first else {
            completion(true)
            return
        }

        let animationCanceller = viewModel.animationCanceller!
        viewModel.setDisk(disk, atX: x, y: y, animated: true) { [weak self] finished in
            guard let self = self else { return }
            if animationCanceller.isCancelled { return }
            if finished {
                self.animateSettingDisks(at: coordinates.dropFirst(), to: disk, completion: completion)
            } else {
                for (x, y) in coordinates {
                    self.viewModel.setDisk(disk, atX: x, y: y, animated: false)
                }
                completion(false)
            }
        }
    }
}

// MARK: Inputs

extension ViewController {
    @IBAction func pressResetButton(_ sender: UIButton) {
        let alertController = UIAlertController(
            title: "Confirmation",
            message: "Do you really want to reset the game?",
            preferredStyle: .alert
        )
        alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in })
        alertController.addAction(UIAlertAction(title: "OK", style: .default) { [weak self] _ in
            guard let self = self else { return }
            
            self.viewModel.animationCanceller?.cancel()
            self.viewModel.animationCanceller = nil
            
            for side in Disk.allCases {
                self.viewModel.playerCancellers[side]?.cancel()
                self.viewModel.playerCancellers.removeValue(forKey: side)
            }
            
            self.viewModel.newGame()
            self.viewModel.waitForPlayer()
        })
        present(alertController, animated: true)
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
        guard let turn = viewModel.turn else { return }
        if viewModel.isAnimating { return }
        guard case .manual = viewModel.playerOfCurrentTurn else { return }
        // try? because doing nothing when an error occurs
        try? placeDisk(turn, atX: x, y: y, animated: true) { [weak self] _ in
            self?.viewModel.nextTurn()
        }
    }
}

// MARK: Additional types

struct DiskPlacementError: Error {
    let disk: Disk
    let x: Int
    let y: Int
}
