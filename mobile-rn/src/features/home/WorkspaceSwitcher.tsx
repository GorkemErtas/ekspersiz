import { useState } from 'react';
import { View } from 'react-native';
import { api, session, useSession } from '../../core/runtime';
import { AppText, Icon } from '../../design/components';
import { Sheet } from '../../design/Sheet';
import { useTheme } from '../../design/ThemeProvider';
import { TouchSurface } from '../../design/TouchSurface';
import { dimensions, radius, spacing } from '../../design/tokens';
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
      <TouchSurface
        accessibilityRole="button"
        accessibilityLabel="Hesap değiştir"
        accessibilityState={{
          busy: action.busy,
          disabled: action.busy,
          expanded: open,
        }}
        accessibilityValue={{
          text:
            workspace === 'BUSINESS' ? business.companyName : 'Kişisel Hesap',
        }}
        disabled={action.busy}
        onPress={() => setOpen(true)}
        style={{
          marginHorizontal: spacing.page,
          marginTop: spacing.s,
          paddingHorizontal: spacing.sm,
          minHeight: dimensions.touch,
          paddingVertical: spacing.sm,
          borderRadius: radius.small,
          borderWidth: 1,
          borderColor: colors.border,
          backgroundColor: colors.low,
          flexDirection: 'row',
          gap: spacing.s,
          alignItems: 'center',
        }}
      >
        <Icon
          name={workspace === 'BUSINESS' ? 'business' : 'person'}
          size={20}
        />
        <AppText variant="titleSmall" style={{ flex: 1, minWidth: 0 }}>
          {workspace === 'BUSINESS' ? business.companyName : 'Kişisel Hesap'}
        </AppText>
        <Icon name="chevron" size={20} />
      </TouchSurface>
      <Sheet
        title="Hesap Değiştir"
        visible={open}
        onClose={() => setOpen(false)}
      >
        {(['PERSONAL', 'BUSINESS'] as const).map((value) => (
          <TouchSurface
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
              paddingVertical: spacing.sm,
              flexDirection: 'row',
              gap: spacing.sm,
              alignItems: 'center',
              opacity:
                value === 'BUSINESS' && !business.workspaceAvailable ? 0.5 : 1,
            }}
          >
            <Icon name={value === 'BUSINESS' ? 'business' : 'person'} />
            <View style={{ flex: 1, minWidth: 0 }}>
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
          </TouchSurface>
        ))}
      </Sheet>
    </>
  );
}
