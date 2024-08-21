import 'dart:async';
import 'dart:developer';

import 'package:advstory/advstory.dart';
import 'package:advstory/src/view/inherited_widgets/data_provider.dart';
import 'package:advstory/src/view/content_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Creates a content group view.
class StoryView extends StatefulWidget {
  /// Creates a widget to managing [Story] skips using [PageView].
  const StoryView({Key? key}) : super(key: key);

  @override
  State<StoryView> createState() => _StoryViewState();
}

/// State for [StoryView].
class _StoryViewState extends State<StoryView> {
  DataProvider? _provider;
  final _key = GlobalKey<ScaffoldState>();
  double _delta = 0;
  bool _isAnimating = false;
  bool _hasInterceptorCalled = false;
  StoryEvent? _event;
  FutureOr<void> Function()? _interception;

  @override
  void didChangeDependencies() {
    _provider ??= DataProvider.of(context)!;
    super.didChangeDependencies();
  }

  @override
  void dispose() {
    _provider!.controller.notifyListeners(StoryEvent.close);
    if (_provider!.hasTrays && _provider!.style.hideBars) {
      SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.manual,
        overlays: SystemUiOverlay.values,
      );
    }

    super.dispose();
  }

  double _dragStartX = 0.0;
  double _dragEndX = 0.0;


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _key,
      resizeToAvoidBottomInset: false,
      backgroundColor: Colors.transparent, /// original code
      body: ValueListenableBuilder(
        valueListenable: _provider!.controller.gesturesDisabled,
        builder: (context, bool value, child) {
          return IgnorePointer(
            ignoring: value,
            child: child,
          );
        },
        child:
        GestureDetector(
          ///Latest
          onHorizontalDragStart: (details) {
            _dragStartX = details.globalPosition.dx;
          },
          onHorizontalDragUpdate: (details) {
            _dragEndX = details.globalPosition.dx;
          },
          onHorizontalDragEnd: (details) {
            double dragDistance = _dragEndX - _dragStartX;
            TextDirection textDirection = Directionality.of(context);

            if (textDirection == TextDirection.rtl) {
              dragDistance = -dragDistance;
            }

            if (dragDistance > 50) {
              if (_provider!.controller.storyController!.page! == 0) {
                log("0 page ===> ");
                _provider!.controller.resume();
              }
              /// Go to previous page
              if (_provider!.controller.storyController!.page! > 0) {
                _provider!.controller.storyController!.previousPage(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              }
            } else if (dragDistance < -50) {
              /// Go to next page
              if (_provider!.controller.storyController!.page! < 2) {
                _provider!.controller.storyController!.nextPage(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              } else {
                /// Exit the Story when the last page is reached
                Navigator.of(context).pop();
              }
            } else {
              /// Return to the current page
              _provider!.controller.storyController!.animateToPage(
                _provider!.controller.storyController!.page!.round(),
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
              _provider!.controller.resume();
            }
          },
          /// NEW TEST NOT WORKING
          // onHorizontalDragUpdate: (details) {
          //   log("onHorizontalDragUpdate details => $details");
          //   log("current page => ${_provider!.controller.storyController!}");
          //   /// Update the scroll position based on the drag distance
          //   _provider!.controller.storyController!
          //       .jumpTo(_provider!.controller.storyController!.position.pixels - details.primaryDelta!);
          // },
          /// ORIGINAL CODE
          // onHorizontalDragUpdate: _handleDragUpdate,
          // onHorizontalDragEnd: _handleDragEnd,
          // onHorizontalDragCancel: _resetParams,
          child: PageView.builder(
            allowImplicitScrolling: _provider!.preloadStory,
            physics: const NeverScrollableScrollPhysics(),
            pageSnapping: false,
            controller: _provider!.controller.storyController!,
            // Added one more page to detect when user swiped past
            // the last page
            itemBuilder: (context, index) {
              // If user swipes past the last page, return an empty view
              // before closing story view.
              if (index >= _provider!.controller.storyCount) {
                return const SizedBox();
              }

              final ValueNotifier<Widget> content =
                  ValueNotifier(_provider!.style());

              () async {
                final story = await _provider!.buildHelper.buildStory(index);

                content.value = ContentView(
                  storyIndex: index,
                  story: story,
                );
              }();

              return ValueListenableBuilder<Widget>(
                valueListenable: content,
                builder: (context, value, child) => value,
              );
            },
            onPageChanged: _handlePageChange,
          ),
        ),
      ),
    );
  }

  void _handlePageChange(int index) {
    /// User reached to the last page, close story view.
    if (index == _provider!.controller.storyCount) {
      !_provider!.hasTrays
          ? _provider!.controller.positionNotifier.shouldShowView.value = false
          :
      Navigator.of(context).pop();
    } else {
      _provider!.controller.handleStoryChange(index);
    }
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    log("HANDLE DRAG UPDATE STARTED ============================================>");
    if (_isAnimating) return;
    final delta = details.primaryDelta!;
    final cont = _provider!.controller;
    final pageCont = cont.storyController!;
    log("Delta => $delta");
    log("cont => $cont");
    log("pageCont => $pageCont");

    if (!_hasInterceptorCalled) _callInterceptor(delta);

    if (_interception == null) {
      log("NULL Round => ${pageCont.page!.round()}");
      /// Prevent right scroll on first story
      if (pageCont.page!.round() == 0 && delta > 0) {
        cont.resume();
        return;
      }

      _delta += delta;
      pageCont.jumpTo(pageCont.position.pixels - delta); /// Working =>
      final width = _key.currentContext!.size!.width;
      log("Width => $width");
      if (_delta.abs() < width * .2) cont.resume();
    } else if (_event == StoryEvent.close) {
      _interception!();
    } else {
      cont.resume();
    }
  }

  void _callInterceptor(double delta) {
    log("CALL INTERCEPTOR STARTED ============================================>");
    final cont = _provider!.controller;
    log("_callInterceptor const => $cont");
    if (cont.storyController!.page!.round() == cont.storyCount - 1 &&
        delta < 0) {
      log("_callInterceptor 1 => ");
      _event = StoryEvent.close;
    } else {
      log("_callInterceptor 2 => ");
      _event = delta < 0 ? StoryEvent.nextStory : StoryEvent.previousStory;
    }
    _interception = cont.interceptor?.call(_event!);

    _hasInterceptorCalled = true;
  }

  void _handleDragEnd(_) {
    log("HANDLE GRAG END STARTED ============================================>");
    if (_interception == null) {
      final cont = _provider!.controller.storyController!;
      final width = _key.currentContext!.size!.width;
      final bound = _delta.abs() > width * .2;

      log("cont => $cont");
      log("width => $width");
      log("bound => $bound");

      final addition = _delta < 0 ? 1 : -1;
      log("addition => $addition");
      final contPage = cont.page!.round();
      log("page => $contPage");
      final page =
          _delta.abs() < width * .5 && bound ? contPage + addition : contPage;

      log("page => $page");

      _isAnimating = true;
      const duration = Duration(milliseconds: 300);
      cont.animateToPage(page, curve: Curves.ease, duration: duration);
      Future.delayed(duration, () {
        _delta = 0;
        _isAnimating = false;
      });
    } else {
      _interception!();
    }

    _resetParams();
  }

  void _resetParams() {
    _delta = 0;
    _hasInterceptorCalled = false;
    _event = null;
    _interception = null;
  }
}
