import SwiftUI
import AVFoundation

struct ContentView: View {
    @StateObject var whisperState = WhisperState()
    
    var content: some View {
        switch whisperState.state {
        case .errorLoadingModel:
            return AnyView(Text("Error loading model"))
        case .errorRecording(let err):
            return AnyView(Text("Error recording: " + err))
        case .errorLoadingSample:
            return AnyView(Text("Error loading sample"))
        case .errorTranscribing(let err):
            return AnyView(Text("Error transcribing " + err))
        case .recording:
            return AnyView(Text("Recording..."))
        case .transcribed(let text):
            return AnyView(Text(text))
        case .loadingModel:
            return AnyView(Text("Loading model..."))
        case .recorded(_):
            return AnyView(Text("Transcribing..."))
        }
    }
    
    var transcribeEnabled: Bool {
        if case MyState.transcribed(_) = whisperState.state { return true } else { return false }
    }
    
    var recordEnabled: Bool {
        if case MyState.transcribed(_) = whisperState.state { return true }
        else if case MyState.recording = whisperState.state { return true }
        else { return false }
    }
    
    var body: some View {
        NavigationStack {
            VStack {
                HStack {
                    Button("Transcribe1", action: {
                        Task {
                            await whisperState.transcribeSample1()
                        }
                    })
                    .buttonStyle(.bordered)
                    .disabled(!transcribeEnabled)
                    
                    Button("Transcribe2", action: {
                        Task {
                            await whisperState.transcribeSample2()
                        }
                    })
                    .buttonStyle(.bordered)
                    .disabled(!transcribeEnabled)
                    
                    Button(whisperState.state == MyState.recording ? "Stop recording" : "Start recording", action: {
                        Task {
                            await whisperState.toggleRecord()
                        }
                    })
                    .buttonStyle(.bordered)
                    .disabled(!recordEnabled)
                }
                
                content
                    .navigationTitle("Jyut Jam")
                    .padding()
            }
        }.onAppear(perform: {() -> () in
            do {
                let session = AVAudioSession.sharedInstance()
                try session.setCategory(.playAndRecord, mode: .default)
            } catch {
                whisperState.state = MyState.errorRecording(error.localizedDescription)
            }
        })
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
