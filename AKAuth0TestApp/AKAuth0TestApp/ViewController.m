//
//  ViewController.m
//  AKAuth0TestApp
//

#import "ViewController.h"
#import "AppDelegate.h"
#import <Lock/Lock.h>

//Please use your Auth0 APIv2 token from https://auth0.com/docs/api/management/v2/tokens
//scopes : read:users, update:users, read:logs
static NSString *kAuth0APIv2Token = @"Auth0APIv2Token";

static NSString *kAuth0Domain = @"Auth0Domain";

@interface ViewController ()

@property (strong, nonatomic) A0Token *token;
@property (strong, nonatomic) A0UserProfile *profile;
@property (strong, nonatomic) NSMutableArray *pickerData;
@property (strong, nonatomic) NSMutableArray *userList;
@property (strong, nonatomic) A0UserProfile *selectedUser;

@property (strong, nonatomic) NSMutableArray *linkedPickerData;
@property (strong, nonatomic) NSMutableArray *linkedUserList;
@property (strong, nonatomic) A0UserIdentity *selectedLinkedUser;

@property (weak, nonatomic) IBOutlet UILabel *connectionLabel;
- (IBAction)clickLoginButton:(id)sender;
@property (weak, nonatomic) IBOutlet UILabel *userName;
@property (weak, nonatomic) IBOutlet UILabel *userId;
@property (weak, nonatomic) IBOutlet UILabel *userEmail;
- (IBAction)clickGetUserList:(id)sender;
@property (weak, nonatomic) IBOutlet UIPickerView *usersPickerView;
- (IBAction)clickLinkButton:(id)sender;
@property (weak, nonatomic) IBOutlet UIPickerView *linkedAccountPickerView;
- (IBAction)clickUnlinkButton:(id)sender;
- (IBAction)clickLinkedAccounts:(id)sender;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.usersPickerView.dataSource = self;
    self.usersPickerView.delegate = self;
    
    self.pickerData = [NSMutableArray arrayWithCapacity:10];
    
    self.linkedAccountPickerView.dataSource = self;
    self.linkedAccountPickerView.delegate = self;
    
    self.linkedPickerData = [NSMutableArray arrayWithCapacity:10];
}

// Step 1: Login to Auth0
- (IBAction)clickLoginButton:(id)sender {
    A0LockViewController *controller = [[A0Lock sharedLock] newLockViewController];
    controller.useWebView = NO;
    controller.onAuthenticationBlock = ^(A0UserProfile *profile, A0Token *token) {
        self.token = token;
        self.profile = profile;
        [self createLinkedUserList:profile.identities];
        dispatch_async(dispatch_get_main_queue(), ^{
            self.connectionLabel.text = @"CONNECTION";
        });
        //some delay for getting correct logs
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self getLogForUser];
        });
        
        [self dismissViewControllerAnimated:YES completion:nil];
    };
    
    [self presentViewController:controller animated:YES completion:nil];
    
}

// Get log for current user to determine what kind of connection was used for login to Auth0
- (void)getLogForUser {
    // GET request
    // We need url "https://<Auth0 Domain>/api/v2/users/<UserId>/logs?include_totals=true&per_page=1"
    // and header "Authorization : Bearer <kAuth0APIv2Token>"
    
    NSString *apiToken = [NSBundle mainBundle].infoDictionary[kAuth0APIv2Token];
    NSString *bearerToken = [NSString stringWithFormat:@"Bearer %@", apiToken];
    NSDictionary *headers = @{ @"Authorization": bearerToken};
    
    NSString *userId = [self.profile.userId stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet alphanumericCharacterSet]];
    
    NSString *domain = [NSBundle mainBundle].infoDictionary[kAuth0Domain];
    NSString *urlString = [NSString stringWithFormat:@"https://%@/api/v2/users/%@/logs?include_totals=true&per_page=1", domain, userId];
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
                                                        [self showMessage:[NSString stringWithFormat:@"%@", error]];
                                                    } else {
                                                        NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:&error];
                                                        NSLog(@"%@", dict);
                                                        NSArray *logs = dict[@"logs"];//array with 1 element - the latest connection
                                                        dispatch_async(dispatch_get_main_queue(), ^{
                                                            self.connectionLabel.text = logs[0][@"connection"];
                                                        });
                                                        
                                                    }
                                                }];
    [dataTask resume];
}

// Step 2: Get list of available users for linking
- (IBAction)clickGetUserList:(id)sender {
    // GET request
    // We need url "https://<Auth0 Domain>/api/v2/users?include_totals=true&include_fields=true&search_engine=v2"
    // and header "Authorization : Bearer <kAuth0APIv2Token>"
    
    NSString *apiToken = [NSBundle mainBundle].infoDictionary[kAuth0APIv2Token];
    NSString *bearerToken = [NSString stringWithFormat:@"Bearer %@", apiToken];
    NSDictionary *headers = @{ @"Authorization": bearerToken };
    
    NSString *domain = [NSBundle mainBundle].infoDictionary[kAuth0Domain];
    NSString *urlString = [NSString stringWithFormat:@"https://%@/api/v2/users?include_totals=true&include_fields=true&search_engine=v2", domain];
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
                                                        [self showMessage:[NSString stringWithFormat:@"%@", error]];
                                                    } else {
                                                        NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:&error];
                                                        NSLog(@"%@", dict);
                                                        [self createUserList:dict];
                                                    }
                                                }];
    [dataTask resume];
}

// Step 3: Link a new user to current user account
- (IBAction)clickLinkButton:(id)sender {
    // POST request
    // We need url "https://<Auth0 Domain>/api/v2/users/<CurrentUserId>/identities"
    // and header "Authorization : Bearer <kAuth0APIv2Token>"
    
    NSString *apiToken = [NSBundle mainBundle].infoDictionary[kAuth0APIv2Token];
    NSString *bearerToken = [NSString stringWithFormat:@"Bearer %@", apiToken];
    NSDictionary *headers = @{ @"content-type": @"application/json",
                               @"Authorization": bearerToken};
    
    if (!self.selectedUser && !self.userList.count) {
        return;
    }
    
    if (!self.selectedUser) {
        self.selectedUser = [[A0UserProfile alloc] initWithDictionary:self.userList[[self.usersPickerView selectedRowInComponent:0]]];
    }
    
    A0UserIdentity *userIdentity = self.selectedUser.identities[0];
    NSString *provider = userIdentity.provider;
    NSString *userId = [userIdentity.userId stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet alphanumericCharacterSet]];
    NSDictionary *body = @{ @"provider": provider,
                            @"user_id" : userId
                            };
    
    NSError *error;
    NSData *dataFromDict = [NSJSONSerialization dataWithJSONObject:body
                                                           options:0
                                                             error:&error];
    
    userId = [self.profile.userId stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet alphanumericCharacterSet]];
    NSString *domain = [NSBundle mainBundle].infoDictionary[kAuth0Domain];
    NSString *urlString = [NSString stringWithFormat:@"https://%@/api/v2/users/%@/identities", domain, userId];
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
                                                        [self showMessage:[NSString stringWithFormat:@"%@", error]];
                                                    } else {
                                                        NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:&error];
                                                        NSLog(@"%@", dict);
                                                        if ([dict isKindOfClass:[NSDictionary class]]) {
                                                            if (dict[@"error"] || dict[@"errorCode"] || dict[@"statusCode"]) {
                                                                [self showMessage:[NSString stringWithFormat:@"%@", dict]];
                                                            }
                                                        } else if ([dict isKindOfClass:[NSArray class]]) {
                                                            [self fetchUserProfile];
                                                        }
                                                    }
                                                }];
    [dataTask resume];
}

// Step 4: Get list of linked accounts
- (IBAction)clickLinkedAccounts:(id)sender {
    [self fetchUserProfile];
}

// Fetch the current user prfile with idetnities (linked accounts)
- (void)fetchUserProfile {
    if (!self.token) {
        [self showMessage:@"Please login first"];
        return;
    }
    
    A0APIClient *client = [[A0Lock sharedLock] apiClient];
    [client fetchUserProfileWithIdToken:self.token.idToken success:^(A0UserProfile * _Nonnull profile) {
        self.profile = profile;
        [self createLinkedUserList:profile.identities];
    } failure:^(NSError * _Nonnull error) {
        NSLog(@"Oops something went wrong: %@", error);
        [self showMessage:[NSString stringWithFormat:@"%@", error]];
    }];
}

// Step 5: Unlink selected linked user
- (IBAction)clickUnlinkButton:(id)sender {
    // DELETE request
    // We need url "https://<Auth0 Domain>/api/v2/users/<CurrectUserId>/identities/<ProviderName>/<LinkedUserId>"
    // and header "Authorization : Bearer <kAuth0APIv2Token>"
    
    NSString *apiToken = [NSBundle mainBundle].infoDictionary[kAuth0APIv2Token];
    NSString *bearerToken = [NSString stringWithFormat:@"Bearer %@", apiToken];
    NSDictionary *headers = @{ @"Authorization": bearerToken};
    
    if (!self.selectedLinkedUser && !self.linkedUserList.count) {
        return;
    }
    
    if (!self.selectedLinkedUser) {
        self.selectedLinkedUser = [[A0UserIdentity alloc] initWithJSONDictionary:self.linkedUserList[[self.linkedAccountPickerView selectedRowInComponent:0]]];
    }
    
    A0UserIdentity *userIdentity = self.selectedLinkedUser;
    NSString *provider = userIdentity.provider;
    NSString *linkedUserId = [userIdentity.userId stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet alphanumericCharacterSet]];
    NSString *userId = [self.profile.userId stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet alphanumericCharacterSet]];
    
    NSString *domain = [NSBundle mainBundle].infoDictionary[kAuth0Domain];
    NSString *urlString = [NSString stringWithFormat:@"https://%@/api/v2/users/%@/identities/%@/%@", domain, userId, provider, linkedUserId];
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
                                                        [self showMessage:[NSString stringWithFormat:@"%@", error]];
                                                    } else {
                                                        NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:&error];
                                                        NSLog(@"%@", dict);
                                                        if ([dict isKindOfClass:[NSDictionary class]]) {
                                                            if (dict[@"error"] || dict[@"errorCode"] || dict[@"statusCode"]) {
                                                                [self showMessage:[NSString stringWithFormat:@"%@", dict]];
                                                            }
                                                        } else if ([dict isKindOfClass:[NSArray class]]) {
                                                            [self fetchUserProfile];
                                                        }
                                                    }
                                                }];
    [dataTask resume];
}

// UIPickerViewDataSource delegate methods
- (NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView {
    return 1;
}

- (NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component {
    if (pickerView == self.usersPickerView) {
        return self.pickerData.count;
    } else if (pickerView == self.linkedAccountPickerView) {
        return self.linkedPickerData.count;
    }
    return 0;
}

- (NSString*)pickerView:(UIPickerView *)pickerView titleForRow:(NSInteger)row forComponent:(NSInteger)component {
    if (pickerView == self.usersPickerView) {
        return self.pickerData[row];
    } else if (pickerView == self.linkedAccountPickerView) {
        return self.linkedPickerData[row];
    }
    return 0;
}

- (void)pickerView:(UIPickerView *)pickerView didSelectRow:(NSInteger)row inComponent:(NSInteger)component {
    if (pickerView == self.usersPickerView) {
        self.selectedUser = [[A0UserProfile alloc] initWithDictionary:self.userList[row]];
    } else if (pickerView == self.linkedAccountPickerView) {
        self.selectedLinkedUser = self.linkedUserList[row];
    }
}

// Internal methods
- (void)setProfile:(A0UserProfile *)profile {
    _profile = profile;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        self.userName.text = profile.name;
        self.userId.text = profile.userId;
        self.userEmail.text = profile.email;
    });
}

- (void)createUserList:(NSDictionary *)userList {
    self.userList = [NSMutableArray arrayWithArray:userList[@"users"]];
    [self.pickerData removeAllObjects];
    for (NSDictionary *userDict in self.userList) {
        A0UserProfile *user = [[A0UserProfile alloc] initWithDictionary:userDict];
        NSString *name = user.name;
        if (name) {
            [self.pickerData addObject:name];
        } else {
            NSLog(@"NUL : %@", user);
            [self.pickerData addObject:user.userId];
        }
        
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.usersPickerView reloadAllComponents];
    });
}

- (void)showMessage:(NSString *)message {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"Auth0" message:message preferredStyle:UIAlertControllerStyleAlert];
        
        UIAlertAction* ok = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil];
        [alertController addAction:ok];
        
        [self presentViewController:alertController animated:YES completion:nil];
    });
}

- (void)createLinkedUserList:(NSArray *)userList {
    self.linkedUserList = [NSMutableArray arrayWithArray:userList];
    [self.linkedPickerData removeAllObjects];
    for (A0UserIdentity *userIdentity in self.linkedUserList) {
        if (userIdentity.profileData) {
            NSString *name = userIdentity.profileData[@"name"];
            NSString *username = userIdentity.profileData[@"username"];
            if (name) {
                [self.linkedPickerData addObject:name];
            } else if (username) {
                [self.linkedPickerData addObject:username];
            }
            
        } else {
            NSLog(@"WIHTOUT NAME : %@", userIdentity);
            [self.linkedPickerData addObject:userIdentity.userId];
        }
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.linkedAccountPickerView reloadAllComponents];
    });
}

@end
