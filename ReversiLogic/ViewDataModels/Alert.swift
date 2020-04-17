public struct Alert: Equatable {
    public let title: String
    public let message: String
    public let actions: [Action]
}

extension Alert {

    public struct Action {
        public let title: String
        public let style: Style
        public let handler: () -> Void
    }
}

extension Alert.Action: Equatable {

    public enum Style: Equatable {
        case `default`
        case cancel
    }

    public static func == (lhs: Alert.Action, rhs: Alert.Action) -> Bool {
        lhs.title == rhs.title && lhs.style == rhs.style
    }
}
