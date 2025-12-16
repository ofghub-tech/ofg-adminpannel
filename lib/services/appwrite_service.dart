import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart';
import '../constants.dart';
import '../models/video_model.dart'; // <--- FIX: Moved to top

class AppwriteService {
  late Client client;
  late Account account;
  late Databases databases;

  AppwriteService() {
    client = Client()
        .setEndpoint(AppConstants.appwriteEndpoint)
        .setProject(AppConstants.appwriteProjectId);
    
    account = Account(client);
    databases = Databases(client);
  }

  // --- AUTH METHODS ---

  Future<User?> getCurrentUser() async {
    try {
      return await account.get();
    } catch (e) {
      return null;
    }
  }

  Future<String?> login(String email, String password) async {
    try {
      // 1. Check if a session already exists
      try {
        await account.getSession(sessionId: 'current');
        return null; // Already logged in, consider success
      } catch (_) {
        // No active session, proceed to create one
      }

      // 2. Create new session
      await account.createEmailPasswordSession(
        email: email, 
        password: password
      );
      return null; // Success

    } on AppwriteException catch (e) {
      // 3. Handle known Appwrite errors
      if (e.code == 429) {
        print("Rate Limit Hit: ${e.message}");
        return "Too many login attempts. Please wait 15-60 minutes.";
      } else if (e.code == 401) {
        return "Invalid email or password.";
      } else {
        return "Login Error: ${e.message}";
      }
    } catch (e) {
      return "An unexpected error occurred: $e";
    }
  }

  Future<void> logout() async {
    try {
      await account.deleteSession(sessionId: 'current');
    } catch (e) {
      print("Logout error: $e");
    }
  }

  // --- DATABASE METHODS ---

  Future<List<VideoModel>> getVideos() async {
    try {
      DocumentList result = await databases.listDocuments(
        databaseId: AppConstants.appwriteDatabaseId,
        collectionId: AppConstants.appwriteCollectionId,
      );

      return result.documents.map((doc) => VideoModel.fromJson(doc.data)).toList();
    } catch (e) {
      print("Error fetching videos: $e");
      return [];
    }
  }

  Future<void> updateStatus(String documentId, Map<String, dynamic> data) async {
    try {
      await databases.updateDocument(
        databaseId: AppConstants.appwriteDatabaseId,
        collectionId: AppConstants.appwriteCollectionId,
        documentId: documentId,
        data: data,
      );
    } catch (e) {
      print("Error updating status: $e");
    }
  }

  Future<void> deleteDocument(String documentId) async {
    try {
      await databases.deleteDocument(
        databaseId: AppConstants.appwriteDatabaseId,
        collectionId: AppConstants.appwriteCollectionId,
        documentId: documentId,
      );
    } catch (e) {
      print("Error deleting document: $e");
    }
  }
}