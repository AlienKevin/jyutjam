import Foundation
import SwiftUI
import AVFoundation

enum MyState: Equatable {
    case loadingModel
    case errorLoadingModel
    case errorLoadingSample
    case recording
    case errorRecording
    case recorded(URL)
    case errorTranscribing
    case transcribed(String)
}

@MainActor
class WhisperState: NSObject, ObservableObject, AVAudioRecorderDelegate {
    @Published var state = MyState.loadingModel
    
    private var whisperContext: WhisperContext?
    private let recorder = Recorder()
    private var audioPlayer: AVAudioPlayer?
    
    private var modelUrl: URL? {
        Bundle.main.url(forResource: "ggml-small", withExtension: "bin", subdirectory: "models")
    }
    
    private var sampleUrl: URL? {
        Bundle.main.url(forResource: "cyunsyutzung", withExtension: "wav", subdirectory: "samples")
    }
    
    private enum LoadError: Error {
        case couldNotLocateModel
    }
    
    override init() {
        super.init()
        loadModel()
    }
    
    private func loadModel() {
        if let modelUrl {
            do {
                whisperContext = try WhisperContext.createContext(path: modelUrl.path())
                state = MyState.transcribed("")
            } catch {
                state = MyState.errorLoadingModel
            }
        } else {
            state = MyState.errorLoadingModel
        }
    }
    
    func transcribeSample() async {
        if let sampleUrl {
            state = MyState.recorded(sampleUrl)
            await transcribeAudio()
        } else {
            state = MyState.errorLoadingSample
        }
    }
    
    private func transcribeAudio() async {
        guard case let MyState.recorded(url) = state else {
            return
        }
        guard let whisperContext else {
            return
        }
        
        do {
            let data = try readAudioSamples(url)
            await whisperContext.fullTranscribe(samples: data)
            let text = await whisperContext.getTranscription()
            state = MyState.transcribed(text)
        } catch {
            state = MyState.errorTranscribing
        }
    }
    
    private func readAudioSamples(_ url: URL) throws -> [Float] {
        stopPlayback()
        try startPlayback(url)
        return try decodeWaveFile(url)
    }
    
    func toggleRecord() async {
        do {
            let url = try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
                .appending(path: "output.wav")
            if case MyState.recording = state {
                await recorder.stopRecording()
                state = MyState.recorded(url)
                await transcribeAudio()
            } else {
                requestRecordPermission { granted in
                    if granted {
                        Task {
                            self.stopPlayback()
                            try await self.recorder.startRecording(toOutputFile: url, delegate: self)
                            self.state = MyState.recording
                        }
                    }
                }
            }
        } catch {
            self.state = MyState.errorRecording
        }
    }
    
    private func requestRecordPermission(response: @escaping (Bool) -> Void) {
#if os(macOS)
        response(true)
#else
        AVAudioSession.sharedInstance().requestRecordPermission { granted in
            response(granted)
        }
#endif
    }
    
    private func startPlayback(_ url: URL) throws {
        audioPlayer = try AVAudioPlayer(contentsOf: url)
        audioPlayer?.play()
    }
    
    private func stopPlayback() {
        audioPlayer?.stop()
        audioPlayer = nil
    }
    
    // MARK: AVAudioRecorderDelegate
    
    nonisolated func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        if let error {
            Task {
                await handleRecError(error)
            }
        }
    }
    
    private func handleRecError(_ error: Error) {
        state = MyState.errorRecording
    }
    
    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        Task {
            await onDidFinishRecording()
        }
    }
    
    private func onDidFinishRecording() {
        // TODO
    }
}
