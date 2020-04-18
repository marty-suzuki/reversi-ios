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

extension Alert {

    static func reset(okHandler: @escaping () -> Void) -> Alert {
        let cancel = Alert.Action(title: "Cancel", style: .cancel, handler: {})
        let ok = Alert.Action(title: "OK", style: .default, handler: okHandler)
        let alert = Alert(
            title: "Confirmation",
            message: "Do you really want to reset the game?",
            actions: [cancel, ok]
        )
        return alert
    }

    static func pass(dismissHandler: @escaping () -> Void) -> Alert {
        let action = Alert.Action(title: "Dismiss", style: .default, handler: dismissHandler)
        let alert = Alert(
            title: "Pass",
            message: "Cannot place a disk.",
            actions: [action]
        )
        return alert
    }
}
