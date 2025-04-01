// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:meta/meta.dart';

import 'default_extension_map.dart';

/// Default extension for recognized MIME types.
///
/// Is the inverse of [defaultExtensionMap], and where that
/// map has multiple extensions which map to the same
/// MIME type, this map maps that MIME type to a *default*
/// extension.
///
/// Used by [extensionFromMime].
final Map<String, String> _defaultMimeTypeMap = {
  ..._additionalMimeTypesForExistingExtensionsMap,
  for (var entry in defaultExtensionMap.entries) entry.value: entry.key,
  ..._defaultMimeTypeFallbackMap,
};

/// A map for with the default file extensions for MIME types.
///
/// setting default file extensions for MIME types,
/// which are having multiple extensions
///
/// used by [_defaultMimeTypeMap]
const Map<String, String> _defaultMimeTypeFallbackMap = {
  'application/inkml+xml': 'inkml',
  'application/mathematica': 'nb',
  'application/mp21': 'mp21',
  'application/msword': 'doc',
  'application/octet-stream': 'so',
  'application/onenote': 'onetoc2',
  'application/pgp-signature': 'sig',
  'application/pkcs7-mime': 'p7m',
  'application/postscript': 'ps',
  'application/smil+xml': 'smil',
  'application/tei+xml': 'teicorpus',
  'application/vnd.acucorp': 'atc',
  'application/vnd.adobe.fxp': 'fxpl',
  'application/vnd.clonk.c4group': 'c4u',
  'application/vnd.dece.data': 'uvvf',
  'application/vnd.dece.ttml+xml': 'uvvt',
  'application/vnd.dece.unspecified': 'uvx',
  'application/vnd.dece.zip': 'uvz',
  'application/vnd.eszigno3+xml': 'et3',
  'application/vnd.fdsn.seed': 'seed',
  'application/vnd.framemaker': 'maker',
  'application/vnd.geometry-explorer': 'gre',
  'application/vnd.grafeq': 'gqs',
  'application/vnd.ibm.modcap': 'listafp',
  'application/vnd.iccprofile': 'icm',
  'application/vnd.intercon.formnet': 'xpx',
  'application/vnd.kahootz': 'ktz',
  'application/vnd.kde.kpresenter': 'kpt',
  'application/vnd.kde.kword': 'kwt',
  'application/vnd.kinar': 'knp',
  'application/vnd.koan': 'skt',
  'application/vnd.ms-excel': 'xls',
  'application/vnd.ms-powerpoint': 'ppt',
  'application/vnd.ms-project': 'mpt',
  'application/vnd.ms-works': 'wps',
  'application/vnd.nitf': 'ntf',
  'application/vnd.palm': 'pqa',
  'application/vnd.quark.quarkxpress': 'qxt',
  'application/vnd.simtech-mindmapper': 'twds',
  'application/vnd.solent.sdkm+xml': 'sdkm',
  'application/vnd.stardivision.writer': 'vor',
  'application/vnd.sus-calendar': 'susp',
  'application/vnd.symbian.install': 'sisx',
  'application/vnd.tcpdump.pcap': 'pcap',
  'application/vnd.ufdl': 'ufdl',
  'application/vnd.visio': 'vsw',
  'application/vnd.zul': 'zirz',
  'application/x-authorware-bin': 'x32',
  'application/x-blorb': 'blorb',
  'application/x-bzip2': 'bz2',
  'application/x-cbr': 'cbz',
  'application/x-debian-package': 'deb',
  'application/x-director': 'w3d',
  'application/x-font-ttf': 'ttf',
  'application/x-font-type1': 'pfm',
  'application/x-lzh-compressed': 'lzh',
  'application/x-mobipocket-ebook': 'prc',
  'application/x-msdownload': 'msi',
  'application/x-msmediaview': 'mvb',
  'application/x-msmetafile': 'wmf',
  'application/x-netcdf': 'nc',
  'application/x-pkcs12': 'pfx',
  'application/x-pkcs7-certificates': 'spc',
  'application/x-texinfo': 'texinfo',
  'application/x-x509-ca-cert': 'der',
  'application/x-zmachine': 'z8',
  'application/xhtml+xml': 'xhtml',
  'application/xml': 'xml',
  'application/xv+xml': 'xvml',
  'audio/basic': 'snd',
  'audio/midi': 'mid',
  'audio/mp4': 'm4a',
  'audio/mpeg': 'mp3',
  'audio/ogg': 'ogg',
  'audio/vnd.dece.audio': 'uvva',
  'audio/x-aiff': 'aif',
  'audio/x-pn-realaudio': 'ram',
  'image/jpeg': 'jpg',
  'image/svg+xml': 'svg',
  'image/tiff': 'tif',
  'image/vnd.dece.graphic': 'uvvi',
  'image/vnd.djvu': 'djvu',
  'image/x-freehand': 'fhc',
  'image/x-pict': 'pic',
  'message/rfc822': 'mime',
  'model/iges': 'igs',
  'model/mesh': 'silo',
  'model/vrml': 'vrml',
  'model/x3d+binary': 'x3dbz',
  'model/x3d+vrml': 'x3dvz',
  'model/x3d+xml': 'x3dz',
  'text/calendar': 'ics',
  'text/html': 'html',
  'text/javascript': 'js',
  'text/markdown': 'md',
  'text/plain': 'txt',
  'text/sgml': 'sgml',
  'text/troff': 'tr',
  'text/uri-list': 'urls',
  'text/x-asm': 'asm',
  'text/x-c': 'c',
  'text/x-fortran': 'for',
  'text/x-pascal': 'pas',
  'video/jpm': 'jpm',
  'video/mj2': 'mjp2',
  'video/mp4': 'mp4',
  'video/mpeg': 'mpg',
  'video/quicktime': 'mov',
  'video/vnd.dece.hd': 'uvvh',
  'video/vnd.dece.mobile': 'uvvm',
  'video/vnd.dece.pd': 'uvvp',
  'video/vnd.dece.sd': 'uvvs',
  'video/vnd.dece.video': 'uvvv',
  'video/vnd.mpegurl': 'mxu',
  'video/vnd.uvvu.mp4': 'uvvu',
  'video/x-matroska': 'mkv',
  'video/x-ms-asf': 'asx',
};

/// Additional MIME types for existing extensions.
///
/// used for additional mime types, used by the existing extensions
/// used by [_defaultMimeTypeMap]
const Map<String, String> _additionalMimeTypesForExistingExtensionsMap = {
  'audio/wav': 'wav',
};

/// access [_defaultMimeTypeFallbackMap] for testing purposes
@visibleForTesting
const Map<String, String> defaultMimeTypeFallbackMap =
    _defaultMimeTypeFallbackMap;

/// The default file extension for a given MIME type.
///
/// If [mimeType] has multiple associated extensions,
/// the returned string is one of those, chosen as the default
/// extension for that MIME type.
///
/// Returns `null` if [mimeType] is not a recognized and
/// supported MIME type.
String? extensionFromMime(String mimeType) =>
    _defaultMimeTypeMap[mimeType.toLowerCase()];
