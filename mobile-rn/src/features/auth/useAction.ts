import { useEffect, useRef, useState } from 'react';
import { Keyboard } from 'react-native';
import { StaleSessionError } from '../../core/session';
import { useSnackbar } from '../../design/Snackbar';

export function useAction() {
  const [busy, setBusy] = useState(false);
  const pending = useRef(false);
  const mounted = useRef(true);
  const show = useSnackbar();
  useEffect(() => {
    mounted.current = true;
    return () => {
      mounted.current = false;
    };
  }, []);
  async function run(action: () => Promise<unknown>, success?: () => void) {
    if (pending.current) return;
    Keyboard.dismiss();
    pending.current = true;
    setBusy(true);
    try {
      await action();
      if (mounted.current) success?.();
    } catch (error) {
      if (mounted.current && !(error instanceof StaleSessionError))
        show(error instanceof Error ? error.message : 'İşlem tamamlanamadı.');
    } finally {
      pending.current = false;
      if (mounted.current) setBusy(false);
    }
  }
  return { busy, run, show };
}
