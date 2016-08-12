
//
//  USUserContactManager.m
//  HTWallet
//
//  Created by jansti on 16/7/20.
//  Copyright © 2016年 MaRuJun. All rights reserved.
//

#import "USUserContactManager.h"
#import <Contacts/Contacts.h>
#import <AddressBook/AddressBook.h>

#define kUserContactsFilePath ([DocumentPath stringByAppendingPathComponent:@"Contacts"])

@interface USUserContactManager()

@property (nonatomic, strong) NSMutableArray *userContactsM; // 只包含联系人名字电话数组

@property (nonatomic, strong) CNContactStore *contactStore;
@property (nonatomic, strong) NSMutableArray *contectsM;  // 联系人数组

@property (nonatomic, assign) ABAddressBookRef addBookRef;


@end

@implementation USUserContactManager


+ (instancetype)defaultManager
{
    static dispatch_once_t pred = 0;
    __strong static id defaultContactManager = nil;
    dispatch_once( &pred, ^{
        defaultContactManager = [[self alloc] init];
    });
    return defaultContactManager;
}

- (instancetype)init{
    self = [super init];
    if (self) {
        _contectsM = [NSMutableArray array];
        NSFileManager *fileManager = [NSFileManager defaultManager];
        if (![fileManager fileExistsAtPath:kUserContactsFilePath]) {
            [fileManager createDirectoryAtPath:kUserContactsFilePath withIntermediateDirectories:YES attributes:nil error:nil];
        }
    }
    
    return self;
}

+ (NSArray *)userContacts{
    
    NSFileManager *fileMagager = [NSFileManager defaultManager];
    NSString *contactsPlistPath = [kUserContactsFilePath stringByAppendingPathComponent:@"contacts.plist"];
    if ([fileMagager fileExistsAtPath:contactsPlistPath]) {
        NSArray *userContacts = [NSArray arrayWithContentsOfFile:contactsPlistPath];
        return userContacts;
    }else{
        return nil;
    }
}

+ (void)acquireUserContacts{
    [[self defaultManager] acquireUserContacts];
}

+ (BOOL)userAuthorizationAllowed{
    
    BOOL hasGetAuth = NO;
    if (NSClassFromString(@"CNContact") && [[[UIDevice currentDevice] systemVersion] floatValue] > 9.0) {
        
        CNAuthorizationStatus status = [CNContactStore authorizationStatusForEntityType:CNEntityTypeContacts];
        if (status == CNAuthorizationStatusAuthorized) {
            hasGetAuth = YES;
        }
    }else{
        
        ABAuthorizationStatus status = ABAddressBookGetAuthorizationStatus();
        if (status == kABAuthorizationStatusAuthorized) {
            hasGetAuth = YES;
        }
    }
    
    return hasGetAuth;
}

- (void )acquireUserContacts{
    
    NSArray *array = [[self class] userContacts];
    if (array) {
        [[NSNotificationCenter defaultCenter] postNotificationName:Notification_ContactsCollectDone object:nil];
        return;
    }
    
    if (NSClassFromString(@"CNContact") && [[[UIDevice currentDevice] systemVersion] floatValue] > 9.0) {
        [self getContactsUsingContact];
    }else{
        [self getContactsUsingABAddressBook];
    }
}


#pragma mark - CNContact

- (void)getContactsUsingContact{
    
    CNAuthorizationStatus status = [CNContactStore authorizationStatusForEntityType:CNEntityTypeContacts];
    _contactStore = [[CNContactStore alloc] init];
    switch (status) {
        case CNAuthorizationStatusNotDetermined:{
            [_contactStore requestAccessForEntityType:CNEntityTypeContacts completionHandler:^(BOOL granted, NSError * _Nullable error) {
                
                if (granted && !error) {
                    [self accessUerContact];
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [[NSNotificationCenter defaultCenter] postNotificationName:Notification_ContactsAuthorized object:@(YES)];
                    });
                    
                }else{
                    dispatch_async(dispatch_get_main_queue(), ^{
                        NSLog(@"用户没有允许通讯录权限");
                        [self showAuthorityHint];
                    });
                }
            }];
        }
            break;
        case CNAuthorizationStatusRestricted:
            NSLog(@"用户通讯录权限被限制");
            break;
        case CNAuthorizationStatusDenied:{
            dispatch_async(dispatch_get_main_queue(), ^{
                NSLog(@"用户没有允许通讯录权限");
                [self showAuthorityHint];
            });
        }
            break;
        case CNAuthorizationStatusAuthorized:
            [self accessUerContact];
            dispatch_async(dispatch_get_main_queue(), ^{
                [[NSNotificationCenter defaultCenter] postNotificationName:Notification_ContactsAuthorized object:@(YES)];
            });
            break;
            
        default:
            break;
    }
}

- (void)accessUerContact{
    
    NSArray *keysToFetch = @[[CNContactFormatter descriptorForRequiredKeysForStyle:CNContactFormatterStyleFullName],
                             CNContactPhoneNumbersKey];
    CNContactFetchRequest *fetchRequest = [[CNContactFetchRequest alloc] initWithKeysToFetch:keysToFetch];
    
    
    BOOL success =  [_contactStore enumerateContactsWithFetchRequest:fetchRequest error:nil usingBlock:^(CNContact * _Nonnull contact, BOOL * _Nonnull stop) {
        [_contectsM addObject:contact];
    }];
    
    if (success) {
        [self setupContactsArrayUsingCN];
    }else{
        NSLog(@"获取用户通讯录数据异常");
    }
    
}

- (void)setupContactsArrayUsingCN{
    
    _userContactsM = [NSMutableArray array];
    [_contectsM enumerateObjectsUsingBlock:^(CNContact *contact, NSUInteger idx, BOOL * _Nonnull stop) {
        NSString *name = [CNContactFormatter stringFromContact:contact style:CNContactFormatterStyleFullName];
        NSArray *phoneLabelArray = contact.phoneNumbers;
        NSMutableArray *phoneNumbersM = [NSMutableArray array];
        [phoneLabelArray enumerateObjectsUsingBlock:^(CNLabeledValue* phoneLabel, NSUInteger idx, BOOL * _Nonnull stop) {
            CNPhoneNumber *phoneNumber = phoneLabel.value;
            NSString *phone = phoneNumber.stringValue;
            [phoneNumbersM addObject:phone];
        }];
        if (phoneNumbersM.count) {
            NSDictionary *dict = @{
                                   @"name":name,
                                   @"phone":phoneNumbersM
                                   };
            [_userContactsM addObject:dict];
        }
        
    }];
    
    NSString *filePath = [kUserContactsFilePath stringByAppendingPathComponent:@"contacts.plist"];
    [_userContactsM writeToFile:filePath atomically:YES];
    _userContactsM = nil;
    _contectsM = nil;
    _contactStore = nil;
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:Notification_ContactsCollectDone object:nil];
    });
    
}


#pragma mark - ABAddressBoo

- (void)getContactsUsingABAddressBook{
    
    _addBookRef = ABAddressBookCreateWithOptions(NULL, NULL); // need to be release
    
    ABAuthorizationStatus status = ABAddressBookGetAuthorizationStatus();
    switch (status) {
        case kABAuthorizationStatusNotDetermined:{
            ABAddressBookRequestAccessWithCompletion(_addBookRef, ^(bool granted, CFErrorRef error) {
                if (granted) {
                    [self accessUerABAddress];
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [[NSNotificationCenter defaultCenter] postNotificationName:Notification_ContactsAuthorized object:@(YES)];
                    });
                }else{
                    dispatch_async(dispatch_get_main_queue(), ^{
                         NSLog(@"用户没有允许通讯录权限");
                        [self showAuthorityHint];
                    });
                }
            });
        }
            break;
        case kABAuthorizationStatusRestricted:
             NSLog(@"用户没有通讯录权限被限制");
            [self showAuthorityHint];
            break;
        case kABAuthorizationStatusDenied:
             NSLog(@"用户没有允许通讯录权限");
            [self showAuthorityHint];
            break;
        case kABAuthorizationStatusAuthorized:
            [self accessUerABAddress];
            dispatch_async(dispatch_get_main_queue(), ^{
                [[NSNotificationCenter defaultCenter] postNotificationName:Notification_ContactsAuthorized object:@(YES)];
            });
            break;
            
            
        default:
            break;
    }

   
}

- (void)accessUerABAddress{
    
    CFArrayRef allLinkPeople = ABAddressBookCopyArrayOfAllPeople(_addBookRef); // need to release
    CFIndex number = ABAddressBookGetPersonCount(_addBookRef);
    
    _userContactsM = [NSMutableArray array];
    for (int i = 0; i < number; i++) {
        
        ABRecordRef  people = CFArrayGetValueAtIndex(allLinkPeople, i);
        
        NSString*firstName=(__bridge_transfer NSString *)(ABRecordCopyValue(people, kABPersonFirstNameProperty));
        NSString*lastName=(__bridge_transfer NSString *)(ABRecordCopyValue(people, kABPersonLastNameProperty));
        NSString*middleName=(__bridge_transfer NSString*)(ABRecordCopyValue(people, kABPersonMiddleNameProperty));
        
        NSMutableString *name = [NSMutableString string];
        if (lastName) {
            [name appendString:lastName];
        }
        if (middleName) {
            [name appendString:middleName];
        }
        if (firstName) {
            [name appendString:firstName];
        }
        
        NSMutableArray * phoneNumbersM = [[NSMutableArray alloc]init];
        ABMultiValueRef phones= ABRecordCopyValue(people, kABPersonPhoneProperty);
        for (NSInteger j=0; j < ABMultiValueGetCount(phones); j++) {
            [phoneNumbersM addObject:(__bridge_transfer NSString *)(ABMultiValueCopyValueAtIndex(phones, j))];
        }
        CFRelease(phones);
        
        if (phoneNumbersM.count) {
            NSDictionary *dict = @{
                                   @"name":name,
                                   @"phone":phoneNumbersM
                                   };
            [_userContactsM addObject:dict];
        }
    }
    CFRelease(allLinkPeople);
    CFRelease(_addBookRef);
    _addBookRef = NULL;
    
    NSString *filePath = [kUserContactsFilePath stringByAppendingPathComponent:@"contacts.plist"];
    [_userContactsM writeToFile:filePath atomically:YES];
    _userContactsM = nil;
    _contectsM = nil;
    _addBookRef = NULL;
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:Notification_ContactsCollectDone object:nil];
    });
    

}

#pragma mark - Function

- (void)showAuthorityHint{
    
    [[NSNotificationCenter defaultCenter] postNotificationName:Notification_ContactsAuthorized object:@(NO)];
//    NSString *appName = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleIdentifier"];
//    if (&UIApplicationOpenSettingsURLString) {
//        USAlertView *alert = [USAlertView initWithTitle:@"您的通讯录权限被禁止" message:[NSString stringWithFormat:@"请在设置-%@-通讯录权限中开启",appName] cancelButtonTitle:@"取消" otherButtonTitles:@"去开启", nil];
//        [alert showWithCompletionBlock:^(NSInteger buttonIndex) {
//            if (buttonIndex == 1) {
//                [[UIApplication sharedApplication] openURL:[NSURL URLWithString:UIApplicationOpenSettingsURLString]];
//            }
//        }];
//    } else {
//        [USAlertView showWithMessage:[NSString stringWithFormat:@"请在设备的\"设置-隐私-通讯录\"中允许访问通讯录."]];
//    }

}

@end
