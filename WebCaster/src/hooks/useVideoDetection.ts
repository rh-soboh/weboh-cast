import { useState, useCallback, useRef } from 'react';
import { DetectedVideo } from '../models/types';
import { parseVideoMessage, probeVideoMetadata } from '../services/videoDetector/VideoDetectionService';

export function useVideoDetection() {
  const [detectedVideos, setDetectedVideos] = useState<DetectedVideo[]>([]);
  const urlsRef = useRef(new Set<string>());

  const handleWebViewMessage = useCallback((data: string, pageTitle?: string, pageURL?: string) => {
    try {
      const msg = JSON.parse(data);
      if (msg.type !== 'videoDetected') return;

      const video = parseVideoMessage(JSON.stringify(msg.payload), pageTitle, pageURL);
      if (!video || urlsRef.current.has(video.url)) return;

      urlsRef.current.add(video.url);
      setDetectedVideos(prev => [...prev, video]);

      probeVideoMetadata(video).then(probed => {
        setDetectedVideos(prev => prev.map(v => v.id === probed.id ? probed : v));
      });
    } catch {}
  }, []);

  const clearDetected = useCallback(() => {
    setDetectedVideos([]);
    urlsRef.current.clear();
  }, []);

  return { detectedVideos, setDetectedVideos, handleWebViewMessage, clearDetected };
}
