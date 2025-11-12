import ExpoModulesCore
import Speech
import AVFoundation

public class ExpoSpeechTranscriberModule: Module {
  
  private func requestTranscribePermissions() async -> String {
      return await withCheckedContinuation { continuation in
          SFSpeechRecognizer.requestAuthorization { authStatus in
              switch authStatus {
              case .authorized:
                  continuation.resume(returning: "authorized")
              case .denied:
                  continuation.resume(returning: "denied")
              case .restricted:
                  continuation.resume(returning: "restricted")
              case .notDetermined:
                  continuation.resume(returning: "notDetermined")
              @unknown default:
                  continuation.resume(returning: "unknown")
              }
          }
      }
  }

  private func transcribeAudio(url: URL) async -> String {
      // Check if file exists first
      guard FileManager.default.fileExists(atPath: url.path) else {
          return "Error: Audio file not found at \(url.path)"
      }
      
      return await withCheckedContinuation { continuation in
          guard let recognizer = SFSpeechRecognizer() else {
              continuation.resume(returning: "Error: Speech recognizer not available for current locale")
              return
          }
          
          guard recognizer.isAvailable else {
              continuation.resume(returning: "Error: Speech recognizer not available at this time")
              return
          }
          
          let request = SFSpeechURLRecognitionRequest(url: url)
          request.shouldReportPartialResults = false

          recognizer.recognitionTask(with: request) { (result, error) in
              if let error = error {
                  continuation.resume(returning: "Error: \(error.localizedDescription)")
                  return
              }
              
              guard let result = result else {
                  continuation.resume(returning: "Error: No transcription available")
                  return
              }

              if result.isFinal {
                  let text = result.bestTranscription.formattedString
                  continuation.resume(returning: text.isEmpty ? "No speech detected" : text)
              }
          }
      }
  }
  
  // New method using Apple's latest SpeechAnalyzer API (iOS 26+)
  @available(iOS 26.0, *)
  private func transcribeAudioWithAnalyzer(url: URL) async throws -> String {
      // Check if file exists
      guard FileManager.default.fileExists(atPath: url.path) else {
          throw NSError(domain: "ExpoSpeechTranscriber", code: 404, 
                       userInfo: [NSLocalizedDescriptionKey: "Audio file not found at \(url.path)"])
      }
      
      // Use English locale
      let locale = Locale(identifier: "en_US")
      
      // Check if locale is supported
      guard await isLocaleSupported(locale: locale) else {
          throw NSError(domain: "ExpoSpeechTranscriber", code: 400,
                       userInfo: [NSLocalizedDescriptionKey: "English locale not supported"])
      }
      
      // Create transcriber
      let transcriber = SpeechTranscriber(
          locale: locale,
          transcriptionOptions: [],
          reportingOptions: [.volatileResults],
          attributeOptions: [.audioTimeRange]
      )
      
      // Ensure model is downloaded
      try await ensureModel(transcriber: transcriber, locale: locale)
      
      // Create analyzer
      let analyzer = SpeechAnalyzer(modules: [transcriber])
      
      // Analyze audio file
      let audioFile = try AVAudioFile(forReading: url)
      if let lastSample = try await analyzer.analyzeSequence(from: audioFile) {
          try await analyzer.finalizeAndFinish(through: lastSample)
      } else {
          await analyzer.cancelAndFinishNow()
      }
      
      // Collect final transcription
      var finalText = ""
      for try await recResponse in transcriber.results {
          if recResponse.isFinal {
              finalText += String(recResponse.text.characters)
          }
      }
      
      return finalText.isEmpty ? "No speech detected" : finalText
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
  
  public func definition() -> ModuleDefinition {
    Name("ExpoSpeechTranscriber")
    Events("onTranscriptionProgress", "onTranscriptionError")

    // Renamed from "transcribeAudio" to match TypeScript naming
    AsyncFunction("transcribeAudioWithSFRecognizer") { (audioFilePath: String?) async throws -> String in
      guard let audioFilePath = audioFilePath else {
        throw NSError(domain: "ExpoSpeechTranscriber", code: 400, userInfo: [NSLocalizedDescriptionKey: "Audio file path is required"])
      }
      
      // Handle both file:// URLs and plain paths
      let url: URL
      if audioFilePath.hasPrefix("file://") {
          url = URL(string: audioFilePath)!
      } else {
          url = URL(fileURLWithPath: audioFilePath)
      }
      
      print("Processing audio file at: \(url.path)")
      let transcription = await self.transcribeAudio(url: url)
      print("Transcription result: \(transcription)")
      return transcription
    }
    
    // New function using SpeechAnalyzer (iOS 26+) with English locale only
    AsyncFunction("transcribeAudioWithAnalyzer") { (audioFilePath: String?) async throws -> String in
      guard let audioFilePath = audioFilePath else {
        throw NSError(domain: "ExpoSpeechTranscriber", code: 400, userInfo: [NSLocalizedDescriptionKey: "Audio file path is required"])
      }
      
      if #available(iOS 26.0, *) {
          // Handle both file:// URLs and plain paths
          let url: URL
          if audioFilePath.hasPrefix("file://") {
              url = URL(string: audioFilePath)!
          } else {
              url = URL(fileURLWithPath: audioFilePath)
          }
          
          print("Processing audio file at: \(url.path) with English locale")
          let transcription = try await self.transcribeAudioWithAnalyzer(url: url)
          print("Transcription result: \(transcription)")
          return transcription
      } else {
          throw NSError(domain: "ExpoSpeechTranscriber", code: 501,
                       userInfo: [NSLocalizedDescriptionKey: "SpeechAnalyzer requires iOS 26.0 or later"])
      }
    }

    // Check if Analyzer API is available on this device
    Function("isAnalyzerAvailable") { () -> Bool in
      if #available(iOS 26.0, *) {
          return true
      } else {
          return false
      }
    }

    AsyncFunction("requestPermissions") { () async -> String in
        return await self.requestTranscribePermissions()
    }
  }
}
