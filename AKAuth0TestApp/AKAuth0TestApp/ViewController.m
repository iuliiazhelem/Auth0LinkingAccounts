//
//  ViewController.m
//  AKAuth0TestApp
//
//  Created by Iuliia Zhelem on 14.06.16.
//  Copyright © 2016 Akvelon. All rights reserved.
//

#import "ViewController.h"
#import "AppDelegate.h"
#import <Lock/Lock.h>

//Please use your Auth0 APIv2 token from https://auth0.com/docs/api/management/v2/tokens
static NSString *kAuth0APIv2Token = @"eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJJdUFiSnZvZXpwZTFFWUM2ZVhRRUoyd0QwSm5MOE5IZSIsInNjb3BlcyI6eyJ1c2VycyI6eyJhY3Rpb25zIjpbInJlYWQiLCJ1cGRhdGUiXX19LCJpYXQiOjE0Njc0NTc5NTAsImp0aSI6ImYwYmM4MTg4ODVmMjkxZDVjYTZlN2I0ZTM0MTRmN2MwIn0.NHagVjzpdsvtGlNaiFa5HneahioU5I-JnOWX7-VDRmA";


//Please use your Auth0 Domain
static NSString *kAppRequestUrl = @"https://juliazhelem.eu.auth0.com";

static NSString *kAuth0ConnectionType = @"Username-Password-Authentication";

@interface ViewController ()

@property (strong, nonatomic) A0Token *token;
@property (strong, nonatomic) A0UserProfile *profile;
@property (strong, nonatomic) NSMutableArray *pickerData;
@property (strong, nonatomic) NSMutableArray *userList;
@property (strong, nonatomic) A0UserProfile *selectedUser;

@property (strong, nonatomic) NSMutableArray *linkedPickerData;
@property (strong, nonatomic) NSMutableArray *linkedUserList;
@property (strong, nonatomic) A0UserIdentity *selectedLinkedUser;

@property (weak, nonatomic) IBOutlet UITextField *emailTextField;
@property (weak, nonatomic) IBOutlet UITextField *passwordTextField;
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

- (void)setProfile:(A0UserProfile *)profile {
    _profile = profile;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        self.userName.text = profile.name;
        self.userId.text = profile.userId;
        self.userEmail.text = profile.email;
    });
}

- (IBAction)clickGetUserList:(id)sender {
    NSString *bearerToken = [NSString stringWithFormat:@"Bearer %@", kAuth0APIv2Token];
    NSDictionary *headers = @{ @"Authorization": bearerToken };
    
    NSString *urlString = [NSString stringWithFormat:@"%@/api/v2/users?include_totals=true&include_fields=true&search_engine=v2", kAppRequestUrl];
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
                                                        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *) response;
                                                        NSLog(@"%@", httpResponse);
                                                        NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:&error];
                                                        NSLog(@"%@", dict);
                                                        [self createUserList:dict];
                                                    }
                                                }];
    [dataTask resume];
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


- (IBAction)clickLinkButton:(id)sender {
   
    NSString *token = [NSString stringWithFormat:@"Bearer %@", kAuth0APIv2Token];
    NSDictionary *headers = @{ @"content-type": @"application/json",
                               @"Authorization": token};
    
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
    
    NSString *strBody = [[NSString alloc] initWithData:dataFromDict encoding:NSUTF8StringEncoding];
    NSLog(@"BODY : %@", strBody);
    
    
    userId = [self.profile.userId stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet alphanumericCharacterSet]];
    NSString *urlString = [NSString stringWithFormat:@"%@/api/v2/users/%@/identities", kAppRequestUrl, userId];
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

- (IBAction)clickUnlinkButton:(id)sender {
    NSString *token = [NSString stringWithFormat:@"Bearer %@", kAuth0APIv2Token];
    NSDictionary *headers = @{ @"Authorization": token};
    
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
    NSString *urlString = [NSString stringWithFormat:@"%@/api/v2/users/%@/identities/%@/%@", kAppRequestUrl, userId, provider, linkedUserId];
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

- (IBAction)clickLinkedAccounts:(id)sender {
    [self fetchUserProfile];
}

- (IBAction)clickLoginButton:(id)sender {
    if (self.emailTextField.text.length < 1) {
        [self showMessage:@"You need to eneter email"];
        return;
    }
    if (self.passwordTextField.text.length < 1) {
        [self showMessage:@"You need to eneter password"];
        return;
    }
    
    NSString *email = self.emailTextField.text;
    NSString *password = self.passwordTextField.text;
    A0APIClient *client = [[A0Lock sharedLock] apiClient];
    A0APIClientAuthenticationSuccess success = ^(A0UserProfile *profile, A0Token *token) {
        self.token = token;
        self.profile = profile;
        [self createLinkedUserList:profile.identities];
    };
    A0APIClientError error = ^(NSError *error){
        NSLog(@"Oops something went wrong: %@", error);
        [self showMessage:[NSString stringWithFormat:@"%@", error]];
    };
    A0AuthParameters *params = [A0AuthParameters newDefaultParams];
    params[A0ParameterConnection] = kAuth0ConnectionType; // Or your configured DB connection
    [client loginWithUsername:email
                     password:password
                   parameters:params
                      success:success
                      failure:error];
}

- (void)showMessage:(NSString *)message
{
    dispatch_async(dispatch_get_main_queue(), ^{
        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"Auth0" message:message preferredStyle:UIAlertControllerStyleAlert];
        
        UIAlertAction* ok = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil];
        [alertController addAction:ok];
        
        [self presentViewController:alertController animated:YES completion:nil];
    });
}

// The number of columns of data
- (NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView
{
    return 1;
}

// The number of rows of data
- (NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component
{
    if (pickerView == self.usersPickerView) {
        return self.pickerData.count;
    } else if (pickerView == self.linkedAccountPickerView) {
        return self.linkedPickerData.count;
    }
    return 0;
}

// The data to return for the row and component (column) that's being passed in
- (NSString*)pickerView:(UIPickerView *)pickerView titleForRow:(NSInteger)row forComponent:(NSInteger)component
{
    if (pickerView == self.usersPickerView) {
        return self.pickerData[row];
    } else if (pickerView == self.linkedAccountPickerView) {
        return self.linkedPickerData[row];
    }
    return 0;
}

- (void)pickerView:(UIPickerView *)pickerView didSelectRow:(NSInteger)row inComponent:(NSInteger)component
{
    if (pickerView == self.usersPickerView) {
        self.selectedUser = [[A0UserProfile alloc] initWithDictionary:self.userList[row]];
    } else if (pickerView == self.linkedAccountPickerView) {
        self.selectedLinkedUser = self.linkedUserList[row];
    }
}

@end
