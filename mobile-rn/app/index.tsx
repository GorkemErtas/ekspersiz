import { Redirect } from 'expo-router';
import { useSession } from '../src/core/runtime';
export default function Index() {
  const { profile } = useSession();
  return <Redirect href={profile ? '/account' : '/login'} />;
}
