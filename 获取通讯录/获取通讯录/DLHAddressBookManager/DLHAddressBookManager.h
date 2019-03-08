//
//  DLHAddressBookManager.h
//  DLHAddressBookManager
//
//  Created by Duan on 2019/3/7.
//  Copyright © 2019 Duan. All rights reserved.
//

/**
 本工具用于快速获取用户手机的通讯录并返回
 !!!由于我们调用的通讯录是属于用户隐私的数据，所有在获取通讯录数据的时候需要用户对我们的APP进行授权，我们需要在info.plist文件里面添加权限说明：key: Privacy - Contacts Usage Description   value: 我们需要上传您的通讯录至服务器，仅用于给您推荐更好的人脉，请允许我获取您的使用权限。
 最低兼容iOS8的系统，由于没有更低的手机系统了iOS8之前的没有测试
 使用方法看方法说明，可以定制返回的数据格式，模型数据需要自己手动添加模型
 **/

#define AddManager [DLHAddressBookManager shareInstance]

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
NS_ASSUME_NONNULL_BEGIN

/// 返回数据格式
typedef NS_ENUM(NSInteger, DLHAddressBookDataStyle) {
    /// 默认返回数据格式 [{nickName:昵称1,phoneNum:手机号1},{nickName:昵称2,phoneNum:手机号2}...]
    DLHAddressBookDataStyle_Default,
    /// 定制数据格式 [{手机号1:昵称1},{手机号2:昵称2}...]
    DLHAddressBookDataStyle_Data_Dict,
    /// 定制数据格式 [{手机号:{nickName:昵称1,phoneNum:手机号1}},{手机号:{nickName:昵称2,phoneNum:手机号2}}...]
    DLHAddressBookDataStyle_Num_DataDict,
    /// 选择自定义数据格式 需要在setReturnDataInDataArray方法里面自己手动书写自己需要的数据格式
    DLHAddressBookDataStyle_Custom,
};

@interface DLHAddressBookManager : NSObject

/// 无法获取用户通讯录权限弹框说明 (不设置的情况下使用默认提示语)
@property (nonatomic,copy) NSString *refuseUseABMsg;
/// 系统首次弹框后，用户拒绝后是否继续弹 自定义话术的Alert 默认为YES
@property (nonatomic,assign) BOOL firstRefuseShowAlert;
/// 设置返回数据格式，如果枚举类型不满足，可以自定义（默认DLHAddressBookDataStyle_Default）
@property (nonatomic,assign) DLHAddressBookDataStyle dataStyle;
/**
 获取实例对象

 @return 返回一个单例对象
 */
+ (instancetype)shareInstance;

/**
 直接获取通讯录方法

 @param completionHandler 直接获取通讯录（自带判断是否有权限的逻辑）granted是否获取成功
 @param useCache 没有获取到是否使用缓存数据
 */
- (void)getAddressBookData:(void(^)(NSArray * _Nullable addressBookArray,BOOL granted))completionHandler useCache:(BOOL)useCache;

/**
 获取是否有权限获取通讯录的方法
 
 @param completionHandler 是否有权限获取通讯录
 */
- (void)requestAuthorizationAddressBook:(void(^)(BOOL granted))completionHandler;




@end

NS_ASSUME_NONNULL_END
