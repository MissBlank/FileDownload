//
//  GNDownloadManager.m
//  FileDownload
//
//  Created by NERC on 2018/5/14.
//  Copyright © 2018年 GaoNing. All rights reserved.
//

#import "GNDownloadManager.h"
#import <CommonCrypto/CommonDigest.h>

NSString * const MCDownloadCacheFolderName = @"MCDownloadCache";

static NSString * cacheFolder() {
    NSFileManager * fileManager =[NSFileManager defaultManager];
    static NSString * cacheFolder;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken,^{
        if (!cacheFolder) {
            NSString * cacheDir = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES).firstObject;
            cacheFolder =[cacheDir stringByAppendingString:MCDownloadCacheFolderName];
        }
        NSError * error =nil;
        if (![fileManager createDirectoryAtPath:cacheFolder withIntermediateDirectories:YES attributes:nil error:&error]) {
            NSLog(@"Failed to create cache directory at %@",cacheFolder);
            cacheFolder = nil;
        }
    });
    
    return cacheFolder;
    
}


#pragma MD5加密
static NSString * getMD5String(NSString * str){
    
    if (str == nil) return  nil;
    
    const char * cstring =str.UTF8String;
    unsigned char bytes[CC_MD5_DIGEST_LENGTH];
    CC_MD5(cstring, (CC_LONG)strlen(cstring), bytes);
    NSMutableString * md5String =[NSMutableString string];
    for (int i =0; i<CC_MD5_DIGEST_LENGTH; i++) {
        [md5String appendFormat:@"%02x",bytes[i] ];
    }
    return md5String;
    
}

static unsigned long long fileSizeForPath(NSString *path){
    
    signed long long fileSize = 0;
    NSFileManager * fileManager =[NSFileManager defaultManager];
    if ([fileManager fileExistsAtPath:path]) { //判断路径下是路径还是文件夹，yes是路径
        NSError * error =nil;
        NSDictionary * fileDic=[fileManager attributesOfItemAtPath:path error:&error];//获取文件的大小和文件的内容等属性
        if (!error &&fileDic) {
            fileSize =[fileDic fileSize];
        }
    }
    return fileSize;
    
}


@interface GNDownloadReceipt()



@property (strong, nonatomic) NSOutputStream *stream;

@property (nonatomic, strong) NSDate *date;              //????
@property (nonatomic, assign) NSUInteger totalRead;     //????

@end

@implementation GNDownloadReceipt

-(NSOutputStream *)stream{
    if (_stream == nil) {
        _stream =[NSOutputStream outputStreamToFileAtPath:self.filePath append:YES];
    }
    return _stream;
}


-(NSString * )filePath{
    
    NSString * path =[cacheFolder() stringByAppendingString:self.filename];
    if (![path isEqualToString:_filePath]) {
        if (_filePath && ![[NSFileManager defaultManager]fileExistsAtPath:_filePath]) {
            NSString * dir =[_filePath stringByDeletingLastPathComponent];
            [[NSFileManager defaultManager] createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
        }
      
        _filePath =path;

    }
    NSLog(@"文件路径：%@",_filePath);
    
    return _filePath;
}

-(NSString *)filename{

    if (_filename == nil) {
        NSString * pathExtension =self.url.pathExtension;
        if (pathExtension.length) {
            _filename =[NSString stringWithFormat:@"%@.%@",getMD5String(self.url),pathExtension];
        }else{
            _filename = getMD5String(self.url);
        }
    }
    return _filename;
}

-(NSString *)truename{
    if (_truename ==nil) {
        _truename =self.url.lastPathComponent;
    }
    
    return _truename;
}

-(NSProgress *)progress{
    if (_progress==nil) {
        _progress =[[NSProgress alloc]initWithParent:nil userInfo:nil];
    }
    @try{
        
        _progress.totalUnitCount = self.totalBytesExpectedToWrite;
        _progress.completedUnitCount= self.totalBytesWritten;

    } @catch (NSException * exception){
        
    }
    return _progress;
}

-(long long)totalBytesWritten{
    return fileSizeForPath(self.filePath);
}

-(instancetype)initWithUrl:(NSString *)url{
    
    if (self =[self init]) {
        self.url =url;
        self.totalBytesExpectedToWrite =1;
    }
    return self;
    
}

#pragma NSCoding
-(void)encodeWithCoder:(NSCoder *)coder{
    
    [coder encodeObject:self.url forKey:NSStringFromSelector(@selector(url))];
    [coder encodeObject:self.filePath forKey:NSStringFromSelector(@selector(filePath))];
    [coder encodeObject:@(self.state) forKey:NSStringFromSelector(@selector(state))];
    [coder encodeObject:self.filename forKey:NSStringFromSelector(@selector(filename))];
    [coder encodeObject:@(self.totalBytesWritten) forKey:NSStringFromSelector(@selector(totalBytesWritten))];
    [coder encodeObject:@(self.totalBytesExpectedToWrite) forKey:NSStringFromSelector(@selector(totalBytesExpectedToWrite))];
    
}

-(id)initWithCoder:(NSCoder *)Decoder{
    self =[super init];
    if (self) {
        self.url =[Decoder decodeObjectForKey:NSStringFromSelector(@selector(url))];
        self.filePath =[Decoder decodeObjectForKey:NSStringFromSelector(@selector(filePath))];
        self.state=[[Decoder decodeObjectOfClass:[NSNumber class] forKey:NSStringFromSelector(@selector(state))]unsignedIntegerValue];
        self.filename =[Decoder decodeObjectForKey:NSStringFromSelector(@selector(filename))];
        self.totalBytesWritten = [[Decoder decodeObjectOfClass:[NSNumber class] forKey:NSStringFromSelector(@selector(totalBytesWritten))] unsignedIntegerValue];
        self.totalBytesExpectedToWrite = [[Decoder decodeObjectOfClass:[NSNumber class] forKey:NSStringFromSelector(@selector(totalBytesExpectedToWrite))] unsignedIntegerValue];
    }
    return self;
    
}

@end







static NSString * localReceiptsPath(){
    return [cacheFolder() stringByAppendingPathComponent:@"receipts.data"];
}

#if OS_OBJECT_USE_OBJC
#define MCDispatchQueueSetterSementics strong
#else
#define MCDispatchQueueSetterSementics assign
#endif
@interface GNDownloadManager()<NSURLSessionDataDelegate>

@property (nonatomic, MCDispatchQueueSetterSementics) dispatch_queue_t synchronizationQueue;
@property (nonatomic, strong) NSMutableDictionary *tasks;
@property (strong, nonatomic) NSURLSession *session;

@property (nonatomic, strong) NSMutableArray *queuedTasks;

@property (nonatomic, assign) NSInteger maximumActiveDownloads;
@property (nonatomic, assign) NSInteger activeRequestCount;

@property (nonatomic, strong) NSMutableDictionary *allDownloadReceipts;
@property (assign, nonatomic) UIBackgroundTaskIdentifier backgroundTaskId;



@end



@implementation GNDownloadManager

+(instancetype)defaultInstance{
    static GNDownloadManager * sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc]init];
    });
    return sharedInstance;
}


-(NSMutableDictionary *)allDownloadReceipts{
    
    if (_allDownloadReceipts == nil) {
        NSDictionary * receipts =[NSKeyedUnarchiver unarchiveObjectWithFile:localReceiptsPath()];
        _allDownloadReceipts = receipts !=nil ? receipts.mutableCopy : [NSMutableDictionary dictionary];
    }
    return _allDownloadReceipts;
    
}


+(NSURLSessionConfiguration *)defaultURLSessionConfiguration{
    NSURLSessionConfiguration * configuration =[NSURLSessionConfiguration defaultSessionConfiguration];
    
    configuration.HTTPShouldSetCookies =YES;
    configuration.HTTPShouldUsePipelining = NO;
    configuration.requestCachePolicy = NSURLRequestUseProtocolCachePolicy;
    configuration.allowsCellularAccess = YES;
    configuration.timeoutIntervalForRequest = 60.0;
    configuration.HTTPMaximumConnectionsPerHost = 10;
    configuration.discretionary =YES;
    return configuration;
}

-(instancetype)init{
    
    NSURLSessionConfiguration * defaultConfiguration =[self.class defaultURLSessionConfiguration];
    
    NSOperationQueue * queue =[[NSOperationQueue alloc]init];
    queue.maxConcurrentOperationCount =1;
    NSURLSession * session =[NSURLSession sessionWithConfiguration:defaultConfiguration delegate:self delegateQueue:queue];
    return  [self initWithSession:session downloadPrioritization:GNDownloadPrioritizationFIFO maximumActiveDownloads:4];
}

-(instancetype)initWithSession:(NSURLSession *)session downloadPrioritization:(GNDownloadPrioritization)downloadPrioritization maximumActiveDownloads:(NSInteger)maximumActiveDownloads{
    
    if (self = [super init]) {
        
        self.session =session;
        self.downloadPrioritizaton =downloadPrioritization;
        self.maximumActiveDownloads =maximumActiveDownloads;
        
        self.queuedTasks =[[NSMutableArray alloc]init];
        self.tasks =[[NSMutableDictionary alloc]init];
        self.activeRequestCount =0;
        
        NSString * name =[NSString stringWithFormat:@"com.mc.downloadManager.synchronizationqueue-%@", [[NSUUID UUID] UUIDString]];
        self.synchronizationQueue =dispatch_queue_create([name cStringUsingEncoding:NSASCIIStringEncoding], DISPATCH_QUEUE_SERIAL);
        
        
        [[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(applicationWillTerminate:) name:UIApplicationWillTerminateNotification object:nil];
        [[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(applicationDidReceiveMemoryWarning:) name:UIApplicationDidReceiveMemoryWarningNotification object:nil];
        [[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(applicationWillResignActive:) name:UIApplicationWillResignActiveNotification object:nil];
        [[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(applicationDidBecomeActive:) name:UIApplicationDidBecomeActiveNotification object:nil];
        
        
    }
    
    return self;
}




//-(GNDownloadReceipt *)downloadFileWithURL:(NSString *)url
//                                 progress:(void (^)(NSProgress * _Nonnull, GNDownloadReceipt *receipt))downloadProgressBlock
//                              destination:(NSURL *(^)(NSURL * _Nonnull, NSURLResponse *_Nonnull))destination
//                                  success:(void (^)(NSURLRequest *_Nullable, NSHTTPURLResponse * _Nullable, NSURL *_Nonnull))success failure:(void (^)(NSURLRequest *_Nullable, NSHTTPURLResponse * _Nullable, NSError *_Nonnull))failure{

- (GNDownloadReceipt *)downloadFileWithURL:(NSString *)url
                                  progress:(void (^)(NSProgress * _Nonnull,GNDownloadReceipt *receipt))downloadProgressBlock
                               destination:(NSURL *  (^)(NSURL * _Nonnull, NSURLResponse * _Nonnull))destination
                                   success:(nullable void (^)(NSURLRequest * _Nullable, NSHTTPURLResponse * _Nullable, NSURL * _Nonnull))success
                                   failure:(nullable void (^)(NSURLRequest * _Nullable, NSHTTPURLResponse * _Nullable, NSError * _Nonnull))failure {
    
    __block GNDownloadReceipt * receipt =[self downloadReceiptForURL:url];
    dispatch_async(_synchronizationQueue, ^{
        NSString * URLIdentifier = url;
        if (URLIdentifier == nil) {
            if (failure) {
                NSError * error =[NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorBadURL userInfo:nil];
                dispatch_async(dispatch_get_main_queue(), ^{
                    failure(nil,nil,error);
                });
            }
            return ;
        }
        receipt.successBlock = success;
        receipt.failureBlock = failure;
        receipt.progressBlock = downloadProgressBlock;
        
        if (receipt.state == GNDownloadStateCompleted && receipt.totalBytesWritten == receipt.totalBytesExpectedToWrite) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (receipt.successBlock) {
                    receipt.successBlock(nil, nil, [NSURL URLWithString:receipt.url]);
                }
            });
            return;
        }
        if (receipt.state == GNDownloadStateDownloading && receipt.totalBytesWritten!= receipt.totalBytesExpectedToWrite) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (receipt.progressBlock) {
                    receipt.progressBlock(receipt.progress , receipt);
                }
            });
            return;
        }
        
        NSURLSessionDataTask * task =self.tasks[receipt.url];
        //当请求暂停一段时间后，状态会变化，所以要判断下状态
        if (!task || ((task.state!= NSURLSessionTaskStateRunning)&&(task.state != NSURLSessionTaskStateSuspended))) {
          
            NSMutableURLRequest * request =[NSMutableURLRequest requestWithURL:[NSURL URLWithString:receipt.url]];
            NSString * range =[NSString stringWithFormat:@"bytes=%zd-",receipt.totalBytesWritten];
            [request setValue:range forHTTPHeaderField:@"Range"];
            NSURLSessionDataTask * task =[self.session dataTaskWithRequest:request];
            task.taskDescription=receipt.url;
            self.tasks[receipt.url] = task;
            [self.queuedTasks addObject:task];
        }
        
        
        [self resumeWithDownloadReceipt:receipt];

        
    });
    return receipt;
    
}


#pragma mark --   重新下载调用
-(void)resumeWithDownloadReceipt:(GNDownloadReceipt *)receipt{
    
    if ([self isActiveRequestCountBelowMaximumLimit]) {
        NSURLSessionDataTask * task =self.tasks[receipt.url];
        //请求暂停一段时间，状态发生变化，要判断下载的状态
        if (!task ||((task.state !=NSURLSessionTaskStateRunning)&& (task.state != NSURLSessionTaskStateSuspended))) {
            [self downloadFileWithURL:receipt.url progress:receipt.progressBlock destination:nil success:receipt.successBlock failure:receipt.failureBlock];
        }else{
            [self startTask:self.tasks[receipt.url]];
            receipt.date =[NSDate date];
        }
    }else{
        receipt.state=GNDownloadStateWillResume;
        [self saveReceipts:self.allDownloadReceipts];
        [self enqueueTask:self.tasks[receipt.url]];
    }
    
}





#pragma mark - NSNotification 程序不同状态下的操作
//程序被杀死时调用，该事件进行释放一些资源和保存用户数据
-(void)applicationWillTerminate:(NSNotification *)noti{
    
    [self  suspendAll];
    
}
//程序内存警告，可能要终止程序时调用
-(void)applicationDidReceiveMemoryWarning:(NSNotification *)noti{
    
    [self suspendAll];
}

//当程序挂起时（比如有电话进来或者锁屏），会调用这个通知，这里的是重写
-(void)applicationWillResignActive:(NSNotification *)noti{
    Class UIApplicationClass = NSClassFromString(@"UIApplication");
    BOOL hasApplication = UIApplicationClass &&[UIApplicationClass respondsToSelector:@selector(sharedApplication)];
    if (hasApplication) {
        __weak __typeof__(self)wself =self;
        UIApplication * app =[UIApplicationClass performSelector:@selector(sharedApplication)];
        self.backgroundTaskId = [app beginBackgroundTaskWithExpirationHandler:^{
            __strong __typeof (wself)sself =wself;
            if (sself) {
                [sself suspendAll];
                
                [app endBackgroundTask:sself.backgroundTaskId];
                sself.backgroundTaskId = UIBackgroundTaskInvalid;
            }
        }];
    }
    
}

//当程序复原时，调用
-(void)applicationDidBecomeActive:(NSNotification *)noti{
    Class UIApplicationClass = NSClassFromString(@"UIApplication");
    if (!UIApplicationClass || ![UIApplicationClass respondsToSelector:@selector(sharedApplication)]) {
        return;
    }
    if (self.backgroundTaskId != UIBackgroundTaskInvalid) {
        UIApplication * app =[UIApplication performSelector:@selector(sharedApplication)];
        [app endBackgroundTask:self.backgroundTaskId];
        self.backgroundTaskId = UIBackgroundTaskInvalid;
    }
    
}


-(void)suspendAll{
    
    for (NSURLSessionDataTask * task in self.queuedTasks) {
        GNDownloadReceipt * receipt =[self downloadReceiptForURL:task.taskDescription];
        receipt.state =GNDownloadStateFailed;
        [task suspend];  //暂停
        [self safelyDecrementActiveTaskCount];
    }
    [self saveReceipts:self.allDownloadReceipts];
    
}

-(GNDownloadReceipt *)downloadReceiptForURL:(NSString *)url{
    
    if (url == nil)return nil;
    GNDownloadReceipt * receipt = self.allDownloadReceipts[url];
    if (receipt) return receipt;
    receipt=[[GNDownloadReceipt alloc]initWithUrl:url];
    receipt.state=GNDownloadStateNone;
    receipt.totalBytesExpectedToWrite = 1;
    
    dispatch_sync(self.synchronizationQueue, ^{
        [self.allDownloadReceipts setObject:receipt forKey:url];
        [self saveReceipts:self.allDownloadReceipts];
    });
    
    return receipt;
}


- (void)saveReceipts:(NSDictionary *)receipts {
    [NSKeyedArchiver archiveRootObject:receipts toFile:localReceiptsPath()];
}

- (GNDownloadReceipt *)updateReceiptWithURL:(NSString *)url state:(GNDownloadState)state {
    GNDownloadReceipt *receipt = [self downloadReceiptForURL:url];
    receipt.state = state;
    
    [self saveReceipts:self.allDownloadReceipts];
    
    return receipt;
}




#pragma mark URLSessionDataDelegate
-(void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveResponse:(NSURLResponse *)response completionHandler:(void (^)(NSURLSessionResponseDisposition))completionHandler{
    
    GNDownloadReceipt * receipt =[self downloadReceiptForURL:dataTask.taskDescription];
    receipt.totalBytesExpectedToWrite = receipt.totalBytesWritten + dataTask.countOfBytesExpectedToReceive;
    receipt.state = GNDownloadStateDownloading;
    [self saveReceipts:self.allDownloadReceipts];
    completionHandler(NSURLSessionResponseAllow);
}

-(void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data{
    dispatch_sync(self.synchronizationQueue, ^{
        __block NSError * error = nil;
        GNDownloadReceipt * receipt =[self downloadReceiptForURL:dataTask.taskDescription];
        receipt.totalRead +=data.length;
        NSDate * currentDate =[NSDate date];
        if ([currentDate timeIntervalSinceDate:receipt.date]>=1 ) {
            
            double time =[currentDate timeIntervalSinceDate:receipt.date];
            long long speed =receipt.totalRead/time;
            receipt.speed = [self formatByteCount:speed];
            receipt.totalRead = 0.0;
            receipt.date =currentDate;
        }
        
        //将网络大文件加载到本地
        NSInputStream * inputStream =[[NSInputStream alloc]initWithData:data];
        NSOutputStream * outputStream=[[NSOutputStream alloc]initWithURL:[NSURL fileURLWithPath:receipt.filePath] append:YES];
        [inputStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
        [outputStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
        
        [inputStream open];
        [outputStream open];
        
        //hasBytesAvailable 检测是否有可读的数据， 用streamError来查看流处理过程中的错误
        while ([inputStream hasBytesAvailable]&& [outputStream hasSpaceAvailable]) {
            uint8_t buffer[1024];
            NSInteger bytesRead =[inputStream read:buffer maxLength:1024]; //read：maxLength：获取可读数据
            if (inputStream.streamError || bytesRead <0) {
                error = inputStream.streamError;
                break;
            }
            NSInteger bytesWritten =[outputStream write:buffer maxLength:(NSInteger)bytesRead]; //将数据写入流
            if (outputStream.streamError || bytesRead <0) {
                error =outputStream.streamError;
                break;
            }
            if (bytesRead == 0 && bytesWritten == 0) {
                break;
            }
        }
        [outputStream close];
        [inputStream close];
        
        receipt.progress.totalUnitCount = receipt.totalBytesExpectedToWrite;
        receipt.progress.completedUnitCount = receipt.totalBytesWritten;
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (receipt.progressBlock) {
                receipt.progressBlock(receipt.progress, receipt);
            }
        });
    });
    
}

-(void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error{
    
    GNDownloadReceipt * receipt =[self downloadReceiptForURL:task.taskDescription];
    if (error) {
        receipt.state =GNDownloadStateFailed;
        dispatch_async(dispatch_get_main_queue(), ^{
            if (receipt.failureBlock) {
                receipt.failureBlock(task.originalRequest, (NSHTTPURLResponse *)task.response, error);
            }
        });
    }else{
        [receipt.stream close];
        receipt.stream = nil;
        receipt.state =GNDownloadStateCompleted;
        dispatch_async(dispatch_get_main_queue(), ^{
            if (receipt.successBlock) {
                receipt.successBlock(task.originalRequest, (NSHTTPURLResponse *)task, task.originalRequest.URL);
            }
        });
    }
    
    [self saveReceipts:self.allDownloadReceipts];
    [self safelyDecrementActiveTaskCount];
    [self safelyStartNextTaskIfNecessary];
    
    
}

- (NSString*)formatByteCount:(long long)size
{
    return [NSByteCountFormatter stringFromByteCount:size countStyle:NSByteCountFormatterCountStyleFile];
}

#pragma mark 删除已下载课程
-(void)removeWithURL:(NSString *)url{
    if (url ==nil)return;
    GNDownloadReceipt * receipt=[self downloadReceiptForURL:url];
    [self removeWithDownloadReceipt:receipt];
}
-(void)removeWithDownloadReceipt:(GNDownloadReceipt *)receipt{
    
    NSURLSessionDataTask * task =self.tasks[receipt.url];
    if (task) {
        [task cancel];
    }
    
    [self.queuedTasks removeObject:task];
    [self safelyRemoveTaskWithURLIdentifier:receipt.url];
    
    dispatch_async(self.synchronizationQueue, ^{
        [self.allDownloadReceipts removeObjectForKey:receipt.url];
        [self saveReceipts:self.allDownloadReceipts];
    });
    
    NSFileManager * fileManager=[NSFileManager defaultManager];
    [fileManager removeItemAtPath:receipt.filePath error:nil];
    
}

#pragma mark 继续下载调用
-(void)suspendWithDownloadReceipt:(GNDownloadReceipt *)receipt{
    
    [self updateReceiptWithURL:receipt.url state:GNDownloadStateSuSpened];
    NSURLSessionDataTask * task =self.tasks[receipt.url];
    if (task) {
        [task suspend];
        [self safelyDecrementActiveTaskCount];
        [self safelyStartNextTaskIfNecessary];
    }
    
}

#pragma mark ------------------
- (NSURLSessionDataTask*)safelyRemoveTaskWithURLIdentifier:(NSString *)URLIdentifier {
    __block NSURLSessionDataTask *task = nil;
    dispatch_sync(self.synchronizationQueue, ^{
        task = [self removeTaskWithURLIdentifier:URLIdentifier];
    });
    return task;
}

//This method should only be called from safely within the synchronizationQueue
- (NSURLSessionDataTask *)removeTaskWithURLIdentifier:(NSString *)URLIdentifier {
    NSURLSessionDataTask *task = self.tasks[URLIdentifier];
    [self.tasks removeObjectForKey:URLIdentifier];
    return task;
}

- (void)safelyDecrementActiveTaskCount {
    dispatch_sync(self.synchronizationQueue, ^{
        if (self.activeRequestCount > 0) {
            self.activeRequestCount -= 1;
        }
    });
}

- (void)safelyStartNextTaskIfNecessary {
    dispatch_sync(self.synchronizationQueue, ^{
        if ([self isActiveRequestCountBelowMaximumLimit]) {
            while (self.queuedTasks.count > 0) {
                NSURLSessionDataTask *task = [self dequeueTask];
                GNDownloadReceipt *receipt = [self downloadReceiptForURL:task.taskDescription];
                if (task.state == NSURLSessionTaskStateSuspended && receipt.state == GNDownloadStateWillResume) {
                    [self startTask:task];
                    break;
                }
            }
        }
    });
}


- (void)startTask:(NSURLSessionDataTask *)task {
    [task resume];
    ++self.activeRequestCount;
    [self updateReceiptWithURL:task.taskDescription state:GNDownloadStateDownloading];
}

- (void)enqueueTask:(NSURLSessionDataTask *)task {
    switch (self.downloadPrioritizaton) {
        case GNDownloadPrioritizationFIFO:  //
            [self.queuedTasks addObject:task];
            break;
        case GNDownloadPrioritizationLIFO:  //
            [self.queuedTasks insertObject:task atIndex:0];
            break;
    }
}

- (NSURLSessionDataTask *)dequeueTask {
    NSURLSessionDataTask *task = nil;
    task = [self.queuedTasks firstObject];
    [self.queuedTasks removeObject:task];
    return task;
}

- (BOOL)isActiveRequestCountBelowMaximumLimit {
    return self.activeRequestCount < self.maximumActiveDownloads;
}
@end

















