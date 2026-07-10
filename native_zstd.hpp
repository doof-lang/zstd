#pragma once

#include "doof_runtime.hpp"

#include <algorithm>
#include <array>
#include <cstddef>
#include <cstdint>
#include <limits>
#include <memory>
#include <string>
#include <vector>
#include <zstd.h>

namespace doof_zstd {

namespace detail {

inline std::shared_ptr<std::vector<uint8_t>> emptyBytes() {
    return std::make_shared<std::vector<uint8_t>>();
}

inline const void* dataPointer(const std::shared_ptr<std::vector<uint8_t>>& data) {
    if (!data || data->empty()) {
        return nullptr;
    }
    return data->data();
}

inline size_t dataSize(const std::shared_ptr<std::vector<uint8_t>>& data) {
    return data ? data->size() : 0u;
}

inline std::string zstdError(const char* operation, size_t code) {
    return std::string("zstd ") + operation + " failed: " + ZSTD_getErrorName(code);
}

inline int32_t normalizeLevel(int32_t level) {
    if (level == 0) {
        return ZSTD_CLEVEL_DEFAULT;
    }
    return std::clamp<int32_t>(
        level,
        static_cast<int32_t>(ZSTD_minCLevel()),
        static_cast<int32_t>(ZSTD_maxCLevel())
    );
}

}  // namespace detail

class NativeZstdEncoder {
public:
    static std::shared_ptr<NativeZstdEncoder> create(int32_t level) {
        return std::shared_ptr<NativeZstdEncoder>(new NativeZstdEncoder(level));
    }

    ~NativeZstdEncoder() {
        ZSTD_freeCCtx(context_);
    }

    doof::Result<std::shared_ptr<std::vector<uint8_t>>, std::string> update(
        const std::shared_ptr<std::vector<uint8_t>>& data
    ) {
        if (finished_) {
            return doof::Failure<std::string>{"zstd encoder update after finish"};
        }

        if (!data || data->empty()) {
            return doof::Success<std::shared_ptr<std::vector<uint8_t>>>{detail::emptyBytes()};
        }

        ZSTD_inBuffer input { data->data(), data->size(), 0u };
        return drain(input, ZSTD_e_continue, "compress");
    }

    doof::Result<std::shared_ptr<std::vector<uint8_t>>, std::string> finish() {
        if (finished_) {
            return doof::Success<std::shared_ptr<std::vector<uint8_t>>>{detail::emptyBytes()};
        }

        finished_ = true;
        ZSTD_inBuffer input { nullptr, 0u, 0u };
        return drain(input, ZSTD_e_end, "finish");
    }

private:
    explicit NativeZstdEncoder(int32_t level) {
        context_ = ZSTD_createCCtx();
        if (context_ == nullptr) {
            doof::panic("zstd failed to allocate compression context");
        }

        const size_t result = ZSTD_CCtx_setParameter(context_, ZSTD_c_compressionLevel, detail::normalizeLevel(level));
        if (ZSTD_isError(result)) {
            doof::panic(detail::zstdError("configure", result));
        }
    }

    doof::Result<std::shared_ptr<std::vector<uint8_t>>, std::string> drain(
        ZSTD_inBuffer& input,
        ZSTD_EndDirective directive,
        const char* operation
    ) {
        auto output = std::make_shared<std::vector<uint8_t>>();
        std::array<uint8_t, 65536> buffer {};

        while (true) {
            ZSTD_outBuffer out { buffer.data(), buffer.size(), 0u };
            const size_t remaining = ZSTD_compressStream2(context_, &out, &input, directive);
            if (ZSTD_isError(remaining)) {
                return doof::Failure<std::string>{detail::zstdError(operation, remaining)};
            }

            output->insert(output->end(), buffer.begin(), buffer.begin() + static_cast<std::ptrdiff_t>(out.pos));

            if (directive == ZSTD_e_continue) {
                if (input.pos == input.size) {
                    return doof::Success<std::shared_ptr<std::vector<uint8_t>>>{output};
                }
            } else if (remaining == 0u) {
                return doof::Success<std::shared_ptr<std::vector<uint8_t>>>{output};
            }
        }
    }

    ZSTD_CCtx* context_ = nullptr;
    bool finished_ = false;
};

inline doof::Result<std::shared_ptr<std::vector<uint8_t>>, std::string> compressWithLevel(
    const std::shared_ptr<std::vector<uint8_t>>& data,
    int32_t level
) {
    const size_t sourceSize = detail::dataSize(data);
    const size_t bound = ZSTD_compressBound(sourceSize);
    auto output = std::make_shared<std::vector<uint8_t>>(bound);

    const size_t written = ZSTD_compress(
        output->data(),
        output->size(),
        detail::dataPointer(data),
        sourceSize,
        detail::normalizeLevel(level)
    );
    if (ZSTD_isError(written)) {
        return doof::Failure<std::string>{detail::zstdError("compress", written)};
    }

    output->resize(written);
    return doof::Success<std::shared_ptr<std::vector<uint8_t>>>{output};
}

inline doof::Result<std::shared_ptr<std::vector<uint8_t>>, std::string> compress(
    const std::shared_ptr<std::vector<uint8_t>>& data
) {
    return compressWithLevel(data, ZSTD_CLEVEL_DEFAULT);
}

inline doof::Result<std::shared_ptr<std::vector<uint8_t>>, std::string> decompress(
    const std::shared_ptr<std::vector<uint8_t>>& data
) {
    ZSTD_DCtx* rawContext = ZSTD_createDCtx();
    if (rawContext == nullptr) {
        return doof::Failure<std::string>{"zstd failed to allocate decompression context"};
    }
    std::unique_ptr<ZSTD_DCtx, decltype(&ZSTD_freeDCtx)> context(rawContext, ZSTD_freeDCtx);

    ZSTD_inBuffer input { detail::dataPointer(data), detail::dataSize(data), 0u };
    auto output = std::make_shared<std::vector<uint8_t>>();
    std::array<uint8_t, 65536> buffer {};
    size_t remaining = 1u;

    while (input.pos < input.size) {
        ZSTD_outBuffer out { buffer.data(), buffer.size(), 0u };
        remaining = ZSTD_decompressStream(context.get(), &out, &input);
        if (ZSTD_isError(remaining)) {
            return doof::Failure<std::string>{detail::zstdError("decompress", remaining)};
        }

        output->insert(output->end(), buffer.begin(), buffer.begin() + static_cast<std::ptrdiff_t>(out.pos));
    }

    if (remaining != 0u) {
        return doof::Failure<std::string>{"zstd decompress failed: truncated frame"};
    }

    return doof::Success<std::shared_ptr<std::vector<uint8_t>>>{output};
}

}  // namespace doof_zstd
