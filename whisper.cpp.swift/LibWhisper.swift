import Foundation

enum WhisperError: Error {
    case couldNotInitializeContext
}

// Meet Whisper C++ constraint: Don't access from more than one thread at a time.
actor WhisperContext {
    private var context: OpaquePointer
    
    init(context: OpaquePointer) {
        self.context = context
    }
    
    deinit {
        whisper_free(context)
    }
    
    func fullTranscribe(samples: [Float]) {
        // Leave 2 processors free (i.e. the high-efficiency cores).
        let maxThreads = max(1, min(8, cpuCount() - 2))
        print("Selecting \(maxThreads) threads")
        var params = whisper_full_default_params(WHISPER_SAMPLING_GREEDY)
        "en".withCString { en in
            // Adapted from whisper.objc
            params.print_realtime = false
            params.print_progress = false
            params.print_special = false
            params.print_timestamps = false
            params.single_segment = false
            params.translate = false
            params.language = en
            params.n_threads = Int32(maxThreads)
            params.split_on_word = true
            params.greedy.best_of = 5
            params.token_timestamps = true
            params.max_len = 1
            params.no_context = true
            params.logprob_thold = -1.0
            
            whisper_reset_timings(context)
            print("About to run whisper_full")
            samples.withUnsafeBufferPointer { samples in
                if (whisper_full(context, params, samples.baseAddress, Int32(samples.count)) != 0) {
                    print("Failed to run the model")
                } else {
                    whisper_print_timings(context)
                }
            }
        }
    }
    
    func millisecondsToTimestamp(_ milliseconds: Int64) -> String {
        let hours = (milliseconds / (1000 * 60 * 60)) % 24
        let minutes = (milliseconds / (1000 * 60)) % 60
        let seconds = (milliseconds / 1000) % 60
        let millis = milliseconds % 1000

        let formattedString = String(format: "%02d:%02d:%02d.%03d", hours, minutes, seconds, millis)
        return formattedString
    }
    
    func getTranscription() -> String {
        var transcription = ""
        for i in 0..<whisper_full_n_segments(context) {
            print(millisecondsToTimestamp(whisper_full_get_segment_t0(context, i)) + " -> " + millisecondsToTimestamp(whisper_full_get_segment_t1(context, i)) + ": " + String.init(cString: whisper_full_get_segment_text(context, i)).trimmingCharacters(in: .whitespacesAndNewlines))
            transcription += String.init(cString: whisper_full_get_segment_text(context, i))
        }
        return transcription
    }
    
    static func createContext(path: String) throws -> WhisperContext {
        let context = whisper_init_from_file(path)
        if let context {
            return WhisperContext(context: context)
        } else {
            print("Couldn't load model at \(path)")
            throw WhisperError.couldNotInitializeContext
        }
    }
}

fileprivate func cpuCount() -> Int {
    ProcessInfo.processInfo.processorCount
}
