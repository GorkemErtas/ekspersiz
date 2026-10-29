import { useState } from 'react';
import { Pressable, View } from 'react-native';
import { api, session, useSession } from '../../core/runtime';
import { AppText, Icon } from '../../design/components';
import { Sheet } from '../../design/Sheet';
import { useTheme } from '../../design/ThemeProvider';
import { useAction } from '../auth/useAction';
export default function WorkspaceSwitcher() {
  const { profile, workspace } = useSession(),
    { colors } = useTheme(),
    [open, setOpen] = useState(false),
    action = useAction();
  const business = profile?.businessAccount;
  if (!business) return null;
  return (
    <>
      <Pressable
        accessibilityRole="button"
        accessibilityLabel="Hesap değiştir"
        accessibilityState={{ busy: action.busy }}
        disabled={action.busy}
        onPress={() => setOpen(true)}
        style={{
          marginHorizontal: 16,
          marginTop: 8,
          paddingHorizontal: 12,
          minHeight: 40,
          paddingVertical: 10,
          borderRadius: 14,
          backgroundColor: colors.low,
          flexDirection: 'row',
          gap: 10,
          alignItems: 'center',
        }}
      >
        <Icon
          name={workspace === 'BUSINESS' ? 'business' : 'person'}
          size={20}
        />
        <AppText variant="labelLarge" numberOfLines={1} style={{ flex: 1 }}>
          {workspace === 'BUSINESS' ? business.companyName : 'Kişisel Hesap'}
        </AppText>
        <Icon name="chevron" size={20} />
      </Pressable>
      <Sheet
        title="Hesap Değiştir"
        visible={open}
        onClose={() => setOpen(false)}
      >
        {(['PERSONAL', 'BUSINESS'] as const).map((value) => (
          <Pressable
            key={value}
            accessibilityRole="button"
            accessibilityState={{
              selected: workspace === value,
              disabled: value === 'BUSINESS' && !business.workspaceAvailable,
            }}
            disabled={value === 'BUSINESS' && !business.workspaceAvailable}
            onPress={() => {
              setOpen(false);
              if (value !== workspace)
                void action.run(() =>
                  session.select(value, () =>
                    api.request('/workspace', { workspace: value }),
                  ),
                );
            }}
            style={{
              minHeight: 72,
              paddingVertical: 12,
              flexDirection: 'row',
              gap: 12,
              alignItems: 'center',
              opacity:
                value === 'BUSINESS' && !business.workspaceAvailable ? 0.5 : 1,
            }}
          >
            <Icon name={value === 'BUSINESS' ? 'business' : 'person'} />
            <View style={{ flex: 1 }}>
              <AppText variant="titleMedium">
                {value === 'PERSONAL' ? 'Kişisel Hesap' : business.companyName}
              </AppText>
              <AppText variant="bodySmall">
                {value === 'PERSONAL'
                  ? 'Kendi araçlarınız ve kişisel kredileriniz'
                  : business.workspaceAvailable
                    ? 'Ortak araçlar ve şirket kredileri'
                    : 'Şirket aboneliği aktif değil. Kişisel alanınızı kullanabilirsiniz.'}
              </AppText>
            </View>
            {workspace === value && (
              <Icon name="verified" color={colors.primary} />
            )}
          </Pressable>
        ))}
      </Sheet>
    </>
  );
}
