//
//  DLHAddressBookManager.h
//  DLHAddressBookManager
//
//  Created by Duan on 2019/3/7.
//  Copyright © 2019 Duan. All rights reserved.
//

#import "DLHAddressBookManager.h"

#import <AddressBook/AddressBook.h>
#import <Contacts/Contacts.h>

#define CurrentVersion [[[UIDevice currentDevice] systemVersion] floatValue]
// 归档文件名
#define ArchiverKey @"DLHAddressBookManager.Archiver.data"

@interface DLHAddressBookManager ()<UIAlertViewDelegate>
/// 用于归档存储的数组
@property (nonatomic,strong) NSMutableArray *cacheArray;

@end


@implementation DLHAddressBookManager
#pragma mark - ============== 单例的初始化方法 ================
static DLHAddressBookManager *_instance = nil;
+(instancetype)shareInstance
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _instance = [[super allocWithZone:NULL] init];
        [_instance setDefaultData];
    });
    return _instance;
}
+(id)allocWithZone:(struct _NSZone *)zone
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _instance = [[super allocWithZone:zone] init];
        [_instance setDefaultData];
    });
    return _instance;
}
- (id)copyWithZone:(nullable NSZone *)zone
{
    return [DLHAddressBookManager shareInstance];
}
- (id)mutableCopyWithZone:(nullable NSZone *)zone
{
    return [DLHAddressBookManager shareInstance];
}

#pragma mark - ============== 设置默认参数 ================
- (void)setDefaultData
{
    NSString *appName = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleDisplayName"];
    // 自定义弹框消息
    self.refuseUseABMsg = [NSString stringWithFormat:@"请在iPhone的\"设置-隐私-通讯录\"选项中,允许%@访问你的通讯录",appName];
    // 用户拒绝之后 继续弹框
    self.firstRefuseShowAlert = YES;
    
    // 设置默认返回数据格式
    self.dataStyle = DLHAddressBookDataStyle_Default;
    
    // 初始化归档用的数组
    self.cacheArray = [[NSMutableArray alloc] init];
}
#pragma mark - ============== 是否有权限获取通讯录的方法并弹框 ================
- (void)requestAuthorizationAddressBook:(void(^)(BOOL granted))completionHandler
{
    // iOS9 之后 和 9之前 两种获取用于通讯录授权的状态方法
    if (@available(iOS 9.0, *)) {
        // 获取用户的通讯录 授权状态
        CNAuthorizationStatus status = [CNContactStore authorizationStatusForEntityType:CNEntityTypeContacts];
        // 是否弹框让用户做出授权选择
        if (status == CNAuthorizationStatusNotDetermined) {
            // 申请权限
            CNContactStore * store = [[CNContactStore alloc] init];
            [store requestAccessForEntityType:CNEntityTypeContacts completionHandler:^(BOOL granted, NSError * _Nullable error) {
                if (!granted) {
                    // 授权失败
                    [self showAlertToGetUserAddressBook];
                }
                if (completionHandler) {
                    completionHandler(granted);
                }
            }];
        }else if (status == CNAuthorizationStatusAuthorized){
            // 拿到通讯录的权限
            if (completionHandler) {
                completionHandler(YES);
            }
        }else{
            // 用户的通讯录 不能正常访问(包括用户拒绝，或者b存在活动的限制)
            if (completionHandler) {
                completionHandler(NO);
            }
            [self showAlertToGetUserAddressBook];
        }
    } else {
        // 获取用户的通讯录 授权状态
        ABAuthorizationStatus status =ABAddressBookGetAuthorizationStatus();
        // 是否弹框让用户做出授权选择
        if (status ==kABAuthorizationStatusNotDetermined) {
            // 请求授权
            ABAddressBookRef addressBookRef =ABAddressBookCreate();
            ABAddressBookRequestAccessWithCompletion(addressBookRef, ^(bool granted, CFErrorRef error) {
                if (!granted) {
                    // 授权失败
                    [self showAlertToGetUserAddressBook];
                }
                if (completionHandler) {
                    completionHandler(granted);
                }
            });
        }else if (status == kABAuthorizationStatusAuthorized){
            // 拿到通讯录的权限
            if (completionHandler) {
                completionHandler(YES);
            }
        }else{
            // 用户的通讯录 不能正常访问(包括用户拒绝，或者b存在活动的限制)
            if (completionHandler) {
                completionHandler(NO);
            }
            [self showAlertToGetUserAddressBook];
        }
    }
}
#pragma mark - ============== 直接获取通讯录granted是否获取成功 ================
-(void)getAddressBookData:(void (^)(NSArray * _Nullable, BOOL))completionHandler useCache:(BOOL)useCache
{
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    // 判断是否有权限获取通讯录
    [self requestAuthorizationAddressBook:^(BOOL granted) {
        if (granted) {
            // 每次获取之前先移除缓存数组，然后进行缓存
            [self.cacheArray removeAllObjects];
            if (@available(iOS 9.0, *)) {
                dispatch_async(queue, ^{
                    [self getAboveVer9AddressBook:^(NSArray *addressBookArray) {
                        // 数据归档
                        [self cacheAddressBookData];
                        dispatch_async(dispatch_get_main_queue(), ^{
                            if (completionHandler) {
                                completionHandler(addressBookArray,granted);
                            }
                        });
                    }];
                });
            }else{
                dispatch_async(queue, ^{
                    [self getBelowVer9AddressBook:^(NSArray *addressBookArray) {
                        // 数据归档
                        [self cacheAddressBookData];
                        dispatch_async(dispatch_get_main_queue(), ^{
                            if (completionHandler) {
                                completionHandler(addressBookArray,granted);
                            }
                        });
                    }];
                });
            }
        }else{
            // 没有获取到通讯录数据
            if (completionHandler) {
                dispatch_async(queue, ^{
                    NSArray *data = [self getcacheAddressBookData];
                    dispatch_async(dispatch_get_main_queue(), ^{
                        completionHandler(useCache ? [self getcacheAddressBookData] : data,granted);
                    });
                });
            }
        }
    }];
}
// iOS9 之后获取通讯录的方法
- (void)getAboveVer9AddressBook:(void(^)(NSArray *addressBookArray))completionHandler
{
    if (@available(iOS 9.0, *)) {

        CNContactStore * store = [[CNContactStore alloc] init];
        CNContactFetchRequest * request = [[CNContactFetchRequest alloc] initWithKeysToFetch:@[CNContactGivenNameKey, CNContactFamilyNameKey, CNContactPhoneNumbersKey]];
        // 存储我们需要的格式的数组
        NSMutableArray *dataArray = [[NSMutableArray alloc] init];
        
        [store enumerateContactsWithFetchRequest:request error:nil usingBlock:^(CNContact * _Nonnull contact, BOOL * _Nonnull stop) {
            // 我们需要的姓名是 姓+名
            NSString *nickName = [NSString stringWithFormat:@"%@%@",contact.familyName,contact.givenName];
            // 我们需要的是手机号，遍历本条号码数组，得到一个手机号就 退出当前循环
            NSArray *phoneArray = contact.phoneNumbers;
            for (CNLabeledValue *labelValue in phoneArray) {
                CNPhoneNumber *phoneNumber = labelValue.value;
                // 获取到数字字符串 并且删除以86开头的 86
                NSString *phoneNumStr = [self findNumFromString:phoneNumber.stringValue delete86:YES];
                if ([self validatePhoneNumber:phoneNumStr]) {
                    [self setReturnDataInDataArray:dataArray nickName:nickName phoneNum:phoneNumStr];
                    // 此处不能使用break跳出循环，因为有的nickName对应多个手机号 break会只添加一个手机号就跳出循环
                    continue;
                }
            }
        }];
        completionHandler(dataArray);
    }
}

// iOS9 之前获取通讯录的方法
- (void)getBelowVer9AddressBook:(void(^)(NSArray *addressBookArray))completionHandler
{
    if (CurrentVersion < 9.0) {
        ABAddressBookRef addressRef = ABAddressBookCreateWithOptions(nil, nil);
        CFArrayRef dataArr = ABAddressBookCopyArrayOfAllPeople(addressRef);
        // 存储我们需要的格式的数组
        NSMutableArray *dataArray = [[NSMutableArray alloc] init];
        
        for (int i = 0; i < CFArrayGetCount(dataArr); i ++) {
            ABRecordRef person = CFArrayGetValueAtIndex(dataArr, i);
            // 姓
            NSString *familyName = (__bridge NSString *)ABRecordCopyValue(person, kABPersonLastNameProperty);
            // 名
            NSString *givenName = (__bridge NSString *)ABRecordCopyValue(person, kABPersonFirstNameProperty);
            // 我们需要的姓名是 姓+名
            NSString *nickName = [NSString stringWithFormat:@"%@%@",familyName,givenName];
            
            // 每个联系人有一个号码数组
            // 我们需要的是手机号，遍历本条号码数组，得到一个手机号就 退出当前循环
            ABMultiValueRef phoneNos = ABRecordCopyValue(person, kABPersonPhoneProperty);
            NSArray* phoneNosArr = CFBridgingRelease(ABMultiValueCopyArrayOfAllValues(phoneNos));
            for(int i = 0; i< phoneNosArr.count; i++){
                // 号码
                NSString *phoneNo = [phoneNosArr objectAtIndex:i];
                // 获取到数字字符串 并且删除以86开头的 86
                NSString *phoneNumStr = [self findNumFromString:phoneNo delete86:YES];
                if ([self validatePhoneNumber:phoneNumStr]) {
                    [self setReturnDataInDataArray:dataArray nickName:nickName phoneNum:phoneNumStr];
                    // 此处不能使用break跳出循环，因为有的nickName对应多个手机号 break会只添加一个手机号就跳出循环
                    continue;
                }
            }
        }
        completionHandler(dataArray);
    }
}
// !!!设置返回通讯录数据格式
- (void)setReturnDataInDataArray:(NSMutableArray *)dataArray nickName:(NSString *)nickName phoneNum:(NSString *)phoneNum
{
    if (nickName.length == 0 || nickName ==nil || phoneNum.length == 0 || phoneNum == nil) {
        return;
    }
    
    if (self.dataStyle == DLHAddressBookDataStyle_Default) {
        /// 默认返回数据格式 [{nickName:昵称1,phoneNum:手机号1},{nickName:昵称2,phoneNum:手机号2}...]
        [dataArray addObject:@{@"nickName":nickName,@"phoneNum":phoneNum}];
    }else if (self.dataStyle == DLHAddressBookDataStyle_Data_Dict){
        /// 定制数据格式 [{手机号1:昵称1},{手机号2:昵称2}...]
        [dataArray addObject:@{phoneNum:nickName}];
    }else if (self.dataStyle == DLHAddressBookDataStyle_Num_DataDict){
        /// 定制数据格式 [{手机号:{nickName:昵称1,phoneNum:手机号1}},{手机号:{nickName:昵称2,phoneNum:手机号2}}...]
        [dataArray addObject:@{phoneNum:@{@"nickName":nickName,@"phoneNum":phoneNum}}];
    }else{
        /// 选择自定义数据格式 需要在此处自己手动书写自己需要的数据格式，可以添加数据模型
        
    }
    
    // 添加默认格式数据到缓存数组
    [self.cacheArray addObject:@{@"nickName":nickName,@"phoneNum":phoneNum}];

}

// 从一个字符串中提取到所有的数字 delete86：如果是86开头的 是否删除
- (NSString *)findNumFromString:(NSString *)originalString delete86:(BOOL)delete
{
    NSMutableString *numberString = [[NSMutableString alloc] init];
    NSString *tempStr;
    NSScanner *scanner = [NSScanner scannerWithString:originalString];
    NSCharacterSet *numbers = [NSCharacterSet characterSetWithCharactersInString:@"0123456789"];
    while(![scanner isAtEnd]){
        [scanner scanUpToCharactersFromSet:numbers intoString:NULL];
        [scanner scanCharactersFromSet:numbers intoString:&tempStr];
        [numberString appendString:tempStr];
        tempStr = @"";
    }
    // 如果删除86开头的86
    if (delete && [numberString hasPrefix:@"86"]) {
        return [numberString substringFromIndex:2];
    }else{
        return numberString;
    }
}

// 弱校验手机号 只判断首位是1 并且11位的数字
- (BOOL)validatePhoneNumber:(NSString *)noStr
{
    NSString *phoneRegex = @"^(1)\\d{10}$";
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"SELF MATCHES %@",phoneRegex];
    return [predicate evaluateWithObject:noStr];
}

#pragma mark - ============== 缓存通讯录 ================
- (void)cacheAddressBookData
{
    //获取根目录
    NSString *path = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)lastObject];
    //添加储存的文件名
    NSString *homePath = [path stringByAppendingPathComponent:ArchiverKey];
    // 归档数据
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        if ([NSKeyedArchiver archiveRootObject:self.cacheArray toFile:homePath]) {
            NSLog(@"存储成功-------");
        }
    });
}
- (NSArray *)getcacheAddressBookData
{
    //获取根目录
    NSString *path = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)lastObject];
    //添加储存的文件名
    NSString *homePath = [path stringByAppendingPathComponent:ArchiverKey];
    // 获取到缓存的数据
    NSArray *data = [NSKeyedUnarchiver unarchiveObjectWithFile:homePath];
    
    if (self.dataStyle == DLHAddressBookDataStyle_Default) {
        return data;
    }else{
        NSMutableArray *temp = [[NSMutableArray alloc] init];
        for (NSDictionary *dict in data) {
            NSString *nickName = dict[@"nickName"];
            NSString *phoneNum = dict[@"phoneNum"];
            if (self.dataStyle == DLHAddressBookDataStyle_Data_Dict){
                /// 定制数据格式 [{手机号1:昵称1},{手机号2:昵称2}...]
                [temp addObject:@{phoneNum:nickName}];
            }else if (self.dataStyle == DLHAddressBookDataStyle_Num_DataDict){
                /// 定制数据格式 [{手机号:{nickName:昵称1,phoneNum:手机号1}},{手机号:{nickName:昵称2,phoneNum:手机号2}}...]
                [temp addObject:@{phoneNum:@{@"nickName":nickName,@"phoneNum":phoneNum}}];
            }else{
                // 自定义数据格式的 需要自己写 数据格式类型
            }
        }
        return temp;
    }
}

#pragma mark - ============== Alert ================
- (void)showAlertToGetUserAddressBook
{
    __weak __typeof(& *self) weakSelf = self;
    // 弹框使用默认的UIAlert 无论版本号
    dispatch_async(dispatch_get_main_queue(), ^{
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:nil message:weakSelf.refuseUseABMsg delegate:weakSelf cancelButtonTitle:@"取消" otherButtonTitles:@"确定", nil];
        [alert show];
    });
}
-(void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    // 点击确定
    if (buttonIndex == 1) {
        // 跳转通讯录授权方法
        NSURL *url = [NSURL URLWithString:UIApplicationOpenSettingsURLString];
        if ([[UIApplication sharedApplication] canOpenURL:url]) {
            [[UIApplication sharedApplication] openURL:url];
        }
    }
}
@end
