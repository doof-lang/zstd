import class NativeZstdEncoder from "native_zstd.hpp" as doof_zstd::NativeZstdEncoder {
  isolated static create(level: int): NativeZstdEncoder
  isolated update(data: readonly byte[]): Result<readonly byte[], string>
  isolated finish(): Result<readonly byte[], string>
}

export import isolated function zstdCompress(data: readonly byte[]): Result<readonly byte[], string> from "native_zstd.hpp" as doof_zstd::compress
export import isolated function zstdCompressWithLevel(data: readonly byte[], level: int): Result<readonly byte[], string> from "native_zstd.hpp" as doof_zstd::compressWithLevel
export import isolated function zstdDecompress(data: readonly byte[]): Result<readonly byte[], string> from "native_zstd.hpp" as doof_zstd::decompress

export class ZstdCompressStream implements Stream<readonly byte[]> {
  source: Stream<readonly byte[]>
  level: int = 3
  private native: NativeZstdEncoder
  private let currentValue: readonly byte[] = []
  private let sourceDone: bool = false
  private let finished: bool = false
  private let failed: string | none = none

  static constructor(source: Stream<readonly byte[]>, level: int = 3): ZstdCompressStream {
    return ZstdCompressStream {
      source,
      level,
      native: NativeZstdEncoder.create(level),
    }
  }

  static withLevel(source: Stream<readonly byte[]>, level: int): ZstdCompressStream {
    return ZstdCompressStream(source, level)
  }

  next(): bool {
    if this.failed != none {
      panic(this.failed!)
    }

    while true {
      if !this.sourceDone {
        if this.source.next() {
          let compressed: readonly byte[] = []
          case this.native.update(this.source.value()) {
            s: Success -> {
              compressed = s.value
            }
            f: Failure -> {
              this.failed = f.error
              panic(f.error)
            }
          }
          if compressed.length > 0 {
            this.currentValue = compressed
            return true
          }
          continue
        }
        this.sourceDone = true
      }

      if this.finished {
        return false
      }

      this.finished = true
      let finalChunk: readonly byte[] = []
      case this.native.finish() {
        s: Success -> {
          finalChunk = s.value
        }
        f: Failure -> {
          this.failed = f.error
          panic(f.error)
        }
      }
      if finalChunk.length == 0 {
        return false
      }
      this.currentValue = finalChunk
      return true
    }
  }

  value(): readonly byte[] => this.currentValue
}
