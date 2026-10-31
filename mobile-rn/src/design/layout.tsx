import type { ReactNode } from 'react';
import {
  ActivityIndicator,
  FlatList,
  Keyboard,
  KeyboardAvoidingView,
  Alert,
  Platform,
  Pressable,
  RefreshControl,
  ScrollView,
  Switch,
  View,
  useWindowDimensions,
} from 'react-native';
import {
  SafeAreaView,
  useSafeAreaInsets,
} from 'react-native-safe-area-context';
import { useRouter } from 'expo-router';
import DateTimePicker from '@react-native-community/datetimepicker';
import { useState } from 'react';
import {
  AppText,
  Button,
  Card,
  Field,
  Gap,
  Icon,
  IconButton,
  type IconName,
} from './components';
import { useTheme } from './ThemeProvider';
import { Sheet } from './Sheet';
import { TouchSurface } from './TouchSurface';
import { fonts, spacing } from './tokens';
import { dateText, isoDate, label } from '../core/labels';

export function Page({
  title,
  children,
  back = true,
  scroll = true,
  keyboardAvoiding = false,
  refreshing = false,
  onRefresh,
  actions,
  embedded = false,
  toolbar = true,
  contentBottom = spacing.l,
  themeToggle = true,
  close = false,
  contentGap = spacing.m,
  contentTop = spacing.m,
  contentMax = 1100,
}: {
  title: string;
  children: ReactNode;
  back?: boolean;
  scroll?: boolean;
  keyboardAvoiding?: boolean;
  refreshing?: boolean;
  onRefresh?: () => void;
  actions?: ReactNode;
  embedded?: boolean;
  toolbar?: boolean;
  contentBottom?: number;
  themeToggle?: boolean;
  close?: boolean;
  contentGap?: number;
  contentTop?: number;
  contentMax?: number;
}) {
  const { mode, toggle } = useTheme();
  const router = useRouter();
  const insets = useSafeAreaInsets();
  const { width, fontScale } = useWindowDimensions();
  const [toolbarHeight, setToolbarHeight] = useState(0);
  const stackedActions = !!actions && (width < 380 || fontScale > 1.3);
  const content = (
    <View
      style={{
        width: '100%',
        maxWidth: contentMax,
        alignSelf: 'center',
        paddingHorizontal: spacing.page,
        paddingTop: contentTop,
        paddingBottom: contentBottom,
        gap: contentGap,
      }}
    >
      {children}
    </View>
  );
  return (
    <SafeAreaView
      edges={embedded ? [] : ['top', 'left', 'right', 'bottom']}
      style={{ flex: 1 }}
    >
      {toolbar && (
        <View
          onLayout={(event) =>
            setToolbarHeight(event.nativeEvent.layout.height)
          }
        >
          <View
            style={{
              minHeight: 60,
              paddingHorizontal: back ? spacing.xs : spacing.page,
              flexDirection: 'row',
              alignItems: 'center',
              gap: 8,
            }}
          >
            {back && (
              <IconButton
                label={close ? 'Kapat' : 'Geri'}
                icon={close ? 'close' : 'back'}
                onPress={() =>
                  router.canGoBack() ? router.back() : router.replace('/')
                }
              />
            )}
            <AppText
              variant="titleLarge"
              accessibilityRole="header"
              style={{ flex: 1, minWidth: 0 }}
            >
              {title}
            </AppText>
            {!stackedActions && actions}
            {themeToggle && (
              <IconButton
                surface
                label={mode === 'dark' ? 'Açık tema' : 'Koyu tema'}
                icon={mode === 'dark' ? 'light' : 'dark'}
                onPress={toggle}
              />
            )}
          </View>
          {stackedActions && (
            <View
              style={{
                paddingHorizontal: spacing.page,
                paddingBottom: spacing.s,
                alignItems: 'flex-end',
              }}
            >
              {actions}
            </View>
          )}
        </View>
      )}
      {scroll || keyboardAvoiding ? (
        <KeyboardAvoidingView
          style={{ flex: 1 }}
          behavior={Platform.OS === 'ios' ? 'padding' : 'height'}
          keyboardVerticalOffset={
            Platform.OS === 'ios'
              ? (embedded ? 0 : insets.top) + toolbarHeight
              : 0
          }
        >
          {scroll ? (
            <ScrollView
              contentContainerStyle={{ flexGrow: 1 }}
              keyboardShouldPersistTaps="handled"
              keyboardDismissMode="on-drag"
              refreshControl={
                onRefresh ? (
                  <RefreshControl
                    refreshing={refreshing}
                    onRefresh={onRefresh}
                  />
                ) : undefined
              }
            >
              {content}
            </ScrollView>
          ) : (
            children
          )}
        </KeyboardAvoidingView>
      ) : (
        children
      )}
    </SafeAreaView>
  );
}
export function Heading({
  title,
  description,
  icon = 'car',
}: {
  title: string;
  description?: string;
  icon?: IconName;
}) {
  const { colors } = useTheme();
  const { width, fontScale } = useWindowDimensions();
  return (
    <View
      style={{
        flexDirection: width < 360 || fontScale > 1.3 ? 'column' : 'row',
        alignItems: 'flex-start',
        gap: 14,
      }}
    >
      <View
        style={{
          width: 48,
          height: 48,
          borderRadius: 16,
          backgroundColor: colors.primaryContainer,
          alignItems: 'center',
          justifyContent: 'center',
        }}
      >
        <Icon name={icon} color={colors.primary} size={24} />
      </View>
      <View style={{ flexShrink: 1 }}>
        <AppText variant="headlineSmall" style={{ fontWeight: '900' }}>
          {title}
        </AppText>
        {description && <AppText>{description}</AppText>}
      </View>
    </View>
  );
}
export function Section({
  title,
  action,
  onPress,
}: {
  title: string;
  action?: string;
  onPress?: () => void;
}) {
  return (
    <View
      style={{
        flexDirection: 'row',
        flexWrap: 'wrap',
        alignItems: 'center',
        gap: 8,
        marginTop: 7,
      }}
    >
      <AppText
        variant="titleLarge"
        style={{ flexGrow: 1, flexShrink: 1, flexBasis: 160 }}
      >
        {title}
      </AppText>
      {action && onPress && (
        <View style={{ maxWidth: '100%' }}>
          <Button variant="text" label={action} onPress={onPress} />
        </View>
      )}
    </View>
  );
}
export function Tile({
  title,
  subtitle,
  icon = 'car',
  onPress,
  children,
}: {
  title: string;
  subtitle?: string;
  icon?: IconName;
  onPress?: () => void;
  children?: ReactNode;
}) {
  const { colors } = useTheme();
  return (
    <TouchSurface
      disabled={!onPress}
      onPress={onPress}
      accessibilityRole={onPress ? 'button' : undefined}
    >
      <Card>
        <View style={{ flexDirection: 'row', alignItems: 'center', gap: 14 }}>
          <View
            style={{
              width: 48,
              height: 48,
              borderRadius: 16,
              backgroundColor: colors.primaryContainer,
              alignItems: 'center',
              justifyContent: 'center',
            }}
          >
            <Icon name={icon} color={colors.primary} />
          </View>
          <View style={{ flex: 1, minWidth: 0 }}>
            <AppText variant="titleMedium">{title}</AppText>
            {subtitle && <AppText>{subtitle}</AppText>}
          </View>
          {onPress && <Icon name="chevron" color={colors.secondaryText} />}
        </View>
        {children}
      </Card>
    </TouchSurface>
  );
}
export function Badge({
  text,
  status,
  compact = false,
}: {
  text: string;
  status?: string | null;
  compact?: boolean;
}) {
  const { colors } = useTheme();
  const danger = ['OVERDUE', 'SEVERE', 'FAILED', 'EXPIRED'].includes(
    status ?? '',
  );
  const warning = ['UPCOMING', 'DUE_SOON', 'MINOR'].includes(status ?? ''),
    success = ['GOOD', 'NONE', 'COMPLETED', 'ACTIVE'].includes(status ?? '');
  const foreground = danger
    ? colors.error
    : status === 'MODERATE'
      ? colors.moderate
      : warning
        ? colors.warning
        : success
          ? colors.success
          : colors.primary;
  const background = danger
    ? colors.errorSoft
    : status === 'MODERATE'
      ? colors.moderateSoft
      : warning
        ? colors.warningSoft
        : success
          ? colors.successSoft
          : colors.primaryContainer;
  return (
    <View
      style={{
        alignSelf: 'flex-start',
        maxWidth: '100%',
        paddingHorizontal: compact ? 8 : 10,
        paddingVertical: compact ? 4 : 6,
        borderRadius: 999,
        backgroundColor: background,
      }}
    >
      <AppText
        variant="bodySmall"
        style={{
          color: foreground,
          ...(compact ? { fontSize: 10.5, lineHeight: 14.7 } : {}),
          fontFamily: fonts.medium,
        }}
      >
        {text}
      </AppText>
    </View>
  );
}
export function StateView({
  loading,
  error,
  empty,
  retry,
}: {
  loading?: boolean;
  error?: unknown;
  empty?: string;
  retry?: () => void;
}) {
  const { colors } = useTheme();
  return (
    <Card>
      <View style={{ paddingVertical: 24, alignItems: 'center', gap: 15 }}>
        {loading ? (
          <ActivityIndicator
            color={colors.primary}
            accessibilityLabel="Yükleniyor"
          />
        ) : (
          <Icon
            name={error ? 'warning' : 'car'}
            size={48}
            color={colors.primary}
          />
        )}
        <AppText
          accessibilityRole={error ? 'alert' : undefined}
          style={{ textAlign: 'center' }}
        >
          {loading
            ? 'Yükleniyor...'
            : error instanceof Error
              ? error.message
              : (empty ?? 'Kayıt bulunamadı.')}
        </AppText>
        {retry && (
          <Button label="Tekrar Dene" onPress={retry} variant="outlined" />
        )}
      </View>
    </Card>
  );
}
export function Select({
  title,
  value,
  items,
  onChange,
  disabled,
}: {
  title: string;
  value: string;
  items: readonly string[] | { value: string; title: string }[];
  onChange: (value: string) => void;
  disabled?: boolean;
}) {
  const { colors } = useTheme();
  const [open, setOpen] = useState(false);
  const [query, setQuery] = useState('');
  const options = items.map((item) =>
    typeof item === 'string' ? { value: item, title: label(item) } : item,
  );
  const selected = options.find((item) => item.value === value);
  const filtered = options.filter((item) =>
    item.title
      .toLocaleLowerCase('tr-TR')
      .includes(query.trim().toLocaleLowerCase('tr-TR')),
  );
  return (
    <View style={{ gap: spacing.s }}>
      <AppText variant="bodySmall">{title}</AppText>
      <TouchSurface
        accessibilityRole="button"
        accessibilityLabel={title}
        accessibilityHint="Seçenekleri aç"
        accessibilityValue={{ text: selected?.title ?? label(value) }}
        accessibilityState={{ disabled: !!disabled, expanded: open }}
        disabled={disabled}
        onPress={() => {
          Keyboard.dismiss();
          setQuery('');
          setOpen(true);
        }}
        style={{
          minHeight: 52,
          padding: 12,
          borderWidth: 1,
          borderColor: colors.border,
          borderRadius: 16,
          backgroundColor: colors.input,
          opacity: disabled ? 0.5 : 1,
          flexDirection: 'row',
          alignItems: 'center',
          gap: spacing.s,
        }}
      >
        <AppText variant="bodyLarge" style={{ flex: 1, minWidth: 0 }}>
          {selected?.title ?? label(value)}
        </AppText>
        <View style={{ transform: [{ rotate: '90deg' }] }}>
          <Icon name="chevron" color={colors.secondaryText} />
        </View>
      </TouchSurface>
      <Sheet
        visible={open}
        onClose={() => setOpen(false)}
        title={title + ' seçin'}
        scroll={false}
      >
        <FlatList
          data={filtered}
          keyExtractor={(item) => item.value}
          keyboardShouldPersistTaps="handled"
          keyboardDismissMode="on-drag"
          contentContainerStyle={{ gap: spacing.s, paddingVertical: spacing.s }}
          ListHeaderComponent={
            options.length > 12 ? (
              <Field
                label="Seçeneklerde ara"
                icon="search"
                value={query}
                onChangeText={setQuery}
                placeholder={title + ' ara'}
                autoCorrect={false}
              />
            ) : undefined
          }
          ListEmptyComponent={
            <AppText style={{ padding: spacing.m }}>
              Eşleşen seçenek bulunamadı.
            </AppText>
          }
          renderItem={({ item }) => (
            <TouchSurface
              accessibilityRole="button"
              accessibilityLabel={item.title}
              accessibilityState={{ selected: item.value === value }}
              onPress={() => {
                onChange(item.value);
                setOpen(false);
              }}
              style={{
                minHeight: 48,
                padding: 12,
                borderRadius: 12,
                flexDirection: 'row',
                alignItems: 'center',
                gap: spacing.s,
                backgroundColor:
                  item.value === value
                    ? colors.primaryContainer
                    : colors.surface,
              }}
            >
              <AppText
                style={{
                  flex: 1,
                  color:
                    item.value === value
                      ? colors.onPrimaryContainer
                      : colors.text,
                }}
              >
                {item.title}
              </AppText>
              {item.value === value && (
                <Icon name="verified" color={colors.primary} />
              )}
            </TouchSurface>
          )}
        />
      </Sheet>
    </View>
  );
}
export function DateField({
  title,
  value,
  onChange,
  optional = true,
  time = false,
}: {
  title: string;
  value: string;
  onChange: (value: string) => void;
  optional?: boolean;
  time?: boolean;
}) {
  const [stage, setStage] = useState<'date' | 'time' | null>(null),
    [pending, setPending] = useState(new Date());
  const { colors } = useTheme();
  const localDateTime = (date: Date) =>
    `${isoDate(date)}T${String(date.getHours()).padStart(2, '0')}:${String(date.getMinutes()).padStart(2, '0')}:00`;
  return (
    <View>
      <Pressable
        accessibilityRole="button"
        accessibilityLabel={title}
        onPress={() => {
          setPending(value ? new Date(value) : new Date());
          setStage('date');
        }}
        style={{
          minHeight: 60,
          paddingVertical: 12,
          flexDirection: 'row',
          alignItems: 'center',
          gap: 10,
        }}
      >
        <View style={{ flex: 1 }}>
          <AppText>{title}</AppText>
          <AppText variant="bodyLarge">
            {dateText(value)}
            {time && value
              ? ` ${new Date(value).toLocaleTimeString('tr-TR', { hour: '2-digit', minute: '2-digit' })}`
              : ''}
          </AppText>
        </View>
        <Icon name="calendar" color={colors.primary} />
      </Pressable>
      {optional && value && (
        <Button
          label="Tarihi temizle"
          variant="text"
          onPress={() => onChange('')}
        />
      )}
      {stage && (
        <DateTimePicker
          key={stage}
          value={pending}
          mode={Platform.OS === 'ios' && time ? 'datetime' : stage}
          minimumDate={new Date(1950, 0, 1)}
          maximumDate={new Date(new Date().getFullYear() + 10, 11, 31)}
          onChange={(event, date) => {
            if (event.type !== 'set' || !date) {
              setStage(null);
              return;
            }
            if (time && Platform.OS === 'android' && stage === 'date') {
              setPending(date);
              setStage('time');
              return;
            }
            setStage(null);
            onChange(time ? localDateTime(date) : isoDate(date));
          }}
        />
      )}
    </View>
  );
}
export function Toggle({
  title,
  value,
  onChange,
}: {
  title: string;
  value: boolean;
  onChange: (value: boolean) => void;
}) {
  const { colors } = useTheme();
  return (
    <View style={{ flexDirection: 'row', alignItems: 'center', gap: 12 }}>
      <AppText style={{ flex: 1 }}>{title}</AppText>
      <Switch
        accessibilityLabel={title}
        value={value}
        onValueChange={onChange}
        trackColor={{ true: colors.primary }}
      />
    </View>
  );
}
export function Columns({
  first,
  second,
}: {
  first: ReactNode;
  second: ReactNode;
}) {
  const { fontScale } = useWindowDimensions();
  const [available, setAvailable] = useState(0);
  return (
    <View
      onLayout={(event) => setAvailable(event.nativeEvent.layout.width)}
      style={{
        flexDirection: available >= 760 && fontScale <= 1.3 ? 'row' : 'column',
        gap: spacing.l,
      }}
    >
      <View style={{ flex: 1 }}>{first}</View>
      <View style={{ flex: 1 }}>{second}</View>
    </View>
  );
}
export function confirm(
  title: string,
  message: string,
  action: () => void,
  destructive = false,
) {
  Alert.alert(title, message, [
    { text: 'Vazgeç', style: 'cancel' },
    {
      text: destructive ? 'Sil' : 'Devam Et',
      style: destructive ? 'destructive' : 'default',
      onPress: action,
    },
  ]);
}
export { Gap };
