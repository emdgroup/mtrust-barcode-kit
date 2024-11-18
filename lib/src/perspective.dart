import 'dart:collection';
import 'dart:typed_data';

import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:mtrust_barcode_kit/mtrust_barcode_kit.dart';

// Adapted from  https://raw.githubusercontent.com/alesdi/qr_code_vision/master/lib/helpers/perspective_transform.dart

/// A representation of a perspective transformation, that can be applied to
/// single points. Common linear transformation operations (such as inversion
/// and comCornerPoint) are also supported.
class PerspectiveTransform extends Equatable {
  /// Creates a [PerspectiveTransform] from a list of 9 elements
  PerspectiveTransform(List<double> elements)
      : _matrix = _PerspectiveMatrix.fromList(elements);

  /// Creates a [PerspectiveTransform] that transforms a 1x1 square into the
  /// given quadrilateral, expressed as a list of its vertices.
  factory PerspectiveTransform.fromTransformedSquare(
    List<CornerPoint> vertices,
  ) {
    assert(vertices.length == 4, 'Exactly 4 vertices are required');
    final p1 = vertices[0];
    final p2 = vertices[1];
    final p3 = vertices[2];
    final p4 = vertices[3];

    final dx3 = p1.x - p2.x + p3.x - p4.x;
    final dy3 = p1.y - p2.y + p3.y - p4.y;
    if (dx3 == 0 && dy3 == 0) {
      // Affine
      return PerspectiveTransform([
        p2.x - p1.x, p2.y - p1.y, 0, //
        p3.x - p2.x, p3.y - p2.y, 0, //
        p1.x, p1.y, 1, //
      ]);
    } else {
      final dx1 = p2.x - p3.x;
      final dx2 = p4.x - p3.x;
      final dy1 = p2.y - p3.y;
      final dy2 = p4.y - p3.y;
      final denominator = dx1 * dy2 - dx2 * dy1;
      final a13 = (dx3 * dy2 - dx2 * dy3) / denominator;
      final a23 = (dx1 * dy3 - dx3 * dy1) / denominator;
      return PerspectiveTransform([
        p2.x - p1.x + a13 * p2.x, p2.y - p1.y + a13 * p2.y, a13, //
        p4.x - p1.x + a23 * p4.x, p4.y - p1.y + a23 * p4.y, a23, //
        p1.x, p1.y, 1, //
      ]);
    }
  }

  /// Creates a [PerspectiveTransform] that transforms a given quadrilateral
  /// into another given quadrilateral, expressed as a list of its vertices.
  factory PerspectiveTransform.fromQuadrilaterals(
    List<CornerPoint> originVertices,
    List<CornerPoint> destinationVertices,
  ) {
    final fromOriginToSquare =
        PerspectiveTransform.fromTransformedSquare(originVertices).inverse();
    final fromSquareToDestination =
        PerspectiveTransform.fromTransformedSquare(destinationVertices);
    return fromSquareToDestination.compose(fromOriginToSquare);
  }
  final _PerspectiveMatrix _matrix;

  /// Creates a [PerspectiveTransform] that is the comCornerPoint of this
  /// transformation and a given [other] transformation.
  PerspectiveTransform compose(PerspectiveTransform other) {
    final A = other._matrix.toList();
    final B = _matrix.toList();
    final result = List<double>.filled(9, 0);
    for (var i = 0; i < 3; i++) {
      for (var j = 0; j < 3; j++) {
        for (var k = 0; k < 3; k++) {
          result[i * 3 + j] += A[i * 3 + k] * B[k * 3 + j];
        }
      }
    }

    return PerspectiveTransform(result);
  }

  /// Creates a [PerspectiveTransform] that is the inverse of this
  PerspectiveTransform inverse() {
    final A = _matrix;

    // Compute the adjoint matrix (transposed co-factors matrix)
    return PerspectiveTransform(
      _PerspectiveMatrix([
        [
          A(2, 2) * A(3, 3) - A(2, 3) * A(3, 2),
          A(1, 3) * A(3, 2) - A(1, 2) * A(3, 3),
          A(1, 2) * A(2, 3) - A(1, 3) * A(2, 2),
        ],
        [
          A(3, 1) * A(2, 3) - A(3, 3) * A(2, 1),
          A(1, 1) * A(3, 3) - A(1, 3) * A(3, 1),
          A(1, 3) * A(2, 1) - A(1, 1) * A(2, 3),
        ],
        [
          A(2, 1) * A(3, 2) - A(2, 2) * A(3, 1),
          A(1, 2) * A(3, 1) - A(1, 1) * A(3, 2),
          A(1, 1) * A(2, 2) - A(1, 2) * A(2, 1),
        ],
      ]),
    );

    // transpose
  }

  /// Applies this transformation to a given [point] and returns the transformed
  /// point.
  CornerPoint apply(CornerPoint point) {
    final x = point.x;
    final y = point.y;
    final denominator = _matrix(1, 3) * x + _matrix(2, 3) * y + _matrix(3, 3);
    return CornerPoint(
      x: (_matrix(1, 1) * x + _matrix(2, 1) * y + _matrix(3, 1)) / denominator,
      y: (_matrix(1, 2) * x + _matrix(2, 2) * y + _matrix(3, 2)) / denominator,
    );
  }

  /// Compute an equivalent 3D perspective matrix (4x4) that can be used to
  /// transform a canvas or as argument for the Transform widget in Flutter.
  Float64List to3DPerspectiveMatrix() {
    return Float64List.fromList([
      _matrix(1, 1), _matrix(1, 2), 0, _matrix(1, 3), //
      _matrix(2, 1), _matrix(2, 2), 0, _matrix(2, 3), //
      0, 0, 1, 1, //
      _matrix(3, 1), _matrix(3, 2), 0, _matrix(3, 3), //
    ]);
  }

  @override
  List<Object?> get props => [_matrix];
}

class _PerspectiveMatrix extends ListBase<double> with EquatableMixin {
  _PerspectiveMatrix(List<List<double>> matrix)
      : _values = matrix.reduce((value, element) => [...value, ...element]);

  _PerspectiveMatrix.fromList(this._values);
  final List<double> _values;

  double call(int row, int column) {
    return this[(row - 1) * 3 + column - 1];
  }

  @override
  int length = 9;

  @override
  double operator [](int index) {
    return _values[index];
  }

  @override
  void operator []=(int index, double value) {
    _values[index] = value;
  }

  @override
  String toString() {
    return "PerspectiveMatrix:\n${_values.sublist(0, 3).join(', ')}\n"
        "${_values.sublist(3, 6).join(', ')}\n"
        "${_values.sublist(6, 9).join(', ')}";
  }

  @override
  List<Object?> get props => [_values];
}

/// A widget that applies a perspective transformation to its
/// child based on a [DetectedBarcode].
class PerspectiveBarcode extends StatelessWidget {
  /// Creates a [PerspectiveBarcode] widget.
  const PerspectiveBarcode({
    required this.barcode,
    required this.child,
    super.key,
  });

  /// The barcode that defines the perspective transformation.
  final DetectedBarcode barcode;

  /// The widget that is transformed. Has to be 1x1 in size.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final points = barcode.cornerPoints!.map((e) => e!).toList();
    return Transform(
      transform: Matrix4.fromFloat64List(
        PerspectiveTransform.fromTransformedSquare(points)
            .to3DPerspectiveMatrix(),
      ),
      child: child,
    );
  }
}
