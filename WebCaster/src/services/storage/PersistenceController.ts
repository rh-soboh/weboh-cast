import AsyncStorage from '@react-native-async-storage/async-storage';
import { HistoryEntry, Bookmark, PlaylistItem, Playlist, CastDevice, AppSettings, DEFAULT_SETTINGS } from '../../models/types';

const KEYS = {
  HISTORY: 'webcaster_history',
  BOOKMARKS: 'webcaster_bookmarks',
  QUEUE: 'webcaster_queue',
  PLAYLISTS: 'webcaster_playlists',
  SETTINGS: 'webcaster_settings',
  POSITIONS: 'webcaster_positions',
  RECENT_DEVICES: 'webcaster_recent_devices',
};

async function load<T>(key: string, fallback: T): Promise<T> {
  try {
    const raw = await AsyncStorage.getItem(key);
    return raw ? JSON.parse(raw) : fallback;
  } catch {
    return fallback;
  }
}

async function save(key: string, value: unknown): Promise<void> {
  try {
    await AsyncStorage.setItem(key, JSON.stringify(value));
  } catch (e) {
    console.warn('[Storage] Save failed:', key, e);
  }
}

export const Storage = {
  // History
  async loadHistory(): Promise<HistoryEntry[]> {
    return load(KEYS.HISTORY, []);
  },
  async saveHistory(entries: HistoryEntry[]): Promise<void> {
    await save(KEYS.HISTORY, entries);
  },
  async addHistoryEntry(entry: HistoryEntry): Promise<HistoryEntry[]> {
    const history = await this.loadHistory();
    const filtered = history.filter(h => h.url !== entry.url);
    const updated = [entry, ...filtered].slice(0, 500);
    await this.saveHistory(updated);
    return updated;
  },
  async clearHistory(): Promise<void> {
    await AsyncStorage.removeItem(KEYS.HISTORY);
  },

  // Bookmarks
  async loadBookmarks(): Promise<Bookmark[]> {
    return load(KEYS.BOOKMARKS, []);
  },
  async saveBookmarks(bookmarks: Bookmark[]): Promise<void> {
    await save(KEYS.BOOKMARKS, bookmarks);
  },
  async addBookmark(bookmark: Bookmark): Promise<Bookmark[]> {
    const bookmarks = await this.loadBookmarks();
    if (bookmarks.some(b => b.url === bookmark.url)) return bookmarks;
    const updated = [...bookmarks, bookmark];
    await this.saveBookmarks(updated);
    return updated;
  },
  async removeBookmark(id: string): Promise<Bookmark[]> {
    const bookmarks = await this.loadBookmarks();
    const updated = bookmarks.filter(b => b.id !== id);
    await this.saveBookmarks(updated);
    return updated;
  },

  // Queue
  async loadQueue(): Promise<PlaylistItem[]> {
    return load(KEYS.QUEUE, []);
  },
  async saveQueue(queue: PlaylistItem[]): Promise<void> {
    await save(KEYS.QUEUE, queue);
  },

  // Playlists
  async loadPlaylists(): Promise<Playlist[]> {
    return load(KEYS.PLAYLISTS, []);
  },
  async savePlaylists(playlists: Playlist[]): Promise<void> {
    await save(KEYS.PLAYLISTS, playlists);
  },

  // Playback positions
  async getPosition(videoURL: string): Promise<number | null> {
    const positions = await load<Record<string, number>>(KEYS.POSITIONS, {});
    return positions[videoURL] ?? null;
  },
  async savePosition(videoURL: string, position: number): Promise<void> {
    const positions = await load<Record<string, number>>(KEYS.POSITIONS, {});
    positions[videoURL] = position;
    await save(KEYS.POSITIONS, positions);
  },

  // Settings
  async loadSettings(): Promise<AppSettings> {
    return load(KEYS.SETTINGS, DEFAULT_SETTINGS);
  },
  async saveSettings(settings: AppSettings): Promise<void> {
    await save(KEYS.SETTINGS, settings);
  },

  // Recent devices
  async loadRecentDevices(): Promise<CastDevice[]> {
    return load(KEYS.RECENT_DEVICES, []);
  },
  async saveRecentDevice(device: CastDevice): Promise<void> {
    const devices = await this.loadRecentDevices();
    const filtered = devices.filter(d => !(d.host === device.host && d.port === device.port));
    const updated = [device, ...filtered].slice(0, 10);
    await save(KEYS.RECENT_DEVICES, updated);
  },

  // Clear all
  async clearAll(): Promise<void> {
    await AsyncStorage.multiRemove(Object.values(KEYS));
  },
};
