import React, { useState, useCallback } from 'react';
import {
  View, Text, TouchableOpacity, FlatList, StyleSheet, SafeAreaView, Alert, TextInput, Modal,
} from 'react-native';
import { Colors } from '../theme/colors';
import { PlaylistItem, DetectedVideo, Playlist } from '../models/types';
import { Storage } from '../services/storage/PersistenceController';

interface Props {
  queue: PlaylistItem[];
  setQueue: React.Dispatch<React.SetStateAction<PlaylistItem[]>>;
  onPlay: (video: DetectedVideo) => void;
}

export function QueueScreen({ queue, setQueue, onPlay }: Props) {
  const [playlists, setPlaylists] = useState<Playlist[]>([]);
  const [showSaveModal, setShowSaveModal] = useState(false);
  const [playlistName, setPlaylistName] = useState('');
  const [showPlaylists, setShowPlaylists] = useState(false);

  React.useEffect(() => {
    Storage.loadPlaylists().then(setPlaylists);
  }, []);

  const removeFromQueue = useCallback((id: string) => {
    setQueue(prev => {
      const updated = prev.filter(item => item.id !== id);
      Storage.saveQueue(updated);
      return updated;
    });
  }, [setQueue]);

  const clearQueue = () => {
    Alert.alert('Clear Queue', 'Remove all items?', [
      { text: 'Cancel', style: 'cancel' },
      { text: 'Clear', style: 'destructive', onPress: () => { setQueue([]); Storage.saveQueue([]); } },
    ]);
  };

  const moveItem = (fromIndex: number, toIndex: number) => {
    if (toIndex < 0 || toIndex >= queue.length) return;
    setQueue(prev => {
      const updated = [...prev];
      const [moved] = updated.splice(fromIndex, 1);
      updated.splice(toIndex, 0, moved);
      Storage.saveQueue(updated);
      return updated;
    });
  };

  const saveAsPlaylist = () => {
    if (!playlistName.trim() || queue.length === 0) return;
    const playlist: Playlist = {
      id: Date.now().toString(36),
      name: playlistName.trim(),
      items: queue,
      createdAt: Date.now(),
    };
    const updated = [...playlists, playlist];
    setPlaylists(updated);
    Storage.savePlaylists(updated);
    setShowSaveModal(false);
    setPlaylistName('');
  };

  const loadPlaylist = (playlist: Playlist) => {
    setQueue(playlist.items);
    Storage.saveQueue(playlist.items);
    setShowPlaylists(false);
  };

  const deletePlaylist = (id: string) => {
    const updated = playlists.filter(p => p.id !== id);
    setPlaylists(updated);
    Storage.savePlaylists(updated);
  };

  return (
    <SafeAreaView style={styles.container}>
      <View style={styles.header}>
        <Text style={styles.title}>Queue</Text>
        <View style={styles.headerActions}>
          <TouchableOpacity onPress={() => setShowPlaylists(true)}>
            <Text style={styles.headerBtn}>Playlists</Text>
          </TouchableOpacity>
          {queue.length > 0 && (
            <>
              <TouchableOpacity onPress={() => setShowSaveModal(true)}>
                <Text style={styles.headerBtn}>Save</Text>
              </TouchableOpacity>
              <TouchableOpacity onPress={clearQueue}>
                <Text style={[styles.headerBtn, { color: Colors.red }]}>Clear</Text>
              </TouchableOpacity>
            </>
          )}
        </View>
      </View>

      <FlatList
        data={queue}
        keyExtractor={item => item.id}
        renderItem={({ item, index }) => (
          <View style={styles.row}>
            <View style={styles.reorderBtns}>
              <TouchableOpacity onPress={() => moveItem(index, index - 1)} disabled={index === 0}>
                <Text style={[styles.reorderIcon, index === 0 && styles.disabled]}>▲</Text>
              </TouchableOpacity>
              <TouchableOpacity onPress={() => moveItem(index, index + 1)} disabled={index === queue.length - 1}>
                <Text style={[styles.reorderIcon, index === queue.length - 1 && styles.disabled]}>▼</Text>
              </TouchableOpacity>
            </View>
            <TouchableOpacity style={styles.rowContent} onPress={() => onPlay(item.video)}>
              <Text style={styles.rowTitle} numberOfLines={1}>{item.video.title}</Text>
              <Text style={styles.rowMeta}>
                {item.video.format.toUpperCase()}
                {item.video.resolution ? ` • ${item.video.resolution}` : ''}
              </Text>
            </TouchableOpacity>
            <TouchableOpacity onPress={() => removeFromQueue(item.id)} style={styles.removeBtn}>
              <Text style={styles.removeText}>✕</Text>
            </TouchableOpacity>
          </View>
        )}
        ListEmptyComponent={
          <View style={styles.empty}>
            <Text style={styles.emptyText}>Queue is empty</Text>
            <Text style={styles.emptyHint}>Detected videos can be added from the browser</Text>
          </View>
        }
      />

      <Modal visible={showSaveModal} transparent animationType="fade">
        <View style={styles.modalOverlay}>
          <View style={styles.modal}>
            <Text style={styles.modalTitle}>Save as Playlist</Text>
            <TextInput
              style={styles.modalInput}
              value={playlistName}
              onChangeText={setPlaylistName}
              placeholder="Playlist name"
              placeholderTextColor={Colors.textSecondary}
              autoFocus
            />
            <View style={styles.modalActions}>
              <TouchableOpacity onPress={() => setShowSaveModal(false)}>
                <Text style={styles.modalCancel}>Cancel</Text>
              </TouchableOpacity>
              <TouchableOpacity onPress={saveAsPlaylist}>
                <Text style={styles.modalSave}>Save</Text>
              </TouchableOpacity>
            </View>
          </View>
        </View>
      </Modal>

      <Modal visible={showPlaylists} transparent animationType="slide">
        <View style={styles.modalOverlay}>
          <View style={styles.playlistsModal}>
            <View style={styles.playlistsHeader}>
              <Text style={styles.playlistsTitle}>Saved Playlists</Text>
              <TouchableOpacity onPress={() => setShowPlaylists(false)}>
                <Text style={styles.modalSave}>Done</Text>
              </TouchableOpacity>
            </View>
            <FlatList
              data={playlists}
              keyExtractor={item => item.id}
              renderItem={({ item }) => (
                <TouchableOpacity style={styles.playlistRow} onPress={() => loadPlaylist(item)}>
                  <View style={styles.rowContent}>
                    <Text style={styles.rowTitle}>{item.name}</Text>
                    <Text style={styles.rowMeta}>{item.items.length} item{item.items.length !== 1 ? 's' : ''}</Text>
                  </View>
                  <TouchableOpacity onPress={() => deletePlaylist(item.id)}>
                    <Text style={styles.removeText}>✕</Text>
                  </TouchableOpacity>
                </TouchableOpacity>
              )}
              ListEmptyComponent={
                <View style={styles.empty}>
                  <Text style={styles.emptyText}>No saved playlists</Text>
                </View>
              }
            />
          </View>
        </View>
      </Modal>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: Colors.background },
  header: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', paddingHorizontal: 16, paddingTop: 12, paddingBottom: 8 },
  title: { color: Colors.text, fontSize: 28, fontWeight: '700' },
  headerActions: { flexDirection: 'row', gap: 16 },
  headerBtn: { color: Colors.orange, fontSize: 15, fontWeight: '600' },
  row: { flexDirection: 'row', alignItems: 'center', paddingVertical: 10, paddingHorizontal: 16, borderBottomWidth: 0.5, borderBottomColor: Colors.border },
  reorderBtns: { marginRight: 10, gap: 2 },
  reorderIcon: { color: Colors.textSecondary, fontSize: 14 },
  disabled: { opacity: 0.3 },
  rowContent: { flex: 1 },
  rowTitle: { color: Colors.text, fontSize: 15 },
  rowMeta: { color: Colors.textSecondary, fontSize: 12, marginTop: 2 },
  removeBtn: { padding: 8 },
  removeText: { color: Colors.textSecondary, fontSize: 16 },
  empty: { alignItems: 'center', marginTop: 60 },
  emptyText: { color: Colors.textSecondary, fontSize: 16 },
  emptyHint: { color: Colors.textSecondary, fontSize: 13, marginTop: 4 },
  modalOverlay: { flex: 1, backgroundColor: 'rgba(0,0,0,0.6)', justifyContent: 'center', alignItems: 'center' },
  modal: { backgroundColor: Colors.surface, borderRadius: 16, padding: 20, width: '80%' },
  modalTitle: { color: Colors.text, fontSize: 18, fontWeight: '600', marginBottom: 12 },
  modalInput: { backgroundColor: Colors.surfaceElevated, color: Colors.text, borderRadius: 10, paddingHorizontal: 12, height: 40, fontSize: 15, marginBottom: 16 },
  modalActions: { flexDirection: 'row', justifyContent: 'flex-end', gap: 16 },
  modalCancel: { color: Colors.textSecondary, fontSize: 16 },
  modalSave: { color: Colors.orange, fontSize: 16, fontWeight: '600' },
  playlistsModal: { backgroundColor: Colors.surface, borderTopLeftRadius: 16, borderTopRightRadius: 16, maxHeight: '70%', paddingBottom: 30, width: '100%', position: 'absolute', bottom: 0 },
  playlistsHeader: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', padding: 16, borderBottomWidth: 0.5, borderBottomColor: Colors.border },
  playlistsTitle: { color: Colors.text, fontSize: 17, fontWeight: '600' },
  playlistRow: { flexDirection: 'row', alignItems: 'center', paddingVertical: 12, paddingHorizontal: 16, borderBottomWidth: 0.5, borderBottomColor: Colors.border },
});
