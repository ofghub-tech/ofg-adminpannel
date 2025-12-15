import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart';
import '../constants.dart';
import '../models/video_model.dart';

class AppwriteService {
  Client client = Client();
  late Databases databases;
  late Account account;

  AppwriteService() {
    client
        .setEndpoint(AppConstants.endpoint)
        .setProject(AppConstants.projectId);
    databases = Databases(client);
    account = Account(client);
  }

  // --- AUTH METHODS ---

  // 1. Get Current User (The missing function!)
  Future<User?> getCurrentUser() async {
    try {
      return await account.get();
    } catch (e) {
      return null; // No active session
    }
  }

  // 2. Smart Login (Handles "Session already active" error)
  Future<bool> login(String email, String password) async {
    try {
      // Attempt to create a session
      await account.createEmailPasswordSession(email: email, password: password);
      return true;
    } on AppwriteException catch (e) {
      // If session exists (Code 401), delete it and try again to verify password
      if (e.code == 401 || (e.message != null && e.message!.contains('active'))) {
        print("Session exists. Re-authenticating...");
        try {
          await account.deleteSession(sessionId: 'current');
          await account.createEmailPasswordSession(email: email, password: password);
          return true;
        } catch (ex) {
          print("Re-login failed: $ex");
          return false;
        }
      }
      print("Login Failed: ${e.message}");
      return false;
    } catch (e) {
      print("Unknown Error: $e");
      return false;
    }
  }

  // 3. Logout
  Future<void> logout() async {
    try {
      await account.deleteSession(sessionId: 'current');
    } catch (e) {
      // Ignore if already logged out
    }
  }

  // --- DATABASE METHODS ---

  Future<List<VideoModel>> getVideos() async {
    try {
      DocumentList result = await databases.listDocuments(
        databaseId: AppConstants.databaseId,
        collectionId: AppConstants.collectionId,
        queries: [Query.orderDesc('\$createdAt')] 
      );
      return result.documents.map((doc) => VideoModel.fromJson(doc.data)).toList();
    } catch (e) {
      print("Fetch Error: $e");
      return [];
    }
  }

  Future<void> updateStatus(String docId, Map<String, dynamic> data) async {
    await databases.updateDocument(
      databaseId: AppConstants.databaseId,
      collectionId: AppConstants.collectionId,
      documentId: docId,
      data: data,
    );
  }

  Future<void> deleteDocument(String docId) async {
    await databases.deleteDocument(
      databaseId: AppConstants.databaseId,
      collectionId: AppConstants.collectionId,
      documentId: docId,
    );
  }
}