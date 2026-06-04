import React from 'react';
import {
  View, Text, TouchableOpacity, Switch, StyleSheet, SafeAreaView, ScrollView, Alert,
} from 'react-native';
import { Colors } from '../theme/colors';
import { AppSettings, SearchEngine, SEARCH_ENGINES } from '../models/types';
import { Storage } from '../services/storage/PersistenceController';

interface Props {
  settings: AppSettings;
  setSettings: React.Dispatch<React.SetStateAction<AppSettings>>;
}

function SettingRow({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <View style={styles.settingRow}>
      <Text style={styles.settingLabel}>{label}</Text>
      {children}
    </View>
  );
}

function SectionHeader({ title }: { title: string }) {
  return <Text style={styles.sectionHeader}>{title}</Text>;
}

export function SettingsScreen({ settings, setSettings }: Props) {
  const updateSetting = <K extends keyof AppSettings>(key: K, value: AppSettings[K]) => {
    setSettings(prev => ({ ...prev, [key]: value }));
  };

  const clearAllData = () => {
    Alert.alert('Clear All Data', 'This will delete all history, bookmarks, playlists, and settings.', [
      { text: 'Cancel', style: 'cancel' },
      {
        text: 'Clear Everything',
        style: 'destructive',
        onPress: async () => {
          await Storage.clearAll();
          Alert.alert('Done', 'All data cleared. Restart the app for full effect.');
        },
      },
    ]);
  };

  return (
    <SafeAreaView style={styles.container}>
      <View style={styles.header}>
        <Text style={styles.title}>Settings</Text>
      </View>

      <ScrollView>
        <SectionHeader title="SEARCH" />

        <SettingRow label="Search Engine">
          <View style={styles.enginePicker}>
            {(Object.keys(SEARCH_ENGINES) as SearchEngine[]).map(key => (
              <TouchableOpacity
                key={key}
                style={[styles.engineBtn, settings.searchEngine === key && styles.engineBtnActive]}
                onPress={() => updateSetting('searchEngine', key)}
              >
                <Text style={[styles.engineText, settings.searchEngine === key && styles.engineTextActive]}>
                  {SEARCH_ENGINES[key].name}
                </Text>
              </TouchableOpacity>
            ))}
          </View>
        </SettingRow>

        <SectionHeader title="PRIVACY" />

        <SettingRow label="Ad Blocker">
          <Switch
            value={settings.adBlockerEnabled}
            onValueChange={v => updateSetting('adBlockerEnabled', v)}
            trackColor={{ false: Colors.border, true: Colors.orange }}
            thumbColor={Colors.white}
          />
        </SettingRow>

        <SettingRow label="Block WebRTC">
          <Switch
            value={settings.blockWebRTC}
            onValueChange={v => updateSetting('blockWebRTC', v)}
            trackColor={{ false: Colors.border, true: Colors.orange }}
            thumbColor={Colors.white}
          />
        </SettingRow>

        <SectionHeader title="PLAYBACK" />

        <SettingRow label="Autoplay Videos">
          <Switch
            value={settings.autoplayVideos}
            onValueChange={v => updateSetting('autoplayVideos', v)}
            trackColor={{ false: Colors.border, true: Colors.orange }}
            thumbColor={Colors.white}
          />
        </SettingRow>

        <SettingRow label="Default Speed">
          <View style={styles.speedPicker}>
            {[0.5, 0.75, 1.0, 1.25, 1.5, 2.0].map(speed => (
              <TouchableOpacity
                key={speed}
                style={[styles.speedBtn, settings.defaultPlaybackSpeed === speed && styles.speedBtnActive]}
                onPress={() => updateSetting('defaultPlaybackSpeed', speed)}
              >
                <Text style={[styles.speedText, settings.defaultPlaybackSpeed === speed && styles.speedTextActive]}>
                  {speed}x
                </Text>
              </TouchableOpacity>
            ))}
          </View>
        </SettingRow>

        <SectionHeader title="DATA" />

        <TouchableOpacity style={styles.dangerRow} onPress={clearAllData}>
          <Text style={styles.dangerText}>Clear All Data</Text>
        </TouchableOpacity>

        <SectionHeader title="ABOUT" />

        <View style={styles.aboutSection}>
          <Text style={styles.aboutName}>WebCaster</Text>
          <Text style={styles.aboutVersion}>Version 1.0.0</Text>
          <Text style={styles.aboutDesc}>
            Browse the web, detect videos, and cast them to your TV.
          </Text>
        </View>
      </ScrollView>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: Colors.background },
  header: { paddingHorizontal: 16, paddingTop: 12, paddingBottom: 8 },
  title: { color: Colors.text, fontSize: 28, fontWeight: '700' },
  sectionHeader: { color: Colors.textSecondary, fontSize: 13, fontWeight: '600', paddingHorizontal: 16, paddingTop: 20, paddingBottom: 6, letterSpacing: 0.5 },
  settingRow: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', paddingVertical: 12, paddingHorizontal: 16, backgroundColor: Colors.surface, borderBottomWidth: 0.5, borderBottomColor: Colors.border, minHeight: 48 },
  settingLabel: { color: Colors.text, fontSize: 16, flex: 1 },
  enginePicker: { flexDirection: 'row', flexWrap: 'wrap', gap: 6, justifyContent: 'flex-end' },
  engineBtn: { paddingHorizontal: 10, paddingVertical: 4, borderRadius: 8, backgroundColor: Colors.surfaceElevated },
  engineBtnActive: { backgroundColor: Colors.orange },
  engineText: { color: Colors.textSecondary, fontSize: 13 },
  engineTextActive: { color: Colors.white, fontWeight: '600' },
  speedPicker: { flexDirection: 'row', gap: 4 },
  speedBtn: { paddingHorizontal: 8, paddingVertical: 4, borderRadius: 6, backgroundColor: Colors.surfaceElevated },
  speedBtnActive: { backgroundColor: Colors.orange },
  speedText: { color: Colors.textSecondary, fontSize: 12, fontWeight: '500' },
  speedTextActive: { color: Colors.white },
  dangerRow: { paddingVertical: 14, paddingHorizontal: 16, backgroundColor: Colors.surface },
  dangerText: { color: Colors.red, fontSize: 16 },
  aboutSection: { padding: 16, alignItems: 'center' },
  aboutName: { color: Colors.text, fontSize: 18, fontWeight: '700' },
  aboutVersion: { color: Colors.textSecondary, fontSize: 14, marginTop: 4 },
  aboutDesc: { color: Colors.textSecondary, fontSize: 13, marginTop: 8, textAlign: 'center' },
});
