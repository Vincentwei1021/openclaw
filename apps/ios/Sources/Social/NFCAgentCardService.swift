import CoreNFC
import Foundation

enum NFCAgentCardService {
    static var isSupported: Bool {
        NFCNDEFReaderSession.readingAvailable
    }

    static var availabilityText: String {
        self.isSupported ? "Supported" : "Unavailable on this iPhone/iPad"
    }
}
