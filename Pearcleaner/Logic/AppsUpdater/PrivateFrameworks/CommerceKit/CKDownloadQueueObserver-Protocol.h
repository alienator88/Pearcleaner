//
// CKDownloadQueueObserver-Protocol.h
// mas
//
// Copyright © 2018 mas-cli. All rights reserved.
//

@protocol CKDownloadQueueObserver

@required

- (void)downloadQueue:(nonnull CKDownloadQueue *)queue changedWithAddition:(nonnull SSDownload *)download;
- (void)downloadQueue:(nonnull CKDownloadQueue *)queue changedWithRemoval:(nonnull SSDownload *)download;
- (void)downloadQueue:(nonnull CKDownloadQueue *)queue statusChangedForDownload:(nonnull SSDownload *)download;

@optional

@end
