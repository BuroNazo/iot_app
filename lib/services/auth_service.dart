import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // Mevcut kullanıcı
  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Email + Şifre ile Kayıt
  Future<String?> register(String email, String password) async {
    try {
      await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      return null; // başarılı
    } on FirebaseAuthException catch (e) {
      return _authErrorMessage(e.code);
    }
  }

  // Email + Şifre ile Giriş
  Future<String?> signInWithEmail(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return null;
    } on FirebaseAuthException catch (e) {
      return _authErrorMessage(e.code);
    }
  }

  // Google ile Giriş
  Future<String?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return "Giris iptal edildi.";

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      await _auth.signInWithCredential(credential);
      return null;
    } catch (e) {
      return "Google girisi basarisiz: $e";
    }
  }

  // Çıkış
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  // Hata mesajları
  String _authErrorMessage(String code) {
    switch (code) {
      case 'email-already-in-use':
        return "Bu email zaten kayitli.";
      case 'invalid-email':
        return "Gecersiz email adresi.";
      case 'weak-password':
        return "Sifre en az 6 karakter olmali.";
      case 'user-not-found':
        return "Kullanici bulunamadi.";
      case 'wrong-password':
        return "Yanlis sifre.";
      case 'too-many-requests':
        return "Cok fazla deneme. Lutfen bekleyin.";
      default:
        return "Bir hata olustu: $code";
    }
  }
}
