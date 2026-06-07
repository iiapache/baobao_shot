import BabyCameraNetwork
import XCTest
@testable import BabyCameraCredit

final class PendingIAPReceiptStoreTests: XCTestCase {
    func testSaveLoadAndRemove() {
        let defaults = UserDefaults(suiteName: "PendingIAPReceiptStoreTests")!
        defaults.removePersistentDomain(forName: "PendingIAPReceiptStoreTests")
        let store = PendingIAPReceiptStore(defaults: defaults, key: "pending")

        let tx = IAPVerifiedTransaction.fixture(transactionID: "tx_1")
        store.save(tx)
        XCTAssertEqual(store.loadAll().count, 1)
        XCTAssertEqual(store.loadAll().first?.transactionID, "tx_1")

        store.remove(transactionID: "tx_1")
        XCTAssertTrue(store.loadAll().isEmpty)
    }

    func testSaveUpdatesExistingTransaction() {
        let defaults = UserDefaults(suiteName: "PendingIAPReceiptStoreTests.update")!
        defaults.removePersistentDomain(forName: "PendingIAPReceiptStoreTests.update")
        let store = PendingIAPReceiptStore(defaults: defaults, key: "pending")

        store.save(.fixture(transactionID: "tx_1", signedTransaction: "old"))
        store.save(.fixture(transactionID: "tx_1", signedTransaction: "new"))

        XCTAssertEqual(store.loadAll().count, 1)
        XCTAssertEqual(store.loadAll().first?.signedTransaction, "new")
    }
}
