import React, { useRef, useCallback } from 'react';
import { View, StyleSheet, PanResponder, LayoutChangeEvent } from 'react-native';
import { Colors } from '../theme/colors';

interface Props {
  value: number;
  maximumValue: number;
  onValueChange: (value: number) => void;
}

export function CustomSlider({ value, maximumValue, onValueChange }: Props) {
  const widthRef = useRef(0);

  const onLayout = useCallback((e: LayoutChangeEvent) => {
    widthRef.current = e.nativeEvent.layout.width;
  }, []);

  const panResponder = useRef(
    PanResponder.create({
      onStartShouldSetPanResponder: () => true,
      onMoveShouldSetPanResponder: () => true,
      onPanResponderGrant: (e) => {
        const x = e.nativeEvent.locationX;
        const pct = Math.max(0, Math.min(1, x / widthRef.current));
        onValueChange(pct * maximumValue);
      },
      onPanResponderMove: (e) => {
        const x = e.nativeEvent.locationX;
        const pct = Math.max(0, Math.min(1, x / widthRef.current));
        onValueChange(pct * maximumValue);
      },
    })
  ).current;

  const pct = maximumValue > 0 ? (value / maximumValue) * 100 : 0;

  return (
    <View style={styles.container} onLayout={onLayout} {...panResponder.panHandlers}>
      <View style={styles.track}>
        <View style={[styles.fill, { width: `${pct}%` }]} />
        <View style={[styles.thumb, { left: `${pct}%` }]} />
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, height: 30, justifyContent: 'center' },
  track: { height: 4, backgroundColor: 'rgba(255,255,255,0.3)', borderRadius: 2, position: 'relative' },
  fill: { height: 4, backgroundColor: Colors.orange, borderRadius: 2 },
  thumb: { position: 'absolute', top: -6, width: 16, height: 16, borderRadius: 8, backgroundColor: Colors.orange, marginLeft: -8 },
});
