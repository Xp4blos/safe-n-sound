// Dev tool: reads hilog "EVT ... fp=a,b,c,..." lines (see LOG_EVENT_FINGERPRINTS in AudioService.ets) from a
// file and prints each event's key fingerprint fields and the pairwise similarity matrix.
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <string>
#include <vector>

#include "matcher.h"

int main(int argc, char** argv) {
    if (argc != 2) {
        std::fprintf(stderr, "usage: fp_cli <evt-lines.txt>\n");
        return 2;
    }
    FILE* f = std::fopen(argv[1], "r");
    if (!f) {
        std::fprintf(stderr, "cannot read %s\n", argv[1]);
        return 1;
    }
    std::vector<sns::Fingerprint> fps;
    char line[4096];
    while (std::fgets(line, sizeof line, f)) {
        const char* p = std::strstr(line, "fp=");
        if (!p) continue;
        sns::Fingerprint fp{};
        p += 3;
        for (int i = 0; i < sns::kFingerprintSize && *p; ++i) {
            fp[i] = static_cast<float>(std::strtod(p, const_cast<char**>(&p)));
            if (*p == ',') ++p;
        }
        fps.push_back(fp);
    }
    std::fclose(f);
    for (size_t i = 0; i < fps.size(); ++i) {
        const auto& fp = fps[i];
        std::printf("#%zu peaks=%.0f,%.0f,%.0f Hz period=%.2fs duty=%.2f\n", i, fp[0] * 8000, fp[1] * 8000,
                    fp[2] * 8000, fp[19] * 2, fp[20]);
    }
    for (size_t i = 0; i < fps.size(); ++i) {
        for (size_t j = 0; j < fps.size(); ++j) std::printf("%5.2f ", sns::Similarity(fps[i], fps[j]));
        std::printf("\n");
    }
    return 0;
}
