import ComposableArchitecture2
import CustomDump
import Foundation
import Testing
@testable import PlnFlrCapture

@Test func pendingPurchaseDoesNotUnlockPro() async {
    let client = PurchaseClient(product: { .init(displayPrice: "49,99 zł") },
                                purchase: { .pending }, restore: { false }, currentAccess: { false },
                                updates: { AsyncStream { $0.finish() } })
    let store = await TestStoreActor(initialState: Workspace.State()) {
        Workspace().environment(\.purchases, client)
    }
    await store.send(.buyProButtonTapped) { $0.isPurchasing = true }
    await store.receive(\.purchaseFinished) {
        $0.isPurchasing = false
        $0.purchaseMessage = "Zakup oczekuje na zatwierdzenie przez Apple."
    }
}

@Test func verifiedPurchaseUnlocksAndClosesPaywall() async {
    var state = Workspace.State()
    state.isPaywallPresented = true
    let client = PurchaseClient(product: { nil }, purchase: { .purchased }, restore: { false }, currentAccess: { false },
                                updates: { AsyncStream { $0.finish() } })
    let store = await TestStoreActor(initialState: state) { Workspace().environment(\.purchases, client) }
    await store.send(.buyProButtonTapped) { $0.isPurchasing = true }
    await store.receive(\.purchaseFinished) {
        $0.isPurchasing = false
        $0.hasPro = true
        $0.isPaywallPresented = false
    }
}

@Test func cancelledPurchaseIsNotAnError() async {
    let client = PurchaseClient(product: { nil }, purchase: { .cancelled }, restore: { false }, currentAccess: { false },
                                updates: { AsyncStream { $0.finish() } })
    let store = await TestStoreActor(initialState: Workspace.State()) { Workspace().environment(\.purchases, client) }
    await store.send(.buyProButtonTapped) { $0.isPurchasing = true }
    await store.receive(\.purchaseFinished) { $0.isPurchasing = false }
}

@Test func restoreWithNoPurchaseDoesNotUnlock() async {
    let client = PurchaseClient(product: { nil }, purchase: { .cancelled }, restore: { false }, currentAccess: { false },
                                updates: { AsyncStream { $0.finish() } })
    let store = await TestStoreActor(initialState: Workspace.State()) { Workspace().environment(\.purchases, client) }
    await store.send(.restorePurchasesButtonTapped) { $0.isPurchasing = true }
    await store.receive(\.restoreFinished) {
        $0.isPurchasing = false
        $0.purchaseMessage = "Na tym koncie Apple nie znaleziono zakupu PlnFlr Pro."
    }
}

@Test func entitlementPolicyRejectsRevokedUnverifiedAndOtherProducts() {
    #expect(ProEntitlement.accepts(productID: ProEntitlement.productID, verified: true, revoked: false, upgraded: false))
    #expect(!ProEntitlement.accepts(productID: ProEntitlement.productID, verified: false, revoked: false, upgraded: false))
    #expect(!ProEntitlement.accepts(productID: ProEntitlement.productID, verified: true, revoked: true, upgraded: false))
    #expect(!ProEntitlement.accepts(productID: "other", verified: true, revoked: false, upgraded: false))
    #expect(!ProEntitlement.accepts(productID: ProEntitlement.productID, verified: true, revoked: false, upgraded: true))
}
