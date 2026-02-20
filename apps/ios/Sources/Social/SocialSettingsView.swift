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

    @State private var protocolTypeDraft: SocialProtocolMessageType = .memorySync
    @State private var protocolRecipientsDraft: String = ""
    @State private var protocolPayloadDraft: String = ""
    @State private var protocolImportInput: String = ""

    @State private var memoryKeyDraft: String = ""
    @State private var memoryValueDraft: String = ""
    @State private var memorySourceDraft: String = ""
    @State private var memoryImportInput: String = ""

    @State private var meetingTitleDraft: String = ""
    @State private var meetingParticipantsDraft: String = ""
    @State private var meetingSpeakerDraft: String = ""
    @State private var meetingMessageDraft: String = ""

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

                self.statusTextView
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

            Section("Agent Protocol") {
                Picker("Message Type", selection: self.$protocolTypeDraft) {
                    ForEach(SocialProtocolMessageType.allCases, id: \.self) { messageType in
                        Text(messageType.rawValue).tag(messageType)
                    }
                }
                TextField("Recipients (comma-separated peer IDs)", text: self.$protocolRecipientsDraft)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                TextField("Payload (key=value per line)", text: self.$protocolPayloadDraft, axis: .vertical)
                    .lineLimit(2 ... 5)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                Button("Send Protocol Message") {
                    _ = self.socialHub.sendProtocolMessage(
                        type: self.protocolTypeDraft,
                        recipientsCSV: self.protocolRecipientsDraft,
                        payloadText: self.resolvedProtocolPayloadText())
                }
                .buttonStyle(.borderedProminent)

                LabeledContent("Outbox", value: "\(self.socialHub.protocolOutbox.count)")
                LabeledContent("Inbox", value: "\(self.socialHub.protocolInbox.count)")

                if !self.socialHub.latestProtocolCode.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Latest Protocol Code")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(self.socialHub.latestProtocolCode)
                            .font(.system(size: 12, weight: .regular, design: .monospaced))
                            .textSelection(.enabled)
                        Button("Copy Protocol Code") {
                            UIPasteboard.general.string = self.socialHub.latestProtocolCode
                            self.socialHub.importStatusText = "Protocol code copied."
                        }
                    }
                }

                if !self.socialHub.latestProtocolDeepLink.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Latest Protocol Deep Link")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(self.socialHub.latestProtocolDeepLink)
                            .font(.system(size: 12, weight: .regular, design: .monospaced))
                            .textSelection(.enabled)
                        Button("Copy Protocol Deep Link") {
                            UIPasteboard.general.string = self.socialHub.latestProtocolDeepLink
                            self.socialHub.importStatusText = "Protocol deep link copied."
                        }
                    }
                }

                TextField("Paste protocol code or openclaw://social link", text: self.$protocolImportInput, axis: .vertical)
                    .lineLimit(1 ... 3)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                Button("Import Protocol Message") {
                    _ = self.socialHub.importProtocolMessage(from: self.protocolImportInput)
                }

                self.statusTextView
            }

            Section("Shared Memory") {
                TextField("Memory Key", text: self.$memoryKeyDraft)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                TextField("Memory Value", text: self.$memoryValueDraft, axis: .vertical)
                    .lineLimit(1 ... 3)
                TextField("Source Peer ID (optional)", text: self.$memorySourceDraft)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                Button("Add or Update Memory") {
                    _ = self.socialHub.upsertSharedMemory(
                        key: self.memoryKeyDraft,
                        value: self.memoryValueDraft,
                        sourcePeerID: self.memorySourceDraft)
                }

                if self.socialHub.sharedMemories.isEmpty {
                    Text("No shared memory records yet.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(Array(self.socialHub.sharedMemories.prefix(8))) { memory in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(memory.key)
                                .font(.footnote.weight(.semibold))
                            Text(memory.value)
                                .font(.footnote)
                            Text("source: \(memory.sourcePeerID)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 2)
                    }
                }

                if !self.socialHub.sharedMemoryCode.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Shared Memory Code")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(self.socialHub.sharedMemoryCode)
                            .font(.system(size: 12, weight: .regular, design: .monospaced))
                            .textSelection(.enabled)
                        Button("Copy Memory Code") {
                            UIPasteboard.general.string = self.socialHub.sharedMemoryCode
                            self.socialHub.importStatusText = "Memory code copied."
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Shared Memory Deep Link")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(self.socialHub.sharedMemoryDeepLink)
                            .font(.system(size: 12, weight: .regular, design: .monospaced))
                            .textSelection(.enabled)
                        Button("Copy Memory Deep Link") {
                            UIPasteboard.general.string = self.socialHub.sharedMemoryDeepLink
                            self.socialHub.importStatusText = "Memory deep link copied."
                        }
                    }
                }

                TextField("Paste memory code or openclaw://memory link", text: self.$memoryImportInput, axis: .vertical)
                    .lineLimit(1 ... 3)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                Button("Import Memory Packet") {
                    _ = self.socialHub.importSharedMemory(from: self.memoryImportInput)
                }

                if !self.socialHub.sharedMemories.isEmpty {
                    Button("Clear Shared Memory", role: .destructive) {
                        self.socialHub.clearSharedMemory()
                    }
                }

                self.statusTextView
            }

            Section("Multi Agent Meeting") {
                if let active = self.socialHub.activeMeeting {
                    LabeledContent("Active Meeting", value: active.title)
                    Text("Host: \(active.hostPeerID)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Text("Participants: \(active.participantPeerIDs.joined(separator: ", "))")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    if active.messages.isEmpty {
                        Text("No meeting messages yet.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(Array(active.messages.suffix(8))) { message in
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(message.peerID)")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                Text(message.text)
                                    .font(.footnote)
                            }
                            .padding(.vertical, 2)
                        }
                    }

                    TextField("Speaker Peer ID (optional)", text: self.$meetingSpeakerDraft)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField("Meeting Message", text: self.$meetingMessageDraft, axis: .vertical)
                        .lineLimit(1 ... 3)

                    Button("Append Message") {
                        _ = self.socialHub.appendActiveMeetingMessage(
                            peerID: self.meetingSpeakerDraft,
                            text: self.meetingMessageDraft)
                        self.meetingMessageDraft = ""
                    }

                    Button("End Active Meeting", role: .destructive) {
                        _ = self.socialHub.endActiveMeeting()
                    }
                }

                TextField("Meeting Title", text: self.$meetingTitleDraft)
                TextField("Participant Peer IDs (comma-separated)", text: self.$meetingParticipantsDraft)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                Button("Start Meeting") {
                    _ = self.socialHub.startMeeting(
                        title: self.meetingTitleDraft,
                        participantsCSV: self.meetingParticipantsDraft)
                }
                .disabled(self.socialHub.activeMeeting != nil)

                if !self.socialHub.meetingSessions.isEmpty {
                    ForEach(Array(self.socialHub.meetingSessions.prefix(6))) { session in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(session.title)
                                    .font(.footnote.weight(.semibold))
                                Spacer()
                                Text(session.isActive ? "active" : "ended")
                                    .font(.caption)
                                    .foregroundStyle(session.isActive ? .green : .secondary)
                            }
                            Text("\(session.participantPeerIDs.count) participants, \(session.messages.count) messages")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 2)
                    }
                }

                self.statusTextView
            }

            Section("Social Graph") {
                let graph = self.socialHub.socialGraphSnapshot
                LabeledContent("Summary", value: graph.summaryText)

                if graph.nodes.isEmpty {
                    Text("No graph nodes yet.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(Array(graph.nodes.prefix(10))) { node in
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text(node.displayName)
                                    .font(.footnote.weight(.semibold))
                                Spacer()
                                Text(node.relation.rawValue)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Text("memory: \(node.memoryCount), meetings: \(node.meetingCount)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 2)
                    }
                }

                if !graph.edges.isEmpty {
                    Divider()
                    ForEach(Array(graph.edges.prefix(12))) { edge in
                        Text(edge.summaryText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle("Social")
        .onAppear {
            self.socialHub.bootstrap(displayName: self.nodeDisplayName, instanceID: self.nodeInstanceID)
            self.syncDraftsFromProfile()
            if self.meetingSpeakerDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                self.meetingSpeakerDraft = self.socialHub.profile.id
            }
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

    private var statusTextView: some View {
        Group {
            if let importStatusText = self.socialHub.importStatusText,
               !importStatusText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            {
                Text(importStatusText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func resolvedProtocolPayloadText() -> String {
        if !self.protocolPayloadDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return self.protocolPayloadDraft
        }

        if self.protocolTypeDraft == .memorySync,
           !self.socialHub.sharedMemoryCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        {
            return "memory=\(self.socialHub.sharedMemoryCode)"
        }

        return ""
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
