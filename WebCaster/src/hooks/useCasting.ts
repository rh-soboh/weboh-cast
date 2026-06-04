import { useState, useEffect, useCallback } from 'react';
import { CastingManager, CastingState } from '../services/casting/CastingManager';
import { DetectedVideo, CastDevice } from '../models/types';

export function useCasting() {
  const [state, setState] = useState<CastingState>(CastingManager.getState());

  useEffect(() => {
    return CastingManager.subscribe(setState);
  }, []);

  const startDiscovery = useCallback(() => CastingManager.startDiscovery(), []);
  const connect = useCallback((d: CastDevice) => CastingManager.connect(d), []);
  const disconnect = useCallback(() => CastingManager.disconnect(), []);
  const cast = useCallback((v: DetectedVideo) => CastingManager.cast(v), []);
  const pause = useCallback(() => CastingManager.pauseCasting(), []);
  const resume = useCallback(() => CastingManager.resumeCasting(), []);
  const stop = useCallback(() => CastingManager.stopCasting(), []);

  return {
    ...state,
    startDiscovery,
    connect,
    disconnect,
    cast,
    pause,
    resume,
    stop,
  };
}
