// Runs the engine over a WAV file and prints one line per detected event.
// Supports 16-bit PCM mono 16 kHz only. One second of silence is appended so a trailing event closes.
#include <algorithm>
#include <cstdint>
#include <cstdio>
#include <cstring>
#include <vector>

#include "engine.h"

namespace {

bool ReadAll(const char* path, std::vector<uint8_t>* bytes) {
    FILE* f = std::fopen(path, "rb");
    if (!f) return false;
    uint8_t buf[4096];
    size_t n;
    while ((n = std::fread(buf, 1, sizeof buf, f)) > 0) bytes->insert(bytes->end(), buf, buf + n);
    std::fclose(f);
    return true;
}

uint32_t U32(const uint8_t* p) { return p[0] | (p[1] << 8) | (p[2] << 16) | (static_cast<uint32_t>(p[3]) << 24); }
uint16_t U16(const uint8_t* p) { return static_cast<uint16_t>(p[0] | (p[1] << 8)); }

}  // namespace

int main(int argc, char** argv) {
    if (argc != 2) {
        std::fprintf(stderr, "usage: wav_cli <file.wav>\n");
        return 2;
    }
    std::vector<uint8_t> b;
    if (!ReadAll(argv[1], &b)) {
        std::fprintf(stderr, "cannot read %s\n", argv[1]);
        return 1;
    }
    if (b.size() < 12 || std::memcmp(b.data(), "RIFF", 4) != 0 || std::memcmp(b.data() + 8, "WAVE", 4) != 0) {
        std::fprintf(stderr, "not a RIFF/WAVE file\n");
        return 1;
    }
    bool haveFmt = false;
    const uint8_t* data = nullptr;
    size_t dataLen = 0;
    for (size_t pos = 12; pos + 8 <= b.size();) {
        const uint32_t len = U32(&b[pos + 4]);
        const uint8_t* body = &b[pos + 8];
        if (std::memcmp(&b[pos], "fmt ", 4) == 0 && pos + 8 + 16 <= b.size()) {
            haveFmt = true;
            if (U16(body) != 1 || U16(body + 2) != 1 || U32(body + 4) != 16000 || U16(body + 14) != 16) {
                std::fprintf(stderr, "unsupported format: need 16-bit PCM mono 16000 Hz\n");
                return 1;
            }
        } else if (std::memcmp(&b[pos], "data", 4) == 0) {
            data = body;
            dataLen = std::min<size_t>(len, b.size() - (pos + 8));
            break;
        }
        pos += 8 + len + (len & 1);
    }
    if (!haveFmt || !data) {
        std::fprintf(stderr, "missing fmt or data chunk\n");
        return 1;
    }

    std::vector<int16_t> pcm(dataLen / 2 + sns::kSampleRate, 0);  // trailing second stays silent
    for (size_t i = 0; i < dataLen / 2; ++i) pcm[i] = static_cast<int16_t>(U16(data + 2 * i));

    sns::Engine engine(sns::kSampleRate);
    for (size_t pos = 0; pos < pcm.size(); pos += 1600) {
        const auto out = engine.Process(pcm.data() + pos, std::min<size_t>(1600, pcm.size() - pos));
        for (const auto& e : out.events) {
            std::printf("start=%.2f dur=%.2f kind=%s\n", e.startSec, e.durationSec,
                        e.kind == sns::EventKind::Pulsed ? "Pulsed" : "Tonal");
        }
    }
    return 0;
}
