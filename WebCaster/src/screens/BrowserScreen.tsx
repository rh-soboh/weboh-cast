import React, { useState, useRef, useCallback, forwardRef, useImperativeHandle } from 'react';
import {
  View, Text, TextInput, TouchableOpacity, StyleSheet, SafeAreaView,
  ScrollView, Modal, Alert, FlatList, Dimensions,
} from 'react-native';
import { WebView, WebViewNavigation } from 'react-native-webview';
import { Colors } from '../theme/colors';
import { DetectedVideo, BrowserTab, HistoryEntry, Bookmark, AppSettings, SEARCH_ENGINES } from '../models/types';
import { getAdBlockInjectionScript, shouldBlockURL } from '../services/adblock/AdBlockService';
import { getDetectorScript, parseVideoMessage, probeVideoMetadata } from '../services/videoDetector/VideoDetectionService';
import { CastingState } from '../services/casting/CastingManager';
import { Storage } from '../services/storage/PersistenceController';
import { AddressBar } from '../components/AddressBar';
import { VideoDetectionOverlay } from '../components/VideoDetectionOverlay';
import { NowCastingBar } from '../components/NowCastingBar';

interface Props {
  tabs: BrowserTab[];
  setTabs: React.Dispatch<React.SetStateAction<BrowserTab[]>>;
  activeTabIndex: number;
  setActiveTabIndex: React.Dispatch<React.SetStateAction<number>>;
  detectedVideos: DetectedVideo[];
  setDetectedVideos: React.Dispatch<React.SetStateAction<DetectedVideo[]>>;
  history: HistoryEntry[];
  setHistory: React.Dispatch<React.SetStateAction<HistoryEntry[]>>;
  bookmarks: Bookmark[];
  setBookmarks: React.Dispatch<React.SetStateAction<Bookmark[]>>;
  settings: AppSettings;
  castingState: CastingState;
  onPlay: (video: DetectedVideo) => void;
  onCast: (video: DetectedVideo) => void;
}

export const BrowserScreen = forwardRef<any, Props>(function BrowserScreen(props, ref) {
  const {
    tabs, setTabs, activeTabIndex, setActiveTabIndex,
    detectedVideos, setDetectedVideos,
    history, setHistory, bookmarks, setBookmarks,
    settings, castingState, onPlay, onCast,
  } = props;

  const webViewRef = useRef<WebView>(null);
  const [showTabs, setShowTabs] = useState(false);
  const [addressText, setAddressText] = useState('');
  const [showVideos, setShowVideos] = useState(false);

  const activeTab = tabs[activeTabIndex] || tabs[0];

  useImperativeHandle(ref, () => ({
    navigateToURL: (url: string) => {
      setTabs(prev => {
        const updated = [...prev];
        updated[activeTabIndex] = { ...updated[activeTabIndex], url };
        return updated;
      });
    },
  }));

  const injectedJS = `
    ${settings.adBlockerEnabled ? getAdBlockInjectionScript(settings.blockWebRTC) : ''}
    ${getDetectorScript()}
    true;
  `;

  const handleNavigate = useCallback((url: string) => {
    let finalURL = url.trim();
    if (!finalURL) return;
    if (!/^https?:\/\//i.test(finalURL)) {
      if (finalURL.includes('.') && !finalURL.includes(' ')) {
        finalURL = 'https://' + finalURL;
      } else {
        const engine = SEARCH_ENGINES[settings.searchEngine];
        finalURL = engine.searchURL + encodeURIComponent(finalURL);
      }
    }
    setTabs(prev => {
      const updated = [...prev];
      updated[activeTabIndex] = { ...updated[activeTabIndex], url: finalURL };
      return updated;
    });
  }, [activeTabIndex, settings.searchEngine, setTabs]);

  const handleNavigationStateChange = useCallback((nav: WebViewNavigation) => {
    setTabs(prev => {
      const updated = [...prev];
      updated[activeTabIndex] = {
        ...updated[activeTabIndex],
        url: nav.url,
        title: nav.title || updated[activeTabIndex].title,
        canGoBack: nav.canGoBack,
        canGoForward: nav.canGoForward,
        isLoading: nav.loading,
      };
      return updated;
    });

    if (!nav.loading && nav.url && nav.url !== 'about:blank') {
      const entry: HistoryEntry = {
        id: Date.now().toString(36),
        title: nav.title || nav.url,
        url: nav.url,
        visitedAt: Date.now(),
      };
      setHistory(prev => {
        const filtered = prev.filter(h => h.url !== entry.url);
        return [entry, ...filtered].slice(0, 500);
      });
      Storage.addHistoryEntry(entry);
    }
  }, [activeTabIndex, setTabs, setHistory]);

  const handleMessage = useCallback((event: { nativeEvent: { data: string } }) => {
    try {
      const msg = JSON.parse(event.nativeEvent.data);
      if (msg.type === 'videoDetected') {
        const video = parseVideoMessage(
          JSON.stringify(msg.payload),
          activeTab.title,
          activeTab.url,
        );
        if (video) {
          setDetectedVideos(prev => {
            if (prev.some(v => v.url === video.url)) return prev;
            return [...prev, video];
          });
          probeVideoMetadata(video).then(probed => {
            setDetectedVideos(prev =>
              prev.map(v => v.id === probed.id ? probed : v)
            );
          });
        }
      }
    } catch {}
  }, [activeTab, setDetectedVideos]);

  const shouldStartLoad = useCallback((request: { url: string }) => {
    if (settings.adBlockerEnabled && shouldBlockURL(request.url)) return false;
    return true;
  }, [settings.adBlockerEnabled]);

  const addBookmark = useCallback(() => {
    if (bookmarks.some(b => b.url === activeTab.url)) {
      Alert.alert('Already bookmarked');
      return;
    }
    const bm: Bookmark = {
      id: Date.now().toString(36),
      title: activeTab.title,
      url: activeTab.url,
      createdAt: Date.now(),
    };
    setBookmarks(prev => [...prev, bm]);
  }, [activeTab, bookmarks, setBookmarks]);

  const addNewTab = useCallback(() => {
    const engine = SEARCH_ENGINES[settings.searchEngine];
    const newTab: BrowserTab = {
      id: Date.now().toString(36),
      url: engine.homeURL,
      title: engine.name,
      canGoBack: false,
      canGoForward: false,
      isLoading: false,
    };
    setTabs(prev => [...prev, newTab]);
    setActiveTabIndex(tabs.length);
    setShowTabs(false);
  }, [settings.searchEngine, tabs.length, setTabs, setActiveTabIndex]);

  const closeTab = useCallback((index: number) => {
    if (tabs.length <= 1) return;
    setTabs(prev => prev.filter((_, i) => i !== index));
    if (activeTabIndex >= tabs.length - 1) {
      setActiveTabIndex(Math.max(0, tabs.length - 2));
    } else if (index < activeTabIndex) {
      setActiveTabIndex(prev => prev - 1);
    }
  }, [tabs.length, activeTabIndex, setTabs, setActiveTabIndex]);

  return (
    <SafeAreaView style={styles.container}>
      {castingState.connectedDevice && (
        <NowCastingBar device={castingState.connectedDevice} />
      )}

      <AddressBar
        url={activeTab.url}
        isLoading={activeTab.isLoading}
        onNavigate={handleNavigate}
        onBack={() => webViewRef.current?.goBack()}
        onForward={() => webViewRef.current?.goForward()}
        onRefresh={() => webViewRef.current?.reload()}
        onBookmark={addBookmark}
        onTabs={() => setShowTabs(true)}
        canGoBack={activeTab.canGoBack}
        canGoForward={activeTab.canGoForward}
        tabCount={tabs.length}
      />

      <View style={styles.webViewContainer}>
        <WebView
          ref={webViewRef}
          source={{ uri: activeTab.url }}
          style={styles.webView}
          injectedJavaScript={injectedJS}
          onNavigationStateChange={handleNavigationStateChange}
          onMessage={handleMessage}
          onShouldStartLoadWithRequest={shouldStartLoad}
          allowsBackForwardNavigationGestures
          javaScriptEnabled
          domStorageEnabled
          mediaPlaybackRequiresUserAction={false}
          allowsInlineMediaPlayback
          startInLoadingState
          renderLoading={() => (
            <View style={styles.loading}>
              <Text style={styles.loadingText}>Loading...</Text>
            </View>
          )}
          userAgent={settings.customUserAgent || undefined}
        />

        {detectedVideos.length > 0 && (
          <VideoDetectionOverlay
            videos={detectedVideos}
            expanded={showVideos}
            onToggle={() => setShowVideos(prev => !prev)}
            onPlay={onPlay}
            onCast={onCast}
            onAddToQueue={(video) => {
              setDetectedVideos(prev => prev);
              const item = {
                id: Date.now().toString(36),
                video,
                order: 0,
                addedAt: Date.now(),
              };
              // Queue update is handled through props
              props.setDetectedVideos(prev => prev);
            }}
          />
        )}
      </View>

      <Modal visible={showTabs} animationType="slide" transparent>
        <View style={styles.modalOverlay}>
          <View style={styles.tabsModal}>
            <View style={styles.tabsHeader}>
              <Text style={styles.tabsTitle}>Tabs ({tabs.length})</Text>
              <TouchableOpacity onPress={addNewTab}>
                <Text style={styles.addTab}>+ New Tab</Text>
              </TouchableOpacity>
              <TouchableOpacity onPress={() => setShowTabs(false)}>
                <Text style={styles.closeModal}>Done</Text>
              </TouchableOpacity>
            </View>
            <FlatList
              data={tabs}
              keyExtractor={(_, i) => i.toString()}
              renderItem={({ item, index }) => (
                <TouchableOpacity
                  style={[styles.tabItem, index === activeTabIndex && styles.tabItemActive]}
                  onPress={() => { setActiveTabIndex(index); setShowTabs(false); }}
                >
                  <View style={styles.tabInfo}>
                    <Text style={styles.tabTitle} numberOfLines={1}>{item.title}</Text>
                    <Text style={styles.tabUrl} numberOfLines={1}>{item.url}</Text>
                  </View>
                  {tabs.length > 1 && (
                    <TouchableOpacity onPress={() => closeTab(index)} style={styles.closeTabBtn}>
                      <Text style={styles.closeTabText}>✕</Text>
                    </TouchableOpacity>
                  )}
                </TouchableOpacity>
              )}
            />
          </View>
        </View>
      </Modal>
    </SafeAreaView>
  );
});

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: Colors.background },
  webViewContainer: { flex: 1, position: 'relative' },
  webView: { flex: 1, backgroundColor: Colors.background },
  loading: { ...StyleSheet.absoluteFillObject, backgroundColor: Colors.background, justifyContent: 'center', alignItems: 'center' },
  loadingText: { color: Colors.textSecondary, fontSize: 14 },
  modalOverlay: { flex: 1, backgroundColor: 'rgba(0,0,0,0.6)', justifyContent: 'flex-end' },
  tabsModal: { backgroundColor: Colors.surface, borderTopLeftRadius: 16, borderTopRightRadius: 16, maxHeight: '70%', paddingBottom: 30 },
  tabsHeader: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', padding: 16, borderBottomWidth: 0.5, borderBottomColor: Colors.border },
  tabsTitle: { color: Colors.text, fontSize: 17, fontWeight: '600' },
  addTab: { color: Colors.orange, fontSize: 15, fontWeight: '600' },
  closeModal: { color: Colors.orange, fontSize: 15, fontWeight: '600' },
  tabItem: { flexDirection: 'row', alignItems: 'center', paddingVertical: 12, paddingHorizontal: 16, borderBottomWidth: 0.5, borderBottomColor: Colors.border },
  tabItemActive: { backgroundColor: Colors.orangeLight },
  tabInfo: { flex: 1 },
  tabTitle: { color: Colors.text, fontSize: 15 },
  tabUrl: { color: Colors.textSecondary, fontSize: 12, marginTop: 2 },
  closeTabBtn: { padding: 8 },
  closeTabText: { color: Colors.textSecondary, fontSize: 16 },
});
