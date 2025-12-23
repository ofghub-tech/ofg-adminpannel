import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConstants {
  // --- Appwrite Configuration ---
  static String get appwriteEndpoint => dotenv.env['APPWRITE_ENDPOINT'] ?? 'https://cloud.appwrite.io/v1';
  static String get appwriteProjectId => dotenv.env['APPWRITE_PROJECT_ID'] ?? '';
  static String get appwriteDatabaseId => dotenv.env['APPWRITE_DATABASE_ID'] ?? '';
  
  // FIXED: Matches the variable name in your .env file
  static String get appwriteCollectionId => dotenv.env['APPWRITE_COLLECTION_ID_VIDEOS'] ?? 'videos';

  // --- Cloudflare R2 Configuration ---
  static String get r2EndpointUrl => dotenv.env['R2_ENDPOINT_URL'] ?? '';
  
  // FIXED: Matches the variable name in your .env file
  static String get r2BucketName => dotenv.env['R2_BUCKET_ID'] ?? '';
  
  static String get r2AccessKey => dotenv.env['R2_ACCESS_KEY_ID'] ?? '';
  static String get r2SecretKey => dotenv.env['R2_SECRET_ACCESS_KEY'] ?? '';
}