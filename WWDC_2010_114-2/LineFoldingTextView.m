/*
     File: LineFoldingTextView.m
 Abstract: NSTextView subclass that manages lineFoldingAttributeName.
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

#import "LineFoldingTextView.h"
#import "LineFoldingTypesetter.h"
#import "LineFoldingLayoutManager.h"
#import "LineFoldingTextStorage.h"
#import "LineFoldingTextAttachmentCell.h"

@interface LineFoldingAnimationOverlay : NSView {
    void (^_renderer)(void);
    NSRange _glyphRange;
    BOOL _folding;
}
@property (copy) void (^renderer)(void);
@property NSRange glyphRange;
@property(getter=isFolding) BOOL folding;
@end

@implementation LineFoldingAnimationOverlay : NSView
@synthesize renderer = _renderer, glyphRange = _glyphRange, folding = _folding;

- (id)initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect];

    if (self) {
        [self setWantsLayer:YES];
    }

    return self;
}

- (BOOL)isFlipped { return YES; }

- (void)dealloc {
    [_renderer release];
    [super dealloc];
}

- (void)drawRect:(NSRect)dirtyRect {
    if (_renderer) _renderer();
}
@end

@implementation LineFoldingTextView

- (void)awakeFromNib {
    // Make sure using LineFoldingLayoutManager
    if (![[self layoutManager] isKindOfClass:[LineFoldingLayoutManager class]]) {
        LineFoldingLayoutManager *layoutManager = [[LineFoldingLayoutManager alloc] init];
        [[self textContainer] replaceLayoutManager:layoutManager];
        [layoutManager release];
    }
}

// lineFoldingAttributeName supporting action messages
- (void)foldSelectedLines:(id)sender {
    NSArray *ranges = [self rangesForUserParagraphAttributeChange];

    if (([ranges count] > 0) && [self shouldChangeTextInRanges:ranges replacementStrings:nil]) {
        NSNumber *trueValue = [NSNumber numberWithBool:YES];
        NSMutableArray *views = [NSMutableArray arrayWithCapacity:[ranges count]];
        NSLayoutManager *layoutManager = [self layoutManager];
        NSTextStorage *textStorage = [self textStorage];
        NSColor *color = ([self drawsBackground] ? [self backgroundColor] : nil);
        NSRect visibleRect = [self visibleRect];
        NSPoint containerOrigin = [self textContainerOrigin];
        NSView *baseOverlay = [[LineFoldingAnimationOverlay alloc] initWithFrame:visibleRect];
        __block LineFoldingAnimationOverlay *lastOverlay = nil;

        [self addSubview:baseOverlay];

        [textStorage beginEditing];
        [ranges enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            LineFoldingAnimationOverlay *overlay;
            NSRange characterRange = [obj rangeValue];
            NSRange glyphRange = [layoutManager glyphRangeForCharacterRange:characterRange actualCharacterRange:NULL];
            NSRect bounds = [layoutManager boundingRectForGlyphRange:glyphRange inTextContainer:[self textContainer]];
            NSRect viewBounds = bounds;

            viewBounds.origin.x += containerOrigin.x;
            viewBounds.origin.y += containerOrigin.y;

            if (NSIntersectsRect(viewBounds, visibleRect)) {
                viewBounds.origin.x -= NSMinX(visibleRect);
                viewBounds.origin.y -= NSMinY(visibleRect);

                if (lastOverlay) {
                    NSRange aGlyphRange;
                    NSRect aBounds;
                    aGlyphRange.location = NSMaxRange([lastOverlay glyphRange]);
                    aGlyphRange.length = glyphRange.location - aGlyphRange.location;
                    aBounds.origin.x = NSMinX(bounds) + containerOrigin.x;
                    aBounds.size.width = NSWidth(bounds);
                    aBounds.origin.y = NSMaxY([lastOverlay frame]) + containerOrigin.y;
                    aBounds.size.height = NSMinY(bounds) - NSMinY(aBounds);

                    overlay = [[LineFoldingAnimationOverlay alloc] initWithFrame:aBounds];
                    [baseOverlay addSubview:overlay];
                    [overlay setGlyphRange:aGlyphRange];
                    [overlay setRenderer:(void (^)(void))^() {
                        NSRect bounds = [layoutManager boundingRectForGlyphRange:aGlyphRange inTextContainer:[self textContainer]];
                        [color set];
                        NSRectFill([overlay bounds]);
                        [layoutManager drawGlyphsForGlyphRange:aGlyphRange atPoint:NSMakePoint(0.0, -NSMinY(bounds))];
                    }];
                    [views addObject:overlay];
                    [overlay release];
                }

                overlay = [[LineFoldingAnimationOverlay alloc] initWithFrame:viewBounds];
                [baseOverlay addSubview:overlay];
                [overlay setLayerContentsRedrawPolicy:NSViewLayerContentsRedrawNever];
                [overlay setGlyphRange:glyphRange];
                [overlay setFolding:YES];
                [overlay setRenderer:(void (^)(void))^(void) {
                    [color set];
                    NSRectFill([overlay bounds]);
                    [layoutManager drawGlyphsForGlyphRange:glyphRange atPoint:NSMakePoint(-NSMinX(bounds), -NSMinY(bounds))];
                }];
                [views addObject:overlay];
                [overlay display];
                [overlay release];
                lastOverlay = overlay;
            }

            [textStorage addAttribute:lineFoldingAttributeName value:trueValue range:characterRange];
        }];
        [textStorage endEditing];
        [self didChangeText];

        if ([views count] > 0) {
            if (lastOverlay) {
                NSRange aGlyphRange;

                aGlyphRange.location = NSMaxRange([lastOverlay glyphRange]);

                if ([layoutManager numberOfGlyphs] > aGlyphRange.location) {
                    NSRect aBounds = [layoutManager lineFragmentRectForGlyphAtIndex:aGlyphRange.location effectiveRange:NULL];

                    visibleRect.origin.y -= containerOrigin.y;

                    if (NSMaxY(visibleRect) > NSMinY(aBounds)) {
                        LineFoldingAnimationOverlay *overlay;

                        aBounds.size.height = NSMaxY(visibleRect) - NSMinY(aBounds);
                        aGlyphRange = [layoutManager glyphRangeForBoundingRect:aBounds inTextContainer:[self textContainer]];
                        aBounds.origin.x += containerOrigin.x;
                        aBounds.origin.y = NSMaxY([lastOverlay frame]);
                        overlay = [[LineFoldingAnimationOverlay alloc] initWithFrame:aBounds];
                        [baseOverlay addSubview:overlay];
                        [overlay setGlyphRange:aGlyphRange];
                        [overlay setRenderer:(void (^)(void))^(void) {
                            NSRect bounds = [layoutManager boundingRectForGlyphRange:aGlyphRange inTextContainer:[self textContainer]];
                            [color set];
                            NSRectFill([overlay bounds]);
                            [layoutManager drawGlyphsForGlyphRange:aGlyphRange atPoint:NSMakePoint(0.0, -NSMinY(bounds))];
                        }];
                        [views addObject:overlay];
                        [overlay display];
                        [overlay release];
                    }
                }
            }

            double duration = ([NSEvent modifierFlags] & NSControlKeyMask) ? 5.0 : 0.5;

            [NSAnimationContext beginGrouping];
            [[NSAnimationContext currentContext] setDuration:duration];
            
            [views enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                if (![obj isFolding]) {
                    NSPoint origin = [obj frame].origin;

                    origin.y = NSMinY([layoutManager boundingRectForGlyphRange:[obj glyphRange] inTextContainer:[self textContainer]]) + containerOrigin.y - NSMinY(visibleRect);

                    [[obj animator] setFrameOrigin:origin];
                }
            }];

            [NSAnimationContext endGrouping];
            
            [baseOverlay performSelector:@selector(removeFromSuperview) withObject:nil afterDelay:duration];
            [baseOverlay release];
        }

        [self setSelectedRange:NSMakeRange(NSMaxRange([[ranges lastObject] rangeValue]), 0)];
    }
}

- (BOOL)unfoldLinesContainingCharacterAtIndex:(NSUInteger)charIndex {
    NSTextStorage *textStorage = [self textStorage];
    NSRange range;
    NSNumber *value = [textStorage attribute:lineFoldingAttributeName atIndex:charIndex longestEffectiveRange:&range inRange:NSMakeRange(0, [textStorage length])];

    if (value && [value boolValue] && [self shouldChangeTextInRange:range replacementString:nil]) {
        NSTextStorage *textStorage = [self textStorage];
        NSLayoutManager *layoutManager = [self layoutManager];
        NSColor *color = ([self drawsBackground] ? [self backgroundColor] : nil);
        NSRect visibleRect = [self visibleRect];
        NSPoint containerOrigin = [self textContainerOrigin];
        NSView *baseOverlay = [[LineFoldingAnimationOverlay alloc] initWithFrame:visibleRect];
        NSRange glyphRange = [layoutManager glyphRangeForCharacterRange:range actualCharacterRange:NULL];
        LineFoldingAnimationOverlay *attachmentView;
        LineFoldingAnimationOverlay *triangleView;
        LineFoldingAnimationOverlay *slidingView;
        NSRect bounds;
        double duration = ([NSEvent modifierFlags] & NSControlKeyMask) ? 5.0 : 0.5;

        [self addSubview:baseOverlay];

        [(LineFoldingTextStorage *)textStorage setLineFoldingEnabled:YES];
        bounds = [layoutManager boundingRectForGlyphRange:glyphRange inTextContainer:[self textContainer]];

        attachmentView = [[LineFoldingAnimationOverlay alloc] initWithFrame:NSMakeRect(NSMinX(bounds) + containerOrigin.x - NSMinX(visibleRect), NSMinY(bounds) + containerOrigin.y - NSMinY(visibleRect), NSWidth(bounds), NSHeight(bounds))];

        [attachmentView setRenderer:(void (^)(void))^{
            [color set];
            NSRectFill(NSMakeRect(0.0, 0.0, NSWidth(bounds), NSHeight(bounds)));
            [layoutManager drawGlyphsForGlyphRange:glyphRange atPoint:NSMakePoint(-NSMinX(bounds), -NSMinY(bounds))];
        }];

        [baseOverlay addSubview:attachmentView];

        triangleView = [[LineFoldingAnimationOverlay alloc] initWithFrame:[LineFoldingTextAttachmentCell boundingRectForDisclosureTriangleInFrame:[attachmentView frame]]];
        [triangleView setRenderer:(void (^)(void))^{
            NSImage *image = [LineFoldingTextAttachmentCell disclosureTriangleImage];
            NSRect frame = NSZeroRect;
            frame.size = [image size];
            [image drawAtPoint:NSZeroPoint fromRect:frame operation:NSCompositeSourceOver fraction:1.0];
        }];
        [baseOverlay addSubview:triangleView];

        bounds = [attachmentView frame];

        visibleRect.size.height = NSMaxY(visibleRect) - NSMaxY(bounds);
        visibleRect.origin.y = NSMaxY(bounds);

        slidingView = [[LineFoldingAnimationOverlay alloc] initWithFrame:visibleRect];

        visibleRect.origin.x -= containerOrigin.x;
        visibleRect.origin.y -= containerOrigin.y;

        glyphRange = [layoutManager glyphRangeForBoundingRect:visibleRect inTextContainer:[self textContainer]];

        bounds = [layoutManager lineFragmentRectForGlyphAtIndex:glyphRange.location effectiveRange:NULL];

        [slidingView setRenderer:(void (^)(void))^{
            [color set];
            NSRectFill([slidingView bounds]);
            [layoutManager drawGlyphsForGlyphRange:glyphRange atPoint:NSMakePoint(-NSMinX(bounds), -NSMinY(bounds))];
        }];
        [baseOverlay addSubview:slidingView];

        [baseOverlay display];
         
        [(LineFoldingTextStorage *)textStorage setLineFoldingEnabled:NO];

        [textStorage removeAttribute:lineFoldingAttributeName range:range];
        [self didChangeText];

        [NSAnimationContext beginGrouping];
        [[NSAnimationContext currentContext] setDuration:duration];
        [[attachmentView animator] setAlphaValue:0.0];

        NSRect frame = [triangleView frame];

        [[triangleView animator] setFrameOrigin:NSMakePoint(NSMinX(frame) + NSHeight(frame), NSMinY(frame))];
        [[triangleView animator] setFrameRotation:-90.0];

        frame = [layoutManager lineFragmentRectForGlyphAtIndex:glyphRange.location effectiveRange:NULL];

        frame.origin.x = NSMinX([slidingView frame]);
        frame.origin.y += containerOrigin.y;

        [[slidingView animator] setFrameOrigin:frame.origin];
        [NSAnimationContext endGrouping];

        [attachmentView release];
        [triangleView release];
        [slidingView release];

        [baseOverlay performSelector:@selector(removeFromSuperview) withObject:nil afterDelay:duration];
        [baseOverlay release];

        [self setSelectedRange:NSMakeRange(NSMaxRange(range), 0)];

        return YES;
    }

    return NO;
}

// navigation support
- (void)mouseDown:(NSEvent *)event {
    NSLayoutManager *layoutManager = [self layoutManager];
    NSUInteger glyphIndex = [layoutManager glyphIndexForPoint:[self convertPointFromBase:[event locationInWindow]] inTextContainer:[self textContainer]];
    NSTextStorage *textStorage = [self textStorage];

    [(LineFoldingTextStorage *)textStorage setLineFoldingEnabled:YES];

    // trigger unfolding if inside LineFoldingAttachmentCell
    if (glyphIndex < [layoutManager numberOfGlyphs]) {
        NSUInteger charIndex = [layoutManager characterIndexForGlyphAtIndex:glyphIndex];
        NSRange range;
        NSNumber *value = [textStorage attribute:lineFoldingAttributeName atIndex:charIndex longestEffectiveRange:&range inRange:NSMakeRange(0, [textStorage length])];

        if (value && [value boolValue]) {
            NSTextAttachment *attachment = [textStorage attribute:NSAttachmentAttributeName atIndex:range.location effectiveRange:NULL];

            if (attachment) {
                NSTextAttachmentCell *cell = (NSTextAttachmentCell *)[attachment attachmentCell];
                NSRect cellFrame;
                NSPoint delta;

                glyphIndex = [layoutManager glyphIndexForCharacterAtIndex:range.location];

                cellFrame.origin = [self textContainerOrigin];
                cellFrame.size = [layoutManager attachmentSizeForGlyphAtIndex:glyphIndex];

                delta = [layoutManager lineFragmentRectForGlyphAtIndex:glyphIndex effectiveRange:NULL].origin;
                cellFrame.origin.x += delta.x;
                cellFrame.origin.y += delta.y;

                cellFrame.origin.x += [layoutManager locationForGlyphAtIndex:glyphIndex].x;

                if ([cell wantsToTrackMouseForEvent:event inRect:cellFrame ofView:self atCharacterIndex:range.location] && [cell trackMouse:event inRect:cellFrame ofView:self atCharacterIndex:range.location untilMouseUp:YES]) return;
            }
        }
    }

    [(LineFoldingTextStorage *)textStorage setLineFoldingEnabled:NO];

    [super mouseDown:event];
}

- (void)setSelectedRanges:(NSArray *)ranges affinity:(NSSelectionAffinity)affinity stillSelecting:(BOOL)stillSelectingFlag {
    if (!stillSelectingFlag && ([ranges count] == 1)) {
        NSRange range = [[ranges objectAtIndex:0] rangeValue];
        NSTextStorage *textStorage = [self textStorage];
        NSUInteger length = [textStorage length];

        if ((range.location < length) && ([[ranges objectAtIndex:0] rangeValue].length == 0)) { // make sure it's not inside lineFoldingAttributeName
            NSNumber *value = [textStorage attribute:lineFoldingAttributeName atIndex:range.location effectiveRange:NULL];

            if (value && [value boolValue]) {
                NSRange effectiveRange;
                (void)[textStorage attribute:lineFoldingAttributeName atIndex:range.location longestEffectiveRange:&effectiveRange inRange:NSMakeRange(0, length)];

                if (range.location != effectiveRange.location) { // it's not at the beginning. should be adjusted
                    range.location = ((affinity == NSSelectionAffinityUpstream) ? effectiveRange.location : NSMaxRange(effectiveRange));
                    [super setSelectedRange:range];
                    return;
                }
            }
        }   
    }

    [super setSelectedRanges:ranges affinity:affinity stillSelecting:stillSelectingFlag];
}

- (void)setTypingAttributes:(NSDictionary *)attrs {
    if ([attrs objectForKey:lineFoldingAttributeName]) { // we don't want to store lineFoldingAttributeName as a typing attribute
        NSMutableDictionary *copy = [[attrs mutableCopyWithZone:NULL] autorelease];
        [copy removeObjectForKey:lineFoldingAttributeName];
        attrs = copy;
    }
    
    [super setTypingAttributes:attrs];
}
@end
