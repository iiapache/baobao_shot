import BabyCameraNetwork
import Foundation

public extension AppAttestIAPAttachment {
    var networkAttachment: AppAttestNetworkAttachment {
        AppAttestNetworkAttachment(
            keyId: keyId,
            assertionBase64: assertionBase64,
            clientDataHashBase64: clientDataHashBase64
        )
    }
}

public enum AppAttestAttachmentProviders {
    /// App 层注入 IAP / 订阅校验的 App Attest 附加上下文。
    public static func makeDefault(
        forceStub: Bool = false,
        service: AppAttestProviding? = nil
    ) -> AppAttestAttachmentProvider {
        let resolved = service ?? AppAttestService(forceStub: forceStub)
        let builder = AppAttestIAPAttachmentBuilder(service: resolved)
        return { transactionId, productId in
            guard let attachment = await builder.attachment(
                transactionId: transactionId,
                productId: productId
            ) else {
                return nil
            }
            return attachment.networkAttachment
        }
    }
}
