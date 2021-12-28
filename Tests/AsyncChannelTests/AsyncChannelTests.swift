@testable import AsyncChannel
import XCTest

struct Err: Error {}

final class AsyncChannelTests: XCTestCase {
    func testSend() async throws {
        let channel = AsyncChannel<Int>()
        
        Task.detached {
            try await Task.sleep(nanoseconds: 1 * NSEC_PER_SEC)
            channel.send(42)
        }
        
        let value = try await channel.value
        XCTAssertEqual(value, 42)
    }
    
    func testMultipleAwaits() async throws {
        let channel = AsyncChannel<Int>()
        
        Task.detached {
            try await Task.sleep(nanoseconds: 1 * NSEC_PER_SEC)
            channel.send(42)
        }
        
        let result = await withTaskGroup(of: Int.self, returning: [Int].self) { group in
            for i in 1...10 {
                group.addTask {
                    let value = try? await channel.value
                    XCTAssertEqual(value, 42)
                    return i
                }
            }
            return await group.reduce(into: [], { $0.append($1) })
        }
        XCTAssertEqual(result.count, 10)
    }
    
    func testCanelChannel() async throws {
        let channel = AsyncChannel<Int>()
        
        Task.detached {
            try await Task.sleep(nanoseconds: 1 * NSEC_PER_SEC)
            channel.cancel()
        }
        
        let result = await withTaskGroup(of: Int.self, returning: [Int].self) { group in
            for i in 1...10 {
                group.addTask {
                    let value = try? await channel.value
                    XCTAssertEqual(value, nil)
                    return i
                }
            }
            return await group.reduce(into: [], { $0.append($1) })
        }
        XCTAssertEqual(result.count, 10)
    }
    
    func testCanelAwait() async throws {
        let channel = AsyncChannel<Int>()
        
        Task.detached {
            try await Task.sleep(nanoseconds: 2 * NSEC_PER_SEC)
            channel.send(42)
        }
        
        let immediateCancel = Task<Int?, Never> {
            let value = try? await channel.value
            return value
        }
        immediateCancel.cancel()
        let noValue = await immediateCancel.value
        XCTAssertEqual(noValue, nil)
        
        let delayedCancel = Task<Int?, Never> {
            let value = try? await channel.value
            return value
        }
        Task {
            try await Task.sleep(nanoseconds: 1 * NSEC_PER_SEC)
            delayedCancel.cancel()
        }
        let noDelayedValue = await delayedCancel.value
        XCTAssertEqual(noDelayedValue, nil)
        
        let finish = Task<Int?, Never> {
            let value = try? await channel.value
            return value
        }
        let value = await finish.value
        XCTAssertEqual(value, 42)
    }
    
    func testMap() async throws {
        let channel = AsyncChannel<Int>()
        
        Task.detached {
            try await Task.sleep(nanoseconds: 1 * NSEC_PER_SEC)
            channel.send(42)
        }
        
        let value = try await channel
            .map(String.init)
            .value
        XCTAssertEqual(value, "42")
    }
    
}
