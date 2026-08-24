//! Native hot-path core for happy_flutter.
//!
//! Flutter stays the view layer; the CPU-bound data work that was blocking
//! the Dart UI isolate lives here. Production telemetry motivating this:
//! frozen frames on the chat route ran ~487 ms p95 while frame *build* and
//! *raster* were only ~9.6 ms each — ~96 % of every frozen frame was the UI
//! isolate blocked on pure computation, not on widgets or the GPU.

pub mod api;
pub mod crypto;
mod frb_generated;
