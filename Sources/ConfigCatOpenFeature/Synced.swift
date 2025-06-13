import Foundation

@propertyWrapper
struct Synced<Value: Equatable> {
    private let lock = UnfairLock()
    private var storedValue: Value

    init(wrappedValue: Value) {
        storedValue = wrappedValue
    }

    var wrappedValue: Value {
        get {
            lock.lock()
            defer { lock.unlock() }
            return storedValue
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            storedValue = newValue
        }
    }

    @discardableResult
    mutating func testAndSet(expect: Value, new: Value) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        let challenge = storedValue == expect
        storedValue = challenge ? new : storedValue
        return challenge
    }

    mutating func getAndSet(new: Value) -> Value {
        lock.lock()
        defer { lock.unlock() }
        let old = storedValue
        storedValue = new
        return old
    }
}

final class UnfairLock {
    private var unfairLock: UnsafeMutablePointer<os_unfair_lock>

    init() {
        unfairLock = UnsafeMutablePointer<os_unfair_lock>.allocate(capacity: 1)
        unfairLock.initialize(to: os_unfair_lock())
    }

    func lock() {
        os_unfair_lock_lock(unfairLock)
    }

    func unlock() {
        os_unfair_lock_unlock(unfairLock)
    }

    deinit {
        unfairLock.deallocate()
    }
}
