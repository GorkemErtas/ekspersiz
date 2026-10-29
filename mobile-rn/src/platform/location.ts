import * as Location from 'expo-location';
/** One foreground fix. Every exit removes the native GPS subscription. */
export async function currentPosition(
  signal: AbortSignal,
  timeoutMs = 20000,
): Promise<Location.LocationObject> {
  if (signal.aborted) throw new Error('Konum isteği iptal edildi.');
  const known = await Location.getLastKnownPositionAsync({
    maxAge: 30000,
    requiredAccuracy: 500,
  });
  if (signal.aborted) throw new Error('Konum isteği iptal edildi.');
  if (known) return known;
  return new Promise((resolve, reject) => {
    let finished = false,
      subscription: Location.LocationSubscription | undefined;
    const finish = (error?: Error, point?: Location.LocationObject) => {
      if (finished) return;
      finished = true;
      clearTimeout(timer);
      signal.removeEventListener('abort', cancel);
      subscription?.remove();
      if (error) reject(error);
      else if (point) resolve(point);
    };
    const cancel = () => finish(new Error('Konum isteği iptal edildi.'));
    const timer = setTimeout(
      () =>
        finish(
          new Error('Konum zamanında alınamadı. Açık alanda yeniden deneyin.'),
        ),
      timeoutMs,
    );
    signal.addEventListener('abort', cancel, { once: true });
    void Location.watchPositionAsync(
      {
        accuracy: Location.Accuracy.High,
        timeInterval: 1000,
        distanceInterval: 0,
      },
      (point) => finish(undefined, point),
      () =>
        finish(new Error('Konum alınamadı. Konum ayarlarını kontrol edin.')),
    )
      .then((value) => {
        subscription = value;
        if (finished) value.remove();
      })
      .catch((error) =>
        finish(error instanceof Error ? error : new Error('Konum alınamadı.')),
      );
  });
}
export async function positionCity(coords: Location.LocationObjectCoords) {
  let timer: ReturnType<typeof setTimeout> | undefined;
  try {
    return await Promise.race([
      Location.reverseGeocodeAsync(coords),
      new Promise<Location.LocationGeocodedAddress[]>((resolve) => {
        timer = setTimeout(() => resolve([]), 3000);
      }),
    ]);
  } finally {
    clearTimeout(timer);
  }
}
