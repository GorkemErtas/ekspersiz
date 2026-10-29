import { createContext, useContext } from 'react';
export const BootReadyContext = createContext(false);
export const useBootReady = () => useContext(BootReadyContext);
