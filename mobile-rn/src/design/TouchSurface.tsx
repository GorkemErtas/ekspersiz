import { useState } from 'react';
import {
  Pressable,
  type PressableProps,
  type StyleProp,
  type ViewStyle,
} from 'react-native';
import Animated, { useReducedMotion } from 'react-native-reanimated';
import { motion } from './tokens';

const AnimatedPressable = Animated.createAnimatedComponent(Pressable);

/** Shared press feedback for existing controls; actions fire immediately. */
export function TouchSurface({
  style,
  onPressIn,
  onPressOut,
  ...props
}: Omit<PressableProps, 'style'> & { style?: StyleProp<ViewStyle> }) {
  const [pressed, setPressed] = useState(false);
  const reduce = useReducedMotion();
  return (
    <AnimatedPressable
      {...props}
      onPressIn={(event) => {
        setPressed(true);
        onPressIn?.(event);
      }}
      onPressOut={(event) => {
        setPressed(false);
        onPressOut?.(event);
      }}
      style={[
        {
          opacity: pressed && !props.disabled ? 0.86 : 1,
          transform: [
            {
              scale:
                pressed && !props.disabled && !reduce ? motion.pressedScale : 1,
            },
          ],
          transitionProperty: ['opacity', 'transform'],
          transitionDuration: reduce ? 0 : motion.fast,
          transitionTimingFunction: 'ease-out',
        },
        style,
      ]}
    />
  );
}
