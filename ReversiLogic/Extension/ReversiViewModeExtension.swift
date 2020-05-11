import RxSwift
import UIKit

extension ReversiViewModel.Input {
    public static func make() -> ReversiViewModel.Input {
        .init()
    }
}

extension ReversiViewModel.Output {
    public static func make(
        messageDisk: Observable<Disk>,
        messageDiskSizeConstant: Observable<CGFloat>,
        messageText: Observable<String>,
        showAlert: Observable<Alert>,
        isPlayerDarkAnimating: Observable<Bool>,
        isPlayerLightAnimating: Observable<Bool>,
        playerDarkCount: Observable<String>,
        playerLightCount: Observable<String>,
        playerDarkSelectedIndex: Observable<Int>,
        playerLightSelectedIndex: Observable<Int>,
        resetBoard: Observable<Void>,
        updateBoard: Observable<UpdateDisk>
    ) -> ReversiViewModel.Output {
        .init(messageDisk: messageDisk,
              messageDiskSizeConstant: messageDiskSizeConstant,
              messageText: messageText,
              showAlert: showAlert,
              isPlayerDarkAnimating: isPlayerDarkAnimating,
              isPlayerLightAnimating: isPlayerLightAnimating,
              playerDarkCount: playerDarkCount,
              playerLightCount: playerLightCount,
              playerDarkSelectedIndex: playerDarkSelectedIndex,
              playerLightSelectedIndex: playerLightSelectedIndex,
              resetBoard: resetBoard,
              updateBoard: updateBoard)
    }
}
