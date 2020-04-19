@propertyWrapper
final class CountableProperty<Element> {

    var wrappedValue: Element {
        get {
            projectedValue.getterCalledCount += 1
            return value
        }
        set {
            projectedValue.setterCalledCount += 1
            value = newValue
        }
    }

    let projectedValue = Counts()

    private var value: Element

    init(wrappedValue: Element) {
        self.value = wrappedValue
    }
}

extension CountableProperty {
    final class Counts {
        fileprivate(set) var getterCalledCount = 0
        fileprivate(set) var setterCalledCount = 0
    }
}
