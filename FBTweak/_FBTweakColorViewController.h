/**
 Copyright (c) 2014-present, Facebook, Inc.
 All rights reserved.

 This source code is licensed under the BSD-style license found in the
 LICENSE file in the root directory of this source tree. An additional grant
 of patent rights can be found in the PATENTS file in the same directory.
 */

#import <UIKit/UIKit.h>

@class FBTweak;
@protocol _FBTweakColorViewControllerDelegate;

/**
 *  @abstract Displays a view to edit a tweak with color value.
 */
@interface _FBTweakColorViewController : UIViewController

/**
 @abstract Create a RGB view controller.
 @param tweak The tweak with color value to edit.
 @discussion This is the designated initializer.
 */
- (instancetype)initWithTweak:(FBTweak *)tweak;

//! @abstract The tweak to edit.
@property (nonatomic, strong, readonly) FBTweak *tweak;

@property (nonatomic, weak, readwrite) id<_FBTweakColorViewControllerDelegate> delegate;

@end

@protocol _FBTweakColorViewControllerDelegate <NSObject>

/**
 @abstract Called when done is selected.
 @param viewController The view controller that selected done.
 */
- (void)tweakColorViewControllerSelectedDone:(_FBTweakColorViewController *)viewController;

@end
