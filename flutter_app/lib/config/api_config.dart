class ApiConfig {
  // For local development on Android Emulator:
  // - 10.0.2.2 points to your computer's localhost
  // For iOS Simulator, Web, or Windows:
  // - use 'http://localhost:8000'
  // static const String baseUrl = 'http://10.0.2.2:8000';

  // Production Railway backend — uncomment when deploying:
  static const String baseUrl = 'https://mimbackend-834223221174.asia-south1.run.app';

  static String get wsUrl => baseUrl
      .replaceFirst('https://', 'wss://')
      .replaceFirst('http://', 'ws://');

  // Must match the GOOGLE_CLIENT_ID Railway env var on the backend.
  // Same client ID the website's AuthContext.jsx uses — both must stay in sync.
  static const String googleServerClientId =
      '610696728606-hjv0463opi1e5umn1nas2e3589ss9dqv.apps.googleusercontent.com';
}
