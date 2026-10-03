#include "ambient/trainer.hpp"

#include <algorithm>
#include <cmath>
#include <stdexcept>

namespace ambient {

namespace {
struct Segment {
    std::size_t n = 0;
    std::vector<float> bands;  // n * kBands
    std::vector<float> levels; // n
    float peak_db = -200.f;
};

std::string rec_name(std::size_t i) { return "recording " + std::to_string(i + 1); }

Segment cut_sound(Detector& det, const Recording& r, const TrainOptions& o, std::size_t idx,
                  double hop_s) {
    const FrameMatrix fm = det.extract_frames(r.samples, r.count);
    if (fm.frames < 8) throw std::invalid_argument(rec_name(idx) + " is too short");

    std::vector<float> sorted = fm.level_db;
    std::nth_element(sorted.begin(), sorted.begin() + static_cast<std::ptrdiff_t>(sorted.size() / 10),
                     sorted.end());
    const float floor_db = sorted[sorted.size() / 10];
    const float peak_db = *std::max_element(fm.level_db.begin(), fm.level_db.end());
    if (peak_db - floor_db < o.min_contrast_db)
        throw std::invalid_argument(rec_name(idx) + ": no clear sound above the background noise");

    const float thr = floor_db + std::max(8.f, 0.3f * (peak_db - floor_db));
    std::size_t first = fm.frames, last = 0;
    for (std::size_t i = 0; i < fm.frames; ++i) {
        if (fm.level_db[i] > thr) {
            first = std::min(first, i);
            last = i;
        }
    }
    if (static_cast<double>(last - first + 1) * hop_s > o.max_duration_s)
        throw std::invalid_argument(rec_name(idx) + ": sound is too long");

    const std::size_t m = static_cast<std::size_t>(std::max(0, o.margin_frames));
    const std::size_t s = first > m ? first - m : 0;
    const std::size_t e = std::min(fm.frames - 1, last + m);

    Segment seg;
    seg.n = e - s + 1;
    seg.bands.assign(fm.bands.begin() + static_cast<std::ptrdiff_t>(s * kBands),
                     fm.bands.begin() + static_cast<std::ptrdiff_t>((e + 1) * kBands));
    seg.levels.assign(fm.level_db.begin() + static_cast<std::ptrdiff_t>(s),
                      fm.level_db.begin() + static_cast<std::ptrdiff_t>(e + 1));
    for (float v : seg.levels) seg.peak_db = std::max(seg.peak_db, v);
    return seg;
}

// Linear time-stretch of an n x dim matrix to target x dim.
std::vector<float> resample(const std::vector<float>& src, std::size_t n, std::size_t dim,
                            std::size_t target) {
    std::vector<float> out(target * dim);
    for (std::size_t j = 0; j < target; ++j) {
        const double p = target > 1 ? static_cast<double>(j) * static_cast<double>(n - 1) /
                                          static_cast<double>(target - 1)
                                    : 0.0;
        const std::size_t i0 = static_cast<std::size_t>(p);
        const std::size_t i1 = std::min(i0 + 1, n - 1);
        const float w = static_cast<float>(p - static_cast<double>(i0));
        for (std::size_t b = 0; b < dim; ++b)
            out[j * dim + b] = src[i0 * dim + b] * (1.f - w) + src[i1 * dim + b] * w;
    }
    return out;
}

double dot(const std::vector<float>& a, const std::vector<float>& b) {
    double d = 0.0;
    for (std::size_t k = 0; k < a.size(); ++k) d += static_cast<double>(a[k]) * b[k];
    return d;
}

bool normalize(std::vector<float>& v) {
    double ss = 0.0;
    for (float x : v) ss += static_cast<double>(x) * x;
    if (ss < 1e-9) return false;
    const float inv = static_cast<float>(1.0 / std::sqrt(ss));
    for (auto& x : v) x *= inv;
    return true;
}
}  // namespace

TrainResult train_custom_sound(const Config& cfg, const std::string& name,
                               const std::vector<Recording>& recordings, const TrainOptions& opt) {
    if (name.empty() || name.size() > 256) throw std::invalid_argument("sound name must be 1..256 characters");
    if (recordings.empty()) throw std::invalid_argument("no recordings given");

    Detector det(cfg);  // validates cfg, provides the very same feature extraction as live detection
    const double hop_s = static_cast<double>(cfg.hop_size) / cfg.sample_rate;

    std::vector<Segment> segs;
    for (std::size_t i = 0; i < recordings.size(); ++i) {
        if (recordings[i].samples == nullptr || recordings[i].count == 0)
            throw std::invalid_argument(rec_name(i) + " is empty");
        segs.push_back(cut_sound(det, recordings[i], opt, i, hop_s));
    }

    std::vector<std::size_t> lens;
    for (const auto& s : segs) lens.push_back(s.n);
    std::sort(lens.begin(), lens.end());
    const std::size_t len = lens[lens.size() / 2];
    if (len < 4) throw std::invalid_argument("sound is too short");

    const std::size_t dim = len * kBands;
    std::vector<std::vector<float>> prepared, env;  // env[i] empty when that recording's envelope is flat
    float peak = -200.f;
    for (std::size_t i = 0; i < segs.size(); ++i) {
        std::vector<float> p(dim), e(len);
        const std::vector<float> rs = resample(segs[i].bands, segs[i].n, kBands, len);
        if (!prepare_window(rs.data(), dim, p.data()))
            throw std::invalid_argument(rec_name(i) + " has no spectral structure");
        const std::vector<float> lv = resample(segs[i].levels, segs[i].n, 1, len);
        if (!prepare_window(lv.data(), len, e.data())) e.clear();
        prepared.push_back(std::move(p));
        env.push_back(std::move(e));
        peak = std::max(peak, segs[i].peak_db);
    }
    bool use_env = true;
    for (const auto& e : env) use_env = use_env && !e.empty();

    float consistency = 1.f;
    for (std::size_t a = 0; a < prepared.size(); ++a) {
        for (std::size_t b = a + 1; b < prepared.size(); ++b) {
            double sim = dot(prepared[a], prepared[b]);
            if (use_env) sim = 0.5 * (sim + dot(env[a], env[b]));
            consistency = std::min(consistency, static_cast<float>(sim));
        }
    }
    if (consistency < opt.min_consistency)
        throw std::invalid_argument("recordings do not match each other (similarity " +
                                    std::to_string(consistency) + "); record the sound again");

    std::vector<float> avg(dim, 0.f), avg_env(use_env ? len : 0, 0.f);
    for (std::size_t i = 0; i < prepared.size(); ++i) {
        for (std::size_t k = 0; k < dim; ++k) avg[k] += prepared[i][k];
        if (use_env)
            for (std::size_t k = 0; k < len; ++k) avg_env[k] += env[i][k];
    }
    if (!normalize(avg)) throw std::invalid_argument("recordings cancel out");
    if (use_env && !normalize(avg_env)) avg_env.clear();

    TrainResult res;
    res.consistency = consistency;
    res.duration_s = static_cast<float>(static_cast<double>(len) * hop_s);
    CustomSound& s = res.sound;
    s.name = name;
    s.sample_rate = static_cast<std::uint32_t>(cfg.sample_rate);
    s.frame_size = static_cast<std::uint32_t>(cfg.frame_size);
    s.hop_size = static_cast<std::uint32_t>(cfg.hop_size);
    s.frames = static_cast<std::uint32_t>(len);
    s.threshold = segs.size() == 1 ? opt.default_threshold
                                   : std::min(0.9f, std::max(0.7f, consistency - 0.1f));
    s.min_level_db = std::max(peak - 20.f, -75.f);
    s.refractory_s = opt.refractory_s;
    s.tmpl = std::move(avg);
    s.env = std::move(avg_env);

    // Self-check at enrolment: the template must recognise each of its own recordings,
    // otherwise it would fail silently in the field.
    for (std::size_t i = 0; i < recordings.size(); ++i) {
        Detector probe(cfg);
        probe.add_custom_sound(s);
        std::vector<std::int16_t> pcm(recordings[i].samples, recordings[i].samples + recordings[i].count);
        pcm.resize(pcm.size() + static_cast<std::size_t>(cfg.sample_rate), 0);  // let the matcher settle
        bool found = false;
        for (const Event& e : probe.process(pcm.data(), pcm.size()))
            found = found || e.type == EventType::Custom;
        if (!found)
            throw std::invalid_argument(rec_name(i) + " is not reliably recognised by the learned sound; "
                                                      "record it again");
    }
    return res;
}

}  // namespace ambient
