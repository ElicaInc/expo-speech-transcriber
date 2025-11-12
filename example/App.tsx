import React, { useEffect, useState } from 'react';
import { View, Text, TouchableOpacity, StyleSheet, Alert, ScrollView } from 'react-native';
import {
  useAudioRecorder,
  AudioModule,
  RecordingPresets,
  setAudioModeAsync,
  useAudioRecorderState,
} from 'expo-audio';
import { Ionicons } from '@expo/vector-icons';
import * as SpeechTranscriber from "expo-speech-transcriber"

const App = () => {
  const [transcription, setTranscription] = useState('');
  const [lastRecordingUri, setLastRecordingUri] = useState<string | null>(null);
  const [analyzerAvailable, setAnalyzerAvailable] = useState(false);
  const audioRecorder = useAudioRecorder(RecordingPresets.HIGH_QUALITY);
  const recorderState = useAudioRecorderState(audioRecorder);

  useEffect(() => {
    (async () => {
      // Request microphone permission
      const status = await AudioModule.requestRecordingPermissionsAsync();
      if (!status.granted) {
        Alert.alert('Permission denied', 'Microphone access is required.');
        return;
      }

      // Request speech recognition permission
      const speechPermission = await SpeechTranscriber.requestPermissions();
      if (speechPermission !== 'authorized') {
        Alert.alert('Permission Required', 'Speech recognition permission is needed.');
        return;
      }

      // Check if new Analyzer API is available
      const hasAnalyzer = SpeechTranscriber.isAnalyzerAvailable();
      setAnalyzerAvailable(hasAnalyzer);
      console.log('Analyzer API available:', hasAnalyzer);

      await setAudioModeAsync({
        playsInSilentMode: true,
        allowsRecording: true,
      });
    })();
  }, []);

  const startRecording = async () => {
    try {
      setTranscription('');
      await audioRecorder.prepareToRecordAsync();
      audioRecorder.record();
    } catch (error) {
      Alert.alert('Error', 'Failed to start recording.');
    }
  };

  const stopRecording = async () => {
    try {
      await audioRecorder.stop();
      const uri = audioRecorder.uri;
      
      if (!uri) {
        Alert.alert('Error', 'No recording URI available');
        return;
      }
      
      setLastRecordingUri(uri);
      console.log('Recording saved:', uri);
    } catch (error) {
      Alert.alert('Error', 'Failed to stop recording.');
    }
  };

  const transcribeWithLegacy = async () => {
    if (!lastRecordingUri) return;
    
    try {
      setTranscription('Transcribing...');
      const result = await SpeechTranscriber.transcribeAudioWithSFRecognizer(lastRecordingUri);
      console.log('Transcription result:', result);
      setTranscription(result || "No speech detected");
    } catch (error) {
      console.error('Transcription error:', error);
      Alert.alert('Error', `Transcription failed: ${error instanceof Error ? error.message : String(error)}`);
      setTranscription('');
    }
  };

  const transcribeWithAnalyzer = async () => {
    if (!lastRecordingUri) return;
    
    try {
      setTranscription('Transcribing with improved model...');
      const result = await SpeechTranscriber.transcribeAudioWithAnalyzer(lastRecordingUri);
      console.log('Analyzer transcription:', result);
      setTranscription(result || "No speech detected");
    } catch (error) {
      console.error('Analyzer error:', error);
      Alert.alert('Error', `Transcription failed: ${error instanceof Error ? error.message : String(error)}`);
      setTranscription('');
    }
  };

  const handleRecordPress = async () => {
    if (recorderState?.isRecording) {
      await stopRecording();
    } else {
      await startRecording();
    }
  };

  const isRecording = recorderState?.isRecording ?? false;

  return (
    <ScrollView contentContainerStyle={styles.container}>
      <Text style={styles.title}>🎙️ Speech Transcriber</Text>
      <Text style={styles.subtitle}>
        Record audio and transcribe it to text
      </Text>

      {/* Recording Control */}
      <TouchableOpacity
        onPress={handleRecordPress}
        style={[styles.button, styles.recordButton, isRecording && styles.recordingButton]}
      >
        <Ionicons
          name={isRecording ? 'stop-circle' : 'mic'}
          size={32}
          color="#FFF"
        />
        <Text style={styles.buttonText}>
          {isRecording ? 'Stop Recording' : 'Start Recording'}
        </Text>
      </TouchableOpacity>

      {recorderState?.isRecording && (
        <Text style={styles.recordingTime}>
          Recording: {Math.floor((recorderState?.durationMillis ?? 0) / 1000)}s
        </Text>
      )}

      {/* Transcription Options */}
      {lastRecordingUri && !isRecording && (
        <View style={styles.optionsContainer}>
          <Text style={styles.optionsTitle}>Choose transcription method:</Text>
          
          <TouchableOpacity
            onPress={transcribeWithLegacy}
            style={[styles.button, styles.transcribeButton]}
          >
            <Ionicons name="text" size={24} color="#FFF" />
            <Text style={styles.buttonText}>Standard Transcription</Text>
          </TouchableOpacity>

          {analyzerAvailable ? (
            <TouchableOpacity
              onPress={transcribeWithAnalyzer}
              style={[styles.button, styles.analyzerButton]}
            >
              <Ionicons name="sparkles" size={24} color="#FFF" />
              <View style={styles.buttonTextContainer}>
                <Text style={styles.buttonText}>Enhanced Transcription</Text>
                <Text style={styles.buttonSubtext}>iOS 26+ </Text>
              </View>
            </TouchableOpacity>
          ) : (
            <View style={styles.unavailableContainer}>
              <Ionicons name="information-circle-outline" size={20} color="#999" />
              <Text style={styles.unavailableText}>
                Enhanced transcription requires iOS 26+
              </Text>
            </View>
          )}
        </View>
      )}

      {/* Transcription Result */}
      {transcription && (
        <View style={styles.transcriptionContainer}>
          <Text style={styles.transcriptionTitle}>📝 Transcription:</Text>
          <Text style={styles.transcriptionText}>{transcription}</Text>
        </View>
      )}

      {!lastRecordingUri && !isRecording && (
        <Text style={styles.hintText}>
          Tap the microphone to start recording
        </Text>
      )}
    </ScrollView>
  );
};

const styles = StyleSheet.create({
  container: {
    flexGrow: 1,
    justifyContent: 'center',
    alignItems: 'center',
    padding: 20,
    backgroundColor: '#f5f5f5',
  },
  title: {
    fontSize: 28,
    fontWeight: 'bold',
    marginBottom: 8,
    color: '#333',
  },
  subtitle: {
    fontSize: 16,
    color: '#666',
    marginBottom: 30,
    textAlign: 'center',
  },
  button: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    paddingVertical: 15,
    paddingHorizontal: 30,
    borderRadius: 12,
    marginVertical: 8,
    minWidth: 280,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.1,
    shadowRadius: 4,
    elevation: 3,
  },
  recordButton: {
    backgroundColor: '#007bff',
  },
  recordingButton: {
    backgroundColor: '#dc3545',
  },
  transcribeButton: {
    backgroundColor: '#6c757d',
  },
  analyzerButton: {
    backgroundColor: '#28a745',
  },
  buttonText: {
    color: '#fff',
    fontSize: 18,
    fontWeight: '600',
    marginLeft: 10,
  },
  buttonTextContainer: {
    marginLeft: 10,
  },
  buttonSubtext: {
    color: '#fff',
    fontSize: 12,
    opacity: 0.9,
  },
  recordingTime: {
    fontSize: 16,
    color: '#dc3545',
    marginTop: 10,
    fontWeight: '600',
  },
  optionsContainer: {
    marginTop: 20,
    width: '100%',
    alignItems: 'center',
  },
  optionsTitle: {
    fontSize: 18,
    fontWeight: '600',
    color: '#333',
    marginBottom: 15,
  },
  unavailableContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    padding: 15,
    backgroundColor: '#f8f9fa',
    borderRadius: 12,
    marginTop: 8,
    minWidth: 280,
  },
  unavailableText: {
    fontSize: 14,
    color: '#999',
    marginLeft: 8,
    flex: 1,
  },
  transcriptionContainer: {
    marginTop: 30,
    padding: 20,
    backgroundColor: '#fff',
    borderRadius: 12,
    width: '100%',
    maxWidth: 400,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.1,
    shadowRadius: 8,
    elevation: 5,
  },
  transcriptionTitle: {
    fontSize: 18,
    fontWeight: 'bold',
    marginBottom: 12,
    color: '#333',
  },
  transcriptionText: {
    fontSize: 16,
    color: '#555',
    lineHeight: 24,
  },
  hintText: {
    fontSize: 14,
    color: '#999',
    marginTop: 20,
    textAlign: 'center',
  },
});

export default App;