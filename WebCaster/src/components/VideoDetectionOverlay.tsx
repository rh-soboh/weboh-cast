import React from 'react';
import { View, Text, TouchableOpacity, StyleSheet, ScrollView } from 'react-native';
import { Colors } from '../theme/colors';
import { DetectedVideo } from '../models/types';

interface Props {
  videos: DetectedVideo[];
  expanded: boolean;
  onToggle: () => void;
  onPlay: (video: DetectedVideo) => void;
  onCast: (video: DetectedVideo) => void;
  onAddToQueue: (video: DetectedVideo) => void;
}

function formatSize(bytes?: number): string {
  if (!bytes) return '';
  if (bytes > 1048576) return `${(bytes / 1048576).toFixed(1)} MB`;
  if (bytes > 1024) return `${(bytes / 1024).toFixed(0)} KB`;
  return `${bytes} B`;
}

export function VideoDetectionOverlay({ videos, expanded, onToggle, onPlay, onCast, onAddToQueue }: Props) {
  return (
    <View style={styles.container}>
      <TouchableOpacity style={styles.badge} onPress={onToggle}>
        <Text style={styles.badgeText}>
          {videos.length} video{videos.length !== 1 ? 's' : ''} found
        </Text>
        <Text style={styles.chevron}>{expanded ? '▼' : '▲'}</Text>
      </TouchableOpacity>

      {expanded && (
        <ScrollView style={styles.list} nestedScrollEnabled>
          {videos.map((video) => (
            <View key={video.id} style={styles.videoItem}>
              <View style={styles.videoInfo}>
                <Text style={styles.videoTitle} numberOfLines={1}>{video.title}</Text>
                <Text style={styles.videoMeta}>
                  {video.format.toUpperCase()}
                  {video.resolution ? ` • ${video.resolution}` : ''}
                  {video.size ? ` • ${formatSize(video.size)}` : ''}
                </Text>
              </View>
              <View style={styles.videoActions}>
                <TouchableOpacity style={styles.actionBtn} onPress={() => onPlay(video)}>
                  <Text style={styles.actionText}>▶</Text>
                </TouchableOpacity>
                <TouchableOpacity style={styles.actionBtn} onPress={() => onCast(video)}>
                  <Text style={styles.actionText}>📺</Text>
                </TouchableOpacity>
                <TouchableOpacity style={styles.actionBtn} onPress={() => onAddToQueue(video)}>
                  <Text style={styles.actionText}>+</Text>
                </TouchableOpacity>
              </View>
            </View>
          ))}
        </ScrollView>
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  container: { position: 'absolute', bottom: 0, left: 0, right: 0 },
  badge: {
    flexDirection: 'row', alignItems: 'center', justifyContent: 'center',
    backgroundColor: Colors.orange, paddingVertical: 8, paddingHorizontal: 16,
    marginHorizontal: 16, marginBottom: 8, borderRadius: 20,
  },
  badgeText: { color: Colors.white, fontWeight: '600', fontSize: 14 },
  chevron: { color: Colors.white, fontSize: 12, marginLeft: 6 },
  list: { backgroundColor: Colors.surface, maxHeight: 250, borderTopWidth: 0.5, borderTopColor: Colors.border },
  videoItem: { flexDirection: 'row', alignItems: 'center', paddingVertical: 10, paddingHorizontal: 16, borderBottomWidth: 0.5, borderBottomColor: Colors.border },
  videoInfo: { flex: 1, marginRight: 8 },
  videoTitle: { color: Colors.text, fontSize: 14, fontWeight: '500' },
  videoMeta: { color: Colors.textSecondary, fontSize: 12, marginTop: 2 },
  videoActions: { flexDirection: 'row', gap: 8 },
  actionBtn: { width: 36, height: 36, borderRadius: 18, backgroundColor: Colors.surfaceElevated, justifyContent: 'center', alignItems: 'center' },
  actionText: { fontSize: 16 },
});
