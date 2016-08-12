//
//  ViewController.m
//  ContactDemo
//
//  Created by wanglidan on 16/8/3.
//  Copyright © 2016年 wanglidan. All rights reserved.
//

#import "ViewController.h"
#import <Contacts/Contacts.h>
#import <ContactsUI/ContactsUI.h>
#import <AddressBook/AddressBook.h>
#import <AddressBookUI/AddressBookUI.h>

#define DocumentPath        [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject]    //获取Document文件夹的路径
#define kUserContactsFilePath ([DocumentPath stringByAppendingPathComponent:@"Contacts"])


@interface ViewController ()<ABPeoplePickerNavigationControllerDelegate, CNContactPickerDelegate>

@property (nonatomic,assign) ABAddressBookRef addressRef;
@property (nonatomic,strong) CNContactStore *contactStore;
@property (nonatomic, strong) NSMutableArray *userContactsM; // 只包含联系人名字电话数组
@property (nonatomic, strong) NSMutableArray *contectsM;  // 联系人数组


@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    _contectsM = [NSMutableArray array];

}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}
- (IBAction)contactAction:(id)sender
{
    CNContactPickerViewController *pickerVC = [[CNContactPickerViewController alloc] init];
    pickerVC.delegate = self;
    [self presentViewController:pickerVC animated:YES completion:nil];
    
}

- (IBAction)addressAction:(id)sender
{
    ABPeoplePickerNavigationController *nav = [[ABPeoplePickerNavigationController alloc] init];
    nav.peoplePickerDelegate = self;
    //在iOS8之后，需要添加下面的代码，否侧选择联系人之后会直接dismiss，不能进入详情
    if ([[[UIDevice currentDevice] systemVersion] floatValue] > 8.0) {
        nav.predicateForSelectionOfPerson = [NSPredicate predicateWithValue:false];
    }
    [self presentViewController:nav animated:YES completion:nil];
}
#pragma mark -delegate
- (void)peoplePickerNavigationControllerDidCancel:(ABPeoplePickerNavigationController *)peoplePicker
{
    [peoplePicker dismissViewControllerAnimated:YES completion:nil];
}
- (void)peoplePickerNavigationController:(ABPeoplePickerNavigationController *)peoplePicker didSelectPerson:(ABRecordRef)person property:(ABPropertyID)property identifier:(ABMultiValueIdentifier)identifier
{
    
}
- (void)peoplePickerNavigationController:(ABPeoplePickerNavigationController *)peoplePicker didSelectPerson:(ABRecordRef)person
{
    ABPersonViewController *personVC = [[ABPersonViewController alloc] init];
    personVC.displayedPerson = person;
    [peoplePicker pushViewController:personVC animated:YES];
}
//校验是否有读取通讯录的权限
- (void)getContactsWithAddressBook
{
    _addressRef = ABAddressBookCreateWithOptions(NULL, NULL);
    
    ABAuthorizationStatus statu = ABAddressBookGetAuthorizationStatus();

    switch (statu) {
        case kABAuthorizationStatusNotDetermined:{
            NSLog(@"未授权");
            ABAddressBookRequestAccessWithCompletion(_addressRef, ^(bool granted, CFErrorRef error) {
                if (granted) {
                    //允许访问
                    [self accessUerABAddress];
                }else{
                    NSLog(@"用户拒绝授权");
                }
            });
        }
            break;
        case kABAuthorizationStatusRestricted:
            NSLog(@"受限制");
            break;
        case kABAuthorizationStatusDenied:
            NSLog(@"用户拒绝");
            break;
        case kABAuthorizationStatusAuthorized:
            NSLog(@"已授权");
            [self accessUerABAddress];
            break;
        default:
            break;
    }
}
//获取用户通讯录
- (void)accessUerABAddress
{
//    AddressBook framework 为我们提供了 ABAddressBookCopyArrayOfAllPeople 方法获取通讯录所有人的记录。然后我们可以通过ABRecordCopyValue读取记录中属性
    
    /*两者的区别 ABAddressBookCopyArrayOfAllPeople 和 enumerateContactsWithFetchRequest
     1.返回值不一样，前者调用后直接通过数组的形式返回所有的联系人信息；后者则返回成功或失败，联系人信息则通过usingBlock返回
     2.参数不一样，前者需要接收一个AddressBook对象，后者则是CNContactStore对象中的一个成员函数，但他需要接收一个CNContactFetchRequest对象，告诉它我们需要获取哪些属性信息。
     */
    _userContactsM = [NSMutableArray array];
    
    CFArrayRef arrayRef = ABAddressBookCopyArrayOfAllPeople(_addressRef);
    CFIndex number =  ABAddressBookGetPersonCount(_addressRef);
    
    for (int i = 0; i < number; i++) {
        ABRecordRef people = CFArrayGetValueAtIndex(arrayRef, i);
        NSString *firstName = (__bridge NSString *)(ABRecordCopyValue(people, kABPersonLastNameProperty));
        NSString *lastName = (__bridge NSString *)(ABRecordCopyValue(people, kABPersonFirstNameProperty));
        NSString *middleName = (__bridge NSString *)(ABRecordCopyValue(people, kABPersonMiddleNameProperty));
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
        
        NSMutableArray *phoneNumbersM = [[NSMutableArray alloc] init];
        ABMultiValueRef phones = ABRecordCopyValue(people, kABPersonPhoneProperty);
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
    CFRelease(arrayRef);
    CFRelease(_addressRef);
    _addressRef = NULL;
    
    NSString *filePath = [kUserContactsFilePath stringByAppendingPathComponent:@"contacts.plist"];
    [_userContactsM writeToFile:filePath atomically:YES];
    _userContactsM = nil;
    _contectsM = nil;
    _addressRef = NULL;
    
    
}
- (void)getContactsWithContact
{
    _contactStore = [[CNContactStore alloc] init];
    CNAuthorizationStatus statu = [CNContactStore authorizationStatusForEntityType:CNEntityTypeContacts];
    switch (statu) {
        case CNAuthorizationStatusNotDetermined:{
            NSLog(@"未授权");
            [_contactStore requestAccessForEntityType:CNEntityTypeContacts completionHandler:^(BOOL granted, NSError * _Nullable error) {
                if (granted) {
                    //允许访问
                    [self accessUserContact];
                }else{
                    NSLog(@"用户拒绝授权");
                }
            }];
        }
            break;
        case CNAuthorizationStatusRestricted:
            NSLog(@"受限制");
            break;
        case CNAuthorizationStatusDenied:
            NSLog(@"用户拒绝");
            break;
        case CNAuthorizationStatusAuthorized:
            NSLog(@"已授权");
            [self accessUserContact];
            break;
            
        default:
            break;
    }
    
}
- (void)accessUserContact
{
//    Contacts framework 为我们通过 enumerateContactsWithFetchRequest 方法获取通讯录的联系人信息，我们需要同CNContactFetchRequest指定获取联系人信息的属性
    
    NSArray  *keysToFetch = @[[CNContactFormatter descriptorForRequiredKeysForStyle:CNContactFormatterStyleFullName], CNContactPhoneNumbersKey];
    
    CNContactFetchRequest *request = [[CNContactFetchRequest alloc] initWithKeysToFetch:keysToFetch];
    
    BOOL success = [_contactStore enumerateContactsWithFetchRequest:request error:nil usingBlock:^(CNContact * _Nonnull contact, BOOL * _Nonnull stop) {
        [_contectsM addObject:contact];
    }];
    
    if (success) {
        [self setupContactsArrayUsingCN];
    }else{
        NSLog(@"获取用户通讯录数据异常");
    }
    
}
- (void)setupContactsArrayUsingCN
{
    _userContactsM = [NSMutableArray array];
    [_contectsM enumerateObjectsUsingBlock:^(CNContact *contact, NSUInteger idx, BOOL * _Nonnull stop) {
        NSString *name = [CNContactFormatter stringFromContact:contact style:CNContactFormatterStyleFullName];
        NSArray *phoneArray = contact.phoneNumbers;
        NSMutableArray *phoneNumbersM = [NSMutableArray array];
        [phoneArray enumerateObjectsUsingBlock:^(CNLabeledValue *phoneLabel, NSUInteger idx, BOOL * _Nonnull stop) {
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
}

@end
















