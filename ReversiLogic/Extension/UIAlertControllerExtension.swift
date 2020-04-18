import UIKit

extension UIAlertController {

    public static func make(alert: Alert) -> UIAlertController {
        let alertController = UIAlertController(
            title: alert.title,
            message: alert.message,
            preferredStyle: .alert
        )

        alert.actions.forEach { action in
            let style: UIAlertAction.Style
            switch action.style {
            case .default:
                style = .default
            case .cancel:
                style = .cancel
            }
            let alertAction = UIAlertAction(title: action.title, style: style) { _ in
                action.handler()
            }
            alertController.addAction(alertAction)
        }

        return alertController
    }
}
