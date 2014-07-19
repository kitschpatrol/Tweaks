/**
 Copyright (c) 2014-present, Facebook, Inc.
 All rights reserved.
 
 This source code is licensed under the BSD-style license found in the
 LICENSE file in the root directory of this source tree. An additional grant
 of patent rights can be found in the PATENTS file in the same directory.
 */

#import "FBTweak.h"
#import "FBColorUtils.h"
#import "_FBTweakTableViewCell.h"

@interface UIImage (Utils)
+ (UIImage*)imageWithColor:(UIColor*)color size:(CGSize)size;
@end

@implementation UIImage (Utils)

+ (UIImage*)imageWithColor:(UIColor*)color size:(CGSize)size
{
  UIGraphicsBeginImageContext(size);
  UIBezierPath* rPath = [UIBezierPath bezierPathWithRect:CGRectMake(0., 0., size.width, size.height)];
  [color setFill];
  [rPath fill];
  UIImage* image = UIGraphicsGetImageFromCurrentImageContext();
  UIGraphicsEndImageContext();
  return image;
}

@end

@interface _FBTweakTableViewCell () <UITextFieldDelegate>
@end

@implementation _FBTweakTableViewCell {
  UIView *_accessoryView;
  
  _FBTweakTableViewCellMode _mode;
  UISwitch *_switch;
  UITextField *_textField;
  UIStepper *_stepper;
}

- (instancetype)initWithReuseIdentifier:(NSString *)reuseIdentifier
{
  if ((self = [super initWithStyle:UITableViewCellStyleDefault reuseIdentifier:reuseIdentifier])) {
    self.selectionStyle = UITableViewCellSelectionStyleNone;

    _accessoryView = [[UIView alloc] init];
    self.accessoryView = _accessoryView; // necessary?



    _switch = [[UISwitch alloc] init];
    [_switch addTarget:self action:@selector(_switchChanged:) forControlEvents:UIControlEventValueChanged];
    [_accessoryView addSubview:_switch];
    
    _textField = [[UITextField alloc] init];
    _textField.textAlignment = NSTextAlignmentRight;
    _textField.delegate = self;
    [_accessoryView addSubview:_textField];
    
    _stepper = [[UIStepper alloc] init];
    [_stepper addTarget:self action:@selector(_stepperChanged:) forControlEvents:UIControlEventValueChanged];
    [_accessoryView addSubview:_stepper];
  }

  return self;
}

- (void)dealloc
{
  [_switch removeTarget:self action:@selector(_switchChanged:) forControlEvents:UIControlEventValueChanged];
  _textField.delegate = nil;
  [_stepper removeTarget:self action:@selector(_stepperChanged:) forControlEvents:UIControlEventValueChanged];
}

- (void)layoutSubviews
{
  if (_mode == _FBTweakTableViewCellModeBoolean) {
    [_switch sizeToFit];
    _accessoryView.bounds = _switch.bounds;
  } else if (_mode == _FBTweakTableViewCellModeInteger ||
             _mode == _FBTweakTableViewCellModeReal) {
    [_stepper sizeToFit];
    
    CGRect textFrame = CGRectMake(0, 0, self.bounds.size.width / 4, self.bounds.size.height);
    CGRect stepperFrame = CGRectMake(textFrame.size.width + 6.0,
                                     (textFrame.size.height - _stepper.bounds.size.height) / 2,
                                     _stepper.bounds.size.width,
                                     _stepper.bounds.size.height);
    _textField.frame = CGRectIntegral(textFrame);
    _stepper.frame = CGRectIntegral(stepperFrame);
    
    CGRect accessoryFrame = CGRectUnion(stepperFrame, textFrame);
    _accessoryView.bounds = CGRectIntegral(accessoryFrame);
  } else if (_mode == _FBTweakTableViewCellModeString || _mode == _FBTweakTableViewCellModeColor) {
    CGFloat margin = CGRectGetMinX(self.textLabel.frame);
    CGFloat textFieldWidth = self.bounds.size.width - (margin * 3.0) - [self.textLabel sizeThatFits:CGSizeZero].width;
    CGRect textBounds = CGRectMake(0, 0, textFieldWidth, self.bounds.size.height);
    _textField.frame = CGRectIntegral(textBounds);
    _accessoryView.bounds = CGRectIntegral(textBounds);
  } else if (_mode == _FBTweakTableViewCellModeAction) {
    _accessoryView.bounds = CGRectZero;
  }

  // This positions the accessory view, so call it after updating its bounds.
  [super layoutSubviews];
}

#pragma mark - Configuration

- (_FBTweakTableViewCellMode)mode
{
    FBTweakValue value = (_tweak.currentValue ?: _tweak.defaultValue);
    _FBTweakTableViewCellMode mode = _FBTweakTableViewCellModeNone;
    if ([value isKindOfClass:[NSString class]]) {
      if ([value hasPrefix:@"#"]) {
        mode = _FBTweakTableViewCellModeColor;
      } else {
        mode = _FBTweakTableViewCellModeString;
      }
    } else if ([value isKindOfClass:[NSNumber class]]) {
      // In the 64-bit runtime, BOOL is a real boolean.
      // NSNumber doesn't always agree; compare both.
      if (strcmp([value objCType], @encode(char)) == 0 ||
          strcmp([value objCType], @encode(_Bool)) == 0) {
        mode = _FBTweakTableViewCellModeBoolean;
      } else if (strcmp([value objCType], @encode(NSInteger)) == 0 ||
                 strcmp([value objCType], @encode(NSUInteger)) == 0) {
        mode = _FBTweakTableViewCellModeInteger;
      } else {
        mode = _FBTweakTableViewCellModeReal;
      }
    } else if ([_tweak isAction]) {
      mode = _FBTweakTableViewCellModeAction;
    }
return mode;

    }

#pragma mark - Configuration
    
- (void)setTweak:(FBTweak *)tweak
{
  if (_tweak != tweak) {
    _tweak = tweak;
  }
  self.textLabel.text = tweak.name;
  FBTweakValue value = (tweak.currentValue ?: tweak.defaultValue);
  [self _updateMode:[self mode]];
  [self _updateValue:value write:NO];
}

- (void)_updateMode:(_FBTweakTableViewCellMode)mode
{
  _mode = mode;

  self.accessoryView = _accessoryView;
  self.accessoryType = UITableViewCellAccessoryNone;
  self.selectionStyle = UITableViewCellSelectionStyleNone;

  if (_mode == _FBTweakTableViewCellModeBoolean) {
    _switch.hidden = NO;
    _textField.hidden = YES;
    _stepper.hidden = YES;
    self.imageView.hidden = YES;
  } else if (_mode == _FBTweakTableViewCellModeInteger) {
    _switch.hidden = YES;
    _textField.hidden = NO;
    _textField.keyboardType = UIKeyboardTypeNumberPad;
    _stepper.hidden = NO;
    _stepper.stepValue = 1.0;
    _stepper.minimumValue = [_tweak.minimumValue longLongValue];
    _stepper.maximumValue = [_tweak.maximumValue longLongValue];
    self.imageView.hidden = YES;
  } else if (_mode == _FBTweakTableViewCellModeReal) {
    _switch.hidden = YES;
    _textField.hidden = NO;
    _textField.keyboardType = UIKeyboardTypeDecimalPad;
    _stepper.hidden = NO;
    _stepper.stepValue = 1.0;

    if (_tweak.minimumValue != nil) {
      _stepper.minimumValue = [_tweak.minimumValue doubleValue];
    } else {
      _stepper.minimumValue = [_tweak.defaultValue doubleValue] / 10.0;
    }

    if (_tweak.maximumValue != nil) {
      _stepper.maximumValue = [_tweak.maximumValue doubleValue];
    } else {
      _stepper.maximumValue = [_tweak.defaultValue doubleValue] * 10.0;
    }

    _stepper.stepValue = (_stepper.maximumValue - _stepper.minimumValue) / 100.0;
    self.imageView.hidden = YES;
  } else if (_mode == _FBTweakTableViewCellModeString) {
    _switch.hidden = YES;
    _textField.hidden = NO;
    _textField.keyboardType = UIKeyboardTypeDefault;
    _stepper.hidden = YES;
    self.imageView.hidden = YES;
  } else if (_mode == _FBTweakTableViewCellModeColor) {
    _switch.hidden = YES;
    _textField.hidden = YES;
    _stepper.hidden = YES;
    self.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    self.accessoryView = nil;
    self.imageView.hidden = NO;
 } else if (_mode == _FBTweakTableViewCellModeAction) {
    _switch.hidden = YES;
    _textField.hidden = YES;
    _stepper.hidden = YES;

    self.accessoryView = nil;
    self.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    self.selectionStyle = UITableViewCellSelectionStyleBlue;
    self.imageView.hidden = YES;
  } else {
    _switch.hidden = YES;
    _textField.hidden = YES;
    _stepper.hidden = YES;
    self.imageView.hidden = YES;
  }

  
  [self setNeedsLayout];
  [self layoutIfNeeded];
}

#pragma mark - Actions

- (void)setSelected:(BOOL)selected animated:(BOOL)animated
{
  [super setSelected:selected animated:animated];

  if (_mode == _FBTweakTableViewCellModeAction) {
    if (selected) {
      [self setSelected:NO animated:YES];

      dispatch_block_t block = _tweak.defaultValue;
      if (block != NULL) {
        block();
      }
    }
  }
}

- (void)_switchChanged:(UISwitch *)switch_
{
  [self _updateValue:@(_switch.on) primary:NO write:YES];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
  [_textField resignFirstResponder];
  return YES;
}

- (void)textFieldDidEndEditing:(UITextField *)textField
{
  if (_mode == _FBTweakTableViewCellModeString || _mode == _FBTweakTableViewCellModeColor) {
    [self _updateValue:_textField.text primary:NO write:YES];
  } else if (_mode == _FBTweakTableViewCellModeInteger) {
    NSNumber *number = @([_textField.text longLongValue]);
    [self _updateValue:number primary:NO write:YES];
  } else if (_mode == _FBTweakTableViewCellModeReal) {
    NSNumber *number = @([_textField.text doubleValue]);
    [self _updateValue:number primary:NO write:YES];
  } else {
    NSAssert(NO, @"unexpected type");
  }
}

- (void)_stepperChanged:(UIStepper *)stepper
{
  if (_mode == _FBTweakTableViewCellModeInteger) {
    NSNumber *number = @([@(stepper.value) longLongValue]);
    [self _updateValue:number primary:NO write:YES];
  } else {
    [self _updateValue:@(stepper.value) primary:NO write:YES];
  }
}

- (void)_updateValue:(FBTweakValue)value primary:(BOOL)primary write:(BOOL)write
{
  if (write) {
    _tweak.currentValue = value;
  }
  
  if (_mode == _FBTweakTableViewCellModeBoolean) {
    if (primary) {
      _switch.on = [value boolValue];
    }
  } else if (_mode == _FBTweakTableViewCellModeString) {
    if (primary) {
      _textField.text = value;
    }
  } else if (_mode == _FBTweakTableViewCellModeColor) {
    [self.imageView setImage:[UIImage imageWithColor:FBColorFromHexString(value) size:CGSizeMake(30, 30)]];
  } else if (_mode == _FBTweakTableViewCellModeInteger) {
    if (primary) {
      _stepper.value = [value longLongValue];
    }
    _textField.text = [value stringValue];
  } else if (_mode == _FBTweakTableViewCellModeReal) {
    if (primary) {
      _stepper.value = [value doubleValue];
    }
    
    double exp = log10(_stepper.stepValue);
    long precision = exp < 0 ? ceilf(fabs(exp)) : 0;
    
    if (_tweak.precisionValue) {
      precision = [[_tweak precisionValue] longValue];
    }
      
    NSString *format = [NSString stringWithFormat:@"%%.%ldf", precision];
    _textField.text = [NSString stringWithFormat:format, [value doubleValue]];
  }
}


@end
