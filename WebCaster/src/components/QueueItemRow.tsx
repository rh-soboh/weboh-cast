import React from 'react';
import { View, Text, TouchableOpacity, StyleSheet } from 'react-native';
import { Colors } from '../theme/colors';
import { PlaylistItem } from '../models/types';

interface Props {
  item: PlaylistItem;
  onPlay: () => void;
  onRemove: () => void;
  isActive?: boolean;
}

export function QueueItemRow({ item, onPlay, onRemove, isActive }: Props) {
  return (
    <TouchableOpacity
      style={[styles.row, isActive && styles.activeRow]}
      onPress={onPlay}
    >
      <View style={styles.info}>
        <Text style={styles.title} numberOfLines={1}>{item.video.title}</Text>
        <Text style={styles.meta}>
          {item.video.format.toUpperCase()}
          {item.video.resolution ? ` • ${item.video.resolution}` : ''}
        </Text>
      </View>
      {isActive && <Text style={styles.nowPlaying}>Now Playing</Text>}
      <TouchableOpacity onPress={onRemove} style={styles.removeBtn}>
        <Text style={styles.removeIcon}>✕</Text>
      </TouchableOpacity>
    </TouchableOpacity>
  );
}

const styles = StyleSheet.create({
  row: { flexDirection: 'row', alignItems: 'center', paddingVertical: 10, paddingHorizontal: 16, borderBottomWidth: 0.5, borderBottomColor: Colors.border },
  activeRow: { backgroundColor: Colors.orangeLight },
  info: { flex: 1, marginRight: 8 },
  title: { color: Colors.text, fontSize: 14, fontWeight: '500' },
  meta: { color: Colors.textSecondary, fontSize: 12, marginTop: 2 },
  nowPlaying: { color: Colors.orange, fontSize: 11, fontWeight: '600', marginRight: 8 },
  removeBtn: { padding: 6 },
  removeIcon: { color: Colors.textSecondary, fontSize: 14 },
});
