// TerrainFetch.js
// QML-JS library: queue + backoff for Open-Elevation requests
.pragma library

var _queue = [];
var _busy = false;
var _delayMs = 0;
var _batchSize = 90;     // Open-Elevation likes <=100 points per call
var _maxDelay = 15000;   // backoff cap 15s

// Internal: pump the queue. Calls cb(...) provided by QML side.
function _pump(cb) {
    if (_busy) return;

    if (_queue.length === 0) {
        // Signal "nothing to do". QML handler checks for batch === null.
        cb(null, 0);
        return;
    }

    _busy = true;
    var batch = _queue.splice(0, _batchSize);

    // Provide three continuations to the QML caller:
    //  ok()           -> success, maybe reduce backoff and continue
    //  rateLimited()  -> got HTTP 429, increase backoff and ask QML to delay
    //  fail()         -> other failure, increase backoff and continue
    cb(
        batch,
        0, // current suggested delay for this batch (handled in QML when batch===null)
        function ok() {
            _busy = false;
            // gentle decay of delay
            _delayMs = Math.max(0, Math.floor(_delayMs * 0.5));
            _pump(cb);
        },
        function rateLimited() {
            _busy = false;
            // exponential backoff with floor
            _delayMs = Math.min(_maxDelay, Math.max(1000, _delayMs ? _delayMs * 2 : 1000));
            // Tell QML to wait _delayMs then call request() again (batch=null phase)
            cb(null, _delayMs);
        },
        function fail() {
            _busy = false;
            _delayMs = Math.min(_maxDelay, Math.max(1000, _delayMs ? _delayMs * 2 : 1000));
            _pump(cb);
        }
    );
}

// Public: enqueue points and start/continue pumping
function request(points, cb) {
    if (points && points.length) {
        for (var i = 0; i < points.length; i++) _queue.push(points[i]);
    }

    if (_busy) return;

    if (_delayMs > 0) {
        // Ask QML to wait and then call back into request() (batch === null path)
        cb(null, _delayMs);
        return;
    }

    _pump(cb);
}
