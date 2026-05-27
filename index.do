import class NativeZstdEncoder from "native_zstd.hpp" as doof_zstd::NativeZstdEncoder {
  static create(level: int): NativeZstdEncoder
  update(data: readonly byte[]): Result<readonly byte[], string>
  finish(): Result<readonly byte[], string>
}

export import function zstdCompress(data: readonly byte[]): Result<readonly byte[], string> from "native_zstd.hpp" as doof_zstd::compress
export import function zstdCompressWithLevel(data: readonly byte[], level: int): Result<readonly byte[], string> from "native_zstd.hpp" as doof_zstd::compressWithLevel
export import function zstdDecompress(data: readonly byte[]): Result<readonly byte[], string> from "native_zstd.hpp" as doof_zstd::decompress

export class ZstdCompressStream implements Stream<readonly byte[]> {
  source: Stream<readonly byte[]>
  level: int = 3
  private native: NativeZstdEncoder
  private currentValue: readonly byte[] = []
  private sourceDone: bool = false
  private finished: bool = false
  private failed: string | null = null

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
    if this.failed != null {
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
