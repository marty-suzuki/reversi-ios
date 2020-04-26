import RxRelay
import RxSwift
@testable import ReversiLogic

struct MockValidMovesFactory: ValidMovesFactoryProtocol {

    let validMoves: MockValidMoves

    func make(flippedDiskCoordinates: FlippedDiskCoordinatesProtocol,
              store: GameStoreProtocol) -> ValidMovesProtocol {
        return validMoves
    }
}

struct MockValidMoves: ValidMovesProtocol {

    @MockResponse<Disk, [Coordinate]>
    var _callAsFunction: [Coordinate] = []

    func callAsFunction(for disk: Disk) -> [Coordinate] {
        return __callAsFunction.respond(disk)
    }
}
