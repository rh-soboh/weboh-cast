import React, { useState, useRef, useCallback, useEffect } from 'react';
import {
  View, Text, TouchableOpacity, StyleSheet, SafeAreaView, Dimensions, Platform,
} from 'react-native';
import { Video, ResizeMode, AVPlaybackStatus, Audio } from 'expo-av';
import { useNavigation } from '@react-navigation/native';
import { Colors } from '../theme/colors';
import { DetectedVideo, PlaylistItem } from '../models/types';
import { CastingState, CastingManager } from '../services/casting/CastingManager';
import { Storage } from '../services/storage/PersistenceController';
import { SubtitleCue, fetchAndParse } from '../services/subtitles/SubtitleParser';
import { CustomSlider } from '../components/CustomSlider';

interface Props {
  video: DetectedVideo;
  queue: PlaylistItem[];
  setQueue: React.Dispatch<React.SetStateAction<PlaylistItem[]>>;
  castingState: CastingState;
}

const SPEEDS = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];
const { width: SCREEN_WIDTH } = Dimensions.get('window');

function formatTime(ms: number): string {
  const totalSec = Math.floor(ms / 1000);
  const h = Math.floor(totalSec / 3600);
  const m = Math.floor((totalSec % 3600) / 60);
  const s = totalSec % 60;
  if (h > 0) return `${h}:${m.toString().padStart(2, '0')}:${s.toString().padStart(2, '0')}`;
  return `${m}:${s.toString().padStart(2, '0')}`;
}

export function PlayerScreen({ video: initialVideo, queue, setQueue, castingState }: Props) {
  const navigation = useNavigation();
  const videoRef = useRef<Video>(null);

  const [currentVideo, setCurrentVideo] = useState(initialVideo);
  const [isPlaying, setIsPlaying] = useState(true);
  const [position, setPosition] = useState(0);
  const [duration, setDuration] = useState(0);
  const [speed, setSpeed] = useState(1.0);
  const [showControls, setShowControls] = useState(true);
  const [subtitles, setSubtitles] = useState<SubtitleCue[]>([]);
  const [currentCue, setCurrentCue] = useState<string>('');

  useEffect(() => {
    Audio.setAudioModeAsync({
      staysActiveInBackground: true,
      playsInSilentModeIOS: true,
    });
  }, []);

  useEffect(() => {
    const sec = position / 1000;
    const cue = subtitles.find(c => sec >= c.startTime && sec <= c.endTime);
    setCurrentCue(cue?.text || '');
  }, [position, subtitles]);

  useEffect(() => {
    (async () => {
      const savedPos = await Storage.getPosition(currentVideo.url);
      if (savedPos && savedPos > 1000) {
        videoRef.current?.setPositionAsync(savedPos);
      }
    })();
  }, [currentVideo]);

  const onPlaybackStatusUpdate = useCallback((status: AVPlaybackStatus) => {
    if (!status.isLoaded) return;
    setPosition(status.positionMillis || 0);
    setDuration(status.durationMillis || 0);
    setIsPlaying(status.isPlaying);

    if (status.positionMillis && status.positionMillis > 0) {
      Storage.savePosition(currentVideo.url, status.positionMillis);
    }

    if (status.didJustFinish) {
      playNext();
    }
  }, [currentVideo, queue]);

  const togglePlay = async () => {
    if (isPlaying) {
      await videoRef.current?.pauseAsync();
    } else {
      await videoRef.current?.playAsync();
    }
  };

  const seekRelative = async (ms: number) => {
    const newPos = Math.max(0, Math.min(position + ms, duration));
    await videoRef.current?.setPositionAsync(newPos);
  };

  const seekTo = async (ms: number) => {
    await videoRef.current?.setPositionAsync(ms);
  };

  const cycleSpeed = () => {
    const idx = SPEEDS.indexOf(speed);
    const next = SPEEDS[(idx + 1) % SPEEDS.length];
    setSpeed(next);
    videoRef.current?.setRateAsync(next, true);
  };

  const queueIndex = queue.findIndex(q => q.video.url === currentVideo.url);

  const playNext = () => {
    if (queueIndex >= 0 && queueIndex < queue.length - 1) {
      setCurrentVideo(queue[queueIndex + 1].video);
    }
  };

  const playPrev = () => {
    if (position > 3000) {
      videoRef.current?.setPositionAsync(0);
    } else if (queueIndex > 0) {
      setCurrentVideo(queue[queueIndex - 1].video);
    }
  };

  const castCurrent = () => {
    CastingManager.cast(currentVideo);
  };

  return (
    <SafeAreaView style={styles.container}>
      <TouchableOpacity
        style={styles.videoArea}
        activeOpacity={1}
        onPress={() => setShowControls(prev => !prev)}
      >
        <Video
          ref={videoRef}
          source={{ uri: currentVideo.url }}
          style={styles.video}
          resizeMode={ResizeMode.CONTAIN}
          shouldPlay={isPlaying}
          rate={speed}
          volume={1.0}
          onPlaybackStatusUpdate={onPlaybackStatusUpdate}
          useNativeControls={false}
        />

        {currentCue !== '' && (
          <View style={styles.subtitleContainer}>
            <Text style={styles.subtitleText}>{currentCue}</Text>
          </View>
        )}

        {showControls && (
          <View style={styles.controlsOverlay}>
            <View style={styles.topBar}>
              <TouchableOpacity onPress={() => navigation.goBack()}>
                <Text style={styles.closeBtn}>✕</Text>
              </TouchableOpacity>
              <Text style={styles.videoTitle} numberOfLines={1}>{currentVideo.title}</Text>
              <TouchableOpacity onPress={castCurrent}>
                <Text style={styles.castBtn}>📺</Text>
              </TouchableOpacity>
            </View>

            <View style={styles.centerControls}>
              <TouchableOpacity onPress={() => seekRelative(-10000)} style={styles.seekBtn}>
                <Text style={styles.seekText}>-10s</Text>
              </TouchableOpacity>
              <TouchableOpacity onPress={playPrev} style={styles.controlBtn}>
                <Text style={styles.controlIcon}>⏮</Text>
              </TouchableOpacity>
              <TouchableOpacity onPress={togglePlay} style={styles.playBtn}>
                <Text style={styles.playIcon}>{isPlaying ? '⏸' : '▶'}</Text>
              </TouchableOpacity>
              <TouchableOpacity onPress={playNext} style={styles.controlBtn}>
                <Text style={styles.controlIcon}>⏭</Text>
              </TouchableOpacity>
              <TouchableOpacity onPress={() => seekRelative(10000)} style={styles.seekBtn}>
                <Text style={styles.seekText}>+10s</Text>
              </TouchableOpacity>
            </View>

            <View style={styles.bottomControls}>
              <Text style={styles.timeText}>{formatTime(position)}</Text>
              <CustomSlider
                value={position}
                maximumValue={duration || 1}
                onValueChange={seekTo}
              />
              <Text style={styles.timeText}>{formatTime(duration)}</Text>
            </View>

            <View style={styles.extraControls}>
              <TouchableOpacity onPress={cycleSpeed} style={styles.extraBtn}>
                <Text style={styles.extraText}>{speed}x</Text>
              </TouchableOpacity>
            </View>
          </View>
        )}
      </TouchableOpacity>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: Colors.black },
  videoArea: { flex: 1, justifyContent: 'center' },
  video: { width: '100%', height: '100%' },
  subtitleContainer: { position: 'absolute', bottom: 80, left: 16, right: 16, alignItems: 'center' },
  subtitleText: { color: Colors.white, fontSize: 18, fontWeight: '600', textShadowColor: 'rgba(0,0,0,0.8)', textShadowOffset: { width: 1, height: 1 }, textShadowRadius: 4, backgroundColor: 'rgba(0,0,0,0.5)', paddingHorizontal: 12, paddingVertical: 4, borderRadius: 4, textAlign: 'center', overflow: 'hidden' },
  controlsOverlay: { ...StyleSheet.absoluteFillObject, backgroundColor: 'rgba(0,0,0,0.4)', justifyContent: 'space-between' },
  topBar: { flexDirection: 'row', alignItems: 'center', paddingHorizontal: 16, paddingTop: 16 },
  closeBtn: { color: Colors.white, fontSize: 24, padding: 4 },
  videoTitle: { flex: 1, color: Colors.white, fontSize: 16, fontWeight: '600', marginHorizontal: 12 },
  castBtn: { fontSize: 22, padding: 4 },
  centerControls: { flexDirection: 'row', justifyContent: 'center', alignItems: 'center', gap: 20 },
  seekBtn: { padding: 8 },
  seekText: { color: Colors.white, fontSize: 13, fontWeight: '600' },
  controlBtn: { padding: 8 },
  controlIcon: { color: Colors.white, fontSize: 28 },
  playBtn: { width: 64, height: 64, borderRadius: 32, backgroundColor: 'rgba(255,255,255,0.2)', justifyContent: 'center', alignItems: 'center' },
  playIcon: { color: Colors.white, fontSize: 30 },
  bottomControls: { flexDirection: 'row', alignItems: 'center', paddingHorizontal: 16, paddingBottom: 8, gap: 8 },
  timeText: { color: Colors.white, fontSize: 12, fontWeight: '500', width: 50, textAlign: 'center' },
  extraControls: { flexDirection: 'row', justifyContent: 'center', paddingBottom: 16, gap: 16 },
  extraBtn: { paddingHorizontal: 12, paddingVertical: 6, borderRadius: 8, backgroundColor: 'rgba(255,255,255,0.2)' },
  extraText: { color: Colors.white, fontSize: 13, fontWeight: '600' },
});
