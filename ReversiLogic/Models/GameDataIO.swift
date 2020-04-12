import Foundation

public enum GameDataIO {
    public static func save(
        data: GameData,
        writeToFile: (String, String) throws -> Void
    ) throws {
        var output: String = ""
        let turn: Disk?
        switch data.status {
        case .gameOver:
            turn = nil
        case let .turn(disk):
            turn = disk
        }
        output += turn.symbol
        output += data.playerDark.rawValue.description
        output += data.playerLight.rawValue.description
        output += "\n"

        data.board.cells.forEach { rows in
            rows.forEach { cell in
                output += cell.disk.symbol
            }
            output += "\n"
        }

        do {
            try writeToFile(output, path)
        } catch let error {
            throw FileIOError.read(path: path, cause: error)
        }
    }

    public static func loadGame(
        contentsOfFile: (String) throws -> String,
        completion: (GameData) -> Void
    ) throws {
        let input = try contentsOfFile(path)
        var lines: ArraySlice<Substring> = input.split(separator: "\n")[...]

        guard var line = lines.popFirst() else {
            throw FileIOError.read(path: path, cause: nil)
        }

        let turn: Disk?
        do { // turn
            guard
                let diskSymbol = line.popFirst(),
                let disk = Optional<Disk>(symbol: diskSymbol.description)
            else {
                throw FileIOError.read(path: path, cause: nil)
            }
            turn = disk
        }

        // players
        let getPlayer: () throws -> GameData.Player = {
            guard
                let playerSymbol = line.popFirst(),
                let playerNumber = Int(playerSymbol.description),
                let player = GameData.Player(rawValue: playerNumber)
            else {
                throw FileIOError.read(path: path, cause: nil)
            }
            return player
        }
        let playerDark = try getPlayer()
        let playerLight = try getPlayer()


        var cells = GameData.Board.initial().cells
        do { // board
            guard lines.count == cells.count else {
                throw FileIOError.read(path: path, cause: nil)
            }

            var y = 0
            while let line = lines.popFirst() {
                var x = 0
                for character in line {
                    let disk = Disk?(symbol: "\(character)").flatMap { $0 }
                    cells[y][x].disk = disk
                    x += 1
                }
                guard x == cells[y].count else {
                    throw FileIOError.read(path: path, cause: nil)
                }
                y += 1
            }
            guard y == cells.count else {
                throw FileIOError.read(path: path, cause: nil)
            }
        }

        let data = GameData(
            status: turn.map(GameData.Status.turn) ?? .gameOver,
            playerDark: playerDark,
            playerLight: playerLight,
            board: .init(cells: cells)
        )
        completion(data)
    }
}

extension GameDataIO {
    private static let path = (NSSearchPathForDirectoriesInDomains(.libraryDirectory, .userDomainMask, true).first! as NSString).appendingPathComponent("Game")

    public enum FileIOError: Error {
        case write(path: String, cause: Error?)
        case read(path: String, cause: Error?)
    }
}

extension Optional where Wrapped == Disk {
    fileprivate init?<S: StringProtocol>(symbol: S) {
        switch symbol {
        case "x":
            self = .some(.dark)
        case "o":
            self = .some(.light)
        case "-":
            self = .none
        default:
            return nil
        }
    }

    fileprivate var symbol: String {
        switch self {
        case .some(.dark):
            return "x"
        case .some(.light):
            return "o"
        case .none:
            return "-"
        }
    }
}
