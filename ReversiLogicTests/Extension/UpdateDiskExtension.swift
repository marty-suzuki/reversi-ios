@testable import ReversiLogic

extension UpdateDisk: Equatable {
    public static func == (lhs: UpdateDisk, rhs: UpdateDisk) -> Bool {
        return lhs.disk == rhs.disk
            && lhs.coordinate == rhs.coordinate
            && lhs.animated == rhs.animated
    }
}
