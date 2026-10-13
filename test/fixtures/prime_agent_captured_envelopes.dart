import 'dart:convert';

// Exact Happy envelopes from the captured Prime ACP subagent replay through
// happy-cli-go. Keep this browser-safe rather than reading a fixture via IO.
List<Map<String, dynamic>> capturedPrimeAgentEnvelopes() =>
    (jsonDecode(_capturedEnvelopes) as List).cast<Map<String, dynamic>>();

const _capturedEnvelopes = r'''
[
  {
    "content": {
      "data": {
        "agentId": "sub-alpha",
        "agentMetadata": {
          "model": "gpt-6-luna",
          "nickname": "alpha_reader",
          "provider": "openai-codex"
        },
        "callId": "prime-agent:sub-alpha",
        "input": {
          "agentId": "sub-alpha",
          "agentMetadata": {
            "model": "gpt-6-luna",
            "nickname": "alpha_reader",
            "provider": "openai-codex"
          },
          "description": "alpha_reader",
          "nickname": "alpha_reader",
          "prompt": "alpha_reader",
          "sessionName": "alpha_reader",
          "subagent_type": "prime-agent"
        },
        "name": "Agent",
        "status": "running",
        "type": "tool-call"
      },
      "type": "acp"
    },
    "role": "agent"
  },
  {
    "content": {
      "data": {
        "agentId": "sub-beta",
        "agentMetadata": {
          "model": "gpt-6-luna",
          "nickname": "beta_reader",
          "provider": "openai-codex"
        },
        "callId": "prime-agent:sub-beta",
        "input": {
          "agentId": "sub-beta",
          "agentMetadata": {
            "model": "gpt-6-luna",
            "nickname": "beta_reader",
            "provider": "openai-codex"
          },
          "description": "beta_reader",
          "nickname": "beta_reader",
          "prompt": "beta_reader",
          "sessionName": "beta_reader",
          "subagent_type": "prime-agent"
        },
        "name": "Agent",
        "status": "running",
        "type": "tool-call"
      },
      "type": "acp"
    },
    "role": "agent"
  },
  {
    "content": {
      "data": {
        "agentId": "sub-beta",
        "agentMetadata": {
          "model": "gpt-6-luna",
          "nickname": "beta_reader",
          "provider": "openai-codex"
        },
        "callId": "prime-agent:sub-beta",
        "isError": false,
        "result": {
          "agentMetadata": {
            "model": "gpt-6-luna",
            "nickname": "beta_reader",
            "provider": "openai-codex"
          },
          "rawStatus": "done",
          "status": "completed"
        },
        "status": "completed",
        "type": "tool-result"
      },
      "type": "acp"
    },
    "role": "agent"
  },
  {
    "content": {
      "data": {
        "agentId": "sub-alpha",
        "agentMetadata": {
          "model": "gpt-6-luna",
          "nickname": "alpha_reader",
          "provider": "openai-codex"
        },
        "callId": "prime-agent:sub-alpha",
        "isError": false,
        "result": {
          "agentMetadata": {
            "model": "gpt-6-luna",
            "nickname": "alpha_reader",
            "provider": "openai-codex"
          },
          "rawStatus": "done",
          "status": "completed"
        },
        "status": "completed",
        "type": "tool-result"
      },
      "type": "acp"
    },
    "role": "agent"
  }
]
''';
