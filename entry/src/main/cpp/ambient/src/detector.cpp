#include "ambient/detector.hpp"

#include <algorithm>
#include <cmath>
#include <stdexcept>

namespace ambient {

namespace {
constexpr float kPi = 3.14159265358979323846f;
constexpr float kEps = 1e-9f;
constexpr int kPeakHalfWidth = 3;   // bins around the spectral peak
constexpr float kMinAnalysisHz = 100.f;
constexpr float kExplainMarginDb = 6.f;  // custom match hides built-in events up to this much louder

float clamp01(float v) { return std::min(1.f, std::max(0.f, v)); }
}  // namespace

const char* to_string(EventType t) {
    switch (t) {
        case EventType::Alarm: return "alarm";
        case EventType::Knock: return "knock";
        case EventType::LoudSound: return "loud_sound";
        case EventType::Custom: return "custom";
    }
    return "unknown";
}

void Config::validate() const {
    if (sample_rate < 8000) throw std::invalid_argument("sample_rate too low");
    if (frame_size < 64 || (frame_size & (frame_size - 1)) != 0)
        throw std::invalid_argument("frame_size must be a power of two >= 64");
    if (hop_size == 0 || hop_size > frame_size)
        throw std::invalid_argument("hop_size must be in (0, frame_size]");
    if (tonal_ratio_min <= 0.f || tonal_ratio_min > 1.f)
        throw std::invalid_argument("tonal_ratio_min must be in (0, 1]");
    if (alarm_min_hz >= alarm_max_hz || alarm_max_hz > sample_rate / 2.f)
        throw std::invalid_argument("invalid alarm frequency range");
    if (custom_hold_s < 0.f) throw std::invalid_argument("custom_hold_s must be >= 0");
    if (sample_rate > 192000 || frame_size > 16384)
        throw std::invalid_argument("sample_rate / frame_size too large");
    if (!std::isfinite(min_level_db) || min_level_db > 0.f)
        throw std::invalid_argument("min_level_db must be finite and <= 0");
    if (!(onset_db > 0.f) || !(decay_db > 0.f) || !std::isfinite(onset_db) || !std::isfinite(decay_db))
        throw std::invalid_argument("onset_db / decay_db must be > 0");
    if (!(alarm_min_s > 0.f) || !(knock_max_s > 0.f))
        throw std::invalid_argument("alarm_min_s / knock_max_s must be > 0");
    if (alarm_gap_frames < 0) throw std::invalid_argument("alarm_gap_frames must be >= 0");
    if (!(background_alpha > 0.f && background_alpha <= 1.f))
        throw std::invalid_argument("background_alpha must be in (0, 1]");
}

Detector::Detector(Config cfg)
    : cfg_((cfg.validate(), cfg)),
      fft_(cfg_.frame_size),
      window_(cfg_.frame_size),
      spec_(cfg_.frame_size),
      bank_(cfg_.sample_rate, cfg_.frame_size),
      bands_(kBands) {
    for (std::size_t i = 0; i < cfg_.frame_size; ++i) {  // Hann
        window_[i] = 0.5f - 0.5f * std::cos(2.f * kPi * static_cast<float>(i) /
                                            static_cast<float>(cfg_.frame_size));
    }
    hop_s_ = static_cast<float>(cfg_.hop_size) / static_cast<float>(cfg_.sample_rate);
    matcher_.configure(static_cast<double>(cfg_.hop_size) / cfg_.sample_rate,
                       static_cast<double>(cfg_.frame_size) / cfg_.sample_rate);
}

std::vector<std::string> Detector::custom_sound_names() const {
    std::lock_guard<std::mutex> lk(mu_);
    return matcher_.names();
}

double Detector::stream_time_s() const {
    std::lock_guard<std::mutex> lk(mu_);
    return static_cast<double>(consumed_ + read_) / static_cast<double>(cfg_.sample_rate);
}

int Detector::add_custom_sound(const CustomSound& s) {
    validate_sound(s);
    std::lock_guard<std::mutex> lk(mu_);
    if (static_cast<int>(s.sample_rate) != cfg_.sample_rate || s.frame_size != cfg_.frame_size ||
        s.hop_size != cfg_.hop_size)
        throw std::invalid_argument("custom sound was trained with a different sample_rate/frame/hop");
    return matcher_.add(s);
}

bool Detector::remove_custom_sound(const std::string& name) {
    std::lock_guard<std::mutex> lk(mu_);
    return matcher_.remove(name);
}

std::vector<Event> Detector::flush() {
    std::lock_guard<std::mutex> lk(mu_);
    std::vector<Event> out;
    out.swap(held_);
    return out;
}

void Detector::release_held(double now, std::vector<Event>& out) {
    std::size_t keep = 0;
    for (auto& e : held_) {
        if (now - e.time_s >= cfg_.custom_hold_s) out.push_back(std::move(e));
        else held_[keep++] = std::move(e);
    }
    held_.resize(keep);
}

FrameMatrix Detector::extract_frames(const std::int16_t* samples, std::size_t count) {
    std::lock_guard<std::mutex> lk(mu_);
    FrameMatrix m;
    if (samples == nullptr) return m;
    std::vector<float> buf(count);
    for (std::size_t i = 0; i < count; ++i) buf[i] = static_cast<float>(samples[i]) / 32768.f;
    for (std::size_t pos = 0; pos + cfg_.frame_size <= count; pos += cfg_.hop_size) {
        const Features f = analyze(buf.data() + pos, true);
        m.level_db.push_back(f.level_db);
        m.bands.insert(m.bands.end(), bands_.begin(), bands_.end());
        ++m.frames;
    }
    return m;
}

void Detector::reset_state() {
    tonal_run_ = miss_run_ = 0;
    alarm_active_ = false;
    state_ = State::Idle;
    bg_init_ = false;
    bg_db_ = -90.f;
    onset_frames_ = tonal_frames_ = 0;
    peak_db_ = -90.f;
    jump_db_ = 0.f;
}

void Detector::reset() {
    std::lock_guard<std::mutex> lk(mu_);
    held_.clear();
    matcher_.reset();
    pending_.clear();
    read_ = 0;
    consumed_ = 0;
    reset_state();
}

std::vector<Event> Detector::process(const std::int16_t* samples, std::size_t count) {
    std::vector<Event> out;
    if (samples == nullptr || count == 0) return out;
    std::lock_guard<std::mutex> lk(mu_);

    pending_.reserve(pending_.size() + count);
    for (std::size_t i = 0; i < count; ++i) {
        pending_.push_back(static_cast<float>(samples[i]) / 32768.f);
    }

    while (pending_.size() - read_ >= cfg_.frame_size) {
        const bool custom = !matcher_.empty();
        const Features f = analyze(pending_.data() + read_, custom);
        const double t = static_cast<double>(consumed_ + read_ + cfg_.frame_size) /
                         static_cast<double>(cfg_.sample_rate);

        frame_ev_.clear();
        on_frame(f, t, frame_ev_);
        for (auto& e : frame_ev_) {
            const bool holdable = e.type == EventType::Knock || e.type == EventType::LoudSound;
            if (custom && holdable && cfg_.custom_hold_s > 0.f) held_.push_back(std::move(e));
            else out.push_back(std::move(e));
        }

        if (custom) {
            matches_.clear();
            matcher_.push(bands_.data(), f.level_db, t, matches_);
            for (const auto& m : matches_) {
                const CustomSound* s = matcher_.find(m.id);
                if (s == nullptr) continue;
                // The sound is explained by the custom match: drop built-in events inside it.
                // A much louder transient is NOT explained by it and stays reported.
                held_.erase(std::remove_if(held_.begin(), held_.end(),
                                           [&](const Event& h) {
                                               return h.time_s >= m.start_s - hop_s_ &&
                                                      h.level_db <= m.level_db + kExplainMarginDb;
                                           }),
                            held_.end());
                Event e{EventType::Custom,
                        clamp01(0.5f + 0.5f * (m.score - s->threshold) / (1.f - s->threshold)),
                        m.time_s, 0.f, m.level_db};
                e.start_s = m.start_s;
                e.sound_id = m.id;
                e.label = s->name;
                out.push_back(std::move(e));
            }
        }
        release_held(t, out);
        read_ += cfg_.hop_size;
    }

    if (read_ > 0) {  // drop consumed samples
        pending_.erase(pending_.begin(), pending_.begin() + static_cast<std::ptrdiff_t>(read_));
        consumed_ += read_;
        read_ = 0;
    }
    return out;
}

Detector::Features Detector::analyze(const float* frame, bool with_bands) {
    const std::size_t n = cfg_.frame_size;

    double sum_sq = 0.0;
    for (std::size_t i = 0; i < n; ++i) {
        sum_sq += static_cast<double>(frame[i]) * frame[i];
        spec_[i] = {frame[i] * window_[i], 0.f};
    }
    const float rms = static_cast<float>(std::sqrt(sum_sq / static_cast<double>(n)));
    const float level_db = 20.f * std::log10(rms + kEps);

    fft_.forward(spec_.data());
    if (with_bands) bank_.compute(spec_.data(), bands_.data());

    const float bin_hz = static_cast<float>(cfg_.sample_rate) / static_cast<float>(n);
    const std::size_t half = n / 2;
    const std::size_t lo = std::max<std::size_t>(
        static_cast<std::size_t>(kMinAnalysisHz / bin_hz), kPeakHalfWidth + 1);

    double total = 0.0;
    float best = 0.f;
    std::size_t peak = lo;
    for (std::size_t k = lo; k < half; ++k) {
        const float p = std::norm(spec_[k]);
        total += p;
        if (p > best) {
            best = p;
            peak = k;
        }
    }

    double peak_energy = 0.0;
    const std::size_t a = peak - kPeakHalfWidth;
    const std::size_t b = std::min(half - 1, peak + kPeakHalfWidth);
    for (std::size_t k = a; k <= b; ++k) peak_energy += std::norm(spec_[k]);

    Features f;
    f.level_db = level_db;
    f.peak_hz = static_cast<float>(peak) * bin_hz;
    f.tonal_ratio = total > 0.0 ? static_cast<float>(peak_energy / total) : 0.f;
    return f;
}

void Detector::on_frame(const Features& f, double t, std::vector<Event>& out) {
    const bool audible = f.level_db >= cfg_.min_level_db;

    // ---- Alarm: sustained narrow-band tone --------------------------------
    const bool tonal = audible && f.tonal_ratio >= cfg_.tonal_ratio_min &&
                       f.peak_hz >= cfg_.alarm_min_hz && f.peak_hz <= cfg_.alarm_max_hz;
    if (tonal) {
        ++tonal_run_;
        miss_run_ = 0;
    } else if (++miss_run_ > cfg_.alarm_gap_frames) {
        tonal_run_ = 0;
        alarm_active_ = false;
    }
    if (!alarm_active_ && static_cast<float>(tonal_run_) * hop_s_ >= cfg_.alarm_min_s) {
        alarm_active_ = true;
        out.push_back({EventType::Alarm, clamp01(f.tonal_ratio), t, f.peak_hz, f.level_db});
    }

    // ---- Transients: Knock / LoudSound -------------------------------------
    if (!bg_init_) {
        bg_db_ = f.level_db;
        bg_init_ = true;
    }

    switch (state_) {
        case State::Idle:
            if (audible && f.level_db - bg_db_ >= cfg_.onset_db) {
                state_ = State::Onset;
                onset_frames_ = 1;
                tonal_frames_ = tonal ? 1 : 0;
                peak_db_ = f.level_db;
                jump_db_ = f.level_db - bg_db_;
            } else {
                bg_db_ += cfg_.background_alpha * (f.level_db - bg_db_);
            }
            break;

        case State::Onset: {
            ++onset_frames_;
            if (tonal) ++tonal_frames_;
            peak_db_ = std::max(peak_db_, f.level_db);

            if (f.level_db < peak_db_ - cfg_.decay_db) {
                // Energy died away quickly: short transient.
                out.push_back({EventType::Knock, clamp01(jump_db_ / 30.f), t, 0.f, peak_db_});
                state_ = State::Sustained;
            } else if (static_cast<float>(onset_frames_) * hop_s_ > cfg_.knock_max_s) {
                // Still loud after knock_max_s: sustained sound.
                const bool mostly_tonal = tonal_frames_ * 10 > onset_frames_ * 6;
                if (!mostly_tonal) {  // tones are the alarm detector's job
                    out.push_back({EventType::LoudSound, clamp01(jump_db_ / 30.f), t, 0.f, peak_db_});
                }
                state_ = State::Sustained;
            }
            break;
        }

        case State::Sustained:
            bg_db_ += cfg_.background_alpha * (f.level_db - bg_db_);  // adapt to new ambience
            if (f.level_db < bg_db_ + cfg_.onset_db * 0.5f) state_ = State::Idle;
            break;
    }
}

}  // namespace ambient
