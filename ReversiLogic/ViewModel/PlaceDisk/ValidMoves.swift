
public protocol ValidMovesFactoryProtocol {
    func make(flippedDiskCoordinates: FlippedDiskCoordinatesProtocol,
              store: GameStoreProtocol) -> ValidMovesProtocol
}

public struct ValidMovesFactory: ValidMovesFactoryProtocol {
    public func make(flippedDiskCoordinates: FlippedDiskCoordinatesProtocol,
                     store: GameStoreProtocol) -> ValidMovesProtocol {
        ValidMoves(flippedDiskCoordinates: flippedDiskCoordinates,
                   store: store)
    }
}

public protocol ValidMovesProtocol {
    func callAsFunction(for disk: Disk) -> [Coordinate]
}

struct ValidMoves: ValidMovesProtocol {

    let flippedDiskCoordinates: FlippedDiskCoordinatesProtocol
    let store: GameStoreProtocol

    func canPlace(disk: Disk, at coordinate: Coordinate) -> Bool {
        return !flippedDiskCoordinates(by: disk, at: coordinate)
            .isEmpty
    }

    func callAsFunction(for disk: Disk) -> [Coordinate] {
        store.cells.value.reduce([Coordinate]()) { result, rows in
            rows.reduce(result) { result, cell in
                if canPlace(disk: disk, at: cell.coordinate) {
                    return result + [cell.coordinate]
                } else {
                    return result
                }
            }
        }
    }
}
