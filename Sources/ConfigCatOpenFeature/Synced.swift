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
            lock.withLock {
                return storedValue
            }
        }
        set {
            lock.withLock {
                storedValue = newValue
            }
        }
    }

    @discardableResult
    mutating func testAndSet(expect: Value, new: Value) -> Bool {
        lock.withLock {
            let challenge = storedValue == expect
            storedValue = challenge ? new : storedValue
            return challenge
        }
    }

    mutating func getAndSet(new: Value) -> Value {
        lock.withLock {
            let old = storedValue
            storedValue = new
            return old
        }
    }
}

final class UnfairLock {
    private var lock: UnsafeMutablePointer<os_unfair_lock>

    init() {
        lock = UnsafeMutablePointer<os_unfair_lock>.allocate(capacity: 1)
        lock.initialize(to: os_unfair_lock())
    }

    deinit {
        lock.deallocate()
    }

    func withLock<T>(_ code: () -> T) -> T {
        os_unfair_lock_lock(lock)
        defer { os_unfair_lock_unlock(lock) }
        return code()
    }
}
