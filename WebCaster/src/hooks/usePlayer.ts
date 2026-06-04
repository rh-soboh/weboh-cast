import { useState, useRef, useCallback, useEffect } from 'react';
import { Video, AVPlaybackStatus, Audio } from 'expo-av';
import { DetectedVideo, PlaylistItem } from '../models/types';
import { Storage } from '../services/storage/PersistenceController';

export function usePlayer(initialVideo: DetectedVideo, queue: PlaylistItem[]) {
  const videoRef = useRef<Video>(null);
  const [currentVideo, setCurrentVideo] = useState(initialVideo);
  const [isPlaying, setIsPlaying] = useState(true);
  const [position, setPosition] = useState(0);
  const [duration, setDuration] = useState(0);
  const [speed, setSpeed] = useState(1.0);

  useEffect(() => {
    Audio.setAudioModeAsync({
      staysActiveInBackground: true,
      playsInSilentModeIOS: true,
    });
  }, []);

  const onPlaybackStatusUpdate = useCallback((status: AVPlaybackStatus) => {
    if (!status.isLoaded) return;
    setPosition(status.positionMillis || 0);
    setDuration(status.durationMillis || 0);
    setIsPlaying(status.isPlaying);
    if (status.positionMillis > 0) {
      Storage.savePosition(currentVideo.url, status.positionMillis);
    }
  }, [currentVideo]);

  const togglePlay = useCallback(async () => {
    if (isPlaying) await videoRef.current?.pauseAsync();
    else await videoRef.current?.playAsync();
  }, [isPlaying]);

  const seekTo = useCallback(async (ms: number) => {
    await videoRef.current?.setPositionAsync(ms);
  }, []);

  const changeSpeed = useCallback(async (newSpeed: number) => {
    setSpeed(newSpeed);
    await videoRef.current?.setRateAsync(newSpeed, true);
  }, []);

  const queueIndex = queue.findIndex(q => q.video.url === currentVideo.url);

  const playNext = useCallback(() => {
    if (queueIndex >= 0 && queueIndex < queue.length - 1) {
      setCurrentVideo(queue[queueIndex + 1].video);
    }
  }, [queue, queueIndex]);

  const playPrev = useCallback(() => {
    if (position > 3000) {
      videoRef.current?.setPositionAsync(0);
    } else if (queueIndex > 0) {
      setCurrentVideo(queue[queueIndex - 1].video);
    }
  }, [queue, queueIndex, position]);

  return {
    videoRef,
    currentVideo,
    setCurrentVideo,
    isPlaying,
    position,
    duration,
    speed,
    onPlaybackStatusUpdate,
    togglePlay,
    seekTo,
    changeSpeed,
    playNext,
    playPrev,
    queueIndex,
  };
}
