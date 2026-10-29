import type { ErrorBoundaryProps } from 'expo-router';
import { useRouter } from 'expo-router';
import { Button } from './components';
import { Heading, Page } from './layout';
export default function RouteErrorBoundary({ retry }: ErrorBoundaryProps) {
  const router = useRouter();
  return (
    <Page title="Sayfa açılamadı" back={false}>
      <Heading
        title="Bu sayfa açılamadı"
        description="Bağlantıyı kontrol edip yeniden deneyebilir veya ana sayfaya dönebilirsiniz."
        icon="warning"
      />
      <Button label="Yeniden Dene" onPress={() => void retry()} />
      <Button
        label="Ana Sayfa"
        variant="outlined"
        onPress={() => router.replace('/main')}
      />
    </Page>
  );
}
