//
//  FileDownloadOperator.m
//  Zalo-File Download Manager
//
//  Created by Trần Đình Tôn Hiếu on 4/5/20.
//  Copyright © 2020 Trần Đình Tôn Hiếu. All rights reserved.
//

#import "FileDownloadOperator.h"
#import "DownloadDataCache.h"

@interface FileDownloadOperator () <NSURLSessionDownloadDelegate>

@property (nonatomic, strong) FileDownloadItem *item;
@property (nonatomic, strong) NSURLSessionDownloadTask *downloadTask;
@property (nonatomic, strong) dispatch_queue_t callBackQueue;

@end

@implementation FileDownloadOperator

- (instancetype)init {
    self = [super initWithTaskBlock:^{} priority:TaskPriorityNormal];
    if (self) {
    }
    return self;
}

- (instancetype)initWithFileDownloadItem:(FileDownloadItem *)item
                                priority:(TaskPriority)priority
                           callBackQueue:(dispatch_queue_t)callBackQueue {
    return [self initWithFileDownloadItem:item
                                 priority:priority
                        timeOutForRequest:30
                            callBackQueue:callBackQueue];
}

- (instancetype)initWithFileDownloadItem:(FileDownloadItem *)item
                                priority:(TaskPriority)priority
                       timeOutForRequest:(int)timeOut
                           callBackQueue:(dispatch_queue_t)callBackQueue {
    self = [super init];
    if (self) {
        _item = item;
        _downloadTask = [self downloadTaskFromUrl:item.url timeOutIntervalForRequest:timeOut];
        _callBackQueue = callBackQueue;
        
        __weak FileDownloadOperator *weakSelf = self;
        self.priority = priority;
        self.taskBlock = ^{
            if (weakSelf.downloadTask) {
                [weakSelf.downloadTask resume];
            }
        };
    }
    return self;
}

- (void)updateTaskToStopDownloadWithPriority:(TaskPriority)priority
                           completionHandler:(void (^)(NSString *url, NSError *error))completionHandler
                               callBackQueue:(dispatch_queue_t)callBackQueue {
    __weak FileDownloadOperator *weakSelf = self;
    self.priority = priority;
    self.taskBlock = ^{
        if (weakSelf.downloadTask) {
            [weakSelf.downloadTask cancelByProducingResumeData:^(NSData *resumeData) {
                if (resumeData) {
                    [[DownloadDataCache instance] setData:resumeData forKey:weakSelf.item.identifier];
                    completionHandler(weakSelf.item.url, nil);
                } else {
                    NSError *error = [[NSError alloc] initWithDomain:@"FileDownloadOperator"
                                                                code:ERROR_GET_RESUME_DATA_FAILED
                                                            userInfo:@{@"Tạm dừng download thất bại!": NSLocalizedDescriptionKey}];
                    completionHandler(weakSelf.item.url, error);
                }
            }];
        }
    };
}

- (NSURLSessionDownloadTask *)downloadTaskFromUrl:(NSString *)url
                        timeOutIntervalForRequest:(int)timeOut {
    NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
    configuration.timeoutIntervalForRequest = timeOut;
    
    NSURLSession *session = [NSURLSession sessionWithConfiguration:configuration delegate:self delegateQueue:nil];
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:url]];
    
    NSURLSessionDownloadTask *downloadTask = [session downloadTaskWithRequest:request];
    return downloadTask;
}

#pragma mark - NSURLSessionDelegate

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask
                                           didWriteData:(int64_t)bytesWritten
                                      totalBytesWritten:(int64_t)totalBytesWritten
                              totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite {
    if (downloadTask == self.downloadTask && self.item && self.item.progressHandler) {
        dispatch_async(self.callBackQueue, ^{
            self.item.progressHandler(self.item.url, totalBytesWritten, totalBytesExpectedToWrite);
        });
    }
}

- (void)URLSession:(nonnull NSURLSession *)session
      downloadTask:(nonnull NSURLSessionDownloadTask *)downloadTask didFinishDownloadingToURL:(nonnull NSURL *)location {
    
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task
                           didCompleteWithError:(NSError *)error {
    if (task && self.item && self.item.completionHandler) {
        dispatch_async(self.callBackQueue, ^{
            if (error) {
                NSLog(@"URL Session error: %@", error.userInfo);
            }
            
            self.item.completionHandler(self.item.url, @"", error);
        });
    }
}

@end