import Foundation
import ReversiLogic

public enum GameDataIO {
    public static func save(
        turn: Disk?,
        selectedSegumentIndexFor: (Int) -> Int,
        yRange: Range<Int>,
        xRange: Range<Int>,
        diskAt: (Int, Int) -> Disk?,
        writeToFile: (String, String) throws -> Void
    ) throws {
        var output: String = ""
        output += turn.symbol
        for side in Disk.sides {
            output += selectedSegumentIndexFor(side.index).description
        }
        output += "\n"

        for y in yRange {
            for x in xRange {
                output += diskAt(x, y).symbol
            }
            output += "\n"
        }

        do {
            try writeToFile(output, path)
        } catch let error {
            throw FileIOError.read(path: path, cause: error)
        }
    }

    public static func loadGame<T: RawRepresentable>(
        rawRepresentable _: T.Type,
        width: Int,
        height: Int,
        contentsOfFile: (String) throws -> String,
        setTurn: (Disk?) -> Void,
        setSelectedSegmentIndexFor: (Int, Int) -> Void,
        setDisk: (Disk?, Int, Int, Bool) -> Void,
        completion: () -> Void
    ) throws where T.RawValue == Int {
        let input = try contentsOfFile(path)
        var lines: ArraySlice<Substring> = input.split(separator: "\n")[...]

        guard var line = lines.popFirst() else {
            throw FileIOError.read(path: path, cause: nil)
        }

        do { // turn
            guard
                let diskSymbol = line.popFirst(),
                let disk = Optional<Disk>(symbol: diskSymbol.description)
            else {
                throw FileIOError.read(path: path, cause: nil)
            }
            setTurn(disk)
        }

        // players
        for side in Disk.sides {
            guard
                let playerSymbol = line.popFirst(),
                let playerNumber = Int(playerSymbol.description),
                let player = T(rawValue: playerNumber)
            else {
                throw FileIOError.read(path: path, cause: nil)
            }
            setSelectedSegmentIndexFor(side.index, player.rawValue)
        }

        do { // board
            guard lines.count == height else {
                throw FileIOError.read(path: path, cause: nil)
            }

            var y = 0
            while let line = lines.popFirst() {
                var x = 0
                for character in line {
                    let disk = Disk?(symbol: "\(character)").flatMap { $0 }
                    setDisk(disk, x, y, false)
                    x += 1
                }
                guard x == width else {
                    throw FileIOError.read(path: path, cause: nil)
                }
                y += 1
            }
            guard y == height else {
                throw FileIOError.read(path: path, cause: nil)
            }
        }

        completion()
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
