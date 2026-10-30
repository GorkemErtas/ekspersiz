import type { ReactNode } from 'react';
import { Modal, Pressable, View, useWindowDimensions } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { AppText, IconButton } from './components';
import { useTheme } from './ThemeProvider';
export function Sheet({
  visible,
  onClose,
  title,
  children,
}: {
  visible: boolean;
  onClose: () => void;
  title: string;
  children: ReactNode;
}) {
  const { colors } = useTheme(),
    { height } = useWindowDimensions();
  return (
    <Modal
      visible={visible}
      transparent
      animationType="slide"
      onRequestClose={onClose}
    >
      <View
        style={{
          flex: 1,
          justifyContent: 'flex-end',
          backgroundColor: '#00000080',
        }}
      >
        <Pressable
          accessibilityLabel="Kapat"
          accessibilityRole="button"
          onPress={onClose}
          style={{ position: 'absolute', top: 0, left: 0, right: 0, bottom: 0 }}
        />
        <SafeAreaView
          edges={['bottom', 'left', 'right']}
          accessibilityViewIsModal
          style={{
            maxHeight: height * 0.72,
            width: '100%',
            maxWidth: 760,
            alignSelf: 'center',
            backgroundColor: colors.surface,
            borderTopLeftRadius: 28,
            borderTopRightRadius: 28,
            paddingTop: 10,
            paddingHorizontal: 18,
            paddingBottom: 14,
          }}
        >
          <View
            style={{
              width: 36,
              height: 4,
              borderRadius: 4,
              alignSelf: 'center',
              backgroundColor: colors.outline,
              marginBottom: 8,
            }}
          />
          <View style={{ flexDirection: 'row', alignItems: 'center', gap: 10 }}>
            <AppText
              accessibilityRole="header"
              variant="titleLarge"
              style={{ flex: 1 }}
            >
              {title}
            </AppText>
            <IconButton label="Kapat" icon="back" onPress={onClose} />
          </View>
          {children}
        </SafeAreaView>
      </View>
    </Modal>
  );
}
