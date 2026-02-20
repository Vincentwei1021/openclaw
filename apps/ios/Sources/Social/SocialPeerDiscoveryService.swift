import Foundation
import Network

@MainActor
final class SocialPeerDiscoveryService {
    struct DiscoveredPeer: Identifiable, Equatable, Sendable {
        var id: String { self.peerID }
        var peerID: String
        var displayName: String
        var bio: String
        var capabilities: [String]
        var endpointSummary: String
        var cardCode: String?
        var discoveredAt: Date
    }

    struct Snapshot: Equatable, Sendable {
        var peers: [DiscoveredPeer]
        var statusText: String
    }

    var onSnapshot: ((Snapshot) -> Void)?

    private let browserQueue = DispatchQueue(label: "ai.openclaw.ios.social.browser")
    private let listenerQueue = DispatchQueue(label: "ai.openclaw.ios.social.listener")
    private var browser: NWBrowser?
    private var listener: NWListener?
    private var localPeerID: String = ""
    private var peersByID: [String: DiscoveredPeer] = [:]
    private var browserState: NWBrowser.State?
    private var listenerState: NWListener.State?
    private static let serviceType = "_openclaw-peer._tcp"
    private(set) var latestSnapshot = Snapshot(peers: [], statusText: "Stopped")

    func start(profile: AgentProfile, cardCode: String?) {
        self.localPeerID = profile.id
        self.startAdvertising(profile: profile, cardCode: cardCode)
        self.startBrowsing()
    }

    func refresh(profile: AgentProfile, cardCode: String?) {
        guard self.browser != nil || self.listener != nil else { return }
        self.start(profile: profile, cardCode: cardCode)
    }

    func stop() {
        self.browser?.cancel()
        self.listener?.cancel()
        self.browser = nil
        self.listener = nil
        self.browserState = nil
        self.listenerState = nil
        self.peersByID = [:]
        self.emit(statusText: "Stopped")
    }

    private func startBrowsing() {
        self.browser?.cancel()

        let params = NWParameters.tcp
        params.includePeerToPeer = true
        let browser = NWBrowser(for: .bonjour(type: Self.serviceType, domain: nil), using: params)

        browser.stateUpdateHandler = { [weak self] state in
            Task { @MainActor in
                guard let self else { return }
                self.browserState = state
                self.emit()
            }
        }

        browser.browseResultsChangedHandler = { [weak self] results, _ in
            Task { @MainActor in
                self?.handleBrowseResults(results)
            }
        }

        self.browser = browser
        browser.start(queue: self.browserQueue)
    }

    private func startAdvertising(profile: AgentProfile, cardCode: String?) {
        self.listener?.cancel()

        let params = NWParameters.tcp
        params.includePeerToPeer = true

        do {
            let listener = try NWListener(using: params, on: .any)
            listener.newConnectionHandler = { connection in
                connection.cancel()
            }

            listener.service = NWListener.Service(
                name: self.sanitizedServiceName(profile.displayName),
                type: Self.serviceType,
                domain: nil,
                txtRecord: SocialPeerTXTRecordCodec.encodeTXTData(profile: profile, cardCode: cardCode))

            listener.stateUpdateHandler = { [weak self] state in
                Task { @MainActor in
                    guard let self else { return }
                    self.listenerState = state
                    self.emit()
                }
            }

            self.listener = listener
            listener.start(queue: self.listenerQueue)
        } catch {
            self.listener = nil
            self.listenerState = nil
            let browserStatus = Self.prettyBrowserState(self.browserState)
            self.emit(statusText: "Browse: \(browserStatus) / Advertise: failed (\(error.localizedDescription))")
        }
    }

    private func handleBrowseResults(_ results: Set<NWBrowser.Result>) {
        let previousByID = self.peersByID
        var nextByID: [String: DiscoveredPeer] = [:]

        for result in results {
            let endpointID = Self.endpointStableID(result.endpoint)
            guard !endpointID.isEmpty else { continue }

            let serviceName = Self.endpointServiceName(result.endpoint)
            let txt = result.endpoint.txtRecord?.dictionary ?? [:]
            let decoded = SocialPeerTXTRecordCodec.decode(dictionary: txt)

            let peerID = decoded?.peerID.trimmingCharacters(in: .whitespacesAndNewlines) ?? endpointID
            guard !peerID.isEmpty, peerID != self.localPeerID else { continue }

            let displayNameCandidate = decoded?.displayName ?? serviceName ?? endpointID
            let displayName = displayNameCandidate.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !displayName.isEmpty else { continue }

            let peer = DiscoveredPeer(
                peerID: peerID,
                displayName: displayName,
                bio: decoded?.bio ?? "",
                capabilities: decoded?.capabilities ?? [],
                endpointSummary: Self.endpointSummary(result.endpoint),
                cardCode: decoded?.cardCode,
                discoveredAt: previousByID[peerID]?.discoveredAt ?? Date())
            nextByID[peerID] = peer
        }

        self.peersByID = nextByID
        self.emit()
    }

    private func emit(statusText: String? = nil) {
        let peers = self.peersByID.values.sorted {
            if $0.displayName.caseInsensitiveCompare($1.displayName) == .orderedSame {
                return $0.peerID.caseInsensitiveCompare($1.peerID) == .orderedAscending
            }
            return $0.displayName.caseInsensitiveCompare($1.displayName) == .orderedAscending
        }

        let status = statusText ?? Self.makeStatusText(
            browserState: self.browserState,
            listenerState: self.listenerState,
            isRunning: self.browser != nil || self.listener != nil)

        let snapshot = Snapshot(peers: peers, statusText: status)
        self.latestSnapshot = snapshot
        self.onSnapshot?(snapshot)
    }

    private func sanitizedServiceName(_ value: String) -> String {
        let compact = value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
        if compact.isEmpty { return "OpenClaw Agent" }
        return String(compact.prefix(48))
    }

    private static func endpointServiceName(_ endpoint: NWEndpoint) -> String? {
        switch endpoint {
        case let .service(name, _, _, _):
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        default:
            return nil
        }
    }

    private static func endpointSummary(_ endpoint: NWEndpoint) -> String {
        switch endpoint {
        case let .service(name, type, domain, _):
            "\(name).\(type)\(domain)"
        default:
            String(describing: endpoint)
        }
    }

    private static func endpointStableID(_ endpoint: NWEndpoint) -> String {
        switch endpoint {
        case let .service(name, type, domain, _):
            let stable = "\(name)|\(type)|\(domain)"
            return stable.trimmingCharacters(in: .whitespacesAndNewlines)
        default:
            return String(describing: endpoint)
        }
    }

    private static func makeStatusText(
        browserState: NWBrowser.State?,
        listenerState: NWListener.State?,
        isRunning: Bool) -> String
    {
        guard isRunning else { return "Stopped" }
        let browser = Self.prettyBrowserState(browserState)
        let listener = Self.prettyListenerState(listenerState)
        return "Browse: \(browser) / Advertise: \(listener)"
    }

    private static func prettyBrowserState(_ state: NWBrowser.State?) -> String {
        guard let state else { return "idle" }
        switch state {
        case .setup:
            return "setup"
        case .ready:
            return "ready"
        case .cancelled:
            return "cancelled"
        case let .waiting(error):
            return "waiting (\(error.localizedDescription))"
        case let .failed(error):
            return "failed (\(error.localizedDescription))"
        @unknown default:
            return "unknown"
        }
    }

    private static func prettyListenerState(_ state: NWListener.State?) -> String {
        guard let state else { return "idle" }
        switch state {
        case .setup:
            return "setup"
        case .ready:
            return "ready"
        case .cancelled:
            return "cancelled"
        case let .waiting(error):
            return "waiting (\(error.localizedDescription))"
        case let .failed(error):
            return "failed (\(error.localizedDescription))"
        @unknown default:
            return "unknown"
        }
    }
}
