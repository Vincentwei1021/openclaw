import Foundation
import OpenClawKit
import Testing

@Suite struct ShareDraftBuilderTests {
    @Test func buildIncludesStructuredFieldsInstructionAndAttachmentCount() {
        let payload = SharedContentPayload(
            title: "Trip Plan",
            url: URL(string: "https://example.com/plan")!,
            text: "Find flights and a 3-day itinerary.")

        let draft = ShareDraftBuilder.build(
            from: payload,
            options: ShareDraftOptions(
                instruction: "Summarize and provide next steps.",
                imageAttachmentCount: 2,
                maxCharacters: 2400))

        #expect(draft.contains("Shared from iOS."))
        #expect(draft.contains("Title: Trip Plan"))
        #expect(draft.contains("URL: https://example.com/plan"))
        #expect(draft.contains("Text:\nFind flights and a 3-day itinerary."))
        #expect(draft.contains("Attached image(s): 2"))
        #expect(draft.contains("Summarize and provide next steps."))
    }

    @Test func buildDropsBoilerplateAndDuplicateURLInText() {
        let payload = SharedContentPayload(
            title: nil,
            url: URL(string: "https://example.com/post")!,
            text: """
                Shared from iOS.
                URL: https://example.com/post
                https://example.com/post

                Keep only this line.
                """)

        let draft = ShareDraftBuilder.build(
            from: payload,
            options: ShareDraftOptions(instruction: "Review this."))

        #expect(draft.contains("URL: https://example.com/post"))
        #expect(draft.contains("Text:\nKeep only this line."))
        #expect(!draft.contains("Text:\nShared from iOS."))
        #expect(!draft.contains("Text:\nURL: https://example.com/post"))
    }

    @Test func buildAppliesCharacterLimit() {
        let repeated = String(repeating: "long-text-", count: 400)
        let payload = SharedContentPayload(title: "Big", url: nil, text: repeated)
        let draft = ShareDraftBuilder.build(
            from: payload,
            options: ShareDraftOptions(instruction: "Keep it short.", maxCharacters: 300))

        #expect(draft.count == 300)
    }
}
