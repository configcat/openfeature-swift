import ConfigCat

class SingleValueCache: ConfigCache {
    var value: String

    init(initValue: String) {
        value = initValue
    }

    public func read(for key: String) throws -> String {
        value
    }

    public func write(for key: String, value: String) throws {
        self.value = value
    }
}
