// Reexport the native module. On web, it will be resolved to ExpoSpeechTranscriberModule.web.ts
// and on native platforms to ExpoSpeechTranscriberModule.ts
import ExpoSpeechTranscriberModule from './ExpoSpeechTranscriberModule';

export * from './ExpoSpeechTranscriber.types';

export function transcribeAudioWithSFRecognizer(audioFilePath: string): Promise<string> {
  return ExpoSpeechTranscriberModule.transcribeAudioWithSFRecognizer(audioFilePath);
}

export function transcribeAudioWithAnalyzer(audioFilePath: string): Promise<string> {
  return ExpoSpeechTranscriberModule.transcribeAudioWithAnalyzer(audioFilePath);
}

export function requestPermissions(): Promise<string> {
  return ExpoSpeechTranscriberModule.requestPermissions();
}

export function isAnalyzerAvailable(): boolean {
  return ExpoSpeechTranscriberModule.isAnalyzerAvailable();
}
