//
//  GNDownloadManager.h
//  FileDownload
//
//  Created by NERC on 2018/5/14.
//  Copyright © 2018年 GaoNing. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@class GNDownloadReceipt;

typedef NS_ENUM(NSUInteger,GNDownloadState) {
    GNDownloadStateNone,
    GNDownloadStateWillResume,
    GNDownloadStateDownloading,
    GNDownloadStateSuSpened,
    GNDownloadStateCompleted,
    GNDownloadStateFailed
};
typedef NS_ENUM(NSInteger,GNDownloadPrioritization) {
    GNDownloadPrioritizationFIFO,
    GNDownloadPrioritizationLIFO
    
};

typedef void (^GNSucessBlock)(NSURLRequest * _Nullable, NSHTTPURLResponse * _Nullable, NSURL * _Nonnull);
typedef void (^GNFailureBlock)(NSURLRequest * _Nullable, NSHTTPURLResponse * _Nullable, NSError * _Nonnull);

typedef void (^GNProgressBlock)(NSProgress * _Nonnull,GNDownloadReceipt *);


#pragma GNDownloadReceipt

@interface GNDownloadReceipt : NSObject

@property(nonatomic,assign)GNDownloadState state;
@property(nonatomic,copy) NSString * url;
@property(nonatomic,copy) NSString * filePath;
@property(nonatomic,copy) NSString * filename;
@property(nonatomic,copy) NSString * truename;
@property(nonatomic,copy) NSString * speed; // kb/s

@property(nonatomic,assign) long long  totalBytesWritten;
@property(nonatomic,assign) long long totalBytesExpectedToWrite;

@property (nonatomic, copy, nonnull) NSProgress *progress;
@property (nonatomic, strong, readonly, nullable) NSError *error;


@property(nonatomic,copy)GNSucessBlock successBlock;
@property(nonatomic,copy)GNFailureBlock failureBlock;
@property(nonatomic,copy)GNProgressBlock progressBlock;

@end




@protocol GNDownloadControlDelegate <NSObject>

- (void)suspendWithURL:(NSString * _Nonnull)url;
- (void)suspendWithDownloadReceipt:(GNDownloadReceipt * _Nonnull)receipt;

//删除已下载的文件
- (void)removeWithURL:(NSString * _Nonnull)url;
- (void)removeWithDownloadReceipt:(GNDownloadReceipt * _Nonnull)receipt;

@end

#pragma GNDownloadManager

@interface GNDownloadManager : NSObject<GNDownloadControlDelegate>

@property(nonatomic,assign)GNDownloadPrioritization downloadPrioritizaton;


+(instancetype)defaultInstance;
-(instancetype)init;

/**
 Initializes the `GNDownloadManager` instance with the given session manager, download prioritization, maximum active download count.
 
 @param sessionManager The session manager to use to download file.
 @param downloadPrioritization The download prioritization of the download queue.
 @param maximumActiveDownloads  The maximum number of active downloads allowed at any given time. Recommend `4`.
 
 @return The new `MCDownloadManager` instance.
 */
-(instancetype)initWithSession:(NSURLSession *)session
        downloadPrioritization:(GNDownloadPrioritization)downloadPrioritization
        maximumActiveDownloads:(NSInteger)maximumActiveDownloads;


/**
 Creates an `MCDownloadReceipt` with the specified request.
 
 @param url The URL  for the request.
 @param downloadProgressBlock A block object to be executed when the download progress is updated. Note this block is called on the session queue, not the main queue.
 @param destination A block object to be executed in order to determine the destination of the downloaded file. This block takes two arguments, the target path & the server response, and returns the desired file URL of the resulting download. The temporary file used during the download will be automatically deleted after being moved to the returned URL.
 
 @warning If using a background `NSURLSessionConfiguration` on iOS, these blocks will be lost when the app is terminated. Background sessions may prefer to use `-setDownloadTaskDidFinishDownloadingBlock:` to specify the URL for saving the downloaded file, rather than the destination block of this method.
 */
-(GNDownloadReceipt *)downloadFileWithURL:(NSString * _Nullable)url
                                 progress:(nullable void(^)(NSProgress * downloadProgress,GNDownloadReceipt *receipt))downloadProgressBlock
                              destination:(nullable NSURL * (^)(NSURL * targetPath,NSURLResponse * response))destination
                              success:(nullable void(^)(NSURLRequest * request,NSHTTPURLResponse * _Nullable response, NSURL * filePath))success
                                  failure:(nullable void(^)(NSURLRequest * request, NSHTTPURLResponse* _Nullable response,NSError * error))failure;


-(GNDownloadReceipt * _Nullable)downloadReceiptForURL:(NSString *)url;







@end
