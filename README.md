# DLHAddressBookManager
用于获取用户的通讯录数据，兼容版本ios8之上，获取成功之后就会做本地缓存，下次权限被限制之后，也能从缓存拿到数据，通讯录权限判断等，多种返回数据格式可供选择
#  本工具用于快速获取用户手机的通讯录并返回
 !!!由于我们调用的通讯录是属于用户隐私的数据，所有在获取通讯录数据的时候需要用户对我们的APP进行授权，我们需要在info.plist文件里面添加权限说明：key: Privacy - Contacts Usage Description   value: 我们需要上传您的通讯录至服务器，仅用于给您推荐更好的人脉，请允许我获取您的使用权限。
 
 最低兼容iOS8的系统，由于没有更低的手机系统了iOS8之前的没有测试
 
 使用方法看方法说明，可以定制返回的数据格式，模型数据需要自己手动添加模型
 

# 使用方法
下载工程之后 复制DLHAddressBookManager 文件夹到工程中，然后引用头文件进行使用

[AddManager getAddressBookData:^(NSArray * _Nullable addressBookArray, BOOL granted) {
        NSLog(@"%@",addressBookArray);
    } useCache:YES];
