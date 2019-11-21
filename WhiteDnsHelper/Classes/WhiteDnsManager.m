//
//  DNSManager.m
//  WhiteSDK
//
//  Created by yleaf on 2019/11/21.
//

#import "WhiteDnsManager.h"
#import <HappyDNS/HappyDNS.h>

static NSString *const kTencentDns = @"119.29.29.29";
static NSString *const kSDKAPIHost = @"cloudcapiv4.herewhite.com";
static NSString *const kNormalStorage = @"expresscloudharestoragev2.herewhite.com";
static NSString *const kConStorage = @"cloudharestoragev2.herewhite.com";
static NSString *const kGlobalStorage = @"scdncloudharestoragev3.herewhite.com";

@interface WhiteDnsManager ()
@property (nonatomic, strong, readwrite) NSMutableDictionary<NSString *, NSArray<NSString *>*> *domainMap;
@end

@implementation WhiteDnsManager

static WhiteDnsManager *_sharedObject;

+ (instancetype)shareInstance
{
    static dispatch_once_t pred = 0;
    dispatch_once(&pred, ^{
        _sharedObject = [[self alloc] init];
    });
    return _sharedObject;
}

- (instancetype)init
{
    if (self = [super init]) {
        _domainMap = [[NSMutableDictionary alloc] init];
    }
    return self;
}

- (void)querySdkDomain
{
    [self queryHost:kSDKAPIHost];
    [self queryHost:kNormalStorage];
    [self queryHost:kConStorage];
    [self queryHost:kGlobalStorage];
}

- (NSString *)ipForDomain:(NSString *)host
{
    return [self.domainMap[host] firstObject];
}

- (void)queryHost:(NSString *)host
{
    NSMutableArray *array = [[NSMutableArray alloc] init];
    [array addObject:[QNResolver systemResolver]];
    [array addObject:[[QNResolver alloc] initWithAddress:kTencentDns]];
    QNDnsManager *dns = [[QNDnsManager alloc] init:array networkInfo:[QNNetworkInfo normal]];
    NSArray *ips = [dns query:host];
    if ([ips count] > 0) {
        self.domainMap[host] = ips;
    }
}

@end
