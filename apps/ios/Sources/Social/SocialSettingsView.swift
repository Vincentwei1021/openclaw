import SwiftUI
import UIKit

struct SocialSettingsView: View {
    @AppStorage("node.displayName") private var nodeDisplayName: String = "iOS Node"
    @AppStorage("node.instanceId") private var nodeInstanceID: String = UUID().uuidString
    @State private var socialHub = SocialHub()
    @State private var profileNameDraft: String = ""
    @State private var profileBioDraft: String = ""
    @State private var profileCapabilitiesDraft: String = ""
    @State private var importedCardInput: String = ""

    var body: some View {
        Form {
            Section("Agent Profile") {
                TextField("Display Name", text: self.$profileNameDraft)
                TextField("Bio", text: self.$profileBioDraft, axis: .vertical)
                    .lineLimit(2 ... 4)
                TextField("Capabilities (comma-separated)", text: self.$profileCapabilitiesDraft, axis: .vertical)
                    .lineLimit(1 ... 3)

                Button("Save Profile") {
                    self.socialHub.updateProfile(
                        displayName: self.profileNameDraft,
                        bio: self.profileBioDraft,
                        capabilitiesCSV: self.profileCapabilitiesDraft)
                    self.syncDraftsFromProfile()
                }
                .buttonStyle(.borderedProminent)
            }

            Section("Same WiFi Discovery") {
                Toggle("Enable Peer Discovery", isOn: self.wifiDiscoveryBinding)

                LabeledContent("Discovery", value: self.socialHub.discoveryStatusText)

                if self.socialHub.discoveredPeers.isEmpty {
                    Text("No nearby agents discovered yet.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(self.socialHub.discoveredPeers) { peer in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(peer.displayName)
                                    .font(.headline)
                                Spacer()
                                self.peerMenu(peer)
                            }
                            if !peer.bio.isEmpty {
                                Text(peer.bio)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                            if !peer.capabilities.isEmpty {
                                Text(peer.capabilities.joined(separator: ", "))
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                            Text("ID: \(peer.peerID)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(self.authorizationStateLabel(peerID: peer.peerID))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(self.authorizationStateColor(peerID: peer.peerID))
                        }
                        .padding(.vertical, 4)
                    }
                }
            }

            Section("NFC Agent Card Exchange") {
                Toggle("Enable NFC Card Exchange", isOn: self.nfcEnabledBinding)
                LabeledContent("NFC", value: self.socialHub.nfcAvailabilityText)

                VStack(alignment: .leading, spacing: 8) {
                    Text("My Card Code")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(self.socialHub.localCardCode)
                        .font(.system(size: 12, weight: .regular, design: .monospaced))
                        .textSelection(.enabled)
                    Button("Copy Card Code") {
                        UIPasteboard.general.string = self.socialHub.localCardCode
                        self.socialHub.importStatusText = "Card code copied."
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("My Card Deep Link")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(self.socialHub.localCardDeepLink)
                        .font(.system(size: 12, weight: .regular, design: .monospaced))
                        .textSelection(.enabled)
                    Button("Copy Deep Link") {
                        UIPasteboard.general.string = self.socialHub.localCardDeepLink
                        self.socialHub.importStatusText = "Card deep link copied."
                    }
                }

                TextField("Paste card code or openclaw://agent-card link", text: self.$importedCardInput, axis: .vertical)
                    .lineLimit(1 ... 3)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                Button("Import Card") {
                    _ = self.socialHub.importAgentCard(from: self.importedCardInput)
                }

                if let importStatusText = self.socialHub.importStatusText,
                   !importStatusText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                {
                    Text(importStatusText)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Authorization") {
                Picker("Policy", selection: self.authorizationPolicyBinding) {
                    ForEach(SocialAuthorizationPolicy.allCases, id: \.self) { policy in
                        Text(policy.title).tag(policy)
                    }
                }
                Text(self.socialHub.authorizationPolicy.helpText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                LabeledContent("Trusted peers", value: "\(self.socialHub.trustedPeerIDs.count)")
                LabeledContent("Blocked peers", value: "\(self.socialHub.blockedPeerIDs.count)")

                if !self.socialHub.trustedPeerIDs.isEmpty || !self.socialHub.blockedPeerIDs.isEmpty {
                    Button("Clear Authorization Lists", role: .destructive) {
                        self.socialHub.clearAuthorizationLists()
                    }
                }
            }
        }
        .navigationTitle("Social")
        .onAppear {
            self.socialHub.bootstrap(displayName: self.nodeDisplayName, instanceID: self.nodeInstanceID)
            self.syncDraftsFromProfile()
        }
    }

    private var wifiDiscoveryBinding: Binding<Bool> {
        Binding(
            get: { self.socialHub.wifiDiscoveryEnabled },
            set: { self.socialHub.setWiFiDiscoveryEnabled($0) })
    }

    private var nfcEnabledBinding: Binding<Bool> {
        Binding(
            get: { self.socialHub.nfcEnabled },
            set: { self.socialHub.setNFCEnabled($0) })
    }

    private var authorizationPolicyBinding: Binding<SocialAuthorizationPolicy> {
        Binding(
            get: { self.socialHub.authorizationPolicy },
            set: { self.socialHub.setAuthorizationPolicy($0) })
    }

    @ViewBuilder
    private func peerMenu(_ peer: SocialPeerDiscoveryService.DiscoveredPeer) -> some View {
        Menu {
            if self.socialHub.isPeerTrusted(peer.peerID) {
                Button("Remove Trust") {
                    self.socialHub.untrust(peerID: peer.peerID)
                }
            } else {
                Button("Trust") {
                    self.socialHub.trust(peerID: peer.peerID)
                }
            }

            if self.socialHub.isPeerBlocked(peer.peerID) {
                Button("Unblock") {
                    self.socialHub.unblock(peerID: peer.peerID)
                }
            } else {
                Button("Block", role: .destructive) {
                    self.socialHub.block(peerID: peer.peerID)
                }
            }

            if let cardCode = peer.cardCode,
               !cardCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            {
                Button("Import Peer Card") {
                    _ = self.socialHub.importAgentCard(from: cardCode)
                }
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .foregroundStyle(.secondary)
        }
    }

    private func authorizationStateLabel(peerID: String) -> String {
        let decision = self.socialHub.authorizationDecision(for: peerID)
        if decision.allowed {
            return "Allowed: \(decision.reason)"
        }
        if decision.requiresPrompt {
            return "Requires prompt"
        }
        return "Blocked: \(decision.reason)"
    }

    private func authorizationStateColor(peerID: String) -> Color {
        let decision = self.socialHub.authorizationDecision(for: peerID)
        if decision.allowed { return .green }
        if decision.requiresPrompt { return .orange }
        return .red
    }

    private func syncDraftsFromProfile() {
        self.profileNameDraft = self.socialHub.profile.displayName
        self.profileBioDraft = self.socialHub.profile.bio
        self.profileCapabilitiesDraft = self.socialHub.capabilitiesCSV
    }
}
