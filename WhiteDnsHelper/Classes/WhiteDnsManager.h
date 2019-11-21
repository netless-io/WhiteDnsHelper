//
//  DNSManager.h
//  WhiteSDK
//
//  Created by yleaf on 2019/11/21.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface WhiteDnsManager : NSObject

/**
 sdk 解析结果
 key 为解析的域名，
 value 为对应的 ip 数组
 如果对应域名解析为空，该key不会被保存
 */
@property (nonatomic, strong, readonly) NSMutableDictionary<NSString *, NSArray<NSString *>*> *domainMap;


+ (instancetype)shareInstance;

/**
 提前解析 SDK API 域名，推荐在初始化时，异步调用。
 */
- (void)querySdkDomain;

/**
 根据 host 在内部查询已经解析完成的结果
 */
- (NSString *)ipForDomain:(NSString *)host;

/**
 提前解析对应域名
 */
- (void)queryHost:(NSString *)host;

@end

NS_ASSUME_NONNULL_END
