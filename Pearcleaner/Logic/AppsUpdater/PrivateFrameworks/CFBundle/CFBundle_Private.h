//
//  CFBundle_Private.h
//  Pearcleaner
//
//  Private API for flushing bundle caches
//

#import <Foundation/Foundation.h>

/*!
 @abstract Clears cache values on the given bundle object.

 @discussion This is private API and is subject to change in future OS versions. Check for availability prior to usage.
 Source: https://michelf.ca/blog/2010/killer-private-eraser/
 */
extern void _CFBundleFlushBundleCaches(CFBundleRef bundle) __attribute__((weak_import));
