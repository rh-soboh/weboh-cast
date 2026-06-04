export const Colors = {
  orange: '#FF6D00',
  orangeLight: 'rgba(255, 109, 0, 0.15)',
  background: '#121217',
  surface: '#1C1C23',
  surfaceElevated: '#26262E',
  text: '#FFFFFF',
  textSecondary: '#999999',
  border: '#2A2A33',
  red: '#FF4444',
  green: '#4CAF50',
  black: '#000000',
  white: '#FFFFFF',
  transparent: 'transparent',
};

export const NavigationTheme = {
  dark: true,
  colors: {
    primary: Colors.orange,
    background: Colors.background,
    card: Colors.background,
    text: Colors.text,
    border: Colors.border,
    notification: Colors.orange,
  },
  fonts: {
    regular: { fontFamily: 'System', fontWeight: '400' as const },
    medium: { fontFamily: 'System', fontWeight: '500' as const },
    bold: { fontFamily: 'System', fontWeight: '700' as const },
    heavy: { fontFamily: 'System', fontWeight: '800' as const },
  },
};
