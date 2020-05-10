import RxSwift

public protocol ValidMovesProtocol {
    func callAsFunction(for disk: Disk) -> Single<[Coordinate]>
}

struct ValidMoves: ValidMovesProtocol {

    let flippedDiskCoordinates: FlippedDiskCoordinatesProtocol
    let store: GameStoreProtocol

    func callAsFunction(for disk: Disk) -> Single<[Coordinate]> {
        store.cells
            .flatMap { [flippedDiskCoordinates] cells -> Observable<[Coordinate]> in
                let coordinates = cells.flatMap { rows in
                    rows.map { cell in
                        flippedDiskCoordinates(by: disk, at: cell.coordinate)
                            .map { coordinates -> Coordinate? in
                                if coordinates.isEmpty {
                                    return nil
                                } else {
                                    return cell.coordinate
                                }
                            }
                            .asObservable()
                    }
                }
                return Observable.zip(coordinates)
                    .map { $0.compactMap { $0 } }
            }
            .take(1)
            .asSingle()
    }
}
