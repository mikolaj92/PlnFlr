import StoreKit
import StoreKitTest
import XCTest
@testable import PlnFlrCapture

@MainActor
final class StoreKitLocalTests: XCTestCase {
    func testPurchaseRestoreAndRefund() async throws {
        let session = try SKTestSession(configurationFileNamed: "PlnFlr")
        session.resetToDefaultState()
        session.clearTransactions()
        session.disableDialogs = true
        defer { session.clearTransactions() }
        let client = PurchaseClient.live
        let before = await client.currentAccess()
        XCTAssertFalse(before)
        let product = try await client.product()
        XCTAssertNotNil(product)
        let outcome = try await client.purchase()
        XCTAssertEqual(outcome, .purchased)
        let access = await client.currentAccess()
        XCTAssertTrue(access)
        let restored = try await client.restore()
        XCTAssertTrue(restored)
        let transaction = try XCTUnwrap(session.allTransactions().first)
        try session.refundTransaction(identifier: transaction.identifier)
        // StoreKit publishes the revocation asynchronously.
        var revoked = false
        for _ in 0..<50 {
            if !(await client.currentAccess()) { revoked = true; break }
            try await Task.sleep(for: .milliseconds(100))
        }
        XCTAssertTrue(revoked)
    }
}
