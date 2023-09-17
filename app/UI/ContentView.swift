import SwiftUI
import AVFoundation

struct ContentView: View {
    @StateObject var whisperState = WhisperState()
    
    var content: some View {
        switch whisperState.state {
        case .errorLoadingModel:
            return AnyView(Text("Error loading model"))
        case .errorRecording:
            return AnyView(Text("Error recording"))
        case .errorLoadingSample:
            return AnyView(Text("Error loading sample"))
        case .errorTranscribing:
            return AnyView(Text("Error transcribing"))
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
                    Button("Transcribe", action: {
                        Task {
                            await whisperState.transcribeSample()
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
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
