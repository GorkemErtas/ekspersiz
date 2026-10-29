import { useRouter } from 'expo-router';
import { session } from '../src/core/runtime';
import { Button } from '../src/design/components';
import { Heading, Page } from '../src/design/layout';
export default function NotFound() {
  const router = useRouter();
  return (
    <Page title="Sayfa bulunamadı" back={false}>
      <Heading
        title="Bağlantı bulunamadı"
        description="Bu bağlantı geçersiz veya artık kullanılamıyor."
        icon="warning"
      />
      <Button
        label="Devam Et"
        onPress={() =>
          router.replace(session.getSnapshot().profile ? '/main' : '/login')
        }
      />
    </Page>
  );
}
