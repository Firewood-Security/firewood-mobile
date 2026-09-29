// test/csv_import_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:firewood/services/csv_import_service.dart';

void main() {
  final csvService = CsvImportService();

  group('CsvImportService Parsing Tests', () {
    test('parses Chrome password export CSV with headers', () {
      const csv = '''name,url,username,password,note
GitHub,https://github.com,octocat,gh_secret123,Developer account
Google,https://accounts.google.com,test@gmail.com,goog_pass456,Personal mail
''';

      final items = csvService.parseCsv(csv);
      expect(items.length, 2);

      expect(items[0].title, 'GitHub');
      expect(items[0].fields['username'], 'octocat');
      expect(items[0].fields['password'], 'gh_secret123');
      expect(items[0].fields['url'], 'https://github.com');
      expect(items[0].fields['notes'], 'Developer account');
      expect(items[0].type, 'login');

      expect(items[1].title, 'Google');
      expect(items[1].fields['username'], 'test@gmail.com');
      expect(items[1].fields['password'], 'goog_pass456');
    });

    test('parses Bitwarden export with folders and types', () {
      const csv =
          '''folder,favorite,type,name,notes,fields,reprompt,login_uri,login_username,login_password,login_totp
Work,1,login,Slack,Work workspace,,,https://slack.com,worker@company.com,SlackPass123!,JBSWY3DPEHPK3PXP
Finance,,card,Chase Sapphire,Primary card,,,,"John Doe","4111222233334444","12/28","123"
''';

      final items = csvService.parseCsv(csv);
      expect(items.length, 2);

      expect(items[0].title, 'Slack');
      expect(items[0].type, 'login');
      expect(items[0].fields['bundle'], 'Work');
      expect(items[0].fields['username'], 'worker@company.com');
      expect(items[0].fields['totp_secret'], 'JBSWY3DPEHPK3PXP');

      expect(items[1].title, 'Chase Sapphire');
      expect(items[1].type, 'card');
      expect(items[1].fields['bundle'], 'Finance');
    });

    test('overrides bundle when targetBundle is specified', () {
      const csv = '''name,username,password,folder
AWS Root,admin@cloud.com,AwsSecret123!,OldFolder
Stripe,api@stripe.com,StripeSecret456!,AnotherFolder
''';

      final items = csvService.parseCsv(csv, targetBundle: 'Infrastructure');
      expect(items.length, 2);
      expect(items[0].fields['bundle'], 'Infrastructure');
      expect(items[1].fields['bundle'], 'Infrastructure');
    });

    test('handles escaped quotes and embedded commas correctly', () {
      const csv = '''title,username,password,notes
"Company, Inc.","user@company.com","p@""ss,word","Notes with ""quotes"" and , commas"
''';

      final items = csvService.parseCsv(csv);
      expect(items.length, 1);
      expect(items[0].title, 'Company, Inc.');
      expect(items[0].fields['username'], 'user@company.com');
      expect(items[0].fields['password'], 'p@"ss,word');
      expect(items[0].fields['notes'], 'Notes with "quotes" and , commas');
    });

    test('handles multiline notes within quotes', () {
      const csv = '''title,username,password,notes
Server SSH,root,toor,"Line 1
Line 2
Line 3"
Database,postgres,dbpass,"Host: 10.0.0.1"
''';

      final items = csvService.parseCsv(csv);
      expect(items.length, 2);
      expect(items[0].title, 'Server SSH');
      expect(items[0].fields['notes'], 'Line 1\nLine 2\nLine 3');
      expect(items[1].title, 'Database');
    });
  });
}
