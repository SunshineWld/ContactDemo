//
//  USUserContactManager.h
//  HTWallet
//
//  Created by jansti on 16/7/20.
//  Copyright © 2016年 MaRuJun. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#define DocumentPath        [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject]    //获取Document文件夹的路径
#define kUserContactsFilePath ([DocumentPath stringByAppendingPathComponent:@"Contacts"])

#define Notification_ContactsCollectDone                              @"ContactsCollectDone"                  //通讯录数据收集完成
#define Notification_ContactsAuthorized                              @"ContactsAuthorized"                   //通讯录权限获取成功

@interface USUserContactManager : NSObject

+ (void)acquireUserContacts;

+ (NSArray *)userContacts;

+ (BOOL)userAuthorizationAllowed;

@end
