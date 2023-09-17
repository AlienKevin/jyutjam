import Foundation
import AVFAudio

func decodeWaveFile(_ url: URL) throws -> [Float] {
    let file = try AVAudioFile(forReading: url)

    let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: file.fileFormat.sampleRate, channels: file.fileFormat.channelCount, interleaved: false)

    let buffer: AVAudioPCMBuffer
    buffer = AVAudioPCMBuffer(pcmFormat: format!, frameCapacity: AVAudioFrameCount(file.length))!
    try file.read(into: buffer)

    let floatArray = Array(UnsafeBufferPointer(start: buffer.floatChannelData?[0], count: Int(buffer.frameLength)))

    return floatArray
}
