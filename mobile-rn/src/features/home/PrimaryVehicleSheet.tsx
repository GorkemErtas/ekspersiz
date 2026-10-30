import { FlatList, View } from 'react-native';
import type { Vehicle } from '../../core/models';
import { vehicles } from '../../core/services';
import { invalidate } from '../../core/queries';
import { AppText, Icon } from '../../design/components';
import { Sheet } from '../../design/Sheet';
import { Tile } from '../../design/layout';
import { useTheme } from '../../design/ThemeProvider';
import { useAction } from '../auth/useAction';
export default function PrimaryVehicleSheet({
  items,
  selected,
  visible,
  onClose,
}: {
  items: Vehicle[];
  selected?: number;
  visible: boolean;
  onClose: () => void;
}) {
  const { colors } = useTheme(),
    action = useAction();
  return (
    <Sheet visible={visible} onClose={onClose} title="Ana Aracı Seç">
      <FlatList
        data={items}
        keyExtractor={(item) => String(item.id)}
        contentContainerStyle={{ paddingVertical: 12, gap: 8 }}
        renderItem={({ item }) => (
          <Tile
            title={`${item.brand} ${item.model}`}
            subtitle={`${item.plate} • ${item.modelYear}`}
            onPress={() => {
              onClose();
              if (item.id !== selected)
                void action.run(async () => {
                  await vehicles.primary(item.id);
                  await invalidate('vehicles');
                });
            }}
          >
            <View
              style={{
                flexDirection: 'row',
                alignItems: 'center',
                paddingTop: 10,
              }}
            >
              <AppText style={{ flex: 1 }}>
                {item.mileage.toLocaleString('tr-TR')} km
              </AppText>
              {item.id === selected && (
                <Icon name="verified" color={colors.primary} />
              )}
            </View>
          </Tile>
        )}
      />
    </Sheet>
  );
}
