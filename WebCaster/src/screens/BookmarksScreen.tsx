import React, { useState, useMemo } from 'react';
import {
  View, Text, TextInput, TouchableOpacity, FlatList, StyleSheet, SafeAreaView, Alert,
} from 'react-native';
import { Colors } from '../theme/colors';
import { Bookmark } from '../models/types';
import { Storage } from '../services/storage/PersistenceController';

interface Props {
  bookmarks: Bookmark[];
  setBookmarks: React.Dispatch<React.SetStateAction<Bookmark[]>>;
  navigateToURL: (url: string) => void;
}

export function BookmarksScreen({ bookmarks, setBookmarks, navigateToURL }: Props) {
  const [search, setSearch] = useState('');

  const filtered = useMemo(() => {
    if (!search) return bookmarks;
    const q = search.toLowerCase();
    return bookmarks.filter(b => b.title.toLowerCase().includes(q) || b.url.toLowerCase().includes(q));
  }, [bookmarks, search]);

  const deleteBookmark = (id: string) => {
    setBookmarks(prev => {
      const updated = prev.filter(b => b.id !== id);
      Storage.saveBookmarks(updated);
      return updated;
    });
  };

  return (
    <SafeAreaView style={styles.container}>
      <View style={styles.header}>
        <Text style={styles.title}>Bookmarks</Text>
      </View>

      <View style={styles.searchBox}>
        <TextInput
          style={styles.searchInput}
          value={search}
          onChangeText={setSearch}
          placeholder="Search bookmarks..."
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
              Alert.alert('Delete Bookmark', `Remove "${item.title}"?`, [
                { text: 'Cancel', style: 'cancel' },
                { text: 'Delete', style: 'destructive', onPress: () => deleteBookmark(item.id) },
              ]);
            }}
          >
            <View style={styles.bookmark}>
              <Text style={styles.rowTitle} numberOfLines={1}>{item.title}</Text>
              <Text style={styles.rowUrl} numberOfLines={1}>{item.url}</Text>
            </View>
          </TouchableOpacity>
        )}
        ListEmptyComponent={
          <View style={styles.empty}>
            <Text style={styles.emptyText}>No bookmarks yet</Text>
            <Text style={styles.emptyHint}>Tap the star in the browser to add one</Text>
          </View>
        }
      />
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: Colors.background },
  header: { paddingHorizontal: 16, paddingTop: 12, paddingBottom: 8 },
  title: { color: Colors.text, fontSize: 28, fontWeight: '700' },
  searchBox: { paddingHorizontal: 16, paddingBottom: 8 },
  searchInput: { backgroundColor: Colors.surface, color: Colors.text, borderRadius: 10, paddingHorizontal: 12, height: 38, fontSize: 14 },
  row: { paddingVertical: 12, paddingHorizontal: 16, borderBottomWidth: 0.5, borderBottomColor: Colors.border },
  bookmark: {},
  rowTitle: { color: Colors.text, fontSize: 15 },
  rowUrl: { color: Colors.textSecondary, fontSize: 12, marginTop: 2 },
  empty: { alignItems: 'center', marginTop: 60 },
  emptyText: { color: Colors.textSecondary, fontSize: 16 },
  emptyHint: { color: Colors.textSecondary, fontSize: 13, marginTop: 4 },
});
