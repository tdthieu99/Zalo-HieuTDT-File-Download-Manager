//
//  FileDownloadManager.m
//  Zalo-File Download Manager
//
//  Created by Trần Đình Tôn Hiếu on 4/5/20.
//  Copyright © 2020 Trần Đình Tôn Hiếu. All rights reserved.
//

#import "FileDownloadManager.h"
#import "FileDownloadOperator.h"
#import "FileDownloadItem.h"

@interface FileDownloadManager ()

@property (nonatomic, strong) NSMutableDictionary<NSString *, FileDownloadOperator *> *fileOperatorDictionary;

@end

@implementation FileDownloadManager

- (instancetype)init {
    self = [super init];
    if (self) {
        _fileOperatorDictionary = [[NSMutableDictionary alloc] init];
    }
    return self;
}

+ (instancetype)instance {
    static FileDownloadManager *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[FileDownloadManager alloc] init];
    });
    return sharedInstance;
}

- (void)performDownloadFileWithUrl:(NSString *)url
                          priority:(TaskPriority)priority
         timeOutIntervalForRequest:(int)timeOut
                   progressHandler:(void (^)(NSString *url, long long bytesWritten, long long totalBytes))progressHandler
                 completionHandler:(void (^)(NSString *url, NSString *locationPath, NSError *error))completionHandler {
    if (!url || !progressHandler || !completionHandler)
        return;
    
    if ([self.fileOperatorDictionary valueForKey:url] && [self.fileOperatorDictionary valueForKey:url].isRunning) {
        return;
    }

    dispatch_async(self.serialQueue, ^{
        FileDownloadItem *downloadItem = [[FileDownloadItem alloc] initWithDownloadUrl:url
                                                                       progressHandler:progressHandler
                                                                     completionHandler:completionHandler];
        FileDownloadOperator *downloadOperator = [[FileDownloadOperator alloc] initWithFileDownloadItem:downloadItem
                                                                                               priority:priority
                                                                                      timeOutForRequest:timeOut
                                                                                          callBackQueue:self.serialQueue];
        
        if ([self.fileOperatorDictionary valueForKey:url]) {
            [self.fileOperatorDictionary setObject:downloadOperator forKey:url];
        } else {
            [self.fileOperatorDictionary addEntriesFromDictionary:@{url : downloadOperator}];
        }
            
        [self performTaskOperator:downloadOperator];
    });
}

- (void)pauseDownloadFileWithUrl:(NSString *)url
               completionHandler:(void (^)(NSString *url, NSError *error))completionHandler {
    if (!url)
        return;
    
    dispatch_async(self.serialQueue, ^{
        FileDownloadOperator *downloadOperator = [self.fileOperatorDictionary objectForKey:url];
        
        if (!downloadOperator) {
            NSError *error = [[NSError alloc] initWithDomain:@"FileDownloadOperator"
                                                        code:ERROR_GET_OPERATOR_FAILED
                                                    userInfo:@{@"Can't find DownloadOperator": NSLocalizedDescriptionKey}];
            
            if (completionHandler) {
                completionHandler(url, error);
            }
        }
        
        [downloadOperator updateTaskToPauseDownloadWithPriority:TaskPriorityHigh completionHandler:^(NSString * _Nonnull url, NSError *error) {
            completionHandler(url, error);
        } callBackQueue:self.serialQueue];
        
        [self performTaskOperator:downloadOperator];
    });
}

- (void)resumeDownloadFileWithUrl:(NSString *)url
                completionHandler:(void (^)(NSString *url, NSError *error))completionHandler {
    if (!url)
        return;
    
    dispatch_async(self.serialQueue, ^{
        FileDownloadOperator *downloadOperator = [self.fileOperatorDictionary objectForKey:url];
        
        if (!downloadOperator) {
            NSError *error = [[NSError alloc] initWithDomain:@"FileDownloadOperator"
                                                        code:ERROR_GET_OPERATOR_FAILED
                                                    userInfo:@{@"Can't find DownloadOperator": NSLocalizedDescriptionKey}];
            if (completionHandler) {
                completionHandler(url, error);
            }
        }
        
        [downloadOperator updateTaskToResumeDownloadWithPriority:TaskPriorityHigh
                                               completionHandler:^(NSString * _Nonnull url, NSError *error) {
            if (completionHandler) {
                completionHandler(url, error);
            }
        } callBackQueue:self.serialQueue];
        
        [self performTaskOperator:downloadOperator];
    });
}

- (void)cancelDownloadFileWithUrl:(NSString *)url
                completionHandler:(void (^)(NSString *url))completionHandler {
    if (!url)
        return;
    
    dispatch_async(self.serialQueue, ^{
        FileDownloadOperator *downloadOperator = [self.fileOperatorDictionary objectForKey:url];
        
        if (!downloadOperator) {
            if (completionHandler) {
                completionHandler(url);
            }
            return;
        }
        
        [downloadOperator updateTaskToCancelDownloadWithPriority:TaskPriorityHigh
                                               completionHandler:^(NSString * _Nonnull url) {
            if (completionHandler) {
                completionHandler(url);
            }
        } callBackQueue:self.serialQueue];
        
        [self performTaskOperator:downloadOperator];
    });
}

- (void)retryDownloadFileWithUrl:(NSString *)url
               completionHandler:(void (^)(NSString *url, NSError *error))completionHandler {
    if (!url)
        return;
    
    dispatch_async(self.serialQueue, ^{
        FileDownloadOperator *downloadOperator = [self.fileOperatorDictionary objectForKey:url];
        if (!downloadOperator) {
            NSError *error = [[NSError alloc] initWithDomain:@"FileDownloadOperator"
                                                        code:ERROR_GET_OPERATOR_FAILED
                                                    userInfo:@{@"Can't find DownloadOperator": NSLocalizedDescriptionKey}];
            if (completionHandler) {
                completionHandler(url, error);
            }
        }
        
        [downloadOperator updateTaskToReDownloadWithPriority:TaskPriorityHigh
                                           timeOutForRequest:30
                                           completionHandler:^(NSString * _Nonnull url, NSError *error) {
            if (completionHandler) {
                completionHandler(url, error);
            }
        } callBackQueue:self.serialQueue];
        
        [self performTaskOperator:downloadOperator];
    });
}

@end
