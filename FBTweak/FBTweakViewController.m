/**
 Copyright (c) 2014-present, Facebook, Inc.
 All rights reserved.
 
 This source code is licensed under the BSD-style license found in the
 LICENSE file in the root directory of this source tree. An additional grant
 of patent rights can be found in the PATENTS file in the same directory.
 */

#import "FBTweakStore.h"
#import "FBTweakViewController.h"
#import "_FBTweakCategoryViewController.h"
#import "_FBTweakCollectionViewController.h"
#import "_FBTweakColorViewController.h"

NSString *const FBTweakShakeViewControllerDidDismissNotification = @"FBTweakShakeViewControllerDidDismissNotification";

@interface FBTweakViewController () <_FBTweakCategoryViewControllerDelegate, _FBTweakCollectionViewControllerDelegate, _FBTweakColorViewControllerDelegate>
@end

@implementation FBTweakViewController {
  FBTweakStore *_store;
}

- (instancetype)initWithStore:(FBTweakStore *)store
{
  if ((self = [super init])) {
    _store = store;
    
    _FBTweakCategoryViewController *categoryViewController = [[_FBTweakCategoryViewController alloc] initWithStore:store];
    categoryViewController.delegate = self;
    [self pushViewController:categoryViewController animated:NO];
  }
  
  return self;
}

- (void)tweakCategoryViewController:(_FBTweakCategoryViewController *)viewController selectedCategory:(FBTweakCategory *)category
{
  _FBTweakCollectionViewController *collectionViewController = [[_FBTweakCollectionViewController alloc] initWithTweakCategory:category];
  collectionViewController.delegate = self;
  [self pushViewController:collectionViewController animated:YES];
}

- (void)tweakCategoryViewControllerSelectedDone:(_FBTweakCategoryViewController *)viewController
{
  [_tweaksDelegate tweakViewControllerPressedDone:self];
}

- (void)tweakCollectionViewControllerSelectedDone:(_FBTweakCollectionViewController *)viewController
{
  [_tweaksDelegate tweakViewControllerPressedDone:self];
}

- (void)tweakColorViewControllerSelectedDone:(_FBTweakColorViewController *)viewController
{
  [_tweaksDelegate tweakViewControllerPressedDone:self];
}

@end
