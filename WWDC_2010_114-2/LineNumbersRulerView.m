/*
     File: LineNumbersRulerView.m
 Abstract: NSRulerView subclass displaying the line number.
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

#import "LineNumbersRulerView.h"

@interface LineNumbersRulerView ()
@property (getter=isLineInformationValid) BOOL lineInformationValid;

- (NSDictionary *)textAttributes;
@end

@implementation LineNumbersRulerView

@synthesize font, textColor, backgroundColor, lineInformationValid;

- (id)initWithScrollView:(NSScrollView *)scrollView orientation:(NSRulerOrientation)orientation {
    self = [super initWithScrollView:scrollView orientation:orientation];
    if (self) {
        font = [[NSFont labelFontOfSize:[NSFont systemFontSizeForControlSize:NSMiniControlSize]] retain];
        textColor = [[NSColor darkGrayColor] retain];
        backgroundColor = [[NSColor colorWithCalibratedWhite:0.9 alpha:1.0] retain];
    }
    return self;
}

- (void)dealloc {
    [font release];
    [textColor release];
    [backgroundColor release];
    
    [super dealloc];
}

- (BOOL)isFlipped {
    return YES;
}

- (void)setClientView:(NSView *)clientView {
    NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
    
    [notificationCenter removeObserver:self name:NSTextStorageDidProcessEditingNotification object:nil];
    
    [super setClientView:clientView];
    
    if ([clientView isKindOfClass:[NSTextView self]]) {
        NSTextStorage *textStorage = [(NSTextView *)clientView textStorage];
        
        [notificationCenter addObserver:self selector:@selector(clientTextStorageDidProcessEditing:) name:NSTextStorageDidProcessEditingNotification object:textStorage];
    }
}

- (void)clientTextStorageDidProcessEditing:(NSNotification *)notification {
    self.lineInformationValid = NO;
    
    [self setNeedsDisplay:YES];
}

- (NSTextStorage *)currentTextStorage {
    NSView *clientView = [self clientView];
    return [clientView isKindOfClass:[NSTextView self]] ? [(NSTextView *)clientView textStorage] : nil;
}

- (void)updateLineInformation {
    NSMutableIndexSet *mutableLineStartCharacterIndexes = [NSMutableIndexSet indexSet];
    
    NSString *clientString = [[self currentTextStorage] string];
    
    [clientString enumerateSubstringsInRange:(NSRange){.length=[clientString length]} options:NSStringEnumerationByLines|NSStringEnumerationSubstringNotRequired usingBlock:^(NSString *substring, NSRange substringRange, NSRange enclosingRange, BOOL *stop) {
        [mutableLineStartCharacterIndexes addIndex:substringRange.location];
    }];
    
    const NSUInteger numberOfLines = [mutableLineStartCharacterIndexes count];
    const NSUInteger newLineStartCharacterIndexesSize = numberOfLines * sizeof(NSUInteger);
    if (newLineStartCharacterIndexesSize > _lineStartCharacterIndexesSize) {
        if (_lineStartCharacterIndexes) {
            void *__strong newIndexes = NSReallocateCollectable(_lineStartCharacterIndexes, newLineStartCharacterIndexesSize, 0);
            if (!newIndexes) {
                return;
            }
            
            _lineStartCharacterIndexes = newIndexes;
        }
        else {
            _lineStartCharacterIndexes = NSAllocateCollectable(newLineStartCharacterIndexesSize, 0);
            if (!_lineStartCharacterIndexes)
                return;
        }
        
        _lineStartCharacterIndexesSize = newLineStartCharacterIndexesSize;
    }
    
    if (_lineStartCharacterIndexes) {
        [mutableLineStartCharacterIndexes getIndexes:_lineStartCharacterIndexes maxCount:_lineStartCharacterIndexesSize/sizeof(NSUInteger) inIndexRange:NULL];
    }
    
    self.lineInformationValid = YES;
    
    // update the thickness
    const double numberOfDigits = numberOfLines > 0 ? ceil(log10(numberOfLines)) : 1;
    
    // get the size of a digit to use
    const NSSize digitSize = [@"0" sizeWithAttributes:[self textAttributes]];
    const CGFloat newRuleThickness = MAX(ceil(digitSize.width * numberOfDigits + 8.0), 10.0);
    
    [self setRuleThickness:newRuleThickness];
}

- (void)viewWillDraw {
    [super viewWillDraw];

    if (!self.lineInformationValid) {
        [self updateLineInformation];
    }
}

- (NSUInteger)lineIndexForCharacterIndex:(NSUInteger)characterIndex {
    if (!_lineStartCharacterIndexes) {
        return NSNotFound;
    }
    
    NSUInteger *foundIndex = bsearch_b(&characterIndex, _lineStartCharacterIndexes, _lineStartCharacterIndexesSize/sizeof(NSUInteger), sizeof(NSUInteger), ^(const void *arg1, const void *arg2) {
        const NSUInteger int1 = *(NSUInteger *)arg1;
        const NSUInteger int2 = *(NSUInteger *)arg2;
        if (int1 < int2) {
            return -1;
        }
        else if (int1 > int2) {
            return 1;
        }
        else {
            return 0;
        }
    });
    
    return foundIndex ? (foundIndex-_lineStartCharacterIndexes) : NSNotFound;
}

- (NSDictionary *)textAttributes {
    return [NSDictionary dictionaryWithObjectsAndKeys:self.font, NSFontAttributeName, self.textColor, NSForegroundColorAttributeName, nil];
}

- (void)drawHashMarksAndLabelsInRect:(NSRect)dirtyRect {
    const NSRect bounds = [self bounds];
    
    [backgroundColor set];
    NSRectFill(dirtyRect);
    
    const NSRulerOrientation orientation = [self orientation];
    NSRect borderLineRect;
    switch (orientation) {
        case NSVerticalRuler:
            borderLineRect = NSMakeRect(NSMaxX(bounds)-1.0, 0, 1.0, NSHeight(bounds));
            break;
        case NSHorizontalRuler:
            borderLineRect = NSMakeRect(0, 0, NSWidth(bounds), 1.0);
            break;
    }
    
    if ([self needsToDrawRect:borderLineRect]) {
        [[backgroundColor shadowWithLevel:0.4] set];
        NSRectFill(borderLineRect);
    }
    
    NSView *clientView = [self clientView];
    if (![clientView isKindOfClass:[NSTextView self]]) {
        return;
    }
    
    NSTextView *textView = (NSTextView *)clientView;
    NSLayoutManager *layoutManager = [textView layoutManager];
    NSTextContainer *textContainer = [textView textContainer];
    NSTextStorage *textStorage = [textView textStorage];
    NSString *textString = [textStorage string];
    const NSRect visibleRect = [[[self scrollView] contentView] bounds];
    const NSSize textContainerInset = [textView textContainerInset];
    const NSUInteger textLength = [textString length];
    const CGFloat rightMostDrawableLocation = NSMinX(borderLineRect);
    
    const NSRange visibleGlyphRange = [layoutManager glyphRangeForBoundingRect:visibleRect inTextContainer:textContainer];
    const NSRange visibleCharacterRange = [layoutManager characterRangeForGlyphRange:visibleGlyphRange actualGlyphRange:NULL];
    
    NSDictionary *textAttributes = [self textAttributes];

    CGFloat lastLinePositionY = -1.0;

    for (NSUInteger characterIndex=visibleCharacterRange.location; characterIndex<textLength;) {
        const NSUInteger lineNumber = [self lineIndexForCharacterIndex:characterIndex];
        if (lineNumber == NSNotFound) {
            break;
        }
        
        NSUInteger layoutRectCount;
        NSRectArray layoutRects = [layoutManager rectArrayForCharacterRange:(NSRange){characterIndex, 0} withinSelectedCharacterRange:(NSRange){NSNotFound, 0} inTextContainer:textContainer rectCount:&layoutRectCount];
        if (layoutRectCount == 0) {
            break;
        }
        
        NSString *lineString = [NSString stringWithFormat:@"%lu", (unsigned long)lineNumber+1];
        const NSSize lineStringSize = [lineString sizeWithAttributes:textAttributes];
        const NSRect lineStringRect = NSMakeRect(rightMostDrawableLocation - lineStringSize.width - 2.0, NSMinY(layoutRects[0]) + textContainerInset.height - NSMinY(visibleRect) + (NSHeight(layoutRects[0]) - lineStringSize.height) / 2.0, lineStringSize.width, lineStringSize.height);
        
        if ([self needsToDrawRect:NSInsetRect(lineStringRect, -4.0, -4.0)] && (NSMinY(lineStringRect) != lastLinePositionY)) {
            [lineString drawWithRect:lineStringRect options:NSStringDrawingUsesLineFragmentOrigin attributes:textAttributes];
        }

        lastLinePositionY = NSMinY(lineStringRect);

        [textString getLineStart:NULL end:&characterIndex contentsEnd:NULL forRange:(NSRange){characterIndex, 0}];
    }
}

@end
