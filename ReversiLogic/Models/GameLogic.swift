public protocol GameLogicFactoryProtocol {
    static func make(cache: GameDataCellGettable & GemeDataDiskGettable) -> GameLogicProtocol
}

public enum GameLogicFactory: GameLogicFactoryProtocol {

    public static func make(cache: GameDataCellGettable & GemeDataDiskGettable) -> GameLogicProtocol {
        GameLogic(cache: cache)
    }
}

public protocol GameLogicProtocol: AnyObject {
    func count(of disk: Disk) -> Int
    func sideWithMoreDisks() -> Disk?
    func flippedDiskCoordinates(by disk: Disk,
                                at coordinate: Coordinate) -> [Coordinate]
    func canPlace(disk: Disk, at coordinate: Coordinate) -> Bool
    func validMoves(for disk: Disk) -> [Coordinate]
}

final class GameLogic: GameLogicProtocol {

    private let cache: GameDataCellGettable & GemeDataDiskGettable

    init(cache: GameDataCellGettable & GemeDataDiskGettable) {
        self.cache = cache
    }

    func count(of disk: Disk) -> Int {
        cache.cells.reduce(0) { result, rows in
            rows.reduce(result) { result, cell in
                if cell.disk == disk {
                    return result + 1
                } else {
                    return result
                }
            }
        }
    }

    func sideWithMoreDisks() -> Disk? {
        let darkCount = count(of: .dark)
        let lightCount = count(of: .light)
        if darkCount == lightCount {
            return nil
        } else {
            return darkCount > lightCount ? .dark : .light
        }
    }

    func flippedDiskCoordinates(by disk: Disk,
                                at coordinate: Coordinate) -> [Coordinate] {
        let directions = [
            (x: -1, y: -1),
            (x:  0, y: -1),
            (x:  1, y: -1),
            (x:  1, y:  0),
            (x:  1, y:  1),
            (x:  0, y:  1),
            (x: -1, y:  0),
            (x: -1, y:  1),
        ]

        guard cache.cells[safe: coordinate.y]?[safe: coordinate.x]?.disk == nil else {
            return []
        }

        var diskCoordinates: [Coordinate] = []

        for direction in directions {
            var x = coordinate.x
            var y = coordinate.y

            var diskCoordinatesInLine: [Coordinate] = []
            flipping: while true {
                x += direction.x
                y += direction.y

                switch (disk, cache.cells[safe: y]?[safe: x]?.disk) { // Uses tuples to make patterns exhaustive
                case (.dark, .dark?), (.light, .light?):
                    diskCoordinates.append(contentsOf: diskCoordinatesInLine)
                    break flipping
                case (.dark, .light?), (.light, .dark?):
                    diskCoordinatesInLine.append(Coordinate(x: x, y: y))
                case (_, .none):
                    break flipping
                }
            }
        }

        return diskCoordinates
    }

    func canPlace(disk: Disk, at coordinate: Coordinate) -> Bool {
        !flippedDiskCoordinates(by: disk, at: coordinate).isEmpty
    }

    func validMoves(for disk: Disk) -> [Coordinate] {
        cache.cells.reduce([Coordinate]()) { result, rows in
            rows.reduce(result) { result, cell in
                let coordinate = Coordinate(x: cell.x, y: cell.y)
                if canPlace(disk: disk, at: coordinate) {
                    return result + [coordinate]
                } else {
                    return result
                }
            }
        }
    }
}
