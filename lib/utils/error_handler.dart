import 'package:flutter/material.dart';

class ErrorHandler {
  /// Get user-friendly error message based on error type
  static String getErrorMessage(dynamic error) {
    final errorString = error.toString().toLowerCase();
    
    // Check for server errors (500, 502, 503, 504)
    if (errorString.contains('500') || 
        errorString.contains('internal server error') ||
        errorString.contains('502') ||
        errorString.contains('503') ||
        errorString.contains('504') ||
        errorString.contains('cloudflare')) {
      return 'A server error occurred. Please try again in a few moments or contact the system administrator.';
    }
    
    // Check for network errors
    if (errorString.contains('network') || 
        errorString.contains('connection') ||
        errorString.contains('timeout') ||
        errorString.contains('socket')) {
      return 'Unable to connect to the server. Please check your internet connection.';
    }
    
    // Check for PostgrestException by checking error string
    if (errorString.contains('postgrestexception') || errorString.contains('postgrest')) {
      // Check for error codes in the string
      if (errorString.contains('code: 500') || 
          errorString.contains('code: 502') || 
          errorString.contains('code: 503') || 
          errorString.contains('code: 504')) {
        return 'A server error occurred. Please try again in a few moments or contact the system administrator.';
      }
      
      // Not found
      if (errorString.contains('pgrst116') || errorString.contains('code: 404')) {
        return 'Data not found.';
      }
      
      // Unauthorized
      if (errorString.contains('pgrst301') || errorString.contains('code: 401')) {
        return 'You do not have permission to access this data.';
      }
      
      // Forbidden
      if (errorString.contains('code: 403')) {
        return 'Access denied.';
      }
    }
    
    // Default error message
    return error.toString().replaceAll('Exception: ', '');
  }
  
  /// Show error snackbar with user-friendly message
  static void showError(BuildContext? context, dynamic error) {
    if (context == null) return;
    
    final errorMessage = getErrorMessage(error);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          errorMessage,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'OK',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }
  
  /// Check if error is a server error
  static bool isServerError(dynamic error) {
    final errorString = error.toString().toLowerCase();
    
    if (errorString.contains('500') || 
        errorString.contains('internal server error') ||
        errorString.contains('502') ||
        errorString.contains('503') ||
        errorString.contains('504') ||
        errorString.contains('cloudflare')) {
      return true;
    }
    
    // Check for PostgrestException error codes in string
    if (errorString.contains('postgrestexception') || errorString.contains('postgrest')) {
      return errorString.contains('code: 500') || 
             errorString.contains('code: 502') || 
             errorString.contains('code: 503') || 
             errorString.contains('code: 504');
    }
    
    return false;
  }
}

