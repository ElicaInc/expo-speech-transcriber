import React, { useState, useEffect } from 'react';
import { View, Text, TouchableOpacity, StyleSheet, Alert, ScrollView, Button } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import * as SpeechTranscriber from 'expo-speech-transcriber';

const App = () => {
  const { text, isFinal, error } = SpeechTranscriber.useRealTimeTranscription();
  const [isTranscribing, setIsTranscribing] = useState(false);

  useEffect(() => {
    if (isFinal) {
      setIsTranscribing(false);
    }
  }, [isFinal]);

  const handleStartTranscription = async () => {
    try {
      const speechPermission = await SpeechTranscriber.requestPermissions();
      if (speechPermission !== 'authorized') {
        Alert.alert('Permission Required', 'Speech recognition permission is needed.');
        return;
      }
      setIsTranscribing(true);
      await SpeechTranscriber.recordRealTimeAndTranscribe(); 
    } catch (err) {
      Alert.alert('Error', 'Failed to request permissions');
      setIsTranscribing(false);
    }
  };

  const handleStopTranscription = () => {
    SpeechTranscriber.stopListening();
    setIsTranscribing(false);
  };

  return (
    <ScrollView contentContainerStyle={styles.container}>
      <Text style={styles.title}>Live Transcription</Text>

      <TouchableOpacity
        onPress={handleStartTranscription}
        disabled={isTranscribing}
        style={[
          styles.button,
          styles.recordButton,
          isTranscribing && styles.disabled,
        ]}
      >
        <Ionicons name="mic" size={24} color="#FFF" />
        <Text style={styles.buttonText}>Start Transcription</Text>
      </TouchableOpacity>

      <TouchableOpacity
        onPress={handleStopTranscription}
        disabled={!isTranscribing}
        style={[styles.button, styles.stopButton, !isTranscribing && styles.disabled]}
      >
        <Ionicons name="stop-circle" size={24} color="#FFF" />
        <Text style={styles.buttonText}>Stop Transcription</Text>
      </TouchableOpacity>

      {isTranscribing && (
        <View style={styles.recordingIndicator}>
          <Ionicons name="radio-button-on" size={20} color="#dc3545" />
          <Text style={styles.recordingText}>Transcribing...</Text>
        </View>
      )}

      {error && (
        <View style={styles.errorContainer}>
          <Text style={styles.errorText}>Error: {error}</Text>
        </View>
      )}

      <Button onPress={ () => SpeechTranscriber.isAnalyzerAvailable()} title='Test Analyzer available'  />

      {text && (
        <View style={styles.transcriptionContainer}>
          <Text style={styles.transcriptionTitle}>Transcription:</Text>
          <Text style={styles.transcriptionText}>{text}</Text>
          {isFinal && <Text style={styles.finalText}>Final!</Text>}
        </View>
      )}

      {!isTranscribing && !text && (
        <Text style={styles.hintText}>
          Press "Start Transcription" to begin live transcription
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
  stopButton: {
    backgroundColor: '#dc3545',
  },
  disabled: {
    backgroundColor: '#ccc',
    opacity: 0.6,
  },
  buttonText: {
    color: '#fff',
    fontSize: 18,
    fontWeight: '600',
    marginLeft: 10,
  },
  recordingIndicator: {
    flexDirection: 'row',
    alignItems: 'center',
    marginTop: 20,
    padding: 15,
    backgroundColor: '#fff',
    borderRadius: 12,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.1,
    shadowRadius: 4,
    elevation: 3,
  },
  recordingText: {
    fontSize: 16,
    color: '#dc3545',
    marginLeft: 10,
    fontWeight: '600',
  },
  errorContainer: {
    marginTop: 20,
    padding: 15,
    backgroundColor: '#f8d7da',
    borderRadius: 12,
    width: '100%',
    maxWidth: 400,
  },
  errorText: {
    fontSize: 16,
    color: '#721c24',
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
  finalText: {
    fontSize: 14,
    color: '#28a745',
    fontWeight: 'bold',
    marginTop: 10,
  },
  hintText: {
    fontSize: 14,
    color: '#999',
    marginTop: 20,
    textAlign: 'center',
  },
});

export default App;