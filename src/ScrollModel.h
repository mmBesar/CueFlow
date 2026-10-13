#pragma once

#include <algorithm>
#include <cmath>

// Dependency-free playback model. Progress is normalized so changing font size or
// display dimensions preserves the reader's relative place in the script.
class ScrollModel final {
public:
    static constexpr double kDefaultSpeedPixelsPerSecond = 55.0;

    explicit ScrollModel(double speedPixelsPerSecond = kDefaultSpeedPixelsPerSecond)
        : speed_(std::max(0.0, speedPixelsPerSecond)) {}

    [[nodiscard]] double progress() const noexcept { return progress_; }
    [[nodiscard]] double speed() const noexcept { return speed_; }
    [[nodiscard]] bool playing() const noexcept { return playing_; }

    void setProgress(double value) noexcept { progress_ = clamp01(value); }
    void setSpeed(double value) noexcept { speed_ = std::clamp(value, 0.0, 1200.0); }
    void setPlaying(bool value) noexcept { playing_ = value; }
    void togglePlaying() noexcept { playing_ = !playing_; }
    void reset() noexcept { progress_ = 0.0; playing_ = false; }

    // Advances by physical pixels per second, normalized by the current range.
    // A delta-time cap avoids a visible jump after suspend/debugger pauses.
    // Returns true only when progress changed.
    bool advance(double elapsedSeconds, double scrollRangePixels) noexcept {
        if (!playing_ || speed_ <= 0.0 || scrollRangePixels <= 0.0 || !std::isfinite(elapsedSeconds))
            return false;

        const double dt = std::clamp(elapsedSeconds, 0.0, 0.05);
        if (dt <= 0.0)
            return false;

        const double before = progress_;
        progress_ = clamp01(progress_ + (speed_ * dt / scrollRangePixels));
        if (progress_ >= 1.0)
            playing_ = false;
        return progress_ != before;
    }

    // Precise small scroll adjustments, expressed in rendered pixels.
    bool nudgePixels(double deltaPixels, double scrollRangePixels) noexcept {
        if (!std::isfinite(deltaPixels) || !std::isfinite(scrollRangePixels) || scrollRangePixels <= 0.0)
            return false;
        const double before = progress_;
        progress_ = clamp01(progress_ + deltaPixels / scrollRangePixels);
        return progress_ != before;
    }

    [[nodiscard]] double offsetPixels(double scrollRangePixels) const noexcept {
        if (!std::isfinite(scrollRangePixels) || scrollRangePixels <= 0.0)
            return 0.0;
        return progress_ * scrollRangePixels;
    }

private:
    static double clamp01(double value) noexcept {
        if (!std::isfinite(value)) return 0.0;
        return std::clamp(value, 0.0, 1.0);
    }

    double progress_ = 0.0;
    double speed_ = kDefaultSpeedPixelsPerSecond;
    bool playing_ = false;
};
