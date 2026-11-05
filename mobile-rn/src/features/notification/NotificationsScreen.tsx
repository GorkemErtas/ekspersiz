import { spacing } from '../../design/tokens';
import { FlatList, View } from 'react-native';
import { useRouter } from 'expo-router';
import { notifications, vehicles } from '../../core/services';
import { invalidate, useResource } from '../../core/queries';
import { dateText } from '../../core/labels';
import { AppText, Button, Gap } from '../../design/components';
import {
  Badge,
  layoutStyles,
  Page,
  StateView,
  Tile,
} from '../../design/layout';
import { useAction } from '../auth/useAction';
export default function NotificationsScreen() {
  const router = useRouter(),
    action = useAction(),
    items = useResource('notifications', notifications.list);
  return (
    <Page
      title="Bildirimler"
      scroll={false}
      actions={
        <Button
          label="Tümünü oku"
          variant="text"
          disabled={action.busy || !items.data?.some((item) => !item.read)}
          onPress={() =>
            void action.run(async () => {
              await notifications.readAll();
              await invalidate('notifications', 'notifications/unread');
            })
          }
        />
      }
    >
      {items.isPending || items.error ? (
        <View style={{ padding: spacing.page }}>
          <StateView
            loading={items.isPending}
            error={items.error}
            retry={() => void items.refetch()}
          />
        </View>
      ) : (
        <FlatList
          data={items.data}
          keyExtractor={(item) => String(item.id)}
          contentContainerStyle={layoutStyles.listContent}
          refreshing={items.isRefetching}
          onRefresh={() => void items.refetch()}
          ListEmptyComponent={<StateView empty="Henüz bildiriminiz yok." />}
          renderItem={({ item }) => (
            <Tile
              title={item.title}
              subtitle={item.body}
              icon="bell"
              onPress={() =>
                void action.run(async () => {
                  if (!item.read) {
                    await notifications.read(item.id);
                    await invalidate('notifications', 'notifications/unread');
                  }
                  if (item.vehicleId) {
                    await vehicles.get(item.vehicleId);
                    router.push(`/vehicle/${item.vehicleId}`);
                  }
                })
              }
            >
              <Gap />
              <View
                style={{
                  flexDirection: 'row',
                  flexWrap: 'wrap',
                  justifyContent: 'space-between',
                }}
              >
                <AppText variant="bodySmall">
                  {dateText(item.createdAt)}
                </AppText>
                {!item.read && <Badge text="Yeni" status={item.severity} />}
              </View>
            </Tile>
          )}
        />
      )}
    </Page>
  );
}
