import React, { useEffect, useState } from 'react';
import {
  View, Text, TouchableOpacity, FlatList, StyleSheet, SafeAreaView, ActivityIndicator,
} from 'react-native';
import { useNavigation } from '@react-navigation/native';
import { Colors } from '../theme/colors';
import { CastDevice, DetectedVideo } from '../models/types';
import { CastingManager, CastingState } from '../services/casting/CastingManager';

interface Props {
  video: DetectedVideo;
  castingState: CastingState;
}

export function DevicePickerSheet({ video, castingState }: Props) {
  const navigation = useNavigation();
  const [localState, setLocalState] = useState(castingState);

  useEffect(() => {
    const unsub = CastingManager.subscribe(setLocalState);
    CastingManager.startDiscovery();
    return unsub;
  }, []);

  const selectDevice = async (device: CastDevice) => {
    await CastingManager.connect(device);
    await CastingManager.cast(video);
    navigation.goBack();
  };

  const protocolIcon = (protocol: string) => {
    switch (protocol) {
      case 'dlna': return '📡';
      case 'chromecast': return '📺';
      case 'airplay': return '📱';
      default: return '•';
    }
  };

  return (
    <SafeAreaView style={styles.container}>
      <View style={styles.header}>
        <Text style={styles.title}>Cast to Device</Text>
        <TouchableOpacity onPress={() => navigation.goBack()}>
          <Text style={styles.closeBtn}>Done</Text>
        </TouchableOpacity>
      </View>

      <View style={styles.videoInfo}>
        <Text style={styles.videoTitle} numberOfLines={1}>{video.title}</Text>
        <Text style={styles.videoFormat}>{video.format.toUpperCase()}</Text>
      </View>

      {localState.isDiscovering && (
        <View style={styles.discovering}>
          <ActivityIndicator color={Colors.orange} />
          <Text style={styles.discoveringText}>Searching for devices...</Text>
        </View>
      )}

      {localState.error && (
        <View style={styles.errorBox}>
          <Text style={styles.errorText}>{localState.error}</Text>
          <TouchableOpacity onPress={() => CastingManager.clearError()}>
            <Text style={styles.dismissText}>Dismiss</Text>
          </TouchableOpacity>
        </View>
      )}

      <FlatList
        data={localState.devices}
        keyExtractor={item => item.id}
        renderItem={({ item }) => (
          <TouchableOpacity style={styles.deviceRow} onPress={() => selectDevice(item)}>
            <Text style={styles.deviceIcon}>{protocolIcon(item.protocol)}</Text>
            <View style={styles.deviceInfo}>
              <Text style={styles.deviceName}>{item.name}</Text>
              <Text style={styles.deviceMeta}>
                {item.protocol.toUpperCase()} • {item.host}:{item.port}
              </Text>
            </View>
            {localState.connectedDevice?.id === item.id && (
              <Text style={styles.connectedBadge}>Connected</Text>
            )}
          </TouchableOpacity>
        )}
        ListEmptyComponent={
          !localState.isDiscovering ? (
            <View style={styles.empty}>
              <Text style={styles.emptyText}>No devices found</Text>
              <Text style={styles.emptyHint}>
                Make sure your TV or speaker is on the same Wi-Fi network
              </Text>
              <TouchableOpacity
                style={styles.retryBtn}
                onPress={() => CastingManager.startDiscovery()}
              >
                <Text style={styles.retryText}>Retry</Text>
              </TouchableOpacity>
            </View>
          ) : null
        }
      />
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: Colors.background },
  header: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', paddingHorizontal: 16, paddingVertical: 12, borderBottomWidth: 0.5, borderBottomColor: Colors.border },
  title: { color: Colors.text, fontSize: 18, fontWeight: '600' },
  closeBtn: { color: Colors.orange, fontSize: 16, fontWeight: '600' },
  videoInfo: { flexDirection: 'row', alignItems: 'center', paddingHorizontal: 16, paddingVertical: 10, backgroundColor: Colors.surface, borderBottomWidth: 0.5, borderBottomColor: Colors.border },
  videoTitle: { flex: 1, color: Colors.text, fontSize: 14 },
  videoFormat: { color: Colors.orange, fontSize: 12, fontWeight: '600', marginLeft: 8 },
  discovering: { flexDirection: 'row', alignItems: 'center', justifyContent: 'center', padding: 16, gap: 8 },
  discoveringText: { color: Colors.textSecondary, fontSize: 14 },
  errorBox: { flexDirection: 'row', alignItems: 'center', backgroundColor: 'rgba(255,68,68,0.15)', paddingHorizontal: 16, paddingVertical: 10 },
  errorText: { flex: 1, color: Colors.red, fontSize: 13 },
  dismissText: { color: Colors.red, fontSize: 13, fontWeight: '600' },
  deviceRow: { flexDirection: 'row', alignItems: 'center', paddingVertical: 14, paddingHorizontal: 16, borderBottomWidth: 0.5, borderBottomColor: Colors.border },
  deviceIcon: { fontSize: 24, marginRight: 12 },
  deviceInfo: { flex: 1 },
  deviceName: { color: Colors.text, fontSize: 16, fontWeight: '500' },
  deviceMeta: { color: Colors.textSecondary, fontSize: 12, marginTop: 2 },
  connectedBadge: { color: Colors.green, fontSize: 12, fontWeight: '600' },
  empty: { alignItems: 'center', marginTop: 60, paddingHorizontal: 32 },
  emptyText: { color: Colors.textSecondary, fontSize: 16 },
  emptyHint: { color: Colors.textSecondary, fontSize: 13, marginTop: 8, textAlign: 'center' },
  retryBtn: { marginTop: 16, paddingHorizontal: 24, paddingVertical: 10, backgroundColor: Colors.orange, borderRadius: 20 },
  retryText: { color: Colors.white, fontWeight: '600' },
});
