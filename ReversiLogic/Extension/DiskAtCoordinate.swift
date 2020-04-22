public protocol DiskAtCoordinate {
    subscript(coordinate: Coordinate) -> Disk? { get }
}

extension DiskAtCoordinate where Self: Collection, Element: Collection, Index == Element.Index, Element.Element == GameData.Cell, Index == Int {
    public subscript(coordinate: Coordinate) -> Disk? {
        guard let cell = self[safe: coordinate.y]?[safe: coordinate.x],
            cell.coordinate == coordinate
        else {
            return nil
        }
        return cell.disk
    }
}

extension Array: DiskAtCoordinate where Element == [GameData.Cell] {}
