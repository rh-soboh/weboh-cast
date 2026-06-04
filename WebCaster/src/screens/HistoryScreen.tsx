import React, { useState, useMemo } from 'react';
import {
  View, Text, TextInput, TouchableOpacity, FlatList, StyleSheet, SafeAreaView, Alert,
} from 'react-native';
import { Colors } from '../theme/colors';
import { HistoryEntry } from '../models/types';
import { Storage } from '../services/storage/PersistenceController';

interface Props {
  history: HistoryEntry[];
  setHistory: React.Dispatch<React.SetStateAction<HistoryEntry[]>>;
  navigateToURL: (url: string) => void;
}

function formatDate(ts: number): string {
  const d = new Date(ts);
  const now = new Date();
  if (d.toDateString() === now.toDateString()) {
    return d.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
  }
  const yesterday = new Date(now);
  yesterday.setDate(yesterday.getDate() - 1);
  if (d.toDateString() === yesterday.toDateString()) {
    return 'Yesterday';
  }
  return d.toLocaleDateString([], { month: 'short', day: 'numeric' });
}

export function HistoryScreen({ history, setHistory, navigateToURL }: Props) {
  const [search, setSearch] = useState('');

  const filtered = useMemo(() => {
    if (!search) return history;
    const q = search.toLowerCase();
    return history.filter(h => h.title.toLowerCase().includes(q) || h.url.toLowerCase().includes(q));
  }, [history, search]);

  const deleteEntry = (id: string) => {
    setHistory(prev => {
      const updated = prev.filter(h => h.id !== id);
      Storage.saveHistory(updated);
      return updated;
    });
  };

  const clearAll = () => {
    Alert.alert('Clear History', 'Delete all browsing history?', [
      { text: 'Cancel', style: 'cancel' },
      {
        text: 'Clear', style: 'destructive',
        onPress: () => { setHistory([]); Storage.clearHistory(); },
      },
    ]);
  };

  return (
    <SafeAreaView style={styles.container}>
      <View style={styles.header}>
        <Text style={styles.title}>History</Text>
        {history.length > 0 && (
          <TouchableOpacity onPress={clearAll}>
            <Text style={styles.clearBtn}>Clear All</Text>
          </TouchableOpacity>
        )}
      </View>

      <View style={styles.searchBox}>
        <TextInput
          style={styles.searchInput}
          value={search}
          onChangeText={setSearch}
          placeholder="Search history..."
          placeholderTextColor={Colors.textSecondary}
        />
      </View>

      <FlatList
        data={filtered}
        keyExtractor={item => item.id}
        renderItem={({ item }) => (
          <TouchableOpacity
            style={styles.row}
            onPress={() => navigateToURL(item.url)}
            onLongPress={() => {
              Alert.alert('Delete', `Remove "${item.title}"?`, [
                { text: 'Cancel', style: 'cancel' },
                { text: 'Delete', style: 'destructive', onPress: () => deleteEntry(item.id) },
              ]);
            }}
          >
            <View style={styles.rowContent}>
              <Text style={styles.rowTitle} numberOfLines={1}>{item.title}</Text>
              <Text style={styles.rowUrl} numberOfLines={1}>{item.url}</Text>
            </View>
            <Text style={styles.rowTime}>{formatDate(item.visitedAt)}</Text>
          </TouchableOpacity>
        )}
        ListEmptyComponent={
          <View style={styles.empty}>
            <Text style={styles.emptyText}>No history yet</Text>
          </View>
        }
      />
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: Colors.background },
  header: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', paddingHorizontal: 16, paddingTop: 12, paddingBottom: 8 },
  title: { color: Colors.text, fontSize: 28, fontWeight: '700' },
  clearBtn: { color: Colors.red, fontSize: 15 },
  searchBox: { paddingHorizontal: 16, paddingBottom: 8 },
  searchInput: { backgroundColor: Colors.surface, color: Colors.text, borderRadius: 10, paddingHorizontal: 12, height: 38, fontSize: 14 },
  row: { flexDirection: 'row', alignItems: 'center', paddingVertical: 12, paddingHorizontal: 16, borderBottomWidth: 0.5, borderBottomColor: Colors.border },
  rowContent: { flex: 1, marginRight: 8 },
  rowTitle: { color: Colors.text, fontSize: 15 },
  rowUrl: { color: Colors.textSecondary, fontSize: 12, marginTop: 2 },
  rowTime: { color: Colors.textSecondary, fontSize: 12 },
  empty: { alignItems: 'center', marginTop: 60 },
  emptyText: { color: Colors.textSecondary, fontSize: 16 },
});
