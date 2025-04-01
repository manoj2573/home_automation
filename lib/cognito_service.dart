import 'package:amazon_cognito_identity_dart_2/cognito.dart';
import 'package:http/http.dart' as http;

class CognitoService {
  final String userPoolId;
  final String clientId;
  late CognitoUserPool userPool;

  CognitoService({required this.userPoolId, required this.clientId}) {
    userPool = CognitoUserPool(userPoolId, clientId);
  }

  Future<CognitoUserSession?> login(String email, String password) async {
    final cognitoUser = CognitoUser(email, userPool);
    final authDetails = AuthenticationDetails(
      username: email,
      password: password,
    );

    try {
      return await cognitoUser.authenticateUser(authDetails);
    } catch (e) {
      throw e;
    }
  }

  Future<void> register(String email, String password) async {
    final userAttributes = [AttributeArg(name: 'email', value: email)];

    try {
      await userPool.signUp(email, password, userAttributes: userAttributes);
    } catch (e) {
      throw e;
    }
  }

  Future<void> resetPassword(String email) async {
    final cognitoUser = CognitoUser(email, userPool);
    try {
      await cognitoUser.forgotPassword();
    } catch (e) {
      throw e;
    }
  }

  Future<void> logout() async {
    final cognitoUser = await userPool.getCurrentUser();
    if (cognitoUser != null) {
      await cognitoUser.signOut();
    }
  }

  Future<CognitoUser?> getCurrentUser() async {
    return await userPool.getCurrentUser();
  }
}
