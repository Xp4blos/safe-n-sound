// NAPI bridge between ArkTS and the Safe'n'Sound engine. Thin on purpose: argument checking and
// conversion only; all signal processing lives in ../engine.
#include <cstdint>
#include <cstring>
#include <map>
#include <memory>
#include <mutex>
#include <vector>

#include "hilog/log.h"
#include "napi/native_api.h"

#include "matcher.h"
#include "engine.h"

namespace {

constexpr unsigned int kLogDomain = 0x3201;
constexpr const char* kLogTag = "SnsNative";

std::mutex g_mutex;
std::map<int, std::unique_ptr<sns::Engine>> g_engines;
int g_nextHandle = 1;

napi_value Undefined(napi_env env) {
    napi_value v;
    napi_get_undefined(env, &v);
    return v;
}

napi_value Throw(napi_env env, const char* message) {
    napi_throw_error(env, nullptr, message);
    return nullptr;
}

napi_value MakeNumber(napi_env env, double d) {
    napi_value v;
    napi_create_double(env, d, &v);
    return v;
}

napi_value MakeMatchResult(napi_env env, int index, float score) {
    napi_value obj;
    napi_create_object(env, &obj);
    napi_set_named_property(env, obj, "index", MakeNumber(env, index));
    napi_set_named_property(env, obj, "score", MakeNumber(env, score));
    return obj;
}

// Reads a JS array of numbers into `out`; false if `value` is not an array of numbers.
bool ReadNumberArray(napi_env env, napi_value value, std::vector<float>* out) {
    bool isArray = false;
    if (napi_is_array(env, value, &isArray) != napi_ok || !isArray) return false;
    uint32_t length = 0;
    napi_get_array_length(env, value, &length);
    out->clear();
    out->reserve(length);
    for (uint32_t i = 0; i < length; ++i) {
        napi_value item;
        double d = 0.0;
        if (napi_get_element(env, value, i, &item) != napi_ok || napi_get_value_double(env, item, &d) != napi_ok) {
            return false;
        }
        out->push_back(static_cast<float>(d));
    }
    return true;
}

bool ReadHandle(napi_env env, napi_value value, int* handle) {
    int32_t h = 0;
    if (napi_get_value_int32(env, value, &h) != napi_ok) return false;
    *handle = h;
    return true;
}

napi_value CreateEngine(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    int32_t sampleRate = 0;
    if (argc < 1 || napi_get_value_int32(env, args[0], &sampleRate) != napi_ok || sampleRate < 8000 ||
        sampleRate > 48000) {
        return Throw(env, "createEngine: sampleRate must be an integer between 8000 and 48000");
    }
    std::lock_guard<std::mutex> lock(g_mutex);
    const int handle = g_nextHandle++;
    g_engines[handle] = std::make_unique<sns::Engine>(sampleRate);
    return MakeNumber(env, handle);
}

napi_value DestroyEngine(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    int handle = 0;
    if (argc < 1 || !ReadHandle(env, args[0], &handle)) return Throw(env, "destroyEngine: bad handle");
    std::lock_guard<std::mutex> lock(g_mutex);
    g_engines.erase(handle);  // unknown handle: nothing to do
    return Undefined(env);
}

napi_value EventToJs(napi_env env, const sns::Event& e) {
    napi_value obj, fp;
    napi_create_object(env, &obj);
    napi_set_named_property(env, obj, "startSec", MakeNumber(env, e.startSec));
    napi_set_named_property(env, obj, "durationSec", MakeNumber(env, e.durationSec));
    napi_set_named_property(env, obj, "kind", MakeNumber(env, static_cast<int>(e.kind)));
    napi_create_array_with_length(env, e.fp.size(), &fp);
    for (size_t i = 0; i < e.fp.size(); ++i) napi_set_element(env, fp, static_cast<uint32_t>(i), MakeNumber(env, e.fp[i]));
    napi_set_named_property(env, obj, "fingerprint", fp);
    return obj;
}

napi_value Process(napi_env env, napi_callback_info info) {
    size_t argc = 2;
    napi_value args[2];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    int handle = 0;
    if (argc < 2 || !ReadHandle(env, args[0], &handle)) return Throw(env, "process: bad handle");

    void* data = nullptr;
    size_t byteLength = 0;
    if (napi_get_arraybuffer_info(env, args[1], &data, &byteLength) != napi_ok) {
        return Throw(env, "process: second argument must be an ArrayBuffer");
    }
    if (byteLength % 2 != 0) {
        OH_LOG_Print(LOG_APP, LOG_WARN, kLogDomain, kLogTag, "odd PCM byte length %{public}zu, ignoring last byte",
                     byteLength);
    }
    const size_t sampleCount = byteLength / 2;
    std::vector<int16_t> pcm(sampleCount);  // copy: the ArrayBuffer may not be 2-byte aligned
    if (sampleCount > 0) std::memcpy(pcm.data(), data, sampleCount * 2);

    sns::EngineOutput out;
    {
        std::lock_guard<std::mutex> lock(g_mutex);
        auto it = g_engines.find(handle);
        if (it == g_engines.end()) return Throw(env, "process: unknown engine handle");
        out = it->second->Process(pcm.data(), sampleCount);
    }

    napi_value result, events;
    napi_create_object(env, &result);
    napi_create_array_with_length(env, out.events.size(), &events);
    for (size_t i = 0; i < out.events.size(); ++i) {
        napi_set_element(env, events, static_cast<uint32_t>(i), EventToJs(env, out.events[i]));
    }
    napi_set_named_property(env, result, "levelDb", MakeNumber(env, out.levelDb));
    napi_set_named_property(env, result, "events", events);
    return result;
}

napi_value MatchFingerprint(napi_env env, napi_callback_info info) {
    size_t argc = 2;
    napi_value args[2];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    if (argc < 2) return Throw(env, "matchFingerprint: expected (fp, saved)");

    std::vector<float> fpValues;
    if (!ReadNumberArray(env, args[0], &fpValues) || fpValues.size() != sns::kFingerprintSize) {
        return MakeMatchResult(env, -1, 0.0f);
    }
    sns::Fingerprint fp;
    std::copy(fpValues.begin(), fpValues.end(), fp.begin());

    bool isArray = false;
    if (napi_is_array(env, args[1], &isArray) != napi_ok || !isArray) return MakeMatchResult(env, -1, 0.0f);
    uint32_t savedCount = 0;
    napi_get_array_length(env, args[1], &savedCount);

    std::vector<sns::Fingerprint> valid;
    std::vector<int> originalIndex;  // maps positions in `valid` back to the caller's array
    for (uint32_t i = 0; i < savedCount; ++i) {
        napi_value item;
        std::vector<float> values;
        if (napi_get_element(env, args[1], i, &item) != napi_ok || !ReadNumberArray(env, item, &values) ||
            values.size() != sns::kFingerprintSize) {
            continue;  // skip malformed saved fingerprints
        }
        sns::Fingerprint s;
        std::copy(values.begin(), values.end(), s.begin());
        valid.push_back(s);
        originalIndex.push_back(static_cast<int>(i));
    }

    const sns::MatchResult m = sns::Match(fp, valid);
    return MakeMatchResult(env, m.index < 0 ? -1 : originalIndex[m.index], m.score);
}

napi_value Init(napi_env env, napi_value exports) {
    napi_property_descriptor props[] = {
        {"createEngine", nullptr, CreateEngine, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"destroyEngine", nullptr, DestroyEngine, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"process", nullptr, Process, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"matchFingerprint", nullptr, MatchFingerprint, nullptr, nullptr, nullptr, napi_default, nullptr},
    };
    napi_define_properties(env, exports, sizeof(props) / sizeof(props[0]), props);
    return exports;
}

napi_module g_module = {1, 0, nullptr, Init, "safensound", nullptr, {nullptr}};

}  // namespace

extern "C" __attribute__((constructor)) void RegisterSafensoundModule(void) {
    napi_module_register(&g_module);
}
