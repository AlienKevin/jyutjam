import Foundation
import SwiftUI
import AVFoundation

enum MyState: Equatable {
    case loadingModel
    case errorLoadingModel
    case errorLoadingSample
    case recording
    case errorRecording(String)
    case recorded(URL)
    case errorTranscribing(String)
    case transcribed(String)
}

@MainActor
class WhisperState: NSObject, ObservableObject, AVAudioRecorderDelegate {
    @Published var state = MyState.loadingModel
    
    private var whisperContext: WhisperContext?
    private var recorder: AVAudioRecorder?
    private var audioPlayer: AVAudioPlayer?
    private var recordingUrl: URL?;
    
    private var modelUrl: URL? {
        Bundle.main.url(forResource: "ggml-small", withExtension: "bin", subdirectory: "models")
    }
    
    private var sampleUrl1: URL? {
        Bundle.main.url(forResource: "cyunsyutzung", withExtension: "wav", subdirectory: "samples")
    }
    
    private var sampleUrl2: URL? {
        Bundle.main.url(forResource: "neihaidou", withExtension: "wav", subdirectory: "samples")
    }
    
    private enum LoadError: Error {
        case couldNotLocateModel
    }
    
    override init() {
        super.init()
        do {
            self.recordingUrl = try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
                .appending(path: "output.wav")
            
            loadModel()
            
            let recordSettings: [String : Any] = [
                AVFormatIDKey: Int(kAudioFormatLinearPCM),
                AVSampleRateKey: 16000.0,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]
            recorder = try AVAudioRecorder(url: self.recordingUrl!, settings: recordSettings)
            recorder?.delegate = self
        } catch {
            print(error)
            state = MyState.errorRecording(error.localizedDescription)
        }
    }
    
    func startRecording(toOutputFile url: URL, delegate: AVAudioRecorderDelegate?) throws {
#if !os(macOS)
        let session = AVAudioSession.sharedInstance()
        try session.setActive(true)
        session.requestRecordPermission() { allowed in
            if allowed {
                if self.recorder?.record() == false {
                    self.state = MyState.errorRecording("Failed to record")
                }
            }
        }
#else
        if self.recorder?.record() == false {
            self.state = MyState.errorRecording("Failed to record")
        }
#endif
    }
    
    func stopRecording() {
        recorder?.stop()
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
    
    func transcribeSample1() async {
        if let sampleUrl1 {
            state = MyState.recorded(sampleUrl1)
            await transcribeAudio()
        } else {
            state = MyState.errorLoadingSample
        }
    }
    
    func transcribeSample2() async {
        if let sampleUrl2 {
            state = MyState.recorded(sampleUrl2)
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
            state = MyState.errorTranscribing(error.localizedDescription)
        }
    }
    
    private func readAudioSamples(_ url: URL) throws -> [Float] {
//        stopPlayback()
//        try startPlayback(url)
        return try decodeWaveFile(url)
    }
    
    func toggleRecord() async {
        if case MyState.recording = state {
            stopRecording()
            state = MyState.recorded(recordingUrl!)
            await transcribeAudio()
        } else {
//         self.stopPlayback()
            do {
                try startRecording(toOutputFile: self.recordingUrl!, delegate: self)
                self.state = MyState.recording
            } catch {
                self.state = MyState.errorRecording(error.localizedDescription)
            }
        }
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
        state = MyState.errorRecording(error.localizedDescription)
    }
    
    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        Task {
            await onDidFinishRecording()
        }
    }
    
    private func onDidFinishRecording() {
        state = MyState.recorded(recordingUrl!)
    }
}
