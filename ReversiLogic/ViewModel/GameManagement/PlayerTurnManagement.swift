import RxSwift

public protocol PlayerTurnManagementProtocol {
    func callAsFunction<A1: Acceptable, A2: Acceptable>(
        waitForPlayer: Observable<Void>,
        setPlayerForDiskWithIndex: Observable<(Disk, Int)>,
        handleSelectedCoordinate: Observable<Coordinate>,
        save: A1,
        willTurnDiskOfComputer: A2,
        didTurnDiskOfComputer: A2
    ) -> Observable<(Disk, Coordinate)> where A1.Element == Void, A2.Element == Disk
}

struct PlayerTurnManagement: PlayerTurnManagementProtocol {

    let store: GameStoreProtocol
    let actionCreator: GameActionCreatorProtocol
    let validMoves: ValidMovesProtocol
    let mainScheduler: SchedulerType

    func callAsFunction<A1: Acceptable, A2: Acceptable>(
        waitForPlayer: Observable<Void>,
        setPlayerForDiskWithIndex: Observable<(Disk, Int)>,
        handleSelectedCoordinate: Observable<Coordinate>,
        save: A1,
        willTurnDiskOfComputer: A2,
        didTurnDiskOfComputer: A2
    ) -> Observable<(Disk, Coordinate)> where A1.Element == Void, A2.Element == Disk {
        let playTurnOfComputerTrigger1: Observable<Void> = waitForPlayer
            .withLatestFrom(store.status)
            .withLatestFrom(store.playerDark) { ($0, $1) }
            .withLatestFrom(store.playerLight) { ($0.0, $0.1, $1) }
            .flatMap { status, playerDark, playerLight -> Observable<Void> in
                let player: GameData.Player
                switch status {
                case .gameOver:
                    return .empty()
                case .turn(.dark):
                    player = playerDark
                case .turn(.light):
                    player = playerLight
                }

                switch player {
                case .manual:
                    return .empty()
                case .computer:
                    return .just(())
                }
            }

        let playTurnOfComputerTrigger2: Observable<Void> = { [actionCreator, store] in
            let sideEffectBeforeIsDiskPlacingCheck: (Disk, Int) -> Void = { disk, index in
                switch disk {
                case .dark:
                    actionCreator.setPlayerOfDark(GameData.Player(rawValue: index) ?? .manual)
                case .light:
                    actionCreator.setPlayerOfLight(GameData.Player(rawValue: index) ?? .manual)
                }

                save.accept(())

                if let canceller = store.playerCancellers.value[disk] {
                    canceller.cancel()
                }
            }

            let passIsDiskPlacingCheck: Observable<Disk> = setPlayerForDiskWithIndex
                .do(onNext: sideEffectBeforeIsDiskPlacingCheck)
                .withLatestFrom(store.isDiskPlacing) { ($0.0, $1) }
                .flatMap { disk, isDiskPlacing -> Observable<Disk> in
                    if isDiskPlacing {
                        return .empty()
                    } else {
                        return .just(disk)
                    }
                }

            let passComputerCheck: Observable<Disk> = passIsDiskPlacingCheck
                .withLatestFrom(store.playerDark) { ($0, $1) }
                .withLatestFrom(store.playerLight) { ($0.0, $0.1, $1) }
                .flatMap { disk, playerDark, playerLight -> Observable<Disk> in
                    let player: GameData.Player
                    switch disk {
                    case .dark:
                        player = playerDark
                    case .light:
                        player = playerLight
                    }
                    guard player == .computer else {
                        return .empty()
                    }
                    return .just(disk)
                }

            return passComputerCheck
                .withLatestFrom(store.status) { ($0, $1) }
                .flatMap { disk, status -> Observable<Void> in
                    guard case .turn(disk) = status else {
                        return .empty()
                    }
                    return .just(())
                }
        }()

        let computerPlaceDiskTrigger: Observable<(Disk, Coordinate)> = Observable.merge(
                playTurnOfComputerTrigger1,
                playTurnOfComputerTrigger2
            )
            .withLatestFrom(store.status)
            .flatMap { [validMoves] status -> Observable<(Disk, Coordinate)> in
                guard case let .turn(disk) = status else {
                    preconditionFailure()
                }
                return validMoves(for: disk)
                    .map { coordinates -> (Disk, Coordinate) in
                        guard let coordinate = coordinates.randomElement() else {
                            preconditionFailure()
                        }
                        return (disk, coordinate)
                    }
                    .asObservable()
            }
            .do(onNext: { disk, _ in
                willTurnDiskOfComputer.accept(disk)
            })
            .map { [actionCreator] disk, coordinate -> (Disk, Coordinate, Canceller) in
                let cleanUp: () -> Void = {
                    didTurnDiskOfComputer.accept(disk)
                    actionCreator.setPlayerCanceller(nil, for: disk)
                }
                return (disk, coordinate, Canceller(cleanUp))
            }
            .do(onNext: { [actionCreator] disk, _, canceller in
                actionCreator.setPlayerCanceller(canceller, for: disk)
            })
            .flatMap { [mainScheduler] disk, coordinate, canceller -> Maybe<(Disk, Coordinate)> in
                weak var canceller = canceller
                return Maybe.just(())
                    .delay(.seconds(2), scheduler: mainScheduler)
                    .flatMap { _ -> Maybe<(Disk, Coordinate)> in
                        guard let canceller = canceller, !canceller.isCancelled else {
                            return .empty()
                        }
                        return .just((disk, coordinate))
                    }
                    .do(onNext: { _ in
                        canceller?.cancel()
                    })
            }
            .asObservable()

        let manualPlaceDiskTrigger: Observable<(Disk, Coordinate)> = handleSelectedCoordinate
            .withLatestFrom(store.isDiskPlacing) { ($0, $1) }
            .flatMap { coordinate, isDiskPlacing -> Observable<Coordinate> in
                if isDiskPlacing {
                    return .empty()
                }
                return .just(coordinate)
            }
            .withLatestFrom(store.playerOfCurrentTurn) { ($0, $1) }
            .flatMap { coordinate, playerOfCurrentTurn -> Observable<Coordinate> in
                guard playerOfCurrentTurn == .manual else {
                    return .empty()
                }
                return .just(coordinate)
            }
            .withLatestFrom(store.status) { ($0, $1) }
            .flatMap { coordinate, status -> Observable<(Disk, Coordinate)> in
                guard case let .turn(turn) = status else {
                    return .empty()
                }
                return .just((turn, coordinate))
            }

        return Observable.merge(computerPlaceDiskTrigger, manualPlaceDiskTrigger)
    }
}
