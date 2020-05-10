import RxRelay
import RxSwift
@testable import ReversiLogic

struct MockValidMoves: ValidMovesProtocol {

    @MockPublishResponse<Disk, [Coordinate]>
    var _callAsFunction: AnyObserver<[Coordinate]>

    func callAsFunction(for disk: Disk) -> Single<[Coordinate]> {
        return __callAsFunction.respond(disk).take(1).asSingle()
    }
}
