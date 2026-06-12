# std/zstd

Zstandard compression utilities for byte arrays and byte streams.

Doof automatically acquires the pinned upstream Meta Zstandard v1.5.7 source archive into `vendor/zstd` during build/test.

## Usage

```doof
import { zstdCompress, zstdDecompress, ZstdCompressStream } from "std/zstd"

compressed := try! zstdCompress(bytes)
original := try! zstdDecompress(compressed)

compressedChunks := ZstdCompressStream(chunks)
```

## Exports

### `zstdCompress(data: readonly byte[]): Result<readonly byte[], string>`

Compress a byte array using the default Zstandard compression level.

### `zstdCompressWithLevel(data: readonly byte[], level: int): Result<readonly byte[], string>`

Compress a byte array using a specific Zstandard compression level. Passing `0`
uses the upstream default level. Levels outside the upstream-supported range are
clamped to the nearest supported level.

### `zstdDecompress(data: readonly byte[]): Result<readonly byte[], string>`

Decompress a complete Zstandard frame.

### `ZstdCompressStream(source: Stream<readonly byte[]>): Stream<readonly byte[]>`

Return a stream that incrementally compresses chunks from another byte stream
using the default compression level.

### `ZstdCompressStream.withLevel(source: Stream<readonly byte[]>, level: int): Stream<readonly byte[]>`

Return a stream that incrementally compresses chunks using a specific
compression level.
