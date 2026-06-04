export type CastProtocol = 'airplay' | 'dlna' | 'chromecast';
export type CastDeviceState = 'available' | 'connecting' | 'connected' | 'playing' | 'paused' | 'error';
export type SearchEngine = 'google' | 'duckduckgo' | 'bing' | 'yahoo';
export type VideoFormat = 'mp4' | 'webm' | 'hls' | 'dash' | 'mkv' | 'other';

export interface DetectedVideo {
  id: string;
  url: string;
  title: string;
  format: VideoFormat;
  resolution?: string;
  duration?: number;
  size?: number;
  pageURL?: string;
  pageTitle?: string;
  detectedAt: number;
}

export interface CastDevice {
  id: string;
  name: string;
  host: string;
  port: number;
  protocol: CastProtocol;
  state: CastDeviceState;
  modelName?: string;
  manufacturer?: string;
  controlURL?: string;
  lastConnected?: number;
}

export interface HistoryEntry {
  id: string;
  title: string;
  url: string;
  visitedAt: number;
  favicon?: string;
}

export interface Bookmark {
  id: string;
  title: string;
  url: string;
  createdAt: number;
  favicon?: string;
}

export interface PlaylistItem {
  id: string;
  video: DetectedVideo;
  order: number;
  addedAt: number;
}

export interface Playlist {
  id: string;
  name: string;
  items: PlaylistItem[];
  createdAt: number;
}

export interface BrowserTab {
  id: string;
  url: string;
  title: string;
  canGoBack: boolean;
  canGoForward: boolean;
  isLoading: boolean;
}

export interface AppSettings {
  searchEngine: SearchEngine;
  adBlockerEnabled: boolean;
  blockWebRTC: boolean;
  autoplayVideos: boolean;
  defaultPlaybackSpeed: number;
  customUserAgent: string;
}

export const DEFAULT_SETTINGS: AppSettings = {
  searchEngine: 'google',
  adBlockerEnabled: true,
  blockWebRTC: true,
  autoplayVideos: true,
  defaultPlaybackSpeed: 1.0,
  customUserAgent: '',
};

export const SEARCH_ENGINES: Record<SearchEngine, { name: string; searchURL: string; homeURL: string }> = {
  google: { name: 'Google', searchURL: 'https://www.google.com/search?q=', homeURL: 'https://www.google.com' },
  duckduckgo: { name: 'DuckDuckGo', searchURL: 'https://duckduckgo.com/?q=', homeURL: 'https://duckduckgo.com' },
  bing: { name: 'Bing', searchURL: 'https://www.bing.com/search?q=', homeURL: 'https://www.bing.com' },
  yahoo: { name: 'Yahoo', searchURL: 'https://search.yahoo.com/search?p=', homeURL: 'https://search.yahoo.com' },
};
