@propertyWrapper
final class MockResponse<Parameter, Value> {
    var wrappedValue: Value {
        get { projectedValue.value }
        set { projectedValue.value = newValue }
    }

    let projectedValue: State

    init(wrappedValue: Value) {
        self.projectedValue = State(initial: wrappedValue)
    }

    func respond(_ parameter: Parameter) -> Value {
        projectedValue.calledCount += 1
        projectedValue.parameters += [parameter]
        return projectedValue.value
    }
}

extension MockResponse {

    final class State {
        fileprivate(set) var calledCount = 0
        fileprivate(set) var parameters: [Parameter] = []
        fileprivate(set) var value: Value

        init(initial: Value) {
            self.value = initial
        }
    }
}

extension MockResponse where Value == Void {

    convenience init() {
        self.init(wrappedValue: ())
    }
}

extension MockResponse where Parameter == Void {

    func respond() -> Value {
        self.respond(())
    }
}
