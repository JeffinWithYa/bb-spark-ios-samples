/* Copyright (c) 2017 BlackBerry.  All Rights Reserved.
* 
* Licensed under the Apache License, Version 2.0 (the "License"); 
* you may not use this file except in compliance with the License. 
* You may obtain a copy of the License at 
* 
* http://www.apache.org/licenses/LICENSE-2.0 
* 
* Unless required by applicable law or agreed to in writing, software 
* distributed under the License is distributed on an "AS IS" BASIS, 
* WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. 
* See the License for the specific language governing permissions and 
* limitations under the License. 
  
* This sample code was created by BlackBerry using SDKs from Apple Inc. 
* and may contain code licensed for use only with Apple products. 
* Please review your Apple SDK Agreement for additional details. 
*/ 

#import "AccountViewController.h"
#import "ConfigSettings.h"

#import "BBMAccess.h"
#import "BBMGoogleTokenManager.h"
#import "BBMAuthController.h"
#import "BBMAuthenticatedAccount.h"
#import "BBMEndpointManager.h"

#import <BBMEnterprise/BBMEnterprise.h>
#import <GoogleSignIn/GIDSignInButton.h>


@interface AccountViewController () <BBMConnectivityListener, BBMAuthControllerDelegate>

@property (weak, nonatomic) IBOutlet UILabel *serviceStateLabel;
@property (weak, nonatomic) IBOutlet UILabel *authTokenStateLabel;
@property (weak, nonatomic) IBOutlet UILabel *setupStateLabel;
@property (weak, nonatomic) IBOutlet UILabel *regIdLabel;
@property (weak, nonatomic) IBOutlet UILabel *domainLabel;
@property (weak, nonatomic) IBOutlet UILabel *userEmailLabel;
@property (weak, nonatomic) IBOutlet UILabel *serviceConnectivityLabel;
@property (weak, nonatomic) IBOutlet UIButton *switchDeviceButton;
@property (weak, nonatomic) IBOutlet GIDSignInButton *googleSignInButton;
@property (weak, nonatomic) IBOutlet UIButton *signOutButton;

@property (nonatomic, strong) BBMAuthController *authController;
@property (nonatomic, strong) BBMEndpointManager *endpointManager;

@property (nonatomic, strong) ObservableMonitor *serviceMonitor;

@end

@implementation AccountViewController

- (void)viewDidLoad
{
    [super viewDidLoad];

    //Configure our buttons and labels
    self.googleSignInButton.hidden = YES;
    self.switchDeviceButton.enabled = NO;
    self.signOutButton.hidden = YES;
    self.domainLabel.text = SDK_SERVICE_DOMAIN;

    //Listen for connectivity changes to the BBM Enterprise Service
    [[BBMEnterpriseService service] addConnectivityListener:self];

    //Create an AuthController instance.  This view controller will act as the delegate and the
    //root controller for any modally presented auth UI.  We will use the BBMGoogleTokenManager
    //(a wrapper around the GoolgeSignIn API) to fetch tokens
    self.authController = [[BBMAuthController alloc] initWithTokenManager:[BBMGoogleTokenManager class]];
    self.authController.rootController = self;

    //Auth controller using delegation
    [self.authController addDelegate:self];


    /***********

    //Alternative: Auth controller using ObservableMonitor.  This approach monitors the serviceStarted
    //and authState properties on the authManager instance rather than registering the view controller
    //as an explicit delegate

    typeof(self) __weak weakSelf = self;
    self.serviceMonitor = [ObservableMonitor monitorActivatedWithName:@"serviceMonitor" block:^{
        [weakSelf serviceStateChanged:weakSelf.authController.serviceStarted];
        [weakSelf authStateChanged:weakSelf.authController.authState];
    }];
    
    *************/


    //Start the BBM Enterprise service.
    [self.authController startBBMEnterpriseService];

    //Resume our previous session
    [self.authController signInSilently];
}


#pragma mark - BBMAuthDelegate

//The AuthController will invoke this callback any time the user credentials/auth state changes
- (void)authStateChanged:(BBMAuthState *)authState
{
    self.authTokenStateLabel.text = authState.authTokenState ?: @"No Token";
    self.setupStateLabel.text = authState.setupState ?: @"Setup Not Started";
    self.regIdLabel.text = authState.regId.integerValue ? authState.regId.stringValue : @"";
    self.userEmailLabel.text = authState.account.email;

    self.googleSignInButton.hidden = self.authController.startedAndAuthenticated;
    self.signOutButton.hidden = !self.authController.startedAndAuthenticated;

    //Whenever a user switches devices, a device switch should occur. This button gets
    //enabled whenever a device switch is required.
    self.switchDeviceButton.enabled = [authState.setupState isEqualToString:kBBMSetupStateDeviceSwitch];

    //In order to complete the setup process, we must syncronize the profile keys.  For the sake of
    //brevity, we will simply set the key state to synced.  See the other BBM Enterprise samples
    //and/or BBMKeyManager in /examples/support for details on how to export/import profile keys
    if([authState.setupState isEqualToString:kBBMSetupStateOngoing] &&
       [[[[BBMEnterpriseService service] model] globalProfileKeysState] isEqualToString:kBBMKeyStateNotSynced])
    {
        NSDictionary* element = @{@"name":@"profileKeysState", @"value": @"Synced" };
        BBMRequestListChangeMessage *syncProfileKey = [[BBMRequestListChangeMessage alloc] initWithElements:@[element] type:@"global"];
        [[BBMEnterpriseService service] sendMessageToService:syncProfileKey];
    }

    // If state is full, ask for list of endpoints and remove one so that setup can continue.
    if([authState.setupState isEqualToString:kBBMSetupStateFull]) {
        self.endpointManager = [[BBMEndpointManager alloc] init];
        [self.endpointManager deregisterAnyEndpointAndContinueSetup];
    }

    [self.tableView reloadData];
}

- (void)serviceStateChanged:(BOOL)serviceStarted
{
    self.serviceStateLabel.text = serviceStarted ? @"Started" : @"Stopped";
    [self.tableView reloadData];
}

#pragma mark - BBMConnectivityListener

- (void)connectivityStateChange:(BOOL)connected strict:(BOOL)connectedStrict
{
    self.serviceConnectivityLabel.text = connected ? @"Connected" : @"Disconnected";
}


#pragma mark - UI Actions

- (IBAction)switchDevice:(id)sender
{
    [BBMAccess sendSetupRetry];
}

- (IBAction)signOut:(id)sender
{
    //Wipe all local BBM data
    [[BBMEnterpriseService service] resetService];
    [self.authController signOut];
}


@end