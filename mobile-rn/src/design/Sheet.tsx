import { useState, type ReactNode } from 'react';
import {
  KeyboardAvoidingView,
  Modal,
  Platform,
  Pressable,
  ScrollView,
  StyleSheet,
  View,
  useWindowDimensions,
} from 'react-native';
import {
  SafeAreaView,
  useSafeAreaInsets,
} from 'react-native-safe-area-context';
import Animated, { FadeInDown, ReduceMotion } from 'react-native-reanimated';
import { AppText, IconButton } from './components';
import { useTheme } from './ThemeProvider';
import { borders, motion, radius, spacing } from './tokens';

export function Sheet({
  visible,
  onClose,
  title,
  children,
  scroll = true,
}: {
  visible: boolean;
  onClose: () => void;
  title: string;
  children: ReactNode;
  scroll?: boolean;
}) {
  const { colors } = useTheme();
  const { height } = useWindowDimensions();
  const [containerHeight, setContainerHeight] = useState(height);
  const insets = useSafeAreaInsets();
  const viewport = Math.min(height, containerHeight);
  const available = Math.max(
    0,
    Math.min(viewport * 0.88, viewport - insets.top - spacing.m),
  );
  return (
    <Modal
      visible={visible}
      transparent
      animationType="none"
      onRequestClose={onClose}
    >
      <KeyboardAvoidingView
        behavior={Platform.OS === 'ios' ? 'padding' : 'height'}
        onLayout={(event) =>
          setContainerHeight(event.nativeEvent.layout.height)
        }
        style={{
          flex: 1,
          justifyContent: 'flex-end',
          backgroundColor: '#00000080',
        }}
      >
        <Pressable
          accessibilityLabel="Seçimi kapat"
          accessibilityRole="button"
          onPress={onClose}
          style={StyleSheet.absoluteFill}
        />
        <Animated.View
          entering={FadeInDown.duration(motion.medium).reduceMotion(
            ReduceMotion.System,
          )}
          style={{
            maxHeight: available,
            height: scroll ? undefined : available,
            width: '100%',
            maxWidth: 760,
            alignSelf: 'center',
            backgroundColor: colors.surface,
            borderWidth: borders.hairline,
            borderColor: colors.border,
            borderTopLeftRadius: radius.xlarge,
            borderTopRightRadius: radius.xlarge,
          }}
        >
          <SafeAreaView
            edges={['bottom', 'left', 'right']}
            accessibilityViewIsModal
            style={{
              flexShrink: 1,
              height: scroll ? undefined : '100%',
              paddingHorizontal: spacing.page,
              paddingTop: spacing.s,
              paddingBottom: spacing.s,
            }}
          >
            <View
              style={{
                width: spacing.xxl,
                height: spacing.xs,
                borderRadius: spacing.xs,
                alignSelf: 'center',
                backgroundColor: colors.border,
                marginBottom: spacing.s,
              }}
            />
            <View
              style={{
                flexDirection: 'row',
                alignItems: 'center',
                gap: spacing.s,
                marginBottom: spacing.s,
              }}
            >
              <AppText
                accessibilityRole="header"
                variant="titleLarge"
                style={{ flex: 1, minWidth: 0 }}
              >
                {title}
              </AppText>
              <IconButton label="Kapat" icon="close" onPress={onClose} />
            </View>
            {scroll ? (
              <ScrollView
                style={{ flexGrow: 0 }}
                keyboardShouldPersistTaps="handled"
                keyboardDismissMode="on-drag"
              >
                {children}
              </ScrollView>
            ) : (
              <View style={{ flex: 1, minHeight: 0 }}>{children}</View>
            )}
          </SafeAreaView>
        </Animated.View>
      </KeyboardAvoidingView>
    </Modal>
  );
}
