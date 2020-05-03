import RxRelay
import RxSwift
@testable import ReversiLogic

struct MockValidMoves: ValidMovesProtocol {

    @MockResponse<Disk, [Coordinate]>
    var _callAsFunction: [Coordinate] = []

    func callAsFunction(for disk: Disk) -> [Coordinate] {
        return __callAsFunction.respond(disk)
    }
}
