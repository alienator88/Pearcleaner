//
//  UpdateQueue.swift
//  Pearcleaner
//
//  Manages concurrent Sparkle update operations with proper queuing to prevent conflicts.
//  Limits concurrent operations to prevent Sparkle framework internal lock contention.
//

import Foundation

class UpdateQueue {
    static let shared = UpdateQueue()

    private let queue: OperationQueue

    private init() {
        queue = OperationQueue()
        queue.maxConcurrentOperationCount = 3  // Limit concurrent Sparkle updates
        queue.qualityOfService = .userInitiated
    }

    /// Add a Sparkle update operation to the queue
    func addOperation(_ operation: Operation) {
        queue.addOperation(operation)
    }

    /// Cancel all pending operations
    func cancelAll() {
        queue.cancelAllOperations()
    }

    /// Check if an operation for a specific app is already queued or running
    func containsOperation(for bundleIdentifier: String) -> Bool {
        queue.operations.contains { operation in
            guard let sparkleOp = operation as? SparkleUpdateOperation else { return false }
            return sparkleOp.bundleIdentifier == bundleIdentifier
        }
    }
}
