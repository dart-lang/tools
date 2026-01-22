## 2.1.0-wip

* Switched to using the Apache httpd mime.conf table as the source of truth for
  mime types.

Mime type additions:
- `application/vnd.geogebra.slides`
- `font/collection`
- `image/jxl`
- `image/vnd.dvb.subtitle`
- `video/mp2t`

Renamed mime types:
- `application/x-font-otf` => `font/otf`
- `application/x-font-ttf` => `font/ttf`
- `application/x-font-woff` => `font/woff`

Removed mime types:
- `model/vnd.mts`

Mime types where the default file extension changed:
- `application/inkml+xml`, `inkml` => `ink`
- `application/octet-stream`, `so` => `bin`
- `application/onenote`, `onetoc2` => `onetoc`
- `application/pgp-signature`, `sig` => `asc`
- `application/tei+xml`, `teicorpus` => `tei`
- `application/vnd.adobe.fxp`, `fxpl` => `fxp`
- `application/vnd.clonk.c4group`, `c4u` => `c4g`
- `application/vnd.dece.data`, `uvvf` => `uvf`
- `application/vnd.dece.ttml+xml`, `uvvt` => `uvt`
- `application/vnd.eszigno3+xml`, `et3` => `es3`
- `application/vnd.framemaker`, `maker` => `fm`
- `application/vnd.geometry-explorer`, `gre` => `gex`
- `application/vnd.grafeq`, `gqs` => `gqf`
- `application/vnd.ibm.modcap`, `listafp` => `afp`
- `application/vnd.iccprofile`, `icm` => `icc`
- `application/vnd.intercon.formnet`, `xpx` => `xpw`
- `application/vnd.kde.kpresenter`, `kpt` => `kpr`
- `application/vnd.kde.kword`, `kwt` => `kwd`
- `application/vnd.kinar`, `knp` => `kne`
- `application/vnd.koan`, `skt` => `skp`
- `application/vnd.ms-project`, `mpt` => `mpp`
- `application/vnd.palm`, `pqa` => `pdb`
- `application/vnd.quark.quarkxpress`, `qxt` => `qxd`
- `application/vnd.simtech-mindmapper`, `twds` => `twd`
- `application/vnd.stardivision.writer`, `vor` => `sdw`
- `application/vnd.sus-calendar`, `susp` => `sus`
- `application/vnd.symbian.install`, `sisx` => `sis`
- `application/vnd.ufdl`, `ufdl` => `ufd`
- `application/vnd.visio`, `vsw` => `vsd`
- `application/vnd.zul`, `zirz` => `zir`
- `application/x-authorware-bin`, `x32` => `aab`
- `application/x-blorb`, `blorb` => `blb`
- `application/x-cbr`, `cbz` => `cbr`
- `application/x-director`, `w3d` => `dir`
- `application/x-font-type1`, `pfm` => `pfa`
- `application/x-msdownload`, `msi` => `exe`
- `application/x-pkcs12`, `pfx` => `p12`
- `application/x-pkcs7-certificates`, `spc` => `p7b`
- `application/x-zmachine`, `z8` => `z1`
- `application/xv+xml`, `xvml` => `mxml`
- `audio/basic`, snd => `au`
- `audio/mpeg`, mpga => `mp3`
- `audio/vnd.dece.audio`, `uvva` => `uva`
- `image/tiff`, `tif` => `tiff`
- `image/vnd.dece.graphic`, `uvvi` => `uvi`
- `image/x-freehand`, `fhc` => `fh`
- `message/rfc822`, `mime` => `eml`
- `model/mesh`, `silo` => `msh`
- `model/x3d+binary`, `x3dbz` => `x3db`
- `model/x3d+vrml`, `x3dvz` => `x3dv`
- `model/x3d+xml`, `x3dz` => `x3d`
- `text/troff`, `tr` => `t`
- `text/uri-list`, `urls` => `uri`
- `text/x-fortran`, `for` => `f`
- `video/mj2`, `mjp2` => `mj2`
- `video/vnd.dece.hd`, `uvvh` => `uvh`
- `video/vnd.dece.mobile`, `uvvm` => `uvm`
- `video/vnd.dece.pd`, `uvvp` => `uvp`
- `video/vnd.dece.sd`, `uvvs` => `uvs`
- `video/vnd.dece.video`, `uvvv` => `uvv`
- `video/vnd.uvvu.mp4`, `uvvu` => `uvu`
- `video/x-ms-asf`, `asx` => `asf`

## 2.0.0

* **[Breaking]** `extensionFromMime(String mimeType)` returns `null` instead of
  `mimeType` for an unknown mime type.
* Update `extensionFromMime` to return a default extension when a MIME type maps
  to multiple extensions.

## 1.0.6

* Add `topics` section to `pubspec.yaml`.
* Move to `dart-lang/tools` monorepo.

## 1.0.5

* Update `video/mp4` mimeType lookup by header bytes.
* Add `image/heic` mimeType lookup by header bytes.
* Add `image/heif` mimeType lookup by header bytes.
* Add m4b mimeType lookup by extension.
* Add `text/markdown` mimeType lookup by extension.
* Require Dart 3.2.0.

## 1.0.4

* Changed `.js` to `text/javascript` per 
  https://datatracker.ietf.org/doc/html/rfc9239.
* Added `.mjs` as `text/javascript`.
* Add `application/dicom` mimeType lookup by extension.
* Require Dart 2.18.

## 1.0.3

* Add application/manifest+json lookup by extension.
* Add application/toml mimeType lookup by extension.
* Add audio/aac mimeType lookup by header bytes.
* Add audio/mpeg mimeType lookup by header bytes.
* Add audio/ogg mimeType lookup by header bytes.
* Add audio/weba mimeType lookup by header bytes.
* Add font/woff2 lookup by extension and header bytes.
* Add image/avif mimeType lookup by extension.
* Add image/heic mimeType lookup by extension.
* Add image/heif mimeType lookup by extension.
* Change audio/x-aac to audio/aac when detected by extension.

## 1.0.2

* Add audio/x-aiff mimeType lookup by header bytes.
* Add audio/x-flac mimeType lookup by header bytes.
* Add audio/x-wav mimeType lookup by header bytes.
* Add audio/mp4 mimeType lookup by file path.

## 1.0.1

* Add image/webp mimeType lookup by header bytes.

## 1.0.0

* Stable null safety release.

## 1.0.0-nullsafety.0

* Update to null safety.

## 0.9.7

* Add `extensionFromMime` utility function.

## 0.9.6+3

* Change the mime type for Dart source from `application/dart` to `text/x-dart`.
* Add example.
* Fix links and code in README.

## 0.9.6+2

* Set max SDK version to `<3.0.0`, and adjust other dependencies.

## 0.9.6+1

* Stop using deprecated constants from the SDK.

## 0.9.6

* Updates to support Dart 2.0 core library changes (wave
  2.2). See [issue 31847][sdk#31847] for details.

  [sdk#31847]: https://github.com/dart-lang/sdk/issues/31847

## 0.9.5

* Add support for the WebAssembly format.

## 0.9.4

* Updated Dart SDK requirement to `>= 1.8.3 <2.0.0`

* Strong-mode clean.

* Added support for glTF text and binary formats.

## 0.9.3

* Fixed erroneous behavior for listening and when pausing/resuming
  stream of parts.

## 0.9.2

* Fixed erroneous behavior when pausing/canceling stream of parts but already
  listened to one part.

## 0.9.1

* Handle parsing of MIME multipart content with no parts.

## 1.0.0-next

- Replaced deprecated `pub run` with `dart run` in documentation.

