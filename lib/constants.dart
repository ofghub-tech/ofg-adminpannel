import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConstants {
  // --- Appwrite Configuration ---
  static String get appwriteEndpoint => dotenv.env['APPWRITE_ENDPOINT'] ?? 'https://cloud.appwrite.io/v1';
  static String get appwriteProjectId => dotenv.env['APPWRITE_PROJECT_ID'] ?? '';
  static String get appwriteDatabaseId => dotenv.env['APPWRITE_DATABASE_ID'] ?? '';
  static String get appwriteCollectionId => dotenv.env['APPWRITE_COLLECTION_ID'] ?? '';

  // --- Cloudflare R2 Configuration ---
  static String get r2EndpointUrl => dotenv.env['R2_ENDPOINT_URL'] ?? '';
  static String get r2BucketName => dotenv.env['R2_BUCKET_NAME'] ?? '';
  static String get r2AccessKey => dotenv.env['R2_ACCESS_KEY'] ?? '';
  static String get r2SecretKey => dotenv.env['R2_SECRET_KEY'] ?? '';
}