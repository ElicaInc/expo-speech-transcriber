// Reexport the native module. On web, it will be resolved to ExpoSpeechTranscriberModule.web.ts
// and on native platforms to ExpoSpeechTranscriberModule.ts
import ExpoSpeechTranscriberModule from './ExpoSpeechTranscriberModule';

export * from './ExpoSpeechTranscriber.types';

export async function transcribeAudio(audioFilePath: string): Promise<string> {
  try {
    return await ExpoSpeechTranscriberModule.transcribeAudio(audioFilePath);
  } catch (error) {
    console.error('Transcription error:', error);
    throw error;
  }
}

export async function requestPermissions(): Promise<string> {
  try {
    return await ExpoSpeechTranscriberModule.requestPermissions();
  } catch (error) {
    console.error('Permission error:', error);
    throw error;
  }
}
