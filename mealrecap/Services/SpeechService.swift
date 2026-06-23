import Foundation

@MainActor
final class SpeechService: ObservableObject {
    enum RecordingState: Equatable {
        case idle
    }

    @Published var transcript = ""
    @Published private(set) var state: RecordingState = .idle

    var isRecording: Bool { false }
    var isBusy: Bool { false }
    var hasFinishedRecording: Bool { false }
    var canAnalyze: Bool { false }
    var failureMessage: String? { nil }

    func startRecording() async throws {
        // Release build intentionally uses native keyboard dictation in VoiceLogSheet.
    }

    func stopRecording() {}

    func cancelRecording() {
        transcript = ""
        state = .idle
    }

    func clearFinishedRecording() {
        transcript = ""
        state = .idle
    }
}
