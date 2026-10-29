import { useEffect, useState, useSyncExternalStore } from 'react';
import { Image } from 'expo-image';
import { useSession } from '../core/runtime';
import {
  protectedImage,
  imageEpoch,
  subscribeImages,
} from '../platform/images';
import { StateView } from './layout';
export function InspectionPhoto({ id }: { id: number }) {
  const { generation } = useSession();
  const epoch = useSyncExternalStore(subscribeImages, imageEpoch, imageEpoch);
  const [retry, setRetry] = useState(0),
    [image, setImage] = useState<{
      uri: string;
      generation: number;
      epoch: number;
      id: number;
    } | null>(null),
    [error, setError] = useState<unknown>();
  useEffect(() => {
    let alive = true;
    const controller = new AbortController();
    const requestEpoch = imageEpoch();
    void protectedImage(id, controller.signal)
      .then((uri) => {
        if (alive) setImage({ uri, generation, epoch: requestEpoch, id });
      })
      .catch((reason) => {
        if (alive && !controller.signal.aborted) setError(reason);
      });
    return () => {
      alive = false;
      controller.abort();
    };
  }, [id, generation, retry]);
  return image?.generation === generation &&
    image.epoch === epoch &&
    image.id === id ? (
    <Image
      source={{ uri: image.uri }}
      accessibilityLabel="Hasar fotoğrafı"
      cachePolicy="none"
      recyclingKey={`${generation}-${epoch}-${id}`}
      contentFit="contain"
      style={{ width: '100%', height: 250, borderRadius: 16 }}
    />
  ) : (
    <StateView
      loading={!error}
      error={error}
      retry={() => {
        setError(undefined);
        setRetry((v) => v + 1);
      }}
    />
  );
}
