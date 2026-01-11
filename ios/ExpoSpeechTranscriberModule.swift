import ExpoModulesCore
import Speech
import AVFoundation

public class ExpoSpeechTranscriberModule: Module {
    private var audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var bufferRecognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var bufferRecognitionTask: SFSpeechRecognitionTask?
    private var startedListening = false
    
    public func definition() -> ModuleDefinition {
        Name("ExpoSpeechTranscriber")
        
        Events("onTranscriptionProgress", "onTranscriptionError")
        
        // expose realtime recording/transcription
        AsyncFunction("recordRealTimeAndTranscribe") { () async -> Void in
            await self.recordRealTimeAndTranscribe()
        }
        
        // Method 2: Transcribe from URL using SFSpeechRecognizer (iOS 13+)
        AsyncFunction("transcribeAudioWithSFRecognizer") { (audioFilePath: String, options: [String: Any]?) async throws -> String in
            
            let url: URL
            if audioFilePath.hasPrefix("file://") {
                url = URL(string: audioFilePath)!
            } else {
                url = URL(fileURLWithPath: audioFilePath)
            }
            
            // Extract locale from options, default to current device locale
            let localeIdentifier = options?["locale"] as? String
            let locale: Locale
            if let identifier = localeIdentifier {
                locale = Locale(identifier: identifier)
            } else {
                locale = Locale.current
            }
            
            let transcription = await self.transcribeAudio(url: url, locale: locale)
            return transcription
        }
        
        // Method 3: Transcribe from URL using SpeechAnalyzer (iOS 26+)
        AsyncFunction("transcribeAudioWithAnalyzer") { (audioFilePath: String, localeIdentifier: String?) async throws -> String in
            
            if #available(iOS 26.0, *) {
                let url: URL
                if audioFilePath.hasPrefix("file://") {
                    url = URL(string: audioFilePath)!
                } else {
                    url = URL(fileURLWithPath: audioFilePath)
                }
                
                // Use provided locale or default to current device locale
                let locale: Locale
                if let identifier = localeIdentifier {
                    // Log the received identifier
                    print("[ExpoSpeechTranscriber] Received localeIdentifier: \(identifier)")
                    locale = Locale(identifier: identifier)
                } else {
                    locale = Locale.current
                }
                
                print("[ExpoSpeechTranscriber] Created Locale object: \(locale.identifier)")
                
                let transcription = try await self.transcribeAudioWithAnalyzer(url: url, locale: locale)
                return transcription
            } else {
                throw NSError(domain: "ExpoSpeechTranscriber", code: 501,
                              userInfo: [NSLocalizedDescriptionKey: "SpeechAnalyzer requires iOS 26.0 or later"])
            }
        }
        
        AsyncFunction("requestPermissions") { () async -> String in
            return await self.requestTranscribePermissions()
        }
        
        AsyncFunction("requestMicrophonePermissions") { () async -> String in
            return await self.requestMicrophonePermissions()
        }
        
        
        Function("stopListening"){ () -> Void in
            return self.stopListening()
        }
        
        Function("isRecording") { () -> Bool in
            return self.isRecording()
        }
        
        Function("isAnalyzerAvailable") { () -> Bool in
            if #available(iOS 26.0, *) {
                return true
            }
            return false
        }
        
        AsyncFunction("realtimeBufferTranscribe") { (buffer: [Float32], sampleRate: Double) async -> Void in
            await self.realtimeBufferTranscribe(buffer: buffer, sampleRate: sampleRate)
        }
        
        Function("stopBufferTranscription") { () -> Void in
            return self.stopBufferTranscription()
        }
    }
    
    // MARK: - Private Implementation Methods
    
    private func realtimeBufferTranscribe(buffer: [Float32], sampleRate: Double) async -> Void {
        if bufferRecognitionRequest == nil {
            let speechRecognizer = SFSpeechRecognizer()!
            bufferRecognitionRequest = SFSpeechAudioBufferRecognitionRequest()
            
            guard let recognitionRequest = bufferRecognitionRequest else {
                self.sendEvent("onTranscriptionError", ["message": "Unable to create recognition request"])
                return
            }
            recognitionRequest.shouldReportPartialResults = true
            
            bufferRecognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { result, error in
                if let error = error {
                    self.sendEvent("onTranscriptionError", ["message": error.localizedDescription])
                    return
                }
                
                guard let result = result else {
                    return
                }
                
                let recognizedText = result.bestTranscription.formattedString
                self.sendEvent(
                    "onTranscriptionProgress",
                    ["text": recognizedText, "isFinal": result.isFinal]
                )
            }
        }
      
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: AVAudioChannelCount(1))! // hardcode channel to 1 since we only support mono audio
        guard let pcmBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(buffer.count)) else {
            self.sendEvent("onTranscriptionError", ["message": "Unable to create PCM buffer"])
            return
        }
        
        pcmBuffer.frameLength = AVAudioFrameCount(buffer.count)
        if let channelData = pcmBuffer.floatChannelData {
            buffer.withUnsafeBufferPointer { bufferPointer in
                guard let sourceAddress = bufferPointer.baseAddress else { return }
                
                let destination = channelData[0]
                let byteCount = buffer.count * MemoryLayout<Float>.size
                
                memcpy(destination, sourceAddress, byteCount)
            }
        }
        
        // Append buffer to recognition request
        bufferRecognitionRequest?.append(pcmBuffer)
    }
    
    private func stopBufferTranscription() {
        bufferRecognitionRequest?.endAudio()
        bufferRecognitionRequest = nil
        
        bufferRecognitionTask?.cancel()
        bufferRecognitionTask = nil
    }
    
    // startRecordingAndTranscription using SFSpeechRecognizer
    private func recordRealTimeAndTranscribe() async -> Void  {
        let speechRecognizer = SFSpeechRecognizer()!
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            self.sendEvent("onTranscriptionError", ["message": "Unable to create recognition request"])
            return
        }
        recognitionRequest.shouldReportPartialResults = true
        
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.removeTap(onBus: 0)
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, when in
            recognitionRequest.append(buffer)
        }
        
        audioEngine.prepare()
        do {
            try audioEngine.start()
            startedListening = true
        } catch {
            self.sendEvent("onTranscriptionError", ["message": error.localizedDescription])
            return
        }
        
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { result, error in
            if let error = error {
                self.stopListening()
                self.sendEvent("onTranscriptionError", ["message": error.localizedDescription])
                return
            }
            
            guard let result = result else {
                return
            }
            
            let recognizedText = result.bestTranscription.formattedString
            self.sendEvent(
                "onTranscriptionProgress",
                ["text": recognizedText, "isFinal": result.isFinal]
            )
            
            if result.isFinal {
                self.stopListening()
            }
        }
    }
    
    private func stopListening() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        //recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil
    }
    
    
    private func isRecording() -> Bool {
        return audioEngine.isRunning
    }
    
    
    
    // Implemetation for URL transcription with SFSpeechRecognizer
    private func transcribeAudio(url: URL, locale: Locale) async -> String {
        
        guard FileManager.default.fileExists(atPath: url.path) else {
            let err = "Error: Audio file not found at \(url.path)"
            return err
        }
        
        return await withCheckedContinuation { continuation in
            guard let recognizer = SFSpeechRecognizer(locale: locale) else {
                let err = "Error: Speech recognizer not available for locale \(locale.identifier)"
                continuation.resume(returning: err)
                return
            }
            
            guard recognizer.isAvailable else {
                let err = "Error: Speech recognizer not available at this time"
                continuation.resume(returning: err)
                return
            }
            
            let request = SFSpeechURLRecognitionRequest(url: url)
            request.shouldReportPartialResults = false
            recognizer.recognitionTask(with: request) { (result, error) in
                if let error = error {
                    let errorMsg = "Error: \(error.localizedDescription)"
                    continuation.resume(returning: errorMsg)
                    return
                }
                
                guard let result = result else {
                    let errorMsg = "Error: No transcription available"
                    continuation.resume(returning: errorMsg)
                    return
                }
                
                if result.isFinal {
                    let text = result.bestTranscription.formattedString
                    let finalResult = text.isEmpty ? "No speech detected" : text
                    continuation.resume(returning: finalResult)
                }
            }
        }
    }
    
    // Implementation for URL transcription with SpeechAnalyzer (iOS 26+)
    @available(iOS 26.0, *)
    private func transcribeAudioWithAnalyzer(url: URL, locale: Locale) async throws -> String {
        
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw NSError(domain: "ExpoSpeechTranscriber", code: 404,
                          userInfo: [NSLocalizedDescriptionKey: "Audio file not found at \(url.path)"])
        }
        
        // Step 1: Get supported locale using supportedLocale(equivalentTo:) - must use await
        guard let supportedLocale = await SpeechTranscriber.supportedLocale(equivalentTo: locale) else {
            throw NSError(domain: "ExpoSpeechTranscriber", code: 400,
                          userInfo: [NSLocalizedDescriptionKey: "Locale \(locale.identifier) is not supported by SpeechTranscriber"])
        }
        
        // Log the supported locale for debugging
        print("[ExpoSpeechTranscriber] Input locale: \(locale.identifier)")
        print("[ExpoSpeechTranscriber] Supported locale: \(supportedLocale.identifier)")
        
        // Step 2: Create transcriber with supported locale and transcription preset
        let transcriber = SpeechTranscriber(locale: supportedLocale, preset: .transcription)
        
        // Step 3: Check and install assets if needed BEFORE starting transcription
        print("[ExpoSpeechTranscriber] Checking asset installation status...")
        do {
            if let installationRequest = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
                print("[ExpoSpeechTranscriber] Downloading and installing assets...")
                try await installationRequest.downloadAndInstall()
                print("[ExpoSpeechTranscriber] Assets installed successfully")
            } else {
                print("[ExpoSpeechTranscriber] Assets already installed")
            }
        } catch {
            print("[ExpoSpeechTranscriber] Asset installation error: \(error)")
            throw NSError(domain: "ExpoSpeechTranscriber", code: 500,
                          userInfo: [NSLocalizedDescriptionKey: "Failed to install language assets: \(error.localizedDescription)"])
        }
        
        // Step 4: Create analyzer and read audio file
        let analyzer = SpeechAnalyzer(modules: [transcriber])
        let audioFile = try AVAudioFile(forReading: url)
        
        print("[ExpoSpeechTranscriber] Starting audio analysis...")
        
        // Step 5: Set up results collection task
        let resultsTask = Task {
            var collectedText = ""
            do {
                for try await result in transcriber.results {
                    let plainText = String(result.text.characters)
                    print("[ExpoSpeechTranscriber] Received text: \(plainText)")
                    collectedText += plainText
                }
            } catch {
                print("[ExpoSpeechTranscriber] Error collecting transcription results: \(error)")
            }
            return collectedText
        }
        
        // Step 6: Perform analysis
        let lastSampleTime = try await analyzer.analyzeSequence(from: audioFile)
        
        // Step 7: Finish analysis
        if let lastSampleTime {
            print("[ExpoSpeechTranscriber] Finalizing analysis...")
            try await analyzer.finalizeAndFinish(through: lastSampleTime)
        } else {
            print("[ExpoSpeechTranscriber] No audio data, cancelling...")
            await analyzer.cancelAndFinishNow()
        }
        
        // Wait for results collection to complete
        let finalText = await resultsTask.value
        
        print("[ExpoSpeechTranscriber] Final transcription: \(finalText)")
        let result = finalText.isEmpty ? "No speech detected" : finalText
        return result
    }
    
    @available(iOS 26.0, *)
    private func isLocaleSupported(locale: Locale) async -> Bool {
        guard SpeechTranscriber.isAvailable else { return false }
        let supported = await DictationTranscriber.supportedLocales
        return supported.map { $0.identifier(.bcp47) }.contains(locale.identifier(.bcp47))
    }
    
    @available(iOS 26.0, *)
    private func isLocaleInstalled(locale: Locale) async -> Bool {
        let installed = await Set(SpeechTranscriber.installedLocales)
        return installed.map { $0.identifier(.bcp47) }.contains(locale.identifier(.bcp47))
    }
    
    @available(iOS 26.0, *)
    private func ensureModel(transcriber: SpeechTranscriber, locale: Locale) async throws {
        guard await isLocaleSupported(locale: locale) else {
            throw NSError(domain: "ExpoSpeechTranscriber", code: 400,
                          userInfo: [NSLocalizedDescriptionKey: "Locale not supported"])
        }
        
        if await isLocaleInstalled(locale: locale) {
            return
        } else {
            try await downloadModelIfNeeded(for: transcriber)
        }
    }
    
    @available(iOS 26.0, *)
    private func downloadModelIfNeeded(for module: SpeechTranscriber) async throws {
        if let downloader = try await AssetInventory.assetInstallationRequest(supporting: [module]) {
            try await downloader.downloadAndInstall()
        }
    }
    
    private func requestTranscribePermissions() async -> String {
        return await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { authStatus in
                let result: String
                switch authStatus {
                case .authorized:
                    result = "authorized"
                case .denied:
                    result = "denied"
                case .restricted:
                    result = "restricted"
                case .notDetermined:
                    result = "notDetermined"
                @unknown default:
                    result = "unknown"
                }
                continuation.resume(returning: result)
            }
        }
    }
    
    private func requestMicrophonePermissions() async -> String {
        return await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                let result = granted ? "granted" : "denied"
                continuation.resume(returning: result)
            }
        }
    }
}

