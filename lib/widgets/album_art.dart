// ignore_for_file: deprecated_member_use

import 'dart:io';

import 'package:flutter/material.dart';

/// عرض غلاف الألبوم مع fallback لأيقونة موسيقى عند الفشل.
class AlbumArt extends StatefulWidget {
  final String? uri;
  final Future<String?> Function()? lazyFetchUri;
  final double size;
  final double radius;
  final String fallbackImage;

  const AlbumArt({
    super.key,
    required this.uri,
    this.lazyFetchUri,
    this.size = 56,
    this.radius = 10,
    this.fallbackImage = 'assets/images/albume.png',
  });

  @override
  State<AlbumArt> createState() => _AlbumArtState();
}

class _AlbumArtState extends State<AlbumArt> {
  String? _resolvedUri;
  Future<String?>? _loadingFuture;

  @override
  void initState() {
    super.initState();
    _resolvedUri = widget.uri;
    _maybeLoadUri();
  }

  @override
  void didUpdateWidget(covariant AlbumArt oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.uri != oldWidget.uri ||
        widget.lazyFetchUri != oldWidget.lazyFetchUri) {
      _loadingFuture = null;
      if (widget.uri != null && widget.uri!.isNotEmpty) {
        if (_resolvedUri != widget.uri) {
          setState(() {
            _resolvedUri = widget.uri;
          });
        }
      } else {
        // Keep previously resolved non-empty URI to avoid flicker when the
        // incoming `uri` briefly becomes null/empty. Attempt a lazy fetch only
        // if we don't already have a resolved URI.
        _maybeLoadUri();
      }
    }
  }

  void _maybeLoadUri() {
    final src = widget.uri;
    if ((src == null || src.isEmpty || src.startsWith('content://')) &&
        widget.lazyFetchUri != null) {
      // If we already have a resolved URI, avoid redundant lazy fetches to
      // prevent unnecessary state churn that can cause flicker.
      if (_resolvedUri != null && _resolvedUri!.isNotEmpty) return;

      _loadingFuture = widget.lazyFetchUri!();
      _loadingFuture!.then((value) {
        if (!mounted) return;
        if (value != null && value.isNotEmpty) {
          setState(() {
            _resolvedUri = value;
          });
        }
      }).catchError((_) {});
    }
  }

  ImageProvider? _resolveImageProvider(String src) {
    if (src.startsWith('file://')) {
      return FileImage(File(Uri.parse(src).toFilePath()));
    }
    if (src.startsWith('/')) {
      return FileImage(File(src));
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        image: DecorationImage(
          image: AssetImage(widget.fallbackImage),
          fit: BoxFit.cover,
        ),
        borderRadius: BorderRadius.circular(widget.radius),
      ),
    );

    final src = _resolvedUri;
    if (src == null || src.isEmpty) return fallback;

    final provider = _resolveImageProvider(src);
    if (provider == null) return fallback;

    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.radius),
      child: Image(
        image: provider,
        width: widget.size,
        height: widget.size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => fallback,
        loadingBuilder: (_, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return fallback;
        },
      ),
    );
  }
}
