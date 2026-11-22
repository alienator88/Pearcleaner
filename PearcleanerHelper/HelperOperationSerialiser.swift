import Foundation

/// Keeps privileged mutations strictly ordered even when several XPC clients
/// submit requests at once. Deliberately separate from the listener so its
/// serialization guarantee can be exercised without a root service.
final class HelperOperationSerialiser {
    private let queue = DispatchQueue(label: "com.alienator88.Pearcleaner.helper.operations")

    func execute(_ operation: @escaping @Sendable () -> Void) {
        queue.async(execute: operation)
    }
}