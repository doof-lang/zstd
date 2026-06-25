# std/zstd Guide

`std/zstd` compresses and decompresses Zstandard frames. It is a good default
for new binary formats and storage where both sides can depend on Zstandard.
For HTTP interoperability with older clients, `std/gzip` may still be the safer
choice.

Doof automatically acquires the pinned upstream Meta Zstandard v1.5.7 source
archive into `vendor/zstd` during build/test.

## Quick Start

```doof
import { ZstdCompressStream, zstdCompress, zstdDecompress } from "std/zstd"

compressed := try! zstdCompress(bytes)
original := try! zstdDecompress(compressed)

for chunk of ZstdCompressStream(sourceChunks) {
  // write each compressed chunk to a file, socket, or another stream sink
}
```

## One-Shot Compression

`zstdCompress(data)` compresses a complete byte array using the module default
level. `zstdCompressWithLevel(data, level)` lets callers choose the level
explicitly. Both return `Result` values because the native encoder can report
configuration or allocation failures.

`zstdDecompress(data)` expects a complete Zstandard frame and returns `Failure`
for invalid input.

## Compression Levels

The stream type defaults to level `3`, matching the default used by the wrapper.
Use `zstdCompressWithLevel` or `ZstdCompressStream.withLevel` when you need to
trade CPU time for compressed size.

The native layer clamps unsupported levels to the nearest level accepted by the
upstream library. Prefer documenting the level you choose at the call site when
it is part of a file format or protocol.

## Streaming Compression

`ZstdCompressStream` implements `Stream<readonly byte[]>`. It pulls chunks from
the source stream, emits non-empty compressed chunks, and flushes the final frame
when the source is exhausted.

Native encoder failures during stream iteration currently panic, because
`Stream.next()` returns `bool` and has no error channel. Use one-shot
compression when you need to handle compression failure explicitly.

There is currently no streaming Zstandard decompressor; use `zstdDecompress`
for complete frames.

## API

### `zstdCompress`

```doof
export import function zstdCompress(data: readonly byte[]): Result<readonly byte[], string>
```

Compress a complete byte array with the default Zstandard level.

Defined in [index.do](../index.do).

### `zstdCompressWithLevel`

```doof
export import function zstdCompressWithLevel(data: readonly byte[], level: int): Result<readonly byte[], string>
```

Compress a complete byte array with an explicit level.

Defined in [index.do](../index.do).

### `zstdDecompress`

```doof
export import function zstdDecompress(data: readonly byte[]): Result<readonly byte[], string>
```

Decompress a complete Zstandard frame.

Defined in [index.do](../index.do).

### `ZstdCompressStream`

```doof
export class ZstdCompressStream implements Stream<readonly byte[]>
```

Incrementally compress chunks from another byte stream. Construct with
`ZstdCompressStream(source)` for the default level or
`ZstdCompressStream.withLevel(source, level)` for an explicit level.

Fields:

- `source: Stream<readonly byte[]>`
- `level: int = 3`

Methods:

- `next(): bool` advances to the next non-empty compressed chunk.
- `value(): readonly byte[]` returns the current compressed chunk.

Defined in [index.do](../index.do).
