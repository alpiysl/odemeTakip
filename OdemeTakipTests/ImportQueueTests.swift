import Foundation
import Testing
@testable import OdemeTakip

struct ImportQueueTests {
    private let a = URL(filePath: "/tmp/a.pdf")
    private let b = URL(filePath: "/tmp/b.pdf")
    private let c = URL(filePath: "/tmp/c.pdf")

    @Test func idleQueueStartsRightAway() {
        var queue = ImportQueue()
        #expect(queue.request(a) == a)
        #expect(queue.isBusy)
    }

    @Test func busyQueueKeepsTheLatestAndStartsItWhenDone() {
        var queue = ImportQueue()
        _ = queue.request(a)
        #expect(queue.request(b) == nil)
        #expect(queue.request(c) == nil)
        #expect(queue.finished() == c)
        #expect(queue.isBusy)
        #expect(queue.finished() == nil)
        #expect(!queue.isBusy)
    }
}
