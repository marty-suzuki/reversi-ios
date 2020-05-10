import RxSwift

public protocol NextTurnManagementProtocol {
    func callAsFunction(nextTurn: Observable<Void>) -> Observable<NextTurn.Response>
}

public enum NextTurn {
    public enum Response {
        case gameOver
        case validMoves(GameData.Status)
        case noValidMoves(GameData.Status)
    }

    struct Management {
        let store: GameStoreProtocol
        let actionCreator: GameActionCreatorProtocol
        let validMoves: ValidMovesProtocol
    }
}

extension NextTurn.Management: NextTurnManagementProtocol {

    func callAsFunction(nextTurn: Observable<Void>) -> Observable<NextTurn.Response> {
        nextTurn
            .withLatestFrom(store.status)
            .flatMap { [validMoves] status -> Observable<NextTurn.Response> in
                var turn: Disk
                switch status {
                case let .turn(disk):
                    turn = disk
                case .gameOver:
                    return .empty()
                }

                turn.flip()

                return validMoves(for: turn)
                    .flatMap { coordinates -> Single<NextTurn.Response> in
                        if coordinates.isEmpty {
                            return validMoves(for: turn.flipped)
                                .flatMap { coordinates -> Single<NextTurn.Response> in
                                    if coordinates.isEmpty {
                                        return .just(.gameOver)
                                    } else {
                                        return .just(.noValidMoves(.turn(turn)))
                                    }
                                }
                        } else {
                            return .just(.validMoves(.turn(turn)))
                        }
                    }
                    .asObservable()
            }
            .do(onNext: { [actionCreator] result in
                switch result {
                case .gameOver:
                    actionCreator.setStatus(.gameOver)
                case let .validMoves(status),
                     let .noValidMoves(status):
                    actionCreator.setStatus(status)
                }
            })
    }
}
