import { BlobBuilder } from "std/blob"
import { zstdCompress, zstdCompressWithLevel, zstdDecompress, ZstdCompressStream } from "../index"

class ChunkStream implements Stream<readonly byte[]> {
  chunks: string[]
  let index: int = 0
  let currentValue: readonly byte[] = []

  next(): bool {
    if this.index >= this.chunks.length {
      return false
    }
    this.currentValue = encodeText(this.chunks[this.index])
    this.index += 1
    return true
  }

  value(): readonly byte[] => this.currentValue
}

function assertBytes(actual: readonly byte[], expected: readonly byte[]): none {
  assert(actual.length == expected.length, "expected byte lengths to match")

  for index of 0..<actual.length {
    assert(actual[index] == expected[index], "expected bytes to match")
  }
}

function encodeText(text: string): readonly byte[] {
  builder := BlobBuilder()
  builder.writeString(text)
  return builder.build()
}

function buildPayload(): readonly byte[] {
  builder := BlobBuilder()
  builder.writeString("hello zstd\n")
  builder.writeString("hello zstd\n")
  builder.writeString("hello zstd\n")
  return builder.build()
}

function collect(stream: Stream<readonly byte[]>): readonly byte[] {
  builder := BlobBuilder()
  for chunk of stream {
    builder.writeBytes(chunk)
  }
  return builder.build()
}

export function testZstdCompressProducesZstdFrame(): none {
  let compressed: readonly byte[] = []
  case zstdCompress(buildPayload()) {
    s: Success -> {
      compressed = s.value
    }
    f: Failure -> {
      panic(f.error)
    }
  }

  assert(compressed.length > 4, "expected zstd frame payload")
  assert(compressed[0] == 40, "expected zstd magic byte 1")
  assert(compressed[1] == 181, "expected zstd magic byte 2")
  assert(compressed[2] == 47, "expected zstd magic byte 3")
  assert(compressed[3] == 253, "expected zstd magic byte 4")
}

export function testZstdRoundTrip(): none {
  input := buildPayload()
  let compressed: readonly byte[] = []
  case zstdCompressWithLevel(input, 5) {
    s: Success -> {
      compressed = s.value
    }
    f: Failure -> {
      panic(f.error)
    }
  }
  let decompressed: readonly byte[] = []
  case zstdDecompress(compressed) {
    s: Success -> {
      decompressed = s.value
    }
    f: Failure -> {
      panic(f.error)
    }
  }

  assertBytes(decompressed, input)
}

export function testZstdCompressStreamRoundTrip(): none {
  input := buildPayload()
  compressed := collect(ZstdCompressStream(ChunkStream {
    chunks: [
      "hello ",
      "zstd\nhello ",
      "zstd\nhello zstd\n",
    ],
  }))
  let decompressed: readonly byte[] = []
  case zstdDecompress(compressed) {
    s: Success -> {
      decompressed = s.value
    }
    f: Failure -> {
      panic(f.error)
    }
  }

  assertBytes(decompressed, input)
}

export function testZstdDecompressRejectsInvalidFrame(): none {
  decompressed := zstdDecompress(encodeText("not zstd"))
  case decompressed {
    _: Success -> {
      assert(false, "expected invalid zstd frame to fail")
    }
    _: Failure -> {}
  }
}
