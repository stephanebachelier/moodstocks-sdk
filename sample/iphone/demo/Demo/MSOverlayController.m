/**
 * Copyright (c) 2012 Moodstocks SAS
 *
 * Permission is hereby granted, free of charge, to any person obtaining
 * a copy of this software and associated documentation files (the
 * "Software"), to deal in the Software without restriction, including
 * without limitation the rights to use, copy, modify, merge, publish,
 * distribute, sublicense, and/or sell copies of the Software, and to
 * permit persons to whom the Software is furnished to do so, subject to
 * the following conditions:
 *
 * The above copyright notice and this permission notice shall be
 * included in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 * EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
 * MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 * NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
 * LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
 * OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
 * WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 */

#import "MSOverlayController.h"

#import "MSDebug.h"
#import "MSScanner.h"

/* UI settings */
static const NSInteger kMSScanInfoMargin = 5;
static const NSInteger kMSInfoFontSize   = 14;

@interface MSOverlayController ()

- (UILabel *)getLabelWithTag:(NSInteger)tag;
- (void)updateCacheCount:(NSInteger)count;
- (void)updateCacheProgress:(float)percent;
- (void)updateCache:(NSString *)info;
- (void)updateEAN;
- (void)updateQRCode;

@end

@implementation MSOverlayController

@synthesize decodeEAN_8;
@synthesize decodeEAN_13;
@synthesize decodeQRCode;
@synthesize decodeDatamatrix;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        _scanner = nil;
        
        // Register as a sync delegate to update the UI when a sync is pending
        // NOTE: you are not supposed to register as follow if you do not plan
        // to include UI elements related to the synchronization on your app
        [[[MSScanner sharedInstance] syncDelegates] addObject:self];
    }
    return self;
}

- (void)dealloc {
    [_actionSheet release];
    _actionSheet = nil;
    
    [[[MSScanner sharedInstance] syncDelegates] removeObject:self];
    
    [super dealloc];
}

#pragma mark - View lifecycle

- (void)loadView {
    CGRect frame = [UIScreen mainScreen].applicationFrame;
    CGRect navFrame = CGRectMake(0, 0, frame.size.width, frame.size.height - 44);
    self.view = [[[UIView alloc] initWithFrame:navFrame] autorelease];
    self.view.autoresizesSubviews = YES;
    self.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.view.backgroundColor = [UIColor clearColor];
    
    NSInteger tag = 0;
    UIFont *font = [UIFont systemFontOfSize:kMSInfoFontSize];
    UILineBreakMode breakMode = UILineBreakModeWordWrap;
    
    // Scanner settings
    NSMutableArray *scanInfo = [NSMutableArray array];
    [scanInfo addObject:@" [  ] cache "];
    [scanInfo addObject:@" [  ] EAN "];
    [scanInfo addObject:@" [  ] QR Code "];
    [scanInfo addObject:@" [  ] Datamatrix"];
    
    CGFloat offsetY = 0;
    for (NSString *text in scanInfo) {
        offsetY += kMSScanInfoMargin;
        
        CGSize textSize = [text sizeWithFont:font
                           constrainedToSize:CGSizeMake(self.view.frame.size.width - kMSScanInfoMargin, CGFLOAT_MAX)
                               lineBreakMode:breakMode];
        
        UILabel* infoLabel        = [[[UILabel alloc] init] autorelease];
        infoLabel.tag             = tag;
        infoLabel.contentMode     = UIViewContentModeLeft;
        infoLabel.lineBreakMode   = breakMode;
        infoLabel.numberOfLines   = 0; // i.e. no limit
        infoLabel.backgroundColor = [[[UIColor alloc] initWithRed:0 green:0 blue:0 alpha:0.5] autorelease];
        infoLabel.textColor       = [UIColor whiteColor];
        infoLabel.shadowColor     = [UIColor blackColor];
        infoLabel.text            = text;
        infoLabel.font            = font;
        infoLabel.frame           = CGRectMake(kMSScanInfoMargin, offsetY, textSize.width, textSize.height);
        
        offsetY += textSize.height;
        tag++;
        
        [self.view addSubview:infoLabel];
    }
    
    offsetY = self.view.frame.size.height;
    
    // Instructions
    NSMutableArray *userInfo = [NSMutableArray array];
    [userInfo addObject:@" One object/barcode at a time. "];
    [userInfo addObject:@" Place it upright. "];
    [userInfo addObject:@" Tap to snap if nothing's found. "];
    
    for (int i = 2; i >=0; i--) {
        NSString *text = [userInfo objectAtIndex:i];
        
        offsetY -= kMSScanInfoMargin;
        
        CGSize textSize = [text sizeWithFont:font
                           constrainedToSize:CGSizeMake(self.view.frame.size.width, CGFLOAT_MAX)
                               lineBreakMode:breakMode];
        
        UILabel* userInfoLabel        = [[[UILabel alloc] init] autorelease];
        userInfoLabel.tag             = tag;
        userInfoLabel.contentMode     = UIViewContentModeCenter;
        userInfoLabel.lineBreakMode   = breakMode;
        userInfoLabel.numberOfLines   = 0; // i.e. no limit
        userInfoLabel.backgroundColor = [[[UIColor alloc] initWithRed:0 green:0 blue:0 alpha:0.5] autorelease];
        userInfoLabel.textColor       = [UIColor whiteColor];
        userInfoLabel.shadowColor     = [UIColor blackColor];
        userInfoLabel.text            = text;
        userInfoLabel.font            = font;
        userInfoLabel.frame           = CGRectMake(0.5 * (self.view.frame.size.width - textSize.width),
                                                   offsetY - textSize.height,
                                                   textSize.width,
                                                   textSize.height);
        
        offsetY -= textSize.height;
        tag++;
        
        [self.view addSubview:userInfoLabel];
    }
}

- (void)viewDidLoad {
#if MS_SDK_REQUIREMENTS
    MSScanner *scanner = [MSScanner sharedInstance];
    if (![scanner isSyncing]) [self updateCacheCount:[scanner count:nil]];
    else [self updateCache:@"syncing..."];
#endif
}

- (void)viewDidUnload {
    [super viewDidUnload];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    // Return YES for supported orientations
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

#pragma mark - Private stuff

- (UILabel *)getLabelWithTag:(NSInteger)tag {
    UILabel* label = nil;
    for (UIView *v in [self.view subviews]) {
        if ([v isKindOfClass:[UILabel class]]) {
            UILabel *l = (UILabel *) v;
            if (l.tag == tag) {
                label = l;
                break;
            }
        }
    }
    
    return label;
}

- (void)updateCacheCount:(NSInteger)count {
    [self updateCache:[NSString stringWithFormat:@"%d %@", count, (count > 1 ? @"images" : @"image")]];
}

- (void)updateCacheProgress:(float)percent {
    [self updateCache:[NSString stringWithFormat:@"syncing... %.0f%%", percent]];
}

- (void)updateCache:(NSString *)info {
    UILabel *label = [self getLabelWithTag:0];
    
    if (label != nil) {
        NSString *text = [NSString stringWithFormat:@" [✓] cache (%@) ", info];
        UIFont *font = [UIFont systemFontOfSize:kMSInfoFontSize];
        UILineBreakMode breakMode = UILineBreakModeWordWrap;
        CGSize textSize = [text sizeWithFont:font
                           constrainedToSize:CGSizeMake(self.view.frame.size.width - kMSScanInfoMargin, CGFLOAT_MAX)
                               lineBreakMode:breakMode];
        CGRect frame = label.frame;
        
        label.text = text;
        label.frame = CGRectMake(frame.origin.x, frame.origin.y, textSize.width, textSize.height);
    }
}

- (void)updateEAN {
    UILabel * label = [self getLabelWithTag:1];
    
    if (label != nil) {
        BOOL ean = !!(self.decodeEAN_8 || self.decodeEAN_13);
        NSMutableArray *formats = [NSMutableArray array];
        if (ean) {
            if (self.decodeEAN_8)  [formats addObject:@"8"];
            if (self.decodeEAN_13) [formats addObject:@"13"];
        }
        NSString *head = ean ? @"✓" : @"  ";
        NSString *tail = ean ? [NSString stringWithFormat:@"(%@)", [formats componentsJoinedByString:@","]] : @"";
        
        NSString *text = [NSString stringWithFormat:@" [%@] EAN %@ ", head, tail];
        
        UIFont *font = [UIFont systemFontOfSize:kMSInfoFontSize];
        UILineBreakMode breakMode = UILineBreakModeWordWrap;
        CGSize textSize = [text sizeWithFont:font
                           constrainedToSize:CGSizeMake(self.view.frame.size.width - kMSScanInfoMargin, CGFLOAT_MAX)
                               lineBreakMode:breakMode];
        CGRect frame = label.frame;
        
        label.text = text;
        label.frame = CGRectMake(frame.origin.x, frame.origin.y, textSize.width, textSize.height);
    }
}

- (void)updateQRCode {
    UILabel * label = [self getLabelWithTag:2];
    
    if (label != nil) {
        NSString *text = [NSString stringWithFormat:@" [%@] QR Code ", (self.decodeQRCode ? @"✓" : @"  ")];
        
        UIFont *font = [UIFont systemFontOfSize:kMSInfoFontSize];
        UILineBreakMode breakMode = UILineBreakModeWordWrap;
        CGSize textSize = [text sizeWithFont:font
                           constrainedToSize:CGSizeMake(self.view.frame.size.width - kMSScanInfoMargin, CGFLOAT_MAX)
                               lineBreakMode:breakMode];
        CGRect frame = label.frame;
        
        label.text = text;
        label.frame = CGRectMake(frame.origin.x, frame.origin.y, textSize.width, textSize.height);
    }
}

- (void)updateDatamatrix {
    UILabel * label = [self getLabelWithTag:3];
    
    if (label != nil) {
        NSString *text = [NSString stringWithFormat:@" [%@] Datamatrix ", (self.decodeDatamatrix ? @"✓" : @"  ")];
        
        UIFont *font = [UIFont systemFontOfSize:kMSInfoFontSize];
        UILineBreakMode breakMode = UILineBreakModeWordWrap;
        CGSize textSize = [text sizeWithFont:font
                           constrainedToSize:CGSizeMake(self.view.frame.size.width - kMSScanInfoMargin, CGFLOAT_MAX)
                               lineBreakMode:breakMode];
        CGRect frame = label.frame;
        
        label.text = text;
        label.frame = CGRectMake(frame.origin.x, frame.origin.y, textSize.width, textSize.height);
    }
}

#pragma mark - MSScannerOverlayDelegate

- (void)scanner:(MSScannerController *)scanner resultFound:(MSResult *)result {
    _scanner = scanner;
    
    int type = [result getType];
    NSString *value = [result getValue];
    NSString *resultStr;
    switch (type) {
        case MS_RESULT_TYPE_IMAGE:
            resultStr = value;
            break;
            
        case MS_RESULT_TYPE_EAN8:
            resultStr = [NSString stringWithFormat:@"EAN 8: %@", value];
            break;
            
        case MS_RESULT_TYPE_EAN13:
            resultStr = [NSString stringWithFormat:@"EAN 13: %@", value];
            break;
            
        case MS_RESULT_TYPE_QRCODE:
            resultStr = [NSString stringWithFormat:@"QR Code: %@", value];
            break;
            
        case MS_RESULT_TYPE_DMTX:
            resultStr = [NSString stringWithFormat:@"Datamatrix: %@", value];
            break;

        default:
            resultStr = @"<UNDEFINED>";
            break;
    }
    
    // Retrieve and dismiss former result (if any)
    if (_actionSheet != nil) {
        [_actionSheet dismissWithClickedButtonIndex:-1 animated:NO];
        [_actionSheet release];
        _actionSheet = nil;
    }
    
    // Present the most up-to-date result in overlay
    //
    // NOTE: this is a very basic way to display some information / action in overlay
    //       You can think of it as an "hello world". In a real application you may want
    //       to introduce your own UI elements and animations according to your needs
    _actionSheet = [[UIActionSheet alloc] initWithTitle:resultStr
                                               delegate:self
                                      cancelButtonTitle:@"OK"
                                 destructiveButtonTitle:nil
                                      otherButtonTitles:nil];
    _actionSheet.actionSheetStyle = UIActionSheetStyleBlackTranslucent;
    [_actionSheet showInView:self.view];
}

- (void)scanner:(MSScannerController *)scanner stateUpdated:(NSDictionary *)state {
    NSNumber *ean8 = (NSNumber *) [state objectForKey:@"decode_ean_8"];
    if (ean8 != nil)
        self.decodeEAN_8 = [ean8 boolValue];
    NSNumber *ean13 = (NSNumber *) [state objectForKey:@"decode_ean_13"];
    if (ean13 != nil)
        self.decodeEAN_13 = [ean13 boolValue];
    
    if (ean8 != nil || ean13 != nil) [self updateEAN];
    
    NSNumber *qrCode = (NSNumber *) [state objectForKey:@"decode_qrcode"];
    if (qrCode != nil) {
        self.decodeQRCode = [qrCode boolValue];
        [self updateQRCode];
    }
    
    NSNumber *dmtx = (NSNumber *) [state objectForKey:@"decode_datamatrix"];
    if (dmtx != nil) {
        self.decodeDatamatrix = [dmtx boolValue];
        [self updateDatamatrix];
    }
}

#pragma mark - UIActionSheetDelegate

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (buttonIndex == 0) {
        // Tell the scanner to start scanning again
        [_scanner resume];
    }
}

#pragma mark - MSScannerDelegate

// The purpose of the methods below is to update the synchronization information on the UI side

#if MS_SDK_REQUIREMENTS
- (void)scannerWillSync:(MSScanner *)scanner {
    [self updateCache:@"syncing..."];
}

- (void)didSyncWithProgress:(NSNumber *)current total:(NSNumber *)total {
    float percent = 100 * [current floatValue] / [total floatValue];
    [self updateCacheProgress:percent];
}

- (void)scannerDidSync:(MSScanner *)scanner {
    [self updateCacheCount:[scanner count:nil]];
}

- (void)scanner:(MSScanner *)scanner failedToSyncWithError:(NSError *)error {
    [self updateCacheCount:[scanner count:nil]];
}
#endif

@end
