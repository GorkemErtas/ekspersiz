import { memo } from 'react';
import { View, Linking } from 'react-native';
import Markdown from '@ronradtke/react-native-markdown-display';
import type { ChatMessage } from '../../core/models';
import { AppText, Button } from '../../design/components';
import { useTheme } from '../../design/ThemeProvider';
import { fonts } from '../../design/tokens';
import { useSnackbar } from '../../design/Snackbar';
import { webLink } from '../../platform/links';
export const MessageBubble = memo(function MessageBubble({
  message,
}: {
  message: ChatMessage;
}) {
  const { colors } = useTheme(),
    show = useSnackbar();
  return (
    <View
      style={{
        alignSelf: message.role === 'user' ? 'flex-end' : 'flex-start',
        maxWidth: 620,
        width: '95%',
        backgroundColor:
          message.role === 'user' ? colors.primaryContainer : colors.surface,
        borderRadius: 20,
        borderWidth: 1,
        borderColor: colors.border,
        paddingHorizontal: 14,
        paddingVertical: 11,
      }}
    >
      {message.role === 'user' ? (
        <AppText variant="bodyLarge">{message.content}</AppText>
      ) : (
        <Markdown
          style={{
            body: {
              color: colors.text,
              fontFamily: fonts.regular,
              fontSize: 14,
              lineHeight: 21,
            },
            heading1: { color: colors.text, fontSize: 22 },
            heading2: { color: colors.text, fontSize: 20 },
            link: { color: colors.primary },
            code_inline: {
              backgroundColor: colors.highest,
              color: colors.text,
            },
            fence: { backgroundColor: colors.low, color: colors.text },
          }}
          onLinkPress={(url) => {
            try {
              void Linking.openURL(webLink(url)).catch(() =>
                show('Bağlantı açılamadı.'),
              );
            } catch {
              show('Bağlantı açılamadı.');
            }
            return false;
          }}
        >
          {message.content}
        </Markdown>
      )}
      {message.sources?.map((source, index) =>
        source.url ? (
          <Button
            key={index}
            label={source.name}
            variant="text"
            onPress={() => {
              try {
                void Linking.openURL(webLink(source.url!)).catch(() =>
                  show('Bağlantı açılamadı.'),
                );
              } catch {
                show('Bağlantı açılamadı.');
              }
            }}
          />
        ) : (
          <AppText key={index} variant="bodySmall">
            {source.name}
          </AppText>
        ),
      )}
    </View>
  );
});
