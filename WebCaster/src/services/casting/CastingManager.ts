import { CastDevice, DetectedVideo } from '../../models/types';
import { DLNA } from './DLNAService';
import { Storage } from '../storage/PersistenceController';

export type CastingState = {
  devices: CastDevice[];
  connectedDevice: CastDevice | null;
  isDiscovering: boolean;
  isCasting: boolean;
  error: string | null;
};

const initialState: CastingState = {
  devices: [],
  connectedDevice: null,
  isDiscovering: false,
  isCasting: false,
  error: null,
};

let state = { ...initialState };
let listeners: ((s: CastingState) => void)[] = [];

function notify() {
  listeners.forEach(fn => fn({ ...state }));
}

export const CastingManager = {
  subscribe(fn: (s: CastingState) => void) {
    listeners.push(fn);
    fn({ ...state });
    return () => { listeners = listeners.filter(l => l !== fn); };
  },

  getState(): CastingState {
    return { ...state };
  },

  async startDiscovery() {
    if (state.isDiscovering) return;
    state = { ...state, isDiscovering: true, error: null, devices: [] };
    notify();

    const recent = await Storage.loadRecentDevices();
    state = { ...state, devices: recent, isDiscovering: false };
    notify();
  },

  async connect(device: CastDevice) {
    const updated: CastDevice = { ...device, state: 'connected', lastConnected: Date.now() };
    state = { ...state, connectedDevice: updated };
    await Storage.saveRecentDevice(updated);
    notify();
  },

  disconnect() {
    if (state.connectedDevice) {
      if (state.connectedDevice.protocol === 'dlna') {
        DLNA.stop(state.connectedDevice);
      }
    }
    state = { ...state, connectedDevice: null, isCasting: false };
    notify();
  },

  async cast(video: DetectedVideo) {
    const device = state.connectedDevice;
    if (!device) {
      state = { ...state, error: 'No device connected' };
      notify();
      return;
    }

    state = { ...state, isCasting: true, error: null };
    notify();

    let success = false;
    switch (device.protocol) {
      case 'dlna':
        success = await DLNA.cast(video, device);
        break;
      case 'chromecast':
        state = { ...state, error: 'Chromecast requires react-native-google-cast native module' };
        notify();
        return;
      case 'airplay':
        break;
    }

    if (success) {
      state = { ...state, connectedDevice: { ...device, state: 'playing' } };
    } else {
      state = { ...state, error: 'Failed to cast video', isCasting: false };
    }
    notify();
  },

  async pauseCasting() {
    const device = state.connectedDevice;
    if (!device) return;
    if (device.protocol === 'dlna') {
      const ok = await DLNA.pause(device);
      if (ok) state = { ...state, connectedDevice: { ...device, state: 'paused' } };
    }
    notify();
  },

  async resumeCasting() {
    const device = state.connectedDevice;
    if (!device) return;
    if (device.protocol === 'dlna') {
      const ok = await DLNA.play(device);
      if (ok) state = { ...state, connectedDevice: { ...device, state: 'playing' } };
    }
    notify();
  },

  async stopCasting() {
    const device = state.connectedDevice;
    if (!device) return;
    if (device.protocol === 'dlna') await DLNA.stop(device);
    state = { ...state, connectedDevice: { ...device, state: 'connected' }, isCasting: false };
    notify();
  },

  clearError() {
    state = { ...state, error: null };
    notify();
  },
};
