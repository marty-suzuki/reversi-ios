public struct UpdateDisk {
    public let disk: Disk?
    public let coordinate: Coordinate
    public let animated: Bool
    public let completion: ((Bool) -> Void)?
}
