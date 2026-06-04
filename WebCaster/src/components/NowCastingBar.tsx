import React from 'react';
import { View, Text, TouchableOpacity, StyleSheet } from 'react-native';
import { Colors } from '../theme/colors';
import { CastDevice } from '../models/types';
import { CastingManager } from '../services/casting/CastingManager';

interface Props {
  device: CastDevice;
}

export function NowCastingBar({ device }: Props) {
  return (
    <View style={styles.bar}>
      <View style={styles.info}>
        <Text style={styles.label}>Casting to</Text>
        <Text style={styles.deviceName} numberOfLines={1}>{device.name}</Text>
      </View>
      <View style={styles.controls}>
        {device.state === 'playing' ? (
          <TouchableOpacity onPress={() => CastingManager.pauseCasting()} style={styles.btn}>
            <Text style={styles.btnText}>⏸</Text>
          </TouchableOpacity>
        ) : device.state === 'paused' ? (
          <TouchableOpacity onPress={() => CastingManager.resumeCasting()} style={styles.btn}>
            <Text style={styles.btnText}>▶</Text>
          </TouchableOpacity>
        ) : null}
        <TouchableOpacity onPress={() => CastingManager.stopCasting()} style={styles.btn}>
          <Text style={styles.btnText}>⏹</Text>
        </TouchableOpacity>
        <TouchableOpacity onPress={() => CastingManager.disconnect()} style={styles.btn}>
          <Text style={[styles.btnText, { color: Colors.red }]}>✕</Text>
        </TouchableOpacity>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  bar: { flexDirection: 'row', alignItems: 'center', backgroundColor: Colors.orange, paddingHorizontal: 12, paddingVertical: 8 },
  info: { flex: 1 },
  label: { color: Colors.white, fontSize: 11, opacity: 0.8 },
  deviceName: { color: Colors.white, fontSize: 14, fontWeight: '600' },
  controls: { flexDirection: 'row', gap: 8 },
  btn: { width: 32, height: 32, borderRadius: 16, backgroundColor: 'rgba(0,0,0,0.2)', justifyContent: 'center', alignItems: 'center' },
  btnText: { color: Colors.white, fontSize: 16 },
});
