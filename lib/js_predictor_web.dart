import 'dart:async';
import 'dart:js' as js;

Future<List<dynamic>> predictWithJS(String base64Image) async {
  final completer = Completer<List<dynamic>>();

  try {
    js.context.callMethod('predictBase64Image', [
      base64Image,
          (result) {
        if (result is List) {
          completer.complete(result.cast<dynamic>());
        } else if (result is js.JsObject) {
          final List<dynamic> list = [];
          final length = result['length'];
          for (var i = 0; i < length; i++) {
            list.add(result[i]);
          }
          completer.complete(list);
        } else {
          completer.completeError("Unexpected JS result type: $result");
        }
      }
    ]);
  } catch (e) {
    completer.completeError("JS call failed: $e");
  }

  return completer.future;
}
