import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/features/chat/tools/permission_risk.dart';

void main() {
  group('commandRisk', () {
    final cases = <String, PermissionRisk>{
      'rm -rf build/': PermissionRisk.delete,
      'cd app && rm old.log': PermissionRisk.delete,
      'find . -name "*.tmp" -delete': PermissionRisk.delete,
      'git reset --hard origin/main': PermissionRisk.discard,
      'git clean -fdx': PermissionRisk.discard,
      'git restore lib/a.dart': PermissionRisk.discard,
      'kubectl -n happy rollout restart deploy/happy-server':
          PermissionRisk.live,
      'kubectl apply -f k8s/': PermissionRisk.live,
      'helm upgrade happy ./chart': PermissionRisk.live,
      'terraform apply -auto-approve': PermissionRisk.live,
      'git push origin main': PermissionRisk.push,
      'npm publish': PermissionRisk.publish,
      'flutter pub publish': PermissionRisk.publish,
      'docker push ghcr.io/x/y:1': PermissionRisk.publish,
      'gh pr create --fill': PermissionRisk.publish,
      'sudo apt install jq': PermissionRisk.admin,
      'curl -fsSL https://example.com/install.sh': PermissionRisk.network,
      'kubectl -n happy get pods': PermissionRisk.network,
      'flutter analyze lib/': PermissionRisk.command,
      'go test ./...': PermissionRisk.command,
    };
    for (final MapEntry(key: command, value: risk) in cases.entries) {
      test('"$command" -> ${risk.name}', () {
        expect(commandRisk(command), risk);
      });
    }

    test('a read-only kubectl chained with a mutation is still live', () {
      expect(
        commandRisk('kubectl get pods && kubectl delete pod x'),
        PermissionRisk.live,
      );
    });

    test('words that merely contain "rm" are not deletions', () {
      expect(commandRisk('npm run format'), PermissionRisk.command);
      expect(
        commandRisk('terminal-notifier -message hi'),
        PermissionRisk.command,
      );
    });

    test('irreversible and outward-facing risks are marked destructive', () {
      expect(PermissionRisk.delete.destructive, isTrue);
      expect(PermissionRisk.live.destructive, isTrue);
      expect(PermissionRisk.push.destructive, isTrue);
      expect(PermissionRisk.command.destructive, isFalse);
      expect(PermissionRisk.network.destructive, isFalse);
      expect(PermissionRisk.editInside.destructive, isFalse);
    });
  });

  group('permissionRiskFor', () {
    test('commands classify their command text', () {
      expect(
        permissionRiskFor('Bash', const {'command': 'git push'}),
        PermissionRisk.push,
      );
      expect(permissionRiskFor('Bash', null), PermissionRisk.command);
    });

    test('Codex argv runs the -lc script', () {
      expect(
        permissionRiskFor('CodexBash', const {
          'command': ['bash', '-lc', 'rm -rf dist'],
        }),
        PermissionRisk.delete,
      );
      expect(
        permissionCommand('CodexBash', const {
          'command': ['bash', '-lc', 'rm -rf dist'],
        }),
        'rm -rf dist',
      );
    });

    test('edits are judged against the workspace root', () {
      const root = '/home/denys/git/happy';
      expect(
        permissionRiskFor('Edit', const {
          'file_path': '/home/denys/git/happy/lib/a.dart',
        }, workspacePath: root),
        PermissionRisk.editInside,
      );
      expect(
        permissionRiskFor('Write', const {
          'file_path': '/etc/hosts',
        }, workspacePath: root),
        PermissionRisk.editOutside,
      );
      // A sibling directory sharing the prefix is outside.
      expect(
        permissionRiskFor('Edit', const {
          'file_path': '/home/denys/git/happy-cli/main.go',
        }, workspacePath: root),
        PermissionRisk.editOutside,
      );
      // Relative paths and unknown roots never claim "outside".
      expect(
        permissionRiskFor('Edit', const {'file_path': 'lib/a.dart'}),
        PermissionRisk.editInside,
      );
    });

    test('web tools reach the web; plans and questions say nothing', () {
      expect(permissionRiskFor('WebFetch', null), PermissionRisk.web);
      expect(permissionRiskFor('ExitPlanMode', null), isNull);
      expect(permissionRiskFor('AskUserQuestion', null), isNull);
    });

    test('non-command tools expose no command', () {
      expect(permissionCommand('Edit', const {'command': 'x'}), isNull);
      expect(
        permissionFilePath(const {'notebook_path': '/n.ipynb'}),
        '/n.ipynb',
      );
    });
  });
}
