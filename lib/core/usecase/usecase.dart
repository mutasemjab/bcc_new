import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';

import '../error/failures.dart';

typedef ResultFuture<T> = Future<Either<Failure, T>>;

/// A single business action that returns a result once.
abstract class UseCase<T, P> {
  const UseCase();
  ResultFuture<T> call(P params);
}

/// A business action that exposes a live, real-time stream.
abstract class StreamUseCase<T, P> {
  const StreamUseCase();
  Stream<T> call(P params);
}

class NoParams extends Equatable {
  const NoParams();
  @override
  List<Object?> get props => [];
}
