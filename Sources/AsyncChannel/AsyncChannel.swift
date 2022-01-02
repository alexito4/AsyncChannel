import Foundation

public final class AsyncChannel<T> {
    private let buffer = Buffer()

    public init() {}

    /// Get the value asyncronously.
    /// This returns the value immediatly if already available,
    /// or will await until it's received.
    public var value: T {
        get async throws {
            let id = UUID()
            return try await withTaskCancellationHandler(operation: {
                try Task.checkCancellation()
                return try await withCheckedThrowingContinuation { continuation in
                    guard !Task.isCancelled else { return }
                    Task {
                        await buffer.addContinuationIfNeeded(continuation, id)
                    }
                }
            }, onCancel: {
                Task {
                    await buffer.cancelContinuation(id)
                }
            })
        }
    }

    /// Provide a value.
    /// This will send the value to every method that is awaiting to get it.
    /// It will also cache it internally so any subsequent `get` receives it immediatly.
    /// - Note: Only 1 value should be provided.
    public func send(_ v: T) {
        Task {
            await buffer.send(v)
        }
    }

    /// Removes every awaiting method and stops sending any values.
    public func cancel() {
        Task {
            await buffer.cancel()
        }
    }
}

// MARK: Internal Buffer

extension AsyncChannel {
    actor Buffer {
        enum State {
            case pending
            case fulfilled(T)
            case cancelled

            var isPending: Bool {
                if case .pending = self {
                    return true
                }
                return false
            }

            var isCancelled: Bool {
                if case .cancelled = self {
                    return true
                }
                return false
            }

            var value: T? {
                if case let .fulfilled(value) = self {
                    return value
                }
                return nil
            }
        }

        private var continuations = [UUID: CheckedContinuation<T, Error>]()
        private var state: State = .pending

        func addContinuationIfNeeded(_ continuation: CheckedContinuation<T, Error>, _ id: UUID) {
            assert(!state.isCancelled)

            if let value = state.value {
                continuation.resume(returning: value)
                return
            }

            continuations[id] = continuation
        }

        func cancelContinuation(_ id: UUID) {
            continuations[id]?.resume(throwing: CancellationError())
            continuations[id] = nil
        }

        func send(_ v: T) {
            guard !state.isCancelled else { return }
            assert(state.isPending, "AsyncChannel should only receive 1 value.")
//            print("send", v)

            state = .fulfilled(v)
            continuations.values.forEach { $0.resume(returning: v) }
            continuations.removeAll()
        }

        func cancel() {
            state = .cancelled
            continuations.values.forEach { continuation in
                continuation.resume(throwing: CancellationError())
            }
            continuations.removeAll()
        }
    }
}

// MARK: Extra functionality

extension AsyncChannel {
    func map<R>(_ f: @escaping (T) -> R) -> AsyncChannel<R> {
        let newChannel = AsyncChannel<R>()
        Task {
            let original = try await self.value
            newChannel.send(f(original))
        }
        return newChannel
    }
}
