// Legacy metronome implementation - preserved for reference
// This is the original Timer.periodic-based implementation that was
// replaced by RockSolidMetronome for improved timing accuracy.
//
// Key differences:
// - Original: Used Timer.periodic which accumulates timing drift
// - New: Uses timestamp-based scheduling for rock-solid timing
// - Original: Audio could stutter on first beat
// - New: Audio preloading and warm-up prevents first-beat stutter
//
// This file is kept for historical reference and can be removed
// once the new implementation is verified to work correctly.
