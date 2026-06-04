import React, { useState, useRef, useCallback, useEffect } from 'react';
import { NavigationContainer } from '@react-navigation/native';
import { createBottomTabNavigator } from '@react-navigation/bottom-tabs';
import { createNativeStackNavigator } from '@react-navigation/native-stack';
import { StatusBar } from 'expo-status-bar';
import { Text } from 'react-native';

import { NavigationTheme, Colors } from './src/theme/colors';
import { BrowserScreen } from './src/screens/BrowserScreen';
import { HistoryScreen } from './src/screens/HistoryScreen';
import { BookmarksScreen } from './src/screens/BookmarksScreen';
import { QueueScreen } from './src/screens/QueueScreen';
import { SettingsScreen } from './src/screens/SettingsScreen';
import { PlayerScreen } from './src/screens/PlayerScreen';
import { DevicePickerSheet } from './src/screens/DevicePickerSheet';
import { DetectedVideo, BrowserTab, HistoryEntry, Bookmark, PlaylistItem, AppSettings, DEFAULT_SETTINGS, CastDevice, SEARCH_ENGINES } from './src/models/types';
import { Storage } from './src/services/storage/PersistenceController';
import { CastingManager, CastingState } from './src/services/casting/CastingManager';

export type RootStackParamList = {
  MainTabs: undefined;
  Player: { video: DetectedVideo };
  DevicePicker: { video: DetectedVideo };
};

export type TabParamList = {
  Browser: undefined;
  History: undefined;
  Bookmarks: undefined;
  Queue: undefined;
  Settings: undefined;
};

const Tab = createBottomTabNavigator<TabParamList>();
const Stack = createNativeStackNavigator<RootStackParamList>();

function TabIcon({ name, focused }: { name: string; focused: boolean }) {
  const icons: Record<string, string> = {
    Browser: '🌐',
    History: '🕒',
    Bookmarks: '★',
    Queue: '▶',
    Settings: '⚙',
  };
  return (
    <Text style={{ fontSize: 22, opacity: focused ? 1 : 0.5 }}>
      {icons[name] || '•'}
    </Text>
  );
}

function MainTabs({
  browserRef,
  history,
  setHistory,
  bookmarks,
  setBookmarks,
  queue,
  setQueue,
  settings,
  setSettings,
  detectedVideos,
  setDetectedVideos,
  castingState,
  tabs,
  setTabs,
  activeTabIndex,
  setActiveTabIndex,
  navigateToURL,
  onPlay,
  onCast,
}: {
  browserRef: React.RefObject<any>;
  history: HistoryEntry[];
  setHistory: React.Dispatch<React.SetStateAction<HistoryEntry[]>>;
  bookmarks: Bookmark[];
  setBookmarks: React.Dispatch<React.SetStateAction<Bookmark[]>>;
  queue: PlaylistItem[];
  setQueue: React.Dispatch<React.SetStateAction<PlaylistItem[]>>;
  settings: AppSettings;
  setSettings: React.Dispatch<React.SetStateAction<AppSettings>>;
  detectedVideos: DetectedVideo[];
  setDetectedVideos: React.Dispatch<React.SetStateAction<DetectedVideo[]>>;
  castingState: CastingState;
  tabs: BrowserTab[];
  setTabs: React.Dispatch<React.SetStateAction<BrowserTab[]>>;
  activeTabIndex: number;
  setActiveTabIndex: React.Dispatch<React.SetStateAction<number>>;
  navigateToURL: (url: string) => void;
  onPlay: (video: DetectedVideo) => void;
  onCast: (video: DetectedVideo) => void;
}) {
  return (
    <Tab.Navigator
      screenOptions={({ route }) => ({
        headerShown: false,
        tabBarIcon: ({ focused }) => <TabIcon name={route.name} focused={focused} />,
        tabBarActiveTintColor: Colors.orange,
        tabBarInactiveTintColor: Colors.textSecondary,
        tabBarStyle: {
          backgroundColor: Colors.background,
          borderTopColor: Colors.border,
          borderTopWidth: 0.5,
        },
        tabBarLabelStyle: { fontSize: 11 },
      })}
    >
      <Tab.Screen name="Browser">
        {() => (
          <BrowserScreen
            ref={browserRef}
            tabs={tabs}
            setTabs={setTabs}
            activeTabIndex={activeTabIndex}
            setActiveTabIndex={setActiveTabIndex}
            detectedVideos={detectedVideos}
            setDetectedVideos={setDetectedVideos}
            history={history}
            setHistory={setHistory}
            bookmarks={bookmarks}
            setBookmarks={setBookmarks}
            settings={settings}
            castingState={castingState}
            onPlay={onPlay}
            onCast={onCast}
          />
        )}
      </Tab.Screen>
      <Tab.Screen name="History">
        {() => (
          <HistoryScreen
            history={history}
            setHistory={setHistory}
            navigateToURL={navigateToURL}
          />
        )}
      </Tab.Screen>
      <Tab.Screen name="Bookmarks">
        {() => (
          <BookmarksScreen
            bookmarks={bookmarks}
            setBookmarks={setBookmarks}
            navigateToURL={navigateToURL}
          />
        )}
      </Tab.Screen>
      <Tab.Screen name="Queue">
        {() => (
          <QueueScreen
            queue={queue}
            setQueue={setQueue}
            onPlay={onPlay}
          />
        )}
      </Tab.Screen>
      <Tab.Screen name="Settings">
        {() => (
          <SettingsScreen
            settings={settings}
            setSettings={setSettings}
          />
        )}
      </Tab.Screen>
    </Tab.Navigator>
  );
}

export default function App() {
  const navigationRef = useRef<any>(null);
  const browserRef = useRef<any>(null);

  const [history, setHistory] = useState<HistoryEntry[]>([]);
  const [bookmarks, setBookmarks] = useState<Bookmark[]>([]);
  const [queue, setQueue] = useState<PlaylistItem[]>([]);
  const [settings, setSettings] = useState<AppSettings>(DEFAULT_SETTINGS);
  const [detectedVideos, setDetectedVideos] = useState<DetectedVideo[]>([]);
  const [castingState, setCastingState] = useState<CastingState>(CastingManager.getState());
  const [tabs, setTabs] = useState<BrowserTab[]>([
    { id: '1', url: SEARCH_ENGINES.google.homeURL, title: 'Google', canGoBack: false, canGoForward: false, isLoading: false },
  ]);
  const [activeTabIndex, setActiveTabIndex] = useState(0);

  useEffect(() => {
    (async () => {
      const [h, b, q, s] = await Promise.all([
        Storage.loadHistory(),
        Storage.loadBookmarks(),
        Storage.loadQueue(),
        Storage.loadSettings(),
      ]);
      setHistory(h);
      setBookmarks(b);
      setQueue(q);
      setSettings(s);
    })();

    const unsub = CastingManager.subscribe(setCastingState);
    return unsub;
  }, []);

  useEffect(() => { Storage.saveHistory(history); }, [history]);
  useEffect(() => { Storage.saveBookmarks(bookmarks); }, [bookmarks]);
  useEffect(() => { Storage.saveQueue(queue); }, [queue]);
  useEffect(() => { Storage.saveSettings(settings); }, [settings]);

  const navigateToURL = useCallback((url: string) => {
    setTabs(prev => {
      const updated = [...prev];
      updated[activeTabIndex] = { ...updated[activeTabIndex], url };
      return updated;
    });
    navigationRef.current?.navigate('MainTabs', { screen: 'Browser' });
  }, [activeTabIndex]);

  const onPlay = useCallback((video: DetectedVideo) => {
    navigationRef.current?.navigate('Player', { video });
  }, []);

  const onCast = useCallback((video: DetectedVideo) => {
    navigationRef.current?.navigate('DevicePicker', { video });
  }, []);

  return (
    <>
      <StatusBar style="light" />
      <NavigationContainer ref={navigationRef} theme={NavigationTheme as any}>
        <Stack.Navigator screenOptions={{ headerShown: false }}>
          <Stack.Screen name="MainTabs">
            {() => (
              <MainTabs
                browserRef={browserRef}
                history={history}
                setHistory={setHistory}
                bookmarks={bookmarks}
                setBookmarks={setBookmarks}
                queue={queue}
                setQueue={setQueue}
                settings={settings}
                setSettings={setSettings}
                detectedVideos={detectedVideos}
                setDetectedVideos={setDetectedVideos}
                castingState={castingState}
                tabs={tabs}
                setTabs={setTabs}
                activeTabIndex={activeTabIndex}
                setActiveTabIndex={setActiveTabIndex}
                navigateToURL={navigateToURL}
                onPlay={onPlay}
                onCast={onCast}
              />
            )}
          </Stack.Screen>
          <Stack.Screen
            name="Player"
            options={{ presentation: 'fullScreenModal', animation: 'slide_from_bottom' }}
          >
            {(props: any) => (
              <PlayerScreen
                video={props.route.params.video}
                queue={queue}
                setQueue={setQueue}
                castingState={castingState}
              />
            )}
          </Stack.Screen>
          <Stack.Screen
            name="DevicePicker"
            options={{ presentation: 'modal', animation: 'slide_from_bottom' }}
          >
            {(props: any) => (
              <DevicePickerSheet
                video={props.route.params.video}
                castingState={castingState}
              />
            )}
          </Stack.Screen>
        </Stack.Navigator>
      </NavigationContainer>
    </>
  );
}
