public struct GameData: Equatable {
    public let status: Status
    public let playerDark: Player
    public let playerLight: Player
    public let cells: [[Cell]]

    public init(status: Status,
                playerDark: Player,
                playerLight: Player,
                cells: [[Cell]]) {
        self.status = status
        self.playerDark = playerDark
        self.playerLight = playerLight
        self.cells = cells
    }
}

extension GameData {
    public enum Status: Equatable {
        case gameOver
        case turn(Disk)
    }

    public enum Player: Int {
        case manual = 0
        case computer = 1
    }

    public struct Cell: Equatable {
        public let coordinate: Coordinate
        public var disk: Disk?

        public init(coordinate: Coordinate, disk: Disk?) {
            self.coordinate = coordinate
            self.disk = disk
        }
    }
}

extension GameData {

    public static let initial: GameData = {
        let range = (0..<8)
        let disk: [[Disk?]] = [
            range.map { _ in nil },
            range.map { _ in nil },
            range.map { _ in nil },
            [nil, nil, nil, .light, .dark, nil, nil, nil],
            [nil, nil, nil, .dark, .light, nil, nil, nil],
            range.map { _ in nil },
            range.map { _ in nil },
            range.map { _ in nil },
        ]

        let cells: [[Cell]] = disk.enumerated().map { y, rows in
            rows.enumerated().map { x, disk in
                Cell(coordinate: .init(x: x, y: y), disk: disk)
            }
        }

        return GameData(status: .turn(.dark),
                        playerDark: .manual,
                        playerLight: .manual,
                        cells: cells)
    }()
}
