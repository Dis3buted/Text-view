/*
     File: LineFoldingTextAttachmentCell.m
 Abstract: NSTextAttachmentCell subclass for showing disclosure triangle icon for folded text.
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

#import "LineFoldingTextAttachmentCell.h"
#import "LineFoldingTextView.h"
#import "LineFoldingTextStorage.h"

#define HorizontalInset (4.0)
#define VerticalInset (1.0)
#define MaxWidth (100.0)

@implementation LineFoldingTextAttachmentCell
static NSImage *triangleImage = nil;
static NSGradient *gradient = nil;
static NSLayoutManager *scratchLayoutManager = nil;

+ (void)initialize {
    if (self == [LineFoldingTextAttachmentCell class]) {
        NSTextContainer *textContainer = [[NSTextContainer alloc] initWithContainerSize:NSZeroSize];

        triangleImage = [NSImage imageNamed:NSImageNameRightFacingTriangleTemplate];
        gradient = [[NSGradient alloc] initWithStartingColor:[NSColor whiteColor] endingColor:[NSColor redColor]];
        scratchLayoutManager = [[NSLayoutManager alloc] init];
        [scratchLayoutManager addTextContainer:textContainer];
    }
}

+ (NSImage *)disclosureTriangleImage { return triangleImage; }

+ (NSRect)boundingRectForDisclosureTriangleInFrame:(NSRect)aFrame {
    NSRect boundingRect;
    boundingRect.size = [self disclosureTriangleImage].size;

    boundingRect.origin = NSMakePoint(NSMinX(aFrame) + HorizontalInset, NSMinY(aFrame) + ((NSHeight(aFrame) - NSHeight(boundingRect)) / 2));

    return boundingRect;
}


- (void)drawWithFrame:(NSRect)cellFrame inView:(NSView *)controlView characterIndex:(NSUInteger)charIndex layoutManager:(NSLayoutManager *)layoutManager {
    NSBezierPath *path = [NSBezierPath bezierPathWithRoundedRect:cellFrame xRadius:5.0 yRadius:4.0];
    NSRect triangleRect = [[self class] boundingRectForDisclosureTriangleInFrame:cellFrame];
    NSTextContainer *textContainer = [layoutManager textContainerForGlyphAtIndex:[layoutManager glyphIndexForCharacterAtIndex:charIndex] effectiveRange:NULL];
    NSTextStorage *textStorage = layoutManager.textStorage;
    NSTextContainer *scratchContainer = scratchLayoutManager.textContainers[0];
    NSRect textFrame;
    NSRange glyphRange;
    BOOL lineFoldingEnabled;
    
    if (layoutManager == scratchLayoutManager) return; // don't render for scratchLayoutManager
    
    [gradient drawInBezierPath:path angle:85.0];
    
    [[[self class] disclosureTriangleImage] drawInRect:triangleRect fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0];
    
    // render text
    NSGraphicsContext *context = [NSGraphicsContext currentContext];
    
    [context saveGraphicsState];
    
    lineFoldingEnabled = ((LineFoldingTextStorage *)textStorage).lineFoldingEnabled;
    [(LineFoldingTextStorage *)textStorage setLineFoldingEnabled:NO];
    
    cellFrame.size.width = (NSMaxX(cellFrame) - HorizontalInset) - NSMaxX(triangleRect);
    cellFrame.origin.x = NSMaxX(triangleRect);
    
    NSRectClip(cellFrame);
    
    if (scratchLayoutManager.textStorage != textStorage) {
        [textStorage addLayoutManager:scratchLayoutManager];
    }
    
    if (!NSEqualSizes(textContainer.containerSize, scratchContainer.containerSize)) scratchContainer.containerSize = textContainer.containerSize;
    
    [scratchLayoutManager ensureLayoutForCharacterRange:NSMakeRange(charIndex, 1)];
    textFrame = [scratchLayoutManager lineFragmentRectForGlyphAtIndex:[scratchLayoutManager glyphIndexForCharacterAtIndex:charIndex] effectiveRange:&glyphRange];
    
    cellFrame.origin.x -= NSMinX(textFrame);
    cellFrame.origin.y -= NSMinY(textFrame);
    
    [scratchLayoutManager drawGlyphsForGlyphRange:glyphRange atPoint:cellFrame.origin];
    
    ((LineFoldingTextStorage *)textStorage).lineFoldingEnabled = lineFoldingEnabled;
    
    [context restoreGraphicsState];
}

- (BOOL)wantsToTrackMouseForEvent:(NSEvent *)theEvent inRect:(NSRect)cellFrame ofView:(NSView *)controlView atCharacterIndex:(NSUInteger)charIndex {
    return NSPointInRect([controlView convertPointFromBacking:theEvent.locationInWindow], [[self class] boundingRectForDisclosureTriangleInFrame:cellFrame]);
}

- (BOOL)trackMouse:(NSEvent *)theEvent inRect:(NSRect)cellFrame ofView:(NSView *)controlView atCharacterIndex:(NSUInteger)charIndex untilMouseUp:(BOOL)flag {

    if ([controlView respondsToSelector:@selector(unfoldLinesContainingCharacterAtIndex:)] && NSPointInRect([controlView convertPointFromBacking:theEvent.locationInWindow], [[self class] boundingRectForDisclosureTriangleInFrame:cellFrame])) {
        return [(LineFoldingTextView *)controlView unfoldLinesContainingCharacterAtIndex:charIndex];
    }

    return NO;
}

- (NSRect)cellFrameForTextContainer:(NSTextContainer *)textContainer proposedLineFragment:(NSRect)lineFrag glyphPosition:(NSPoint)position characterIndex:(NSUInteger)charIndex {
    NSLayoutManager *layoutManager = textContainer.layoutManager;
    NSTextStorage *textStorage = layoutManager.textStorage;
    NSTextContainer *scratchContainer = scratchLayoutManager.textContainers[0];
    NSRect textFrame;
    NSRange glyphRange;
    NSRect frame;
    BOOL lineFoldingEnabled = ((LineFoldingTextStorage *)textStorage).lineFoldingEnabled;

    if (layoutManager == scratchLayoutManager) return NSZeroRect; // we don't do layout for scratchLayoutManager

    [(LineFoldingTextStorage *)textStorage setLineFoldingEnabled:NO];

    if (scratchLayoutManager.textStorage != textStorage) {
        [textStorage addLayoutManager:scratchLayoutManager];
    }

    if (!NSEqualSizes(textContainer.containerSize, scratchContainer.containerSize)) scratchContainer.containerSize = textContainer.containerSize;

    [scratchLayoutManager ensureLayoutForCharacterRange:NSMakeRange(charIndex, 1)];
    textFrame = [scratchLayoutManager lineFragmentRectForGlyphAtIndex:[scratchLayoutManager glyphIndexForCharacterAtIndex:charIndex] effectiveRange:&glyphRange];

    ((LineFoldingTextStorage *)textStorage).lineFoldingEnabled = lineFoldingEnabled;
    
    frame.origin = NSZeroPoint;
    frame.size = [[self class] disclosureTriangleImage].size; 

    frame.size.width += (HorizontalInset * 2);
    frame.size.height = NSHeight(lineFrag);

    frame.origin.y -= [scratchLayoutManager.typesetter baselineOffsetInLayoutManager:scratchLayoutManager glyphIndex:glyphRange.location];

    frame.size.width += NSWidth(textFrame);
    if (NSWidth(frame) > MaxWidth) frame.size.width = MaxWidth;

    return frame;
}
@end
