//
//  WhiteProtocol.m
//  WhiteSDK
//
//  Created by yleaf on 2019/11/21.
//

#import "WhiteDnsProtocol.h"
#import "WhiteDnsManager.h"
#import <HappyDNS/HappyDNS.h>

static NSString *kDomain = @"herewhite.com";

@interface WhiteDnsProtocol ()

@property (nonatomic, readwrite, strong) NSURLSessionDataTask *task;
@property (nonatomic, readwrite, strong) NSMutableData *data;
@property (nonatomic, readwrite, strong) NSURLResponse *response;
@end

@implementation WhiteDnsProtocol

+ (BOOL)canInitWithRequest:(NSURLRequest *)request
{
    return [self needInterrupt:request];
}

+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request
{
    NSMutableURLRequest *mutableReqeust = [request mutableCopy];
    NSURL *url = mutableReqeust.URL;
    NSString *originalUrl = url.absoluteString;
    
    NSString *ip = [[WhiteDnsManager shareInstance] ipForDomain:url.host];
                    
    if (ip && url.host) {
        NSRange hostFirstRange = [originalUrl rangeOfString:url.host];
        if (NSNotFound != hostFirstRange.location) {
            NSString *newUrl = [originalUrl stringByReplacingCharactersInRange:hostFirstRange withString:ip];
            mutableReqeust.URL = [NSURL URLWithString:newUrl];
            [mutableReqeust setValue:url.host forHTTPHeaderField:@"host"];
        }
    }
    
    //国内需要 httpdns 的用户，不需要全球加速。更换成国内 API 的 ip 地址。数据库内容一致
    if ([url.host containsString:WhiteGlobalStorage] && [QNDnsManager needHttpDns]) {
        NSRange scdnRange = [originalUrl rangeOfString:WhiteGlobalStorage];
        NSString *normalIp = [[WhiteDnsManager shareInstance] ipForDomain:WhiteNormalStorage];
        if (NSNotFound != scdnRange.location && normalIp) {
            NSString *newUrl = [originalUrl stringByReplacingCharactersInRange:scdnRange withString:normalIp];
            mutableReqeust.URL = [NSURL URLWithString:newUrl];
            [mutableReqeust setValue:WhiteNormalStorage forHTTPHeaderField:@"host"];
        } else {
            //即使没有查询到，也不使用 SNI 的 API 地址
            NSString *newUrl = [originalUrl stringByReplacingCharactersInRange:scdnRange withString:WhiteNormalStorage];
            mutableReqeust.URL = [NSURL URLWithString:newUrl];
        }
    } else if ([url.host containsString:WhiteGlobalStorage]) {
        //全球加速地址是SNI场景，不能直接使用 httpdns，需要 libcurl 进行请求
        mutableReqeust.URL = url;
    }
    
    return mutableReqeust;
}

#pragma mark - Private class methods

+ (BOOL)needInterrupt:(NSURLRequest *)request
{
    BOOL alreadyInterrupt = [self propertyForKey:kFlagProperty inRequest:request];
    if (alreadyInterrupt) {
        return NO;
    }
    
    //海外用户，不需要 httpdns 处理，容易画蛇添足
    if (![QNDnsManager needHttpDns]) {
        return NO;
    }
    
    // 有解析结果再拦截
    if ([request.URL.host containsString:kDomain] && [[WhiteDnsManager shareInstance] ipForDomain:request.URL.host]) {
        return YES;
    }
    
    return NO;
}

- (BOOL)evaluateServerTrust:(SecTrustRef)serverTrust
                  forDomain:(NSString *)domain {
    /*
     * 创建证书校验策略
     */
    NSMutableArray *policies = [NSMutableArray array];
    if (domain) {
        [policies addObject:(__bridge_transfer id) SecPolicyCreateSSL(true, (__bridge CFStringRef) domain)];
    } else {
        [policies addObject:(__bridge_transfer id) SecPolicyCreateBasicX509()];
    }
    /*
     * 绑定校验策略到服务端的证书上
     */
    SecTrustSetPolicies(serverTrust, (__bridge CFArrayRef) policies);
    /*
     * 评估当前serverTrust是否可信任，
     * 官方建议在result = kSecTrustResultUnspecified 或 kSecTrustResultProceed
     * 的情况下serverTrust可以被验证通过，https://developer.apple.com/library/ios/technotes/tn2232/_index.html
     * 关于SecTrustResultType的详细信息请参考SecTrust.h
     */
    SecTrustResultType result;
    SecTrustEvaluate(serverTrust, &result);
    return (result == kSecTrustResultUnspecified);
}

#pragma mark - Subclass methods

- (void)startLoading
{
    NSMutableURLRequest *mutableReqeust = [[self request] mutableCopy];
    [[self class] setProperty:@YES forKey:kFlagProperty inRequest:mutableReqeust];
    NSURLSession *session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration] delegate:(id<NSURLSessionDelegate>)self delegateQueue:nil];
    self.task = [session dataTaskWithRequest:mutableReqeust];
    [self.task resume];
}

- (void)stopLoading
{
    [self.task cancel];
}

#pragma mark - NSURLSessionDelegate
static NSString * kFlagProperty = @"com.herewhite.com";

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task willPerformHTTPRedirection:(NSHTTPURLResponse *)response newRequest:(NSURLRequest *)newRequest completionHandler:(void (^)(NSURLRequest *))completionHandler
{
    NSMutableURLRequest *redirectRequest;
    assert([[self class] propertyForKey:kFlagProperty inRequest:newRequest] != nil);
    
    redirectRequest = [newRequest mutableCopy];
    [[self class] removePropertyForKey:kFlagProperty inRequest:redirectRequest];
    [[self client] URLProtocol:self wasRedirectedToRequest:redirectRequest redirectResponse:response];
    
    [self.task cancel];
    
    [[self client] URLProtocol:self didFailWithError:[NSError errorWithDomain:NSCocoaErrorDomain code:NSUserCancelledError userInfo:nil]];
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition, NSURLCredential *))completionHandler
{
    if (!challenge) {
        return;
    }
    NSURLSessionAuthChallengeDisposition disposition = NSURLSessionAuthChallengePerformDefaultHandling;
    NSURLCredential *credential = nil;
    /*
     * 获取原始域名信息。
     */
    NSString *host = [[task.originalRequest allHTTPHeaderFields] objectForKey:@"host"];
    if (!host) {
        host = task.originalRequest.URL.host;
    }
    if ([challenge.protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust]) {
        if ([self evaluateServerTrust:challenge.protectionSpace.serverTrust forDomain:host]) {
            disposition = NSURLSessionAuthChallengeUseCredential;
            credential = [NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust];
        } else {
            disposition = NSURLSessionAuthChallengePerformDefaultHandling;
        }
    } else {
        disposition = NSURLSessionAuthChallengePerformDefaultHandling;
    }
    // 对于其他的challenges直接使用默认的验证方案
    completionHandler(disposition, credential);

}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveResponse:(NSURLResponse *)response completionHandler:(void (^)(NSURLSessionResponseDisposition))completionHandler
{
    self.response = response;
    [self.client URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageNotAllowed];
    completionHandler(NSURLSessionResponseAllow);
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data
{
    self.data = [data mutableCopy];
    [[self client] URLProtocol:self didLoadData:data];
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error
{
    if (error) {
        [self.client URLProtocol:self didFailWithError:error];
    } else {
        [self.client URLProtocolDidFinishLoading:self];
    }
    self.data = nil;
    self.response = nil;
    self.task = nil;
}

@end
