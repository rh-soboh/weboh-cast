import React, { useState, useEffect } from 'react';
import { View, TextInput, TouchableOpacity, Text, StyleSheet, ActivityIndicator } from 'react-native';
import { Colors } from '../theme/colors';

interface Props {
  url: string;
  isLoading: boolean;
  onNavigate: (url: string) => void;
  onBack: () => void;
  onForward: () => void;
  onRefresh: () => void;
  onBookmark: () => void;
  onTabs: () => void;
  canGoBack: boolean;
  canGoForward: boolean;
  tabCount: number;
}

export function AddressBar({
  url, isLoading, onNavigate, onBack, onForward, onRefresh,
  onBookmark, onTabs, canGoBack, canGoForward, tabCount,
}: Props) {
  const [text, setText] = useState(url);
  const [isFocused, setIsFocused] = useState(false);

  useEffect(() => {
    if (!isFocused) setText(url);
  }, [url, isFocused]);

  const handleSubmit = () => {
    onNavigate(text);
  };

  return (
    <View style={styles.container}>
      <View style={styles.navRow}>
        <TouchableOpacity onPress={onBack} disabled={!canGoBack} style={styles.navBtn}>
          <Text style={[styles.navIcon, !canGoBack && styles.disabled]}>‹</Text>
        </TouchableOpacity>
        <TouchableOpacity onPress={onForward} disabled={!canGoForward} style={styles.navBtn}>
          <Text style={[styles.navIcon, !canGoForward && styles.disabled]}>›</Text>
        </TouchableOpacity>

        <View style={styles.inputWrapper}>
          {isLoading && <ActivityIndicator size="small" color={Colors.orange} style={styles.spinner} />}
          <TextInput
            style={styles.input}
            value={text}
            onChangeText={setText}
            onSubmitEditing={handleSubmit}
            onFocus={() => { setIsFocused(true); setText(url); }}
            onBlur={() => setIsFocused(false)}
            placeholder="Search or enter URL"
            placeholderTextColor={Colors.textSecondary}
            autoCapitalize="none"
            autoCorrect={false}
            keyboardType="url"
            returnKeyType="go"
            selectTextOnFocus
          />
        </View>

        <TouchableOpacity onPress={onRefresh} style={styles.navBtn}>
          <Text style={styles.navIcon}>↻</Text>
        </TouchableOpacity>
        <TouchableOpacity onPress={onBookmark} style={styles.navBtn}>
          <Text style={styles.navIcon}>★</Text>
        </TouchableOpacity>
        <TouchableOpacity onPress={onTabs} style={styles.tabsBtn}>
          <Text style={styles.tabCount}>{tabCount}</Text>
        </TouchableOpacity>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { backgroundColor: Colors.surface, paddingHorizontal: 8, paddingVertical: 6, borderBottomWidth: 0.5, borderBottomColor: Colors.border },
  navRow: { flexDirection: 'row', alignItems: 'center', gap: 4 },
  navBtn: { padding: 6 },
  navIcon: { color: Colors.orange, fontSize: 22, fontWeight: '600' },
  disabled: { opacity: 0.3 },
  inputWrapper: { flex: 1, flexDirection: 'row', alignItems: 'center', backgroundColor: Colors.surfaceElevated, borderRadius: 10, paddingHorizontal: 10, height: 36 },
  spinner: { marginRight: 6 },
  input: { flex: 1, color: Colors.text, fontSize: 14, height: 36, padding: 0 },
  tabsBtn: { width: 28, height: 28, borderRadius: 6, borderWidth: 1.5, borderColor: Colors.orange, justifyContent: 'center', alignItems: 'center' },
  tabCount: { color: Colors.orange, fontSize: 13, fontWeight: '700' },
});
