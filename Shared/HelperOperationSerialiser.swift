import Foundation

/// Keeps privileged mutations strictly ordered even when several call sites
/// submit requests at once. Deliberately separate from SessionPrivilegeManager
/// so its serialization guarantee can be exercised without elevation.
final class HelperOperationSerialiser {
    private let queue = DispatchQueue(label: "com.alienator88.Pearcleaner.helper.operations")

    func execute(_ operation: @escaping @Sendable () -> Void) {
        queue.async(execute: operation)
    }
}