import ComposableArchitecture2
import Foundation
import StoreKit

public enum ProEntitlement {
    public static let productID = "it.patryk.plnflr.pro"

    static func accepts(productID: String, verified: Bool, revoked: Bool, upgraded: Bool) -> Bool {
        productID == Self.productID && verified && !revoked && !upgraded
    }
}

public struct ProProduct: Equatable, Sendable {
    public var displayPrice: String
}

public enum PurchaseOutcome: Equatable, Sendable {
    case purchased, pending, cancelled
}

struct PurchaseClient: Sendable {
    var product: @Sendable () async throws -> ProProduct?
    var purchase: @Sendable () async throws -> PurchaseOutcome
    var restore: @Sendable () async throws -> Bool
    var currentAccess: @Sendable () async -> Bool
    var updates: @Sendable () -> AsyncStream<Bool>

    static var live: Self {
        Self(
            product: {
                try await Product.products(for: [ProEntitlement.productID]).first.map { ProProduct(displayPrice: $0.displayPrice) }
            },
            purchase: {
                guard let product = try await Product.products(for: [ProEntitlement.productID]).first else {
                    throw PurchaseError.unavailable
                }
                switch try await product.purchase() {
                case .success(let result):
                    guard case .verified(let transaction) = result, isPro(transaction) else {
                        throw PurchaseError.unverified
                    }
                    await transaction.finish()
                    return .purchased
                case .pending: return .pending
                case .userCancelled: return .cancelled
                @unknown default: throw PurchaseError.unavailable
                }
            },
            restore: {
                try await AppStore.sync()
                return await hasPro()
            },
            currentAccess: { await hasPro() },
            updates: {
                AsyncStream { continuation in
                    let task = Task {
                        for await result in Transaction.updates {
                            if case .verified(let transaction) = result,
                               transaction.productID == ProEntitlement.productID {
                                continuation.yield(await hasPro())
                                await transaction.finish()
                            }
                        }
                        continuation.finish()
                    }
                    continuation.onTermination = { _ in task.cancel() }
                }
            }
        )
    }

    private static func hasPro() async -> Bool {
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result, isPro(transaction) { return true }
        }
        return false
    }

    private static func isPro(_ transaction: Transaction) -> Bool {
        ProEntitlement.accepts(productID: transaction.productID, verified: true,
                               revoked: transaction.revocationDate != nil, upgraded: transaction.isUpgraded)
    }
}

enum PurchaseError: LocalizedError {
    case unavailable, unverified
    var errorDescription: String? {
        switch self {
        case .unavailable: "Zakup jest niedostępny. Lokalnie uruchom aplikację ze schematu z konfiguracją PlnFlr.storekit."
        case .unverified: "Nie udało się zweryfikować zakupu w Apple. Spróbuj przywrócić zakupy."
        }
    }
}

extension FeatureEnvironmentValues {
    @FeatureEnvironmentEntry(liveValue: PurchaseClient.live)
    var purchases = PurchaseClient(product: { nil }, purchase: { throw PurchaseError.unavailable },
                                   restore: { false }, currentAccess: { false },
                                   updates: { AsyncStream { $0.finish() } })
}
