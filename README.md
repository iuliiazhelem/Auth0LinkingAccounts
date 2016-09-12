# Auth0LinkingAccounts

This sample exposes how to manage accounts linking for an Auth0 user. 

Auth0 supports the linking of user accounts from various identity providers, allowing a user to authenticate from any of their accounts and still be recognized by your app and associated with the same user profile.
The process of linking accounts merges two existing user profiles into a single account. When linking accounts, a primary account and a secondary account must be specified.

For this you need to add the following to your `Podfile`:
```
pod 'Lock', '~> 1.24'
pod 'SimpleKeychain'
```

The main steps for linking accounts are:

- Getting Auth0 APIv2 token as described [here](https://auth0.com/docs/api/management/v2/tokens)
- Login to your iOS application
- You may need to get list of available users for linking or you can see this list on [Dashboard](https://manage.auth0.com/#/users)
- Perform a linking for selected user (user_id)

## Important Snippets

### Step 1: Login to Auth0. 
```Objective-C
A0LockViewController *controller = [[A0Lock sharedLock] newLockViewController];
controller.onAuthenticationBlock = ^(A0UserProfile *profile, A0Token *token) {
  //save token and userProfile
  [self dismissViewControllerAnimated:YES completion:nil];
};
[self presentViewController:controller animated:YES completion:nil];
```

### Step 2: Get list of available users for linking.

```Objective-C
    NSString *bearerToken = [NSString stringWithFormat:@"Bearer %@", <API_V2_TOKEN>];
    NSDictionary *headers = @{ @"Authorization": bearerToken };
    
    NSString *urlString = [NSString stringWithFormat:@"https://%@/api/v2/users?include_totals=true&include_fields=true&search_engine=v2", <AUTH0_DOMAIN>];
    NSURL *url = [NSURL URLWithString:urlString];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url
                                                           cachePolicy:NSURLRequestUseProtocolCachePolicy
                                                       timeoutInterval:10.0];
    [request setHTTPMethod:@"GET"];
    [request setAllHTTPHeaderFields:headers];
    
    NSURLSession *session = [NSURLSession sharedSession];
    NSURLSessionDataTask *dataTask = [session dataTaskWithRequest:request
                                                completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                                                    if (error) {
                                                        NSLog(@"%@", error);
                                                    } else {
                                                        NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:&error];
                                                        NSLog(@"%@", dict);
                                                    }
                                                }];
    [dataTask resume];
```

### Step 3: Step 3: Link a new user to current user account
```Objective-C
NSString *bearerToken = [NSString stringWithFormat:@"Bearer %@", <API_V2_TOKEN>];
NSDictionary *headers = @{ @"content-type": @"application/json",
                          @"Authorization": bearerToken};
    
NSDictionary *body = @{ @"provider": <NEW_USER_PROVIDER>,
                        @"user_id" : <NEW_USER_ID>
                      };
    
NSError *error;
NSData *dataFromDict = [NSJSONSerialization dataWithJSONObject:body
                                                       options:0
                                                         error:&error];
    
NSString *urlString = [NSString stringWithFormat:@"https://%@/api/v2/users/%@/identities", <AUTH0_DOMAIN>, <CURRENT_USER_ID>];
NSURL *url = [NSURL URLWithString:urlString];
NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url
                                                       cachePolicy:NSURLRequestUseProtocolCachePolicy
                                                   timeoutInterval:10.0];
[request setHTTPMethod:@"POST"];
[request setAllHTTPHeaderFields:headers];
[request setHTTPBody:dataFromDict];
    
NSURLSession *session = [NSURLSession sharedSession];
NSURLSessionDataTask *dataTask = [session dataTaskWithRequest:request
                                            completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                                              if (error) {
                                                NSLog(@"%@", error);
                                              } else {
                                                NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:&error];
                                                        NSLog(@"%@", dict);
                                                if ([dict isKindOfClass:[NSDictionary class]]) {
                                                  if (dict[@"error"] || dict[@"errorCode"] || dict[@"statusCode"]) {
                                                    NSLog(@"Error: %@", dict);
                                                  }
                                                } else if ([dict isKindOfClass:[NSArray class]]) {
                                                  //Success
                                                }
                                              }
                                            }];
[dataTask resume];
```

### Step 4: Unlink selected linked user
```Objective-C
NSString *bearerToken = [NSString stringWithFormat:@"Bearer %@", <API_V2_TOKEN>];
NSDictionary *headers = @{ @"Authorization": bearerToken};
    
NSString *urlString = [NSString stringWithFormat:@"https://%@/api/v2/users/%@/identities/%@/%@", <AUTH0_DOMAIN>, <CURRENT_USER_ID>, <LINKED_USER_PROVIDER>, <LINKED_USER_ID>];
NSURL *url = [NSURL URLWithString:urlString];
NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url
                                                       cachePolicy:NSURLRequestUseProtocolCachePolicy
                                                   timeoutInterval:10.0];
[request setHTTPMethod:@"DELETE"];
[request setAllHTTPHeaderFields:headers];

NSURLSession *session = [NSURLSession sharedSession];
NSURLSessionDataTask *dataTask = [session dataTaskWithRequest:request
                                            completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                                              if (error) {
                                                NSLog(@"%@", error);
                                              } else {
                                                NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:&error];
                                                        NSLog(@"%@", dict);
                                                if ([dict isKindOfClass:[NSDictionary class]]) {
                                                  if (dict[@"error"] || dict[@"errorCode"] || dict[@"statusCode"]) {
                                                    NSLog(@"Error: %@", dict);
                                                  }
                                                } else if ([dict isKindOfClass:[NSArray class]]) {
                                                  //Success
                                                }
                                              }
                                            }];
[dataTask resume];
```

Before using the example, please make sure that you change some keys in the `Info.plist` file with your data:

##### Auth0 data from [Auth0 Dashboard](https://manage.auth0.com/#/applications):

- Auth0ClientId
- Auth0Domain
- CFBundleURLSchemes

```
<key>CFBundleTypeRole</key>
<string>None</string>
<key>CFBundleURLName</key>
<string>auth0</string>
<key>CFBundleURLSchemes</key>
<array>
<string>a0{CLIENT_ID}</string>
</array>
```

##### [Auth0 APIv2 token](https://auth0.com/docs/api/management/v2/tokens)

- Auth0APIv2Token

For more information about reset password please check the following links:
* [Link accounts](https://auth0.com/docs/link-accounts)
* [Swift quickstart](https://auth0.com/docs/quickstart/native/ios-swift/05-linking-accounts)
