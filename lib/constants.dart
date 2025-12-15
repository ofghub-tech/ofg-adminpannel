import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConstants {
  // --- APPWRITE CONFIG ---
  static String get endpoint => dotenv.env['APPWRITE_ENDPOINT'] ?? '';
  static String get projectId => dotenv.env['APPWRITE_PROJECT_ID'] ?? '';
  static String get databaseId => dotenv.env['APPWRITE_DATABASE_ID'] ?? '';
  static String get collectionId => dotenv.env['APPWRITE_COLLECTION_ID'] ?? 'videos';

  // --- CLOUDFLARE R2 CONFIG ---
  static String get r2AccountId => dotenv.env['R2_ACCOUNT_ID'] ?? '';
  static String get r2AccessKey => dotenv.env['R2_ACCESS_KEY'] ?? '';
  static String get r2SecretKey => dotenv.env['R2_SECRET_KEY'] ?? '';
  static String get r2BucketName => dotenv.env['R2_BUCKET_ID'] ?? '';
  static String get r2EndpointUrl => dotenv.env['R2_ENDPOINT_URL'] ?? '';
}