import ExpoModulesCore
import Speech
import AVFoundation

public class ExpoSpeechTranscriberModule: Module {
  // Each module class must implement the definition function. The definition consists of components
  // that describes the module's functionality and behavior.
  // See https://docs.expo.dev/modules/module-api for more details about available components.

  private func requestTranscribePermissions() async -> String {
      return await withCheckedContinuation { continuation in
          SFSpeechRecognizer.requestAuthorization { authStatus in
              if authStatus == .authorized {
                  continuation.resume(returning: "Permission granted!")
              } else {
                  continuation.resume(returning: "Transcription permission was declined.")
              }
          }
      }
  }

  private func transcribeAudio(url: URL) async -> String {
      return await withCheckedContinuation { continuation in
          // create a new recognizer and point it at our audio
          let recognizer = SFSpeechRecognizer()
          let request = SFSpeechURLRecognitionRequest(url: url)

          // start recognition!
          recognizer?.recognitionTask(with: request) { (result, error) in
              // abort if we didn't get any transcription back
              if let error = error {
                  continuation.resume(returning: "Error: \(error.localizedDescription)")
                  return
              }
              
              guard let result = result else {
                  continuation.resume(returning: "No transcription available")
                  return
              }

              // if we got the final transcription back, return it
              if result.isFinal {
                  continuation.resume(returning: result.bestTranscription.formattedString)
              }
          }
      }
  }
  public func definition() -> ModuleDefinition {
    // Sets the name of the module that JavaScript code will use to refer to the module. Takes a string as an argument.
    // Can be inferred from module's class name, but it's recommended to set it explicitly for clarity.
    // The module will be accessible from `requireNativeModule('ExpoSpeechTranscriber')` in JavaScript.
    Name("ExpoSpeechTranscriber")

    // Defines event names that the module can send to JavaScript.
    Events("onTranscriptionProgress", "onTranscriptionError")

    // Main transcription function - takes audio file path, returns transcribed text
    AsyncFunction("transcribeAudio") { (audioFilePath: String?) async throws -> String in
      guard let audioFilePath = audioFilePath else {
        throw NSError(domain: "ExpoSpeechTranscriber", code: 400, userInfo: [NSLocalizedDescriptionKey: "Audio file path is required"])
      }
      
      let url = URL(fileURLWithPath: audioFilePath)
      let transcription = await self.transcribeAudio(url: url)
        print(transcription)
      return transcription
    }

    // Optional: Request speech recognition permission
    AsyncFunction("requestPermissions") { () async -> String in
        let hasPermission: String = await self.requestTranscribePermissions()
        return hasPermission
    }
  }
}
