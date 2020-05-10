import RxSwift

public protocol AlertManagementProtocol {
    func callAsFunction<A: Acceptable>(
        nextTurnResponse: Observable<NextTurn.Response>,
        prepareForReset: Observable<Void>,
        nextTurn: A,
        reset: A,
        waitForPlayer: A
    ) -> Observable<Alert> where A.Element == Void
}

struct AlertManagement: AlertManagementProtocol {
    let store: GameStoreProtocol
    let actionCreator: GameActionCreatorProtocol

    func callAsFunction<A: Acceptable>(
        nextTurnResponse: Observable<NextTurn.Response>,
        prepareForReset: Observable<Void>,
        nextTurn: A,
        reset: A,
        waitForPlayer: A
    ) -> Observable<Alert> where A.Element == Void {
        let noValidMovesAlert: Observable<Alert> = nextTurnResponse
            .flatMap { result -> Observable<Alert> in
                guard case .noValidMoves = result else {
                    return .empty()
                }
                let alert = Alert.pass {
                    nextTurn.accept(())
                }
                return .just(alert)
            }

        let resetAlert: Observable<Alert> = prepareForReset
            .map { [store, actionCreator] _ -> Alert in
                Alert.reset {
                    store.placeDiskCanceller.value?.cancel()
                    actionCreator.setPlaceDiskCanceller(nil)

                    for side in Disk.allCases {
                        store.playerCancellers.value[side]?.cancel()
                        actionCreator.setPlayerCanceller(nil, for: side)
                    }

                    reset.accept(())
                    waitForPlayer.accept(())
                }
            }

        return Observable.merge(noValidMovesAlert, resetAlert)
    }
}
