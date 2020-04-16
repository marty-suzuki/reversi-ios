enum GameLogic {

    static func count(of disk: Disk, from cells: [[GameData.Board.Cell]]) -> Int {
        cells.reduce(0) { result, rows in
            rows.reduce(result) { result, cell in
                if cell.disk == disk {
                    return result + 1
                } else {
                    return result
                }
            }
        }
    }

    static func sideWithMoreDisks(from cells: [[GameData.Board.Cell]]) -> Disk? {
        let darkCount = count(of: .dark, from: cells)
        let lightCount = count(of: .light, from: cells)
        if darkCount == lightCount {
            return nil
        } else {
            return darkCount > lightCount ? .dark : .light
        }
    }

    static func flippedDiskCoordinates(from cells: [[GameData.Board.Cell]],
                                       by disk: Disk,
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

        guard cells[safe: coordinate.y]?[safe: coordinate.x]?.disk == nil else {
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

                switch (disk, cells[safe: y]?[safe: x]?.disk) { // Uses tuples to make patterns exhaustive
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

    static func canPlace(disk: Disk,
                         from cells: [[GameData.Board.Cell]],
                         at coordinate: Coordinate) -> Bool {
        !flippedDiskCoordinates(from: cells, by: disk, at: coordinate).isEmpty
    }

    static func validMoves(for disk: Disk,
                           from cells: [[GameData.Board.Cell]]) -> [Coordinate] {
        cells.reduce([Coordinate]()) { result, rows in
            rows.reduce(result) { result, cell in
                let coordinate = Coordinate(x: cell.x, y: cell.y)
                if canPlace(disk: disk,  from: cells, at: coordinate) {
                    return result + [coordinate]
                } else {
                    return result
                }
            }
        }
    }
}
