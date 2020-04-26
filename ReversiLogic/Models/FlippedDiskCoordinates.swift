protocol FlippedDiskCoordinatesProtocol {
    func callAsFunction(by disk: Disk, at coordinate: Coordinate, cells: [[GameData.Cell]]) -> [Coordinate]
}

struct FlippedDiskCoordinates: FlippedDiskCoordinatesProtocol {

    func callAsFunction(by disk: Disk, at coordinate: Coordinate, cells: [[GameData.Cell]]) -> [Coordinate] {
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

        guard cells[coordinate] == nil else {
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

                let coordinate = Coordinate(x: x, y: y)
                switch (disk, cells[coordinate]) { // Uses tuples to make patterns exhaustive
                case (.dark, .dark?), (.light, .light?):
                    diskCoordinates.append(contentsOf: diskCoordinatesInLine)
                    break flipping
                case (.dark, .light?), (.light, .dark?):
                    diskCoordinatesInLine.append(coordinate)
                case (_, .none):
                    break flipping
                }
            }
        }

        return diskCoordinates
    }
}
