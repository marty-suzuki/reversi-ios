import XCTest
@testable import ReversiLogic

final class DiskAtCoordinateTests: XCTestCase {

    func test() {
        let cell1 = GameData.Cell(coordinate: .init(x: 0, y: 0), disk: .light)
        let cell2 = GameData.Cell(coordinate: .init(x: 1, y: 0), disk: .dark)
        let cells = [[cell1, cell2]]

        XCTAssertEqual(cells[cell1.coordinate], cell1.disk)
        XCTAssertEqual(cells[cell2.coordinate], cell2.disk)
    }
}
