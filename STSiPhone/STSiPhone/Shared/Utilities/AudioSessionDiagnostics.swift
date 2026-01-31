import AVFoundation

#if DEBUG
enum AudioSessionDiagnostics {
    static func snapshot(_ context: String) {
        let session = AVAudioSession.sharedInstance()
        let route = session.currentRoute
        let outputs = route.outputs.map { $0.portType.rawValue }.joined(separator: ",")
        let inputs = route.inputs.map { $0.portType.rawValue }.joined(separator: ",")
        let opts = describeOptions(session.categoryOptions)
        let outputVolume = String(format: "%.2f", session.outputVolume)
        let preferredSampleRate = String(format: "%.0f", session.preferredSampleRate)
        let sampleRate = String(format: "%.0f", session.sampleRate)

        print("🔊 AudioSession[\(context)] cat=\(session.category.rawValue) mode=\(session.mode.rawValue) opts=\(opts) otherAudio=\(session.isOtherAudioPlaying) secondarySilence=\(session.secondaryAudioShouldBeSilencedHint) vol=\(outputVolume) routeOut=\(outputs) routeIn=\(inputs) prefSR=\(preferredSampleRate) SR=\(sampleRate) prefInCh=\(session.preferredInputNumberOfChannels) outCh=\(session.outputNumberOfChannels)")
    }

    static func installObservers(context: String, includeRouteChange: Bool = true) -> [NSObjectProtocol] {
        var tokens: [NSObjectProtocol] = []
        let center = NotificationCenter.default

        if includeRouteChange {
            let token = center.addObserver(
                forName: AVAudioSession.routeChangeNotification,
                object: nil,
                queue: .main
            ) { _ in
                snapshot("\(context)/routeChange")
            }
            tokens.append(token)
        }

        let interruptionToken = center.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil,
            queue: .main
        ) { notification in
            let typeValue = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
            let type = typeValue.flatMap { AVAudioSession.InterruptionType(rawValue: $0) }
            let optionValue = notification.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
            let options = AVAudioSession.InterruptionOptions(rawValue: optionValue)
            let resumeText = options.contains(.shouldResume) ? "true" : "false"
            let typeText = type.map { String($0.rawValue) } ?? "nil"
            print("🔊 AudioSession[\(context)] interruption type=\(typeText) shouldResume=\(resumeText)")
            snapshot("\(context)/interruption")
        }
        tokens.append(interruptionToken)

        let resetToken = center.addObserver(
            forName: AVAudioSession.mediaServicesWereResetNotification,
            object: nil,
            queue: .main
        ) { _ in
            print("🔊 AudioSession[\(context)] mediaServicesWereReset")
            snapshot("\(context)/mediaReset")
        }
        tokens.append(resetToken)

        return tokens
    }

    static func removeObservers(_ tokens: inout [NSObjectProtocol]) {
        let center = NotificationCenter.default
        for token in tokens {
            center.removeObserver(token)
        }
        tokens.removeAll()
    }

    private static func describeOptions(_ options: AVAudioSession.CategoryOptions) -> String {
        var parts: [String] = []
        if options.contains(.mixWithOthers) { parts.append("mix") }
        if options.contains(.duckOthers) { parts.append("duck") }
        if options.contains(.interruptSpokenAudioAndMixWithOthers) { parts.append("interruptSpoken") }
        if options.contains(.allowBluetoothA2DP) { parts.append("a2dp") }
        if options.contains(.allowBluetoothHFP) { parts.append("hfp") }
        if options.contains(.allowAirPlay) { parts.append("airplay") }
        if options.contains(.defaultToSpeaker) { parts.append("speaker") }
        if options.contains(.overrideMutedMicrophoneInterruption) { parts.append("overrideMuteMic") }
        if parts.isEmpty { return "[]" }
        return "[\(parts.joined(separator: ","))]"
    }
}
#endif
