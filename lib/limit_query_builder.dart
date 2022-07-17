import 'package:flutter/material.dart';
import 'package:limit_query_builder/models/preload_options.dart';

enum LimitQueryType { limitOffset, pageSize }

/// controller for save items and update query
class LimitQueryController<T> extends ScrollController {
  LimitQueryController(
      {this.type = LimitQueryType.limitOffset, this.limit = 10});

  ///if ```LimitQueryType.limitOffset``` in builder return
  /// * limit = limit
  /// * offset = offset
  ///
  ///if ```LimitQueryType.pageSize``` in builder return
  /// * pageSize = limit
  /// * pageIndex = offset
  final LimitQueryType type;

  ///if ```LimitQueryType.limitOffset``` then limit query
  ///
  ///if ```LimitQueryType.pageSize``` then pageSize
  final int limit;

  int _offsetItems = 0;
  final List<T> _items = [];
  Function()? _onUpdate;

  int get currentOffset => _offsetItems;
  List<T> get items => _items;

  ///clear all items, offset to 0, call first load
  void update() async {
    _offsetItems = 0;
    _items.clear();

    if (_onUpdate != null) {
      _onUpdate!();
    }
  }
}

class LimitQueryBuilder<T> extends StatefulWidget {
  const LimitQueryBuilder({
    Key? key,
    required this.controller,
    required this.queryLoad,
    required this.builder,
    this.preLoadEmptyObject,
  }) : super(key: key);

  final LimitQueryController<T> controller;
  final PreLoadOptions<T>? preLoadEmptyObject;
  final Future<List<T>> Function(int offset, int limit) queryLoad;
  final Widget Function(
    BuildContext context,
    AsyncSnapshot<List<T>> snapshot,
  ) builder;

  @override
  State<LimitQueryBuilder<T>> createState() => _LimitQueryBuilderState<T>();
}

class _LimitQueryBuilderState<T> extends State<LimitQueryBuilder<T>> {
  bool _isLoadMore = false;
  late AsyncSnapshot<List<T>> snap;

  load({bool isFirstLoad = false}) async {
    try {
      if (((widget.controller.position.extentAfter < 300 &&
                  widget.controller._items.length >=
                      widget.controller._offsetItems) ||
              isFirstLoad) &&
          !_isLoadMore) {
        if (widget.preLoadEmptyObject != null) {
          snap = AsyncSnapshot.withData(
            ConnectionState.waiting,
            widget.controller._items +
                (widget.preLoadEmptyObject != null
                    ? List.generate(
                        widget.preLoadEmptyObject!.itemCount,
                        (index) => widget.preLoadEmptyObject!.item,
                      )
                    : []),
          );
        }

        _isLoadMore = true;
        if (!mounted) return;
        setState(() {});

        widget.controller._items.addAll(
          await widget.queryLoad(
              widget.controller._offsetItems, widget.controller.limit),
        );

        widget.controller._offsetItems += widget.controller.limit;

        _isLoadMore = false;

        snap = AsyncSnapshot.withData(
          ConnectionState.done,
          widget.controller._items,
        );
        if (!mounted) return;
        setState(() {});
      }
    } catch (error) {
      rethrow;
    }
  }

  @override
  void initState() {
    snap = const AsyncSnapshot.nothing();
    widget.controller._onUpdate = () => load(isFirstLoad: true);
    load(isFirstLoad: true);
    widget.controller.addListener(load);
    super.initState();
  }

  @override
  Widget build(BuildContext context) => widget.builder(
        context,
        snap,
      );
}
