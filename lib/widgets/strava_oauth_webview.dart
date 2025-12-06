import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'dart:async';

class StravaOAuthWebView extends StatefulWidget {
  final String authorizationUrl;
  final String redirectUri;
  final Function(String code) onCodeReceived;
  final Function(String error) onError;

  const StravaOAuthWebView({
    super.key,
    required this.authorizationUrl,
    required this.redirectUri,
    required this.onCodeReceived,
    required this.onError,
  });

  @override
  State<StravaOAuthWebView> createState() => _StravaOAuthWebViewState();
}

class _StravaOAuthWebViewState extends State<StravaOAuthWebView> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _codeProcessed = false; // Flag to prevent double processing
  bool _logoutCompleted = false; // Flag to track if logout page has loaded
  int _authorizationRetryCount = 0; // Track retry attempts for authorization URL
  static const int _maxRetries = 3; // Maximum retry attempts

  @override
  void initState() {
    super.initState();
    
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      // Set User-Agent to Chrome to avoid Google OAuth block
      ..setUserAgent('Mozilla/5.0 (Linux; Android 10; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.120 Mobile Safari/537.36')
      // Clear all cookies and cache before loading Strava login to force re-authentication
      ..clearCache()
      ..clearLocalStorage()
      // Add JavaScript channel to detect redirects
      ..addJavaScriptChannel(
        'FlutterRedirect',
        onMessageReceived: (JavaScriptMessage message) {
          final url = message.message;
          print('📨 JavaScript message received: $url');
          
          // Check if this is an error message
          if (url.startsWith('ERROR:')) {
            final errorUrl = url.substring(6); // Remove 'ERROR:' prefix
            print('❌ STRAVA ERROR PAGE DETECTED!');
            print('Error URL: $errorUrl');
            print('Retry count: $_authorizationRetryCount');
            print('');
            
            // If this happens after logout and retry count is low, try to retry
            if (_logoutCompleted && _authorizationRetryCount < _maxRetries) {
              _authorizationRetryCount++;
              print('🔄 Retrying authorization (attempt $_authorizationRetryCount/$_maxRetries)...');
              print('Clearing cookies and reloading authorization URL...');
              
              // Clear cookies again and retry
              _clearStravaCookies().then((_) {
                Future.delayed(const Duration(seconds: 2), () {
                  if (mounted && !_codeProcessed) {
                    print('Retrying: Loading authorization URL...');
                    _controller.loadRequest(Uri.parse(widget.authorizationUrl));
                  }
                });
              });
              return;
            }
            
            print('🔴 MASALAH: Strava menampilkan error page!');
            print('Kemungkinan penyebab:');
            print('  1. Authorization Callback Domain belum terdaftar di Strava');
            print('  2. Redirect URI tidak sesuai dengan Strava settings');
            print('  3. Client ID atau Client Secret salah');
            print('  4. Session Strava masih aktif dan menyebabkan konflik');
            print('');
            print('✅ SOLUSI:');
            print('  1. Buka: https://www.strava.com/settings/api');
            print('  2. Edit aplikasi Anda');
            print('  3. Di "Authorization Callback Domain", tambahkan: 127.0.0.1');
            print('  4. Pastikan tidak ada spasi atau karakter tambahan');
            print('  5. Simpan perubahan');
            print('  6. Coba login lagi');
            print('');
            print('💡 TIP: Jika error terjadi setelah logout, coba:');
            print('  - Tutup aplikasi dan buka lagi');
            print('  - Atau tunggu beberapa detik sebelum login lagi');
            
            // Show error dialog to user
            if (mounted) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Strava Authorization Error'),
                    content: Text(
                      'Strava menampilkan error page.\n\n'
                      'Jika error terjadi setelah logout:\n'
                      '• Tutup aplikasi dan buka lagi\n'
                      '• Atau tunggu beberapa detik sebelum login lagi\n\n'
                      'Pastikan "Authorization Callback Domain" di Strava API settings sudah diisi dengan: 127.0.0.1\n\n'
                      'Buka: https://www.strava.com/settings/api'
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('OK'),
                      ),
                    ],
                  ),
                );
              });
            }
            return;
          }
          
          if (!_codeProcessed && (url.contains('127.0.0.1') || url.contains('localhost'))) {
            _handleRedirect(url);
          }
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (NavigationRequest request) {
            final url = request.url;
            
            print('=== NAVIGATION REQUEST ===');
            print('URL: $url');
            print('Code processed: $_codeProcessed');
            
            // IMPORTANT: Only intercept redirect to http://127.0.0.1 (Strava final redirect)
            // DO NOT intercept Google OAuth redirects inside Strava (strava.com/o_auth/google)
            // DO NOT intercept Strava dashboard (strava.com/dashboard)
            // We need to wait for Strava to complete Google OAuth and redirect to our app
            if (!_codeProcessed) {
              // Check if this is the final redirect with authorization code
              if (url.startsWith('http://127.0.0.1') || url.startsWith('http://localhost')) {
                print('✅ INTERCEPTING Strava final redirect: $url');
                _handleRedirect(url);
                return NavigationDecision.prevent; // Prevent navigation to localhost
              }
              
              // Check if URL contains code parameter (might be in different format)
              if (url.contains('code=') && (url.contains('127.0.0.1') || url.contains('localhost'))) {
                print('✅ INTERCEPTING URL with code parameter: $url');
                _handleRedirect(url);
                return NavigationDecision.prevent;
              }
              
              // Prevent navigation to Strava dashboard or "Getting Started" - user should not see it
              if (url.contains('strava.com/dashboard') || 
                  url.contains('strava.com/athlete') ||
                  url.contains('strava.com/getting-started') ||
                  url.contains('strava.com/onboarding')) {
                print('⚠️ Blocking navigation to Strava page - waiting for redirect...');
                print('URL: $url');
                // Don't prevent, but log it - Strava should redirect to our app
                // If it doesn't redirect, we might need to handle this differently
              }
              
              // DO NOT extract code from intermediate redirects
              // Only extract from final redirect to localhost
              // This prevents capturing Google OAuth codes
            }
            
            // Allow navigation to Strava authorization, login, and Google OAuth pages
            print('Allowing navigation to: $url');
            return NavigationDecision.navigate;
          },
          onPageStarted: (String url) {
            setState(() {
              _isLoading = true;
            });
            
            print('=== PAGE STARTED ===');
            print('URL: $url');
            print('Code processed: $_codeProcessed');
            
            // Also check on page started as backup (only for final Strava redirect)
            if (!_codeProcessed) {
              if (url.startsWith('http://127.0.0.1') || url.startsWith('http://localhost')) {
                print('✅ Page started with Strava redirect URL: $url');
                _handleRedirect(url);
              } else if (url.contains('code=') && (url.contains('127.0.0.1') || url.contains('localhost'))) {
                print('✅ Page started with code parameter: $url');
                _handleRedirect(url);
              } else if (url.contains('strava.com/oauth/authorize') && url.contains('login')) {
                // If we're back at login page after authorization attempt, something went wrong
                print('⚠️ WARNING: Back at Strava login page after authorization attempt!');
                print('URL: $url');
                print('This might mean:');
                print('  1. Authorization was denied');
                print('  2. Redirect URI tidak sesuai dengan Strava settings');
                print('  3. Strava tidak melakukan redirect ke ${widget.redirectUri}');
                print('');
                print('🔴 ACTION REQUIRED:');
                print('Please check Strava API settings:');
                print('  1. Go to: https://www.strava.com/settings/api');
                print('  2. Edit your application');
                print('  3. In "Authorization Callback Domain", add: 127.0.0.1');
                print('  4. Make sure it matches redirect_uri in code: http://127.0.0.1');
                print('');
                // Check if there's an error in URL
                if (url.contains('error=')) {
                  final errorMatch = RegExp(r'[?&]error=([^&]+)').firstMatch(url);
                  if (errorMatch != null) {
                    final error = Uri.decodeComponent(errorMatch.group(1)!);
                    print('Error from URL: $error');
                    widget.onError('Authorization failed: $error');
                    if (mounted) {
                      Navigator.of(context).pop();
                    }
                    return;
                  }
                }
              } else if (url.contains('strava.com/dashboard') || 
                         url.contains('strava.com/athlete') ||
                         url.contains('strava.com/getting-started') ||
                         url.contains('strava.com/onboarding')) {
                print('⚠️ WARNING: Strava redirected to internal page instead of our app!');
                print('URL: $url');
                print('This might mean authorization was approved but redirect failed');
                // Check if code is in URL
                if (url.contains('code=')) {
                  print('Found code in URL, trying to extract...');
                  _handleRedirect(url);
                }
              }
            }
          },
          onPageFinished: (String url) {
            setState(() {
              _isLoading = false;
            });
            
            print('=== PAGE FINISHED ===');
            print('URL: $url');
            print('Code processed: $_codeProcessed');
            
            // Check for 403 error (CloudFront blocking or Strava quota limit)
            if (url.contains('403') || url.contains('cloudfront') || 
                (url.contains('error') && url.contains('request could not be satisfied')) ||
                url.contains('Limit of connected athletes exceeded')) {
              print('❌ 403 ERROR DETECTED!');
              print('URL: $url');
              
              // Check if it's Strava quota limit error
              if (url.contains('Limit of connected athletes exceeded') || 
                  url.contains('limit of connected athletes')) {
                print('🔴 STRAVA QUOTA LIMIT EXCEEDED!');
                print('This app has exceeded the limit of connected athletes.');
                print('');
                print('💡 SOLUTION:');
                print('  1. Contact Strava developer support to request quota increase');
                print('  2. Go to: https://www.strava.com/settings/api');
                print('  3. Check your app quota limits');
                print('  4. Request quota increase if needed');
                
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Error 403: Limit of connected athletes exceeded. Please contact Strava developer support.'),
                      backgroundColor: Colors.red,
                      duration: Duration(seconds: 8),
                    ),
                  );
                }
              } else {
                print('CloudFront is blocking the request. This might be due to:');
                print('  1. Too many requests (rate limiting)');
                print('  2. IP blocking');
                print('  3. Configuration issue');
                print('');
                print('💡 SOLUTION:');
                print('  - Wait a few minutes before trying again');
                print('  - Close and reopen the app');
                print('  - Check your internet connection');
                
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('403 Error: Request blocked. Please wait a moment and try again.'),
                      backgroundColor: Colors.red,
                      duration: Duration(seconds: 5),
                    ),
                  );
                }
              }
              return; // Don't process further
            }
            
            // Check for redirect URL in page content (JavaScript redirect)
            // CRITICAL: Only process if URL STARTS with localhost/127.0.0.1 (actual redirect)
            // NOT if it just contains it (like authorization URL with redirect_uri parameter)
            if (!_codeProcessed && 
                (url.startsWith('http://127.0.0.1') || url.startsWith('http://localhost')) &&
                !url.contains('oauth/authorize')) {
              print('✅ Page finished with redirect URL: $url');
              _handleRedirect(url);
            }
            
            // Check for Strava error page (but NOT login page - login page is normal)
            // Also skip authorization page - it's normal too
            if (!_codeProcessed && 
                url.contains('strava.com') && 
                !url.contains('strava.com/login') &&
                !url.contains('oauth/authorize')) {
              // Check if page contains error message (but exclude login and authorization pages)
              _controller.runJavaScript('''
                (function() {
                  var currentUrl = window.location.href;
                  
                  // NEVER check login page or authorization page for errors
                  if (currentUrl.includes('strava.com/login') || 
                      currentUrl.includes('oauth/authorize')) {
                    return; // Don't check these pages - they're normal
                  }
                  
                  // Wait a bit for page to fully load
                  setTimeout(function() {
                    var errorText = document.body.innerText || document.body.textContent || '';
                    // Very specific error detection - must have "Oops!" or "There seems to be a problem"
                    // Don't trigger on generic "error" word which might appear in normal pages
                    if ((errorText.includes('Oops!') || errorText.includes('There seems to be a problem')) &&
                        !currentUrl.includes('login') &&
                        !currentUrl.includes('oauth/authorize')) {
                      if (typeof FlutterRedirect !== 'undefined') {
                        FlutterRedirect.postMessage('ERROR:' + currentUrl);
                      }
                    }
                  }, 1000); // Wait 1 second for page to load
                })();
              ''');
            }
            
            // Also check if page contains redirect in JavaScript or meta tags
            if (!_codeProcessed && url.contains('strava.com')) {
              // Inject JavaScript to check for redirects in page
              _controller.runJavaScript('''
                (function() {
                  console.log('=== CHECKING FOR REDIRECTS IN PAGE ===');
                  console.log('Current URL: ' + window.location.href);
                  
                  // Check if URL contains code parameter
                  if (window.location.href.includes('code=')) {
                    console.log('Found code in current URL!');
                    if (typeof FlutterRedirect !== 'undefined') {
                      FlutterRedirect.postMessage(window.location.href);
                    }
                  }
                  
                  // Check for meta refresh redirects
                  var metaTags = document.getElementsByTagName('meta');
                  for (var i = 0; i < metaTags.length; i++) {
                    if (metaTags[i].getAttribute('http-equiv') === 'refresh') {
                      var content = metaTags[i].getAttribute('content');
                      console.log('Found meta refresh: ' + content);
                      if (content && (content.includes('127.0.0.1') || content.includes('localhost') || content.includes('code='))) {
                        console.log('Meta refresh contains redirect!');
                        if (typeof FlutterRedirect !== 'undefined') {
                          FlutterRedirect.postMessage(content);
                        }
                      }
                    }
                  }
                  
                  // Check for JavaScript redirects in page scripts
                  var scripts = document.getElementsByTagName('script');
                  for (var i = 0; i < scripts.length; i++) {
                    var scriptContent = scripts[i].innerHTML;
                    if (scriptContent.includes('127.0.0.1') || scriptContent.includes('localhost')) {
                      console.log('Found redirect in script!');
                      // Try to extract URL from script
                      // Fix regex - escape properly
                      try {
                        // Use RegExp constructor to avoid regex parsing issues
                        // Match: "http://127.0.0.1..." or 'http://127.0.0.1...'
                        var urlPattern = new RegExp('["\'](http://127\\.0\\.0\\.1[^"\']*?)["\']', 'g');
                        var urlMatch = urlPattern.exec(scriptContent);
                        if (urlMatch && urlMatch[1]) {
                          var extractedUrl = urlMatch[1];
                          // Only process if it has code parameter (actual redirect, not just URL in code)
                          if (extractedUrl.includes('code=')) {
                            console.log('Extracted redirect URL from script: ' + extractedUrl);
                            if (typeof FlutterRedirect !== 'undefined') {
                              FlutterRedirect.postMessage(extractedUrl);
                            }
                          }
                        }
                      } catch (e) {
                        console.log('Error extracting URL from script: ' + e);
                      }
                    }
                  }
                  
                  // Monitor for immediate redirects
                  setTimeout(function() {
                    var currentUrl = window.location.href;
                    console.log('URL after 500ms: ' + currentUrl);
                    if (currentUrl !== window.location.href || currentUrl.includes('127.0.0.1') || currentUrl.includes('localhost')) {
                      if (typeof FlutterRedirect !== 'undefined') {
                        FlutterRedirect.postMessage(currentUrl);
                      }
                    }
                  }, 500);
                })();
              ''');
            }
            
            // If logout page finished, wait a bit then load authorization URL
            // Authorization URL should show login form if session is cleared
            if (!_logoutCompleted && url.contains('strava.com/logout')) {
              _logoutCompleted = true;
              print('✅ Logout page finished');
              print('Clearing cookies again to ensure clean session...');
              
              // Clear cookies again after logout page loads to ensure clean state
              _clearStravaCookies().then((_) {
                print('Cookies cleared. Waiting 2 seconds before loading authorization URL...');
                
                // Wait 2 seconds to ensure session is fully cleared
                Future.delayed(const Duration(seconds: 2), () {
                  if (mounted && !_codeProcessed) {
                    print('=== LOADING AUTHORIZATION URL ===');
                    print('URL: ${widget.authorizationUrl}');
                    print('This should open Strava authorization page');
                    print('If user is not logged in, will show login page first');
                    print('After login, will redirect to authorization page');
                    print('=================================');
                    _authorizationRetryCount = 0; // Reset retry count
                    _controller.loadRequest(Uri.parse(widget.authorizationUrl));
                  }
                });
              });
            }
            
            // If user is at login page and we've already loaded authorization URL, 
            // wait for them to login, then check if we need to reload authorization URL
            if (_logoutCompleted && 
                !_codeProcessed && 
                url.contains('strava.com/login') &&
                !url.contains('oauth/authorize')) {
              print('ℹ️ User is at login page');
              print('Waiting for user to login...');
              
              // After user logs in, Strava should redirect to authorization page
              // But if it doesn't, we'll reload authorization URL after a delay
              // IMPORTANT: Limit retries to prevent 403 errors from too many requests
              // Use a different counter for login page retries
              if (_authorizationRetryCount < 2) { // Max 2 retries
                Future.delayed(const Duration(seconds: 5), () { // Increased delay to 5 seconds
                  if (mounted && !_codeProcessed) {
                    _controller.currentUrl().then((currentUrl) {
                      print('Checking URL after login attempt: $currentUrl');
                      if (currentUrl != null) {
                        if (currentUrl.contains('oauth/authorize')) {
                          print('✅ Found authorization page! User can now approve');
                          _authorizationRetryCount = 0; // Reset counter on success
                        } else if (currentUrl.contains('127.0.0.1') || currentUrl.contains('localhost')) {
                          print('✅ Found redirect to localhost! Processing...');
                          _handleRedirect(currentUrl);
                          _authorizationRetryCount = 0; // Reset counter on success
                        } else if (currentUrl.contains('strava.com/login')) {
                          _authorizationRetryCount++;
                          print('Still at login page - retry count: $_authorizationRetryCount/2');
                          if (_authorizationRetryCount < 2) {
                            print('Will reload authorization URL after delay...');
                            // Reload authorization URL to trigger redirect to authorization page
                            Future.delayed(const Duration(seconds: 3), () {
                              if (mounted && !_codeProcessed) {
                                print('Reloading authorization URL: ${widget.authorizationUrl}');
                                _controller.loadRequest(Uri.parse(widget.authorizationUrl));
                              }
                            });
                          } else {
                            print('⚠️ Max retries reached. User might need to manually login.');
                            print('Please ensure you are logged into Strava and try again.');
                          }
                        } else {
                          print('Unknown URL: $currentUrl');
                        }
                      }
                    });
                  }
                });
              }
            }
            
            // If we're at accept_application page, set up monitoring for redirect
            if (!_codeProcessed && url.contains('oauth/accept_application')) {
              print('✅ User clicked "Authorize" - waiting for Strava redirect...');
              print('Strava will redirect to http://127.0.0.1 with code parameter.');
              print('Monitoring for redirect...');
              
              // Set up aggressive monitoring for the redirect
              // The page should redirect automatically to localhost with code
              Future.delayed(const Duration(seconds: 2), () {
                if (mounted && !_codeProcessed) {
                  _controller.currentUrl().then((currentUrl) {
                    if (currentUrl != null) {
                      if (currentUrl.startsWith('http://127.0.0.1') || 
                          currentUrl.startsWith('http://localhost')) {
                        print('✅ Redirect detected from accept_application page!');
                        _handleRedirect(currentUrl);
                      } else if (currentUrl.contains('accept_application')) {
                        print('Still on accept_application page, waiting for redirect...');
                        // Continue monitoring
                      }
                    }
                  });
                }
              });
            }
            
            // If we're at authorization page, log it
            if (!_codeProcessed && url.contains('oauth/authorize')) {
              print('✅ AUTHORIZATION PAGE LOADED!');
              print('URL: $url');
              print('User should see "Authorize" button now');
              print('After clicking Authorize, Strava will redirect to: ${widget.redirectUri}');
            }
            
            // If we're back at login page after loading authorization URL, user needs to login first
            // This is normal - after logout, user needs to login, then Strava will redirect to authorization page
            if (_logoutCompleted && 
                !_codeProcessed && 
                url.contains('strava.com/login') &&
                !url.contains('oauth/authorize')) {
              print('ℹ️ INFO: User is at login page');
              print('This is normal - after logout, user needs to login first');
              print('After login, Strava should redirect to authorization page automatically');
              print('Current URL: $url');
              print('Waiting for user to login and redirect to authorization page...');
              
              // Monitor for redirect to authorization page after login
              // This will happen automatically when user logs in
            }
            
            // If we're on Strava homepage/marketing page, redirect to authorization URL
            // This prevents showing marketing page instead of login/authorization
            if (!_logoutCompleted && 
                !_codeProcessed && 
                (url == 'https://www.strava.com/' || 
                 url == 'https://www.strava.com' ||
                 (url.contains('strava.com') && 
                  !url.contains('oauth') && 
                  !url.contains('login') &&
                  !url.contains('logout') &&
                  !url.contains('dashboard') &&
                  !url.contains('athlete') &&
                  !url.contains('getting-started') &&
                  !url.contains('onboarding') &&
                  !url.contains('127.0.0.1') &&
                  !url.contains('localhost')))) {
              print('⚠️ Detected Strava homepage/marketing page');
              print('URL: $url');
              print('Redirecting to authorization URL...');
              Future.delayed(const Duration(milliseconds: 500), () {
                if (mounted && !_codeProcessed) {
                  print('Loading authorization URL: ${widget.authorizationUrl}');
                  _controller.loadRequest(Uri.parse(widget.authorizationUrl));
                }
              });
            }
            
            // Inject JavaScript to monitor for redirects - ALWAYS monitor on any Strava page
            if (!_codeProcessed && url.contains('strava.com')) {
              print('🔍 Setting up aggressive redirect monitoring for: $url');
              _controller.runJavaScript('''
                (function() {
                  console.log('=== AGGRESSIVE REDIRECT MONITORING ===');
                  console.log('Current URL: ' + window.location.href);
                  
                  var redirectDetected = false;
                  
                  // Function to send redirect to Flutter
                  function sendRedirect(url) {
                    if (!redirectDetected) {
                      redirectDetected = true;
                      console.log('✅ REDIRECT DETECTED: ' + url);
                      if (typeof FlutterRedirect !== 'undefined') {
                        FlutterRedirect.postMessage(url);
                      } else {
                        console.error('FlutterRedirect channel not available!');
                      }
                    }
                  }
                  
                  // Monitor window.location.href every 100ms (very aggressive)
                  var checkCount = 0;
                  var checkInterval = setInterval(function() {
                    checkCount++;
                    var currentUrl = window.location.href;
                    
                    // Log every 10th check (every 1 second)
                    if (checkCount % 10 === 0) {
                      console.log('Monitor check #' + checkCount + ': ' + currentUrl);
                    }
                    
                    // Check for localhost redirect
                    if (currentUrl.includes('127.0.0.1') || currentUrl.includes('localhost')) {
                      console.log('✅ LOCALHOST REDIRECT DETECTED!');
                      sendRedirect(currentUrl);
                      clearInterval(checkInterval);
                      return;
                    }
                    
                    // Check for code parameter (even if not localhost - might be in intermediate redirect)
                    if (currentUrl.includes('code=') && currentUrl.includes('127.0.0.1')) {
                      console.log('✅ CODE PARAMETER FOUND IN LOCALHOST URL!');
                      sendRedirect(currentUrl);
                      clearInterval(checkInterval);
                      return;
                    }
                    
                    // Stop after 15 seconds (150 checks)
                    if (checkCount >= 150) {
                      console.log('❌ Monitoring stopped after 15 seconds - no redirect found');
                      console.log('Final URL: ' + currentUrl);
                      clearInterval(checkInterval);
                    }
                  }, 100); // Check every 100ms
                  
                  // Also monitor document.location
                  var docLocationCheck = 0;
                  var docInterval = setInterval(function() {
                    docLocationCheck++;
                    try {
                      var docLocation = document.location.href;
                      if (docLocation.includes('127.0.0.1') || docLocation.includes('localhost')) {
                        console.log('✅ DOCUMENT.LOCATION REDIRECT DETECTED!');
                        sendRedirect(docLocation);
                        clearInterval(docInterval);
                      }
                    } catch (e) {
                      console.log('Error checking document.location: ' + e);
                    }
                    
                    if (docLocationCheck >= 150) {
                      clearInterval(docInterval);
                    }
                  }, 100);
                  
                  // Override window.location to catch redirects
                  try {
                    var originalLocation = window.location;
                    Object.defineProperty(window, 'location', {
                      get: function() {
                        return originalLocation;
                      },
                      set: function(newLocation) {
                        console.log('⚠️ window.location SET called: ' + newLocation);
                        if (newLocation && (newLocation.includes('127.0.0.1') || newLocation.includes('localhost'))) {
                          sendRedirect(newLocation);
                        }
                        originalLocation.href = newLocation;
                      }
                    });
                  } catch (e) {
                    console.log('Could not override window.location: ' + e);
                  }
                  
                  // Also listen for popstate events (back/forward navigation)
                  window.addEventListener('popstate', function(event) {
                    console.log('popstate event: ' + window.location.href);
                    if (window.location.href.includes('127.0.0.1') || window.location.href.includes('localhost')) {
                      sendRedirect(window.location.href);
                    }
                  });
                  
                  // Listen for hashchange (might be used for redirects)
                  window.addEventListener('hashchange', function(event) {
                    console.log('hashchange event: ' + window.location.href);
                    if (window.location.href.includes('127.0.0.1') || window.location.href.includes('localhost')) {
                      sendRedirect(window.location.href);
                    }
                  });
                })();
              ''');
            }
            
            // Also periodically check current URL from Flutter side as fallback
            if (!_codeProcessed && url.contains('strava.com') && !url.contains('logout')) {
              // Check URL every 2 seconds for 20 seconds
              var checkCount = 0;
              Timer.periodic(const Duration(seconds: 2), (timer) {
                checkCount++;
                if (_codeProcessed || checkCount > 10) {
                  timer.cancel();
                  return;
                }
                
                _controller.currentUrl().then((currentUrl) {
                  if (currentUrl != null && !_codeProcessed) {
                    // Skip authorization page completely - don't log or process it
                    if (currentUrl.contains('oauth/authorize')) {
                      return; // Skip authorization page - it's normal, not a redirect
                    }
                    
                    // Only log non-authorization pages
                    print('🔍 Periodic URL check #$checkCount: $currentUrl');
                    
                    // CRITICAL: Only process as redirect if:
                    // 1. URL STARTS with http://127.0.0.1 or http://localhost (not just contains it)
                    // 2. AND has code parameter
                    // This prevents processing authorization URL which contains "127.0.0.1" in redirect_uri parameter
                    if ((currentUrl.startsWith('http://127.0.0.1') || currentUrl.startsWith('http://localhost')) &&
                        currentUrl.contains('code=')) {
                      print('✅ REDIRECT FOUND VIA PERIODIC CHECK!');
                      _handleRedirect(currentUrl);
                      timer.cancel();
                    }
                  }
                }).catchError((e) {
                  print('Error checking URL: $e');
                });
              });
            }
            
            // If user is on Strava page after authorization (dashboard, getting-started, etc), check for redirect
            if (!_codeProcessed && (url.contains('strava.com/dashboard') || 
                                    url.contains('strava.com/athlete') ||
                                    url.contains('strava.com/getting-started') ||
                                    url.contains('strava.com/onboarding'))) {
              print('⚠️ WARNING: User is on Strava page after authorization');
              print('URL: $url');
              print('Expected redirect_uri: ${widget.redirectUri}');
              print('This might mean redirect_uri tidak sesuai dengan Strava settings');
              print('');
              print('🔴 CRITICAL: Strava did not redirect to ${widget.redirectUri}');
              print('Please check Strava API settings:');
              print('  1. Go to: https://www.strava.com/settings/api');
              print('  2. Edit your application');
              print('  3. In "Authorization Callback Domain", add: 127.0.0.1');
              print('  4. Make sure redirect_uri in code matches: http://127.0.0.1');
              print('');
              
              // Inject JavaScript to check for redirect or extract code from page
              // Also periodically check current URL in case redirect happens
              _controller.runJavaScript('''
                (function() {
                  console.log('=== CHECKING FOR REDIRECT OR CODE ===');
                  console.log('Current URL: ' + window.location.href);
                  
                  // Check URL for code parameter
                  var url = window.location.href;
                  if (url.includes('code=')) {
                    console.log('✅ Found code in URL: ' + url);
                    if (typeof FlutterRedirect !== 'undefined') {
                      FlutterRedirect.postMessage(url);
                    }
                    return;
                  }
                  
                  // Check if URL contains redirect to localhost (might be in page content)
                  if (url.includes('127.0.0.1') || url.includes('localhost')) {
                    console.log('✅ Found localhost in URL: ' + url);
                    if (typeof FlutterRedirect !== 'undefined') {
                      FlutterRedirect.postMessage(url);
                    }
                    return;
                  }
                  
                  // Check for meta refresh redirect
                  var metaTags = document.getElementsByTagName('meta');
                  for (var i = 0; i < metaTags.length; i++) {
                    if (metaTags[i].getAttribute('http-equiv') === 'refresh') {
                      var content = metaTags[i].getAttribute('content');
                      console.log('Found meta refresh: ' + content);
                      if (content && (content.includes('127.0.0.1') || content.includes('localhost') || content.includes('code='))) {
                        if (typeof FlutterRedirect !== 'undefined') {
                          FlutterRedirect.postMessage(content);
                        }
                        return;
                      }
                    }
                  }
                  
                  // Monitor for redirects
                  var checkCount = 0;
                  var checkInterval = setInterval(function() {
                    checkCount++;
                    var currentUrl = window.location.href;
                    
                    if (currentUrl.includes('127.0.0.1') || currentUrl.includes('localhost')) {
                      console.log('Redirect detected! URL: ' + currentUrl);
                      if (typeof FlutterRedirect !== 'undefined') {
                        FlutterRedirect.postMessage(currentUrl);
                      }
                      clearInterval(checkInterval);
                    } else if (currentUrl.includes('code=')) {
                      console.log('Found code in URL: ' + currentUrl);
                      if (typeof FlutterRedirect !== 'undefined') {
                        FlutterRedirect.postMessage(currentUrl);
                      }
                      clearInterval(checkInterval);
                    }
                    
                    // Stop after 10 seconds
                    if (checkCount >= 33) { // 33 * 300ms = ~10 seconds
                      clearInterval(checkInterval);
                      console.log('❌ Stopped monitoring - no redirect found after 10 seconds');
                      console.log('Final URL: ' + window.location.href);
                      console.log('Expected redirect to: ${widget.redirectUri}');
                    }
                  }, 300);
                  
                  // Also check document.location periodically (catches JavaScript redirects)
                  var locationCheckCount = 0;
                  var locationInterval = setInterval(function() {
                    locationCheckCount++;
                    var currentLocation = document.location.href;
                    console.log('Location check #' + locationCheckCount + ': ' + currentLocation);
                    
                    if (currentLocation.includes('127.0.0.1') || currentLocation.includes('localhost')) {
                      console.log('✅ Redirect detected via document.location!');
                      if (typeof FlutterRedirect !== 'undefined') {
                        FlutterRedirect.postMessage(currentLocation);
                      }
                      clearInterval(locationInterval);
                    }
                    
                    if (locationCheckCount >= 33) {
                      clearInterval(locationInterval);
                    }
                  }, 300);
                })();
              ''');
              
              // Wait and check if redirect happens via JavaScript
              Future.delayed(const Duration(seconds: 5), () {
                if (mounted && !_codeProcessed) {
                  _controller.currentUrl().then((currentUrl) {
                    print('Current URL after 5 seconds: $currentUrl');
                    if (currentUrl != null && (currentUrl.contains('127.0.0.1') || currentUrl.contains('localhost'))) {
                      print('✅ Found redirect URL! Processing...');
                      _handleRedirect(currentUrl);
                    } else if (currentUrl != null && currentUrl.contains('code=')) {
                      print('✅ Found code in URL! Processing...');
                      _handleRedirect(currentUrl);
                    } else {
                      print('❌ Still on Strava page - redirect failed');
                      print('Kemungkinan masalah:');
                      print('1. Redirect URI di Strava settings: harus "127.0.0.1" (tanpa http://)');
                      print('2. Redirect URI di code: harus "http://127.0.0.1"');
                      print('3. Keduanya harus sama persis!');
                      print('4. Pastikan di Strava API settings, Authorization Callback Domain = 127.0.0.1');
                    }
                  });
                }
              });
            }
          },
          onWebResourceError: (WebResourceError error) {
            // If localhost error, try to extract code from failed URL (only if not already processed)
            // Only handle errors for http://127.0.0.1 redirects
            if (!_codeProcessed) {
              final errorUrl = error.url;
              print('=== WEB RESOURCE ERROR ===');
              print('Error: ${error.description}');
              print('Error Code: ${error.errorCode}');
              print('URL: $errorUrl');
              print('Code processed: $_codeProcessed');
              
              // This is actually GOOD - localhost redirects will fail to load
              // But the URL contains the authorization code!
              if (errorUrl != null && 
                  (errorUrl.startsWith('http://127.0.0.1') || 
                   errorUrl.startsWith('http://localhost') ||
                   errorUrl.contains('127.0.0.1') ||
                   errorUrl.contains('localhost'))) {
                print('✅ Found redirect URL in error (this is expected for localhost)!');
                print('Extracting code from error URL: $errorUrl');
                _handleRedirect(errorUrl);
              } else {
                print('⚠️ Error URL is not localhost - might be unrelated error');
              }
            }
          },
        ),
      );
    
    // Reset state for new login attempt
    _codeProcessed = false;
    _logoutCompleted = false;
    _authorizationRetryCount = 0;
    
    // Clear Strava cookies explicitly before loading
    _clearStravaCookies();
    
    // Strategy: Load Strava logout page first to clear session
    // Then load authorization URL which should show login form if session is cleared
    print('=== STRAVA OAUTH WEBVIEW INITIALIZED ===');
    print('Authorization URL: ${widget.authorizationUrl}');
    print('Redirect URI: ${widget.redirectUri}');
    print('Step 1: Clearing Strava cookies...');
    print('Step 2: Loading Strava logout page to clear session...');
    print('Step 3: After logout, will clear cookies again and wait 2 seconds');
    print('Step 4: Then load authorization URL');
    print('Step 5: Authorization page should appear (or login page if not logged in)');
    print('Step 6: After user approves, Strava should redirect to: ${widget.redirectUri}');
    print('==========================================');
    
    // Load logout page first - onPageFinished will handle next step
    // But also set up a fallback to load authorization URL if logout takes too long
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        _controller.loadRequest(Uri.parse('https://www.strava.com/logout'));
      }
    });
    
    // Fallback: If logout doesn't complete in 5 seconds, clear cookies and load authorization URL anyway
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted && !_logoutCompleted && !_codeProcessed) {
        print('⚠️ Logout page taking too long, clearing cookies and loading authorization URL...');
        _logoutCompleted = true;
        _clearStravaCookies().then((_) {
          Future.delayed(const Duration(seconds: 1), () {
            if (mounted && !_codeProcessed) {
              _controller.loadRequest(Uri.parse(widget.authorizationUrl));
            }
          });
        });
      }
    });
  }
  
  // Clear Strava cookies explicitly
  Future<void> _clearStravaCookies() async {
    try {
      // Clear cookies for strava.com domain
      final cookieManager = WebViewCookieManager();
      final cleared = await cookieManager.clearCookies();
      print('Cookies cleared: $cleared');
      
      // Also try to clear specific Strava cookies
      await cookieManager.setCookie(
        WebViewCookie(
          name: 'strava_session',
          value: '',
          domain: '.strava.com',
          path: '/',
        ),
      );
      print('Strava session cookie cleared');
    } catch (e) {
      print('Error clearing cookies: $e');
    }
  }

  void _handleRedirect(String url) {
    // Prevent double processing
    if (_codeProcessed) {
      print('Code already processed, ignoring redirect: $url');
      return;
    }
    
    print('=== HANDLING REDIRECT ===');
    print('URL: $url');
    
    // CRITICAL: Only process redirects to our app (localhost/127.0.0.1)
    // DO NOT process intermediate redirects like Google OAuth
    // DO NOT process authorization URL (it's the page we're waiting for, not a redirect)
    if (!url.startsWith('http://127.0.0.1') && 
        !url.startsWith('http://localhost') &&
        !url.contains('127.0.0.1') &&
        !url.contains('localhost')) {
      print('⚠️ Ignoring non-localhost redirect: $url');
      print('This might be an intermediate redirect (e.g., Google OAuth)');
      return;
    }
    
    // Don't process authorization URL as redirect - it's the page we're waiting for
    if (url.contains('oauth/authorize') && !url.contains('code=')) {
      print('ℹ️ This is authorization page, not a redirect. Waiting for user to approve...');
      return;
    }
    
    // Handle accept_application page - this is Strava's confirmation page
    // It will redirect to localhost with code, so we need to wait for that redirect
    if (url.contains('oauth/accept_application') && !url.contains('code=')) {
      print('ℹ️ This is Strava accept_application page. Waiting for redirect to localhost...');
      print('Strava will redirect to http://127.0.0.1 with code parameter shortly.');
      // Don't return - let the page load and wait for redirect
      // The JavaScript monitoring will catch the redirect
      return;
    }
    
    // Also reject if it's a Strava internal redirect
    if (url.contains('strava.com/o_auth/google') || 
        url.contains('strava.com/oauth/google')) {
      print('⚠️ Ignoring Google OAuth redirect: $url');
      print('Waiting for final Strava redirect to localhost...');
      return;
    }
    
    try {
      String? extractedCode;
      
      // First, try to extract code from URL string directly (more reliable)
      if (url.contains('code=')) {
        final codeMatch = RegExp(r'[?&]code=([^&]+)').firstMatch(url);
        if (codeMatch != null) {
          // Get raw code first
          final rawCode = codeMatch.group(1)!;
          print('Raw code from URL: $rawCode');
          
          // Decode URL-encoded characters
          extractedCode = Uri.decodeComponent(rawCode);
          print('Decoded code: $extractedCode');
          print('Code length: ${extractedCode.length}');
          
          // Validate code format - Strava codes are typically alphanumeric, 20+ chars
          // Google OAuth codes often have slashes or different format
          if (extractedCode.contains('/') && extractedCode.length < 50) {
            print('⚠️ WARNING: Code format looks like Google OAuth code, not Strava code');
            print('Rejecting this code - waiting for final Strava redirect...');
            return;
          }
        }
      }
      
      // If not found in regex, try parsing as URI
      if (extractedCode == null) {
        final uri = Uri.parse(url);
        if (uri.queryParameters.containsKey('code')) {
          extractedCode = uri.queryParameters['code']!;
          print('Code from queryParameters: $extractedCode');
          print('Code length: ${extractedCode.length}');
          
          // Validate code format
          if (extractedCode.contains('/') && extractedCode.length < 50) {
            print('⚠️ WARNING: Code format looks like Google OAuth code');
            return;
          }
        }
      }
      
      // Process code if found and validated
      if (extractedCode != null && extractedCode.isNotEmpty) {
        // Additional validation: Strava codes are usually longer and alphanumeric
        if (extractedCode.length < 20) {
          print('⚠️ WARNING: Code too short (${extractedCode.length} chars) - might be invalid');
          print('Strava codes are typically 20+ characters');
          return;
        }
        
        // Mark as processed BEFORE calling callback
        _codeProcessed = true;
        
        // Clean code - remove any whitespace
        final cleanCode = extractedCode.trim();
        print('✅ VALID CODE EXTRACTED');
        print('Final clean code: ${cleanCode.substring(0, cleanCode.length > 30 ? 30 : cleanCode.length)}...');
        print('Final code length: ${cleanCode.length}');
        
        // Only call once to avoid double processing
        if (mounted) {
          print('✅ Sending code to callback...');
          print('Code preview: ${cleanCode.substring(0, cleanCode.length > 50 ? 50 : cleanCode.length)}...');
          widget.onCodeReceived(cleanCode);
          Navigator.of(context).pop();
        }
        return;
      }
      
      // Check for error
      if (url.contains('error=')) {
        final errorMatch = RegExp(r'[?&]error=([^&]+)').firstMatch(url);
        if (errorMatch != null) {
          final error = Uri.decodeComponent(errorMatch.group(1)!);
          _codeProcessed = true; // Mark as processed
          print('❌ ERROR IN REDIRECT URL: $error');
          widget.onError('Authorization failed: $error. Please check Strava API settings.');
          if (mounted) {
            Navigator.of(context).pop();
          }
          return;
        }
      }
      
      // Try parsing error from URI
      final uri = Uri.parse(url);
      if (uri.queryParameters.containsKey('error')) {
        _codeProcessed = true; // Mark as processed
        final error = uri.queryParameters['error'] ?? 'Unknown error';
        print('❌ ERROR IN QUERY PARAMETERS: $error');
        widget.onError('Authorization failed: $error. Please check Strava API settings.');
        if (mounted) {
          Navigator.of(context).pop();
        }
        return;
      }
      
      // If we reach here, no code found
      print('⚠️ No code found in URL: $url');
      print('This might mean:');
      print('  1. Strava tidak melakukan redirect ke ${widget.redirectUri}');
      print('  2. Redirect URI tidak sesuai dengan Strava settings');
      print('  3. Authorization Callback Domain belum terdaftar di Strava');
      print('');
      print('Please check Strava API settings and try again.');
    } catch (e) {
      print('Error parsing redirect: $e'); // Debug log
      if (!_codeProcessed) {
        _codeProcessed = true; // Mark as processed to prevent retry
        widget.onError('Failed to parse redirect: $e');
        if (mounted) {
          Navigator.of(context).pop();
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (didPop) return;
        // User pressed back button - treat as cancellation
        widget.onError('User cancelled');
        Navigator.of(context).pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Login with Strava'),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () {
              widget.onError('User cancelled');
              Navigator.of(context).pop();
            },
          ),
        ),
        body: Stack(
          children: [
            WebViewWidget(controller: _controller),
            if (_isLoading)
              const Center(
                child: CircularProgressIndicator(),
              ),
          ],
        ),
      ),
    );
  }
}

