/// Shared constants for message content data types used across the
/// encryption processor pipeline.
///
/// These values appear in the `data['type']` field of nested content
/// envelopes processed by the handlers in
/// `lib/core/encryption/processors/`. Keeping them in one file prevents
/// drift between the five processors that switch on dataType.
library;

/// Content-type constants for agent message data envelopes.
abstract final class DataType {
  // -------------------------------------------------------------------------
  // Core message types (used by all processors)
  // -------------------------------------------------------------------------

  /// Plain text message.
  static const String message = 'message';

  /// Anthropic reasoning / thinking block.
  static const String reasoning = 'reasoning';

  /// Thinking block (ACP-specific).
  static const String thinking = 'thinking';

  /// Model output text (Codex/Pi-specific).
  static const String modelOutput = 'model-output';

  /// Tool call from the agent.
  static const String toolCall = 'tool-call';

  /// Tool result envelope.
  static const String toolResult = 'tool-result';

  /// Tool call result envelope (alternate name).
  static const String toolCallResult = 'tool-call-result';

  // -------------------------------------------------------------------------
  // Assistant envelope (used by output, codex, pi processors)
  // -------------------------------------------------------------------------

  /// Anthropic assistant message envelope with content blocks.
  static const String assistant = 'assistant';

  // -------------------------------------------------------------------------
  // User envelope (used by output processor)
  // -------------------------------------------------------------------------

  /// User message envelope.
  static const String user = 'user';

  // -------------------------------------------------------------------------
  // Web search (used by output processor)
  // -------------------------------------------------------------------------

  /// Web search call.
  static const String webSearchCall = 'web_search_call';

  // -------------------------------------------------------------------------
  // Result envelope (used by codex, pi, output processors)
  // -------------------------------------------------------------------------

  /// Combined result envelope with tool calls and results.
  static const String result = 'result';

  // -------------------------------------------------------------------------
  // File edit (used by acp processor)
  // -------------------------------------------------------------------------

  /// File edit tool call.
  static const String fileEdit = 'file-edit';

  // -------------------------------------------------------------------------
  // System / meta (used by acp, output processors)
  // -------------------------------------------------------------------------

  /// System event envelope.
  static const String system = 'system';

  // -------------------------------------------------------------------------
  // Event content types (used by event processor)
  // -------------------------------------------------------------------------

  /// Ready signal.
  static const String ready = 'ready';

  /// Usage report telemetry.
  static const String usageReport = 'usage_report';

  /// Tool execution progress update.
  static const String toolExecutionUpdate = 'tool-execution-update';

  // -------------------------------------------------------------------------
  // Content block types (used inside assistant.content lists)
  // -------------------------------------------------------------------------

  /// Text content block.
  static const String text = 'text';

  /// Thinking content block.
  static const String thinkingBlock = 'thinking';

  /// Tool use block (Anthropic).
  static const String toolUse = 'tool_use';

  /// Tool call block (alternate).
  static const String toolCallBlock = 'toolCall';

  /// Server tool use block.
  static const String serverToolUse = 'server_tool_use';

  /// MCP tool use block.
  static const String mcpToolUse = 'mcp_tool_use';

  /// Code execution tool use block.
  static const String codeExecutionToolUse = 'code_execution_tool_use';

  /// Tool result block.
  static const String toolResultBlock = 'tool_result';

  /// Image content block.
  static const String image = 'image';

  /// Web search tool result block.
  static const String webSearchToolResult = 'web_search_tool_result';

  /// Server tool result block.
  static const String serverToolResult = 'server_tool_result';

  /// MCP tool result block.
  static const String mcpToolResult = 'mcp_tool_result';

  /// Code execution tool result block.
  static const String codeExecutionToolResult = 'code_execution_tool_result';

  /// Redacted thinking block.
  static const String redactedThinking = 'redacted_thinking';

  // -------------------------------------------------------------------------
  // Session event types (used by session processor)
  // -------------------------------------------------------------------------

  /// Turn start event.
  static const String turnStart = 'turn-start';

  /// Start event.
  static const String start = 'start';

  /// Stop event.
  static const String stop = 'stop';

  /// Turn end event.
  static const String turnEnd = 'turn-end';

  /// Service event.
  static const String service = 'service';

  /// Text event.
  static const String textEvent = 'text';

  /// Tool call start event.
  static const String toolCallStart = 'tool-call-start';

  /// Tool call end event.
  static const String toolCallEnd = 'tool-call-end';

  /// File event.
  static const String file = 'file';

  // -------------------------------------------------------------------------
  // Meta / output subtypes (used by output processor)
  // -------------------------------------------------------------------------

  /// Tool progress meta event.
  static const String toolProgress = 'tool_progress';

  /// Rate limit event.
  static const String rateLimitEvent = 'rate_limit_event';

  /// Compact boundary meta event.
  static const String compactBoundary = 'compact_boundary';

  /// API retry meta event.
  static const String apiRetry = 'api_retry';

  /// Task started subtype.
  static const String taskStarted = 'task_started';

  /// Task progress subtype.
  static const String taskProgress = 'task_progress';

  /// Task updated subtype.
  static const String taskUpdated = 'task_updated';

  /// Task notification subtype.
  static const String taskNotification = 'task_notification';

  /// Init subtype.
  static const String init = 'init';
}
