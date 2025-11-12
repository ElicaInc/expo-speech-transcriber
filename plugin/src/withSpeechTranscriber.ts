import { ConfigPlugin, IOSConfig } from 'expo/config-plugins';

const SPEECH_RECOGNITION_USAGE = 'Allow $(PRODUCT_NAME) to use speech recognition to transcribe audio';

const withSpeechTranscriber: ConfigPlugin<{ speechRecognitionPermission?: string | false } | void> = (
  config,
  { speechRecognitionPermission } = {}
) => {
  config = IOSConfig.Permissions.createPermissionsPlugin({
    NSSpeechRecognitionUsageDescription: SPEECH_RECOGNITION_USAGE,
  })(config, {
    NSSpeechRecognitionUsageDescription: speechRecognitionPermission,
  });

  return config;
};

export default withSpeechTranscriber;