/*
     File: LineFoldingLayoutManager.m
 Abstract: NSLayoutManager subclass implementing custom layout/glyph invalidation logic for lineFoldingAttributeName.
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

#import "LineFoldingLayoutManager.h"
#import "LineFoldingTypesetter.h"
#import "LineFoldingGlyphGenerator.h"
#import "LineFoldingTextStorage.h"

@implementation LineFoldingLayoutManager
- (instancetype)init {
    self = [super init];
    
    if (nil == self) return nil;

    // Setup LineFoldingTypesetter
    LineFoldingTypesetter *typesetter = [[LineFoldingTypesetter alloc] init];
    
    self.typesetter = typesetter;
    

    // Setup LineFoldingGlyphGenerator
    LineFoldingGlyphGenerator *glyphGenerator = [[LineFoldingGlyphGenerator alloc] init];

    self.glyphGenerator = glyphGenerator;


    [self setBackgroundLayoutEnabled:NO];

    return self;
}

- (void)drawGlyphsForGlyphRange:(NSRange)glyphsToShow atPoint:(NSPoint)origin {
    NSTextStorage *textStorage = self.textStorage;
    
    [(LineFoldingTextStorage *)textStorage setLineFoldingEnabled:YES];
    [super drawGlyphsForGlyphRange:glyphsToShow atPoint:origin];
    [(LineFoldingTextStorage *)textStorage setLineFoldingEnabled:NO];
}

// -textStorage:edited:range:changeInLength:invalidatedRange: delegate method invoked from NSTextStorage notifies layout managers whenever there was a modifications.  Based on the notification, NSLayoutManager invalidates cached internal information.  With normal circumstances, NSLayoutManager extends the invalidated range to nearest paragraph boundaries.  Since -[LineFoldingTypesetter actionForCharacterAtIndex:] might change the paragraph separator behavior, we need to make sure that the invalidation is covering the visible line range.
- (void)textStorage:(NSTextStorage *)str edited:(NSUInteger)editedMask range:(NSRange)newCharRange changeInLength:(NSInteger)delta invalidatedRange:(NSRange)invalidatedCharRange {
    NSUInteger length = str.length;
    NSNumber *value;
    NSRange effectiveRange, range;

    if ((invalidatedCharRange.location == length) && (invalidatedCharRange.location != 0)) { // it's at the end. check if the last char is in lineFoldingAttributeName
        value = [str attribute:lineFoldingAttributeName atIndex:invalidatedCharRange.location - 1 effectiveRange:&effectiveRange];

        if (value && value.boolValue) invalidatedCharRange = NSUnionRange(invalidatedCharRange, effectiveRange);
    }

    if (invalidatedCharRange.location < length) {
        NSString *string = str.string;
        NSUInteger start, end;

        if (delta > 0) {
            NSUInteger contentsEnd;

            [string getParagraphStart:NULL end:&end contentsEnd:&contentsEnd forRange:newCharRange];

            if ((contentsEnd != end) && (invalidatedCharRange.location > 0) && (NSMaxRange(newCharRange) == end)) { // there was para sep insertion. extend to both sides
                if (newCharRange.location <= invalidatedCharRange.location) {
                    invalidatedCharRange.length = (NSMaxRange(invalidatedCharRange) - (newCharRange.location - 1));
                    invalidatedCharRange.location = (newCharRange.location - 1);
                }

                if ((end < length) && (NSMaxRange(invalidatedCharRange) <= end)) {
                    invalidatedCharRange.length = ((end + 1) - invalidatedCharRange.location);
                }
            }
        }

        range = invalidatedCharRange;

        while ((range.location > 0) || (NSMaxRange(range) < length)) {
            [string getParagraphStart:&start end:&end contentsEnd:NULL forRange:range];
            range.location = start;
            range.length = (end - start);

            // Extend backward
            value = [str attribute:lineFoldingAttributeName atIndex:range.location longestEffectiveRange:&effectiveRange inRange:NSMakeRange(0, range.location + 1)];
            if (value && value.boolValue && (effectiveRange.location < range.location)) {
                range.length += (range.location - effectiveRange.location);
                range.location = effectiveRange.location;
            }

            // Extend forward
            if (NSMaxRange(range) < length) {
                value = [str attribute:lineFoldingAttributeName atIndex:NSMaxRange(range) longestEffectiveRange:&effectiveRange inRange:NSMakeRange(NSMaxRange(range), length - NSMaxRange(range))];
                if (value && value.boolValue && (NSMaxRange(effectiveRange) > NSMaxRange(range))) {
                    range.length = NSMaxRange(effectiveRange) - range.location;
                }
            }

            if (NSEqualRanges(range, invalidatedCharRange)) break;
            invalidatedCharRange = range;
        }
    }

    [super textStorage:str edited:editedMask range:newCharRange changeInLength:delta invalidatedRange:invalidatedCharRange];
}
@end
