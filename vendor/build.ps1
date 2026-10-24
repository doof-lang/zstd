# Builds lib\zstd.lib and installs the public zstd headers into include\.
# Runs inside a private copy of vendor\ with CC, AR, and CFLAGS supplied by
# the Doof compiler from a Visual Studio developer environment.
$ErrorActionPreference = 'Stop'

New-Item -ItemType Directory -Force -Path include, lib, obj | Out-Null
Copy-Item zstd\lib\zstd.h, zstd\lib\zstd_errors.h include\

$flags = @()
if ($env:CFLAGS) { $flags = $env:CFLAGS -split ' ' | Where-Object { $_ -ne '' } }
$objects = @()
foreach ($directory in 'common', 'compress', 'decompress') {
  foreach ($source in Get-ChildItem "zstd\lib\$directory\*.c") {
    $object = "obj\${directory}_$($source.BaseName).obj"
    & $env:CC @flags /DZSTD_DISABLE_ASM /Izstd\lib /Izstd\lib\common /TC /c $source.FullName "/Fo$object"
    if ($LASTEXITCODE -ne 0) { throw "Compiling $($source.Name) failed" }
    $objects += $object
  }
}

& $env:AR /nologo "/OUT:lib\zstd.lib" @objects
if ($LASTEXITCODE -ne 0) { throw 'Archiving zstd.lib failed' }
