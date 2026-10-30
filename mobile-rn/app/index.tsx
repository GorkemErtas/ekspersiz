import { Redirect } from 'expo-router';
import { useSession } from '../src/core/runtime';
import { useBootReady } from '../src/core/BootContext';
export default function Index() {
  const { profile } = useSession();
  const ready = useBootReady();
  if (!ready) return null;
  return <Redirect href={profile ? '/main' : '/login'} />;
}
