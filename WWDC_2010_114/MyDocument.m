/*
     File: MyDocument.m
 Abstract: Simple Editor document class.
  Version: 1.0
 
 Disclaimer: IMPORTANT:  This Apple software is supplied to you by Apple
 Inc. ("Apple") in consideration of your agreement to the following
 terms, and your use, installation, modification or redistribution of
 this Apple software constitutes acceptance of these terms.  If you do
 not agree with these terms, please do not use, install, modify or
 redistribute this Apple software.
 
 In consideration of your agreement to abide by the following terms, and
 subject to these terms, Apple grants you a personal, non-exclusive
 license, under Apple's copyrights in this original Apple software (the
 "Apple Software"), to use, reproduce, modify and redistribute the Apple
 Software, with or without modifications, in source and/or binary forms;
 provided that if you redistribute the Apple Software in its entirety and
 without modifications, you must retain this notice and the following
 text and disclaimers in all such redistributions of the Apple Software.
 Neither the name, trademarks, service marks or logos of Apple Inc. may
 be used to endorse or promote products derived from the Apple Software
 without specific prior written permission from Apple.  Except as
 expressly stated in this notice, no other rights or licenses, express or
 implied, are granted by Apple herein, including but not limited to any
 patent rights that may be infringed by your derivative works or by other
 works in which the Apple Software may be incorporated.
 
 The Apple Software is provided by Apple on an "AS IS" basis.  APPLE
 MAKES NO WARRANTIES, EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION
 THE IMPLIED WARRANTIES OF NON-INFRINGEMENT, MERCHANTABILITY AND FITNESS
 FOR A PARTICULAR PURPOSE, REGARDING THE APPLE SOFTWARE OR ITS USE AND
 OPERATION ALONE OR IN COMBINATION WITH YOUR PRODUCTS.
 
 IN NO EVENT SHALL APPLE BE LIABLE FOR ANY SPECIAL, INDIRECT, INCIDENTAL
 OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 INTERRUPTION) ARISING IN ANY WAY OUT OF THE USE, REPRODUCTION,
 MODIFICATION AND/OR DISTRIBUTION OF THE APPLE SOFTWARE, HOWEVER CAUSED
 AND WHETHER UNDER THEORY OF CONTRACT, TORT (INCLUDING NEGLIGENCE),
 STRICT LIABILITY OR OTHERWISE, EVEN IF APPLE HAS BEEN ADVISED OF THE
 POSSIBILITY OF SUCH DAMAGE.
 
 Copyright (C) 2010 Apple Inc. All Rights Reserved.
 
 */

#import "MyDocument.h"
#import "LineNumbersRulerView.h"
#import "LineFoldingTextStorage.h"

@implementation MyDocument

@synthesize topTextView, bottomTextView, contentText, bottomScrollView, splitView;

- (instancetype) init {
    self = [super init];
    if (self) {
        contentText = [[LineFoldingTextStorage alloc] init];
        plainStringEncoding = NSUnicodeStringEncoding;
    }
    return self;
}


- (NSString *)windowNibName {
    return @"MyDocument";
}

- (void)windowControllerDidLoadNib:(NSWindowController *) aController {
    [super windowControllerDidLoadNib:aController];
    
    NSArray *textViews = @[topTextView, bottomTextView];
    
    for (NSTextView *textView in textViews) {
        [textView.layoutManager replaceTextStorage:contentText];

        NSScrollView *scrollView = textView.enclosingScrollView;
        [scrollView setHasHorizontalRuler:NO];
        [scrollView setHasVerticalRuler:YES];
        
        LineNumbersRulerView *rulerView = [[LineNumbersRulerView alloc] initWithScrollView:scrollView orientation:NSVerticalRuler];
        rulerView.clientView = textView;
        
        scrollView.verticalRulerView = rulerView;
        
        [scrollView setRulersVisible:YES];
    }
    
    [bottomScrollView removeFromSuperview];
}

- (BOOL)writeToURL:(NSURL *)absoluteURL ofType:(NSString *)typeName error:(NSError **)outError {
    if (UTTypeConformsTo((__bridge CFStringRef)typeName, kUTTypeRTFD)) {
        return [contentText.string writeToURL:absoluteURL atomically:YES encoding:plainStringEncoding error:outError];
    }
    else {
        return [super writeToURL:absoluteURL ofType:typeName error:outError];
    }
}

- (NSFileWrapper *)fileWrapperOfType:(NSString *)typeName error:(NSError **)outError {
    if (UTTypeConformsTo((__bridge CFStringRef)typeName, kUTTypeRTFD)) {
        return [contentText RTFDFileWrapperFromRange:(NSRange){.length=contentText.length } documentAttributes:nil];
    } // return [contentText RTFDFileWrapperFromRange:(NSRange){.length=[contentText length]} documentAttributes:nil];
    else {
        return [super fileWrapperOfType:typeName error:outError];
    }
}

- (NSData *)dataOfType:(NSString *)typeName error:(NSError **)outError {
    if (UTTypeConformsTo((__bridge CFStringRef)typeName, kUTTypeRTF)) {
        return [contentText RTFFromRange:(NSRange){.length=contentText.length } documentAttributes:nil];
    }
    else if (UTTypeConformsTo((__bridge CFStringRef)typeName, kUTTypeFlatRTFD)) {
        return [contentText RTFDFromRange:(NSRange){.length=contentText.length } documentAttributes:nil];
    }
    else {
        return nil;
    }
}

- (BOOL)readFromURL:(NSURL *)absoluteURL ofType:(NSString *)typeName error:(NSError **)outError {
    if (UTTypeConformsTo((__bridge CFStringRef)typeName, kUTTypePlainText)) {
        NSString *fileContents = [NSString stringWithContentsOfURL:absoluteURL usedEncoding:&plainStringEncoding error:outError];
        if (!fileContents) {
            return NO;
        }
        
        [contentText beginEditing];
        [contentText replaceCharactersInRange:(NSRange){.length=contentText.length } withString:fileContents];
        [contentText endEditing];
        
        return YES;
    }
    else {
        return [super readFromURL:absoluteURL ofType:typeName error:outError];
    }
}

- (BOOL)readFromFileWrapper:(NSFileWrapper *)fileWrapper ofType:(NSString *)typeName error:(NSError **)outError {
    if (UTTypeConformsTo((__bridge CFStringRef)typeName, kUTTypeRTFD)) {
        NSAttributedString *fileContents = [[NSAttributedString alloc] initWithRTFDFileWrapper:fileWrapper documentAttributes:NULL];
        if (!fileContents) {
            return NO;
        }
        
        [contentText beginEditing];
        [contentText replaceCharactersInRange:(NSRange){.length=contentText.length } withAttributedString:fileContents];
        [contentText endEditing];
        
		
        return YES;
    }
    else {
        return [super readFromFileWrapper:fileWrapper ofType:typeName error:outError];
    }
}

- (BOOL)readFromData:(NSData *)data ofType:(NSString *)typeName error:(NSError **)outError {
    NSAttributedString *fileContents = nil;
    
    if (UTTypeConformsTo((__bridge CFStringRef)typeName, kUTTypeRTF)) {
        fileContents = [[NSAttributedString alloc] initWithRTF:data documentAttributes:NULL];
    }
    else if (UTTypeConformsTo((__bridge CFStringRef)typeName, kUTTypeFlatRTFD)) {
        fileContents = [[NSAttributedString alloc] initWithRTF:data documentAttributes:NULL];
    }
    
    if (!fileContents) {
        return NO;
    }
    
    [contentText beginEditing];
    [contentText replaceCharactersInRange:(NSRange){.length=contentText.length } withAttributedString:fileContents];
    [contentText endEditing];
    
    
    return YES;
}

- (NSPrintOperation *)printOperationWithSettings:(NSDictionary *)printSettings error:(NSError **)outError {
    return [NSPrintOperation printOperationWithView:topTextView printInfo:self.printInfo];
}

- (IBAction)splitTextView:(id)sender {
    if (bottomScrollView.superview) {
        [bottomScrollView removeFromSuperview];
    }
    else {
        [splitView addSubview:bottomScrollView positioned:NSWindowBelow relativeTo:topTextView.enclosingScrollView];
    }
}

- (IBAction)toggleLineNumbers:(id)sender {
    const BOOL rulersVisible = bottomScrollView.rulersVisible;
    
    topTextView.enclosingScrollView.rulersVisible = !rulersVisible;
    bottomScrollView.rulersVisible = !rulersVisible;
}

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem {
    SEL action = menuItem.action;
    
    if (action == @selector(toggleLineNumbers:)) {
        menuItem.state = bottomScrollView.rulersVisible ? NSOnState : NSOffState;
    }
    else  if (action == @selector(splitTextView:)) {
        menuItem.state = bottomScrollView.superview != nil ? NSOnState : NSOffState;
    }
    
    return YES;
}

@end
