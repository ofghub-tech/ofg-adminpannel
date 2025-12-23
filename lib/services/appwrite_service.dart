import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart';
import '../constants.dart';
import '../models/video_model.dart';

class AppwriteService {
  late Client client;
  late Account account;
  late Databases databases;
  late Realtime realtime;

  AppwriteService() {
    client = Client()
        .setEndpoint(AppConstants.appwriteEndpoint)
        .setProject(AppConstants.appwriteProjectId);
    
    account = Account(client);
    databases = Databases(client);
    realtime = Realtime(client);
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
      try {
        await account.getSession(sessionId: 'current');
        return null; 
      } catch (_) {}

      await account.createEmailPasswordSession(
        email: email, 
        password: password
      );
      return null;
    } on AppwriteException catch (e) {
      if (e.code == 429) return "Too many attempts. Wait 15m.";
      if (e.code == 401) return "Invalid credentials.";
      return "Login Error: ${e.message}";
    } catch (e) {
      return "Error: $e";
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

  Future<List<VideoModel>> getVideos({String? searchTerm}) async {
    try {
      List<String> queries = [
        Query.limit(100),              
        Query.orderDesc('\$createdAt'), 
      ];

      if (searchTerm != null && searchTerm.isNotEmpty) {
        queries.add(Query.search('title', searchTerm));
      } 
      // FIXED: Removed the 'else' block that forced 'adminStatus == pending'.
      // Now it fetches ALL videos, allowing the tabs to sort them locally.

      DocumentList result = await databases.listDocuments(
        databaseId: AppConstants.appwriteDatabaseId,
        collectionId: AppConstants.appwriteCollectionId,
        queries: queries,
      );

      return result.documents.map((doc) => VideoModel.fromJson(doc.data)).toList();
    } catch (e) {
      print("Error fetching videos: $e");
      return [];
    }
  }

  Future<bool> updateStatus(String documentId, Map<String, dynamic> data) async {
    try {
      await databases.updateDocument(
        databaseId: AppConstants.appwriteDatabaseId,
        collectionId: AppConstants.appwriteCollectionId,
        documentId: documentId,
        data: data,
      );
      return true;
    } catch (e) {
      print("Error updating status: $e");
      return false;
    }
  }

  Future<bool> deleteDocument(String documentId) async {
    try {
      await databases.deleteDocument(
        databaseId: AppConstants.appwriteDatabaseId,
        collectionId: AppConstants.appwriteCollectionId,
        documentId: documentId,
      );
      return true;
    } catch (e) {
      print("Error deleting document: $e");
      return false;
    }
  }

  // --- REALTIME ---
  RealtimeSubscription subscribeToVideos() {
    return realtime.subscribe([
      'databases.${AppConstants.appwriteDatabaseId}.collections.${AppConstants.appwriteCollectionId}.documents'
    ]);
  }
}