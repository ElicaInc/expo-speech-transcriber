# expo-speech-transcriber

On-device speech transcription for Expo apps using Apple's Speech framework.

## Features

- 🎯 **On-device transcription** - Works offline, privacy-focused
- 🚀 **Two APIs** - Legacy SFSpeechRecognizer (iOS 13+) and SpeechAnalyzer (iOS 26+)
- 📦 **Easy integration** - Auto-configures permissions
- 🔒 **Secure** - All processing happens on device

> **Note:** While the newer SpeechAnalyzer API (iOS 26+) is available, I recommend using `transcribeAudioWithSFRecognizer()` as it's more reliable and has broader device support. The SFSpeechRecognizer API is battle-tested and works across all iOS versions 13+.

## Installation

```bash
npx expo install expo-speech-transcriber expo-audio
```

Add the plugin to your `app.json`:

```json
{
  "expo": {
    "plugins": [
      "expo-audio",
      "expo-speech-transcriber"
    ]
  }
}
```

### Custom permission message (optional):

```json
{
  "expo": {
    "plugins": [
      "expo-audio",
      [
        "expo-speech-transcriber",
        {
          "speechRecognitionPermission": "We need speech recognition to transcribe your recordings"
        }
      ]
    ]
  }
}
```

## Usage

### Recommended: Using SFSpeechRecognizer (iOS 13+)

```typescript
import * as SpeechTranscriber from 'expo-speech-transcriber';
import { useAudioRecorder, RecordingPresets } from 'expo-audio';

// Request permissions first
const permission = await SpeechTranscriber.requestPermissions();
if (permission !== 'authorized') {
  console.log('Permission denied');
  return;
}

// Record audio with expo-audio
const audioRecorder = useAudioRecorder(RecordingPresets.HIGH_QUALITY);
await audioRecorder.record();
// ... user speaks ...
await audioRecorder.stop();
const audioUri = audioRecorder.uri;

// Transcribe with SFSpeechRecognizer (recommended)
const text = await SpeechTranscriber.transcribeAudioWithSFRecognizer(audioUri);
console.log('Transcription:', text);
```

### Alternative: Using SpeechAnalyzer (iOS 26+ only)

```typescript
// Check if the newer API is available
if (SpeechTranscriber.isAnalyzerAvailable()) {
  const text = await SpeechTranscriber.transcribeAudioWithAnalyzer(audioUri);
  console.log('Transcription:', text);
}
```

## API Reference

### `requestPermissions()`
Request speech recognition permission.

**Returns:** `Promise<string>` - `"authorized"`, `"denied"`, `"restricted"`, or `"notDetermined"`

### `transcribeAudioWithSFRecognizer(audioFilePath: string)` ⭐ Recommended
Transcribe audio using the reliable SFSpeechRecognizer API.

**Requires:** iOS 13+  
**Returns:** `Promise<string>` - Transcribed text

**Why use this?** Proven reliability, broader device support, and consistent results across all iOS versions.

### `transcribeAudioWithAnalyzer(audioFilePath: string)`
Transcribe audio using the newer SpeechAnalyzer API.

**Requires:** iOS 26+  
**Returns:** `Promise<string>` - Transcribed text

**Note:** This is a newer API with limited device support. Use `transcribeAudioWithSFRecognizer()` for production apps.

### `isAnalyzerAvailable()`
Check if SpeechAnalyzer API is available on this device.

**Returns:** `boolean` - `true` if iOS 26+, `false` otherwise

## Example

See the [example app](./example) for a complete implementation with recording UI.

## Requirements

- iOS 13.0+
- Expo SDK 52+
- `expo-audio` for recording

## Limitations

- **iOS only** - Android not supported (Speech framework is Apple-only)
- **English only** - Currently hardcoded to `en_US` locale
- **File size** - Best for short recordings (< 1 minute)
- **SpeechAnalyzer** - Requires iOS 26+, limited device availability

## API Comparison

| Feature | SFSpeechRecognizer | SpeechAnalyzer |
|---------|-------------------|----------------|
| iOS Version | 13+ | 26+ |
| Device Support | All modern iPhones | Latest iPhones only |
| Reliability | Proven & stable | Newer, less tested |
| **Recommendation** | ✅ **Use this** |

## License

MIT

## Contributing

Contributions welcome! Please open an issue or PR on [GitHub](https://github.com/DaveyEke/expo-speech-transcriber).

## Author

Dave Mkpa Eke - [GitHub](https://github.com/DaveyEke)