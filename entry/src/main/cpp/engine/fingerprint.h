#pragma once
#include <vector>

#include "frame_analyzer.h"
#include "types.h"

namespace sns {

// Two active stretches separated by fewer inactive frames than this are one segment.
constexpr int kMinSegmentGapFrames = 2;

// Layout (29 floats):
//  [0..2]   top 3 peak frequencies / 8000, ascending, 0 if absent
//  [3..18]  mean band energy over active frames, sum 1
//  [19]     beep period in seconds / 2, clamped to [0,1]; 0 if not periodic (< 3 segments)
//  [20]     duty cycle (on-time / period); 0 if not periodic
//  [21..28] amplitude envelope resampled to 8 points, max = 1
// `frames` holds every frame from the event's first to its last active frame, `activeMask` flags
// which of them were active.
Fingerprint BuildFingerprint(const std::vector<FrameFeatures>& frames, const std::vector<bool>& activeMask,
                             double frameSec);

}  // namespace sns
