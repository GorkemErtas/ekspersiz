import { useRouter } from 'expo-router';
import Guide from '../../src/features/onboarding/Guide';
export default function Replay() {
  const router = useRouter();
  return <Guide replay onFinish={() => router.back()} />;
}
