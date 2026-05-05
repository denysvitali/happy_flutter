import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/encryption/encryptor.dart';
import 'package:happy_flutter/core/encryption/encryption_cache.dart';
import 'package:happy_flutter/core/encryption/encryption_manager.dart';
import 'package:happy_flutter/core/encryption/message_processor.dart';
import 'package:happy_flutter/core/encryption/session_encryption.dart';
import 'package:happy_flutter/core/models/built_in_profiles.dart';
import 'package:happy_flutter/core/models/machine.dart';
import 'package:happy_flutter/core/models/session.dart';
import 'package:happy_flutter/core/models/settings.dart';
import 'package:happy_flutter/core/rpc/rpc_types.dart';
import 'package:happy_flutter/core/services/sync_service.dart';
import 'package:happy_flutter/core/utils/invalidate_sync.dart';

/// E2E tests for profile switching and environment variable propagation.
///
/// Verifies that:
///   - Switching profiles causes the correct env vars to be sent on spawn
///   - Built-in profile env vars are forwarded correctly
///   - Custom profiles with explicit configs produce the right env vars
///   - Profile switches between sessions are isolated
///   - Auto-restore uses the session-specific profile, not the global one
///   - The `_profileEnvironmentVariables` logic merges env vars + configs
///   - No profile → empty env vars (no stale leakage)
void main() {
  group('Profile env vars on createSession', () {
    late Sync sync;
    late _FakeEncryption encryption;

    setUp(() {
      sync = Sync();
      encryption = _FakeEncryption();
      sync.encryption = encryption;
      sync.testIsInitialized = true;
      sync.testSocketConnectedOverride = true;
      sync.testSocketSendOverride = (_, __) {};
      sync.testSessions.clear();
      sync.testClearSessionSpawnedAt();
      sync.testSettingsSnapshot = Settings();
      sync.testFetchMessagesOverride = (_, __, ___) async => <String, dynamic>{
        'messages': <dynamic>[],
      };
      _stubAllSyncs(sync);
    });

    tearDown(() {
      sync.testSocketConnectedOverride = null;
      sync.testSocketSendOverride = null;
      sync.testMachineRPCOverride = null;
      sync.testGetSpawnEnvVarsOverride = null;
      sync.testFetchMessagesOverride = null;
    });

    test('creates session with DeepSeek profile env vars', () async {
      final sessionId = 'profile-deepseek-1';
      Map<String, dynamic>? capturedParams;
      sync.testMachineRPCOverride = (machineId, method, params) async {
        capturedParams = params;
        return <String, dynamic>{
          'type': 'success',
          'sessionId': sessionId,
          'dataEncryptionKey': null,
        };
      };

      await sync.applySettings({'lastUsedProfile': 'deepseek'});

      await sync.createSession(
        agent: 'claude',
        machineId: 'machine-1',
        path: '/home/user/project',
      );

      expect(capturedParams, isNotNull);
      final envVars =
          capturedParams!['environmentVariables'] as Map<String, dynamic>?;
      expect(envVars, isNotNull);
      expect(
        envVars!['ANTHROPIC_BASE_URL'],
        contains('deepseek'),
        reason: 'DeepSeek profile must set ANTHROPIC_BASE_URL',
      );
      expect(
        envVars['ANTHROPIC_AUTH_TOKEN'],
        isNotNull,
        reason: 'DeepSeek profile must set ANTHROPIC_AUTH_TOKEN',
      );
      expect(
        envVars['ANTHROPIC_MODEL'],
        contains('deepseek'),
        reason: 'DeepSeek profile must set ANTHROPIC_MODEL',
      );
      expect(
        envVars['CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC'],
        isNotNull,
        reason: 'DeepSeek profile disables nonessential traffic',
      );
    });

    test('creates session with OpenAI profile env vars', () async {
      final sessionId = 'profile-openai-1';
      Map<String, dynamic>? capturedParams;
      sync.testMachineRPCOverride = (machineId, method, params) async {
        capturedParams = params;
        return <String, dynamic>{
          'type': 'success',
          'sessionId': sessionId,
          'dataEncryptionKey': null,
        };
      };

      await sync.applySettings({'lastUsedProfile': 'openai'});

      await sync.createSession(
        agent: 'claude',
        machineId: 'machine-1',
        path: '/home/user/project',
      );

      expect(capturedParams, isNotNull);
      final envVars =
          capturedParams!['environmentVariables'] as Map<String, dynamic>?;
      expect(envVars, isNotNull);
      expect(
        envVars!['OPENAI_BASE_URL'],
        'https://api.openai.com/v1',
        reason: 'OpenAI profile must set OPENAI_BASE_URL',
      );
      expect(
        envVars['OPENAI_MODEL'],
        '',
        reason: 'OpenAI profile must set OPENAI_MODEL',
      );
      expect(
        envVars['API_TIMEOUT_MS'],
        '600000',
        reason: 'OpenAI profile must set API_TIMEOUT_MS',
      );
      // OpenAI profile should NOT set Anthropic env vars
      expect(
        envVars.containsKey('ANTHROPIC_BASE_URL'),
        isFalse,
        reason: 'OpenAI profile must not set Anthropic env vars',
      );
    });

    test('creates session with Azure OpenAI profile env vars', () async {
      final sessionId = 'profile-azure-1';
      Map<String, dynamic>? capturedParams;
      sync.testMachineRPCOverride = (machineId, method, params) async {
        capturedParams = params;
        return <String, dynamic>{
          'type': 'success',
          'sessionId': sessionId,
          'dataEncryptionKey': null,
        };
      };

      await sync.applySettings({'lastUsedProfile': 'azure-openai'});

      await sync.createSession(
        agent: 'claude',
        machineId: 'machine-1',
        path: '/home/user/project',
      );

      expect(capturedParams, isNotNull);
      final envVars =
          capturedParams!['environmentVariables'] as Map<String, dynamic>?;
      expect(envVars, isNotNull);
      expect(
        envVars!['AZURE_OPENAI_API_VERSION'],
        '2024-02-15-preview',
        reason: 'Azure profile must set AZURE_OPENAI_API_VERSION',
      );
      expect(
        envVars['AZURE_OPENAI_DEPLOYMENT_NAME'],
        'gpt-5-codex',
        reason: 'Azure profile must set AZURE_OPENAI_DEPLOYMENT_NAME',
      );
    });

    test('creates session with MiniMax profile env vars', () async {
      final sessionId = 'profile-minimax-1';
      Map<String, dynamic>? capturedParams;
      sync.testMachineRPCOverride = (machineId, method, params) async {
        capturedParams = params;
        return <String, dynamic>{
          'type': 'success',
          'sessionId': sessionId,
          'dataEncryptionKey': null,
        };
      };

      await sync.applySettings({'lastUsedProfile': 'minimax'});

      await sync.createSession(
        agent: 'claude',
        machineId: 'machine-1',
        path: '/home/user/project',
      );

      expect(capturedParams, isNotNull);
      final envVars =
          capturedParams!['environmentVariables'] as Map<String, dynamic>?;
      expect(envVars, isNotNull);
      expect(
        envVars!['ANTHROPIC_BASE_URL'],
        contains('minimax'),
        reason: 'MiniMax profile must set ANTHROPIC_BASE_URL',
      );
      expect(
        envVars['ANTHROPIC_AUTH_TOKEN'],
        isNotNull,
        reason: 'MiniMax profile must set ANTHROPIC_AUTH_TOKEN',
      );
      expect(
        envVars['ANTHROPIC_MODEL'],
        contains('MiniMax-M2.7'),
        reason: 'MiniMax profile must set ANTHROPIC_MODEL',
      );
      expect(
        envVars['ANTHROPIC_DEFAULT_OPUS_MODEL'],
        contains('MiniMax-M2.7'),
        reason: 'MiniMax profile must set Anthropic tier overrides',
      );
    });

    test('creates session with Z.AI profile env vars', () async {
      final sessionId = 'profile-zai-1';
      Map<String, dynamic>? capturedParams;
      sync.testMachineRPCOverride = (machineId, method, params) async {
        capturedParams = params;
        return <String, dynamic>{
          'type': 'success',
          'sessionId': sessionId,
          'dataEncryptionKey': null,
        };
      };

      await sync.applySettings({'lastUsedProfile': 'zai'});

      await sync.createSession(
        agent: 'claude',
        machineId: 'machine-1',
        path: '/home/user/project',
      );

      expect(capturedParams, isNotNull);
      final envVars =
          capturedParams!['environmentVariables'] as Map<String, dynamic>?;
      expect(envVars, isNotNull);
      expect(
        envVars!['ANTHROPIC_BASE_URL'],
        contains('z.ai'),
        reason: 'Z.AI profile must set ANTHROPIC_BASE_URL',
      );
      expect(
        envVars['ANTHROPIC_DEFAULT_OPUS_MODEL'],
        contains('glm-5.1'),
        reason: 'Z.AI profile must set Opus model override',
      );
      expect(envVars['ANTHROPIC_DEFAULT_SONNET_MODEL'], contains('glm-4.7'));
      expect(envVars['ANTHROPIC_DEFAULT_HAIKU_MODEL'], contains('glm-4.5-air'));
      expect(
        envVars.containsKey('ANTHROPIC_MODEL'),
        isFalse,
        reason:
            'Z.AI profile should rely on tier overrides, not ANTHROPIC_MODEL',
      );
    });

    test('no profile sends empty env vars', () async {
      final sessionId = 'profile-none-1';
      Map<String, dynamic>? capturedParams;
      sync.testMachineRPCOverride = (machineId, method, params) async {
        capturedParams = params;
        return <String, dynamic>{
          'type': 'success',
          'sessionId': sessionId,
          'dataEncryptionKey': null,
        };
      };

      // No profile set — lastUsedProfile is null by default
      await sync.createSession(
        agent: 'claude',
        machineId: 'machine-1',
        path: '/home/user/project',
      );

      expect(capturedParams, isNotNull);
      // SpawnSessionRequest.toJson() omits environmentVariables when
      // empty, so the key may be absent entirely.
      final envVars =
          capturedParams!['environmentVariables'] as Map<String, dynamic>?;
      if (envVars != null) {
        expect(
          envVars.containsKey('ANTHROPIC_BASE_URL'),
          isFalse,
          reason: 'No profile must not inject any profile env vars',
        );
        expect(envVars.containsKey('OPENAI_BASE_URL'), isFalse);
        expect(envVars.containsKey('OPENAI_API_KEY'), isFalse);
      }
      // If envVars is null, that's correct — no env vars to send
    });

    test('Anthropic default profile sends no env vars', () async {
      final sessionId = 'profile-anthropic-1';
      Map<String, dynamic>? capturedParams;
      sync.testMachineRPCOverride = (machineId, method, params) async {
        capturedParams = params;
        return <String, dynamic>{
          'type': 'success',
          'sessionId': sessionId,
          'dataEncryptionKey': null,
        };
      };

      await sync.applySettings({'lastUsedProfile': 'anthropic'});

      await sync.createSession(
        agent: 'claude',
        machineId: 'machine-1',
        path: '/home/user/project',
      );

      expect(capturedParams, isNotNull);
      // Anthropic default has no env vars or config overrides, so
      // SpawnSessionRequest.toJson() omits the key entirely.
      final envVars =
          capturedParams!['environmentVariables'] as Map<String, dynamic>?;
      if (envVars != null) {
        expect(
          envVars.containsKey('ANTHROPIC_BASE_URL'),
          isFalse,
          reason: 'Anthropic default profile has no env overrides',
        );
        expect(envVars.containsKey('OPENAI_BASE_URL'), isFalse);
      }
    });

    test('explicit profileId param overrides lastUsedProfile', () async {
      final sessionId = 'profile-override-1';
      Map<String, dynamic>? capturedParams;
      sync.testMachineRPCOverride = (machineId, method, params) async {
        capturedParams = params;
        return <String, dynamic>{
          'type': 'success',
          'sessionId': sessionId,
          'dataEncryptionKey': null,
        };
      };

      // Set global to OpenAI
      await sync.applySettings({'lastUsedProfile': 'openai'});

      // But pass DeepSeek explicitly
      await sync.createSession(
        agent: 'claude',
        machineId: 'machine-1',
        path: '/home/user/project',
        profileId: 'deepseek',
      );

      expect(capturedParams, isNotNull);
      final envVars =
          capturedParams!['environmentVariables'] as Map<String, dynamic>?;
      expect(envVars, isNotNull);
      // Should have DeepSeek vars, not OpenAI
      expect(
        envVars!['ANTHROPIC_BASE_URL'],
        contains('deepseek'),
        reason: 'Explicit profileId must override lastUsedProfile',
      );
      expect(envVars.containsKey('OPENAI_BASE_URL'), isFalse);
    });
  });

  group('Custom profile env vars on createSession', () {
    late Sync sync;
    late _FakeEncryption encryption;

    setUp(() {
      sync = Sync();
      encryption = _FakeEncryption();
      sync.encryption = encryption;
      sync.testIsInitialized = true;
      sync.testSocketConnectedOverride = true;
      sync.testSocketSendOverride = (_, __) {};
      sync.testSessions.clear();
      sync.testClearSessionSpawnedAt();
      sync.testSettingsSnapshot = Settings();
      sync.testFetchMessagesOverride = (_, __, ___) async => <String, dynamic>{
        'messages': <dynamic>[],
      };
      _stubAllSyncs(sync);
    });

    tearDown(() {
      sync.testSocketConnectedOverride = null;
      sync.testSocketSendOverride = null;
      sync.testMachineRPCOverride = null;
      sync.testGetSpawnEnvVarsOverride = null;
      sync.testFetchMessagesOverride = null;
    });

    test(
      'custom profile with anthropicConfig sends correct env vars',
      () async {
        final sessionId = 'custom-anthropic-1';
        Map<String, dynamic>? capturedParams;
        sync.testMachineRPCOverride = (machineId, method, params) async {
          capturedParams = params;
          return <String, dynamic>{
            'type': 'success',
            'sessionId': sessionId,
            'dataEncryptionKey': null,
          };
        };

        final customProfile = AIBackendProfile(
          id: 'my-custom',
          name: 'My Custom Profile',
          anthropicConfig: AnthropicConfig(
            baseUrl: 'https://my-proxy.example.com/v1',
            authToken: 'sk-custom-token-123',
            model: 'claude-opus-4-20250514',
          ),
        );

        await sync.applySettings({
          'profiles': [customProfile.toJson()],
          'lastUsedProfile': 'my-custom',
        });

        await sync.createSession(
          agent: 'claude',
          machineId: 'machine-1',
          path: '/home/user/project',
        );

        expect(capturedParams, isNotNull);
        final envVars =
            capturedParams!['environmentVariables'] as Map<String, dynamic>?;
        expect(envVars, isNotNull);
        expect(
          envVars!['ANTHROPIC_BASE_URL'],
          'https://my-proxy.example.com/v1',
          reason:
              'Custom profile anthropicConfig.baseUrl must map '
              'to ANTHROPIC_BASE_URL',
        );
        expect(
          envVars['ANTHROPIC_AUTH_TOKEN'],
          'sk-custom-token-123',
          reason:
              'Custom profile anthropicConfig.authToken must map '
              'to ANTHROPIC_AUTH_TOKEN',
        );
        expect(
          envVars['ANTHROPIC_MODEL'],
          'claude-opus-4-20250514',
          reason:
              'Custom profile anthropicConfig.model must map '
              'to ANTHROPIC_MODEL',
        );
      },
    );

    test('custom profile with openaiConfig sends correct env vars', () async {
      final sessionId = 'custom-openai-1';
      Map<String, dynamic>? capturedParams;
      sync.testMachineRPCOverride = (machineId, method, params) async {
        capturedParams = params;
        return <String, dynamic>{
          'type': 'success',
          'sessionId': sessionId,
          'dataEncryptionKey': null,
        };
      };

      final customProfile = AIBackendProfile(
        id: 'my-openai',
        name: 'My OpenAI',
        openaiConfig: OpenAIConfig(
          apiKey: 'sk-openai-secret',
          baseUrl: 'https://openai-proxy.example.com/v1',
          model: 'gpt-4o',
        ),
      );

      await sync.applySettings({
        'profiles': [customProfile.toJson()],
        'lastUsedProfile': 'my-openai',
      });

      await sync.createSession(
        agent: 'claude',
        machineId: 'machine-1',
        path: '/home/user/project',
      );

      expect(capturedParams, isNotNull);
      final envVars =
          capturedParams!['environmentVariables'] as Map<String, dynamic>?;
      expect(envVars, isNotNull);
      expect(envVars!['OPENAI_API_KEY'], 'sk-openai-secret');
      expect(envVars['OPENAI_BASE_URL'], 'https://openai-proxy.example.com/v1');
      expect(envVars['OPENAI_MODEL'], 'gpt-4o');
    });

    test(
      'custom profile with azureOpenAIConfig sends correct env vars',
      () async {
        final sessionId = 'custom-azure-1';
        Map<String, dynamic>? capturedParams;
        sync.testMachineRPCOverride = (machineId, method, params) async {
          capturedParams = params;
          return <String, dynamic>{
            'type': 'success',
            'sessionId': sessionId,
            'dataEncryptionKey': null,
          };
        };

        final customProfile = AIBackendProfile(
          id: 'my-azure',
          name: 'My Azure',
          azureOpenAIConfig: AzureOpenAIConfig(
            apiKey: 'azure-key-abc',
            endpoint: 'https://my-azure.openai.azure.com',
            apiVersion: '2024-06-01',
            deploymentName: 'my-deployment',
          ),
        );

        await sync.applySettings({
          'profiles': [customProfile.toJson()],
          'lastUsedProfile': 'my-azure',
        });

        await sync.createSession(
          agent: 'claude',
          machineId: 'machine-1',
          path: '/home/user/project',
        );

        expect(capturedParams, isNotNull);
        final envVars =
            capturedParams!['environmentVariables'] as Map<String, dynamic>?;
        expect(envVars, isNotNull);
        expect(envVars!['AZURE_OPENAI_API_KEY'], 'azure-key-abc');
        expect(
          envVars['AZURE_OPENAI_ENDPOINT'],
          'https://my-azure.openai.azure.com',
        );
        expect(envVars['AZURE_OPENAI_API_VERSION'], '2024-06-01');
        expect(envVars['AZURE_OPENAI_DEPLOYMENT_NAME'], 'my-deployment');
      },
    );

    test(
      'custom profile with togetherAIConfig sends correct env vars',
      () async {
        final sessionId = 'custom-together-1';
        Map<String, dynamic>? capturedParams;
        sync.testMachineRPCOverride = (machineId, method, params) async {
          capturedParams = params;
          return <String, dynamic>{
            'type': 'success',
            'sessionId': sessionId,
            'dataEncryptionKey': null,
          };
        };

        final customProfile = AIBackendProfile(
          id: 'my-together',
          name: 'My Together',
          togetherAIConfig: TogetherAIConfig(
            apiKey: 'together-key-xyz',
            model: 'meta-llama/Meta-Llama-3.1-70B',
          ),
        );

        await sync.applySettings({
          'profiles': [customProfile.toJson()],
          'lastUsedProfile': 'my-together',
        });

        await sync.createSession(
          agent: 'claude',
          machineId: 'machine-1',
          path: '/home/user/project',
        );

        expect(capturedParams, isNotNull);
        final envVars =
            capturedParams!['environmentVariables'] as Map<String, dynamic>?;
        expect(envVars, isNotNull);
        expect(envVars!['TOGETHER_API_KEY'], 'together-key-xyz');
        expect(envVars['TOGETHER_MODEL'], 'meta-llama/Meta-Llama-3.1-70B');
      },
    );

    test('custom profile with tmuxConfig sends correct env vars', () async {
      final sessionId = 'custom-tmux-1';
      Map<String, dynamic>? capturedParams;
      sync.testMachineRPCOverride = (machineId, method, params) async {
        capturedParams = params;
        return <String, dynamic>{
          'type': 'success',
          'sessionId': sessionId,
          'dataEncryptionKey': null,
        };
      };

      final customProfile = AIBackendProfile(
        id: 'my-tmux',
        name: 'My Tmux',
        tmuxConfig: TmuxConfig(
          sessionName: 'dev-session',
          tmpDir: '/tmp/my-tmux',
          updateEnvironment: true,
        ),
      );

      await sync.applySettings({
        'profiles': [customProfile.toJson()],
        'lastUsedProfile': 'my-tmux',
      });

      await sync.createSession(
        agent: 'claude',
        machineId: 'machine-1',
        path: '/home/user/project',
      );

      expect(capturedParams, isNotNull);
      final envVars =
          capturedParams!['environmentVariables'] as Map<String, dynamic>?;
      expect(envVars, isNotNull);
      expect(envVars!['TMUX_SESSION_NAME'], 'dev-session');
      expect(envVars['TMUX_TMPDIR'], '/tmp/my-tmux');
      expect(envVars['TMUX_UPDATE_ENVIRONMENT'], 'true');
    });

    test('custom profile with explicit environmentVariables list', () async {
      final sessionId = 'custom-envlist-1';
      Map<String, dynamic>? capturedParams;
      sync.testMachineRPCOverride = (machineId, method, params) async {
        capturedParams = params;
        return <String, dynamic>{
          'type': 'success',
          'sessionId': sessionId,
          'dataEncryptionKey': null,
        };
      };

      final customProfile = AIBackendProfile(
        id: 'my-env',
        name: 'Env Profile',
        environmentVariables: [
          EnvironmentVariable(name: 'MY_CUSTOM_VAR', value: 'hello-world'),
          EnvironmentVariable(name: 'FEATURE_FLAG', value: 'enabled'),
        ],
      );

      await sync.applySettings({
        'profiles': [customProfile.toJson()],
        'lastUsedProfile': 'my-env',
      });

      await sync.createSession(
        agent: 'claude',
        machineId: 'machine-1',
        path: '/home/user/project',
      );

      expect(capturedParams, isNotNull);
      final envVars =
          capturedParams!['environmentVariables'] as Map<String, dynamic>?;
      expect(envVars, isNotNull);
      expect(envVars!['MY_CUSTOM_VAR'], 'hello-world');
      expect(envVars['FEATURE_FLAG'], 'enabled');
    });

    test('config fields override explicit environmentVariables list', () async {
      final sessionId = 'custom-merge-1';
      Map<String, dynamic>? capturedParams;
      sync.testMachineRPCOverride = (machineId, method, params) async {
        capturedParams = params;
        return <String, dynamic>{
          'type': 'success',
          'sessionId': sessionId,
          'dataEncryptionKey': null,
        };
      };

      // Profile with both environmentVariables AND anthropicConfig.
      // The config fields should override matching env vars from the
      // list because _profileEnvironmentVariables processes the list
      // first, then the config.
      final customProfile = AIBackendProfile(
        id: 'my-merge',
        name: 'Merge Profile',
        environmentVariables: [
          EnvironmentVariable(
            name: 'ANTHROPIC_BASE_URL',
            value: 'https://from-env-list.com',
          ),
          EnvironmentVariable(name: 'EXTRA_VAR', value: 'kept'),
        ],
        anthropicConfig: AnthropicConfig(baseUrl: 'https://from-config.com'),
      );

      await sync.applySettings({
        'profiles': [customProfile.toJson()],
        'lastUsedProfile': 'my-merge',
      });

      await sync.createSession(
        agent: 'claude',
        machineId: 'machine-1',
        path: '/home/user/project',
      );

      expect(capturedParams, isNotNull);
      final envVars =
          capturedParams!['environmentVariables'] as Map<String, dynamic>?;
      expect(envVars, isNotNull);
      // Config should override the env list entry
      expect(
        envVars!['ANTHROPIC_BASE_URL'],
        'https://from-config.com',
        reason:
            'anthropicConfig.baseUrl must override the '
            'environmentVariables list entry',
      );
      // Non-overlapping env vars should be kept
      expect(envVars['EXTRA_VAR'], 'kept');
    });

    test('custom profile overrides built-in with same ID', () async {
      final sessionId = 'custom-override-1';
      Map<String, dynamic>? capturedParams;
      sync.testMachineRPCOverride = (machineId, method, params) async {
        capturedParams = params;
        return <String, dynamic>{
          'type': 'success',
          'sessionId': sessionId,
          'dataEncryptionKey': null,
        };
      };

      // Custom profile with same ID as built-in 'openai'
      final customProfile = AIBackendProfile(
        id: 'openai',
        name: 'My Custom OpenAI',
        openaiConfig: OpenAIConfig(
          apiKey: 'sk-custom-key',
          baseUrl: 'https://custom-openai.example.com/v1',
          model: 'my-custom-model',
        ),
      );

      await sync.applySettings({
        'profiles': [customProfile.toJson()],
        'lastUsedProfile': 'openai',
      });

      await sync.createSession(
        agent: 'claude',
        machineId: 'machine-1',
        path: '/home/user/project',
      );

      expect(capturedParams, isNotNull);
      final envVars =
          capturedParams!['environmentVariables'] as Map<String, dynamic>?;
      expect(envVars, isNotNull);
      // Custom profile should take precedence over built-in
      expect(
        envVars!['OPENAI_BASE_URL'],
        'https://custom-openai.example.com/v1',
        reason:
            'Custom profile must override built-in with '
            'same ID',
      );
      expect(envVars['OPENAI_API_KEY'], 'sk-custom-key');
      expect(envVars['OPENAI_MODEL'], 'my-custom-model');
    });
  });

  group('Profile switching between sessions', () {
    late Sync sync;
    late _FakeEncryption encryption;

    setUp(() {
      sync = Sync();
      encryption = _FakeEncryption();
      sync.encryption = encryption;
      sync.testIsInitialized = true;
      sync.testSocketConnectedOverride = true;
      sync.testSocketSendOverride = (_, __) {};
      sync.testSessions.clear();
      sync.testClearSessionSpawnedAt();
      sync.testSettingsSnapshot = Settings();
      sync.testFetchMessagesOverride = (_, __, ___) async => <String, dynamic>{
        'messages': <dynamic>[],
      };
      _stubAllSyncs(sync);
    });

    tearDown(() {
      sync.testSocketConnectedOverride = null;
      sync.testSocketSendOverride = null;
      sync.testMachineRPCOverride = null;
      sync.testGetSpawnEnvVarsOverride = null;
      sync.testFetchMessagesOverride = null;
    });

    test('switching profile between two createSession calls sends '
        'different env vars', () async {
      final captures = <String, Map<String, dynamic>>{};
      var callCount = 0;

      sync.testMachineRPCOverride = (machineId, method, params) async {
        callCount++;
        final sessionId = 'session-$callCount';
        captures[sessionId] = params;
        return <String, dynamic>{
          'type': 'success',
          'sessionId': sessionId,
          'dataEncryptionKey': null,
        };
      };

      // First session with DeepSeek
      await sync.applySettings({'lastUsedProfile': 'deepseek'});
      final session1 = await sync.createSession(
        agent: 'claude',
        machineId: 'machine-1',
        path: '/home/user/project-a',
      );

      // Switch to OpenAI
      await sync.applySettings({'lastUsedProfile': 'openai'});
      final session2 = await sync.createSession(
        agent: 'claude',
        machineId: 'machine-1',
        path: '/home/user/project-b',
      );

      final env1 =
          captures[session1]!['environmentVariables'] as Map<String, dynamic>;
      final env2 =
          captures[session2]!['environmentVariables'] as Map<String, dynamic>;

      // Session 1 should have DeepSeek vars
      expect(
        env1['ANTHROPIC_BASE_URL'],
        contains('deepseek'),
        reason: 'First session must use DeepSeek profile',
      );
      expect(env1.containsKey('OPENAI_BASE_URL'), isFalse);

      // Session 2 should have OpenAI vars
      expect(
        env2['OPENAI_BASE_URL'],
        'https://api.openai.com/v1',
        reason: 'Second session must use OpenAI profile',
      );
      expect(env2.containsKey('ANTHROPIC_BASE_URL'), isFalse);
    });

    test('switching from profile to no profile removes env vars', () async {
      final captures = <int, Map<String, dynamic>>{};
      var callCount = 0;

      sync.testMachineRPCOverride = (machineId, method, params) async {
        callCount++;
        captures[callCount] = params;
        return <String, dynamic>{
          'type': 'success',
          'sessionId': 'session-$callCount',
          'dataEncryptionKey': null,
        };
      };

      // First session with DeepSeek
      await sync.applySettings({'lastUsedProfile': 'deepseek'});
      await sync.createSession(
        agent: 'claude',
        machineId: 'machine-1',
        path: '/home/user/project',
      );

      // Switch to no profile
      await sync.applySettings({'lastUsedProfile': null});
      await sync.createSession(
        agent: 'claude',
        machineId: 'machine-1',
        path: '/home/user/project-2',
      );

      final env1 = captures[1]!['environmentVariables'] as Map<String, dynamic>;

      // First session had profile vars
      expect(env1['ANTHROPIC_BASE_URL'], contains('deepseek'));

      // Second session should have NO profile vars — the key is
      // omitted entirely when env vars are empty.
      final env2 =
          captures[2]!['environmentVariables'] as Map<String, dynamic>?;
      if (env2 != null) {
        expect(
          env2.containsKey('ANTHROPIC_BASE_URL'),
          isFalse,
          reason:
              'Clearing profile must remove all profile '
              'env vars from subsequent sessions',
        );
        expect(env2.containsKey('ANTHROPIC_AUTH_TOKEN'), isFalse);
        expect(env2.containsKey('ANTHROPIC_MODEL'), isFalse);
      }
    });
  });

  group('Auto-restore uses session-specific profile', () {
    late Sync sync;
    late _FakeEncryption encryption;

    setUp(() {
      sync = Sync();
      encryption = _FakeEncryption();
      sync.encryption = encryption;
      sync.testIsInitialized = true;
      sync.testSocketConnectedOverride = true;
      sync.testSocketSendOverride = (_, __) {};
      sync.testSessions.clear();
      sync.testClearSessionSpawnedAt();
      sync.testSettingsSnapshot = Settings();
      sync.testFetchMessagesOverride = (_, __, ___) async => <String, dynamic>{
        'messages': <dynamic>[],
      };
      _stubAllSyncs(sync);
    });

    tearDown(() {
      sync.testSocketConnectedOverride = null;
      sync.testSocketSendOverride = null;
      sync.testMachineRPCOverride = null;
      sync.testFetchSingleSessionOverride = null;
      sync.testFetchMessagesOverride = null;
      sync.testGetSpawnEnvVarsOverride = null;
    });

    test('auto-restore sends session-specific profile env vars, '
        'not global lastUsedProfile', () async {
      final sessionId = 'auto-restore-1';
      Map<String, dynamic>? capturedSpawnParams;

      // The session was originally created with DeepSeek profile
      // (stored in MMKV via _getSpawnEnvVarsForSession).
      // We override this to simulate the stored profile.
      sync.testGetSpawnEnvVarsOverride = (sid) async {
        if (sid == sessionId) {
          final deepseek = getBuiltInProfile('deepseek')!;
          return (
            envVars: <String, String>{
              for (final v in deepseek.environmentVariables) v.name: v.value,
            },
            profile: deepseek,
          );
        }
        return (envVars: <String, String>{}, profile: null);
      };

      // Global profile is now OpenAI (user switched after creating
      // the session).
      await sync.applySettings({'lastUsedProfile': 'openai'});

      // Set up an offline session that will trigger auto-restore
      final now = DateTime.now().millisecondsSinceEpoch;
      sync.testSessions[sessionId] = Session(
        id: sessionId,
        seq: 1,
        createdAt: now - 60000,
        updatedAt: now - 60000,
        active: true,
        activeAt: now,
        metadataVersion: 1,
        agentStateVersion: 0,
        thinking: false,
        presence: 'offline',
        metadata: Metadata(
          host: '',
          machineId: 'machine-1',
          path: '/home/user/project',
          lifecycleState: 'archived',
        ),
      );

      // Machine must be online for auto-restore
      sync.testMachines['machine-1'] = Machine(
        id: 'machine-1',
        seq: 1,
        createdAt: 0,
        updatedAt: 0,
        active: true,
        activeAt: now,
        metadataVersion: 0,
        daemonStateVersion: 0,
      );

      sync.testMachineRPCOverride = (machineId, method, params) async {
        if (method == 'spawn-happy-session') {
          capturedSpawnParams = params;
          return <String, dynamic>{
            'type': 'success',
            'sessionId': sessionId,
            'dataEncryptionKey': null,
          };
        }
        return <String, dynamic>{'type': 'error'};
      };

      sync.testFetchSingleSessionOverride = (_) async => null;
      sync.testFetchMessagesOverride = (_, __, ___) async => <String, dynamic>{
        'messages': <dynamic>[],
      };

      // sendMessage triggers auto-restore for offline sessions
      try {
        await sync.sendMessage(sessionId, 'hello');
      } catch (_) {
        // sendMessage may throw after auto-restore, that's fine
      }

      expect(
        capturedSpawnParams,
        isNotNull,
        reason: 'Auto-restore should have triggered a spawn',
      );
      final envVars =
          capturedSpawnParams!['environmentVariables'] as Map<String, dynamic>?;
      expect(envVars, isNotNull);
      expect(
        envVars!['ANTHROPIC_BASE_URL'],
        contains('deepseek'),
        reason:
            'Auto-restore must use the session-specific '
            'profile (DeepSeek), not the global '
            'lastUsedProfile (OpenAI)',
      );
      expect(envVars.containsKey('OPENAI_BASE_URL'), isFalse);
    });

    test('auto-restore with no saved profile sends empty env vars', () async {
      final sessionId = 'auto-restore-noprofile-1';
      Map<String, dynamic>? capturedSpawnParams;

      // No profile saved for this session
      sync.testGetSpawnEnvVarsOverride = (_) async =>
          (envVars: <String, String>{}, profile: null);

      // Global profile is DeepSeek — should NOT be used
      await sync.applySettings({'lastUsedProfile': 'deepseek'});

      final now = DateTime.now().millisecondsSinceEpoch;
      sync.testSessions[sessionId] = Session(
        id: sessionId,
        seq: 1,
        createdAt: now - 60000,
        updatedAt: now - 60000,
        active: true,
        activeAt: now,
        metadataVersion: 1,
        agentStateVersion: 0,
        thinking: false,
        presence: 'offline',
        metadata: Metadata(
          host: '',
          machineId: 'machine-1',
          path: '/home/user/project',
          lifecycleState: 'archived',
        ),
      );

      sync.testMachines['machine-1'] = Machine(
        id: 'machine-1',
        seq: 1,
        createdAt: 0,
        updatedAt: 0,
        active: true,
        activeAt: now,
        metadataVersion: 0,
        daemonStateVersion: 0,
      );

      sync.testMachineRPCOverride = (machineId, method, params) async {
        if (method == 'spawn-happy-session') {
          capturedSpawnParams = params;
          return <String, dynamic>{
            'type': 'success',
            'sessionId': sessionId,
            'dataEncryptionKey': null,
          };
        }
        return <String, dynamic>{'type': 'error'};
      };

      sync.testFetchSingleSessionOverride = (_) async => null;
      sync.testFetchMessagesOverride = (_, __, ___) async => <String, dynamic>{
        'messages': <dynamic>[],
      };

      try {
        await sync.sendMessage(sessionId, 'hello');
      } catch (_) {
        // Expected
      }

      expect(capturedSpawnParams, isNotNull);
      // No saved profile → empty env vars → key omitted from
      // toJson entirely.
      final envVars =
          capturedSpawnParams!['environmentVariables'] as Map<String, dynamic>?;
      if (envVars != null) {
        expect(
          envVars.containsKey('ANTHROPIC_BASE_URL'),
          isFalse,
          reason:
              'Auto-restore with no saved profile must not '
              'fall back to global lastUsedProfile',
        );
        expect(envVars.containsKey('OPENAI_BASE_URL'), isFalse);
      }
    });
  });

  group('Profile permission mode propagation', () {
    late Sync sync;
    late _FakeEncryption encryption;

    setUp(() {
      sync = Sync();
      encryption = _FakeEncryption();
      sync.encryption = encryption;
      sync.testIsInitialized = true;
      sync.testSocketConnectedOverride = true;
      sync.testSocketSendOverride = (_, __) {};
      sync.testSessions.clear();
      sync.testClearSessionSpawnedAt();
      sync.testSettingsSnapshot = Settings();
      sync.testFetchMessagesOverride = (_, __, ___) async => <String, dynamic>{
        'messages': <dynamic>[],
      };
      _stubAllSyncs(sync);
    });

    tearDown(() {
      sync.testSocketConnectedOverride = null;
      sync.testSocketSendOverride = null;
      sync.testMachineRPCOverride = null;
      sync.testGetSpawnEnvVarsOverride = null;
      sync.testFetchMessagesOverride = null;
    });

    test('profile defaultPermissionMode is forwarded on spawn', () async {
      final sessionId = 'perm-mode-1';
      Map<String, dynamic>? capturedParams;
      sync.testMachineRPCOverride = (machineId, method, params) async {
        capturedParams = params;
        return <String, dynamic>{
          'type': 'success',
          'sessionId': sessionId,
          'dataEncryptionKey': null,
        };
      };

      final customProfile = AIBackendProfile(
        id: 'yolo-profile',
        name: 'YOLO',
        defaultPermissionMode: 'bypassPermissions',
      );

      await sync.applySettings({
        'profiles': [customProfile.toJson()],
        'lastUsedProfile': 'yolo-profile',
        'lastUsedPermissionMode': 'default',
      });

      await sync.createSession(
        agent: 'claude',
        machineId: 'machine-1',
        path: '/home/user/project',
      );

      expect(capturedParams, isNotNull);
      expect(
        capturedParams!['permissionMode'],
        'bypassPermissions',
        reason:
            'Profile defaultPermissionMode must override '
            'the global lastUsedPermissionMode',
      );
    });

    test(
      'falls back to global permission mode when profile has none',
      () async {
        final sessionId = 'perm-fallback-1';
        Map<String, dynamic>? capturedParams;
        sync.testMachineRPCOverride = (machineId, method, params) async {
          capturedParams = params;
          return <String, dynamic>{
            'type': 'success',
            'sessionId': sessionId,
            'dataEncryptionKey': null,
          };
        };

        await sync.applySettings({
          'lastUsedProfile': 'deepseek',
          'lastUsedPermissionMode': 'plan',
        });

        await sync.createSession(
          agent: 'claude',
          machineId: 'machine-1',
          path: '/home/user/project',
        );

        expect(capturedParams, isNotNull);
        // DeepSeek built-in has no defaultPermissionMode →
        // falls back to global
        expect(
          capturedParams!['permissionMode'],
          'plan',
          reason:
              'Must fall back to global permission mode '
              'when profile has no default',
        );
      },
    );
  });

  group('resolveProfile precedence', () {
    test('custom profile takes precedence over built-in', () {
      final custom = AIBackendProfile(
        id: 'deepseek',
        name: 'My DeepSeek Override',
        environmentVariables: [
          EnvironmentVariable(name: 'CUSTOM_VAR', value: 'custom-value'),
        ],
      );

      final result = resolveProfile('deepseek', [custom]);
      expect(result, isNotNull);
      expect(result!.name, 'My DeepSeek Override');
      expect(result.environmentVariables.length, 1);
      expect(result.environmentVariables.first.name, 'CUSTOM_VAR');
    });

    test('falls back to built-in when no custom match', () {
      final result = resolveProfile('deepseek', []);
      expect(result, isNotNull);
      expect(result!.name, 'DeepSeek (Chat)');
      expect(result.isBuiltIn, isTrue);
    });

    test('returns null for unknown profile ID', () {
      final result = resolveProfile('nonexistent', []);
      expect(result, isNull);
    });

    test('builtInProfiles returns all 8 profiles', () {
      expect(builtInProfiles.length, 8);
      final ids = builtInProfiles.map((p) => p.id).toSet();
      expect(
        ids,
        containsAll([
          'anthropic',
          'deepseek',
          'zai',
          'minimax',
          'xiaomi-mimo',
          'openrouter',
          'openai',
          'azure-openai',
        ]),
      );
    });
  });

  group('_getModelOverride always returns null', () {
    late Sync sync;

    setUp(() {
      sync = Sync();
      sync.testSettingsSnapshot = Settings();
    });

    test('returns null with no profile', () {
      expect(sync.testGetModelOverride(), isNull);
    });

    test('returns null with DeepSeek profile', () {
      final profile = getBuiltInProfile('deepseek');
      expect(sync.testGetModelOverride(profile: profile), isNull);
    });

    test('returns null with custom profile with model', () {
      final profile = AIBackendProfile(
        id: 'test',
        name: 'Test',
        anthropicConfig: AnthropicConfig(model: 'some-model'),
      );
      expect(sync.testGetModelOverride(profile: profile), isNull);
    });
  });

  group('Profile change on running session triggers respawn', () {
    late Sync sync;
    late _FakeEncryption encryption;

    setUp(() {
      sync = Sync();
      encryption = _FakeEncryption();
      sync.encryption = encryption;
      sync.testIsInitialized = true;
      sync.testSocketConnectedOverride = true;
      sync.testSocketSendOverride = (_, __) {};
      sync.testSessions.clear();
      sync.testMachines.clear();
      sync.testClearSessionSpawnedAt();
      sync.testSettingsSnapshot = Settings();
      sync.testFetchMessagesOverride = (_, __, ___) async => <String, dynamic>{
        'messages': <dynamic>[],
      };
      _stubAllSyncs(sync);
    });

    tearDown(() {
      sync.testSocketConnectedOverride = null;
      sync.testSocketSendOverride = null;
      sync.testMachineRPCOverride = null;
      sync.testGetSpawnEnvVarsOverride = null;
      sync.testFetchMessagesOverride = null;
      sync.testFetchSingleSessionOverride = null;
    });

    /// Marks [sessionId] as a healthy "online" session running on [machineId]
    /// at [path], with the given [spawnedProfileId] tracked as the profile the
    /// running daemon was spawned with. Mirrors the state of an active chat.
    void primeOnlineSession({
      required String sessionId,
      required String machineId,
      required String path,
      required String? spawnedProfileId,
    }) {
      final now = DateTime.now().millisecondsSinceEpoch;
      sync.testSessions[sessionId] = Session(
        id: sessionId,
        seq: 1,
        createdAt: now - 60000,
        updatedAt: now,
        active: true,
        activeAt: now,
        metadataVersion: 1,
        agentStateVersion: 0,
        thinking: false,
        presence: 'online',
        metadata: Metadata(
          host: '',
          machineId: machineId,
          path: path,
          lifecycleState: 'running',
          lifecycleStateSince: now,
        ),
      );
      sync.testMachines[machineId] = Machine(
        id: machineId,
        seq: 1,
        createdAt: 0,
        updatedAt: 0,
        active: true,
        activeAt: now,
        metadataVersion: 0,
        daemonStateVersion: 0,
      );
      sync.testLastEphemeralAt[sessionId] = now;
      sync.testSetSessionSpawnedProfile(sessionId, spawnedProfileId);
    }

    test('switching from custom profile to Default kills and respawns '
        'with empty env vars', () async {
      const sessionId = 'switch-to-default';
      Map<String, dynamic>? capturedSpawnParams;

      primeOnlineSession(
        sessionId: sessionId,
        machineId: 'machine-1',
        path: '/home/user/project',
        spawnedProfileId: 'deepseek',
      );

      // Simulate "user picked Default in the picker" — MMKV cleared,
      // so _getSpawnEnvVarsForSession resolves to empty env vars and a
      // null profile. Without the override, a real MMKV read would also
      // return null (no entry), which is what we want — but tests don't
      // have a fake MMKV plugin, so we override explicitly.
      sync.testGetSpawnEnvVarsOverride = (_) async =>
          (envVars: <String, String>{}, profile: null);

      sync.testMachineRPCOverride = (machineId, method, params) async {
        if (method == 'spawn-happy-session') {
          capturedSpawnParams = params;
          return <String, dynamic>{
            'type': 'success',
            'sessionId': sessionId,
            'dataEncryptionKey': null,
          };
        }
        return <String, dynamic>{'type': 'error'};
      };
      sync.testFetchSingleSessionOverride = (_) async => null;

      try {
        await sync.sendMessage(sessionId, 'hello');
      } catch (_) {
        // sendMessage may throw after the kill+respawn (REST POST not
        // mocked); the kill+respawn happens before that and is what we
        // are asserting here.
      }

      expect(
        capturedSpawnParams,
        isNotNull,
        reason:
            'Switching to Default on a running session must trigger '
            'a kill+respawn — sendMessage(profileId: null) should not '
            'silently keep the old profile alive.',
      );
      final envVars =
          capturedSpawnParams!['environmentVariables'] as Map<String, dynamic>?;
      if (envVars != null) {
        expect(
          envVars.containsKey('ANTHROPIC_BASE_URL'),
          isFalse,
          reason:
              'Respawn after switching to Default must drop the '
              'previous DeepSeek base URL',
        );
        expect(envVars.containsKey('ANTHROPIC_AUTH_TOKEN'), isFalse);
      }
    });

    test('selecting a profile on a running session with unknown spawn state '
        'kills and respawns with profile env vars', () async {
      const sessionId = 'unknown-spawn-select-profile';
      Map<String, dynamic>? capturedSpawnParams;

      primeOnlineSession(
        sessionId: sessionId,
        machineId: 'machine-1',
        path: '/home/user/project',
        spawnedProfileId: null,
      );
      sync.testSessionSpawnedProfile.remove(sessionId);

      final deepseek = getBuiltInProfile('deepseek')!;
      sync.testGetSpawnEnvVarsOverride = (_) async => (
        envVars: {
          for (final v in deepseek.environmentVariables) v.name: v.value,
        },
        profile: deepseek,
      );

      sync.testMachineRPCOverride = (machineId, method, params) async {
        if (method == 'spawn-happy-session') {
          capturedSpawnParams = params;
          return <String, dynamic>{
            'type': 'success',
            'sessionId': sessionId,
            'dataEncryptionKey': null,
          };
        }
        return <String, dynamic>{'type': 'success'};
      };
      sync.testFetchSingleSessionOverride = (_) async => null;

      try {
        await sync.sendMessage(sessionId, 'hello', profileId: 'deepseek');
      } catch (_) {
        // REST POST not mocked.
      }

      expect(
        capturedSpawnParams,
        isNotNull,
        reason:
            'A profile selected in the picker must restart a running '
            'session even when this app instance did not spawn it.',
      );
      final envVars =
          capturedSpawnParams!['environmentVariables'] as Map<String, dynamic>?;
      expect(envVars, isNotNull);
      expect(envVars!['ANTHROPIC_BASE_URL'], contains('deepseek'));
      expect(envVars['ANTHROPIC_AUTH_TOKEN'], isNotNull);
    });

    test('sendMessage with profileId=null does NOT kill session when '
        'the daemon was already spawned with no profile', () async {
      const sessionId = 'no-change-default-to-default';
      var spawnCalled = false;

      primeOnlineSession(
        sessionId: sessionId,
        machineId: 'machine-1',
        path: '/home/user/project',
        spawnedProfileId: null,
      );

      sync.testGetSpawnEnvVarsOverride = (_) async =>
          (envVars: <String, String>{}, profile: null);

      sync.testMachineRPCOverride = (machineId, method, params) async {
        if (method == 'spawn-happy-session') {
          spawnCalled = true;
        }
        return <String, dynamic>{'type': 'success', 'sessionId': sessionId};
      };

      try {
        await sync.sendMessage(sessionId, 'hello');
      } catch (_) {
        // REST POST not mocked.
      }

      expect(
        spawnCalled,
        isFalse,
        reason: 'A no-op send (Default → Default) must not respawn',
      );
    });
  });
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

void _stubAllSyncs(Sync instance, {Future<void> Function()? sessionsFn}) {
  try {
    instance.sessionsSync.dispose();
  } on Error {
    // Not initialized yet
  }
  instance.sessionsSync = InvalidateSync(sessionsFn ?? () async {});
  instance.settingsSync = InvalidateSync(() async {});
  instance.profileSync = InvalidateSync(() async {});
  instance.purchasesSync = InvalidateSync(() async {});
  instance.machinesSync = InvalidateSync(() async {});
  instance.pushTokenSync = InvalidateSync(() async {});
  instance.nativeUpdateSync = InvalidateSync(() async {});
  instance.artifactsSync = InvalidateSync(() async {});
  instance.friendsSync = InvalidateSync(() async {});
  instance.friendRequestsSync = InvalidateSync(() async {});
  instance.feedSync = InvalidateSync(() async {});
  instance.todosSync = InvalidateSync(() async {});
  instance.sessionGitStatusSync = InvalidateSync(() async {});
  instance.messagesSync.clear();
}

// ---------------------------------------------------------------------------
// Fake encryption
// ---------------------------------------------------------------------------

class _FakeEncryption implements Encryption {
  final Map<String, _FakeSessionEncryption> _sessions = {};

  @override
  SessionEncryption? getSessionEncryption(String sessionId) {
    return _sessions.putIfAbsent(
      sessionId,
      () => _FakeSessionEncryption(sessionId: sessionId),
    );
  }

  @override
  Future<Uint8List?> decryptEncryptionKey(String encryptedKey) async {
    return Uint8List.fromList(utf8.encode('decrypted-$encryptedKey'));
  }

  @override
  Future<void> initializeSessions(Map<String, Uint8List?> sessionKeys) async {}

  @override
  String generateId() => 'test-local-${DateTime.now().microsecondsSinceEpoch}';

  @override
  void removeSessionEncryption(String sessionId) {
    _sessions.remove(sessionId);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeSessionEncryption extends SessionEncryption {
  _FakeSessionEncryption({required String sessionId})
    : super(
        sessionId: sessionId,
        encryptor: _FakeEncryptor(),
        decryptor: _FakeEncryptor(),
        cache: EncryptionCache(),
      );
}

class _FakeEncryptor implements Encryptor {
  @override
  Future<List<Uint8List>> encrypt(List<dynamic> data) async {
    return data
        .map((item) => item is Uint8List ? item : Uint8List.fromList([]))
        .toList();
  }

  @override
  Future<List<dynamic>> decrypt(List<Uint8List> data) async {
    return data.toList();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
