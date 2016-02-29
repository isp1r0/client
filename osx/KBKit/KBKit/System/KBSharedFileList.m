//
//  KBSharedFileList.m
//  KBKit
//
//  Created by Gabriel on 2/23/16.
//  Copyright © 2016 Gabriel Handford. All rights reserved.
//

#import "KBSharedFileList.h"
#import "KBDefines.h"

@implementation KBSharedFileList

+ (void)findLoginItemForURL:(NSURL *)URL completion:(void (^)(LSSharedFileListRef fileListRef, CFArrayRef itemsRef, NSArray */*LSSharedFileListItemRef*/foundItems))completion {
  [self findItemForName:nil URL:URL type:kLSSharedFileListSessionLoginItems completion:completion];
}

+ (NSArray *)itemsForType:(CFStringRef)type {
  LSSharedFileListRef fileListRef = LSSharedFileListCreate(NULL, type, NULL);
  if (!fileListRef) return nil;

  UInt32 seed = 0U;
  CFArrayRef itemsRef = LSSharedFileListCopySnapshot(fileListRef, &seed);
  return CFBridgingRelease(itemsRef);
}

+ (void)findItemForName:(NSString *)name URL:(NSURL *)URL type:(CFStringRef)type completion:(void (^)(LSSharedFileListRef fileListRef, CFArrayRef itemsRef, NSArray */*LSSharedFileListItemRef*/matchedItems))completion {
  LSSharedFileListRef fileListRef = LSSharedFileListCreate(NULL, type, NULL);
  if (!fileListRef) return;

  UInt32 seed = 0U;
  NSMutableArray *foundItems = [NSMutableArray array];
  CFArrayRef itemsRef = LSSharedFileListCopySnapshot(fileListRef, &seed);
  NSArray *items = (__bridge NSArray *)itemsRef;
  for (id itemObject in items) {
    LSSharedFileListItemRef itemRef = (__bridge LSSharedFileListItemRef)itemObject;

    BOOL matched = NO;
    if (name) {
      CFStringRef displayNameRef = LSSharedFileListItemCopyDisplayName(itemRef);
      BOOL nameEqual = [name isEqual:(__bridge NSString *)(displayNameRef)];
      CFRelease(displayNameRef);
      if (nameEqual) {
        matched = YES;
      }
    }

    if (!matched && URL) {
      // On El Capitan, the URLRef is null if the mount or path is invalid
      UInt32 resolutionFlags = kLSSharedFileListNoUserInteraction | kLSSharedFileListDoNotMountVolumes;
      CFErrorRef errorRef;
      CFURLRef URLRef = LSSharedFileListItemCopyResolvedURL(itemRef, resolutionFlags, &errorRef);
      BOOL URLEqual = [URL isEqualTo:(__bridge NSURL *)URLRef];
      CFRelease(URLRef);
      if (URLEqual) {
        matched = YES;
      }
    }

    if (matched) {
      [foundItems addObject:(__bridge id _Nonnull)(itemRef)];
    }
  }

  completion(fileListRef, itemsRef, foundItems);

  CFRelease(itemsRef);
  CFRelease(fileListRef);
}

+ (BOOL)setEnabled:(BOOL)enabled URL:(NSURL *)URL name:(NSString *)name type:(CFStringRef)type insertAfter:(LSSharedFileListItemRef)insertAfter error:(NSError **)error {
  __block BOOL changed = NO;
  __block NSError *bError = nil;
  // Good to use name to match (since on El Capitan the URL can be invalid)
  [self findItemForName:name URL:nil type:type completion:^(LSSharedFileListRef fileListRef, CFArrayRef itemsRef, NSArray */*LSSharedFileListItemRef*/matchedItems) {
    // If not enabling, clear all matched items.
    // If matchedItems count is > 1, then let's clear the found items, and re-add a single item, which fixes an issue with duplicates.
    if (!enabled || [matchedItems count] > 1) {
      changed = YES;
      for (id item in matchedItems) {
        LSSharedFileListItemRemove(fileListRef, (__bridge LSSharedFileListItemRef)item);
      }
      matchedItems = [NSArray array];
    }

    if (enabled && [matchedItems count] == 0) {
      LSSharedFileListItemRef itemRef = LSSharedFileListInsertItemURL(fileListRef, insertAfter, (__bridge CFStringRef)name, NULL, (__bridge CFURLRef)URL, NULL, NULL);
      if (!itemRef) {
        bError = KBMakeError(-1, @"Error adding item");
      } else {
        CFRelease(itemRef);
        changed = YES;
      }
    }
  }];

  if (error) *error = bError;
  return changed;
}

+ (BOOL)isEnabledForURL:(NSURL *)URL type:(CFStringRef)type {
  __block BOOL found;
  [self findItemForName:nil URL:URL type:type completion:^(LSSharedFileListRef fileListRef, CFArrayRef itemsRef, NSArray */*LSSharedFileListItemRef*/matchedItems) {
    found = ([matchedItems count] > 0);
  }];
  return found;
}

@end